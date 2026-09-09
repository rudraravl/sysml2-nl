// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title OrderBookExchange
 * @notice On-chain order book DEX for a single token pair (tokenA / tokenB).
 *         The contract custodies deposits of both tokens and matches limit
 *         orders according to price-time priority. An operator may pause all
 *         trading operations.
 */
contract OrderBookExchange {
    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------
    /// @dev Prices are expressed in 1e18 precision. A price must be a
    ///      positive multiple of 0.0001 (i.e. 1e14 in 1e18 precision).
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant PRICE_STEP = 1e14;

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------
    error ZeroAddress();
    error IdenticalTokens();
    error NotOperator();
    error EnforcedPause();
    error UnsupportedToken();
    error InvalidPrice();
    error InvalidQuantity();
    error InsufficientBalance();
    error OrderNotActive();
    error NotOrderMaker();
    error TransferFailed();
    error ReentrantCall();

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event Deposited(address indexed token, address indexed user, uint256 amount);
    event Withdrawn(address indexed token, address indexed user, uint256 amount);
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        bool isBuy,
        uint256 price,
        uint256 quantity
    );
    event OrderCanceled(uint256 indexed orderId, address indexed maker, uint256 remainingQuantity);
    event OrderFilled(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 quantity,
        uint256 tokenAAmount,
        uint256 tokenBAmount
    );
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    // ------------------------------------------------------------------
    // Types
    // ------------------------------------------------------------------
    struct Order {
        uint256 id;
        address maker;
        bool isBuy;
        uint256 price;     // in 1e18 precision
        uint256 quantity;  // remaining quantity in tokenA units
        uint256 reserved;  // reserved amount of the paying token
        bool active;
    }

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    address public operator;
    bool public paused;

    uint256 private _nextOrderId;
    uint256 private _locked; // reentrancy guard: 0 = unlocked, 1 = locked

    /// @dev token => user => balance
    mapping(address => mapping(address => uint256)) private _balances;

    mapping(uint256 => Order) private _orders;

    uint256[] private _buyOrderIds;   // sorted: highest price first, then oldest id
    uint256[] private _sellOrderIds;  // sorted: lowest price first, then oldest id
    mapping(uint256 => uint256) private _buyIndex;  // orderId => index + 1
    mapping(uint256 => uint256) private _sellIndex; // orderId => index + 1

    // ------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------
    constructor(address tokenA_, address tokenB_, address operator_) {
        if (tokenA_ == address(0) || tokenB_ == address(0) || operator_ == address(0)) {
            revert ZeroAddress();
        }
        if (tokenA_ == tokenB_) revert IdenticalTokens();
        tokenA = IERC20(tokenA_);
        tokenB = IERC20(tokenB_);
        operator = operator_;
        _nextOrderId = 1;
        emit OperatorChanged(address(0), operator_);
    }

    // ------------------------------------------------------------------
    // Deposit / Withdraw
    // ------------------------------------------------------------------
    function deposit(address token, uint256 amount) external nonReentrant whenNotPaused {
        _requireSupportedToken(token);
        if (amount == 0) revert InvalidQuantity();

        // Effects: credit the user before the external call (CEI pattern).
        _balances[token][msg.sender] += amount;

        // Interactions: pull tokens from the depositor. Revert on failure.
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            // Roll back the optimistic credit on failure.
            _balances[token][msg.sender] -= amount;
            revert TransferFailed();
        }

        emit Deposited(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        _requireSupportedToken(token);
        if (amount == 0) revert InvalidQuantity();
        if (_balances[token][msg.sender] < amount) revert InsufficientBalance();

        // Effects: deduct balance before external transfer (CEI pattern).
        _balances[token][msg.sender] -= amount;

        // Interactions: send tokens to the user. Revert on failure.
        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) {
            _balances[token][msg.sender] += amount;
            revert TransferFailed();
        }

        emit Withdrawn(token, msg.sender, amount);
    }

    // ------------------------------------------------------------------
    // Order placement
    // ------------------------------------------------------------------
    /// @notice Place a buy order: offer to buy `quantity` of tokenA paying
    ///         tokenB at `price` (per tokenA, in 1e18 precision).
    function placeBuyOrder(uint256 price, uint256 quantity) external whenNotPaused {
        _validatePrice(price);
        _validateQuantity(quantity);

        uint256 cost = (quantity * price) / PRICE_PRECISION;
        if (cost == 0) revert InvalidPrice();
        if (_balances[address(tokenB)][msg.sender] < cost) revert InsufficientBalance();

        _balances[address(tokenB)][msg.sender] -= cost;

        uint256 orderId = _nextOrderId++;
        Order storage o = _orders[orderId];
        o.id = orderId;
        o.maker = msg.sender;
        o.isBuy = true;
        o.price = price;
        o.quantity = quantity;
        o.reserved = cost;
        o.active = true;

        emit OrderPlaced(orderId, msg.sender, true, price, quantity);

        _matchBuy(o);

        if (o.quantity > 0) {
            _insertBuyOrder(orderId);
        } else {
            o.active = false;
            if (o.reserved > 0) {
                _balances[address(tokenB)][msg.sender] += o.reserved;
                o.reserved = 0;
            }
        }
    }

    /// @notice Place a sell order: offer to sell `quantity` of tokenA for
    ///         tokenB at `price` (per tokenA, in 1e18 precision).
    function placeSellOrder(uint256 price, uint256 quantity) external whenNotPaused {
        _validatePrice(price);
        _validateQuantity(quantity);

        if (_balances[address(tokenA)][msg.sender] < quantity) revert InsufficientBalance();

        _balances[address(tokenA)][msg.sender] -= quantity;

        uint256 orderId = _nextOrderId++;
        Order storage o = _orders[orderId];
        o.id = orderId;
        o.maker = msg.sender;
        o.isBuy = false;
        o.price = price;
        o.quantity = quantity;
        o.reserved = quantity;
        o.active = true;

        emit OrderPlaced(orderId, msg.sender, false, price, quantity);

        _matchSell(o);

        if (o.quantity > 0) {
            _insertSellOrder(orderId);
        } else {
            o.active = false;
            if (o.reserved > 0) {
                _balances[address(tokenA)][msg.sender] += o.reserved;
                o.reserved = 0;
            }
        }
    }

    // ------------------------------------------------------------------
    // Cancel
    // ------------------------------------------------------------------
    function cancelOrder(uint256 orderId) external whenNotPaused {
        Order storage o = _orders[orderId];
        if (!o.active) revert OrderNotActive();
        if (o.maker != msg.sender) revert NotOrderMaker();

        uint256 remaining = o.quantity;

        if (o.isBuy) {
            _balances[address(tokenB)][msg.sender] += o.reserved;
            _removeFromBuyList(orderId);
        } else {
            _balances[address(tokenA)][msg.sender] += o.reserved;
            _removeFromSellList(orderId);
        }

        o.quantity = 0;
        o.reserved = 0;
        o.active = false;

        emit OrderCanceled(orderId, msg.sender, remaining);
    }

    // ------------------------------------------------------------------
    // Matching engine
    // ------------------------------------------------------------------
    /// @dev A buy taker crosses against the best (lowest-price) sell orders.
    function _matchBuy(Order storage taker) internal {
        while (taker.quantity > 0 && _sellOrderIds.length > 0) {
            uint256 bestId = _sellOrderIds[0];
            Order storage maker = _orders[bestId];
            if (!maker.active || maker.quantity == 0 || maker.price > taker.price) {
                break;
            }
            _executeBuyTaker(taker, maker);
        }
    }

    /// @dev A sell taker crosses against the best (highest-price) buy orders.
    function _matchSell(Order storage taker) internal {
        while (taker.quantity > 0 && _buyOrderIds.length > 0) {
            uint256 bestId = _buyOrderIds[0];
            Order storage maker = _orders[bestId];
            if (!maker.active || maker.quantity == 0 || maker.price < taker.price) {
                break;
            }
            _executeSellTaker(taker, maker);
        }
    }

    /// @dev Buy order is the taker, sell order is the maker. Trade executes
    ///      at the maker (sell) price; buyer receives a surplus refund.
    function _executeBuyTaker(Order storage buy, Order storage sell) internal {
        uint256 tradeQty = _min(buy.quantity, sell.quantity);
        uint256 reservedCost = (tradeQty * buy.price) / PRICE_PRECISION;
        uint256 actualCost = (tradeQty * sell.price) / PRICE_PRECISION;
        uint256 surplus = reservedCost - actualCost;

        buy.quantity -= tradeQty;
        buy.reserved -= reservedCost;
        sell.quantity -= tradeQty;
        sell.reserved -= tradeQty;

        // tokenA flows from seller (reserved) to buyer
        _balances[address(tokenA)][buy.maker] += tradeQty;
        // tokenB flows from buyer's reserved to seller; surplus back to buyer
        _balances[address(tokenB)][sell.maker] += actualCost;
        _balances[address(tokenB)][buy.maker] += surplus;

        emit OrderFilled(buy.id, sell.id, buy.maker, sell.maker, sell.price, tradeQty, tradeQty, actualCost);

        if (sell.quantity == 0) {
            sell.active = false;
            _removeFromSellList(sell.id);
        }
    }

    /// @dev Sell order is the taker, buy order is the maker. Trade executes
    ///      at the maker (buy) price.
    function _executeSellTaker(Order storage sell, Order storage buy) internal {
        uint256 tradeQty = _min(sell.quantity, buy.quantity);
        uint256 costB = (tradeQty * buy.price) / PRICE_PRECISION;

        sell.quantity -= tradeQty;
        sell.reserved -= tradeQty;
        buy.quantity -= tradeQty;
        buy.reserved -= costB;

        // tokenA flows from seller (reserved) to buyer
        _balances[address(tokenA)][buy.maker] += tradeQty;
        // tokenB flows from buyer's reserved to seller
        _balances[address(tokenB)][sell.maker] += costB;

        emit OrderFilled(buy.id, sell.id, buy.maker, sell.maker, buy.price, tradeQty, tradeQty, costB);

        if (buy.quantity == 0) {
            buy.active = false;
            _removeFromBuyList(buy.id);
        }
    }

    // ------------------------------------------------------------------
    // Sorted order book insertion (price-time priority)
    // ------------------------------------------------------------------
    function _insertBuyOrder(uint256 orderId) internal {
        Order storage order = _orders[orderId];
        uint256 price = order.price;
        uint256 len = _buyOrderIds.length;
        uint256 i = 0;
        // Descending price; ties broken by ascending id (older first).
        while (i < len) {
            Order storage o = _orders[_buyOrderIds[i]];
            if (o.price > price || (o.price == price && o.id < orderId)) {
                i++;
            } else {
                break;
            }
        }
        _buyOrderIds.push();
        for (uint256 j = len; j > i; j--) {
            _buyOrderIds[j] = _buyOrderIds[j - 1];
            _buyIndex[_buyOrderIds[j]] = j + 1;
        }
        _buyOrderIds[i] = orderId;
        _buyIndex[orderId] = i + 1;
    }

    function _insertSellOrder(uint256 orderId) internal {
        Order storage order = _orders[orderId];
        uint256 price = order.price;
        uint256 len = _sellOrderIds.length;
        uint256 i = 0;
        // Ascending price; ties broken by ascending id (older first).
        while (i < len) {
            Order storage o = _orders[_sellOrderIds[i]];
            if (o.price < price || (o.price == price && o.id < orderId)) {
                i++;
            } else {
                break;
            }
        }
        _sellOrderIds.push();
        for (uint256 j = len; j > i; j--) {
            _sellOrderIds[j] = _sellOrderIds[j - 1];
            _sellIndex[_sellOrderIds[j]] = j + 1;
        }
        _sellOrderIds[i] = orderId;
        _sellIndex[orderId] = i + 1;
    }

    function _removeFromBuyList(uint256 orderId) internal {
        uint256 pos = _buyIndex[orderId];
        if (pos == 0) return;
        uint256 idx = pos - 1;
        uint256 lastIdx = _buyOrderIds.length - 1;
        if (idx != lastIdx) {
            uint256 lastId = _buyOrderIds[lastIdx];
            _buyOrderIds[idx] = lastId;
            _buyIndex[lastId] = idx + 1;
        }
        _buyOrderIds.pop();
        delete _buyIndex[orderId];
    }

    function _removeFromSellList(uint256 orderId) internal {
        uint256 pos = _sellIndex[orderId];
        if (pos == 0) return;
        uint256 idx = pos - 1;
        uint256 lastIdx = _sellOrderIds.length - 1;
        if (idx != lastIdx) {
            uint256 lastId = _sellOrderIds[lastIdx];
            _sellOrderIds[idx] = lastId;
            _sellIndex[lastId] = idx + 1;
        }
        _sellOrderIds.pop();
        delete _sellIndex[orderId];
    }

    // ------------------------------------------------------------------
    // Operator controls
    // ------------------------------------------------------------------
    function pause() external onlyOperator {
        if (paused) return;
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) return;
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------
    function getBalance(address token, address user) external view returns (uint256) {
        _requireSupportedToken(token);
        return _balances[token][user];
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return _orders[orderId];
    }

    function buyOrderCount() external view returns (uint256) {
        return _buyOrderIds.length;
    }

    function sellOrderCount() external view returns (uint256) {
        return _sellOrderIds.length;
    }

    function buyOrderAt(uint256 index) external view returns (uint256 orderId) {
        return _buyOrderIds[index];
    }

    function sellOrderAt(uint256 index) external view returns (uint256 orderId) {
        return _sellOrderIds[index];
    }

    function isSupportedToken(address token) public view returns (bool) {
        return token == address(tokenA) || token == address(tokenB);
    }

    // ------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------
    function _requireSupportedToken(address token) internal view {
        if (!isSupportedToken(token)) revert UnsupportedToken();
    }

    function _validatePrice(uint256 price) internal pure {
        if (price == 0) revert InvalidPrice();
        if (price % PRICE_STEP != 0) revert InvalidPrice();
    }

    function _validateQuantity(uint256 quantity) internal pure {
        if (quantity == 0) revert InvalidQuantity();
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
