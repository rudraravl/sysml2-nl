// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPriceOracleFeed {
    function getPrice() external view returns (uint256);
}

interface IRouterLike {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract PerpetualExchange {
    // -------------------------------------------------------------------------
    // Reentrancy Guard (inlined)
    // -------------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error Paused();
    error InvalidPrice();
    error InvalidAmount();
    error PositionNotActive();
    error NotLiquidatable();
    error InsufficientLiquidity();
    error OrderNotActive();
    error OrderNotExecutable();
    error NotOrderOwner();
    error NotPositionOwner();
    error MaxLeverageExceeded();
    error TokenNotSupported();
    error MarketNotSupported();
    error InvalidAddress();
    error TransferFailed();

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_GLOBAL_LEVERAGE = 50;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MaintenanceMarginBpsUpdated(uint256 oldBps, uint256 newBps);
    event LiquidationFeeBpsUpdated(uint256 oldBps, uint256 newBps);
    event CollateralTokenAdded(address indexed token, address oracle, uint256 maxLeverage);
    event CollateralTokenUpdated(address indexed token, bool isActive, address oracle, uint256 maxLeverage);
    event MarketAdded(bytes32 indexed marketId, address oracle, uint256 maxLeverage);
    event MarketUpdated(bytes32 indexed marketId, bool isActive, address oracle, uint256 maxLeverage);
    event RouterUpdated(address indexed oldRouter, address indexed newRouter);
    event PausedEvent(address indexed operator);
    event UnpausedEvent(address indexed operator);

    event PositionOpened(
        uint256 indexed positionId,
        address indexed user,
        bytes32 indexed marketId,
        bool isLong,
        address collateralToken,
        uint256 marginAmount,
        uint256 sizeBase,
        uint256 entryPrice,
        uint256 leverage
    );
    event PositionClosed(uint256 indexed positionId, address indexed user, int256 pnlCollateral, uint256 returnedCollateral);
    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        address indexed user,
        address collateralToken,
        uint256 liquidatorReward,
        int256 poolPnl
    );
    event CollateralAdjusted(uint256 indexed positionId, address indexed user, uint256 amount, bool isAdd);
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed user,
        bytes32 indexed marketId,
        bool isLong,
        address collateralToken,
        uint256 marginAmount,
        uint256 price,
        uint256 leverage,
        uint256 sizeBase
    );
    event OrderExecuted(uint256 indexed orderId, uint256 indexed positionId);
    event OrderCancelled(uint256 indexed orderId);
    event DepositLiquidity(address indexed user, address indexed token, uint256 amount, uint256 lpAmount);
    event WithdrawLiquidity(address indexed user, address indexed token, uint256 lpAmount, uint256 amount);
    event SwapExecuted(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------
    struct Position {
        bool isActive;
        address user;
        bytes32 marketId;
        address collateralToken;
        uint256 marginAmount;
        uint256 sizeBase;
        uint256 entryPrice;
        uint256 leverage;
        bool isLong;
    }

    struct Order {
        bool isActive;
        address user;
        bytes32 marketId;
        address collateralToken;
        uint256 marginAmount;
        uint256 price;
        uint256 leverage;
        bool isLong;
        uint256 sizeBase;
    }

    struct CollateralConfig {
        bool isActive;
        IPriceOracleFeed oracle;
        uint256 maxLeverage;
    }

    struct MarketConfig {
        bool isActive;
        IPriceOracleFeed oracle;
        uint256 maxLeverage;
    }

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------
    address public owner;
    address public operator;
    address public governanceToken;
    bool public paused;

    uint256 public feeBps;
    uint256 public maintenanceMarginBps;
    uint256 public liquidationFeeBps;

    IRouterLike public router;

    mapping(address => bool) public isTokenSupported;
    address[] public supportedTokenList;
    mapping(address => CollateralConfig) public collateralConfigs;

    mapping(bytes32 => bool) public isMarketSupported;
    bytes32[] public supportedMarketList;
    mapping(bytes32 => MarketConfig) public marketConfigs;

    uint256 public nextPositionId;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionList;

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrderList;

    mapping(address => uint256) public poolBalance;
    mapping(address => uint256) public totalLpSupply;
    mapping(address => mapping(address => uint256)) public lpBalances;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(address _owner, address _operator, address _governanceToken) {
        if (_owner == address(0) || _operator == address(0) || _governanceToken == address(0)) revert InvalidAddress();
        _status = _NOT_ENTERED;
        owner = _owner;
        operator = _operator;
        governanceToken = _governanceToken;
        feeBps = 10;
        maintenanceMarginBps = 50;
        liquidationFeeBps = 100;
        emit OperatorUpdated(address(0), _operator);
    }

    // -------------------------------------------------------------------------
    // Internal Helpers
    // -------------------------------------------------------------------------
    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool success = IERC20Minimal(token).transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool success = IERC20Minimal(token).transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _removeFromList(uint256[] storage list, uint256 value) internal {
        uint256 len = list.length;
        for (uint256 i = 0; i < len; i++) {
            if (list[i] == value) {
                if (i != len - 1) {
                    list[i] = list[len - 1];
                }
                list.pop();
                return;
            }
        }
    }

    function _getPrices(
        bytes32 marketId,
        address collateralToken
    ) internal view returns (uint256 basePrice, uint256 collateralPrice) {
        MarketConfig memory mc = marketConfigs[marketId];
        if (!mc.isActive) revert MarketNotSupported();
        CollateralConfig memory cc = collateralConfigs[collateralToken];
        if (!cc.isActive) revert TokenNotSupported();

        basePrice = mc.oracle.getPrice();
        collateralPrice = cc.oracle.getPrice();
        if (basePrice == 0 || collateralPrice == 0) revert InvalidPrice();
    }

    function _computeSizeBase(
        uint256 marginAmount,
        uint256 leverage,
        uint256 basePrice,
        uint256 collateralPrice
    ) internal pure returns (uint256 sizeBase) {
        uint256 usdMargin = (marginAmount * collateralPrice) / PRECISION;
        uint256 usdNotional = usdMargin * leverage;
        sizeBase = (usdNotional * PRECISION) / basePrice;
    }

    function _computePnlCollateral(
        Position memory pos,
        uint256 basePrice,
        uint256 collateralPrice
    ) internal pure returns (int256 pnlCollateral) {
        int256 pnlUsd;
        if (pos.isLong) {
            pnlUsd = int256(basePrice) - int256(pos.entryPrice);
        } else {
            pnlUsd = int256(pos.entryPrice) - int256(basePrice);
        }
        pnlUsd = (pnlUsd * int256(pos.sizeBase)) / int256(PRECISION);
        pnlCollateral = (pnlUsd * int256(PRECISION)) / int256(collateralPrice);
    }

    function _applyFee(
        uint256 usdNotional,
        uint256 collateralPrice
    ) internal view returns (uint256 feeCollateral) {
        uint256 feeUsd = (usdNotional * feeBps) / BPS_DENOMINATOR;
        feeCollateral = (feeUsd * PRECISION) / collateralPrice;
    }

    // -------------------------------------------------------------------------
    // Admin Functions
    // -------------------------------------------------------------------------
    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert InvalidAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function setFeeBps(uint256 _feeBps) external onlyOperator {
        if (_feeBps > BPS_DENOMINATOR) revert InvalidAmount();
        emit FeeBpsUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function setMaintenanceMarginBps(uint256 _bps) external onlyOperator {
        if (_bps > BPS_DENOMINATOR) revert InvalidAmount();
        emit MaintenanceMarginBpsUpdated(maintenanceMarginBps, _bps);
        maintenanceMarginBps = _bps;
    }

    function setLiquidationFeeBps(uint256 _bps) external onlyOperator {
        if (_bps > BPS_DENOMINATOR) revert InvalidAmount();
        emit LiquidationFeeBpsUpdated(liquidationFeeBps, _bps);
        liquidationFeeBps = _bps;
    }

    function addCollateralToken(
        address token,
        address oracle,
        uint256 maxLeverage
    ) external onlyOperator {
        if (token == address(0) || oracle == address(0)) revert InvalidAddress();
        if (maxLeverage == 0 || maxLeverage > MAX_GLOBAL_LEVERAGE) revert MaxLeverageExceeded();
        if (isTokenSupported[token]) revert TokenNotSupported();
        isTokenSupported[token] = true;
        supportedTokenList.push(token);
        collateralConfigs[token] = CollateralConfig({
            isActive: true,
            oracle: IPriceOracleFeed(oracle),
            maxLeverage: maxLeverage
        });
        emit CollateralTokenAdded(token, oracle, maxLeverage);
    }

    function updateCollateralToken(
        address token,
        bool isActive,
        address oracle,
        uint256 maxLeverage
    ) external onlyOperator {
        if (!isTokenSupported[token]) revert TokenNotSupported();
        if (oracle == address(0)) revert InvalidAddress();
        if (maxLeverage == 0 || maxLeverage > MAX_GLOBAL_LEVERAGE) revert MaxLeverageExceeded();
        collateralConfigs[token] = CollateralConfig({
            isActive: isActive,
            oracle: IPriceOracleFeed(oracle),
            maxLeverage: maxLeverage
        });
        emit CollateralTokenUpdated(token, isActive, oracle, maxLeverage);
    }

    function addMarket(
        bytes32 marketId,
        address oracle,
        uint256 maxLeverage
    ) external onlyOperator {
        if (oracle == address(0)) revert InvalidAddress();
        if (maxLeverage == 0 || maxLeverage > MAX_GLOBAL_LEVERAGE) revert MaxLeverageExceeded();
        if (isMarketSupported[marketId]) revert MarketNotSupported();
        isMarketSupported[marketId] = true;
        supportedMarketList.push(marketId);
        marketConfigs[marketId] = MarketConfig({
            isActive: true,
            oracle: IPriceOracleFeed(oracle),
            maxLeverage: maxLeverage
        });
        emit MarketAdded(marketId, oracle, maxLeverage);
    }

    function updateMarket(
        bytes32 marketId,
        bool isActive,
        address oracle,
        uint256 maxLeverage
    ) external onlyOperator {
        if (!isMarketSupported[marketId]) revert MarketNotSupported();
        if (oracle == address(0)) revert InvalidAddress();
        if (maxLeverage == 0 || maxLeverage > MAX_GLOBAL_LEVERAGE) revert MaxLeverageExceeded();
        marketConfigs[marketId] = MarketConfig({
            isActive: isActive,
            oracle: IPriceOracleFeed(oracle),
            maxLeverage: maxLeverage
        });
        emit MarketUpdated(marketId, isActive, oracle, maxLeverage);
    }

    function setRouter(address _router) external onlyOperator {
        if (_router == address(0)) revert InvalidAddress();
        emit RouterUpdated(address(router), _router);
        router = IRouterLike(_router);
    }

    function pause(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit PausedEvent(msg.sender);
        } else {
            emit UnpausedEvent(msg.sender);
        }
    }

    // -------------------------------------------------------------------------
    // Liquidity Pool
    // -------------------------------------------------------------------------
    function depositLP(address token, uint256 amount) external nonReentrant whenNotPaused {
        if (!isTokenSupported[token]) revert TokenNotSupported();
        if (amount == 0) revert InvalidAmount();

        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 lpAmount = amount;
        if (totalLpSupply[token] > 0 && poolBalance[token] > 0) {
            lpAmount = (amount * totalLpSupply[token]) / poolBalance[token];
        }
        totalLpSupply[token] += lpAmount;
        poolBalance[token] += amount;
        lpBalances[msg.sender][token] += lpAmount;

        emit DepositLiquidity(msg.sender, token, amount, lpAmount);
    }

    function withdrawLP(address token, uint256 lpAmount) external nonReentrant {
        if (lpAmount == 0) revert InvalidAmount();
        if (lpBalances[msg.sender][token] < lpAmount) revert InvalidAmount();
        if (totalLpSupply[token] == 0) revert InvalidAmount();

        uint256 balance = poolBalance[token];
        uint256 amount = (lpAmount * balance) / totalLpSupply[token];

        lpBalances[msg.sender][token] -= lpAmount;
        totalLpSupply[token] -= lpAmount;
        poolBalance[token] -= amount;

        _safeTransfer(token, msg.sender, amount);
        emit WithdrawLiquidity(msg.sender, token, lpAmount, amount);
    }

    // -------------------------------------------------------------------------
    // Positions
    // -------------------------------------------------------------------------
    function openPosition(
        bytes32 marketId,
        bool isLong,
        address collateralToken,
        uint256 marginAmount,
        uint256 leverage
    ) external nonReentrant whenNotPaused returns (uint256 positionId) {
        if (marginAmount == 0) revert InvalidAmount();
        if (leverage == 0 || leverage > MAX_GLOBAL_LEVERAGE) revert MaxLeverageExceeded();

        CollateralConfig memory cc = collateralConfigs[collateralToken];
        MarketConfig memory mc = marketConfigs[marketId];
        if (!cc.isActive || !mc.isActive) revert TokenNotSupported();
        if (leverage > cc.maxLeverage || leverage > mc.maxLeverage) revert MaxLeverageExceeded();

        (uint256 basePrice, uint256 collateralPrice) = _getPrices(marketId, collateralToken);

        uint256 sizeBase = _computeSizeBase(marginAmount, leverage, basePrice, collateralPrice);
        uint256 usdNotional = (sizeBase * basePrice) / PRECISION;
        uint256 feeCollateral = _applyFee(usdNotional, collateralPrice);

        if (marginAmount <= feeCollateral) revert InvalidAmount();

        uint256 actualMargin = marginAmount - feeCollateral;

        _safeTransferFrom(collateralToken, msg.sender, address(this), marginAmount);
        poolBalance[collateralToken] += feeCollateral;

        positionId = nextPositionId++;
        positions[positionId] = Position({
            isActive: true,
            user: msg.sender,
            marketId: marketId,
            collateralToken: collateralToken,
            marginAmount: actualMargin,
            sizeBase: sizeBase,
            entryPrice: basePrice,
            leverage: leverage,
            isLong: isLong
        });
        userPositionList[msg.sender].push(positionId);

        emit PositionOpened(positionId, msg.sender, marketId, isLong, collateralToken, actualMargin, sizeBase, basePrice, leverage);
    }

    function closePosition(uint256 positionId) external nonReentrant whenNotPaused {
        Position storage pos = positions[positionId];
        if (!pos.isActive) revert PositionNotActive();
        if (pos.user != msg.sender) revert NotPositionOwner();

        (uint256 basePrice, uint256 collateralPrice) = _getPrices(pos.marketId, pos.collateralToken);
        int256 pnlCollateral = _computePnlCollateral(pos, basePrice, collateralPrice);

        int256 netCollateral = int256(pos.marginAmount) + pnlCollateral;

        uint256 returnAmount = 0;
        if (netCollateral > 0) {
            returnAmount = uint256(netCollateral);
        }

        if (pnlCollateral > 0) {
            uint256 pnlAbs = uint256(pnlCollateral);
            if (poolBalance[pos.collateralToken] < pnlAbs) revert InsufficientLiquidity();
            poolBalance[pos.collateralToken] -= pnlAbs;
        } else if (pnlCollateral < 0) {
            uint256 lossAbs = uint256(-pnlCollateral);
            poolBalance[pos.collateralToken] += lossAbs;
        }

        if (returnAmount > 0) {
            _safeTransfer(pos.collateralToken, msg.sender, returnAmount);
        }

        pos.isActive = false;
        _removeFromList(userPositionList[msg.sender], positionId);

        emit PositionClosed(positionId, msg.sender, pnlCollateral, returnAmount);
    }

    function addCollateral(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        Position storage pos = positions[positionId];
        if (!pos.isActive) revert PositionNotActive();
        if (pos.user != msg.sender) revert NotPositionOwner();

        _safeTransferFrom(pos.collateralToken, msg.sender, address(this), amount);
        pos.marginAmount += amount;
        emit CollateralAdjusted(positionId, msg.sender, amount, true);
    }

    function removeCollateral(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused {
        Position storage pos = positions[positionId];
        if (!pos.isActive) revert PositionNotActive();
        if (pos.user != msg.sender) revert NotPositionOwner();
        if (amount == 0 || amount > pos.marginAmount) revert InvalidAmount();

        (uint256 basePrice, uint256 collateralPrice) = _getPrices(pos.marketId, pos.collateralToken);
        int256 pnlCollateral = _computePnlCollateral(pos, basePrice, collateralPrice);

        uint256 newMargin = pos.marginAmount - amount;
        int256 newNetCollateral = int256(newMargin) + pnlCollateral;
        uint256 usdNotional = (pos.sizeBase * basePrice) / PRECISION;
        uint256 minEquityUsd = (usdNotional * maintenanceMarginBps) / BPS_DENOMINATOR;
        uint256 minEquityCollateral = (minEquityUsd * PRECISION) / collateralPrice;

        if (newNetCollateral <= 0) revert InvalidAmount();
        if (uint256(newNetCollateral) < minEquityCollateral) revert InvalidAmount();

        pos.marginAmount = newMargin;
        _safeTransfer(pos.collateralToken, msg.sender, amount);
        emit CollateralAdjusted(positionId, msg.sender, amount, false);
    }

    // -------------------------------------------------------------------------
    // Limit Orders
    // -------------------------------------------------------------------------
    function placeLimitOrder(
        bytes32 marketId,
        bool isLong,
        address collateralToken,
        uint256 marginAmount,
        uint256 leverage,
        uint256 price
    ) external nonReentrant whenNotPaused returns (uint256 orderId) {
        if (marginAmount == 0 || price == 0) revert InvalidAmount();
        if (leverage == 0 || leverage > MAX_GLOBAL_LEVERAGE) revert MaxLeverageExceeded();

        CollateralConfig memory cc = collateralConfigs[collateralToken];
        MarketConfig memory mc = marketConfigs[marketId];
        if (!cc.isActive || !mc.isActive) revert TokenNotSupported();
        if (leverage > cc.maxLeverage || leverage > mc.maxLeverage) revert MaxLeverageExceeded();

        (, uint256 collateralPrice) = _getPrices(marketId, collateralToken);
        uint256 sizeBase = _computeSizeBase(marginAmount, leverage, price, collateralPrice);

        _safeTransferFrom(collateralToken, msg.sender, address(this), marginAmount);

        orderId = nextOrderId++;
        orders[orderId] = Order({
            isActive: true,
            user: msg.sender,
            marketId: marketId,
            collateralToken: collateralToken,
            marginAmount: marginAmount,
            price: price,
            leverage: leverage,
            isLong: isLong,
            sizeBase: sizeBase
        });
        userOrderList[msg.sender].push(orderId);

        emit OrderPlaced(orderId, msg.sender, marketId, isLong, collateralToken, marginAmount, price, leverage, sizeBase);
    }

    function executeOrder(uint256 orderId) external nonReentrant whenNotPaused {
        Order storage order = orders[orderId];
        if (!order.isActive) revert OrderNotActive();

        (uint256 basePrice, uint256 collateralPrice) = _getPrices(order.marketId, order.collateralToken);
        if (order.isLong) {
            if (basePrice < order.price) revert OrderNotExecutable();
        } else {
            if (basePrice > order.price) revert OrderNotExecutable();
        }

        uint256 usdNotional = (order.sizeBase * order.price) / PRECISION;
        uint256 feeCollateral = _applyFee(usdNotional, collateralPrice);
        if (order.marginAmount <= feeCollateral) revert InvalidAmount();

        uint256 actualMargin = order.marginAmount - feeCollateral;
        poolBalance[order.collateralToken] += feeCollateral;

        uint256 positionId = nextPositionId++;
        positions[positionId] = Position({
            isActive: true,
            user: order.user,
            marketId: order.marketId,
            collateralToken: order.collateralToken,
            marginAmount: actualMargin,
            sizeBase: order.sizeBase,
            entryPrice: order.price,
            leverage: order.leverage,
            isLong: order.isLong
        });
        userPositionList[order.user].push(positionId);

        order.isActive = false;
        _removeFromList(userOrderList[order.user], orderId);

        emit OrderExecuted(orderId, positionId);
        emit PositionOpened(positionId, order.user, order.marketId, order.isLong, order.collateralToken, actualMargin, order.sizeBase, order.price, order.leverage);
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        if (!order.isActive) revert OrderNotActive();
        if (order.user != msg.sender) revert NotOrderOwner();

        _safeTransfer(order.collateralToken, msg.sender, order.marginAmount);

        order.isActive = false;
        _removeFromList(userOrderList[msg.sender], orderId);

        emit OrderCancelled(orderId);
    }

    // -------------------------------------------------------------------------
    // Swap
    // -------------------------------------------------------------------------
    function swap(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        if (tokenIn == tokenOut) revert InvalidAmount();
        if (!isTokenSupported[tokenIn] || !isTokenSupported[tokenOut]) revert TokenNotSupported();
        if (address(router) == address(0)) revert InvalidAddress();
        if (amountIn == 0) revert InvalidAmount();

        _safeTransferFrom(tokenIn, msg.sender, address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp
        );

        amountOut = amounts[1];
        emit SwapExecuted(msg.sender, tokenIn, amountIn, tokenOut, amountOut);
    }

    // -------------------------------------------------------------------------
    // Liquidation
    // -------------------------------------------------------------------------
    function liquidate(uint256 positionId) external nonReentrant whenNotPaused {
        Position storage pos = positions[positionId];
        if (!pos.isActive) revert PositionNotActive();

        (uint256 basePrice, uint256 collateralPrice) = _getPrices(pos.marketId, pos.collateralToken);
        int256 pnlCollateral = _computePnlCollateral(pos, basePrice, collateralPrice);
        int256 netCollateral = int256(pos.marginAmount) + pnlCollateral;

        uint256 usdNotional = (pos.sizeBase * basePrice) / PRECISION;
        uint256 minEquityUsd = (usdNotional * maintenanceMarginBps) / BPS_DENOMINATOR;
        uint256 minEquityCollateral = (minEquityUsd * PRECISION) / collateralPrice;

        if (netCollateral >= int256(minEquityCollateral)) revert NotLiquidatable();

        uint256 rewardUsd = (usdNotional * liquidationFeeBps) / BPS_DENOMINATOR;
        uint256 rewardCollateral = (rewardUsd * PRECISION) / collateralPrice;

        int256 poolPnl;

        if (netCollateral > 0) {
            uint256 netAbs = uint256(netCollateral);
            if (netAbs <= rewardCollateral) {
                rewardCollateral = netAbs;
                poolPnl = -int256(pos.marginAmount);
            } else {
                uint256 remainingCollateral = netAbs - rewardCollateral;
                poolBalance[pos.collateralToken] += remainingCollateral;
                poolPnl = -int256(pos.marginAmount - remainingCollateral);
            }
        } else {
            uint256 loss = uint256(-netCollateral);
            if (poolBalance[pos.collateralToken] < loss + rewardCollateral) revert InsufficientLiquidity();
            poolBalance[pos.collateralToken] -= (loss + rewardCollateral);
            poolPnl = -int256(loss + pos.marginAmount);
        }

        if (rewardCollateral > 0) {
            _safeTransfer(pos.collateralToken, msg.sender, rewardCollateral);
        }

        pos.isActive = false;
        _removeFromList(userPositionList[pos.user], positionId);

        emit PositionLiquidated(positionId, msg.sender, pos.user, pos.collateralToken, rewardCollateral, poolPnl);
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositionList[user];
    }

    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrderList[user];
    }

    function isPositionActive(uint256 positionId) external view returns (bool) {
        return positions[positionId].isActive;
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokenList;
    }

    function getSupportedMarkets() external view returns (bytes32[] memory) {
        return supportedMarketList;
    }

    function getLpBalance(address user, address token) external view returns (uint256) {
        return lpBalances[user][token];
    }
}
