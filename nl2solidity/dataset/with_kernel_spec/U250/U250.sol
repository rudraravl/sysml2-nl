// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        uint256 accumulatedFees0;
        uint256 accumulatedFees1;
        bool exists;
    }

    address public operator;
    uint256 public protocolFeeBps;
    bool public paused;

    mapping(address => mapping(address => Pool)) public pools;
    mapping(address => mapping(address => mapping(address => uint256))) public userLiquidity;

    uint256 private _locked = 1;

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 initialLiquidity
    );
    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    );
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error InsufficientInitialLiquidity();
    error InsufficientLiquidity();
    error InsufficientAmount();
    error SlippageExceeded();
    error SwapPaused();
    error InvalidTokens();
    error ZeroAddress();
    error InvalidFee();
    error ReentrancyDetected();
    error TransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert SwapPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        operator = msg.sender;
        protocolFeeBps = 30; // 0.3%
    }

    function setProtocolFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > 10000) revert InvalidFee();
        emit ProtocolFeeUpdated(protocolFeeBps, _feeBps);
        protocolFeeBps = _feeBps;
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert InvalidTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
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

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function createPool(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        nonReentrant
        returns (uint256 initialLiquidity)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        (uint256 amount0, uint256 amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);

        if (pools[token0][token1].exists) revert PoolAlreadyExists();
        if (amount0 < 100 || amount1 < 100) revert InsufficientInitialLiquidity();

        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        initialLiquidity = _sqrt(amount0 * amount1);
        if (initialLiquidity == 0) revert InsufficientLiquidity();

        pools[token0][token1] = Pool({
            token0: token0,
            token1: token1,
            reserve0: amount0,
            reserve1: amount1,
            totalLiquidity: initialLiquidity,
            accumulatedFees0: 0,
            accumulatedFees1: 0,
            exists: true
        });

        userLiquidity[msg.sender][token0][token1] = initialLiquidity;

        emit PoolCreated(token0, token1, amount0, amount1, initialLiquidity);
        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, initialLiquidity);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();

        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        if (tokenA == token0) {
            (amount0Desired, amount1Desired, amount0Min, amount1Min) =
                (amountADesired, amountBDesired, amountAMin, amountBMin);
        } else {
            (amount0Desired, amount1Desired, amount0Min, amount1Min) =
                (amountBDesired, amountADesired, amountBMin, amountAMin);
        }

        uint256 amount0;
        uint256 amount1;
        {
            uint256 amount1Optimal = (amount0Desired * pool.reserve1) / pool.reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert SlippageExceeded();
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = (amount1Desired * pool.reserve0) / pool.reserve1;
                if (amount0Optimal > amount0Desired) revert SlippageExceeded();
                if (amount0Optimal < amount0Min) revert SlippageExceeded();
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }

        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        liquidity = (amount0 * pool.totalLiquidity) / pool.reserve0;
        if (liquidity == 0) revert InsufficientLiquidity();

        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += liquidity;
        userLiquidity[msg.sender][token0][token1] += liquidity;

        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert InsufficientAmount();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();

        if (userLiquidity[msg.sender][token0][token1] < liquidity) revert InsufficientLiquidity();

        uint256 amount0 = (liquidity * pool.reserve0) / pool.totalLiquidity;
        uint256 amount1 = (liquidity * pool.reserve1) / pool.totalLiquidity;

        if (tokenA == token0) {
            if (amount0 < amountAMin || amount1 < amountBMin) revert SlippageExceeded();
        } else {
            if (amount1 < amountAMin || amount0 < amountBMin) revert SlippageExceeded();
        }

        userLiquidity[msg.sender][token0][token1] -= liquidity;
        pool.totalLiquidity -= liquidity;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        Pool storage pool = pools[token0][token1];
        if (!pool.exists) revert PoolDoesNotExist();

        uint256 reserveIn;
        uint256 reserveOut;
        bool isToken0In = tokenIn == token0;
        if (isToken0In) {
            (reserveIn, reserveOut) = (pool.reserve0, pool.reserve1);
        } else {
            (reserveIn, reserveOut) = (pool.reserve1, pool.reserve0);
        }

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 feeAmount = (amountIn * protocolFeeBps) / 10000;
        uint256 amountInAfterFee = amountIn - feeAmount;

        amountOut = (reserveOut * amountInAfterFee) / (reserveIn + amountInAfterFee);
        if (amountOut == 0) revert InsufficientAmount();
        if (amountOut < amountOutMin) revert SlippageExceeded();

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        if (isToken0In) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
            pool.accumulatedFees0 += feeAmount;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
            pool.accumulatedFees1 += feeAmount;
        }

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeAmount);
    }

    function getPool(address tokenA, address tokenB)
        external
        view
        returns (
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalLiquidity,
            uint256 accumulatedFees0,
            uint256 accumulatedFees1
        )
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        return (
            pool.reserve0,
            pool.reserve1,
            pool.totalLiquidity,
            pool.accumulatedFees0,
            pool.accumulatedFees1
        );
    }

    function getPoolTokens(address tokenA, address tokenB)
        external
        view
        returns (address token0, address token1)
    {
        (token0, token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        return (pool.token0, pool.token1);
    }

    function getUserLiquidity(address user, address tokenA, address tokenB) external view returns (uint256) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return userLiquidity[user][token0][token1];
    }
}
