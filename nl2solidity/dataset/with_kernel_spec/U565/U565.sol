// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        require(ok, "SafeERC20: transfer failed");
    }

    function safeTransferFromSender(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        require(ok, "SafeERC20: transferFrom failed");
    }
}

contract PooledDerivatives {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error ErrZeroAddress();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrPaused();
    error ErrUnsupportedToken();
    error ErrInsufficientBalance();
    error ErrInsufficientCollateral();
    error ErrPositionNotFound();
    error ErrPositionNotOpen();
    error ErrDailyDepositCapReached();
    error ErrInvalidAmount();
    error ErrInvalidParameter();
    error ErrMaxPositionsReached();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event PositionOpened(
        address indexed user,
        uint256 indexed positionId,
        bool isLong,
        address indexed collateralToken,
        uint256 collateral,
        uint256 size,
        uint256 entryPrice,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        uint256 indexed positionId,
        uint256 exitPrice,
        uint256 pnl,
        uint256 fee
    );
    event TokenSupported(address indexed token, bool supported, bool isStable);
    event DailyDepositCapUpdated(address indexed token, uint256 cap);
    event PositionFeeUpdated(uint256 newFeeBps);
    event MaxLeverageUpdated(uint256 newMaxLeverage);
    event MinPositionSizeUpdated(uint256 newMinSize);
    event OperatorUpdated(address indexed newOperator);
    event PausedStateChanged(bool paused);
    event Upgraded(address indexed newImplementation);
    event CollateralRescued(address indexed token, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_DAILY_CAP = 10_000; // 10,000 base units per token per day
    uint256 public constant MAX_POSITIONS_PER_USER = 50;

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------
    struct Position {
        uint256 id;
        address owner;
        bool isLong;
        address collateralToken;
        uint256 collateral;     // amount of collateral locked
        uint256 size;           // notional size in quote units
        uint256 entryPrice;     // price at open (oracle-scaled, 1e18)
        bool isOpen;
    }

    struct GlobalConfig {
        uint256 positionFeeBps;   // fee in basis points on open/close
        uint256 maxLeverage;      // max leverage multiplier (1e18 scale)
        uint256 minPositionSize;  // minimum notional size
    }

    struct DailyDepositTracker {
        uint256 amount;
        uint256 day;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;
    bool public paused;

    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public stablecoin;

    mapping(address => mapping(address => uint256)) public balances; // user => token => available balance
    mapping(address => DailyDepositTracker) public dailyDeposits;     // token => daily tracker

    mapping(address => uint256) public dailyDepositCap; // token => cap per day (base units)

    mapping(uint256 => Position) public positions;       // positionId => Position
    mapping(address => uint256[]) public userPositionIds; // user => position ids
    uint256 public nextPositionId;

    GlobalConfig public config;

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

    modifier onlySupported(address token) {
        if (!supportedTokens[token]) revert ErrUnsupportedToken();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address operator_) {
        if (operator_ == address(0)) revert ErrZeroAddress();

        owner = msg.sender;
        operator = operator_;
        paused = false;
        nextPositionId = 1;

        config = GlobalConfig({
            positionFeeBps: 10,         // 0.1%
            maxLeverage: 10e18,         // 10x
            minPositionSize: 1e16       // 0.01 quote units
        });
    }

    // ---------------------------------------------------------------------
    // Admin: token management
    // ---------------------------------------------------------------------
    function setTokenSupported(address token, bool supported, bool isStable) external onlyOperator {
        if (token == address(0)) revert ErrZeroAddress();
        supportedTokens[token] = supported;
        stablecoin[token] = isStable;
        if (dailyDepositCap[token] == 0) {
            dailyDepositCap[token] = DEFAULT_DAILY_CAP;
        }
        emit TokenSupported(token, supported, isStable);
    }

    function setDailyDepositCap(address token, uint256 cap) external onlyOperator {
        if (token == address(0)) revert ErrZeroAddress();
        if (cap == 0) revert ErrInvalidParameter();
        dailyDepositCap[token] = cap;
        emit DailyDepositCapUpdated(token, cap);
    }

    // ---------------------------------------------------------------------
    // Admin: risk parameters
    // ---------------------------------------------------------------------
    function setPositionFeeBps(uint256 feeBps) external onlyOperator {
        if (feeBps > 1000) revert ErrInvalidParameter(); // max 10%
        config.positionFeeBps = feeBps;
        emit PositionFeeUpdated(feeBps);
    }

    function setMaxLeverage(uint256 maxLeverage) external onlyOperator {
        if (maxLeverage == 0 || maxLeverage > 100e18) revert ErrInvalidParameter();
        config.maxLeverage = maxLeverage;
        emit MaxLeverageUpdated(maxLeverage);
    }

    function setMinPositionSize(uint256 minSize) external onlyOperator {
        if (minSize == 0) revert ErrInvalidParameter();
        config.minPositionSize = minSize;
        emit MinPositionSizeUpdated(minSize);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit PausedStateChanged(state);
    }

    function upgrade(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ErrZeroAddress();
        emit Upgraded(newImplementation);
    }

    function rescue(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ErrZeroAddress();
        if (amount == 0) revert ErrInvalidAmount();
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        emit CollateralRescued(token, to, amount);
    }

    // ---------------------------------------------------------------------
    // User: deposit
    // ---------------------------------------------------------------------
    function deposit(address token, uint256 amount) external whenNotPaused onlySupported(token) {
        if (amount == 0) revert ErrInvalidAmount();

        uint256 day = block.timestamp / 1 days;
        DailyDepositTracker storage tracker = dailyDeposits[token];
        if (tracker.day != day) {
            tracker.day = day;
            tracker.amount = 0;
        }
        uint256 cap = dailyDepositCap[token];
        if (cap == 0) {
            cap = DEFAULT_DAILY_CAP;
        }
        if (tracker.amount + amount > cap) revert ErrDailyDepositCapReached();
        tracker.amount += amount;

        SafeERC20.safeTransferFromSender(IERC20(token), address(this), amount);
        balances[msg.sender][token] += amount;

        emit Deposit(msg.sender, token, amount, 0);
    }

    // ---------------------------------------------------------------------
    // User: withdraw available collateral
    // ---------------------------------------------------------------------
    function withdraw(address token, uint256 amount) external whenNotPaused onlySupported(token) {
        if (amount == 0) revert ErrInvalidAmount();
        uint256 avail = balances[msg.sender][token];
        if (amount > avail) revert ErrInsufficientBalance();

        balances[msg.sender][token] = avail - amount;
        SafeERC20.safeTransfer(IERC20(token), msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    // ---------------------------------------------------------------------
    // User: open position
    // ---------------------------------------------------------------------
    function openPosition(
        address token,
        bool isLong,
        uint256 collateralAmount,
        uint256 size,
        uint256 entryPrice
    ) external whenNotPaused onlySupported(token) returns (uint256 positionId) {
        if (collateralAmount == 0) revert ErrInvalidAmount();
        if (size == 0) revert ErrInvalidAmount();
        if (entryPrice == 0) revert ErrInvalidParameter();
        if (size < config.minPositionSize) revert ErrInvalidParameter();

        // leverage check: size <= collateral * maxLeverage
        if (size > collateralAmount * config.maxLeverage / 1e18) revert ErrInsufficientCollateral();

        uint256 avail = balances[msg.sender][token];
        if (collateralAmount > avail) revert ErrInsufficientBalance();

        // fee = size * feeBps / BPS_DENOMINATOR, charged from available balance in same token
        uint256 fee = size * config.positionFeeBps / BPS_DENOMINATOR;
        uint256 totalDeduct = collateralAmount + fee;
        if (totalDeduct > avail) revert ErrInsufficientBalance();

        if (userPositionIds[msg.sender].length >= MAX_POSITIONS_PER_USER) revert ErrMaxPositionsReached();

        balances[msg.sender][token] -= totalDeduct;

        positionId = nextPositionId++;
        positions[positionId] = Position({
            id: positionId,
            owner: msg.sender,
            isLong: isLong,
            collateralToken: token,
            collateral: collateralAmount,
            size: size,
            entryPrice: entryPrice,
            isOpen: true
        });
        userPositionIds[msg.sender].push(positionId);

        emit PositionOpened(msg.sender, positionId, isLong, token, collateralAmount, size, entryPrice, fee);
    }

    // ---------------------------------------------------------------------
    // User: close position
    // ---------------------------------------------------------------------
    function closePosition(uint256 positionId, uint256 exitPrice) external whenNotPaused returns (uint256 pnl) {
        Position storage p = positions[positionId];
        if (!p.isOpen) revert ErrPositionNotOpen();
        if (p.owner != msg.sender) revert ErrNotOwner();

        if (exitPrice == 0) revert ErrInvalidParameter();

        // PnL calculation:
        // Long: pnl = size * (exitPrice - entryPrice) / entryPrice
        // Short: pnl = size * (entryPrice - exitPrice) / entryPrice
        if (p.isLong) {
            if (exitPrice >= p.entryPrice) {
                pnl = p.size * (exitPrice - p.entryPrice) / p.entryPrice;
            } else {
                pnl = 0; // loss capped at collateral in this simplified model
            }
        } else {
            if (p.entryPrice > exitPrice) {
                pnl = p.size * (p.entryPrice - exitPrice) / p.entryPrice;
            } else {
                pnl = 0;
            }
        }

        // fee on close = size * feeBps / BPS
        uint256 fee = p.size * config.positionFeeBps / BPS_DENOMINATOR;

        // Return collateral + pnl - fee to available balance
        // Ensure non-negative: if loss exceeds collateral, user gets 0
        uint256 returnAmount = p.collateral + pnl;
        if (returnAmount <= fee) {
            returnAmount = 0;
        } else {
            returnAmount = returnAmount - fee;
        }

        balances[msg.sender][p.collateralToken] += returnAmount;

        p.isOpen = false;

        emit PositionClosed(msg.sender, positionId, exitPrice, pnl, fee);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function getAvailableBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }

    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getDailyDeposit(address token) external view returns (uint256 amount, uint256 day) {
        DailyDepositTracker storage t = dailyDeposits[token];
        return (t.amount, t.day);
    }

    function isStablecoin(address token) external view returns (bool) {
        return stablecoin[token];
    }
}
