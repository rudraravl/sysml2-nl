// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PredictionMarket
 * @notice Decentralized prediction market where users stake a base ERC20 token on event outcomes.
 *         Winners receive a proportional share of the total pool minus a 2% fee. Canceled markets
 *         allow users to withdraw their original stake.
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract PredictionMarket {
    // --- Enums ---
    enum MarketStatus {
        Open,
        Resolved,
        Canceled
    }

    // --- Structs ---
    struct Market {
        address creator;
        string question;
        string[] outcomes;
        uint256 resolutionTime;
        uint256 winningOutcome;
        MarketStatus status;
        uint256 totalStaked;
        uint256[] stakedPerOutcome;
        bool exists;
    }

    struct UserBet {
        uint256 amount;
        bool redeemed;
    }

    // --- State Variables ---
    IERC20 public immutable baseCurrency;
    address public operator;
    address public owner;

    uint256 public constant MIN_INITIAL_STAKE = 100;
    uint256 public constant FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public marketCount;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => mapping(uint256 => UserBet))) public userBets;
    mapping(uint256 => mapping(address => uint256)) public userTotalStaked;

    uint256 private _locked = 1;

    // --- Events ---
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        string[] outcomes,
        uint256 resolutionTime,
        uint256 initialStake,
        uint256 initialOutcome
    );
    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        uint256 outcome,
        uint256 amount
    );
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome, uint256 totalStaked);
    event MarketCanceled(uint256 indexed marketId, uint256 totalStaked);
    event WinningsRedeemed(
        uint256 indexed marketId,
        address indexed user,
        uint256 payout,
        uint256 fee
    );
    event StakeWithdrawn(uint256 indexed marketId, address indexed user, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- Errors ---
    error OnlyOperator();
    error OnlyOwner();
    error ZeroAddress();
    error MarketDoesNotExist();
    error InvalidOutcomes();
    error InvalidResolutionTime();
    error InsufficientInitialStake();
    error MarketNotOpen();
    error MarketNotResolved();
    error MarketNotCanceled();
    error InvalidOutcome();
    error AlreadyRedeemed();
    error NoStake();
    error ResolutionTooEarly();
    error ResolutionTimePassed();
    error ZeroAmount();
    error EmptyQuestion();
    error ReentrantCall();
    error TransferFailed();

    // --- Modifiers ---
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (!markets[marketId].exists) revert MarketDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // --- Constructor ---
    constructor(address _baseCurrency, address _operator) {
        if (_baseCurrency == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        baseCurrency = IERC20(_baseCurrency);
        operator = _operator;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // --- Admin Functions ---
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // --- Internal Helpers ---
    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool success = baseCurrency.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool success = baseCurrency.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _copyOutcomesToStorage(string[] storage dest, string[] calldata src) internal {
        for (uint256 i = 0; i < src.length; i++) {
            dest.push(src[i]);
        }
    }

    // --- Market Functions ---

    /**
     * @notice Creates a new prediction market with an initial stake on a chosen outcome.
     * @param question The event question.
     * @param outcomes Array of possible outcome strings (minimum 2).
     * @param resolutionTime Unix timestamp after which the market can be resolved.
     * @param initialOutcome The outcome index the creator stakes on initially.
     * @param initialStake The amount of base currency to stake (must be >= MIN_INITIAL_STAKE).
     * @return marketId The ID of the newly created market.
     */
    function createMarket(
        string calldata question,
        string[] calldata outcomes,
        uint256 resolutionTime,
        uint256 initialOutcome,
        uint256 initialStake
    ) external nonReentrant returns (uint256 marketId) {
        if (bytes(question).length == 0) revert EmptyQuestion();
        if (outcomes.length < 2) revert InvalidOutcomes();
        if (resolutionTime <= block.timestamp) revert InvalidResolutionTime();
        if (initialStake < MIN_INITIAL_STAKE) revert InsufficientInitialStake();
        if (initialOutcome >= outcomes.length) revert InvalidOutcome();

        marketId = ++marketCount;

        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.question = question;
        _copyOutcomesToStorage(m.outcomes, outcomes);
        m.resolutionTime = resolutionTime;
        m.status = MarketStatus.Open;
        m.exists = true;

        uint256 outcomeCount = outcomes.length;
        for (uint256 i = 0; i < outcomeCount; i++) {
            m.stakedPerOutcome.push(0);
        }

        m.stakedPerOutcome[initialOutcome] += initialStake;
        m.totalStaked += initialStake;

        userBets[marketId][msg.sender][initialOutcome].amount += initialStake;
        userTotalStaked[marketId][msg.sender] += initialStake;

        _safeTransferFrom(msg.sender, address(this), initialStake);

        emit MarketCreated(marketId, msg.sender, question, outcomes, resolutionTime, initialStake, initialOutcome);
        emit BetPlaced(marketId, msg.sender, initialOutcome, initialStake);
    }

    /**
     * @notice Places a bet on a specific outcome of an open market.
     * @param marketId The ID of the market.
     * @param outcome The index of the chosen outcome.
     * @param amount The amount of base currency to stake.
     */
    function placeBet(
        uint256 marketId,
        uint256 outcome,
        uint256 amount
    ) external nonReentrant marketExists(marketId) {
        if (amount == 0) revert ZeroAmount();

        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();
        if (outcome >= m.outcomes.length) revert InvalidOutcome();

        m.stakedPerOutcome[outcome] += amount;
        m.totalStaked += amount;

        userBets[marketId][msg.sender][outcome].amount += amount;
        userTotalStaked[marketId][msg.sender] += amount;

        _safeTransferFrom(msg.sender, address(this), amount);

        emit BetPlaced(marketId, msg.sender, outcome, amount);
    }

    /**
     * @notice Resolves a market by declaring the winning outcome. Only callable by the operator.
     * @param marketId The ID of the market.
     * @param winningOutcome The index of the winning outcome.
     */
    function resolveMarket(
        uint256 marketId,
        uint256 winningOutcome
    ) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();
        if (block.timestamp < m.resolutionTime) revert ResolutionTooEarly();
        if (winningOutcome >= m.outcomes.length) revert InvalidOutcome();

        m.winningOutcome = winningOutcome;
        m.status = MarketStatus.Resolved;

        emit MarketResolved(marketId, winningOutcome, m.totalStaked);
    }

    /**
     * @notice Cancels a market before its resolution time. Only callable by the operator.
     * @param marketId The ID of the market.
     */
    function cancelMarket(uint256 marketId) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();
        if (block.timestamp >= m.resolutionTime) revert ResolutionTimePassed();

        m.status = MarketStatus.Canceled;

        emit MarketCanceled(marketId, m.totalStaked);
    }

    /**
     * @notice Redeems winnings for a resolved market. A 2% fee is deducted and sent to the operator.
     * @param marketId The ID of the market.
     */
    function redeemWinnings(uint256 marketId) external nonReentrant marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Resolved) revert MarketNotResolved();

        uint256 winningOutcome = m.winningOutcome;
        UserBet storage bet = userBets[marketId][msg.sender][winningOutcome];
        if (bet.redeemed) revert AlreadyRedeemed();
        if (bet.amount == 0) revert NoStake();

        uint256 winningPool = m.stakedPerOutcome[winningOutcome];
        if (winningPool == 0) revert NoStake();

        // Mark as redeemed before transfer (checks-effects-interactions)
        bet.redeemed = true;

        // Compute payout with full precision to avoid divide-before-multiply rounding loss.
        // netPayout = (totalStaked * bet.amount * (BPS_DENOMINATOR - FEE_BPS)) / (winningPool * BPS_DENOMINATOR)
        uint256 numerator = m.totalStaked * bet.amount;
        uint256 netPayout = (numerator * (BPS_DENOMINATOR - FEE_BPS)) / (winningPool * BPS_DENOMINATOR);
        uint256 grossPayout = numerator / winningPool;
        uint256 fee = grossPayout - netPayout;

        if (netPayout > 0) {
            _safeTransfer(msg.sender, netPayout);
        }
        if (fee > 0) {
            _safeTransfer(operator, fee);
        }

        emit WinningsRedeemed(marketId, msg.sender, netPayout, fee);
    }

    /**
     * @notice Withdraws the initial stake from a canceled market.
     * @param marketId The ID of the market.
     */
    function withdrawStake(uint256 marketId) external nonReentrant marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Canceled) revert MarketNotCanceled();

        uint256 userStaked = userTotalStaked[marketId][msg.sender];
        if (userStaked == 0) revert NoStake();

        // Zero out before transfer (checks-effects-interactions)
        userTotalStaked[marketId][msg.sender] = 0;

        _safeTransfer(msg.sender, userStaked);

        emit StakeWithdrawn(marketId, msg.sender, userStaked);
    }

    // --- View Functions ---

    /**
     * @notice Returns the core details of a market.
     */
    function getMarket(
        uint256 marketId
    )
        external
        view
        marketExists(marketId)
        returns (
            address creator,
            string memory question,
            string[] memory outcomes,
            uint256 resolutionTime,
            uint256 winningOutcome,
            MarketStatus status,
            uint256 totalStaked,
            uint256[] memory stakedPerOutcome
        )
    {
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.question,
            m.outcomes,
            m.resolutionTime,
            m.winningOutcome,
            m.status,
            m.totalStaked,
            m.stakedPerOutcome
        );
    }

    /**
     * @notice Returns a user's bet amount and redemption status for a specific outcome.
     */
    function getUserBet(
        uint256 marketId,
        address user,
        uint256 outcome
    ) external view marketExists(marketId) returns (uint256 amount, bool redeemed) {
        UserBet storage b = userBets[marketId][user][outcome];
        return (b.amount, b.redeemed);
    }

    /**
     * @notice Returns the total amount a user has staked across all outcomes in a market.
     */
    function getUserTotalStaked(
        uint256 marketId,
        address user
    ) external view marketExists(marketId) returns (uint256) {
        return userTotalStaked[marketId][user];
    }

    /**
     * @notice Returns the total staked amount for a specific outcome in a market.
     */
    function getOutcomeStake(
        uint256 marketId,
        uint256 outcome
    ) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        if (outcome >= m.outcomes.length) revert InvalidOutcome();
        return m.stakedPerOutcome[outcome];
    }

    /**
     * @notice Returns the number of outcomes for a given market.
     */
    function getOutcomeCount(uint256 marketId) external view marketExists(marketId) returns (uint256) {
        return markets[marketId].outcomes.length;
    }
}
