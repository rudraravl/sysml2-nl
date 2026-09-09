// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawAll() external returns (uint256);
    function balanceOf() external view returns (uint256);
}

contract YieldAggregator {
    uint256 public constant MAX_STRATEGIES = 10;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant FEE_TIME_WINDOW = 72 hours;

    IERC20 public immutable stablecoin;
    address public owner;
    address public operator;

    uint256 public totalShares;
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public lastDepositTime;

    address[] public strategies;
    mapping(address => uint256) public allocation; // basis points per strategy
    mapping(address => bool) public isActiveStrategy;
    uint256 public totalAllocation; // sum of all active allocation bps

    uint256 private _locked = 1;

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares, uint256 fee);
    event Redeem(address indexed user, uint256 shares, uint256 amount, uint256 fee);
    event StrategyAdded(address indexed strategy, uint256 allocation);
    event StrategyRemoved(address indexed strategy);
    event AllocationUpdated(address indexed strategy, uint256 oldAllocation, uint256 newAllocation);
    event OperatorChanged(address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Rebalanced(uint256 totalDeployed);

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InsufficientShares();
    error MaxStrategiesReached();
    error StrategyNotActive();
    error StrategyAlreadyActive();
    error InvalidAllocation();
    error InsufficientLiquidity();
    error InvalidAmount();
    error TransferFailed();
    error ReentrantCall();
    error WithdrawAllFailed();

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
        emit OperatorChanged(newOperator);
    }

    function totalAssets() public view returns (uint256) {
        uint256 total = stablecoin.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            total += IStrategy(strategies[i]).balanceOf();
        }
        return total;
    }

    function sharePrice() external view returns (uint256) {
        return totalShares > 0 ? (totalAssets() * 1e18) / totalShares : 0;
    }

    function strategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function getStrategies() external view returns (address[] memory) {
        return strategies;
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        uint256 _totalAssets = totalAssets();
        uint256 sharesToMint;
        if (totalShares < 1) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / _totalAssets;
        }
        if (sharesToMint < 1) revert InvalidAmount();

        // Effects before interactions
        totalShares += sharesToMint;
        userShares[msg.sender] += sharesToMint;
        lastDepositTime[msg.sender] = block.timestamp;

        // Interactions
        if (!stablecoin.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        uint256 _totalAssets = totalAssets();
        if (_totalAssets < 1) revert InsufficientLiquidity();

        // Round up shares needed to ensure sufficient coverage
        uint256 sharesNeeded = (amount * totalShares + _totalAssets - 1) / _totalAssets;
        if (userShares[msg.sender] < sharesNeeded) revert InsufficientShares();

        (uint256 netAmount, uint256 fee) = _redeem(sharesNeeded);
        emit Withdraw(msg.sender, netAmount, sharesNeeded, fee);
    }

    function redeem(uint256 shareAmount) external nonReentrant {
        if (shareAmount == 0) revert InvalidAmount();
        if (userShares[msg.sender] < shareAmount) revert InsufficientShares();

        (uint256 netAmount, uint256 fee) = _redeem(shareAmount);
        emit Redeem(msg.sender, shareAmount, netAmount, fee);
    }

    function _redeem(uint256 shareAmount)
        internal
        returns (uint256 netAmount, uint256 fee)
    {
        uint256 _totalAssets = totalAssets();

        // Compute fee directly from raw values to avoid divide-before-multiply precision loss
        // fee = shareAmount * _totalAssets * WITHDRAWAL_FEE_BPS / (totalShares * BPS_DENOMINATOR)
        if (block.timestamp <= lastDepositTime[msg.sender] + FEE_TIME_WINDOW) {
            fee = (shareAmount * _totalAssets * WITHDRAWAL_FEE_BPS) / (totalShares * BPS_DENOMINATOR);
        }

        netAmount = (shareAmount * _totalAssets) / totalShares - fee;

        // Effects
        totalShares -= shareAmount;
        userShares[msg.sender] -= shareAmount;

        // Interactions
        _pullFunds(netAmount);
        if (!stablecoin.transfer(msg.sender, netAmount)) revert TransferFailed();
    }

    function _pullFunds(uint256 amount) internal {
        uint256 idle = stablecoin.balanceOf(address(this));
        if (idle >= amount) return;

        uint256 remaining = amount - idle;
        for (uint256 i = 0; i < strategies.length && remaining > 0; i++) {
            address strat = strategies[i];
            uint256 stratBal = IStrategy(strat).balanceOf();
            if (stratBal < 1) continue;
            uint256 toWithdraw = remaining < stratBal ? remaining : stratBal;
            IStrategy(strat).withdraw(toWithdraw);
            remaining -= toWithdraw;
        }

        if (stablecoin.balanceOf(address(this)) < amount) revert InsufficientLiquidity();
    }

    function addStrategy(address strategy, uint256 allocationBps) external onlyOperator nonReentrant {
        if (strategy == address(0)) revert ZeroAddress();
        if (isActiveStrategy[strategy]) revert StrategyAlreadyActive();
        if (strategies.length >= MAX_STRATEGIES) revert MaxStrategiesReached();
        if (allocationBps == 0) revert InvalidAllocation();
        if (totalAllocation + allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();

        strategies.push(strategy);
        isActiveStrategy[strategy] = true;
        allocation[strategy] = allocationBps;
        totalAllocation += allocationBps;

        emit StrategyAdded(strategy, allocationBps);
    }

    function removeStrategy(address strategy) external onlyOperator nonReentrant {
        if (!isActiveStrategy[strategy]) revert StrategyNotActive();

        // Effects before interactions
        totalAllocation -= allocation[strategy];
        allocation[strategy] = 0;
        isActiveStrategy[strategy] = false;

        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            if (strategies[i] == strategy) {
                strategies[i] = strategies[len - 1];
                strategies.pop();
                break;
            }
        }

        // Interactions: withdraw all funds and check return value
        uint256 bal = IStrategy(strategy).balanceOf();
        if (bal > 0) {
            uint256 withdrawn = IStrategy(strategy).withdrawAll();
            if (withdrawn < bal) revert WithdrawAllFailed();
        }

        emit StrategyRemoved(strategy);
    }

    function setAllocation(address strategy, uint256 newAllocation) external onlyOperator nonReentrant {
        if (!isActiveStrategy[strategy]) revert StrategyNotActive();

        uint256 oldAllocation = allocation[strategy];
        uint256 newTotal = totalAllocation - oldAllocation + newAllocation;
        if (newTotal > BPS_DENOMINATOR) revert InvalidAllocation();

        allocation[strategy] = newAllocation;
        totalAllocation = newTotal;

        emit AllocationUpdated(strategy, oldAllocation, newAllocation);
    }

    function rebalance() external onlyOperator nonReentrant {
        uint256 _totalAssets = totalAssets();
        uint256 idle = stablecoin.balanceOf(address(this));

        for (uint256 i = 0; i < strategies.length; i++) {
            address strat = strategies[i];
            uint256 targetAmount = (_totalAssets * allocation[strat]) / BPS_DENOMINATOR;
            uint256 currentAmount = IStrategy(strat).balanceOf();

            if (targetAmount > currentAmount) {
                uint256 toDeposit = targetAmount - currentAmount;
                if (toDeposit > idle) toDeposit = idle;
                if (toDeposit > 0) {
                    if (!stablecoin.transfer(strat, toDeposit)) revert TransferFailed();
                    IStrategy(strat).deposit(toDeposit);
                    idle -= toDeposit;
                }
            } else if (targetAmount < currentAmount) {
                uint256 toWithdraw = currentAmount - targetAmount;
                IStrategy(strat).withdraw(toWithdraw);
                idle += toWithdraw;
            }
        }

        emit Rebalanced(_totalAssets - idle);
    }

    function getUserInfo(address user) external view returns (uint256 shares, uint256 depositedAt, uint256 currentBalance) {
        shares = userShares[user];
        depositedAt = lastDepositTime[user];
        currentBalance = totalShares > 0 ? (shares * totalAssets()) / totalShares : 0;
    }
}
