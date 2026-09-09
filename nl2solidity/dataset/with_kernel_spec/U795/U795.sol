// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PerpetualFutures {
    // ---------- Custom errors ----------
    error Unauthorized();
    error InvalidAmount();
    error InvalidPrice();
    error PairNotActive();
    error PairAlreadyExists();
    error PairNotFound();
    error InvalidLeverage();
    error InsufficientBalance(uint256 available, uint256 required);
    error PositionExists();
    error NoPosition();
    error NotLiquidatable();
    error MarginTooLow();

    // ---------- Events ----------
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        bytes32 indexed pairId,
        bool isLong,
        uint256 margin,
        uint256 leverage,
        uint256 size,
        uint256 entryPrice
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed pairId,
        int256 pnl,
        uint256 fee,
        uint256 settlement
    );
    event PositionModified(
        address indexed user,
        bytes32 indexed pairId,
        uint256 newMargin,
        uint256 newLeverage,
        uint256 newSize
    );
    event Liquidated(
        address indexed user,
        bytes32 indexed pairId,
        address indexed liquidator,
        int256 pnl,
        uint256 fee,
        uint256 remaining
    );
    event PriceUpdated(bytes32 indexed pairId, uint256 price);
    event PairConfigUpdated(bytes32 indexed pairId, uint256 maxLeverage, uint256 minMargin, bool isActive);

    // ---------- Constants ----------
    uint256 public constant MAX_LEVERAGE = 2000; // 20x in basis points
    uint256 public constant FEE_BPS = 10;         // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAINTENANCE_MARGIN_BPS = 5000; // 50% of margin

    // ---------- Structs ----------
    struct PairConfig {
        uint256 maxLeverage; // in basis points
        uint256 minMargin;   // minimum margin per position
        uint256 oraclePrice;
        bool isActive;
    }

    struct Position {
        bytes32 pairId;
        bool isLong;
        uint256 margin;
        uint256 leverage;   // in basis points
        uint256 size;       // notional in stablecoin terms
        uint256 entryPrice;
    }

    // ---------- State ----------
    IERC20 public immutable collateralToken;
    address public owner;
    address public operator;

    mapping(address => uint256) public balances;       // free collateral
    mapping(address => uint256) public marginUsed;     // locked margin
    mapping(bytes32 => PairConfig) public pairConfigs;
    mapping(address => mapping(bytes32 => Position)) public positions;

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ---------- Constructor ----------
    constructor(address _collateralToken, address _operator) {
        if (_collateralToken == address(0)) revert InvalidAmount();
        if (_operator == address(0)) revert InvalidAmount();
        collateralToken = IERC20(_collateralToken);
        owner = msg.sender;
        operator = _operator;
    }

    // ---------- Admin ----------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert InvalidAmount();
        operator = _operator;
    }

    function addTradingPair(
        bytes32 pairId,
        uint256 maxLeverage,
        uint256 minMargin,
        uint256 initialPrice
    ) external onlyOperator {
        if (pairConfigs[pairId].isActive) revert PairAlreadyExists();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (minMargin == 0) revert InvalidAmount();
        if (initialPrice == 0) revert InvalidPrice();
        pairConfigs[pairId] = PairConfig({
            maxLeverage: maxLeverage,
            minMargin: minMargin,
            oraclePrice: initialPrice,
            isActive: true
        });
        emit PairConfigUpdated(pairId, maxLeverage, minMargin, true);
        emit PriceUpdated(pairId, initialPrice);
    }

    function updatePairConfig(
        bytes32 pairId,
        uint256 maxLeverage,
        uint256 minMargin,
        bool isActive
    ) external onlyOperator {
        PairConfig storage pair = pairConfigs[pairId];
        if (!pair.isActive && !isActive) revert PairNotFound();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (minMargin == 0) revert InvalidAmount();
        pair.maxLeverage = maxLeverage;
        pair.minMargin = minMargin;
        pair.isActive = isActive;
        emit PairConfigUpdated(pairId, maxLeverage, minMargin, isActive);
    }

    function updatePrice(bytes32 pairId, uint256 price) external onlyOperator {
        PairConfig storage pair = pairConfigs[pairId];
        if (!pair.isActive) revert PairNotActive();
        if (price == 0) revert InvalidPrice();
        pair.oraclePrice = price;
        emit PriceUpdated(pairId, price);
    }

    // ---------- Collateral ----------
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert InvalidAmount();
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        uint256 free = _freeCollateral(msg.sender);
        if (amount > free) revert InsufficientBalance(free, amount);
        balances[msg.sender] -= amount;
        bool ok = collateralToken.transfer(msg.sender, amount);
        if (!ok) revert InvalidAmount();
        emit Withdraw(msg.sender, amount);
    }

    // ---------- Positions ----------
    function openPosition(
        bytes32 pairId,
        bool isLong,
        uint256 margin,
        uint256 leverage
    ) external {
        PairConfig storage pair = pairConfigs[pairId];
        if (!pair.isActive) revert PairNotActive();
        if (leverage == 0 || leverage > pair.maxLeverage) revert InvalidLeverage();
        if (margin < pair.minMargin) revert MarginTooLow();

        Position storage existing = positions[msg.sender][pairId];
        if (existing.margin != 0) revert PositionExists();

        uint256 free = _freeCollateral(msg.sender);
        if (margin > free) revert InsufficientBalance(free, margin);

        uint256 size = (margin * leverage) / BPS_DENOMINATOR;
        uint256 fee = (size * FEE_BPS) / BPS_DENOMINATOR;

        // Deduct margin and fee from free balance; fee reduces effective margin.
        balances[msg.sender] -= margin;
        if (fee > margin) {
            // Fee cannot exceed margin in practice; guard anyway.
            margin = 0;
        } else {
            margin -= fee;
        }
        if (margin == 0) revert InvalidAmount();

        marginUsed[msg.sender] += margin;

        positions[msg.sender][pairId] = Position({
            pairId: pairId,
            isLong: isLong,
            margin: margin,
            leverage: leverage,
            size: size,
            entryPrice: pair.oraclePrice
        });

        emit PositionOpened(msg.sender, pairId, isLong, margin, leverage, size, pair.oraclePrice);
    }

    function closePosition(bytes32 pairId) external {
        Position storage pos = positions[msg.sender][pairId];
        if (pos.margin == 0) revert NoPosition();

        PairConfig storage pair = pairConfigs[pairId];
        uint256 currentPrice = pair.oraclePrice;
        if (currentPrice == 0) revert InvalidPrice();

        int256 pnl = _pnl(pos, currentPrice);
        uint256 fee = (pos.size * FEE_BPS) / BPS_DENOMINATOR;

        int256 net = int256(pos.margin) + pnl - int256(fee);
        uint256 settlement = net > 0 ? uint256(net) : 0;

        marginUsed[msg.sender] -= pos.margin;
        delete positions[msg.sender][pairId];

        balances[msg.sender] += settlement;

        emit PositionClosed(msg.sender, pairId, pnl, fee, settlement);
    }

    function modifyPosition(
        bytes32 pairId,
        uint256 marginDelta,
        uint256 newLeverage,
        bool reduceMargin
    ) external {
        Position storage pos = positions[msg.sender][pairId];
        if (pos.margin == 0) revert NoPosition();

        PairConfig storage pair = pairConfigs[pairId];
        if (newLeverage == 0 || newLeverage > pair.maxLeverage) revert InvalidLeverage();

        uint256 newMargin = pos.margin;
        if (reduceMargin) {
            if (marginDelta == 0) revert InvalidAmount();
            if (marginDelta >= pos.margin) revert InvalidAmount();
            newMargin = pos.margin - marginDelta;
            marginUsed[msg.sender] -= marginDelta;
            balances[msg.sender] += marginDelta;
        } else {
            if (marginDelta > 0) {
                uint256 free = _freeCollateral(msg.sender);
                if (marginDelta > free) revert InsufficientBalance(free, marginDelta);
                balances[msg.sender] -= marginDelta;
                marginUsed[msg.sender] += marginDelta;
                newMargin = pos.margin + marginDelta;
            }
        }

        if (newMargin < pair.minMargin) revert MarginTooLow();

        uint256 newSize = (newMargin * newLeverage) / BPS_DENOMINATOR;

        pos.margin = newMargin;
        pos.leverage = newLeverage;
        pos.size = newSize;
        pos.entryPrice = pair.oraclePrice;

        emit PositionModified(msg.sender, pairId, newMargin, newLeverage, newSize);
    }

    function liquidate(address account, bytes32 pairId) external onlyOperator {
        Position storage pos = positions[account][pairId];
        if (pos.margin == 0) revert NoPosition();

        PairConfig storage pair = pairConfigs[pairId];
        uint256 currentPrice = pair.oraclePrice;
        if (currentPrice == 0) revert InvalidPrice();

        int256 pnl = _pnl(pos, currentPrice);
        int256 equity = int256(pos.margin) + pnl;

        // Maintenance margin: 50% of initial margin
        uint256 maintenance = (pos.margin * MAINTENANCE_MARGIN_BPS) / BPS_DENOMINATOR;
        if (equity > int256(maintenance)) revert NotLiquidatable();

        uint256 fee = (pos.size * FEE_BPS) / BPS_DENOMINATOR;
        int256 net = equity - int256(fee);
        uint256 remaining = net > 0 ? uint256(net) : 0;

        marginUsed[account] -= pos.margin;
        delete positions[account][pairId];

        if (remaining > 0) {
            balances[account] += remaining;
        }

        emit Liquidated(account, pairId, msg.sender, pnl, fee, remaining);
    }

    // ---------- Views ----------
    function freeCollateral(address account) external view returns (uint256) {
        return _freeCollateral(account);
    }

    function getPosition(address account, bytes32 pairId)
        external
        view
        returns (Position memory)
    {
        return positions[account][pairId];
    }

    function unrealizedPnL(address account, bytes32 pairId, uint256 price)
        external
        view
        returns (int256)
    {
        Position storage pos = positions[account][pairId];
        if (pos.margin == 0) revert NoPosition();
        return _pnl(pos, price);
    }

    // ---------- Internals ----------
    function _freeCollateral(address account) internal view returns (uint256) {
        uint256 bal = balances[account];
        uint256 used = marginUsed[account];
        if (used >= bal) return 0;
        return bal - used;
    }

    function _pnl(Position storage pos, uint256 currentPrice) internal view returns (int256) {
        if (pos.isLong) {
            if (currentPrice >= pos.entryPrice) {
                uint256 gain = ((currentPrice - pos.entryPrice) * pos.size) / pos.entryPrice;
                return int256(gain);
            } else {
                uint256 loss = ((pos.entryPrice - currentPrice) * pos.size) / pos.entryPrice;
                return -int256(loss);
            }
        } else {
            if (currentPrice <= pos.entryPrice) {
                uint256 gain = ((pos.entryPrice - currentPrice) * pos.size) / pos.entryPrice;
                return int256(gain);
            } else {
                uint256 loss = ((currentPrice - pos.entryPrice) * pos.size) / pos.entryPrice;
                return -int256(loss);
            }
        }
    }
}
