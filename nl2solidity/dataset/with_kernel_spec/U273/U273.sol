// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
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

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (_owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        address previousOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title StableSwap
 * @notice Creates and manages constant-product-with-amplification liquidity pools
 *         for swapping between stable-value ERC20 tokens. Each pool may contain
 *         between 2 and 8 tokens. Pools hold deposited tokens directly as reserves.
 */
contract StableSwap is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ----------------------------------------------------------------------- */
    /* Constants                                                               */
    /* ----------------------------------------------------------------------- */

    uint256 public constant MAX_TOKENS_PER_POOL = 8;
    uint256 public constant MIN_TOKENS_PER_POOL = 2;
    uint256 public constant FEE_DENOMINATOR = 1_000_000;
    uint256 public constant DEFAULT_SWAP_FEE = 400;          // 0.04%
    uint256 public constant MIN_SWAP_FEE = 1;
    uint256 public constant MAX_SWAP_FEE = 100_000;           // 10% cap
    uint256 public constant MIN_AMPLIFICATION = 1e15;
    uint256 public constant MAX_AMPLIFICATION = 1e24;
    uint256 public constant DEFAULT_AMPLIFICATION = 1e20;

    /* ----------------------------------------------------------------------- */
    /* Structs                                                                 */
    /* ----------------------------------------------------------------------- */

    struct PoolConfig {
        bool isActive;
        uint256 amplification;
        uint256 swapFee;
        uint256 totalLpSupply;
        uint256 createdAt;
    }

    struct PoolData {
        address[] tokens;
        mapping(address => uint256) reserves;
        mapping(address => bool) isTokenInPool;
        mapping(address => uint256) lpBalances;
    }

    /* ----------------------------------------------------------------------- */
    /* State                                                                   */
    /* ----------------------------------------------------------------------- */

    mapping(uint256 => PoolConfig) public poolConfigs;
    mapping(uint256 => PoolData) internal _pools;
    uint256[] public allPools;
    uint256 internal _nextPoolId;

    address public feeRecipient;

    /* ----------------------------------------------------------------------- */
    /* Events                                                                  */
    /* ----------------------------------------------------------------------- */

    event PoolCreated(
        uint256 indexed poolId,
        address[] tokens,
        uint256 amplification,
        uint256 swapFee,
        uint256 timestamp
    );
    event Deposit(
        uint256 indexed poolId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 lpMinted
    );
    event Withdrawal(
        uint256 indexed poolId,
        address indexed user,
        address[] tokens,
        uint256[] amounts,
        uint256 lpBurned
    );
    event Exchange(
        uint256 indexed poolId,
        address indexed user,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event PoolAmplificationUpdated(uint256 indexed poolId, uint256 oldAmp, uint256 newAmp);
    event PoolSwapFeeUpdated(uint256 indexed poolId, uint256 oldFee, uint256 newFee);
    event PoolStatusUpdated(uint256 indexed poolId, bool isActive);

    /* ----------------------------------------------------------------------- */
    /* Errors                                                                  */
    /* ----------------------------------------------------------------------- */

    error ZeroAddress();
    error TokenNotInPool();
    error PoolInactive();
    error ExceedsMaxTokens();
    error TooFewTokens();
    error DuplicateTokens();
    error SameToken();
    error InsufficientLiquidity();
    error InsufficientLpBalance();
    error InvalidAmplification();
    error InvalidSwapFee();
    error InvalidAmount();
    error InvalidPoolId();

    /* ----------------------------------------------------------------------- */
    /* Modifiers                                                               */
    /* ----------------------------------------------------------------------- */

    modifier poolExists(uint256 poolId) {
        if (poolId >= _nextPoolId) revert InvalidPoolId();
        _;
    }

    /* ----------------------------------------------------------------------- */
    /* Constructor                                                             */
    /* ----------------------------------------------------------------------- */

    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    /* ----------------------------------------------------------------------- */
    /* Admin: pool management                                                  */
    /* ----------------------------------------------------------------------- */

    /**
     * @notice Creates a new stable-value liquidity pool containing `tokens`.
     * @param tokens ERC20 addresses that will be traded in the pool (2..8).
     * @param amplification Virtual reserve boost; higher = tighter peg.
     * @param swapFee Fee charged on swaps, in units of `FEE_DENOMINATOR`.
     * @return poolId Identifier of the newly created pool.
     */
    function createPool(
        address[] calldata tokens,
        uint256 amplification,
        uint256 swapFee
    ) external onlyOwner returns (uint256 poolId) {
        uint256 n = tokens.length;
        if (n < MIN_TOKENS_PER_POOL) revert TooFewTokens();
        if (n > MAX_TOKENS_PER_POOL) revert ExceedsMaxTokens();
        if (amplification < MIN_AMPLIFICATION || amplification > MAX_AMPLIFICATION) {
            revert InvalidAmplification();
        }
        if (swapFee < MIN_SWAP_FEE || swapFee > MAX_SWAP_FEE) revert InvalidSwapFee();

        for (uint256 i = 0; i < n; ++i) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            for (uint256 j = i + 1; j < n; ++j) {
                if (tokens[i] == tokens[j]) revert DuplicateTokens();
            }
        }

        poolId = _nextPoolId++;

        PoolData storage pool = _pools[poolId];
        for (uint256 i = 0; i < n; ++i) {
            pool.tokens.push(tokens[i]);
            pool.isTokenInPool[tokens[i]] = true;
        }

        poolConfigs[poolId] = PoolConfig({
            isActive: true,
            amplification: amplification,
            swapFee: swapFee,
            totalLpSupply: 0,
            createdAt: block.timestamp
        });

        allPools.push(poolId);

        emit PoolCreated(poolId, tokens, amplification, swapFee, block.timestamp);
    }

    /**
     * @notice Updates the amplification factor of an existing pool.
     */
    function setAmplification(
        uint256 poolId,
        uint256 amplification
    ) external onlyOwner poolExists(poolId) {
        if (amplification < MIN_AMPLIFICATION || amplification > MAX_AMPLIFICATION) {
            revert InvalidAmplification();
        }
        uint256 old = poolConfigs[poolId].amplification;
        poolConfigs[poolId].amplification = amplification;
        emit PoolAmplificationUpdated(poolId, old, amplification);
    }

    /**
     * @notice Updates the swap fee of an existing pool.
     */
    function setSwapFee(
        uint256 poolId,
        uint256 swapFee
    ) external onlyOwner poolExists(poolId) {
        if (swapFee < MIN_SWAP_FEE || swapFee > MAX_SWAP_FEE) revert InvalidSwapFee();
        uint256 old = poolConfigs[poolId].swapFee;
        poolConfigs[poolId].swapFee = swapFee;
        emit PoolSwapFeeUpdated(poolId, old, swapFee);
    }

    /**
     * @notice Enables or disables a pool. Disabled pools cannot be interacted with
     *         except by the owner.
     */
    function setPoolActive(uint256 poolId, bool active) external onlyOwner poolExists(poolId) {
        poolConfigs[poolId].isActive = active;
        emit PoolStatusUpdated(poolId, active);
    }

    /**
     * @notice Updates the global fee recipient address.
     */
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    /* ----------------------------------------------------------------------- */
    /* User: liquidity operations                                              */
    /* ----------------------------------------------------------------------- */

    /**
     * @notice Deposits `amount` of `token` into pool `poolId`, minting LP tokens
     *         proportionally to the caller.
     */
    function deposit(
        uint256 poolId,
        address token,
        uint256 amount
    ) external nonReentrant poolExists(poolId) {
        PoolConfig storage config = poolConfigs[poolId];
        if (!config.isActive) revert PoolInactive();
        if (amount == 0) revert InvalidAmount();

        PoolData storage pool = _pools[poolId];
        if (!pool.isTokenInPool[token]) revert TokenNotInPool();

        // Effects: compute LP minted before mutating state (checks-effects-interactions).
        uint256 lpMinted;
        if (config.totalLpSupply == 0 || pool.reserves[token] == 0) {
            lpMinted = amount;
        } else {
            lpMinted = (amount * config.totalLpSupply) / pool.reserves[token];
        }
        if (lpMinted == 0) revert InsufficientLiquidity();

        pool.reserves[token] += amount;
        config.totalLpSupply += lpMinted;
        pool.lpBalances[msg.sender] += lpMinted;

        // Interactions: pull tokens after state update.
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(poolId, msg.sender, token, amount, lpMinted);
    }

    /**
     * @notice Withdraws a proportional share of every token in pool `poolId`
     *         by burning `lpAmount` LP tokens owned by the caller.
     */
    function withdraw(uint256 poolId, uint256 lpAmount) external nonReentrant poolExists(poolId) {
        PoolConfig storage config = poolConfigs[poolId];
        if (!config.isActive) revert PoolInactive();
        if (lpAmount == 0) revert InvalidAmount();

        PoolData storage pool = _pools[poolId];
        if (pool.lpBalances[msg.sender] < lpAmount) revert InsufficientLpBalance();
        if (config.totalLpSupply == 0) revert InsufficientLiquidity();

        address[] memory tokens = pool.tokens;
        uint256 n = tokens.length;
        uint256[] memory amounts = new uint256[](n);

        // Effects: burn LP and reduce reserves first.
        pool.lpBalances[msg.sender] -= lpAmount;

        for (uint256 i = 0; i < n; ++i) {
            uint256 share = (lpAmount * pool.reserves[tokens[i]]) / config.totalLpSupply;
            amounts[i] = share;
            pool.reserves[tokens[i]] -= share;
        }

        config.totalLpSupply -= lpAmount;

        // Interactions: transfer tokens out after state update.
        for (uint256 i = 0; i < n; ++i) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, amounts[i]);
            }
        }

        emit Withdrawal(poolId, msg.sender, tokens, amounts, lpAmount);
    }

    /**
     * @notice Exchanges `amountIn` of `tokenIn` for `tokenOut` within pool `poolId`,
     *         charging the pool's configured swap fee.
     */
    function exchange(
        uint256 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external nonReentrant poolExists(poolId) returns (uint256 amountOut) {
        PoolConfig storage config = poolConfigs[poolId];
        if (!config.isActive) revert PoolInactive();
        if (amountIn == 0) revert InvalidAmount();
        if (tokenIn == tokenOut) revert SameToken();

        PoolData storage pool = _pools[poolId];
        if (!pool.isTokenInPool[tokenIn] || !pool.isTokenInPool[tokenOut]) {
            revert TokenNotInPool();
        }

        uint256 reserveIn = pool.reserves[tokenIn];
        uint256 reserveOut = pool.reserves[tokenOut];
        if (reserveOut == 0) revert InsufficientLiquidity();

        // Compute output amount and fee before any external calls.
        uint256 fee = (amountIn * config.swapFee) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;
        amountOut = _computeAmountOut(reserveIn, reserveOut, amountInAfterFee, config.amplification);
        if (amountOut == 0 || amountOut > reserveOut) revert InsufficientLiquidity();

        // Effects: update reserves before interactions (checks-effects-interactions).
        pool.reserves[tokenIn] = reserveIn + amountIn;
        pool.reserves[tokenOut] = reserveOut - amountOut;

        // Interactions: pull input tokens and send output tokens after state update.
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Exchange(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    /* ----------------------------------------------------------------------- */
    /* Views                                                                   */
    /* ----------------------------------------------------------------------- */

    function getAllPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    function getPoolTokens(uint256 poolId) external view poolExists(poolId) returns (address[] memory) {
        return _pools[poolId].tokens;
    }

    function getReserve(uint256 poolId, address token) external view poolExists(poolId) returns (uint256) {
        return _pools[poolId].reserves[token];
    }

    function getLpBalance(uint256 poolId, address user) external view poolExists(poolId) returns (uint256) {
        return _pools[poolId].lpBalances[user];
    }

    function isTokenInPool(uint256 poolId, address token) external view poolExists(poolId) returns (bool) {
        return _pools[poolId].isTokenInPool[token];
    }

    /**
     * @notice Returns the amount of `tokenOut` the caller would receive for
     *         `amountIn` of `tokenIn` in pool `poolId`, including the fee.
     */
    function getAmountOut(
        uint256 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view poolExists(poolId) returns (uint256) {
        PoolConfig storage config = poolConfigs[poolId];
        PoolData storage pool = _pools[poolId];
        if (!pool.isTokenInPool[tokenIn] || !pool.isTokenInPool[tokenOut]) {
            revert TokenNotInPool();
        }
        uint256 reserveIn = pool.reserves[tokenIn];
        uint256 reserveOut = pool.reserves[tokenOut];
        if (reserveOut == 0) return 0;

        uint256 fee = (amountIn * config.swapFee) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;
        return _computeAmountOut(reserveIn, reserveOut, amountInAfterFee, config.amplification);
    }

    /* ----------------------------------------------------------------------- */
    /* Internal: pricing                                                       */
    /* ----------------------------------------------------------------------- */

    /**
     * @dev Stable-swap style pricing using virtual reserves. The pool invariant
     *      is (R_in + A) * (R_out + A) = k, where A is the amplification factor.
     *      Larger A produces tighter 1:1 pricing when reserves are balanced and
     *      falls back to constant-product behaviour as reserves diverge.
     */
    function _computeAmountOut(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amountIn,
        uint256 amplification
    ) internal pure returns (uint256) {
        uint256 virtualReserve = amplification;
        uint256 effectiveIn = reserveIn + virtualReserve;
        uint256 effectiveOut = reserveOut + virtualReserve;
        uint256 invariant = effectiveIn * effectiveOut;
        uint256 newEffectiveOut = invariant / (effectiveIn + amountIn);
        if (newEffectiveOut <= virtualReserve) return 0;
        return newEffectiveOut - virtualReserve;
    }
}
