// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract GamingAssetRegistry {
    using SafeERC20 for IERC20;

    ////////////////////////////////////////////////////////////////////////////
    // ERRORS
    ////////////////////////////////////////////////////////////////////////////

    error Unauthorized();
    error ZeroAddress();
    error ZeroValue();
    error ItemTypeDoesNotExist();
    error ItemDoesNotExist();
    error NotItemOwner();
    error MaxSupplyExceeded();
    error SelfTransfer();

    ////////////////////////////////////////////////////////////////////////////
    // EVENTS
    ////////////////////////////////////////////////////////////////////////////

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event ItemTypeCreated(uint256 indexed typeId, string metadata, uint256 maxSupply);
    event ItemMinted(
        uint256 indexed itemId,
        uint256 indexed typeId,
        address indexed owner,
        uint256 value,
        bytes32 immutableProperties
    );
    event ItemTransferred(
        uint256 indexed itemId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 feePaid
    );
    event ItemBurned(uint256 indexed itemId, address indexed owner);

    ////////////////////////////////////////////////////////////////////////////
    // CONSTANTS
    ////////////////////////////////////////////////////////////////////////////

    uint256 public constant MAX_SUPPLY_PER_TYPE = 1_000_000;
    uint256 public constant TRANSFER_FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10_000;

    ////////////////////////////////////////////////////////////////////////////
    // STORAGE
    ////////////////////////////////////////////////////////////////////////////

    address public operator;
    IERC20 public immutable baseCurrency;

    uint256 private _nextTypeId;
    uint256 private _nextItemId;

    struct ItemType {
        uint256 maxSupply;
        uint256 totalMinted;
        string metadata;
        bool exists;
    }

    struct Item {
        uint256 typeId;
        address owner;
        uint256 value;
        bytes32 properties;
        bool exists;
    }

    mapping(uint256 => ItemType) private _itemTypes;
    mapping(uint256 => Item) private _items;

    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier onlyItemOwner(uint256 itemId) {
        Item storage item = _items[itemId];
        if (!item.exists) revert ItemDoesNotExist();
        if (item.owner != msg.sender) revert NotItemOwner();
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    ////////////////////////////////////////////////////////////////////////////

    constructor(address initialOperator, address baseCurrency_) {
        if (initialOperator == address(0)) revert ZeroAddress();
        if (baseCurrency_ == address(0)) revert ZeroAddress();
        operator = initialOperator;
        baseCurrency = IERC20(baseCurrency_);
        _nextTypeId = 1;
        _nextItemId = 1;
        emit OperatorChanged(address(0), initialOperator);
    }

    ////////////////////////////////////////////////////////////////////////////
    // OPERATOR ADMINISTRATION
    ////////////////////////////////////////////////////////////////////////////

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    ////////////////////////////////////////////////////////////////////////////
    // ITEM TYPE LOGIC
    ////////////////////////////////////////////////////////////////////////////

    function createItemType(string calldata metadata) external onlyOperator returns (uint256 typeId) {
        typeId = _nextTypeId++;
        _itemTypes[typeId] = ItemType({
            maxSupply: MAX_SUPPLY_PER_TYPE,
            totalMinted: 0,
            metadata: metadata,
            exists: true
        });
        emit ItemTypeCreated(typeId, metadata, MAX_SUPPLY_PER_TYPE);
    }

    ////////////////////////////////////////////////////////////////////////////
    // ITEM LOGIC
    ////////////////////////////////////////////////////////////////////////////

    function mintItem(
        uint256 typeId,
        address to,
        uint256 value,
        bytes32 properties
    ) external onlyOperator returns (uint256 itemId) {
        ItemType storage t = _itemTypes[typeId];
        if (!t.exists) revert ItemTypeDoesNotExist();
        if (to == address(0)) revert ZeroAddress();
        if (value == 0) revert ZeroValue();
        if (t.totalMinted >= t.maxSupply) revert MaxSupplyExceeded();

        itemId = _nextItemId++;
        _items[itemId] = Item({
            typeId: typeId,
            owner: to,
            value: value,
            properties: properties,
            exists: true
        });
        t.totalMinted += 1;

        emit ItemMinted(itemId, typeId, to, value, properties);
    }

    function transferItem(uint256 itemId, address to) external onlyItemOwner(itemId) {
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert SelfTransfer();

        Item storage item = _items[itemId];
        address previousOwner = item.owner;
        uint256 fee = (item.value * TRANSFER_FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;

        // Effects
        item.owner = to;

        emit ItemTransferred(itemId, previousOwner, to, fee);

        // Interactions
        if (fee > 0) {
            baseCurrency.safeTransferFrom(msg.sender, operator, fee);
        }
    }

    function burnItem(uint256 itemId) external onlyItemOwner(itemId) {
        Item storage item = _items[itemId];
        address owner = item.owner;

        delete _items[itemId];

        emit ItemBurned(itemId, owner);
    }

    ////////////////////////////////////////////////////////////////////////////
    // VIEWS
    ////////////////////////////////////////////////////////////////////////////

    function getItem(uint256 itemId)
        external
        view
        returns (uint256 typeId, address owner, uint256 value, bytes32 properties, bool exists)
    {
        Item storage item = _items[itemId];
        return (item.typeId, item.owner, item.value, item.properties, item.exists);
    }

    function itemOwner(uint256 itemId) external view returns (address) {
        if (!_items[itemId].exists) revert ItemDoesNotExist();
        return _items[itemId].owner;
    }

    function itemType(uint256 typeId)
        external
        view
        returns (uint256 maxSupply, uint256 totalMinted, string memory metadata, bool exists)
    {
        ItemType storage t = _itemTypes[typeId];
        return (t.maxSupply, t.totalMinted, t.metadata, t.exists);
    }

    function nextTypeId() external view returns (uint256) {
        return _nextTypeId;
    }

    function nextItemId() external view returns (uint256) {
        return _nextItemId;
    }

    function computeTransferFee(uint256 value) external pure returns (uint256) {
        return (value * TRANSFER_FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
    }
}
