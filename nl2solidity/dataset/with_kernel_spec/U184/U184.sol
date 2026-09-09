// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_FEE_BPS = 1;
    uint256 public constant MAX_FEE_BPS = 100;

    error NotAdmin();
    error InvalidFee();
    error InvalidToken();
    error IdenticalTokens();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InsufficientOutput();
    error InsufficientAAmount();
    error InsufficientBAmount();
    error TransferFailed();
    error ReentrantCall();
    error PoolNotInitialized();
    error InvalidEmission();
    error RewardTokenMismatch();
    error NoRewardToken();
    error NothingToClaim();

    event PoolInitialized(bytes32 indexed poolId, address indexed token0, address indexed token1, address creator);
    event LiquidityAdded(bytes32 indexed poolId, address indexed provider, uint256 liquidity, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(bytes32 indexed poolId, address indexed provider, uint256 liquidity, uint256 amount0, uint256 amount1);
    event Swap(bytes32 indexed poolId, address indexed trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee);
    event FeesClaimed(bytes32 indexed poolId, address indexed user, uint256 amount0, uint256 amount1);
    event EmissionsClaimed(bytes32 indexed poolId, address indexed user, address indexed rewardToken, uint256 amount);
    event BaseFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event EmissionScheduleSet(bytes32 indexed poolId, address indexed rewardToken, uint256 amount, uint256 duration, uint256 rewardRate);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    address public admin;
    uint256 public baseFeeBps;

    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        uint256 fee0PerLiquidity;
        uint256 fee1PerLiquidity;
        address rewardToken;
        uint256 rewardRate;
        uint256 periodFinish;
        uint256 lastUpdateTime;
        uint256 rewardPerLiquidityStored;
        bool initialized;
    }

    struct UserInfo {
        uint256 liquidity;
        uint256 pendingFee0;
        uint256 pendingFee1;
        uint256 fee0Debt;
        uint256 fee1Debt;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => UserInfo)) public userInfo;

    uint256 private _locked = 1;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        admin = msg.sender;
        baseFeeBps = 5;
        emit AdminChanged(address(0), msg.sender);
        emit BaseFeeUpdated(0, baseFeeBps);
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidToken();
        address previous = admin;
        admin = newAdmin;
        emit AdminChanged(previous, newAdmin);
    }

    function setBaseFee(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps < MIN_FEE_BPS || newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 old = baseFeeBps;
        baseFeeBps = newFeeBps;
        emit BaseFeeUpdated(old, newFeeBps);
    }

    function setEmissionSchedule(
        address tokenA,
        address tokenB,
        address rewardToken,
        uint256 amount,
        uint256 duration
    ) external onlyAdmin nonReentrant {
        if (rewardToken == address(0) || amount == 0 || duration == 0) revert InvalidEmission();

        bytes32 id = _poolIdForSorted(tokenA, tokenB);
        Pool storage pool = pools[id];
        if (!pool.initialized) revert PoolNotInitialized();

        if (
            pool.rewardToken != address(0) &&
            pool.rewardToken != rewardToken &&
            block.timestamp < pool.periodFinish
        ) {
            revert RewardTokenMismatch();
        }

        _updateReward(pool);

        uint256 leftover = 0;
        if (block.timestamp < pool.periodFinish) {
            leftover = (pool.periodFinish - block.timestamp) * pool.rewardRate;
        }

        pool.rewardToken = rewardToken;
        pool.rewardRate = (amount + leftover) / duration;
        pool.periodFinish = block.timestamp + duration;
        pool.lastUpdateTime = block.timestamp;

        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);

        emit EmissionScheduleSet(id, rewardToken, amount, duration, pool.rewardRate);
    }

    function deposit(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (amountADesired == 0 || amountBDesired == 0) revert ZeroAmount();
        bytes32 id = _poolIdForSorted(tokenA, tokenB);
        (amountA, amountB, liquidity) = _deposit(
            id, tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin
        );
    }

    function _deposit(
        bytes32 id,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        Pool storage pool = pools[id];
        if (!pool.initialized) {
            (address t0, address t1) = _sortedTokens(tokenA, tokenB);
            pool.token0 = t0;
            pool.token1 = t1;
            pool.initialized = true;
            pool.lastUpdateTime = block.timestamp;
            emit PoolInitialized(id, t0, t1, msg.sender);
        }

        _accrue(pool, id, msg.sender);

        bool isToken0A = tokenA == pool.token0;

        (uint256 amount0, uint256 amount1) = _computeDepositAmounts(
            isToken0A ? amountADesired : amountBDesired,
            isToken0A ? amountBDesired : amountADesired,
            isToken0A ? amountAMin : amountBMin,
            isToken0A ? amountBMin : amountAMin,
            pool.reserve0,
            pool.reserve1,
            pool.totalLiquidity
        );

        if (amount0 == 0 || amount1 == 0) revert ZeroAmount();

        liquidity = _computeLiquidity(amount0, amount1, pool.reserve0, pool.reserve1, pool.totalLiquidity);
        if (liquidity == 0) revert InsufficientLiquidity();

        _safeTransferFrom(pool.token0, msg.sender, address(this), amount0);
        _safeTransferFrom(pool.token1, msg.sender, address(this), amount1);

        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += liquidity;

        userInfo[id][msg.sender].liquidity += liquidity;
        _setDebts(pool, id, msg.sender);

        (amountA, amountB) = isToken0A ? (amount0, amount1) : (amount1, amount0);

        emit LiquidityAdded(id, msg.sender, liquidity, amount0, amount1);
    }

    function withdraw(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert ZeroAmount();
        bytes32 id = _poolIdForSorted(tokenA, tokenB);
        (amountA, amountB) = _withdraw(id, tokenA, liquidity, amountAMin, amountBMin);
    }

    function _withdraw(
        bytes32 id,
        address tokenA,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        Pool storage pool = pools[id];
        if (!pool.initialized) revert PoolNotInitialized();

        _accrue(pool, id, msg.sender);

        UserInfo storage info = userInfo[id][msg.sender];
        if (info.liquidity < liquidity) revert InsufficientLiquidity();

        uint256 amount0 = (liquidity * pool.reserve0) / pool.totalLiquidity;
        uint256 amount1 = (liquidity * pool.reserve1) / pool.totalLiquidity;

        uint256 total0 = amount0 + info.pendingFee0;
        uint256 total1 = amount1 + info.pendingFee1;

        bool isToken0A = tokenA == pool.token0;
        if (isToken0A) {
            if (total0 < amountAMin || total1 < amountBMin) revert InsufficientLiquidity();
        } else {
            if (total0 < amountBMin || total1 < amountAMin) revert InsufficientLiquidity();
        }

        info.pendingFee0 = 0;
        info.pendingFee1 = 0;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalLiquidity -= liquidity;
        info.liquidity -= liquidity;

        _setDebts(pool, id, msg.sender);

        _safeTransfer(pool.token0, msg.sender, total0);
        _safeTransfer(pool.token1, msg.sender, total1);

        (amountA, amountB) = isToken0A ? (total0, total1) : (total1, total0);

        emit LiquidityRemoved(id, msg.sender, liquidity, amount0, amount1);
        emit FeesClaimed(id, msg.sender, total0 - amount0, total1 - amount1);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert IdenticalTokens();

        bytes32 id = _poolIdForSorted(tokenIn, tokenOut);
        Pool storage pool = pools[id];
        if (!pool.initialized) revert PoolNotInitialized();
        if (pool.totalLiquidity == 0 || pool.reserve0 == 0 || pool.reserve1 == 0) {
            revert InsufficientLiquidity();
        }

        bool zeroForOne = tokenIn == pool.token0;
        uint256 reserveIn = zeroForOne ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = zeroForOne ? pool.reserve1 : pool.reserve0;

        uint256 fee = (amountIn * baseFeeBps) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;
        if (amountInAfterFee == 0) revert InvalidFee();

        amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
        if (amountOut == 0) revert InsufficientOutput();
        if (amountOut < minOut) revert InsufficientOutput();

        if (zeroForOne) {
            pool.reserve0 += amountInAfterFee;
            pool.reserve1 -= amountOut;
            if (pool.totalLiquidity > 0) {
                pool.fee0PerLiquidity += (fee * PRECISION) / pool.totalLiquidity;
            }
        } else {
            pool.reserve1 += amountInAfterFee;
            pool.reserve0 -= amountOut;
            if (pool.totalLiquidity > 0) {
                pool.fee1PerLiquidity += (fee * PRECISION) / pool.totalLiquidity;
            }
        }

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        emit Swap(id, msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    function claimFees(address tokenA, address tokenB)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        bytes32 id = _poolIdForSorted(tokenA, tokenB);
        Pool storage pool = pools[id];
        if (!pool.initialized) revert PoolNotInitialized();

        _accrue(pool, id, msg.sender);

        UserInfo storage info = userInfo[id][msg.sender];
        uint256 fee0 = info.pendingFee0;
        uint256 fee1 = info.pendingFee1;

        if (fee0 == 0 && fee1 == 0) revert NothingToClaim();

        info.pendingFee0 = 0;
        info.pendingFee1 = 0;
        _setDebts(pool, id, msg.sender);

        if (fee0 > 0) _safeTransfer(pool.token0, msg.sender, fee0);
        if (fee1 > 0) _safeTransfer(pool.token1, msg.sender, fee1);

        (amountA, amountB) = tokenA == pool.token0 ? (fee0, fee1) : (fee1, fee0);

        emit FeesClaimed(id, msg.sender, fee0, fee1);
    }

    function claimEmissions(address tokenA, address tokenB)
        external
        nonReentrant
        returns (uint256 amount)
    {
        bytes32 id = _poolIdForSorted(tokenA, tokenB);
        Pool storage pool = pools[id];
        if (!pool.initialized) revert PoolNotInitialized();
        if (pool.rewardToken == address(0)) revert NoRewardToken();

        _accrue(pool, id, msg.sender);

        UserInfo storage info = userInfo[id][msg.sender];
        amount = info.pendingRewards;
        if (amount == 0) revert NothingToClaim();

        info.pendingRewards = 0;
        _setDebts(pool, id, msg.sender);

        _safeTransfer(pool.rewardToken, msg.sender, amount);

        emit EmissionsClaimed(id, msg.sender, pool.rewardToken, amount);
    }

    function poolId(address tokenA, address tokenB) external pure returns (bytes32) {
        return _poolIdForSorted(tokenA, tokenB);
    }

    function getPool(address tokenA, address tokenB)
        external
        view
        returns (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalLiquidity,
            address rewardToken,
            uint256 rewardRate,
            uint256 periodFinish,
            uint256 lastUpdateTime,
            uint256 rewardPerLiquidityStored,
            uint256 fee0PerLiquidity,
            uint256 fee1PerLiquidity,
            bool initialized
        )
    {
        bytes32 id = _poolIdForSorted(tokenA, tokenB);
        Pool storage pool = pools[id];
        return (
            pool.token0,
            pool.token1,
            pool.reserve0,
            pool.reserve1,
            pool.totalLiquidity,
            pool.rewardToken,
            pool.rewardRate,
            pool.periodFinish,
            pool.lastUpdateTime,
            pool.rewardPerLiquidityStored,
            pool.fee0PerLiquidity,
            pool.fee1PerLiquidity,
            pool.initialized
        );
    }

    function getPosition(address tokenA, address tokenB, address user)
        external
        view
        returns (
            uint256 liquidity,
            uint256 pendingFee0,
            uint256 pendingFee1,
            uint256 pendingRewards
        )
    {
        bytes32 id = _poolIdForSorted(tokenA, tokenB);
        UserInfo storage info = userInfo[id][user];
        return (info.liquidity, info.pendingFee0, info.pendingFee1, info.pendingRewards);
    }

    function pendingFees(address tokenA, address tokenB, address user)
        external
        view
        returns (uint256 amountA, uint256 amountB)
    {
        (address token0, ) = _sortedTokens(tokenA, tokenB);
        bytes32 id = _poolIdForSorted(tokenA, tokenB);

        Pool storage pool = pools[id];
        UserInfo storage info = userInfo[id][user];

        uint256 pending0 = info.pendingFee0;
        uint256 pending1 = info.pendingFee1;

        if (info.liquidity > 0) {
            uint256 current0 = (info.liquidity * pool.fee0PerLiquidity) / PRECISION;
            uint256 current1 = (info.liquidity * pool.fee1PerLiquidity) / PRECISION;
            pending0 += current0 > info.fee0Debt ? current0 - info.fee0Debt : 0;
            pending1 += current1 > info.fee1Debt ? current1 - info.fee1Debt : 0;
        }

        if (tokenA == token0) {
            amountA = pending0;
            amountB = pending1;
        } else {
            amountA = pending1;
            amountB = pending0;
        }
    }

    function pendingReward(address tokenA, address tokenB, address user)
        external
        view
        returns (uint256 reward)
    {
        bytes32 id = _poolIdForSorted(tokenA, tokenB);

        Pool storage pool = pools[id];
        UserInfo storage info = userInfo[id][user];

        uint256 rewardPerLiquidity = pool.rewardPerLiquidityStored;
        if (pool.totalLiquidity > 0) {
            uint256 lastTime = block.timestamp > pool.periodFinish ? pool.periodFinish : block.timestamp;
            if (lastTime > pool.lastUpdateTime) {
                uint256 delta = lastTime - pool.lastUpdateTime;
                rewardPerLiquidity += (delta * pool.rewardRate * PRECISION) / pool.totalLiquidity;
            }
        }

        uint256 earned = (info.liquidity * rewardPerLiquidity) / PRECISION;
        reward = earned > info.rewardDebt ? earned - info.rewardDebt : 0;
        reward += info.pendingRewards;
    }

    function _sortedTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        if (tokenA == address(0) || tokenB == address(0)) revert InvalidToken();
        if (tokenA == tokenB) revert IdenticalTokens();
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _poolIdFor(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _poolIdForSorted(address tokenA, address tokenB) internal pure returns (bytes32 id) {
        (address token0, address token1) = _sortedTokens(tokenA, tokenB);
        id = _poolIdFor(token0, token1);
    }

    function _computeDepositAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalLiquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (totalLiquidity == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert InsufficientBAmount();
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                if (amount0Optimal > amount0Desired) revert InsufficientAAmount();
                if (amount0Optimal < amount0Min) revert InsufficientAAmount();
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }
    }

    function _computeLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalLiquidity
    ) internal pure returns (uint256 liquidity) {
        if (totalLiquidity == 0) {
            liquidity = _sqrt(amount0 * amount1);
        } else {
            uint256 liq0 = (amount0 * totalLiquidity) / reserve0;
            uint256 liq1 = (amount1 * totalLiquidity) / reserve1;
            liquidity = liq0 < liq1 ? liq0 : liq1;
        }
    }

    function _updateReward(Pool storage pool) internal {
        if (pool.totalLiquidity == 0) {
            pool.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 lastTime = block.timestamp > pool.periodFinish ? pool.periodFinish : block.timestamp;
        if (lastTime > pool.lastUpdateTime) {
            uint256 delta = lastTime - pool.lastUpdateTime;
            uint256 reward = delta * pool.rewardRate;
            pool.rewardPerLiquidityStored += (reward * PRECISION) / pool.totalLiquidity;
        }
        pool.lastUpdateTime = block.timestamp;
    }

    function _accrue(Pool storage pool, bytes32 id, address user) internal {
        _updateReward(pool);

        UserInfo storage info = userInfo[id][user];
        uint256 liq = info.liquidity;

        if (liq > 0) {
            uint256 currentFee0 = (liq * pool.fee0PerLiquidity) / PRECISION;
            uint256 currentFee1 = (liq * pool.fee1PerLiquidity) / PRECISION;
            uint256 currentReward = (liq * pool.rewardPerLiquidityStored) / PRECISION;

            info.pendingFee0 += currentFee0 > info.fee0Debt ? currentFee0 - info.fee0Debt : 0;
            info.pendingFee1 += currentFee1 > info.fee1Debt ? currentFee1 - info.fee1Debt : 0;
            info.pendingRewards += currentReward > info.rewardDebt ? currentReward - info.rewardDebt : 0;
        }
    }

    function _setDebts(Pool storage pool, bytes32 id, address user) internal {
        UserInfo storage info = userInfo[id][user];
        info.fee0Debt = (info.liquidity * pool.fee0PerLiquidity) / PRECISION;
        info.fee1Debt = (info.liquidity * pool.fee1PerLiquidity) / PRECISION;
        info.rewardDebt = (info.liquidity * pool.rewardPerLiquidityStored) / PRECISION;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
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
