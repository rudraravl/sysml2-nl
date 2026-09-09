// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    // -------- Custom errors --------
    error NotOwner();
    error IdenticalTokens();
    error ZeroAddress();
    error PairAlreadyExists();
    error PairDoesNotExist();
    error PairNotInitialized();
    error InvalidFee();
    error InvalidFeeStep();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InsufficientLiquidityBurned();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error SlippageExceeded();
    error TransferFailed();
    error Reentrancy();
    error ReserveOverflow();

    // -------- Constants --------
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 100;
    uint256 public constant FEE_STEP_BPS = 1;
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    // -------- State --------
    address public owner;
    uint256 public swapFee;

    struct Pool {
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint32 blockTimestampLast;
        uint256 totalLiquidity;
        uint256 accumulatedFees0;
        uint256 accumulatedFees1;
        bool initialized;
    }

    mapping(bytes32 => Pool) internal pools;
    mapping(bytes32 => mapping(address => uint256)) internal lpBalances;
    mapping(address => mapping(address => bytes32)) public pairIdOf;
    bytes32[] public allPairIds;

    bool private locked;

    // -------- Events --------
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event PairCreated(address indexed token0, address indexed token1, bytes32 indexed pairId);
    event LiquidityAdded(
        address indexed provider,
        bytes32 indexed pairId,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        bytes32 indexed pairId,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    event Swap(
        address indexed sender,
        bytes32 indexed pairId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeTaken,
        address indexed to
    );
    event Sync(bytes32 indexed pairId, uint112 reserve0, uint112 reserve1);

    // -------- Modifiers --------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    // -------- Constructor --------
    constructor() {
        owner = msg.sender;
        swapFee = 30;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeUpdated(0, 30);
    }

    // -------- Admin --------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setSwapFee(uint256 newFee) external onlyOwner {
        if (newFee == 0 || newFee > MAX_FEE_BPS) revert InvalidFee();
        uint256 diff = newFee > swapFee ? newFee - swapFee : swapFee - newFee;
        if (diff % FEE_STEP_BPS != 0) revert InvalidFeeStep();
        uint256 old = swapFee;
        swapFee = newFee;
        emit FeeUpdated(old, newFee);
    }

    function createPair(address tokenA, address tokenB) external onlyOwner returns (bytes32 pairId) {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pairId = _pairId(token0, token1);
        if (pools[pairId].token0 != address(0)) revert PairAlreadyExists();

        pools[pairId] = Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            blockTimestampLast: 0,
            totalLiquidity: 0,
            accumulatedFees0: 0,
            accumulatedFees1: 0,
            initialized: false
        });

        pairIdOf[token0][token1] = pairId;
        pairIdOf[token1][token0] = pairId;
        allPairIds.push(pairId);

        emit PairCreated(token0, token1, pairId);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairIds.length;
    }

    // -------- Liquidity --------
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidityMinted) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _pairId(token0, token1);
        Pool storage pool = pools[pairId];
        if (pool.token0 == address(0)) revert PairDoesNotExist();

        if (!pool.initialized) {
            return _addInitialLiquidity(
                pool,
                pairId,
                token0,
                token1,
                tokenA,
                tokenB,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin
            );
        }

        return _addSubsequentLiquidity(
            pool,
            pairId,
            token0,
            token1,
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
    }

    function _addInitialLiquidity(
        Pool storage pool,
        bytes32 pairId,
        address token0,
        address token1,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB, uint256 liquidityMinted) {
        if (amountADesired == 0 || amountBDesired == 0) revert ZeroAmount();
        if (amountADesired < amountAMin || amountBDesired < amountBMin) revert SlippageExceeded();

        (amountA, amountB) = tokenA == token0
            ? (amountADesired, amountBDesired)
            : (amountBDesired, amountADesired);

        _safeTransferFrom(token0, msg.sender, address(this), amountA);
        _safeTransferFrom(token1, msg.sender, address(this), amountB);

        uint256 initial = _sqrt(amountA * amountB);
        if (initial <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
        liquidityMinted = initial - MINIMUM_LIQUIDITY;

        _mintLp(pairId, address(0), MINIMUM_LIQUIDITY);
        _mintLp(pairId, msg.sender, liquidityMinted);

        pool.initialized = true;
        _update(pool, pairId, uint112(amountA), uint112(amountB));

        emit LiquidityAdded(msg.sender, pairId, token0, token1, amountA, amountB, liquidityMinted);
    }

    function _addSubsequentLiquidity(
        Pool storage pool,
        bytes32 pairId,
        address token0,
        address token1,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB, uint256 liquidityMinted) {
        uint256 reserve0 = pool.reserve0;
        uint256 reserve1 = pool.reserve1;
        uint256 totalLiquidity = pool.totalLiquidity;

        uint256 reserveA = tokenA == token0 ? reserve0 : reserve1;
        uint256 reserveB = tokenA == token0 ? reserve1 : reserve0;
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();

        uint256 amount0;
        uint256 amount1;

        uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
        if (amountBOptimal <= amountBDesired) {
            if (amountBOptimal < amountBMin) revert SlippageExceeded();
            (amountA, amountB) = (amountADesired, amountBOptimal);
        } else {
            uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
            if (amountAOptimal > amountADesired) revert SlippageExceeded();
            if (amountAOptimal < amountAMin) revert SlippageExceeded();
            (amountA, amountB) = (amountAOptimal, amountBDesired);
        }

        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        (amount0, amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);

        uint256 liq0 = (amount0 * totalLiquidity) / reserve0;
        uint256 liq1 = (amount1 * totalLiquidity) / reserve1;
        liquidityMinted = liq0 < liq1 ? liq0 : liq1;
        if (liquidityMinted == 0) revert InsufficientLiquidity();

        _mintLp(pairId, msg.sender, liquidityMinted);
        _update(pool, pairId, uint112(reserve0 + amount0), uint112(reserve1 + amount1));

        emit LiquidityAdded(msg.sender, pairId, token0, token1, amountA, amountB, liquidityMinted);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityToRemove,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _pairId(token0, token1);
        Pool storage pool = pools[pairId];
        if (pool.token0 == address(0)) revert PairDoesNotExist();
        if (!pool.initialized) revert PairNotInitialized();
        if (liquidityToRemove == 0) revert ZeroAmount();

        uint256 totalLiquidity = pool.totalLiquidity;
        if (totalLiquidity == 0) revert InsufficientLiquidity();
        if (lpBalances[pairId][msg.sender] < liquidityToRemove) revert InsufficientLiquidityBurned();

        uint256 amount0 = (liquidityToRemove * pool.reserve0) / totalLiquidity;
        uint256 amount1 = (liquidityToRemove * pool.reserve1) / totalLiquidity;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();

        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin || amountB < amountBMin) revert SlippageExceeded();

        _burnLp(pairId, msg.sender, liquidityToRemove);

        _update(pool, pairId, uint112(uint256(pool.reserve0) - amount0), uint112(uint256(pool.reserve1) - amount1));

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, pairId, token0, token1, amountA, amountB, liquidityToRemove);
    }

    // -------- Swap --------
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        if (tokenIn == tokenOut) revert IdenticalTokens();
        if (to == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();

        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        bytes32 pairId = _pairId(token0, token1);
        Pool storage pool = pools[pairId];
        if (pool.token0 == address(0)) revert PairDoesNotExist();
        if (!pool.initialized) revert PairNotInitialized();

        bool zeroForOne = tokenIn == token0;
        uint256 reserveIn = zeroForOne ? uint256(pool.reserve0) : uint256(pool.reserve1);
        uint256 reserveOut = zeroForOne ? uint256(pool.reserve1) : uint256(pool.reserve0);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;

        if (amountOut == 0) revert InsufficientOutputAmount();
        if (amountOut < amountOutMin) revert SlippageExceeded();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        uint256 feeTaken = amountIn - (amountInWithFee / FEE_DENOMINATOR);

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, to, amountOut);

        if (zeroForOne) {
            pool.accumulatedFees0 += feeTaken;
            _update(pool, pairId, uint112(reserveIn + amountIn), uint112(reserveOut - amountOut));
        } else {
            pool.accumulatedFees1 += feeTaken;
            _update(pool, pairId, uint112(reserveOut - amountOut), uint112(reserveIn + amountIn));
        }

        emit Swap(msg.sender, pairId, tokenIn, tokenOut, amountIn, amountOut, feeTaken, to);
    }

    // -------- Views --------
    function getReserves(address tokenA, address tokenB)
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _pairId(token0, token1);
        Pool storage pool = pools[pairId];
        return (pool.reserve0, pool.reserve1, pool.blockTimestampLast);
    }

    function getPairInfo(bytes32 pairId)
        external
        view
        returns (
            address token0,
            address token1,
            uint112 reserve0,
            uint112 reserve1,
            uint256 totalLiquidity,
            uint256 accumulatedFees0,
            uint256 accumulatedFees1,
            bool initialized
        )
    {
        Pool storage pool = pools[pairId];
        return (
            pool.token0,
            pool.token1,
            pool.reserve0,
            pool.reserve1,
            pool.totalLiquidity,
            pool.accumulatedFees0,
            pool.accumulatedFees1,
            pool.initialized
        );
    }

    function getLpBalance(address tokenA, address tokenB, address user) external view returns (uint256) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _pairId(token0, token1);
        return lpBalances[pairId][user];
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        (address token0, ) = _sortTokens(tokenIn, tokenOut);
        bytes32 pairId = _pairId(token0, tokenOut);
        Pool storage pool = pools[pairId];
        if (pool.token0 == address(0)) revert PairDoesNotExist();
        bool zeroForOne = tokenIn == token0;
        uint256 reserveIn = zeroForOne ? uint256(pool.reserve0) : uint256(pool.reserve1);
        uint256 reserveOut = zeroForOne ? uint256(pool.reserve1) : uint256(pool.reserve0);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // -------- Internal helpers --------
    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        if (tokenA < tokenB) {
            (token0, token1) = (tokenA, tokenB);
        } else {
            (token0, token1) = (tokenB, tokenA);
        }
    }

    function _pairId(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _mintLp(bytes32 pairId, address to, uint256 amount) internal {
        lpBalances[pairId][to] += amount;
        pools[pairId].totalLiquidity += amount;
    }

    function _burnLp(bytes32 pairId, address from, uint256 amount) internal {
        lpBalances[pairId][from] -= amount;
        pools[pairId].totalLiquidity -= amount;
    }

    function _update(
        Pool storage pool,
        bytes32 pairId,
        uint112 newReserve0,
        uint112 newReserve1
    ) internal {
        if (uint256(newReserve0) > type(uint112).max || uint256(newReserve1) > type(uint112).max) {
            revert ReserveOverflow();
        }
        pool.reserve0 = newReserve0;
        pool.reserve1 = newReserve1;
        pool.blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        emit Sync(pairId, newReserve0, newReserve1);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
