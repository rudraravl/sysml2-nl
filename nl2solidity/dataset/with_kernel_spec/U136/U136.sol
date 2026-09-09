// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UniversalNameService {
    ////////////////////////////////////////////////////////////////
    //                             ERRORS                          //
    ////////////////////////////////////////////////////////////////
    error Unauthorized();
    error NameNotRegistered();
    error NameNotAvailable();
    error InvalidName();
    error InvalidDuration();
    error InsufficientPayment();
    error RefundFailed();
    error TransferFailed();
    error ZeroAddress();

    ////////////////////////////////////////////////////////////////
    //                           CONSTANTS                         //
    ////////////////////////////////////////////////////////////////
    uint256 public constant MIN_REGISTRATION_PERIOD = 365 days;
    uint256 public constant MAX_REGISTRATION_PERIOD = 100 * 365 days;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant DEFAULT_FEE_PER_YEAR = 0.01 ether;

    ////////////////////////////////////////////////////////////////
    //                             TYPES                           //
    ////////////////////////////////////////////////////////////////
    struct Record {
        address owner;
        address resolver;
        uint64 expirationTime;
    }

    ////////////////////////////////////////////////////////////////
    //                            STORAGE                          //
    ////////////////////////////////////////////////////////////////
    mapping(bytes32 => Record) private _records;

    address public owner;
    address public operator;
    uint256 public registrationFeePerYear;
    uint256 public renewalFeePerYear;
    uint256 public totalCollected;

    ////////////////////////////////////////////////////////////////
    //                             EVENTS                          //
    ////////////////////////////////////////////////////////////////
    event NameRegistered(
        bytes32 indexed nameHash,
        address indexed owner,
        address resolver,
        uint256 expirationTime
    );
    event NameOwnershipTransferred(
        bytes32 indexed nameHash,
        address indexed previousOwner,
        address indexed newOwner
    );
    event NameRenewed(
        bytes32 indexed nameHash,
        address indexed owner,
        uint256 newExpirationTime,
        uint256 duration
    );
    event ResolverUpdated(
        bytes32 indexed nameHash,
        address indexed owner,
        address oldResolver,
        address newResolver
    );
    event RegistrationFeeUpdated(uint256 oldFee, uint256 newFee);
    event RenewalFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    ////////////////////////////////////////////////////////////////
    //                           MODIFIERS                         //
    ////////////////////////////////////////////////////////////////
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                           CONSTRUCTOR                       //
    ////////////////////////////////////////////////////////////////
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        registrationFeePerYear = DEFAULT_FEE_PER_YEAR;
        renewalFeePerYear = DEFAULT_FEE_PER_YEAR;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
    }

    ////////////////////////////////////////////////////////////////
    //                          NAME HASHING                       //
    ////////////////////////////////////////////////////////////////
    function nameHash(string calldata name) public pure returns (bytes32) {
        return keccak256(bytes(name));
    }

    ////////////////////////////////////////////////////////////////
    //                          REGISTRATION                       //
    ////////////////////////////////////////////////////////////////
    function register(
        string calldata name,
        uint256 duration,
        address resolver
    ) external payable returns (bytes32) {
        if (bytes(name).length == 0) revert InvalidName();
        if (duration < MIN_REGISTRATION_PERIOD || duration > MAX_REGISTRATION_PERIOD) {
            revert InvalidDuration();
        }

        bytes32 hash = nameHash(name);
        Record storage record = _records[hash];
        if (record.owner != address(0) && block.timestamp <= record.expirationTime) {
            revert NameNotAvailable();
        }

        uint256 fee = (duration * registrationFeePerYear) / SECONDS_PER_YEAR;
        if (msg.value < fee) revert InsufficientPayment();

        uint64 expirationTime = uint64(block.timestamp + duration);
        record.owner = msg.sender;
        record.resolver = resolver;
        record.expirationTime = expirationTime;

        totalCollected += fee;

        if (msg.value > fee) {
            uint256 refund = msg.value - fee;
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert RefundFailed();
        }

        emit NameRegistered(hash, msg.sender, resolver, expirationTime);
        return hash;
    }

    function transferName(string calldata name, address newOwner) external returns (bytes32) {
        if (newOwner == address(0)) revert ZeroAddress();
        bytes32 hash = nameHash(name);
        Record storage record = _records[hash];
        if (record.owner != msg.sender) revert Unauthorized();
        if (block.timestamp > record.expirationTime) revert NameNotRegistered();

        address previousOwner = record.owner;
        record.owner = newOwner;
        emit NameOwnershipTransferred(hash, previousOwner, newOwner);
        return hash;
    }

    function renew(string calldata name, uint256 duration) external payable returns (bytes32) {
        if (duration == 0 || duration > MAX_REGISTRATION_PERIOD) revert InvalidDuration();
        bytes32 hash = nameHash(name);
        Record storage record = _records[hash];
        if (record.owner != msg.sender) revert Unauthorized();
        if (block.timestamp > record.expirationTime) revert NameNotRegistered();

        uint256 fee = (duration * renewalFeePerYear) / SECONDS_PER_YEAR;
        if (msg.value < fee) revert InsufficientPayment();

        uint64 newExpirationTime = record.expirationTime + uint64(duration);
        record.expirationTime = newExpirationTime;

        totalCollected += fee;
        if (msg.value > fee) {
            uint256 refund = msg.value - fee;
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert RefundFailed();
        }

        emit NameRenewed(hash, msg.sender, newExpirationTime, duration);
        return hash;
    }

    function setResolver(string calldata name, address resolver) external returns (bytes32) {
        bytes32 hash = nameHash(name);
        Record storage record = _records[hash];
        if (record.owner != msg.sender) revert Unauthorized();
        if (block.timestamp > record.expirationTime) revert NameNotRegistered();

        address oldResolver = record.resolver;
        record.resolver = resolver;
        emit ResolverUpdated(hash, msg.sender, oldResolver, resolver);
        return hash;
    }

    ////////////////////////////////////////////////////////////////
    //                              VIEWS                          //
    ////////////////////////////////////////////////////////////////
    function getRecord(
        string calldata name
    ) external view returns (address owner_, address resolver_, uint256 expirationTime) {
        Record storage record = _records[nameHash(name)];
        return (record.owner, record.resolver, record.expirationTime);
    }

    function ownerOf(string calldata name) external view returns (address) {
        return _records[nameHash(name)].owner;
    }

    function resolverOf(string calldata name) external view returns (address) {
        return _records[nameHash(name)].resolver;
    }

    function expirationOf(string calldata name) external view returns (uint256) {
        return _records[nameHash(name)].expirationTime;
    }

    function isAvailable(string calldata name) external view returns (bool) {
        bytes32 hash = nameHash(name);
        Record storage record = _records[hash];
        return record.owner == address(0) || block.timestamp > record.expirationTime;
    }

    function isRegistered(string calldata name) external view returns (bool) {
        bytes32 hash = nameHash(name);
        Record storage record = _records[hash];
        return record.owner != address(0) && block.timestamp <= record.expirationTime;
    }

    function priceForRegistration(uint256 duration) external view returns (uint256) {
        return (duration * registrationFeePerYear) / SECONDS_PER_YEAR;
    }

    function priceForRenewal(uint256 duration) external view returns (uint256) {
        return (duration * renewalFeePerYear) / SECONDS_PER_YEAR;
    }

    ////////////////////////////////////////////////////////////////
    //                       ADMIN / OPERATOR                      //
    ////////////////////////////////////////////////////////////////
    function setRegistrationFee(uint256 fee) external onlyOperator {
        uint256 oldFee = registrationFeePerYear;
        registrationFeePerYear = fee;
        emit RegistrationFeeUpdated(oldFee, fee);
    }

    function setRenewalFee(uint256 fee) external onlyOperator {
        uint256 oldFee = renewalFeePerYear;
        renewalFeePerYear = fee;
        emit RenewalFeeUpdated(oldFee, fee);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previousOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(previousOperator, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = totalCollected;
        totalCollected = 0;
        if (amount > 0) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert TransferFailed();
        }
        emit FeesWithdrawn(to, amount);
    }

    receive() external payable {
        totalCollected += msg.value;
    }
}
