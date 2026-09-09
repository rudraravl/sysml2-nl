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
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title PerpetualFuturesExchange
 * @notice Decentralized perpetual futures exchange supporting multiple
 *         collateral tokens and trading pairs with leverage up to 20x.
 */
contract PerpetualFuturesExchange is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_LEVERAGE = 20e18;
    uint256 public constant LEVERAGE_PRECISION = 1e18;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant MAX_POSITION_SIZE = 1e30;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant DEFAULT_FEE_BPS = 5; // 0.05%

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public operator;

    mapping(address => bool) public isApprovedToken;
    address[] public approvedTokensList;

    struct TradingPair {
        bytes32 id;
        address baseToken;
        address quoteToken;
        bool active;
        uint256 currentPrice;
        uint256 maxLeverage;
    }
    mapping(bytes32 => TradingPair) public tradingPairs;
    bytes32[] public tradingPairIds;

    struct Position {
        bytes32 pairId;
        uint256 size;
        uint256 margin;
        uint256 leverage;
        uint256 entryPrice;
        bool isLong;
        uint256 openTime;
    }
    mapping(address => mapping(bytes32 => Position)) public positions;

    mapping(address => mapping(address => uint256)) public accountBalances;
    mapping(address => uint256) public collectedFees;

    uint256 public tradingFeeBps;
    bool public emergencyShutdown;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed account, address indexed asset, uint256 amount);
    event Withdrawal(address indexed account, address indexed asset, uint256 amount);
    event PositionOpened(
        address indexed account,
        bytes32 indexed pairId,
        address indexed asset,
        uint256 size,
        uint256 margin,
        uint256 leverage,
        bool isLong,
        uint256 entryPrice
    );
    event PositionClosed(
        address indexed account,
        bytes32 indexed pairId,
        address indexed asset,
        uint256 size,
        uint256 payout,
        int256 pnl
    );
    event LeverageAdjusted(
        address indexed account,
        bytes32 indexed pairId,
        uint256 oldLeverage,
        uint256 newLeverage,
        uint256 newMargin
    );
    event TradingPairListed(
        bytes32 indexed pairId,
        address indexed baseToken,
        address indexed quoteToken,
        uint256 maxLeverage
    );
    event PairStatusUpdated(bytes32 indexed pairId, bool active);
    event TradingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PriceUpdated(bytes32 indexed pairId, uint256 price);
    event EmergencyShutdownInitiated(address indexed operator);
    event EmergencyShutdownLifted(address indexed operator);
    event TokenApproved(address indexed token);
    event TokenRemoved(address indexed token);
    event FeesClaimed(address indexed token, address indexed recipient, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error OnlyOperator();
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotApproved(address token);
    error TokenAlreadyApproved(address token);
    error PairAlreadyExists(bytes32 pairId);
    error PairNotActive(bytes32 pairId);
    error PairNotFound(bytes32 pairId);
    error PositionAlreadyExists(address account, bytes32 pairId);
    error PositionDoesNotExist(address account, bytes32 pairId);
    error InsufficientBalance(address account, address token, uint256 required, uint256 available);
    error InsufficientMargin(uint256 required, uint256 provided);
    error LeverageExceeded(uint256 leverage, uint256 maxLeverage);
    error InvalidLeverage();
    error InvalidPrice();
    error SizeTooLarge(uint256 size);
    error FeeTooHigh();
    error EmergencyActive();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier notInEmergency() {
        if (emergencyShutdown) revert EmergencyActive();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, address[] memory _approvedTokens) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        tradingFeeBps = DEFAULT_FEE_BPS;
        for (uint256 i = 0; i < _approvedTokens.length; i++) {
            address t = _approvedTokens[i];
            if (t == address(0)) revert ZeroAddress();
            if (!isApprovedToken[t]) {
                isApprovedToken[t] = true;
                approvedTokensList.push(t);
                emit TokenApproved(t);
            }
        }
    }

    // ---------------------------------------------------------------------
    // Operator: token management
    // ---------------------------------------------------------------------
    function approveToken(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isApprovedToken[token]) revert TokenAlreadyApproved(token);
        isApprovedToken[token] = true;
        approvedTokensList.push(token);
        emit TokenApproved(token);
    }

    function removeToken(address token) external onlyOperator {
        if (!isApprovedToken[token]) revert TokenNotApproved(token);
        isApprovedToken[token] = false;
        uint256 len = approvedTokensList.length;
        for (uint256 i = 0; i < len; i++) {
            if (approvedTokensList[i] == token) {
                approvedTokensList[i] = approvedTokensList[len - 1];
                approvedTokensList.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    // ---------------------------------------------------------------------
    // Operator: pair management
    // ---------------------------------------------------------------------
    function listTradingPair(
        address baseToken,
        address quoteToken,
        uint256 maxLeverage,
        uint256 initialPrice
    ) external onlyOperator returns (bytes32 pairId) {
        if (baseToken == address(0) || quoteToken == address(0)) revert ZeroAddress();
        if (!isApprovedToken[quoteToken]) revert TokenNotApproved(quoteToken);
        if (initialPrice == 0 || initialPrice > type(uint128).max) revert InvalidPrice();
        uint256 effectiveMaxLeverage = maxLeverage == 0 ? MAX_LEVERAGE : maxLeverage;
        if (effectiveMaxLeverage > MAX_LEVERAGE) revert LeverageExceeded(effectiveMaxLeverage, MAX_LEVERAGE);
        pairId = keccak256(abi.encode(baseToken, quoteToken));
        if (tradingPairs[pairId].baseToken != address(0)) revert PairAlreadyExists(pairId);
        tradingPairs[pairId] = TradingPair({
            id: pairId,
            baseToken: baseToken,
            quoteToken: quoteToken,
            active: true,
            currentPrice: initialPrice,
            maxLeverage: effectiveMaxLeverage
        });
        tradingPairIds.push(pairId);
        emit TradingPairListed(pairId, baseToken, quoteToken, effectiveMaxLeverage);
    }

    function setPrice(bytes32 pairId, uint256 price) external onlyOperator {
        TradingPair storage pair = tradingPairs[pairId];
        if (pair.baseToken == address(0)) revert PairNotFound(pairId);
        if (price == 0 || price > type(uint128).max) revert InvalidPrice();
        pair.currentPrice = price;
        emit PriceUpdated(pairId, price);
    }

    function setPairStatus(bytes32 pairId, bool active) external onlyOperator {
        TradingPair storage pair = tradingPairs[pairId];
        if (pair.baseToken == address(0)) revert PairNotFound(pairId);
        pair.active = active;
        emit PairStatusUpdated(pairId, active);
    }

    // ---------------------------------------------------------------------
    // Operator: global config
    // ---------------------------------------------------------------------
    function setTradingFee(uint256 feeBps) external onlyOperator {
        if (feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = tradingFeeBps;
        tradingFeeBps = feeBps;
        emit TradingFeeUpdated(old, feeBps);
    }

    function initiateEmergencyShutdown() external onlyOperator {
        emergencyShutdown = true;
        emit EmergencyShutdownInitiated(msg.sender);
    }

    function liftEmergencyShutdown() external onlyOperator {
        emergencyShutdown = false;
        emit EmergencyShutdownLifted(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function claimFees(address token, address recipient, uint256 amount) external onlyOperator nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 accrued = collectedFees[token];
        if (accrued < amount) revert InsufficientBalance(address(this), token, amount, accrued);
        collectedFees[token] = accrued - amount;
        IERC20(token).safeTransfer(recipient, amount);
        emit FeesClaimed(token, recipient, amount);
    }

    // ---------------------------------------------------------------------
    // User: collateral
    // ---------------------------------------------------------------------
    function deposit(address token, uint256 amount) external nonReentrant {
        if (!isApprovedToken[token]) revert TokenNotApproved(token);
        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        accountBalances[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (!isApprovedToken[token]) revert TokenNotApproved(token);
        if (amount == 0) revert ZeroAmount();
        uint256 bal = accountBalances[msg.sender][token];
        if (bal < amount) revert InsufficientBalance(msg.sender, token, amount, bal);
        accountBalances[msg.sender][token] = bal - amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, token, amount);
    }

    // ---------------------------------------------------------------------
    // User: positions
    // ---------------------------------------------------------------------
    function openPosition(
        bytes32 pairId,
        uint256 size,
        uint256 margin,
        uint256 leverage,
        bool isLong
    ) external nonReentrant notInEmergency {
        TradingPair storage pair = tradingPairs[pairId];
        if (pair.baseToken == address(0)) revert PairNotFound(pairId);
        if (!pair.active) revert PairNotActive(pairId);
        if (positions[msg.sender][pairId].openTime != 0) revert PositionAlreadyExists(msg.sender, pairId);
        if (size == 0 || margin == 0) revert ZeroAmount();
        if (size > MAX_POSITION_SIZE) revert SizeTooLarge(size);
        if (leverage == 0) revert InvalidLeverage();
        if (leverage > pair.maxLeverage || leverage > MAX_LEVERAGE) revert LeverageExceeded(leverage, pair.maxLeverage);
        uint256 price = pair.currentPrice;
        if (price == 0) revert InvalidPrice();

        // Compute notional only for validation; perform fee and margin
        // calculations with multiplication before division to avoid
        // precision loss.
        uint256 notional = (size * price) / PRICE_PRECISION;
        if (notional == 0) revert ZeroAmount();

        uint256 minMargin = (size * price * LEVERAGE_PRECISION) / (PRICE_PRECISION * leverage);
        if (margin < minMargin) revert InsufficientMargin(minMargin, margin);

        uint256 fee = (size * price * tradingFeeBps) / (PRICE_PRECISION * FEE_PRECISION);
        uint256 totalCost = margin + fee;
        uint256 bal = accountBalances[msg.sender][pair.quoteToken];
        if (bal < totalCost) revert InsufficientBalance(msg.sender, pair.quoteToken, totalCost, bal);

        accountBalances[msg.sender][pair.quoteToken] = bal - totalCost;
        collectedFees[pair.quoteToken] += fee;

        positions[msg.sender][pairId] = Position({
            pairId: pairId,
            size: size,
            margin: margin,
            leverage: leverage,
            entryPrice: price,
            isLong: isLong,
            openTime: block.timestamp
        });

        emit PositionOpened(msg.sender, pairId, pair.quoteToken, size, margin, leverage, isLong, price);
    }

    function closePosition(bytes32 pairId) external nonReentrant {
        Position storage pos = positions[msg.sender][pairId];
        if (pos.openTime == 0) revert PositionDoesNotExist(msg.sender, pairId);
        TradingPair storage pair = tradingPairs[pairId];
        uint256 price = pair.currentPrice;
        if (price == 0) revert InvalidPrice();

        int256 priceDiff = int256(price) - int256(pos.entryPrice);
        int256 pnl = (int256(pos.size) * priceDiff) / int256(PRICE_PRECISION);
        if (!pos.isLong) pnl = -pnl;

        int256 payoutSigned = int256(pos.margin) + pnl;
        if (payoutSigned < 0) payoutSigned = 0;
        uint256 payout = uint256(payoutSigned);

        // Compute fee with multiplication before division to avoid
        // precision loss from an intermediate notional division.
        uint256 fee = (pos.size * price * tradingFeeBps) / (PRICE_PRECISION * FEE_PRECISION);
        if (payout > fee) {
            collectedFees[pair.quoteToken] += fee;
            payout = payout - fee;
        } else {
            collectedFees[pair.quoteToken] += payout;
            payout = 0;
        }

        accountBalances[msg.sender][pair.quoteToken] += payout;
        uint256 size = pos.size;
        delete positions[msg.sender][pairId];

        emit PositionClosed(msg.sender, pairId, pair.quoteToken, size, payout, pnl);
    }

    function adjustLeverage(bytes32 pairId, uint256 newLeverage) external nonReentrant notInEmergency {
        Position storage pos = positions[msg.sender][pairId];
        if (pos.openTime == 0) revert PositionDoesNotExist(msg.sender, pairId);
        TradingPair storage pair = tradingPairs[pairId];
        if (!pair.active) revert PairNotActive(pairId);
        if (newLeverage == 0) revert InvalidLeverage();
        if (newLeverage > pair.maxLeverage || newLeverage > MAX_LEVERAGE) revert LeverageExceeded(newLeverage, pair.maxLeverage);

        // Compute new margin with multiplication before division to avoid
        // precision loss from an intermediate notional division.
        uint256 newMargin = (pos.size * pos.entryPrice * LEVERAGE_PRECISION) / (PRICE_PRECISION * newLeverage);
        uint256 oldLeverage = pos.leverage;

        if (newMargin < pos.margin) {
            uint256 refund = pos.margin - newMargin;
            accountBalances[msg.sender][pair.quoteToken] += refund;
            pos.margin = newMargin;
        } else if (newMargin > pos.margin) {
            uint256 add = newMargin - pos.margin;
            uint256 bal = accountBalances[msg.sender][pair.quoteToken];
            if (bal < add) revert InsufficientBalance(msg.sender, pair.quoteToken, add, bal);
            accountBalances[msg.sender][pair.quoteToken] = bal - add;
            pos.margin = newMargin;
        }

        pos.leverage = newLeverage;
        emit LeverageAdjusted(msg.sender, pairId, oldLeverage, newLeverage, newMargin);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function getPairId(address baseToken, address quoteToken) public pure returns (bytes32) {
        return keccak256(abi.encode(baseToken, quoteToken));
    }

    function getBalance(address user, address token) external view returns (uint256) {
        return accountBalances[user][token];
    }

    function getPosition(address user, bytes32 pairId) external view returns (Position memory) {
        return positions[user][pairId];
    }

    function getTradingPair(bytes32 pairId) external view returns (TradingPair memory) {
        return tradingPairs[pairId];
    }

    function getApprovedTokens() external view returns (address[] memory) {
        return approvedTokensList;
    }

    function getTradingPairs() external view returns (bytes32[] memory) {
        return tradingPairIds;
    }

    function computePnl(address user, bytes32 pairId) external view returns (int256 pnl, uint256 payout) {
        Position storage pos = positions[user][pairId];
        if (pos.openTime == 0) return (0, 0);
        TradingPair storage pair = tradingPairs[pairId];
        uint256 price = pair.currentPrice;
        if (price == 0) return (0, 0);
        int256 priceDiff = int256(price) - int256(pos.entryPrice);
        pnl = (int256(pos.size) * priceDiff) / int256(PRICE_PRECISION);
        if (!pos.isLong) pnl = -pnl;
        int256 payoutSigned = int256(pos.margin) + pnl;
        if (payoutSigned < 0) payoutSigned = 0;
        payout = uint256(payoutSigned);
    }
}
