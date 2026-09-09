// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ConcentratedLiquidityPool {
    uint160 public constant Q96 = 2 ** 96;
    uint256 public constant Q128 = 2 ** 128;
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = 887272;
    int24 public constant MIN_TICK_SPACING = 10;
    uint24 public constant DEFAULT_FEE_TIER = 3000; // 0.3%
    uint24 public constant FEE_DENOMINATOR = 1_000_000;

    address public immutable token0;
    address public immutable token1;
    uint160 public immutable minSqrtPriceX96;
    uint160 public immutable maxSqrtPriceX96;

    address public owner;
    bool public paused;
    uint24 public feeTier;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    struct TickInfo {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        bool initialized;
    }

    struct Position {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct SwapCache {
        uint256 amountSpecifiedRemaining;
        uint160 sqrtPrice;
        int24 tick;
        uint128 liq;
        uint256 amountOutTotal;
    }

    Slot0 public slot0;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;
    uint128 public liquidity;

    mapping(int24 => TickInfo) public ticks;
    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId = 1;

    bool private locked;

    event PositionCreated(uint256 indexed positionId, address indexed owner, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1);
    event LiquidityAdded(uint256 indexed positionId, address indexed owner, uint128 liquidityDelta, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(uint256 indexed positionId, address indexed owner, uint128 liquidityDelta, uint256 amount0, uint256 amount1);
    event FeesCollected(uint256 indexed positionId, address indexed recipient, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, address indexed recipient, bool zeroForOne, int256 amount0, int256 amount1, uint160 sqrtPriceX96, int24 tick, uint128 liquidity);
    event FeeTierUpdated(uint24 oldFeeTier, uint24 newFeeTier);
    event PausedStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotPositionOwner();
    error TicksMisordered(int24 tickLower, int24 tickUpper);
    error TickOutOfBounds(int24 tick);
    error TickSpacingTooSmall(int24 tickLower, int24 tickUpper);
    error PoolPaused();
    error ZeroAmount();
    error InvalidPriceLimit(uint160 sqrtPriceLimitX96);
    error InsufficientLiquidity();
    error PositionHasNoLiquidity();
    error TransferFailed();
    error ReentrancyDetected();
    error InvalidFeeTier();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyPositionOwner(uint256 positionId) {
        if (positions[positionId].owner != msg.sender) revert NotPositionOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PoolPaused();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrancyDetected();
        locked = true;
        _;
        locked = false;
    }

    constructor(address _token0, address _token1, uint160 _sqrtPriceX96) {
        token0 = _token0;
        token1 = _token1;
        owner = msg.sender;
        feeTier = DEFAULT_FEE_TIER;
        paused = false;
        minSqrtPriceX96 = getSqrtPriceAtTick(MIN_TICK);
        maxSqrtPriceX96 = getSqrtPriceAtTick(MAX_TICK);
        if (_sqrtPriceX96 < minSqrtPriceX96 || _sqrtPriceX96 > maxSqrtPriceX96) revert InvalidPriceLimit(_sqrtPriceX96);
        int24 tick = getTickAtSqrtPrice(_sqrtPriceX96);
        slot0 = Slot0({sqrtPriceX96: _sqrtPriceX96, tick: tick});
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert NotOwner();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function setFeeTier(uint24 newFeeTier) external onlyOwner {
        if (newFeeTier > FEE_DENOMINATOR) revert InvalidFeeTier();
        uint24 old = feeTier;
        feeTier = newFeeTier;
        emit FeeTierUpdated(old, newFeeTier);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function createPosition(int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 positionId, uint128 liquidityMinted, uint256 amount0, uint256 amount1)
    {
        _checkTicks(tickLower, tickUpper);
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroAmount();

        uint160 sqrtLower = getSqrtPriceAtTick(tickLower);
        uint160 sqrtUpper = getSqrtPriceAtTick(tickUpper);
        uint160 sqrtCurrent = slot0.sqrtPriceX96;

        liquidityMinted = _getLiquidityForAmounts(sqrtCurrent, sqrtLower, sqrtUpper, amount0Desired, amount1Desired);
        if (liquidityMinted == 0) revert InsufficientLiquidity();

        (amount0, amount1) = _getAmountsForLiquidity(sqrtCurrent, sqrtLower, sqrtUpper, liquidityMinted);

        positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: 0,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        _updatePosition(positionId, int128(int256(uint256(liquidityMinted))));

        _pullToken(token0, msg.sender, address(this), amount0);
        _pullToken(token1, msg.sender, address(this), amount1);

        emit PositionCreated(positionId, msg.sender, tickLower, tickUpper, liquidityMinted, amount0, amount1);
    }

    function addLiquidity(uint256 positionId, uint256 amount0Desired, uint256 amount1Desired)
        external
        nonReentrant
        onlyPositionOwner(positionId)
        whenNotPaused
        returns (uint128 liquidityDelta, uint256 amount0, uint256 amount1)
    {
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroAmount();
        Position storage p = positions[positionId];

        uint160 sqrtLower = getSqrtPriceAtTick(p.tickLower);
        uint160 sqrtUpper = getSqrtPriceAtTick(p.tickUpper);
        uint160 sqrtCurrent = slot0.sqrtPriceX96;

        liquidityDelta = _getLiquidityForAmounts(sqrtCurrent, sqrtLower, sqrtUpper, amount0Desired, amount1Desired);
        if (liquidityDelta == 0) revert InsufficientLiquidity();

        (amount0, amount1) = _getAmountsForLiquidity(sqrtCurrent, sqrtLower, sqrtUpper, liquidityDelta);

        _updatePosition(positionId, int128(int256(uint256(liquidityDelta))));

        _pullToken(token0, msg.sender, address(this), amount0);
        _pullToken(token1, msg.sender, address(this), amount1);

        emit LiquidityAdded(positionId, msg.sender, liquidityDelta, amount0, amount1);
    }

    function removeLiquidity(uint256 positionId, uint128 liquidityToRemove)
        external
        nonReentrant
        onlyPositionOwner(positionId)
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage p = positions[positionId];
        if (p.liquidity < liquidityToRemove) revert PositionHasNoLiquidity();
        if (liquidityToRemove == 0) revert ZeroAmount();

        uint160 sqrtLower = getSqrtPriceAtTick(p.tickLower);
        uint160 sqrtUpper = getSqrtPriceAtTick(p.tickUpper);
        uint160 sqrtCurrent = slot0.sqrtPriceX96;

        (amount0, amount1) = _getAmountsForLiquidity(sqrtCurrent, sqrtLower, sqrtUpper, liquidityToRemove);

        _updatePosition(positionId, -int128(int256(uint256(liquidityToRemove))));

        _pushToken(token0, address(this), msg.sender, amount0);
        _pushToken(token1, address(this), msg.sender, amount1);

        emit LiquidityRemoved(positionId, msg.sender, liquidityToRemove, amount0, amount1);
    }

    function collect(uint256 positionId, address recipient)
        external
        nonReentrant
        onlyPositionOwner(positionId)
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage p = positions[positionId];

        (uint256 inside0, uint256 inside1) = _getFeeGrowthInside(p.tickLower, p.tickUpper, slot0.tick);
        uint256 owed0 = (inside0 - p.feeGrowthInside0LastX128) * p.liquidity / Q128;
        uint256 owed1 = (inside1 - p.feeGrowthInside1LastX128) * p.liquidity / Q128;
        p.feeGrowthInside0LastX128 = inside0;
        p.feeGrowthInside1LastX128 = inside1;
        if (owed0 > 0) p.tokensOwed0 += uint128(owed0);
        if (owed1 > 0) p.tokensOwed1 += uint128(owed1);

        amount0 = p.tokensOwed0;
        amount1 = p.tokensOwed1;
        p.tokensOwed0 = 0;
        p.tokensOwed1 = 0;

        if (amount0 > 0) _pushToken(token0, address(this), recipient, amount0);
        if (amount1 > 0) _pushToken(token1, address(this), recipient, amount1);

        emit FeesCollected(positionId, recipient, amount0, amount1);
    }

    function swap(bool zeroForOne, uint256 amountSpecified, uint160 sqrtPriceLimitX96, address recipient)
        external
        nonReentrant
        whenNotPaused
        returns (int256 amount0, int256 amount1)
    {
        if (amountSpecified == 0) revert ZeroAmount();
        if (zeroForOne) {
            if (!(sqrtPriceLimitX96 < slot0.sqrtPriceX96 && sqrtPriceLimitX96 >= minSqrtPriceX96))
                revert InvalidPriceLimit(sqrtPriceLimitX96);
        } else {
            if (!(sqrtPriceLimitX96 > slot0.sqrtPriceX96 && sqrtPriceLimitX96 <= maxSqrtPriceX96))
                revert InvalidPriceLimit(sqrtPriceLimitX96);
        }

        SwapCache memory cache = SwapCache({
            amountSpecifiedRemaining: amountSpecified,
            sqrtPrice: slot0.sqrtPriceX96,
            tick: slot0.tick,
            liq: liquidity,
            amountOutTotal: 0
        });

        while (cache.amountSpecifiedRemaining > 0 && cache.sqrtPrice != sqrtPriceLimitX96) {
            _swapStep(cache, zeroForOne, sqrtPriceLimitX96);
        }

        slot0.sqrtPriceX96 = cache.sqrtPrice;
        slot0.tick = cache.tick;

        if (zeroForOne) {
            amount0 = int256(amountSpecified);
            amount1 = -int256(cache.amountOutTotal);
            _pullToken(token0, msg.sender, address(this), uint256(amount0));
            _pushToken(token1, address(this), recipient, cache.amountOutTotal);
        } else {
            amount1 = int256(amountSpecified);
            amount0 = -int256(cache.amountOutTotal);
            _pullToken(token1, msg.sender, address(this), uint256(amount1));
            _pushToken(token0, address(this), recipient, cache.amountOutTotal);
        }

        emit Swap(msg.sender, recipient, zeroForOne, amount0, amount1, cache.sqrtPrice, cache.tick, liquidity);
    }

    function _swapStep(SwapCache memory cache, bool zeroForOne, uint160 sqrtPriceLimitX96) internal {
        if (cache.liq == 0) revert InsufficientLiquidity();
        int24 nextTick = _nextInitializedTick(cache.tick, zeroForOne);
        uint160 sqrtNext = getSqrtPriceAtTick(nextTick);
        uint160 sqrtTarget = zeroForOne
            ? (sqrtNext > sqrtPriceLimitX96 ? sqrtNext : sqrtPriceLimitX96)
            : (sqrtNext < sqrtPriceLimitX96 ? sqrtNext : sqrtPriceLimitX96);

        uint256 amountInNet = zeroForOne
            ? _getAmount0Delta(cache.sqrtPrice, sqrtTarget, cache.liq)
            : _getAmount1Delta(cache.sqrtPrice, sqrtTarget, cache.liq);
        uint256 amountOut = zeroForOne
            ? _getAmount1Delta(sqrtTarget, cache.sqrtPrice, cache.liq)
            : _getAmount0Delta(sqrtTarget, cache.sqrtPrice, cache.liq);

        uint256 grossIn = (amountInNet * FEE_DENOMINATOR) / (FEE_DENOMINATOR - feeTier);
        uint256 fee = grossIn - amountInNet;

        if (grossIn <= cache.amountSpecifiedRemaining) {
            cache.amountSpecifiedRemaining -= grossIn;
            cache.sqrtPrice = sqrtTarget;
            cache.amountOutTotal += amountOut;
            if (zeroForOne) {
                feeGrowthGlobal0X128 += (fee * Q128) / cache.liq;
            } else {
                feeGrowthGlobal1X128 += (fee * Q128) / cache.liq;
            }
            if (cache.sqrtPrice == sqrtNext && ticks[nextTick].initialized) {
                _crossTick(nextTick, zeroForOne);
                cache.liq = liquidity;
            }
        } else {
            uint256 remainingGross = cache.amountSpecifiedRemaining;
            uint256 remainingNet = (remainingGross * (FEE_DENOMINATOR - feeTier)) / FEE_DENOMINATOR;
            uint256 remainingFee = remainingGross - remainingNet;
            uint160 sqrtNew;
            if (zeroForOne) {
                uint256 num = uint256(cache.liq) * Q96 * cache.sqrtPrice;
                uint256 den = uint256(cache.liq) * Q96 + remainingNet * cache.sqrtPrice;
                sqrtNew = uint160(num / den);
                if (sqrtNew < sqrtPriceLimitX96) sqrtNew = sqrtPriceLimitX96;
                cache.amountOutTotal += _getAmount1Delta(sqrtNew, cache.sqrtPrice, cache.liq);
                feeGrowthGlobal0X128 += (remainingFee * Q128) / cache.liq;
            } else {
                sqrtNew = uint160(uint256(cache.sqrtPrice) + (remainingNet * Q96) / cache.liq);
                if (sqrtNew > sqrtPriceLimitX96) sqrtNew = sqrtPriceLimitX96;
                cache.amountOutTotal += _getAmount0Delta(sqrtNew, cache.sqrtPrice, cache.liq);
                feeGrowthGlobal1X128 += (remainingFee * Q128) / cache.liq;
            }
            cache.amountSpecifiedRemaining = 0;
            cache.sqrtPrice = sqrtNew;
        }
        cache.tick = getTickAtSqrtPrice(cache.sqrtPrice);
    }

    function _checkTicks(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert TicksMisordered(tickLower, tickUpper);
        if (tickLower < MIN_TICK) revert TickOutOfBounds(tickLower);
        if (tickUpper > MAX_TICK) revert TickOutOfBounds(tickUpper);
        if (tickUpper - tickLower < MIN_TICK_SPACING) revert TickSpacingTooSmall(tickLower, tickUpper);
    }

    function _updatePosition(uint256 positionId, int128 liquidityDelta) internal {
        Position storage p = positions[positionId];
        (uint256 inside0, uint256 inside1) = _getFeeGrowthInside(p.tickLower, p.tickUpper, slot0.tick);

        uint256 owed0 = (inside0 - p.feeGrowthInside0LastX128) * p.liquidity / Q128;
        uint256 owed1 = (inside1 - p.feeGrowthInside1LastX128) * p.liquidity / Q128;

        p.feeGrowthInside0LastX128 = inside0;
        p.feeGrowthInside1LastX128 = inside1;

        if (liquidityDelta != 0) {
            p.liquidity = _addDelta(p.liquidity, liquidityDelta);
            _updateTick(p.tickLower, liquidityDelta, slot0.tick);
            _updateTick(p.tickUpper, -liquidityDelta, slot0.tick);
        }

        if (owed0 > 0) p.tokensOwed0 += uint128(owed0);
        if (owed1 > 0) p.tokensOwed1 += uint128(owed1);
    }

    function _updateTick(int24 tick, int128 liquidityDelta, int24 currentTick) internal {
        TickInfo storage t = ticks[tick];
        uint128 grossBefore = t.liquidityGross;
        uint128 grossAfter = _addDelta(grossBefore, liquidityDelta);
        t.liquidityGross = grossAfter;

        if (grossAfter == 0) {
            t.initialized = false;
        } else if (!t.initialized) {
            t.initialized = true;
            if (tick <= currentTick) {
                t.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                t.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }
        }

        if (liquidityDelta != 0) {
            if (tick <= currentTick) {
                liquidity = _addDelta(liquidity, liquidityDelta);
            }
            t.liquidityNet = _addDeltaInt(t.liquidityNet, liquidityDelta);
        }
    }

    function _crossTick(int24 tick, bool zeroForOne) internal {
        TickInfo storage t = ticks[tick];
        t.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - t.feeGrowthOutside0X128;
        t.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - t.feeGrowthOutside1X128;
        if (zeroForOne) {
            liquidity = _addDelta(liquidity, -t.liquidityNet);
        } else {
            liquidity = _addDelta(liquidity, t.liquidityNet);
        }
    }

    function _getFeeGrowthInside(int24 tickLower, int24 tickUpper, int24 currentTick)
        internal
        view
        returns (uint256 inside0, uint256 inside1)
    {
        TickInfo storage lower = ticks[tickLower];
        TickInfo storage upper = ticks[tickUpper];
        uint256 lowerOG0 = lower.feeGrowthOutside0X128;
        uint256 lowerOG1 = lower.feeGrowthOutside1X128;
        uint256 upperOG0 = upper.feeGrowthOutside0X128;
        uint256 upperOG1 = upper.feeGrowthOutside1X128;

        if (currentTick < tickLower) {
            inside0 = lowerOG0 - upperOG0;
            inside1 = lowerOG1 - upperOG1;
        } else if (currentTick >= tickUpper) {
            inside0 = upperOG0 - lowerOG0;
            inside1 = upperOG1 - lowerOG1;
        } else {
            inside0 = feeGrowthGlobal0X128 - lowerOG0 - upperOG0;
            inside1 = feeGrowthGlobal1X128 - lowerOG1 - upperOG1;
        }
    }

    function _nextInitializedTick(int24 tick, bool zeroForOne) internal view returns (int24 next) {
        if (zeroForOne) {
            next = tick - 1;
            while (next >= MIN_TICK) {
                if (ticks[next].initialized) return next;
                next -= 1;
            }
            return MIN_TICK;
        } else {
            next = tick + 1;
            while (next <= MAX_TICK) {
                if (ticks[next].initialized) return next;
                next += 1;
            }
            return MAX_TICK;
        }
    }

    function _getLiquidityForAmounts(uint160 sqrtCurrent, uint160 sqrtLower, uint160 sqrtUpper, uint256 amount0Desired, uint256 amount1Desired)
        internal
        pure
        returns (uint128 liquidityOut)
    {
        if (sqrtCurrent <= sqrtLower) {
            liquidityOut = _getLiquidityForAmount0(sqrtLower, sqrtUpper, amount0Desired);
        } else if (sqrtCurrent >= sqrtUpper) {
            liquidityOut = _getLiquidityForAmount1(sqrtLower, sqrtUpper, amount1Desired);
        } else {
            uint128 liq0 = _getLiquidityForAmount0(sqrtCurrent, sqrtUpper, amount0Desired);
            uint128 liq1 = _getLiquidityForAmount1(sqrtLower, sqrtCurrent, amount1Desired);
            liquidityOut = liq0 < liq1 ? liq0 : liq1;
        }
    }

    function _getAmountsForLiquidity(uint160 sqrtCurrent, uint160 sqrtLower, uint160 sqrtUpper, uint128 liquidityAmt)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        if (sqrtCurrent <= sqrtLower) {
            amount0 = _getAmount0Delta(sqrtUpper, sqrtLower, liquidityAmt);
        } else if (sqrtCurrent >= sqrtUpper) {
            amount1 = _getAmount1Delta(sqrtLower, sqrtUpper, liquidityAmt);
        } else {
            amount0 = _getAmount0Delta(sqrtUpper, sqrtCurrent, liquidityAmt);
            amount1 = _getAmount1Delta(sqrtLower, sqrtCurrent, liquidityAmt);
        }
    }

    function _getLiquidityForAmount0(uint160 sqrtA, uint160 sqrtB, uint256 amount0) internal pure returns (uint128) {
        if (sqrtA >= sqrtB) return 0;
        uint256 num = amount0 * sqrtA * sqrtB;
        uint256 den = Q96 * (uint256(sqrtB) - uint256(sqrtA));
        return uint128(num / den);
    }

    function _getLiquidityForAmount1(uint160 sqrtA, uint160 sqrtB, uint256 amount1) internal pure returns (uint128) {
        if (sqrtA >= sqrtB) return 0;
        return uint128((amount1 * Q96) / (uint256(sqrtB) - uint256(sqrtA)));
    }

    function _getAmount0Delta(uint160 sqrtA, uint160 sqrtB, uint128 L) internal pure returns (uint256) {
        if (sqrtA == sqrtB) return 0;
        if (sqrtA > sqrtB) (sqrtA, sqrtB) = (sqrtB, sqrtA);
        uint256 num = uint256(L) * Q96 * (uint256(sqrtB) - uint256(sqrtA));
        uint256 den = uint256(sqrtA) * uint256(sqrtB);
        return num / den;
    }

    function _getAmount1Delta(uint160 sqrtA, uint160 sqrtB, uint128 L) internal pure returns (uint256) {
        if (sqrtA == sqrtB) return 0;
        if (sqrtA > sqrtB) (sqrtA, sqrtB) = (sqrtB, sqrtA);
        return (uint256(L) * (uint256(sqrtB) - uint256(sqrtA))) / Q96;
    }

    function _addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            z = x - uint128(-int128(y));
            if (z > x) revert InsufficientLiquidity();
        } else {
            z = x + uint128(y);
            if (z < x) revert InsufficientLiquidity();
        }
    }

    function _addDeltaInt(int128 x, int128 y) internal pure returns (int128 z) {
        z = x + y;
        if (y > 0 && z < x) revert InsufficientLiquidity();
        if (y < 0 && z > x) revert InsufficientLiquidity();
    }

    function _pullToken(address token, address from, address to, uint256 amount) internal {
        if (amount == 0) return;
        uint256 balBefore = IERC20(token).balanceOf(to);
        if (!IERC20(token).transferFrom(from, to, amount)) revert TransferFailed();
        if (IERC20(token).balanceOf(to) - balBefore != amount) revert TransferFailed();
    }

    function _pushToken(address token, address from, address to, uint256 amount) internal {
        if (amount == 0) return;
        uint256 balBefore = IERC20(token).balanceOf(to);
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        if (IERC20(token).balanceOf(to) - balBefore != amount) revert TransferFailed();
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getTickInfo(int24 tick) external view returns (TickInfo memory) {
        return ticks[tick];
    }

    function getSqrtPriceAtTick(int24 tick) public pure returns (uint160) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(uint24(MAX_TICK)), "TICK");

        uint256 ratio = absTick & 0x1 != 0
            ? 0xfffcb933bd6fad37aa2d162d1a594001
            : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;
        return uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    function getTickAtSqrtPrice(uint160 sqrtPriceX96) public pure returns (int24 tick) {
        require(sqrtPriceX96 >= 4295128739, "R");
        uint256 ratio = uint256(sqrtPriceX96) << 32;

        uint256 r = ratio;
        uint256 msb = 0;
        assembly {
            let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(5, gt(r, 0xFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(4, gt(r, 0xFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(3, gt(r, 0xFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(2, gt(r, 0xF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(1, gt(r, 0x3))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := gt(r, 0x1)
            msb := or(msb, f)
        }

        if (msb >= 128) r = ratio >> (msb - 127);
        else r = ratio << (127 - msb);

        int256 log_2 = (int256(msb) - 128) << 64;
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(63, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(62, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(61, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(60, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(59, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(58, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(57, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(56, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(55, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(54, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(53, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(52, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(51, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(50, f))
        }

        int256 log_sqrt10001 = log_2 * 255738958999603826347141;
        int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
        int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

        return tickLow == tickHi ? tickLow : getSqrtPriceAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
    }
}
