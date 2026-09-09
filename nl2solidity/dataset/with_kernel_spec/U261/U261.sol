// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PrepaidCryptoCard {
    IERC20 public immutable stablecoin;
    address public owner;
    address public operator;

    uint256 public totalReserve;
    mapping(address => uint256) public userBalances;

    uint256 public transactionFee; // in basis points, 50 = 0.5%
    uint256 public constant MAX_DAILY_SPEND = 1000 * 10**18;

    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastSpendDay;

    struct Transaction {
        address user;
        uint256 amount;
        bool approved;
        bool rejected;
        bool processed;
    }
    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;

    event Deposit(address indexed user, uint256 amount);
    event TransactionInitiated(uint256 indexed txId, address indexed user, uint256 amount);
    event TransactionApproved(uint256 indexed txId, address indexed user, uint256 amount, uint256 fee);
    event TransactionRejected(uint256 indexed txId, address indexed user, uint256 amount);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address oldOperator, address newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event ExcessWithdrawn(address indexed operator, uint256 amount);

    error Unauthorized();
    error TransactionNotFound();
    error TransactionAlreadyProcessed();
    error InsufficientBalance();
    error ExceedsDailyLimit(uint256 requested, uint256 available);
    error ZeroAmount();
    error ZeroAddress();
    error FeeTooHigh();
    error NoExcess();
    error TransferFailed();
    error TransferFromFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        transactionFee = 50; // 0.5%
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        userBalances[msg.sender] += amount;
        totalReserve += amount;

        _safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function initiateTransaction(uint256 amount) external returns (uint256 txId) {
        if (amount == 0) revert ZeroAmount();

        txId = ++transactionCount;
        transactions[txId] = Transaction({
            user: msg.sender,
            amount: amount,
            approved: false,
            rejected: false,
            processed: false
        });

        emit TransactionInitiated(txId, msg.sender, amount);
    }

    function approveTransaction(uint256 txId) external onlyOperator {
        Transaction storage txn = transactions[txId];
        if (txn.user == address(0)) revert TransactionNotFound();
        if (txn.processed) revert TransactionAlreadyProcessed();

        address user = txn.user;
        uint256 amount = txn.amount;
        uint256 fee = (amount * transactionFee) / 10000;
        uint256 totalDeduction = amount + fee;

        if (userBalances[user] < totalDeduction) revert InsufficientBalance();

        uint256 day = block.timestamp / 1 days;
        if (lastSpendDay[user] != day) {
            dailySpent[user] = 0;
            lastSpendDay[user] = day;
        }

        if (dailySpent[user] + amount > MAX_DAILY_SPEND) {
            revert ExceedsDailyLimit(amount, MAX_DAILY_SPEND > dailySpent[user] ? MAX_DAILY_SPEND - dailySpent[user] : 0);
        }
        dailySpent[user] += amount;

        userBalances[user] -= totalDeduction;
        totalReserve -= totalDeduction;

        txn.approved = true;
        txn.processed = true;

        emit TransactionApproved(txId, user, amount, fee);
    }

    function rejectTransaction(uint256 txId) external onlyOperator {
        Transaction storage txn = transactions[txId];
        if (txn.user == address(0)) revert TransactionNotFound();
        if (txn.processed) revert TransactionAlreadyProcessed();

        address user = txn.user;
        uint256 amount = txn.amount;

        txn.rejected = true;
        txn.processed = true;

        emit TransactionRejected(txId, user, amount);
    }

    function setTransactionFee(uint256 newFee) external onlyOperator {
        if (newFee > 10000) revert FeeTooHigh();
        uint256 oldFee = transactionFee;
        transactionFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function withdrawExcess() external onlyOperator {
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (contractBalance <= totalReserve) revert NoExcess();
        uint256 excess = contractBalance - totalReserve;
        _safeTransfer(operator, excess);
        emit ExcessWithdrawn(operator, excess);
    }

    function getDailyRemaining(address user) external view returns (uint256) {
        uint256 day = block.timestamp / 1 days;
        if (lastSpendDay[user] != day) return MAX_DAILY_SPEND;
        uint256 spent = dailySpent[user];
        return spent >= MAX_DAILY_SPEND ? 0 : MAX_DAILY_SPEND - spent;
    }

    function getTransaction(uint256 txId) external view returns (address user, uint256 amount, bool approved, bool rejected, bool processed) {
        Transaction storage txn = transactions[txId];
        user = txn.user;
        amount = txn.amount;
        approved = txn.approved;
        rejected = txn.rejected;
        processed = txn.processed;
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFromFailed();
    }
}
