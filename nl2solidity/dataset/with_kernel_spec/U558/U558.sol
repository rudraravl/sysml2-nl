// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

interface IPriceOracle {
    function getPrice(bytes32 pairKey) external view returns (uint256);
}

contract PerpetualExchange {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MIN_INITIAL_MARGIN_BPS = 1_000;
    uint256 public constant LIQUIDATION_FEE_BPS = 50;
    uint256 public constant MAX_PAIR_LEVERAGE = 100;
    uint256 public constant MAX_INITIAL_LEVERAGE = 10;

    error ZeroAddress();
    error TokenNotApproved();
    error PairNotFound();
    error PairNotActive();
    error PairAlreadyExists();
    error InvalidPairKey();
    error InvalidLeverage();
    error InvalidSize();
    error InvalidPrice();
    error InvalidFeeBps();
    error InvalidLiquidationThreshold();
    error InsufficientBalance();
    error InsufficientMargin();
    error PositionNotOpen();
    error NotPositionOwner();
    error PositionNotLiquidatable();
    error CannotLiquidateOwnPosition();
    error Unauthorized(bytes32 role);
    error NothingToClaim();
    error ReentrantCall();
    error EnforcedPause();

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount, address indexed recipient);
    event CollateralTokenApprovalUpdated(address indexed token, bool approved);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    event TradingPairAdded(
        uint256 indexed pairId,
        bytes32 indexed pairKey,
        uint256 maxLeverage,
        uint256 feeBps,
        uint256 liquidationThresholdBps
    );
    event TradingFeeUpdated(uint256 indexed pairId, uint256 oldFeeBps, uint256 newFeeBps);
    event LiquidationThresholdUpdated(uint256 indexed pairId, uint256 oldThresholdBps, uint256 newThresholdBps);
    event PairStatusUpdated(uint256 indexed pairId, bool active);
    event FeesClaimed(address indexed token, address indexed recipient, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    event PositionOpened(
        uint256 indexed positionId,
        address indexed trader,
        uint256 indexed pairId,
        int256 size,
        uint256 notional,
        uint256 margin,
        uint256 leverage,
        uint256 entryPrice,
        address collateralToken,
        uint256 fee
    );
    event PositionClosed(
        uint256 indexed positionId,
        address indexed trader,
        uint256 indexed pairId,
        int256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 marginReturned
    );
    event LeverageModified(
        uint256 indexed positionId,
        address indexed trader,
        uint256 oldLeverage,
        uint256 newLeverage,
        int256 marginDelta
    );
    event Liquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        address indexed trader,
        uint256 pairId,
        int256 size,
        uint256 liquidationPrice,
        uint256 liquidationFee,
        int256 traderPayout,
        int256 pnl
    );

    struct TradingPair {
        bytes32 pairKey;
        uint256 maxLeverage;
        uint256 feeBps;
        uint256 liquidationThresholdBps;
        bool active;
    }

    struct Position {
        uint256 pairId;
        address trader;
        address collateralToken;
        int256 size;
        uint256 margin;
        uint256 leverage;
        uint256 entryPrice;
        uint256 lastUpdateTimestamp;
        bool isOpen;
    }

    struct PnLResult {
        int256 pnl;
        uint256 currentNotional;
        int256 currentMargin;
    }

    IPriceOracle public oracle;
    mapping(address => bool) public approvedCollateralTokens;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => uint256) public accumulatedFees;

    mapping(uint256 => TradingPair) public tradingPairs;
    uint256[] public pairIdList;

    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionIds;
    uint256 public nextPositionId;
    uint256 public nextPairId;

    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(bytes32 => uint256) private _roleCount;

    bool private _paused;
    uint256 private _locked = 1;

    modifier onlyRole(bytes32 role) {
        if (!_roles[role][msg.sender]) revert Unauthorized(role);
        _;
    }

    modifier onlyOperator() {
        if (!_roles[OPERATOR_ROLE][msg.sender]) revert Unauthorized(OPERATOR_ROLE);
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address admin, address oracle_) {
        if (admin == address(0)) revert ZeroAddress();
        if (oracle_ == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(oracle_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        nextPairId = 1;
        nextPositionId = 1;
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            _roleCount[role]++;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            _roleCount[role]--;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function _pause() internal {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function _pairExists(uint256 pairId) internal view returns (bool) {
        return pairId != 0 && pairId < nextPairId && tradingPairs[pairId].pairKey != bytes32(0);
    }

    function _lockedMargin(address user, address token) internal view returns (uint256 locked) {
        uint256[] storage ids = userPositionIds[user];
        uint256 len = ids.length;
        for (uint256 i = 0; i < len; ++i) {
            Position storage p = positions[ids[i]];
            if (p.isOpen && p.collateralToken == token) {
                locked += p.margin;
            }
        }
    }

    function _pnlAndNotional(Position memory pos, uint256 currentPrice)
        internal
        pure
        returns (PnLResult memory r)
    {
        uint256 absSize = _abs(pos.size);
        int256 entryNotional = int256((absSize * pos.entryPrice) / PRICE_PRECISION);
        r.currentNotional = (absSize * currentPrice) / PRICE_PRECISION;
        int256 signedCurrentNotional = int256(r.currentNotional);
        if (pos.size > 0) {
            r.pnl = signedCurrentNotional - entryNotional;
        } else {
            r.pnl = entryNotional - signedCurrentNotional;
        }
        r.currentMargin = int256(pos.margin) + r.pnl;
    }

    function _isLiquidatable(PnLResult memory r, uint256 liqThresholdBps) internal pure returns (bool) {
        if (r.currentMargin <= 0) return true;
        uint256 requiredMargin = (r.currentNotional * liqThresholdBps) / BASIS_POINTS;
        return uint256(r.currentMargin) < requiredMargin;
    }

    function setOracle(address oracle_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (oracle_ == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IPriceOracle(oracle_);
        emit OracleUpdated(old, oracle_);
    }

    function approveCollateralToken(address token, bool approved) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        approvedCollateralTokens[token] = approved;
        emit CollateralTokenApprovalUpdated(token, approved);
    }

    function addTradingPair(
        bytes32 pairKey,
        uint256 maxLeverage,
        uint256 feeBps,
        uint256 liquidationThresholdBps
    ) external onlyOperator returns (uint256 pairId) {
        if (pairKey == bytes32(0)) revert InvalidPairKey();
        if (maxLeverage == 0 || maxLeverage > MAX_PAIR_LEVERAGE) revert InvalidLeverage();
        if (feeBps > BASIS_POINTS) revert InvalidFeeBps();
        if (liquidationThresholdBps == 0 || liquidationThresholdBps > MIN_INITIAL_MARGIN_BPS) {
            revert InvalidLiquidationThreshold();
        }
        uint256 len = pairIdList.length;
        for (uint256 i = 0; i < len; ++i) {
            if (tradingPairs[pairIdList[i]].pairKey == pairKey) revert PairAlreadyExists();
        }
        pairId = nextPairId++;
        tradingPairs[pairId] = TradingPair({
            pairKey: pairKey,
            maxLeverage: maxLeverage,
            feeBps: feeBps,
            liquidationThresholdBps: liquidationThresholdBps,
            active: true
        });
        pairIdList.push(pairId);
        emit TradingPairAdded(pairId, pairKey, maxLeverage, feeBps, liquidationThresholdBps);
    }

    function updateTradingFee(uint256 pairId, uint256 newFeeBps) external onlyOperator {
        if (!_pairExists(pairId)) revert PairNotFound();
        if (newFeeBps > BASIS_POINTS) revert InvalidFeeBps();
        uint256 oldFeeBps = tradingPairs[pairId].feeBps;
        tradingPairs[pairId].feeBps = newFeeBps;
        emit TradingFeeUpdated(pairId, oldFeeBps, newFeeBps);
    }

    function updateLiquidationThreshold(uint256 pairId, uint256 newThresholdBps) external onlyOperator {
        if (!_pairExists(pairId)) revert PairNotFound();
        if (newThresholdBps == 0 || newThresholdBps > MIN_INITIAL_MARGIN_BPS) {
            revert InvalidLiquidationThreshold();
        }
        uint256 oldThresholdBps = tradingPairs[pairId].liquidationThresholdBps;
        tradingPairs[pairId].liquidationThresholdBps = newThresholdBps;
        emit LiquidationThresholdUpdated(pairId, oldThresholdBps, newThresholdBps);
    }

    function setPairActive(uint256 pairId, bool active) external onlyOperator {
        if (!_pairExists(pairId)) revert PairNotFound();
        tradingPairs[pairId].active = active;
        emit PairStatusUpdated(pairId, active);
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    function claimFees(address token, address recipient) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees[token];
        if (amount == 0) revert NothingToClaim();
        accumulatedFees[token] = 0;
        IERC20(token).safeTransfer(recipient, amount);
        emit FeesClaimed(token, recipient, amount);
    }

    function deposit(address token, uint256 amount) external nonReentrant whenNotPaused {
        if (!approvedCollateralTokens[token]) revert TokenNotApproved();
        if (amount == 0) revert InvalidSize();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount, address recipient) external nonReentrant whenNotPaused {
        if (!approvedCollateralTokens[token]) revert TokenNotApproved();
        if (amount == 0) revert InvalidSize();
        if (recipient == address(0)) revert ZeroAddress();
        uint256 bal = collateralBalances[msg.sender][token];
        if (bal < amount) revert InsufficientBalance();
        uint256 locked = _lockedMargin(msg.sender, token);
        if (locked > bal - amount) revert InsufficientBalance();
        collateralBalances[msg.sender][token] = bal - amount;
        IERC20(token).safeTransfer(recipient, amount);
        emit Withdraw(msg.sender, token, amount, recipient);
    }

    function getAvailableBalance(address user, address token) external view returns (uint256) {
        uint256 bal = collateralBalances[user][token];
        uint256 locked = _lockedMargin(user, token);
        return bal > locked ? bal - locked : 0;
    }

    function openPosition(
        uint256 pairId,
        bool isLong,
        uint256 leverage,
        address collateralToken,
        uint256 marginAmount
    ) external nonReentrant whenNotPaused returns (uint256 positionId) {
        if (!_pairExists(pairId)) revert PairNotFound();
        TradingPair storage pair = tradingPairs[pairId];
        if (!pair.active) revert PairNotActive();
        if (!approvedCollateralTokens[collateralToken]) revert TokenNotApproved();
        if (leverage == 0 || leverage > pair.maxLeverage) revert InvalidLeverage();
        if (leverage > MAX_INITIAL_LEVERAGE) revert InsufficientMargin();
        if (marginAmount == 0) revert InsufficientMargin();

        uint256 price = oracle.getPrice(pair.pairKey);
        if (price == 0) revert InvalidPrice();

        uint256 notional = marginAmount * leverage;
        if (marginAmount < (notional * MIN_INITIAL_MARGIN_BPS) / BASIS_POINTS) revert InsufficientMargin();

        uint256 fee = (notional * pair.feeBps) / BASIS_POINTS;
        uint256 bal = collateralBalances[msg.sender][collateralToken];
        if (bal < marginAmount + fee) revert InsufficientBalance();

        collateralBalances[msg.sender][collateralToken] = bal - (marginAmount + fee);
        if (fee > 0) {
            accumulatedFees[collateralToken] += fee;
        }

        positionId = nextPositionId++;
        Position storage pos = positions[positionId];
        pos.pairId = pairId;
        pos.trader = msg.sender;
        pos.collateralToken = collateralToken;
        pos.size = isLong ? int256((notional * PRICE_PRECISION) / price) : -int256((notional * PRICE_PRECISION) / price);
        pos.margin = marginAmount;
        pos.leverage = leverage;
        pos.entryPrice = price;
        pos.lastUpdateTimestamp = block.timestamp;
        pos.isOpen = true;

        userPositionIds[msg.sender].push(positionId);

        emit PositionOpened(
            positionId,
            msg.sender,
            pairId,
            pos.size,
            notional,
            marginAmount,
            leverage,
            price,
            collateralToken,
            fee
        );
    }

    function closePosition(uint256 positionId) external nonReentrant whenNotPaused {
        Position storage pos = positions[positionId];
        if (!pos.isOpen) revert PositionNotOpen();
        if (pos.trader != msg.sender) revert NotPositionOwner();

        TradingPair storage pair = tradingPairs[pos.pairId];
        uint256 price = oracle.getPrice(pair.pairKey);
        if (price == 0) revert InvalidPrice();

        PnLResult memory r = _pnlAndNotional(pos, price);

        pos.isOpen = false;
        pos.lastUpdateTimestamp = block.timestamp;

        uint256 marginReturned = r.currentMargin > 0 ? uint256(r.currentMargin) : 0;
        if (marginReturned > 0) {
            collateralBalances[pos.trader][pos.collateralToken] += marginReturned;
        }

        emit PositionClosed(positionId, pos.trader, pos.pairId, pos.size, price, r.pnl, marginReturned);
    }

    function modifyLeverage(uint256 positionId, uint256 newLeverage) external nonReentrant whenNotPaused {
        Position storage pos = positions[positionId];
        if (!pos.isOpen) revert PositionNotOpen();
        if (pos.trader != msg.sender) revert NotPositionOwner();

        TradingPair storage pair = tradingPairs[pos.pairId];
        if (!pair.active) revert PairNotActive();
        if (newLeverage == 0 || newLeverage > pair.maxLeverage) revert InvalidLeverage();
        if (newLeverage > MAX_INITIAL_LEVERAGE) revert InsufficientMargin();

        uint256 price = oracle.getPrice(pair.pairKey);
        if (price == 0) revert InvalidPrice();

        uint256 currentNotional = (_abs(pos.size) * price) / PRICE_PRECISION;
        uint256 requiredMargin = currentNotional / newLeverage;
        if (requiredMargin < (currentNotional * MIN_INITIAL_MARGIN_BPS) / BASIS_POINTS) {
            revert InsufficientMargin();
        }

        uint256 oldLeverage = pos.leverage;
        int256 marginDelta;

        if (requiredMargin > pos.margin) {
            uint256 additional = requiredMargin - pos.margin;
            uint256 bal = collateralBalances[msg.sender][pos.collateralToken];
            if (bal < additional) revert InsufficientBalance();
            collateralBalances[msg.sender][pos.collateralToken] = bal - additional;
            pos.margin = requiredMargin;
            marginDelta = int256(additional);
        } else if (requiredMargin < pos.margin) {
            uint256 release = pos.margin - requiredMargin;
            pos.margin = requiredMargin;
            collateralBalances[msg.sender][pos.collateralToken] += release;
            marginDelta = -int256(release);
        }

        pos.leverage = newLeverage;
        pos.lastUpdateTimestamp = block.timestamp;

        emit LeverageModified(positionId, msg.sender, oldLeverage, newLeverage, marginDelta);
    }

    function liquidate(uint256 positionId) external nonReentrant whenNotPaused {
        Position storage pos = positions[positionId];
        if (!pos.isOpen) revert PositionNotOpen();
        if (pos.trader == msg.sender) revert CannotLiquidateOwnPosition();

        TradingPair storage pair = tradingPairs[pos.pairId];
        uint256 price = oracle.getPrice(pair.pairKey);
        if (price == 0) revert InvalidPrice();

        PnLResult memory r = _pnlAndNotional(pos, price);
        if (!_isLiquidatable(r, pair.liquidationThresholdBps)) revert PositionNotLiquidatable();

        uint256 liqFee = (r.currentNotional * LIQUIDATION_FEE_BPS) / BASIS_POINTS;
        int256 equity = r.currentMargin > 0 ? r.currentMargin : int256(0);
        uint256 liquidatorPayout = uint256(equity) < liqFee ? uint256(equity) : liqFee;
        int256 traderPayout = equity - int256(liquidatorPayout);

        pos.isOpen = false;
        pos.lastUpdateTimestamp = block.timestamp;

        if (traderPayout > 0) {
            collateralBalances[pos.trader][pos.collateralToken] += uint256(traderPayout);
        }
        if (liquidatorPayout > 0) {
            IERC20(pos.collateralToken).safeTransfer(msg.sender, liquidatorPayout);
        }

        emit Liquidated(positionId, msg.sender, pos.trader, pos.pairId, pos.size, price, liquidatorPayout, traderPayout, r.pnl);
    }

    function getPairCount() external view returns (uint256) {
        return pairIdList.length;
    }

    function getPair(uint256 pairId) external view returns (TradingPair memory) {
        return tradingPairs[pairId];
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    function getUserOpenPositionCount(address user) external view returns (uint256 count) {
        uint256[] storage ids = userPositionIds[user];
        uint256 len = ids.length;
        for (uint256 i = 0; i < len; ++i) {
            if (positions[ids[i]].isOpen) {
                ++count;
            }
        }
    }

    function getLockedMargin(address user, address token) external view returns (uint256) {
        return _lockedMargin(user, token);
    }

    function getPositionStatus(uint256 positionId)
        external
        view
        returns (
            bool isOpen,
            int256 pnl,
            uint256 currentNotional,
            int256 currentMargin,
            bool liquidatable
        )
    {
        Position memory pos = positions[positionId];
        if (!pos.isOpen) {
            return (false, 0, 0, 0, false);
        }
        TradingPair memory pair = tradingPairs[pos.pairId];
        uint256 price = oracle.getPrice(pair.pairKey);
        if (price == 0) revert InvalidPrice();
        PnLResult memory r = _pnlAndNotional(pos, price);
        isOpen = true;
        pnl = r.pnl;
        currentNotional = r.currentNotional;
        currentMargin = r.currentMargin;
        liquidatable = _isLiquidatable(r, pair.liquidationThresholdBps);
    }

    function getAccumulatedFees(address token) external view returns (uint256) {
        return accumulatedFees[token];
    }
}
