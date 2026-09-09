// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title SyntheticDex
 * @notice Decentralized exchange for synthetic assets backed by a single collateral token.
 *
 * Users deposit collateral, then open long or short positions on registered synthetic
 * asset markets. Profit and loss are realized against an operator-published oracle price
 * and a protocol reserve that funds winning payouts. A flat 0.1% fee is applied to the
 * notional value of every trade (both opens and closes). The maximum leverage for any
 * market is capped at 50x and may be tightened per-market by the operator.
 */
contract SyntheticDex {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MAX_LEVERAGE = 50;       // absolute cap, 50x
    uint256 public constant FEE_BPS = 10;             // 0.1% = 10 basis points
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;   // prices are 18-decimal

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------
    struct Market {
        bool exists;
        uint256 maxLeverage; // integer leverage (e.g. 50 == 50x)
        uint256 price;        // 18-decimal price per one synthetic unit
    }

    struct Position {
        bool isOpen;
        bool isLong;
        uint256 size;       // synthetic units exposed (18 decimals)
        uint256 entryPrice; // 18-decimal price at open
        uint256 margin;     // collateral locked for this position
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    IERC20 public immutable collateralToken;
    address public operator;

    mapping(address => uint256) public collateralBalances;  // free collateral per user
    mapping(address => uint256) public lockedCollateral;     // collateral locked in open positions
    mapping(address => Market) public markets;               // asset => market config
    mapping(address => mapping(address => Position)) public positions; // user => asset => position

    uint256 public collectedFees;    // fees available for operator to claim
    uint256 public protocolReserve;  // reserve used to settle profitable closes

    bool public paused;
    uint256 private _locked; // reentrancy guard

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed recipient, uint256 amount);
    event PositionOpened(
        address indexed user,
        address indexed asset,
        bool isLong,
        uint256 size,
        uint256 entryPrice,
        uint256 margin,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        address indexed asset,
        bool isLong,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 settlement,
        uint256 fee
    );
    event MarketAdded(address indexed asset, uint256 maxLeverage, uint256 initialPrice);
    event MaxLeverageUpdated(address indexed asset, uint256 oldLeverage, uint256 newLeverage);
    event PriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice);
    event Paused(address account);
    event Unpaused(address account);
    event ReserveDeposited(address indexed sender, uint256 amount);
    event ReserveWithdrawn(address indexed recipient, uint256 amount);
    event FeesClaimed(address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error MarketDoesNotExist(address asset);
    error MarketAlreadyExists(address asset);
    error PositionAlreadyOpen(address user, address asset);
    error NoOpenPosition(address user, address asset);
    error InsufficientAvailableCollateral(uint256 available, uint256 required);
    error LeverageExceedsMax(uint256 leverage, uint256 maxLeverage);
    error InvalidLeverage();
    error InsufficientFees(uint256 available, uint256 required);
    error InsufficientReserve(uint256 available, uint256 required);
    error EnforcedPause();
    error ExpectedPause();
    error ReentrantCall();
    error TransferFailed();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 2;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _collateralToken, address _operator) {
        if (_collateralToken == address(0) || _operator == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    // -----------------------------------------------------------------------
    // Internal safe transfer helpers
    // -----------------------------------------------------------------------
    function _safeTransfer(address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(collateralToken).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(collateralToken).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    // -----------------------------------------------------------------------
    // Internal math helpers (avoid divide-before-multiply)
    // -----------------------------------------------------------------------
    /**
     * @notice Computes the notional value of `size` units at `price`.
     * @dev notional = (size * price) / PRICE_PRECISION
     */
    function _notional(uint256 size, uint256 price) internal pure returns (uint256) {
        return (size * price) / PRICE_PRECISION;
    }

    /**
     * @notice Computes the trading fee directly from the raw product to avoid
     *         truncation from an intermediate division.
     * @dev fee = (size * price * FEE_BPS) / (PRICE_PRECISION * BPS_DENOMINATOR)
     */
    function _feeFromRaw(uint256 size, uint256 price) internal pure returns (uint256) {
        return (size * price * FEE_BPS) / (PRICE_PRECISION * BPS_DENOMINATOR);
    }

    // -----------------------------------------------------------------------
    // Collateral management
    // -----------------------------------------------------------------------
    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        collateralBalances[msg.sender] += amount;
        _safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount, address recipient) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        uint256 available = collateralBalances[msg.sender] - lockedCollateral[msg.sender];
        if (amount > available) revert InsufficientAvailableCollateral(available, amount);
        collateralBalances[msg.sender] -= amount;
        _safeTransfer(recipient, amount);
        emit CollateralWithdrawn(msg.sender, recipient, amount);
    }

    function availableCollateral(address user) external view returns (uint256) {
        return collateralBalances[user] - lockedCollateral[user];
    }

    // -----------------------------------------------------------------------
    // Trading
    // -----------------------------------------------------------------------
    function openPosition(address asset, bool isLong, uint256 size, uint256 leverage)
        external
        nonReentrant
        whenNotPaused
    {
        Market storage m = markets[asset];
        if (!m.exists) revert MarketDoesNotExist(asset);
        if (size == 0) revert ZeroAmount();
        if (leverage == 0) revert InvalidLeverage();
        if (leverage > m.maxLeverage) revert LeverageExceedsMax(leverage, m.maxLeverage);
        if (positions[msg.sender][asset].isOpen) revert PositionAlreadyOpen(msg.sender, asset);

        uint256 price = m.price;
        uint256 notional = _notional(size, price);
        uint256 margin = notional / leverage;
        // Compute fee directly from the raw product to avoid divide-before-multiply.
        uint256 fee = _feeFromRaw(size, price);
        uint256 required = margin + fee;

        uint256 available = collateralBalances[msg.sender] - lockedCollateral[msg.sender];
        if (available < required) revert InsufficientAvailableCollateral(available, required);

        // Effects: lock margin, take fee from the user's free collateral.
        lockedCollateral[msg.sender] += margin;
        collateralBalances[msg.sender] -= fee;
        collectedFees += fee;

        positions[msg.sender][asset] = Position({
            isOpen: true,
            isLong: isLong,
            size: size,
            entryPrice: price,
            margin: margin
        });

        emit PositionOpened(msg.sender, asset, isLong, size, price, margin, fee);
    }

    function closePosition(address asset) external nonReentrant whenNotPaused {
        Position storage p = positions[msg.sender][asset];
        if (!p.isOpen) revert NoOpenPosition(msg.sender, asset);
        Market storage m = markets[asset];

        uint256 exitPrice = m.price;
        uint256 notional = _notional(p.size, exitPrice);
        // Compute fee directly from the raw product to avoid divide-before-multiply.
        uint256 fee = _feeFromRaw(p.size, exitPrice);

        // PnL in 18-decimal collateral terms.
        int256 pnl;
        if (p.isLong) {
            pnl = int256((p.size * exitPrice) / PRICE_PRECISION) -
                  int256((p.size * p.entryPrice) / PRICE_PRECISION);
        } else {
            pnl = int256((p.size * p.entryPrice) / PRICE_PRECISION) -
                  int256((p.size * exitPrice) / PRICE_PRECISION);
        }

        // Effects: unlock the margin first.
        lockedCollateral[msg.sender] -= p.margin;

        uint256 settlement = p.margin;
        if (pnl > 0) {
            // Pay profit from the protocol reserve (capped).
            uint256 profit = uint256(pnl);
            uint256 payProfit = profit > protocolReserve ? protocolReserve : profit;
            protocolReserve -= payProfit;
            collateralBalances[msg.sender] += payProfit;
            settlement += payProfit;
        } else if (pnl < 0) {
            // Realize loss; capped at the locked margin. Loss stays in the contract.
            uint256 loss = uint256(-pnl);
            if (loss > p.margin) loss = p.margin;
            collateralBalances[msg.sender] -= loss;
            protocolReserve += loss;
            settlement -= loss;
        }

        // Charge the closing fee from the user's available collateral (capped).
        uint256 available = collateralBalances[msg.sender] - lockedCollateral[msg.sender];
        uint256 feeTaken = fee > available ? available : fee;
        collateralBalances[msg.sender] -= feeTaken;
        collectedFees += feeTaken;

        bool wasLong = p.isLong;
        uint256 closedSize = p.size;
        delete positions[msg.sender][asset];

        emit PositionClosed(msg.sender, asset, wasLong, closedSize, exitPrice, pnl, settlement, feeTaken);
    }

    // -----------------------------------------------------------------------
    // Operator: market configuration
    // -----------------------------------------------------------------------
    function addMarket(address asset, uint256 maxLeverage, uint256 initialPrice)
        external
        onlyOperator
    {
        if (asset == address(0)) revert ZeroAddress();
        if (markets[asset].exists) revert MarketAlreadyExists(asset);
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (initialPrice == 0) revert ZeroAmount();
        markets[asset] = Market({
            exists: true,
            maxLeverage: maxLeverage,
            price: initialPrice
        });
        emit MarketAdded(asset, maxLeverage, initialPrice);
    }

    function setMaxLeverage(address asset, uint256 newLeverage) external onlyOperator {
        if (!markets[asset].exists) revert MarketDoesNotExist(asset);
        if (newLeverage == 0 || newLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        uint256 old = markets[asset].maxLeverage;
        markets[asset].maxLeverage = newLeverage;
        emit MaxLeverageUpdated(asset, old, newLeverage);
    }

    function setPrice(address asset, uint256 newPrice) external onlyOperator {
        if (!markets[asset].exists) revert MarketDoesNotExist(asset);
        if (newPrice == 0) revert ZeroAmount();
        uint256 old = markets[asset].price;
        markets[asset].price = newPrice;
        emit PriceUpdated(asset, old, newPrice);
    }

    function pauseTrading() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpauseTrading() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // -----------------------------------------------------------------------
    // Operator: reserve & fees
    // -----------------------------------------------------------------------
    function depositReserve(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        protocolReserve += amount;
        _safeTransferFrom(msg.sender, address(this), amount);
        emit ReserveDeposited(msg.sender, amount);
    }

    function withdrawReserve(address recipient, uint256 amount) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > protocolReserve) revert InsufficientReserve(protocolReserve, amount);
        protocolReserve -= amount;
        _safeTransfer(recipient, amount);
        emit ReserveWithdrawn(recipient, amount);
    }

    function claimFees(address recipient, uint256 amount) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > collectedFees) revert InsufficientFees(collectedFees, amount);
        collectedFees -= amount;
        _safeTransfer(recipient, amount);
        emit FeesClaimed(recipient, amount);
    }

    // -----------------------------------------------------------------------
    // Operator: admin
    // -----------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------
    function getMarket(address asset)
        external
        view
        returns (bool exists, uint256 maxLeverage, uint256 price)
    {
        Market storage m = markets[asset];
        return (m.exists, m.maxLeverage, m.price);
    }

    function getPosition(address user, address asset)
        external
        view
        returns (bool isOpen, bool isLong, uint256 size, uint256 entryPrice, uint256 margin)
    {
        Position storage p = positions[user][asset];
        return (p.isOpen, p.isLong, p.size, p.entryPrice, p.margin);
    }
}
