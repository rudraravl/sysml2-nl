// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AutomatedMarketMaker {
    error ZeroAddress();
    error IdenticalTokens();
    error PoolAlreadyExists();
    error PoolNotFound();
    error InsufficientLiquidity();
    error InsufficientAmount();
    error SlippageExceeded();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InvalidFee();
    error Unauthorized();
    error TransferFailed();

    event PoolCreated(address indexed token0, address indexed token1, address indexed creator);
    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 lpMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 lpBurned
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
    }

    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant MAX_FEE = 100; // 1%

    address public owner;
    uint256 public fee; // in basis points, 30 = 0.3%

    mapping(address => mapping(address => Pool)) internal pools;
    mapping(address => mapping(address => mapping(address => uint256))) internal lpBalances;

    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        uint256 guard = _locked;
        _locked = 2;
        _;
        _locked = guard;
    }

    constructor() {
        owner = msg.sender;
        fee = 30; // 0.3%
    }

    function setFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint256 oldFee = fee;
        fee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function getPool(address tokenA, address tokenB)
        external
        view
        returns (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalSupply
        )
    {
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        Pool storage p = pools[t0][t1];
        if (p.token0 == address(0)) revert PoolNotFound();
        return (p.token0, p.token1, p.reserve0, p.reserve1, p.totalSupply);
    }

    function lpBalanceOf(address tokenA, address tokenB, address account) external view returns (uint256) {
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        return lpBalances[t0][t1][account];
    }

    function createPool(address tokenA, address tokenB)
        external
        nonReentrant
        returns (address token0, address token1)
    {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();
        (token0, token1) = _sortTokens(tokenA, tokenB);
        if (pools[token0][token1].token0 != address(0)) revert PoolAlreadyExists();
        pools[token0][token1] = Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            totalSupply: 0
        });
        emit PoolCreated(token0, token1, msg.sender);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 lpMinted) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage p = pools[token0][token1];
        if (p.token0 == address(0)) revert PoolNotFound();
        if (amountADesired == 0 || amountBDesired == 0) revert InsufficientAmount();

        bool aIs0 = tokenA == token0;
        uint256 amount0Desired = aIs0 ? amountADesired : amountBDesired;
        uint256 amount1Desired = aIs0 ? amountBDesired : amountADesired;
        uint256 amount0Min = aIs0 ? amountAMin : amountBMin;
        uint256 amount1Min = aIs0 ? amountBMin : amountAMin;

        uint256 amount0;
        uint256 amount1;

        if (p.totalSupply == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            lpMinted = _sqrt(amount0 * amount1);
            if (lpMinted < MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();

            _safeTransferFrom(token0, msg.sender, address(this), amount0);
            _safeTransferFrom(token1, msg.sender, address(this), amount1);

            p.reserve0 = amount0;
            p.reserve1 = amount1;
            p.totalSupply = lpMinted;

            lpBalances[token0][token1][address(0)] += MINIMUM_LIQUIDITY;
            lpBalances[token0][token1][msg.sender] += lpMinted - MINIMUM_LIQUIDITY;
        } else {
            (amount0, amount1, lpMinted) = _addLiquidityExisting(
                p,
                amount0Desired,
                amount1Desired,
                amount0Min,
                amount1Min
            );

            _safeTransferFrom(token0, msg.sender, address(this), amount0);
            _safeTransferFrom(token1, msg.sender, address(this), amount1);

            p.reserve0 += amount0;
            p.reserve1 += amount1;
            p.totalSupply += lpMinted;
            lpBalances[token0][token1][msg.sender] += lpMinted;
        }

        (amountA, amountB) = aIs0 ? (amount0, amount1) : (amount1, amount0);
        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, lpMinted);
    }

    function _addLiquidityExisting(
        Pool storage p,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal returns (uint256 amount0, uint256 amount1, uint256 lpMinted) {
        uint256 reserve0 = p.reserve0;
        uint256 reserve1 = p.reserve1;
        uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
        if (amount1Optimal <= amount1Desired) {
            if (amount1Optimal < amount1Min) revert SlippageExceeded();
            amount0 = amount0Desired;
            amount1 = amount1Optimal;
        } else {
            uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
            if (amount0Optimal > amount0Desired) revert SlippageExceeded();
            if (amount0Optimal < amount0Min) revert SlippageExceeded();
            amount0 = amount0Optimal;
            amount1 = amount1Desired;
        }

        if (amount0 == 0 || amount1 == 0) revert InsufficientAmount();

        lpMinted = (amount0 * p.totalSupply) / reserve0;
        if (lpMinted == 0) revert InsufficientLiquidityMinted();
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 lpAmount,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage p = pools[token0][token1];
        if (p.token0 == address(0)) revert PoolNotFound();
        if (lpAmount == 0) revert InsufficientAmount();

        uint256 userLp = lpBalances[token0][token1][msg.sender];
        if (userLp < lpAmount) revert InsufficientLiquidityBurned();

        uint256 total = p.totalSupply;
        uint256 amount0 = (lpAmount * p.reserve0) / total;
        uint256 amount1 = (lpAmount * p.reserve1) / total;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        bool aIs0 = tokenA == token0;
        uint256 aMin0 = aIs0 ? amountAMin : amountBMin;
        uint256 aMin1 = aIs0 ? amountBMin : amountAMin;
        if (amount0 < aMin0 || amount1 < aMin1) revert SlippageExceeded();

        lpBalances[token0][token1][msg.sender] -= lpAmount;
        p.totalSupply -= lpAmount;
        p.reserve0 -= amount0;
        p.reserve1 -= amount1;

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        (amountA, amountB) = aIs0 ? (amount0, amount1) : (amount1, amount0);
        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, lpAmount);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant returns (uint256 amountOut) {
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();
        if (tokenIn == tokenOut) revert IdenticalTokens();
        if (amountIn == 0) revert InsufficientAmount();

        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        Pool storage p = pools[token0][token1];
        if (p.token0 == address(0)) revert PoolNotFound();
        if (p.totalSupply == 0) revert InsufficientLiquidity();

        bool isToken0In = tokenIn == token0;
        uint256 reserveIn = isToken0In ? p.reserve0 : p.reserve1;
        uint256 reserveOut = isToken0In ? p.reserve1 : p.reserve0;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut < amountOutMin) revert SlippageExceeded();

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        if (isToken0In) {
            p.reserve0 += amountIn;
            p.reserve1 -= amountOut;
        } else {
            p.reserve1 += amountIn;
            p.reserve0 -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

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

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }
}
