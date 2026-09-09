// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedIdentityRegistry
 * @notice Registry that manages attestations of human uniqueness.
 * @dev The contract custodying no assets. It records registered identities,
 *      their verified status, the timestamp of the last verification, and
 *      pending proof submissions. A privileged operator can approve or reject
 *      submitted proofs and revoke an identity's verified status. Verification
 *      is valid for 365 days after approval; at most 10,000 identities may be
 *      registered.
 */
contract DecentralizedIdentityRegistry {
    // --------------------------------------------------------------------------------------------
    // Constants
    // --------------------------------------------------------------------------------------------

    /// @dev Maximum number of identities that can ever be registered.
    uint256 public constant MAX_IDENTITIES = 10_000;

    /// @dev Duration (in seconds) for which a verification remains valid after approval.
    uint256 public constant VERIFICATION_VALIDITY = 365 days;

    // --------------------------------------------------------------------------------------------
    // Storage
    // --------------------------------------------------------------------------------------------

    /// @dev Internal representation of a registered identity.
    struct Identity {
        bool registered;
        bool verified;
        bool pendingProof;
        uint256 lastVerification;
    }

    mapping(address => Identity) private _identities;
    address[] private _identityList;
    mapping(address => uint256) private _identityIndex;

    uint256 public identityCount;
    address public owner;
    address public operator;

    // --------------------------------------------------------------------------------------------
    // Events
    // --------------------------------------------------------------------------------------------

    event IdentityRegistered(address indexed identity, uint256 timestamp);
    event ProofSubmitted(address indexed identity, address indexed submitter, uint256 timestamp);
    event VerificationStatusChanged(address indexed identity, bool indexed status, uint256 timestamp);
    event VerificationRevoked(address indexed identity, address indexed by, uint256 timestamp);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --------------------------------------------------------------------------------------------
    // Errors
    // --------------------------------------------------------------------------------------------

    error ZeroAddress();
    error IdentityAlreadyRegistered();
    error IdentityNotRegistered();
    error MaxIdentitiesReached();
    error NotOwner();
    error NotOperator();
    error ProofAlreadySubmitted();
    error NoProofSubmitted();
    error NotVerified();

    // --------------------------------------------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // --------------------------------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------------------------------

    /// @param _owner Initial contract owner.
    /// @param _operator Initial operator authorized to approve, reject, and revoke.
    constructor(address _owner, address _operator) {
        if (_owner == address(0) || _operator == address(0)) revert ZeroAddress();
        owner = _owner;
        operator = _operator;
        emit OwnershipTransferred(address(0), _owner);
        emit OperatorChanged(address(0), _operator);
    }

    // --------------------------------------------------------------------------------------------
    // Admin functions
    // --------------------------------------------------------------------------------------------

    /// @notice Transfers contract ownership to a new address.
    /// @param newOwner Address of the new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    /// @notice Sets a new operator authorized to approve, reject, and revoke.
    /// @param newOperator Address of the new operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    // --------------------------------------------------------------------------------------------
    // External functions
    // --------------------------------------------------------------------------------------------

    /// @notice Registers the caller as a new identity in the registry.
    /// @dev Anyone may register; the registry caps total registrations at MAX_IDENTITIES.
    function registerIdentity() external {
        if (_identities[msg.sender].registered) revert IdentityAlreadyRegistered();
        if (identityCount >= MAX_IDENTITIES) revert MaxIdentitiesReached();

        _identities[msg.sender] = Identity({
            registered: true,
            verified: false,
            pendingProof: false,
            lastVerification: 0
        });

        _identityIndex[msg.sender] = _identityList.length;
        _identityList.push(msg.sender);
        identityCount = _identityList.length;

        emit IdentityRegistered(msg.sender, block.timestamp);
    }

    /// @notice Submits a proof of human uniqueness for the caller's registered identity.
    /// @dev Sets the pendingProof flag; the operator is expected to approve or reject it.
    function submitProof() external {
        Identity storage id = _identities[msg.sender];
        if (!id.registered) revert IdentityNotRegistered();
        if (id.pendingProof) revert ProofAlreadySubmitted();

        id.pendingProof = true;
        emit ProofSubmitted(msg.sender, msg.sender, block.timestamp);
    }

    /// @notice Operator approves a submitted proof and marks the identity as verified.
    /// @param identity Address of the identity whose proof is being approved.
    function approveProof(address identity) external onlyOperator {
        Identity storage id = _identities[identity];
        if (!id.registered) revert IdentityNotRegistered();
        if (!id.pendingProof) revert NoProofSubmitted();

        id.pendingProof = false;
        id.verified = true;
        id.lastVerification = block.timestamp;

        emit VerificationStatusChanged(identity, true, block.timestamp);
    }

    /// @notice Operator rejects a submitted proof without granting verified status.
    /// @param identity Address of the identity whose proof is being rejected.
    function rejectProof(address identity) external onlyOperator {
        Identity storage id = _identities[identity];
        if (!id.registered) revert IdentityNotRegistered();
        if (!id.pendingProof) revert NoProofSubmitted();

        id.pendingProof = false;

        emit VerificationStatusChanged(identity, false, block.timestamp);
    }

    /// @notice Operator revokes the verified status of an identity.
    /// @dev The identity remains registered but is no longer verified.
    /// @param identity Address of the identity whose verification is being revoked.
    function revokeVerification(address identity) external onlyOperator {
        Identity storage id = _identities[identity];
        if (!id.registered) revert IdentityNotRegistered();
        if (!id.verified) revert NotVerified();

        id.verified = false;
        id.pendingProof = false;
        id.lastVerification = 0;

        emit VerificationRevoked(identity, msg.sender, block.timestamp);
    }

    // --------------------------------------------------------------------------------------------
    // View functions
    // --------------------------------------------------------------------------------------------

    /// @notice Returns whether an identity is currently verified and within the validity window.
    /// @param identity Address of the identity to query.
    /// @return True if the identity is registered, verified, and verification has not expired.
    function isVerified(address identity) external view returns (bool) {
        Identity storage id = _identities[identity];
        if (!id.registered || !id.verified) return false;
        if (block.timestamp > id.lastVerification + VERIFICATION_VALIDITY) return false;
        return true;
    }

    /// @notice Returns whether an identity is currently registered.
    /// @param identity Address of the identity to query.
    /// @return True if the identity has been registered.
    function isRegistered(address identity) external view returns (bool) {
        return _identities[identity].registered;
    }

    /// @notice Returns whether a proof is pending for the given identity.
    /// @param identity Address of the identity to query.
    /// @return True if there is a pending proof awaiting operator action.
    function hasPendingProof(address identity) external view returns (bool) {
        return _identities[identity].pendingProof;
    }

    /// @notice Returns the full record for a given identity.
    /// @param identity Address of the identity to query.
    /// @return registered Whether the identity is registered.
    /// @return verified Whether the identity is flagged as verified.
    /// @return pendingProof Whether there is a pending proof awaiting operator action.
    /// @return lastVerification Timestamp of the last successful verification.
    /// @return validUntil Timestamp until which the verification is valid (0 if not verified).
    function getIdentity(address identity)
        external
        view
        returns (
            bool registered,
            bool verified,
            bool pendingProof,
            uint256 lastVerification,
            uint256 validUntil
        )
    {
        Identity storage id = _identities[identity];
        registered = id.registered;
        verified = id.verified;
        pendingProof = id.pendingProof;
        lastVerification = id.lastVerification;
        validUntil = id.verified ? id.lastVerification + VERIFICATION_VALIDITY : 0;
    }

    /// @notice Returns the list of all registered identity addresses.
    /// @return The array of registered identity addresses in registration order.
    function getIdentityList() external view returns (address[] memory) {
        return _identityList;
    }
}
