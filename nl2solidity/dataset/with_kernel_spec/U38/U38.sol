// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, newAllowance)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
    }
}

contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IYieldStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalValue() external view returns (uint256);
    function harvest() external returns (uint256);
}

contract StablecoinVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_DEPOSIT = 100 * 10 ** 18;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant MAX_TOTAL_WEIGHT = 10000;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 private constant YIELD_SCALE = 1e18;

    IERC20 public immutable stablecoin;
    address public operator;

    uint256 public totalDeposits;
    mapping(address => uint256) public balances;

    uint256 public yieldPerShare;
    uint256 public yieldPool;
    mapping(address => uint256) public userYieldIndex;
    mapping(address => uint256) public pendingYield;

    uint256 public accumulatedFees;

    struct StrategyConfig {
        bool isActive;
        uint256 weight;
    }
    mapping(address => StrategyConfig) public strategies;
    address[] public strategyList;
    mapping(address => uint256) public strategyDeposits;
    uint256 public totalWeight;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event YieldClaimed(address indexed user, uint256 amount);
    event StrategyAdded(address indexed strategy, uint256 weight);
    event StrategyWeightUpdated(address indexed strategy, uint256 oldWeight, uint256 newWeight);
    event StrategyRemoved(address indexed strategy);
    event Rebalance(address indexed caller, uint256 totalAllocated, uint256 yieldHarvested);
    event YieldHarvested(address indexed strategy, uint256 amount);
    event FeesCollected(address indexed caller, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error ZeroAddress();
    error NotOperator(address caller);
    error DepositTooSmall(uint256 amount, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 requested);
    error InsufficientLiquidity(uint256 needed, uint256 available);
    error NothingToClaim();
    error StrategyAlreadyExists(address strategy);
    error StrategyNotFound(address strategy);
    error InvalidWeight(uint256 weight);
    error TotalWeightExceeded(uint256 currentTotal, uint256 additional, uint256 maxWeight);
    error InvalidAmount(uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator(msg.sender);
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount(0);
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);

        _updateYield(msg.sender);

        balances[msg.sender] += amount;
        totalDeposits += amount;

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount(0);
        uint256 userBalance = balances[msg.sender];
        if (userBalance < amount) revert InsufficientBalance(userBalance, amount);

        _updateYield(msg.sender);

        balances[msg.sender] = userBalance - amount;
        totalDeposits -= amount;

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;
        accumulatedFees += fee;

        _ensureLiquidity(amount);
        stablecoin.safeTransfer(msg.sender, payout);

        emit Withdraw(msg.sender, amount, fee);
    }

    function claimYield() external nonReentrant {
        _updateYield(msg.sender);
        uint256 claimed = pendingYield[msg.sender];
        if (claimed == 0) revert NothingToClaim();

        pendingYield[msg.sender] = 0;
        yieldPool -= claimed;

        _ensureLiquidity(claimed);
        stablecoin.safeTransfer(msg.sender, claimed);

        emit YieldClaimed(msg.sender, claimed);
    }

    function addStrategy(address strategy, uint256 weight) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (strategies[strategy].isActive) revert StrategyAlreadyExists(strategy);
        if (weight == 0) revert InvalidWeight(weight);
        if (totalWeight + weight > MAX_TOTAL_WEIGHT) {
            revert TotalWeightExceeded(totalWeight, weight, MAX_TOTAL_WEIGHT);
        }

        strategies[strategy] = StrategyConfig({isActive: true, weight: weight});
        strategyList.push(strategy);
        totalWeight += weight;

        emit StrategyAdded(strategy, weight);
    }

    function updateStrategyWeight(address strategy, uint256 newWeight) external onlyOperator {
        if (!strategies[strategy].isActive) revert StrategyNotFound(strategy);
        if (newWeight == 0) revert InvalidWeight(newWeight);

        uint256 oldWeight = strategies[strategy].weight;
        uint256 newTotal = totalWeight - oldWeight + newWeight;
        if (newTotal > MAX_TOTAL_WEIGHT) {
            revert TotalWeightExceeded(newTotal, newWeight, MAX_TOTAL_WEIGHT);
        }

        strategies[strategy].weight = newWeight;
        totalWeight = newTotal;

        emit StrategyWeightUpdated(strategy, oldWeight, newWeight);
    }

    function removeStrategy(address strategy) external onlyOperator nonReentrant {
        if (!strategies[strategy].isActive) revert StrategyNotFound(strategy);

        uint256 remaining = strategyDeposits[strategy];

        // Effects: update all state before external interactions
        strategyDeposits[strategy] = 0;
        totalWeight -= strategies[strategy].weight;
        delete strategies[strategy];

        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; i++) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[len - 1];
                strategyList.pop();
                break;
            }
        }

        // Interaction: withdraw remaining funds after state is cleared
        if (remaining > 0) {
            IYieldStrategy(strategy).withdraw(remaining);
        }

        emit StrategyRemoved(strategy);
    }

    function rebalance() external onlyOperator nonReentrant {
        if (totalWeight == 0) {
            emit Rebalance(msg.sender, 0, 0);
            return;
        }

        uint256 totalYieldHarvested = 0;

        // Phase 1: Harvest yield from all strategies
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strat = strategyList[i];
            uint256 yieldEarned = IYieldStrategy(strat).harvest();
            if (yieldEarned > 0) {
                totalYieldHarvested += yieldEarned;
                emit YieldHarvested(strat, yieldEarned);
            }
        }

        // Phase 2: Read actual values and correct bookkeeping for losses
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strat = strategyList[i];
            uint256 actualValue = IYieldStrategy(strat).totalValue();
            if (actualValue < strategyDeposits[strat]) {
                strategyDeposits[strat] = actualValue;
            }
        }

        if (totalYieldHarvested > 0) {
            _distributeYield(totalYieldHarvested);
        }

        uint256 totalAvailable = _availableForAllocation() + _totalStrategyValue();
        uint256 allocatable = totalAvailable > totalDeposits + yieldPool + accumulatedFees
            ? totalDeposits + yieldPool + accumulatedFees
            : totalAvailable;

        // Phase 3: Withdraw excess from over-allocated strategies (CEI)
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strat = strategyList[i];
            uint256 target = (allocatable * strategies[strat].weight) / totalWeight;
            uint256 current = strategyDeposits[strat];
            if (current > target) {
                uint256 excess = current - target;
                // Effect: update state before interaction
                strategyDeposits[strat] = target;
                // Interaction
                IYieldStrategy(strat).withdraw(excess);
            }
        }

        // Phase 4: Deposit into under-allocated strategies (CEI)
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strat = strategyList[i];
            uint256 target = (allocatable * strategies[strat].weight) / totalWeight;
            uint256 current = strategyDeposits[strat];
            if (current < target) {
                uint256 deficit = target - current;
                uint256 vaultBalance = stablecoin.balanceOf(address(this));
                uint256 available = _availableForAllocation();
                uint256 toDeposit = deficit;
                if (toDeposit > vaultBalance) toDeposit = vaultBalance;
                if (toDeposit > available) toDeposit = available;
                if (toDeposit > 0) {
                    // Effect: update state before interaction
                    strategyDeposits[strat] = current + toDeposit;
                    // Interaction
                    stablecoin.safeIncreaseAllowance(strat, toDeposit);
                    IYieldStrategy(strat).deposit(toDeposit);
                }
            }
        }

        uint256 totalAllocated = 0;
        for (uint256 i = 0; i < strategyList.length; i++) {
            totalAllocated += strategyDeposits[strategyList[i]];
        }

        emit Rebalance(msg.sender, totalAllocated, totalYieldHarvested);
    }

    function collectFees() external onlyOperator nonReentrant {
        uint256 fees = accumulatedFees;
        if (fees == 0) revert NothingToClaim();
        accumulatedFees = 0;
        _ensureLiquidity(fees);
        stablecoin.safeTransfer(msg.sender, fees);
        emit FeesCollected(msg.sender, fees);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function totalAssets() external view returns (uint256) {
        return stablecoin.balanceOf(address(this)) + _totalStrategyValue();
    }

    function totalStrategyValue() external view returns (uint256) {
        return _totalStrategyValue();
    }

    function getUserYield(address user) external view returns (uint256) {
        uint256 userBalance = balances[user];
        if (userBalance == 0) return pendingYield[user];
        return pendingYield[user] + ((yieldPerShare - userYieldIndex[user]) * userBalance) / YIELD_SCALE;
    }

    function strategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function getStrategyList() external view returns (address[] memory) {
        return strategyList;
    }

    function availableForAllocation() external view returns (uint256) {
        return _availableForAllocation();
    }

    function _updateYield(address user) internal {
        uint256 userBalance = balances[user];
        if (userBalance > 0) {
            uint256 accrued = ((yieldPerShare - userYieldIndex[user]) * userBalance) / YIELD_SCALE;
            if (accrued > 0) {
                pendingYield[user] += accrued;
            }
        }
        userYieldIndex[user] = yieldPerShare;
    }

    function _distributeYield(uint256 yieldAmount) internal {
        if (yieldAmount == 0) return;
        if (totalDeposits > 0) {
            yieldPool += yieldAmount;
            yieldPerShare += (yieldAmount * YIELD_SCALE) / totalDeposits;
        } else {
            accumulatedFees += yieldAmount;
        }
    }

    function _ensureLiquidity(uint256 amount) internal {
        uint256 vaultBalance = stablecoin.balanceOf(address(this));
        if (vaultBalance >= amount) return;

        uint256 needed = amount - vaultBalance;
        for (uint256 i = 0; i < strategyList.length && needed > 0; i++) {
            address strat = strategyList[i];
            uint256 stratDeposit = strategyDeposits[strat];
            if (stratDeposit == 0) continue;

            uint256 toWithdraw = stratDeposit < needed ? stratDeposit : needed;
            // Effect: update state before interaction
            strategyDeposits[strat] -= toWithdraw;
            // Interaction
            IYieldStrategy(strat).withdraw(toWithdraw);
            needed -= toWithdraw;
        }

        // Re-check actual balance after all external calls
        vaultBalance = stablecoin.balanceOf(address(this));
        if (vaultBalance < amount) {
            revert InsufficientLiquidity(amount, vaultBalance);
        }
    }

    function _availableForAllocation() internal view returns (uint256) {
        uint256 balance = stablecoin.balanceOf(address(this));
        uint256 reserved = yieldPool + accumulatedFees;
        if (balance <= reserved) return 0;
        return balance - reserved;
    }

    function _totalStrategyValue() internal view returns (uint256 total) {
        for (uint256 i = 0; i < strategyList.length; i++) {
            total += IYieldStrategy(strategyList[i]).totalValue();
        }
    }
}
