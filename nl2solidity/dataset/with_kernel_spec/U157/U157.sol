// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    error NotOwner();
    error ReentrantCall();
    error IdenticalAddresses();
    error ZeroAddress();
    error PoolExists();
    error PoolNotFound();
    error InvalidFee();
    error InvalidAmount();
    error InsufficientOutput();
    error InsufficientLiquidity();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ReserveOverflow();
    error TransferFailed();

    event PoolCreated(bytes32 indexed poolId, address indexed token0, address indexed token1);
    event GlobalFeeUpdated(uint256 oldFee, uint256 newFee);
    event PoolFeeUpdated(bytes32 indexed poolId, uint256 oldFee, uint256 newFee);
    event LiquidityAdded(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event LiquidityRemoved(
        bytes32 indexed poolId,
        address indexed provider,
        address indexed to,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event Swap(
        bytes32 indexed poolId,
        address indexed sender,
        address indexed to,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event LiquidityTransfer(bytes32 indexed poolId, address indexed from, address indexed to, uint256 amount);
    event LiquidityApproval(bytes32 indexed poolId, address indexed owner, address indexed spender, uint256 amount);

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant MAX_FEE = 1_000; // 10%
    address internal constant LOCK_ADDRESS = address(0xdead);

    address public owner;
    uint256 public globalFee; // basis points, 25 = 0.25%

    struct Pool {
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint256 totalLiquidity;
        uint256 swapFee; // additional per-pool fee in basis points
        bool active;
    }

    mapping(bytes32 => Pool) internal pools;
    mapping(bytes32 => mapping(address => uint256)) internal lpBalances;
    mapping(bytes32 => mapping(address => mapping(address => uint256))) internal lpAllowances;
    bytes32[] internal allPoolIds;

    uint256 private locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (locked != 1) revert ReentrantCall();
        locked = 2;
        _;
        locked = 1;
    }

    constructor() {
        owner = msg.sender;
        globalFee = 25; // 0.25%
    }

    function poolIdOf(address tokenA, address tokenB) external view returns (bytes32) {
        return _poolId(tokenA, tokenB);
    }

    function allPoolsLength() external view returns (uint256) {
        return allPoolIds.length;
    }

    function getPool(bytes32 poolId)
        external
        view
        returns (
            address token0,
            address token1,
            uint112 reserve0,
            uint112 reserve1,
            uint256 totalLiquidity,
            uint256 swapFee,
            bool active
        )
    {
        Pool storage p = pools[poolId];
        return (p.token0, p.token1, p.reserve0, p.reserve1, p.totalLiquidity, p.swapFee, p.active);
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint112 reserve0, uint112 reserve1) {
        bytes32 poolId = _poolId(tokenA, tokenB);
        Pool storage p = pools[poolId];
        return (p.reserve0, p.reserve1);
    }

    function lpBalanceOf(bytes32 poolId, address account) external view returns (uint256) {
        return lpBalances[poolId][account];
    }

    function lpAllowanceOf(bytes32 poolId, address ownerAddr, address spender) external view returns (uint256) {
        return lpAllowances[poolId][ownerAddr][spender];
    }

    function createPair(address tokenA, address tokenB) external onlyOwner returns (bytes32 poolId) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        poolId = keccak256(abi.encodePacked(token0, token1));
        if (pools[poolId].active) revert PoolExists();
        pools[poolId] = Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            totalLiquidity: 0,
            swapFee: 0,
            active: true
        });
        allPoolIds.push(poolId);
        emit PoolCreated(poolId, token0, token1);
    }

    function setGlobalFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert InvalidFee();
        emit GlobalFeeUpdated(globalFee, newFee);
        globalFee = newFee;
    }

    function setPoolFee(address tokenA, address tokenB, uint256 newFee) external onlyOwner {
        bytes32 poolId = _poolId(tokenA, tokenB);
        Pool storage p = pools[poolId];
        if (!p.active) revert PoolNotFound();
        if (newFee > MAX_FEE) revert InvalidFee();
        emit PoolFeeUpdated(poolId, p.swapFee, newFee);
        p.swapFee = newFee;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        bytes32 poolId = _poolId(tokenA, tokenB);
        Pool storage p = pools[poolId];
        if (!p.active) revert PoolNotFound();
        if (to == address(0)) revert ZeroAddress();
        if (amountADesired == 0 || amountBDesired == 0) revert InvalidAmount();

        bool aIs0 = tokenA == p.token0;
        uint256 amount0Desired = aIs0 ? amountADesired : amountBDesired;
        uint256 amount1Desired = aIs0 ? amountBDesired : amountADesired;
        uint256 amount0Min = aIs0 ? amountAMin : amountBMin;
        uint256 amount1Min = aIs0 ? amountBMin : amountAMin;

        uint256 amount0;
        uint256 amount1;

        if (p.totalLiquidity == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            liquidity = _sqrt(amount0 * amount1);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            lpBalances[poolId][LOCK_ADDRESS] = MINIMUM_LIQUIDITY;
            p.totalLiquidity = MINIMUM_LIQUIDITY;
            liquidity -= MINIMUM_LIQUIDITY;
        } else {
            uint256 liq0 = (amount0Desired * p.totalLiquidity) / p.reserve0;
            uint256 liq1 = (amount1Desired * p.totalLiquidity) / p.reserve1;
            liquidity = liq0 < liq1 ? liq0 : liq1;
            if (liquidity == 0) revert InsufficientLiquidity();
            amount0 = (liquidity * p.reserve0) / p.totalLiquidity;
            amount1 = (liquidity * p.reserve1) / p.totalLiquidity;
        }

        if (amount0 < amount0Min || amount1 < amount1Min) revert InsufficientOutput();

        _safeTransferFrom(p.token0, msg.sender, address(this), amount0);
        _safeTransferFrom(p.token1, msg.sender, address(this), amount1);

        uint256 newReserve0 = uint256(p.reserve0) + amount0;
        uint256 newReserve1 = uint256(p.reserve1) + amount1;
        if (newReserve0 > type(uint112).max || newReserve1 > type(uint112).max) revert ReserveOverflow();
        p.reserve0 = uint112(newReserve0);
        p.reserve1 = uint112(newReserve1);
        p.totalLiquidity += liquidity;
        lpBalances[poolId][to] += liquidity;

        (amountA, amountB) = aIs0 ? (amount0, amount1) : (amount1, amount0);

        emit LiquidityAdded(poolId, msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        bytes32 poolId = _poolId(tokenA, tokenB);
        Pool storage p = pools[poolId];
        if (!p.active) revert PoolNotFound();
        if (to == address(0)) revert ZeroAddress();
        if (liquidity == 0) revert InvalidAmount();
        if (lpBalances[poolId][msg.sender] < liquidity) revert InsufficientBalance();

        uint256 amount0 = (liquidity * p.reserve0) / p.totalLiquidity;
        uint256 amount1 = (liquidity * p.reserve1) / p.totalLiquidity;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        uint256 amount0Min = (tokenA == p.token0) ? amountAMin : amountBMin;
        uint256 amount1Min = (tokenA == p.token0) ? amountBMin : amountAMin;
        if (amount0 < amount0Min || amount1 < amount1Min) revert InsufficientOutput();

        lpBalances[poolId][msg.sender] -= liquidity;
        p.totalLiquidity -= liquidity;
        p.reserve0 = uint112(uint256(p.reserve0) - amount0);
        p.reserve1 = uint112(uint256(p.reserve1) - amount1);

        _safeTransfer(p.token0, to, amount0);
        _safeTransfer(p.token1, to, amount1);

        (amountA, amountB) = (tokenA == p.token0) ? (amount0, amount1) : (amount1, amount0);

        emit LiquidityRemoved(poolId, msg.sender, to, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();
        if (tokenIn == tokenOut) revert IdenticalAddresses();
        if (to == address(0)) revert ZeroAddress();

        bytes32 poolId = _poolId(tokenIn, tokenOut);
        Pool storage p = pools[poolId];
        if (!p.active) revert PoolNotFound();

        bool zeroForOne = tokenIn == p.token0;
        uint256 reserveIn = zeroForOne ? uint256(p.reserve0) : uint256(p.reserve1);
        uint256 reserveOut = zeroForOne ? uint256(p.reserve1) : uint256(p.reserve0);

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        if (reserveIn + amountIn > type(uint112).max) revert ReserveOverflow();

        uint256 totalFee = globalFee + p.swapFee;
        if (totalFee >= FEE_DENOMINATOR) revert InvalidFee();

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - totalFee);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        if (amountOut < minAmountOut) revert InsufficientOutput();
        if (amountOut > reserveOut) revert InsufficientLiquidity();

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

        if (zeroForOne) {
            p.reserve0 = uint112(reserveIn + amountIn);
            p.reserve1 = uint112(reserveOut - amountOut);
        } else {
            p.reserve1 = uint112(reserveIn + amountIn);
            p.reserve0 = uint112(reserveOut - amountOut);
        }

        _safeTransfer(tokenOut, to, amountOut);

        emit Swap(poolId, msg.sender, to, tokenIn, tokenOut, amountIn, amountOut);
    }

    function transferLiquidity(bytes32 poolId, address to, uint256 amount) external returns (bool) {
        if (!pools[poolId].active) revert PoolNotFound();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        uint256 bal = lpBalances[poolId][msg.sender];
        if (bal < amount) revert InsufficientBalance();
        unchecked {
            lpBalances[poolId][msg.sender] = bal - amount;
        }
        lpBalances[poolId][to] += amount;
        emit LiquidityTransfer(poolId, msg.sender, to, amount);
        return true;
    }

    function approveLiquidity(bytes32 poolId, address spender, uint256 amount) external returns (bool) {
        if (!pools[poolId].active) revert PoolNotFound();
        if (spender == address(0)) revert ZeroAddress();
        lpAllowances[poolId][msg.sender][spender] = amount;
        emit LiquidityApproval(poolId, msg.sender, spender, amount);
        return true;
    }

    function transferLiquidityFrom(bytes32 poolId, address from, address to, uint256 amount) external returns (bool) {
        if (!pools[poolId].active) revert PoolNotFound();
        if (to == address(0) || from == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        uint256 currentAllowance = lpAllowances[poolId][from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        uint256 bal = lpBalances[poolId][from];
        if (bal < amount) revert InsufficientBalance();
        unchecked {
            lpBalances[poolId][from] = bal - amount;
            lpAllowances[poolId][from][msg.sender] = currentAllowance - amount;
        }
        lpBalances[poolId][to] += amount;
        emit LiquidityTransfer(poolId, from, to, amount);
        return true;
    }

    function _poolId(address tokenA, address tokenB) internal pure returns (bytes32) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
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
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
