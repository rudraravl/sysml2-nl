// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title GamePropertyManager
 * @notice Manages game property ownership, yield accumulation, and property trading.
 * @dev Custodies ERC721 property tokens and ERC20 game tokens for yield distribution.
 */
contract GamePropertyManager is IERC721Receiver {
    // --- Errors ---
    error NotGameAdmin();
    error PropertyNotAvailable(uint256 propertyId);
    error MaxPropertiesOwned(address player);
    error PropertyNotOwned(address player, uint256 propertyId);
    error NoYieldToCollect(uint256 propertyId);
    error TransferFailed();
    error InvalidAddress();
    error InvalidRate();
    error InvalidPrice();
    error PropertyTypeNotConfigured(uint256 propertyType);

    // --- Events ---
    event PropertyPurchased(address indexed player, uint256 indexed propertyId, uint256 propertyType, uint256 price);
    event PropertySold(address indexed player, uint256 indexed propertyId, uint256 propertyType, uint256 price);
    event YieldCollected(address indexed player, uint256 indexed propertyId, uint256 amount, uint256 fee);
    event BasePriceSet(uint256 indexed propertyType, uint256 newPrice);
    event YieldRateSet(uint256 indexed propertyType, uint256 newRate);
    event PropertyMinted(uint256 indexed propertyId, uint256 propertyType);
    event TreasuryUpdated(address indexed newTreasury);

    // --- Structs ---
    struct PropertyInfo {
        uint256 propertyType;
        uint256 lastYieldTimestamp;
        uint256 accumulatedYield;
        bool available;
    }

    struct PlayerInfo {
        uint256[] ownedProperties;
        mapping(uint256 => uint256) propertyIndex; // propertyId => index in ownedProperties + 1
    }

    struct PropertyTypeConfig {
        uint256 basePrice;
        uint256 yieldRate; // yield per second in gameToken units
        bool exists;
    }

    // --- Constants ---
    uint256 public constant MAX_PROPERTIES_PER_PLAYER = 10;
    uint256 public constant YIELD_FEE_BPS = 100; // 1% fee in basis points
    uint256 public constant BPS_DENOMINATOR = 10000;

    // --- State Variables ---
    address public gameAdmin;
    address public treasury;
    IERC721 public propertyNFT;
    IERC20 public gameToken;

    // propertyType => config
    mapping(uint256 => PropertyTypeConfig) public propertyTypes;
    // propertyId => PropertyInfo
    mapping(uint256 => PropertyInfo) public properties;
    // player address => PlayerInfo
    mapping(address => PlayerInfo) private players;
    // propertyId => current owner (within this game system)
    mapping(uint256 => address) public propertyOwner;

    uint256 public nextPropertyId;

    // --- Modifiers ---
    modifier onlyGameAdmin() {
        if (msg.sender != gameAdmin) revert NotGameAdmin();
        _;
    }

    // --- Constructor ---
    constructor(
        address _gameAdmin,
        address _treasury,
        address _propertyNFT,
        address _gameToken
    ) {
        if (_gameAdmin == address(0) || _treasury == address(0) || _propertyNFT == address(0) || _gameToken == address(0)) {
            revert InvalidAddress();
        }
        gameAdmin = _gameAdmin;
        treasury = _treasury;
        propertyNFT = IERC721(_propertyNFT);
        gameToken = IERC20(_gameToken);
        nextPropertyId = 1;
    }

    // --- Admin Functions ---

    /**
     * @notice Updates the treasury address that receives yield fees.
     * @param newTreasury The new treasury address.
     */
    function setTreasury(address newTreasury) external onlyGameAdmin {
        if (newTreasury == address(0)) revert InvalidAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @notice Sets the base purchase price for a property type.
     * @param propertyType The type identifier for the property.
     * @param price The base price in game tokens.
     */
    function setBasePrice(uint256 propertyType, uint256 price) external onlyGameAdmin {
        if (price == 0) revert InvalidPrice();
        propertyTypes[propertyType].basePrice = price;
        propertyTypes[propertyType].exists = true;
        emit BasePriceSet(propertyType, price);
    }

    /**
     * @notice Sets the yield rate (per second) for a property type.
     * @param propertyType The type identifier for the property.
     * @param rate The yield per second in game token units.
     */
    function setYieldRate(uint256 propertyType, uint256 rate) external onlyGameAdmin {
        propertyTypes[propertyType].yieldRate = rate;
        propertyTypes[propertyType].exists = true;
        emit YieldRateSet(propertyType, rate);
    }

    /**
     * @notice Mints a new property NFT and registers it in the game.
     * @param propertyType The type of the property to mint.
     * @return propertyId The ID of the newly minted property.
     */
    function mintProperty(uint256 propertyType) external onlyGameAdmin returns (uint256 propertyId) {
        if (!propertyTypes[propertyType].exists) revert PropertyTypeNotConfigured(propertyType);

        propertyId = nextPropertyId++;
        properties[propertyId] = PropertyInfo({
            propertyType: propertyType,
            lastYieldTimestamp: 0,
            accumulatedYield: 0,
            available: true
        });
        emit PropertyMinted(propertyId, propertyType);
    }

    // --- Player Functions ---

    /**
     * @notice Purchases an available property.
     * @param propertyId The ID of the property to purchase.
     */
    function purchaseProperty(uint256 propertyId) external {
        PropertyInfo storage prop = properties[propertyId];
        if (!prop.available) revert PropertyNotAvailable(propertyId);

        address player = msg.sender;
        PlayerInfo storage playerInfo = players[player];
        if (playerInfo.ownedProperties.length >= MAX_PROPERTIES_PER_PLAYER) {
            revert MaxPropertiesOwned(player);
        }

        uint256 price = propertyTypes[prop.propertyType].basePrice;
        if (price == 0) revert InvalidPrice();

        // Effects
        prop.available = false;
        prop.lastYieldTimestamp = block.timestamp;
        prop.accumulatedYield = 0;
        propertyOwner[propertyId] = player;

        // Update player's owned properties
        playerInfo.propertyIndex[propertyId] = playerInfo.ownedProperties.length + 1;
        playerInfo.ownedProperties.push(propertyId);

        // Interactions
        bool ok = gameToken.transferFrom(player, address(this), price);
        if (!ok) revert TransferFailed();

        emit PropertyPurchased(player, propertyId, prop.propertyType, price);
    }

    /**
     * @notice Collects accumulated yield for a specific owned property.
     * @param propertyId The ID of the property.
     */
    function collectYield(uint256 propertyId) external {
        address player = msg.sender;
        if (propertyOwner[propertyId] != player) revert PropertyNotOwned(player, propertyId);

        PropertyInfo storage prop = properties[propertyId];
        uint256 yieldAmount = _calculateYield(prop);

        // Avoid strict equality; use inequality to guard against no yield.
        if (yieldAmount < 1) revert NoYieldToCollect(propertyId);

        // Calculate fee (1%)
        uint256 fee = (yieldAmount * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netYield = yieldAmount - fee;

        // Effects
        prop.lastYieldTimestamp = block.timestamp;
        prop.accumulatedYield = 0;

        // Interactions
        if (gameToken.balanceOf(address(this)) < yieldAmount) revert TransferFailed();

        bool ok = gameToken.transfer(player, netYield);
        if (!ok) revert TransferFailed();

        if (fee > 0) {
            bool feeOk = gameToken.transfer(treasury, fee);
            if (!feeOk) revert TransferFailed();
        }

        emit YieldCollected(player, propertyId, netYield, fee);
    }

    /**
     * @notice Sells a property back to the game at its base price.
     * @param propertyId The ID of the property to sell.
     */
    function sellProperty(uint256 propertyId) external {
        address player = msg.sender;
        if (propertyOwner[propertyId] != player) revert PropertyNotOwned(player, propertyId);

        PropertyInfo storage prop = properties[propertyId];
        uint256 price = propertyTypes[prop.propertyType].basePrice;

        // Accrue and pay pending yield before selling
        uint256 yieldAmount = _calculateYield(prop);
        uint256 yieldFee = (yieldAmount * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        uint256 yieldPayout = yieldAmount - yieldFee;

        // Effects
        prop.available = true;
        prop.lastYieldTimestamp = 0;
        prop.accumulatedYield = 0;
        delete propertyOwner[propertyId];

        _removePropertyFromPlayer(player, propertyId);

        // Interactions
        uint256 totalNeeded = price + yieldPayout;
        if (gameToken.balanceOf(address(this)) < totalNeeded) revert TransferFailed();

        if (yieldPayout > 0) {
            bool yieldOk = gameToken.transfer(player, yieldPayout);
            if (!yieldOk) revert TransferFailed();
        }

        if (yieldFee > 0) {
            bool feeOk = gameToken.transfer(treasury, yieldFee);
            if (!feeOk) revert TransferFailed();
        }

        bool ok = gameToken.transfer(player, price);
        if (!ok) revert TransferFailed();

        emit PropertySold(player, propertyId, prop.propertyType, price);
        if (yieldAmount > 0) {
            emit YieldCollected(player, propertyId, yieldPayout, yieldFee);
        }
    }

    // --- View Functions ---

    /**
     * @notice Returns the pending yield for a specific property.
     * @param propertyId The ID of the property.
     * @return yieldAmount The amount of pending yield.
     */
    function getPendingYield(uint256 propertyId) external view returns (uint256 yieldAmount) {
        yieldAmount = _calculateYield(properties[propertyId]);
    }

    /**
     * @notice Returns the list of property IDs owned by a player.
     * @param player The address of the player.
     * @return propertyIds Array of owned property IDs.
     */
    function getOwnedProperties(address player) external view returns (uint256[] memory propertyIds) {
        return players[player].ownedProperties;
    }

    /**
     * @notice Returns the total pending yield for all properties owned by a player.
     * @param player The address of the player.
     * @return totalYield The total pending yield.
     */
    function getTotalPendingYield(address player) external view returns (uint256 totalYield) {
        uint256[] memory owned = players[player].ownedProperties;
        for (uint256 i = 0; i < owned.length; i++) {
            totalYield += _calculateYield(properties[owned[i]]);
        }
    }

    /**
     * @notice Returns the number of properties owned by a player.
     * @param player The address of the player.
     * @return count The number of owned properties.
     */
    function getPropertyCount(address player) external view returns (uint256 count) {
        return players[player].ownedProperties.length;
    }

    /**
     * @notice Returns the configuration for a property type.
     * @param propertyType The property type identifier.
     * @return basePrice The base price of the property type.
     * @return yieldRate The yield rate per second.
     * @return exists Whether the property type is configured.
     */
    function getPropertyTypeConfig(uint256 propertyType)
        external
        view
        returns (uint256 basePrice, uint256 yieldRate, bool exists)
    {
        PropertyTypeConfig memory cfg = propertyTypes[propertyType];
        return (cfg.basePrice, cfg.yieldRate, cfg.exists);
    }

    // --- Internal Functions ---

    /**
     * @dev Calculates the pending yield for a property since last update.
     * @param prop The property info storage reference.
     * @return yieldAmount The calculated yield amount.
     */
    function _calculateYield(PropertyInfo storage prop) internal view returns (uint256 yieldAmount) {
        yieldAmount = prop.accumulatedYield;

        if (prop.lastYieldTimestamp == 0 || block.timestamp <= prop.lastYieldTimestamp) {
            return yieldAmount;
        }

        uint256 rate = propertyTypes[prop.propertyType].yieldRate;
        if (rate == 0) return yieldAmount;

        uint256 timeElapsed = block.timestamp - prop.lastYieldTimestamp;
        yieldAmount += timeElapsed * rate;
    }

    /**
     * @dev Removes a property from a player's owned list.
     * @param player The address of the player.
     * @param propertyId The ID of the property to remove.
     */
    function _removePropertyFromPlayer(address player, uint256 propertyId) internal {
        PlayerInfo storage playerInfo = players[player];
        uint256 index = playerInfo.propertyIndex[propertyId];
        if (index == 0) return;

        index--; // Convert from 1-based to 0-based
        uint256 lastIndex = playerInfo.ownedProperties.length - 1;

        if (index != lastIndex) {
            uint256 lastPropertyId = playerInfo.ownedProperties[lastIndex];
            playerInfo.ownedProperties[index] = lastPropertyId;
            playerInfo.propertyIndex[lastPropertyId] = index + 1;
        }

        playerInfo.ownedProperties.pop();
        delete playerInfo.propertyIndex[propertyId];
    }

    // --- ERC721 Receiver ---

    /**
     * @notice Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
