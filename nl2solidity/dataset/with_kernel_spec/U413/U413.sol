// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DomainRegistry
 * @notice A registry for domain name ownership on the blockchain.
 * @dev Manages registration, renewal, transfer, and resolver assignment of domain names.
 *      A designated operator can pause new registrations and renewals. Names are keyed
 *      by their keccak256 hash for gas-efficient storage lookups.
 */
contract DomainRegistry {
    /// @notice Flat fee charged for registering or renewing a name.
    uint256 public constant REGISTRATION_FEE = 0.01 ether;

    /// @notice Duration of a single registration or renewal period (one year).
    uint256 public constant RENEWAL_DURATION = 365 days;

    struct Domain {
        address owner;
        uint256 expiration;
        address resolver;
    }

    mapping(bytes32 => Domain) private _domains;

    /// @notice Current owner of the contract.
    address public owner;

    /// @notice Designated operator who can pause registrations and renewals.
    address public operator;

    /// @notice Whether new registrations and renewals are currently paused.
    bool public registrationsPaused;

    /* ═══════════════════ Events ═══════════════════ */

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event NameRegistered(bytes32 indexed nameHash, string name, address indexed owner, uint256 expiration);
    event NameRenewed(bytes32 indexed nameHash, string name, address indexed owner, uint256 newExpiration);
    event NameTransferred(bytes32 indexed nameHash, string name, address indexed from, address indexed to);
    event ResolverSet(bytes32 indexed nameHash, string name, address indexed resolver);
    event RegistrationsPaused();
    event RegistrationsUnpaused();
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    /* ═══════════════════ Errors ═══════════════════ */

    error NameAlreadyRegistered();
    error NameNotRegistered();
    error NotNameOwner();
    error RegistrationsArePaused();
    error InsufficientFee();
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error EmptyName();
    error NoFeesToWithdraw();
    error TransferFailed();

    /* ═══════════════ Modifiers ═══════════════ */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenRegistrationsNotPaused() {
        if (registrationsPaused) revert RegistrationsArePaused();
        _;
    }

    /* ═══════════════ Constructor ═══════════════ */

    /**
     * @param _operator Address that is allowed to pause registrations and renewals.
     */
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /* ═══════════════ Internal Helpers ═══════════════ */

    /**
     * @dev Computes the keccak256 hash of a name. Reverts on empty names.
     * @param name The human-readable name.
     * @return The keccak256 hash of the name bytes.
     */
    function _nameHash(string calldata name) internal pure returns (bytes32) {
        if (bytes(name).length == 0) revert EmptyName();
        return keccak256(bytes(name));
    }

    /* ═══════════════ External Functions ═══════════════ */

    /**
     * @notice Registers a new name for the caller.
     * @dev Reverts if the name is already actively registered, the fee is insufficient,
     *      or registrations are paused. Expired names may be re-registered by anyone.
     * @param name The name to register.
     */
    function register(string calldata name) external payable whenRegistrationsNotPaused {
        if (msg.value < REGISTRATION_FEE) revert InsufficientFee();

        bytes32 h = _nameHash(name);
        Domain storage d = _domains[h];

        if (d.owner != address(0) && block.timestamp <= d.expiration) {
            revert NameAlreadyRegistered();
        }

        d.owner = msg.sender;
        d.expiration = block.timestamp + RENEWAL_DURATION;
        d.resolver = address(0);

        emit NameRegistered(h, name, msg.sender, d.expiration);
    }

    /**
     * @notice Renews an existing name, extending its expiration by exactly one year
     *         from the current expiration date.
     * @dev Reverts if the name is not registered, the caller is not the owner,
     *      the fee is insufficient, or renewals are paused. Renewal extends from the
     *      stored expiration, not from the current block timestamp.
     * @param name The name to renew.
     */
    function renew(string calldata name) external payable whenRegistrationsNotPaused {
        if (msg.value < REGISTRATION_FEE) revert InsufficientFee();

        bytes32 h = _nameHash(name);
        Domain storage d = _domains[h];

        if (d.owner == address(0)) revert NameNotRegistered();
        if (d.owner != msg.sender) revert NotNameOwner();

        d.expiration = d.expiration + RENEWAL_DURATION;

        emit NameRenewed(h, name, msg.sender, d.expiration);
    }

    /**
     * @notice Transfers ownership of a name to a new address.
     * @param name The name whose ownership is being transferred.
     * @param to The new owner's address.
     */
    function transferName(string calldata name, address to) external {
        if (to == address(0)) revert ZeroAddress();

        bytes32 h = _nameHash(name);
        Domain storage d = _domains[h];

        if (d.owner == address(0)) revert NameNotRegistered();
        if (d.owner != msg.sender) revert NotNameOwner();

        address from = d.owner;
        d.owner = to;

        emit NameTransferred(h, name, from, to);
    }

    /**
     * @notice Sets the resolver address associated with a name.
     * @param name The name whose resolver is being set.
     * @param resolver The new resolver address (use address(0) to clear).
     */
    function setResolver(string calldata name, address resolver) external {
        bytes32 h = _nameHash(name);
        Domain storage d = _domains[h];

        if (d.owner == address(0)) revert NameNotRegistered();
        if (d.owner != msg.sender) revert NotNameOwner();

        d.resolver = resolver;

        emit ResolverSet(h, name, resolver);
    }

    /**
     * @notice Pauses new registrations and renewals. Only callable by the operator.
     */
    function pauseRegistrations() external onlyOperator {
        if (registrationsPaused) revert RegistrationsArePaused();
        registrationsPaused = true;
        emit RegistrationsPaused();
    }

    /**
     * @notice Resumes new registrations and renewals. Only callable by the operator.
     */
    function unpauseRegistrations() external onlyOperator {
        if (!registrationsPaused) revert RegistrationsArePaused();
        registrationsPaused = false;
        emit RegistrationsUnpaused();
    }

    /**
     * @notice Updates the operator address. Only callable by the contract owner.
     * @param newOperator The new operator address.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /**
     * @notice Transfers ownership of the contract. Only callable by the current owner.
     * @param newOwner The address of the new contract owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    /**
     * @notice Withdraws all accumulated registration and renewal fees.
     * @param to Recipient of the withdrawn funds.
     */
    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount < 1) revert NoFeesToWithdraw();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    /* ═══════════════ View Functions ═══════════════ */

    /**
     * @notice Returns the owner, expiration, and resolver for a name.
     * @param name The domain name to query.
     * @return owner_ Current owner address (address(0) if unregistered).
     * @return expiration Unix timestamp of expiration (0 if unregistered).
     * @return resolver Current resolver address.
     */
    function getDomain(string calldata name) external view returns (address owner_, uint256 expiration, address resolver) {
        Domain storage d = _domains[_nameHash(name)];
        return (d.owner, d.expiration, d.resolver);
    }

    /**
     * @notice Returns the owner of a name, or address(0) if unregistered.
     * @param name The domain name to query.
     */
    function getOwner(string calldata name) external view returns (address) {
        return _domains[_nameHash(name)].owner;
    }

    /**
     * @notice Returns the expiration timestamp of a name, or 0 if unregistered.
     * @param name The domain name to query.
     */
    function getExpiration(string calldata name) external view returns (uint256) {
        return _domains[_nameHash(name)].expiration;
    }

    /**
     * @notice Returns the resolver address for a name.
     * @param name The domain name to query.
     */
    function getResolver(string calldata name) external view returns (address) {
        return _domains[_nameHash(name)].resolver;
    }

    /**
     * @notice Returns whether a name is currently registered and not expired.
     * @param name The domain name to query.
     */
    function isActive(string calldata name) external view returns (bool) {
        Domain storage d = _domains[_nameHash(name)];
        return d.owner != address(0) && block.timestamp <= d.expiration;
    }

    /**
     * @notice Hashes a name into the bytes32 key used internally.
     * @param name The human-readable name.
     * @return The keccak256 hash of the name bytes.
     */
    function nameHash(string calldata name) external pure returns (bytes32) {
        return _nameHash(name);
    }

    receive() external payable {}
}
