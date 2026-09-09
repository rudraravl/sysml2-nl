// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RPGProgression
 * @notice Manages player progression, experience points, and quest completion
 *         for a decentralized role-playing game. Holds no custodial assets.
 */
contract RPGProgression {
    uint256 public constant MIN_QUEST_XP = 10;
    uint256 public constant MAX_QUEST_XP = 1000;
    uint256 public constant LEVEL_UP_BASE_COST = 100;
    uint256 public constant STARTING_LEVEL = 1;
    uint256 public constant MAX_LEVEL = 100;

    struct Player {
        uint256 xp;
        uint256 level;
        uint256 progressGeneration;
        bool initialized;
        mapping(uint256 => uint256) completedQuests;
    }

    struct Quest {
        string name;
        uint256 xpReward;
        bool exists;
    }

    address private _owner;

    mapping(address => Player) internal _players;
    mapping(uint256 => Quest) internal _quests;
    uint256[] internal _questIds;
    uint256 public questCount;

    event GameStarted(address indexed player);
    event QuestDefined(uint256 indexed questId, string name, uint256 xpReward);
    event QuestXpUpdated(uint256 indexed questId, uint256 oldXpReward, uint256 newXpReward);
    event QuestCompleted(address indexed player, uint256 indexed questId, uint256 xpEarned);
    event LevelUp(address indexed player, uint256 newLevel, uint256 xpSpent);
    event PlayerReset(address indexed player);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error PlayerAlreadyInitialized();
    error PlayerNotInitialized();
    error QuestDoesNotExist();
    error QuestIdAlreadyUsed();
    error QuestAlreadyCompleted();
    error InvalidXpReward();
    error InsufficientXp(uint256 available, uint256 required);
    error MaxLevelReached(uint256 currentLevel);
    error InvalidLevelUpAmount();
    error NotOwner();
    error InvalidOwnerAddress();

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyInitializedPlayer() {
        if (!_players[msg.sender].initialized) revert PlayerNotInitialized();
        _;
    }

    constructor(address admin) {
        if (admin == address(0)) revert InvalidOwnerAddress();
        _owner = admin;
        emit OwnershipTransferred(address(0), admin);
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidOwnerAddress();
        address previous = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function startGame() external {
        Player storage player = _players[msg.sender];
        if (player.initialized) revert PlayerAlreadyInitialized();
        player.initialized = true;
        player.level = STARTING_LEVEL;
        player.xp = 0;
        player.progressGeneration = 1;
        emit GameStarted(msg.sender);
    }

    function completeQuest(uint256 questId) external onlyInitializedPlayer {
        Quest storage quest = _quests[questId];
        if (!quest.exists) revert QuestDoesNotExist();

        Player storage player = _players[msg.sender];
        if (player.completedQuests[questId] == player.progressGeneration) {
            revert QuestAlreadyCompleted();
        }

        player.completedQuests[questId] = player.progressGeneration;
        uint256 reward = quest.xpReward;
        player.xp += reward;

        emit QuestCompleted(msg.sender, questId, reward);
    }

    function levelUp(uint256 levels) external onlyInitializedPlayer {
        if (levels == 0) revert InvalidLevelUpAmount();

        Player storage player = _players[msg.sender];
        uint256 currentLevel = player.level;
        if (currentLevel >= MAX_LEVEL) revert MaxLevelReached(currentLevel);

        uint256 remaining = MAX_LEVEL - currentLevel;
        if (levels > remaining) levels = remaining;

        uint256 xpRequired = 0;
        for (uint256 i = 0; i < levels; i++) {
            xpRequired += LEVEL_UP_BASE_COST * (currentLevel + i);
        }

        if (player.xp < xpRequired) {
            revert InsufficientXp(player.xp, xpRequired);
        }

        player.xp -= xpRequired;
        player.level = currentLevel + levels;

        emit LevelUp(msg.sender, player.level, xpRequired);
    }

    function defineQuest(uint256 questId, string calldata name, uint256 xpReward) external onlyOwner {
        if (xpReward < MIN_QUEST_XP || xpReward > MAX_QUEST_XP) revert InvalidXpReward();
        if (_quests[questId].exists) revert QuestIdAlreadyUsed();

        _quests[questId].name = name;
        _quests[questId].xpReward = xpReward;
        _quests[questId].exists = true;
        _questIds.push(questId);
        questCount++;

        emit QuestDefined(questId, name, xpReward);
    }

    function updateQuestXp(uint256 questId, uint256 newXpReward) external onlyOwner {
        Quest storage quest = _quests[questId];
        if (!quest.exists) revert QuestDoesNotExist();
        if (newXpReward < MIN_QUEST_XP || newXpReward > MAX_QUEST_XP) revert InvalidXpReward();

        uint256 oldXpReward = quest.xpReward;
        quest.xpReward = newXpReward;

        emit QuestXpUpdated(questId, oldXpReward, newXpReward);
    }

    function resetPlayer(address player) external onlyOwner {
        Player storage p = _players[player];
        if (!p.initialized) revert PlayerNotInitialized();

        p.xp = 0;
        p.level = STARTING_LEVEL;
        p.progressGeneration++; // invalidates all completed-quest entries without looping

        emit PlayerReset(player);
    }

    function levelUpCost(uint256 currentLevel) public pure returns (uint256) {
        return LEVEL_UP_BASE_COST * currentLevel;
    }

    function getXpRequiredForLevelUp(address player, uint256 levels)
        external
        view
        returns (uint256 xpRequired)
    {
        if (!_players[player].initialized) revert PlayerNotInitialized();
        if (levels == 0) revert InvalidLevelUpAmount();

        uint256 currentLevel = _players[player].level;
        uint256 remaining = MAX_LEVEL - currentLevel;
        if (levels > remaining) levels = remaining;

        for (uint256 i = 0; i < levels; i++) {
            xpRequired += LEVEL_UP_BASE_COST * (currentLevel + i);
        }
    }

    function getPlayer(address player)
        external
        view
        returns (uint256 xp, uint256 level, bool initialized)
    {
        Player storage p = _players[player];
        return (p.xp, p.level, p.initialized);
    }

    function getPlayerXp(address player) external view returns (uint256) {
        return _players[player].xp;
    }

    function getPlayerLevel(address player) external view returns (uint256) {
        return _players[player].level;
    }

    function isPlayerInitialized(address player) external view returns (bool) {
        return _players[player].initialized;
    }

    function hasCompletedQuest(address player, uint256 questId) external view returns (bool) {
        Player storage p = _players[player];
        return p.completedQuests[questId] == p.progressGeneration;
    }

    function getQuest(uint256 questId)
        external
        view
        returns (string memory name, uint256 xpReward, bool exists)
    {
        Quest storage q = _quests[questId];
        return (q.name, q.xpReward, q.exists);
    }

    function getQuestXpReward(uint256 questId) external view returns (uint256) {
        return _quests[questId].xpReward;
    }

    function questExists(uint256 questId) external view returns (bool) {
        return _quests[questId].exists;
    }

    function getQuestCount() external view returns (uint256) {
        return _questIds.length;
    }

    function getAllQuestIds() external view returns (uint256[] memory) {
        return _questIds;
    }
}
