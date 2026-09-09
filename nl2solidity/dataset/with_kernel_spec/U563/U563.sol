// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        bool active;
    }

    error ErrZeroAddress();
    error ErrIdenticalTokens();
    error ErrPoolExists();
    error ErrPoolNotFound();
    error ErrPoolInactive();
    error ErrInsufficientInitialLiquidity();
    error ErrInsufficientLiquidity();
    error ErrInsufficientAmount();
    error ErrInsufficientOutput();
    error ErrInsufficientUserLiquidity();
    error ErrFeeTooHigh();
    error ErrPaused();
    error ErrNotOwner();
    error ErrZeroAmount();
    error ErrZeroLiquidity();
    error ErrTransferFailed();
    error ErrSlippageExceeded();
    error ErrReentrant();

    event PoolCreated(bytes32 indexed poolId, address indexed token0, address indexed token1);
    event LiquidityAdded(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    event Swap(
        bytes32 indexed poolId,
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeTaken
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event PausedStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MAX_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_INITIAL_LIQUIDITY = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;

    address public owner;
    address public feeRecipient;
    uint256 public feeBps;
    bool public paused;

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => uint256)) public userLiquidity;

    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ErrReentrant();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier poolIsActive(bytes32 poolId) {
        if (!pools[poolId].active) revert ErrPoolNotFound();
        _;
    }

    constructor(address _feeRecipient, uint256 _feeBps) {
        if (_feeRecipient == address(0)) revert ErrZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert ErrFeeTooHigh();
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address, address) {
        if (tokenA == address(0) || tokenB == address(0)) revert ErrZeroAddress();
        if (tokenA == tokenB) revert ErrIdenticalTokens();
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _poolId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        return keccak256(abi.encodePacked(t0, t1));
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

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _safeTransfer(address token, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function getPool(address tokenA, address tokenB) external view returns (Pool memory) {
        return pools[_poolId(tokenA, tokenB)];
    }

    function getUserLiquidity(address tokenA, address tokenB, address user) external view returns (uint256) {
        return userLiquidity[_poolId(tokenA, tokenB)][user];
    }

    function addTokenPair(address tokenA, address tokenB) external onlyOwner {
        bytes32 poolId = _poolId(tokenA, tokenB);
        if (pools[poolId].active) revert ErrPoolExists();
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        pools[poolId] = Pool({
            token0: t0,
            token1: t1,
            reserve0: 0,
            reserve1: 0,
            totalLiquidity: 0,
            active: true
        });
        emit PoolCreated(poolId, t0, t1);
    }

    function _mintLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalLiquidity
    ) internal pure returns (uint256) {
        if (totalLiquidity == 0) {
            return _sqrt(amount0 * amount1);
        }
        uint256 liquidity0 = (amount0 * totalLiquidity) / reserve0;
        uint256 liquidity1 = (amount1 * totalLiquidity) / reserve1;
        return liquidity0 < liquidity1 ? liquidity0 : liquidity1;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 amountAMin,
        uint256 amountBMin
    ) external whenNotPaused nonReentrant poolIsActive(_poolId(tokenA, tokenB)) returns (uint256 liquidity) {
        if (amountA == 0 || amountB == 0) revert ErrZeroAmount();

        bytes32 poolId = _poolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];

        uint256 amount0;
        uint256 amount1;

        if (pool.totalLiquidity == 0) {
            if (amountA < MIN_INITIAL_LIQUIDITY || amountB < MIN_INITIAL_LIQUIDITY) {
                revert ErrInsufficientInitialLiquidity();
            }
            amount0 = amountA;
            amount1 = amountB;
        } else {
            uint256 amount1Optimal = (amountA * pool.reserve1) / pool.reserve0;
            if (amount1Optimal <= amountB) {
                if (amount1Optimal < amountBMin) revert ErrSlippageExceeded();
                amount0 = amountA;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amountB * pool.reserve0) / pool.reserve1;
                if (amount0Optimal > amountA) revert ErrSlippageExceeded();
                if (amount0Optimal < amountAMin) revert ErrSlippageExceeded();
                amount0 = amount0Optimal;
                amount1 = amountB;
            }
        }

        liquidity = _mintLiquidity(amount0, amount1, pool.reserve0, pool.reserve1, pool.totalLiquidity);
        if (liquidity == 0) revert ErrZeroLiquidity();

        // Effects: update state before interactions
        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += liquidity;
        userLiquidity[poolId][msg.sender] += liquidity;

        // Interactions
        if (!_safeTransferFrom(pool.token0, msg.sender, address(this), amount0)) revert ErrTransferFailed();
        if (!_safeTransferFrom(pool.token1, msg.sender, address(this), amount1)) revert ErrTransferFailed();

        emit LiquidityAdded(poolId, msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external whenNotPaused nonReentrant poolIsActive(_poolId(tokenA, tokenB)) returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert ErrZeroAmount();

        bytes32 poolId = _poolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];

        uint256 userLiq = userLiquidity[poolId][msg.sender];
        if (liquidity > userLiq) revert ErrInsufficientUserLiquidity();
        if (pool.totalLiquidity == 0) revert ErrInsufficientLiquidity();

        uint256 amount0 = (liquidity * pool.reserve0) / pool.totalLiquidity;
        uint256 amount1 = (liquidity * pool.reserve1) / pool.totalLiquidity;
        if (amount0 == 0 || amount1 == 0) revert ErrInsufficientAmount();

        if (tokenA == pool.token0) {
            amountA = amount0;
            amountB = amount1;
        } else {
            amountA = amount1;
            amountB = amount0;
        }

        if (amountA < amountAMin || amountB < amountBMin) revert ErrSlippageExceeded();

        // Effects
        userLiquidity[poolId][msg.sender] -= liquidity;
        pool.totalLiquidity -= liquidity;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;

        // Interactions
        if (!_safeTransfer(pool.token0, msg.sender, amount0)) revert ErrTransferFailed();
        if (!_safeTransfer(pool.token1, msg.sender, amount1)) revert ErrTransferFailed();

        emit LiquidityRemoved(poolId, msg.sender, amount0, amount1, liquidity);
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountOut, uint256 feeTaken) {
        if (amountIn == 0) revert ErrZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert ErrInsufficientLiquidity();
        feeTaken = (amountIn * feeBps) / BPS_DENOMINATOR;
        uint256 amountInWithFee = amountIn - feeTaken;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external whenNotPaused nonReentrant poolIsActive(_poolId(tokenIn, tokenOut)) returns (uint256 amountOut) {
        if (amountIn == 0) revert ErrZeroAmount();

        bytes32 poolId = _poolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];

        bool isToken0In = tokenIn == pool.token0;
        (uint256 reserveIn, uint256 reserveOut) = isToken0In
            ? (pool.reserve0, pool.reserve1)
            : (pool.reserve1, pool.reserve0);

        uint256 feeTaken;
        (amountOut, feeTaken) = _getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < amountOutMin) revert ErrInsufficientOutput();
        if (amountOut >= reserveOut) revert ErrInsufficientLiquidity();

        uint256 amountInWithFee = amountIn - feeTaken;

        // Effects: update state before interactions
        if (isToken0In) {
            pool.reserve0 += amountInWithFee;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountInWithFee;
            pool.reserve0 -= amountOut;
        }

        // Interactions
        if (!_safeTransferFrom(tokenIn, msg.sender, address(this), amountIn)) revert ErrTransferFailed();
        if (!_safeTransfer(tokenOut, msg.sender, amountOut)) revert ErrTransferFailed();

        if (feeTaken > 0) {
            if (!_safeTransfer(tokenIn, feeRecipient, feeTaken)) revert ErrTransferFailed();
        }

        emit Swap(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeTaken);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert ErrFeeTooHigh();
        uint256 oldFee = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(oldFee, newFeeBps);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ErrZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}
