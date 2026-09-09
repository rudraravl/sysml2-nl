// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedSwap {
    error InvalidTokenPair();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InvalidAmount();
    error FeeTooHigh();
    error Unauthorized();
    error PoolDoesNotExist();
    error TransferFailed();
    error Reentrancy();

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

    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    struct Pool {
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint256 totalSupply;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => uint256)) public liquidityBalance;

    uint256 public feeBps;
    address public operator;
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private unlocked = 1;

    modifier lock() {
        if (unlocked != 1) revert Reentrancy();
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert Unauthorized();
        operator = _operator;
        feeBps = 30; // 0.3%
        emit FeeUpdated(0, 30);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert Unauthorized();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > 100) revert FeeTooHigh(); // Max 1%
        emit FeeUpdated(feeBps, newFeeBps);
        feeBps = newFeeBps;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external lock returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 poolId = _getPoolId(token0, token1);
        Pool storage pool = pools[poolId];

        if (pool.token0 == address(0)) {
            pool.token0 = token0;
            pool.token1 = token1;
        }

        (amountA, amountB) = _calcDepositAmounts(
            pool,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        _doTransferIn(tokenA, token0, token1, amountA, amountB);

        uint256 amount0Added;
        uint256 amount1Added;
        (liquidity, amount0Added, amount1Added) = _mintPoolLiquidity(pool, poolId, token0, token1);
        if (liquidity == 0) revert InsufficientLiquidity();

        liquidityBalance[poolId][msg.sender] += liquidity;

        emit LiquidityAdded(msg.sender, token0, token1, amount0Added, amount1Added, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external lock returns (uint256 amountA, uint256 amountB) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 poolId = _getPoolId(token0, token1);
        Pool storage pool = pools[poolId];
        if (pool.token0 == address(0)) revert PoolDoesNotExist();
        if (liquidityBalance[poolId][msg.sender] < liquidity) revert InsufficientLiquidity();

        uint256 amount0 = (liquidity * pool.reserve0) / pool.totalSupply;
        uint256 amount1 = (liquidity * pool.reserve1) / pool.totalSupply;

        amountA = tokenA == token0 ? amount0 : amount1;
        amountB = tokenA == token0 ? amount1 : amount0;

        if (amountA < amountAMin || amountB < amountBMin) revert InsufficientOutputAmount();

        liquidityBalance[poolId][msg.sender] -= liquidity;
        pool.totalSupply -= liquidity;

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        pool.reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        pool.reserve1 = uint112(IERC20(token1).balanceOf(address(this)));

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external lock returns (uint256 amountOut) {
        if (tokenIn == tokenOut) revert InvalidTokenPair();
        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        bytes32 poolId = _getPoolId(token0, token1);
        Pool storage pool = pools[poolId];
        if (pool.token0 == address(0)) revert PoolDoesNotExist();

        uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        uint256 actualAmountIn = IERC20(tokenIn).balanceOf(address(this)) - balanceBefore;
        if (actualAmountIn == 0) revert InvalidAmount();

        amountOut = _getAmountOut(actualAmountIn, pool, tokenIn == token0);
        if (amountOut < amountOutMin) revert InsufficientOutputAmount();

        _safeTransfer(tokenOut, msg.sender, amountOut);

        pool.reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        pool.reserve1 = uint112(IERC20(token1).balanceOf(address(this)));

        emit Swap(msg.sender, tokenIn, tokenOut, actualAmountIn, amountOut);
    }

    function getPool(address tokenA, address tokenB)
        external
        view
        returns (
            address token0,
            address token1,
            uint112 reserve0,
            uint112 reserve1,
            uint256 totalSupply
        )
    {
        bytes32 poolId = _getPoolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        return (pool.token0, pool.token1, pool.reserve0, pool.reserve1, pool.totalSupply);
    }

    function getLiquidityBalance(address tokenA, address tokenB, address user)
        external
        view
        returns (uint256)
    {
        bytes32 poolId = _getPoolId(tokenA, tokenB);
        return liquidityBalance[poolId][user];
    }

    function _getPoolId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        if (tokenA == tokenB) revert InvalidTokenPair();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _calcDepositAmounts(
        Pool storage pool,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (pool.reserve0 == 0 && pool.reserve1 == 0) {
            return (amountADesired, amountBDesired);
        }
        uint256 amountBOptimal = _quote(amountADesired, pool.reserve0, pool.reserve1);
        if (amountBOptimal <= amountBDesired) {
            if (amountBOptimal < amountBMin) revert InsufficientOutputAmount();
            return (amountADesired, amountBOptimal);
        }
        uint256 amountAOptimal = _quote(amountBDesired, pool.reserve1, pool.reserve0);
        if (amountAOptimal < amountAMin) revert InsufficientOutputAmount();
        return (amountAOptimal, amountBDesired);
    }

    function _doTransferIn(
        address tokenA,
        address token0,
        address token1,
        uint256 amountA,
        uint256 amountB
    ) internal {
        if (tokenA == token0) {
            _safeTransferFrom(token0, msg.sender, address(this), amountA);
            _safeTransferFrom(token1, msg.sender, address(this), amountB);
        } else {
            _safeTransferFrom(token1, msg.sender, address(this), amountA);
            _safeTransferFrom(token0, msg.sender, address(this), amountB);
        }
    }

    function _mintPoolLiquidity(Pool storage pool, bytes32 poolId, address token0, address token1)
        internal
        returns (uint256 liquidity, uint256 amount0Added, uint256 amount1Added)
    {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        amount0Added = balance0 - pool.reserve0;
        amount1Added = balance1 - pool.reserve1;

        uint256 _totalSupply = pool.totalSupply;
        if (_totalSupply == 0) {
            liquidity = _sqrt(amount0Added * amount1Added);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            liquidity -= MINIMUM_LIQUIDITY;
            liquidityBalance[poolId][address(0)] = MINIMUM_LIQUIDITY;
            pool.totalSupply = MINIMUM_LIQUIDITY + liquidity;
        } else {
            liquidity = _min(
                (amount0Added * _totalSupply) / pool.reserve0,
                (amount1Added * _totalSupply) / pool.reserve1
            );
            pool.totalSupply = _totalSupply + liquidity;
        }
        pool.reserve0 = uint112(balance0);
        pool.reserve1 = uint112(balance1);
    }

    function _getAmountOut(uint256 amountIn, Pool storage pool, bool zeroForOne)
        internal
        view
        returns (uint256)
    {
        uint256 reserveIn = zeroForOne ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = zeroForOne ? pool.reserve1 : pool.reserve0;
        uint256 amountInWithFee = amountIn * (10000 - feeBps);
        return (amountInWithFee * reserveOut) / (reserveIn * 10000 + amountInWithFee);
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        internal
        pure
        returns (uint256 amountB)
    {
        if (amountA == 0) revert InvalidAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
        amountB = (amountA * reserveB) / reserveA;
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

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    receive() external payable {
        revert("ETH not accepted");
    }

    fallback() external payable {
        revert("ETH not accepted");
    }
}
