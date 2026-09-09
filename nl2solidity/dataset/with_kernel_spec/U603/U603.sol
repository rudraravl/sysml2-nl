// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OnChainRPG
 * @notice Manages player progression, resource ownership, and item crafting within an on-chain RPG.
 */
contract OnChainRPG {
    // ---------------------------------------------------------------------
    //                              Errors
    // ---------------------------------------------------------------------

    error NotAuthorized();
    error NotOperator();
    error PlayerNotFound();
    error AlreadyRegistered();
    error InsufficientExperience(uint256 required, uint256 available);
    error InsufficientLevel(uint256 required, uint256 current);
    error InsufficientItem(uint256 itemId, uint256 required, uint256 available);
    error RecipeNotFound(uint256 recipeId);
    error RecipeNotCraftable(uint256 recipeId);
    error UnknownItem(uint256 itemId);
    error LegendaryNotReady(uint256 requestId, uint256 blocksRemaining);
    error NothingToClaim(address player);
    error ZeroAddress();
    error ZeroAmount();

    // ---------------------------------------------------------------------
    //                              Events
    // ---------------------------------------------------------------------

    event PlayerRegistered(address indexed player, uint256 timestamp);
    event ExperienceGained(address indexed player, uint256 amount, uint256 newTotal);
    event LevelUp(address indexed player, uint256 oldLevel, uint256 newLevel);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemConsumed(address indexed player, uint256 indexed itemId, uint256 amount);
    event RecipeAdded(uint256 indexed recipeId, uint256 outputItem, uint256 outputAmount, bool isRare, bool isLegendary);
    event RecipeUpdated(uint256 indexed recipeId, uint256 outputItem, uint256 outputAmount, bool isRare, bool isLegendary);
    event CraftInitiated(address indexed player, uint256 indexed recipeId, uint256 requestId, uint256 deliverableBlock);
    event CraftCompleted(address indexed player, uint256 indexed recipeId, uint256 outputItem, uint256 outputAmount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    //                              Types
    // ---------------------------------------------------------------------

    struct Player {
        uint256 experience;
        uint256 level;
        bool registered;
    }

    struct Ingredient {
        uint256 itemId;
        uint256 amount;
    }

    struct Recipe {
        uint256 outputItem;
        uint256 outputAmount;
        Ingredient[] ingredients;
        bool isRare;
        bool isLegendary;
        bool exists;
    }

    struct PendingLegendary {
        address player;
        uint256 recipeId;
        uint256 deliverableBlock;
        bool claimed;
    }

    // ---------------------------------------------------------------------
    //                       State Variables
    // ---------------------------------------------------------------------

    address public operator;

    uint256 public constant RARE_LEVEL_REQUIREMENT = 5;
    uint256 public constant LEGENDARY_DELAY_BLOCKS = 10;
    uint256 public constant XP_PER_LEVEL = 1000;

    uint256 private _nextRecipeId = 1;
    uint256 private _nextLegendaryRequestId = 1;

    mapping(address => Player) public players;
    mapping(address => mapping(uint256 => uint256)) public itemBalances;
    mapping(uint256 => Recipe) public recipes;
    mapping(uint256 => PendingLegendary) public pendingLegendary;

    mapping(address => uint256[]) internal _playerPendingRequests;

    // ---------------------------------------------------------------------
    //                            Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyRegistered() {
        if (!players[msg.sender].registered) revert PlayerNotFound();
        _;
    }

    // ---------------------------------------------------------------------
    //                           Constructor
    // ---------------------------------------------------------------------

    constructor(address operator_) {
        if (operator_ == address(0)) revert ZeroAddress();
        operator = operator_;
        emit OperatorUpdated(address(0), operator_);
    }

    // ---------------------------------------------------------------------
    //                     Operator Administration
    // ---------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Mints item tokens to a player. Only callable by the operator.
     */
    function mintItem(address to, uint256 itemId, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (itemId == 0) revert UnknownItem(itemId);
        if (amount == 0) revert ZeroAmount();
        itemBalances[to][itemId] += amount;
        emit ItemMinted(to, itemId, amount);
    }

    /**
     * @notice Adds a new crafting recipe. Only callable by the operator.
     */
    function addRecipe(
        uint256 outputItem,
        uint256 outputAmount,
        Ingredient[] calldata ingredients,
        bool isRare,
        bool isLegendary
    ) external onlyOperator returns (uint256 recipeId) {
        if (outputItem == 0) revert UnknownItem(outputItem);
        if (outputAmount == 0) revert RecipeNotCraftable(0);
        if (isRare && isLegendary) revert RecipeNotCraftable(0);

        recipeId = _nextRecipeId++;
        Recipe storage recipe = recipes[recipeId];
        recipe.outputItem = outputItem;
        recipe.outputAmount = outputAmount;
        recipe.isRare = isRare;
        recipe.isLegendary = isLegendary;
        recipe.exists = true;

        for (uint256 i = 0; i < ingredients.length; i++) {
            if (ingredients[i].itemId == 0) revert UnknownItem(ingredients[i].itemId);
            if (ingredients[i].amount == 0) revert ZeroAmount();
            recipe.ingredients.push(ingredients[i]);
        }

        emit RecipeAdded(recipeId, outputItem, outputAmount, isRare, isLegendary);
    }

    /**
     * @notice Updates an existing crafting recipe. Only callable by the operator.
     */
    function updateRecipe(
        uint256 recipeId,
        uint256 outputItem,
        uint256 outputAmount,
        Ingredient[] calldata ingredients,
        bool isRare,
        bool isLegendary
    ) external onlyOperator {
        Recipe storage recipe = recipes[recipeId];
        if (!recipe.exists) revert RecipeNotFound(recipeId);
        if (outputItem == 0) revert UnknownItem(outputItem);
        if (outputAmount == 0) revert RecipeNotCraftable(recipeId);
        if (isRare && isLegendary) revert RecipeNotCraftable(recipeId);

        delete recipe.ingredients;

        recipe.outputItem = outputItem;
        recipe.outputAmount = outputAmount;
        recipe.isRare = isRare;
        recipe.isLegendary = isLegendary;

        for (uint256 i = 0; i < ingredients.length; i++) {
            if (ingredients[i].itemId == 0) revert UnknownItem(ingredients[i].itemId);
            if (ingredients[i].amount == 0) revert ZeroAmount();
            recipe.ingredients.push(ingredients[i]);
        }

        emit RecipeUpdated(recipeId, outputItem, outputAmount, isRare, isLegendary);
    }

    // ---------------------------------------------------------------------
    //                       Player Registration
    // ---------------------------------------------------------------------

    /**
     * @notice Registers the caller as a new player.
     */
    function registerPlayer() external {
        Player storage p = players[msg.sender];
        if (p.registered) revert AlreadyRegistered();
        p.registered = true;
        p.level = 1;
        emit PlayerRegistered(msg.sender, block.timestamp);
    }

    // ---------------------------------------------------------------------
    //                     Progression: Experience & Level
    // ---------------------------------------------------------------------

    /**
     * @notice Grants experience to a player. Only callable by the operator.
     */
    function grantExperience(address player, uint256 amount) external onlyOperator {
        Player storage p = players[player];
        if (!p.registered) revert PlayerNotFound();
        if (amount == 0) revert ZeroAmount();
        p.experience += amount;
        emit ExperienceGained(player, amount, p.experience);
    }

    /**
     * @notice Levels up the caller if they have accumulated enough experience.
     */
    function levelUp() external onlyRegistered {
        Player storage p = players[msg.sender];
        uint256 required = p.level * XP_PER_LEVEL;
        if (p.experience < required) {
            revert InsufficientExperience(required, p.experience);
        }
        uint256 oldLevel = p.level;
        p.level += 1;
        emit LevelUp(msg.sender, oldLevel, p.level);
    }

    // ---------------------------------------------------------------------
    //                          Item Consumption
    // ---------------------------------------------------------------------

    /**
     * @notice Consumes a quantity of an item for an in-game effect.
     */
    function consumeItem(uint256 itemId, uint256 amount) external onlyRegistered {
        if (itemId == 0) revert UnknownItem(itemId);
        if (amount == 0) revert ZeroAmount();
        uint256 bal = itemBalances[msg.sender][itemId];
        if (bal < amount) revert InsufficientItem(itemId, amount, bal);
        itemBalances[msg.sender][itemId] = bal - amount;
        emit ItemConsumed(msg.sender, itemId, amount);
    }

    // ---------------------------------------------------------------------
    //                              Crafting
    // ---------------------------------------------------------------------

    /**
     * @notice Initiates crafting of a recipe. For legendary items, delivery is delayed by
     *         LEGENDARY_DELAY_BLOCKS blocks and must be claimed via {claimLegendary}.
     */
    function craft(uint256 recipeId) external onlyRegistered {
        Recipe storage recipe = recipes[recipeId];
        if (!recipe.exists) revert RecipeNotFound(recipeId);

        Player storage p = players[msg.sender];

        if (recipe.isRare && p.level < RARE_LEVEL_REQUIREMENT) {
            revert InsufficientLevel(RARE_LEVEL_REQUIREMENT, p.level);
        }

        uint256 len = recipe.ingredients.length;
        for (uint256 i = 0; i < len; i++) {
            Ingredient storage ing = recipe.ingredients[i];
            uint256 bal = itemBalances[msg.sender][ing.itemId];
            if (bal < ing.amount) {
                revert InsufficientItem(ing.itemId, ing.amount, bal);
            }
            itemBalances[msg.sender][ing.itemId] = bal - ing.amount;
        }

        if (recipe.isLegendary) {
            uint256 requestId = _nextLegendaryRequestId++;
            uint256 deliverableBlock = block.number + LEGENDARY_DELAY_BLOCKS;
            pendingLegendary[requestId] = PendingLegendary({
                player: msg.sender,
                recipeId: recipeId,
                deliverableBlock: deliverableBlock,
                claimed: false
            });
            _playerPendingRequests[msg.sender].push(requestId);
            emit CraftInitiated(msg.sender, recipeId, requestId, deliverableBlock);
        } else {
            itemBalances[msg.sender][recipe.outputItem] += recipe.outputAmount;
            emit CraftCompleted(msg.sender, recipeId, recipe.outputItem, recipe.outputAmount);
        }
    }

    /**
     * @notice Claims a legendary item after the required block delay has elapsed.
     */
    function claimLegendary(uint256 requestId) external onlyRegistered {
        PendingLegendary storage pending = pendingLegendary[requestId];
        if (pending.player == address(0)) revert RecipeNotFound(requestId);
        if (pending.player != msg.sender) revert NotAuthorized();
        if (pending.claimed) revert NothingToClaim(msg.sender);
        if (block.number < pending.deliverableBlock) {
            revert LegendaryNotReady(requestId, pending.deliverableBlock - block.number);
        }

        pending.claimed = true;

        Recipe storage recipe = recipes[pending.recipeId];
        itemBalances[msg.sender][recipe.outputItem] += recipe.outputAmount;

        emit CraftCompleted(msg.sender, pending.recipeId, recipe.outputItem, recipe.outputAmount);
    }

    // ---------------------------------------------------------------------
    //                          View Functions
    // ---------------------------------------------------------------------

    function getPlayer(address player) external view returns (uint256 experience, uint256 level, bool registered) {
        Player storage p = players[player];
        return (p.experience, p.level, p.registered);
    }

    function getItemBalance(address player, uint256 itemId) external view returns (uint256) {
        return itemBalances[player][itemId];
    }

    function getRecipe(uint256 recipeId) external view returns (
        uint256 outputItem,
        uint256 outputAmount,
        bool isRare,
        bool isLegendary,
        bool exists,
        Ingredient[] memory ingredients
    ) {
        Recipe storage r = recipes[recipeId];
        return (r.outputItem, r.outputAmount, r.isRare, r.isLegendary, r.exists, r.ingredients);
    }

    function getPendingLegendary(uint256 requestId) external view returns (
        address player,
        uint256 recipeId,
        uint256 deliverableBlock,
        bool claimed
    ) {
        PendingLegendary storage p = pendingLegendary[requestId];
        return (p.player, p.recipeId, p.deliverableBlock, p.claimed);
    }

    function getPendingLegendaryRequests(address player) external view returns (uint256[] memory) {
        return _playerPendingRequests[player];
    }

    function nextRecipeId() external view returns (uint256) {
        return _nextRecipeId;
    }

    function nextLegendaryRequestId() external view returns (uint256) {
        return _nextLegendaryRequestId;
    }
}
