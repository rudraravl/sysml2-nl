// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract YieldAggregatorVault {
    error NotOwner();
    error ZeroAddress();
    error TokenNotSupported(address token);
    error TokenAlreadySupported(address token);
    error TokenHasOutstandingBalances(address token);
    error Paused();
    error ZeroAmount();
    error InsufficientBalance(address token, address user, uint256 requested, uint256 available);
    error InsufficientAllowance(address token, address spender, uint256 requested, uint256 allowed);
    error NoRewardsToClaim(address token, address user);
    error TransferFailed(address token);
    error ReentrantCall();

    uint256 public constant MAX_PERFORMANCE_FEE = 1000;
    uint256 public constant WITHDRAWAL_FEE = 10;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant REWARD_PRECISION = 1e18;

    struct StrategyConfig {
        address externalVault;
        uint256 performanceFee;
    }

    address public owner;
    bool public paused;
    uint256 private _status;
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    mapping(address => bool) public supportedTokens;
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => uint256) public totalDeposits;
    mapping(address => StrategyConfig) public strategies;

    mapping(address => uint256) public rewardPerShare;
    mapping(address => mapping(address => uint256)) public userRewardDebt;
    mapping(address => mapping(address => uint256)) public pendingRewards;
    mapping(address => uint256) public totalPendingRewards;

    mapping(address => mapping(address => mapping(address => uint256))) public internalAllowances;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event RewardClaim(address indexed user, address indexed token, uint256 amount);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event StrategyUpdated(address indexed token, address externalVault, uint256 performanceFee);
    event Approval(address indexed token, address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed token, address indexed from, address indexed to, uint256 amount);
    event PauseStateChanged(bool paused);
    event YieldReported(address indexed token, uint256 totalYield, uint256 performanceFee);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!supportedTokens[token]) revert TokenNotSupported(token);
        _;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    constructor() {
        owner = msg.sender;
        _status = NOT_ENTERED;
    }

    function addSupportedToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (supportedTokens[token]) revert TokenAlreadySupported(token);
        supportedTokens[token] = true;
        emit TokenAdded(token);
    }

    function removeSupportedToken(address token) external onlyOwner onlySupportedToken(token) {
        if (totalDeposits[token] > 0 || totalPendingRewards[token] > 0) revert TokenHasOutstandingBalances(token);
        supportedTokens[token] = false;
        delete strategies[token];
        emit TokenRemoved(token);
    }

    function setStrategy(address token, address externalVault, uint256 performanceFee) external onlyOwner onlySupportedToken(token) {
        if (externalVault == address(0)) revert ZeroAddress();
        if (performanceFee > MAX_PERFORMANCE_FEE) {
            performanceFee = MAX_PERFORMANCE_FEE;
        }
        strategies[token] = StrategyConfig(externalVault, performanceFee);
        emit StrategyUpdated(token, externalVault, performanceFee);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseStateChanged(_paused);
    }

    function harvest(address token) public nonReentrant onlySupportedToken(token) {
        _harvest(token);
    }

    function _harvest(address token) internal {
        uint256 totalDep = totalDeposits[token];
        if (totalDep == 0) return;

        uint256 currentBalance = IERC20(token).balanceOf(address(this));
        uint256 pending = totalPendingRewards[token];

        if (currentBalance <= totalDep) return;
        uint256 excess = currentBalance - totalDep;
        if (excess <= pending) return;
        uint256 yieldAmount = excess - pending;

        StrategyConfig memory strat = strategies[token];
        uint256 feeAmount = (yieldAmount * strat.performanceFee) / BASIS_POINTS;
        uint256 distributable = yieldAmount - feeAmount;

        rewardPerShare[token] += (distributable * REWARD_PRECISION) / totalDep;
        pendingRewards[token][owner] += feeAmount;
        totalPendingRewards[token] += yieldAmount;

        emit YieldReported(token, yieldAmount, feeAmount);
    }

    function _updateReward(address token, address user) internal {
        uint256 shares = userDeposits[token][user];
        uint256 rps = rewardPerShare[token];
        if (shares > 0) {
            uint256 accumulated = (shares * rps) / REWARD_PRECISION;
            if (accumulated > userRewardDebt[token][user]) {
                pendingRewards[token][user] += accumulated - userRewardDebt[token][user];
            }
        }
        userRewardDebt[token][user] = (shares * rps) / REWARD_PRECISION;
    }

    function deposit(address token, uint256 amount) external nonReentrant whenNotPaused onlySupportedToken(token) {
        if (amount == 0) revert ZeroAmount();
        _harvest(token);
        _updateReward(token, msg.sender);

        userDeposits[token][msg.sender] += amount;
        totalDeposits[token] += amount;
        userRewardDebt[token][msg.sender] = (userDeposits[token][msg.sender] * rewardPerShare[token]) / REWARD_PRECISION;

        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed(token);

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused onlySupportedToken(token) {
        if (amount == 0) revert ZeroAmount();
        if (userDeposits[token][msg.sender] < amount) revert InsufficientBalance(token, msg.sender, amount, userDeposits[token][msg.sender]);

        _harvest(token);
        _updateReward(token, msg.sender);

        uint256 fee = (amount * WITHDRAWAL_FEE) / BASIS_POINTS;
        uint256 amountOut = amount - fee;

        userDeposits[token][msg.sender] -= amount;
        totalDeposits[token] -= amount;
        userRewardDebt[token][msg.sender] = (userDeposits[token][msg.sender] * rewardPerShare[token]) / REWARD_PRECISION;

        if (!IERC20(token).transfer(msg.sender, amountOut)) revert TransferFailed(token);

        emit Withdrawal(msg.sender, token, amountOut, fee);
    }

    function claimRewards(address token) external nonReentrant onlySupportedToken(token) {
        _harvest(token);
        _updateReward(token, msg.sender);

        uint256 reward = pendingRewards[token][msg.sender];
        if (reward == 0) revert NoRewardsToClaim(token, msg.sender);

        pendingRewards[token][msg.sender] = 0;
        totalPendingRewards[token] -= reward;

        if (!IERC20(token).transfer(msg.sender, reward)) revert TransferFailed(token);

        emit RewardClaim(msg.sender, token, reward);
    }

    function approve(address token, address spender, uint256 amount) external onlySupportedToken(token) returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        internalAllowances[token][msg.sender][spender] = amount;
        emit Approval(token, msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address token, address from, address to, uint256 amount) external nonReentrant whenNotPaused onlySupportedToken(token) returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 currentAllowance = internalAllowances[token][from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance(token, msg.sender, amount, currentAllowance);

        if (userDeposits[token][from] < amount) revert InsufficientBalance(token, from, amount, userDeposits[token][from]);

        _harvest(token);
        _updateReward(token, from);
        _updateReward(token, to);

        internalAllowances[token][from][msg.sender] = currentAllowance - amount;
        userDeposits[token][from] -= amount;
        userDeposits[token][to] += amount;

        userRewardDebt[token][from] = (userDeposits[token][from] * rewardPerShare[token]) / REWARD_PRECISION;
        userRewardDebt[token][to] = (userDeposits[token][to] * rewardPerShare[token]) / REWARD_PRECISION;

        emit Transfer(token, from, to, amount);

        return true;
    }
}
