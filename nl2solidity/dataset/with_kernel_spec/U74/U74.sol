// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DecentralizedGamingPlatform {
    // --- Constants ---
    uint256 public constant MIN_BET = 100;
    uint256 public constant MAX_HOUSE_EDGE = 500; // 5% in basis points (10000 = 100%)
    uint256 private constant BPS_DENOMINATOR = 10000;

    // --- Access Control ---
    address public operator;

    // --- State Variables ---
    mapping(address => uint256) public playerBalances;
    uint256 public treasuryBalance; // Sum of all player balances

    uint256 public houseEdge; // In basis points (e.g., 500 = 5%)

    struct GameType {
        uint256 minBet;
        uint256 maxBet;
        bool active;
    }

    mapping(uint256 => GameType) public games;
    uint256[] public gameTypeIds;
    uint256 public gameTypeCount;

    // --- Events ---
    event Deposit(address indexed player, uint256 amount);
    event Withdrawal(address indexed player, uint256 amount);
    event GamePlayed(address indexed player, uint256 indexed gameType, uint256 bet, bool won, uint256 payout);
    event GameTypeAdded(uint256 indexed gameType, uint256 minBet, uint256 maxBet);
    event GameTypeUpdated(uint256 indexed gameType, uint256 minBet, uint256 maxBet, bool active);
    event HouseEdgeUpdated(uint256 oldEdge, uint256 newEdge);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // --- Custom Errors ---
    error Unauthorized();
    error ZeroAmount();
    error InsufficientBalance(uint256 available, uint256 required);
    error GameTypeNotActive(uint256 gameType);
    error BetOutOfRange(uint256 bet, uint256 min, uint256 max);
    error HouseEdgeExceedsMaximum(uint256 edge, uint256 max);
    error InvalidBetBounds(uint256 minBet, uint256 maxBet);
    error GameTypeAlreadyExists(uint256 gameType);
    error GameTypeDoesNotExist(uint256 gameType);
    error InsufficientTreasury(uint256 available, uint256 required);
    error InvalidAddress();
    error TransferFailed();

    // --- Modifiers ---
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyGuarded();
        _locked = true;
        _;
        _locked = false;
    }

    error ReentrancyGuarded();

    bool private _locked;

    // --- Constructor ---
    constructor(uint256 _houseEdge) {
        if (_houseEdge > MAX_HOUSE_EDGE) revert HouseEdgeExceedsMaximum(_houseEdge, MAX_HOUSE_EDGE);
        operator = msg.sender;
        houseEdge = _houseEdge;
    }

    // --- Player Functions ---

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        playerBalances[msg.sender] += msg.value;
        treasuryBalance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = playerBalances[msg.sender];
        if (balance < amount) revert InsufficientBalance(balance, amount);

        playerBalances[msg.sender] = balance - amount;
        treasuryBalance -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, amount);
    }

    function play(uint256 gameType, uint256 betAmount) external nonReentrant {
        GameType memory game = games[gameType];
        if (!game.active) revert GameTypeNotActive(gameType);

        uint256 balance = playerBalances[msg.sender];
        if (betAmount > balance) revert InsufficientBalance(balance, betAmount);
        if (betAmount < MIN_BET) revert BetOutOfRange(betAmount, MIN_BET, game.maxBet);
        if (betAmount < game.minBet) revert BetOutOfRange(betAmount, game.minBet, game.maxBet);
        if (betAmount > game.maxBet) revert BetOutOfRange(betAmount, game.minBet, game.maxBet);

        playerBalances[msg.sender] = balance - betAmount;
        treasuryBalance -= betAmount;

        uint256 randomValue = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    gameType,
                    betAmount,
                    gasleft()
                )
            )
        );

        uint256 winChance = (BPS_DENOMINATOR - houseEdge) / 2;
        bool won = (randomValue % BPS_DENOMINATOR) < winChance;

        uint256 payout = 0;
        if (won) {
            payout = betAmount * 2;
            uint256 requiredBalance = treasuryBalance + payout;
            if (address(this).balance < requiredBalance) {
                revert InsufficientTreasury(address(this).balance, requiredBalance);
            }
            playerBalances[msg.sender] += payout;
            treasuryBalance += payout;
        }

        emit GamePlayed(msg.sender, gameType, betAmount, won, payout);
    }

    // --- Operator Functions ---

    function addGameType(uint256 gameType, uint256 minBet, uint256 maxBet) external onlyOperator {
        if (games[gameType].minBet != 0 || games[gameType].active) {
            revert GameTypeAlreadyExists(gameType);
        }
        if (minBet < MIN_BET) revert BetOutOfRange(minBet, MIN_BET, maxBet);
        if (maxBet < minBet) revert InvalidBetBounds(minBet, maxBet);

        games[gameType] = GameType({minBet: minBet, maxBet: maxBet, active: true});
        gameTypeIds.push(gameType);
        gameTypeCount++;

        emit GameTypeAdded(gameType, minBet, maxBet);
    }

    function updateGameType(uint256 gameType, uint256 minBet, uint256 maxBet, bool active) external onlyOperator {
        GameType storage game = games[gameType];
        if (game.minBet == 0 && !game.active) revert GameTypeDoesNotExist(gameType);
        if (minBet < MIN_BET) revert BetOutOfRange(minBet, MIN_BET, maxBet);
        if (maxBet < minBet) revert InvalidBetBounds(minBet, maxBet);

        game.minBet = minBet;
        game.maxBet = maxBet;
        game.active = active;

        emit GameTypeUpdated(gameType, minBet, maxBet, active);
    }

    function setHouseEdge(uint256 newEdge) external onlyOperator {
        if (newEdge > MAX_HOUSE_EDGE) revert HouseEdgeExceedsMaximum(newEdge, MAX_HOUSE_EDGE);
        uint256 oldEdge = houseEdge;
        houseEdge = newEdge;
        emit HouseEdgeUpdated(oldEdge, newEdge);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // --- View Functions ---

    function getBalance(address player) external view returns (uint256) {
        return playerBalances[player];
    }

    function getGameType(uint256 gameType) external view returns (uint256 minBet, uint256 maxBet, bool active) {
        GameType memory game = games[gameType];
        return (game.minBet, game.maxBet, game.active);
    }

    function getAllGameTypeIds() external view returns (uint256[] memory) {
        return gameTypeIds;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getHouseProfit() external view returns (uint256) {
        if (address(this).balance < treasuryBalance) return 0;
        return address(this).balance - treasuryBalance;
    }

    // --- Receive ---

    receive() external payable {
        if (msg.value == 0) revert ZeroAmount();
        playerBalances[msg.sender] += msg.value;
        treasuryBalance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}
