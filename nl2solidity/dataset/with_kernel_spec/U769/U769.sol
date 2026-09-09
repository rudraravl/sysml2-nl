// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedIdentityRegistry
 * @notice Custodies unique identity tokens representing verified human identities.
 *         Allows registration, verification updates, status queries, operator-driven
 *         pausing/unpausing of registrations, and revocation of fraudulent identities.
 *         New registrations are limited to 100 per day.
 */
contract DecentralizedIdentityRegistry {
    struct Identity {
        bytes32 uniqueIdentifier;
        uint256 lastVerificationTimestamp;
        bool active;
    }

    address public operator;

    bool public registrationsPaused;

    uint256 public totalRegisteredIdentities;

    uint256 public constant DAILY_REGISTRATION_LIMIT = 100;

    mapping(address => Identity) private s_identities;
    mapping(bytes32 => address) private s_identifierToOwner;
    mapping(uint256 => uint256) private s_dailyRegistrationCount;

    event IdentityRegistered(address indexed account, bytes32 indexed uniqueIdentifier, uint256 timestamp);
    event IdentityVerificationUpdated(address indexed account, bytes32 indexed uniqueIdentifier, uint256 timestamp);
    event IdentityRevoked(address indexed account, bytes32 indexed uniqueIdentifier, uint256 timestamp);
    event RegistrationsPaused(address indexed operator);
    event RegistrationsUnpaused(address indexed operator);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error RegistrationsArePaused();
    error RegistrationsAreNotPaused();
    error IdentityAlreadyExists(address account);
    error IdentifierAlreadyInUse(bytes32 uniqueIdentifier);
    error IdentityDoesNotExist(address account);
    error IdentityNotActive(address account);
    error InvalidProofOfUniqueness();
    error DailyRegistrationLimitReached();
    error ZeroAddress();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenRegistrationsNotPaused() {
        if (registrationsPaused) revert RegistrationsArePaused();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorTransferred(address(0), _operator);
    }

    function registerIdentity(bytes32 uniqueIdentifier, bytes32 proofOfUniqueness)
        external
        whenRegistrationsNotPaused
    {
        if (msg.sender == address(0)) revert ZeroAddress();
        if (s_identities[msg.sender].active) revert IdentityAlreadyExists(msg.sender);
        if (uniqueIdentifier == bytes32(0)) revert InvalidProofOfUniqueness();
        if (s_identifierToOwner[uniqueIdentifier] != address(0)) revert IdentifierAlreadyInUse(uniqueIdentifier);
        if (!_verifyProofOfUniqueness(uniqueIdentifier, proofOfUniqueness)) revert InvalidProofOfUniqueness();

        uint256 currentDay = block.timestamp / 1 days;
        if (s_dailyRegistrationCount[currentDay] >= DAILY_REGISTRATION_LIMIT) {
            revert DailyRegistrationLimitReached();
        }

        s_dailyRegistrationCount[currentDay] += 1;
        s_identifierToOwner[uniqueIdentifier] = msg.sender;
        s_identities[msg.sender] = Identity({
            uniqueIdentifier: uniqueIdentifier,
            lastVerificationTimestamp: block.timestamp,
            active: true
        });

        totalRegisteredIdentities += 1;

        emit IdentityRegistered(msg.sender, uniqueIdentifier, block.timestamp);
    }

    function updateVerificationTimestamp() external {
        Identity storage identity = s_identities[msg.sender];
        if (identity.uniqueIdentifier == bytes32(0)) revert IdentityDoesNotExist(msg.sender);
        if (!identity.active) revert IdentityNotActive(msg.sender);

        identity.lastVerificationTimestamp = block.timestamp;

        emit IdentityVerificationUpdated(msg.sender, identity.uniqueIdentifier, block.timestamp);
    }

    function revokeIdentity(address account) external onlyOperator {
        Identity storage identity = s_identities[account];
        if (identity.uniqueIdentifier == bytes32(0)) revert IdentityDoesNotExist(account);
        if (!identity.active) revert IdentityNotActive(account);

        bytes32 uniqueIdentifier = identity.uniqueIdentifier;

        identity.active = false;
        identity.lastVerificationTimestamp = block.timestamp;

        if (totalRegisteredIdentities > 0) {
            totalRegisteredIdentities -= 1;
        }

        emit IdentityRevoked(account, uniqueIdentifier, block.timestamp);
    }

    function pauseRegistrations() external onlyOperator {
        if (registrationsPaused) revert RegistrationsArePaused();
        registrationsPaused = true;
        emit RegistrationsPaused(msg.sender);
    }

    function unpauseRegistrations() external onlyOperator {
        if (!registrationsPaused) revert RegistrationsAreNotPaused();
        registrationsPaused = false;
        emit RegistrationsUnpaused(msg.sender);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorTransferred(previous, newOperator);
    }

    function getIdentity(address account)
        external
        view
        returns (bytes32 uniqueIdentifier, uint256 lastVerificationTimestamp, bool active)
    {
        Identity storage identity = s_identities[account];
        return (identity.uniqueIdentifier, identity.lastVerificationTimestamp, identity.active);
    }

    function isIdentityVerified(address account) external view returns (bool) {
        return s_identities[account].active;
    }

    function getVerificationStatus(address account)
        external
        view
        returns (bool active, uint256 lastVerificationTimestamp)
    {
        Identity storage identity = s_identities[account];
        return (identity.active, identity.lastVerificationTimestamp);
    }

    function getOwnerOfIdentifier(bytes32 uniqueIdentifier) external view returns (address) {
        return s_identifierToOwner[uniqueIdentifier];
    }

    function getDailyRegistrationCount(uint256 day) external view returns (uint256) {
        return s_dailyRegistrationCount[day];
    }

    function getCurrentDayRegistrationCount() external view returns (uint256) {
        return s_dailyRegistrationCount[block.timestamp / 1 days];
    }

    function _verifyProofOfUniqueness(bytes32 uniqueIdentifier, bytes32 proofOfUniqueness)
        internal
        pure
        returns (bool)
    {
        return proofOfUniqueness != bytes32(0) && proofOfUniqueness == keccak256(abi.encodePacked(uniqueIdentifier));
    }
}
