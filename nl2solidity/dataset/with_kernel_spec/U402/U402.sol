// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error OnlyOperator();
error ZeroAddress();
error InvalidAmount();
error NativeTransferFailed();
error InsufficientWrappedBalance();
error RequestNotFound();
error RequestNotPending();
error RequestNotExpired();
error RequestExpired();
error FeeExceedsMax();
error InvalidRecipient();

/**
 * @title CrossChainWrappedVault
 * @notice Custodies wrapped tokens (1:1 backed by native Ether) and coordinates
 *         cross-chain transfers. Users deposit native Ether to mint wrapped
 *         tokens, burn wrapped tokens to redeem native Ether, or burn wrapped
 *         tokens to initiate a cross-chain transfer that an off-chain operator
 *         must approve within 24 hours. The destination chain (operated by the
 *         same or a paired contract) releases native assets to the recipient.
 */
contract CrossChainWrappedVault {
    // ------------------------------------------------------------------
    //                              METADATA
    // ------------------------------------------------------------------
    string public constant name = "Cross Chain Wrapped Ether";
    string public constant symbol = "xWETH";
    uint8 public constant decimals = 18;

    // ------------------------------------------------------------------
    //                             CONSTANTS
    // ------------------------------------------------------------------
    /// @dev Maximum transfer fee expressed in basis points (0.5% = 50 bps).
    uint256 public constant MAX_FEE_BPS = 50;
    /// @dev Cross-chain transfer requests must be approved within this window.
    uint256 public constant APPROVAL_WINDOW = 24 hours;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ------------------------------------------------------------------
    //                              STATE
    // ------------------------------------------------------------------
    /// @notice Total wrapped token supply currently minted on this chain.
    uint256 public totalSupply;
    /// @notice Wrapped token balance of each user.
    mapping(address => uint256) public wrappedBalance;
    /// @notice Global fee (in basis points) applied to cross-chain transfers.
    uint256 public transferFeeBps;
    /// @notice Designated operator responsible for approving cross-chain
    ///         transfer requests and updating the transfer fee.
    address public operator;

    enum Status {
        None,
        Pending,
        Approved,
        Refunded
    }

    struct CrossChainRequest {
        address initiator;
        address recipient;
        uint256 amount;
        uint256 fee;
        uint256 initiatedAt;
        Status status;
    }

    /// @notice Registry of all cross-chain transfer requests keyed by id.
    mapping(uint256 => CrossChainRequest) public crossChainRequests;
    /// @dev Auto-incrementing id for cross-chain transfer requests.
    uint256 private _nextRequestId;

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event CrossChainTransferInitiated(
        uint256 indexed requestId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 fee
    );
    event CrossChainTransferApproved(
        uint256 indexed requestId,
        address indexed sender,
        address indexed recipient,
        uint256 netAmount,
        uint256 fee
    );
    event CrossChainTransferRefunded(
        uint256 indexed requestId,
        address indexed initiator,
        uint256 amount
    );
    event TransferFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event WrappedTransfer(address indexed from, address indexed to, uint256 amount);

    // ------------------------------------------------------------------
    //                            MODIFIERS
    // ------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // ------------------------------------------------------------------
    //                           CONSTRUCTOR
    // ------------------------------------------------------------------
    constructor(uint256 initialFeeBps, address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        if (initialFeeBps > MAX_FEE_BPS) revert FeeExceedsMax();
        operator = _operator;
        transferFeeBps = initialFeeBps;
        emit TransferFeeUpdated(0, initialFeeBps);
        emit OperatorUpdated(address(0), _operator);
    }

    // ------------------------------------------------------------------
    //                       WRAPPED TOKEN LOGIC
    // ------------------------------------------------------------------
    /**
     * @notice Deposit native Ether to mint wrapped tokens 1:1 to the caller.
     */
    function deposit() public payable virtual {
        uint256 amount = msg.value;
        if (amount == 0) revert InvalidAmount();
        unchecked {
            wrappedBalance[msg.sender] += amount;
            totalSupply += amount;
        }
        emit Deposit(msg.sender, amount);
        emit WrappedTransfer(address(0), msg.sender, amount);
    }

    /**
     * @notice Burn wrapped tokens to redeem the corresponding native Ether.
     * @param amount The amount of wrapped tokens to burn.
     */
    function withdraw(uint256 amount) public virtual {
        if (amount == 0) revert InvalidAmount();
        if (wrappedBalance[msg.sender] < amount) revert InsufficientWrappedBalance();

        wrappedBalance[msg.sender] -= amount;
        totalSupply -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert NativeTransferFailed();

        emit Withdrawal(msg.sender, amount);
        emit WrappedTransfer(msg.sender, address(0), amount);
    }

    // ------------------------------------------------------------------
    //                  CROSS-CHAIN TRANSFER LOGIC
    // ------------------------------------------------------------------
    /**
     * @notice Initiate a cross-chain transfer by burning wrapped tokens on
     *         this chain. The release on the destination chain must be
     *         triggered by the operator's approval event off-chain.
     * @param recipient The address that should receive the released native
     *                  assets on the destination chain.
     * @param amount    The gross amount of wrapped tokens to transfer.
     * @return requestId The id of the newly created cross-chain request.
     */
    function initiateCrossChainTransfer(
        address recipient,
        uint256 amount
    ) external returns (uint256 requestId) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (wrappedBalance[msg.sender] < amount) revert InsufficientWrappedBalance();

        uint256 fee = (amount * transferFeeBps) / BPS_DENOMINATOR;

        // Burn the gross amount from the initiator.
        wrappedBalance[msg.sender] -= amount;
        totalSupply -= amount;

        requestId = _nextRequestId++;
        crossChainRequests[requestId] = CrossChainRequest({
            initiator: msg.sender,
            recipient: recipient,
            amount: amount,
            fee: fee,
            initiatedAt: block.timestamp,
            status: Status.Pending
        });

        emit CrossChainTransferInitiated(
            requestId,
            msg.sender,
            recipient,
            amount,
            fee
        );
        emit WrappedTransfer(msg.sender, address(0), amount);
    }

    /**
     * @notice Approve a pending cross-chain transfer request. Only callable by
     *         the operator and only within 24 hours of initiation. On
     *         approval, the fee is minted to the operator as compensation and
     *         the net amount is authorized for release on the destination chain.
     * @param requestId The id of the cross-chain request to approve.
     */
    function approveCrossChainTransfer(
        uint256 requestId
    ) external onlyOperator {
        CrossChainRequest storage r = crossChainRequests[requestId];
        if (r.status == Status.None) revert RequestNotFound();
        if (r.status != Status.Pending) revert RequestNotPending();
        if (block.timestamp > r.initiatedAt + APPROVAL_WINDOW)
            revert RequestExpired();

        r.status = Status.Approved;

        uint256 fee = r.fee;
        if (fee > 0) {
            unchecked {
                wrappedBalance[operator] += fee;
                totalSupply += fee;
            }
            emit WrappedTransfer(address(0), operator, fee);
        }

        uint256 netAmount = r.amount - fee;
        emit CrossChainTransferApproved(
            requestId,
            r.initiator,
            r.recipient,
            netAmount,
            fee
        );
    }

    /**
     * @notice Refund a pending cross-chain transfer request that was not
     *         approved by the operator within the 24-hour window. Only the
     *         original initiator may reclaim their burned tokens.
     * @param requestId The id of the cross-chain request to refund.
     */
    function refundExpiredTransfer(uint256 requestId) external {
        CrossChainRequest storage r = crossChainRequests[requestId];
        if (r.status == Status.None) revert RequestNotFound();
        if (r.status != Status.Pending) revert RequestNotPending();
        if (block.timestamp <= r.initiatedAt + APPROVAL_WINDOW)
            revert RequestNotExpired();

        r.status = Status.Refunded;

        uint256 amount = r.amount;
        unchecked {
            wrappedBalance[r.initiator] += amount;
            totalSupply += amount;
        }

        emit CrossChainTransferRefunded(requestId, r.initiator, amount);
        emit WrappedTransfer(address(0), r.initiator, amount);
    }

    // ------------------------------------------------------------------
    //                        ADMIN / OPERATOR
    // ------------------------------------------------------------------
    /**
     * @notice Update the global cross-chain transfer fee (in basis points).
     *         Capped at 0.5% (50 bps).
     * @param newFeeBps The new fee in basis points.
     */
    function updateTransferFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMax();
        uint256 old = transferFeeBps;
        transferFeeBps = newFeeBps;
        emit TransferFeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Transfer operator privileges to a new address.
     * @param newOperator The address of the new operator.
     */
    function updateOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    // ------------------------------------------------------------------
    //                           VIEWS
    // ------------------------------------------------------------------
    /**
     * @notice Query the wrapped token balance of an account.
     * @param account The address to query.
     */
    function balanceOf(address account) external view returns (uint256) {
        return wrappedBalance[account];
    }

    /**
     * @notice Compute the fee applied to a given cross-chain transfer amount
     *         under the current fee configuration.
     * @param amount The gross transfer amount.
     */
    function computeFee(uint256 amount) external view returns (uint256) {
        return (amount * transferFeeBps) / BPS_DENOMINATOR;
    }

    /**
     * @notice Returns whether a pending request is still within the operator
     *         approval window.
     * @param requestId The id of the cross-chain request.
     */
    function isRequestApprovable(uint256 requestId) external view returns (bool) {
        CrossChainRequest storage r = crossChainRequests[requestId];
        return
            r.status == Status.Pending &&
            block.timestamp <= r.initiatedAt + APPROVAL_WINDOW;
    }

    /**
     * @notice Returns the amount of native Ether currently custodied by this
     *         contract. Should always be greater than or equal to the wrapped
     *         token supply because cross-chain transfers leave the equivalent
     *         native value held in custody on the source chain.
     */
    function custodiedNative() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Convenience getter for the next request id that will be assigned.
     */
    function nextRequestId() external view returns (uint256) {
        return _nextRequestId;
    }

    /**
     * @notice Fallback that mints wrapped tokens for any native Ether sent
     *         directly to the contract without calldata.
     */
    receive() external payable {
        deposit();
    }
}
