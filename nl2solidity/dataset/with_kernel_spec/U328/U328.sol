// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LimitOrderBookDEX {
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error SameTokenPair();
    error PriceZero();
    error BelowMinOrder();
    error FeeTooHigh();
    error TradingPausedError();
    error OrderNotActive();
    error NotOrderOwner();
    error CannotFillOwnOrder();
    error InsufficientFreeBalance();
    error InsufficientBalance();
    error TransferFailed();
    error Reentrancy();

    uint256 public constant MAX_FEE_BPS = 20;
    uint256 public constant BPS_DENOM = 10_000;
    uint256 public constant MIN_ORDER_AMOUNT = 100;

    address public operator;
    uint256 public tradingFeeBps;
    address public feeRecipient;
    bool public paused;

    struct Order {
        address maker;
        address baseToken;
        address quoteToken;
        bool isBuy;
        uint256 price;
        uint256 amount;
        uint256 filledBase;
        bool active;
    }

    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256)) public locked;
    mapping(uint256 => Order) public orders;
    uint256[] public activeOrderIds;
    mapping(uint256 => uint256) internal _activeIndex;
    uint256 public nextOrderId = 1;

    uint256 private _reentrancyStatus = 1;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        address indexed baseToken,
        address quoteToken,
        bool isBuy,
        uint256 price,
        uint256 amount
    );
    event OrderCancelled(uint256 indexed orderId, address indexed maker, uint256 remainingBase);
    event Trade(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        address indexed buyer,
        address seller,
        address baseToken,
        address quoteToken,
        uint256 price,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 fee
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event PausedStateChanged(bool isPaused);
    event OperatorTransferred(address indexed oldOperator, address indexed newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus != 1) revert Reentrancy();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    constructor(address _operator, address _feeRecipient, uint256 _feeBps) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        operator = _operator;
        feeRecipient = _feeRecipient;
        tradingFeeBps = _feeBps;
        emit OperatorTransferred(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit FeeUpdated(0, _feeBps);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _safeTransferFrom(token, msg.sender, address(this), amount);
        balances[token][msg.sender] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 avail = balances[token][msg.sender] - locked[token][msg.sender];
        if (amount > avail) revert InsufficientBalance();
        balances[token][msg.sender] -= amount;
        _safeTransfer(token, msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    function getBalance(address token, address user) external view returns (uint256) {
        return balances[token][user];
    }

    function getLocked(address token, address user) external view returns (uint256) {
        return locked[token][user];
    }

    function getFreeBalance(address token, address user) public view returns (uint256) {
        return balances[token][user] - locked[token][user];
    }

    function placeOrder(
        address baseToken,
        address quoteToken,
        bool isBuy,
        uint256 price,
        uint256 amount
    ) external nonReentrant returns (uint256 orderId) {
        if (paused) revert TradingPausedError();
        if (baseToken == address(0) || quoteToken == address(0)) revert ZeroAddress();
        if (baseToken == quoteToken) revert SameTokenPair();
        if (price == 0) revert PriceZero();
        if (amount < MIN_ORDER_AMOUNT) revert BelowMinOrder();

        if (isBuy) {
            uint256 quoteAmount = amount * price;
            if (getFreeBalance(quoteToken, msg.sender) < quoteAmount) revert InsufficientFreeBalance();
            locked[quoteToken][msg.sender] += quoteAmount;
        } else {
            if (getFreeBalance(baseToken, msg.sender) < amount) revert InsufficientFreeBalance();
            locked[baseToken][msg.sender] += amount;
        }

        orderId = nextOrderId++;
        orders[orderId] = Order({
            maker: msg.sender,
            baseToken: baseToken,
            quoteToken: quoteToken,
            isBuy: isBuy,
            price: price,
            amount: amount,
            filledBase: 0,
            active: true
        });
        _activeIndex[orderId] = activeOrderIds.length;
        activeOrderIds.push(orderId);

        emit OrderPlaced(orderId, msg.sender, baseToken, quoteToken, isBuy, price, amount);

        _matchOrder(orderId);
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage o = orders[orderId];
        if (!o.active) revert OrderNotActive();
        if (o.maker != msg.sender) revert NotOrderOwner();

        uint256 remaining = o.amount;
        if (o.isBuy) {
            uint256 lockedQuote = remaining * o.price;
            locked[o.quoteToken][o.maker] -= lockedQuote;
        } else {
            locked[o.baseToken][o.maker] -= remaining;
        }
        o.amount = 0;
        o.active = false;
        _removeActiveOrder(orderId);
        emit OrderCancelled(orderId, o.maker, remaining);
    }

    function fillOrder(uint256 orderId, uint256 amount) external nonReentrant returns (uint256 filled) {
        if (paused) revert TradingPausedError();
        Order storage o = orders[orderId];
        if (!o.active) revert OrderNotActive();
        if (o.maker == msg.sender) revert CannotFillOwnOrder();
        if (amount == 0) revert ZeroAmount();
        if (amount > o.amount) amount = o.amount;
        if (amount < MIN_ORDER_AMOUNT && amount < o.amount) revert BelowMinOrder();

        address baseToken = o.baseToken;
        address quoteToken = o.quoteToken;
        uint256 execPrice = o.price;
        uint256 fillBase = amount;
        uint256 quoteAmount = fillBase * execPrice;
        uint256 fee = (quoteAmount * tradingFeeBps) / BPS_DENOM;

        if (o.isBuy) {
            _settle(o.maker, msg.sender, baseToken, quoteToken, o.price, execPrice, fillBase, true, false);
            emit Trade(orderId, 0, o.maker, msg.sender, baseToken, quoteToken, execPrice, fillBase, quoteAmount, fee);
        } else {
            _settle(msg.sender, o.maker, baseToken, quoteToken, execPrice, execPrice, fillBase, false, true);
            emit Trade(0, orderId, msg.sender, o.maker, baseToken, quoteToken, execPrice, fillBase, quoteAmount, fee);
        }

        o.amount -= fillBase;
        o.filledBase += fillBase;
        if (o.amount == 0) {
            o.active = false;
            _removeActiveOrder(orderId);
        }
        filled = fillBase;
    }

    function _matchOrder(uint256 takerId) internal {
        Order storage taker = orders[takerId];
        while (taker.amount > 0) {
            uint256 restingId = _findBestMatch(
                taker.baseToken,
                taker.quoteToken,
                taker.isBuy,
                taker.price,
                taker.maker
            );
            if (restingId == 0) break;
            Order storage resting = orders[restingId];
            uint256 fillBase = taker.amount < resting.amount ? taker.amount : resting.amount;
            uint256 execPrice = resting.price;

            address buyMaker;
            address sellMaker;
            uint256 buyLockPrice;
            if (taker.isBuy) {
                buyMaker = taker.maker;
                sellMaker = resting.maker;
                buyLockPrice = taker.price;
            } else {
                buyMaker = resting.maker;
                sellMaker = taker.maker;
                buyLockPrice = resting.price;
            }

            uint256 quoteAmount = fillBase * execPrice;
            uint256 fee = (quoteAmount * tradingFeeBps) / BPS_DENOM;

            _settle(
                buyMaker,
                sellMaker,
                taker.baseToken,
                taker.quoteToken,
                buyLockPrice,
                execPrice,
                fillBase,
                true,
                true
            );

            taker.amount -= fillBase;
            taker.filledBase += fillBase;
            resting.amount -= fillBase;
            resting.filledBase += fillBase;

            emit Trade(
                taker.isBuy ? takerId : restingId,
                taker.isBuy ? restingId : takerId,
                buyMaker,
                sellMaker,
                taker.baseToken,
                taker.quoteToken,
                execPrice,
                fillBase,
                quoteAmount,
                fee
            );

            if (resting.amount == 0) {
                resting.active = false;
                _removeActiveOrder(restingId);
            }
        }
        if (taker.amount == 0) {
            taker.active = false;
            _removeActiveOrder(takerId);
        }
    }

    function _settle(
        address buyMaker,
        address sellMaker,
        address baseToken,
        address quoteToken,
        uint256 buyLockPrice,
        uint256 execPrice,
        uint256 fillBase,
        bool buyLocked,
        bool sellLocked
    ) internal {
        uint256 quoteAmount = fillBase * execPrice;
        uint256 fee = (quoteAmount * tradingFeeBps) / BPS_DENOM;

        if (sellLocked) {
            locked[baseToken][sellMaker] -= fillBase;
        } else {
            if (balances[baseToken][sellMaker] - locked[baseToken][sellMaker] < fillBase)
                revert InsufficientFreeBalance();
        }
        balances[baseToken][sellMaker] -= fillBase;
        balances[baseToken][buyMaker] += fillBase;

        if (buyLocked) {
            locked[quoteToken][buyMaker] -= fillBase * buyLockPrice;
        } else {
            if (balances[quoteToken][buyMaker] - locked[quoteToken][buyMaker] < quoteAmount)
                revert InsufficientFreeBalance();
        }
        balances[quoteToken][buyMaker] -= quoteAmount;
        balances[quoteToken][sellMaker] += quoteAmount - fee;
        if (fee > 0) {
            balances[quoteToken][feeRecipient] += fee;
        }
    }

    function _findBestMatch(
        address baseToken,
        address quoteToken,
        bool isBuy,
        uint256 price,
        address takerMaker
    ) internal view returns (uint256 bestId) {
        uint256 len = activeOrderIds.length;
        uint256 bestPrice = 0;
        for (uint256 i = 0; i < len; ++i) {
            uint256 id = activeOrderIds[i];
            Order storage o = orders[id];
            if (o.baseToken != baseToken || o.quoteToken != quoteToken) continue;
            if (o.isBuy == isBuy) continue;
            if (o.maker == takerMaker) continue;
            if (isBuy) {
                if (o.price > price) continue;
                if (bestId == 0 || o.price > bestPrice) {
                    bestId = id;
                    bestPrice = o.price;
                }
            } else {
                if (o.price < price) continue;
                if (bestId == 0 || o.price < bestPrice) {
                    bestId = id;
                    bestPrice = o.price;
                }
            }
        }
    }

    function _removeActiveOrder(uint256 orderId) internal {
        uint256 idx = _activeIndex[orderId];
        uint256 lastIdx = activeOrderIds.length - 1;
        if (idx != lastIdx) {
            uint256 lastId = activeOrderIds[lastIdx];
            activeOrderIds[idx] = lastId;
            _activeIndex[lastId] = idx;
        }
        activeOrderIds.pop();
        delete _activeIndex[orderId];
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function setTradingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeUpdated(tradingFeeBps, newFeeBps);
        tradingFeeBps = newFeeBps;
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorTransferred(operator, newOperator);
        operator = newOperator;
    }

    function getActiveOrderIds() external view returns (uint256[] memory) {
        return activeOrderIds;
    }

    function activeOrderCount() external view returns (uint256) {
        return activeOrderIds.length;
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }
}
