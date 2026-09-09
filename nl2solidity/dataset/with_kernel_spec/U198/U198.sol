// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CrossChainTransferHub
 * @notice A secure hub that temporarily holds fungible tokens during cross-chain
 *         bridging operations. Users deposit tokens, an operator approves or
 *         rejects the transfer, and recipients claim within 72 hours of approval.
 *         Unclaimed transfers are auto-cancelled and refunded. A flat fee of
 *         0.1% (configurable by the operator) is deducted from each transfer.
 */
contract CrossChainTransferHub {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant CLAIM_WINDOW = 72 hours;
    uint256 public constant DEFAULT_FEE_BPS = 10; // 0.1%
    uint256 public constant MAX_FEE_BPS = 1000; // 10%

    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    enum Status {
        Pending,
        Approved,
        Claimed,
        Cancelled,
        Rejected,
        Expired
    }

    struct TransferRequest {
        address user;
        address token;
        address recipient;
        uint256 amount;
        uint256 fee;
        uint256 destinationChain;
        Status status;
        uint256 approvalTime;
        uint256 createdAt;
    }

    // ---------------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------------

    address public operator;
    uint256 public feeBps;
    uint256 public transferCount;

    mapping(address => bool) public supportedTokens;
    mapping(uint256 => TransferRequest) public transfers;
    mapping(address => uint256[]) public userTransfers;

    uint256 private _reentrancyStatus;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event TransferInitiated(
        uint256 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 destinationChain,
        address recipient
    );

    event TransferApproved(
        uint256 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event TransferClaimed(
        uint256 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 netAmount,
        address recipient
    );

    event TransferCancelled(
        uint256 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount,
        Status status
    );

    event TransferRejected(
        uint256 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event TokenSupportUpdated(address indexed token, bool supported);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------------

    error NotOperator();
    error UnsupportedToken(address token);
    error ZeroAmount();
    error ZeroAddress();
    error InvalidFeeBps(uint256 feeBps);
    error InvalidRecipient();
    error TransferNotFound(uint256 transferId);
    error TransferNotPending(uint256 transferId, Status currentStatus);
    error TransferNotApproved(uint256 transferId, Status currentStatus);
    error NotTransferOwner(address caller, uint256 transferId);
    error ClaimDeadlinePassed(uint256 transferId, uint256 deadline);
    error ClaimDeadlineNotPassed(uint256 transferId, uint256 deadline);
    error ReentrancyDetected();
    error TransferFailed(address token, address to, uint256 amount);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == 2) revert ReentrancyDetected();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        feeBps = DEFAULT_FEE_BPS;
        _reentrancyStatus = 1;
        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, feeBps);
    }

    // ---------------------------------------------------------------------
    // User Functions
    // ---------------------------------------------------------------------

    /**
     * @notice Initiates a cross-chain transfer by depositing tokens into custody.
     * @param token            The ERC-20 token to bridge.
     * @param amount           The total amount of tokens to transfer (fee included).
     * @param destinationChain The destination chain identifier.
     * @param recipient        The recipient address on the destination chain.
     * @return transferId      The unique identifier of the created transfer.
     */
    function initiateTransfer(
        address token,
        uint256 amount,
        uint256 destinationChain,
        address recipient
    ) external nonReentrant returns (uint256 transferId) {
        if (!supportedTokens[token]) revert UnsupportedToken(token);
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert InvalidRecipient();

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        _safeTransferFrom(token, msg.sender, address(this), amount);

        transferId = ++transferCount;
        transfers[transferId] = TransferRequest({
            user: msg.sender,
            token: token,
            recipient: recipient,
            amount: amount,
            fee: fee,
            destinationChain: destinationChain,
            status: Status.Pending,
            approvalTime: 0,
            createdAt: block.timestamp
        });
        userTransfers[msg.sender].push(transferId);

        emit TransferInitiated(transferId, msg.sender, token, amount, fee, destinationChain, recipient);
    }

    /**
     * @notice Claims an approved transfer, sending net tokens to the recipient and
     *         the fee to the operator. Reverts if the 72-hour claim window has expired.
     * @param transferId The ID of the transfer to claim.
     */
    function claimTransfer(uint256 transferId) external nonReentrant {
        TransferRequest storage t = transfers[transferId];
        if (t.user == address(0)) revert TransferNotFound(transferId);
        if (t.status != Status.Approved) revert TransferNotApproved(transferId, t.status);

        uint256 deadline = t.approvalTime + CLAIM_WINDOW;
        if (block.timestamp > deadline) revert ClaimDeadlinePassed(transferId, deadline);

        t.status = Status.Claimed;
        uint256 netAmount = t.amount - t.fee;

        _safeTransfer(t.token, t.recipient, netAmount);
        if (t.fee > 0) {
            _safeTransfer(t.token, operator, t.fee);
        }

        emit TransferClaimed(transferId, t.user, t.token, t.amount, netAmount, t.recipient);
    }

    /**
     * @notice Cancels a pending transfer and refunds the deposited tokens.
     *         Only callable by the transfer initiator while the transfer is still Pending.
     * @param transferId The ID of the transfer to cancel.
     */
    function cancelTransfer(uint256 transferId) external nonReentrant {
        TransferRequest storage t = transfers[transferId];
        if (t.user == address(0)) revert TransferNotFound(transferId);
        if (t.user != msg.sender) revert NotTransferOwner(msg.sender, transferId);
        if (t.status != Status.Pending) revert TransferNotPending(transferId, t.status);

        t.status = Status.Cancelled;
        _safeTransfer(t.token, t.user, t.amount);

        emit TransferCancelled(transferId, t.user, t.token, t.amount, Status.Cancelled);
    }

    /**
     * @notice Automatically cancels and refunds an approved transfer whose 72-hour
     *         claim window has expired. Callable by anyone.
     * @param transferId The ID of the transfer to expire.
     */
    function autoCancelExpired(uint256 transferId) external nonReentrant {
        TransferRequest storage t = transfers[transferId];
        if (t.user == address(0)) revert TransferNotFound(transferId);
        if (t.status != Status.Approved) revert TransferNotApproved(transferId, t.status);

        uint256 deadline = t.approvalTime + CLAIM_WINDOW;
        if (block.timestamp <= deadline) revert ClaimDeadlineNotPassed(transferId, deadline);

        t.status = Status.Expired;
        _safeTransfer(t.token, t.user, t.amount);

        emit TransferCancelled(transferId, t.user, t.token, t.amount, Status.Expired);
    }

    // ---------------------------------------------------------------------
    // Operator Functions
    // ---------------------------------------------------------------------

    /**
     * @notice Approves a pending cross-chain transfer request.
     * @param transferId The ID of the transfer to approve.
     */
    function approveTransfer(uint256 transferId) external onlyOperator {
        TransferRequest storage t = transfers[transferId];
        if (t.user == address(0)) revert TransferNotFound(transferId);
        if (t.status != Status.Pending) revert TransferNotPending(transferId, t.status);

        t.status = Status.Approved;
        t.approvalTime = block.timestamp;

        emit TransferApproved(transferId, t.user, t.token, t.amount);
    }

    /**
     * @notice Rejects a pending cross-chain transfer and refunds the user.
     * @param transferId The ID of the transfer to reject.
     */
    function rejectTransfer(uint256 transferId) external onlyOperator nonReentrant {
        TransferRequest storage t = transfers[transferId];
        if (t.user == address(0)) revert TransferNotFound(transferId);
        if (t.status != Status.Pending) revert TransferNotPending(transferId, t.status);

        t.status = Status.Rejected;
        _safeTransfer(t.token, t.user, t.amount);

        emit TransferRejected(transferId, t.user, t.token, t.amount);
    }

    /**
     * @notice Adds or removes a token from the supported list.
     * @param token     The token address.
     * @param supported Whether the token should be supported.
     */
    function setTokenSupport(address token, bool supported) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        supportedTokens[token] = supported;
        emit TokenSupportUpdated(token, supported);
    }

    /**
     * @notice Updates the flat fee (in basis points) applied to all transfers.
     * @param newFeeBps The new fee in basis points (max 1000 = 10%).
     */
    function setFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFeeBps(newFeeBps);
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Updates the operator address.
     * @param newOperator The new operator address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    // ---------------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the full transfer request details.
     * @param transferId The transfer ID.
     */
    function getTransfer(uint256 transferId) external view returns (TransferRequest memory) {
        return transfers[transferId];
    }

    /**
     * @notice Returns the list of transfer IDs created by a user.
     * @param user The user address.
     */
    function getUserTransfers(address user) external view returns (uint256[] memory) {
        return userTransfers[user];
    }

    /**
     * @notice Returns the claim deadline for an approved transfer.
     * @param transferId The transfer ID.
     * @return The timestamp after which the transfer can be auto-cancelled.
     */
    function claimDeadlineOf(uint256 transferId) external view returns (uint256) {
        return transfers[transferId].approvalTime + CLAIM_WINDOW;
    }

    /**
     * @notice Checks whether an approved transfer's claim window has expired.
     * @param transferId The transfer ID.
     * @return True if the transfer is approved and the claim window has passed.
     */
    function isExpired(uint256 transferId) external view returns (bool) {
        TransferRequest storage t = transfers[transferId];
        return t.status == Status.Approved && block.timestamp > t.approvalTime + CLAIM_WINDOW;
    }

    /**
     * @notice Computes the fee and net amount for a given token and amount.
     * @param token  The token address (must be supported).
     * @param amount The gross amount.
     * @return fee      The fee deducted.
     * @return netAmount The amount the recipient would receive.
     */
    function quoteFee(address token, uint256 amount) external view returns (uint256 fee, uint256 netAmount) {
        if (!supportedTokens[token]) revert UnsupportedToken(token);
        fee = (amount * feeBps) / BPS_DENOMINATOR;
        netAmount = amount - fee;
    }

    // ---------------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------------

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        if (!_isContract(token)) revert TransferFailed(token, to, amount);
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed(token, to, amount);
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed(token, to, amount);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        if (!_isContract(token)) revert TransferFailed(token, to, amount);
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert TransferFailed(token, to, amount);
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed(token, to, amount);
    }
}
