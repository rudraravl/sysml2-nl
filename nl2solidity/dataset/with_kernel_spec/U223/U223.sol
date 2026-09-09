// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @title PeerToPeerExchange
/// @notice On-chain order book for peer-to-peer ERC20 trading. Users deposit tokens,
///         place limit orders, and fill existing orders. A 0.1% fee is charged on the
///         taker's filled volume and routed to a configurable fee recipient. An
///         operator may pause new trading activity and enable/disable trading pairs.
contract PeerToPeerExchange {
    uint256 public constant MAX_OPEN_ORDERS_PER_USER = 100;
    uint16 public constant FEE_BPS = 10; // 0.1%
    uint16 public constant BPS_DENOMINATOR = 10000;

    struct Order {
        address maker;
        address tokenGive;
        address tokenGet;
        uint256 amountGive;
        uint256 amountGet;
        uint256 remainingGive;
        uint256 remainingGet;
        bool active;
        uint64 createdAt;
    }

    address public operator;
    address public feeRecipient;
    bool public paused;

    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => mapping(address => bool)) public pairAllowed;
    mapping(address => uint256) public openOrderCount;

    Order[] internal _orders;
    mapping(bytes32 => uint256[]) internal _orderBook;
    mapping(address => uint256[]) internal _userOpenOrders;
    mapping(uint256 => uint256) internal _userOrderIndex;

    uint256 private _locked = 1;

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        address tokenGive,
        address tokenGet,
        uint256 amountGive,
        uint256 amountGet
    );
    event OrderCancelled(uint256 indexed orderId, address indexed maker, uint256 remainingGive, uint256 remainingGet);
    event OrderFilled(
        uint256 indexed orderId,
        address indexed taker,
        address indexed maker,
        uint256 fillGive,
        uint256 fillGet,
        uint256 fee
    );
    event TradingPaused();
    event TradingResumed();
    event PairConfigUpdated(address indexed tokenGive, address indexed tokenGet, bool allowed);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

    error Unauthorized();
    error ZeroAddress();
    error AmountMustBePositive();
    error InsufficientBalance(uint256 available, uint256 required);
    error OrderNotFound();
    error OrderNotActive();
    error NotMaker();
    error CannotFillOwnOrder();
    error MaxOpenOrdersReached();
    error TradingIsPaused();
    error InvalidPair();
    error InvalidFillAmount();
    error ReentrantCall();
    error TransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingIsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountMustBePositive();
        userBalances[msg.sender][token] += amount;
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountMustBePositive();
        uint256 available = userBalances[msg.sender][token];
        if (available < amount) revert InsufficientBalance(available, amount);
        userBalances[msg.sender][token] = available - amount;
        _safeTransfer(token, msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    function placeOrder(
        address tokenGive,
        uint256 amountGive,
        address tokenGet,
        uint256 amountGet
    ) external whenNotPaused nonReentrant returns (uint256 orderId) {
        if (tokenGive == address(0) || tokenGet == address(0)) revert ZeroAddress();
        if (tokenGive == tokenGet) revert InvalidPair();
        if (amountGive == 0 || amountGet == 0) revert AmountMustBePositive();
        if (!pairAllowed[tokenGive][tokenGet]) revert InvalidPair();
        if (openOrderCount[msg.sender] >= MAX_OPEN_ORDERS_PER_USER) revert MaxOpenOrdersReached();

        uint256 available = userBalances[msg.sender][tokenGive];
        if (available < amountGive) revert InsufficientBalance(available, amountGive);
        userBalances[msg.sender][tokenGive] = available - amountGive;

        orderId = _orders.length;
        _orders.push(
            Order({
                maker: msg.sender,
                tokenGive: tokenGive,
                tokenGet: tokenGet,
                amountGive: amountGive,
                amountGet: amountGet,
                remainingGive: amountGive,
                remainingGet: amountGet,
                active: true,
                createdAt: uint64(block.timestamp)
            })
        );

        _orderBook[_pairKey(tokenGive, tokenGet)].push(orderId);
        _userOrderIndex[orderId] = _userOpenOrders[msg.sender].length;
        _userOpenOrders[msg.sender].push(orderId);
        openOrderCount[msg.sender] += 1;

        emit OrderPlaced(orderId, msg.sender, tokenGive, tokenGet, amountGive, amountGet);
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        if (orderId >= _orders.length) revert OrderNotFound();
        Order storage order = _orders[orderId];
        if (!order.active) revert OrderNotActive();
        if (order.maker != msg.sender) revert NotMaker();

        uint256 remainingGive = order.remainingGive;
        uint256 remainingGet = order.remainingGet;

        order.active = false;
        if (remainingGive > 0) {
            userBalances[msg.sender][order.tokenGive] += remainingGive;
            order.remainingGive = 0;
        }
        order.remainingGet = 0;
        _removeFromUserOrders(order.maker, orderId);
        openOrderCount[msg.sender] -= 1;

        emit OrderCancelled(orderId, msg.sender, remainingGive, remainingGet);
    }

    function fillOrder(uint256 orderId, uint256 fillGetAmount) external whenNotPaused nonReentrant {
        if (orderId >= _orders.length) revert OrderNotFound();
        Order storage order = _orders[orderId];
        if (!order.active) revert OrderNotActive();
        if (fillGetAmount == 0) revert AmountMustBePositive();
        if (fillGetAmount > order.remainingGet) revert InvalidFillAmount();
        if (order.maker == msg.sender) revert CannotFillOwnOrder();

        uint256 fillGiveAmount = (order.remainingGive * fillGetAmount) / order.remainingGet;
        if (fillGiveAmount == 0) revert InvalidFillAmount();

        uint256 fee = (fillGetAmount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 takerNeeds = fillGetAmount + fee;

        uint256 takerBal = userBalances[msg.sender][order.tokenGet];
        if (takerBal < takerNeeds) revert InsufficientBalance(takerBal, takerNeeds);

        userBalances[msg.sender][order.tokenGet] = takerBal - takerNeeds;
        userBalances[order.maker][order.tokenGet] += fillGetAmount;
        userBalances[msg.sender][order.tokenGive] += fillGiveAmount;
        userBalances[feeRecipient][order.tokenGet] += fee;

        order.remainingGive -= fillGiveAmount;
        order.remainingGet -= fillGetAmount;

        if (order.remainingGet == 0) {
            order.active = false;
            if (order.remainingGive > 0) {
                userBalances[order.maker][order.tokenGive] += order.remainingGive;
                order.remainingGive = 0;
            }
            _removeFromUserOrders(order.maker, orderId);
            openOrderCount[order.maker] -= 1;
        }

        emit OrderFilled(orderId, msg.sender, order.maker, fillGiveAmount, fillGetAmount, fee);
    }

    function _removeFromUserOrders(address user, uint256 orderId) internal {
        uint256 idx = _userOrderIndex[orderId];
        uint256 lastIndex = _userOpenOrders[user].length - 1;
        if (idx != lastIndex) {
            uint256 lastOrderId = _userOpenOrders[user][lastIndex];
            _userOpenOrders[user][idx] = lastOrderId;
            _userOrderIndex[lastOrderId] = idx;
        }
        _userOpenOrders[user].pop();
        delete _userOrderIndex[orderId];
    }

    function _pairKey(address tokenA, address tokenB) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenA, tokenB));
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit TradingPaused();
        } else {
            emit TradingResumed();
        }
    }

    function updatePairConfig(address tokenGive, address tokenGet, bool allowed) external onlyOperator {
        if (tokenGive == address(0) || tokenGet == address(0)) revert ZeroAddress();
        if (tokenGive == tokenGet) revert InvalidPair();
        pairAllowed[tokenGive][tokenGet] = allowed;
        pairAllowed[tokenGet][tokenGive] = allowed;
        emit PairConfigUpdated(tokenGive, tokenGet, allowed);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function getBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        if (orderId >= _orders.length) revert OrderNotFound();
        return _orders[orderId];
    }

    function getOrderCount() external view returns (uint256) {
        return _orders.length;
    }

    function getPairOrders(address tokenGive, address tokenGet) external view returns (uint256[] memory) {
        return _orderBook[_pairKey(tokenGive, tokenGet)];
    }

    function getUserOpenOrders(address user) external view returns (uint256[] memory) {
        return _userOpenOrders[user];
    }

    function isPairAllowed(address tokenGive, address tokenGet) external view returns (bool) {
        return pairAllowed[tokenGive][tokenGet];
    }
}
