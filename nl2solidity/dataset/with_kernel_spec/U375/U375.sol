// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrossChainMessenger
 * @notice Facilitates cross-chain message passing between Layer 1 and Layer 2.
 *         The contract itself does not custody any assets; it merely tracks
 *         the lifecycle of messages (pending -> relayed | failed) and restricts
 *         the right to relay or attest failures to a permissioned set of relayers.
 */
contract CrossChainMessenger {
    // --------------------------------------------------------------------------------------------
    // Enums
    // --------------------------------------------------------------------------------------------

    enum Status {
        NonExistent, // 0 — default value, indicates no record exists for the hash
        Pending, // 1 — message has been initiated on L1, awaiting relay to L2
        Relayed, // 2 — message has been successfully relayed to L2
        Failed // 3 — message relay to L2 was proven to have failed
    }

    // --------------------------------------------------------------------------------------------
    // Events
    // --------------------------------------------------------------------------------------------

    /// @notice Emitted when a caller initiates a new cross-chain message on L1.
    event MessageInitiated(
        bytes32 indexed messageHash,
        address indexed sender,
        bytes message,
        uint256 blockNumber
    );

    /// @notice Emitted when an authorized relayer successfully relays a message to L2.
    event MessageRelayed(
        bytes32 indexed messageHash,
        address indexed relayer,
        address indexed sender,
        bytes message
    );

    /// @notice Emitted when an authorized relayer proves that a message failed on L2.
    event MessageRelayFailed(
        bytes32 indexed messageHash,
        address indexed relayer,
        address indexed sender,
        bytes message,
        string reason
    );

    /// @notice Emitted when the owner updates the relay fee.
    event RelayFeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when the owner authorizes or revokes a relayer.
    event RelayerAuthorizationUpdated(address indexed relayer, bool authorized);

    /// @notice Emitted when ownership is transferred.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --------------------------------------------------------------------------------------------
    // Errors
    // --------------------------------------------------------------------------------------------

    error RelayerNotAuthorized(address caller);
    error MessageAlreadyExists(bytes32 messageHash);
    error MessageDoesNotExist(bytes32 messageHash);
    error MessageNotPending(bytes32 messageHash);
    error InsufficientRelayFee(uint256 required, uint256 provided);
    error RelayFeeTooLow(uint256 provided, uint256 minimum);
    error NotEnoughBlocksPassed(uint256 required, uint256 elapsed);
    error ZeroAddress();
    error FeeTransferFailed();
    error NotOwner();
    error DirectDepositNotAllowed();

    // --------------------------------------------------------------------------------------------
    // State
    // --------------------------------------------------------------------------------------------

    /// @notice Minimum relay fee enforceable by the owner (0.001 ether).
    uint256 public constant MIN_RELAY_FEE = 0.001 ether;

    /// @notice Number of L1 blocks that must pass after initiation before a message may be relayed.
    uint256 public constant RELAY_DELAY_BLOCKS = 100;

    struct MessageRecord {
        Status status;
        uint256 blockNumber;
    }

    /// @notice Current relay fee (in wei) charged upon message initiation and forwarded to the owner.
    uint256 public relayFee;

    /// @notice Mapping of message hash -> record describing its lifecycle on L1.
    mapping(bytes32 => MessageRecord) internal _messages;

    /// @notice Mapping of relayer address -> authorized flag.
    mapping(address => bool) internal _authorizedRelayers;

    /// @notice The owner of the contract.
    address public owner;

    // --------------------------------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------------------------------

    /**
     * @param _relayFee The initial relay fee in wei; must be >= MIN_RELAY_FEE.
     * @param _owner The address that will own the contract and manage configuration.
     */
    constructor(uint256 _relayFee, address _owner) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_relayFee < MIN_RELAY_FEE) revert RelayFeeTooLow(_relayFee, MIN_RELAY_FEE);
        owner = _owner;
        relayFee = _relayFee;
        emit OwnershipTransferred(address(0), _owner);
        emit RelayFeeUpdated(0, _relayFee);
    }

    // --------------------------------------------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAuthorizedRelayer() {
        if (!_authorizedRelayers[msg.sender]) revert RelayerNotAuthorized(msg.sender);
        _;
    }

    // --------------------------------------------------------------------------------------------
    // External — Message lifecycle
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Initiates a new cross-chain message on L1.
     * @dev The caller must attach at least the current `relayFee` in native value; this fee is
     *      forwarded immediately to the owner so the contract never custodies funds between
     *      transactions. The message hash is derived from (msg.sender, message, block.number),
     *      which uniquely identifies a message initiated by `msg.sender` in the current block.
     * @param message Arbitrary payload intended to be delivered on Layer 2.
     * @return messageHash The hash identifying the newly initiated message.
     */
    function initiateMessage(bytes calldata message) external payable returns (bytes32 messageHash) {
        if (msg.value < relayFee) revert InsufficientRelayFee(relayFee, msg.value);

        messageHash = keccak256(abi.encodePacked(msg.sender, message, block.number));
        if (_messages[messageHash].status != Status.NonExistent) {
            revert MessageAlreadyExists(messageHash);
        }

        // Effects: store the pending record before any external interaction.
        _messages[messageHash] = MessageRecord({
            status: Status.Pending,
            blockNumber: block.number
        });

        // Interactions: forward the fee to the owner immediately so the contract retains no custody.
        if (msg.value > 0) {
            (bool ok, ) = owner.call{value: msg.value}("");
            if (!ok) revert FeeTransferFailed();
        }

        emit MessageInitiated(messageHash, msg.sender, message, block.number);
    }

    /**
     * @notice Relays a previously initiated message to Layer 2. Restricted to authorized relayers.
     * @dev A message may only be relayed once at least `RELAY_DELAY_BLOCKS` L1 blocks have elapsed
     *      since its initiation. The message must currently be in the `Pending` state.
     * @param sender The original initiator of the message on L1.
     * @param message The original message payload.
     * @param blockNumber The L1 block number at which the message was initiated.
     */
    function relayMessage(address sender, bytes calldata message, uint256 blockNumber)
        external
        onlyAuthorizedRelayer
    {
        bytes32 messageHash = keccak256(abi.encodePacked(sender, message, blockNumber));
        MessageRecord memory record = _messages[messageHash];
        if (record.status == Status.NonExistent) revert MessageDoesNotExist(messageHash);
        if (record.status != Status.Pending) revert MessageNotPending(messageHash);

        uint256 elapsed = block.number - record.blockNumber;
        if (elapsed < RELAY_DELAY_BLOCKS) {
            revert NotEnoughBlocksPassed(RELAY_DELAY_BLOCKS, elapsed);
        }

        _messages[messageHash].status = Status.Relayed;
        emit MessageRelayed(messageHash, msg.sender, sender, message);
    }

    /**
     * @notice Proves that a message has failed to be delivered on Layer 2. Restricted to authorized
     *         relayers. The message must currently be in the `Pending` state. Unlike `relayMessage`,
     *         no minimum block delay is enforced, as failures may be attested at any time.
     * @param sender The original initiator of the message on L1.
     * @param message The original message payload.
     * @param blockNumber The L1 block number at which the message was initiated.
     * @param reason A human-readable description of the failure reason.
     */
    function proveMessageFailed(
        address sender,
        bytes calldata message,
        uint256 blockNumber,
        string calldata reason
    ) external onlyAuthorizedRelayer {
        bytes32 messageHash = keccak256(abi.encodePacked(sender, message, blockNumber));
        MessageRecord memory record = _messages[messageHash];
        if (record.status == Status.NonExistent) revert MessageDoesNotExist(messageHash);
        if (record.status != Status.Pending) revert MessageNotPending(messageHash);

        _messages[messageHash].status = Status.Failed;
        emit MessageRelayFailed(messageHash, msg.sender, sender, message, reason);
    }

    // --------------------------------------------------------------------------------------------
    // External — Admin (owner only)
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Updates the relay fee. The new fee must be at least `MIN_RELAY_FEE`.
     * @param newFee The new relay fee in wei.
     */
    function setRelayFee(uint256 newFee) external onlyOwner {
        if (newFee < MIN_RELAY_FEE) revert RelayFeeTooLow(newFee, MIN_RELAY_FEE);
        uint256 oldFee = relayFee;
        relayFee = newFee;
        emit RelayFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Authorizes or revokes a relayer address. Revoking a currently-authorized relayer
     *         is allowed. The zero address is not permitted.
     * @param relayer The relayer address whose authorization should change.
     * @param authorized True to authorize, false to revoke.
     */
    function setRelayerAuthorization(address relayer, bool authorized) external onlyOwner {
        if (relayer == address(0)) revert ZeroAddress();
        _authorizedRelayers[relayer] = authorized;
        emit RelayerAuthorizationUpdated(relayer, authorized);
    }

    /**
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // --------------------------------------------------------------------------------------------
    // External — View
    // --------------------------------------------------------------------------------------------

    /// @notice Returns whether the given address is an authorized relayer.
    function isAuthorizedRelayer(address relayer) external view returns (bool) {
        return _authorizedRelayers[relayer];
    }

    /// @notice Returns the current status and initiation block number for a given message hash.
    function getMessage(bytes32 messageHash) external view returns (Status status, uint256 blockNumber) {
        MessageRecord memory record = _messages[messageHash];
        return (record.status, record.blockNumber);
    }

    /// @notice Returns the status of a given message hash.
    function messageStatus(bytes32 messageHash) external view returns (Status) {
        return _messages[messageHash].status;
    }

    /// @notice Returns the L1 block number at which a given message was initiated.
    function messageBlockNumber(bytes32 messageHash) external view returns (uint256) {
        return _messages[messageHash].blockNumber;
    }

    /// @notice Pure helper to deterministically compute a message hash off-chain or on-chain.
    function computeMessageHash(address sender, bytes calldata message, uint256 blockNumber)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(sender, message, blockNumber));
    }

    // --------------------------------------------------------------------------------------------
    // Receive / Fallback
    // --------------------------------------------------------------------------------------------

    /// @dev Reject direct ETH transfers; the contract is non-custodial.
    receive() external payable {
        revert DirectDepositNotAllowed();
    }

    fallback() external payable {
        revert DirectDepositNotAllowed();
    }
}
