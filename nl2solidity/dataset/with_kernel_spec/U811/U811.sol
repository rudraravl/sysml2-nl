// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CreatureGame
 * @notice Core mechanics for a decentralized gaming platform: creature minting,
 *         leveling, and resource harvesting with a daily mint cap and platform fee.
 */
contract CreatureGame {
    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------

    struct Creature {
        uint256 creatureType;
        uint32 level;
        uint128 unclaimedResources;
        uint64 lastHarvestTimestamp;
        bool exists;
    }

    struct CreatureTypeConfig {
        uint256 baseResourceRate; // resources per second at level 1
        uint256 feedCost;         // cost in game tokens to feed (per level)
        uint256 maxLevel;
        bool enabled;
    }

    struct GlobalConfig {
        uint256 mintPrice;        // game tokens required to mint
        uint256 harvestFeeBps;     // platform fee in basis points
        uint256 dailyMintCap;
        uint256 levelUpMultiplier; // additional rate multiplier per level (bps)
    }

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error CreatureDoesNotExist();
    error CreatureTypeNotEnabled();
    error MaxLevelReached();
    error InsufficientPayment();
    error InsufficientResources();
    error DailyMintCapExceeded();
    error InvalidCreatureType();
    error TransferFailed();
    error ZeroAddress();
    error NotOperator();
    error NotOwner();
    error InvalidAmount();
    error FeeExceedsMax();
    error ReentrantCall();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event CreatureMinted(uint256 indexed tokenId, address indexed owner, uint256 creatureType);
    event CreatureLeveledUp(uint256 indexed tokenId, address indexed owner, uint32 newLevel);
    event ResourcesHarvested(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 fee);
    event CreatureTypeAdded(uint256 indexed creatureType, uint256 baseResourceRate, uint256 feedCost, uint256 maxLevel);
    event GlobalConfigUpdated(uint256 mintPrice, uint256 harvestFeeBps, uint256 dailyMintCap, uint256 levelUpMultiplier);
    event ResourceRateUpdated(uint256 indexed creatureType, uint256 newBaseRate);
    event OperatorUpdated(address indexed newOperator);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    IERC20 public immutable gameToken;
    address public feeRecipient;
    address public operator;
    address private _owner;

    uint256 private _nextTokenId = 1;
    uint256 private _locked = 1;

    mapping(uint256 => Creature) public creatures;
    mapping(uint256 => address) public creatureOwners;
    mapping(address => uint256[]) internal _ownerCreatureIds;
    mapping(uint256 => CreatureTypeConfig) public creatureTypes;
    uint256[] public availableCreatureTypes;

    GlobalConfig public config;

    uint256 public currentDay;
    uint256 public mintsToday;

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_DAILY_MINT_CAP = 1000;
    uint256 public constant DEFAULT_HARVEST_FEE_BPS = 500; // 5%

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyCreatureOwner(uint256 tokenId) {
        if (creatureOwners[tokenId] != msg.sender) revert CreatureDoesNotExist();
        _;
    }

    modifier creatureExists(uint256 tokenId) {
        if (!creatures[tokenId].exists) revert CreatureDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(
        address _gameToken,
        address _feeRecipient,
        address _operator,
        uint256 _mintPrice
    ) {
        if (_gameToken == address(0) || _feeRecipient == address(0) || _operator == address(0)) revert ZeroAddress();
        gameToken = IERC20(_gameToken);
        feeRecipient = _feeRecipient;
        operator = _operator;
        _owner = msg.sender;
        config = GlobalConfig({
            mintPrice: _mintPrice,
            harvestFeeBps: DEFAULT_HARVEST_FEE_BPS,
            dailyMintCap: DEFAULT_DAILY_MINT_CAP,
            levelUpMultiplier: 10000 // 1x base; +10000 bps per level
        });
        currentDay = block.timestamp / 1 days;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // Ownership
    // -----------------------------------------------------------------------

    function owner() external view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = _owner;
        _owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    // -----------------------------------------------------------------------
    // Operator / Admin functions
    // -----------------------------------------------------------------------

    function addCreatureType(
        uint256 creatureType,
        uint256 baseResourceRate,
        uint256 feedCost,
        uint256 maxLevel
    ) external onlyOperator {
        if (creatureTypes[creatureType].enabled) revert InvalidCreatureType();
        if (baseResourceRate == 0) revert InvalidAmount();
        if (maxLevel == 0) revert InvalidAmount();

        creatureTypes[creatureType] = CreatureTypeConfig({
            baseResourceRate: baseResourceRate,
            feedCost: feedCost,
            maxLevel: maxLevel,
            enabled: true
        });
        availableCreatureTypes.push(creatureType);
        emit CreatureTypeAdded(creatureType, baseResourceRate, feedCost, maxLevel);
    }

    function setResourceRate(uint256 creatureType, uint256 newBaseRate) external onlyOperator {
        if (!creatureTypes[creatureType].enabled) revert CreatureTypeNotEnabled();
        if (newBaseRate == 0) revert InvalidAmount();
        creatureTypes[creatureType].baseResourceRate = newBaseRate;
        emit ResourceRateUpdated(creatureType, newBaseRate);
    }

    function setGlobalConfig(
        uint256 _mintPrice,
        uint256 _harvestFeeBps,
        uint256 _dailyMintCap,
        uint256 _levelUpMultiplier
    ) external onlyOwner {
        if (_harvestFeeBps > BPS_DENOMINATOR) revert FeeExceedsMax();
        if (_dailyMintCap == 0) revert InvalidAmount();
        config = GlobalConfig({
            mintPrice: _mintPrice,
            harvestFeeBps: _harvestFeeBps,
            dailyMintCap: _dailyMintCap,
            levelUpMultiplier: _levelUpMultiplier
        });
        emit GlobalConfigUpdated(_mintPrice, _harvestFeeBps, _dailyMintCap, _levelUpMultiplier);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    // -----------------------------------------------------------------------
    // Core gameplay functions
    // -----------------------------------------------------------------------

    function mintCreature(uint256 creatureType) external nonReentrant returns (uint256 tokenId) {
        _updateDay();
        if (!creatureTypes[creatureType].enabled) revert CreatureTypeNotEnabled();
        if (mintsToday >= config.dailyMintCap) revert DailyMintCapExceeded();

        // Effects: update state before external interactions
        tokenId = _nextTokenId++;
        mintsToday++;

        creatures[tokenId] = Creature({
            creatureType: creatureType,
            level: 1,
            unclaimedResources: 0,
            lastHarvestTimestamp: uint64(block.timestamp),
            exists: true
        });
        creatureOwners[tokenId] = msg.sender;
        _ownerCreatureIds[msg.sender].push(tokenId);

        // Interactions: pull payment after state is committed
        uint256 price = config.mintPrice;
        if (price > 0) {
            bool success = gameToken.transferFrom(msg.sender, address(this), price);
            if (!success) revert TransferFailed();
        }

        emit CreatureMinted(tokenId, msg.sender, creatureType);
    }

    function feedCreature(uint256 tokenId) external nonReentrant onlyCreatureOwner(tokenId) creatureExists(tokenId) {
        Creature storage creature = creatures[tokenId];
        CreatureTypeConfig storage typeConfig = creatureTypes[creature.creatureType];

        if (creature.level >= typeConfig.maxLevel) revert MaxLevelReached();

        // Effects: accrue resources and level up before external interactions
        _accrueResources(tokenId);
        creature.level += 1;

        // Interactions: pull payment after state is committed
        uint256 cost = typeConfig.feedCost * uint256(creature.level - 1);
        if (cost > 0) {
            bool success = gameToken.transferFrom(msg.sender, address(this), cost);
            if (!success) revert TransferFailed();
        }

        emit CreatureLeveledUp(tokenId, msg.sender, creature.level);
    }

    function harvestResources(uint256 tokenId) external nonReentrant onlyCreatureOwner(tokenId) creatureExists(tokenId) {
        _accrueResources(tokenId);
        Creature storage creature = creatures[tokenId];
        uint256 amount = creature.unclaimedResources;
        if (amount == 0) revert InsufficientResources();

        // Effects: zero out balance before transfers
        creature.unclaimedResources = 0;

        uint256 fee = (amount * config.harvestFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Interactions
        if (fee > 0) {
            bool feeSuccess = gameToken.transfer(feeRecipient, fee);
            if (!feeSuccess) revert TransferFailed();
        }
        if (netAmount > 0) {
            bool success = gameToken.transfer(msg.sender, netAmount);
            if (!success) revert TransferFailed();
        }

        emit ResourcesHarvested(tokenId, msg.sender, netAmount, fee);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    function getPendingResources(uint256 tokenId) external view creatureExists(tokenId) returns (uint256) {
        Creature storage creature = creatures[tokenId];
        CreatureTypeConfig storage typeConfig = creatureTypes[creature.creatureType];

        uint256 timeElapsed = block.timestamp - creature.lastHarvestTimestamp;
        if (timeElapsed < 1) return creature.unclaimedResources;

        // Multiply before divide to preserve precision
        uint256 rateMultiplier = BPS_DENOMINATOR + (uint256(creature.level - 1) * config.levelUpMultiplier);
        uint256 generated = (typeConfig.baseResourceRate * rateMultiplier * timeElapsed) / BPS_DENOMINATOR;
        return creature.unclaimedResources + generated;
    }

    function getCreature(uint256 tokenId) external view creatureExists(tokenId) returns (
        uint256 creatureType,
        uint32 level,
        uint128 unclaimedResources,
        uint64 lastHarvestTimestamp
    ) {
        Creature storage c = creatures[tokenId];
        return (c.creatureType, c.level, c.unclaimedResources, c.lastHarvestTimestamp);
    }

    function getOwnerCreatureIds(address ownerAddr) external view returns (uint256[] memory) {
        return _ownerCreatureIds[ownerAddr];
    }

    function getCreatureTypeConfig(uint256 creatureType) external view returns (
        uint256 baseResourceRate,
        uint256 feedCost,
        uint256 maxLevel,
        bool enabled
    ) {
        CreatureTypeConfig storage c = creatureTypes[creatureType];
        return (c.baseResourceRate, c.feedCost, c.maxLevel, c.enabled);
    }

    function getAvailableCreatureTypes() external view returns (uint256[] memory) {
        return availableCreatureTypes;
    }

    function totalCreatures() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    // -----------------------------------------------------------------------
    // Internal functions
    // -----------------------------------------------------------------------

    function _updateDay() internal {
        uint256 day = block.timestamp / 1 days;
        if (day != currentDay) {
            currentDay = day;
            mintsToday = 0;
        }
    }

    function _accrueResources(uint256 tokenId) internal {
        Creature storage creature = creatures[tokenId];
        CreatureTypeConfig storage typeConfig = creatureTypes[creature.creatureType];

        uint256 timeElapsed = block.timestamp - creature.lastHarvestTimestamp;
        if (timeElapsed < 1) return;

        // Multiply before divide to preserve precision
        uint256 rateMultiplier = BPS_DENOMINATOR + (uint256(creature.level - 1) * config.levelUpMultiplier);
        uint256 generated = (typeConfig.baseResourceRate * rateMultiplier * timeElapsed) / BPS_DENOMINATOR;

        creature.unclaimedResources += uint128(generated);
        creature.lastHarvestTimestamp = uint64(block.timestamp);
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        bool success = gameToken.transfer(to, amount);
        if (!success) revert TransferFailed();
    }
}
