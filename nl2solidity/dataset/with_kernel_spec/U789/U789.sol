// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EtherGame {
    /*//////////////////////////////////////////////////////////////
                              ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    address public operator;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              GAME STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant ABSOLUTE_MAX_GAMES = 10;

    uint256 public maxActiveGames = ABSOLUTE_MAX_GAMES;
    uint256 public activeGames;
    uint256 public globalHighScore;

    struct Game {
        bool active;
        uint256 playerCount;
        mapping(address => uint256) balances;
    }

    mapping(uint256 => Game) private games;
    mapping(address => uint256) public totalCollected;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event GameStarted(uint256 indexed gameId);
    event GameEnded(uint256 indexed gameId);
    event PlayerEntered(uint256 indexed gameId, address indexed player, uint256 amount);
    event EtherCollected(uint256 indexed gameId, address indexed player, uint256 amount);
    event PlayerEscaped(uint256 indexed gameId, address indexed player, uint256 amount);
    event PlayerEliminated(uint256 indexed gameId, address indexed player, uint256 amountLost);
    event HighScoreUpdated(address indexed player, uint256 newHighScore);
    event MaxActiveGamesUpdated(uint256 newMax);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error ZeroAddress();
    error GameNotActive(uint256 gameId);
    error GameAlreadyActive(uint256 gameId);
    error MaxActiveGamesReached(uint256 max);
    error GameNotEmpty(uint256 gameId);
    error PlayerAlreadyInGame(uint256 gameId, address player);
    error PlayerNotInGame(uint256 gameId, address player);
    error InsufficientDeposit(uint256 required, uint256 sent);
    error ZeroDeposit();
    error InvalidMaxGames(uint256 max);
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setMaxActiveGames(uint256 _max) external onlyOperator {
        if (_max == 0 || _max > ABSOLUTE_MAX_GAMES) revert InvalidMaxGames(_max);
        maxActiveGames = _max;
        emit MaxActiveGamesUpdated(_max);
    }

    function startGame(uint256 gameId) external onlyOperator {
        if (games[gameId].active) revert GameAlreadyActive(gameId);
        if (activeGames >= maxActiveGames) revert MaxActiveGamesReached(maxActiveGames);

        games[gameId].active = true;
        activeGames++;
        emit GameStarted(gameId);
    }

    function endGame(uint256 gameId) external onlyOperator {
        Game storage game = games[gameId];
        if (!game.active) revert GameNotActive(gameId);
        if (game.playerCount != 0) revert GameNotEmpty(gameId);

        game.active = false;
        activeGames--;
        emit GameEnded(gameId);
    }

    function eliminatePlayer(uint256 gameId, address player) external onlyOperator {
        Game storage game = games[gameId];
        if (!game.active) revert GameNotActive(gameId);
        uint256 balance = game.balances[player];
        if (balance == 0) revert PlayerNotInGame(gameId, player);

        game.balances[player] = 0;
        game.playerCount--;

        emit PlayerEliminated(gameId, player, balance);
    }

    /*//////////////////////////////////////////////////////////////
                            PLAYER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function enterGame(uint256 gameId) external payable {
        Game storage game = games[gameId];
        if (!game.active) revert GameNotActive(gameId);
        if (game.balances[msg.sender] != 0) revert PlayerAlreadyInGame(gameId, msg.sender);
        if (msg.value < MIN_DEPOSIT) revert InsufficientDeposit(MIN_DEPOSIT, msg.value);

        game.balances[msg.sender] = msg.value;
        game.playerCount++;

        emit PlayerEntered(gameId, msg.sender, msg.value);
    }

    function collectEther(uint256 gameId) external payable {
        Game storage game = games[gameId];
        if (!game.active) revert GameNotActive(gameId);
        if (game.balances[msg.sender] == 0) revert PlayerNotInGame(gameId, msg.sender);
        if (msg.value == 0) revert ZeroDeposit();

        game.balances[msg.sender] += msg.value;

        emit EtherCollected(gameId, msg.sender, msg.value);
    }

    function escapeGame(uint256 gameId) external {
        Game storage game = games[gameId];
        if (!game.active) revert GameNotActive(gameId);
        uint256 balance = game.balances[msg.sender];
        if (balance == 0) revert PlayerNotInGame(gameId, msg.sender);

        // Effects
        game.balances[msg.sender] = 0;
        game.playerCount--;

        totalCollected[msg.sender] += balance;

        if (balance > globalHighScore) {
            globalHighScore = balance;
            emit HighScoreUpdated(msg.sender, balance);
        }

        emit PlayerEscaped(gameId, msg.sender, balance);

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPlayerBalance(uint256 gameId, address player) external view returns (uint256) {
        return games[gameId].balances[player];
    }

    function getGamePlayerCount(uint256 gameId) external view returns (uint256) {
        return games[gameId].playerCount;
    }

    function isGameActive(uint256 gameId) external view returns (bool) {
        return games[gameId].active;
    }
}
