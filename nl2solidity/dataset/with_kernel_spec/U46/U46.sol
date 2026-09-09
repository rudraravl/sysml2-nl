// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedSwap {
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant FEE_DENOMINATOR = 10000;

    address public owner;
    uint256 public fee; // in basis points, default 30 = 0.3%
    bool public paused;

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => uint256)) public lpBalances;

    uint256 private unlocked = 1;

    error Locked();
    error NotOwner();
    error Paused();
    error IdenticalAddresses();
    error ZeroAddress();
    error InsufficientAmount();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error PoolNotInitialized();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error TransferFailed();
    error FeeTooHigh();
    error RatioMismatch();

    modifier lock() {
        if (unlocked != 1) revert Locked();
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

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
    event PausedStateChanged(bool paused);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor() {
        owner = msg.sender;
        fee = 30; // 0.3%
    }

    function setFee(uint256 _fee) external onlyOwner {
        if (_fee > 1000) revert FeeTooHigh(); // max 10%
        uint256 oldFee = fee;
        fee = _fee;
        emit FeeUpdated(oldFee, _fee);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function pairId(address tokenA, address tokenB) public pure returns (bytes32) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }

    function getPool(address tokenA, address tokenB) external view returns (
        address token0,
        address token1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    ) {
        bytes32 id = pairId(tokenA, tokenB);
        Pool storage p = pools[id];
        return (p.token0, p.token1, p.reserve0, p.reserve1, p.totalSupply);
    }

    function balanceOf(address tokenA, address tokenB, address account) external view returns (uint256) {
        return lpBalances[pairId(tokenA, tokenB)][account];
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external lock returns (uint256 liquidity) {
        if (amountA == 0 || amountB == 0) revert InsufficientAmount();

        bytes32 id = pairId(tokenA, tokenB);
        Pool storage p = pools[id];

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (uint256 amount0, uint256 amount1) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);

        if (p.totalSupply == 0) {
            p.token0 = token0;
            p.token1 = token1;
            liquidity = _sqrt(amount0 * amount1);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
            // Effects: update reserves and mint LP tokens before interactions
            p.reserve0 += amount0;
            p.reserve1 += amount1;
            _mint(id, address(0), MINIMUM_LIQUIDITY);
            _mint(id, msg.sender, liquidity - MINIMUM_LIQUIDITY);
        } else {
            if (p.token0 != token0 || p.token1 != token1) revert PoolNotInitialized();
            if (amount0 * p.reserve1 != amount1 * p.reserve0) revert RatioMismatch();
            liquidity = (amount0 * p.totalSupply) / p.reserve0;
            if (liquidity == 0) revert InsufficientLiquidityMinted();
            // Effects: update reserves and mint LP tokens before interactions
            p.reserve0 += amount0;
            p.reserve1 += amount1;
            _mint(id, msg.sender, liquidity);
        }

        // Interactions: pull tokens from caller
        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external lock returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) revert InsufficientLiquidityBurned();

        bytes32 id = pairId(tokenA, tokenB);
        Pool storage p = pools[id];
        if (p.totalSupply == 0) revert PoolNotInitialized();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        uint256 balance = lpBalances[id][msg.sender];
        if (balance < liquidity) revert InsufficientLiquidityBurned();

        amount0 = (liquidity * p.reserve0) / p.totalSupply;
        amount1 = (liquidity * p.reserve1) / p.totalSupply;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();

        // Effects: burn LP tokens and update reserves before interactions
        _burn(id, msg.sender, liquidity);
        p.reserve0 -= amount0;
        p.reserve1 -= amount1;

        // Interactions: send tokens to caller
        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external lock whenNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();

        bytes32 id = pairId(tokenIn, tokenOut);
        Pool storage p = pools[id];
        if (p.totalSupply == 0) revert PoolNotInitialized();

        (uint256 reserveIn, uint256 reserveOut) =
            tokenIn == p.token0 ? (p.reserve0, p.reserve1) : (p.reserve1, p.reserve0);

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;

        if (amountOut < minAmountOut) revert InsufficientOutputAmount();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        // Effects: update reserves before interactions
        if (tokenIn == p.token0) {
            p.reserve0 += amountIn;
            p.reserve1 -= amountOut;
        } else {
            p.reserve1 += amountIn;
            p.reserve0 -= amountOut;
        }

        // Interactions: pull input and push output
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function _mint(bytes32 id, address to, uint256 amount) internal {
        pools[id].totalSupply += amount;
        lpBalances[id][to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(bytes32 id, address from, uint256 amount) internal {
        lpBalances[id][from] -= amount;
        pools[id].totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
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
