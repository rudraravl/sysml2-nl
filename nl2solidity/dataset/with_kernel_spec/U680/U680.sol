// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

library SafeERC20 {
    error SafeTransferFailed();
    error SafeTransferFromFailed();
    error ApproveFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) {
            if (address(token).code.length == 0) revert SafeTransferFailed();
            (bool ok, bytes memory data) = address(token).call(
                abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
            );
            if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert SafeTransferFailed();
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) {
            if (address(token).code.length == 0) revert SafeTransferFromFailed();
            (bool ok, bytes memory data) = address(token).call(
                abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
            );
            if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert SafeTransferFromFailed();
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title DecentralizedExchange
 * @notice Manages liquidity pools for token pairs, enabling deposits, withdrawals,
 *         and constant-product swaps with a configurable fee (default 0.3%).
 *         Only the operator may add new token pairs, set initial fees, and pause trading.
 */
contract DecentralizedExchange is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error TradingPaused();
    error PoolNotFound();
    error PoolAlreadyExists();
    error InvalidTokens();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientInitialLiquidity();
    error InsufficientShares();
    error InsufficientOutputAmount();
    error InsufficientLiquidityMinted();
    error InvalidFee();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MINIMUM_INITIAL_LIQUIDITY = 100;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10% cap

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalShares;
        uint256 feeBps; // e.g. 30 = 0.3%
        bool active;
    }

    struct ProviderLiquidity {
        uint256 shares;
        uint256 amount0Deposited;
        uint256 amount1Deposited;
    }

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------
    address public operator;
    bool public paused;

    mapping(bytes32 => Pool) private _pools;
    mapping(bytes32 => mapping(address => ProviderLiquidity)) private _providerLiquidity;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event PoolAdded(bytes32 indexed poolId, address indexed token0, address indexed token1, uint256 feeBps);
    event PoolFeeUpdated(bytes32 indexed poolId, uint256 oldFee, uint256 newFee);
    event LiquidityDeposited(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event LiquidityWithdrawn(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event TokensSwapped(
        bytes32 indexed poolId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event TradingPausedChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    modifier poolExists(bytes32 poolId) {
        if (!_pools[poolId].active) revert PoolNotFound();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor() {
        operator = msg.sender;
        emit OperatorChanged(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // Operator administration
    // -----------------------------------------------------------------------

    /**
     * @notice Adds a new token pair with an initial liquidity deposit and fee.
     * @param tokenA First token of the pair.
     * @param tokenB Second token of the pair.
     * @param initialAmount0 Amount of token0 to seed the pool.
     * @param initialAmount1 Amount of token1 to seed the pool.
     * @param feeBps Swap fee in basis points (e.g. 30 = 0.3%).
     */
    function addTokenPair(
        address tokenA,
        address tokenB,
        uint256 initialAmount0,
        uint256 initialAmount1,
        uint256 feeBps
    ) external onlyOperator {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (feeBps > MAX_FEE_BPS) revert InvalidFee();

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 poolId = _getPoolId(token0, token1);

        if (_pools[poolId].active) revert PoolAlreadyExists();
        if (initialAmount0 < MINIMUM_INITIAL_LIQUIDITY || initialAmount1 < MINIMUM_INITIAL_LIQUIDITY)
            revert InsufficientInitialLiquidity();

        _pools[poolId] = Pool({
            token0: token0,
            token1: token1,
            reserve0: initialAmount0,
            reserve1: initialAmount1,
            totalShares: initialAmount0,
            feeBps: feeBps,
            active: true
        });

        // Seed liquidity belongs to the operator.
        _providerLiquidity[poolId][msg.sender] = ProviderLiquidity({
            shares: initialAmount0,
            amount0Deposited: initialAmount0,
            amount1Deposited: initialAmount1
        });

        IERC20(token0).safeTransferFrom(msg.sender, address(this), initialAmount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), initialAmount1);

        emit PoolAdded(poolId, token0, token1, feeBps);
        emit LiquidityDeposited(poolId, msg.sender, initialAmount0, initialAmount1, initialAmount0);
    }

    /**
     * @notice Updates the swap fee for an existing pool.
     */
    function setPoolFee(bytes32 poolId, uint256 newFeeBps) external onlyOperator poolExists(poolId) {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 oldFee = _pools[poolId].feeBps;
        _pools[poolId].feeBps = newFeeBps;
        emit PoolFeeUpdated(poolId, oldFee, newFeeBps);
    }

    /**
     * @notice Pauses or unpauses all trading and liquidity operations.
     */
    function setPaused(bool state) external onlyOperator {
        paused = state;
        emit TradingPausedChanged(state);
    }

    /**
     * @notice Transfers operator role to a new address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // -----------------------------------------------------------------------
    // Liquidity provision
    // -----------------------------------------------------------------------

    /**
     * @notice Deposits both tokens into a pool to receive LP shares.
     * @param poolId Identifier of the target pool.
     * @param amount0Desired Desired amount of token0 to deposit.
     * @param amount1Desired Desired amount of token1 to deposit.
     * @param amount0Min Minimum amount of token0 accepted (slippage protection).
     * @param amount1Min Minimum amount of token1 accepted (slippage protection).
     * @return shares The number of LP shares minted.
     */
    function deposit(
        bytes32 poolId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused poolExists(poolId) returns (uint256 shares) {
        if (amount0Desired == 0 || amount1Desired == 0) revert ZeroAmount();

        Pool storage pool = _pools[poolId];

        (uint256 amount0, uint256 amount1) = _optimalDepositAmounts(
            pool.reserve0,
            pool.reserve1,
            amount0Desired,
            amount1Desired
        );

        if (amount0 < amount0Min || amount1 < amount1Min) revert InsufficientLiquidityMinted();

        // Shares are minted proportionally to the smaller side.
        uint256 shares0 = (amount0 * pool.totalShares) / pool.reserve0;
        uint256 shares1 = (amount1 * pool.totalShares) / pool.reserve1;
        shares = shares0 < shares1 ? shares0 : shares1;
        if (shares == 0) revert InsufficientLiquidityMinted();

        // Effects.
        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalShares += shares;

        ProviderLiquidity storage pl = _providerLiquidity[poolId][msg.sender];
        pl.shares += shares;
        pl.amount0Deposited += amount0;
        pl.amount1Deposited += amount1;

        // Interactions.
        IERC20(pool.token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(pool.token1).safeTransferFrom(msg.sender, address(this), amount1);

        emit LiquidityDeposited(poolId, msg.sender, amount0, amount1, shares);
    }

    /**
     * @notice Withdraws a proportional share of both tokens by burning LP shares.
     * @param poolId Identifier of the pool.
     * @param shares Number of LP shares to burn.
     * @return amount0 Amount of token0 returned.
     * @return amount1 Amount of token1 returned.
     */
    function withdraw(
        bytes32 poolId,
        uint256 shares
    ) external nonReentrant whenNotPaused poolExists(poolId) returns (uint256 amount0, uint256 amount1) {
        if (shares == 0) revert ZeroAmount();

        Pool storage pool = _pools[poolId];
        ProviderLiquidity storage pl = _providerLiquidity[poolId][msg.sender];
        if (pl.shares < shares) revert InsufficientShares();

        amount0 = (shares * pool.reserve0) / pool.totalShares;
        amount1 = (shares * pool.reserve1) / pool.totalShares;
        if (amount0 == 0 && amount1 == 0) revert InsufficientShares();

        // Effects.
        uint256 previousShares = pl.shares;
        pl.shares -= shares;

        uint256 withdrawn0 = (shares * pl.amount0Deposited) / previousShares;
        uint256 withdrawn1 = (shares * pl.amount1Deposited) / previousShares;
        pl.amount0Deposited -= withdrawn0;
        pl.amount1Deposited -= withdrawn1;

        pool.totalShares -= shares;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;

        // Interactions.
        IERC20(pool.token0).safeTransfer(msg.sender, amount0);
        IERC20(pool.token1).safeTransfer(msg.sender, amount1);

        emit LiquidityWithdrawn(poolId, msg.sender, amount0, amount1, shares);
    }

    // -----------------------------------------------------------------------
    // Swaps
    // -----------------------------------------------------------------------

    /**
     * @notice Swaps `amountIn` of `tokenIn` for `tokenOut` within a pool.
     * @param poolId Identifier of the pool.
     * @param tokenIn Address of the token being sold.
     * @param tokenOut Address of the token being bought.
     * @param amountIn Amount of tokenIn to sell.
     * @param amountOutMin Minimum amount of tokenOut accepted (slippage protection).
     * @return amountOut Amount of tokenOut received.
     */
    function swap(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant whenNotPaused poolExists(poolId) returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();

        Pool storage pool = _pools[poolId];
        bool isToken0In = tokenIn == pool.token0;
        if (!isToken0In && tokenIn != pool.token1) revert InvalidTokens();
        if (tokenOut != (isToken0In ? pool.token1 : pool.token0)) revert InvalidTokens();

        uint256 reserveIn = isToken0In ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = isToken0In ? pool.reserve1 : pool.reserve0;

        uint256 fee = (amountIn * pool.feeBps) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;

        amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
        if (amountOut == 0 || amountOut >= reserveOut) revert InsufficientOutputAmount();
        if (amountOut < amountOutMin) revert InsufficientOutputAmount();

        // Effects.
        if (isToken0In) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        // Interactions.
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    function getPoolId(address tokenA, address tokenB) external pure returns (bytes32) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return _getPoolId(token0, token1);
    }

    function getPool(
        bytes32 poolId
    )
        external
        view
        returns (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalShares,
            uint256 feeBps,
            bool active
        )
    {
        Pool storage pool = _pools[poolId];
        return (
            pool.token0,
            pool.token1,
            pool.reserve0,
            pool.reserve1,
            pool.totalShares,
            pool.feeBps,
            pool.active
        );
    }

    function getProviderLiquidity(
        bytes32 poolId,
        address provider
    ) external view returns (uint256 shares, uint256 amount0Deposited, uint256 amount1Deposited) {
        ProviderLiquidity storage pl = _providerLiquidity[poolId][provider];
        return (pl.shares, pl.amount0Deposited, pl.amount1Deposited);
    }

    function getAmountOut(
        bytes32 poolId,
        address tokenIn,
        uint256 amountIn
    ) external view poolExists(poolId) returns (uint256) {
        Pool storage pool = _pools[poolId];
        bool isToken0In = tokenIn == pool.token0;
        if (!isToken0In && tokenIn != pool.token1) revert InvalidTokens();

        uint256 reserveIn = isToken0In ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = isToken0In ? pool.reserve1 : pool.reserve0;

        uint256 amountInAfterFee = amountIn - (amountIn * pool.feeBps) / FEE_DENOMINATOR;
        return (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert InvalidTokens();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    function _getPoolId(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    /**
     * @dev Computes the optimal deposit amounts that maintain the pool ratio,
     *      minimizing excess deposits on either side.
     */
    function _optimalDepositAmounts(
        uint256 reserve0,
        uint256 reserve1,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            return (amount0Desired, amount1Desired);
        }

        uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
        if (amount1Optimal <= amount1Desired) {
            return (amount0Desired, amount1Optimal);
        } else {
            uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
            return (amount0Optimal, amount1Desired);
        }
    }
}
