// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategyAdapter {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

contract BitcoinStrategyManager {
    error ZeroAddress();
    error Unauthorized();
    error StrategyNotActive();
    error StrategyPaused();
    error AmountZero();
    error CapExceeded();
    error InsufficientBalance();
    error NoRewardsToClaim();
    error InvalidParameter();
    error TransferFailed();
    error Reentrancy();

    event Deposit(address indexed user, uint256 indexed strategyId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed strategyId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed strategyId, uint256 reward, uint256 fee);
    event StrategyAdded(uint256 indexed strategyId, address indexed adapter, address indexed token);
    event StrategyUpdated(uint256 indexed strategyId, bool active, bool paused, uint256 cap);
    event Rebalanced(uint256 indexed fromStrategy, uint256 indexed toStrategy, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PerformanceFeeCollected(uint256 indexed strategyId, uint256 fee);
    event FeesWithdrawn(uint256 indexed strategyId, address indexed recipient, uint256 amount);

    struct Strategy {
        address adapter;
        address token;
        bool active;
        bool paused;
        uint256 cap;
        uint256 totalDeposited;
        uint256 totalAllocated;
        uint256 accRewardPerShare;
        uint256 lastRewardBlock;
        uint256 pendingFees;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    uint256 public constant MAX_CAP = 1000 * 1e18;
    uint256 public constant PERFORMANCE_FEE = 50; // 0.5% in basis points
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant ACC_REWARD_PRECISION = 1e18;

    address public owner;
    address public operator;
    address public feeRecipient;

    Strategy[] public strategies;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier strategyExists(uint256 strategyId) {
        if (strategyId >= strategies.length) revert InvalidParameter();
        _;
    }

    modifier strategyActive(uint256 strategyId) {
        if (strategyId >= strategies.length) revert InvalidParameter();
        Strategy storage s = strategies[strategyId];
        if (!s.active) revert StrategyNotActive();
        if (s.paused) revert StrategyPaused();
        _;
    }

    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    function strategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function getStrategy(uint256 strategyId) external view strategyExists(strategyId) returns (Strategy memory) {
        return strategies[strategyId];
    }

    function getUserInfo(uint256 strategyId, address user) external view strategyExists(strategyId) returns (UserInfo memory) {
        return userInfo[strategyId][user];
    }

    function pendingRewards(uint256 strategyId, address user) external view strategyExists(strategyId) returns (uint256) {
        Strategy storage s = strategies[strategyId];
        UserInfo storage info = userInfo[strategyId][user];
        uint256 accPerShare = s.accRewardPerShare;
        if (block.number > s.lastRewardBlock && s.totalDeposited != 0) {
            uint256 totalAssets = IStrategyAdapter(s.adapter).totalAssets();
            uint256 harvested = totalAssets > s.totalAllocated ? totalAssets - s.totalAllocated : 0;
            if (harvested > 0) {
                uint256 netReward = harvested - (harvested * PERFORMANCE_FEE / FEE_DENOMINATOR);
                accPerShare += (netReward * ACC_REWARD_PRECISION) / s.totalDeposited;
            }
        }
        uint256 pending = (info.amount * accPerShare) / ACC_REWARD_PRECISION;
        return pending + info.pendingRewards - info.rewardDebt;
    }

    function _updateRewards(uint256 strategyId) internal {
        Strategy storage s = strategies[strategyId];
        if (block.number <= s.lastRewardBlock) return;
        if (s.totalDeposited == 0) {
            s.lastRewardBlock = block.number;
            return;
        }
        uint256 totalAssets = IStrategyAdapter(s.adapter).totalAssets();
        uint256 harvested = totalAssets > s.totalAllocated ? totalAssets - s.totalAllocated : 0;
        if (harvested == 0) {
            s.lastRewardBlock = block.number;
            return;
        }
        uint256 fee = (harvested * PERFORMANCE_FEE) / FEE_DENOMINATOR;
        uint256 netReward = harvested - fee;
        s.accRewardPerShare += (netReward * ACC_REWARD_PRECISION) / s.totalDeposited;
        s.pendingFees += fee;
        s.totalAllocated = totalAssets - fee;
        s.lastRewardBlock = block.number;
        emit PerformanceFeeCollected(strategyId, fee);
    }

    function deposit(uint256 strategyId, uint256 amount) external nonReentrant strategyActive(strategyId) {
        if (amount == 0) revert AmountZero();
        Strategy storage s = strategies[strategyId];
        if (s.totalDeposited + amount > s.cap) revert CapExceeded();

        _updateRewards(strategyId);

        UserInfo storage info = userInfo[strategyId][msg.sender];

        // Effects: credit pending rewards and update balances before interactions
        uint256 pending = (info.amount * s.accRewardPerShare) / ACC_REWARD_PRECISION + info.pendingRewards - info.rewardDebt;
        info.pendingRewards = pending;

        info.amount += amount;
        s.totalDeposited += amount;
        s.totalAllocated += amount;
        info.rewardDebt = (info.amount * s.accRewardPerShare) / ACC_REWARD_PRECISION;

        // Interactions
        if (!IERC20(s.token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        if (!IERC20(s.token).approve(s.adapter, amount)) revert TransferFailed();
        IStrategyAdapter(s.adapter).deposit(amount);

        emit Deposit(msg.sender, strategyId, amount);
    }

    function withdraw(uint256 strategyId, uint256 amount) external nonReentrant strategyActive(strategyId) {
        if (amount == 0) revert AmountZero();
        Strategy storage s = strategies[strategyId];
        UserInfo storage info = userInfo[strategyId][msg.sender];
        if (info.amount < amount) revert InsufficientBalance();

        _updateRewards(strategyId);

        // Effects: credit pending rewards and update balances before interactions
        uint256 pending = (info.amount * s.accRewardPerShare) / ACC_REWARD_PRECISION + info.pendingRewards - info.rewardDebt;
        info.pendingRewards = pending;

        info.amount -= amount;
        s.totalDeposited -= amount;
        s.totalAllocated = s.totalAllocated > amount ? s.totalAllocated - amount : 0;
        info.rewardDebt = (info.amount * s.accRewardPerShare) / ACC_REWARD_PRECISION;

        // Interactions
        IStrategyAdapter(s.adapter).withdraw(amount);
        if (!IERC20(s.token).transfer(msg.sender, amount)) revert TransferFailed();

        emit Withdraw(msg.sender, strategyId, amount);
    }

    function claimRewards(uint256 strategyId) external nonReentrant strategyActive(strategyId) {
        Strategy storage s = strategies[strategyId];
        UserInfo storage info = userInfo[strategyId][msg.sender];

        _updateRewards(strategyId);

        uint256 pending = (info.amount * s.accRewardPerShare) / ACC_REWARD_PRECISION + info.pendingRewards - info.rewardDebt;
        if (pending == 0) revert NoRewardsToClaim();

        // Effects
        info.pendingRewards = 0;
        info.rewardDebt = (info.amount * s.accRewardPerShare) / ACC_REWARD_PRECISION;

        // Interactions
        if (!IERC20(s.token).transfer(msg.sender, pending)) revert TransferFailed();

        emit RewardClaimed(msg.sender, strategyId, pending, 0);
    }

    function addStrategy(address adapter, address token) external onlyOperator {
        if (adapter == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();

        strategies.push(Strategy({
            adapter: adapter,
            token: token,
            active: true,
            paused: false,
            cap: MAX_CAP,
            totalDeposited: 0,
            totalAllocated: 0,
            accRewardPerShare: 0,
            lastRewardBlock: block.number,
            pendingFees: 0
        }));

        emit StrategyAdded(strategies.length - 1, adapter, token);
    }

    function adjustStrategy(uint256 strategyId, bool active, bool paused, uint256 cap) external onlyOperator strategyExists(strategyId) {
        if (cap > MAX_CAP) revert InvalidParameter();
        Strategy storage s = strategies[strategyId];
        s.active = active;
        s.paused = paused;
        s.cap = cap;
        emit StrategyUpdated(strategyId, active, paused, cap);
    }

    function rebalance(uint256 fromStrategy, uint256 toStrategy, uint256 amount) external nonReentrant onlyOperator {
        if (amount == 0) revert AmountZero();
        if (fromStrategy >= strategies.length || toStrategy >= strategies.length) revert InvalidParameter();
        Strategy storage from = strategies[fromStrategy];
        Strategy storage to = strategies[toStrategy];
        if (!from.active || !to.active) revert StrategyNotActive();
        if (from.totalAllocated < amount) revert InsufficientBalance();
        if (to.totalDeposited + to.totalAllocated + amount > to.cap) revert CapExceeded();

        // Effects: update allocations before interactions
        from.totalAllocated -= amount;
        to.totalAllocated += amount;

        // Interactions
        IStrategyAdapter(from.adapter).withdraw(amount);
        if (!IERC20(from.token).approve(to.adapter, amount)) revert TransferFailed();
        IStrategyAdapter(to.adapter).deposit(amount);

        emit Rebalanced(fromStrategy, toStrategy, amount);
    }

    function collectFees(uint256 strategyId) external nonReentrant onlyOperator strategyExists(strategyId) {
        Strategy storage s = strategies[strategyId];
        uint256 fees = s.pendingFees;
        if (fees == 0) revert NoRewardsToClaim();
        // Effects
        s.pendingFees = 0;
        // Interactions
        if (!IERC20(s.token).transfer(feeRecipient, fees)) revert TransferFailed();
        emit FeesWithdrawn(strategyId, feeRecipient, fees);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
