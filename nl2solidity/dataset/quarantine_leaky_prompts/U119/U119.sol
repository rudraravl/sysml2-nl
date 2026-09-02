// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title PredictFun
 * @notice A prediction-market contract using a constant-product market maker (CPMM)
 *         for trading YES/NO outcome shares. Each market is seeded with initial
 *         liquidity, trades continuously until its end time, is resolved by a
 *         trusted resolver, passes through a dispute window, and finally allows
 *         winners to claim collateral proportionally.
 *
 * @dev Main flows:
 *
 *      1. Market Creation — A creator deposits initial liquidity (collateral) which
 *         seeds a CPMM pool with equal YES and NO reserves. The market is configured
 *         with an end time, dispute duration, and fee rate.
 *
 *      2. Trading — Until the market's end time, users can buy and sell YES or NO
 *         shares. Buying YES mints NO into the pool and removes YES from the pool
 *         (and vice-versa), preserving the invariant yesReserve * noReserve = k.
 *         A fee (in basis points) is charged per trade and retained in the pool for
 *         the liquidity provider. Slippage protection is enforced via min-output
 *         parameters.
 *
 *      3. Resolution — After the end time, the resolver (or owner) sets the outcome
 *         to Yes, No, or Void.
 *
 *      4. Dispute — During the dispute window after resolution, anyone may dispute
 *         the outcome, which resets it to Pending for re-resolution.
 *
 *      5. Finalization — Once the dispute window closes, anyone can finalize the
 *         market. Finalization pre-computes the creator's payout: the pool's
 *         winning-token value plus all accrued fees.
 *
 *      6. Claiming — Users holding winning outcome shares claim 1 collateral per
 *         share. If the market is voided, all shares (YES and NO) receive a
 *         proportional refund. The creator claims their pre-computed payout.
 *         Unclaimed funds can be swept to the creator after a 90-day delay.
 */
contract PredictFun {
    /* =============================================================== //
     *                           Types                                  //
     * =============================================================== //
     */

    enum Outcome { Pending, Yes, No, Void }

    struct Market {
        address creator;
        address collateralToken;
        string question;
        uint256 endTime;
        uint256 disputeDuration;
        uint256 resolveTime;
        Outcome outcome;
        bool finalized;
        bool creatorClaimed;
        bool swept;
        uint256 yesReserve;
        uint256 noReserve;
        uint256 totalYesSupply;
        uint256 totalNoSupply;
        uint256 poolCollateral;
        uint256 feeRate;
        uint256 creatorPayout;
        uint256 totalUserClaimed;
    }

    struct MarketSummary {
        address creator;
        address collateralToken;
        string question;
        uint256 endTime;
        uint256 resolveTime;
        Outcome outcome;
        bool finalized;
        uint256 yesReserve;
        uint256 noReserve;
        uint256 poolCollateral;
        uint256 creatorPayout;
    }

    /* =============================================================== //
     *                       State Variables                           //
     * =============================================================== //
     */

    address public owner;
    address public resolver;
    uint256 public marketCount;
    uint256 private _locked;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => uint256)) public yesShares;
    mapping(uint256 => mapping(address => uint256)) public noShares;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    /* =============================================================== //
     *                         Constants                                //
     * =============================================================== //
     */

    uint256 private constant PRECISION = 1e18;
    uint256 private constant BPS_DENOM = 10000;
    uint256 private constant MAX_FEE = 1000;        // 10 % ceiling
    uint256 private constant SWEEP_DELAY = 90 days;

    /* =============================================================== //
     *                            Events                                //
     * =============================================================== //
     */

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        uint256 endTime,
        uint256 initialLiquidity
    );
    event SharesBought(
        uint256 indexed marketId,
        address indexed buyer,
        bool isYes,
        uint256 collateralIn,
        uint256 sharesOut
    );
    event SharesSold(
        uint256 indexed marketId,
        address indexed seller,
        bool isYes,
        uint256 sharesIn,
        uint256 collateralOut
    );
    event MarketResolved(uint256 indexed marketId, Outcome outcome, uint256 resolveTime);
    event MarketDisputed(uint256 indexed marketId, address indexed disputer);
    event MarketFinalized(uint256 indexed marketId, uint256 creatorPayout);
    event UserClaimed(uint256 indexed marketId, address indexed user, uint256 amount);
    event CreatorClaimed(uint256 indexed marketId, address indexed creator, uint256 amount);
    event SweptUnclaimed(uint256 indexed marketId, address indexed to, uint256 amount);
    event ResolverUpdated(address indexed oldResolver, address indexed newResolver);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /* =============================================================== //
     *                            Errors                                //
     * =============================================================== //
     */

    error OnlyOwner();
    error OnlyResolver();
    error MarketNotFound();
    error MarketClosed();
    error MarketNotClosed();
    error NotResolved();
    error NotFinalized();
    error AlreadyResolved();
    error AlreadyFinalized();
    error AlreadyClaimed();
    error AlreadySwept();
    error DisputeWindowOpen();
    error DisputeWindowClosed();
    error SweepTooEarly();
    error InsufficientShares();
    error ZeroAmount();
    error ZeroAddress();
    error EmptyQuestion();
    error SlippageExceeded();
    error InvalidEndTime();
    error InvalidFeeRate();
    error InvalidOutcome();
    error TransferFailed();
    error ReentrancyDetected();

    /* =============================================================== //
     *                           Modifiers                             //
     * =============================================================== //
     */

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier marketExists(uint256 marketId) {
        if (marketId >= marketCount) revert MarketNotFound();
        _;
    }

    /* =============================================================== //
     *                          Constructor                             //
     * =============================================================== //
     */

    constructor(address _resolver) {
        if (_resolver == address(0)) revert ZeroAddress();
        owner = msg.sender;
        resolver = _resolver;
        _locked = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit ResolverUpdated(address(0), _resolver);
    }

    /* =============================================================== //
     *                       Admin Functions                           //
     * =============================================================== //
     */

    function setResolver(address _resolver) external onlyOwner {
        if (_resolver == address(0)) revert ZeroAddress();
        emit ResolverUpdated(resolver, _resolver);
        resolver = _resolver;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /* =============================================================== //
     *                      Market Creation                             //
     * =============================================================== //
     */

    /**
     * @notice Creates a new prediction market and seeds it with initial liquidity.
     * @param question         Human-readable question describing the market.
     * @param collateralToken  ERC-20 token used as collateral for this market.
     * @param endTime          Timestamp after which trading is disabled.
     * @param disputeDuration  Length of the dispute window after resolution (seconds).
     * @param feeRate          Trading fee in basis points (max 1000 = 10 %).
     * @param initialLiquidity Amount of collateral to seed the CPMM pool.
     * @return marketId        Numeric ID of the newly created market.
     */
    function createMarket(
        string calldata question,
        address collateralToken,
        uint256 endTime,
        uint256 disputeDuration,
        uint256 feeRate,
        uint256 initialLiquidity
    ) external nonReentrant returns (uint256 marketId) {
        if (bytes(question).length == 0) revert EmptyQuestion();
        if (collateralToken == address(0)) revert ZeroAddress();
        if (endTime <= block.timestamp) revert InvalidEndTime();
        if (feeRate > MAX_FEE) revert InvalidFeeRate();
        if (initialLiquidity == 0) revert ZeroAmount();

        // -------- Effects --------
        marketId = marketCount++;
        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.collateralToken = collateralToken;
        m.question = question;
        m.endTime = endTime;
        m.disputeDuration = disputeDuration;
        m.feeRate = feeRate;
        m.yesReserve = initialLiquidity;
        m.noReserve = initialLiquidity;
        m.totalYesSupply = initialLiquidity;
        m.totalNoSupply = initialLiquidity;
        m.poolCollateral = initialLiquidity;

        // -------- Interactions --------
        bool ok = IERC20(collateralToken).transferFrom(
            msg.sender,
            address(this),
            initialLiquidity
        );
        if (!ok) revert TransferFailed();

        emit MarketCreated(marketId, msg.sender, question, endTime, initialLiquidity);
    }

    /* =============================================================== //
     *                     Trading — Buy Shares                        //
     * =============================================================== //
     */

    /**
     * @notice Buys YES shares from the CPMM pool.
     * @param  marketId      ID of the market.
     * @param  collateralIn  Amount of collateral to spend.
     * @param  minSharesOut  Minimum shares to receive (slippage protection).
     * @return sharesOut      Number of YES shares received.
     */
    function buyYes(
        uint256 marketId,
        uint256 collateralIn,
        uint256 minSharesOut
    ) external nonReentrant marketExists(marketId) returns (uint256 sharesOut) {
        Market storage m = markets[marketId];
        if (block.timestamp >= m.endTime) revert MarketClosed();
        if (collateralIn == 0) revert ZeroAmount();

        uint256 fee = (collateralIn * m.feeRate) / BPS_DENOM;
        uint256 effectiveIn = collateralIn - fee;

        // CPMM: sharesOut = yesReserve * effectiveIn / (noReserve + effectiveIn)
        sharesOut = (m.yesReserve * effectiveIn) / (m.noReserve + effectiveIn);
        if (sharesOut == 0) revert ZeroAmount();
        if (sharesOut < minSharesOut) revert SlippageExceeded();

        // -------- Effects --------
        m.yesReserve -= sharesOut;
        m.noReserve += effectiveIn;
        m.totalNoSupply += effectiveIn;
        m.poolCollateral += collateralIn;
        yesShares[marketId][msg.sender] += sharesOut;

        // -------- Interactions --------
        bool ok = IERC20(m.collateralToken).transferFrom(
            msg.sender,
            address(this),
            collateralIn
        );
        if (!ok) revert TransferFailed();

        emit SharesBought(marketId, msg.sender, true, collateralIn, sharesOut);
    }

    /**
     * @notice Buys NO shares from the CPMM pool.
     * @param  marketId      ID of the market.
     * @param  collateralIn  Amount of collateral to spend.
     * @param  minSharesOut  Minimum shares to receive (slippage protection).
     * @return sharesOut      Number of NO shares received.
     */
    function buyNo(
        uint256 marketId,
        uint256 collateralIn,
        uint256 minSharesOut
    ) external nonReentrant marketExists(marketId) returns (uint256 sharesOut) {
        Market storage m = markets[marketId];
        if (block.timestamp >= m.endTime) revert MarketClosed();
        if (collateralIn == 0) revert ZeroAmount();

        uint256 fee = (collateralIn * m.feeRate) / BPS_DENOM;
        uint256 effectiveIn = collateralIn - fee;

        // CPMM: sharesOut = noReserve * effectiveIn / (yesReserve + effectiveIn)
        sharesOut = (m.noReserve * effectiveIn) / (m.yesReserve + effectiveIn);
        if (sharesOut == 0) revert ZeroAmount();
        if (sharesOut < minSharesOut) revert SlippageExceeded();

        // -------- Effects --------
        m.noReserve -= sharesOut;
        m.yesReserve += effectiveIn;
        m.totalYesSupply += effectiveIn;
        m.poolCollateral += collateralIn;
        noShares[marketId][msg.sender] += sharesOut;

        // -------- Interactions --------
        bool ok = IERC20(m.collateralToken).transferFrom(
            msg.sender,
            address(this),
            collateralIn
        );
        if (!ok) revert TransferFailed();

        emit SharesBought(marketId, msg.sender, false, collateralIn, sharesOut);
    }

    /* =============================================================== //
     *                     Trading — Sell Shares                        //
     * =============================================================== //
     */

    /**
     * @notice Sells YES shares back into the CPMM pool.
     * @param  marketId           ID of the market.
     * @param  sharesIn           Number of YES shares to sell.
     * @param  minCollateralOut   Minimum collateral to receive (slippage protection).
     * @return collateralOut       Collateral received.
     */
    function sellYes(
        uint256 marketId,
        uint256 sharesIn,
        uint256 minCollateralOut
    ) external nonReentrant marketExists(marketId) returns (uint256 collateralOut) {
        Market storage m = markets[marketId];
        if (block.timestamp >= m.endTime) revert MarketClosed();
        if (sharesIn == 0) revert ZeroAmount();
        if (yesShares[marketId][msg.sender] < sharesIn) revert InsufficientShares();

        // CPMM: rawOut = noReserve * sharesIn / (yesReserve + sharesIn)
        uint256 rawOut = (m.noReserve * sharesIn) / (m.yesReserve + sharesIn);
        uint256 fee = (rawOut * m.feeRate) / BPS_DENOM;
        collateralOut = rawOut - fee;
        if (collateralOut < minCollateralOut) revert SlippageExceeded();

        // -------- Effects --------
        yesShares[marketId][msg.sender] -= sharesIn;
        m.yesReserve += sharesIn;
        m.noReserve -= rawOut;
        m.totalNoSupply -= rawOut;
        m.poolCollateral -= collateralOut;

        // -------- Interactions --------
        bool ok = IERC20(m.collateralToken).transfer(msg.sender, collateralOut);
        if (!ok) revert TransferFailed();

        emit SharesSold(marketId, msg.sender, true, sharesIn, collateralOut);
    }

    /**
     * @notice Sells NO shares back into the CPMM pool.
     * @param  marketId           ID of the market.
     * @param  sharesIn           Number of NO shares to sell.
     * @param  minCollateralOut   Minimum collateral to receive (slippage protection).
     * @return collateralOut       Collateral received.
     */
    function sellNo(
        uint256 marketId,
        uint256 sharesIn,
        uint256 minCollateralOut
    ) external nonReentrant marketExists(marketId) returns (uint256 collateralOut) {
        Market storage m = markets[marketId];
        if (block.timestamp >= m.endTime) revert MarketClosed();
        if (sharesIn == 0) revert ZeroAmount();
        if (noShares[marketId][msg.sender] < sharesIn) revert InsufficientShares();

        // CPMM: rawOut = yesReserve * sharesIn / (noReserve + sharesIn)
        uint256 rawOut = (m.yesReserve * sharesIn) / (m.noReserve + sharesIn);
        uint256 fee = (rawOut * m.feeRate) / BPS_DENOM;
        collateralOut = rawOut - fee;
        if (collateralOut < minCollateralOut) revert SlippageExceeded();

        // -------- Effects --------
        noShares[marketId][msg.sender] -= sharesIn;
        m.noReserve += sharesIn;
        m.yesReserve -= rawOut;
        m.totalYesSupply -= rawOut;
        m.poolCollateral -= collateralOut;

        // -------- Interactions --------
        bool ok = IERC20(m.collateralToken).transfer(msg.sender, collateralOut);
        if (!ok) revert TransferFailed();

        emit SharesSold(marketId, msg.sender, false, sharesIn, collateralOut);
    }

    /* =============================================================== //
     *                       Resolution & Dispute                       //
     * =============================================================== //
     */

    /**
     * @notice Resolves the market outcome. Only callable by the resolver or owner
     *         after the market's end time.
     */
    function resolveMarket(uint256 marketId, Outcome outcome)
        external
        marketExists(marketId)
    {
        if (msg.sender != resolver && msg.sender != owner) revert OnlyResolver();
        Market storage m = markets[marketId];
        if (block.timestamp < m.endTime) revert MarketNotClosed();
        if (m.outcome != Outcome.Pending) revert AlreadyResolved();
        if (outcome == Outcome.Pending) revert InvalidOutcome();

        m.outcome = outcome;
        m.resolveTime = block.timestamp;

        emit MarketResolved(marketId, outcome, block.timestamp);
    }

    /**
     * @notice Disputes a resolution, resetting the outcome to Pending so the
     *         resolver can re-resolve. Callable by anyone within the dispute window.
     */
    function disputeResolution(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.outcome == Outcome.Pending) revert NotResolved();
        if (m.finalized) revert AlreadyFinalized();
        if (block.timestamp > m.resolveTime + m.disputeDuration)
            revert DisputeWindowClosed();

        m.outcome = Outcome.Pending;
        m.resolveTime = 0;

        emit MarketDisputed(marketId, msg.sender);
    }

    /**
     * @notice Finalizes the market after the dispute window closes, pre-computing
     *         the creator's payout (pool token value + accrued fees).
     */
    function finalizeMarket(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.outcome == Outcome.Pending) revert NotResolved();
        if (m.finalized) revert AlreadyFinalized();
        if (block.timestamp <= m.resolveTime + m.disputeDuration)
            revert DisputeWindowOpen();

        if (m.outcome == Outcome.Yes) {
            // Each YES token is worth 1 collateral; creator gets pool's YES + excess.
            uint256 totalUserYes = m.totalYesSupply - m.yesReserve;
            m.creatorPayout = m.poolCollateral - totalUserYes;
        } else if (m.outcome == Outcome.No) {
            // Each NO token is worth 1 collateral; creator gets pool's NO + excess.
            uint256 totalUserNo = m.totalNoSupply - m.noReserve;
            m.creatorPayout = m.poolCollateral - totalUserNo;
        } else {
            // Void: every token (YES or NO) gets a proportional refund.
            _computeVoidPayout(m);
        }

        m.finalized = true;
        emit MarketFinalized(marketId, m.creatorPayout);
    }

    /// @dev Computes the creator payout for a Void outcome in-place.
    function _computeVoidPayout(Market storage m) internal {
        uint256 totalSupply = m.totalYesSupply + m.totalNoSupply;
        if (totalSupply == 0) {
            m.creatorPayout = m.poolCollateral;
        } else {
            uint256 totalUserTokens =
                (m.totalYesSupply - m.yesReserve) + (m.totalNoSupply - m.noReserve);
            uint256 totalUserPayout =
                (totalUserTokens * m.poolCollateral) / totalSupply;
            m.creatorPayout = m.poolCollateral - totalUserPayout;
        }
    }

    /* =============================================================== //
     *                          Claiming                                //
     * =============================================================== //
     */

    /**
     * @notice Claims a user's winnings after the market is finalized.
     *         If YES won, each YES share is worth 1 collateral.
     *         If NO won, each NO share is worth 1 collateral.
     *         If voided, both YES and NO shares receive a proportional refund.
     */
    function claim(uint256 marketId)
        external
        nonReentrant
        marketExists(marketId)
        returns (uint256 payout)
    {
        Market storage m = markets[marketId];
        if (!m.finalized) revert NotFinalized();
        if (m.swept) revert AlreadySwept();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        payout = _computeUserPayout(m, marketId, msg.sender);

        // -------- Effects --------
        hasClaimed[marketId][msg.sender] = true;
        yesShares[marketId][msg.sender] = 0;
        noShares[marketId][msg.sender] = 0;
        m.totalUserClaimed += payout;

        // -------- Interactions --------
        if (payout > 0) {
            bool ok = IERC20(m.collateralToken).transfer(msg.sender, payout);
            if (!ok) revert TransferFailed();
        }

        emit UserClaimed(marketId, msg.sender, payout);
    }

    /// @dev Computes a user's payout based on the finalized outcome.
    function _computeUserPayout(Market storage m, uint256 marketId, address user)
        internal
        view
        returns (uint256 payout)
    {
        uint256 userYes = yesShares[marketId][user];
        uint256 userNo = noShares[marketId][user];

        if (m.outcome == Outcome.Yes) {
            payout = userYes;
        } else if (m.outcome == Outcome.No) {
            payout = userNo;
        } else {
            uint256 totalSupply = m.totalYesSupply + m.totalNoSupply;
            if (totalSupply > 0) {
                payout = ((userYes + userNo) * m.poolCollateral) / totalSupply;
            }
        }
    }

    /**
     * @notice Claims the creator's (liquidity provider's) pre-computed payout.
     *         The owner may also call this on the creator's behalf.
     */
    function claimCreator(uint256 marketId)
        external
        nonReentrant
        marketExists(marketId)
        returns (uint256 payout)
    {
        Market storage m = markets[marketId];
        if (!m.finalized) revert NotFinalized();
        if (m.swept) revert AlreadySwept();
        if (m.creatorClaimed) revert AlreadyClaimed();
        if (msg.sender != m.creator && msg.sender != owner) revert OnlyOwner();

        m.creatorClaimed = true;
        payout = m.creatorPayout;

        if (payout > 0) {
            bool ok = IERC20(m.collateralToken).transfer(m.creator, payout);
            if (!ok) revert TransferFailed();
        }

        emit CreatorClaimed(marketId, m.creator, payout);
    }

    /**
     * @notice Sweeps any unclaimed user funds to the creator after a 90-day
     *         delay from the end of the dispute window. Also claims the
     *         creator's payout if it has not been claimed yet.
     */
    function sweepUnclaimed(uint256 marketId) external nonReentrant marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.finalized) revert NotFinalized();
        if (m.swept) revert AlreadySwept();
        if (block.timestamp <= m.resolveTime + m.disputeDuration + SWEEP_DELAY)
            revert SweepTooEarly();

        m.swept = true;

        // Claim creator payout if not already done.
        if (!m.creatorClaimed) {
            m.creatorClaimed = true;
            if (m.creatorPayout > 0) {
                bool ok = IERC20(m.collateralToken).transfer(
                    m.creator,
                    m.creatorPayout
                );
                if (!ok) revert TransferFailed();
            }
            emit CreatorClaimed(marketId, m.creator, m.creatorPayout);
        }

        // Sweep remaining unclaimed user funds.
        uint256 remaining = m.poolCollateral - m.totalUserClaimed - m.creatorPayout;
        if (remaining > 0) {
            bool ok = IERC20(m.collateralToken).transfer(m.creator, remaining);
            if (!ok) revert TransferFailed();
        }

        emit SweptUnclaimed(marketId, m.creator, remaining);
    }

    /* =============================================================== //
     *                       View Functions                            //
     * =============================================================== //
     */

    /**
     * @notice Returns the current YES price (in 1e18 precision).
     *         Price = noReserve / (yesReserve + noReserve).
     */
    function getYesPrice(uint256 marketId)
        public
        view
        marketExists(marketId)
        returns (uint256)
    {
        Market storage m = markets[marketId];
        uint256 total = m.yesReserve + m.noReserve;
        if (total == 0) return PRECISION / 2;
        return (m.noReserve * PRECISION) / total;
    }

    /**
     * @notice Returns the current NO price (in 1e18 precision).
     *         Price = yesReserve / (yesReserve + noReserve).
     */
    function getNoPrice(uint256 marketId)
        public
        view
        marketExists(marketId)
        returns (uint256)
    {
        Market storage m = markets[marketId];
        uint256 total = m.yesReserve + m.noReserve;
        if (total == 0) return PRECISION / 2;
        return (m.yesReserve * PRECISION) / total;
    }

    /**
     * @notice Quotes the number of shares a user would receive for a given
     *         collateral amount on a buy trade (before any state change).
     */
    function getBuyQuote(uint256 marketId, bool isYes, uint256 collateralIn)
        external
        view
        marketExists(marketId)
        returns (uint256 sharesOut)
    {
        Market storage m = markets[marketId];
        uint256 fee = (collateralIn * m.feeRate) / BPS_DENOM;
        uint256 effectiveIn = collateralIn - fee;
        if (isYes) {
            sharesOut = (m.yesReserve * effectiveIn) / (m.noReserve + effectiveIn);
        } else {
            sharesOut = (m.noReserve * effectiveIn) / (m.yesReserve + effectiveIn);
        }
    }

    /**
     * @notice Quotes the collateral a user would receive for selling a given
     *         number of shares (before any state change).
     */
    function getSellQuote(uint256 marketId, bool isYes, uint256 sharesIn)
        external
        view
        marketExists(marketId)
        returns (uint256 collateralOut)
    {
        Market storage m = markets[marketId];
        uint256 rawOut;
        if (isYes) {
            rawOut = (m.noReserve * sharesIn) / (m.yesReserve + sharesIn);
        } else {
            rawOut = (m.yesReserve * sharesIn) / (m.noReserve + sharesIn);
        }
        uint256 fee = (rawOut * m.feeRate) / BPS_DENOM;
        collateralOut = rawOut - fee;
    }

    /**
     * @notice Returns a user's current YES/NO share balances and claim status.
     */
    function getUserPosition(uint256 marketId, address user)
        external
        view
        marketExists(marketId)
        returns (uint256 userYes, uint256 userNo, bool claimed)
    {
        return (
            yesShares[marketId][user],
            noShares[marketId][user],
            hasClaimed[marketId][user]
        );
    }

    /**
     * @notice Returns a summary of the market's current state.
     */
    function getMarketSummary(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (MarketSummary memory)
    {
        Market storage m = markets[marketId];
        return MarketSummary({
            creator: m.creator,
            collateralToken: m.collateralToken,
            question: m.question,
            endTime: m.endTime,
            resolveTime: m.resolveTime,
            outcome: m.outcome,
            finalized: m.finalized,
            yesReserve: m.yesReserve,
            noReserve: m.noReserve,
            poolCollateral: m.poolCollateral,
            creatorPayout: m.creatorPayout
        });
    }
}
