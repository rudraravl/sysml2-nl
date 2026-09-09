// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract StableSwap {
    error NotAdmin();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error ZeroAddress();
    error IdenticalTokens();
    error ZeroAmount();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error InsufficientBalance();
    error InvalidFee();
    error NotPoolToken();
    error TransferFailed();

    event PoolAdded(address indexed tokenA, address indexed tokenB, address indexed poolId);
    event FeeUpdated(address indexed poolId, uint256 oldFee, uint256 newFee);
    event Deposit(
        address indexed user,
        address indexed poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 sharesMinted
    );
    event Withdraw(
        address indexed user,
        address indexed poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 sharesBurned
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    uint256 public constant DEFAULT_SWAP_FEE_BPS = 5; // 0.05%
    uint256 public constant MAX_SLIPPAGE_BPS = 100; // 1%
    uint256 public constant MAX_FEE_BPS = 100; // 1%
    uint256 private constant BPS_DENOMINATOR = 10000;

    address public admin;

    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalShares;
        uint32 swapFeeBps;
        bool exists;
    }

    mapping(address => Pool) public pools; // poolId => Pool
    mapping(address => mapping(address => uint256)) public userShares; // poolId => user => shares
    mapping(address => bool) public supportedTokens;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        admin = newAdmin;
    }

    function addPool(address tokenA, address tokenB) external onlyAdmin returns (address poolId) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();

        poolId = _computePoolId(tokenA, tokenB);
        if (pools[poolId].exists) revert PoolAlreadyExists();

        pools[poolId] = Pool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalShares: 0,
            swapFeeBps: uint32(DEFAULT_SWAP_FEE_BPS),
            exists: true
        });

        supportedTokens[tokenA] = true;
        supportedTokens[tokenB] = true;

        emit PoolAdded(tokenA, tokenB, poolId);
    }

    function setSwapFee(address poolId, uint32 newFeeBps) external onlyAdmin {
        Pool storage pool = pools[poolId];
        if (!pool.exists) revert PoolDoesNotExist();
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 oldFee = pool.swapFeeBps;
        pool.swapFeeBps = newFeeBps;
        emit FeeUpdated(poolId, oldFee, newFeeBps);
    }

    function deposit(
        address poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 minSharesOut
    ) external returns (uint256 sharesMinted) {
        Pool storage pool = pools[poolId];
        if (!pool.exists) revert PoolDoesNotExist();
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        uint256 _reserveA = pool.reserveA;
        uint256 _reserveB = pool.reserveB;
        uint256 _totalShares = pool.totalShares;

        if (_totalShares == 0) {
            sharesMinted = _sqrt(amountA * amountB);
            if (sharesMinted == 0) revert ZeroAmount();
        } else {
            uint256 sharesA = (amountA * _totalShares) / _reserveA;
            uint256 sharesB = (amountB * _totalShares) / _reserveB;
            sharesMinted = sharesA < sharesB ? sharesA : sharesB;
        }

        if (sharesMinted < minSharesOut) revert SlippageExceeded();

        pool.reserveA = _reserveA + amountA;
        pool.reserveB = _reserveB + amountB;
        pool.totalShares = _totalShares + sharesMinted;
        userShares[poolId][msg.sender] += sharesMinted;

        _safeTransferFrom(pool.tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(pool.tokenB, msg.sender, address(this), amountB);

        emit Deposit(msg.sender, poolId, amountA, amountB, sharesMinted);
    }

    function withdraw(
        address poolId,
        uint256 sharesToBurn,
        uint256 minAmountA,
        uint256 minAmountB
    ) external returns (uint256 amountA, uint256 amountB) {
        Pool storage pool = pools[poolId];
        if (!pool.exists) revert PoolDoesNotExist();
        if (sharesToBurn == 0) revert ZeroAmount();

        uint256 userBal = userShares[poolId][msg.sender];
        if (sharesToBurn > userBal) revert InsufficientBalance();

        uint256 _reserveA = pool.reserveA;
        uint256 _reserveB = pool.reserveB;
        uint256 _totalShares = pool.totalShares;

        amountA = (sharesToBurn * _reserveA) / _totalShares;
        amountB = (sharesToBurn * _reserveB) / _totalShares;

        if (amountA < minAmountA || amountB < minAmountB) revert SlippageExceeded();

        userShares[poolId][msg.sender] = userBal - sharesToBurn;
        pool.totalShares = _totalShares - sharesToBurn;
        pool.reserveA = _reserveA - amountA;
        pool.reserveB = _reserveB - amountB;

        _safeTransfer(pool.tokenA, msg.sender, amountA);
        _safeTransfer(pool.tokenB, msg.sender, amountB);

        emit Withdraw(msg.sender, poolId, amountA, amountB, sharesToBurn);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (!supportedTokens[tokenIn] || !supportedTokens[tokenOut]) revert NotPoolToken();

        address poolId = _computePoolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];
        if (!pool.exists) revert PoolDoesNotExist();

        (uint256 reserveIn, uint256 reserveOut) = _getOrderedReserves(pool, tokenIn, tokenOut);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 feeBps = pool.swapFeeBps;
        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - feeBps);
        amountOut = (amountInWithFee * reserveOut) / ((reserveIn * BPS_DENOMINATOR) + amountInWithFee);

        if (amountOut == 0) revert InsufficientLiquidity();

        // Compute the minimum allowed output (1% slippage floor) without
        // an intermediate division to avoid divide-before-multiply precision loss.
        // minAllowed = amountIn * reserveOut * (BPS_DENOMINATOR - MAX_SLIPPAGE_BPS)
        //              / (reserveIn * BPS_DENOMINATOR)
        uint256 minAllowed = (amountIn * reserveOut * (BPS_DENOMINATOR - MAX_SLIPPAGE_BPS)) /
            (reserveIn * BPS_DENOMINATOR);

        if (amountOut < minAllowed) revert SlippageExceeded();
        if (amountOut < minAmountOut) revert SlippageExceeded();

        if (tokenIn == pool.tokenA) {
            pool.reserveA = reserveIn + amountIn;
            pool.reserveB = reserveOut - amountOut;
        } else {
            pool.reserveB = reserveIn + amountIn;
            pool.reserveA = reserveOut - amountOut;
        }

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        uint256 feeAmount = (amountIn * feeBps) / BPS_DENOMINATOR;
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeAmount);
    }

    function getPool(address tokenA, address tokenB) external view returns (Pool memory) {
        address poolId = _computePoolId(tokenA, tokenB);
        return pools[poolId];
    }

    function getPoolId(address tokenA, address tokenB) external pure returns (address) {
        return _computePoolId(tokenA, tokenB);
    }

    function getUserShares(address poolId, address user) external view returns (uint256) {
        return userShares[poolId][user];
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        address poolId = _computePoolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];
        if (!pool.exists) revert PoolDoesNotExist();

        (uint256 reserveIn, uint256 reserveOut) = _getOrderedReserves(pool, tokenIn, tokenOut);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - pool.swapFeeBps);
        return (amountInWithFee * reserveOut) / ((reserveIn * BPS_DENOMINATOR) + amountInWithFee);
    }

    function _computePoolId(address tokenA, address tokenB) internal pure returns (address) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return address(uint160(uint256(keccak256(abi.encodePacked(token0, token1)))));
    }

    function _getOrderedReserves(Pool storage pool, address tokenIn, address tokenOut)
        internal
        view
        returns (uint256 reserveIn, uint256 reserveOut)
    {
        if (tokenIn == pool.tokenA && tokenOut == pool.tokenB) {
            return (pool.reserveA, pool.reserveB);
        } else if (tokenIn == pool.tokenB && tokenOut == pool.tokenA) {
            return (pool.reserveB, pool.reserveA);
        } else {
            revert NotPoolToken();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool success = IERC20(token).transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool success = IERC20(token).transfer(to, amount);
        if (!success) revert TransferFailed();
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
}
