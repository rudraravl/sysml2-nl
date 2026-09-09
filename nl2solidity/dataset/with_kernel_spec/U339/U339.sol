// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedSpotExchange {
    struct Order {
        address maker;
        address baseToken;
        address quoteToken;
        uint256 price;        // quote units per base unit, scaled by 1e18
        uint256 amount;       // total base units
        uint256 filled;       // base units filled
        uint256 lockedAmount; // collateral locked: quoteToken if isBuy, else baseToken
        bool isBuy;           // true: maker buys base with quote; false: maker sells base for quote
        bool active;
    }

    struct PairConfig {
        uint256 minOrderSize;
        bool enabled;
    }

    uint256 public constant PRICE_SCALE = 1e18;
    uint256 public constant FEE_SCALE = 10000;
    uint256 public constant MAX_OPEN_ORDERS_PER_ACCOUNT = 100;
    uint256 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 public constant FEE_BPS_DEFAULT = 10; // 0.1%

    address public owner;
    address public feeRecipient;
    uint256 public feeBps = FEE_BPS_DEFAULT;
    bool public paused;

    uint256 public nextOrderId = 1;
    uint256 private _guard = 1;

    mapping(address => bool) public supportedTokens;
    mapping(address => mapping(address => uint256)) public balances; // user => token => available amount
    mapping(uint256 => Order) public orders;
    mapping(address => uint256) public openOrderCount;
    mapping(address => uint256) public feesCollected; // token => amount
    mapping(bytes32 => PairConfig) public pairConfigs; // keccak256(base, quote) => config

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        address indexed baseToken,
        address quoteToken,
        bool isBuy,
        uint256 price,
        uint256 amount,
        uint256 lockedAmount
    );
    event OrderCancelled(
        uint256 indexed orderId,
        address indexed maker,
        uint256 remainingAmount,
        uint256 refundedAmount
    );
    event OrderFilled(
        uint256 indexed orderId,
        address indexed taker,
        address indexed maker,
        address baseToken,
        address quoteToken,
        bool isBuy,
        uint256 amountFilled,
        uint256 price,
        uint256 quoteAmount,
        uint256 fee
    );
    event SupportedTokenAdded(address indexed token);
    event SupportedTokenRemoved(address indexed token);
    event PairConfigUpdated(address indexed baseToken, address indexed quoteToken, uint256 minOrderSize, bool enabled);
    event FeeBpsUpdated(uint256 feeBps);
    event FeeRecipientUpdated(address indexed newRecipient);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event FeesWithdrawn(address indexed token, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidPrice();
    error InvalidPair();
    error UnsupportedToken();
    error AlreadySupported();
    error PairNotEnabled();
    error OrderTooSmall();
    error TooManyOpenOrders();
    error InsufficientBalance();
    error InsufficientCollateral();
    error OrderNotFound();
    error OrderNotActive();
    error FillTooLarge();
    error SelfTrade();
    error NotOrderMaker();
    error NotFeeRecipient();
    error NoFees();
    error FeeTooHigh();
    error TransferFailed();
    error ReentrantCall();
    error WhenPaused();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier nonReentrant() {
        if (_guard != 1) revert ReentrantCall();
        _guard = 2;
        _;
        _guard = 1;
    }

    constructor() {
        owner = msg.sender;
        feeRecipient = msg.sender;
        paused = false;
    }

    // ------------------------- owner / admin -------------------------

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function addSupportedToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (supportedTokens[token]) revert AlreadySupported();
        supportedTokens[token] = true;
        emit SupportedTokenAdded(token);
    }

    function removeSupportedToken(address token) external onlyOwner {
        if (!supportedTokens[token]) revert UnsupportedToken();
        delete supportedTokens[token];
        emit SupportedTokenRemoved(token);
    }

    function setPairConfig(
        address baseToken,
        address quoteToken,
        uint256 minOrderSize,
        bool enabled
    ) external onlyOwner {
        _validatePair(baseToken, quoteToken);
        pairConfigs[_getPairKey(baseToken, quoteToken)] = PairConfig({
            minOrderSize: minOrderSize,
            enabled: enabled
        });
        emit PairConfigUpdated(baseToken, quoteToken, minOrderSize, enabled);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
        emit FeeBpsUpdated(newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function withdrawFees(address token) external nonReentrant {
        if (msg.sender != feeRecipient) revert NotFeeRecipient();
        uint256 amount = feesCollected[token];
        if (amount == 0) revert NoFees();
        feesCollected[token] = 0;
        if (!_safeTransfer(token, msg.sender, amount)) revert TransferFailed();
        emit FeesWithdrawn(token, amount);
    }

    // ------------------------- user / trading -------------------------

    function deposit(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (!supportedTokens[token]) revert UnsupportedToken();
        if (amount == 0) revert InvalidAmount();
        if (!_safeTransferFrom(token, msg.sender, address(this), amount)) revert TransferFailed();
        balances[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        uint256 userBalance = balances[msg.sender][token];
        if (amount > userBalance) revert InsufficientBalance();

        balances[msg.sender][token] = userBalance - amount;
        if (!_safeTransfer(token, msg.sender, amount)) revert TransferFailed();
        emit Withdraw(msg.sender, token, amount);
    }

    function placeOrder(
        address baseToken,
        address quoteToken,
        bool isBuy,
        uint256 price,
        uint256 amount
    ) external whenNotPaused nonReentrant returns (uint256 orderId) {
        _validatePair(baseToken, quoteToken);

        PairConfig memory cfg = pairConfigs[_getPairKey(baseToken, quoteToken)];
        if (!cfg.enabled) revert PairNotEnabled();
        if (amount < cfg.minOrderSize) revert OrderTooSmall();
        if (price == 0) revert InvalidPrice();
        if (openOrderCount[msg.sender] >= MAX_OPEN_ORDERS_PER_ACCOUNT) revert TooManyOpenOrders();

        address collateralToken = isBuy ? quoteToken : baseToken;
        uint256 lockedAmount;
        if (isBuy) {
            lockedAmount = (amount * price) / PRICE_SCALE;
        } else {
            lockedAmount = amount;
        }

        if (lockedAmount == 0) revert InvalidAmount();
        if (balances[msg.sender][collateralToken] < lockedAmount) revert InsufficientBalance();

        balances[msg.sender][collateralToken] -= lockedAmount;

        orderId = nextOrderId++;
        orders[orderId] = Order({
            maker: msg.sender,
            baseToken: baseToken,
            quoteToken: quoteToken,
            price: price,
            amount: amount,
            filled: 0,
            lockedAmount: lockedAmount,
            isBuy: isBuy,
            active: true
        });
        openOrderCount[msg.sender]++;

        emit OrderPlaced(orderId, msg.sender, baseToken, quoteToken, isBuy, price, amount, lockedAmount);
    }

    function cancelOrder(uint256 orderId) external whenNotPaused nonReentrant {
        Order storage order = orders[orderId];
        if (order.maker == address(0)) revert OrderNotFound();
        if (order.maker != msg.sender) revert NotOrderMaker();
        if (!order.active) revert OrderNotActive();

        order.active = false;
        openOrderCount[msg.sender]--;

        address collateralToken = order.isBuy ? order.quoteToken : order.baseToken;
        uint256 refund = order.lockedAmount;
        order.lockedAmount = 0;

        balances[msg.sender][collateralToken] += refund;

        emit OrderCancelled(orderId, msg.sender, order.amount - order.filled, refund);
    }

    function fillOrder(uint256 orderId, uint256 amountToFill) external whenNotPaused nonReentrant {
        Order storage order = orders[orderId];
        if (order.maker == address(0)) revert OrderNotFound();
        if (!order.active) revert OrderNotActive();
        if (msg.sender == order.maker) revert SelfTrade();
        if (amountToFill == 0) revert InvalidAmount();

        PairConfig memory cfg = pairConfigs[_getPairKey(order.baseToken, order.quoteToken)];
        if (!cfg.enabled) revert PairNotEnabled();

        uint256 remaining = order.amount - order.filled;
        if (amountToFill > remaining) revert FillTooLarge();

        // Compute the raw (untruncated) quote value so that the fee is derived
        // from full-precision arithmetic, avoiding divide-before-multiply.
        // fee = (amountToFill * order.price * feeBps) / (PRICE_SCALE * FEE_SCALE)
        uint256 rawQuote = amountToFill * order.price;
        uint256 quoteAmount = rawQuote / PRICE_SCALE;
        if (quoteAmount == 0) revert InvalidAmount();
        uint256 fee = (rawQuote * feeBps) / (PRICE_SCALE * FEE_SCALE);

        if (order.isBuy) {
            // Maker buys base, taker sells base for quote.
            if (balances[msg.sender][order.baseToken] < amountToFill) revert InsufficientBalance();
            if (order.lockedAmount < quoteAmount) revert InsufficientCollateral();

            balances[msg.sender][order.baseToken] -= amountToFill;
            balances[order.maker][order.baseToken] += amountToFill;
            balances[msg.sender][order.quoteToken] += quoteAmount - fee;
            feesCollected[order.quoteToken] += fee;
            order.lockedAmount -= quoteAmount;
        } else {
            // Maker sells base, taker buys base with quote.
            if (balances[msg.sender][order.quoteToken] < quoteAmount) revert InsufficientBalance();
            if (order.lockedAmount < amountToFill) revert InsufficientCollateral();

            balances[msg.sender][order.quoteToken] -= quoteAmount;
            balances[order.maker][order.quoteToken] += quoteAmount - fee;
            feesCollected[order.quoteToken] += fee;
            balances[msg.sender][order.baseToken] += amountToFill;
            order.lockedAmount -= amountToFill;
        }

        order.filled += amountToFill;

        if (order.filled == order.amount) {
            order.active = false;
            openOrderCount[order.maker]--;

            address collateralToken = order.isBuy ? order.quoteToken : order.baseToken;
            uint256 leftover = order.lockedAmount;
            if (leftover > 0) {
                balances[order.maker][collateralToken] += leftover;
                order.lockedAmount = 0;
            }
        }

        emit OrderFilled(
            orderId,
            msg.sender,
            order.maker,
            order.baseToken,
            order.quoteToken,
            order.isBuy,
            amountToFill,
            order.price,
            quoteAmount,
            fee
        );
    }

    // ------------------------- view helpers -------------------------

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    function getPairConfig(address baseToken, address quoteToken)
        external
        view
        returns (uint256 minOrderSize, bool enabled)
    {
        PairConfig storage cfg = pairConfigs[_getPairKey(baseToken, quoteToken)];
        return (cfg.minOrderSize, cfg.enabled);
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }

    function isSupportedToken(address token) external view returns (bool) {
        return supportedTokens[token];
    }

    function getPairKey(address baseToken, address quoteToken) external pure returns (bytes32) {
        return _getPairKey(baseToken, quoteToken);
    }

    // ------------------------- internals -------------------------

    function _validatePair(address baseToken, address quoteToken) internal view {
        if (baseToken == address(0) || quoteToken == address(0)) revert ZeroAddress();
        if (baseToken == quoteToken) revert InvalidPair();
        if (!supportedTokens[baseToken] || !supportedTokens[quoteToken]) revert UnsupportedToken();
    }

    function _getPairKey(address baseToken, address quoteToken) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseToken, quoteToken));
    }

    function _safeTransfer(address token, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }
}
