// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function totalAssets() external view returns (uint256);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool success = token.approve(spender, amount);
        require(success, "SafeERC20: approve failed");
    }
}

contract YieldAggregatorVault {
    using SafeERC20 for IERC20;

    /* ========== ERRORS ========== */
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error InsufficientAvailablePrincipal();
    error NotOwner();
    error ReentrantCall();
    error StrategyNotActive();
    error StrategyAlreadyActive();
    error MaxStrategiesReached();
    error FeeTooHigh();
    error TransferFromFailed();

    /* ========== EVENTS ========== */
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event Harvest(uint256 profit, uint256 fee, uint256 netProfit);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event AllocationAdjusted(address indexed strategy, uint256 newAllocated);
    event StrategyLoss(address indexed strategy, uint256 loss);
    event FeePercentageUpdated(uint256 newFeePercentage);
    event FeeRecipientUpdated(address newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /* ========== CONSTANTS ========== */
    uint256 public constant MAX_STRATEGIES = 10;
    uint256 public constant MAX_FEE = 1500; // 15% in basis points
    uint256 private constant ACC_REWARD_PRECISION = 1e12;

    /* ========== STATE ========== */
    IERC20 public immutable token;
    address public owner;
    address public feeRecipient;
    uint256 public feePercentage; // basis points

    uint256 public totalDeposited; // principal deposited by users
    uint256 public rewardPoolBalance; // unclaimed net rewards held in vault
    uint256 public accRewardPerShare; // scaled by ACC_REWARD_PRECISION

    address[] public activeStrategies;
    mapping(address => bool) public isActiveStrategy;
    mapping(address => uint256) public strategyAllocated;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    mapping(address => UserInfo) public userInfo;

    uint256 private _status = 1;

    /* ========== MODIFIERS ========== */
    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /* ========== CONSTRUCTOR ========== */
    constructor(address _token, address _feeRecipient, uint256 _feePercentage) {
        if (_token == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feePercentage > MAX_FEE) revert FeeTooHigh();
        token = IERC20(_token);
        feeRecipient = _feeRecipient;
        feePercentage = _feePercentage;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /* ========== VIEWS ========== */
    function strategyCount() external view returns (uint256) {
        return activeStrategies.length;
    }

    function getAvailablePrincipal() public view returns (uint256) {
        return token.balanceOf(address(this)) - rewardPoolBalance;
    }

    function pendingReward(address user) external view returns (uint256) {
        UserInfo storage u = userInfo[user];
        return (u.amount * accRewardPerShare) / ACC_REWARD_PRECISION - u.rewardDebt;
    }

    function totalAssets() external view returns (uint256) {
        uint256 total = token.balanceOf(address(this));
        uint256 len = activeStrategies.length;
        for (uint256 i = 0; i < len; i++) {
            total += IStrategy(activeStrategies[i]).totalAssets();
        }
        return total;
    }

    /* ========== USER FUNCTIONS ========== */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateReward(msg.sender);

        UserInfo storage u = userInfo[msg.sender];
        u.amount += amount;
        totalDeposited += amount;
        u.rewardDebt = (u.amount * accRewardPerShare) / ACC_REWARD_PRECISION;

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFromFailed();

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserInfo storage u = userInfo[msg.sender];
        if (u.amount < amount) revert InsufficientBalance();

        _updateReward(msg.sender);

        u.amount -= amount;
        totalDeposited -= amount;
        u.rewardDebt = (u.amount * accRewardPerShare) / ACC_REWARD_PRECISION;

        uint256 vaultBalance = token.balanceOf(address(this));
        if (vaultBalance < amount) {
            _withdrawFromStrategies(amount - vaultBalance);
        }
        token.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
    }

    /* ========== HARVEST ========== */
    function harvest() external nonReentrant {
        _harvest();
    }

    function _harvest() internal {
        uint256 strategyProfit;
        uint256 len = activeStrategies.length;
        for (uint256 i = 0; i < len; i++) {
            address strategy = activeStrategies[i];
            uint256 allocated = strategyAllocated[strategy];
            uint256 total = IStrategy(strategy).totalAssets();

            if (total > allocated) {
                uint256 profit = total - allocated;
                // Update state before external call (checks-effects-interactions)
                strategyAllocated[strategy] = allocated;
                uint256 withdrawn = IStrategy(strategy).withdraw(profit);
                // Adjust if actual withdrawn differs from requested
                strategyAllocated[strategy] = allocated - (withdrawn > profit ? profit : withdrawn) + (withdrawn > profit ? withdrawn - profit : 0);
                // Simplify: after withdrawing profit, strategy holds (total - withdrawn).
                // We track allocated as the principal, so it stays at allocated if withdrawn == profit.
                // If withdrawn < profit (partial), strategy still holds (total - withdrawn) > allocated.
                // Recalculate based on actual:
                strategyAllocated[strategy] = total - withdrawn;
                strategyProfit += withdrawn;
            } else if (total < allocated) {
                uint256 loss = allocated - total;
                strategyAllocated[strategy] = total;
                emit StrategyLoss(strategy, loss);
            }
        }

        if (strategyProfit > 0) {
            _distributeProfit(strategyProfit);
        }
    }

    function _distributeProfit(uint256 profit) internal {
        uint256 fee = (profit * feePercentage) / 10000;
        uint256 netProfit = profit - fee;

        if (totalDeposited > 0 && netProfit > 0) {
            rewardPoolBalance += netProfit;
            accRewardPerShare += (netProfit * ACC_REWARD_PRECISION) / totalDeposited;
        }

        if (fee > 0) {
            token.safeTransfer(feeRecipient, fee);
        }

        emit Harvest(profit, fee, netProfit);
    }

    function _updateReward(address user) internal {
        UserInfo storage u = userInfo[user];
        uint256 pending = (u.amount * accRewardPerShare) / ACC_REWARD_PRECISION - u.rewardDebt;
        u.rewardDebt = (u.amount * accRewardPerShare) / ACC_REWARD_PRECISION;

        if (pending > 0) {
            rewardPoolBalance -= pending;
            uint256 vaultBalance = token.balanceOf(address(this));
            if (vaultBalance < pending) {
                _withdrawFromStrategies(pending - vaultBalance);
            }
            token.safeTransfer(user, pending);
            emit Claim(user, pending);
        }
    }

    function _withdrawFromStrategies(uint256 amountNeeded) internal {
        uint256 remaining = amountNeeded;
        uint256 len = activeStrategies.length;
        for (uint256 i = 0; i < len; i++) {
            if (remaining < 1) break;
            address strategy = activeStrategies[i];
            uint256 allocated = strategyAllocated[strategy];
            if (allocated < 1) continue;

            uint256 toWithdraw = allocated < remaining ? allocated : remaining;
            // Update state before external call (checks-effects-interactions)
            strategyAllocated[strategy] -= toWithdraw;
            uint256 withdrawn = IStrategy(strategy).withdraw(toWithdraw);
            // Adjust for any shortfall (loss)
            strategyAllocated[strategy] += (toWithdraw - withdrawn);
            remaining -= withdrawn;
        }
        if (remaining > 0) revert InsufficientLiquidity();
    }

    /* ========== OWNER: STRATEGY MANAGEMENT ========== */
    function addStrategy(address strategy) external onlyOwner nonReentrant {
        if (strategy == address(0)) revert ZeroAddress();
        if (isActiveStrategy[strategy]) revert StrategyAlreadyActive();
        if (activeStrategies.length >= MAX_STRATEGIES) revert MaxStrategiesReached();

        isActiveStrategy[strategy] = true;
        activeStrategies.push(strategy);
        token.safeApprove(strategy, type(uint256).max);

        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external onlyOwner nonReentrant {
        if (!isActiveStrategy[strategy]) revert StrategyNotActive();

        uint256 allocated = strategyAllocated[strategy];

        // Update all state before external calls (checks-effects-interactions)
        strategyAllocated[strategy] = 0;
        isActiveStrategy[strategy] = false;

        uint256 len = activeStrategies.length;
        for (uint256 i = 0; i < len; i++) {
            if (activeStrategies[i] == strategy) {
                activeStrategies[i] = activeStrategies[len - 1];
                activeStrategies.pop();
                break;
            }
        }

        uint256 withdrawn = 0;
        if (allocated > 0) {
            withdrawn = IStrategy(strategy).withdraw(allocated);
            if (withdrawn > allocated) {
                _distributeProfit(withdrawn - allocated);
            }
        }

        token.safeApprove(strategy, 0);

        emit StrategyRemoved(strategy);
    }

    function adjustAllocation(address strategy, uint256 newAllocated) external onlyOwner nonReentrant {
        if (!isActiveStrategy[strategy]) revert StrategyNotActive();
        uint256 current = strategyAllocated[strategy];

        if (newAllocated > current) {
            uint256 diff = newAllocated - current;
            if (getAvailablePrincipal() < diff) revert InsufficientAvailablePrincipal();
            // Update state before external call
            strategyAllocated[strategy] = newAllocated;
            IStrategy(strategy).deposit(diff);
        } else if (newAllocated < current) {
            uint256 diff = current - newAllocated;
            // Update state before external call
            strategyAllocated[strategy] = newAllocated;
            uint256 withdrawn = IStrategy(strategy).withdraw(diff);
            // Adjust for actual withdrawn amount
            strategyAllocated[strategy] = current - withdrawn;
            if (withdrawn > diff) {
                _distributeProfit(withdrawn - diff);
            }
        }

        emit AllocationAdjusted(strategy, strategyAllocated[strategy]);
    }

    /* ========== OWNER: CONFIG ========== */
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        if (newFeePercentage > MAX_FEE) revert FeeTooHigh();
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(newFeePercentage);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }
}
