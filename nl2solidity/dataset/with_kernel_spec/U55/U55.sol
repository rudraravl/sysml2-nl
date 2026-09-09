// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedNameService
 * @notice A decentralized name service that custodies unique domain names.
 * @dev Each domain name maps to an owner, a resolver address, and an expiration timestamp.
 *      Registration and renewal fees are configurable by the contract owner.
 */
contract DecentralizedNameService {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error NameNotFound();
    error NameAlreadyRegistered();
    error NameExpired();
    error InvalidNameLength();
    error InvalidResolver();
    error InvalidFee();
    error InvalidDuration();
    error InsufficientPayment();
    error TransferToCurrentOwner();
    error RefundFailed();
    error ZeroAddressNotAllowed();
    error WithdrawFailed();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event NameRegistered(
        address indexed owner,
        bytes32 indexed nameHash,
        string name,
        address resolver,
        uint256 expiration
    );
    event NameRenewed(
        bytes32 indexed nameHash,
        uint256 newExpiration,
        uint256 yearsExtended
    );
    event NameTransferred(
        bytes32 indexed nameHash,
        address indexed previousOwner,
        address indexed newOwner
    );
    event ResolverUpdated(
        bytes32 indexed nameHash,
        address indexed oldResolver,
        address indexed newResolver
    );
    event RegistrationFeeUpdated(uint256 oldFee, uint256 newFee);
    event RenewalFeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Withdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             STORAGE
    //////////////////////////////////////////////////////////////*/

    struct DomainRecord {
        address owner;
        address resolver;
        uint256 expiration;
    }

    uint256 public constant MIN_NAME_LENGTH = 3;
    uint256 public constant MAX_NAME_LENGTH = 64;
    uint256 public constant YEAR = 365 days;

    uint256 public registrationFeePerYear;
    uint256 public renewalFeePerYear;

    address public owner;

    mapping(bytes32 => DomainRecord) private _records;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;
        registrationFeePerYear = 0.01 ether;
        renewalFeePerYear = 0.005 ether;
        emit OwnershipTransferred(address(0), msg.sender);
        emit RegistrationFeeUpdated(0, registrationFeePerYear);
        emit RenewalFeeUpdated(0, renewalFeePerYear);
    }

    /*//////////////////////////////////////////////////////////////
                           MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddressNotAllowed();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @notice Leaves the contract without owner. It will not be possible to call
     *         `onlyOwner` functions anymore.
     */
    function renounceOwnership() external onlyOwner {
        address previousOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }

    /**
     * @notice Sets the registration fee per year.
     * @param newFee The new registration fee per year (in wei).
     */
    function setRegistrationFee(uint256 newFee) external onlyOwner {
        if (newFee == 0) revert InvalidFee();
        uint256 oldFee = registrationFeePerYear;
        registrationFeePerYear = newFee;
        emit RegistrationFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Sets the renewal fee per year.
     * @param newFee The new renewal fee per year (in wei).
     */
    function setRenewalFee(uint256 newFee) external onlyOwner {
        if (newFee == 0) revert InvalidFee();
        uint256 oldFee = renewalFeePerYear;
        renewalFeePerYear = newFee;
        emit RenewalFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Withdraws all Ether held by the contract to the owner.
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool ok, ) = payable(owner).call{value: balance}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(owner, balance);
    }

    /*//////////////////////////////////////////////////////////////
                       USER-FACING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Registers a new domain name for a given number of years.
     * @param name The domain name to register (3-64 characters).
     * @param resolver The resolver address to associate with the name.
     * @param durationYears The number of years to register the name for.
     */
    function register(
        string calldata name,
        address resolver,
        uint256 durationYears
    ) external payable {
        bytes32 nameHash = _validateName(name);
        if (durationYears == 0) revert InvalidDuration();
        if (resolver == address(0)) revert InvalidResolver();

        DomainRecord storage record = _records[nameHash];
        if (record.owner != address(0) && record.expiration > block.timestamp) {
            revert NameAlreadyRegistered();
        }

        uint256 totalCost = registrationFeePerYear * durationYears;
        if (msg.value < totalCost) revert InsufficientPayment();

        record.owner = msg.sender;
        record.resolver = resolver;
        record.expiration = block.timestamp + (durationYears * YEAR);

        emit NameRegistered(msg.sender, nameHash, name, resolver, record.expiration);

        _refundExcess(msg.value, totalCost);
    }

    /**
     * @notice Renews an existing domain name for a given number of years.
     * @param name The domain name to renew.
     * @param durationYears The number of years to extend the registration by.
     */
    function renew(string calldata name, uint256 durationYears) external payable {
        bytes32 nameHash = _validateName(name);
        if (durationYears == 0) revert InvalidDuration();

        DomainRecord storage record = _records[nameHash];
        if (record.owner == address(0)) revert NameNotFound();

        uint256 totalCost = renewalFeePerYear * durationYears;
        if (msg.value < totalCost) revert InsufficientPayment();

        uint256 base = record.expiration > block.timestamp
            ? record.expiration
            : block.timestamp;
        record.expiration = base + (durationYears * YEAR);

        emit NameRenewed(nameHash, record.expiration, durationYears);

        _refundExcess(msg.value, totalCost);
    }

    /**
     * @notice Transfers ownership of a domain name to a new address.
     * @param name The domain name to transfer.
     * @param newOwner The address of the new owner.
     */
    function transfer(string calldata name, address newOwner) external {
        bytes32 nameHash = _validateName(name);
        if (newOwner == address(0)) revert ZeroAddressNotAllowed();

        DomainRecord storage record = _records[nameHash];
        if (record.owner == address(0)) revert NameNotFound();
        if (record.expiration <= block.timestamp) revert NameExpired();
        if (record.owner != msg.sender) revert Unauthorized();
        if (record.owner == newOwner) revert TransferToCurrentOwner();

        address previousOwner = record.owner;
        record.owner = newOwner;

        emit NameTransferred(nameHash, previousOwner, newOwner);
    }

    /**
     * @notice Sets the resolver address for a domain name.
     * @param name The domain name whose resolver should be updated.
     * @param resolver The new resolver address.
     */
    function setResolver(string calldata name, address resolver) external {
        bytes32 nameHash = _validateName(name);
        if (resolver == address(0)) revert InvalidResolver();

        DomainRecord storage record = _records[nameHash];
        if (record.owner == address(0)) revert NameNotFound();
        if (record.expiration <= block.timestamp) revert NameExpired();
        if (record.owner != msg.sender) revert Unauthorized();

        address oldResolver = record.resolver;
        record.resolver = resolver;

        emit ResolverUpdated(nameHash, oldResolver, resolver);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the owner of a given domain name.
     */
    function ownerOf(string calldata name) external view returns (address) {
        return _records[_hashName(name)].owner;
    }

    /**
     * @notice Returns the resolver address associated with a given domain name.
     */
    function resolverOf(string calldata name) external view returns (address) {
        return _records[_hashName(name)].resolver;
    }

    /**
     * @notice Returns the expiration timestamp of a given domain name.
     */
    function expirationOf(string calldata name) external view returns (uint256) {
        return _records[_hashName(name)].expiration;
    }

    /**
     * @notice Returns the full record for a given domain name.
     */
    function getRecord(string calldata name)
        external
        view
        returns (address recordOwner, address resolver, uint256 expiration)
    {
        DomainRecord storage record = _records[_hashName(name)];
        return (record.owner, record.resolver, record.expiration);
    }

    /**
     * @notice Returns whether a domain name is currently registered and active.
     */
    function isActive(string calldata name) external view returns (bool) {
        DomainRecord storage record = _records[_hashName(name)];
        return record.owner != address(0) && record.expiration > block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that the provided name is between MIN_NAME_LENGTH and
     *         MAX_NAME_LENGTH characters, and returns its keccak256 hash.
     * @param name The domain name to validate.
     * @return nameHash The keccak256 hash of the name bytes.
     */
    function _validateName(string calldata name) internal pure returns (bytes32 nameHash) {
        uint256 length = bytes(name).length;
        if (length < MIN_NAME_LENGTH || length > MAX_NAME_LENGTH) {
            revert InvalidNameLength();
        }
        return keccak256(abi.encodePacked(name));
    }

    /**
     * @notice Hashes a name without validating its length (for view functions).
     * @param name The domain name to hash.
     * @return The keccak256 hash of the name bytes.
     */
    function _hashName(string calldata name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(name));
    }

    /**
     * @notice Refunds any excess payment to the caller.
     * @param sent The amount of wei sent with the transaction.
     * @param cost The required cost of the operation.
     */
    function _refundExcess(uint256 sent, uint256 cost) internal {
        if (sent > cost) {
            uint256 excess = sent - cost;
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert RefundFailed();
        }
    }

    receive() external payable {}
}
