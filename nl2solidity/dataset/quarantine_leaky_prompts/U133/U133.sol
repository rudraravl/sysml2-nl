// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IOracle {
    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title GMXPerpMarket
 * @notice A perpetual-futures derivatives market inspired by GMX V1 Perps.
 *
 * High-level behaviour
 * --------------------
 * The contract operates an internal liquidity pool denominated in a single
 * collateral token. Liquidity providers seed the pool through `addLiquidity`;
 * idle liquidity can be withdrawn by the admin through `removeLiquidity`. The
 * pool backs the counterparty side of every trade.
 *
 * Multiple perpetual "markets" can be registered by the owner. Each market is
 * identified by an id and references an underlying index asset plus a
 * Chainlink-style oracle that returns that asset's USD price. Traders open
 * leveraged long or short positions in a market through `increasePosition`,
 * specifying how much additional collateral to deposit and the USD notional
 * `sizeDelta` to add. Opening fees, expressed in basis points of notional, are
 * charged to the position's collateral and forwarded to a designated fee
 * collector.
 *
 * Positions are keyed by `keccak256(account, marketId, isLong)`. When a position
 * is increased, a volume-weighted average entry price is maintained. Leverage
 * is enforced per market through `minLeverage`/`maxLeverage` parameters
 * expressed in 1e30 precision.
 *
 * A per-second signed funding rate is set per market. Funding accrues
 * continuously: a positive rate means longs pay shorts; a negative rate means
 * shorts pay longs.
 *
 * Traders reduce or close positions through `decreasePosition`, supplying a
 * minimum acceptable exit price for slippage protection. Positions that have
 * fallen below the maintenance margin must be liquidated.
 *
 * Anybody may call `liquidatePosition` on an under-collateralised position.
 *
 * All state mutations follow checks-effects-interactions to prevent reentrancy.
 */
contract GMXPerpMarket {
    uint256 public constant USD_PRECISION = 1e30;
    uint256 public constant PRICE_PRECISION = 1e30;
    uint256 public constant FUNDING_RATE_PRECISION = 1e18;
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;
    uint256 public constant MAX_LEVERAGE_LIMIT = 1_000e30;
    uint256 public constant MIN_LEVERAGE_LIMIT = 1e30;
    int256  public constant MAX_FUNDING_RATE_PER_SEC = 1e15;
    uint256 public constant STALE_PRICE_SECONDS = 300;
    uint256 public constant MIN_SIZE_USD = 1e24;

    event MarketAdded(uint256 indexed marketId, address indexToken, address oracle);
    event MarketUpdated(uint256 indexed marketId, bool active, uint256 minLeverage, uint256 maxLeverage, uint256 maxOpenInterest);
    event FundingRateSet(uint256 indexed marketId, int256 fundingRatePerSec);
    event CumulativeFundingUpdated(uint256 indexed marketId, int256 longRate, int256 shortRate, uint256 lastFundingTime);
    event FeeParamsUpdated(uint256 marginFeeBps, uint256 liquidationFeeBps, uint256 maintenanceMarginBps);
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    event IncreasePosition(
        address indexed account, uint256 indexed marketId, bool isLong,
        uint256 collateralDelta, uint256 sizeDelta, uint256 newCollateral,
        uint256 newSize, uint256 averagePrice, uint256 fee
    );
    event DecreasePosition(
        address indexed account, uint256 indexed marketId, bool isLong,
        uint256 sizeDelta, int256 pnl, int256 fundingFee, uint256 marginFee, uint256 payout
    );
    event LiquidatePosition(
        address indexed account, uint256 indexed marketId, bool isLong,
        uint256 size, uint256 collateral, int256 pnl, uint256 liquidationFee,
        address indexed liquidator
    );
    event LiquidityAdded(address indexed provider, uint256 amount);
    event LiquidityRemoved(address indexed receiver, uint256 amount);
    event Paused(bool paused);
    event OwnershipTransferred(address previousOwner, address newOwner);

    error ZeroAddress();
    error Unauthorized();
    error MarketNotFound();
    error MarketNotActive();
    error InvalidLeverage();
    error InvalidPrice();
    error StalePrice();
    error InsufficientCollateral();
    error InsufficientPool();
    error PositionNotFound();
    error MaxOpenInterestExceeded();
    error SlippageExceeded();
    error PositionNotLiquidatable();
    error PositionAlreadyLiquidatable();
    error FundingRateExceeded();
    error InvalidAmount();
    error InvalidOracleDecimals();
    error DuplicatePosition();
    error SizeBelowMinimum();
    error ContractPaused();
    error ReentrantCall();
    error InvalidParam();
    error TransferFailed();

    struct Market {
        address indexToken;
        address oracle;
        uint256 minLeverage;
        uint256 maxLeverage;
        uint256 maxOpenInterest;
        uint256 openInterestLong;
        uint256 openInterestShort;
        int256  fundingRatePerSec;
        int256  cumulativeFundingRateLong;
        int256  cumulativeFundingRateShort;
        uint256 lastFundingTime;
        bool    active;
    }

    struct Position {
        address account;
        uint256 marketId;
        bool    isLong;
        uint256 size;
        uint256 collateral;
        uint256 averagePrice;
        int256  entryFundingRate;
        int256  realisedPnl;
        uint256 lastIncreasedTime;
    }

    struct IncreaseCalc {
        uint256 newCollateral;
        uint256 newSize;
        uint256 newAvgPrice;
        uint256 feeTokens;
        bool isNew;
    }

    struct DecreaseCalc {
        int256 pnlUSD;
        int256 fundingFeeUSD;
        uint256 marginFeeTokens;
        uint256 liqFeeTokens;
        uint256 collateralReleased;
        uint256 payout;
        uint256 feeCollectorPayout;
    }

    address public owner;
    address public collateralToken;
    uint256 public collateralDecimals;
    address public feeCollector;
    uint256 public marginFeeBps;
    uint256 public liquidationFeeBps;
    uint256 public maintenanceMarginBps;
    uint256 public marketCount;
    mapping(uint256 => Market) public markets;
    mapping(bytes32 => Position) public positions;
    mapping(address => bytes32[]) public userPositionKeys;
    mapping(bytes32 => uint256) internal _userPositionIndex;
    uint256 public totalPositionCollateral;
    bool public isPaused;
    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (markets[marketId].indexToken == address(0)) revert MarketNotFound();
        _;
    }

    modifier whenNotPaused() {
        if (isPaused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address owner_,
        address collateralToken_,
        address feeCollector_,
        uint256 marginFeeBps_,
        uint256 liquidationFeeBps_,
        uint256 maintenanceMarginBps_
    ) {
        if (owner_ == address(0) || collateralToken_ == address(0) || feeCollector_ == address(0)) revert ZeroAddress();
        if (marginFeeBps_ > BASIS_POINTS_DIVISOR) revert InvalidParam();
        if (liquidationFeeBps_ > BASIS_POINTS_DIVISOR) revert InvalidParam();
        if (maintenanceMarginBps_ < 1 || maintenanceMarginBps_ > BASIS_POINTS_DIVISOR) revert InvalidParam();

        owner = owner_;
        collateralToken = collateralToken_;
        collateralDecimals = IERC20(collateralToken_).decimals();
        feeCollector = feeCollector_;
        marginFeeBps = marginFeeBps_;
        liquidationFeeBps = liquidationFeeBps_;
        maintenanceMarginBps = maintenanceMarginBps_;

        emit OwnershipTransferred(address(0), owner_);
    }

    function addMarket(
        address indexToken,
        address oracle,
        uint256 minLeverage,
        uint256 maxLeverage,
        uint256 maxOpenInterest
    ) external onlyOwner returns (uint256 marketId) {
        if (indexToken == address(0) || oracle == address(0)) revert ZeroAddress();
        if (minLeverage < MIN_LEVERAGE_LIMIT || maxLeverage < minLeverage || maxLeverage > MAX_LEVERAGE_LIMIT) {
            revert InvalidLeverage();
        }
        marketId = ++marketCount;
        markets[marketId] = Market({
            indexToken: indexToken,
            oracle: oracle,
            minLeverage: minLeverage,
            maxLeverage: maxLeverage,
            maxOpenInterest: maxOpenInterest,
            openInterestLong: 0,
            openInterestShort: 0,
            fundingRatePerSec: 0,
            cumulativeFundingRateLong: 0,
            cumulativeFundingRateShort: 0,
            lastFundingTime: block.timestamp,
            active: true
        });
        emit MarketAdded(marketId, indexToken, oracle);
    }

    function updateMarket(
        uint256 marketId,
        bool active,
        uint256 minLeverage,
        uint256 maxLeverage,
        uint256 maxOpenInterest
    ) external onlyOwner marketExists(marketId) {
        if (minLeverage < MIN_LEVERAGE_LIMIT || maxLeverage < minLeverage || maxLeverage > MAX_LEVERAGE_LIMIT) {
            revert InvalidLeverage();
        }
        Market storage m = markets[marketId];
        m.active = active;
        m.minLeverage = minLeverage;
        m.maxLeverage = maxLeverage;
        m.maxOpenInterest = maxOpenInterest;
        emit MarketUpdated(marketId, active, minLeverage, maxLeverage, maxOpenInterest);
    }

    function setFundingRate(uint256 marketId, int256 fundingRatePerSec) external onlyOwner marketExists(marketId) {
        if (fundingRatePerSec > MAX_FUNDING_RATE_PER_SEC || fundingRatePerSec < -MAX_FUNDING_RATE_PER_SEC) {
            revert FundingRateExceeded();
        }
        _updateFunding(marketId);
        markets[marketId].fundingRatePerSec = fundingRatePerSec;
        emit FundingRateSet(marketId, fundingRatePerSec);
    }

    function setFeeParams(
        uint256 marginFeeBps_,
        uint256 liquidationFeeBps_,
        uint256 maintenanceMarginBps_
    ) external onlyOwner {
        if (marginFeeBps_ > BASIS_POINTS_DIVISOR || liquidationFeeBps_ > BASIS_POINTS_DIVISOR) revert InvalidParam();
        if (maintenanceMarginBps_ < 1 || maintenanceMarginBps_ > BASIS_POINTS_DIVISOR) revert InvalidParam();
        marginFeeBps = marginFeeBps_;
        liquidationFeeBps = liquidationFeeBps_;
        maintenanceMarginBps = maintenanceMarginBps_;
        emit FeeParamsUpdated(marginFeeBps_, liquidationFeeBps_, maintenanceMarginBps_);
    }

    function setFeeCollector(address feeCollector_) external onlyOwner {
        if (feeCollector_ == address(0)) revert ZeroAddress();
        emit FeeCollectorUpdated(feeCollector, feeCollector_);
        feeCollector = feeCollector_;
    }

    function setPaused(bool paused_) external onlyOwner {
        isPaused = paused_;
        emit Paused(paused_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function addLiquidity(uint256 amount) external whenNotPaused nonReentrant {
        if (amount < 1) revert InvalidAmount();
        _safeTransferFrom(collateralToken, msg.sender, address(this), amount);
        emit LiquidityAdded(msg.sender, amount);
    }

    function removeLiquidity(uint256 amount) external onlyOwner nonReentrant {
        if (amount < 1) revert InvalidAmount();
        if (amount > _freePool()) revert InsufficientPool();
        _safeTransfer(collateralToken, msg.sender, amount);
        emit LiquidityRemoved(msg.sender, amount);
    }

    function freePool() external view returns (uint256) {
        return _freePool();
    }

    function _freePool() internal view returns (uint256) {
        uint256 bal = IERC20(collateralToken).balanceOf(address(this));
        return bal > totalPositionCollateral ? bal - totalPositionCollateral : 0;
    }

    function updateFunding(uint256 marketId) external marketExists(marketId) {
        _updateFunding(marketId);
    }

    function _updateFunding(uint256 marketId) internal {
        Market storage m = markets[marketId];
        if (block.timestamp <= m.lastFundingTime) return;
        uint256 elapsed = block.timestamp - m.lastFundingTime;
        int256 delta = m.fundingRatePerSec * int256(elapsed);
        m.cumulativeFundingRateLong += delta;
        m.cumulativeFundingRateShort -= delta;
        m.lastFundingTime = block.timestamp;
        emit CumulativeFundingUpdated(marketId, m.cumulativeFundingRateLong, m.cumulativeFundingRateShort, m.lastFundingTime);
    }

    function _getPrice(uint256 marketId) internal view returns (uint256) {
        IOracle o = IOracle(markets[marketId].oracle);
        int256 ans = o.latestAnswer();
        if (ans <= 0) revert InvalidPrice();
        uint256 ts = o.latestTimestamp();
        if (block.timestamp > ts + STALE_PRICE_SECONDS) revert StalePrice();
        uint8 dec = o.decimals();
        if (dec < 1 || dec > 18) revert InvalidOracleDecimals();
        return (uint256(ans) * PRICE_PRECISION) / (10 ** uint256(dec));
    }

    function getPrice(uint256 marketId) external view marketExists(marketId) returns (uint256) {
        return _getPrice(marketId);
    }

    function positionKey(address account, uint256 marketId, bool isLong) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, marketId, isLong));
    }

    function _registerKey(address account, bytes32 key) internal {
        if (_userPositionIndex[key] != 0) revert DuplicatePosition();
        userPositionKeys[account].push(key);
        _userPositionIndex[key] = userPositionKeys[account].length;
    }

    function _deregisterKey(address account, bytes32 key) internal {
        uint256 idx = _userPositionIndex[key];
        if (idx == 0) return;
        uint256 len = userPositionKeys[account].length;
        if (idx != len) {
            bytes32 lastKey = userPositionKeys[account][len - 1];
            userPositionKeys[account][idx - 1] = lastKey;
            _userPositionIndex[lastKey] = idx;
        }
        userPositionKeys[account].pop();
        delete _userPositionIndex[key];
    }

    function getUserPositionKeys(address account) external view returns (bytes32[] memory) {
        return userPositionKeys[account];
    }

    function _usdToToken(uint256 usd) internal view returns (uint256) {
        return (usd * (10 ** collateralDecimals)) / USD_PRECISION;
    }

    function _usdToTokenSigned(int256 usd) internal view returns (int256) {
        bool neg = usd < 0;
        uint256 mag = neg ? uint256(-usd) : uint256(usd);
        uint256 tok = (mag * (10 ** collateralDecimals)) / USD_PRECISION;
        return neg ? -int256(tok) : int256(tok);
    }

    function _getPnl(uint256 entryPrice, uint256 exitPrice, uint256 sizeDelta, bool isLong)
        internal
        pure
        returns (int256 pnl)
    {
        if (isLong) {
            if (exitPrice >= entryPrice) {
                pnl = int256((sizeDelta * (exitPrice - entryPrice)) / entryPrice);
            } else {
                pnl = -int256((sizeDelta * (entryPrice - exitPrice)) / entryPrice);
            }
        } else {
            if (exitPrice <= entryPrice) {
                pnl = int256((sizeDelta * (entryPrice - exitPrice)) / entryPrice);
            } else {
                pnl = -int256((sizeDelta * (exitPrice - entryPrice)) / entryPrice);
            }
        }
    }

    function _getFundingFee(int256 cumulative, int256 entry, uint256 sizeDelta) internal pure returns (int256) {
        return ((cumulative - entry) * int256(sizeDelta)) / int256(FUNDING_RATE_PRECISION);
    }

    function _checkLeverage(uint256 size, uint256 collateral, uint256 minLev, uint256 maxLev) internal view {
        uint256 sizeInTokens = size * (10 ** collateralDecimals);
        if (sizeInTokens > collateral * maxLev) revert InvalidLeverage();
        if (sizeInTokens < collateral * minLev) revert InvalidLeverage();
    }

    function _isLiquidatable(Position storage pos, uint256 price) internal view returns (bool) {
        if (pos.size < 1) return false;
        Market storage m = markets[pos.marketId];
        int256 pnlUSD = _getPnl(pos.averagePrice, price, pos.size, pos.isLong);
        int256 fundingCum = pos.isLong ? m.cumulativeFundingRateLong : m.cumulativeFundingRateShort;
        int256 fundingFeeUSD = _getFundingFee(fundingCum, pos.entryFundingRate, pos.size);
        int256 effectiveCollateral =
            int256(pos.collateral) + _usdToTokenSigned(pnlUSD) - _usdToTokenSigned(fundingFeeUSD);
        if (effectiveCollateral <= 0) return true;
        uint256 maintenanceTokens = _usdToToken((pos.size * maintenanceMarginBps) / BASIS_POINTS_DIVISOR);
        return uint256(effectiveCollateral) < maintenanceTokens;
    }

    function isLiquidatable(address account, uint256 marketId, bool isLong)
        external
        view
        marketExists(marketId)
        returns (bool)
    {
        Position storage pos = positions[positionKey(account, marketId, isLong)];
        if (pos.size < 1) return false;
        return _isLiquidatable(pos, _getPrice(marketId));
    }

    function _calcIncrease(
        Position storage pos,
        uint256 collateralAmount,
        uint256 sizeDeltaUSD,
        uint256 price
    ) internal view returns (IncreaseCalc memory c) {
        c.isNew = (pos.size < 1);
        c.feeTokens = _usdToToken((sizeDeltaUSD * marginFeeBps) / BASIS_POINTS_DIVISOR);
        c.newCollateral = pos.collateral + collateralAmount;
        if (c.feeTokens > c.newCollateral) revert InsufficientCollateral();
        c.newCollateral -= c.feeTokens;
        if (c.newCollateral < 1) revert InsufficientCollateral();
        c.newSize = pos.size + sizeDeltaUSD;
        c.newAvgPrice = c.isNew ? price : ((pos.size * pos.averagePrice) + (sizeDeltaUSD * price)) / c.newSize;
    }

    function increasePosition(
        uint256 marketId,
        bool isLong,
        uint256 collateralAmount,
        uint256 sizeDeltaUSD,
        uint256 maxAcceptablePrice
    ) external nonReentrant whenNotPaused marketExists(marketId) returns (uint256 newAvgPrice) {
        Market storage m = markets[marketId];
        if (!m.active) revert MarketNotActive();
        if (sizeDeltaUSD < MIN_SIZE_USD) revert SizeBelowMinimum();

        uint256 price = _getPrice(marketId);
        if (maxAcceptablePrice > 0 && price > maxAcceptablePrice) revert SlippageExceeded();

        _updateFunding(marketId);

        bytes32 key = positionKey(msg.sender, marketId, isLong);
        Position storage pos = positions[key];
        uint256 oldCollateral = pos.collateral;

        IncreaseCalc memory c = _calcIncrease(pos, collateralAmount, sizeDeltaUSD, price);

        _checkLeverage(c.newSize, c.newCollateral, m.minLeverage, m.maxLeverage);

        {
            uint256 newOI = (isLong ? m.openInterestLong : m.openInterestShort) + sizeDeltaUSD;
            if (m.maxOpenInterest > 0 && newOI > m.maxOpenInterest) revert MaxOpenInterestExceeded();
            if (isLong) m.openInterestLong = newOI;
            else m.openInterestShort = newOI;
        }

        pos.account = msg.sender;
        pos.marketId = marketId;
        pos.isLong = isLong;
        pos.size = c.newSize;
        pos.collateral = c.newCollateral;
        pos.averagePrice = c.newAvgPrice;
        if (c.isNew) {
            pos.entryFundingRate = isLong ? m.cumulativeFundingRateLong : m.cumulativeFundingRateShort;
            _registerKey(msg.sender, key);
        }
        pos.lastIncreasedTime = block.timestamp;

        totalPositionCollateral += c.newCollateral - oldCollateral;

        if (collateralAmount > 0) {
            _safeTransferFrom(collateralToken, msg.sender, address(this), collateralAmount);
        }
        if (c.feeTokens > 0) {
            _safeTransfer(collateralToken, feeCollector, c.feeTokens);
        }

        newAvgPrice = c.newAvgPrice;
        emit IncreasePosition(
            msg.sender, marketId, isLong, collateralAmount, sizeDeltaUSD,
            c.newCollateral, c.newSize, c.newAvgPrice, c.feeTokens
        );
    }

    function _calcDecrease(
        Position storage pos,
        uint256 sizeDeltaUSD,
        uint256 price,
        bool isLiquidation
    ) internal view returns (DecreaseCalc memory d) {
        bool pl = pos.isLong;
        Market storage m = markets[pos.marketId];
        d.pnlUSD = _getPnl(pos.averagePrice, price, sizeDeltaUSD, pl);
        int256 fundingCum = pl ? m.cumulativeFundingRateLong : m.cumulativeFundingRateShort;
        d.fundingFeeUSD = _getFundingFee(fundingCum, pos.entryFundingRate, sizeDeltaUSD);
        d.marginFeeTokens = _usdToToken((sizeDeltaUSD * marginFeeBps) / BASIS_POINTS_DIVISOR);
        d.liqFeeTokens = isLiquidation ? _usdToToken((sizeDeltaUSD * liquidationFeeBps) / BASIS_POINTS_DIVISOR) : 0;
        d.collateralReleased = (pos.collateral * sizeDeltaUSD) / pos.size;

        int256 payoutSigned = int256(d.collateralReleased)
            + _usdToTokenSigned(d.pnlUSD)
            - _usdToTokenSigned(d.fundingFeeUSD)
            - int256(d.marginFeeTokens)
            - int256(d.liqFeeTokens);
        if (!isLiquidation && payoutSigned < 0) revert InsufficientCollateral();
        if (payoutSigned < 0) payoutSigned = 0;
        d.payout = uint256(payoutSigned);
        d.feeCollectorPayout = d.marginFeeTokens + d.liqFeeTokens;
    }

    function decreasePosition(
        uint256 marketId,
        bool isLong,
        uint256 sizeDeltaUSD,
        uint256 minAcceptablePrice
    ) external nonReentrant whenNotPaused marketExists(marketId) returns (uint256 payout) {
        _updateFunding(marketId);
        Market storage m = markets[marketId];
        if (!m.active) revert MarketNotActive();

        bytes32 key = positionKey(msg.sender, marketId, isLong);
        Position storage pos = positions[key];
        if (pos.size < 1) revert PositionNotFound();
        if (sizeDeltaUSD < 1) revert InvalidAmount();
        if (sizeDeltaUSD > pos.size) sizeDeltaUSD = pos.size;

        uint256 price = _getPrice(marketId);
        if (minAcceptablePrice > 0) {
            if (isLong ? price < minAcceptablePrice : price > minAcceptablePrice) revert SlippageExceeded();
        }
        if (_isLiquidatable(pos, price)) revert PositionAlreadyLiquidatable();

        payout = _settleDecrease(msg.sender, key, sizeDeltaUSD, price, false);
    }

    function liquidatePosition(address account, uint256 marketId, bool isLong)
        external
        nonReentrant
        marketExists(marketId)
        returns (uint256 payout)
    {
        _updateFunding(marketId);

        bytes32 key = positionKey(account, marketId, isLong);
        Position storage pos = positions[key];
        if (pos.size < 1) revert PositionNotFound();

        uint256 price = _getPrice(marketId);
        if (!_isLiquidatable(pos, price)) revert PositionNotLiquidatable();

        payout = _settleDecrease(account, key, pos.size, price, true);
    }

    function _settleDecrease(
        address account,
        bytes32 key,
        uint256 sizeDeltaUSD,
        uint256 price,
        bool isLiquidation
    ) internal returns (uint256 payout) {
        Position storage pos = positions[key];
        bool pl = pos.isLong;
        uint256 mktId = pos.marketId;

        DecreaseCalc memory d = _calcDecrease(pos, sizeDeltaUSD, price, isLiquidation);

        if (_freePool() + d.collateralReleased < d.payout + d.feeCollectorPayout) revert InsufficientPool();

        pos.realisedPnl += d.pnlUSD;
        pos.size -= sizeDeltaUSD;
        pos.collateral -= d.collateralReleased;
        totalPositionCollateral -= d.collateralReleased;

        Market storage m = markets[mktId];
        if (pl) m.openInterestLong -= sizeDeltaUSD;
        else m.openInterestShort -= sizeDeltaUSD;

        if (pos.size < 1) {
            _deregisterKey(account, key);
            delete positions[key];
        }

        if (d.payout > 0) _safeTransfer(collateralToken, account, d.payout);
        if (d.feeCollectorPayout > 0) _safeTransfer(collateralToken, feeCollector, d.feeCollectorPayout);

        payout = d.payout;

        if (isLiquidation) {
            emit LiquidatePosition(account, mktId, pl, sizeDeltaUSD, d.collateralReleased, d.pnlUSD, d.liqFeeTokens, msg.sender);
        } else {
            emit DecreasePosition(account, mktId, pl, sizeDeltaUSD, d.pnlUSD, d.fundingFeeUSD, d.marginFeeTokens, d.payout);
        }
    }

    function getMarket(uint256 marketId) external view marketExists(marketId) returns (Market memory) {
        return markets[marketId];
    }

    function getPosition(address account, uint256 marketId, bool isLong) external view returns (Position memory) {
        return positions[positionKey(account, marketId, isLong)];
    }

    function totalOpenInterest(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (uint256 longOI, uint256 shortOI)
    {
        return (markets[marketId].openInterestLong, markets[marketId].openInterestShort);
    }

    function cumulativeFundingRates(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (int256 longRate, int256 shortRate)
    {
        return (markets[marketId].cumulativeFundingRateLong, markets[marketId].cumulativeFundingRateShort);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
