// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPriceOracle {
    function getPrice() external view returns (uint256);
    function lastUpdated() external view returns (uint256);
}

contract PerpetualExchange {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant LEVERAGE_PRECISION = 1e18;
    uint256 public constant MAX_LEVERAGE = 50e18;
    uint256 public constant DEFAULT_FEE_RATE_BPS = 10;
    uint256 public constant MAX_FEE_RATE_BPS = 1_000;
    uint256 public constant STALE_PRICE_THRESHOLD = 1 hours;
    uint256 public constant FUNDING_PRECISION = 1e18;
    uint256 public constant MAX_FUNDING_RATE = 1e16;

    IERC20 public immutable collateralToken;

    IPriceOracle public oracle;
    address public operator;
    bool public paused;
    uint256 public feeRateBps;
    uint256 public fundingRate;
    uint256 public lastFundingUpdate;
    uint256 public accumulatedFees;
    uint256 public totalReservedMargin;

    struct Position {
        bool exists;
        bool isLong;
        uint256 size;
        uint256 margin;
        uint256 entryPrice;
        uint256 lastFundingTime;
    }

    mapping(address => uint256) public availableBalance;
    mapping(address => Position) public positions;

    event Deposit(address indexed account, address indexed asset, uint256 amount);
    event Withdraw(address indexed account, address indexed asset, uint256 amount);
    event PositionOpened(
        address indexed account,
        address indexed asset,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 leverage,
        uint256 entryPrice,
        uint256 fee
    );
    event PositionClosed(
        address indexed account,
        address indexed asset,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 exitPrice,
        int256 pnl,
        int256 fundingPayment,
        uint256 feePaid,
        uint256 returned
    );
    event FeeRateUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event OracleUpdated(address indexed operator, address oldOracle, address newOracle);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event TradingPausedEvent(address indexed operator);
    event TradingUnpausedEvent(address indexed operator);
    event FundingRateUpdated(address indexed operator, uint256 oldRate, uint256 newRate);
    event FeesCollected(address indexed operator, address indexed to, uint256 amount);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error TradingIsPaused();
    error InsufficientAvailable();
    error InsufficientBalance();
    error PositionAlreadyExists();
    error NoPosition();
    error InvalidLeverage();
    error InvalidMargin();
    error StalePrice();
    error FeeExceedsMax();
    error FundingRateExceedsMax();
    error NotOperator();
    error TransferFailed();
    error InvalidPrice();
    error CannotRescueCollateral();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingIsPaused();
        _;
    }

    constructor(
        address collateralToken_,
        address oracle_,
        address operator_
    ) {
        if (collateralToken_ == address(0)) revert ZeroAddress();
        if (oracle_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        collateralToken = IERC20(collateralToken_);
        oracle = IPriceOracle(oracle_);
        operator = operator_;
        feeRateBps = DEFAULT_FEE_RATE_BPS;
        lastFundingUpdate = block.timestamp;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        availableBalance[msg.sender] += amount;
        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit Deposit(msg.sender, address(collateralToken), amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = availableBalance[msg.sender];
        if (bal < amount) revert InsufficientAvailable();
        availableBalance[msg.sender] = bal - amount;
        bool ok = collateralToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit Withdraw(msg.sender, address(collateralToken), amount);
    }

    function openPosition(bool isLong, uint256 margin, uint256 leverage)
        external
        whenNotPaused
    {
        if (margin == 0) revert InvalidMargin();
        if (leverage == 0 || leverage > MAX_LEVERAGE) revert InvalidLeverage();

        Position storage p = positions[msg.sender];
        if (p.exists) revert PositionAlreadyExists();

        uint256 size = (margin * leverage) / LEVERAGE_PRECISION;
        uint256 fee = (size * feeRateBps) / BPS_DENOMINATOR;
        uint256 totalNeeded = margin + fee;
        if (availableBalance[msg.sender] < totalNeeded) revert InsufficientAvailable();

        uint256 price = _getPrice();

        availableBalance[msg.sender] -= totalNeeded;
        totalReservedMargin += margin;
        accumulatedFees += fee;

        p.exists = true;
        p.isLong = isLong;
        p.size = size;
        p.margin = margin;
        p.entryPrice = price;
        p.lastFundingTime = block.timestamp;

        emit PositionOpened(
            msg.sender,
            address(collateralToken),
            isLong,
            size,
            margin,
            leverage,
            price,
            fee
        );
    }

    function closePosition() external whenNotPaused {
        Position storage p = positions[msg.sender];
        if (!p.exists) revert NoPosition();

        uint256 price = _getPrice();
        int256 pnl = _getPnl(p, price);
        int256 fundingPayment = _getPendingFunding(p, block.timestamp);
        int256 marginAdjustment = p.isLong ? -fundingPayment : fundingPayment;
        int256 netMargin = int256(p.margin) + pnl + marginAdjustment;

        uint256 nominalFee = (p.size * feeRateBps) / BPS_DENOMINATOR;
        uint256 feePaid;
        uint256 returned;
        if (netMargin <= 0) {
            feePaid = 0;
            returned = 0;
        } else {
            uint256 nm = uint256(netMargin);
            if (nm >= nominalFee) {
                returned = nm - nominalFee;
                feePaid = nominalFee;
            } else {
                returned = 0;
                feePaid = nm;
            }
        }

        bool wasLong = p.isLong;
        uint256 sizeCopy = p.size;
        uint256 marginCopy = p.margin;

        totalReservedMargin -= marginCopy;
        accumulatedFees += feePaid;
        if (returned > 0) {
            availableBalance[msg.sender] += returned;
        }

        delete positions[msg.sender];

        emit PositionClosed(
            msg.sender,
            address(collateralToken),
            wasLong,
            sizeCopy,
            marginCopy,
            price,
            pnl,
            marginAdjustment,
            feePaid,
            returned
        );
    }

    function setFeeRate(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_RATE_BPS) revert FeeExceedsMax();
        uint256 old = feeRateBps;
        feeRateBps = newFeeBps;
        emit FeeRateUpdated(msg.sender, old, newFeeBps);
    }

    function updateOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IPriceOracle(newOracle);
        emit OracleUpdated(msg.sender, old, newOracle);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit TradingPausedEvent(msg.sender);
        } else {
            emit TradingUnpausedEvent(msg.sender);
        }
    }

    function setFundingRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_FUNDING_RATE) revert FundingRateExceedsMax();
        uint256 old = fundingRate;
        fundingRate = newRate;
        lastFundingUpdate = block.timestamp;
        emit FundingRateUpdated(msg.sender, old, newRate);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function collectFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        uint256 bal = collateralToken.balanceOf(address(this));
        if (bal == 0) revert InsufficientBalance();
        uint256 collectable = amount < bal ? amount : bal;
        accumulatedFees -= collectable;
        bool ok = collateralToken.transfer(to, collectable);
        if (!ok) revert TransferFailed();
        emit FeesCollected(msg.sender, to, collectable);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token == address(collateralToken)) revert CannotRescueCollateral();
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
        emit TokenRescued(token, to, amount);
    }

    function getPrice() external view returns (uint256) {
        return _getPrice();
    }

    function getPosition(address account) external view returns (Position memory) {
        return positions[account];
    }

    function getPnl(address account) external view returns (int256) {
        Position storage p = positions[account];
        if (!p.exists) return 0;
        uint256 price = oracle.getPrice();
        if (price == 0) return 0;
        return _getPnl(p, price);
    }

    function getPendingFunding(address account) external view returns (int256) {
        Position storage p = positions[account];
        if (!p.exists) return 0;
        return _getPendingFunding(p, block.timestamp);
    }

    function getPositionValue(address account) external view returns (int256) {
        Position storage p = positions[account];
        if (!p.exists) return 0;
        uint256 price = oracle.getPrice();
        if (price == 0) return int256(p.margin);
        int256 pnl = _getPnl(p, price);
        int256 fundingPayment = _getPendingFunding(p, block.timestamp);
        int256 marginAdjustment = p.isLong ? -fundingPayment : fundingPayment;
        return int256(p.margin) + pnl + marginAdjustment;
    }

    function getMarginRatio(address account) external view returns (uint256) {
        Position storage p = positions[account];
        if (!p.exists || p.size == 0) return 0;
        return (p.margin * LEVERAGE_PRECISION) / p.size;
    }

    function getLeverage(address account) external view returns (uint256) {
        Position storage p = positions[account];
        if (!p.exists || p.margin == 0) return 0;
        return (p.size * LEVERAGE_PRECISION) / p.margin;
    }

    function getLiquidationPrice(address account) external view returns (uint256) {
        Position storage p = positions[account];
        if (!p.exists || p.size == 0) return 0;
        uint256 delta = (p.entryPrice * p.margin) / p.size;
        if (p.isLong) {
            if (delta >= p.entryPrice) return 0;
            return p.entryPrice - delta;
        } else {
            return p.entryPrice + delta;
        }
    }

    function totalAccountValue(address account) external view returns (int256) {
        Position storage p = positions[account];
        int256 posValue = int256(p.margin);
        if (p.exists) {
            uint256 price = oracle.getPrice();
            if (price != 0) {
                int256 pnl = _getPnl(p, price);
                int256 fundingPayment = _getPendingFunding(p, block.timestamp);
                int256 marginAdjustment = p.isLong ? -fundingPayment : fundingPayment;
                posValue = int256(p.margin) + pnl + marginAdjustment;
            }
        }
        return int256(availableBalance[account]) + posValue;
    }

    function _getPrice() internal view returns (uint256) {
        uint256 lastUpd = oracle.lastUpdated();
        if (lastUpd == 0 || block.timestamp < lastUpd || block.timestamp - lastUpd > STALE_PRICE_THRESHOLD) {
            revert StalePrice();
        }
        uint256 price = oracle.getPrice();
        if (price == 0) revert InvalidPrice();
        return price;
    }

    function _getPnl(Position storage p, uint256 currentPrice) internal view returns (int256) {
        int256 priceDiff = int256(currentPrice) - int256(p.entryPrice);
        int256 pnl = (int256(p.size) * priceDiff) / int256(p.entryPrice);
        return p.isLong ? pnl : -pnl;
    }

    function _getPendingFunding(Position storage p, uint256 atTime) internal view returns (int256) {
        if (!p.exists) return 0;
        uint256 elapsed = atTime > p.lastFundingTime ? atTime - p.lastFundingTime : 0;
        if (elapsed == 0) return 0;
        return int256((p.size * fundingRate * elapsed) / FUNDING_PRECISION);
    }
}
