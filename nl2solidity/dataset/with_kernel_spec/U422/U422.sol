// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ConcentratedLiquidityDEX {
    // ============ Custom Errors ============
    error Unauthorized();
    error PoolNotFound();
    error PoolNotInitialized();
    error PoolAlreadyExists();
    error TradingPaused();
    error InvalidTickRange();
    error InsufficientDeposit();
    error FeeTooHigh();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InvalidPriceLimit();
    error NoFeesToClaim();
    error SlippageExceeded();
    error PositionNotFound();
    error TransferFailed();

    // ============ Events ============
    event PoolCreated(address indexed token0, address indexed token1, uint24 fee);
    event PoolInitialized(address indexed poolId, uint160 sqrtPriceX96, int24 tick);
    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        address indexed poolId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );
    event LiquidityAdded(
        uint256 indexed positionId,
        uint128 liquidityDelta,
        uint256 amount0,
        uint256 amount1
    );
    event LiquidityRemoved(
        uint256 indexed positionId,
        uint128 liquidityDelta,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address indexed poolId,
        address indexed sender,
        address indexed recipient,
        bool zeroForOne,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity
    );
    event FeesClaimed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 amount0,
        uint256 amount1
    );
    event FeeUpdated(address indexed poolId, uint24 newFee);
    event TradingPausedStateChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ============ Constants ============
    uint24 public constant MAX_FEE = 10000; // 1% in basis points (1e6 scale)
    uint256 public constant MIN_BASE_DEPOSIT = 100;
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = 887272;
    uint160 public constant MIN_SQRT_PRICE = 4295128739;
    uint160 public constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    // ============ Structs ============
    struct Pool {
        address token0;
        address token1;
        uint24 fee;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        bool initialized;
    }

    struct Position {
        address owner;
        address poolId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        uint256 deposited0;
        uint256 deposited1;
    }

    struct TickInfo {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        bool initialized;
    }

    struct PositionView {
        address owner;
        address poolId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 deposited0;
        uint256 deposited1;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
    }

    struct PoolView {
        address token0;
        address token1;
        uint24 fee;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        bool initialized;
    }

    struct TickView {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        bool initialized;
    }

    struct Amounts {
        uint256 amount0;
        uint256 amount1;
    }

    // ============ State Variables ============
    address public owner;
    address public operator;
    bool public tradingPaused;

    uint256 public nextPositionId;
    mapping(uint256 => Position) public positions;
    mapping(address => Pool) public pools;
    mapping(address => mapping(int24 => TickInfo)) public tickData;
    mapping(address => uint256) public poolBalances0;
    mapping(address => uint256) public poolBalances1;

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notPaused() {
        if (tradingPaused) revert TradingPaused();
        _;
    }

    // ============ Constructor ============
    constructor(address _operator) {
        if (_operator == address(0)) revert Unauthorized();
        owner = msg.sender;
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    // ============ Admin Functions ============
    function setOperator(address _newOperator) external {
        if (msg.sender != owner && msg.sender != operator) revert Unauthorized();
        if (_newOperator == address(0)) revert Unauthorized();
        address old = operator;
        operator = _newOperator;
        emit OperatorChanged(old, _newOperator);
    }

    function setTradingPaused(bool _paused) external onlyOperator {
        tradingPaused = _paused;
        emit TradingPausedStateChanged(_paused);
    }

    function addTokenPair(address token0, address token1, uint24 fee)
        external
        onlyOperator
        returns (address poolId)
    {
        if (fee > MAX_FEE) revert FeeTooHigh();
        if (token0 == token1) revert PoolAlreadyExists();
        poolId = _poolId(token0, token1);
        if (pools[poolId].token0 != address(0)) revert PoolAlreadyExists();

        (address t0, address t1) = token0 < token1 ? (token0, token1) : (token1, token0);
        pools[poolId] = Pool({
            token0: t0,
            token1: t1,
            fee: fee,
            sqrtPriceX96: 0,
            tick: 0,
            liquidity: 0,
            feeGrowthGlobal0X128: 0,
            feeGrowthGlobal1X128: 0,
            initialized: false
        });

        emit PoolCreated(t0, t1, fee);
    }

    function setPoolFee(address poolId, uint24 newFee) external onlyOperator {
        Pool storage pool = pools[poolId];
        if (pool.token0 == address(0)) revert PoolNotFound();
        if (newFee > MAX_FEE) revert FeeTooHigh();
        pool.fee = newFee;
        emit FeeUpdated(poolId, newFee);
    }

    function initializePool(address poolId, uint160 sqrtPriceX96) external onlyOperator {
        Pool storage pool = pools[poolId];
        if (pool.token0 == address(0)) revert PoolNotFound();
        if (pool.initialized) revert PoolAlreadyExists();
        if (sqrtPriceX96 < MIN_SQRT_PRICE || sqrtPriceX96 > MAX_SQRT_PRICE)
            revert InvalidPriceLimit();

        pool.sqrtPriceX96 = sqrtPriceX96;
        pool.tick = _getTickAtSqrtPrice(sqrtPriceX96);
        pool.initialized = true;

        emit PoolInitialized(poolId, sqrtPriceX96, pool.tick);
    }

    // ============ Position Management ============
    function createPosition(
        address poolId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0Max,
        uint256 amount1Max
    ) external notPaused returns (uint256 positionId) {
        Pool storage pool = pools[poolId];
        if (!pool.initialized) revert PoolNotInitialized();
        _checkTicks(tickLower, tickUpper);

        Amounts memory amts = _getAmountsForLiquidity(pool.sqrtPriceX96, tickLower, tickUpper, liquidity);

        if (amts.amount0 < MIN_BASE_DEPOSIT && amts.amount1 < MIN_BASE_DEPOSIT)
            revert InsufficientDeposit();

        if (amts.amount0 > amount0Max || amts.amount1 > amount1Max) revert SlippageExceeded();

        positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            poolId: poolId,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0,
            deposited0: amts.amount0,
            deposited1: amts.amount1
        });

        _updateTick(poolId, tickLower, int128(liquidity), pool.tick);
        _updateTick(poolId, tickUpper, -int128(liquidity), pool.tick);
        pool.liquidity += liquidity;

        poolBalances0[poolId] += amts.amount0;
        poolBalances1[poolId] += amts.amount1;

        _transferIn(pool.token0, msg.sender, amts.amount0);
        _transferIn(pool.token1, msg.sender, amts.amount1);

        emit PositionCreated(positionId, msg.sender, poolId, tickLower, tickUpper, liquidity);
        emit LiquidityAdded(positionId, liquidity, amts.amount0, amts.amount1);
    }

    function addLiquidity(
        uint256 positionId,
        uint128 liquidityDelta,
        uint256 amount0Max,
        uint256 amount1Max
    ) external notPaused returns (uint256 amount0, uint256 amount1) {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert PositionNotFound();
        if (pos.owner != msg.sender) revert Unauthorized();
        Pool storage pool = pools[pos.poolId];
        if (!pool.initialized) revert PoolNotInitialized();

        _collectFees(pos, pool);

        Amounts memory amts = _getAmountsForLiquidity(
            pool.sqrtPriceX96,
            pos.tickLower,
            pos.tickUpper,
            liquidityDelta
        );

        if (amts.amount0 > amount0Max || amts.amount1 > amount1Max) revert SlippageExceeded();

        _updateTick(pos.poolId, pos.tickLower, int128(liquidityDelta), pool.tick);
        _updateTick(pos.poolId, pos.tickUpper, -int128(liquidityDelta), pool.tick);
        pool.liquidity += liquidityDelta;
        pos.liquidity += liquidityDelta;
        pos.deposited0 += amts.amount0;
        pos.deposited1 += amts.amount1;

        poolBalances0[pos.poolId] += amts.amount0;
        poolBalances1[pos.poolId] += amts.amount1;

        _transferIn(pool.token0, msg.sender, amts.amount0);
        _transferIn(pool.token1, msg.sender, amts.amount1);

        amount0 = amts.amount0;
        amount1 = amts.amount1;

        emit LiquidityAdded(positionId, liquidityDelta, amount0, amount1);
    }

    function removeLiquidity(uint256 positionId, uint128 liquidityDelta)
        external
        notPaused
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert PositionNotFound();
        if (pos.owner != msg.sender) revert Unauthorized();
        if (liquidityDelta > pos.liquidity) revert InsufficientLiquidity();
        Pool storage pool = pools[pos.poolId];
        if (!pool.initialized) revert PoolNotInitialized();

        _collectFees(pos, pool);

        Amounts memory amts = _getAmountsForLiquidity(
            pool.sqrtPriceX96,
            pos.tickLower,
            pos.tickUpper,
            liquidityDelta
        );

        _updateTick(pos.poolId, pos.tickLower, -int128(liquidityDelta), pool.tick);
        _updateTick(pos.poolId, pos.tickUpper, int128(liquidityDelta), pool.tick);
        pool.liquidity -= liquidityDelta;
        pos.liquidity -= liquidityDelta;

        poolBalances0[pos.poolId] -= amts.amount0;
        poolBalances1[pos.poolId] -= amts.amount1;

        _transferOut(pool.token0, msg.sender, amts.amount0);
        _transferOut(pool.token1, msg.sender, amts.amount1);

        amount0 = amts.amount0;
        amount1 = amts.amount1;

        emit LiquidityRemoved(positionId, liquidityDelta, amount0, amount1);
    }

    function claimFees(uint256 positionId)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage pos = positions[positionId];
        if (pos.owner == address(0)) revert PositionNotFound();
        if (pos.owner != msg.sender) revert Unauthorized();
        Pool storage pool = pools[pos.poolId];
        if (!pool.initialized) revert PoolNotInitialized();

        _collectFees(pos, pool);

        amount0 = pos.tokensOwed0;
        amount1 = pos.tokensOwed1;
        if (amount0 == 0 && amount1 == 0) revert NoFeesToClaim();

        pos.tokensOwed0 = 0;
        pos.tokensOwed1 = 0;

        poolBalances0[pos.poolId] -= amount0;
        poolBalances1[pos.poolId] -= amount1;

        if (amount0 > 0) _transferOut(pool.token0, msg.sender, amount0);
        if (amount1 > 0) _transferOut(pool.token1, msg.sender, amount1);

        emit FeesClaimed(positionId, msg.sender, amount0, amount1);
    }

    // ============ Swap ============
    function swap(
        address poolId,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut,
        uint160 sqrtPriceLimitX96
    ) external notPaused returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];
        if (!pool.initialized) revert PoolNotInitialized();
        if (amountIn == 0) revert ZeroAmount();
        if (pool.liquidity == 0) revert InsufficientLiquidity();

        if (zeroForOne) {
            if (sqrtPriceLimitX96 >= pool.sqrtPriceX96 || sqrtPriceLimitX96 < MIN_SQRT_PRICE)
                revert InvalidPriceLimit();
        } else {
            if (sqrtPriceLimitX96 <= pool.sqrtPriceX96 || sqrtPriceLimitX96 > MAX_SQRT_PRICE)
                revert InvalidPriceLimit();
        }

        uint256 feeAmount = (amountIn * pool.fee) / 1_000_000;
        uint256 amountInAfterFee = amountIn - feeAmount;
        uint160 sqrtPriceBefore = pool.sqrtPriceX96;
        uint256 liquidity = pool.liquidity;

        if (zeroForOne) {
            uint256 newSqrtPrice = sqrtPriceBefore - (amountInAfterFee << 96) / liquidity;
            if (newSqrtPrice < sqrtPriceLimitX96) newSqrtPrice = sqrtPriceLimitX96;
            amountOut = ((sqrtPriceBefore - newSqrtPrice) * liquidity) >> 96;
            pool.sqrtPriceX96 = uint160(newSqrtPrice);
            pool.tick = _getTickAtSqrtPrice(uint160(newSqrtPrice));

            pool.feeGrowthGlobal0X128 += (feeAmount << 128) / liquidity;
            poolBalances0[poolId] += amountIn;
            poolBalances1[poolId] -= amountOut;

            _transferIn(pool.token0, msg.sender, amountIn);
            _transferOut(pool.token1, msg.sender, amountOut);
        } else {
            uint256 newSqrtPrice = sqrtPriceBefore + (amountInAfterFee << 96) / liquidity;
            if (newSqrtPrice > sqrtPriceLimitX96) newSqrtPrice = sqrtPriceLimitX96;
            amountOut = ((newSqrtPrice - sqrtPriceBefore) * liquidity) >> 96;
            pool.sqrtPriceX96 = uint160(newSqrtPrice);
            pool.tick = _getTickAtSqrtPrice(uint160(newSqrtPrice));

            pool.feeGrowthGlobal1X128 += (feeAmount << 128) / liquidity;
            poolBalances1[poolId] += amountIn;
            poolBalances0[poolId] -= amountOut;

            _transferIn(pool.token1, msg.sender, amountIn);
            _transferOut(pool.token0, msg.sender, amountOut);
        }

        if (amountOut < minAmountOut) revert SlippageExceeded();

        int256 amt0 = zeroForOne ? int256(amountIn) : -int256(amountOut);
        int256 amt1 = zeroForOne ? -int256(amountOut) : int256(amountIn);

        emit Swap(
            poolId,
            msg.sender,
            msg.sender,
            zeroForOne,
            amt0,
            amt1,
            pool.sqrtPriceX96,
            pool.liquidity
        );
    }

    // ============ View Functions ============
    function getPosition(uint256 positionId) external view returns (PositionView memory view_) {
        Position storage pos = positions[positionId];
        view_ = PositionView({
            owner: pos.owner,
            poolId: pos.poolId,
            tickLower: pos.tickLower,
            tickUpper: pos.tickUpper,
            liquidity: pos.liquidity,
            deposited0: pos.deposited0,
            deposited1: pos.deposited1,
            tokensOwed0: pos.tokensOwed0,
            tokensOwed1: pos.tokensOwed1
        });
    }

    function getPool(address poolId) external view returns (PoolView memory view_) {
        Pool storage p = pools[poolId];
        view_ = PoolView({
            token0: p.token0,
            token1: p.token1,
            fee: p.fee,
            sqrtPriceX96: p.sqrtPriceX96,
            tick: p.tick,
            liquidity: p.liquidity,
            initialized: p.initialized
        });
    }

    function getTickInfo(address poolId, int24 tick) external view returns (TickView memory view_) {
        TickInfo storage info = tickData[poolId][tick];
        view_ = TickView({
            liquidityGross: info.liquidityGross,
            liquidityNet: info.liquidityNet,
            feeGrowthOutside0X128: info.feeGrowthOutside0X128,
            feeGrowthOutside1X128: info.feeGrowthOutside1X128,
            initialized: info.initialized
        });
    }

    // ============ Internal Functions ============
    function _poolId(address token0, address token1) internal pure returns (address) {
        (address t0, address t1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return address(uint160(uint256(keccak256(abi.encodePacked(t0, t1)))));
    }

    function _checkTicks(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (tickLower < MIN_TICK || tickUpper > MAX_TICK) revert InvalidTickRange();
    }

    function _updateTick(
        address poolId,
        int24 tick,
        int128 liquidityDelta,
        int24 currentTick
    ) internal {
        TickInfo storage info = tickData[poolId][tick];
        uint128 grossBefore = info.liquidityGross;
        uint128 grossAfter = _addDelta(grossBefore, liquidityDelta);
        info.liquidityGross = grossAfter;
        info.liquidityNet += liquidityDelta;

        if (grossBefore == 0 && grossAfter > 0) {
            info.initialized = true;
            Pool storage pool = pools[poolId];
            if (tick <= currentTick) {
                info.feeGrowthOutside0X128 = pool.feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = pool.feeGrowthGlobal1X128;
            }
        }
    }

    function _collectFees(Position storage pos, Pool storage pool) internal {
        if (pos.liquidity == 0) return;

        (uint256 feeGrowthInside0, uint256 feeGrowthInside1) = _getFeeGrowthInside(pos, pool);

        uint256 owed0 = ((feeGrowthInside0 - pos.feeGrowthInside0LastX128) * pos.liquidity) >> 128;
        uint256 owed1 = ((feeGrowthInside1 - pos.feeGrowthInside1LastX128) * pos.liquidity) >> 128;

        pos.feeGrowthInside0LastX128 = feeGrowthInside0;
        pos.feeGrowthInside1LastX128 = feeGrowthInside1;
        pos.tokensOwed0 += owed0;
        pos.tokensOwed1 += owed1;
    }

    function _getFeeGrowthInside(Position storage pos, Pool storage pool)
        internal
        view
        returns (uint256 feeGrowthInside0, uint256 feeGrowthInside1)
    {
        TickInfo storage lower = tickData[pos.poolId][pos.tickLower];
        TickInfo storage upper = tickData[pos.poolId][pos.tickUpper];

        uint256 feeGrowthBelow0;
        uint256 feeGrowthBelow1;
        if (pool.tick >= pos.tickLower) {
            feeGrowthBelow0 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0 = pool.feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1 = pool.feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        uint256 feeGrowthAbove0;
        uint256 feeGrowthAbove1;
        if (pool.tick < pos.tickUpper) {
            feeGrowthAbove0 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0 = pool.feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1 = pool.feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0 = pool.feeGrowthGlobal0X128 - feeGrowthBelow0 - feeGrowthAbove0;
        feeGrowthInside1 = pool.feeGrowthGlobal1X128 - feeGrowthBelow1 - feeGrowthAbove1;
    }

    function _getAmountsForLiquidity(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal pure returns (Amounts memory amts) {
        uint160 sqrtRatioAX96 = _getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = _getSqrtRatioAtTick(tickUpper);

        if (sqrtPriceX96 <= sqrtRatioAX96) {
            amts.amount0 = _getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtPriceX96 < sqrtRatioBX96) {
            amts.amount0 = _getAmount0ForLiquidity(sqrtPriceX96, sqrtRatioBX96, liquidity);
            amts.amount1 = _getAmount1ForLiquidity(sqrtRatioAX96, sqrtPriceX96, liquidity);
        } else {
            amts.amount1 = _getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }

    function _getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }
        uint256 numerator1 = uint256(liquidity) << 96;
        uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;
        amount0 = (numerator1 * numerator2) / sqrtRatioBX96 / sqrtRatioAX96;
    }

    function _getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }
        amount1 = (uint256(liquidity) * (sqrtRatioBX96 - sqrtRatioAX96)) >> 96;
    }

    function _addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            z = x - uint128(-y);
        } else {
            z = x + uint128(y);
        }
    }

    function _getTickAtSqrtPrice(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        if (sqrtPriceX96 == 0) return MIN_TICK;
        uint256 priceX96 = (uint256(sqrtPriceX96) * sqrtPriceX96) >> 96;
        uint256 log2 = 0;
        uint256 p = priceX96;
        if (p >= 1 << 128) { p >>= 128; log2 += 128; }
        if (p >= 1 << 64) { p >>= 64; log2 += 64; }
        if (p >= 1 << 32) { p >>= 32; log2 += 32; }
        if (p >= 1 << 16) { p >>= 16; log2 += 16; }
        if (p >= 1 << 8) { p >>= 8; log2 += 8; }
        if (p >= 1 << 4) { p >>= 4; log2 += 4; }
        if (p >= 1 << 2) { p >>= 2; log2 += 2; }
        if (p >= 1 << 1) { log2 += 1; }
        int256 logPrice = int256(log2) - 96;
        tick = int24((logPrice * 6932) / 10000);
        if (tick < MIN_TICK) tick = MIN_TICK;
        if (tick > MAX_TICK) tick = MAX_TICK;
    }

    function _getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        if (tick == 0) return uint160(1 << 96);
        bool negative = tick < 0;
        uint256 absTick = uint256(negative ? -int256(tick) : int256(tick));

        uint256 ratio;
        if (absTick < 256) {
            ratio = uint256(1 << 96) * (1e18 + (absTick * 1e14) / 2) / 1e18;
        } else {
            uint256 power = absTick / 2;
            ratio = uint256(1 << 96);
            for (uint256 i = 0; i < power && i < 500; i++) {
                ratio = ratio * 10001 / 10000;
            }
        }
        if (negative) {
            sqrtPriceX96 = uint160((uint256(1 << 192)) / ratio);
        } else {
            sqrtPriceX96 = uint160(ratio);
        }
        if (sqrtPriceX96 < MIN_SQRT_PRICE) return MIN_SQRT_PRICE;
        if (sqrtPriceX96 > MAX_SQRT_PRICE) return MAX_SQRT_PRICE;
    }

    // ============ Transfer Helpers ============
    function _transferIn(address token, address from, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _transferOut(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
