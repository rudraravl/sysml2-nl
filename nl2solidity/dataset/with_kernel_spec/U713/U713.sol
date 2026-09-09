// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MetaDomainRegistry
 * @notice Manages registration, renewal, transfer, and resolution of ".meta" domain names.
 * @dev The contract custodies registration and renewal fees. Only the designated operator
 *      can set fees, update the base resolver, and withdraw accumulated fees.
 */
contract MetaDomainRegistry {
    struct DomainRecord {
        address owner;
        uint64 expiration;
        address resolver;
    }

    error Unauthorized();
    error InvalidDomainName();
    error DomainAlreadyRegistered();
    error DomainNotRegistered();
    error DomainExpired();
    error InsufficientPayment();
    error InvalidDuration();
    error ZeroAddress();
    error RefundFailed();
    error WithdrawFailed();

    event DomainRegistered(string indexed name, address indexed owner, uint64 expiration, uint256 feePaid);
    event DomainRenewed(string indexed name, address indexed owner, uint64 newExpiration, uint256 feePaid);
    event DomainTransferred(string indexed name, address indexed from, address indexed to);
    event ResolverUpdated(string indexed name, address indexed owner, address resolver);
    event RegistrationFeeUpdated(uint256 oldFee, uint256 newFee);
    event RenewalFeeUpdated(uint256 oldFee, uint256 newFee);
    event BaseResolverUpdated(address oldResolver, address newResolver);
    event FeesWithdrawn(address indexed operator, address indexed to, uint256 amount);

    string public constant SUFFIX = ".meta";
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    address public operator;
    uint256 public registrationFeePerYear;
    uint256 public renewalFeePerYear;
    address public baseResolver;

    mapping(bytes32 => DomainRecord) private _records;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier onlyDomainOwner(bytes32 nameHash) {
        DomainRecord storage record = _records[nameHash];
        if (record.owner == address(0)) revert DomainNotRegistered();
        if (block.timestamp > record.expiration) revert DomainExpired();
        if (msg.sender != record.owner) revert Unauthorized();
        _;
    }

    constructor(address _operator, address _baseResolver) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        registrationFeePerYear = 0.01 ether;
        renewalFeePerYear = 0.005 ether;
        baseResolver = _baseResolver;
    }

    /**
     * @notice Computes a normalized hash for a domain name.
     * @dev Validates that the name ends with ".meta" and has a non-empty label.
     *      Uppercase ASCII letters are lowercased before hashing.
     */
    function nameHash(string calldata name) public pure returns (bytes32) {
        bytes memory raw = bytes(name);
        uint256 len = raw.length;
        if (len < 6) revert InvalidDomainName(); // at least "x.meta"

        // Verify ".meta" suffix
        if (raw[len - 5] != bytes1(".") ||
            raw[len - 4] != bytes1("m") ||
            raw[len - 3] != bytes1("e") ||
            raw[len - 2] != bytes1("t") ||
            raw[len - 1] != bytes1("a")) {
            revert InvalidDomainName();
        }

        // Lowercase normalization
        bytes memory normalized = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            bytes1 b = raw[i];
            if (uint8(b) >= 65 && uint8(b) <= 90) {
                normalized[i] = bytes1(uint8(b) + 32);
            } else {
                normalized[i] = b;
            }
        }
        return keccak256(normalized);
    }

    function getRecord(string calldata name) external view returns (DomainRecord memory) {
        return _records[nameHash(name)];
    }

    function ownerOf(string calldata name) external view returns (address) {
        return _records[nameHash(name)].owner;
    }

    function expirationOf(string calldata name) external view returns (uint64) {
        return _records[nameHash(name)].expiration;
    }

    function resolverOf(string calldata name) external view returns (address) {
        return _records[nameHash(name)].resolver;
    }

    function isRegistered(string calldata name) external view returns (bool) {
        return _records[nameHash(name)].owner != address(0);
    }

    function isExpired(string calldata name) external view returns (bool) {
        DomainRecord storage record = _records[nameHash(name)];
        if (record.owner == address(0)) return true;
        return block.timestamp > record.expiration;
    }

    /**
     * @notice Register a new ".meta" domain.
     * @param name The domain name, e.g. "hello.meta".
     * @param durationYears Number of years to register (must be > 0).
     */
    function register(string calldata name, uint64 durationYears) external payable {
        if (durationYears == 0) revert InvalidDuration();
        bytes32 hash = nameHash(name);

        DomainRecord storage existing = _records[hash];
        if (existing.owner != address(0) && block.timestamp <= existing.expiration) {
            revert DomainAlreadyRegistered();
        }

        uint256 requiredFee = registrationFeePerYear * durationYears;
        if (msg.value < requiredFee) revert InsufficientPayment();

        uint64 expiration = uint64(block.timestamp) + uint64(durationYears * SECONDS_PER_YEAR);

        _records[hash] = DomainRecord({
            owner: msg.sender,
            expiration: expiration,
            resolver: baseResolver
        });

        emit DomainRegistered(name, msg.sender, expiration, requiredFee);

        if (msg.value > requiredFee) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - requiredFee}("");
            if (!refunded) revert RefundFailed();
        }
    }

    /**
     * @notice Renew an existing domain, extending its expiration.
     * @param name The domain name.
     * @param durationYears Number of years to add (must be > 0).
     */
    function renew(string calldata name, uint64 durationYears) external payable onlyDomainOwner(nameHash(name)) {
        if (durationYears == 0) revert InvalidDuration();
        bytes32 hash = nameHash(name);
        uint256 requiredFee = renewalFeePerYear * durationYears;
        if (msg.value < requiredFee) revert InsufficientPayment();

        DomainRecord storage record = _records[hash];
        uint64 base = record.expiration > block.timestamp
            ? record.expiration
            : uint64(block.timestamp);
        uint64 newExpiration = base + uint64(durationYears * SECONDS_PER_YEAR);
        record.expiration = newExpiration;

        emit DomainRenewed(name, record.owner, newExpiration, requiredFee);

        if (msg.value > requiredFee) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - requiredFee}("");
            if (!refunded) revert RefundFailed();
        }
    }

    /**
     * @notice Transfer ownership of a registered, non-expired domain.
     * @param name The domain name.
     * @param to The new owner address (must be non-zero).
     */
    function transfer(string calldata name, address to) external onlyDomainOwner(nameHash(name)) {
        if (to == address(0)) revert ZeroAddress();
        bytes32 hash = nameHash(name);
        address from = _records[hash].owner;
        _records[hash].owner = to;
        emit DomainTransferred(name, from, to);
    }

    /**
     * @notice Set the resolver address for a domain owned by the caller.
     * @param name The domain name.
     * @param resolver The new resolver address.
     */
    function setResolver(string calldata name, address resolver) external onlyDomainOwner(nameHash(name)) {
        bytes32 hash = nameHash(name);
        _records[hash].resolver = resolver;
        emit ResolverUpdated(name, msg.sender, resolver);
    }

    function setRegistrationFee(uint256 newFee) external onlyOperator {
        uint256 old = registrationFeePerYear;
        registrationFeePerYear = newFee;
        emit RegistrationFeeUpdated(old, newFee);
    }

    function setRenewalFee(uint256 newFee) external onlyOperator {
        uint256 old = renewalFeePerYear;
        renewalFeePerYear = newFee;
        emit RenewalFeeUpdated(old, newFee);
    }

    function setBaseResolver(address newResolver) external onlyOperator {
        address old = baseResolver;
        baseResolver = newResolver;
        emit BaseResolverUpdated(old, newResolver);
    }

    /**
     * @notice Withdraw accumulated fees to a recipient.
     * @param to The recipient address.
     * @param amount The amount to withdraw; if 0, withdraws the full balance.
     */
    function withdrawFees(address payable to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (amount == 0) amount = balance;
        if (amount > balance) revert InsufficientPayment();
        (bool sent, ) = to.call{value: amount}("");
        if (!sent) revert WithdrawFailed();
        emit FeesWithdrawn(msg.sender, to, amount);
    }

    receive() external payable {}
}
