// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract ConcentratedLiquidityExchange {
    uint256 public constant MAX_POSITIONS_PER_USER = 100;
    uint24 public constant FEE_DENOMINATOR = 100000;
    uint24 public constant DEFAULT_FEE = 250; // 0.25%
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = 887272;

    error ZeroAddress();
    error Unauthorized();
    error ReentrantCall();
    error PoolNotActive();
    error PoolIsPaused();
    error PoolAlreadyExists();
    error PairNotWhitelisted();
    error TokenNotInPool();
    error InvalidTickRange();
    error InvalidAmount();
    error InvalidFee();
    error SameToken();
    error InsufficientLiquidity();
    error InsufficientOutput();
    error SlippageExceeded();
    error MaxPositionsExceeded();
    error PositionNotFound();
    error NotPositionOwner();
    error TransferFailed();
    error LiquidityOverflow();

    event PairWhitelisted(address indexed token0, address indexed token1, uint256 indexed poolId);
    event TokenWhitelistUpdated(address indexed token, bool status);
    event GlobalFeeUpdated(uint24 oldFee, uint24 newFee);
    event PoolPaused(uint256 indexed poolId, bool paused);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event PositionCreated(
        uint256 indexed positionId,
        uint256 indexed poolId,
        address indexed owner,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event LiquidityAdded(
        uint256 indexed positionId,
        uint256 indexed poolId,
        address indexed owner,
        uint128 liquidityDelta,
        uint256 amount0,
        uint256 amount1
    );
    event LiquidityRemoved(
        uint256 indexed positionId,
        uint256 indexed poolId,
        address indexed owner,
        uint128 liquidityDelta,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        uint256 indexed poolId,
        address indexed user,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint24 fee
    );

    address public operator;
    uint24 public globalFee;
    uint256 public poolCount;
    uint256 public positionCount;
    bool private locked;

    struct TickInfo {
        uint128 liquidityGross;
        int128 liquidityNet;
        bool initialized;
    }

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint128 totalLiquidity;
        int24 currentTick;
        bool paused;
        bool active;
    }

    struct Position {
        uint256 poolId;
        address owner;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bool active;
    }

    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(int24 => TickInfo)) public poolTicks;
    mapping(bytes32 => uint256) public pairToPoolId;
    mapping(address => uint256[]) public userPositions;
    mapping(uint256 => Position) public positions;
    mapping(address => bool) public whitelistedTokens;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        operator = msg.sender;
        globalFee = DEFAULT_FEE;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert SameToken();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _pairKey(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _checkTicks(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (tickLower < MIN_TICK) revert InvalidTickRange();
        if (tickUpper > MAX_TICK) revert InvalidTickRange();
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function _computeLiquidity(uint256 amount0, uint256 amount1) internal pure returns (uint128) {
        if (amount0 == 0 || amount1 == 0) revert InvalidAmount();
        uint256 prod = amount0 * amount1;
        uint256 sqrtProd = _sqrt(prod);
        if (sqrtProd == 0 || sqrtProd > type(uint128).max) revert LiquidityOverflow();
        return uint128(sqrtProd);
    }

    function _updateTick(uint256 poolId, int24 tick, int128 liquidityDelta, bool isLower) internal {
        TickInfo storage info = poolTicks[poolId][tick];
        if (liquidityDelta >= 0) {
            uint128 add = uint128(uint256(int256(liquidityDelta)));
            info.liquidityGross += add;
        } else {
            uint128 sub = uint128(uint256(-int256(liquidityDelta)));
            if (info.liquidityGross < sub) revert InsufficientLiquidity();
            info.liquidityGross -= sub;
        }
        if (isLower) {
            info.liquidityNet += liquidityDelta;
        } else {
            info.liquidityNet -= liquidityDelta;
        }
        info.initialized = info.liquidityGross > 0;
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        if (!IERC20(token).transferFrom(from, to, amount)) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
    }

    function whitelistToken(address token, bool status) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        whitelistedTokens[token] = status;
        emit TokenWhitelistUpdated(token, status);
    }

    function addPair(address tokenA, address tokenB) external onlyOperator returns (uint256 poolId) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (!whitelistedTokens[token0] || !whitelistedTokens[token1]) revert PairNotWhitelisted();
        bytes32 key = _pairKey(token0, token1);
        if (pairToPoolId[key] != 0) revert PoolAlreadyExists();
        poolId = ++poolCount;
        pools[poolId] = Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            totalLiquidity: 0,
            currentTick: 0,
            paused: false,
            active: true
        });
        pairToPoolId[key] = poolId;
        emit PairWhitelisted(token0, token1, poolId);
    }

    function setGlobalFee(uint24 newFee) external onlyOperator {
        if (newFee > FEE_DENOMINATOR) revert InvalidFee();
        uint24 oldFee = globalFee;
        globalFee = newFee;
        emit GlobalFeeUpdated(oldFee, newFee);
    }

    function setPoolPaused(uint256 poolId, bool paused) external onlyOperator {
        if (!pools[poolId].active) revert PoolNotActive();
        pools[poolId].paused = paused;
        emit PoolPaused(poolId, paused);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function createPosition(
        uint256 poolId,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external nonReentrant returns (uint256 positionId) {
        if (amount0Desired == 0 || amount1Desired == 0) revert InvalidAmount();
        Pool storage pool = pools[poolId];
        if (!pool.active) revert PoolNotActive();
        if (pool.paused) revert PoolIsPaused();
        _checkTicks(tickLower, tickUpper);
        if (userPositions[msg.sender].length >= MAX_POSITIONS_PER_USER) revert MaxPositionsExceeded();

        uint128 liquidity = _computeLiquidity(amount0Desired, amount1Desired);

        _updateTick(poolId, tickLower, int128(int256(uint256(liquidity))), true);
        _updateTick(poolId, tickUpper, -int128(int256(uint256(liquidity))), false);

        pool.reserve0 += amount0Desired;
        pool.reserve1 += amount1Desired;
        pool.totalLiquidity += liquidity;
        if (pool.currentTick == 0) {
            pool.currentTick = (tickLower + tickUpper) / 2;
        }

        positionId = ++positionCount;
        positions[positionId] = Position({
            poolId: poolId,
            owner: msg.sender,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            active: true
        });
        userPositions[msg.sender].push(positionId);

        _safeTransferFrom(pool.token0, msg.sender, address(this), amount0Desired);
        _safeTransferFrom(pool.token1, msg.sender, address(this), amount1Desired);

        emit PositionCreated(positionId, poolId, msg.sender, tickLower, tickUpper, liquidity, amount0Desired, amount1Desired);
    }

    function addLiquidity(
        uint256 positionId,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external nonReentrant returns (uint128 liquidityDelta) {
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotFound();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (amount0Desired == 0 || amount1Desired == 0) revert InvalidAmount();

        Pool storage pool = pools[pos.poolId];
        if (!pool.active) revert PoolNotActive();
        if (pool.paused) revert PoolIsPaused();

        liquidityDelta = _computeLiquidity(amount0Desired, amount1Desired);

        _updateTick(pos.poolId, pos.tickLower, int128(int256(uint256(liquidityDelta))), true);
        _updateTick(pos.poolId, pos.tickUpper, -int128(int256(uint256(liquidityDelta))), false);

        pool.reserve0 += amount0Desired;
        pool.reserve1 += amount1Desired;
        pool.totalLiquidity += liquidityDelta;
        pos.liquidity += liquidityDelta;

        _safeTransferFrom(pool.token0, msg.sender, address(this), amount0Desired);
        _safeTransferFrom(pool.token1, msg.sender, address(this), amount1Desired);

        emit LiquidityAdded(positionId, pos.poolId, msg.sender, liquidityDelta, amount0Desired, amount1Desired);
    }

    function removeLiquidity(uint256 positionId, uint128 liquidityToRemove)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotFound();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (liquidityToRemove == 0) revert InvalidAmount();
        if (pos.liquidity < liquidityToRemove) revert InsufficientLiquidity();

        Pool storage pool = pools[pos.poolId];
        if (!pool.active) revert PoolNotActive();
        if (pool.totalLiquidity == 0) revert InsufficientLiquidity();

        uint256 liq = uint256(liquidityToRemove);
        uint256 totalLiq = uint256(pool.totalLiquidity);
        amount0 = (liq * pool.reserve0) / totalLiq;
        amount1 = (liq * pool.reserve1) / totalLiq;
        if (amount0 == 0 && amount1 == 0) revert InsufficientLiquidity();
        if (amount0 > pool.reserve0) amount0 = pool.reserve0;
        if (amount1 > pool.reserve1) amount1 = pool.reserve1;

        _updateTick(pos.poolId, pos.tickLower, -int128(int256(liq)), true);
        _updateTick(pos.poolId, pos.tickUpper, int128(int256(liq)), false);

        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalLiquidity -= liquidityToRemove;
        pos.liquidity -= liquidityToRemove;

        _safeTransfer(pool.token0, msg.sender, amount0);
        _safeTransfer(pool.token1, msg.sender, amount1);

        emit LiquidityRemoved(positionId, pos.poolId, msg.sender, liquidityToRemove, amount0, amount1);
    }

    function swap(uint256 poolId, address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        Pool storage pool = pools[poolId];
        if (!pool.active) revert PoolNotActive();
        if (pool.paused) revert PoolIsPaused();
        if (amountIn == 0) revert InvalidAmount();

        bool zeroForOne = tokenIn == pool.token0;
        if (!zeroForOne && tokenIn != pool.token1) revert TokenNotInPool();

        (uint256 reserveIn, uint256 reserveOut) = zeroForOne
            ? (pool.reserve0, pool.reserve1)
            : (pool.reserve1, pool.reserve0);

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        // Compute output with full precision (multiply before divide) to avoid divide-before-multiply.
        uint256 feeMultiplier = FEE_DENOMINATOR - globalFee;
        uint256 numerator = reserveOut * amountIn * feeMultiplier;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountIn * feeMultiplier;
        amountOut = numerator / denominator;

        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (amountOut >= reserveOut) revert InsufficientOutput();

        address tokenOut = zeroForOne ? pool.token1 : pool.token0;

        // Effects: update reserves before interactions.
        if (zeroForOne) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        // Interactions: pull input and push output.
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        emit Swap(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, globalFee);
    }

    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }

    function getUserPositionCount(address user) external view returns (uint256) {
        return userPositions[user].length;
    }

    function getPoolReserves(uint256 poolId) external view returns (uint256 reserve0, uint256 reserve1) {
        return (pools[poolId].reserve0, pools[poolId].reserve1);
    }

    function getPoolTokens(uint256 poolId) external view returns (address token0, address token1) {
        return (pools[poolId].token0, pools[poolId].token1);
    }

    function getPoolLiquidity(uint256 poolId) external view returns (uint128) {
        return pools[poolId].totalLiquidity;
    }

    function isPoolPaused(uint256 poolId) external view returns (bool) {
        return pools[poolId].paused;
    }

    function isPoolActive(uint256 poolId) external view returns (bool) {
        return pools[poolId].active;
    }

    function getTickInfo(uint256 poolId, int24 tick) external view returns (uint128 liquidityGross, int128 liquidityNet, bool initialized) {
        TickInfo storage info = poolTicks[poolId][tick];
        return (info.liquidityGross, info.liquidityNet, info.initialized);
    }

    function getPoolByPair(address tokenA, address tokenB) external view returns (uint256) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return pairToPoolId[_pairKey(token0, token1)];
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }
}
