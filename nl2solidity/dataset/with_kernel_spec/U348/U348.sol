// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract StablecoinDepositManager {
    // ---------- Errors ----------
    error NotAuthorized();
    error ZeroAmount();
    error ZeroAddress();
    error DepositExceedsMaximum(uint256 newTotal, uint256 maxDeposit);
    error InsufficientBalance(uint256 available, uint256 required);
    error ExternalAccountNotSet(address user);
    error InvalidRecipient();
    error TransactionNotFound(uint256 txId);
    error TransactionNotPending(uint256 txId);
    error InvalidFee(uint256 proposed);
    error TransferFailed();

    // ---------- Constants ----------
    uint256 public constant MAX_DEPOSIT_UNITS = 10_000;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5%

    // ---------- State Variables ----------
    IERC20 public immutable stablecoin;
    address public operator;
    uint256 public immutable maxDeposit;
    uint256 public feeBps;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public reservedBalance;
    mapping(address => address) public externalAccounts;

    enum Status {
        Pending,
        Approved,
        Rejected
    }

    struct SpendingTransaction {
        address user;
        address recipient;
        uint256 amount;
        uint256 fee;
        Status status;
    }

    mapping(uint256 => SpendingTransaction) public transactions;
    uint256 public transactionCount;

    // ---------- Events ----------
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawal(address indexed user, uint256 amount, uint256 newBalance);
    event ExternalAccountSet(address indexed user, address indexed externalAccount);
    event SpendingInitiated(uint256 indexed txId, address indexed user, address recipient, uint256 amount);
    event SpendingApproved(uint256 indexed txId, address indexed user, uint256 amount, uint256 fee);
    event SpendingRejected(uint256 indexed txId, address indexed user);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorChanged(address oldOperator, address newOperator);

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    // ---------- Constructor ----------
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;

        // Safely determine decimals; default to 18 if the call fails
        // so the constructor does not revert when the token lacks
        // an exported decimals() function.
        uint8 dec = 18;
        try IERC20(_stablecoin).decimals() returns (uint8 d) {
            dec = d;
        } catch {}

        maxDeposit = MAX_DEPOSIT_UNITS * (10 ** uint256(dec));
        feeBps = DEFAULT_FEE_BPS;
    }

    // ---------- External Account Management ----------
    function setExternalAccount(address externalAccount) external {
        if (externalAccount == address(0)) revert ZeroAddress();
        externalAccounts[msg.sender] = externalAccount;
        emit ExternalAccountSet(msg.sender, externalAccount);
    }

    // ---------- Deposit & Withdraw ----------
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 newTotal = deposits[msg.sender] + amount;
        if (newTotal > maxDeposit) revert DepositExceedsMaximum(newTotal, maxDeposit);

        deposits[msg.sender] = newTotal;
        _safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, newTotal);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 currentDeposits = deposits[msg.sender];
        uint256 currentReserved = reservedBalance[msg.sender];
        require(currentReserved <= currentDeposits, "reserved exceeds deposits");
        uint256 available = currentDeposits - currentReserved;
        if (available < amount) revert InsufficientBalance(available, amount);

        deposits[msg.sender] = currentDeposits - amount;
        _safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount, deposits[msg.sender]);
    }

    // ---------- Spending Transaction Lifecycle ----------
    function initiateSpending(uint256 amount, address recipient) external {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert InvalidRecipient();
        if (externalAccounts[msg.sender] == address(0)) revert ExternalAccountNotSet(msg.sender);

        uint256 currentDeposits = deposits[msg.sender];
        uint256 currentReserved = reservedBalance[msg.sender];
        require(currentReserved <= currentDeposits, "reserved exceeds deposits");
        uint256 available = currentDeposits - currentReserved;
        if (available < amount) revert InsufficientBalance(available, amount);

        reservedBalance[msg.sender] = currentReserved + amount;

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 txId = transactionCount;
        transactions[txId] = SpendingTransaction({
            user: msg.sender,
            recipient: recipient,
            amount: amount,
            fee: fee,
            status: Status.Pending
        });
        transactionCount = txId + 1;

        emit SpendingInitiated(txId, msg.sender, recipient, amount);
    }

    function approveSpending(uint256 txId) external onlyOperator {
        if (txId >= transactionCount) revert TransactionNotFound(txId);
        SpendingTransaction storage txn = transactions[txId];
        if (txn.status != Status.Pending) revert TransactionNotPending(txId);

        // Effects
        txn.status = Status.Approved;
        reservedBalance[txn.user] -= txn.amount;
        deposits[txn.user] -= txn.amount;

        uint256 netAmount = txn.amount - txn.fee;

        // Interactions
        if (netAmount > 0) {
            _safeTransfer(txn.recipient, netAmount);
        }
        if (txn.fee > 0) {
            _safeTransfer(operator, txn.fee);
        }

        emit SpendingApproved(txId, txn.user, txn.amount, txn.fee);
    }

    function rejectSpending(uint256 txId) external onlyOperator {
        if (txId >= transactionCount) revert TransactionNotFound(txId);
        SpendingTransaction storage txn = transactions[txId];
        if (txn.status != Status.Pending) revert TransactionNotPending(txId);

        txn.status = Status.Rejected;
        reservedBalance[txn.user] -= txn.amount;

        emit SpendingRejected(txId, txn.user);
    }

    // ---------- Admin ----------
    function setFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > BPS_DENOMINATOR) revert InvalidFee(_feeBps);
        uint256 oldFee = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(oldFee, _feeBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // ---------- Views ----------
    function getAvailableBalance(address user) external view returns (uint256) {
        return deposits[user] - reservedBalance[user];
    }

    function getTransaction(uint256 txId) external view returns (SpendingTransaction memory) {
        return transactions[txId];
    }

    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * feeBps) / BPS_DENOMINATOR;
    }

    // ---------- Internal Safe Transfers ----------
    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
