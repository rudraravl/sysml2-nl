// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ConcentratedLiquidityExchange {
    uint256 public constant FEE_DENOMINATOR = 1_000_000;
    uint256 public constant MIN_INITIAL_LIQUIDITY = 100;
    uint24 public constant MAX_PROTOCOL_FEE = 5000;
    uint24 public constant DEFAULT_PROTOCOL_FEE = 500;

    address public owner;
    uint24 public protocolFee = DEFAULT_PROTOCOL_FEE;
    uint256 private _locked = 1;

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint256 protocolFee0;
        uint256 protocolFee1;
        bool initialized;
    }

    struct Position {
        uint256 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 priceLower;
        uint256 priceUpper;
    }

    struct PositionView {
        uint256 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 priceLower;
        uint256 priceUpper;
    }

    struct PoolView {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(address => mapping(address => bool)) public allowedPairs;
    mapping(bytes32 => mapping(address => Position)) public positions;

    event PoolCreated(address indexed token0, address indexed token1, uint256 reserve0, uint256 reserve1);
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
        address indexed caller,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event ProtocolFeeUpdated(uint24 oldFee, uint24 newFee);
    event PairAllowedUpdated(address indexed token0, address indexed token1, bool allowed);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProtocolFeesCollected(address indexed token0, address indexed token1, address indexed recipient, uint256 amount0, uint256 amount1);

    error NotOwner();
    error ZeroAddress();
    error IdenticalTokens();
    error PairNotAllowed();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error InsufficientInitialLiquidity();
    error InsufficientLiquidity();
    error InsufficientInput();
    error InsufficientOutput();
    error InvalidRange();
    error FeeTooHigh();
    error TransferFailed();
    error Reentrancy();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 priceLower,
        uint256 priceUpper
    ) external nonReentrant returns (bytes32 poolId) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();
        if (priceLower >= priceUpper) revert InvalidRange();

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        poolId = _getPoolId(token0, token1);
        Pool storage pool = pools[poolId];

        if (pool.initialized) revert PoolAlreadyExists();
        if (!allowedPairs[token0][token1]) revert PairNotAllowed();

        if (amount0Desired == 0 || amount1Desired == 0) revert InsufficientInput();
        if (amount0Desired < MIN_INITIAL_LIQUIDITY && amount1Desired < MIN_INITIAL_LIQUIDITY)
            revert InsufficientInitialLiquidity();

        uint256 liquidity = _sqrt(amount0Desired * amount1Desired);

        // Effects: write pool state before interactions
        pool.token0 = token0;
        pool.token1 = token1;
        pool.reserve0 = amount0Desired;
        pool.reserve1 = amount1Desired;
        pool.totalSupply = liquidity;
        pool.initialized = true;

        Position storage pos = positions[poolId][msg.sender];
        pos.liquidity = liquidity;
        pos.amount0 = amount0Desired;
        pos.amount1 = amount1Desired;
        pos.priceLower = priceLower;
        pos.priceUpper = priceUpper;

        // Interactions
        _safeTransferFrom(token0, msg.sender, address(this), amount0Desired);
        _safeTransferFrom(token1, msg.sender, address(this), amount1Desired);

        emit PoolCreated(token0, token1, amount0Desired, amount1Desired);
        emit LiquidityAdded(msg.sender, token0, token1, amount0Desired, amount1Desired, liquidity);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 priceLower,
        uint256 priceUpper
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();
        if (priceLower >= priceUpper) revert InvalidRange();
        if (amount0Desired == 0 || amount1Desired == 0) revert InsufficientInput();

        bytes32 poolId = _getPoolIdSorted(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        if (!pool.initialized) revert PoolDoesNotExist();
        if (pool.totalSupply == 0) revert InsufficientLiquidity();

        // Compute optimal amounts using single multiply-then-divide (no chained divide-before-multiply)
        uint256 amount1Optimal = (amount0Desired * pool.reserve1) / pool.reserve0;
        if (amount1Optimal <= amount1Desired) {
            amount0 = amount0Desired;
            amount1 = amount1Optimal;
        } else {
            amount0 = (amount1Desired * pool.reserve0) / pool.reserve1;
            amount1 = amount1Desired;
            if (amount0 > amount0Desired) revert InsufficientOutput();
        }

        // Liquidity derived from final amounts (multiply-then-divide, no chained division)
        liquidity = (amount0 * pool.totalSupply) / pool.reserve0;
        if (liquidity == 0) revert InsufficientLiquidity();

        // Effects: update state before interactions
        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalSupply += liquidity;

        Position storage pos = positions[poolId][msg.sender];
        pos.liquidity += liquidity;
        pos.amount0 += amount0;
        pos.amount1 += amount1;
        pos.priceLower = priceLower;
        pos.priceUpper = priceUpper;

        // Interactions
        _safeTransferFrom(pool.token0, msg.sender, address(this), amount0);
        _safeTransferFrom(pool.token1, msg.sender, address(this), amount1);

        emit LiquidityAdded(msg.sender, pool.token0, pool.token1, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        bytes32 poolId = _getPoolIdSorted(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        if (!pool.initialized) revert PoolDoesNotExist();

        Position storage pos = positions[poolId][msg.sender];
        if (liquidity == 0 || liquidity > pos.liquidity) revert InsufficientLiquidity();

        amount0 = (liquidity * pool.reserve0) / pool.totalSupply;
        amount1 = (liquidity * pool.reserve1) / pool.totalSupply;

        // Effects: update state before interactions
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalSupply -= liquidity;

        uint256 remainingLiquidity = pos.liquidity - liquidity;
        if (remainingLiquidity == 0) {
            pos.amount0 = 0;
            pos.amount1 = 0;
        } else {
            pos.amount0 = (pos.amount0 * remainingLiquidity) / pos.liquidity;
            pos.amount1 = (pos.amount1 * remainingLiquidity) / pos.liquidity;
        }
        pos.liquidity = remainingLiquidity;

        // Interactions
        _safeTransfer(pool.token0, msg.sender, amount0);
        _safeTransfer(pool.token1, msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, pool.token0, pool.token1, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        if (tokenIn == address(0) || tokenOut == address(0) || to == address(0)) revert ZeroAddress();
        if (tokenIn == tokenOut) revert IdenticalTokens();
        if (amountIn == 0) revert InsufficientInput();

        bytes32 poolId = _getPoolIdSorted(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];
        if (!pool.initialized) revert PoolDoesNotExist();

        bool zeroForOne = tokenIn == pool.token0;
        uint256 feeAmount = (amountIn * protocolFee) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - feeAmount;
        if (amountInAfterFee == 0) revert FeeTooHigh();

        uint256 reserveIn;
        uint256 reserveOut;
        if (zeroForOne) {
            reserveIn = pool.reserve0;
            reserveOut = pool.reserve1;
        } else {
            reserveIn = pool.reserve1;
            reserveOut = pool.reserve0;
        }

        amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
        if (amountOut < minAmountOut) revert InsufficientOutput();

        // Effects: update state before interactions
        if (zeroForOne) {
            pool.reserve0 += amountInAfterFee;
            pool.reserve1 -= amountOut;
            pool.protocolFee0 += feeAmount;
        } else {
            pool.reserve1 += amountInAfterFee;
            pool.reserve0 -= amountOut;
            pool.protocolFee1 += feeAmount;
        }

        // Interactions
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, to, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeAmount);
    }

    function setProtocolFee(uint24 newFee) external onlyOwner {
        if (newFee > MAX_PROTOCOL_FEE) revert FeeTooHigh();
        uint24 oldFee = protocolFee;
        protocolFee = newFee;
        emit ProtocolFeeUpdated(oldFee, newFee);
    }

    function setAllowedPair(address tokenA, address tokenB, bool allowed) external onlyOwner {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        allowedPairs[token0][token1] = allowed;
        emit PairAllowedUpdated(token0, token1, allowed);
    }

    function collectProtocolFees(address tokenA, address tokenB, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        bytes32 poolId = _getPoolIdSorted(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        if (!pool.initialized) revert PoolDoesNotExist();

        uint256 fee0 = pool.protocolFee0;
        uint256 fee1 = pool.protocolFee1;

        // Effects: zero out before transfer
        pool.protocolFee0 = 0;
        pool.protocolFee1 = 0;

        // Interactions
        if (fee0 > 0) _safeTransfer(pool.token0, to, fee0);
        if (fee1 > 0) _safeTransfer(pool.token1, to, fee1);

        emit ProtocolFeesCollected(pool.token0, pool.token1, to, fee0, fee1);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function getPoolInfo(address tokenA, address tokenB) external view returns (PoolView memory view_) {
        bytes32 poolId = _getPoolIdSorted(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        if (!pool.initialized) revert PoolDoesNotExist();
        view_ = PoolView({
            token0: pool.token0,
            token1: pool.token1,
            reserve0: pool.reserve0,
            reserve1: pool.reserve1,
            totalSupply: pool.totalSupply
        });
    }

    function getPosition(address tokenA, address tokenB, address provider)
        external
        view
        returns (PositionView memory view_)
    {
        bytes32 poolId = _getPoolIdSorted(tokenA, tokenB);
        Position storage pos = positions[poolId][provider];
        view_ = PositionView({
            liquidity: pos.liquidity,
            amount0: pos.amount0,
            amount1: pos.amount1,
            priceLower: pos.priceLower,
            priceUpper: pos.priceUpper
        });
    }

    function getPoolId(address tokenA, address tokenB) external pure returns (bytes32) {
        return _getPoolIdSorted(tokenA, tokenB);
    }

    function _getPoolIdSorted(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return _getPoolId(token0, token1);
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA < tokenB) {
            return (tokenA, tokenB);
        } else {
            return (tokenB, tokenA);
        }
    }

    function _getPoolId(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool success = IERC20(token).transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool success = IERC20(token).transfer(to, amount);
        if (!success) revert TransferFailed();
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
