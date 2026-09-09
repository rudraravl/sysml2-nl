// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract PerpetualExchange {
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_LEVERAGE = 50e18;        // 50x cap for every pair
    uint256 public constant TAKER_FEE_RATE = 1e14;       // 0.01% taker fee
    int256 private constant MAX_FUNDING_RATE = 1e18;    // defensive cap, 100% per second

    IERC20 public immutable collateral;
    address public operator;

    uint256 public minInitialMargin;                    // minimum margin required to open a position
    uint256 public accumulatedFees;                     // protocol fees collected, in collateral units

    struct Pair {
        bool exists;
        bool active;
        int256 fundingRate;      // per second, signed, in 1e18
        int256 fundingIndex;     // accumulated funding index, in 1e18
        uint256 lastFundingTime; // last timestamp the index was rolled forward
        uint256 markPrice;       // quote per base, in 1e18
    }

    struct Position {
        bool isOpen;
        bool isLong;
        uint256 size;        // base asset amount, in 1e18
        uint256 entryPrice;  // in 1e18
        uint256 margin;      // locked collateral, in 1e18
        int256 fundingIndex; // pair funding index captured at last settlement
    }

    mapping(bytes32 => Pair) private pairs;
    bytes32[] public pairList;

    mapping(address => uint256) public balances; // free collateral per account
    mapping(address => mapping(bytes32 => Position)) private userPositions;

    // ---- events ----
    event Deposit(address indexed account, address indexed asset, uint256 amount);
    event Withdrawal(address indexed account, address indexed asset, uint256 amount);
    event PositionOpened(
        address indexed account,
        bytes32 indexed pairId,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 entryPrice,
        uint256 fee
    );
    event PositionClosed(
        address indexed account,
        bytes32 indexed pairId,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        int256 fundingPnl,
        uint256 fee,
        uint256 returned
    );
    event PairAdded(bytes32 indexed pairId, int256 fundingRate, uint256 markPrice);
    event PairUpdated(bytes32 indexed pairId, bool active, int256 fundingRate, uint256 markPrice);
    event GlobalParamsUpdated(uint256 minInitialMargin);
    event FundingSettled(bytes32 indexed pairId, int256 fundingIndex, uint256 lastFundingTime);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ---- errors ----
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidParameter();
    error InvalidPrice();
    error PairNotFound();
    error PairNotActive();
    error PairAlreadyExists();
    error InsufficientBalance();
    error InsufficientMargin();
    error PositionNotOpen();
    error PositionAlreadyOpen();
    error ExceedsMaxLeverage();
    error FundingRateOutOfBounds();
    error InsufficientFees();
    error TransferFailed();
    error SizeOverflow();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address collateral_, address operator_, uint256 minInitialMargin_) {
        if (collateral_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        collateral = IERC20(collateral_);
        operator = operator_;
        minInitialMargin = minInitialMargin_;
    }

    // ================================================================
    // Internal transfer helpers (replace SafeERC20)
    // ================================================================

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool ok = collateral.transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool ok = collateral.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    // ================================================================
    // User functions
    // ================================================================

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        // effects before interactions
        balances[msg.sender] += amount;
        _safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, address(collateral), amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = balances[msg.sender];
        if (bal < amount) revert InsufficientBalance();
        // effects before interactions
        balances[msg.sender] = bal - amount;
        _safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, address(collateral), amount);
    }

    function openPosition(
        bytes32 pairId,
        bool isLong,
        uint256 margin,
        uint256 size
    ) external {
        if (pairId == bytes32(0)) revert InvalidParameter();
        if (size == 0) revert ZeroAmount();
        if (margin == 0) revert ZeroAmount();
        if (margin < minInitialMargin) revert InsufficientMargin();

        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotFound();
        if (!pair.active) revert PairNotActive();

        uint256 price = pair.markPrice;
        if (price == 0) revert InvalidPrice();

        Position storage pos = userPositions[msg.sender][pairId];
        if (pos.isOpen) revert PositionAlreadyOpen();

        // Guard against overflow when computing size * price * TAKER_FEE_RATE.
        // Realistic trading volumes keep this well below 2^256, but we check defensively.
        if (size > type(uint256).max / price) revert SizeOverflow();
        uint256 notionalRaw = size * price;
        if (notionalRaw > type(uint256).max / TAKER_FEE_RATE) revert SizeOverflow();

        // Leverage guard: notional <= margin * 50x
        uint256 notional = notionalRaw / PRECISION;
        uint256 maxNotional = (margin * MAX_LEVERAGE) / PRECISION;
        if (notional > maxNotional) revert ExceedsMaxLeverage();

        // Roll the global funding index to "now" before snapshotting for the position.
        _updateFundingIndex(pairId);

        // 0.01% taker fee on notional.
        // Compute fee from the raw product to avoid divide-before-multiply precision loss.
        uint256 fee = (notionalRaw * TAKER_FEE_RATE) / (PRECISION * PRECISION);
        uint256 totalNeeded = margin + fee;
        if (balances[msg.sender] < totalNeeded) revert InsufficientBalance();
        balances[msg.sender] -= totalNeeded;
        accumulatedFees += fee;

        pos.isOpen = true;
        pos.isLong = isLong;
        pos.size = size;
        pos.entryPrice = price;
        pos.margin = margin;
        pos.fundingIndex = pair.fundingIndex;

        emit PositionOpened(msg.sender, pairId, isLong, size, margin, price, fee);
    }

    function closePosition(bytes32 pairId) external {
        if (pairId == bytes32(0)) revert InvalidParameter();

        Position storage pos = userPositions[msg.sender][pairId];
        if (!pos.isOpen) revert PositionNotOpen();

        Pair storage pair = pairs[pairId];
        uint256 price = pair.markPrice;
        if (price == 0) revert InvalidPrice();

        _updateFundingIndex(pairId);
        int256 fundingPnl = _accountFunding(pairId, pos);

        uint256 size = pos.size;
        bool isLong = pos.isLong;
        uint256 entryPrice = pos.entryPrice;

        int256 pnl;
        {
            int256 exitNotional = int256((price * size) / PRECISION);
            int256 entryNotional = int256((entryPrice * size) / PRECISION);
            if (isLong) {
                pnl = exitNotional - entryNotional;
            } else {
                pnl = entryNotional - exitNotional;
            }
        }

        // Compute fee from the raw product to avoid divide-before-multiply precision loss.
        // Overflow guarded defensively.
        if (price > type(uint256).max / size) revert SizeOverflow();
        uint256 exitNotionalRaw = price * size;
        if (exitNotionalRaw > type(uint256).max / TAKER_FEE_RATE) revert SizeOverflow();
        uint256 fee = (exitNotionalRaw * TAKER_FEE_RATE) / (PRECISION * PRECISION);
        accumulatedFees += fee;

        int256 net = int256(pos.margin) + pnl + fundingPnl - int256(fee);
        // Initialize `returned` explicitly to avoid uninitialized-local warnings.
        uint256 returned = net > 0 ? uint256(net) : 0;
        if (returned > 0) {
            balances[msg.sender] += returned;
        }

        // Clear the position so the slot can be reused.
        pos.isOpen = false;
        pos.isLong = false;
        pos.size = 0;
        pos.entryPrice = 0;
        pos.margin = 0;
        pos.fundingIndex = 0;

        emit PositionClosed(msg.sender, pairId, size, price, pnl, fundingPnl, fee, returned);
    }

    // ================================================================
    // Operator functions
    // ================================================================

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function addPair(bytes32 pairId, int256 fundingRate, uint256 markPrice) external onlyOperator {
        if (pairId == bytes32(0)) revert InvalidParameter();
        if (markPrice == 0) revert InvalidPrice();
        if (fundingRate > MAX_FUNDING_RATE || fundingRate < -MAX_FUNDING_RATE) {
            revert FundingRateOutOfBounds();
        }

        Pair storage p = pairs[pairId];
        if (p.exists) revert PairAlreadyExists();

        p.exists = true;
        p.active = true;
        p.fundingRate = fundingRate;
        p.fundingIndex = 0;
        p.lastFundingTime = block.timestamp;
        p.markPrice = markPrice;

        pairList.push(pairId);
        emit PairAdded(pairId, fundingRate, markPrice);
    }

    function updatePair(
        bytes32 pairId,
        bool active,
        int256 fundingRate,
        uint256 markPrice
    ) external onlyOperator {
        if (pairId == bytes32(0)) revert InvalidParameter();
        if (markPrice == 0) revert InvalidPrice();
        if (fundingRate > MAX_FUNDING_RATE || fundingRate < -MAX_FUNDING_RATE) {
            revert FundingRateOutOfBounds();
        }

        Pair storage p = pairs[pairId];
        if (!p.exists) revert PairNotFound();

        // Settle accrued funding at the old rate before switching.
        _updateFundingIndex(pairId);

        p.active = active;
        p.fundingRate = fundingRate;
        p.markPrice = markPrice;

        emit PairUpdated(pairId, active, fundingRate, markPrice);
    }

    function setGlobalParams(uint256 minInitialMargin_) external onlyOperator {
        minInitialMargin = minInitialMargin_;
        emit GlobalParamsUpdated(minInitialMargin_);
    }

    function settleFunding(bytes32 pairId) external onlyOperator {
        if (pairId == bytes32(0)) revert InvalidParameter();
        Pair storage p = pairs[pairId];
        if (!p.exists) revert PairNotFound();
        _updateFundingIndex(pairId);
        emit FundingSettled(pairId, p.fundingIndex, p.lastFundingTime);
    }

    function withdrawFees(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (accumulatedFees < amount) revert InsufficientFees();
        accumulatedFees -= amount;
        _safeTransfer(msg.sender, amount);
        emit FeesWithdrawn(msg.sender, amount);
    }

    // ================================================================
    // Internal helpers
    // ================================================================

    function _updateFundingIndex(bytes32 pairId) internal {
        Pair storage p = pairs[pairId];
        uint256 last = p.lastFundingTime;
        if (last == 0) {
            p.lastFundingTime = block.timestamp;
            return;
        }
        uint256 dt = block.timestamp - last;
        int256 rate = p.fundingRate;
        // Avoid strict equality on dt; when dt is zero the contribution is zero anyway.
        if (rate != 0 && dt > 0) {
            p.fundingIndex += rate * int256(dt);
        }
        p.lastFundingTime = block.timestamp;
    }

    function _accountFunding(bytes32 pairId, Position storage pos)
        internal
        view
        returns (int256 fundingPnl)
    {
        Pair storage p = pairs[pairId];
        int256 deltaIndex = p.fundingIndex - pos.fundingIndex;
        if (deltaIndex == 0) {
            return 0;
        }
        uint256 notional = (pos.size * p.markPrice) / PRECISION;
        int256 payment = (int256(notional) * deltaIndex) / int256(PRECISION);
        if (pos.isLong) {
            // Positive rate: longs pay shorts.
            return -payment;
        }
        return payment;
    }

    // ================================================================
    // Views
    // ================================================================

    function getPair(bytes32 pairId) external view returns (Pair memory) {
        return pairs[pairId];
    }

    function getPosition(address account, bytes32 pairId) external view returns (Position memory) {
        return userPositions[account][pairId];
    }

    function pairCount() external view returns (uint256) {
        return pairList.length;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
