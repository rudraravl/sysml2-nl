// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CompetitiveGamingArena {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ErrZeroAddress();
    error ErrNotOperator();
    error ErrMatchNotFound();
    error ErrMatchNotOpen();
    error ErrMatchFull();
    error ErrAlreadyJoined();
    error ErrNotParticipant();
    error ErrInvalidEntryFee();
    error ErrInvalidConfig();
    error ErrNotInProgress();
    error ErrAlreadySubmitted();
    error ErrInvalidWinner();
    error ErrNotWinner();
    error ErrAlreadyClaimed();
    error ErrTransferFailed();
    error ErrInvalidFeeBps();
    error ErrReentrancy();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event MatchCreated(uint256 indexed matchId, address indexed creator, uint256 entryFee, uint256 maxPlayers);
    event PlayerJoined(uint256 indexed matchId, address indexed player, uint256 playerCount, uint256 prizePool);
    event ResultSubmitted(uint256 indexed matchId, address indexed submitter, address indexed proposedWinner, uint256 voteCount);
    event DisputeResolved(uint256 indexed matchId, address indexed winner, address indexed resolver);
    event PrizeClaimed(uint256 indexed matchId, address indexed winner, uint256 amount, uint256 fee);
    event ConfigUpdated(uint256 minEntryFee, uint256 maxEntryFee, uint256 matchDuration);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event FeeBpsUpdated(uint256 newFeeBps);
    event OperatorUpdated(address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_PLAYERS = 8;
    uint256 public constant BPS = 10000;

    /*//////////////////////////////////////////////////////////////
                              ENUMS
    //////////////////////////////////////////////////////////////*/
    enum MatchState { Open, InProgress, PendingResult, Completed, Cancelled }

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct GameConfig {
        uint256 minEntryFee;
        uint256 maxEntryFee;
        uint256 matchDuration;
    }

    struct Match {
        uint256 entryFee;
        uint256 prizePool;
        uint256 playerCount;
        uint256 createdAt;
        MatchState state;
        address winner;
        bool claimed;
        address[] players;
        mapping(address => bool) hasJoined;
        mapping(address => bool) hasSubmitted;
        mapping(address => uint256) votes;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE STORAGE
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable stablecoin;
    address public operator;
    address public feeRecipient;
    GameConfig public config;
    uint256 public feeBps = 500; // 5%
    uint256 public nextMatchId = 1;
    mapping(uint256 => Match) private matches;

    uint256 private _locked = 1;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier matchExists(uint256 matchId) {
        if (matchId == 0 || matchId >= nextMatchId) revert ErrMatchNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ErrReentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _stablecoin,
        address _operator,
        address _feeRecipient,
        GameConfig memory _config
    ) {
        if (_stablecoin == address(0) || _operator == address(0) || _feeRecipient == address(0)) {
            revert ErrZeroAddress();
        }
        if (_config.minEntryFee == 0 || _config.maxEntryFee < _config.minEntryFee || _config.matchDuration == 0) {
            revert ErrInvalidConfig();
        }
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        feeRecipient = _feeRecipient;
        config = _config;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setConfig(GameConfig calldata _config) external onlyOperator {
        if (_config.minEntryFee == 0 || _config.maxEntryFee < _config.minEntryFee || _config.matchDuration == 0) {
            revert ErrInvalidConfig();
        }
        config = _config;
        emit ConfigUpdated(_config.minEntryFee, _config.maxEntryFee, _config.matchDuration);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert ErrZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function setFeeBps(uint256 _feeBps) external onlyOperator {
        if (_feeBps > 1000) revert ErrInvalidFeeBps(); // cap at 10%
        feeBps = _feeBps;
        emit FeeBpsUpdated(_feeBps);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ErrZeroAddress();
        operator = _newOperator;
        emit OperatorUpdated(_newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                          MATCH FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createMatch(uint256 entryFee) external onlyOperator returns (uint256 matchId) {
        GameConfig memory cfg = config;
        if (entryFee < cfg.minEntryFee || entryFee > cfg.maxEntryFee) revert ErrInvalidEntryFee();

        matchId = nextMatchId++;
        Match storage m = matches[matchId];
        m.entryFee = entryFee;
        m.createdAt = block.timestamp;
        m.state = MatchState.Open;

        emit MatchCreated(matchId, msg.sender, entryFee, MAX_PLAYERS);
    }

    function joinMatch(uint256 matchId) external nonReentrant matchExists(matchId) {
        Match storage m = matches[matchId];
        if (m.state != MatchState.Open) revert ErrMatchNotOpen();
        if (m.playerCount >= MAX_PLAYERS) revert ErrMatchFull();
        if (m.hasJoined[msg.sender]) revert ErrAlreadyJoined();

        uint256 fee = m.entryFee;

        // Effects before interactions
        m.hasJoined[msg.sender] = true;
        m.players.push(msg.sender);
        m.playerCount += 1;
        m.prizePool += fee;

        if (m.playerCount == MAX_PLAYERS) {
            m.state = MatchState.InProgress;
        }

        // Interaction
        if (!stablecoin.transferFrom(msg.sender, address(this), fee)) revert ErrTransferFailed();

        emit PlayerJoined(matchId, msg.sender, m.playerCount, m.prizePool);
    }

    function submitResult(uint256 matchId, address proposedWinner) external nonReentrant matchExists(matchId) {
        Match storage m = matches[matchId];
        if (m.state != MatchState.InProgress && m.state != MatchState.PendingResult) revert ErrNotInProgress();
        if (!m.hasJoined[msg.sender]) revert ErrNotParticipant();
        if (m.hasSubmitted[msg.sender]) revert ErrAlreadySubmitted();
        if (!m.hasJoined[proposedWinner]) revert ErrInvalidWinner();

        m.hasSubmitted[msg.sender] = true;
        m.votes[proposedWinner] += 1;

        if (m.votes[proposedWinner] == m.playerCount) {
            m.winner = proposedWinner;
            m.state = MatchState.Completed;
        } else {
            m.state = MatchState.PendingResult;
        }

        emit ResultSubmitted(matchId, msg.sender, proposedWinner, m.votes[proposedWinner]);
    }

    function resolveDispute(uint256 matchId, address winner) external onlyOperator matchExists(matchId) {
        Match storage m = matches[matchId];
        if (m.state != MatchState.InProgress && m.state != MatchState.PendingResult) revert ErrNotInProgress();
        if (!m.hasJoined[winner]) revert ErrInvalidWinner();

        m.winner = winner;
        m.state = MatchState.Completed;

        emit DisputeResolved(matchId, winner, msg.sender);
    }

    function claimWinnings(uint256 matchId) external nonReentrant matchExists(matchId) {
        Match storage m = matches[matchId];
        if (m.state != MatchState.Completed) revert ErrNotInProgress();
        if (msg.sender != m.winner) revert ErrNotWinner();
        if (m.claimed) revert ErrAlreadyClaimed();

        uint256 prizePool = m.prizePool;
        uint256 fee = (prizePool * feeBps) / BPS;
        uint256 payout = prizePool - fee;

        // Effects before interactions
        m.claimed = true;

        // Interactions
        if (!stablecoin.transfer(m.winner, payout)) revert ErrTransferFailed();
        if (fee > 0) {
            if (!stablecoin.transfer(feeRecipient, fee)) revert ErrTransferFailed();
        }

        emit PrizeClaimed(matchId, m.winner, payout, fee);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getMatch(uint256 matchId)
        external
        view
        matchExists(matchId)
        returns (
            uint256 entryFee,
            uint256 prizePool,
            uint256 playerCount,
            MatchState state,
            address winner,
            bool claimed
        )
    {
        Match storage m = matches[matchId];
        return (m.entryFee, m.prizePool, m.playerCount, m.state, m.winner, m.claimed);
    }

    function getPlayers(uint256 matchId) external view matchExists(matchId) returns (address[] memory) {
        return matches[matchId].players;
    }

    function hasJoined(uint256 matchId, address player) external view matchExists(matchId) returns (bool) {
        return matches[matchId].hasJoined[player];
    }

    function hasSubmittedResult(uint256 matchId, address player) external view matchExists(matchId) returns (bool) {
        return matches[matchId].hasSubmitted[player];
    }

    function votesFor(uint256 matchId, address candidate) external view matchExists(matchId) returns (uint256) {
        return matches[matchId].votes[candidate];
    }
}
