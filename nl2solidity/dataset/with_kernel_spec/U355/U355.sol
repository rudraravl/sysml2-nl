// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

contract PredictionExchange {
    using SafeERC20 for IERC20;

    // --------------------------------------------------------------
    // Custom Errors
    // --------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidOutcomeCount();
    error InvalidOutcomeIndex();
    error InvalidWinningOutcome();
    error InvalidDescription();
    error MarketNotFound();
    error MarketAlreadySettled();
    error MarketNotSettled();
    error InsufficientBalance();
    error InsufficientOutcomeBalance();
    error OrderNotFound();
    error NotOrderOwner();
    error OrderNotActive();
    error OrderValueTooLow();
    error InvalidPrice();
    error CannotFillOwnOrder();
    error FillExceedsRemaining();
    error AlreadyClaimed();
    error NothingToClaim();
    error FeeTooHigh();
    error NoWinningSupply();

    // --------------------------------------------------------------
    // Constants
    // --------------------------------------------------------------
    uint256 public constant MAX_OUTCOMES = 2;
    uint256 public constant MIN_ORDER_VALUE = 100;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 internal constant UNSET_WINNING_OUTCOME = type(uint256).max;

    // --------------------------------------------------------------
    // State Variables
    // --------------------------------------------------------------
    address public operator;
    uint256 public marketCreationFeeBps;
    uint256 public nextMarketId = 1;
    uint256 public nextOrderId = 1;

    struct Market {
        address creator;
        address collateralToken;
        uint8 outcomeCount;
        uint256 winningOutcome;
        uint256 totalCollateral;
        uint256 winningSupply;
        bool settled;
        string description;
    }

    struct Order {
        uint256 marketId;
        address trader;
        bool isBuy;
        uint8 outcomeIndex;
        uint256 amount;
        uint256 price;
        uint256 filled;
        bool active;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => Order) public orders;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(uint256 => mapping(address => mapping(uint8 => uint256))) public outcomeBalances;
    mapping(uint256 => mapping(uint8 => uint256)) public totalOutcomeSupply;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    // --------------------------------------------------------------
    // Events
    // --------------------------------------------------------------
    event MarketCreated(uint256 indexed marketId, address indexed creator, address collateralToken, uint8 outcomeCount, string description);
    event CollateralDeposited(address indexed token, address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed token, address indexed user, uint256 amount);
    event PositionSplit(uint256 indexed marketId, address indexed user, uint256 amount);
    event OrderPlaced(uint256 indexed orderId, uint256 indexed marketId, address indexed trader, bool isBuy, uint8 outcomeIndex, uint256 amount, uint256 price);
    event OrderFilled(uint256 indexed orderId, address indexed filler, uint256 fillAmount);
    event OrderCancelled(uint256 indexed orderId, address indexed trader, uint256 refundAmount);
    event MarketSettled(uint256 indexed marketId, uint256 winningOutcome, uint256 fee);
    event ProceedsClaimed(uint256 indexed marketId, address indexed user, uint256 outcomeTokens, uint256 payout);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // --------------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (markets[marketId].collateralToken == address(0)) revert MarketNotFound();
        _;
    }

    // --------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        marketCreationFeeBps = 10; // 0.1%
        emit OperatorUpdated(address(0), _operator);
    }

    // --------------------------------------------------------------
    // Admin Functions
    // --------------------------------------------------------------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setMarketCreationFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > FEE_DENOMINATOR) revert FeeTooHigh();
        emit FeeUpdated(marketCreationFeeBps, newFeeBps);
        marketCreationFeeBps = newFeeBps;
    }

    // --------------------------------------------------------------
    // Collateral Escrow
    // --------------------------------------------------------------
    function deposit(address token, uint256 amount) external {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        collateralBalances[token][msg.sender] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 bal = collateralBalances[token][msg.sender];
        if (bal < amount) revert InsufficientBalance();
        collateralBalances[token][msg.sender] = bal - amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(token, msg.sender, amount);
    }

    // --------------------------------------------------------------
    // Market Lifecycle
    // --------------------------------------------------------------
    function createMarket(
        address collateralToken,
        uint8 outcomeCount,
        string calldata description
    ) external returns (uint256 marketId) {
        if (collateralToken == address(0)) revert ZeroAddress();
        if (outcomeCount == 0 || outcomeCount > MAX_OUTCOMES) revert InvalidOutcomeCount();
        if (bytes(description).length == 0) revert InvalidDescription();

        marketId = nextMarketId++;
        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.collateralToken = collateralToken;
        m.outcomeCount = outcomeCount;
        m.winningOutcome = UNSET_WINNING_OUTCOME;
        m.description = description;

        emit MarketCreated(marketId, msg.sender, collateralToken, outcomeCount, description);
    }

    function depositToMarket(uint256 marketId, uint256 amount) external marketExists(marketId) {
        if (amount == 0) revert ZeroAmount();
        Market storage m = markets[marketId];
        if (m.settled) revert MarketAlreadySettled();

        address token = m.collateralToken;
        uint256 bal = collateralBalances[token][msg.sender];
        if (bal < amount) revert InsufficientBalance();
        collateralBalances[token][msg.sender] = bal - amount;
        m.totalCollateral += amount;

        for (uint8 i = 0; i < m.outcomeCount; i++) {
            outcomeBalances[marketId][msg.sender][i] += amount;
            totalOutcomeSupply[marketId][i] += amount;
        }

        emit PositionSplit(marketId, msg.sender, amount);
    }

    // --------------------------------------------------------------
    // Order Book
    // --------------------------------------------------------------
    function placeOrder(
        uint256 marketId,
        bool isBuy,
        uint8 outcomeIndex,
        uint256 amount,
        uint256 price
    ) external marketExists(marketId) returns (uint256 orderId) {
        Market storage m = markets[marketId];
        if (m.settled) revert MarketAlreadySettled();
        if (outcomeIndex >= m.outcomeCount) revert InvalidOutcomeIndex();
        if (amount == 0) revert ZeroAmount();
        if (price == 0 || price > PRICE_PRECISION) revert InvalidPrice();

        uint256 orderValue = (amount * price) / PRICE_PRECISION;
        if (orderValue < MIN_ORDER_VALUE) revert OrderValueTooLow();

        if (isBuy) {
            address token = m.collateralToken;
            uint256 bal = collateralBalances[token][msg.sender];
            if (bal < orderValue) revert InsufficientBalance();
            collateralBalances[token][msg.sender] = bal - orderValue;
        } else {
            uint256 ob = outcomeBalances[marketId][msg.sender][outcomeIndex];
            if (ob < amount) revert InsufficientOutcomeBalance();
            outcomeBalances[marketId][msg.sender][outcomeIndex] = ob - amount;
        }

        orderId = nextOrderId++;
        orders[orderId] = Order({
            marketId: marketId,
            trader: msg.sender,
            isBuy: isBuy,
            outcomeIndex: outcomeIndex,
            amount: amount,
            price: price,
            filled: 0,
            active: true
        });

        emit OrderPlaced(orderId, marketId, msg.sender, isBuy, outcomeIndex, amount, price);
    }

    function fillOrder(uint256 orderId, uint256 fillAmount) external returns (uint256) {
        Order storage order = orders[orderId];
        if (order.trader == address(0)) revert OrderNotFound();
        if (!order.active) revert OrderNotActive();
        if (fillAmount == 0) revert ZeroAmount();
        if (order.trader == msg.sender) revert CannotFillOwnOrder();

        uint256 remaining = order.amount - order.filled;
        if (fillAmount > remaining) revert FillExceedsRemaining();

        Market storage m = markets[order.marketId];
        if (m.collateralToken == address(0)) revert MarketNotFound();
        if (m.settled) revert MarketAlreadySettled();

        address token = m.collateralToken;
        uint256 fillValue = (fillAmount * order.price) / PRICE_PRECISION;

        if (order.isBuy) {
            uint256 ob = outcomeBalances[order.marketId][msg.sender][order.outcomeIndex];
            if (ob < fillAmount) revert InsufficientOutcomeBalance();
            outcomeBalances[order.marketId][msg.sender][order.outcomeIndex] = ob - fillAmount;
            outcomeBalances[order.marketId][order.trader][order.outcomeIndex] += fillAmount;
            collateralBalances[token][msg.sender] += fillValue;
        } else {
            uint256 cb = collateralBalances[token][msg.sender];
            if (cb < fillValue) revert InsufficientBalance();
            collateralBalances[token][msg.sender] = cb - fillValue;
            collateralBalances[token][order.trader] += fillValue;
            outcomeBalances[order.marketId][msg.sender][order.outcomeIndex] += fillAmount;
        }

        order.filled += fillAmount;
        if (order.filled >= order.amount) order.active = false;

        emit OrderFilled(orderId, msg.sender, fillAmount);
        return fillAmount;
    }

    function cancelOrder(uint256 orderId) external returns (uint256) {
        Order storage order = orders[orderId];
        if (order.trader == address(0)) revert OrderNotFound();
        if (msg.sender != order.trader) revert NotOrderOwner();
        if (!order.active) revert OrderNotActive();

        order.active = false;
        uint256 remaining = order.amount - order.filled;
        Market storage m = markets[order.marketId];
        address token = m.collateralToken;
        uint256 refund;

        if (order.isBuy) {
            refund = (remaining * order.price) / PRICE_PRECISION;
            collateralBalances[token][order.trader] += refund;
        } else {
            refund = remaining;
            outcomeBalances[order.marketId][order.trader][order.outcomeIndex] += remaining;
        }

        emit OrderCancelled(orderId, order.trader, refund);
        return refund;
    }

    // --------------------------------------------------------------
    // Settlement & Claims
    // --------------------------------------------------------------
    function settleMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.settled) revert MarketAlreadySettled();
        if (winningOutcome >= m.outcomeCount) revert InvalidWinningOutcome();

        uint256 totalCollateral = m.totalCollateral;
        uint256 fee = (totalCollateral * marketCreationFeeBps) / FEE_DENOMINATOR;
        m.totalCollateral = totalCollateral - fee;
        m.winningOutcome = winningOutcome;
        m.winningSupply = totalOutcomeSupply[marketId][uint8(winningOutcome)];
        m.settled = true;

        if (fee > 0) {
            collateralBalances[m.collateralToken][operator] += fee;
        }

        emit MarketSettled(marketId, winningOutcome, fee);
    }

    function claimProceeds(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.settled) revert MarketNotSettled();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        uint8 winning = uint8(m.winningOutcome);
        uint256 balance = outcomeBalances[marketId][msg.sender][winning];
        if (balance == 0) revert NothingToClaim();

        uint256 supply = m.winningSupply;
        if (supply == 0) revert NoWinningSupply();
        uint256 payout = (balance * m.totalCollateral) / supply;

        hasClaimed[marketId][msg.sender] = true;
        outcomeBalances[marketId][msg.sender][winning] = 0;
        totalOutcomeSupply[marketId][winning] -= balance;
        collateralBalances[m.collateralToken][msg.sender] += payout;

        emit ProceedsClaimed(marketId, msg.sender, balance, payout);
    }

    // --------------------------------------------------------------
    // View Functions
    // --------------------------------------------------------------
    function getMarket(uint256 marketId)
        external
        view
        returns (
            address creator,
            address collateralToken,
            uint8 outcomeCount,
            uint256 winningOutcome,
            uint256 totalCollateral,
            uint256 winningSupply,
            bool settled,
            string memory description
        )
    {
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.collateralToken,
            m.outcomeCount,
            m.winningOutcome,
            m.totalCollateral,
            m.winningSupply,
            m.settled,
            m.description
        );
    }

    function getOrder(uint256 orderId)
        external
        view
        returns (
            uint256 marketId,
            address trader,
            bool isBuy,
            uint8 outcomeIndex,
            uint256 amount,
            uint256 price,
            uint256 filled,
            bool active
        )
    {
        Order storage o = orders[orderId];
        return (
            o.marketId,
            o.trader,
            o.isBuy,
            o.outcomeIndex,
            o.amount,
            o.price,
            o.filled,
            o.active
        );
    }

    function getOutcomeBalance(uint256 marketId, address user, uint8 outcomeIndex) external view returns (uint256) {
        return outcomeBalances[marketId][user][outcomeIndex];
    }

    function getOutcomeSupply(uint256 marketId, uint8 outcomeIndex) external view returns (uint256) {
        return totalOutcomeSupply[marketId][outcomeIndex];
    }

    function getCollateralBalance(address user, address token) external view returns (uint256) {
        return collateralBalances[token][user];
    }
}
