// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        require(address(token) != address(0), "SafeERC20: transfer from zero address");
        require(to != address(0), "SafeERC20: transfer to zero address");
        bool ok = token.transfer(to, amount);
        require(ok, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(address(token) != address(0), "SafeERC20: transferFrom zero address");
        require(from != address(0), "SafeERC20: transferFrom from zero");
        require(to != address(0), "SafeERC20: transferFrom to zero");
        bool ok = token.transferFrom(from, to, amount);
        require(ok, "SafeERC20: transferFrom failed");
    }
}

abstract contract AccessControl {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) internal _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    modifier onlyRole(bytes32 role) {
        require(_roles[role].members[msg.sender], "AccessControl: account missing role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role].members[account]) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role].members[account]) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function grantRole(bytes32 role, address account) public onlyRole(_roles[role].adminRole) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(_roles[role].adminRole) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public {
        require(msg.sender == account, "AccessControl: can only renounce for self");
        _revokeRole(role, account);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = _roles[role].adminRole;
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }
}

abstract contract Pausable {
    bool internal _paused;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function _pause() internal whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IPerpOracle {
    function getPrice(address asset) external view returns (uint256);
}

contract PerpetualsExchange is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    //------------------------------------------------------------------
    // Custom errors
    //------------------------------------------------------------------
    error ZeroAddress();
    error PairAlreadyExists();
    error PairNotFound();
    error PairNotActive();
    error InvalidAmount();
    error InvalidLeverage();
    error LeverageExceedsMax();
    error InsufficientBalance();
    error InsufficientMargin();
    error PositionNotFound();
    error NotPositionOwner();
    error PositionNotOpen();
    error InvalidPrice();
    error NotLiquidatable();
    error OICapExceeded();
    error FeeTooHigh();

    //------------------------------------------------------------------
    // Constants
    //------------------------------------------------------------------
    uint256 public constant MAX_LEVERAGE = 50e18;
    uint256 public constant MIN_LEVERAGE = 1e18;
    uint256 public constant WAD = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_TRADING_FEE_BPS = 5; // 0.05%

    //------------------------------------------------------------------
    // Enums
    //------------------------------------------------------------------
    enum Side {
        Long,
        Short
    }

    //------------------------------------------------------------------
    // Structs
    //------------------------------------------------------------------
    struct TradingPair {
        address underlying;
        address oracle;
        uint256 maxOpenInterest;
        uint256 currentLongOI;
        uint256 currentShortOI;
        uint256 maxLeverage;
        uint256 liquidationThresholdBps;
        uint256 liquidationPenaltyBps;
        bool enabled;
    }

    struct Position {
        address account;
        bytes32 pairId;
        Side side;
        uint256 margin;
        uint256 leverage;
        uint256 entryPrice;
        uint256 notional;
        uint256 openTimestamp;
        bool isOpen;
    }

    //------------------------------------------------------------------
    // State variables
    //------------------------------------------------------------------
    IERC20 public immutable collateralToken;
    uint256 public tradingFeeBps;
    uint256 public totalCollateralDeposited;
    uint256 public accumulatedFees;
    uint256 public nextPositionId;

    mapping(bytes32 => TradingPair) public tradingPairs;
    bytes32[] public pairList;

    mapping(address => uint256) public accountBalances;
    mapping(uint256 => Position) internal _positions;
    mapping(address => uint256[]) internal _userPositionIds;

    //------------------------------------------------------------------
    // Events
    //------------------------------------------------------------------
    event PairAdded(bytes32 indexed pairId, address indexed underlying, address indexed oracle);
    event PairUpdated(
        bytes32 indexed pairId,
        uint256 maxLeverage,
        uint256 liquidationThresholdBps,
        uint256 liquidationPenaltyBps
    );
    event PairStatusChanged(bytes32 indexed pairId, bool enabled);
    event PairMaxOIUpdated(bytes32 indexed pairId, uint256 maxOpenInterest);
    event TradingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TradingPaused();
    event TradingUnpaused();
    event FeesWithdrawn(address indexed to, uint256 amount);

    event CollateralDeposited(address indexed account, uint256 amount);
    event CollateralWithdrawn(address indexed account, address indexed to, uint256 amount);

    event PositionOpened(
        uint256 indexed positionId,
        address indexed account,
        bytes32 indexed pairId,
        Side side,
        uint256 margin,
        uint256 leverage,
        uint256 entryPrice,
        uint256 notional
    );
    event PositionClosed(
        uint256 indexed positionId,
        address indexed account,
        bytes32 pairId,
        uint256 exitPrice,
        int256 pnl,
        uint256 collateralReturned
    );
    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed account,
        address indexed liquidator,
        bytes32 pairId,
        uint256 price,
        uint256 remainingCollateral,
        uint256 liquidatorReward
    );

    //------------------------------------------------------------------
    // Modifiers
    //------------------------------------------------------------------
    modifier onlyActivePair(bytes32 pairId) {
        if (!tradingPairs[pairId].enabled) revert PairNotActive();
        _;
    }

    //------------------------------------------------------------------
    // Constructor
    //------------------------------------------------------------------
    constructor(address admin, address collateralToken_) {
        if (admin == address(0)) revert ZeroAddress();
        if (collateralToken_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);

        collateralToken = IERC20(collateralToken_);
        tradingFeeBps = DEFAULT_TRADING_FEE_BPS;
    }

    //------------------------------------------------------------------
    // Operator: pair management
    //------------------------------------------------------------------
    function addPair(
        bytes32 pairId,
        address underlying,
        address oracle,
        uint256 maxOpenInterest,
        uint256 maxLeverage,
        uint256 liquidationThresholdBps,
        uint256 liquidationPenaltyBps
    ) external onlyRole(OPERATOR_ROLE) {
        if (underlying == address(0)) revert ZeroAddress();
        if (oracle == address(0)) revert ZeroAddress();
        if (tradingPairs[pairId].underlying != address(0)) revert PairAlreadyExists();
        if (maxOpenInterest == 0) revert InvalidAmount();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (liquidationThresholdBps == 0 || liquidationThresholdBps >= BPS_DENOMINATOR)
            revert InvalidLeverage();
        if (liquidationPenaltyBps >= BPS_DENOMINATOR) revert FeeTooHigh();

        tradingPairs[pairId] = TradingPair({
            underlying: underlying,
            oracle: oracle,
            maxOpenInterest: maxOpenInterest,
            currentLongOI: 0,
            currentShortOI: 0,
            maxLeverage: maxLeverage,
            liquidationThresholdBps: liquidationThresholdBps,
            liquidationPenaltyBps: liquidationPenaltyBps,
            enabled: true
        });
        pairList.push(pairId);

        emit PairAdded(pairId, underlying, oracle);
    }

    function updatePair(
        bytes32 pairId,
        uint256 maxLeverage,
        uint256 liquidationThresholdBps,
        uint256 liquidationPenaltyBps
    ) external onlyRole(OPERATOR_ROLE) {
        if (tradingPairs[pairId].underlying == address(0)) revert PairNotFound();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (liquidationThresholdBps == 0 || liquidationThresholdBps >= BPS_DENOMINATOR)
            revert InvalidLeverage();
        if (liquidationPenaltyBps >= BPS_DENOMINATOR) revert FeeTooHigh();

        TradingPair storage pair = tradingPairs[pairId];
        pair.maxLeverage = maxLeverage;
        pair.liquidationThresholdBps = liquidationThresholdBps;
        pair.liquidationPenaltyBps = liquidationPenaltyBps;

        emit PairUpdated(pairId, maxLeverage, liquidationThresholdBps, liquidationPenaltyBps);
    }

    function setPairStatus(bytes32 pairId, bool enabled) external onlyRole(OPERATOR_ROLE) {
        if (tradingPairs[pairId].underlying == address(0)) revert PairNotFound();
        tradingPairs[pairId].enabled = enabled;
        emit PairStatusChanged(pairId, enabled);
    }

    function setPairMaxOI(bytes32 pairId, uint256 maxOpenInterest) external onlyRole(OPERATOR_ROLE) {
        if (tradingPairs[pairId].underlying == address(0)) revert PairNotFound();
        if (maxOpenInterest == 0) revert InvalidAmount();
        tradingPairs[pairId].maxOpenInterest = maxOpenInterest;
        emit PairMaxOIUpdated(pairId, maxOpenInterest);
    }

    function setTradingFee(uint256 newFeeBps) external onlyRole(OPERATOR_ROLE) {
        if (newFeeBps > BPS_DENOMINATOR) revert FeeTooHigh();
        uint256 oldFeeBps = tradingFeeBps;
        tradingFeeBps = newFeeBps;
        emit TradingFeeUpdated(oldFeeBps, newFeeBps);
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
        emit TradingPaused();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
        emit TradingUnpaused();
    }

    function withdrawFees(address to, uint256 amount) external onlyRole(OPERATOR_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (amount > accumulatedFees) revert InsufficientBalance();
        accumulatedFees -= amount;
        collateralToken.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    //------------------------------------------------------------------
    // User: collateral management
    //------------------------------------------------------------------
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        accountBalances[msg.sender] += amount;
        totalCollateralDeposited += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (accountBalances[msg.sender] < amount) revert InsufficientBalance();
        accountBalances[msg.sender] -= amount;
        totalCollateralDeposited -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, msg.sender, amount);
    }

    //------------------------------------------------------------------
    // User: positions
    //------------------------------------------------------------------
    function openPosition(
        bytes32 pairId,
        Side side,
        uint256 marginAmount,
        uint256 leverage
    ) external nonReentrant whenNotPaused onlyActivePair(pairId) returns (uint256 positionId) {
        if (marginAmount == 0) revert InsufficientMargin();
        if (leverage < MIN_LEVERAGE || leverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (accountBalances[msg.sender] < marginAmount) revert InsufficientBalance();

        TradingPair storage pair = tradingPairs[pairId];
        if (leverage > pair.maxLeverage) revert LeverageExceedsMax();

        uint256 notional = (marginAmount * leverage) / WAD;
        if (notional == 0) revert InvalidAmount();

        if (side == Side.Long) {
            if (pair.currentLongOI + notional > pair.maxOpenInterest) revert OICapExceeded();
        } else {
            if (pair.currentShortOI + notional > pair.maxOpenInterest) revert OICapExceeded();
        }

        uint256 entryPrice = IPerpOracle(pair.oracle).getPrice(pair.underlying);
        if (entryPrice == 0) revert InvalidPrice();

        uint256 fee = (notional * tradingFeeBps) / BPS_DENOMINATOR;
        if (marginAmount <= fee) revert InsufficientMargin();

        uint256 effectiveMargin = marginAmount - fee;
        uint256 effectiveNotional = (effectiveMargin * leverage) / WAD;

        accountBalances[msg.sender] -= marginAmount;
        accumulatedFees += fee;

        if (side == Side.Long) {
            pair.currentLongOI += effectiveNotional;
        } else {
            pair.currentShortOI += effectiveNotional;
        }

        positionId = nextPositionId++;
        _positions[positionId] = Position({
            account: msg.sender,
            pairId: pairId,
            side: side,
            margin: effectiveMargin,
            leverage: leverage,
            entryPrice: entryPrice,
            notional: effectiveNotional,
            openTimestamp: block.timestamp,
            isOpen: true
        });
        _userPositionIds[msg.sender].push(positionId);

        emit PositionOpened(
            positionId,
            msg.sender,
            pairId,
            side,
            effectiveMargin,
            leverage,
            entryPrice,
            effectiveNotional
        );
    }

    function closePosition(uint256 positionId) external nonReentrant whenNotPaused returns (int256 pnl) {
        Position storage pos = _positions[positionId];
        if (!pos.isOpen) revert PositionNotFound();
        if (pos.account != msg.sender) revert NotPositionOwner();

        TradingPair storage pair = tradingPairs[pos.pairId];
        uint256 exitPrice = IPerpOracle(pair.oracle).getPrice(pair.underlying);
        if (exitPrice == 0) revert InvalidPrice();

        pnl = _computePnL(pos, exitPrice);

        if (pos.side == Side.Long) {
            pair.currentLongOI -= pos.notional;
        } else {
            pair.currentShortOI -= pos.notional;
        }

        uint256 returnAmount;
        if (pnl >= 0) {
            returnAmount = pos.margin + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            returnAmount = loss >= pos.margin ? 0 : pos.margin - loss;
        }

        pos.isOpen = false;
        accountBalances[msg.sender] += returnAmount;

        emit PositionClosed(positionId, msg.sender, pos.pairId, exitPrice, pnl, returnAmount);
    }

    function liquidatePosition(uint256 positionId) external nonReentrant whenNotPaused {
        Position storage pos = _positions[positionId];
        if (!pos.isOpen) revert PositionNotFound();

        TradingPair storage pair = tradingPairs[pos.pairId];
        uint256 currentPrice = IPerpOracle(pair.oracle).getPrice(pair.underlying);
        if (currentPrice == 0) revert InvalidPrice();

        int256 pnl = _computePnL(pos, currentPrice);

        uint256 equity;
        if (pnl >= 0) {
            equity = pos.margin + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            equity = loss >= pos.margin ? 0 : pos.margin - loss;
        }

        uint256 maintenanceMargin = (pos.notional * pair.liquidationThresholdBps) / BPS_DENOMINATOR;
        if (equity >= maintenanceMargin) revert NotLiquidatable();

        if (pos.side == Side.Long) {
            pair.currentLongOI -= pos.notional;
        } else {
            pair.currentShortOI -= pos.notional;
        }

        uint256 reward = (equity * pair.liquidationPenaltyBps) / BPS_DENOMINATOR;
        if (reward > equity) reward = equity;

        pos.isOpen = false;

        accountBalances[msg.sender] += reward;
        if (equity > reward) {
            accountBalances[pos.account] += (equity - reward);
        }

        emit PositionLiquidated(
            positionId,
            pos.account,
            msg.sender,
            pos.pairId,
            currentPrice,
            equity,
            reward
        );
    }

    //------------------------------------------------------------------
    // Views
    //------------------------------------------------------------------
    function getPosition(uint256 positionId) external view returns (Position memory) {
        return _positions[positionId];
    }

    function getUserPositions(address account) external view returns (uint256[] memory) {
        return _userPositionIds[account];
    }

    function getPairCount() external view returns (uint256) {
        return pairList.length;
    }

    function getPair(bytes32 pairId) external view returns (TradingPair memory) {
        return tradingPairs[pairId];
    }

    function computePnL(uint256 positionId) external view returns (int256) {
        Position storage pos = _positions[positionId];
        if (!pos.isOpen) revert PositionNotOpen();
        TradingPair storage pair = tradingPairs[pos.pairId];
        uint256 currentPrice = IPerpOracle(pair.oracle).getPrice(pair.underlying);
        if (currentPrice == 0) revert InvalidPrice();
        return _computePnL(pos, currentPrice);
    }

    function isLiquidatable(uint256 positionId) external view returns (bool) {
        Position storage pos = _positions[positionId];
        if (!pos.isOpen) return false;
        TradingPair storage pair = tradingPairs[pos.pairId];
        uint256 currentPrice = IPerpOracle(pair.oracle).getPrice(pair.underlying);
        if (currentPrice == 0) return false;

        int256 pnl = _computePnL(pos, currentPrice);
        uint256 equity;
        if (pnl >= 0) {
            equity = pos.margin + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            equity = loss >= pos.margin ? 0 : pos.margin - loss;
        }

        uint256 maintenanceMargin = (pos.notional * pair.liquidationThresholdBps) / BPS_DENOMINATOR;
        return equity < maintenanceMargin;
    }

    function getPositionEquity(uint256 positionId)
        external
        view
        returns (uint256 equity, int256 pnl)
    {
        Position storage pos = _positions[positionId];
        if (!pos.isOpen) revert PositionNotOpen();
        TradingPair storage pair = tradingPairs[pos.pairId];
        uint256 currentPrice = IPerpOracle(pair.oracle).getPrice(pair.underlying);
        if (currentPrice == 0) revert InvalidPrice();

        pnl = _computePnL(pos, currentPrice);
        if (pnl >= 0) {
            equity = pos.margin + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            equity = loss >= pos.margin ? 0 : pos.margin - loss;
        }
    }

    //------------------------------------------------------------------
    // Internal
    //------------------------------------------------------------------
    function _computePnL(Position storage pos, uint256 currentPrice)
        internal
        view
        returns (int256)
    {
        if (currentPrice == 0) return 0;
        if (pos.side == Side.Long) {
            if (currentPrice >= pos.entryPrice) {
                return int256(
                    (currentPrice - pos.entryPrice) * pos.notional / pos.entryPrice
                );
            } else {
                return -int256(
                    (pos.entryPrice - currentPrice) * pos.notional / pos.entryPrice
                );
            }
        } else {
            if (pos.entryPrice >= currentPrice) {
                return int256(
                    (pos.entryPrice - currentPrice) * pos.notional / pos.entryPrice
                );
            } else {
                return -int256(
                    (currentPrice - pos.entryPrice) * pos.notional / pos.entryPrice
                );
            }
        }
    }

    receive() external payable {
        revert("ETH not accepted");
    }
}
