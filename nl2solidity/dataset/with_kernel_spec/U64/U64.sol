// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedIdentityCredentials
 * @notice Tracks user-earned credentials and credential-type definitions for a
 *         decentralized identity system. The contract custodies no off-chain
 *         assets but does collect a small claim fee, withdrawable by the owner.
 */
contract DecentralizedIdentityCredentials {
    /* ------------------------------------------------------------------ */
    /* Constants                                                          */
    /* ------------------------------------------------------------------ */

    /// @notice Maximum number of distinct credential types that may be defined.
    uint256 public constant MAX_CREDENTIAL_TYPES = 10_000;

    /// @notice Fee, in wei, required to claim a single credential.
    uint256 public constant CLAIM_FEE = 0.01 ether;

    /* ------------------------------------------------------------------ */
    /* Custom errors                                                      */
    /* ------------------------------------------------------------------ */

    error Unauthorized();
    error ContractPaused();
    error AlreadyPaused();
    error NotPaused();
    error InvalidAddress();
    error InvalidMetadata();
    error InvalidCredentialType();
    error CredentialTypeLimitReached();
    error CredentialAlreadyEarned();
    error IncorrectFee();
    error CredentialNotFound();
    error NoFeesToWithdraw();
    error WithdrawalFailed();
    error NoCredentialsToTransfer();

    /* ------------------------------------------------------------------ */
    /* Structs                                                            */
    /* ------------------------------------------------------------------ */

    struct CredentialDefinition {
        string name;
        string metadataURI;
        bool active;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct CredentialRecord {
        uint256 credentialId;
        uint256 issuedAt;
        string claimMetadata;
    }

    /* ------------------------------------------------------------------ */
    /* State variables                                                    */
    /* ------------------------------------------------------------------ */

    address public owner;
    bool public paused;
    uint256 public credentialTypeCount;
    uint256 public accumulatedFees;

    mapping(uint256 => CredentialDefinition) public credentialDefinitions;

    mapping(address => mapping(uint256 => CredentialRecord)) private _records;
    mapping(address => mapping(uint256 => bool)) private _earned;
    mapping(address => uint256[]) private _userCredentials;

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CredentialClaimed(address indexed account, uint256 indexed credentialId, uint256 issuedAt);
    event CredentialDefinitionUpdated(uint256 indexed credentialId, string name, string metadataURI, bool active);
    event IdentityTransferred(address indexed from, address indexed to);
    event SystemPaused(address indexed by, uint256 timestamp);
    event SystemUnpaused(address indexed by, uint256 timestamp);
    event FeesWithdrawn(address indexed to, uint256 amount);

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */

    constructor() {
        owner = msg.sender;
        paused = false;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /* ------------------------------------------------------------------ */
    /* Admin functions                                                    */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Halts user-facing credential claims and identity transfers.
     */
    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit SystemPaused(msg.sender, block.timestamp);
    }

    /**
     * @notice Resumes user-facing operations.
     */
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit SystemUnpaused(msg.sender, block.timestamp);
    }

    /**
     * @notice Transfers contract ownership to a new account.
     * @param newOwner Address of the next owner; must not be zero.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @notice Defines a new credential type that can later be claimed.
     * @param name Human-readable name of the credential type.
     * @param metadataURI URI pointing to off-chain metadata.
     * @return credentialId The sequential id assigned to the new type.
     */
    function defineCredentialType(
        string calldata name,
        string calldata metadataURI
    ) external onlyOwner returns (uint256 credentialId) {
        if (bytes(name).length == 0) revert InvalidMetadata();
        if (bytes(metadataURI).length == 0) revert InvalidMetadata();
        if (credentialTypeCount >= MAX_CREDENTIAL_TYPES) revert CredentialTypeLimitReached();

        credentialId = credentialTypeCount;

        credentialDefinitions[credentialId] = CredentialDefinition({
            name: name,
            metadataURI: metadataURI,
            active: true,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        unchecked {
            credentialTypeCount += 1;
        }

        emit CredentialDefinitionUpdated(credentialId, name, metadataURI, true);
    }

    /**
     * @notice Updates the metadata of an existing credential type.
     * @param credentialId Id of the credential type to update.
     * @param name New name.
     * @param metadataURI New metadata URI.
     */
    function updateCredentialDefinition(
        uint256 credentialId,
        string calldata name,
        string calldata metadataURI
    ) external onlyOwner {
        if (credentialId >= credentialTypeCount) revert InvalidCredentialType();
        if (bytes(name).length == 0) revert InvalidMetadata();
        if (bytes(metadataURI).length == 0) revert InvalidMetadata();

        CredentialDefinition storage def = credentialDefinitions[credentialId];
        def.name = name;
        def.metadataURI = metadataURI;
        def.updatedAt = block.timestamp;

        emit CredentialDefinitionUpdated(credentialId, name, metadataURI, def.active);
    }

    /**
     * @notice Activates or deactivates a credential type. Inactive types
     *         cannot be claimed by new users but existing claims persist.
     * @param credentialId Id of the credential type to toggle.
     * @param active New active state.
     */
    function setCredentialActive(uint256 credentialId, bool active) external onlyOwner {
        if (credentialId >= credentialTypeCount) revert InvalidCredentialType();
        CredentialDefinition storage def = credentialDefinitions[credentialId];
        def.active = active;
        def.updatedAt = block.timestamp;
        emit CredentialDefinitionUpdated(credentialId, def.name, def.metadataURI, active);
    }

    /**
     * @notice Withdraws all accumulated claim fees to a recipient.
     * @param to Payable address that will receive the fees.
     */
    function withdrawFees(address payable to) external onlyOwner {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();
        if (to == address(0)) revert InvalidAddress();

        accumulatedFees = 0;

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit FeesWithdrawn(to, amount);
    }

    /* ------------------------------------------------------------------ */
    /* User functions                                                     */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Claims a credential for the caller. The exact claim fee must be
     *         sent and the credential type must be active and unclaimed.
     * @param credentialId Id of the credential type to claim.
     * @param claimMetadata Optional caller-supplied metadata for this claim.
     * @return recordIndex The position of this claim in the caller's history.
     */
    function claimCredential(
        uint256 credentialId,
        string calldata claimMetadata
    ) external payable whenNotPaused returns (uint256 recordIndex) {
        if (msg.value != CLAIM_FEE) revert IncorrectFee();
        if (credentialId >= credentialTypeCount) revert InvalidCredentialType();

        CredentialDefinition storage def = credentialDefinitions[credentialId];
        if (!def.active) revert InvalidCredentialType();
        if (_earned[msg.sender][credentialId]) revert CredentialAlreadyEarned();

        _earned[msg.sender][credentialId] = true;
        _records[msg.sender][credentialId] = CredentialRecord({
            credentialId: credentialId,
            issuedAt: block.timestamp,
            claimMetadata: claimMetadata
        });

        recordIndex = _userCredentials[msg.sender].length;
        _userCredentials[msg.sender].push(credentialId);

        accumulatedFees += msg.value;

        emit CredentialClaimed(msg.sender, credentialId, block.timestamp);
    }

    /**
     * @notice Transfers the caller's identity (all earned credentials) to a
     *         new owner. Credentials already held by the new owner are not
     *         duplicated. The caller's identity is cleared after the transfer.
     * @param newOwner Address that will receive the caller's credentials.
     */
    function transferIdentity(address newOwner) external whenNotPaused {
        if (newOwner == address(0)) revert InvalidAddress();
        if (newOwner == msg.sender) revert InvalidAddress();

        uint256[] storage senderIds = _userCredentials[msg.sender];
        uint256 length = senderIds.length;
        if (length == 0) revert NoCredentialsToTransfer();

        for (uint256 i = 0; i < length; i++) {
            uint256 credentialId = senderIds[i];

            if (!_earned[newOwner][credentialId]) {
                _earned[newOwner][credentialId] = true;
                _records[newOwner][credentialId] = _records[msg.sender][credentialId];
                _userCredentials[newOwner].push(credentialId);
            }

            _earned[msg.sender][credentialId] = false;
            delete _records[msg.sender][credentialId];
        }

        delete _userCredentials[msg.sender];

        emit IdentityTransferred(msg.sender, newOwner);
    }

    /* ------------------------------------------------------------------ */
    /* View functions                                                     */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Returns the number of credentials held by an account.
     */
    function getCredentialCount(address account) external view returns (uint256) {
        return _userCredentials[account].length;
    }

    /**
     * @notice Returns whether an account has claimed a given credential type.
     */
    function hasCredential(address account, uint256 credentialId) external view returns (bool) {
        return _earned[account][credentialId];
    }

    /**
     * @notice Returns the on-chain record for a specific claimed credential.
     */
    function getCredentialRecord(address account, uint256 credentialId)
        external
        view
        returns (CredentialRecord memory)
    {
        if (!_earned[account][credentialId]) revert CredentialNotFound();
        return _records[account][credentialId];
    }

    /**
     * @notice Returns full details of a credential type definition.
     */
    function getCredentialDefinition(uint256 credentialId)
        external
        view
        returns (CredentialDefinition memory)
    {
        if (credentialId >= credentialTypeCount) revert InvalidCredentialType();
        return credentialDefinitions[credentialId];
    }

    /**
     * @notice Returns the full credential history for an account, in claim order.
     */
    function getCredentialHistory(address account)
        external
        view
        returns (CredentialRecord[] memory)
    {
        uint256[] storage ids = _userCredentials[account];
        uint256 length = ids.length;

        CredentialRecord[] memory history = new CredentialRecord[](length);
        for (uint256 i = 0; i < length; i++) {
            history[i] = _records[account][ids[i]];
        }

        return history;
    }

    /**
     * @notice Returns a slice of an account's credential history.
     * @param account Address whose history to page through.
     * @param offset Starting index (inclusive) within the account's history.
     * @param limit Maximum number of records to return.
     */
    function getCredentialHistoryPaginated(
        address account,
        uint256 offset,
        uint256 limit
    ) external view returns (CredentialRecord[] memory page) {
        uint256 total = _userCredentials[account].length;
        if (offset >= total) return new CredentialRecord[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        page = new CredentialRecord[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = _records[account][_userCredentials[account][i]];
        }
    }

    /* ------------------------------------------------------------------ */
    /* Receive                                                            */
    /* ------------------------------------------------------------------ */

    receive() external payable {
        // Direct ETH deposits are treated as additional claim fees that the
        // owner may withdraw; this prevents ETH from being locked in contract.
        accumulatedFees += msg.value;
    }
}
