// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _pause() internal {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }
}

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: unauthorized");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(role, account);
    }
}

contract PerpetualFuturesExchange is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant TRADING_FEE_BPS = 10; // 0.1%
    uint256 public constant MAX_LEVERAGE_CAP = 50e18;
    uint256 public constant LIQUIDATION_PENALTY_BPS = 500; // 5%
    uint256 public constant MIN_MAINT_MARGIN_BPS = 500; // 5%

    struct CollateralConfig {
        bool supported;
        uint256 decimals;
        uint256 price; // USD per whole token, scaled by 1e18
        uint256 depositCap;
    }

    struct MarketConfig {
        bool active;
        uint256 markPrice; // USD per base unit, scaled by 1e18
        uint256 maxLeverage; // scaled by 1e18
        int256 fundingRatePerSecond; // scaled by 1e18
    }

    struct Position {
        address trader;
        bytes32 market;
        address collateralToken;
        bool isLong;
        uint256 size; // base units scaled by 1e18
        uint256 margin; // collateral token amount
        uint256 entryPrice;
        uint256 lastFundingTime;
    }

    mapping(address => CollateralConfig) public collateralConfigs;
    mapping(bytes32 => MarketConfig) public marketConfigs;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256)) public reserved;
    mapping(address => mapping(bytes32 => Position)) public positions;
    mapping(address => uint256) public totalDeposits;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event PositionOpened(
        address indexed user,
        bytes32 indexed market,
        address indexed collateralToken,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 entryPrice
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed market,
        int256 pnl,
        uint256 fee,
        uint256 returnedAmount
    );
    event MarginAdjusted(address indexed user, bytes32 indexed market, int256 marginDelta, uint256 newMargin);
    event Liquidated(
        address indexed user,
        bytes32 indexed market,
        address indexed liquidator,
        int256 pnl,
        uint256 seizedMargin,
        uint256 penalty
    );
    event CollateralConfigured(address indexed token, bool supported, uint256 decimals, uint256 price, uint256 depositCap);
    event CollateralPriceUpdated(address indexed token, uint256 price);
    event MarketConfigured(
        bytes32 indexed market,
        uint256 markPrice,
        uint256 maxLeverage,
        int256 fundingRatePerSecond
    );
    event MarketActiveUpdated(bytes32 indexed market, bool active);
    event MarkPriceUpdated(bytes32 indexed market, uint256 price);
    event MaxLeverageUpdated(bytes32 indexed market, uint256 maxLeverage);
    event FundingRateUpdated(bytes32 indexed market, int256 fundingRatePerSecond);
    event OperatorFeesClaimed(address indexed token, address indexed to, uint256 amount);
    event TradingPaused(bool paused);

    error ErrZeroAddress();
    error ErrZeroAmount();
    error ErrUnsupportedCollateral();
    error ErrMarketInactive();
    error ErrInvalidMarket();
    error ErrInvalidPrice();
    error ErrInvalidLeverage();
    error ErrInvalidDecimals();
    error ErrExceedsMaxLeverage();
    error ErrInsufficientBalance();
    error ErrInsufficientFreeCollateral();
    error ErrPositionNotFound();
    error ErrNotPositionOwner();
    error ErrPositionAlreadyOpen();
    error ErrNotLiquidatable();
    error ErrWouldBeLiquidatable();
    error ErrCapExceeded();
    error ErrUndercollateralized();

    constructor(address admin, address operator) {
        if (admin == address(0)) revert ErrZeroAddress();
        if (operator == address(0)) revert ErrZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, operator);
    }

    modifier onlySupported(address token) {
        if (!collateralConfigs[token].supported) revert ErrUnsupportedCollateral();
        _;
    }

    modifier onlyActiveMarket(bytes32 market) {
        if (!marketConfigs[market].active) revert ErrMarketInactive();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function deposit(address token, uint256 amount) external nonReentrant onlySupported(token) {
        if (amount == 0) revert ErrZeroAmount();
        uint256 cap = collateralConfigs[token].depositCap;
        if (cap > 0 && totalDeposits[token] + amount > cap) revert ErrCapExceeded();

        // Effects before interactions
        balances[msg.sender][token] += amount;
        totalDeposits[token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant onlySupported(token) {
        if (amount == 0) revert ErrZeroAmount();
        uint256 free = _freeCollateral(msg.sender, token);
        if (free < amount) revert ErrInsufficientFreeCollateral();

        // Effects before interactions
        balances[msg.sender][token] -= amount;
        totalDeposits[token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    function getFreeCollateral(address trader, address token) external view returns (uint256) {
        return _freeCollateral(trader, token);
    }

    /*//////////////////////////////////////////////////////////////
                        POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function openPosition(
        bytes32 market,
        bool isLong,
        uint256 size,
        uint256 margin,
        address collateralToken
    ) external whenNotPaused nonReentrant onlyActiveMarket(market) onlySupported(collateralToken) {
        if (size == 0 || margin == 0) revert ErrZeroAmount();
        if (positions[msg.sender][market].size != 0) revert ErrPositionAlreadyOpen();

        MarketConfig storage mc = marketConfigs[market];
        uint256 marginUsd = _tokenToUsd(collateralToken, margin);
        if (marginUsd == 0) revert ErrInvalidPrice();

        // Full-precision notional (size * markPrice) avoids divide-before-multiply.
        // notionalUsd = (size * markPrice) / WAD; notionalUsd * WAD == size * markPrice.
        uint256 notionalRaw = size * mc.markPrice;

        // Leverage check using full precision: notionalRaw > maxLeverage * marginUsd
        if (notionalRaw > (mc.maxLeverage * marginUsd)) revert ErrExceedsMaxLeverage();

        // Fee computed without intermediate division: feeUsd = (size * markPrice * TRADING_FEE_BPS) / (WAD * BPS_DENOM)
        uint256 feeUsd = (notionalRaw * TRADING_FEE_BPS) / (WAD * BPS_DENOM);
        uint256 feeToken = _usdToToken(collateralToken, feeUsd);

        if (_freeCollateral(msg.sender, collateralToken) < margin + feeToken) {
            revert ErrInsufficientFreeCollateral();
        }

        // Effects before interactions
        balances[msg.sender][collateralToken] -= (margin + feeToken);
        reserved[msg.sender][collateralToken] += margin;

        Position storage pos = positions[msg.sender][market];
        pos.trader = msg.sender;
        pos.market = market;
        pos.collateralToken = collateralToken;
        pos.isLong = isLong;
        pos.size = size;
        pos.margin = margin;
        pos.entryPrice = mc.markPrice;
        pos.lastFundingTime = block.timestamp;

        emit PositionOpened(msg.sender, market, collateralToken, isLong, size, margin, mc.markPrice);
    }

    function closePosition(bytes32 market) external whenNotPaused nonReentrant onlyActiveMarket(market) {
        Position storage pos = positions[msg.sender][market];
        if (pos.size == 0) revert ErrPositionNotFound();
        if (pos.trader != msg.sender) revert ErrNotPositionOwner();

        (int256 pnl, uint256 fee, uint256 returned) = _settlePosition(pos);
        address collateralToken = pos.collateralToken;
        uint256 margin = pos.margin;

        // Effects before interactions
        reserved[msg.sender][collateralToken] -= margin;
        if (returned > 0) {
            balances[msg.sender][collateralToken] += returned;
        }
        delete positions[msg.sender][market];

        emit PositionClosed(msg.sender, market, pnl, fee, returned);
    }

    function adjustMargin(bytes32 market, int256 marginDelta) external whenNotPaused nonReentrant onlyActiveMarket(market) {
        Position storage pos = positions[msg.sender][market];
        if (pos.size == 0) revert ErrPositionNotFound();
        if (pos.trader != msg.sender) revert ErrNotPositionOwner();
        if (marginDelta == 0) revert ErrZeroAmount();

        address token = pos.collateralToken;

        if (marginDelta > 0) {
            uint256 addAmount = uint256(marginDelta);
            if (_freeCollateral(msg.sender, token) < addAmount) revert ErrInsufficientFreeCollateral();
            balances[msg.sender][token] -= addAmount;
            reserved[msg.sender][token] += addAmount;
            pos.margin += addAmount;
        } else {
            uint256 removeAmount = uint256(-marginDelta);
            if (removeAmount >= pos.margin) revert ErrInsufficientBalance();
            uint256 newMargin = pos.margin - removeAmount;

            uint256 notionalRaw = pos.size * marketConfigs[market].markPrice;
            uint256 newMarginUsd = _tokenToUsd(token, newMargin);
            if (notionalRaw > (marketConfigs[market].maxLeverage * newMarginUsd)) {
                revert ErrExceedsMaxLeverage();
            }

            if (_isUndercollateralized(token, newMarginUsd, notionalRaw, pos)) {
                revert ErrWouldBeLiquidatable();
            }

            pos.margin = newMargin;
            reserved[msg.sender][token] -= removeAmount;
            balances[msg.sender][token] += removeAmount;
        }

        emit MarginAdjusted(msg.sender, market, marginDelta, pos.margin);
    }

    function liquidate(address trader, bytes32 market) external whenNotPaused nonReentrant onlyActiveMarket(market) {
        Position storage pos = positions[trader][market];
        if (pos.size == 0) revert ErrPositionNotFound();

        (int256 pnlUsd, uint256 marginUsd, uint256 notional) = _positionMetrics(pos);
        int256 equity = int256(marginUsd) + pnlUsd;
        uint256 maintenance = (notional * MIN_MAINT_MARGIN_BPS) / BPS_DENOM;
        if (equity >= int256(maintenance)) revert ErrNotLiquidatable();

        uint256 penalty = (pos.margin * LIQUIDATION_PENALTY_BPS) / BPS_DENOM;
        address collateralToken = pos.collateralToken;
        uint256 margin = pos.margin;

        // Effects before interactions
        reserved[trader][collateralToken] -= margin;

        uint256 returnedToTrader;
        if (margin > penalty) {
            returnedToTrader = margin - penalty;
            balances[trader][collateralToken] += returnedToTrader;
        }

        delete positions[trader][market];

        // Interaction
        if (penalty > 0) {
            IERC20(collateralToken).safeTransfer(msg.sender, penalty);
        }

        emit Liquidated(trader, market, msg.sender, pnlUsd, margin, penalty);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function configureCollateral(
        address token,
        bool supported,
        uint256 decimals,
        uint256 price,
        uint256 depositCap
    ) external onlyRole(OPERATOR_ROLE) {
        if (token == address(0)) revert ErrZeroAddress();
        if (decimals > 36) revert ErrInvalidDecimals();
        if (supported && price == 0) revert ErrInvalidPrice();

        collateralConfigs[token] = CollateralConfig({
            supported: supported,
            decimals: decimals,
            price: price,
            depositCap: depositCap
        });

        emit CollateralConfigured(token, supported, decimals, price, depositCap);
    }

    function setCollateralPrice(address token, uint256 price) external onlyRole(OPERATOR_ROLE) {
        if (!collateralConfigs[token].supported) revert ErrUnsupportedCollateral();
        if (price == 0) revert ErrInvalidPrice();
        collateralConfigs[token].price = price;
        emit CollateralPriceUpdated(token, price);
    }

    function configureMarket(
        bytes32 market,
        uint256 markPrice,
        uint256 maxLeverage,
        int256 fundingRatePerSecond
    ) external onlyRole(OPERATOR_ROLE) {
        if (market == bytes32(0)) revert ErrInvalidMarket();
        if (markPrice == 0) revert ErrInvalidPrice();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE_CAP) revert ErrInvalidLeverage();

        marketConfigs[market] = MarketConfig({
            active: true,
            markPrice: markPrice,
            maxLeverage: maxLeverage,
            fundingRatePerSecond: fundingRatePerSecond
        });

        emit MarketConfigured(market, markPrice, maxLeverage, fundingRatePerSecond);
    }

    function setMarketActive(bytes32 market, bool active) external onlyRole(OPERATOR_ROLE) {
        if (marketConfigs[market].markPrice == 0) revert ErrInvalidMarket();
        marketConfigs[market].active = active;
        emit MarketActiveUpdated(market, active);
    }

    function setMarkPrice(bytes32 market, uint256 price) external onlyRole(OPERATOR_ROLE) {
        if (!marketConfigs[market].active) revert ErrMarketInactive();
        if (price == 0) revert ErrInvalidPrice();
        marketConfigs[market].markPrice = price;
        emit MarkPriceUpdated(market, price);
    }

    function setMaxLeverage(bytes32 market, uint256 maxLeverage) external onlyRole(OPERATOR_ROLE) {
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE_CAP) revert ErrInvalidLeverage();
        marketConfigs[market].maxLeverage = maxLeverage;
        emit MaxLeverageUpdated(market, maxLeverage);
    }

    function setFundingRate(bytes32 market, int256 fundingRatePerSecond) external onlyRole(OPERATOR_ROLE) {
        if (!marketConfigs[market].active) revert ErrMarketInactive();
        marketConfigs[market].fundingRatePerSecond = fundingRatePerSecond;
        emit FundingRateUpdated(market, fundingRatePerSecond);
    }

    function setTradingPaused(bool tradePaused) external onlyRole(OPERATOR_ROLE) {
        if (tradePaused) {
            _pause();
        } else {
            _unpause();
        }
        emit TradingPaused(tradePaused);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function getNotional(bytes32 market, uint256 size) public view returns (uint256) {
        return _notional(market, size);
    }

    function getUnrealizedPnl(address trader, bytes32 market) public view returns (int256) {
        Position storage pos = positions[trader][market];
        if (pos.size == 0) return 0;
        return _pnlUsd(pos);
    }

    function isLiquidatable(address trader, bytes32 market) public view returns (bool) {
        Position storage pos = positions[trader][market];
        if (pos.size == 0) return false;
        (int256 pnlUsd, uint256 marginUsd, uint256 notional) = _positionMetrics(pos);
        int256 equity = int256(marginUsd) + pnlUsd;
        uint256 maintenance = (notional * MIN_MAINT_MARGIN_BPS) / BPS_DENOM;
        return equity < int256(maintenance);
    }

    function getCurrentLeverage(address trader, bytes32 market) public view returns (uint256) {
        Position storage pos = positions[trader][market];
        if (pos.size == 0) return 0;
        (int256 pnlUsd, uint256 marginUsd, uint256 notional) = _positionMetrics(pos);
        int256 equity = int256(marginUsd) + pnlUsd;
        if (equity <= 0) return type(uint256).max;
        return (notional * WAD) / uint256(equity);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _freeCollateral(address trader, address token) internal view returns (uint256) {
        return balances[trader][token] - reserved[trader][token];
    }

    function _notional(bytes32 market, uint256 size) internal view returns (uint256) {
        return (size * marketConfigs[market].markPrice) / WAD;
    }

    function _tokenToUsd(address token, uint256 amount) internal view returns (uint256) {
        CollateralConfig storage c = collateralConfigs[token];
        uint256 wadAmount = _toWad(amount, c.decimals);
        return (wadAmount * c.price) / WAD;
    }

    function _usdToToken(address token, uint256 usd) internal view returns (uint256) {
        CollateralConfig storage c = collateralConfigs[token];
        if (c.price == 0) return 0;
        uint256 wadAmount = (usd * WAD) / c.price;
        return _fromWad(wadAmount, c.decimals);
    }

    function _pnlUsd(Position storage pos) internal view returns (int256) {
        MarketConfig storage mc = marketConfigs[pos.market];
        uint256 mark = mc.markPrice;
        if (pos.entryPrice == 0) return 0;

        int256 priceDiff;
        if (pos.isLong) {
            priceDiff = int256(mark) - int256(pos.entryPrice);
        } else {
            priceDiff = int256(pos.entryPrice) - int256(mark);
        }
        return (int256(pos.size) * priceDiff) / int256(WAD);
    }

    function _positionMetrics(Position storage pos)
        internal
        view
        returns (int256 pnlUsd, uint256 marginUsd, uint256 notional)
    {
        pnlUsd = _pnlUsd(pos);
        marginUsd = _tokenToUsd(pos.collateralToken, pos.margin);
        notional = _notional(pos.market, pos.size);
    }

    function _isUndercollateralized(
        address,
        uint256 marginUsd,
        uint256 notionalRaw,
        Position storage pos
    ) internal view returns (bool) {
        int256 pnl = _pnlUsd(pos);
        int256 equity = int256(marginUsd) + pnl;
        // notionalRaw = size * markPrice; maintenanceUsd = notionalRaw / WAD * MIN_MAINT_MARGIN_BPS / BPS_DENOM
        // Compute without divide-before-multiply: maintenanceRaw = notionalRaw * MIN_MAINT_MARGIN_BPS / (WAD * BPS_DENOM)
        uint256 maintenanceRaw = (notionalRaw * MIN_MAINT_MARGIN_BPS) / (WAD * BPS_DENOM);
        return equity < int256(maintenanceRaw);
    }

    function _settlePosition(Position storage pos)
        internal
        view
        returns (int256 pnl, uint256 fee, uint256 returned)
    {
        pnl = _pnlUsd(pos);
        uint256 notionalRaw = pos.size * marketConfigs[pos.market].markPrice;
        // Avoid divide-before-multiply: feeUsd = (size * markPrice * TRADING_FEE_BPS) / (WAD * BPS_DENOM)
        uint256 feeUsd = (notionalRaw * TRADING_FEE_BPS) / (WAD * BPS_DENOM);
        fee = _usdToToken(pos.collateralToken, feeUsd);

        uint256 marginUsd = _tokenToUsd(pos.collateralToken, pos.margin);
        int256 net = int256(marginUsd) + pnl - int256(feeUsd);
        if (net <= 0) {
            returned = 0;
        } else {
            returned = _usdToToken(pos.collateralToken, uint256(net));
            if (returned > pos.margin) {
                returned = pos.margin;
            }
        }
    }

    function _toWad(uint256 amount, uint256 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * (10 ** (18 - decimals));
        return amount / (10 ** (decimals - 18));
    }

    function _fromWad(uint256 amount, uint256 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount / (10 ** (18 - decimals));
        return amount * (10 ** (decimals - 18));
    }
}
