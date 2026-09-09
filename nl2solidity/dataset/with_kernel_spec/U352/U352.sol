// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title PredictionMarket
 * @notice Manages binary (Yes/No) prediction markets backed by an ERC20 stablecoin.
 *         Users deposit collateral to mint outcome shares, can sell shares back before
 *         resolution, and claim a proportional share of the pool after the market is
 *         resolved. A designated market creator resolves each market; a 2% fee is taken
 *         from the resolution payout pool.
 */
contract PredictionMarket {
    enum Outcome {
        None,
        Yes,
        No
    }

    struct Market {
        string topic;
        address creator;
        bool resolved;
        Outcome outcome;
        uint256 totalCollateral;
        uint256 totalYesShares;
        uint256 totalNoShares;
        uint256 feeAmount;
        uint256 payoutPool;
    }

    struct UserPosition {
        uint256 yesShares;
        uint256 noShares;
        bool withdrawn;
    }

    IERC20 public immutable stablecoin;
    address public marketCreator;
    uint256 public nextMarketId;

    uint256 public constant MIN_INITIAL_COLLATERAL = 100 ether; // assumes 18-decimal stablecoin
    uint256 public constant FEE_BPS = 200; // 2.00%
    uint256 private constant BPS_DENOM = 10_000;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => UserPosition)) public positions;

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string topic,
        Outcome initialOutcome,
        uint256 initialCollateral
    );
    event CollateralDeposited(
        uint256 indexed marketId,
        address indexed user,
        Outcome outcome,
        uint256 amount,
        uint256 sharesMinted
    );
    event SharesSold(
        uint256 indexed marketId,
        address indexed user,
        Outcome outcome,
        uint256 shares,
        uint256 amountReturned
    );
    event CollateralWithdrawn(uint256 indexed marketId, address indexed user, uint256 amount);
    event MarketResolved(
        uint256 indexed marketId,
        Outcome outcome,
        uint256 feeAmount,
        uint256 payoutPool
    );
    event MarketCreatorUpdated(address indexed previousCreator, address indexed newCreator);

    error NotMarketCreator();
    error InvalidAddress();
    error MarketNotFound();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error InsufficientInitialCollateral(uint256 provided, uint256 required);
    error InvalidOutcome();
    error InsufficientShares();
    error NoWinningShares();
    error AlreadyWithdrawn();
    error ZeroAmount();
    error TransferFailed();

    modifier onlyMarketCreator() {
        if (msg.sender != marketCreator) revert NotMarketCreator();
        _;
    }

    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert InvalidAddress();
        stablecoin = IERC20(_stablecoin);
        marketCreator = msg.sender;
        nextMarketId = 1;
    }

    /**
     * @notice Creates a new prediction market and seeds it with an initial collateral deposit.
     * @param topic Human-readable description of the market.
     * @param initialOutcome The outcome to seed (Yes or No).
     * @param initialCollateral Amount of stablecoin to deposit; must be >= MIN_INITIAL_COLLATERAL.
     * @return marketId The id of the newly created market.
     */
    function createMarket(
        string calldata topic,
        Outcome initialOutcome,
        uint256 initialCollateral
    ) external returns (uint256 marketId) {
        if (initialCollateral < MIN_INITIAL_COLLATERAL) {
            revert InsufficientInitialCollateral(initialCollateral, MIN_INITIAL_COLLATERAL);
        }
        if (initialOutcome == Outcome.None) revert InvalidOutcome();

        marketId = nextMarketId++;
        Market storage m = markets[marketId];
        m.topic = topic;
        m.creator = msg.sender;
        m.totalCollateral = initialCollateral;

        UserPosition storage pos = positions[marketId][msg.sender];
        if (initialOutcome == Outcome.Yes) {
            m.totalYesShares = initialCollateral;
            pos.yesShares = initialCollateral;
        } else {
            m.totalNoShares = initialCollateral;
            pos.noShares = initialCollateral;
        }

        _safeTransferFrom(msg.sender, address(this), initialCollateral);

        emit MarketCreated(marketId, msg.sender, topic, initialOutcome, initialCollateral);
        emit CollateralDeposited(marketId, msg.sender, initialOutcome, initialCollateral, initialCollateral);
    }

    /**
     * @notice Deposits collateral into an active market to mint outcome shares (1:1).
     */
    function deposit(uint256 marketId, Outcome outcome, uint256 amount) external {
        Market storage m = markets[marketId];
        if (m.creator == address(0)) revert MarketNotFound();
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcome == Outcome.None) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();

        m.totalCollateral += amount;
        UserPosition storage pos = positions[marketId][msg.sender];
        if (outcome == Outcome.Yes) {
            m.totalYesShares += amount;
            pos.yesShares += amount;
        } else {
            m.totalNoShares += amount;
            pos.noShares += amount;
        }

        _safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(marketId, msg.sender, outcome, amount, amount);
    }

    /**
     * @notice Sells outcome shares back to the market for collateral (1:1) before resolution.
     */
    function sellShares(uint256 marketId, Outcome outcome, uint256 shares) external {
        Market storage m = markets[marketId];
        if (m.creator == address(0)) revert MarketNotFound();
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcome == Outcome.None) revert InvalidOutcome();
        if (shares == 0) revert ZeroAmount();

        UserPosition storage pos = positions[marketId][msg.sender];
        if (outcome == Outcome.Yes) {
            if (pos.yesShares < shares) revert InsufficientShares();
            pos.yesShares -= shares;
            m.totalYesShares -= shares;
        } else {
            if (pos.noShares < shares) revert InsufficientShares();
            pos.noShares -= shares;
            m.totalNoShares -= shares;
        }
        m.totalCollateral -= shares;

        _safeTransfer(msg.sender, shares);

        emit SharesSold(marketId, msg.sender, outcome, shares, shares);
    }

    /**
     * @notice Resolves a market to a final outcome. Only the designated market creator may call.
     *         A 2% fee is deducted from the payout pool and sent to the market creator.
     */
    function resolveMarket(uint256 marketId, Outcome outcome) external onlyMarketCreator {
        Market storage m = markets[marketId];
        if (m.creator == address(0)) revert MarketNotFound();
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcome == Outcome.None) revert InvalidOutcome();

        uint256 totalWinning = (outcome == Outcome.Yes) ? m.totalYesShares : m.totalNoShares;
        if (totalWinning == 0) revert NoWinningShares();

        uint256 feeAmount = (m.totalCollateral * FEE_BPS) / BPS_DENOM;
        uint256 payoutPool = m.totalCollateral - feeAmount;

        m.resolved = true;
        m.outcome = outcome;
        m.feeAmount = feeAmount;
        m.payoutPool = payoutPool;

        if (feeAmount > 0) {
            _safeTransfer(marketCreator, feeAmount);
        }

        emit MarketResolved(marketId, outcome, feeAmount, payoutPool);
    }

    /**
     * @notice Withdraws a user's proportional share of a resolved market's payout pool.
     *         Only holders of the winning outcome shares may withdraw.
     */
    function withdraw(uint256 marketId) external {
        Market storage m = markets[marketId];
        if (m.creator == address(0)) revert MarketNotFound();
        if (!m.resolved) revert MarketNotResolved();

        UserPosition storage pos = positions[marketId][msg.sender];
        if (pos.withdrawn) revert AlreadyWithdrawn();

        uint256 shares = (m.outcome == Outcome.Yes) ? pos.yesShares : pos.noShares;
        if (shares == 0) revert InsufficientShares();

        uint256 totalWinning = (m.outcome == Outcome.Yes) ? m.totalYesShares : m.totalNoShares;
        if (totalWinning == 0) revert NoWinningShares();

        uint256 payout = (m.payoutPool * shares) / totalWinning;
        pos.withdrawn = true;

        _safeTransfer(msg.sender, payout);

        emit CollateralWithdrawn(marketId, msg.sender, payout);
    }

    /**
     * @notice Transfers the market creator privilege to a new address.
     */
    function setMarketCreator(address newCreator) external onlyMarketCreator {
        if (newCreator == address(0)) revert InvalidAddress();
        emit MarketCreatorUpdated(marketCreator, newCreator);
        marketCreator = newCreator;
    }

    /**
     * @dev Internal safe transfer that reverts on a failed `transfer`.
     */
    function _safeTransfer(address to, uint256 amount) internal {
        if (!stablecoin.transfer(to, amount)) revert TransferFailed();
    }

    /**
     * @dev Internal safe transferFrom that reverts on a failed `transferFrom`.
     */
    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        if (!stablecoin.transferFrom(from, to, amount)) revert TransferFailed();
    }
}
