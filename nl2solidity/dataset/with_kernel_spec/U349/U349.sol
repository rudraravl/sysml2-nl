// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title MobileMoneyTransfer
 * @notice A global mobile money transfer system backed by a stablecoin reserve.
 *         Users can deposit, transfer to other registered users, and withdraw
 *         to an external wallet. An operator registers users, sets transfer
 *         fees (capped at 0.5%), and can pause/unpause transfers.
 */
contract MobileMoneyTransfer {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error NotRegistered();
    error AlreadyRegistered();
    error TransfersPaused();
    error InsufficientBalance();
    error ZeroAddress();
    error FeeTooHigh();
    error DailyLimitExceeded();
    error TransferFailed();
    error AmountMustBePositive();
    error CannotTransferToSelf();

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_TRANSACTIONS = 10;
    uint256 public constant DAILY_WITHDRAWAL_LIMIT = 1000 * 10**18;

    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------
    enum TxType { Deposit, TransferIn, TransferOut, Withdrawal }

    struct Transaction {
        TxType txType;
        uint256 amount;
        address counterparty;
        uint256 timestamp;
    }

    struct User {
        bool registered;
        uint256 balance;
        uint256 lastWithdrawalDay;
        uint256 withdrawnToday;
        uint256 txHead;
        uint256 txCount;
        mapping(uint256 => Transaction) transactions;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    IERC20 public immutable stablecoin;
    address public operator;
    bool public transfersPaused;
    uint256 public transferFeeBps;

    uint256 public totalUserBalances;
    uint256 public feesCollected;

    mapping(address => User) private users;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event Withdrawal(address indexed user, address indexed to, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TransfersPausedChanged(bool paused);
    event UserRegistered(address indexed user);
    event FeesClaimed(address indexed operator, uint256 amount);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (transfersPaused) revert TransfersPaused();
        _;
    }

    modifier onlyRegistered(address user) {
        if (!users[user].registered) revert NotRegistered();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        transferFeeBps = 0;
    }

    // ---------------------------------------------------------------------
    // External functions — user operations
    // ---------------------------------------------------------------------

    function deposit(uint256 amount) external onlyRegistered(msg.sender) {
        if (amount == 0) revert AmountMustBePositive();

        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        User storage user = users[msg.sender];
        user.balance += amount;
        totalUserBalances += amount;

        _recordTransaction(msg.sender, TxType.Deposit, amount, address(this));

        emit Deposit(msg.sender, amount);
    }

    function transfer(address to, uint256 amount)
        external
        onlyRegistered(msg.sender)
        onlyRegistered(to)
        whenNotPaused
    {
        if (amount == 0) revert AmountMustBePositive();
        if (to == msg.sender) revert CannotTransferToSelf();

        uint256 fee = (amount * transferFeeBps) / 10000;
        uint256 totalDeduct = amount + fee;

        User storage sender = users[msg.sender];
        if (sender.balance < totalDeduct) revert InsufficientBalance();

        sender.balance -= totalDeduct;
        users[to].balance += amount;
        totalUserBalances -= fee;
        feesCollected += fee;

        _recordTransaction(msg.sender, TxType.TransferOut, amount, to);
        _recordTransaction(to, TxType.TransferIn, amount, msg.sender);

        emit Transfer(msg.sender, to, amount, fee);
    }

    function withdraw(address to, uint256 amount)
        external
        onlyRegistered(msg.sender)
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountMustBePositive();

        User storage user = users[msg.sender];
        if (user.balance < amount) revert InsufficientBalance();

        uint256 today = block.timestamp / 1 days;
        if (user.lastWithdrawalDay != today) {
            user.lastWithdrawalDay = today;
            user.withdrawnToday = 0;
        }
        if (user.withdrawnToday + amount > DAILY_WITHDRAWAL_LIMIT) {
            revert DailyLimitExceeded();
        }
        user.withdrawnToday += amount;

        user.balance -= amount;
        totalUserBalances -= amount;

        bool ok = stablecoin.transfer(to, amount);
        if (!ok) revert TransferFailed();

        _recordTransaction(msg.sender, TxType.Withdrawal, amount, to);

        emit Withdrawal(msg.sender, to, amount);
    }

    // ---------------------------------------------------------------------
    // External functions — operator operations
    // ---------------------------------------------------------------------

    function registerUser(address user) external onlyOperator {
        if (user == address(0)) revert ZeroAddress();
        if (users[user].registered) revert AlreadyRegistered();
        users[user].registered = true;
        emit UserRegistered(user);
    }

    function setTransferFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = transferFeeBps;
        transferFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function pauseTransfers() external onlyOperator {
        if (transfersPaused) return;
        transfersPaused = true;
        emit TransfersPausedChanged(true);
    }

    function unpauseTransfers() external onlyOperator {
        if (!transfersPaused) return;
        transfersPaused = false;
        emit TransfersPausedChanged(false);
    }

    function claimFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = feesCollected;
        if (amount == 0) revert AmountMustBePositive();
        feesCollected = 0;
        bool ok = stablecoin.transfer(to, amount);
        if (!ok) revert TransferFailed();
        emit FeesClaimed(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // External view functions
    // ---------------------------------------------------------------------

    function isRegistered(address user) external view returns (bool) {
        return users[user].registered;
    }

    function getBalance(address user) external view onlyRegistered(user) returns (uint256) {
        return users[user].balance;
    }

    function getWithdrawnToday(address user) external view onlyRegistered(user) returns (uint256) {
        User storage u = users[user];
        if (u.lastWithdrawalDay != block.timestamp / 1 days) {
            return 0;
        }
        return u.withdrawnToday;
    }

    function remainingDailyWithdrawal(address user) external view onlyRegistered(user) returns (uint256) {
        User storage u = users[user];
        uint256 used = (u.lastWithdrawalDay == block.timestamp / 1 days) ? u.withdrawnToday : 0;
        if (used >= DAILY_WITHDRAWAL_LIMIT) return 0;
        return DAILY_WITHDRAWAL_LIMIT - used;
    }

    function getRecentTransactions(address user)
        external
        view
        onlyRegistered(user)
        returns (Transaction[] memory)
    {
        User storage u = users[user];
        uint256 count = u.txCount;
        Transaction[] memory result = new Transaction[](count);
        if (count == 0) return result;
        uint256 start;
        if (count < MAX_TRANSACTIONS) {
            start = 0;
        } else {
            start = u.txHead;
        }
        for (uint256 i = 0; i < count; ++i) {
            result[i] = u.transactions[(start + i) % MAX_TRANSACTIONS];
        }
        return result;
    }

    function totalReserve() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _recordTransaction(address user, TxType txType, uint256 amount, address counterparty) internal {
        User storage u = users[user];
        uint256 index = u.txHead;
        u.transactions[index] = Transaction({
            txType: txType,
            amount: amount,
            counterparty: counterparty,
            timestamp: block.timestamp
        });
        u.txHead = (index + 1) % MAX_TRANSACTIONS;
        if (u.txCount < MAX_TRANSACTIONS) {
            u.txCount += 1;
        }
    }
}
