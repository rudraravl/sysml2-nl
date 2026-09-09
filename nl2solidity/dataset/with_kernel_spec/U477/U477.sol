// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeTransfer {
    error TransferFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}

contract RWAPerpVault {
    using SafeTransfer for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error ZeroSize();
    error NotOperator();
    error TradingPaused();
    error NotPaused();
    error Reentrancy();
    error UnsupportedCollateral();
    error TokenAlreadySupported();
    error UnsupportedAsset();
    error AssetAlreadyExists();
    error AssetNotFound();
    error InvalidDecimals();
    error InvalidPrice();
    error InvalidLeverage();
    error LeverageTooHigh();
    error InsufficientFreeCollateral();
    error InsufficientReserve();
    error PositionNotFound();
    error CannotReversePosition();
    error SizeExceedsPosition();
    error EthNotAccepted();

    enum AssetType {
        RWA,
        Perp
    }

    uint256 public constant BPS = 10_000;
    uint256 public constant TRADING_FEE_BPS = 5; // 0.05%
    uint256 public constant MAX_LEVERAGE = 20e18;
    uint256 public constant PRICE_PRECISION = 1e30;
    uint256 public constant FUNDING_PRECISION = 1e18;
    uint256 public constant LEVERAGE_PRECISION = 1e18;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event PositionOpened(
        address indexed user,
        address indexed asset,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 entryPrice,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        address indexed asset,
        uint256 sizeClosed,
        uint256 marginReleased,
        int256 settle,
        uint256 fee
    );
    event FundingSettled(address indexed user, address indexed asset, int256 funding);
    event FundingUpdated(address indexed asset, int256 cumulativeFunding, uint40 lastTs);
    event AssetAdded(
        address indexed asset,
        address indexed quoteToken,
        AssetType assetType,
        uint256 price,
        uint256 maxLeverage,
        int256 fundingRate
    );
    event AssetSupportedChanged(address indexed asset, bool supported);
    event AssetPriceUpdated(address indexed asset, uint256 price);
    event MaxLeverageUpdated(address indexed asset, uint256 maxLeverage);
    event FundingRateUpdated(address indexed asset, int256 fundingRate);
    event CollateralTokenAdded(address indexed token, uint8 decimals);
    event CollateralTokenRemoved(address indexed token);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event Paused();
    event Unpaused();
    event ProtocolFeesClaimed(address indexed token, address indexed to, uint256 amount);

    address public operator;
    bool public paused;
    uint256 private _locked = 1;

    struct Collateral {
        bool supported;
        uint8 decimals;
    }

    struct Asset {
        bool supported;
        AssetType assetType;
        address quoteToken;
        uint256 price;
        uint256 maxLeverage;
        int256 fundingRate;
        int256 cumulativeFunding;
        uint40 lastFundingTs;
    }

    struct Position {
        uint256 size;
        bool isLong;
        uint256 entryPrice;
        uint256 margin;
        int256 entryFunding;
    }

    mapping(address => Collateral) public collateralTokens;
    mapping(address => Asset) public assets;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(address => uint256)) public lockedCollateral;
    mapping(address => mapping(address => Position)) public positions;
    mapping(address => uint256) public protocolFees;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        operator = msg.sender;
        emit OperatorChanged(address(0), msg.sender);
    }

    receive() external payable {
        revert EthNotAccepted();
    }

    // ------------------------------------------------------------------
    // View helpers
    // ------------------------------------------------------------------

    function freeCollateral(address user, address token) public view returns (uint256) {
        uint256 bal = collateralBalances[user][token];
        uint256 locked = lockedCollateral[user][token];
        return bal >= locked ? bal - locked : 0;
    }

    function isSupportedCollateral(address token) external view returns (bool) {
        return collateralTokens[token].supported;
    }

    function getAsset(address asset)
        external
        view
        returns (
            bool supported,
            AssetType assetType,
            address quoteToken,
            uint256 price,
            uint256 maxLeverage,
            int256 fundingRate,
            int256 cumulativeFunding,
            uint40 lastFundingTs
        )
    {
        Asset storage a = assets[asset];
        return (
            a.supported,
            a.assetType,
            a.quoteToken,
            a.price,
            a.maxLeverage,
            a.fundingRate,
            a.cumulativeFunding,
            a.lastFundingTs
        );
    }

    function getPosition(address user, address asset)
        external
        view
        returns (uint256 size, bool isLong, uint256 entryPrice, uint256 margin, int256 entryFunding)
    {
        Position storage p = positions[user][asset];
        return (p.size, p.isLong, p.entryPrice, p.margin, p.entryFunding);
    }

    // ------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------

    function _to18(uint256 amount, uint8 d) internal pure returns (uint256) {
        if (d == 18) return amount;
        if (d < 18) return amount * 10 ** (18 - d);
        return amount / 10 ** (d - 18);
    }

    function _from18(uint256 amount, uint8 d) internal pure returns (uint256) {
        if (d == 18) return amount;
        if (d < 18) return amount / 10 ** (18 - d);
        return amount * 10 ** (d - 18);
    }

    function _accrueFunding(address asset) internal {
        Asset storage a = assets[asset];
        uint40 last = a.lastFundingTs;
        if (last == 0) return;
        uint40 now_ = uint40(block.timestamp);
        if (now_ <= last) return;
        uint256 dt = uint256(now_) - uint256(last);
        a.cumulativeFunding += int256(dt) * a.fundingRate;
        a.lastFundingTs = now_;
    }

    function _computeFeeRaw(uint256 notional18, uint8 d) internal pure returns (uint256) {
        return _from18((notional18 * TRADING_FEE_BPS) / BPS, d);
    }

    // ------------------------------------------------------------------
    // Funding accrual (callable by anyone)
    // ------------------------------------------------------------------

    function updateFunding(address asset) external {
        if (assets[asset].lastFundingTs == 0) return;
        _accrueFunding(asset);
        emit FundingUpdated(asset, assets[asset].cumulativeFunding, assets[asset].lastFundingTs);
    }

    // ------------------------------------------------------------------
    // Collateral management
    // ------------------------------------------------------------------

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!collateralTokens[token].supported) revert UnsupportedCollateral();
        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 free = freeCollateral(msg.sender, token);
        if (free < amount) revert InsufficientFreeCollateral();
        collateralBalances[msg.sender][token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    // ------------------------------------------------------------------
    // Trading — open
    // ------------------------------------------------------------------

    function openPosition(address asset, uint256 size, bool isLong, uint256 margin)
        external
        nonReentrant
        whenNotPaused
    {
        Asset storage a = assets[asset];
        if (!a.supported) revert UnsupportedAsset();
        if (size == 0) revert ZeroSize();
        if (margin == 0) revert ZeroAmount();

        address quote = a.quoteToken;
        if (!collateralTokens[quote].supported) revert UnsupportedCollateral();
        uint8 d = collateralTokens[quote].decimals;
        if (d == 0) revert InvalidDecimals();

        uint256 price = a.price;
        if (price == 0) revert InvalidPrice();
        uint256 notional18 = (size * price) / PRICE_PRECISION;
        if (notional18 == 0) revert ZeroSize();

        _accrueFunding(asset);

        Position storage p = positions[msg.sender][asset];
        if (p.size != 0) {
            _increasePosition(p, a, asset, isLong, size, margin, notional18, price, d, quote);
        } else {
            _openNewPosition(p, a, asset, isLong, size, margin, notional18, price, d, quote);
        }
    }

    function _increasePosition(
        Position storage p,
        Asset storage a,
        address asset,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 notional18,
        uint256 price,
        uint8 d,
        address quote
    ) internal {
        if (p.isLong != isLong) revert CannotReversePosition();

        uint256 newSize = p.size + size;
        uint256 newMargin = p.margin + margin;
        uint256 margin18 = _to18(newMargin, d);
        if (margin18 == 0) revert ZeroAmount();
        uint256 lev = ((newSize * price) / PRICE_PRECISION * LEVERAGE_PRECISION) / margin18;
        if (lev > a.maxLeverage || lev > MAX_LEVERAGE) revert LeverageTooHigh();

        uint256 feeRaw = _computeFeeRaw(notional18, d);
        if (freeCollateral(msg.sender, quote) < margin + feeRaw) revert InsufficientFreeCollateral();

        p.entryPrice = (p.size * p.entryPrice + size * price) / newSize;
        p.entryFunding =
            (int256(p.size) * p.entryFunding + int256(size) * a.cumulativeFunding) /
            int256(newSize);
        p.size = newSize;
        p.margin = newMargin;

        collateralBalances[msg.sender][quote] -= feeRaw;
        protocolFees[quote] += feeRaw;
        lockedCollateral[msg.sender][quote] += margin;

        emit PositionOpened(msg.sender, asset, isLong, size, margin, price, feeRaw);
    }

    function _openNewPosition(
        Position storage p,
        Asset storage a,
        address asset,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 notional18,
        uint256 price,
        uint8 d,
        address quote
    ) internal {
        uint256 margin18 = _to18(margin, d);
        if (margin18 == 0) revert ZeroAmount();
        uint256 lev = (notional18 * LEVERAGE_PRECISION) / margin18;
        if (lev > a.maxLeverage || lev > MAX_LEVERAGE) revert LeverageTooHigh();

        uint256 feeRaw = _computeFeeRaw(notional18, d);
        if (freeCollateral(msg.sender, quote) < margin + feeRaw) revert InsufficientFreeCollateral();

        p.size = size;
        p.isLong = isLong;
        p.entryPrice = price;
        p.margin = margin;
        p.entryFunding = a.cumulativeFunding;

        collateralBalances[msg.sender][quote] -= feeRaw;
        protocolFees[quote] += feeRaw;
        lockedCollateral[msg.sender][quote] += margin;

        emit PositionOpened(msg.sender, asset, isLong, size, margin, price, feeRaw);
    }

    // ------------------------------------------------------------------
    // Trading — close
    // ------------------------------------------------------------------

    function closePosition(address asset, uint256 sizeToClose)
        external
        nonReentrant
        whenNotPaused
    {
        Position storage p = positions[msg.sender][asset];
        if (p.size == 0) revert PositionNotFound();
        if (sizeToClose == 0) revert ZeroSize();
        if (sizeToClose > p.size) revert SizeExceedsPosition();

        Asset storage a = assets[asset];
        address quote = a.quoteToken;
        uint8 d = collateralTokens[quote].decimals;
        if (d == 0) revert InvalidDecimals();

        _accrueFunding(asset);
        if (a.price == 0) revert InvalidPrice();

        (int256 settle18, uint256 settleAbsRaw, uint256 feeRaw, uint256 marginReleased) =
            _computeCloseSettlement(p, a, sizeToClose, d);

        uint256 userPays = feeRaw + (settle18 < 0 ? settleAbsRaw : uint256(0));
        if (freeCollateral(msg.sender, quote) + marginReleased < userPays)
            revert InsufficientFreeCollateral();

        if (settle18 > 0) {
            if (protocolFees[quote] < settleAbsRaw) revert InsufficientReserve();
            protocolFees[quote] -= settleAbsRaw;
            collateralBalances[msg.sender][quote] += settleAbsRaw;
        }

        collateralBalances[msg.sender][quote] -= feeRaw;
        protocolFees[quote] += feeRaw;

        if (settle18 < 0) {
            collateralBalances[msg.sender][quote] -= settleAbsRaw;
            protocolFees[quote] += settleAbsRaw;
        }

        lockedCollateral[msg.sender][quote] -= marginReleased;

        if (sizeToClose == p.size) {
            delete positions[msg.sender][asset];
        } else {
            p.size -= sizeToClose;
            p.margin -= marginReleased;
        }

        int256 settleSignedRaw = settle18 >= 0 ? int256(settleAbsRaw) : -int256(settleAbsRaw);
        emit PositionClosed(msg.sender, asset, sizeToClose, marginReleased, settleSignedRaw, feeRaw);
    }

    function _computeCloseSettlement(
        Position storage p,
        Asset storage a,
        uint256 sizeToClose,
        uint8 d
    ) internal view returns (int256 settle18, uint256 settleAbsRaw, uint256 feeRaw, uint256 marginReleased) {
        uint256 price = a.price;
        int256 priceDiff = p.isLong
            ? int256(price) - int256(p.entryPrice)
            : int256(p.entryPrice) - int256(price);
        int256 pnl18 = (int256(sizeToClose) * priceDiff) / int256(PRICE_PRECISION);

        uint256 notionalClosed18 = (sizeToClose * price) / PRICE_PRECISION;
        int256 fundDelta = a.cumulativeFunding - p.entryFunding;
        int256 funding18 = ((p.isLong ? -fundDelta : fundDelta) * int256(notionalClosed18)) /
            int256(FUNDING_PRECISION);

        settle18 = pnl18 + funding18;
        settleAbsRaw = _from18(settle18 >= 0 ? uint256(settle18) : uint256(-settle18), d);
        feeRaw = _computeFeeRaw(notionalClosed18, d);
        marginReleased = (p.margin * sizeToClose) / p.size;
    }

    // ------------------------------------------------------------------
    // Trading — funding claim
    // ------------------------------------------------------------------

    function claimFunding(address asset) external nonReentrant {
        Position storage p = positions[msg.sender][asset];
        if (p.size == 0) revert PositionNotFound();

        Asset storage a = assets[asset];
        address quote = a.quoteToken;
        uint8 d = collateralTokens[quote].decimals;
        if (d == 0) revert InvalidDecimals();

        _accrueFunding(asset);
        if (a.price == 0) revert InvalidPrice();

        (int256 funding18, uint256 absRaw) = _computeFundingAmount(p, a, d);

        if (funding18 >= 0) {
            if (protocolFees[quote] < absRaw) revert InsufficientReserve();
            protocolFees[quote] -= absRaw;
            collateralBalances[msg.sender][quote] += absRaw;
        } else {
            if (freeCollateral(msg.sender, quote) < absRaw) revert InsufficientFreeCollateral();
            collateralBalances[msg.sender][quote] -= absRaw;
            protocolFees[quote] += absRaw;
        }

        p.entryFunding = a.cumulativeFunding;
        emit FundingSettled(msg.sender, asset, funding18);
    }

    function _computeFundingAmount(
        Position storage p,
        Asset storage a,
        uint8 d
    ) internal view returns (int256 funding18, uint256 absRaw) {
        uint256 price = a.price;
        uint256 notional18 = (p.size * price) / PRICE_PRECISION;
        int256 fundDelta = a.cumulativeFunding - p.entryFunding;
        funding18 = ((p.isLong ? -fundDelta : fundDelta) * int256(notional18)) /
            int256(FUNDING_PRECISION);
        uint256 abs18 = funding18 >= 0 ? uint256(funding18) : uint256(-funding18);
        absRaw = _from18(abs18, d);
    }

    // ------------------------------------------------------------------
    // Operator controls
    // ------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function pause() external onlyOperator {
        if (paused) revert TradingPaused();
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOperator {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused();
    }

    function addCollateralToken(address token, uint8 decimals_) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (collateralTokens[token].supported) revert TokenAlreadySupported();
        if (decimals_ == 0 || decimals_ > 36) revert InvalidDecimals();
        collateralTokens[token] = Collateral({supported: true, decimals: decimals_});
        emit CollateralTokenAdded(token, decimals_);
    }

    function removeCollateralToken(address token) external onlyOperator {
        if (!collateralTokens[token].supported) revert UnsupportedCollateral();
        collateralTokens[token].supported = false;
        emit CollateralTokenRemoved(token);
    }

    function addAsset(
        address asset,
        address quoteToken,
        AssetType assetType,
        uint256 price,
        uint256 maxLeverage,
        int256 fundingRate
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (assets[asset].lastFundingTs != 0) revert AssetAlreadyExists();
        if (!collateralTokens[quoteToken].supported) revert UnsupportedCollateral();
        if (price == 0) revert InvalidPrice();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();

        assets[asset] = Asset({
            supported: true,
            assetType: assetType,
            quoteToken: quoteToken,
            price: price,
            maxLeverage: maxLeverage,
            fundingRate: fundingRate,
            cumulativeFunding: 0,
            lastFundingTs: uint40(block.timestamp)
        });

        emit AssetAdded(asset, quoteToken, assetType, price, maxLeverage, fundingRate);
    }

    function setAssetSupported(address asset, bool supported) external onlyOperator {
        if (assets[asset].lastFundingTs == 0) revert AssetNotFound();
        assets[asset].supported = supported;
        emit AssetSupportedChanged(asset, supported);
    }

    function setAssetPrice(address asset, uint256 price) external onlyOperator {
        if (assets[asset].lastFundingTs == 0) revert AssetNotFound();
        if (price == 0) revert InvalidPrice();
        assets[asset].price = price;
        emit AssetPriceUpdated(asset, price);
    }

    function setMaxLeverage(address asset, uint256 maxLeverage) external onlyOperator {
        if (assets[asset].lastFundingTs == 0) revert AssetNotFound();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        assets[asset].maxLeverage = maxLeverage;
        emit MaxLeverageUpdated(asset, maxLeverage);
    }

    function setFundingRate(address asset, int256 fundingRate) external onlyOperator {
        if (assets[asset].lastFundingTs == 0) revert AssetNotFound();
        _accrueFunding(asset);
        assets[asset].fundingRate = fundingRate;
        emit FundingRateUpdated(asset, fundingRate);
    }

    function claimProtocolFees(address token, address to, uint256 amount)
        external
        onlyOperator
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (protocolFees[token] < amount) revert InsufficientReserve();
        protocolFees[token] -= amount;
        IERC20(token).safeTransfer(to, amount);
        emit ProtocolFeesClaimed(token, to, amount);
    }
}
