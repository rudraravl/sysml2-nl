// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract DecentralizedSwap {
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error IdenticalTokens();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error MustIncludeBaseToken();
    error InsufficientInitialLiquidity();
    error InsufficientLiquidity();
    error InsufficientShares();
    error InsufficientOutputAmount();
    error FeeTooHigh();
    error NotERC20();
    error TransferFailed();
    error TokenMismatch();
    error ReentrantCall();

    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE = 1000; // 10% cap
    uint256 public constant MINIMUM_BASE_LIQUIDITY = 100; // 100 whole units of base token

    uint256 public swapFeeBps; // 30 = 0.3%
    address public owner;
    address public baseToken;

    uint256 private _locked;

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalShares;
        bool isActive;
    }

    mapping(bytes32 => Pool) private pools;
    mapping(bytes32 => mapping(address => uint256)) private providerShares;

    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 sharesMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 sharesBurned
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    );
    event PairAdded(address indexed token0, address indexed token1, bytes32 indexed poolId);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _baseToken) {
        if (_baseToken == address(0)) revert ZeroAddress();
        owner = msg.sender;
        baseToken = _baseToken;
        swapFeeBps = 30; // 0.3% default
        _locked = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeUpdated(0, 30);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function setSwapFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE) revert FeeTooHigh();
        emit FeeUpdated(swapFeeBps, newFeeBps);
        swapFeeBps = newFeeBps;
    }

    function getPoolId(address tokenA, address tokenB) public pure returns (bytes32) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(t0, t1));
    }

    function getPool(address tokenA, address tokenB)
        external
        view
        returns (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalShares,
            bool isActive
        )
    {
        Pool storage p = pools[getPoolId(tokenA, tokenB)];
        return (p.token0, p.token1, p.reserve0, p.reserve1, p.totalShares, p.isActive);
    }

    function getProviderShares(address tokenA, address tokenB, address provider)
        external
        view
        returns (uint256)
    {
        return providerShares[getPoolId(tokenA, tokenB)][provider];
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        bytes32 poolId = getPoolId(tokenIn, tokenOut);
        Pool storage p = pools[poolId];
        if (!p.isActive) revert PoolDoesNotExist();

        bool zeroToOne = (tokenIn == p.token0);
        uint256 reserveIn = zeroToOne ? p.reserve0 : p.reserve1;
        uint256 reserveOut = zeroToOne ? p.reserve1 : p.reserve0;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFeeBps);
        uint256 numerator = reserveOut * amountInWithFee;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    function _validateERC20(address token) internal view {
        if (token.code.length == 0) revert NotERC20();
        try IERC20(token).totalSupply() returns (uint256 totalSupply) {
            if (totalSupply == 0) revert NotERC20();
        } catch {
            revert NotERC20();
        }
        try IERC20(token).decimals() returns (uint8 tokenDecimals) {
            if (tokenDecimals == 0 || tokenDecimals > 36) revert NotERC20();
        } catch {
            revert NotERC20();
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

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function addPair(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external onlyOwner nonReentrant {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        bytes32 poolId = getPoolId(tokenA, tokenB);
        if (pools[poolId].isActive) revert PoolAlreadyExists();

        _validateERC20(tokenA);
        _validateERC20(tokenB);

        if (tokenA != baseToken && tokenB != baseToken) revert MustIncludeBaseToken();

        uint256 baseAmount = tokenA == baseToken ? amountA : amountB;
        if (baseAmount <= MINIMUM_BASE_LIQUIDITY) revert InsufficientInitialLiquidity();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        uint256 amount0 = tokenA == token0 ? amountA : amountB;
        uint256 amount1 = tokenA == token0 ? amountB : amountA;

        uint256 shares = _sqrt(amount0 * amount1);
        if (shares == 0) revert InsufficientInitialLiquidity();

        pools[poolId] = Pool({
            token0: token0,
            token1: token1,
            reserve0: amount0,
            reserve1: amount1,
            totalShares: shares,
            isActive: true
        });

        providerShares[poolId][msg.sender] = shares;

        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        emit PairAdded(token0, token1, poolId);
        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, shares);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        bytes32 poolId = getPoolId(tokenA, tokenB);
        Pool storage p = pools[poolId];
        if (!p.isActive) revert PoolDoesNotExist();

        (address token0, ) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        uint256 amount0 = tokenA == token0 ? amountA : amountB;
        uint256 amount1 = tokenA == token0 ? amountB : amountA;

        uint256 shares;
        if (p.totalShares == 0 || p.reserve0 == 0 || p.reserve1 == 0) {
            shares = _sqrt(amount0 * amount1);
        } else {
            uint256 shares0 = (amount0 * p.totalShares) / p.reserve0;
            uint256 shares1 = (amount1 * p.totalShares) / p.reserve1;
            shares = shares0 < shares1 ? shares0 : shares1;
        }
        if (shares == 0) revert InsufficientLiquidity();

        p.reserve0 += amount0;
        p.reserve1 += amount1;
        p.totalShares += shares;
        providerShares[poolId][msg.sender] += shares;

        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        emit LiquidityAdded(msg.sender, p.token0, p.token1, amount0, amount1, shares);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 sharesToBurn
    ) external nonReentrant {
        if (sharesToBurn == 0) revert ZeroAmount();

        bytes32 poolId = getPoolId(tokenA, tokenB);
        Pool storage p = pools[poolId];
        if (!p.isActive) revert PoolDoesNotExist();

        uint256 userShares = providerShares[poolId][msg.sender];
        if (userShares < sharesToBurn) revert InsufficientShares();

        uint256 amount0 = (p.reserve0 * sharesToBurn) / p.totalShares;
        uint256 amount1 = (p.reserve1 * sharesToBurn) / p.totalShares;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        p.totalShares -= sharesToBurn;
        p.reserve0 -= amount0;
        p.reserve1 -= amount1;
        providerShares[poolId][msg.sender] = userShares - sharesToBurn;

        _safeTransfer(p.token0, msg.sender, amount0);
        _safeTransfer(p.token1, msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, p.token0, p.token1, amount0, amount1, sharesToBurn);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert IdenticalTokens();

        bytes32 poolId = getPoolId(tokenIn, tokenOut);
        Pool storage p = pools[poolId];
        if (!p.isActive) revert PoolDoesNotExist();

        bool zeroToOne = (tokenIn == p.token0);
        if (zeroToOne) {
            if (tokenOut != p.token1) revert TokenMismatch();
        } else {
            if (tokenOut != p.token0) revert TokenMismatch();
        }

        uint256 reserveIn = zeroToOne ? p.reserve0 : p.reserve1;
        uint256 reserveOut = zeroToOne ? p.reserve1 : p.reserve0;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFeeBps);
        uint256 numerator = reserveOut * amountInWithFee;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        if (amountOut < minAmountOut) revert InsufficientOutputAmount();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        if (zeroToOne) {
            p.reserve0 += amountIn;
            p.reserve1 -= amountOut;
        } else {
            p.reserve1 += amountIn;
            p.reserve0 -= amountOut;
        }

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        uint256 feeAmount = (amountIn * swapFeeBps) / FEE_DENOMINATOR;
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeAmount);
    }
}
