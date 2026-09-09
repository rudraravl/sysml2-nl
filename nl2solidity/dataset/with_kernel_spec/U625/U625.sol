// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PrincipalProtectedAMM {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error ErrZeroAddress();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrPaused();
    error ErrPairNotSupported();
    error ErrPairAlreadySupported();
    error ErrMaxPairsReached();
    error ErrSameToken();
    error ErrInvalidAmount();
    error ErrInvalidFee();
    error ErrInsufficientBalance();
    error ErrInsufficientLiquidity();
    error ErrInsufficientOutput();
    error ErrPositionNotFound();
    error ErrPositionNotOwner();
    error ErrPositionAlreadyClosed();
    error ErrPositionAlreadyOpen();
    error ErrEthNotAccepted();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event LogDeposit(address indexed user, uint256 indexed pairId, address indexed token, uint256 amount);
    event LogWithdraw(address indexed user, uint256 indexed pairId, address indexed token, uint256 amount);
    event LogPositionOpened(
        uint256 indexed positionId,
        address indexed user,
        uint256 indexed pairId,
        uint256 baseAmount,
        uint256 quoteAmount,
        bool isLong
    );
    event LogPositionClosed(
        uint256 indexed positionId,
        address indexed user,
        uint256 baseReturned,
        uint256 quoteReturned
    );
    event LogSwap(
        address indexed user,
        uint256 indexed pairId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event LogFeeUpdated(uint256 oldFee, uint256 newFee);
    event LogPairAdded(uint256 indexed pairId, address baseToken, address quoteToken);
    event LogPairRemoved(uint256 indexed pairId);
    event LogPausedChanged(bool paused);
    event LogOperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------
    struct Pair {
        address baseToken;
        address quoteToken;
        bool active;
        uint256 baseReserve;
        uint256 quoteReserve;
    }

    struct Position {
        uint256 pairId;
        address owner;
        uint256 baseAmount;
        uint256 quoteAmount;
        bool isLong;
        bool closed;
        uint256 openedAt;
    }

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_PAIRS = 10;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE = 25; // 0.25%

    // ---------------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;
    bool public paused;
    uint256 public swapFee; // in basis points
    uint256 public pairCount;

    mapping(uint256 => Pair) public pairs;
    mapping(address => mapping(uint256 => uint256)) public userBaseDeposits; // user => pairId => baseAmount
    mapping(address => mapping(uint256 => uint256)) public userQuoteDeposits; // user => pairId => quoteAmount
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionIds;
    mapping(address => mapping(uint256 => bool)) public userHasOpenPosition; // user => pairId => hasOpen
    uint256 public nextPositionId;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier pairExists(uint256 pairId) {
        if (pairId >= pairCount || !pairs[pairId].active) revert ErrPairNotSupported();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address operator_) {
        if (operator_ == address(0)) revert ErrZeroAddress();
        owner = msg.sender;
        operator = operator_;
        swapFee = DEFAULT_FEE;
        paused = false;
        nextPositionId = 1;
    }

    receive() external payable {
        revert ErrEthNotAccepted();
    }

    // ---------------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        address old = operator;
        operator = newOperator;
        emit LogOperatorChanged(old, newOperator);
    }

    function setSwapFee(uint256 newFee) external onlyOperator {
        if (newFee > FEE_DENOMINATOR) revert ErrInvalidFee();
        uint256 old = swapFee;
        swapFee = newFee;
        emit LogFeeUpdated(old, newFee);
    }

    function setPaused(bool paused_) external onlyOperator {
        paused = paused_;
        emit LogPausedChanged(paused_);
    }

    function addPair(address baseToken, address quoteToken) external onlyOperator returns (uint256 pairId) {
        if (baseToken == address(0) || quoteToken == address(0)) revert ErrZeroAddress();
        if (baseToken == quoteToken) revert ErrSameToken();
        if (pairCount >= MAX_PAIRS) revert ErrMaxPairsReached();

        for (uint256 i = 0; i < pairCount; i++) {
            Pair storage existing = pairs[i];
            if (
                (existing.baseToken == baseToken && existing.quoteToken == quoteToken) ||
                (existing.baseToken == quoteToken && existing.quoteToken == baseToken)
            ) {
                if (existing.active) revert ErrPairAlreadySupported();
                existing.active = true;
                emit LogPairAdded(i, baseToken, quoteToken);
                return i;
            }
        }

        pairId = pairCount++;
        pairs[pairId] = Pair({
            baseToken: baseToken,
            quoteToken: quoteToken,
            active: true,
            baseReserve: 0,
            quoteReserve: 0
        });
        emit LogPairAdded(pairId, baseToken, quoteToken);
    }

    function removePair(uint256 pairId) external onlyOperator {
        if (pairId >= pairCount || !pairs[pairId].active) revert ErrPairNotSupported();
        pairs[pairId].active = false;
        emit LogPairRemoved(pairId);
    }

    // ---------------------------------------------------------------------
    // Deposit / Withdraw
    // ---------------------------------------------------------------------
    function deposit(uint256 pairId, address token, uint256 amount) external whenNotPaused pairExists(pairId) {
        if (amount == 0) revert ErrInvalidAmount();

        Pair storage pair = pairs[pairId];
        if (token != pair.baseToken && token != pair.quoteToken) revert ErrPairNotSupported();

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert ErrInsufficientBalance();

        if (token == pair.baseToken) {
            userBaseDeposits[msg.sender][pairId] += amount;
            pair.baseReserve += amount;
        } else {
            userQuoteDeposits[msg.sender][pairId] += amount;
            pair.quoteReserve += amount;
        }

        emit LogDeposit(msg.sender, pairId, token, amount);
    }

    function withdraw(uint256 pairId, address token, uint256 amount) external whenNotPaused pairExists(pairId) {
        if (amount == 0) revert ErrInvalidAmount();

        Pair storage pair = pairs[pairId];
        if (token != pair.baseToken && token != pair.quoteToken) revert ErrPairNotSupported();

        if (token == pair.baseToken) {
            if (userBaseDeposits[msg.sender][pairId] < amount) revert ErrInsufficientBalance();
            userBaseDeposits[msg.sender][pairId] -= amount;
            pair.baseReserve -= amount;
        } else {
            if (userQuoteDeposits[msg.sender][pairId] < amount) revert ErrInsufficientBalance();
            userQuoteDeposits[msg.sender][pairId] -= amount;
            pair.quoteReserve -= amount;
        }

        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert ErrInsufficientBalance();

        emit LogWithdraw(msg.sender, pairId, token, amount);
    }

    // ---------------------------------------------------------------------
    // Position Management
    // ---------------------------------------------------------------------
    function openPosition(
        uint256 pairId,
        uint256 baseAmount,
        uint256 quoteAmount,
        bool isLong
    ) external whenNotPaused pairExists(pairId) returns (uint256 positionId) {
        if (baseAmount == 0 && quoteAmount == 0) revert ErrInvalidAmount();
        if (userHasOpenPosition[msg.sender][pairId]) revert ErrPositionAlreadyOpen();

        Pair storage pair = pairs[pairId];

        if (baseAmount > 0 && userBaseDeposits[msg.sender][pairId] < baseAmount) {
            revert ErrInsufficientBalance();
        }
        if (quoteAmount > 0 && userQuoteDeposits[msg.sender][pairId] < quoteAmount) {
            revert ErrInsufficientBalance();
        }

        // Lock principal into the position (tokens remain in contract for principal protection)
        if (baseAmount > 0) {
            userBaseDeposits[msg.sender][pairId] -= baseAmount;
        }
        if (quoteAmount > 0) {
            userQuoteDeposits[msg.sender][pairId] -= quoteAmount;
        }

        positionId = nextPositionId++;
        positions[positionId] = Position({
            pairId: pairId,
            owner: msg.sender,
            baseAmount: baseAmount,
            quoteAmount: quoteAmount,
            isLong: isLong,
            closed: false,
            openedAt: block.timestamp
        });
        userPositionIds[msg.sender].push(positionId);
        userHasOpenPosition[msg.sender][pairId] = true;

        emit LogPositionOpened(positionId, msg.sender, pairId, baseAmount, quoteAmount, isLong);
    }

    function closePosition(uint256 positionId) external whenNotPaused {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert ErrPositionNotFound();
        if (pos.owner != msg.sender) revert ErrPositionNotOwner();
        if (pos.closed) revert ErrPositionAlreadyClosed();

        pos.closed = true;
        userHasOpenPosition[msg.sender][pos.pairId] = false;

        // Return principal to user deposits
        Pair storage pair = pairs[pos.pairId];
        if (pos.baseAmount > 0) {
            userBaseDeposits[msg.sender][pos.pairId] += pos.baseAmount;
        }
        if (pos.quoteAmount > 0) {
            userQuoteDeposits[msg.sender][pos.pairId] += pos.quoteAmount;
        }

        emit LogPositionClosed(positionId, msg.sender, pos.baseAmount, pos.quoteAmount);
    }

    // ---------------------------------------------------------------------
    // Swap
    // ---------------------------------------------------------------------
    function swap(
        uint256 pairId,
        bool baseToQuote,
        uint256 amountIn,
        uint256 minAmountOut
    ) external whenNotPaused pairExists(pairId) returns (uint256 amountOut) {
        if (amountIn == 0) revert ErrInvalidAmount();

        Pair storage pair = pairs[pairId];
        address tokenIn;
        address tokenOut;
        uint256 reserveIn;
        uint256 reserveOut;

        if (baseToQuote) {
            tokenIn = pair.baseToken;
            tokenOut = pair.quoteToken;
            reserveIn = pair.baseReserve;
            reserveOut = pair.quoteReserve;
            if (userBaseDeposits[msg.sender][pairId] < amountIn) revert ErrInsufficientBalance();
        } else {
            tokenIn = pair.quoteToken;
            tokenOut = pair.baseToken;
            reserveIn = pair.quoteReserve;
            reserveOut = pair.baseReserve;
            if (userQuoteDeposits[msg.sender][pairId] < amountIn) revert ErrInsufficientBalance();
        }

        if (reserveIn == 0 || reserveOut == 0) revert ErrInsufficientLiquidity();

        uint256 fee = (amountIn * swapFee) / FEE_DENOMINATOR;
        uint256 amountAfterFee = amountIn - fee;

        // Constant product formula: amountOut = (reserveOut * amountAfterFee) / (reserveIn + amountAfterFee)
        amountOut = (reserveOut * amountAfterFee) / (reserveIn + amountAfterFee);
        if (amountOut == 0 || amountOut < minAmountOut) revert ErrInsufficientOutput();

        // Deduct input from user deposit and pair reserve
        if (baseToQuote) {
            userBaseDeposits[msg.sender][pairId] -= amountIn;
            userQuoteDeposits[msg.sender][pairId] += amountOut;
            pair.baseReserve -= amountIn;
            pair.quoteReserve -= amountOut;
            // Fee remains in the pool as principal-protection buffer
            pair.baseReserve += fee;
        } else {
            userQuoteDeposits[msg.sender][pairId] -= amountIn;
            userBaseDeposits[msg.sender][pairId] += amountOut;
            pair.quoteReserve -= amountIn;
            pair.baseReserve -= amountOut;
            pair.quoteReserve += fee;
        }

        emit LogSwap(msg.sender, pairId, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    // ---------------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------------
    function getUserBaseDeposit(address user, uint256 pairId) external view returns (uint256) {
        return userBaseDeposits[user][pairId];
    }

    function getUserQuoteDeposit(address user, uint256 pairId) external view returns (uint256) {
        return userQuoteDeposits[user][pairId];
    }

    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    function getPair(uint256 pairId)
        external
        view
        returns (address baseToken, address quoteToken, bool active, uint256 baseReserve, uint256 quoteReserve)
    {
        if (pairId >= pairCount) revert ErrPairNotSupported();
        Pair storage p = pairs[pairId];
        return (p.baseToken, p.quoteToken, p.active, p.baseReserve, p.quoteReserve);
    }

    function getPosition(uint256 positionId)
        external
        view
        returns (
            uint256 pairId,
            address positionOwner,
            uint256 baseAmount,
            uint256 quoteAmount,
            bool isLong,
            bool closed,
            uint256 openedAt
        )
    {
        Position storage p = positions[positionId];
        if (p.owner == address(0)) revert ErrPositionNotFound();
        return (p.pairId, p.owner, p.baseAmount, p.quoteAmount, p.isLong, p.closed, p.openedAt);
    }

    function getExpectedSwapOutput(uint256 pairId, bool baseToQuote, uint256 amountIn)
        external
        view
        returns (uint256 amountOut, uint256 fee)
    {
        if (pairId >= pairCount || !pairs[pairId].active) revert ErrPairNotSupported();
        Pair storage pair = pairs[pairId];
        uint256 reserveIn = baseToQuote ? pair.baseReserve : pair.quoteReserve;
        uint256 reserveOut = baseToQuote ? pair.quoteReserve : pair.baseReserve;

        fee = (amountIn * swapFee) / FEE_DENOMINATOR;
        uint256 amountAfterFee = amountIn - fee;
        if (reserveIn == 0 || reserveOut == 0) {
            amountOut = 0;
        } else {
            amountOut = (reserveOut * amountAfterFee) / (reserveIn + amountAfterFee);
        }
    }

    function getSupportedPairCount() external view returns (uint256 count) {
        count = 0;
        for (uint256 i = 0; i < pairCount; i++) {
            if (pairs[i].active) count++;
        }
    }
}
