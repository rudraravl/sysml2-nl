// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SpotOrderBook {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOwner();
    error NotOperator();
    error OrderNotActive();
    error NotOrderOwner();
    error InsufficientBalance();
    error OrderTooSmall();
    error PriceNotMatching();
    error AmountExceedsOrder();
    error InvalidOrderSide();
    error InvalidToken();
    error InvalidPrice();
    error ZeroAddress();
    error SameToken();
    error TransferFailed();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        bool isBuy,
        uint256 price,
        uint256 amount,
        uint256 timestamp
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address indexed maker,
        bool isBuy,
        uint256 price,
        uint256 remainingAmount
    );

    event TradeExecuted(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        address indexed buyer,
        address seller,
        uint256 amount,
        uint256 price,
        uint256 buyerFee,
        uint256 sellerFee
    );

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_ORDER_SIZE = 100;
    uint256 public constant FEE_RATE = 10; // basis points (0.1%)
    uint256 public constant FEE_DENOMINATOR = 10000;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;
    address public feeRecipient;

    IERC20 public immutable baseToken;
    IERC20 public immutable quoteToken;

    /// @dev Free (unlocked) balance of each user for each token.
    mapping(address => mapping(address => uint256)) public balances;

    struct Order {
        address maker;
        bool isBuy;
        uint256 price; // quote per base
        uint256 amount; // remaining base token amount
        uint256 timestamp;
        uint256 next; // next order id in linked list (0 = tail)
        bool active;
    }

    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId = 1;

    /// @dev Head of the buy-order linked list (best = highest price, then earliest time).
    uint256 public buyHead;
    /// @dev Head of the sell-order linked list (best = lowest price, then earliest time).
    uint256 public sellHead;

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _baseToken,
        address _quoteToken,
        address _operator,
        address _feeRecipient
    ) {
        if (_baseToken == address(0) || _quoteToken == address(0)) revert ZeroAddress();
        if (_baseToken == _quoteToken) revert SameToken();
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();

        baseToken = IERC20(_baseToken);
        quoteToken = IERC20(_quoteToken);
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function deposit(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token != address(baseToken) && token != address(quoteToken)) revert InvalidToken();

        balances[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
    }

    function withdraw(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();

        balances[msg.sender][token] -= amount;
        emit Withdrawal(msg.sender, token, amount);

        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                         ORDER PLACEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Place a buy order: lock quote tokens to buy `amount` base at `price` each.
    function placeBuyOrder(uint256 price, uint256 amount) external returns (uint256 orderId) {
        if (amount < MIN_ORDER_SIZE) revert OrderTooSmall();
        if (price == 0) revert InvalidPrice();

        uint256 quoteRequired = amount * price;
        if (balances[msg.sender][address(quoteToken)] < quoteRequired) revert InsufficientBalance();

        // Effects: lock collateral
        balances[msg.sender][address(quoteToken)] -= quoteRequired;

        orderId = nextOrderId++;
        orders[orderId] = Order({
            maker: msg.sender,
            isBuy: true,
            price: price,
            amount: amount,
            timestamp: block.timestamp,
            next: 0,
            active: true
        });

        _insertBuyOrder(orderId);

        emit OrderPlaced(orderId, msg.sender, true, price, amount, block.timestamp);
    }

    /// @notice Place a sell order: lock base tokens to sell `amount` base at `price` each.
    function placeSellOrder(uint256 price, uint256 amount) external returns (uint256 orderId) {
        if (amount < MIN_ORDER_SIZE) revert OrderTooSmall();
        if (price == 0) revert InvalidPrice();

        if (balances[msg.sender][address(baseToken)] < amount) revert InsufficientBalance();

        // Effects: lock collateral
        balances[msg.sender][address(baseToken)] -= amount;

        orderId = nextOrderId++;
        orders[orderId] = Order({
            maker: msg.sender,
            isBuy: false,
            price: price,
            amount: amount,
            timestamp: block.timestamp,
            next: 0,
            active: true
        });

        _insertSellOrder(orderId);

        emit OrderPlaced(orderId, msg.sender, false, price, amount, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                          ORDER CANCELLATION
    //////////////////////////////////////////////////////////////*/
    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        if (!order.active) revert OrderNotActive();
        if (order.maker != msg.sender) revert NotOrderOwner();

        order.active = false;

        if (order.isBuy) {
            // Refund locked quote tokens
            uint256 refund = order.amount * order.price;
            balances[msg.sender][address(quoteToken)] += refund;
            _removeBuyOrder(orderId);
        } else {
            // Refund locked base tokens
            balances[msg.sender][address(baseToken)] += order.amount;
            _removeSellOrder(orderId);
        }

        emit OrderCancelled(orderId, msg.sender, order.isBuy, order.price, order.amount);
    }

    /*//////////////////////////////////////////////////////////////
                         TRADE EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Operator executes a trade between a matching buy and sell order.
    /// @dev Buy price must be >= sell price. Trade settles at the maker's (earlier) price.
    function executeTrade(
        uint256 buyOrderId,
        uint256 sellOrderId,
        uint256 amount
    ) external onlyOperator {
        Order storage buyOrder = orders[buyOrderId];
        Order storage sellOrder = orders[sellOrderId];

        if (!buyOrder.active || !buyOrder.isBuy) revert OrderNotActive();
        if (!sellOrder.active || sellOrder.isBuy) revert OrderNotActive();
        if (amount == 0) revert ZeroAmount();
        if (amount > buyOrder.amount || amount > sellOrder.amount) revert AmountExceedsOrder();
        if (buyOrder.price < sellOrder.price) revert PriceNotMatching();

        // Determine maker (earlier timestamp) and trade at maker's price
        uint256 tradePrice;
        if (buyOrder.timestamp <= sellOrder.timestamp) {
            tradePrice = buyOrder.price;
        } else {
            tradePrice = sellOrder.price;
        }

        uint256 quoteAmount = amount * tradePrice;

        // 0.1% fee on received amount for both sides
        uint256 buyerFee = (amount * FEE_RATE) / FEE_DENOMINATOR;
        uint256 sellerFee = (quoteAmount * FEE_RATE) / FEE_DENOMINATOR;

        uint256 buyerReceives = amount - buyerFee;
        uint256 sellerReceives = quoteAmount - sellerFee;

        // Effects: reduce remaining order amounts
        buyOrder.amount -= amount;
        sellOrder.amount -= amount;

        // Settle: buyer receives base (from seller's locked base), seller receives quote (from buyer's locked quote)
        balances[buyOrder.maker][address(baseToken)] += buyerReceives;
        balances[sellOrder.maker][address(quoteToken)] += sellerReceives;

        // Fees accrue to fee recipient
        balances[feeRecipient][address(baseToken)] += buyerFee;
        balances[feeRecipient][address(quoteToken)] += sellerFee;

        // Remove fully filled orders from the book
        if (buyOrder.amount == 0) {
            _removeBuyOrder(buyOrderId);
            buyOrder.active = false;
        }
        if (sellOrder.amount == 0) {
            _removeSellOrder(sellOrderId);
            sellOrder.active = false;
        }

        emit TradeExecuted(
            buyOrderId,
            sellOrderId,
            buyOrder.maker,
            sellOrder.maker,
            amount,
            tradePrice,
            buyerFee,
            sellerFee
        );
    }

    /*//////////////////////////////////////////////////////////////
                    LINKED-LIST SORTING HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Buy ordering: higher price first; tie-break by earlier timestamp.
    function _buyShouldBeBefore(uint256 a, uint256 b) internal view returns (bool) {
        Order storage orderA = orders[a];
        Order storage orderB = orders[b];
        if (orderA.price > orderB.price) return true;
        if (orderA.price < orderB.price) return false;
        return orderA.timestamp < orderB.timestamp;
    }

    /// @dev Sell ordering: lower price first; tie-break by earlier timestamp.
    function _sellShouldBeBefore(uint256 a, uint256 b) internal view returns (bool) {
        Order storage orderA = orders[a];
        Order storage orderB = orders[b];
        if (orderA.price < orderB.price) return true;
        if (orderA.price > orderB.price) return false;
        return orderA.timestamp < orderB.timestamp;
    }

    function _insertBuyOrder(uint256 orderId) internal {
        if (buyHead != 0 && !_buyShouldBeBefore(orderId, buyHead)) {
            uint256 prev = buyHead;
            while (orders[prev].next != 0 && !_buyShouldBeBefore(orderId, orders[prev].next)) {
                prev = orders[prev].next;
            }
            orders[orderId].next = orders[prev].next;
            orders[prev].next = orderId;
        } else {
            orders[orderId].next = buyHead;
            buyHead = orderId;
        }
    }

    function _insertSellOrder(uint256 orderId) internal {
        if (sellHead != 0 && !_sellShouldBeBefore(orderId, sellHead)) {
            uint256 prev = sellHead;
            while (orders[prev].next != 0 && !_sellShouldBeBefore(orderId, orders[prev].next)) {
                prev = orders[prev].next;
            }
            orders[orderId].next = orders[prev].next;
            orders[prev].next = orderId;
        } else {
            orders[orderId].next = sellHead;
            sellHead = orderId;
        }
    }

    function _removeBuyOrder(uint256 orderId) internal {
        if (buyHead != orderId) {
            uint256 prev = buyHead;
            while (orders[prev].next != orderId) {
                prev = orders[prev].next;
            }
            orders[prev].next = orders[orderId].next;
        } else {
            buyHead = orders[orderId].next;
        }
        orders[orderId].next = 0;
    }

    function _removeSellOrder(uint256 orderId) internal {
        if (sellHead != orderId) {
            uint256 prev = sellHead;
            while (orders[prev].next != orderId) {
                prev = orders[prev].next;
            }
            orders[prev].next = orders[orderId].next;
        } else {
            sellHead = orders[orderId].next;
        }
        orders[orderId].next = 0;
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function bestBuyPrice() external view returns (uint256) {
        if (buyHead != 0) {
            return orders[buyHead].price;
        }
        return 0;
    }

    function bestSellPrice() external view returns (uint256) {
        if (sellHead != 0) {
            return orders[sellHead].price;
        }
        return 0;
    }

    function getBuyOrderIds(uint256 maxCount) external view returns (uint256[] memory) {
        if (maxCount == 0) return new uint256[](0);
        uint256[] memory temp = new uint256[](maxCount);
        uint256 count = 0;
        uint256 current = buyHead;
        while (current != 0 && count < maxCount) {
            temp[count] = current;
            current = orders[current].next;
            unchecked {
                ++count;
            }
        }
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; ) {
            result[i] = temp[i];
            unchecked {
                ++i;
            }
        }
        return result;
    }

    function getSellOrderIds(uint256 maxCount) external view returns (uint256[] memory) {
        if (maxCount == 0) return new uint256[](0);
        uint256[] memory temp = new uint256[](maxCount);
        uint256 count = 0;
        uint256 current = sellHead;
        while (current != 0 && count < maxCount) {
            temp[count] = current;
            current = orders[current].next;
            unchecked {
                ++count;
            }
        }
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; ) {
            result[i] = temp[i];
            unchecked {
                ++i;
            }
        }
        return result;
    }

    function getOrder(uint256 orderId)
        external
        view
        returns (
            address maker,
            bool isBuy,
            uint256 price,
            uint256 amount,
            uint256 timestamp,
            uint256 next,
            bool active
        )
    {
        Order storage order = orders[orderId];
        return (
            order.maker,
            order.isBuy,
            order.price,
            order.amount,
            order.timestamp,
            order.next,
            order.active
        );
    }

    function getBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }
}
