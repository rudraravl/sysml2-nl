// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
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
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
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
            uint256 twos = (uint256(0) - denominator) & denominator;
            assembly {
                denominator := div(denominator, twos)
            }
            assembly {
                prod0 := div(prod0, twos)
            }
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            assembly {
                prod0 := or(prod0, mul(prod1, twos))
            }
            uint256 inv = (3 * denominator) ^ 2;
            inv = inv * (2 - denominator * inv);
            inv = inv * (2 - denominator * inv);
            inv = inv * (2 - denominator * inv);
            inv = inv * (2 - denominator * inv);
            inv = inv * (2 - denominator * inv);
            inv = inv * (2 - denominator * inv);
            assembly {
                result := mul(prod0, inv)
            }
            return result;
        }
    }
}

contract ConcentratedLiquidityManager {
    uint256 private constant Q96 = 2 ** 96;
    uint256 private constant Q128 = 2 ** 128;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant PROTOCOL_FEE_SHARE_BPS = 1_000;
    uint256 public constant MAX_POSITIONS_PER_PAIR = 10_000;
    uint24 public constant MIN_FEE_RATE = 1;
    uint24 public constant MAX_FEE_RATE = 5_000;
    int24 public constant MIN_TICK = -887_272;
    int24 public constant MAX_TICK = 887_272;
    uint160 public constant MIN_SQRT_RATIO = 4_295_128_739;
    uint160 public constant MAX_SQRT_RATIO =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;

    struct Position {
        address owner;
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint160 sqrtRatioLowerX96;
        uint160 sqrtRatioUpperX96;
        uint128 liquidity;
        uint256 amount0Deposited;
        uint256 amount1Deposited;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        bool active;
    }

    struct PairState {
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint256 positionCount;
        bool initialized;
    }

    struct SwapResult {
        uint256 amountOut;
        uint256 amountInConsumed;
        uint160 sqrtPriceNext;
    }

    address public operator;
    uint24 public baseFeeRate;
    bool public paused;
    uint256 public nextPositionId;
    bool private locked;

    mapping(uint256 => Position) public positions;
    mapping(address => mapping(address => PairState)) public pairs;
    mapping(address => uint256) public protocolFees;

    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        address token0,
        address token1,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event LiquidityAdded(
        uint256 indexed positionId,
        address indexed owner,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event LiquidityRemoved(
        uint256 indexed positionId,
        address indexed owner,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event FeesCollected(
        uint256 indexed positionId,
        address indexed owner,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountInConsumed,
        uint256 amountOut,
        uint160 sqrtPriceX96,
        int24 tick,
        uint128 liquidity
    );
    event PairInitialized(address indexed token0, address indexed token1, uint160 sqrtPriceX96, int24 tick);
    event BaseFeeRateUpdated(uint24 oldRate, uint24 newRate);
    event PausedStateChanged(bool paused);
    event ProtocolFeesWithdrawn(address indexed token, address indexed to, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error Unauthorized();
    error ReentrantCall();
    error Paused();
    error PairNotInitialized();
    error AlreadyInitialized();
    error InvalidTickRange();
    error InvalidPriceRange();
    error InvalidPrice();
    error InsufficientLiquidity();
    error PositionNotActive();
    error NotPositionOwner();
    error MaxPositionsReached();
    error SlippageExceeded();
    error ZeroAmount();
    error InvalidTokens();
    error TransferFailed();
    error FeeRateOutOfRange();

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert InvalidTokens();
        operator = _operator;
        baseFeeRate = 30;
        nextPositionId = 1;
        emit OperatorUpdated(address(0), _operator);
        emit BaseFeeRateUpdated(0, 30);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidTokens();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setBaseFeeRate(uint24 newRate) external onlyOperator {
        if (newRate < MIN_FEE_RATE || newRate > MAX_FEE_RATE) revert FeeRateOutOfRange();
        emit BaseFeeRateUpdated(baseFeeRate, newRate);
        baseFeeRate = newRate;
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function withdrawProtocolFees(address token, address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert InvalidTokens();
        uint256 available = protocolFees[token];
        if (amount > available) revert InsufficientLiquidity();
        protocolFees[token] = available - amount;
        _safeTransfer(token, to, amount);
        emit ProtocolFeesWithdrawn(token, to, amount);
    }

    function initializePair(address tokenA, address tokenB, uint160 sqrtPriceX96) external onlyOperator {
        if (tokenA == address(0) || tokenB == address(0) || tokenA == tokenB) revert InvalidTokens();
        if (sqrtPriceX96 < MIN_SQRT_RATIO || sqrtPriceX96 > MAX_SQRT_RATIO) revert InvalidPrice();
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        PairState storage pair = pairs[t0][t1];
        if (pair.initialized) revert AlreadyInitialized();
        pair.sqrtPriceX96 = sqrtPriceX96;
        pair.tick = _tickFromSqrtPrice(sqrtPriceX96);
        pair.initialized = true;
        emit PairInitialized(t0, t1, sqrtPriceX96, pair.tick);
    }

    function createPosition(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint160 sqrtRatioLowerX96,
        uint160 sqrtRatioUpperX96,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external nonReentrant returns (uint256 positionId) {
        if (tokenA == address(0) || tokenB == address(0) || tokenA == tokenB) revert InvalidTokens();
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroAmount();
        if (tickLower >= tickUpper || tickLower < MIN_TICK || tickUpper > MAX_TICK) revert InvalidTickRange();
        if (sqrtRatioLowerX96 >= sqrtRatioUpperX96) revert InvalidPriceRange();
        if (sqrtRatioLowerX96 < MIN_SQRT_RATIO || sqrtRatioUpperX96 > MAX_SQRT_RATIO) revert InvalidPrice();

        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        PairState storage pair = pairs[t0][t1];
        if (!pair.initialized) revert PairNotInitialized();
        if (pair.positionCount >= MAX_POSITIONS_PER_PAIR) revert MaxPositionsReached();

        uint256 liquidity = _getLiquidityForAmounts(
            pair.sqrtPriceX96,
            sqrtRatioLowerX96,
            sqrtRatioUpperX96,
            amount0Desired,
            amount1Desired
        );
        if (liquidity == 0) revert ZeroAmount();
        if (liquidity > type(uint128).max) revert InsufficientLiquidity();

        (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity(
            pair.sqrtPriceX96,
            sqrtRatioLowerX96,
            sqrtRatioUpperX96,
            uint128(liquidity)
        );

        if (amount0 > 0) _transferFrom(t0, msg.sender, address(this), amount0);
        if (amount1 > 0) _transferFrom(t1, msg.sender, address(this), amount1);

        positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            token0: t0,
            token1: t1,
            tickLower: tickLower,
            tickUpper: tickUpper,
            sqrtRatioLowerX96: sqrtRatioLowerX96,
            sqrtRatioUpperX96: sqrtRatioUpperX96,
            liquidity: uint128(liquidity),
            amount0Deposited: amount0,
            amount1Deposited: amount1,
            feeGrowthInside0LastX128: pair.feeGrowthGlobal0X128,
            feeGrowthInside1LastX128: pair.feeGrowthGlobal1X128,
            tokensOwed0: 0,
            tokensOwed1: 0,
            active: true
        });

        pair.liquidity += uint128(liquidity);
        pair.positionCount += 1;

        emit PositionCreated(positionId, msg.sender, t0, t1, tickLower, tickUpper, uint128(liquidity), amount0, amount1);
    }

    function addLiquidity(
        uint256 positionId,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external nonReentrant returns (uint128 liquidityAdded, uint256 amount0, uint256 amount1) {
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroAmount();
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotActive();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        PairState storage pair = pairs[pos.token0][pos.token1];

        _updatePositionFees(positionId);

        uint256 liq = _getLiquidityForAmounts(
            pair.sqrtPriceX96,
            pos.sqrtRatioLowerX96,
            pos.sqrtRatioUpperX96,
            amount0Desired,
            amount1Desired
        );
        if (liq == 0) revert ZeroAmount();
        if (uint256(pos.liquidity) + liq > type(uint128).max) revert InsufficientLiquidity();
        liquidityAdded = uint128(liq);

        (amount0, amount1) = _getAmountsForLiquidity(
            pair.sqrtPriceX96,
            pos.sqrtRatioLowerX96,
            pos.sqrtRatioUpperX96,
            liquidityAdded
        );

        if (amount0 > 0) _transferFrom(pos.token0, msg.sender, address(this), amount0);
        if (amount1 > 0) _transferFrom(pos.token1, msg.sender, address(this), amount1);

        pos.liquidity += liquidityAdded;
        pos.amount0Deposited += amount0;
        pos.amount1Deposited += amount1;
        pair.liquidity += liquidityAdded;

        emit LiquidityAdded(positionId, msg.sender, liquidityAdded, amount0, amount1);
    }

    function removeLiquidity(uint256 positionId, uint128 liquidityToRemove)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidityToRemove == 0) revert ZeroAmount();
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotActive();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (liquidityToRemove > pos.liquidity) revert InsufficientLiquidity();
        PairState storage pair = pairs[pos.token0][pos.token1];

        _updatePositionFees(positionId);

        (amount0, amount1) = _getAmountsForLiquidity(
            pair.sqrtPriceX96,
            pos.sqrtRatioLowerX96,
            pos.sqrtRatioUpperX96,
            liquidityToRemove
        );

        pos.liquidity -= liquidityToRemove;
        pair.liquidity -= liquidityToRemove;

        if (pos.liquidity == 0) {
            pos.active = false;
            if (pair.positionCount > 0) {
                pair.positionCount -= 1;
            }
        }

        if (amount0 > 0) {
            if (IERC20(pos.token0).balanceOf(address(this)) < amount0) revert InsufficientLiquidity();
            _safeTransfer(pos.token0, msg.sender, amount0);
        }
        if (amount1 > 0) {
            if (IERC20(pos.token1).balanceOf(address(this)) < amount1) revert InsufficientLiquidity();
            _safeTransfer(pos.token1, msg.sender, amount1);
        }

        emit LiquidityRemoved(positionId, msg.sender, liquidityToRemove, amount0, amount1);
    }

    function collectFees(uint256 positionId)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage pos = positions[positionId];
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (!pos.active && pos.tokensOwed0 == 0 && pos.tokensOwed1 == 0) revert PositionNotActive();

        _updatePositionFees(positionId);

        amount0 = pos.tokensOwed0;
        amount1 = pos.tokensOwed1;
        pos.tokensOwed0 = 0;
        pos.tokensOwed1 = 0;

        if (amount0 > 0) {
            if (IERC20(pos.token0).balanceOf(address(this)) < amount0) revert InsufficientLiquidity();
            _safeTransfer(pos.token0, msg.sender, amount0);
        }
        if (amount1 > 0) {
            if (IERC20(pos.token1).balanceOf(address(this)) < amount1) revert InsufficientLiquidity();
            _safeTransfer(pos.token1, msg.sender, amount1);
        }

        emit FeesCollected(positionId, msg.sender, amount0, amount1);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96,
        uint256 minAmountOut,
        address recipient
    ) external nonReentrant whenNotPaused returns (uint256 amountOut, uint256 amountInConsumed) {
        if (tokenIn == address(0) || tokenOut == address(0) || tokenIn == tokenOut) revert InvalidTokens();
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert InvalidTokens();

        (address t0, ) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        PairState storage pair = pairs[t0][tokenIn < tokenOut ? tokenOut : tokenIn];
        if (!pair.initialized) revert PairNotInitialized();
        if (pair.liquidity == 0) revert InsufficientLiquidity();

        bool zeroForOne = tokenIn == t0;
        uint160 sqrtPriceCurrent = pair.sqrtPriceX96;

        if (zeroForOne) {
            if (sqrtPriceLimitX96 >= sqrtPriceCurrent || sqrtPriceLimitX96 < MIN_SQRT_RATIO) revert InvalidPrice();
        } else {
            if (sqrtPriceLimitX96 <= sqrtPriceCurrent || sqrtPriceLimitX96 > MAX_SQRT_RATIO) revert InvalidPrice();
        }

        _transferFrom(tokenIn, msg.sender, address(this), amountIn);

        SwapResult memory res = _computeSwap(
            zeroForOne,
            sqrtPriceCurrent,
            sqrtPriceLimitX96,
            pair.liquidity,
            amountIn,
            baseFeeRate
        );

        amountOut = res.amountOut;
        amountInConsumed = res.amountInConsumed;

        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (IERC20(tokenOut).balanceOf(address(this)) < amountOut) revert InsufficientLiquidity();

        uint256 fee = (amountInConsumed * uint256(baseFeeRate)) / BASIS_POINTS;
        uint256 protocolFee = (fee * PROTOCOL_FEE_SHARE_BPS) / BASIS_POINTS;
        uint256 lpFee = fee - protocolFee;

        pair.sqrtPriceX96 = res.sqrtPriceNext;
        pair.tick = _tickFromSqrtPrice(res.sqrtPriceNext);

        uint128 L = pair.liquidity;
        if (L > 0) {
            if (zeroForOne) {
                pair.feeGrowthGlobal0X128 += FullMath.mulDiv(lpFee, Q128, uint256(L));
            } else {
                pair.feeGrowthGlobal1X128 += FullMath.mulDiv(lpFee, Q128, uint256(L));
            }
        }
        protocolFees[tokenIn] += protocolFee;

        uint256 leftover = amountIn - amountInConsumed;
        if (leftover > 0) _safeTransfer(tokenIn, msg.sender, leftover);
        if (amountOut > 0) _safeTransfer(tokenOut, recipient, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountInConsumed, amountOut, pair.sqrtPriceX96, pair.tick, pair.liquidity);
    }

    function _computeSwap(
        bool zeroForOne,
        uint160 sqrtPriceCurrent,
        uint160 sqrtPriceLimitX96,
        uint128 L,
        uint256 amountIn,
        uint24 feeRate
    ) internal pure returns (SwapResult memory res) {
        uint256 feeIfFull = (amountIn * uint256(feeRate)) / BASIS_POINTS;
        uint256 amountInNetFull = amountIn - feeIfFull;
        uint256 L256 = uint256(L);

        if (zeroForOne) {
            uint256 reserve0 = FullMath.mulDiv(L256, Q96, uint256(sqrtPriceCurrent));
            uint256 reserve0Target = FullMath.mulDiv(L256, Q96, uint256(sqrtPriceLimitX96));
            uint256 maxInNet = reserve0Target - reserve0;

            if (amountInNetFull <= maxInNet) {
                res.amountInNet = amountInNetFull;
                res.amountInConsumed = amountIn;
                res.sqrtPriceNext = uint160(FullMath.mulDiv(L256, Q96, reserve0 + amountInNetFull));
            } else {
                res.amountInNet = maxInNet;
                res.amountInConsumed = (maxInNet * BASIS_POINTS) / (BASIS_POINTS - uint256(feeRate));
                res.sqrtPriceNext = sqrtPriceLimitX96;
            }
            res.amountOut = FullMath.mulDiv(L256, uint256(sqrtPriceCurrent) - uint256(res.sqrtPriceNext), Q96);
        } else {
            uint256 reserve1 = FullMath.mulDiv(L256, uint256(sqrtPriceCurrent), Q96);
            uint256 reserve1Target = FullMath.mulDiv(L256, uint256(sqrtPriceLimitX96), Q96);
            uint256 maxInNet = reserve1Target - reserve1;

            if (amountInNetFull <= maxInNet) {
                res.amountInNet = amountInNetFull;
                res.amountInConsumed = amountIn;
                res.sqrtPriceNext = uint160(uint256(sqrtPriceCurrent) + FullMath.mulDiv(amountInNetFull, Q96, L256));
            } else {
                res.amountInNet = maxInNet;
                res.amountInConsumed = (maxInNet * BASIS_POINTS) / (BASIS_POINTS - uint256(feeRate));
                res.sqrtPriceNext = sqrtPriceLimitX96;
            }
            uint256 reserve0Old = FullMath.mulDiv(L256, Q96, uint256(sqrtPriceCurrent));
            uint256 reserve0New = FullMath.mulDiv(L256, Q96, uint256(res.sqrtPriceNext));
            res.amountOut = reserve0Old - reserve0New;
        }
    }

    function getPair(address tokenA, address tokenB) external view returns (PairState memory) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return pairs[t0][t1];
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getAmountsForLiquidity(
        address tokenA,
        address tokenB,
        uint160 sqrtRatioLowerX96,
        uint160 sqrtRatioUpperX96,
        uint128 liquidity
    ) external view returns (uint256 amount0, uint256 amount1) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        PairState storage pair = pairs[t0][t1];
        return _getAmountsForLiquidity(pair.sqrtPriceX96, sqrtRatioLowerX96, sqrtRatioUpperX96, liquidity);
    }

    function getLiquidityForAmounts(
        address tokenA,
        address tokenB,
        uint160 sqrtRatioLowerX96,
        uint160 sqrtRatioUpperX96,
        uint256 amount0,
        uint256 amount1
    ) external view returns (uint256 liquidity) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        PairState storage pair = pairs[t0][t1];
        return _getLiquidityForAmounts(pair.sqrtPriceX96, sqrtRatioLowerX96, sqrtRatioUpperX96, amount0, amount1);
    }

    function pairPositionCount(address tokenA, address tokenB) external view returns (uint256) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return pairs[t0][t1].positionCount;
    }

    function _updatePositionFees(uint256 positionId) internal {
        Position storage pos = positions[positionId];
        PairState storage pair = pairs[pos.token0][pos.token1];
        if (pos.liquidity > 0) {
            uint256 owed0 = FullMath.mulDiv(
                pair.feeGrowthGlobal0X128 - pos.feeGrowthInside0LastX128,
                pos.liquidity,
                Q128
            );
            uint256 owed1 = FullMath.mulDiv(
                pair.feeGrowthGlobal1X128 - pos.feeGrowthInside1LastX128,
                pos.liquidity,
                Q128
            );
            pos.tokensOwed0 += owed0;
            pos.tokensOwed1 += owed1;
        }
        pos.feeGrowthInside0LastX128 = pair.feeGrowthGlobal0X128;
        pos.feeGrowthInside1LastX128 = pair.feeGrowthGlobal1X128;
    }

    function _getLiquidityForAmount0(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint256 amount0)
        internal
        pure
        returns (uint256)
    {
        return FullMath.mulDiv(
            FullMath.mulDiv(uint256(sqrtRatioAX96), uint256(sqrtRatioBX96), Q96),
            amount0,
            uint256(sqrtRatioBX96 - sqrtRatioAX96)
        );
    }

    function _getLiquidityForAmount1(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint256 amount1)
        internal
        pure
        returns (uint256)
    {
        return FullMath.mulDiv(amount1, Q96, uint256(sqrtRatioBX96 - sqrtRatioAX96));
    }

    function _getLiquidityForAmounts(
        uint160 sqrtPriceX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint256 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }
        if (sqrtPriceX96 <= sqrtRatioAX96) {
            liquidity = _getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
        } else if (sqrtPriceX96 < sqrtRatioBX96) {
            uint256 l0 = _getLiquidityForAmount0(sqrtPriceX96, sqrtRatioBX96, amount0);
            uint256 l1 = _getLiquidityForAmount1(sqrtRatioAX96, sqrtPriceX96, amount1);
            liquidity = l0 < l1 ? l0 : l1;
        } else {
            liquidity = _getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
        }
    }

    function _getAmount0ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        internal
        pure
        returns (uint256)
    {
        return FullMath.mulDiv(
            uint256(liquidity) << 96,
            uint256(sqrtRatioBX96 - sqrtRatioAX96),
            uint256(sqrtRatioBX96)
        ) / uint256(sqrtRatioAX96);
    }

    function _getAmount1ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        internal
        pure
        returns (uint256)
    {
        return FullMath.mulDiv(uint256(liquidity), uint256(sqrtRatioBX96 - sqrtRatioAX96), Q96);
    }

    function _getAmountsForLiquidity(
        uint160 sqrtPriceX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }
        if (sqrtPriceX96 <= sqrtRatioAX96) {
            amount0 = _getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
            amount1 = 0;
        } else if (sqrtPriceX96 < sqrtRatioBX96) {
            amount0 = _getAmount0ForLiquidity(sqrtPriceX96, sqrtRatioBX96, liquidity);
            amount1 = _getAmount1ForLiquidity(sqrtRatioAX96, sqrtPriceX96, liquidity);
        } else {
            amount0 = 0;
            amount1 = _getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }

    function _tickFromSqrtPrice(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        if (sqrtPriceX96 == 0) return MIN_TICK;
        int256 l2s = _log2(uint256(sqrtPriceX96));
        int256 log2p24 = 2 * l2s - int256(uint256(192) << 24);
        int256 num = log2p24 * 100;
        int256 q = num / 242032;
        if (num < 0 && num % 242032 != 0) q -= 1;
        if (q < int256(int24(MIN_TICK))) q = int256(int24(MIN_TICK));
        if (q > int256(int24(MAX_TICK))) q = int256(int24(MAX_TICK));
        tick = int24(q);
    }

    function _msb(uint256 x) private pure returns (uint256 r) {
        if (x >= 1 << 128) { x >>= 128; r |= 128; }
        if (x >= 1 << 64) { x >>= 64; r |= 64; }
        if (x >= 1 << 32) { x >>= 32; r |= 32; }
        if (x >= 1 << 16) { x >>= 16; r |= 16; }
        if (x >= 1 << 8) { x >>= 8; r |= 8; }
        if (x >= 1 << 4) { x >>= 4; r |= 4; }
        if (x >= 1 << 2) { x >>= 2; r |= 2; }
        if (x >= 1 << 1) { r |= 1; }
    }

    function _log2(uint256 x) private pure returns (int256 r) {
        uint256 msb = _msb(x);
        r = int256(msb) << 24;
        uint256 a;
        if (msb <= 96) {
            a = x << (96 - msb);
        } else {
            a = x >> (msb - 96);
        }
        uint256 mask = 1 << 23;
        for (uint256 i = 0; i < 24; i++) {
            uint256 aa = a * a;
            if (aa >= (1 << 193)) {
                r |= int256(mask);
                a = aa >> 97;
            } else {
                a = aa >> 96;
            }
            mask >>= 1;
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _transferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
