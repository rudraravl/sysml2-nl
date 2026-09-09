// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PerpetualExchange {
    // ============ Custom Errors ============
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientFreeCollateral();
    error PositionNotFound();
    error PositionNotOpen();
    error PositionAlreadyOpen();
    error LeverageTooHigh(uint256 requested, uint256 max);
    error LeverageTooLow(uint256 requested, uint256 min);
    error InvalidLeverage();
    error NotUndercollateralized();
    error OnlyOperator();
    error InvalidParameter();
    error ZeroAmount();
    error SelfLiquidation();
    error ReentrantCall();

    // ============ Constants ============
    uint256 public constant MAX_LEVERAGE = 20e18; // 20x
    uint256 public constant MIN_LEVERAGE = 1e18;  // 1x
    uint256 public constant TRADING_FEE_BPS = 10;  // 0.1% = 10 basis points
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant LEVERAGE_PRECISION = 1e18;

    // ============ Structs ============
    struct Position {
        bool isOpen;
        bool isLong;
        uint256 margin;     // collateral locked for this position
        uint256 leverage;   // e.g. 10e18 = 10x
        uint256 entryPrice; // price at position open
        uint256 size;       // notional size = margin * leverage / LEVERAGE_PRECISION
    }

    struct GlobalConfig {
        uint256 liquidationThreshold; // in bps, e.g. 8000 = 80%
        uint256 liquidationPenalty;   // in bps, e.g. 500 = 5%
        uint256 fundingRate;          // per-second funding rate (scaled)
        uint256 maxPositionSize;      // max notional per position
    }

    // ============ State Variables ============
    IERC20 public immutable collateralToken;
    address public operator;
    GlobalConfig public config;

    uint256 private _locked = 1; // Reentrancy guard

    mapping(address => uint256) public accountBalances; // free collateral
    mapping(address => Position) public positions;      // one position per account

    uint256 public totalCollateral;
    uint256 public totalPositionNotional;
    uint256 public accumulatedFunding; // global funding index

    // ============ Events ============
    event CollateralDeposited(address indexed account, uint256 amount);
    event CollateralWithdrawn(address indexed account, uint256 amount, address to);
    event PositionOpened(
        address indexed account,
        bool isLong,
        uint256 margin,
        uint256 leverage,
        uint256 entryPrice,
        uint256 size,
        uint256 fee
    );
    event PositionClosed(
        address indexed account,
        bool isLong,
        uint256 margin,
        uint256 exitPrice,
        int256 pnl,
        uint256 fee
    );
    event LeverageAdjusted(address indexed account, uint256 oldLeverage, uint256 newLeverage);
    event PositionLiquidated(
        address indexed account,
        address indexed liquidator,
        uint256 margin,
        uint256 price,
        uint256 penalty
    );
    event ConfigUpdated(
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 fundingRate,
        uint256 maxPositionSize
    );
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier positionOpen(address account) {
        if (!positions[account].isOpen) revert PositionNotOpen();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Constructor ============
    constructor(address _collateralToken, address _operator) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;

        config = GlobalConfig({
            liquidationThreshold: 8000, // 80%
            liquidationPenalty: 500,    // 5%
            fundingRate: 0,
            maxPositionSize: 1_000_000e18
        });
    }

    // ============ External Functions ============

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralToken.transferFrom(msg.sender, address(this), amount))
            revert InsufficientBalance();

        accountBalances[msg.sender] += amount;
        totalCollateral += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdraw(uint256 amount, address to) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (accountBalances[msg.sender] < amount) revert InsufficientFreeCollateral();

        // Effects
        accountBalances[msg.sender] -= amount;
        totalCollateral -= amount;

        // Interactions
        if (!collateralToken.transfer(to, amount)) revert InsufficientBalance();

        emit CollateralWithdrawn(msg.sender, amount, to);
    }

    function openPosition(
        bool isLong,
        uint256 margin,
        uint256 leverage,
        uint256 entryPrice
    ) external nonReentrant {
        if (margin == 0) revert ZeroAmount();
        if (leverage < MIN_LEVERAGE || leverage > MAX_LEVERAGE)
            revert LeverageTooHigh(leverage, MAX_LEVERAGE);
        if (entryPrice == 0) revert InvalidParameter();
        if (positions[msg.sender].isOpen) revert PositionAlreadyOpen();

        if (accountBalances[msg.sender] < margin) revert InsufficientFreeCollateral();

        uint256 size = (margin * leverage) / LEVERAGE_PRECISION;
        if (size > config.maxPositionSize) revert InvalidParameter();

        // Fix divide-before-multiply: compute fee from raw values to preserve precision.
        // fee = size * TRADING_FEE_BPS / BPS_DENOMINATOR
        //     = (margin * leverage / LEVERAGE_PRECISION) * TRADING_FEE_BPS / BPS_DENOMINATOR
        //     = (margin * leverage * TRADING_FEE_BPS) / (LEVERAGE_PRECISION * BPS_DENOMINATOR)
        uint256 fee = (margin * leverage * TRADING_FEE_BPS) /
            (LEVERAGE_PRECISION * BPS_DENOMINATOR);
        uint256 totalNeeded = margin + fee;

        if (accountBalances[msg.sender] < totalNeeded) revert InsufficientFreeCollateral();

        // Effects
        accountBalances[msg.sender] -= totalNeeded;
        totalCollateral -= fee; // fee stays in contract as protocol revenue

        positions[msg.sender] = Position({
            isOpen: true,
            isLong: isLong,
            margin: margin,
            leverage: leverage,
            entryPrice: entryPrice,
            size: size
        });

        totalPositionNotional += size;

        emit PositionOpened(msg.sender, isLong, margin, leverage, entryPrice, size, fee);
    }

    function closePosition(uint256 exitPrice)
        external
        nonReentrant
        positionOpen(msg.sender)
        returns (int256 pnl)
    {
        Position storage pos = positions[msg.sender];
        if (exitPrice == 0) revert InvalidParameter();

        pnl = _calculatePnl(pos, exitPrice);

        uint256 fee = (pos.size * TRADING_FEE_BPS) / BPS_DENOMINATOR;

        int256 settlement = int256(pos.margin) + pnl - int256(fee);

        // Cache values before deleting
        bool _isLong = pos.isLong;
        uint256 _margin = pos.margin;
        uint256 _size = pos.size;

        // Effects
        totalPositionNotional -= _size;
        delete positions[msg.sender];

        if (settlement > 0) {
            uint256 payout = uint256(settlement);
            uint256 contractBal = collateralToken.balanceOf(address(this));
            if (payout > contractBal) payout = contractBal;
            accountBalances[msg.sender] += payout;
        }

        emit PositionClosed(msg.sender, _isLong, _margin, exitPrice, pnl, fee);
    }

    function adjustLeverage(uint256 newLeverage, uint256 currentPrice)
        external
        nonReentrant
        positionOpen(msg.sender)
    {
        if (newLeverage < MIN_LEVERAGE || newLeverage > MAX_LEVERAGE)
            revert LeverageTooHigh(newLeverage, MAX_LEVERAGE);
        if (currentPrice == 0) revert InvalidParameter();

        Position storage pos = positions[msg.sender];
        uint256 oldLeverage = pos.leverage;

        uint256 newSize = (pos.margin * newLeverage) / LEVERAGE_PRECISION;
        if (newSize > config.maxPositionSize) revert InvalidParameter();

        int256 pnl = _calculatePnl(pos, currentPrice);
        int256 effectiveMargin = int256(pos.margin) + pnl;
        if (effectiveMargin <= 0) revert NotUndercollateralized();

        // Fix divide-before-multiply: compute maintenance margin from raw values.
        // maintenanceMargin = newSize * liquidationThreshold / BPS_DENOMINATOR
        //                   = (pos.margin * newLeverage / LEVERAGE_PRECISION) * liquidationThreshold / BPS_DENOMINATOR
        //                   = (pos.margin * newLeverage * liquidationThreshold) / (LEVERAGE_PRECISION * BPS_DENOMINATOR)
        uint256 maintenanceMargin = (pos.margin * newLeverage * config.liquidationThreshold) /
            (LEVERAGE_PRECISION * BPS_DENOMINATOR);
        if (uint256(effectiveMargin) < maintenanceMargin)
            revert NotUndercollateralized();

        // Effects
        totalPositionNotional = totalPositionNotional - pos.size + newSize;
        pos.leverage = newLeverage;
        pos.size = newSize;

        emit LeverageAdjusted(msg.sender, oldLeverage, newLeverage);
    }

    // ============ Operator Functions ============

    function updateConfig(
        uint256 _liquidationThreshold,
        uint256 _liquidationPenalty,
        uint256 _fundingRate,
        uint256 _maxPositionSize
    ) external onlyOperator {
        if (_liquidationThreshold == 0 || _liquidationThreshold > BPS_DENOMINATOR)
            revert InvalidParameter();
        if (_liquidationPenalty > BPS_DENOMINATOR) revert InvalidParameter();
        if (_maxPositionSize == 0) revert InvalidParameter();

        config.liquidationThreshold = _liquidationThreshold;
        config.liquidationPenalty = _liquidationPenalty;
        config.fundingRate = _fundingRate;
        config.maxPositionSize = _maxPositionSize;

        emit ConfigUpdated(
            _liquidationThreshold,
            _liquidationPenalty,
            _fundingRate,
            _maxPositionSize
        );
    }

    function liquidate(address account, uint256 currentPrice)
        external
        nonReentrant
        onlyOperator
    {
        if (account == msg.sender) revert SelfLiquidation();
        Position storage pos = positions[account];
        if (!pos.isOpen) revert PositionNotFound();
        if (currentPrice == 0) revert InvalidParameter();

        int256 pnl = _calculatePnl(pos, currentPrice);
        int256 effectiveMargin = int256(pos.margin) + pnl;

        uint256 maintenanceMargin = (pos.size * config.liquidationThreshold) /
            BPS_DENOMINATOR;
        if (effectiveMargin >= int256(maintenanceMargin))
            revert NotUndercollateralized();

        uint256 penalty = (pos.margin * config.liquidationPenalty) / BPS_DENOMINATOR;

        // Cache values for event before mutating state
        uint256 _margin = pos.margin;
        uint256 _size = pos.size;

        // Effects: update all state before external interaction
        totalPositionNotional -= _size;

        uint256 remaining = _margin > penalty ? _margin - penalty : 0;
        if (remaining > 0) {
            accountBalances[account] += remaining;
        }

        delete positions[account];

        // Interactions: transfer penalty to liquidator after all state is settled
        if (penalty > 0) {
            if (!collateralToken.transfer(msg.sender, penalty))
                revert InsufficientBalance();
        }

        emit PositionLiquidated(account, msg.sender, _margin, currentPrice, penalty);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function withdrawFees(address to, uint256 amount) external nonReentrant onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!collateralToken.transfer(to, amount)) revert InsufficientBalance();
    }

    // ============ View Functions ============

    function getPosition(address account) external view returns (Position memory) {
        return positions[account];
    }

    function getFreeCollateral(address account) external view returns (uint256) {
        return accountBalances[account];
    }

    function getPnl(address account, uint256 currentPrice) external view returns (int256) {
        Position storage pos = positions[account];
        if (!pos.isOpen) return 0;
        return _calculatePnl(pos, currentPrice);
    }

    function isLiquidatable(address account, uint256 currentPrice)
        external
        view
        returns (bool)
    {
        Position storage pos = positions[account];
        if (!pos.isOpen) return false;
        int256 pnl = _calculatePnl(pos, currentPrice);
        int256 effectiveMargin = int256(pos.margin) + pnl;
        uint256 maintenanceMargin = (pos.size * config.liquidationThreshold) /
            BPS_DENOMINATOR;
        return effectiveMargin < int256(maintenanceMargin);
    }

    function getTradingFee(uint256 notional) external pure returns (uint256) {
        return (notional * TRADING_FEE_BPS) / BPS_DENOMINATOR;
    }

    // ============ Internal Functions ============

    function _calculatePnl(Position storage pos, uint256 currentPrice)
        internal
        view
        returns (int256)
    {
        if (pos.isLong) {
            // PnL = size * (currentPrice - entryPrice) / entryPrice
            if (currentPrice >= pos.entryPrice) {
                return int256(
                    (pos.size * (currentPrice - pos.entryPrice)) / pos.entryPrice
                );
            } else {
                return -int256(
                    (pos.size * (pos.entryPrice - currentPrice)) / pos.entryPrice
                );
            }
        } else {
            // Short: PnL = size * (entryPrice - currentPrice) / entryPrice
            if (pos.entryPrice >= currentPrice) {
                return int256(
                    (pos.size * (pos.entryPrice - currentPrice)) / pos.entryPrice
                );
            } else {
                return -int256(
                    (pos.size * (currentPrice - pos.entryPrice)) / pos.entryPrice
                );
            }
        }
    }
}
