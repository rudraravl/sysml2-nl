// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DebitCardStablecoinPool {
    // -----------------------------------------------------------------
    // State
    // -----------------------------------------------------------------
    IERC20 public immutable stablecoin;
    address public operator;

    uint256 public feeBps; // 50 = 0.5%
    uint256 public constant MAX_DEPOSIT = 10_000 * 1e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    mapping(address => uint256) public userBalances;
    uint256 public globalReserve;
    mapping(address => bytes32) public cardIdentifiers;

    enum TransactionStatus {
        Pending,
        Approved,
        Rejected
    }

    struct SpendingTransaction {
        address user;
        uint256 amount;
        uint256 fee;
        bytes32 cardIdentifier;
        TransactionStatus status;
    }

    mapping(uint256 => SpendingTransaction) public transactions;
    uint256 public nextTransactionId;

    // -----------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------
    event StablecoinDeposited(
        address indexed user,
        uint256 amount,
        uint256 newBalance,
        uint256 newReserve
    );
    event CardLinked(address indexed user, bytes32 cardIdentifier);
    event FiatSpendingInitiated(
        uint256 indexed txId,
        address indexed user,
        uint256 amount,
        uint256 fee,
        bytes32 cardIdentifier
    );
    event FiatSpendingApproved(
        uint256 indexed txId,
        address indexed user,
        uint256 amount,
        uint256 fee
    );
    event FiatSpendingRejected(
        uint256 indexed txId,
        address indexed user,
        uint256 amount
    );
    event StablecoinWithdrawn(
        address indexed user,
        uint256 amount,
        uint256 newBalance
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // -----------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------
    error NotOperator();
    error ZeroAmount();
    error ZeroCardIdentifier();
    error ZeroAddress();
    error MaxDepositExceeded(uint256 currentBalance, uint256 depositAmount, uint256 maxDeposit);
    error InsufficientBalance(uint256 available, uint256 required);
    error TransactionNotFound(uint256 txId);
    error TransactionNotPending(uint256 txId, TransactionStatus status);
    error FeeTooHigh(uint256 feeBps);
    error TransferFailed();

    // -----------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // -----------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0) || _operator == address(0))
            revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        feeBps = 50; // 0.5%
    }

    // -----------------------------------------------------------------
    // Internal safe-transfer helpers (compatible with non-standard ERC20s)
    // -----------------------------------------------------------------
    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    // -----------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------

    /// @notice Links an external card identifier to the caller's address.
    function linkCard(bytes32 cardIdentifier) external {
        if (cardIdentifier == bytes32(0)) revert ZeroCardIdentifier();
        cardIdentifiers[msg.sender] = cardIdentifier;
        emit CardLinked(msg.sender, cardIdentifier);
    }

    /// @notice Deposits stablecoins into the caller's balance.
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 currentBalance = userBalances[msg.sender];
        uint256 newBalance = currentBalance + amount;
        if (newBalance > MAX_DEPOSIT) {
            revert MaxDepositExceeded(currentBalance, amount, MAX_DEPOSIT);
        }

        // Effects
        userBalances[msg.sender] = newBalance;
        globalReserve += amount;

        // Interactions
        _safeTransferFrom(msg.sender, address(this), amount);

        emit StablecoinDeposited(msg.sender, amount, newBalance, globalReserve);
    }

    /// @notice Initiates a fiat spending transaction, locking the spending
    ///         amount plus fee from the caller's balance.
    function initiateFiatSpending(uint256 amount, bytes32 cardIdentifier)
        external
    {
        if (amount == 0) revert ZeroAmount();
        if (cardIdentifier == bytes32(0)) revert ZeroCardIdentifier();

        // Record the card identifier for this user
        cardIdentifiers[msg.sender] = cardIdentifier;

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 totalRequired = amount + fee;

        uint256 available = userBalances[msg.sender];
        if (available < totalRequired) {
            revert InsufficientBalance(available, totalRequired);
        }

        // Effects — lock funds
        uint256 txId = nextTransactionId++;
        transactions[txId] = SpendingTransaction({
            user: msg.sender,
            amount: amount,
            fee: fee,
            cardIdentifier: cardIdentifier,
            status: TransactionStatus.Pending
        });
        userBalances[msg.sender] = available - totalRequired;

        emit FiatSpendingInitiated(
            txId,
            msg.sender,
            amount,
            fee,
            cardIdentifier
        );
    }

    /// @notice Withdraws stablecoins from the caller's available balance.
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 available = userBalances[msg.sender];
        if (available < amount) {
            revert InsufficientBalance(available, amount);
        }

        // Effects
        userBalances[msg.sender] = available - amount;
        globalReserve -= amount;

        // Interactions
        _safeTransfer(msg.sender, amount);

        emit StablecoinWithdrawn(msg.sender, amount, userBalances[msg.sender]);
    }

    // -----------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------

    /// @notice Approves a pending fiat spending transaction and transfers
    ///         the locked stablecoins (amount + fee) to the operator for
    ///         off-chain fiat settlement.
    function approveTransaction(uint256 txId) external onlyOperator {
        SpendingTransaction storage txn = transactions[txId];
        if (txn.user == address(0)) revert TransactionNotFound(txId);
        if (txn.status != TransactionStatus.Pending)
            revert TransactionNotPending(txId, txn.status);

        // Effects
        txn.status = TransactionStatus.Approved;
        uint256 totalAmount = txn.amount + txn.fee;
        globalReserve -= totalAmount;

        // Interactions
        _safeTransfer(operator, totalAmount);

        emit FiatSpendingApproved(txId, txn.user, txn.amount, txn.fee);
    }

    /// @notice Rejects a pending fiat spending transaction and returns the
    ///         locked stablecoins (amount + fee) to the user's balance.
    function rejectTransaction(uint256 txId) external onlyOperator {
        SpendingTransaction storage txn = transactions[txId];
        if (txn.user == address(0)) revert TransactionNotFound(txId);
        if (txn.status != TransactionStatus.Pending)
            revert TransactionNotPending(txId, txn.status);

        // Effects — refund locked funds
        txn.status = TransactionStatus.Rejected;
        uint256 totalAmount = txn.amount + txn.fee;
        userBalances[txn.user] += totalAmount;

        emit FiatSpendingRejected(txId, txn.user, txn.amount);
    }

    /// @notice Sets the transaction fee in basis points (max 10 000 = 100%).
    function setFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > BPS_DENOMINATOR) revert FeeTooHigh(_feeBps);
        uint256 oldFeeBps = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(oldFeeBps, _feeBps);
    }

    /// @notice Transfers operator rights to a new address.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    // -----------------------------------------------------------------
    // View helpers
    // -----------------------------------------------------------------

    function getTransaction(uint256 txId)
        external
        view
        returns (
            address user,
            uint256 amount,
            uint256 fee,
            bytes32 cardIdentifier,
            TransactionStatus status
        )
    {
        SpendingTransaction memory txn = transactions[txId];
        return (
            txn.user,
            txn.amount,
            txn.fee,
            txn.cardIdentifier,
            txn.status
        );
    }

    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * feeBps) / BPS_DENOMINATOR;
    }

    function getAvailableBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }
}
