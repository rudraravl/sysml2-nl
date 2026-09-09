// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract CompetitiveGamingPlatform {
    uint256 public constant MAX_EQUIPPED_ITEMS = 5;
    uint256 public constant FEE_BASIS_POINTS = 200;
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 public constant INITIAL_HERO_STAT = 100;
    uint256 public constant LEVEL_DIVISOR = 100;

    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error BattleNotFound();
    error NotHeroOwner();
    error HeroNotRegistered();
    error HeroAlreadyRegistered();
    error HeroAlreadyInBattle();
    error MaxItemsReached();
    error ItemNotEquipped();
    error ItemAlreadyEquipped();
    error InsufficientTrainingPoints();
    error InsufficientBalance();
    error BattleNotActive();
    error BattleAlreadyStarted();
    error BattleAlreadyCompleted();
    error BattleNotCompleted();
    error BattleAlreadyDistributed();
    error BattleNotDistributed();
    error NotBattleWinner();
    error AlreadyClaimed();
    error InvalidTimeRange();
    error BattleNotInScheduleWindow();
    error NoParticipants();
    error InvalidWinner();
    error TransferFailed();
    error InsufficientRewardPool();
    error ArrayLengthMismatch();
    error ReentrancyDetected();

    event GameTokensDeposited(address indexed player, uint256 amount);
    event GameTokensWithdrawn(address indexed player, uint256 amount);
    event HeroRegistered(address indexed player, uint256 indexed tokenId);
    event HeroUnregistered(address indexed player, uint256 indexed tokenId);
    event ItemEquipped(address indexed player, uint256 indexed heroId, uint256 itemId);
    event ItemUnequipped(address indexed player, uint256 indexed heroId, uint256 itemId);
    event TrainingPointsAllocated(address indexed player, uint256 indexed heroId, uint256 points, uint256 newPower);
    event HeroEnteredBattle(uint256 indexed battleId, uint256 indexed heroId, address indexed player);
    event BattleCreated(uint256 indexed battleId, uint256 startTime, uint256 endTime);
    event BattleCommenced(uint256 indexed battleId, uint256 startTime, uint256 participantCount);
    event BattleResult(uint256 indexed battleId, uint256 winnerHeroId, address winner);
    event RewardDistributed(uint256 indexed battleId, address indexed winner, uint256 amount);
    event RewardsClaimed(address indexed player, uint256 indexed battleId, uint256 amount, uint256 fee);
    event BattleScheduleUpdated(uint256 start, uint256 end);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeReceiverUpdated(address indexed oldFeeReceiver, address indexed newFeeReceiver);
    event RewardsDeposited(address indexed depositor, uint256 amount);

    struct HeroStats {
        uint256 power;
        uint256 defense;
        uint256 speed;
        uint256 level;
    }

    struct Hero {
        address owner;
        uint256 tokenId;
        HeroStats stats;
        uint256[] equippedItems;
        uint256 trainingPoints;
        bool isRegistered;
    }

    struct Player {
        uint256 depositedTokens;
        uint256 availableTrainingPoints;
        uint256 totalClaimed;
        uint256[] heroIds;
    }

    struct Battle {
        uint256 battleId;
        address[] participants;
        uint256[] heroIds;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isCompleted;
        bool isDistributed;
        uint256 winnerHeroId;
        address winner;
        uint256 rewardPool;
        mapping(address => bool) hasClaimed;
    }

    IERC20 public immutable gameToken;
    IERC721 public immutable heroToken;

    address public owner;
    address public operator;
    address public feeReceiver;

    uint256 public battleScheduleStart;
    uint256 public battleScheduleEnd;
    uint256 public totalRewardPool;
    uint256 public battleCount;

    uint256 private _locked; // reentrancy guard: 1 = locked, 2 = unlocked

    mapping(address => Player) public players;
    mapping(uint256 => Hero) public heroes;
    mapping(uint256 => Battle) internal battles;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrancyDetected();
        _locked = 1;
        _;
        _locked = 2;
    }

    constructor(
        address _gameToken,
        address _heroToken,
        address _operator,
        address _feeReceiver,
        uint256 _battleScheduleStart,
        uint256 _battleScheduleEnd
    ) {
        if (_gameToken == address(0) || _heroToken == address(0)) revert ZeroAddress();
        if (_operator == address(0) || _feeReceiver == address(0)) revert ZeroAddress();
        if (_battleScheduleStart >= _battleScheduleEnd) revert InvalidTimeRange();
        gameToken = IERC20(_gameToken);
        heroToken = IERC721(_heroToken);
        owner = msg.sender;
        operator = _operator;
        feeReceiver = _feeReceiver;
        battleScheduleStart = _battleScheduleStart;
        battleScheduleEnd = _battleScheduleEnd;
        _locked = 2;
        emit BattleScheduleUpdated(_battleScheduleStart, _battleScheduleEnd);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeReceiver(address newFeeReceiver) external onlyOwner {
        if (newFeeReceiver == address(0)) revert ZeroAddress();
        emit FeeReceiverUpdated(feeReceiver, newFeeReceiver);
        feeReceiver = newFeeReceiver;
    }

    function setBattleSchedule(uint256 start, uint256 end) external onlyOwner {
        if (start >= end) revert InvalidTimeRange();
        battleScheduleStart = start;
        battleScheduleEnd = end;
        emit BattleScheduleUpdated(start, end);
    }

    function depositRewards(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        if (!gameToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        totalRewardPool += amount;
        emit RewardsDeposited(msg.sender, amount);
    }

    function createBattle(uint256 startTime, uint256 endTime) external onlyOperator {
        if (startTime >= endTime) revert InvalidTimeRange();
        if (startTime < battleScheduleStart || endTime > battleScheduleEnd) revert BattleNotInScheduleWindow();
        uint256 battleId = ++battleCount;
        Battle storage battle = battles[battleId];
        battle.battleId = battleId;
        battle.startTime = startTime;
        battle.endTime = endTime;
        emit BattleCreated(battleId, startTime, endTime);
    }

    function commenceBattle(uint256 battleId) external onlyOperator {
        if (battleId == 0 || battleId > battleCount) revert BattleNotFound();
        Battle storage battle = battles[battleId];
        if (battle.isActive) revert BattleAlreadyStarted();
        if (battle.isCompleted) revert BattleAlreadyCompleted();
        if (battle.participants.length == 0) revert NoParticipants();
        battle.isActive = true;
        battle.startTime = block.timestamp;
        emit BattleCommenced(battleId, battle.startTime, battle.participants.length);
    }

    function determineBattleResult(uint256 battleId, uint256 winnerHeroId) external onlyOperator {
        if (battleId == 0 || battleId > battleCount) revert BattleNotFound();
        Battle storage battle = battles[battleId];
        if (!battle.isActive) revert BattleNotActive();
        if (battle.isCompleted) revert BattleAlreadyCompleted();

        bool found = false;
        for (uint256 i = 0; i < battle.heroIds.length; i++) {
            if (battle.heroIds[i] == winnerHeroId) {
                found = true;
                break;
            }
        }
        if (!found) revert InvalidWinner();

        battle.isActive = false;
        battle.isCompleted = true;
        battle.winnerHeroId = winnerHeroId;
        battle.winner = heroes[winnerHeroId].owner;
        battle.endTime = block.timestamp;

        emit BattleResult(battleId, winnerHeroId, battle.winner);
    }

    function distributeRewards(uint256 battleId, uint256 rewardAmount) external onlyOperator {
        if (battleId == 0 || battleId > battleCount) revert BattleNotFound();
        Battle storage battle = battles[battleId];
        if (!battle.isCompleted) revert BattleNotCompleted();
        if (battle.isDistributed) revert BattleAlreadyDistributed();
        if (totalRewardPool < rewardAmount) revert InsufficientRewardPool();

        totalRewardPool -= rewardAmount;
        battle.rewardPool = rewardAmount;
        battle.isDistributed = true;

        emit RewardDistributed(battleId, battle.winner, rewardAmount);
    }

    function depositGameTokens(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        players[msg.sender].depositedTokens += amount;
        players[msg.sender].availableTrainingPoints += amount;
        if (!gameToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit GameTokensDeposited(msg.sender, amount);
    }

    function withdrawGameTokens(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Player storage p = players[msg.sender];
        if (p.availableTrainingPoints < amount) revert InsufficientTrainingPoints();
        p.depositedTokens -= amount;
        p.availableTrainingPoints -= amount;
        if (!gameToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit GameTokensWithdrawn(msg.sender, amount);
    }

    function registerHero(uint256 tokenId) external nonReentrant {
        if (heroToken.ownerOf(tokenId) != msg.sender) revert NotHeroOwner();
        if (heroes[tokenId].isRegistered) revert HeroAlreadyRegistered();

        // Effects: set state before external transfer
        Hero storage hero = heroes[tokenId];
        hero.owner = msg.sender;
        hero.tokenId = tokenId;
        hero.stats = HeroStats({
            power: INITIAL_HERO_STAT,
            defense: INITIAL_HERO_STAT,
            speed: INITIAL_HERO_STAT,
            level: 1
        });
        hero.isRegistered = true;

        players[msg.sender].heroIds.push(tokenId);

        // Interactions: transfer NFT after state is set
        heroToken.transferFrom(msg.sender, address(this), tokenId);

        emit HeroRegistered(msg.sender, tokenId);
    }

    function unregisterHero(uint256 heroId) external nonReentrant {
        Hero storage hero = heroes[heroId];
        if (!hero.isRegistered) revert HeroNotRegistered();
        if (hero.owner != msg.sender) revert NotHeroOwner();

        // Effects: update state before external transfer
        uint256[] storage heroList = players[msg.sender].heroIds;
        for (uint256 i = 0; i < heroList.length; i++) {
            if (heroList[i] == heroId) {
                heroList[i] = heroList[heroList.length - 1];
                heroList.pop();
                break;
            }
        }

        delete heroes[heroId];

        // Interactions: transfer NFT after state is cleared
        heroToken.transferFrom(address(this), msg.sender, heroId);

        emit HeroUnregistered(msg.sender, heroId);
    }

    function equipItem(uint256 heroId, uint256 itemId) external {
        Hero storage hero = heroes[heroId];
        if (!hero.isRegistered) revert HeroNotRegistered();
        if (hero.owner != msg.sender) revert NotHeroOwner();
        if (hero.equippedItems.length >= MAX_EQUIPPED_ITEMS) revert MaxItemsReached();

        for (uint256 i = 0; i < hero.equippedItems.length; i++) {
            if (hero.equippedItems[i] == itemId) revert ItemAlreadyEquipped();
        }

        hero.equippedItems.push(itemId);
        emit ItemEquipped(msg.sender, heroId, itemId);
    }

    function unequipItem(uint256 heroId, uint256 itemId) external {
        Hero storage hero = heroes[heroId];
        if (!hero.isRegistered) revert HeroNotRegistered();
        if (hero.owner != msg.sender) revert NotHeroOwner();

        uint256[] storage items = hero.equippedItems;
        bool found = false;
        uint256 index = 0;
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i] == itemId) {
                found = true;
                index = i;
                break;
            }
        }
        if (!found) revert ItemNotEquipped();

        if (index != items.length - 1) {
            items[index] = items[items.length - 1];
        }
        items.pop();

        emit ItemUnequipped(msg.sender, heroId, itemId);
    }

    function allocateTrainingPoints(uint256 heroId, uint256 points) external {
        if (points == 0) revert ZeroAmount();
        Hero storage hero = heroes[heroId];
        if (!hero.isRegistered) revert HeroNotRegistered();
        if (hero.owner != msg.sender) revert NotHeroOwner();
        if (players[msg.sender].availableTrainingPoints < points) revert InsufficientTrainingPoints();

        players[msg.sender].availableTrainingPoints -= points;
        hero.trainingPoints += points;
        hero.stats.power += points;
        hero.stats.defense += points;
        hero.stats.speed += points;
        hero.stats.level = 1 + hero.trainingPoints / LEVEL_DIVISOR;

        emit TrainingPointsAllocated(msg.sender, heroId, points, hero.stats.power);
    }

    function enterBattle(uint256 battleId, uint256 heroId) external {
        if (battleId == 0 || battleId > battleCount) revert BattleNotFound();
        Battle storage battle = battles[battleId];
        if (battle.isActive) revert BattleAlreadyStarted();
        if (battle.isCompleted) revert BattleAlreadyCompleted();

        Hero storage hero = heroes[heroId];
        if (!hero.isRegistered) revert HeroNotRegistered();
        if (hero.owner != msg.sender) revert NotHeroOwner();

        for (uint256 i = 0; i < battle.heroIds.length; i++) {
            if (battle.heroIds[i] == heroId) revert HeroAlreadyInBattle();
        }

        battle.participants.push(msg.sender);
        battle.heroIds.push(heroId);

        emit HeroEnteredBattle(battleId, heroId, msg.sender);
    }

    function claimRewards(uint256 battleId) external nonReentrant {
        if (battleId == 0 || battleId > battleCount) revert BattleNotFound();
        Battle storage battle = battles[battleId];
        if (!battle.isDistributed) revert BattleNotDistributed();
        if (battle.winner != msg.sender) revert NotBattleWinner();
        if (battle.hasClaimed[msg.sender]) revert AlreadyClaimed();

        uint256 reward = battle.rewardPool;
        uint256 fee = (reward * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        uint256 netReward = reward - fee;

        // Effects: mark claimed and update accounting before transfers
        battle.hasClaimed[msg.sender] = true;
        players[msg.sender].totalClaimed += netReward;

        // Interactions: transfer tokens after state is updated
        if (fee > 0) {
            if (!gameToken.transfer(feeReceiver, fee)) revert TransferFailed();
        }
        if (!gameToken.transfer(msg.sender, netReward)) revert TransferFailed();

        emit RewardsClaimed(msg.sender, battleId, netReward, fee);
    }

    function getHero(uint256 heroId)
        external
        view
        returns (
            address heroOwner,
            uint256 tokenId,
            uint256 power,
            uint256 defense,
            uint256 speed,
            uint256 level,
            uint256[] memory equippedItems,
            uint256 trainingPoints,
            bool isRegistered
        )
    {
        Hero storage hero = heroes[heroId];
        return (
            hero.owner,
            hero.tokenId,
            hero.stats.power,
            hero.stats.defense,
            hero.stats.speed,
            hero.stats.level,
            hero.equippedItems,
            hero.trainingPoints,
            hero.isRegistered
        );
    }

    function getPlayer(address playerAddr)
        external
        view
        returns (
            uint256 depositedTokens,
            uint256 availableTrainingPoints,
            uint256 totalClaimed,
            uint256[] memory heroIds
        )
    {
        Player storage p = players[playerAddr];
        return (p.depositedTokens, p.availableTrainingPoints, p.totalClaimed, p.heroIds);
    }

    function getBattleInfo(uint256 battleId)
        external
        view
        returns (
            uint256 id,
            uint256 startTime,
            uint256 endTime,
            bool isActive,
            bool isCompleted,
            bool isDistributed,
            uint256 winnerHeroId,
            address winner,
            uint256 rewardPool
        )
    {
        Battle storage battle = battles[battleId];
        return (
            battle.battleId,
            battle.startTime,
            battle.endTime,
            battle.isActive,
            battle.isCompleted,
            battle.isDistributed,
            battle.winnerHeroId,
            battle.winner,
            battle.rewardPool
        );
    }

    function getBattleParticipants(uint256 battleId)
        external
        view
        returns (address[] memory participants, uint256[] memory heroIds)
    {
        return (battles[battleId].participants, battles[battleId].heroIds);
    }

    function hasClaimedRewards(uint256 battleId, address player) external view returns (bool) {
        return battles[battleId].hasClaimed[player];
    }

    function pendingRewards(uint256 battleId, address player) external view returns (uint256) {
        Battle storage battle = battles[battleId];
        if (!battle.isDistributed) return 0;
        if (battle.winner != player) return 0;
        if (battle.hasClaimed[player]) return 0;
        uint256 reward = battle.rewardPool;
        uint256 fee = (reward * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        return reward - fee;
    }

    function getEquippedItems(uint256 heroId) external view returns (uint256[] memory) {
        return heroes[heroId].equippedItems;
    }

    function getHeroStats(uint256 heroId)
        external
        view
        returns (uint256 power, uint256 defense, uint256 speed, uint256 level)
    {
        HeroStats storage stats = heroes[heroId].stats;
        return (stats.power, stats.defense, stats.speed, stats.level);
    }
}
