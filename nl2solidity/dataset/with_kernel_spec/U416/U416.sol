// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract GovernancePowerVault {
    // ---------------------------------------------------------------------
    //  Errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error TokenNotApproved();
    error TokenAlreadyApproved();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidMultiplier();
    error DepositTooSmall(uint256 provided, uint256 minimum);
    error InsufficientBalance(uint256 requested, uint256 available);
    error NoPendingWithdrawal();
    error WithdrawalNotReady(uint256 availableAt);
    error HasPendingWithdrawal();
    error NoStakedPower();
    error NothingToClaim();
    error TransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    //  Events
    // ---------------------------------------------------------------------
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TokenApproved(address indexed token, uint256 multiplier);
    event TokenMultiplierUpdated(address indexed token, uint256 oldMultiplier, uint256 newMultiplier);
    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 weightedAmount);
    event WithdrawalRequested(address indexed user, address indexed token, uint256 amount, uint256 availableAt);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event WithdrawalCancelled(address indexed user, address indexed token, uint256 amount);
    event GovernancePowerDistributed(address indexed operator, uint256 totalAmount);
    event GovernancePowerClaimed(address indexed user, uint256 amount);

    // ---------------------------------------------------------------------
    //  Constants
    // ---------------------------------------------------------------------
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant WITHDRAWAL_DELAY = 24 hours;
    uint256 private constant PRECISION = 1e18;

    // ---------------------------------------------------------------------
    //  Configuration
    // ---------------------------------------------------------------------
    address public operator;
    mapping(address => bool) public isApprovedToken;
    mapping(address => uint256) public tokenMultiplier; // scaled by PRECISION (1e18 = 1x)

    // ---------------------------------------------------------------------
    //  Per-user deposit state
    // ---------------------------------------------------------------------
    mapping(address => mapping(address => uint256)) public userBalances;             // user => token => amount
    mapping(address => mapping(address => uint256)) public userWeightedTokenDeposits; // user => token => weighted amount
    mapping(address => uint256) public userWeightedDeposits;                         // user => total weighted amount
    uint256 public totalWeightedDeposits;

    // ---------------------------------------------------------------------
    //  Governance power accounting (MasterChef-style)
    // ---------------------------------------------------------------------
    uint256 public accPowerPerWeight;                 // accumulated governance power per unit of weighted deposit
    mapping(address => uint256) public userPowerDebt; // snapshot used to compute pending rewards
    mapping(address => uint256) public accumulatedGovernancePower; // total power credited to a user
    uint256 public totalDistributedPower;

    // ---------------------------------------------------------------------
    //  Pending withdrawals (with 24h timelock)
    // ---------------------------------------------------------------------
    struct PendingWithdrawal {
        uint256 amount;
        uint256 requestTime;
        uint256 weightedAmount;
    }
    mapping(address => mapping(address => PendingWithdrawal)) public pendingWithdrawals;

    // ---------------------------------------------------------------------
    //  Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    //  Access control
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyApprovedToken(address token) {
        if (!isApprovedToken[token]) revert TokenNotApproved();
        _;
    }

    // ---------------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    //  Operator administration
    // ---------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function approveToken(address token, uint256 multiplier) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isApprovedToken[token]) revert TokenAlreadyApproved();
        if (multiplier == 0) revert InvalidMultiplier();
        isApprovedToken[token] = true;
        tokenMultiplier[token] = multiplier;
        emit TokenApproved(token, multiplier);
    }

    function updateTokenMultiplier(address token, uint256 newMultiplier) external onlyOperator onlyApprovedToken(token) {
        if (newMultiplier == 0) revert InvalidMultiplier();
        uint256 old = tokenMultiplier[token];
        tokenMultiplier[token] = newMultiplier;
        emit TokenMultiplierUpdated(token, old, newMultiplier);
    }

    function distributeGovernancePower(uint256 totalAmount) external onlyOperator nonReentrant {
        if (totalAmount == 0) revert ZeroAmount();
        if (totalWeightedDeposits == 0) revert NoStakedPower();
        // Increase the per-weight accumulator; users claim lazily.
        accPowerPerWeight += (totalAmount * PRECISION) / totalWeightedDeposits;
        totalDistributedPower += totalAmount;
        emit GovernancePowerDistributed(msg.sender, totalAmount);
    }

    // ---------------------------------------------------------------------
    //  User actions
    // ---------------------------------------------------------------------
    function deposit(address token, uint256 amount) external nonReentrant onlyApprovedToken(token) {
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);

        uint256 multiplier = tokenMultiplier[token];
        uint256 weightedAmount = (amount * multiplier) / PRECISION;

        // Settle pending governance power before mutating the user's weight.
        _claimPending(msg.sender);

        userBalances[msg.sender][token] += amount;
        userWeightedTokenDeposits[msg.sender][token] += weightedAmount;
        userWeightedDeposits[msg.sender] += weightedAmount;
        totalWeightedDeposits += weightedAmount;

        userPowerDebt[msg.sender] = (userWeightedDeposits[msg.sender] * accPowerPerWeight) / PRECISION;

        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount, weightedAmount);
    }

    function requestWithdrawal(address token, uint256 amount) external nonReentrant onlyApprovedToken(token) {
        if (amount == 0) revert ZeroAmount();
        if (pendingWithdrawals[msg.sender][token].amount > 0) revert HasPendingWithdrawal();

        uint256 balance = userBalances[msg.sender][token];
        if (balance < amount) revert InsufficientBalance(amount, balance);

        // Proportional weighted amount being removed.
        uint256 totalWeighted = userWeightedTokenDeposits[msg.sender][token];
        uint256 weightedAmount = (totalWeighted * amount) / balance;

        // Settle pending governance power before reducing the user's weight.
        _claimPending(msg.sender);

        // Effects: remove stake immediately so it cannot be double-spent.
        userBalances[msg.sender][token] = balance - amount;
        userWeightedTokenDeposits[msg.sender][token] = totalWeighted - weightedAmount;
        userWeightedDeposits[msg.sender] -= weightedAmount;
        totalWeightedDeposits -= weightedAmount;

        userPowerDebt[msg.sender] = (userWeightedDeposits[msg.sender] * accPowerPerWeight) / PRECISION;

        pendingWithdrawals[msg.sender][token] = PendingWithdrawal({
            amount: amount,
            requestTime: block.timestamp,
            weightedAmount: weightedAmount
        });

        emit WithdrawalRequested(msg.sender, token, amount, block.timestamp + WITHDRAWAL_DELAY);
    }

    function executeWithdrawal(address token) external nonReentrant {
        PendingWithdrawal memory pending = pendingWithdrawals[msg.sender][token];
        if (pending.amount == 0) revert NoPendingWithdrawal();
        uint256 availableAt = pending.requestTime + WITHDRAWAL_DELAY;
        if (block.timestamp < availableAt) revert WithdrawalNotReady(availableAt);

        // Effects
        delete pendingWithdrawals[msg.sender][token];

        // Interactions
        _safeTransfer(token, msg.sender, pending.amount);

        emit Withdrawn(msg.sender, token, pending.amount);
    }

    function cancelWithdrawal(address token) external nonReentrant onlyApprovedToken(token) {
        PendingWithdrawal memory pending = pendingWithdrawals[msg.sender][token];
        if (pending.amount == 0) revert NoPendingWithdrawal();

        // Settle pending governance power before restoring the user's weight.
        _claimPending(msg.sender);

        delete pendingWithdrawals[msg.sender][token];
        userBalances[msg.sender][token] += pending.amount;
        userWeightedTokenDeposits[msg.sender][token] += pending.weightedAmount;
        userWeightedDeposits[msg.sender] += pending.weightedAmount;
        totalWeightedDeposits += pending.weightedAmount;

        userPowerDebt[msg.sender] = (userWeightedDeposits[msg.sender] * accPowerPerWeight) / PRECISION;

        emit WithdrawalCancelled(msg.sender, token, pending.amount);
    }

    function claimGovernancePower() external nonReentrant {
        uint256 owed = _claimPending(msg.sender);
        if (owed == 0) revert NothingToClaim();
        userPowerDebt[msg.sender] = (userWeightedDeposits[msg.sender] * accPowerPerWeight) / PRECISION;
        emit GovernancePowerClaimed(msg.sender, owed);
    }

    // ---------------------------------------------------------------------
    //  Internal helpers
    // ---------------------------------------------------------------------
    function _claimPending(address user) internal returns (uint256 owed) {
        uint256 accumulated = (userWeightedDeposits[user] * accPowerPerWeight) / PRECISION;
        uint256 debt = userPowerDebt[user];
        // accumulated is always >= debt because debt is snapshotted from accumulated
        // after each interaction that changes the user's weight.
        owed = accumulated - debt;
        if (owed > 0) {
            accumulatedGovernancePower[user] += owed;
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    //  Views
    // ---------------------------------------------------------------------
    function pendingGovernancePower(address user) external view returns (uint256) {
        return (userWeightedDeposits[user] * accPowerPerWeight) / PRECISION - userPowerDebt[user];
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }

    function getUserWeightedDeposit(address user) external view returns (uint256) {
        return userWeightedDeposits[user];
    }

    function getPendingWithdrawal(address user, address token)
        external
        view
        returns (uint256 amount, uint256 requestTime, uint256 weightedAmount)
    {
        PendingWithdrawal memory p = pendingWithdrawals[user][token];
        return (p.amount, p.requestTime, p.weightedAmount);
    }

    function isWithdrawalReady(address user, address token) external view returns (bool) {
        uint256 t = pendingWithdrawals[user][token].requestTime;
        if (t == 0) return false;
        return block.timestamp >= t + WITHDRAWAL_DELAY;
    }

    function withdrawalTimeRemaining(address user, address token) external view returns (uint256) {
        uint256 t = pendingWithdrawals[user][token].requestTime;
        if (t == 0) return 0;
        uint256 ready = t + WITHDRAWAL_DELAY;
        if (block.timestamp >= ready) return 0;
        return ready - block.timestamp;
    }

    function totalDepositedOf(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
