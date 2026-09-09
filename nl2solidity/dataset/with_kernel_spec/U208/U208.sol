// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VirtualFarmingGame {
    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------
    error NotAdmin();
    error ZeroAddress();
    error ParcelDoesNotExist();
    error NotParcelOwner();
    error ParcelSupplyCapReached();
    error CropAlreadyPlanted();
    error NoCropPlanted();
    error CropNotMature();
    error InvalidCropType();
    error AdventureTypeNotFound();
    error AdventureNotActive();
    error AdventureCooldownActive(uint256 remaining);
    error InsufficientResources(uint256 resourceType, uint256 needed, uint256 available);
    error RecipeNotFound();
    error InvalidAmount();
    error InvalidDifficulty();
    error InvalidGrowthDuration();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant PARCEL_SUPPLY_CAP = 10_000;
    uint256 public constant HARVEST_TAX_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant ADVENTURE_COOLDOWN = 24 hours;
    uint256 public constant MAX_DIFFICULTY = 100;

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------
    struct LandParcel {
        address owner;
        uint256 cropType;        // 0 = no crop planted
        uint256 plantedAt;
        uint256 growthDuration;  // seconds until mature
        uint256 yieldAmount;     // resources yielded on harvest
    }

    struct AdventureType {
        string name;
        uint256 difficulty;          // 1-MAX_DIFFICULTY
        uint256 resourceRewardType;
        uint256 minReward;
        uint256 maxReward;
        bool active;
    }

    struct CraftingRecipe {
        uint256 outputResourceType;
        uint256 outputAmount;
        uint256[] inputResourceTypes;
        uint256[] inputAmounts;
    }

    // -----------------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------------
    address public admin;
    address public treasury;

    uint256 public parcelCount;
    uint256 public adventureTypeCount;
    uint256 public recipeCount;

    mapping(uint256 => LandParcel) public parcels;
    mapping(address => mapping(uint256 => uint256)) public inventories;            // player => resourceType => amount
    mapping(address => mapping(uint256 => uint256)) public lastAdventureTime;     // player => characterId => timestamp
    mapping(uint256 => uint256) public resourceGenerationRates;                   // resourceType => base rate
    mapping(uint256 => AdventureType) public adventureTypes;
    mapping(uint256 => CraftingRecipe) public craftingRecipes;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);
    event ParcelMinted(uint256 indexed parcelId, address indexed owner);
    event CropPlanted(uint256 indexed parcelId, address indexed farmer, uint256 cropType, uint256 plantedAt, uint256 growthDuration, uint256 yieldAmount);
    event ResourcesHarvested(uint256 indexed parcelId, address indexed farmer, uint256 cropType, uint256 grossYield, uint256 tax, uint256 netYield);
    event AdventureCompleted(address indexed player, uint256 indexed characterId, uint256 indexed adventureId, uint256 resourceType, uint256 reward);
    event ItemCrafted(address indexed crafter, uint256 indexed recipeId, uint256 outputResourceType, uint256 outputAmount);
    event AdventureTypeAdded(uint256 indexed adventureId, string name, uint256 difficulty, uint256 resourceRewardType);
    event AdventureTypeToggled(uint256 indexed adventureId, bool active);
    event RecipeAdded(uint256 indexed recipeId, uint256 outputResourceType, uint256 outputAmount);
    event ResourceGenerationRateUpdated(uint256 indexed resourceType, uint256 newRate);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier validParcel(uint256 parcelId) {
        if (parcelId == 0 || parcelId > parcelCount) revert ParcelDoesNotExist();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();
        admin = msg.sender;
        treasury = _treasury;
        emit AdminChanged(address(0), msg.sender);
        emit TreasuryChanged(address(0), _treasury);
    }

    // -----------------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------------
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function setTreasury(address newTreasury) external onlyAdmin {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    function setResourceGenerationRate(uint256 resourceType, uint256 rate) external onlyAdmin {
        if (resourceType == 0) revert InvalidAmount();
        resourceGenerationRates[resourceType] = rate;
        emit ResourceGenerationRateUpdated(resourceType, rate);
    }

    function mintParcel(address to) external onlyAdmin returns (uint256 parcelId) {
        if (to == address(0)) revert ZeroAddress();
        if (parcelCount >= PARCEL_SUPPLY_CAP) revert ParcelSupplyCapReached();

        parcelId = ++parcelCount;
        parcels[parcelId] = LandParcel({
            owner: to,
            cropType: 0,
            plantedAt: 0,
            growthDuration: 0,
            yieldAmount: 0
        });
        emit ParcelMinted(parcelId, to);
    }

    function addAdventureType(
        string calldata name,
        uint256 difficulty,
        uint256 resourceRewardType,
        uint256 minReward,
        uint256 maxReward
    ) external onlyAdmin returns (uint256 adventureId) {
        if (difficulty == 0 || difficulty > MAX_DIFFICULTY) revert InvalidDifficulty();
        if (resourceRewardType == 0) revert InvalidAmount();
        if (minReward > maxReward) revert InvalidAmount();

        adventureId = ++adventureTypeCount;
        adventureTypes[adventureId] = AdventureType({
            name: name,
            difficulty: difficulty,
            resourceRewardType: resourceRewardType,
            minReward: minReward,
            maxReward: maxReward,
            active: true
        });
        emit AdventureTypeAdded(adventureId, name, difficulty, resourceRewardType);
    }

    function toggleAdventureType(uint256 adventureId, bool active) external onlyAdmin {
        if (adventureId == 0 || adventureId > adventureTypeCount) revert AdventureTypeNotFound();
        adventureTypes[adventureId].active = active;
        emit AdventureTypeToggled(adventureId, active);
    }

    function addRecipe(
        uint256 outputResourceType,
        uint256 outputAmount,
        uint256[] calldata inputResourceTypes,
        uint256[] calldata inputAmounts
    ) external onlyAdmin returns (uint256 recipeId) {
        if (outputResourceType == 0 || outputAmount == 0) revert InvalidAmount();
        if (inputResourceTypes.length == 0 || inputResourceTypes.length != inputAmounts.length) revert RecipeNotFound();

        for (uint256 i = 0; i < inputResourceTypes.length; ++i) {
            if (inputResourceTypes[i] == 0) revert InvalidAmount();
            if (inputAmounts[i] == 0) revert InvalidAmount();
        }

        recipeId = ++recipeCount;
        craftingRecipes[recipeId] = CraftingRecipe({
            outputResourceType: outputResourceType,
            outputAmount: outputAmount,
            inputResourceTypes: inputResourceTypes,
            inputAmounts: inputAmounts
        });
        emit RecipeAdded(recipeId, outputResourceType, outputAmount);
    }

    function mintResource(address to, uint256 resourceType, uint256 amount) external onlyAdmin {
        if (to == address(0)) revert ZeroAddress();
        if (resourceType == 0 || amount == 0) revert InvalidAmount();
        inventories[to][resourceType] += amount;
    }

    // -----------------------------------------------------------------------
    // Player Functions
    // -----------------------------------------------------------------------
    function plantSeed(
        uint256 parcelId,
        uint256 cropType,
        uint256 growthDuration,
        uint256 yieldAmount
    ) external validParcel(parcelId) {
        LandParcel storage parcel = parcels[parcelId];
        if (parcel.owner != msg.sender) revert NotParcelOwner();
        if (parcel.cropType != 0) revert CropAlreadyPlanted();
        if (cropType == 0) revert InvalidCropType();
        if (growthDuration == 0) revert InvalidGrowthDuration();
        if (yieldAmount == 0) revert InvalidAmount();

        parcel.cropType = cropType;
        parcel.plantedAt = block.timestamp;
        parcel.growthDuration = growthDuration;
        parcel.yieldAmount = yieldAmount;

        emit CropPlanted(parcelId, msg.sender, cropType, block.timestamp, growthDuration, yieldAmount);
    }

    function harvest(uint256 parcelId) external validParcel(parcelId) {
        LandParcel storage parcel = parcels[parcelId];
        if (parcel.owner != msg.sender) revert NotParcelOwner();
        if (parcel.cropType == 0) revert NoCropPlanted();
        if (block.timestamp < parcel.plantedAt + parcel.growthDuration) revert CropNotMature();

        uint256 cropType = parcel.cropType;
        uint256 grossYield = parcel.yieldAmount;
        uint256 tax = (grossYield * HARVEST_TAX_BPS) / BPS_DENOMINATOR;
        uint256 netYield = grossYield - tax;

        // Reset parcel crop state (effects)
        parcel.cropType = 0;
        parcel.plantedAt = 0;
        parcel.growthDuration = 0;
        parcel.yieldAmount = 0;

        // Credit player and treasury
        inventories[msg.sender][cropType] += netYield;
        inventories[treasury][cropType] += tax;

        emit ResourcesHarvested(parcelId, msg.sender, cropType, grossYield, tax, netYield);
    }

    function goOnAdventure(uint256 characterId, uint256 adventureId) external returns (uint256 rewardAmount) {
        if (adventureId == 0 || adventureId > adventureTypeCount) revert AdventureTypeNotFound();
        AdventureType storage adv = adventureTypes[adventureId];
        if (!adv.active) revert AdventureNotActive();

        uint256 lastTime = lastAdventureTime[msg.sender][characterId];
        if (block.timestamp < lastTime + ADVENTURE_COOLDOWN) {
            revert AdventureCooldownActive((lastTime + ADVENTURE_COOLDOWN) - block.timestamp);
        }

        // Update cooldown before computing reward (checks-effects-interactions)
        lastAdventureTime[msg.sender][characterId] = block.timestamp;

        // Deterministic reward scaled by difficulty.
        // Avoids weak on-chain PRNG (block.prevrandao/timestamp are miner-influenced
        // and predictable). Reward = minReward + (maxReward - minReward) * difficulty / MAX_DIFFICULTY.
        uint256 range = adv.maxReward - adv.minReward;
        rewardAmount = adv.minReward + ((range * adv.difficulty) / MAX_DIFFICULTY);

        inventories[msg.sender][adv.resourceRewardType] += rewardAmount;

        emit AdventureCompleted(msg.sender, characterId, adventureId, adv.resourceRewardType, rewardAmount);
    }

    function craft(uint256 recipeId) external returns (uint256 craftedAmount) {
        if (recipeId == 0 || recipeId > recipeCount) revert RecipeNotFound();
        CraftingRecipe storage recipe = craftingRecipes[recipeId];

        // Verify and deduct inputs (checks-effects)
        for (uint256 i = 0; i < recipe.inputResourceTypes.length; ++i) {
            uint256 inputType = recipe.inputResourceTypes[i];
            uint256 needed = recipe.inputAmounts[i];
            uint256 available = inventories[msg.sender][inputType];
            if (available < needed) {
                revert InsufficientResources(inputType, needed, available);
            }
            inventories[msg.sender][inputType] = available - needed;
        }

        craftedAmount = recipe.outputAmount;
        inventories[msg.sender][recipe.outputResourceType] += craftedAmount;

        emit ItemCrafted(msg.sender, recipeId, recipe.outputResourceType, craftedAmount);
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------
    function getInventory(address player, uint256 resourceType) external view returns (uint256) {
        return inventories[player][resourceType];
    }

    function getParcel(uint256 parcelId)
        external
        view
        validParcel(parcelId)
        returns (
            address owner,
            uint256 cropType,
            uint256 plantedAt,
            uint256 growthDuration,
            uint256 yieldAmount,
            bool isMature
        )
    {
        LandParcel storage p = parcels[parcelId];
        owner = p.owner;
        cropType = p.cropType;
        plantedAt = p.plantedAt;
        growthDuration = p.growthDuration;
        yieldAmount = p.yieldAmount;
        isMature = (p.cropType != 0) && (block.timestamp >= p.plantedAt + p.growthDuration);
    }

    function getAdventureType(uint256 adventureId)
        external
        view
        returns (
            string memory name,
            uint256 difficulty,
            uint256 resourceRewardType,
            uint256 minReward,
            uint256 maxReward,
            bool active
        )
    {
        AdventureType storage adv = adventureTypes[adventureId];
        return (adv.name, adv.difficulty, adv.resourceRewardType, adv.minReward, adv.maxReward, adv.active);
    }

    function getRecipe(uint256 recipeId)
        external
        view
        returns (
            uint256 outputResourceType,
            uint256 outputAmount,
            uint256[] memory inputResourceTypes,
            uint256[] memory inputAmounts
        )
    {
        CraftingRecipe storage r = craftingRecipes[recipeId];
        return (r.outputResourceType, r.outputAmount, r.inputResourceTypes, r.inputAmounts);
    }

    function getAdventureCooldown(address player, uint256 characterId)
        external
        view
        returns (uint256 lastTime, uint256 availableAt, bool ready)
    {
        lastTime = lastAdventureTime[player][characterId];
        availableAt = lastTime + ADVENTURE_COOLDOWN;
        ready = block.timestamp >= availableAt;
    }

    function isCropMature(uint256 parcelId) external view validParcel(parcelId) returns (bool) {
        LandParcel storage p = parcels[parcelId];
        return p.cropType != 0 && block.timestamp >= p.plantedAt + p.growthDuration;
    }
}
