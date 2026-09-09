// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CryptoFiatEscrow {
    enum OrderStatus {
        None,
        Active,
        Accepted,
        Confirmed,
        Cancelled
    }

    struct SwapOrder {
        address creator;
        address acceptor;
        uint256 fiatAmount;
        uint256 cryptoPrice;
        uint256 cryptoAmount;
        OrderStatus status;
    }

    uint256 public constant MAX_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_DEPOSIT_CAP = 1000;

    IERC20 public immutable cryptoToken;
    uint8 public immutable tokenDecimals;

    address public operator;

    uint256 public swapFeeBps;
    uint256 public maxDepositPerOrder;

    mapping(address => uint256) public balances;

    mapping(uint256 => SwapOrder) public orders;
    uint256[] public activeOrderIds;
    mapping(uint256 => uint256) private activeOrderIndex;

    uint256 public nextOrderId;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event OrderCreated(uint256 indexed orderId, address indexed creator, uint256 fiatAmount, uint256 cryptoPrice, uint256 cryptoAmount);
    event OrderAccepted(uint256 indexed orderId, address indexed acceptor);
    event OrderConfirmed(uint256 indexed orderId, address indexed creator, address indexed acceptor, uint256 cryptoTransferred, uint256 feeCollected);
    event OrderCancelled(uint256 indexed orderId, address indexed creator);
    event SwapFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MaxDepositPerOrderUpdated(uint256 oldMax, uint256 newMax);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidDecimals(uint8 decimals);
    error InsufficientBalance(uint256 available, uint256 required);
    error TransferFailed();
    error OrderNotFound(uint256 orderId);
    error OrderNotActive(uint256 orderId);
    error OrderNotAccepted(uint256 orderId);
    error NotOrderCreator(uint256 orderId);
    error CryptoAmountExceedsMax(uint256 amount, uint256 max);
    error FeeExceedsCap(uint256 feeBps, uint256 maxFeeBps);
    error DepositExceedsCap(uint256 amount, uint256 max);
    error ZeroCryptoPrice();
    error ZeroFiatAmount();
    error CannotAcceptOwnOrder(uint256 orderId);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _cryptoToken, address _operator, uint8 _decimals) {
        if (_cryptoToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_decimals > 18) revert InvalidDecimals(_decimals);

        cryptoToken = IERC20(_cryptoToken);
        tokenDecimals = _decimals;
        operator = _operator;

        swapFeeBps = MAX_FEE_BPS;
        maxDepositPerOrder = MAX_DEPOSIT_CAP * (10 ** uint256(_decimals));
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        balances[msg.sender] += amount;

        bool ok = cryptoToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 available = balances[msg.sender];
        if (amount > available) revert InsufficientBalance(available, amount);

        balances[msg.sender] -= amount;

        bool ok = cryptoToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function createOrder(uint256 fiatAmount, uint256 cryptoPrice) external returns (uint256 orderId) {
        if (fiatAmount == 0) revert ZeroFiatAmount();
        if (cryptoPrice == 0) revert ZeroCryptoPrice();

        uint256 cryptoAmount = (fiatAmount * (10 ** uint256(tokenDecimals))) / cryptoPrice;
        if (cryptoAmount == 0) revert ZeroAmount();
        if (cryptoAmount > maxDepositPerOrder) {
            revert CryptoAmountExceedsMax(cryptoAmount, maxDepositPerOrder);
        }

        uint256 available = balances[msg.sender];
        if (cryptoAmount > available) revert InsufficientBalance(available, cryptoAmount);

        balances[msg.sender] -= cryptoAmount;

        orderId = nextOrderId++;
        orders[orderId] = SwapOrder({
            creator: msg.sender,
            acceptor: address(0),
            fiatAmount: fiatAmount,
            cryptoPrice: cryptoPrice,
            cryptoAmount: cryptoAmount,
            status: OrderStatus.Active
        });

        activeOrderIndex[orderId] = activeOrderIds.length + 1;
        activeOrderIds.push(orderId);

        emit OrderCreated(orderId, msg.sender, fiatAmount, cryptoPrice, cryptoAmount);
    }

    function acceptOrder(uint256 orderId) external {
        SwapOrder storage order = orders[orderId];
        if (order.status == OrderStatus.None) revert OrderNotFound(orderId);
        if (order.status != OrderStatus.Active) revert OrderNotActive(orderId);
        if (msg.sender == order.creator) revert CannotAcceptOwnOrder(orderId);

        order.acceptor = msg.sender;
        order.status = OrderStatus.Accepted;

        emit OrderAccepted(orderId, msg.sender);
    }

    function confirmFiatReceipt(uint256 orderId) external {
        SwapOrder storage order = orders[orderId];
        if (order.status == OrderStatus.None) revert OrderNotFound(orderId);
        if (order.status != OrderStatus.Accepted) revert OrderNotAccepted(orderId);
        if (msg.sender != order.creator) revert NotOrderCreator(orderId);

        address acceptor = order.acceptor;
        uint256 cryptoAmount = order.cryptoAmount;
        uint256 fee = (cryptoAmount * swapFeeBps) / BPS_DENOMINATOR;
        uint256 payout = cryptoAmount - fee;

        order.status = OrderStatus.Confirmed;
        _removeActiveOrder(orderId);

        if (fee > 0) {
            bool feeOk = cryptoToken.transfer(operator, fee);
            if (!feeOk) revert TransferFailed();
        }
        bool payOk = cryptoToken.transfer(acceptor, payout);
        if (!payOk) revert TransferFailed();

        emit OrderConfirmed(orderId, order.creator, acceptor, payout, fee);
    }

    function cancelOrder(uint256 orderId) external {
        SwapOrder storage order = orders[orderId];
        if (order.status == OrderStatus.None) revert OrderNotFound(orderId);
        if (order.status != OrderStatus.Active) revert OrderNotActive(orderId);
        if (msg.sender != order.creator) revert NotOrderCreator(orderId);

        uint256 cryptoAmount = order.cryptoAmount;
        order.status = OrderStatus.Cancelled;
        balances[msg.sender] += cryptoAmount;
        _removeActiveOrder(orderId);

        emit OrderCancelled(orderId, msg.sender);
    }

    function setSwapFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsCap(newFeeBps, MAX_FEE_BPS);
        uint256 old = swapFeeBps;
        swapFeeBps = newFeeBps;
        emit SwapFeeUpdated(old, newFeeBps);
    }

    function setMaxDepositPerOrder(uint256 newMax) external onlyOperator {
        uint256 cap = MAX_DEPOSIT_CAP * (10 ** uint256(tokenDecimals));
        if (newMax > cap) revert DepositExceedsCap(newMax, cap);
        uint256 old = maxDepositPerOrder;
        maxDepositPerOrder = newMax;
        emit MaxDepositPerOrderUpdated(old, newMax);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function getOrder(uint256 orderId) external view returns (SwapOrder memory) {
        return orders[orderId];
    }

    function getActiveOrderIds() external view returns (uint256[] memory) {
        return activeOrderIds;
    }

    function activeOrderCount() external view returns (uint256) {
        return activeOrderIds.length;
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function _removeActiveOrder(uint256 orderId) internal {
        uint256 idxPlusOne = activeOrderIndex[orderId];
        if (idxPlusOne == 0) return;

        uint256 idx = idxPlusOne - 1;
        uint256 lastIndex = activeOrderIds.length - 1;

        if (idx != lastIndex) {
            uint256 lastId = activeOrderIds[lastIndex];
            activeOrderIds[idx] = lastId;
            activeOrderIndex[lastId] = idx + 1;
        }

        activeOrderIds.pop();
        delete activeOrderIndex[orderId];
    }
}
