// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() external virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract IdentifierRegistry is Ownable {
    struct Record {
        address owner;
        address resolver;
        uint64 createdAt;
    }

    error IdentifierAlreadyRegistered(string identifier);
    error IdentifierNotRegistered(string identifier);
    error CallerNotIdentifierOwner(string identifier);
    error IdentifierTooShort(string identifier, uint256 length, uint256 minLength);
    error InvalidResolver(address resolver);
    error InvalidNewOwner(address newOwner);
    error InsufficientRegistrationFee(uint256 sent, uint256 required);
    error InvalidMinimumLength(uint256 provided);
    error EmptyIdentifier();
    error WithdrawalFailed();

    event IdentifierRegistered(
        bytes32 indexed identifierHash,
        string identifier,
        address indexed owner,
        address resolver,
        uint64 createdAt
    );
    event IdentifierTransferred(
        bytes32 indexed identifierHash,
        string identifier,
        address indexed previousOwner,
        address indexed newOwner,
        address resolver
    );
    event ResolverUpdated(
        bytes32 indexed identifierHash,
        string identifier,
        address indexed owner,
        address oldResolver,
        address newResolver
    );
    event RegistrationFeeUpdated(uint256 oldFee, uint256 newFee);
    event MinimumLengthUpdated(uint256 oldLength, uint256 newLength);
    event FeesWithdrawn(address indexed to, uint256 amount);

    uint256 private constant MIN_ALLOWED_MINIMUM_LENGTH = 3;

    mapping(bytes32 => Record) private _records;
    uint256 private _registrationFee;
    uint256 private _minimumLength;

    constructor(
        address initialOwner,
        uint256 registrationFee_,
        uint256 minimumLength_
    ) Ownable(initialOwner) {
        if (minimumLength_ < MIN_ALLOWED_MINIMUM_LENGTH) {
            revert InvalidMinimumLength(minimumLength_);
        }
        _registrationFee = registrationFee_;
        _minimumLength = minimumLength_;
        emit RegistrationFeeUpdated(0, registrationFee_);
        emit MinimumLengthUpdated(0, minimumLength_);
    }

    function registrationFee() external view returns (uint256) {
        return _registrationFee;
    }

    function minimumLength() external view returns (uint256) {
        return _minimumLength;
    }

    function setRegistrationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = _registrationFee;
        _registrationFee = newFee;
        emit RegistrationFeeUpdated(oldFee, newFee);
    }

    function setMinimumLength(uint256 newMinimumLength) external onlyOwner {
        if (newMinimumLength < MIN_ALLOWED_MINIMUM_LENGTH) {
            revert InvalidMinimumLength(newMinimumLength);
        }
        uint256 oldLength = _minimumLength;
        _minimumLength = newMinimumLength;
        emit MinimumLengthUpdated(oldLength, newMinimumLength);
    }

    function register(string calldata identifier, address resolver) external payable returns (bytes32) {
        if (bytes(identifier).length == 0) {
            revert EmptyIdentifier();
        }
        uint256 length = bytes(identifier).length;
        if (length < _minimumLength) {
            revert IdentifierTooShort(identifier, length, _minimumLength);
        }
        if (msg.value < _registrationFee) {
            revert InsufficientRegistrationFee(msg.value, _registrationFee);
        }
        if (resolver == address(0)) {
            revert InvalidResolver(resolver);
        }

        bytes32 idHash = _hashIdentifier(identifier);
        if (_records[idHash].owner != address(0)) {
            revert IdentifierAlreadyRegistered(identifier);
        }

        uint64 createdAt = uint64(block.timestamp);
        _records[idHash] = Record({
            owner: msg.sender,
            resolver: resolver,
            createdAt: createdAt
        });

        emit IdentifierRegistered(idHash, identifier, msg.sender, resolver, createdAt);
        return idHash;
    }

    function transferIdentifier(string calldata identifier, address newOwner) external {
        if (newOwner == address(0)) {
            revert InvalidNewOwner(newOwner);
        }

        bytes32 idHash = _hashIdentifier(identifier);
        Record storage record = _records[idHash];
        if (record.owner == address(0)) {
            revert IdentifierNotRegistered(identifier);
        }
        if (record.owner != msg.sender) {
            revert CallerNotIdentifierOwner(identifier);
        }

        address previousOwner = record.owner;
        record.owner = newOwner;

        emit IdentifierTransferred(idHash, identifier, previousOwner, newOwner, record.resolver);
    }

    function updateResolver(string calldata identifier, address newResolver) external {
        if (newResolver == address(0)) {
            revert InvalidResolver(newResolver);
        }

        bytes32 idHash = _hashIdentifier(identifier);
        Record storage record = _records[idHash];
        if (record.owner == address(0)) {
            revert IdentifierNotRegistered(identifier);
        }
        if (record.owner != msg.sender) {
            revert CallerNotIdentifierOwner(identifier);
        }

        address oldResolver = record.resolver;
        record.resolver = newResolver;

        emit ResolverUpdated(idHash, identifier, msg.sender, oldResolver, newResolver);
    }

    function getOwner(string calldata identifier) external view returns (address) {
        return _records[_hashIdentifier(identifier)].owner;
    }

    function getResolver(string calldata identifier) external view returns (address) {
        return _records[_hashIdentifier(identifier)].resolver;
    }

    function getCreatedAt(string calldata identifier) external view returns (uint64) {
        return _records[_hashIdentifier(identifier)].createdAt;
    }

    function getRecord(string calldata identifier)
        external
        view
        returns (address recordOwner, address resolver, uint64 createdAt)
    {
        Record storage record = _records[_hashIdentifier(identifier)];
        return (record.owner, record.resolver, record.createdAt);
    }

    function isRegistered(string calldata identifier) external view returns (bool) {
        return _records[_hashIdentifier(identifier)].owner != address(0);
    }

    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) {
            revert InvalidNewOwner(to);
        }
        uint256 amount = address(this).balance;
        if (amount == 0) {
            return;
        }
        (bool success, ) = to.call{value: amount}("");
        if (!success) {
            revert WithdrawalFailed();
        }
        emit FeesWithdrawn(to, amount);
    }

    function _hashIdentifier(string calldata identifier) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(identifier));
    }
}
