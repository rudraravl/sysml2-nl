// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ────────────────────────────────────────────────────────────────────
   Minimal inlined OpenZeppelin-like primitives so the file compiles
   without external package imports.
   ──────────────────────────────────────────────────────────────────── */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _call(token, abi.encodeWithSelector(IERC20.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _call(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _call(token, abi.encodeWithSelector(IERC20.approve.selector, spender, value));
    }

    function _call(IERC20 token, bytes memory data) internal {
        (bool ok, bytes memory ret) = address(token).call(data);
        if (!ok) {
            if (ret.length > 0) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
            revert("SafeERC20: low-level call failed");
        }
        if (ret.length > 0) {
            require(abi.decode(ret, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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

abstract contract AccessControl {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) internal _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: account is missing role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "AccessControl: can only renounce roles for self");
        _revokeRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = _roles[role].adminRole;
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }
}

interface IPriceOracle {
    function getPrice(bytes32 pairId) external view returns (uint256);
}

/* ════════════════════════════════════════════════════════════════════
   PerpetualExchange
   ════════════════════════════════════════════════════════════════════ */
contract PerpetualExchange is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /* ─────────────────────────── Constants ─────────────────────────── */
    uint256 public constant WAD = 1e18;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_LEVERAGE = 100;
    uint256 public constant DEFAULT_FEE_BPS = 5; // 0.05%

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ───────────────────────────── Types ───────────────────────────── */
    enum Direction {
        Long,
        Short
    }

    struct TradingPair {
        address oracle;
        uint256 maxLeverage;
        bool active;
        uint256 totalLongSize;
        uint256 totalShortSize;
    }

    struct Position {
        Direction direction;
        uint256 size;       // base token amount in WAD
        uint256 margin;     // collateral locked in WAD
        uint256 entryPrice; // price in WAD
        uint256 leverage;   // e.g. 10 => 10x
        bool isOpen;
    }

    /* ─────────────────────────── Storage ──────────────────────────── */
    IERC20 public immutable collateralToken;

    mapping(address => uint256) internal _freeCollateral;
    mapping(bytes32 => TradingPair) internal _pairs;
    mapping(address => mapping(bytes32 => Position)) internal _positions;

    uint256 public tradingFeeBps;
    uint256 public totalFeesCollected;

    /* ─────────────────────────── Events ───────────────────────────── */
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        bytes32 indexed pairId,
        Direction direction,
        uint256 size,
        uint256 margin,
        uint256 entryPrice,
        uint256 leverage,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed pairId,
        Direction direction,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 fee,
        uint256 returned
    );
    event LeverageModified(
        address indexed user,
        bytes32 indexed pairId,
        uint256 oldLeverage,
        uint256 newLeverage,
        int256 marginDelta
    );
    event PairAdded(bytes32 indexed pairId, address indexed oracle, uint256 maxLeverage);
    event PairMaxLeverageUpdated(
        bytes32 indexed pairId,
        uint256 oldMaxLeverage,
        uint256 newMaxLeverage
    );
    event PairStatusChanged(bytes32 indexed pairId, bool active);
    event TradingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TradingPaused();
    event TradingUnpaused();
    event FeesWithdrawn(address indexed to, uint256 amount);

    /* ─────────────────────────── Errors ───────────────────────────── */
    error ErrZeroAddress();
    error ErrZeroAmount();
    error ErrPairNotFound();
    error ErrPairAlreadyExists();
    error ErrPairNotActive();
    error ErrInvalidLeverage();
    error ErrInvalidFeeRate();
    error ErrInsufficientBalance();
    error ErrPositionNotFound();
    error ErrPositionAlreadyOpen();
    error ErrInvalidPrice();
    error ErrInvalidSize();

    /* ─────────────────────────── Constructor ───────────────────────── */
    constructor(address collateralToken_, address admin_) {
        if (collateralToken_ == address(0)) revert ErrZeroAddress();
        if (admin_ == address(0)) revert ErrZeroAddress();

        collateralToken = IERC20(collateralToken_);
        tradingFeeBps = DEFAULT_FEE_BPS;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);
    }

    /* ════════════════════════ Collateral Management ══════════════════ */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrZeroAmount();
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        _freeCollateral[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrZeroAmount();
        if (_freeCollateral[msg.sender] < amount) revert ErrInsufficientBalance();
        _freeCollateral[msg.sender] -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /* ════════════════════════ Position Management ════════════════════ */
    function openPosition(
        bytes32 pairId,
        Direction direction,
        uint256 size,
        uint256 leverage
    ) external nonReentrant whenNotPaused {
        TradingPair storage pair = _pairs[pairId];
        if (pair.oracle == address(0)) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();
        if (size == 0) revert ErrInvalidSize();
        if (leverage == 0 || leverage > pair.maxLeverage || leverage > MAX_LEVERAGE)
            revert ErrInvalidLeverage();

        Position storage pos = _positions[msg.sender][pairId];
        if (pos.isOpen) revert ErrPositionAlreadyOpen();

        uint256 price = IPriceOracle(pair.oracle).getPrice(pairId);
        if (price == 0) revert ErrInvalidPrice();

        // Compute margin from notional (single divide is acceptable as final result).
        uint256 notional = (size * price) / WAD;
        uint256 margin = notional / leverage;
        if (margin == 0) revert ErrInvalidSize();

        // Compute fee directly from the raw product to avoid divide-before-multiply.
        // fee = size * price * tradingFeeBps / (WAD * BPS)
        uint256 fee = (size * price * tradingFeeBps) / (WAD * BPS);

        uint256 totalRequired = margin + fee;
        if (_freeCollateral[msg.sender] < totalRequired) revert ErrInsufficientBalance();

        // Effects
        _freeCollateral[msg.sender] -= totalRequired;
        pos.direction = direction;
        pos.size = size;
        pos.margin = margin;
        pos.entryPrice = price;
        pos.leverage = leverage;
        pos.isOpen = true;

        if (direction == Direction.Long) {
            pair.totalLongSize += size;
        } else {
            pair.totalShortSize += size;
        }

        totalFeesCollected += fee;

        emit PositionOpened(msg.sender, pairId, direction, size, margin, price, leverage, fee);
    }

    function closePosition(bytes32 pairId) external nonReentrant whenNotPaused {
        Position storage pos = _positions[msg.sender][pairId];
        if (!pos.isOpen) revert ErrPositionNotFound();
        TradingPair storage pair = _pairs[pairId];

        uint256 price = IPriceOracle(pair.oracle).getPrice(pairId);
        if (price == 0) revert ErrInvalidPrice();

        int256 pnl = _computePnL(pos.size, pos.entryPrice, price, pos.direction);
        // Compute fee directly from the raw product to avoid divide-before-multiply.
        // fee = pos.size * price * tradingFeeBps / (WAD * BPS)
        uint256 fee = (pos.size * price * tradingFeeBps) / (WAD * BPS);

        int256 equity = int256(pos.margin) + pnl;
        uint256 returnAmount;
        uint256 feePaid;

        if (equity <= 0) {
            returnAmount = 0;
            feePaid = 0;
        } else {
            uint256 eq = uint256(equity);
            if (eq >= fee) {
                feePaid = fee;
                returnAmount = eq - fee;
            } else {
                feePaid = eq;
                returnAmount = 0;
            }
        }

        // Effects
        _freeCollateral[msg.sender] += returnAmount;
        totalFeesCollected += feePaid;

        if (pos.direction == Direction.Long) {
            pair.totalLongSize -= pos.size;
        } else {
            pair.totalShortSize -= pos.size;
        }

        emit PositionClosed(msg.sender, pairId, pos.direction, pos.size, price, pnl, feePaid, returnAmount);

        delete _positions[msg.sender][pairId];
    }

    function modifyLeverage(bytes32 pairId, uint256 newLeverage) external nonReentrant whenNotPaused {
        Position storage pos = _positions[msg.sender][pairId];
        if (!pos.isOpen) revert ErrPositionNotFound();
        TradingPair storage pair = _pairs[pairId];
        if (newLeverage == 0 || newLeverage > pair.maxLeverage || newLeverage > MAX_LEVERAGE)
            revert ErrInvalidLeverage();

        uint256 price = IPriceOracle(pair.oracle).getPrice(pairId);
        if (price == 0) revert ErrInvalidPrice();

        uint256 notional = (pos.size * price) / WAD;
        uint256 newMargin = notional / newLeverage;
        if (newMargin == 0) revert ErrInvalidSize();

        uint256 oldMargin = pos.margin;
        uint256 oldLeverage = pos.leverage;
        int256 marginDelta = 0;

        if (newMargin > oldMargin) {
            uint256 delta = newMargin - oldMargin;
            if (_freeCollateral[msg.sender] < delta) revert ErrInsufficientBalance();
            _freeCollateral[msg.sender] -= delta;
            pos.margin = newMargin;
            marginDelta = int256(delta);
        } else if (newMargin < oldMargin) {
            uint256 delta = oldMargin - newMargin;
            pos.margin = newMargin;
            _freeCollateral[msg.sender] += delta;
            marginDelta = -int256(delta);
        }

        pos.leverage = newLeverage;

        emit LeverageModified(msg.sender, pairId, oldLeverage, newLeverage, marginDelta);
    }

    /* ════════════════════════ Internal Helpers ══════════════════════ */
    function _computePnL(
        uint256 size,
        uint256 entryPrice,
        uint256 currentPrice,
        Direction direction
    ) internal pure returns (int256) {
        int256 signedSize = int256(size);
        if (direction == Direction.Long) {
            return (signedSize * (int256(currentPrice) - int256(entryPrice))) / int256(WAD);
        } else {
            return (signedSize * (int256(entryPrice) - int256(currentPrice))) / int256(WAD);
        }
    }

    /* ══════════════════════ Operator: Pair Config ════════════════════ */
    function addTradingPair(
        bytes32 pairId,
        address oracle_,
        uint256 maxLeverage
    ) external onlyRole(OPERATOR_ROLE) {
        if (oracle_ == address(0)) revert ErrZeroAddress();
        if (_pairs[pairId].oracle != address(0)) revert ErrPairAlreadyExists();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert ErrInvalidLeverage();

        _pairs[pairId] = TradingPair({
            oracle: oracle_,
            maxLeverage: maxLeverage,
            active: true,
            totalLongSize: 0,
            totalShortSize: 0
        });

        emit PairAdded(pairId, oracle_, maxLeverage);
    }

    function setMaxLeverage(bytes32 pairId, uint256 newMaxLeverage) external onlyRole(OPERATOR_ROLE) {
        TradingPair storage pair = _pairs[pairId];
        if (pair.oracle == address(0)) revert ErrPairNotFound();
        if (newMaxLeverage == 0 || newMaxLeverage > MAX_LEVERAGE) revert ErrInvalidLeverage();
        uint256 oldMaxLeverage = pair.maxLeverage;
        pair.maxLeverage = newMaxLeverage;
        emit PairMaxLeverageUpdated(pairId, oldMaxLeverage, newMaxLeverage);
    }

    function setPairActive(bytes32 pairId, bool active) external onlyRole(OPERATOR_ROLE) {
        TradingPair storage pair = _pairs[pairId];
        if (pair.oracle == address(0)) revert ErrPairNotFound();
        pair.active = active;
        emit PairStatusChanged(pairId, active);
    }

    function setTradingFee(uint256 newFeeBps) external onlyRole(OPERATOR_ROLE) {
        if (newFeeBps > BPS) revert ErrInvalidFeeRate();
        uint256 oldFeeBps = tradingFeeBps;
        tradingFeeBps = newFeeBps;
        emit TradingFeeUpdated(oldFeeBps, newFeeBps);
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
        emit TradingPaused();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit TradingUnpaused();
    }

    function withdrawFees(address to, uint256 amount) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ErrZeroAddress();
        if (amount == 0) revert ErrZeroAmount();
        if (amount > totalFeesCollected) revert ErrInsufficientBalance();
        totalFeesCollected -= amount;
        collateralToken.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    /* ═══════════════════════════ Views ════════════════════════════════ */
    function getPair(bytes32 pairId) external view returns (TradingPair memory) {
        if (_pairs[pairId].oracle == address(0)) revert ErrPairNotFound();
        return _pairs[pairId];
    }

    function getPosition(address user, bytes32 pairId) external view returns (Position memory) {
        return _positions[user][pairId];
    }

    function getFreeCollateral(address user) external view returns (uint256) {
        return _freeCollateral[user];
    }

    function getUnrealizedPnL(address user, bytes32 pairId) external view returns (int256) {
        Position storage pos = _positions[user][pairId];
        if (!pos.isOpen) return 0;
        TradingPair storage pair = _pairs[pairId];
        if (pair.oracle == address(0)) return 0;
        uint256 price = IPriceOracle(pair.oracle).getPrice(pairId);
        if (price == 0) return 0;
        return _computePnL(pos.size, pos.entryPrice, price, pos.direction);
    }

    function getEquity(address user, bytes32 pairId) external view returns (int256) {
        Position storage pos = _positions[user][pairId];
        if (!pos.isOpen) return 0;
        TradingPair storage pair = _pairs[pairId];
        if (pair.oracle == address(0)) return 0;
        uint256 price = IPriceOracle(pair.oracle).getPrice(pairId);
        if (price == 0) return 0;
        int256 pnl = _computePnL(pos.size, pos.entryPrice, price, pos.direction);
        return int256(pos.margin) + pnl;
    }

    function getNotionalValue(address user, bytes32 pairId) external view returns (uint256) {
        Position storage pos = _positions[user][pairId];
        if (!pos.isOpen) return 0;
        TradingPair storage pair = _pairs[pairId];
        if (pair.oracle == address(0)) return 0;
        uint256 price = IPriceOracle(pair.oracle).getPrice(pairId);
        if (price == 0) return 0;
        return (pos.size * price) / WAD;
    }

    function getEffectiveLeverage(address user, bytes32 pairId) external view returns (uint256) {
        Position storage pos = _positions[user][pairId];
        if (!pos.isOpen) return 0;
        TradingPair storage pair = _pairs[pairId];
        if (pair.oracle == address(0)) return 0;
        uint256 price = IPriceOracle(pair.oracle).getPrice(pairId);
        if (price == 0) return 0;
        int256 pnl = _computePnL(pos.size, pos.entryPrice, price, pos.direction);
        int256 equity = int256(pos.margin) + pnl;
        if (equity <= 0) return type(uint256).max;
        // Compute effective leverage directly from the raw product to avoid
        // divide-before-multiply: leverage = (size * price) / (equity * WAD)
        return (pos.size * price) / (uint256(equity) * WAD);
    }
}
