// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title DuelStaking
 * @notice Decentralized head-to-head staking game. Players stake tokens
 *         against each other in escrow, declare outcomes, and claim winnings.
 */
contract DuelStaking {
    /* ------------------------------------------------------------------ */
    /* Constants & Immutables                                              */
    /* ------------------------------------------------------------------ */

    IERC20 public immutable gameToken;

    /// @dev Maximum stake per player per match (1000 tokens, assuming 18 decimals).
    uint256 public constant MAX_STAKE = 1000 * 10 ** 18;

    /// @dev Maximum fee the operator may set, in basis points (10%).
    uint256 public constant MAX_FEE_BPS = 1000;

    /* ------------------------------------------------------------------ */
    /* Types                                                               */
    /* ------------------------------------------------------------------ */

    enum MatchStatus {
        None,      // 0 - uninitialized
        Open,      // 1 - created, awaiting opponent
        Active,    // 2 - both players staked, awaiting resolution
        Resolved,  // 3 - outcome determined, winnings claimable
        Cancelled  // 4 - voided, stakes refunded
    }

    struct Match {
        address player1;
        address player2;
        uint256 stake1;
        uint256 stake2;
        uint8   outcome1;   // declaration by player 1 (0 = undeclared)
        uint8   outcome2;   // declaration by player 2 (0 = undeclared)
        MatchStatus status;
        address winner;     // set on resolution (address(0) for draw)
        uint256 fee;        // per-player fee captured at creation time
    }

    /* ------------------------------------------------------------------ */
    /* State                                                               */
    /* ------------------------------------------------------------------ */

    address public operator;
    uint256 public matchFeeBps = 500; // 5% default
    bool    public paused;

    mapping(uint256 => Match) private matches;
    uint256 public nextMatchId;

    /// @dev Claimable winnings credited to each player.
    mapping(address => uint256) public balances;

    /// @dev Accumulated operator fees awaiting withdrawal.
    uint256 public accumulatedFees;

    /* ------------------------------------------------------------------ */
    /* Events                                                              */
    /* ------------------------------------------------------------------ */

    event MatchCreated(uint256 indexed matchId, address indexed player1, uint256 stake, uint256 fee);
    event MatchAccepted(uint256 indexed matchId, address indexed player2, uint256 stake);
    event OutcomeDeclared(uint256 indexed matchId, address indexed player, uint256 outcome);
    event MatchResolved(uint256 indexed matchId, address winner, uint256 totalPayout);
    event WinningsClaimed(address indexed player, uint256 amount);
    event MatchCancelled(uint256 indexed matchId);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PausedToggled(bool paused);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    /* ------------------------------------------------------------------ */
    /* Custom Errors                                                      */
    /* ------------------------------------------------------------------ */

    error NotOperator();
    error GamePaused();
    error InvalidStake();
    error StakeExceedsMax();
    error MatchNotOpen();
    error MatchNotActive();
    error CannotAcceptOwnMatch();
    error NotParticipant();
    error AlreadyDeclared();
    error InvalidOutcome();
    error NoWinnings();
    error TransferFailed();
    error ZeroAddress();
    error FeeTooHigh();

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                           */
    /* ------------------------------------------------------------------ */

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert GamePaused();
        _;
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                         */
    /* ------------------------------------------------------------------ */

    constructor(address _gameToken, address _operator) {
        if (_gameToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        gameToken = IERC20(_gameToken);
        operator = _operator;
    }

    /* ------------------------------------------------------------------ */
    /* Player Functions                                                    */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Create a new open match by staking tokens.
     * @param stake Amount of game tokens to stake (must be > 0 and <= MAX_STAKE).
     * @return matchId The id of the newly created match.
     */
    function createMatch(uint256 stake) external whenNotPaused returns (uint256 matchId) {
        if (stake == 0) revert InvalidStake();
        if (stake > MAX_STAKE) revert StakeExceedsMax();

        matchId = nextMatchId++;
        Match storage m = matches[matchId];
        m.player1 = msg.sender;
        m.stake1 = stake;
        m.status = MatchStatus.Open;
        m.fee = (stake * matchFeeBps) / 10_000;

        bool ok = gameToken.transferFrom(msg.sender, address(this), stake);
        if (!ok) revert TransferFailed();

        emit MatchCreated(matchId, msg.sender, stake, m.fee);
    }

    /**
     * @notice Accept an open match by matching the creator's stake.
     * @param matchId The id of the open match to accept.
     */
    function acceptMatch(uint256 matchId) external whenNotPaused {
        Match storage m = matches[matchId];
        if (m.status != MatchStatus.Open) revert MatchNotOpen();
        if (msg.sender == m.player1) revert CannotAcceptOwnMatch();

        uint256 stake = m.stake1;
        if (stake > MAX_STAKE) revert StakeExceedsMax();

        m.player2 = msg.sender;
        m.stake2 = stake;
        m.status = MatchStatus.Active;

        bool ok = gameToken.transferFrom(msg.sender, address(this), stake);
        if (!ok) revert TransferFailed();

        emit MatchAccepted(matchId, msg.sender, stake);
    }

    /**
     * @notice Declare the outcome of an active match. When both players agree,
     *         the match auto-resolves. If they disagree, the operator must
     *         adjudicate via `resolveMatch`.
     * @param matchId The match id.
     * @param outcome 1 = Player 1 wins, 2 = Player 2 wins, 3 = Draw.
     */
    function declareOutcome(uint256 matchId, uint256 outcome) external {
        Match storage m = matches[matchId];
        if (m.status != MatchStatus.Active) revert MatchNotActive();
        if (outcome < 1 || outcome > 3) revert InvalidOutcome();

        uint8 oc = uint8(outcome);

        if (msg.sender == m.player1) {
            if (m.outcome1 != 0) revert AlreadyDeclared();
            m.outcome1 = oc;
        } else if (msg.sender == m.player2) {
            if (m.outcome2 != 0) revert AlreadyDeclared();
            m.outcome2 = oc;
        } else {
            revert NotParticipant();
        }

        emit OutcomeDeclared(matchId, msg.sender, oc);

        // Auto-resolve when both players agree.
        if (m.outcome1 != 0 && m.outcome2 != 0 && m.outcome1 == m.outcome2) {
            _resolveMatch(matchId, m.outcome1);
        }
    }

    /**
     * @notice Claim all accumulated winnings credited to the caller.
     */
    function claimWinnings() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NoWinnings();

        // Effects
        balances[msg.sender] = 0;

        // Interactions
        bool ok = gameToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit WinningsClaimed(msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /* Operator Functions                                                  */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Set the match fee in basis points (max 10% = 1000 bps).
     * @param _feeBps New fee in basis points.
     */
    function setMatchFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = matchFeeBps;
        matchFeeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    /**
     * @notice Pause or unpause new match creation and acceptance.
     * @param _paused True to pause, false to resume.
     */
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedToggled(_paused);
    }

    /**
     * @notice Operator-adjudicated resolution for disputed matches where
     *         the two players declared different outcomes.
     * @param matchId The match id.
     * @param outcome 1 = Player 1 wins, 2 = Player 2 wins, 3 = Draw.
     */
    function resolveMatch(uint256 matchId, uint256 outcome) external onlyOperator {
        Match storage m = matches[matchId];
        if (m.status != MatchStatus.Active) revert MatchNotActive();
        if (outcome < 1 || outcome > 3) revert InvalidOutcome();
        _resolveMatch(matchId, uint8(outcome));
    }

    /**
     * @notice Cancel a match and refund staked tokens to participants.
     *         Works for both Open and Active matches.
     * @param matchId The match id.
     */
    function cancelMatch(uint256 matchId) external onlyOperator {
        Match storage m = matches[matchId];
        if (m.status != MatchStatus.Open && m.status != MatchStatus.Active) {
            revert MatchNotActive();
        }

        address p1 = m.player1;
        address p2 = m.player2;
        uint256 s1 = m.stake1;
        uint256 s2 = m.stake2;

        m.status = MatchStatus.Cancelled;
        m.stake1 = 0;
        m.stake2 = 0;

        if (s1 > 0) balances[p1] += s1;
        if (s2 > 0) balances[p2] += s2;

        emit MatchCancelled(matchId);
    }

    /**
     * @notice Withdraw accumulated fees to a designated recipient.
     * @param to Recipient address.
     */
    function withdrawFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoWinnings();

        accumulatedFees = 0;

        bool ok = gameToken.transfer(to, amount);
        if (!ok) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    /**
     * @notice Transfer operator role to a new address.
     * @param newOperator The new operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorTransferred(old, newOperator);
    }

    /* ------------------------------------------------------------------ */
    /* View Functions                                                      */
    /* ------------------------------------------------------------------ */

    function getMatch(uint256 matchId) external view returns (Match memory) {
        return matches[matchId];
    }

    function playerBalance(address player) external view returns (uint256) {
        return balances[player];
    }

    /* ------------------------------------------------------------------ */
    /* Internal                                                            */
    /* ------------------------------------------------------------------ */

    /**
     * @dev Resolves a match, credits winnings, and captures fees.
     *      Total pool = stake1 + stake2. Total fee = fee * 2.
     *      Payout = total pool - total fee.
     */
    function _resolveMatch(uint256 matchId, uint8 outcome) internal {
        Match storage m = matches[matchId];
        m.status = MatchStatus.Resolved;

        uint256 totalStake = m.stake1 + m.stake2;
        uint256 totalFee = m.fee * 2;
        uint256 payout = totalStake - totalFee;

        if (outcome == 1) {
            m.winner = m.player1;
            balances[m.player1] += payout;
        } else if (outcome == 2) {
            m.winner = m.player2;
            balances[m.player2] += payout;
        } else {
            // Draw: split payout evenly, remainder goes to player1.
            m.winner = address(0);
            uint256 half = payout / 2;
            balances[m.player1] += half;
            balances[m.player2] += payout - half;
        }

        accumulatedFees += totalFee;

        emit MatchResolved(matchId, m.winner, payout);
    }
}
