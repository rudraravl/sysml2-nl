// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrossChainMessenger
 * @dev Facilitates cross-chain message passing without taking custody of assets.
 *      Each message incurs a fixed fee of 0.01 ether and may carry a payload of up
 *      to 2048 bytes. Source chains are tracked via their respective message
 *      verification configurations and per-source-chain nonces.
 */
contract CrossChainMessenger {
    // ---------------------------------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------------------------------

    /// @dev Fixed fee charged for each sent or retried message.
    uint256 public constant FEE = 0.01 ether;

    /// @dev Maximum payload size, in bytes, accepted for any cross-chain message.
    uint256 public constant MAX_PAYLOAD_SIZE = 2048;

    // ---------------------------------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------------------------------

    /// @notice Current contract owner; can set the operator and withdraw accrued fees.
    address public owner;

    /// @notice Designated operator; can update verification configs and report failed messages.
    address public operator;

    /// @notice Per-source-chain message verification configuration.
    mapping(uint256 => MessageVerificationConfig) public messageVerificationConfigs;

    /// @notice Global message nonce tracked for each source chain.
    mapping(uint256 => uint256) public nonces;

    /// @notice Detailed record of every message dispatched from this contract.
    mapping(bytes32 => Message) public messages;

    /// @notice Marks a message as having failed delivery so it can be retried.
    mapping(bytes32 => bool) public failedMessages;

    // ---------------------------------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------------------------------

    struct MessageVerificationConfig {
        uint256 threshold;             // Minimum signatures required for verification.
        uint256 requiredConfirmations; // Number of confirmations needed for finality.
        bool enabled;                   // Whether messages from this source chain are accepted.
        bytes32 configHash;            // Off-chain commitment hash for additional verification data.
    }

    struct Message {
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sender;
        address recipient;
        bytes payload;
        uint256 nonce;
        uint64 sentAt;
    }

    // ---------------------------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------------------------

    event MessageSent(
        bytes32 indexed messageId,
        uint256 indexed sourceChainId,
        uint256 indexed destinationChainId,
        address sender,
        address recipient,
        uint256 nonce
    );

    event MessageDelivered(
        bytes32 indexed messageId,
        uint256 indexed destinationChainId,
        address recipient,
        bytes32 indexed deliveryHash
    );

    event MessageFailed(
        bytes32 indexed messageId,
        uint256 indexed destinationChainId,
        address recipient,
        string reason,
        bytes32 indexed failureHash
    );

    event MessageRetried(
        bytes32 indexed originalMessageId,
        bytes32 indexed newMessageId,
        uint256 nonce
    );

    event VerificationConfigUpdated(
        uint256 indexed sourceChainId,
        uint256 threshold,
        uint256 requiredConfirmations,
        bool enabled,
        bytes32 configHash
    );

    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ---------------------------------------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error NotMessageSender();
    error PayloadTooLarge(uint256 size, uint256 maxSize);
    error InsufficientFee(uint256 provided, uint256 required);
    error InvalidRecipient();
    error InvalidDestinationChain();
    error InvalidSourceChain();
    error InvalidThreshold();
    error InvalidConfirmations();
    error ZeroAddress();
    error MessageNotFound();
    error MessageNotFailed();
    error MessageAlreadyDelivered();
    error SourceChainDisabled(uint256 sourceChainId);
    error TransferFailed();

    // ---------------------------------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------------------------

    constructor(address initialOperator) {
        owner = msg.sender;
        operator = initialOperator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), initialOperator);
    }

    // ---------------------------------------------------------------------------------------------
    // External Functions - Message Lifecycle
    // ---------------------------------------------------------------------------------------------

    /**
     * @notice Sends a message to a recipient on a destination chain.
     * @param destinationChainId The identifier of the destination chain.
     * @param recipient The recipient address on the destination chain.
     * @param payload The message payload; must be at most MAX_PAYLOAD_SIZE bytes.
     * @return messageId The unique identifier assigned to this message.
     */
    function sendMessage(
        uint256 destinationChainId,
        address recipient,
        bytes calldata payload
    ) external payable returns (bytes32 messageId) {
        if (msg.value < FEE) revert InsufficientFee(msg.value, FEE);
        if (recipient == address(0)) revert InvalidRecipient();
        if (destinationChainId == 0) revert InvalidDestinationChain();
        if (payload.length > MAX_PAYLOAD_SIZE) revert PayloadTooLarge(payload.length, MAX_PAYLOAD_SIZE);

        uint256 sourceChainId = block.chainid;
        _ensureSourceChainEnabled(sourceChainId);

        uint256 nonce = nonces[sourceChainId];
        nonces[sourceChainId] = nonce + 1;

        messageId = _computeMessageId(sourceChainId, destinationChainId, msg.sender, recipient, payload, nonce);

        messages[messageId] = Message({
            sourceChainId: sourceChainId,
            destinationChainId: destinationChainId,
            sender: msg.sender,
            recipient: recipient,
            payload: payload,
            nonce: nonce,
            sentAt: uint64(block.timestamp)
        });

        emit MessageSent(messageId, sourceChainId, destinationChainId, msg.sender, recipient, nonce);

        // Return any excess fee paid to the caller.
        uint256 excess = msg.value - FEE;
        if (excess > 0) {
            _sendNative(msg.sender, excess);
        }
    }

    /**
     * @notice Retries a previously failed message by issuing a new message with a fresh nonce.
     *         The original failure marker is cleared and a new message record is created.
     * @param messageId The unique identifier of the previously failed message.
     * @return newMessageId The unique identifier assigned to the retried message.
     */
    function retryFailedMessage(bytes32 messageId) external payable returns (bytes32 newMessageId) {
        if (msg.value < FEE) revert InsufficientFee(msg.value, FEE);
        if (!failedMessages[messageId]) revert MessageNotFailed();

        Message storage original = messages[messageId];
        if (original.sender == address(0)) revert MessageNotFound();
        if (msg.sender != original.sender) revert NotMessageSender();

        uint256 sourceChainId = block.chainid;
        _ensureSourceChainEnabled(sourceChainId);

        uint256 nonce = nonces[sourceChainId];
        nonces[sourceChainId] = nonce + 1;

        newMessageId = _computeMessageId(
            sourceChainId,
            original.destinationChainId,
            original.sender,
            original.recipient,
            original.payload,
            nonce
        );

        messages[newMessageId] = Message({
            sourceChainId: sourceChainId,
            destinationChainId: original.destinationChainId,
            sender: original.sender,
            recipient: original.recipient,
            payload: original.payload,
            nonce: nonce,
            sentAt: uint64(block.timestamp)
        });

        failedMessages[messageId] = false;

        emit MessageRetried(messageId, newMessageId, nonce);
        emit MessageSent(
            newMessageId,
            sourceChainId,
            original.destinationChainId,
            original.sender,
            original.recipient,
            nonce
        );

        uint256 excess = msg.value - FEE;
        if (excess > 0) {
            _sendNative(msg.sender, excess);
        }
    }

    /**
     * @notice Reports a successful delivery of a previously dispatched message. Intended to be
     *         invoked by off-chain observers or relayers; verification of the reporter is the
     *         responsibility of the integrator.
     * @param messageId The unique identifier of the delivered message.
     * @param deliveryHash Optional hash of any delivery receipt data emitted alongside the event.
     */
    function reportDelivery(bytes32 messageId, bytes32 deliveryHash) external {
        Message storage m = messages[messageId];
        if (m.sender == address(0)) revert MessageNotFound();
        if (failedMessages[messageId]) revert MessageAlreadyDelivered();

        emit MessageDelivered(messageId, m.destinationChainId, m.recipient, deliveryHash);
    }

    /**
     * @notice Reports a failed delivery attempt for a previously dispatched message. Only the
     *         designated operator may report failures to prevent spurious failure claims.
     * @param messageId The unique identifier of the message whose delivery failed.
     * @param reason A human-readable description of the failure reason.
     * @param failureHash Optional commitment hash for additional off-chain evidence.
     */
    function reportFailure(
        bytes32 messageId,
        string calldata reason,
        bytes32 failureHash
    ) external onlyOperator {
        Message storage m = messages[messageId];
        if (m.sender == address(0)) revert MessageNotFound();
        if (failedMessages[messageId]) revert MessageAlreadyDelivered();

        failedMessages[messageId] = true;

        emit MessageFailed(messageId, m.destinationChainId, m.recipient, reason, failureHash);
    }

    // ---------------------------------------------------------------------------------------------
    // External Functions - Configuration
    // ---------------------------------------------------------------------------------------------

    /**
     * @notice Updates the message verification configuration for a specific source chain.
     *         Only the designated operator may perform this action.
     * @param sourceChainId The identifier of the source chain being configured.
     * @param threshold Minimum signatures required to verify a message from this chain.
     * @param requiredConfirmations Confirmations needed for finality on the source chain.
     * @param enabled Whether messages from this source chain are accepted.
     * @param configHash Off-chain commitment hash for additional verification data.
     */
    function updateMessageVerificationConfig(
        uint256 sourceChainId,
        uint256 threshold,
        uint256 requiredConfirmations,
        bool enabled,
        bytes32 configHash
    ) external onlyOperator {
        if (sourceChainId == 0) revert InvalidSourceChain();
        if (threshold == 0) revert InvalidThreshold();
        if (requiredConfirmations == 0) revert InvalidConfirmations();

        messageVerificationConfigs[sourceChainId] = MessageVerificationConfig({
            threshold: threshold,
            requiredConfirmations: requiredConfirmations,
            enabled: enabled,
            configHash: configHash
        });

        emit VerificationConfigUpdated(sourceChainId, threshold, requiredConfirmations, enabled, configHash);
    }

    /**
     * @notice Sets a new operator. Only the contract owner may perform this action.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    /**
     * @notice Transfers contract ownership to a new account.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    /**
     * @notice Withdraws accrued fees to the designated recipient. Only callable by the owner.
     * @param to The address that will receive the withdrawn fees.
     */
    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount == 0) return;
        _sendNative(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    // ---------------------------------------------------------------------------------------------
    // External Functions - Views
    // ---------------------------------------------------------------------------------------------

    /**
     * @notice Returns the full message record for a given identifier.
     */
    function getMessage(bytes32 messageId) external view returns (Message memory) {
        return messages[messageId];
    }

    /**
     * @notice Returns the verification configuration for a given source chain.
     */
    function getVerificationConfig(uint256 sourceChainId) external view returns (MessageVerificationConfig memory) {
        return messageVerificationConfigs[sourceChainId];
    }

    /**
     * @notice Returns the next nonce that will be assigned for the current chain.
     */
    function currentNonce() external view returns (uint256) {
        return nonces[block.chainid];
    }

    /**
     * @notice Returns the accrued fee balance available for withdrawal.
     */
    function accruedFees() external view returns (uint256) {
        return address(this).balance;
    }

    // ---------------------------------------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------------------------------------

    /**
     * @dev Computes a deterministic unique identifier for a message.
     */
    function _computeMessageId(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sender,
        address recipient,
        bytes memory payload,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                sourceChainId,
                destinationChainId,
                sender,
                recipient,
                nonce,
                keccak256(payload)
            )
        );
    }

    /**
     * @dev Reverts if the source chain's configuration is not enabled.
     */
    function _ensureSourceChainEnabled(uint256 sourceChainId) internal view {
        MessageVerificationConfig storage config = messageVerificationConfigs[sourceChainId];
        if (!config.enabled) revert SourceChainDisabled(sourceChainId);
    }

    /**
     * @dev Safely transfers native currency to a recipient, reverting on failure.
     */
    function _sendNative(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
