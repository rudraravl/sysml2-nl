// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IOracle {
    function getPrice(bytes32 pairId) external view returns (uint256 price);
}

contract PerpetualFuturesExchange {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error NotAuthorized();
    error TradingPaused();
    error InsufficientMargin();
    error PositionNotFound();
    error PositionAlreadyOpen();
    error LeverageExceeded();
    error InvalidSize();
    error NotLiquidatable();
    error InvalidPair();
    error InvalidParameter();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed account, uint256 amount, uint256 newBalance);
    event Withdraw(address indexed account, uint256 amount, uint256 newBalance);
    event PositionOpened(
        address indexed account,
        bytes32 indexed pairId,
        int256 size,
        uint256 entryPrice,
        uint256 collateral,
        uint256 leverage
    );
    event PositionModified(
        address indexed account,
        bytes32 indexed pairId,
        int256 sizeDelta,
        uint256 newEntryPrice,
        uint256 newCollateral
    );
    event PositionClosed(
        address indexed account,
        bytes32 indexed pairId,
        int256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 collateralReturned
    );
    event PositionLiquidated(
        address indexed account,
        bytes32 indexed pairId,
        address indexed liquidator,
        int256 size,
        uint256 liquidationPrice,
        uint256 liquidationFee,
        uint256 remainingCollateral
    );
    event FundingUpdated(bytes32 indexed pairId, uint256 cumulativeFunding, int256 ratePerSecond);
    event PairAdded(bytes32 indexed pairId, address oracle, uint256 maxLeverage);
    event ParameterUpdated(bytes32 indexed parameter, uint256 value);
    event TradingPausedChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_GLOBAL_LEVERAGE = 20e18;
    uint256 public constant LIQUIDATION_FEE_RATE = 50; // 0.5% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant FUNDING_PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;

    IERC20 public immutable collateralToken;

    bool public tradingPaused;

    uint256 public initialMarginRate; // e.g. 5e18 for 20x
    uint256 public liquidationThreshold; // e.g. 4e18
    uint256 public minCollateral;

    struct TradingPair {
        bytes32 id;
        IOracle oracle;
        uint256 maxLeverage;
        uint256 cumulativeFunding;
        int256 fundingRatePerSecond;
        uint256 lastFundingUpdate;
        bool exists;
    }

    mapping(bytes32 => TradingPair) public pairs;
    bytes32[] public pairList;

    struct Position {
        int256 size; // positive = long, negative = short
        uint256 entryPrice;
        uint256 collateral;
        uint256 lastFundingIndex;
        bool isOpen;
    }

    mapping(address => mapping(bytes32 => Position)) public positions;
    mapping(address => uint256) public balances;
    uint256 public totalCollateral;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier notPaused() {
        if (tradingPaused) revert TradingPaused();
        _;
    }

    modifier pairExists(bytes32 pairId) {
        if (!pairs[pairId].exists) revert InvalidPair();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _collateralToken, address _operator) {
        if (_collateralToken == address(0) || _operator == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        owner = msg.sender;
        operator = _operator;
        initialMarginRate = 5e18;
        liquidationThreshold = 4e18;
        minCollateral = 100e18;
        emit OperatorChanged(address(0), _operator);
        emit ParameterUpdated("initialMarginRate", initialMarginRate);
        emit ParameterUpdated("liquidationThreshold", liquidationThreshold);
        emit ParameterUpdated("minCollateral", minCollateral);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorChanged(old, _operator);
    }

    function setTradingPaused(bool _paused) external onlyOperator {
        tradingPaused = _paused;
        emit TradingPausedChanged(_paused);
    }

    function setRiskParameters(
        uint256 _initialMarginRate,
        uint256 _liquidationThreshold,
        uint256 _minCollateral
    ) external onlyOperator {
        if (_initialMarginRate == 0 || _liquidationThreshold == 0) revert InvalidParameter();
        if (_liquidationThreshold >= _initialMarginRate) revert InvalidParameter();
        if (_initialMarginRate < 5e18) revert InvalidParameter();
        initialMarginRate = _initialMarginRate;
        liquidationThreshold = _liquidationThreshold;
        minCollateral = _minCollateral;
        emit ParameterUpdated("initialMarginRate", _initialMarginRate);
        emit ParameterUpdated("liquidationThreshold", _liquidationThreshold);
        emit ParameterUpdated("minCollateral", _minCollateral);
    }

    function addPair(bytes32 pairId, address oracle, uint256 maxLeverage) external onlyOperator {
        if (oracle == address(0)) revert ZeroAddress();
        if (pairs[pairId].exists) revert InvalidPair();
        if (maxLeverage > MAX_GLOBAL_LEVERAGE) revert LeverageExceeded();
        pairs[pairId] = TradingPair({
            id: pairId,
            oracle: IOracle(oracle),
            maxLeverage: maxLeverage,
            cumulativeFunding: 0,
            fundingRatePerSecond: 0,
            lastFundingUpdate: block.timestamp,
            exists: true
        });
        pairList.push(pairId);
        emit PairAdded(pairId, oracle, maxLeverage);
    }

    function setFundingRate(bytes32 pairId, int256 ratePerSecond) external onlyOperator pairExists(pairId) {
        _updateFunding(pairId);
        pairs[pairId].fundingRatePerSecond = ratePerSecond;
        emit FundingUpdated(pairId, pairs[pairId].cumulativeFunding, ratePerSecond);
    }

    function setMaxLeverage(bytes32 pairId, uint256 maxLeverage) external onlyOperator pairExists(pairId) {
        if (maxLeverage > MAX_GLOBAL_LEVERAGE) revert LeverageExceeded();
        pairs[pairId].maxLeverage = maxLeverage;
        emit ParameterUpdated("maxLeverage", maxLeverage);
    }

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function deposit(uint256 amount) external notPaused {
        if (amount == 0) revert InvalidParameter();
        _updateAllFundingForUser(msg.sender);

        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        balances[msg.sender] += amount;
        totalCollateral += amount;

        emit Deposit(msg.sender, amount, balances[msg.sender]);
    }

    function withdraw(uint256 amount) external notPaused {
        if (amount == 0) revert InvalidParameter();
        _updateAllFundingForUser(msg.sender);

        uint256 available = getAvailableMargin(msg.sender);
        if (amount > available) revert InsufficientMargin();

        balances[msg.sender] -= amount;
        totalCollateral -= amount;

        bool ok = collateralToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdraw(msg.sender, amount, balances[msg.sender]);
    }

    /*//////////////////////////////////////////////////////////////
                       POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function openPosition(
        bytes32 pairId,
        int256 size,
        uint256 collateralAmount
    ) external notPaused pairExists(pairId) {
        if (size == 0) revert InvalidSize();
        if (collateralAmount < minCollateral) revert InsufficientMargin();
        if (collateralAmount > balances[msg.sender]) revert InsufficientMargin();
        if (positions[msg.sender][pairId].isOpen) revert PositionAlreadyOpen();

        _updateFunding(pairId);

        uint256 price = _getPrice(pairId);
        TradingPair storage pair = pairs[pairId];

        uint256 absSize = _abs(size);

        // Leverage = (absSize * price) / collateralAmount (multiply before divide)
        uint256 leverage = (absSize * price) / collateralAmount;
        if (leverage > pair.maxLeverage) revert LeverageExceeded();

        // Required margin = absSize * price * initialMarginRate / (PRICE_PRECISION * PRICE_PRECISION)
        uint256 requiredMargin = (absSize * price * initialMarginRate) / (PRICE_PRECISION * PRICE_PRECISION);
        if (collateralAmount < requiredMargin) revert InsufficientMargin();

        balances[msg.sender] -= collateralAmount;

        Position storage pos = positions[msg.sender][pairId];
        pos.size = size;
        pos.entryPrice = price;
        pos.collateral = collateralAmount;
        pos.lastFundingIndex = pair.cumulativeFunding;
        pos.isOpen = true;

        emit PositionOpened(msg.sender, pairId, size, price, collateralAmount, leverage);
    }

    function modifyPosition(
        bytes32 pairId,
        int256 sizeDelta,
        uint256 collateralDelta
    ) external notPaused pairExists(pairId) {
        Position storage pos = positions[msg.sender][pairId];
        if (!pos.isOpen) revert PositionNotFound();

        _updateFunding(pairId);
        _settleFunding(msg.sender, pairId, pos);

        uint256 price = _getPrice(pairId);
        TradingPair storage pair = pairs[pairId];

        if (collateralDelta > 0) {
            if (collateralDelta > balances[msg.sender]) revert InsufficientMargin();
            balances[msg.sender] -= collateralDelta;
            pos.collateral += collateralDelta;
        }

        if (sizeDelta != 0) {
            int256 newSize = pos.size + sizeDelta;
            if (newSize == 0) {
                _closePositionInternal(msg.sender, pairId, price);
                emit PositionModified(msg.sender, pairId, sizeDelta, 0, 0);
                return;
            }

            uint256 oldAbsSize = _abs(pos.size);
            uint256 deltaAbsSize = _abs(sizeDelta);
            uint256 newAbsSize = _abs(newSize);

            pos.entryPrice =
                (pos.entryPrice * oldAbsSize + price * deltaAbsSize) /
                (oldAbsSize + deltaAbsSize);
            pos.size = newSize;

            // Leverage = (newAbsSize * price) / pos.collateral (multiply before divide)
            uint256 leverage = (newAbsSize * price) / pos.collateral;
            if (leverage > pair.maxLeverage) revert LeverageExceeded();

            // Required margin = newAbsSize * price * initialMarginRate / (PRICE_PRECISION * PRICE_PRECISION)
            uint256 requiredMargin = (newAbsSize * price * initialMarginRate) / (PRICE_PRECISION * PRICE_PRECISION);
            if (pos.collateral < requiredMargin) revert InsufficientMargin();
        }

        pos.lastFundingIndex = pair.cumulativeFunding;

        emit PositionModified(msg.sender, pairId, sizeDelta, pos.entryPrice, pos.collateral);
    }

    function closePosition(bytes32 pairId) external notPaused pairExists(pairId) {
        Position storage pos = positions[msg.sender][pairId];
        if (!pos.isOpen) revert PositionNotFound();

        _updateFunding(pairId);
        _settleFunding(msg.sender, pairId, pos);

        uint256 price = _getPrice(pairId);
        _closePositionInternal(msg.sender, pairId, price);
    }

    function liquidate(address account, bytes32 pairId) external notPaused pairExists(pairId) {
        Position storage pos = positions[account][pairId];
        if (!pos.isOpen) revert PositionNotFound();

        _updateFunding(pairId);
        _settleFunding(account, pairId, pos);

        uint256 price = _getPrice(pairId);

        if (!_isLiquidatable(account, pairId, price)) revert NotLiquidatable();

        uint256 absSize = _abs(pos.size);

        // Liquidation fee = absSize * price * LIQUIDATION_FEE_RATE / (PRICE_PRECISION * BASIS_POINTS)
        uint256 liquidationFee = (absSize * price * LIQUIDATION_FEE_RATE) / (PRICE_PRECISION * BASIS_POINTS);

        int256 pnl = _computePnL(pos, price);

        uint256 collateralToReturn;
        if (pnl >= 0) {
            collateralToReturn = pos.collateral + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            collateralToReturn = pos.collateral > loss ? pos.collateral - loss : 0;
        }

        if (liquidationFee > collateralToReturn) {
            liquidationFee = collateralToReturn;
        }
        uint256 remaining = collateralToReturn - liquidationFee;

        int256 closedSize = pos.size;
        pos.size = 0;
        pos.entryPrice = 0;
        pos.collateral = 0;
        pos.lastFundingIndex = 0;
        pos.isOpen = false;

        if (liquidationFee > 0) {
            totalCollateral -= liquidationFee;
            bool ok = collateralToken.transfer(msg.sender, liquidationFee);
            if (!ok) revert TransferFailed();
        }

        if (remaining > 0) {
            balances[account] += remaining;
        }

        emit PositionLiquidated(account, pairId, msg.sender, closedSize, price, liquidationFee, remaining);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAvailableMargin(address account) public view returns (uint256) {
        uint256 free = balances[account];
        int256 totalUnrealizedPnl = 0;
        int256 totalFunding = 0;

        for (uint256 i = 0; i < pairList.length; i++) {
            bytes32 pid = pairList[i];
            Position storage pos = positions[account][pid];
            if (!pos.isOpen) continue;

            uint256 price = _getPrice(pid);
            totalUnrealizedPnl += _computePnL(pos, price);

            int256 fundingDiff = int256(pairs[pid].cumulativeFunding) - int256(pos.lastFundingIndex);
            totalFunding += (pos.size * fundingDiff) / int256(FUNDING_PRECISION);
        }

        if (totalUnrealizedPnl < 0) {
            uint256 loss = uint256(-totalUnrealizedPnl);
            free = free > loss ? free - loss : 0;
        } else {
            free += uint256(totalUnrealizedPnl);
        }

        if (totalFunding < 0) {
            uint256 fundingLoss = uint256(-totalFunding);
            free = free > fundingLoss ? free - fundingLoss : 0;
        } else {
            free += uint256(totalFunding);
        }

        return free;
    }

    function getPosition(address account, bytes32 pairId)
        external
        view
        returns (
            int256 size,
            uint256 entryPrice,
            uint256 collateral,
            uint256 lastFundingIndex,
            bool isOpen
        )
    {
        Position storage pos = positions[account][pairId];
        return (pos.size, pos.entryPrice, pos.collateral, pos.lastFundingIndex, pos.isOpen);
    }

    function getPair(bytes32 pairId)
        external
        view
        returns (
            address oracle,
            uint256 maxLeverage,
            uint256 cumulativeFunding,
            int256 fundingRatePerSecond,
            uint256 lastFundingUpdate,
            bool exists
        )
    {
        TradingPair storage p = pairs[pairId];
        return (
            address(p.oracle),
            p.maxLeverage,
            p.cumulativeFunding,
            p.fundingRatePerSecond,
            p.lastFundingUpdate,
            p.exists
        );
    }

    function isLiquidatable(address account, bytes32 pairId) external view returns (bool) {
        Position storage pos = positions[account][pairId];
        if (!pos.isOpen) return false;
        uint256 price = _getPrice(pairId);
        return _isLiquidatable(account, pairId, price);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getPrice(bytes32 pairId) internal view returns (uint256) {
        return pairs[pairId].oracle.getPrice(pairId);
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function _computePnL(Position storage pos, uint256 currentPrice) internal view returns (int256) {
        if (!pos.isOpen) return 0;
        int256 priceDiff = int256(currentPrice) - int256(pos.entryPrice);
        return (pos.size * priceDiff) / int256(PRICE_PRECISION);
    }

    function _isLiquidatable(address account, bytes32 pairId, uint256 price) internal view returns (bool) {
        Position storage pos = positions[account][pairId];
        if (!pos.isOpen) return false;

        int256 pnl = _computePnL(pos, price);
        int256 fundingDiff = int256(pairs[pairId].cumulativeFunding) - int256(pos.lastFundingIndex);
        int256 fundingPayment = (pos.size * fundingDiff) / int256(FUNDING_PRECISION);

        int256 effectiveCollateral = int256(pos.collateral) + pnl + fundingPayment;
        if (effectiveCollateral <= 0) return true;

        uint256 absSize = _abs(pos.size);
        // Margin ratio = effectiveCollateral * PRICE_PRECISION / (absSize * price)
        uint256 marginRatio = (uint256(effectiveCollateral) * PRICE_PRECISION) / (absSize * price);
        return marginRatio < liquidationThreshold;
    }

    function _updateFunding(bytes32 pairId) internal {
        TradingPair storage pair = pairs[pairId];
        if (block.timestamp <= pair.lastFundingUpdate) return;

        uint256 elapsed = block.timestamp - pair.lastFundingUpdate;

        int256 fundingAccrued = pair.fundingRatePerSecond * int256(elapsed);
        if (fundingAccrued >= 0) {
            pair.cumulativeFunding += uint256(fundingAccrued);
        } else {
            uint256 neg = uint256(-fundingAccrued);
            if (pair.cumulativeFunding >= neg) {
                pair.cumulativeFunding -= neg;
            } else {
                pair.cumulativeFunding = 0;
            }
        }
        pair.lastFundingUpdate = block.timestamp;
        emit FundingUpdated(pairId, pair.cumulativeFunding, pair.fundingRatePerSecond);
    }

    function _settleFunding(address account, bytes32 pairId, Position storage pos) internal {
        TradingPair storage pair = pairs[pairId];
        int256 fundingDiff = int256(pair.cumulativeFunding) - int256(pos.lastFundingIndex);
        if (fundingDiff == 0) return;

        int256 fundingPayment = (pos.size * fundingDiff) / int256(FUNDING_PRECISION);

        if (fundingPayment >= 0) {
            uint256 pay = uint256(fundingPayment);
            if (pay >= pos.collateral) {
                pos.collateral = 0;
            } else {
                pos.collateral -= pay;
            }
        } else {
            pos.collateral += uint256(-fundingPayment);
        }

        pos.lastFundingIndex = pair.cumulativeFunding;
    }

    function _updateAllFundingForUser(address account) internal {
        for (uint256 i = 0; i < pairList.length; i++) {
            bytes32 pid = pairList[i];
            if (!positions[account][pid].isOpen) continue;
            _updateFunding(pid);
            _settleFunding(account, pid, positions[account][pid]);
        }
    }

    function _closePositionInternal(address account, bytes32 pairId, uint256 price) internal {
        Position storage pos = positions[account][pairId];
        int256 pnl = _computePnL(pos, price);

        uint256 collateralToReturn;
        if (pnl >= 0) {
            collateralToReturn = pos.collateral + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            collateralToReturn = pos.collateral > loss ? pos.collateral - loss : 0;
        }

        int256 closedSize = pos.size;
        pos.size = 0;
        pos.entryPrice = 0;
        pos.collateral = 0;
        pos.lastFundingIndex = 0;
        pos.isOpen = false;

        balances[account] += collateralToReturn;

        emit PositionClosed(account, pairId, closedSize, price, pnl, collateralToReturn);
    }

    /*//////////////////////////////////////////////////////////////
                       EMERGENCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        if (token == address(collateralToken)) {
            uint256 excess = collateralToken.balanceOf(address(this)) - totalCollateral;
            if (amount > excess) revert InsufficientMargin();
        }
        bool ok = IERC20(token).transfer(owner, amount);
        if (!ok) revert TransferFailed();
    }
}
