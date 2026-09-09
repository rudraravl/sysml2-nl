// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title DebitCardEscrow
 * @notice Escrows stablecoin balances for a debit card spending platform.
 *         Users deposit stablecoins, withdraw available stablecoins, and
 *         initiate spending transactions to a merchant. A designated operator
 *         approves or rejects pending transactions, applying a 10 basis point
 *         fee on every approved spend. Each user is subject to a 1,000
 *         stablecoin daily spending limit, while the operator configures a
 *         global daily spending limit.
 */
contract DebitCardEscrow {
    // -----------------------------------------------------------------------
    //                            Custom Errors
    // -----------------------------------------------------------------------
    error OnlyOwner();
    error OnlyOperator();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error ExceedsUserDailyLimit();
    error ExceedsGlobalDailyLimit();
    error TransactionNotFound();
    error TransactionNotPending();
    error NotTransactionInitiator();
    error TransferFailed();

    // -----------------------------------------------------------------------
    //                              Constants
    // -----------------------------------------------------------------------
    uint256 public constant USER_DAILY_LIMIT = 1000 * 10**18;
    uint256 public constant FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 private constant SECONDS_PER_DAY = 1 days;

    // -----------------------------------------------------------------------
    //                               Enums
    // -----------------------------------------------------------------------
    enum TxStatus {
        None,
        Pending,
        Approved,
        Rejected,
        Cancelled
    }

    // -----------------------------------------------------------------------
    //                              Structs
    // -----------------------------------------------------------------------
    struct SpendingTx {
        address user;
        address merchant;
        uint256 amount;
        uint256 timestamp;
        TxStatus status;
    }

    // -----------------------------------------------------------------------
    //                               Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event SpendingInitiated(uint256 indexed txId, address indexed user, address indexed merchant, uint256 amount);
    event SpendingApproved(uint256 indexed txId, address indexed user, address indexed merchant, uint256 amount, uint256 fee);
    event SpendingRejected(uint256 indexed txId, address indexed user, uint256 amount);
    event SpendingCancelled(uint256 indexed txId, address indexed user, uint256 amount);
    event GlobalDailyLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed owner, uint256 amount);

    // -----------------------------------------------------------------------
    //                           State Variables
    // -----------------------------------------------------------------------
    IERC20 public immutable stablecoin;
    address public owner;
    address public operator;

    uint256 public globalDailyLimit;
    uint256 public globalDailySpent;
    uint256 public globalDay;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public userDailySpent;
    mapping(address => uint256) public userDay;

    uint256 public totalFeesCollected;

    mapping(uint256 => SpendingTx) public transactions;
    uint256 public nextTxId;

    // -----------------------------------------------------------------------
    //                              Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // -----------------------------------------------------------------------
    //                             Constructor
    // -----------------------------------------------------------------------
    constructor(address _stablecoin, address _operator, uint256 _globalDailyLimit) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        globalDailyLimit = _globalDailyLimit;
        globalDay = _currentDay();
        nextTxId = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit GlobalDailyLimitUpdated(0, _globalDailyLimit);
    }

    // -----------------------------------------------------------------------
    //                         Internal Helpers
    // -----------------------------------------------------------------------
    function _currentDay() internal view returns (uint256) {
        return block.timestamp / SECONDS_PER_DAY;
    }

    function _resetGlobalDayIfNeeded() internal {
        uint256 day = _currentDay();
        if (globalDay != day) {
            globalDay = day;
            globalDailySpent = 0;
        }
    }

    function _resetUserDayIfNeeded(address user) internal {
        uint256 day = _currentDay();
        if (userDay[user] != day) {
            userDay[user] = day;
            userDailySpent[user] = 0;
        }
    }

    function _computeFee(uint256 amount) internal pure returns (uint256) {
        return (amount * FEE_BPS) / BPS_DENOMINATOR;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    // -----------------------------------------------------------------------
    //                       User-facing Functions
    // -----------------------------------------------------------------------
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _safeTransferFrom(address(stablecoin), msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        _safeTransfer(address(stablecoin), msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    function initiateSpending(address merchant, uint256 amount) external returns (uint256 txId) {
        if (amount == 0) revert ZeroAmount();
        if (merchant == address(0)) revert ZeroAddress();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        txId = nextTxId++;
        transactions[txId] = SpendingTx({
            user: msg.sender,
            merchant: merchant,
            amount: amount,
            timestamp: block.timestamp,
            status: TxStatus.Pending
        });
        emit SpendingInitiated(txId, msg.sender, merchant, amount);
    }

    function cancelSpending(uint256 txId) external {
        SpendingTx storage txn = transactions[txId];
        if (txn.status == TxStatus.None) revert TransactionNotFound();
        if (txn.status != TxStatus.Pending) revert TransactionNotPending();
        if (txn.user != msg.sender) revert NotTransactionInitiator();
        txn.status = TxStatus.Cancelled;
        emit SpendingCancelled(txId, msg.sender, txn.amount);
    }

    // -----------------------------------------------------------------------
    //                      Operator-only Functions
    // -----------------------------------------------------------------------
    function approveSpending(uint256 txId) external onlyOperator {
        SpendingTx storage txn = transactions[txId];
        if (txn.status == TxStatus.None) revert TransactionNotFound();
        if (txn.status != TxStatus.Pending) revert TransactionNotPending();

        address user = txn.user;
        address merchant = txn.merchant;
        uint256 amount = txn.amount;

        if (balances[user] < amount) revert InsufficientBalance();

        _resetGlobalDayIfNeeded();
        _resetUserDayIfNeeded(user);

        if (userDailySpent[user] + amount > USER_DAILY_LIMIT) revert ExceedsUserDailyLimit();
        if (globalDailySpent + amount > globalDailyLimit) revert ExceedsGlobalDailyLimit();

        uint256 fee = _computeFee(amount);
        uint256 netSpend = amount - fee;

        balances[user] -= amount;
        userDailySpent[user] += amount;
        globalDailySpent += amount;
        totalFeesCollected += fee;
        txn.status = TxStatus.Approved;

        _safeTransfer(address(stablecoin), merchant, netSpend);

        emit SpendingApproved(txId, user, merchant, amount, fee);
    }

    function rejectSpending(uint256 txId) external onlyOperator {
        SpendingTx storage txn = transactions[txId];
        if (txn.status == TxStatus.None) revert TransactionNotFound();
        if (txn.status != TxStatus.Pending) revert TransactionNotPending();
        txn.status = TxStatus.Rejected;
        emit SpendingRejected(txId, txn.user, txn.amount);
    }

    function setGlobalDailyLimit(uint256 newLimit) external onlyOperator {
        emit GlobalDailyLimitUpdated(globalDailyLimit, newLimit);
        globalDailyLimit = newLimit;
    }

    // -----------------------------------------------------------------------
    //                       Owner-only Functions
    // -----------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = totalFeesCollected;
        if (amount == 0) revert ZeroAmount();
        totalFeesCollected = 0;
        _safeTransfer(address(stablecoin), owner, amount);
        emit FeesWithdrawn(owner, amount);
    }

    // -----------------------------------------------------------------------
    //                          View Functions
    // -----------------------------------------------------------------------
    function getBalance(address user) external view returns (uint256 balance) {
        return balances[user];
    }

    function getUserDailySpent(address user) external view returns (uint256 spent) {
        if (userDay[user] != _currentDay()) return 0;
        return userDailySpent[user];
    }

    function getRemainingUserDailyLimit(address user) external view returns (uint256 remaining) {
        if (userDay[user] != _currentDay()) return USER_DAILY_LIMIT;
        return USER_DAILY_LIMIT - userDailySpent[user];
    }

    function getRemainingGlobalDailyLimit() external view returns (uint256 remaining) {
        if (globalDay != _currentDay()) return globalDailyLimit;
        return globalDailyLimit - globalDailySpent;
    }

    function getTransaction(uint256 txId)
        external
        view
        returns (address user, address merchant, uint256 amount, uint256 timestamp, TxStatus status)
    {
        SpendingTx storage txn = transactions[txId];
        return (txn.user, txn.merchant, txn.amount, txn.timestamp, txn.status);
    }
}
