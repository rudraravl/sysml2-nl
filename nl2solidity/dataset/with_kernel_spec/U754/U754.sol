// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DigitalIdentifierRegistry
/// @notice Manages issuance, transfer, metadata updates, and revocation of unique
///         customizable digital identifiers. The contract holds no custodial assets;
///         registration fees are forwarded directly to the operator.
contract DigitalIdentifierRegistry {
    error NotOperator();
    error NotOwner();
    error ZeroAddress();
    error IdentifierDoesNotExist();
    error IdentifierAlreadyExists();
    error InvalidIdentifier();
    error InvalidSchema();
    error RegistrationsPaused();
    error InsufficientFee(uint256 sent, uint256 required);
    error MetadataTooLarge(uint256 size, uint256 max);
    error FeeTransferFailed();

    event IdentifierRegistered(
        uint256 indexed id,
        address indexed owner,
        string name,
        bytes metadata,
        uint256 feePaid
    );
    event OwnershipTransferred(uint256 indexed id, address indexed from, address indexed to);
    event MetadataUpdated(uint256 indexed id, bytes oldMetadata, bytes newMetadata);
    event NameUpdated(uint256 indexed id, string oldName, string newName);
    event IdentifierRevoked(uint256 indexed id, address indexed owner);
    event BaseFeeUpdated(uint256 oldFee, uint256 newFee);
    event PauseStateChanged(bool paused);
    event MetadataSchemaUpdated(bytes32 indexed schemaHash, string description);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MAX_METADATA_BYTES = 256;
    uint256 public constant DEFAULT_BASE_FEE = 0.01 ether;

    struct Identifier {
        address owner;
        string name;
        bytes metadata;
        uint96 registeredAt;
        bool exists;
    }

    address public operator;
    uint256 public baseFee;
    bool public registrationsPaused;

    bytes32 public metadataSchemaHash;
    string public metadataSchemaDescription;

    uint256 private _nextId;
    uint256 private _totalActive;

    mapping(uint256 => Identifier) private _identifiers;
    mapping(address => uint256[]) private _ownedIds;
    mapping(uint256 => uint256) private _ownedIndex;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyOwnerOf(uint256 id) {
        Identifier storage ident = _identifiers[id];
        if (!ident.exists) revert IdentifierDoesNotExist();
        if (ident.owner != msg.sender) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (registrationsPaused) revert RegistrationsPaused();
        _;
    }

    constructor(address initialOperator, string memory initialSchemaDescription) {
        if (initialOperator == address(0)) revert ZeroAddress();
        operator = initialOperator;
        baseFee = DEFAULT_BASE_FEE;
        registrationsPaused = false;
        _nextId = 1;
        _setSchema(initialSchemaDescription);
    }

    function registerIdentifier(string calldata name, bytes calldata metadata)
        external
        payable
        whenNotPaused
        returns (uint256 id)
    {
        if (msg.value < baseFee) revert InsufficientFee(msg.value, baseFee);
        if (bytes(name).length == 0) revert InvalidIdentifier();
        if (metadata.length > MAX_METADATA_BYTES) {
            revert MetadataTooLarge(metadata.length, MAX_METADATA_BYTES);
        }

        id = _nextId++;
        Identifier storage ident = _identifiers[id];
        if (ident.exists) revert IdentifierAlreadyExists();

        ident.owner = msg.sender;
        ident.name = name;
        ident.metadata = metadata;
        ident.registeredAt = uint96(block.timestamp);
        ident.exists = true;

        _addToOwnerList(msg.sender, id);
        _totalActive += 1;

        (bool ok, ) = payable(operator).call{value: msg.value}("");
        if (!ok) revert FeeTransferFailed();

        emit IdentifierRegistered(id, msg.sender, name, metadata, msg.value);
    }

    function transferOwnership(uint256 id, address to) external onlyOwnerOf(id) {
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert InvalidIdentifier();

        address from = msg.sender;
        _removeFromOwnerList(from, id);
        _addToOwnerList(to, id);

        _identifiers[id].owner = to;
        emit OwnershipTransferred(id, from, to);
    }

    function updateMetadata(uint256 id, bytes calldata newMetadata) external onlyOwnerOf(id) {
        if (newMetadata.length > MAX_METADATA_BYTES) {
            revert MetadataTooLarge(newMetadata.length, MAX_METADATA_BYTES);
        }
        bytes memory old = _identifiers[id].metadata;
        _identifiers[id].metadata = newMetadata;
        emit MetadataUpdated(id, old, newMetadata);
    }

    function updateName(uint256 id, string calldata newName) external onlyOwnerOf(id) {
        if (bytes(newName).length == 0) revert InvalidIdentifier();
        string memory old = _identifiers[id].name;
        _identifiers[id].name = newName;
        emit NameUpdated(id, old, newName);
    }

    function revokeIdentifier(uint256 id) external onlyOwnerOf(id) {
        address owner = msg.sender;
        _removeFromOwnerList(owner, id);

        delete _identifiers[id];
        _totalActive -= 1;

        emit IdentifierRevoked(id, owner);
    }

    function setBaseFee(uint256 newFee) external onlyOperator {
        uint256 old = baseFee;
        baseFee = newFee;
        emit BaseFeeUpdated(old, newFee);
    }

    function setRegistrationsPaused(bool paused) external onlyOperator {
        registrationsPaused = paused;
        emit PauseStateChanged(paused);
    }

    function updateMetadataSchema(string calldata description) external onlyOperator {
        if (bytes(description).length == 0) revert InvalidSchema();
        _setSchema(description);
    }

    function changeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function identifierOf(uint256 id)
        external
        view
        returns (address owner, string memory name, bytes memory metadata, uint96 registeredAt, bool exists)
    {
        Identifier storage ident = _identifiers[id];
        return (ident.owner, ident.name, ident.metadata, ident.registeredAt, ident.exists);
    }

    function ownerOf(uint256 id) external view returns (address) {
        if (!_identifiers[id].exists) revert IdentifierDoesNotExist();
        return _identifiers[id].owner;
    }

    function metadataOf(uint256 id) external view returns (bytes memory) {
        if (!_identifiers[id].exists) revert IdentifierDoesNotExist();
        return _identifiers[id].metadata;
    }

    function nameOf(uint256 id) external view returns (string memory) {
        if (!_identifiers[id].exists) revert IdentifierDoesNotExist();
        return _identifiers[id].name;
    }

    function exists(uint256 id) external view returns (bool) {
        return _identifiers[id].exists;
    }

    function totalActive() external view returns (uint256) {
        return _totalActive;
    }

    function totalRegistered() external view returns (uint256) {
        return _nextId - 1;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _ownedIds[owner].length;
    }

    function ownedIds(address owner) external view returns (uint256[] memory) {
        return _ownedIds[owner];
    }

    function getNextId() external view returns (uint256) {
        return _nextId;
    }

    function _setSchema(string memory description) internal {
        metadataSchemaHash = keccak256(abi.encodePacked(description, block.timestamp));
        metadataSchemaDescription = description;
        emit MetadataSchemaUpdated(metadataSchemaHash, description);
    }

    function _addToOwnerList(address owner, uint256 id) internal {
        uint256 idx = _ownedIds[owner].length;
        _ownedIds[owner].push(id);
        _ownedIndex[id] = idx;
    }

    function _removeFromOwnerList(address owner, uint256 id) internal {
        uint256[] storage ids = _ownedIds[owner];
        uint256 idx = _ownedIndex[id];
        uint256 lastIdx = ids.length - 1;

        if (idx != lastIdx) {
            uint256 lastId = ids[lastIdx];
            ids[idx] = lastId;
            _ownedIndex[lastId] = idx;
        }

        ids.pop();
        delete _ownedIndex[id];
    }
}
