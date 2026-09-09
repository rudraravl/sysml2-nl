// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract DecentralizedExchange is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error Unauthorized();
    error Paused();
    error IdenticalTokens();
    error ZeroAddress();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error InvalidFeeRate();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error InsufficientLiquidityBalance();

    event PairAdded(address indexed token0, address indexed token1, uint256 feeRate);
    event FeeRateUpdated(address indexed token0, address indexed token1, uint256 feeRate);
    event PausedStateChanged(bool paused);
    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    uint256 public constant MIN_FEE_BPS = 5;
    uint256 public constant MAX_FEE_BPS = 30;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public operator;
    bool public paused;

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 feeRate;
        uint256 totalSupply;
        bool exists;
    }

    mapping(address => mapping(address => Pool)) public pools;
    mapping(address => mapping(address => mapping(address => uint256))) public liquidityBalances;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
    }

    function addPair(address tokenA, address tokenB, uint256 feeRate) external onlyOperator {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (feeRate < MIN_FEE_BPS || feeRate > MAX_FEE_BPS) revert InvalidFeeRate();

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (pools[token0][token1].exists) revert PoolAlreadyExists();

        pools[token0][token1] = Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            feeRate: feeRate,
            totalSupply: 0,
            exists: true
        });

        emit PairAdded(token0, token1, feeRate);
    }

    function setFeeRate(address tokenA, address tokenB, uint256 feeRate) external onlyOperator {
        if (feeRate < MIN_FEE_BPS || feeRate > MAX_FEE_BPS) revert InvalidFeeRate();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();

        pool.feeRate = feeRate;
        emit FeeRateUpdated(token0, token1, feeRate);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (amountADesired == 0 || amountBDesired == 0) revert InsufficientInputAmount();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();

        uint256 amount0;
        uint256 amount1;

        (uint256 amount0Desired, uint256 amount1Desired) =
            tokenA == token0 ? (amountADesired, amountBDesired) : (amountBDesired, amountADesired);
        (uint256 amount0Min, uint256 amount1Min) =
            tokenA == token0 ? (amountAMin, amountBMin) : (amountBMin, amountAMin);

        if (pool.totalSupply == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            liquidity = _sqrt(amount0 * amount1);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            _mint(token0, token1, address(0), MINIMUM_LIQUIDITY);
            liquidity -= MINIMUM_LIQUIDITY;
        } else {
            uint256 amount1Optimal = (amount0Desired * pool.reserve1) / pool.reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert SlippageExceeded();
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * pool.reserve0) / pool.reserve1;
                if (amount0Optimal > amount0Desired) revert SlippageExceeded();
                if (amount0Optimal < amount0Min) revert SlippageExceeded();
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
            uint256 liq0 = (amount0 * pool.totalSupply) / pool.reserve0;
            uint256 liq1 = (amount1 * pool.totalSupply) / pool.reserve1;
            liquidity = liq0 < liq1 ? liq0 : liq1;
        }

        if (liquidity == 0) revert InsufficientLiquidity();

        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        _mint(token0, token1, msg.sender, liquidity);

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        amountA = tokenA == token0 ? amount0 : amount1;
        amountB = tokenA == token0 ? amount1 : amount0;

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert InsufficientInputAmount();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();

        if (liquidityBalances[token0][token1][msg.sender] < liquidity)
            revert InsufficientLiquidityBalance();

        uint256 amount0 = (liquidity * pool.reserve0) / pool.totalSupply;
        uint256 amount1 = (liquidity * pool.reserve1) / pool.totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        (uint256 amount0Min, uint256 amount1Min) =
            tokenA == token0 ? (amountAMin, amountBMin) : (amountBMin, amountAMin);
        if (amount0 < amount0Min || amount1 < amount1Min) revert SlippageExceeded();

        _burn(token0, token1, msg.sender, liquidity);
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        amountA = tokenA == token0 ? amount0 : amount1;
        amountB = tokenA == token0 ? amount1 : amount0;

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientInputAmount();
        if (tokenIn == tokenOut) revert IdenticalTokens();
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();

        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();

        bool isToken0In = tokenIn == pool.token0;
        (uint256 reserveIn, uint256 reserveOut) =
            isToken0In ? (pool.reserve0, pool.reserve1) : (pool.reserve1, pool.reserve0);

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - pool.feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * BPS_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;

        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        if (isToken0In) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getPool(address tokenA, address tokenB)
        external
        view
        returns (uint256 reserve0, uint256 reserve1, uint256 feeRate, uint256 totalSupply)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        return (pool.reserve0, pool.reserve1, pool.feeRate, pool.totalSupply);
    }

    function getLiquidityBalance(address tokenA, address tokenB, address provider)
        external
        view
        returns (uint256)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return liquidityBalances[token0][token1][provider];
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();
        (uint256 reserveIn, uint256 reserveOut) =
            tokenIn == pool.token0 ? (pool.reserve0, pool.reserve1) : (pool.reserve1, pool.reserve0);
        return _getAmountOut(amountIn, reserveIn, reserveOut, pool.feeRate);
    }

    function getAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) external view returns (uint256) {
        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();
        (uint256 reserveIn, uint256 reserveOut) =
            tokenIn == pool.token0 ? (pool.reserve0, pool.reserve1) : (pool.reserve1, pool.reserve0);
        return _getAmountIn(amountOut, reserveIn, reserveOut, pool.feeRate);
    }

    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeRate
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * BPS_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeRate
    ) internal pure returns (uint256) {
        uint256 numerator = reserveIn * amountOut * BPS_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (BPS_DENOMINATOR - feeRate);
        return (numerator / denominator) + 1;
    }

    function _mint(address token0, address token1, address to, uint256 amount) internal {
        liquidityBalances[token0][token1][to] += amount;
        pools[token0][token1].totalSupply += amount;
    }

    function _burn(address token0, address token1, address from, uint256 amount) internal {
        liquidityBalances[token0][token1][from] -= amount;
        pools[token0][token1].totalSupply -= amount;
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
