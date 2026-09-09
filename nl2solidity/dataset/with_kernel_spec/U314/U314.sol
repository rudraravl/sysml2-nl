// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NameRegistry
 * @notice Registry for unique, non-fungible digital identities (names).
 * @dev Names are registered for a one-year period in exchange for a configurable fee.
 *      The contract owner manages fees, operators, and withdrawals. Operators may
 *      pause/unpause new registrations and renewals.
 */
contract NameRegistry {
    /* ------------------------------------------------------------------ */
    /*                             CUSTOM ERRORS                          */
    /* ------------------------------------------------------------------ */

    error NameNotAvailable();
    error NameNotFound();
    error NotNameOwner();
    error NotContractOwner();
    error NotOperator();
    error RegistrationPaused();
    error InsufficientFee();
    error ZeroAddressDisallowed();
    error EmptyNameDisallowed();
    error ExcessiveStringLength();
    error TransferFailed();

    /* ------------------------------------------------------------------ */
    /*                              EVENTS                                 */
    /* ------------------------------------------------------------------ */

    event NameRegistered(
        bytes32 indexed nameHash,
        address indexed owner,
        string name,
        uint256 expiresAt
    );

    event OwnershipTransferred(
        bytes32 indexed nameHash,
        address indexed previousOwner,
        address indexed newOwner,
        string name
    );

    event ConfigUpdated(
        bytes32 indexed nameHash,
        address indexed owner,
        string name,
        bytes config
    );

    event NameRenewed(
        bytes32 indexed nameHash,
        address indexed owner,
        string name,
        uint256 newExpiresAt
    );

    event RegistrationFeeUpdated(uint256 oldFee, uint256 newFee);

    event OperatorUpdated(address indexed operator, bool isOperator);

    event Paused(address indexed by);

    event Unpaused(address indexed by);

    event FeesWithdrawn(address indexed to, uint256 amount);

    /* ------------------------------------------------------------------ */
    /*                            CONSTANTS                                */
    /* ------------------------------------------------------------------ */

    uint256 public constant REGISTRATION_PERIOD = 365 days;
    uint256 public constant MAX_NAME_LENGTH = 64;
    uint256 public constant MAX_CONFIG_LENGTH = 256;

    /* ------------------------------------------------------------------ */
    /*                             STORAGE                                 */
    /* ------------------------------------------------------------------ */

    struct NameRecord {
        address owner;
        uint256 expiresAt;
        bytes config;
    }

    address public contractOwner;
    uint256 public registrationFee;
    uint256 public totalNamesIssued;
    bool public paused;

    mapping(address => bool) public operators;
    mapping(bytes32 => NameRecord) private _records;
    mapping(bytes32 => bool) private _nameExists;

    /* ------------------------------------------------------------------ */
    /*                            MODIFIERS                                */
    /* ------------------------------------------------------------------ */

    modifier onlyContractOwner() {
        if (msg.sender != contractOwner) revert NotContractOwner();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender] && msg.sender != contractOwner) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert RegistrationPaused();
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "REENTRANT");
        _locked = true;
        _;
        _locked = false;
    }

    /* ------------------------------------------------------------------ */
    /*                            CONSTRUCTOR                             */
    /* ------------------------------------------------------------------ */

    constructor() {
        contractOwner = msg.sender;
        registrationFee = 0.01 ether;
        paused = false;
        _locked = false;
    }

    bool private _locked;

    /* ------------------------------------------------------------------ */
    /*                          EXTERNAL FUNCTIONS                        */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Registers a new name for the caller if it is available.
     * @param name The unique name to register.
     * @param config Optional configuration data associated with the name.
     */
    function registerName(
        string calldata name,
        bytes calldata config
    ) external payable whenNotPaused {
        if (bytes(name).length == 0) revert EmptyNameDisallowed();
        if (bytes(name).length > MAX_NAME_LENGTH) revert ExcessiveStringLength();
        if (config.length > MAX_CONFIG_LENGTH) revert ExcessiveStringLength();
        if (msg.value < registrationFee) revert InsufficientFee();

        bytes32 nameHash = keccak256(abi.encodePacked(name));

        if (_nameExists[nameHash]) {
            if (block.timestamp < _records[nameHash].expiresAt) revert NameNotAvailable();
            // Expired name becomes available again.
        }

        uint256 expiresAt = block.timestamp + REGISTRATION_PERIOD;

        _records[nameHash] = NameRecord({
            owner: msg.sender,
            expiresAt: expiresAt,
            config: config
        });

        if (!_nameExists[nameHash]) {
            _nameExists[nameHash] = true;
            totalNamesIssued += 1;
        }

        emit NameRegistered(nameHash, msg.sender, name, expiresAt);
    }

    /**
     * @notice Transfers ownership of a name to a new owner.
     * @param name The name to transfer.
     * @param newOwner The address receiving ownership.
     */
    function transferOwnership(
        string calldata name,
        address newOwner
    ) external {
        if (newOwner == address(0)) revert ZeroAddressDisallowed();
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) revert NameNotFound();

        NameRecord storage record = _records[nameHash];
        if (record.owner != msg.sender) revert NotNameOwner();

        address previousOwner = record.owner;
        record.owner = newOwner;

        emit OwnershipTransferred(nameHash, previousOwner, newOwner, name);
    }

    /**
     * @notice Updates the configuration record for a name owned by the caller.
     * @param name The name whose configuration is updated.
     * @param newConfig The new configuration data.
     */
    function updateConfig(
        string calldata name,
        bytes calldata newConfig
    ) external {
        if (newConfig.length > MAX_CONFIG_LENGTH) revert ExcessiveStringLength();
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) revert NameNotFound();

        NameRecord storage record = _records[nameHash];
        if (record.owner != msg.sender) revert NotNameOwner();

        record.config = newConfig;

        emit ConfigUpdated(nameHash, msg.sender, name, newConfig);
    }

    /**
     * @notice Renews the registration of a name owned by the caller.
     * @param name The name to renew.
     */
    function renewName(string calldata name) external payable whenNotPaused {
        if (msg.value < registrationFee) revert InsufficientFee();
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) revert NameNotFound();

        NameRecord storage record = _records[nameHash];
        if (record.owner != msg.sender) revert NotNameOwner();

        uint256 base = block.timestamp > record.expiresAt
            ? block.timestamp
            : record.expiresAt;
        uint256 newExpiresAt = base + REGISTRATION_PERIOD;
        record.expiresAt = newExpiresAt;

        emit NameRenewed(nameHash, msg.sender, name, newExpiresAt);
    }

    /* ------------------------------------------------------------------ */
    /*                       CONTRACT OWNER FUNCTIONS                     */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Sets the registration fee required to register or renew a name.
     * @param newFee The new fee in wei.
     */
    function setRegistrationFee(uint256 newFee) external onlyContractOwner {
        uint256 oldFee = registrationFee;
        registrationFee = newFee;
        emit RegistrationFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Grants or revokes operator privileges.
     * @param operator The address whose operator status is changed.
     * @param isOperator True to grant, false to revoke.
     */
    function setOperator(address operator, bool isOperator) external onlyContractOwner {
        if (operator == address(0)) revert ZeroAddressDisallowed();
        operators[operator] = isOperator;
        emit OperatorUpdated(operator, isOperator);
    }

    /**
     * @notice Withdraws collected registration fees to a recipient.
     * @param to The address receiving the fees.
     * @param amount The amount to withdraw (capped to available balance).
     */
    function withdrawFees(address to, uint256 amount) external onlyContractOwner nonReentrant {
        if (to == address(0)) revert ZeroAddressDisallowed();

        uint256 balance = address(this).balance;
        if (amount > balance) {
            amount = balance;
        }

        // Only proceed when there is a positive amount to transfer.
        // Avoids the dangerous strict-equality `amount == 0` check by
        // gating on the positive (greater-than) branch instead.
        if (amount > 0) {
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert TransferFailed();
            emit FeesWithdrawn(to, amount);
        }
    }

    /**
     * @notice Transfers ownership of this contract.
     * @param newOwner The new contract owner.
     */
    function transferContractOwnership(address newOwner) external onlyContractOwner {
        if (newOwner == address(0)) revert ZeroAddressDisallowed();
        contractOwner = newOwner;
    }

    /* ------------------------------------------------------------------ */
    /*                         OPERATOR FUNCTIONS                          */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Pauses new name registrations and renewals.
     */
    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpauses name registrations and renewals.
     */
    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /* ------------------------------------------------------------------ */
    /*                            VIEW FUNCTIONS                          */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Returns the owner of a registered name.
     */
    function ownerOf(string calldata name) external view returns (address) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) revert NameNotFound();
        return _records[nameHash].owner;
    }

    /**
     * @notice Returns the expiration timestamp of a name.
     */
    function expiresAt(string calldata name) external view returns (uint256) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) revert NameNotFound();
        return _records[nameHash].expiresAt;
    }

    /**
     * @notice Returns the configuration record of a name.
     */
    function configOf(string calldata name) external view returns (bytes memory) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) revert NameNotFound();
        return _records[nameHash].config;
    }

    /**
     * @notice Returns whether a name is currently available for registration.
     */
    function isAvailable(string calldata name) external view returns (bool) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) return true;
        return block.timestamp >= _records[nameHash].expiresAt;
    }

    /**
     * @notice Returns whether a name exists in the registry.
     */
    function nameExists(string calldata name) external view returns (bool) {
        return _nameExists[keccak256(abi.encodePacked(name))];
    }

    /**
     * @notice Returns the full record for a name.
     */
    function getRecord(
        string calldata name
    ) external view returns (address owner, uint256 expiry, bytes memory config) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (!_nameExists[nameHash]) revert NameNotFound();
        NameRecord storage record = _records[nameHash];
        return (record.owner, record.expiresAt, record.config);
    }

    /**
     * @notice Returns the current balance of collected fees.
     */
    function collectedFees() external view returns (uint256) {
        return address(this).balance;
    }

    /* ------------------------------------------------------------------ */
    /*                              RECEIVE                               */
    /* ------------------------------------------------------------------ */

    receive() external payable {}
}
