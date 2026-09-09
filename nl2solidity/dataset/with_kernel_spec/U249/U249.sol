// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library FullMath {
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                require(denominator > 0);
                return prod0 / denominator;
            }

            require(denominator > prod1);

            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = (0 - denominator) & denominator;
            uint256 inv;
            assembly {
                let d := div(denominator, twos)
                inv := xor(mul(3, d), 2)
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))

                let p_lo := mul(prod0, inv)
                let mm := mulmod(prod0, inv, not(0))
                let p_hi := sub(sub(mm, p_lo), lt(mm, p_lo))
                let r_lo := mul(prod1, inv)
                let shifted := add(div(sub(0, twos), twos), 1)
                result := add(div(p_lo, twos), mul(add(p_hi, r_lo), shifted))
            }
        }
    }

    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            unchecked {
                require(result < type(uint256).max);
                result += 1;
            }
        }
    }
}

library TickMath {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = 887272;
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 14614467034852101032872730522012752661662336;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick = tick < 0 ? uint256(-int256(int24(tick))) : uint256(int256(int24(tick)));
            require(absTick <= uint256(int256(MAX_TICK)), "T");

            uint256 ratio = absTick & 0x1 != 0
                ? 0xfffcb933bd6fad37aa2d162d1f6e8bc0
                : 0x100000000000000000000000000000000;

            if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a4690551f48a40) >> 128;
            if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4214087d4cf2d1f78c9) >> 128;
            if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843f6077af3a9c1d0e6f5cf4b4c) >> 128;
            if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98d7515cd13f4d6e2d1f4d) >> 128;
            if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea164967c5da99f5d1a5f1c8b1d6d) >> 128;
            if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c305) >> 128;
            if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa38d) >> 128;
            if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e56) >> 128;
            if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f9) >> 128;
            if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792bc45ab) >> 128;
            if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea9261bedfe98) >> 128;
            if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) {
                assembly {
                    ratio := div(not(0), ratio)
                }
            }

            sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
            require(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO, "R");
        }
    }

    function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        unchecked {
            require(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO, "R");

            int24 lo = MIN_TICK;
            int24 hi = MAX_TICK;

            while (lo < hi) {
                int24 mid = int24((int256(lo) + int256(hi) + 1) >> 1);
                if (getSqrtRatioAtTick(mid) <= sqrtPriceX96) {
                    lo = mid;
                } else {
                    hi = mid - 1;
                }
            }

            tick = lo;
            require(tick >= MIN_TICK && tick < MAX_TICK, "T");
        }
    }
}

library LiquidityMath {
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        unchecked {
            if (y < 0) {
                z = x - uint128(-y);
            } else {
                z = x + uint128(y);
            }
        }
    }

    function addDelta(int128 x, int128 y) internal pure returns (int128 z) {
        unchecked {
            z = x + y;
        }
    }
}

library SqrtPriceMath {
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }

        uint256 diff = uint256(sqrtRatioBX96) - uint256(sqrtRatioAX96);

        if (roundUp) {
            amount0 = FullMath.mulDivRoundingUp(liquidity, diff, sqrtRatioBX96);
            amount0 = FullMath.mulDivRoundingUp(amount0, Q96, sqrtRatioAX96);
        } else {
            amount0 = FullMath.mulDiv(liquidity, diff, sqrtRatioBX96);
            amount0 = FullMath.mulDiv(amount0, Q96, sqrtRatioAX96);
        }
    }

    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }

        uint256 diff = uint256(sqrtRatioBX96) - uint256(sqrtRatioAX96);

        if (roundUp) {
            amount1 = FullMath.mulDivRoundingUp(liquidity, diff, Q96);
        } else {
            amount1 = FullMath.mulDiv(liquidity, diff, Q96);
        }
    }

    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amount,
        bool amountIn
    ) internal pure returns (uint160) {
        uint256 numerator = uint256(liquidity) << 96;
        if (amountIn) {
            uint256 denominator = numerator + amount * sqrtPriceX96;
            return uint160(FullMath.mulDiv(numerator, sqrtPriceX96, denominator));
        } else {
            uint256 product = amount * sqrtPriceX96;
            require(product <= numerator, "SqrtPriceMath: underflow");
            uint256 denominator = numerator - product;
            return uint160(FullMath.mulDiv(numerator, sqrtPriceX96, denominator));
        }
    }

    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amount,
        bool amountIn
    ) internal pure returns (uint160) {
        if (amountIn) {
            uint256 addend = FullMath.mulDiv(amount, Q96, liquidity);
            return uint160(uint256(sqrtPriceX96) + addend);
        } else {
            uint256 subtrahend = FullMath.mulDivRoundingUp(amount, Q96, liquidity);
            require(subtrahend <= sqrtPriceX96, "SqrtPriceMath: underflow");
            return uint160(uint256(sqrtPriceX96) - subtrahend);
        }
    }

    function getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        require(sqrtPriceX96 > 0, "SqrtPriceMath: sqrtPrice=0");
        require(liquidity > 0, "SqrtPriceMath: liquidity=0");
        if (zeroForOne) {
            return getNextSqrtPriceFromAmount0RoundingUp(sqrtPriceX96, liquidity, amountIn, true);
        } else {
            return getNextSqrtPriceFromAmount1RoundingDown(sqrtPriceX96, liquidity, amountIn, true);
        }
    }
}

library SwapMath {
    function computeSwapStep(
        uint160 sqrtPriceCurrentX96,
        uint160 sqrtPriceTargetX96,
        uint128 liquidity,
        uint256 amountSpecifiedRemaining,
        uint24 feePips
    )
        internal
        pure
        returns (uint160 sqrtPriceNextX96, uint256 amountIn, uint256 amountOut, uint256 feeAmount)
    {
        bool zeroForOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;

        uint256 amountRemainingLessFee = FullMath.mulDiv(
            amountSpecifiedRemaining,
            1_000_000 - feePips,
            1_000_000
        );

        if (zeroForOne) {
            uint256 amountInMax = SqrtPriceMath.getAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity,
                true
            );
            if (amountRemainingLessFee >= amountInMax) {
                amountIn = amountInMax;
                sqrtPriceNextX96 = sqrtPriceTargetX96;
            } else {
                sqrtPriceNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtPriceCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    true
                );
                amountIn = SqrtPriceMath.getAmount0Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity,
                    true
                );
            }
        } else {
            uint256 amountInMax = SqrtPriceMath.getAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity,
                true
            );
            if (amountRemainingLessFee >= amountInMax) {
                amountIn = amountInMax;
                sqrtPriceNextX96 = sqrtPriceTargetX96;
            } else {
                sqrtPriceNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtPriceCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    false
                );
                amountIn = SqrtPriceMath.getAmount1Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity,
                    true
                );
            }
        }

        feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1_000_000 - feePips);

        if (zeroForOne) {
            amountOut = SqrtPriceMath.getAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96 == 0 ? sqrtPriceTargetX96 : sqrtPriceNextX96,
                liquidity,
                false
            );
        } else {
            amountOut = SqrtPriceMath.getAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96 == 0 ? sqrtPriceTargetX96 : sqrtPriceNextX96,
                liquidity,
                false
            );
        }
    }
}

contract ConcentratedLiquidityManager {
    event PoolCreated(
        uint256 indexed poolId,
        address indexed token0,
        address indexed token1,
        uint24 fee,
        int24 tickSpacing,
        uint160 sqrtPriceX96,
        int24 tick
    );
    event AddLiquidity(
        uint256 indexed poolId,
        uint256 indexed positionId,
        address indexed owner,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event RemoveLiquidity(
        uint256 indexed poolId,
        uint256 indexed positionId,
        address indexed owner,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        uint256 indexed poolId,
        address indexed sender,
        address indexed recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOut,
        uint160 sqrtPriceX96,
        int24 tick,
        uint128 liquidity
    );
    event Collect(
        uint256 indexed poolId,
        uint256 indexed positionId,
        address indexed owner,
        address recipient,
        uint256 amount0,
        uint256 amount1
    );
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event BaseSwapFeeUpdated(uint24 oldFee, uint24 newFee);
    event OperatorTransferred(address indexed oldOperator, address indexed newOperator);

    error ZeroAddress();
    error IdenticalTokens();
    error InvalidFee();
    error InvalidTickSpacing();
    error PoolNotInitialized();
    error TicksMisordered();
    error TickOutOfRange();
    error InsufficientLiquidity();
    error PositionNotFound();
    error InvalidPriceLimit();
    error AmountZero();
    error SwapNotProgressed();
    error Unauthorized();
    error TransferFailed();

    uint24 public constant MAX_FEE = 10_000;
    int24 public constant MIN_TICK_SPACING = 1;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    address public operator;
    address public treasury;
    uint24 public baseSwapFee;

    uint256 public poolCount;

    struct Pool {
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        bool initialized;
    }

    struct TickInfo {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        bool initialized;
    }

    struct Position {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        address owner;
        bool active;
    }

    struct PoolInfo {
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        bool initialized;
    }

    struct PositionInfo {
        uint128 liquidity;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        bool active;
    }

    mapping(uint256 => Pool) internal pools;
    mapping(uint256 => mapping(int24 => TickInfo)) public ticks;
    mapping(uint256 => mapping(bytes32 => Position)) internal positions;
    mapping(uint256 => uint256) public positionCounters;

    uint256 private _locked;

    modifier nonReentrant() {
        require(_locked == 0, "REENTRANT");
        _locked = 1;
        _;
        _locked = 0;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address treasury_, uint24 baseSwapFee_) {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (baseSwapFee_ > MAX_FEE) revert InvalidFee();
        treasury = treasury_;
        baseSwapFee = baseSwapFee_;
        operator = msg.sender;
        emit TreasuryUpdated(address(0), treasury_);
        emit BaseSwapFeeUpdated(0, baseSwapFee_);
        emit OperatorTransferred(address(0), msg.sender);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function setBaseSwapFee(uint24 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint24 old = baseSwapFee;
        baseSwapFee = newFee;
        emit BaseSwapFeeUpdated(old, newFee);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorTransferred(old, newOperator);
    }

    function createPool(
        address tokenA,
        address tokenB,
        int24 tickSpacing,
        uint160 sqrtPriceX96,
        uint24 feeOverride
    ) external nonReentrant returns (uint256 poolId) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tickSpacing < MIN_TICK_SPACING) revert InvalidTickSpacing();

        uint24 fee = feeOverride == 0 ? baseSwapFee : feeOverride;
        if (fee > MAX_FEE) revert InvalidFee();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        poolId = poolCount++;
        Pool storage p = pools[poolId];
        p.token0 = token0;
        p.token1 = token1;
        p.fee = fee;
        p.tickSpacing = tickSpacing;
        p.sqrtPriceX96 = sqrtPriceX96;
        p.tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        p.initialized = true;

        emit PoolCreated(poolId, token0, token1, fee, tickSpacing, sqrtPriceX96, p.tick);
    }

    function addLiquidity(
        uint256 poolId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        Pool storage p = pools[poolId];
        if (!p.initialized) revert PoolNotInitialized();
        if (tickLower >= tickUpper) revert TicksMisordered();
        if (tickLower < TickMath.MIN_TICK || tickUpper > TickMath.MAX_TICK) revert TickOutOfRange();
        if (liquidity == 0) revert AmountZero();

        uint256 positionId = positionCounters[poolId]++;
        bytes32 posKey = keccak256(abi.encodePacked(msg.sender, tickLower, tickUpper, positionId));
        Position storage pos = positions[poolId][posKey];

        (amount0, amount1) = _calcAmountsForLiquidity(
            p.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity,
            true
        );

        int128 liquidityDelta = int128(int256(uint256(liquidity)));
        _updateTick(p, ticks[poolId], tickLower, liquidityDelta, true);
        _updateTick(p, ticks[poolId], tickUpper, -liquidityDelta, false);
        p.liquidity = LiquidityMath.addDelta(p.liquidity, liquidityDelta);

        pos.liquidity = liquidity;
        pos.owner = msg.sender;
        pos.active = true;
        pos.feeGrowthInside0LastX128 = _feeGrowthInside0(p, ticks[poolId], tickLower, tickUpper);
        pos.feeGrowthInside1LastX128 = _feeGrowthInside1(p, ticks[poolId], tickLower, tickUpper);

        if (amount0 > 0) {
            if (!IERC20(p.token0).transferFrom(msg.sender, address(this), amount0)) revert TransferFailed();
        }
        if (amount1 > 0) {
            if (!IERC20(p.token1).transferFrom(msg.sender, address(this), amount1)) revert TransferFailed();
        }

        emit AddLiquidity(poolId, positionId, msg.sender, tickLower, tickUpper, liquidity, amount0, amount1);
    }

    function removeLiquidity(
        uint256 poolId,
        uint256 positionId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        Pool storage p = pools[poolId];
        if (!p.initialized) revert PoolNotInitialized();

        bytes32 posKey = keccak256(abi.encodePacked(msg.sender, tickLower, tickUpper, positionId));
        Position storage pos = positions[poolId][posKey];
        if (!pos.active) revert PositionNotFound();
        if (pos.liquidity < liquidity) revert InsufficientLiquidity();

        _updatePositionFees(p, ticks[poolId], pos, tickLower, tickUpper);

        (amount0, amount1) = _calcAmountsForLiquidity(
            p.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity,
            false
        );

        int128 liquidityDelta = int128(int256(uint256(liquidity)));
        _updateTick(p, ticks[poolId], tickLower, -liquidityDelta, true);
        _updateTick(p, ticks[poolId], tickUpper, liquidityDelta, false);
        p.liquidity = LiquidityMath.addDelta(p.liquidity, -liquidityDelta);

        pos.liquidity -= liquidity;

        if (amount0 > 0) {
            if (!IERC20(p.token0).transfer(msg.sender, amount0)) revert TransferFailed();
        }
        if (amount1 > 0) {
            if (!IERC20(p.token1).transfer(msg.sender, amount1)) revert TransferFailed();
        }

        emit RemoveLiquidity(poolId, positionId, msg.sender, tickLower, tickUpper, liquidity, amount0, amount1);
    }

    function collect(
        uint256 poolId,
        uint256 positionId,
        int24 tickLower,
        int24 tickUpper,
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external nonReentrant returns (uint128 amount0, uint128 amount1) {
        Pool storage p = pools[poolId];
        if (!p.initialized) revert PoolNotInitialized();
        if (recipient == address(0)) revert ZeroAddress();

        bytes32 posKey = keccak256(abi.encodePacked(msg.sender, tickLower, tickUpper, positionId));
        Position storage pos = positions[poolId][posKey];
        if (!pos.active) revert PositionNotFound();

        _updatePositionFees(p, ticks[poolId], pos, tickLower, tickUpper);

        amount0 = amount0Requested > pos.tokensOwed0 ? pos.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > pos.tokensOwed1 ? pos.tokensOwed1 : amount1Requested;

        pos.tokensOwed0 -= amount0;
        pos.tokensOwed1 -= amount1;

        if (amount0 > 0) {
            if (!IERC20(p.token0).transfer(recipient, amount0)) revert TransferFailed();
        }
        if (amount1 > 0) {
            if (!IERC20(p.token1).transfer(recipient, amount1)) revert TransferFailed();
        }

        emit Collect(poolId, positionId, msg.sender, recipient, amount0, amount1);
    }

    function swap(
        uint256 poolId,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        address recipient
    ) external nonReentrant returns (uint256 amountIn, uint256 amountOut) {
        Pool storage p = pools[poolId];
        if (!p.initialized) revert PoolNotInitialized();
        if (amountSpecified == 0) revert AmountZero();

        if (zeroForOne) {
            if (sqrtPriceLimitX96 == 0) sqrtPriceLimitX96 = TickMath.MIN_SQRT_RATIO + 1;
            if (sqrtPriceLimitX96 >= p.sqrtPriceX96 || sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO)
                revert InvalidPriceLimit();
        } else {
            if (sqrtPriceLimitX96 == 0) sqrtPriceLimitX96 = TickMath.MAX_SQRT_RATIO - 1;
            if (sqrtPriceLimitX96 <= p.sqrtPriceX96 || sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO)
                revert InvalidPriceLimit();
        }

        if (p.liquidity == 0) revert InsufficientLiquidity();

        (amountIn, amountOut) = _executeSwap(p, zeroForOne, amountSpecified, sqrtPriceLimitX96);

        address tokenIn = zeroForOne ? p.token0 : p.token1;
        if (!IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn)) revert TransferFailed();

        if (amountOut > 0) {
            address tokenOut = zeroForOne ? p.token1 : p.token0;
            if (!IERC20(tokenOut).transfer(recipient, amountOut)) revert TransferFailed();
        }

        emit Swap(poolId, msg.sender, recipient, zeroForOne, amountIn, amountOut, p.sqrtPriceX96, p.tick, p.liquidity);
    }

    function _executeSwap(
        Pool storage p,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96
    ) internal returns (uint256 amountIn, uint256 amountOut) {
        (uint160 sqrtPriceNextX96, uint256 stepAmountIn, uint256 stepAmountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(p.sqrtPriceX96, sqrtPriceLimitX96, p.liquidity, amountSpecified, p.fee);

        if (sqrtPriceNextX96 == p.sqrtPriceX96 && stepAmountIn == 0) revert SwapNotProgressed();

        p.sqrtPriceX96 = sqrtPriceNextX96;
        p.tick = TickMath.getTickAtSqrtRatio(sqrtPriceNextX96);

        if (p.liquidity > 0) {
            if (zeroForOne) {
                p.feeGrowthGlobal0X128 += FullMath.mulDiv(feeAmount, Q128, p.liquidity);
            } else {
                p.feeGrowthGlobal1X128 += FullMath.mulDiv(feeAmount, Q128, p.liquidity);
            }
        }

        amountIn = stepAmountIn + feeAmount;
        amountOut = stepAmountOut;
    }

    function getPool(uint256 poolId) external view returns (PoolInfo memory info) {
        Pool storage p = pools[poolId];
        info.token0 = p.token0;
        info.token1 = p.token1;
        info.fee = p.fee;
        info.tickSpacing = p.tickSpacing;
        info.sqrtPriceX96 = p.sqrtPriceX96;
        info.tick = p.tick;
        info.liquidity = p.liquidity;
        info.feeGrowthGlobal0X128 = p.feeGrowthGlobal0X128;
        info.feeGrowthGlobal1X128 = p.feeGrowthGlobal1X128;
        info.initialized = p.initialized;
    }

    function getPosition(
        uint256 poolId,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        uint256 positionId
    ) external view returns (PositionInfo memory info) {
        bytes32 posKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper, positionId));
        Position storage pos = positions[poolId][posKey];
        info.liquidity = pos.liquidity;
        info.tokensOwed0 = pos.tokensOwed0;
        info.tokensOwed1 = pos.tokensOwed1;
        info.active = pos.active;
    }

    function _calcAmountsForLiquidity(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            amount0 = SqrtPriceMath.getAmount0Delta(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity, roundUp);
            amount1 = 0;
        } else if (sqrtPriceX96 < sqrtPriceUpperX96) {
            amount0 = SqrtPriceMath.getAmount0Delta(sqrtPriceX96, sqrtPriceUpperX96, liquidity, roundUp);
            amount1 = SqrtPriceMath.getAmount1Delta(sqrtPriceLowerX96, sqrtPriceX96, liquidity, roundUp);
        } else {
            amount0 = 0;
            amount1 = SqrtPriceMath.getAmount1Delta(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity, roundUp);
        }
    }

    function _updateTick(
        Pool storage p,
        mapping(int24 => TickInfo) storage _ticks,
        int24 tick,
        int128 liquidityDelta,
        bool isLower
    ) internal {
        if (liquidityDelta == 0) return;
        TickInfo storage info = _ticks[tick];
        if (!info.initialized) {
            info.initialized = true;
            if (tick <= p.tick) {
                info.feeGrowthOutside0X128 = p.feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = p.feeGrowthGlobal1X128;
            }
        }
        info.liquidityGross = LiquidityMath.addDelta(info.liquidityGross, liquidityDelta);
        if (isLower) {
            info.liquidityNet = LiquidityMath.addDelta(info.liquidityNet, liquidityDelta);
        } else {
            info.liquidityNet = LiquidityMath.addDelta(info.liquidityNet, -liquidityDelta);
        }
    }

    function _feeGrowthInside0(
        Pool storage p,
        mapping(int24 => TickInfo) storage _ticks,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256) {
        TickInfo storage lower = _ticks[tickLower];
        TickInfo storage upper = _ticks[tickUpper];
        uint256 fgBelow = p.tick >= tickLower
            ? lower.feeGrowthOutside0X128
            : p.feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
        uint256 fgAbove = p.tick < tickUpper
            ? upper.feeGrowthOutside0X128
            : p.feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
        return p.feeGrowthGlobal0X128 - fgBelow - fgAbove;
    }

    function _feeGrowthInside1(
        Pool storage p,
        mapping(int24 => TickInfo) storage _ticks,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256) {
        TickInfo storage lower = _ticks[tickLower];
        TickInfo storage upper = _ticks[tickUpper];
        uint256 fgBelow = p.tick >= tickLower
            ? lower.feeGrowthOutside1X128
            : p.feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        uint256 fgAbove = p.tick < tickUpper
            ? upper.feeGrowthOutside1X128
            : p.feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        return p.feeGrowthGlobal1X128 - fgBelow - fgAbove;
    }

    function _updatePositionFees(
        Pool storage p,
        mapping(int24 => TickInfo) storage _ticks,
        Position storage pos,
        int24 tickLower,
        int24 tickUpper
    ) internal {
        uint256 fg0 = _feeGrowthInside0(p, _ticks, tickLower, tickUpper);
        uint256 fg1 = _feeGrowthInside1(p, _ticks, tickLower, tickUpper);
        uint256 delta0 = fg0 - pos.feeGrowthInside0LastX128;
        uint256 delta1 = fg1 - pos.feeGrowthInside1LastX128;
        pos.feeGrowthInside0LastX128 = fg0;
        pos.feeGrowthInside1LastX128 = fg1;
        if (pos.liquidity > 0) {
            pos.tokensOwed0 += uint128(FullMath.mulDiv(delta0, pos.liquidity, Q128));
            pos.tokensOwed1 += uint128(FullMath.mulDiv(delta1, pos.liquidity, Q128));
        }
    }
}
