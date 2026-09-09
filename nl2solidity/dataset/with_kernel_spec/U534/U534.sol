// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "REENTRANT");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title PerpetualFuturesExchange
 * @notice Manages collateral and leveraged long/short positions for a perpetual
 *         futures exchange. Users deposit ERC20 collateral, open positions with
 *         up to 100x leverage, close positions, and withdraw available collateral.
 *         A designated operator updates per-pair funding rates and maximum leverage.
 */
contract PerpetualFuturesExchange is ReentrancyGuard {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_LEVERAGE_CAP = 100e18; // 100x hard cap (1e18 scaled)
    uint256 public constant FEE_RATE = 1e15;           // 0.1% (0.001 * 1e18)
    uint256 public constant PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // Immutable / configurable
    // ---------------------------------------------------------------------
    IERC20 public immutable collateralToken;
    address public operator;
    address public feeRecipient;

    // ---------------------------------------------------------------------
    // Position struct
    // ---------------------------------------------------------------------
    struct Position {
        address trader;
        bytes32 pair;
        bool isLong;
        uint256 size;         // notional in collateral terms
        uint256 entryPrice;   // 1e18 scaled
        uint256 margin;       // locked collateral (excl. fee)
        int256 fundingIndex;  // cumulative funding index at open
        bool isOpen;
    }

    // ---------------------------------------------------------------------
    // User accounting
    //   collateralBalance = free (unlocked) balance
    //   lockedCollateral  = margin currently locked in open positions
    // ---------------------------------------------------------------------
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public lockedCollateral;

    // ---------------------------------------------------------------------
    // Per-pair configuration and state
    // ---------------------------------------------------------------------
    mapping(bytes32 => int256) public fundingRatePerSecond; // 1e18 scaled, signed
    mapping(bytes32 => int256) public fundingIndex;         // cumulative, 1e18 scaled
    mapping(bytes32 => uint256) public lastFundingUpdate;
    mapping(bytes32 => uint256) public maxLeverage;         // 1e18 scaled
    mapping(bytes32 => uint256) public lastPrice;           // 1e18 scaled oracle price
    mapping(bytes32 => bool) internal _pairFundingInitialized;

    // ---------------------------------------------------------------------
    // Positions
    // ---------------------------------------------------------------------
    mapping(uint256 => Position) internal _positions;
    uint256 public positionIdCounter;
    mapping(address => uint256[]) internal _userPositionIds;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event PositionOpened(
        uint256 indexed positionId,
        address indexed trader,
        bytes32 indexed pair,
        bool isLong,
        uint256 size,
        uint256 entryPrice,
        uint256 margin,
        uint256 fee
    );
    event PositionClosed(
        uint256 indexed positionId,
        address indexed trader,
        bytes32 indexed pair,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 fee
    );
    event FundingRateUpdated(bytes32 indexed pair, int256 newRatePerSecond, int256 newFundingIndex);
    event MaxLeverageUpdated(bytes32 indexed pair, uint256 newMaxLeverage);
    event PriceUpdated(bytes32 indexed pair, uint256 price);
    event OperatorUpdated(address indexed newOperator);
    event FeeRecipientUpdated(address indexed newFeeRecipient);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error ZeroAmount();
    error InsufficientAvailable();
    error InvalidLeverage();
    error InvalidPrice();
    error PositionNotOpen();
    error NotPositionOwner();
    error PairNotInitialized();
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address collateralToken_, address operator_, address feeRecipient_) {
        if (collateralToken_ == address(0) || operator_ == address(0) || feeRecipient_ == address(0)) {
            revert ZeroAmount();
        }
        collateralToken = IERC20(collateralToken_);
        operator = operator_;
        feeRecipient = feeRecipient_;
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _toInt256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "INT_OVERFLOW");
        return int256(value);
    }

    function _accumulateFunding(bytes32 pair) internal {
        // Use a dedicated boolean flag rather than strict equality on the
        // timestamp to determine first-time initialization.
        if (!_pairFundingInitialized[pair]) {
            _pairFundingInitialized[pair] = true;
            lastFundingUpdate[pair] = block.timestamp;
            return;
        }
        uint256 last = lastFundingUpdate[pair];
        // Guard against no time elapsed using a range comparison instead of
        // a strict equality on the computed difference.
        if (block.timestamp <= last) {
            return;
        }
        // At this point block.timestamp > last, so elapsed is guaranteed > 0.
        uint256 elapsed = block.timestamp - last;
        int256 rate = fundingRatePerSecond[pair];
        if (rate != 0) {
            int256 delta = (rate * _toInt256(elapsed)) / int256(PRECISION);
            fundingIndex[pair] = fundingIndex[pair] + delta;
        }
        lastFundingUpdate[pair] = block.timestamp;
    }

    function _computePricePnl(
        uint256 size,
        uint256 entryPrice,
        uint256 exitPrice,
        bool isLong
    ) internal pure returns (int256) {
        if (isLong) {
            if (exitPrice >= entryPrice) {
                return int256((size * (exitPrice - entryPrice)) / entryPrice);
            }
            return -int256((size * (entryPrice - exitPrice)) / entryPrice);
        } else {
            if (entryPrice >= exitPrice) {
                return int256((size * (entryPrice - exitPrice)) / entryPrice);
            }
            return -int256((size * (exitPrice - entryPrice)) / entryPrice);
        }
    }

    function _chargeFee(uint256 amount) internal {
        // Use a positive range check instead of strict equality to guard the
        // no-op case.
        if (amount > 0) {
            if (!collateralToken.transfer(feeRecipient, amount)) revert TransferFailed();
        }
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    /// @notice Returns the free (unlocked) collateral available for withdrawal or new positions.
    function availableCollateral(address user) public view returns (uint256) {
        return collateralBalance[user];
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return _positions[positionId];
    }

    function getUserPositionIds(address user) external view returns (uint256[] memory) {
        return _userPositionIds[user];
    }

    function getFundingState(bytes32 pair) external view returns (int256 rate, int256 index, uint256 lastUpdate) {
        return (fundingRatePerSecond[pair], fundingIndex[pair], lastFundingUpdate[pair]);
    }

    // ---------------------------------------------------------------------
    // Collateral management
    // ---------------------------------------------------------------------

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        collateralBalance[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (availableCollateral(msg.sender) < amount) revert InsufficientAvailable();
        collateralBalance[msg.sender] -= amount;
        if (!collateralToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Position management
    // ---------------------------------------------------------------------

    function openPosition(
        bytes32 pair,
        bool isLong,
        uint256 margin,
        uint256 leverage
    ) external nonReentrant {
        uint256 maxLev = maxLeverage[pair];
        if (maxLev == 0) revert PairNotInitialized();
        if (margin == 0) revert ZeroAmount();
        if (leverage == 0 || leverage > maxLev || leverage > MAX_LEVERAGE_CAP) revert InvalidLeverage();

        _accumulateFunding(pair);

        uint256 price = lastPrice[pair];
        if (price == 0) revert InvalidPrice();

        uint256 size = (margin * leverage) / PRECISION;
        // Fix: compute the fee directly from the unrounded product to avoid
        // the divide-before-multiply pattern (size is a rounded value).
        // fee = (margin * leverage * FEE_RATE) / (PRECISION * PRECISION)
        uint256 fee = (margin * leverage * FEE_RATE) / (PRECISION * PRECISION);
        uint256 totalNeeded = margin + fee;
        if (availableCollateral(msg.sender) < totalNeeded) revert InsufficientAvailable();

        // Move margin from free balance into locked bucket and charge opening fee.
        // Checks-effects-interactions: update all accounting before the external
        // token transfer in _chargeFee.
        collateralBalance[msg.sender] -= totalNeeded;
        lockedCollateral[msg.sender] += margin;
        _chargeFee(fee);

        uint256 posId = ++positionIdCounter;
        _positions[posId] = Position({
            trader: msg.sender,
            pair: pair,
            isLong: isLong,
            size: size,
            entryPrice: price,
            margin: margin,
            fundingIndex: fundingIndex[pair],
            isOpen: true
        });
        _userPositionIds[msg.sender].push(posId);

        emit PositionOpened(posId, msg.sender, pair, isLong, size, price, margin, fee);
    }

    function closePosition(uint256 positionId) external nonReentrant {
        Position storage p = _positions[positionId];
        if (!p.isOpen) revert PositionNotOpen();
        if (p.trader != msg.sender) revert NotPositionOwner();

        _accumulateFunding(p.pair);

        uint256 exitPrice = lastPrice[p.pair];
        if (exitPrice == 0) revert InvalidPrice();

        // Price PnL
        int256 pricePnl = _computePricePnl(p.size, p.entryPrice, exitPrice, p.isLong);

        // Funding PnL: positive cumulative funding means longs pay shorts.
        int256 fundingDelta = fundingIndex[p.pair] - p.fundingIndex;
        int256 fundingPayment = (_toInt256(p.size) * fundingDelta) / int256(PRECISION);
        int256 traderFunding = p.isLong ? -fundingPayment : fundingPayment;

        int256 totalPnl = pricePnl + traderFunding;
        int256 settlement = _toInt256(p.margin) + totalPnl;

        uint256 grossPayout = settlement > 0 ? uint256(settlement) : 0;

        // Closing fee on notional size.
        uint256 fee = (p.size * FEE_RATE) / PRECISION;
        uint256 actualFee = fee > grossPayout ? grossPayout : fee;
        uint256 netPayout = grossPayout - actualFee;

        // Settle accounting before external transfer (checks-effects-interactions).
        lockedCollateral[msg.sender] -= p.margin;
        collateralBalance[msg.sender] += netPayout;
        p.isOpen = false;

        _chargeFee(actualFee);

        emit PositionClosed(positionId, msg.sender, p.pair, p.size, exitPrice, totalPnl, actualFee);
    }

    // ---------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------

    function initializePair(bytes32 pair, uint256 leverage, uint256 price) external onlyOperator {
        if (leverage == 0 || leverage > MAX_LEVERAGE_CAP) revert InvalidLeverage();
        if (price == 0) revert InvalidPrice();
        if (!_pairFundingInitialized[pair]) {
            _pairFundingInitialized[pair] = true;
            lastFundingUpdate[pair] = block.timestamp;
        }
        maxLeverage[pair] = leverage;
        lastPrice[pair] = price;
        emit MaxLeverageUpdated(pair, leverage);
        emit PriceUpdated(pair, price);
    }

    function updateFundingRate(bytes32 pair, int256 newRatePerSecond) external onlyOperator {
        if (!_pairFundingInitialized[pair]) revert PairNotInitialized();
        _accumulateFunding(pair);
        fundingRatePerSecond[pair] = newRatePerSecond;
        emit FundingRateUpdated(pair, newRatePerSecond, fundingIndex[pair]);
    }

    function setMaxLeverage(bytes32 pair, uint256 newMaxLeverage) external onlyOperator {
        if (newMaxLeverage == 0 || newMaxLeverage > MAX_LEVERAGE_CAP) revert InvalidLeverage();
        maxLeverage[pair] = newMaxLeverage;
        emit MaxLeverageUpdated(pair, newMaxLeverage);
    }

    function setPrice(bytes32 pair, uint256 price) external onlyOperator {
        if (price == 0) revert InvalidPrice();
        lastPrice[pair] = price;
        emit PriceUpdated(pair, price);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAmount();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAmount();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }
}
