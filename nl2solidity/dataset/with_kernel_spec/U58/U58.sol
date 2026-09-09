// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title TrendPredictionMarket
 * @notice A prediction market where users bet on binary outcomes of social media trends.
 *         Users deposit ERC20 tokens as collateral, place bets on open markets, and
 *         claim proportional winnings after the admin resolves a market. A 2% fee
 *         (configurable by the admin) is applied to all winning payouts and sent to
 *         a designated fee collector.
 */
contract TrendPredictionMarket {
    //--------------------------------------------------------------------
    // State
    //--------------------------------------------------------------------
    IERC20 public immutable token;

    address public admin;
    address public feeCollector;
    uint256 public feePercentage; // in basis points (200 = 2%)
    bool public paused;

    uint256 public constant MIN_STAKE = 100 * 10 ** 18; // 100 tokens (assuming 18 decimals)
    uint256 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 public constant BASIS_POINTS = 10000;

    uint256 public marketCount;

    enum MarketStatus {
        Open,
        Resolved,
        Cancelled
    }

    struct Market {
        uint256 id;
        string description;
        address creator;
        uint256 totalStakeYes;
        uint256 totalStakeNo;
        uint256 endTime;
        MarketStatus status;
        bool outcome; // true = Yes won, false = No won
        uint256 resolvedAt;
    }

    struct Bet {
        uint256 amount;
        bool prediction; // true = Yes, false = No
        bool claimed;
    }

    mapping(address => uint256) public balances;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Bet)) public userBets;
    mapping(address => uint256[]) public userMarketIds;

    //--------------------------------------------------------------------
    // Events
    //--------------------------------------------------------------------
    event MarketCreated(
        uint256 indexed marketId,
        string description,
        address indexed creator,
        uint256 endTime
    );
    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        bool prediction,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        bool outcome,
        uint256 totalStakeYes,
        uint256 totalStakeNo
    );
    event MarketCancelled(uint256 indexed marketId);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 payout,
        uint256 fee
    );
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    event PausedStateChanged(bool paused);
    event AdminUpdated(address oldAdmin, address newAdmin);

    //--------------------------------------------------------------------
    // Errors
    //--------------------------------------------------------------------
    error NotAdmin();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFee();
    error ContractPaused();
    error InsufficientBalance();
    error StakeTooLow();
    error InvalidEndTime();
    error MarketDoesNotExist();
    error MarketNotOpen();
    error MarketExpired();
    error MarketStillActive();
    error MarketNotResolved();
    error AlreadyClaimed();
    error NotWinner();
    error NothingToClaim();

    //--------------------------------------------------------------------
    // Modifiers
    //--------------------------------------------------------------------
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier notPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (marketId == 0 || marketId > marketCount) revert MarketDoesNotExist();
        _;
    }

    //--------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------
    constructor(address _token, address _admin, address _feeCollector) {
        if (_token == address(0) || _admin == address(0) || _feeCollector == address(0))
            revert ZeroAddress();
        token = IERC20(_token);
        admin = _admin;
        feeCollector = _feeCollector;
        feePercentage = 200; // 2%
    }

    //--------------------------------------------------------------------
    // User: deposit / withdraw
    //--------------------------------------------------------------------
    function deposit(uint256 amount) external notPaused {
        if (amount == 0) revert ZeroAmount();
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "TransferFrom failed");
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        bool ok = token.transfer(msg.sender, amount);
        require(ok, "Transfer failed");
        emit Withdrawal(msg.sender, amount);
    }

    //--------------------------------------------------------------------
    // User: create market / place bet
    //--------------------------------------------------------------------
    function createMarket(
        string calldata description,
        uint256 endTime
    ) external notPaused returns (uint256) {
        if (endTime <= block.timestamp) revert InvalidEndTime();

        marketCount += 1;
        Market storage m = markets[marketCount];
        m.id = marketCount;
        m.description = description;
        m.creator = msg.sender;
        m.endTime = endTime;
        m.status = MarketStatus.Open;

        emit MarketCreated(marketCount, description, msg.sender, endTime);
        return marketCount;
    }

    function placeBet(
        uint256 marketId,
        bool prediction,
        uint256 amount
    ) external notPaused marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();
        if (block.timestamp >= m.endTime) revert MarketExpired();
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_STAKE) revert StakeTooLow();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;

        Bet storage b = userBets[marketId][msg.sender];
        if (b.amount == 0) {
            userMarketIds[msg.sender].push(marketId);
        }
        b.amount += amount;
        b.prediction = prediction;

        if (prediction) {
            m.totalStakeYes += amount;
        } else {
            m.totalStakeNo += amount;
        }

        emit BetPlaced(marketId, msg.sender, prediction, amount);
    }

    //--------------------------------------------------------------------
    // User: claim winnings
    //--------------------------------------------------------------------
    function claimWinnings(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Resolved) revert MarketNotResolved();

        Bet storage b = userBets[marketId][msg.sender];
        if (b.claimed) revert AlreadyClaimed();
        if (b.amount == 0) revert NothingToClaim();
        if (b.prediction != m.outcome) revert NotWinner();

        uint256 winningPool = m.outcome ? m.totalStakeYes : m.totalStakeNo;
        if (winningPool == 0) revert NotWinner();

        uint256 totalPool = m.totalStakeYes + m.totalStakeNo;

        // Compute payout and fee using full-precision numerator to avoid
        // divide-before-multiply rounding loss.
        uint256 numerator = b.amount * totalPool;
        uint256 grossPayout = numerator / winningPool;
        uint256 fee = (numerator * feePercentage) / (winningPool * BASIS_POINTS);
        uint256 netPayout = grossPayout - fee;

        b.claimed = true;
        balances[msg.sender] += netPayout;

        if (fee > 0) {
            bool ok = token.transfer(feeCollector, fee);
            require(ok, "Fee transfer failed");
        }

        emit WinningsClaimed(marketId, msg.sender, netPayout, fee);
    }

    //--------------------------------------------------------------------
    // Admin: resolve / cancel / config
    //--------------------------------------------------------------------
    function resolveMarket(uint256 marketId, bool outcome) external onlyAdmin marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();
        if (block.timestamp < m.endTime) revert MarketStillActive();

        m.status = MarketStatus.Resolved;
        m.outcome = outcome;
        m.resolvedAt = block.timestamp;

        emit MarketResolved(marketId, outcome, m.totalStakeYes, m.totalStakeNo);
    }

    function cancelMarket(uint256 marketId) external onlyAdmin marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Open) revert MarketNotOpen();

        m.status = MarketStatus.Cancelled;

        emit MarketCancelled(marketId);
    }

    function claimRefund(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Cancelled) revert MarketNotResolved();

        Bet storage b = userBets[marketId][msg.sender];
        if (b.claimed) revert AlreadyClaimed();
        if (b.amount == 0) revert NothingToClaim();

        uint256 refund = b.amount;
        b.claimed = true;
        balances[msg.sender] += refund;

        emit WinningsClaimed(marketId, msg.sender, refund, 0);
    }

    function setFeePercentage(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 old = feePercentage;
        feePercentage = newFeeBps;
        emit FeePercentageUpdated(old, newFeeBps);
    }

    function setFeeCollector(address newCollector) external onlyAdmin {
        if (newCollector == address(0)) revert ZeroAddress();
        address old = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(old, newCollector);
    }

    function setPaused(bool state) external onlyAdmin {
        paused = state;
        emit PausedStateChanged(state);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address old = admin;
        admin = newAdmin;
        emit AdminUpdated(old, newAdmin);
    }

    //--------------------------------------------------------------------
    // View helpers
    //--------------------------------------------------------------------
    function getMarket(uint256 marketId) external view returns (Market memory) {
        return markets[marketId];
    }

    function getUserBet(uint256 marketId, address user) external view returns (Bet memory) {
        return userBets[marketId][user];
    }

    function getUserMarkets(address user) external view returns (uint256[] memory) {
        return userMarketIds[user];
    }

    function getAvailableBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getMarketStakes(
        uint256 marketId
    ) external view marketExists(marketId) returns (uint256 stakeYes, uint256 stakeNo) {
        stakeYes = markets[marketId].totalStakeYes;
        stakeNo = markets[marketId].totalStakeNo;
    }

    function getPendingWinnings(
        uint256 marketId,
        address user
    ) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        if (m.status != MarketStatus.Resolved) return 0;

        Bet storage b = userBets[marketId][user];
        if (b.amount == 0 || b.prediction != m.outcome) return 0;

        uint256 winningPool = m.outcome ? m.totalStakeYes : m.totalStakeNo;
        if (winningPool == 0) return 0;

        uint256 totalPool = m.totalStakeYes + m.totalStakeNo;

        // Compute payout and fee using full-precision numerator to avoid
        // divide-before-multiply rounding loss.
        uint256 numerator = b.amount * totalPool;
        uint256 grossPayout = numerator / winningPool;
        uint256 fee = (numerator * feePercentage) / (winningPool * BASIS_POINTS);
        return grossPayout - fee;
    }
}
