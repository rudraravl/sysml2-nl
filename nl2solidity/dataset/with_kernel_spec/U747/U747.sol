// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IConcentratedLiquidityPool {
    function deposit(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) external returns (uint256 positionId, uint128 liquidity);

    function withdraw(
        uint256 positionId,
        uint128 liquidity
    ) external returns (uint256 amount0, uint256 amount1);

    function collect(
        uint256 positionId,
        address recipient,
        uint256 amount0Max,
        uint256 amount1Max
    ) external returns (uint256 amount0, uint256 amount1);

    function positions(
        uint256 positionId
    )
        external
        view
        returns (
            uint128 liquidity,
            int24 tickLower,
            int24 tickUpper,
            uint256 tokensOwed0,
            uint256 tokensOwed1
        );
}

contract ConcentratedLiquidityVault {
    struct UserInfo {
        uint256 shares;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    struct Position {
        address pool;
        uint256 positionId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bool active;
    }

    struct StrategyConfig {
        int24 tickLower;
        int24 tickUpper;
        uint256 rebalanceThresholdBps;
        uint256 lastRebalance;
    }

    uint256 public constant MAX_POSITIONS = 10;
    uint256 public constant WITHDRAW_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant REWARD_PRECISION = 1e18;

    address public manager;
    address public operator;
    address public immutable token0;
    address public immutable token1;
    address public immutable rewardToken;

    uint256 public totalShares;
    uint256 public totalToken0;
    uint256 public totalToken1;
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;
    uint256 public rewardPerBlock;

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public approvedPools;
    Position[] public positions;
    StrategyConfig public strategy;

    bool private _locked;

    event Deposit(address indexed user, uint256 amount0, uint256 amount1, uint256 shares);
    event Withdraw(address indexed user, uint256 amount0, uint256 amount1, uint256 shares, uint256 fee0, uint256 fee1);
    event RewardPaid(address indexed user, uint256 amount);
    event Rebalance(address indexed pool, int24 tickLower, int24 tickUpper, uint256 positionId);
    event PoolApproved(address indexed pool, bool approved);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event StrategyUpdated(int24 tickLower, int24 tickUpper, uint256 rebalanceThresholdBps);
    event PositionOpened(uint256 indexed positionId, address indexed pool, int24 tickLower, int24 tickUpper, uint128 liquidity);
    event PositionClosed(uint256 indexed positionId, uint256 amount0, uint256 amount1);
    event RewardsCollected(uint256 indexed positionIndex, uint256 amount0, uint256 amount1);
    event RewardPerBlockUpdated(uint256 oldRate, uint256 newRate);
    event ManagerUpdated(address indexed oldManager, address indexed newManager);

    error OnlyOperator();
    error OnlyManager();
    error PoolNotApproved();
    error MaxPositionsReached();
    error ZeroShares();
    error ZeroAmount();
    error InsufficientBalance();
    error ZeroAddress();
    error InvalidTickRange();
    error InvalidThreshold();
    error PositionNotActive();
    error InvalidIndex();
    error TransferFailed();
    error ApproveFailed();
    error ReentrantCall();
    error NoPendingRewards();

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != manager) revert OnlyOperator();
        _;
    }

    modifier onlyManager() {
        if (msg.sender != manager) revert OnlyManager();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address _token0,
        address _token1,
        address _rewardToken,
        address _operator,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _rebalanceThresholdBps,
        uint256 _rewardPerBlock
    ) {
        if (_token0 == address(0) || _token1 == address(0) || _rewardToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_tickLower >= _tickUpper) revert InvalidTickRange();
        if (_rebalanceThresholdBps == 0 || _rebalanceThresholdBps > BPS_DENOMINATOR) revert InvalidThreshold();

        token0 = _token0;
        token1 = _token1;
        rewardToken = _rewardToken;
        manager = msg.sender;
        operator = _operator;
        rewardPerBlock = _rewardPerBlock;
        lastRewardBlock = block.number;

        strategy = StrategyConfig({
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            rebalanceThresholdBps: _rebalanceThresholdBps,
            lastRebalance: block.timestamp
        });

        emit StrategyUpdated(_tickLower, _tickUpper, _rebalanceThresholdBps);
        emit OperatorUpdated(address(0), _operator);
        emit ManagerUpdated(address(0), msg.sender);
    }

    function totalAssets() public view returns (uint256, uint256) {
        return (totalToken0, totalToken1);
    }

    function pendingReward(address user) external view returns (uint256) {
        return _pendingReward(user);
    }

    function activePositionCount() external view returns (uint256) {
        return positions.length;
    }

    function getPosition(
        uint256 index
    )
        external
        view
        returns (
            address pool,
            uint256 positionId,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            bool active
        )
    {
        if (index >= positions.length) revert InvalidIndex();
        Position storage p = positions[index];
        return (p.pool, p.positionId, p.tickLower, p.tickUpper, p.liquidity, p.active);
    }

    function getUserInfo(
        address user
    )
        external
        view
        returns (uint256 shares, uint256 rewardDebt, uint256 pending)
    {
        UserInfo storage info = userInfo[user];
        return (info.shares, info.rewardDebt, _pendingReward(user));
    }

    function _pendingReward(address user) internal view returns (uint256) {
        UserInfo storage info = userInfo[user];
        if (totalShares == 0) {
            return info.pendingRewards;
        }
        uint256 accrued = (accRewardPerShare * info.shares) / REWARD_PRECISION;
        return info.pendingRewards + accrued - info.rewardDebt;
    }

    function _updateRewards() internal {
        if (totalShares == 0) {
            lastRewardBlock = block.number;
            return;
        }
        if (block.number <= lastRewardBlock) return;
        uint256 blocks = block.number - lastRewardBlock;
        uint256 accrued = rewardPerBlock * blocks;
        accRewardPerShare += (accrued * REWARD_PRECISION) / totalShares;
        lastRewardBlock = block.number;
    }

    function deposit(
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant returns (uint256 shares) {
        if (amount0 == 0 && amount1 == 0) revert ZeroAmount();

        _updateRewards();

        if (totalShares == 0) {
            shares = amount0 + amount1;
        } else {
            uint256 denom0 = totalToken0 == 0 ? 1 : totalToken0;
            uint256 denom1 = totalToken1 == 0 ? 1 : totalToken1;
            uint256 share0 = (amount0 * totalShares) / denom0;
            uint256 share1 = (amount1 * totalShares) / denom1;
            shares = (share0 + share1) / 2;
        }
        if (shares == 0) revert ZeroShares();

        UserInfo storage info = userInfo[msg.sender];
        info.pendingRewards = _pendingReward(msg.sender);
        info.shares += shares;
        info.rewardDebt = (accRewardPerShare * info.shares) / REWARD_PRECISION;

        totalShares += shares;
        totalToken0 += amount0;
        totalToken1 += amount1;

        if (amount0 > 0) {
            if (!IERC20(token0).transferFrom(msg.sender, address(this), amount0)) revert TransferFailed();
        }
        if (amount1 > 0) {
            if (!IERC20(token1).transferFrom(msg.sender, address(this), amount1)) revert TransferFailed();
        }

        emit Deposit(msg.sender, amount0, amount1, shares);
    }

    function withdraw(
        uint256 shareAmount
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        UserInfo storage info = userInfo[msg.sender];
        if (shareAmount == 0) revert ZeroShares();
        if (shareAmount > info.shares) revert InsufficientBalance();

        _updateRewards();
        info.pendingRewards = _pendingReward(msg.sender);

        // Compute fees directly from the product to avoid divide-before-multiply precision loss
        uint256 fee0 = (shareAmount * totalToken0 * WITHDRAW_FEE_BPS) / (totalShares * BPS_DENOMINATOR);
        uint256 fee1 = (shareAmount * totalToken1 * WITHDRAW_FEE_BPS) / (totalShares * BPS_DENOMINATOR);

        uint256 grossAmount0 = (shareAmount * totalToken0) / totalShares;
        uint256 grossAmount1 = (shareAmount * totalToken1) / totalShares;

        amount0 = grossAmount0 - fee0;
        amount1 = grossAmount1 - fee1;

        info.shares -= shareAmount;
        totalShares -= shareAmount;
        totalToken0 -= grossAmount0;
        totalToken1 -= grossAmount1;

        info.rewardDebt = (accRewardPerShare * info.shares) / REWARD_PRECISION;

        if (amount0 > 0) {
            if (!IERC20(token0).transfer(msg.sender, amount0)) revert TransferFailed();
        }
        if (amount1 > 0) {
            if (!IERC20(token1).transfer(msg.sender, amount1)) revert TransferFailed();
        }

        emit Withdraw(msg.sender, amount0, amount1, shareAmount, fee0, fee1);
    }

    function claimRewards() external nonReentrant returns (uint256 claimed) {
        _updateRewards();
        UserInfo storage info = userInfo[msg.sender];
        claimed = _pendingReward(msg.sender);
        if (claimed == 0) revert NoPendingRewards();

        info.pendingRewards = 0;
        info.rewardDebt = (accRewardPerShare * info.shares) / REWARD_PRECISION;

        if (!IERC20(rewardToken).transfer(msg.sender, claimed)) revert TransferFailed();

        emit RewardPaid(msg.sender, claimed);
    }

    function setApprovedPool(address pool, bool approved) external onlyOperator {
        if (pool == address(0)) revert ZeroAddress();
        approvedPools[pool] = approved;
        emit PoolApproved(pool, approved);
    }

    function openPosition(
        address pool,
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) external onlyOperator nonReentrant returns (uint256 positionId) {
        if (!approvedPools[pool]) revert PoolNotApproved();
        if (positions.length >= MAX_POSITIONS) revert MaxPositionsReached();
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (amount0 == 0 && amount1 == 0) revert ZeroAmount();

        if (amount0 > totalToken0) revert InsufficientBalance();
        if (amount1 > totalToken1) revert InsufficientBalance();

        // Effects: update accounting before external interactions
        totalToken0 -= amount0;
        totalToken1 -= amount1;

        // Interactions
        if (amount0 > 0) {
            if (!IERC20(token0).approve(pool, amount0)) revert ApproveFailed();
        }
        if (amount1 > 0) {
            if (!IERC20(token1).approve(pool, amount1)) revert ApproveFailed();
        }

        uint128 liquidity;
        (positionId, liquidity) = IConcentratedLiquidityPool(pool).deposit(amount0, amount1, tickLower, tickUpper);

        positions.push(
            Position({
                pool: pool,
                positionId: positionId,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                active: true
            })
        );

        emit PositionOpened(positionId, pool, tickLower, tickUpper, liquidity);
        emit Rebalance(pool, tickLower, tickUpper, positionId);
    }

    function closePosition(
        uint256 index
    ) external onlyOperator nonReentrant returns (uint256 a0, uint256 a1) {
        if (index >= positions.length) revert InvalidIndex();
        Position memory pos = positions[index];
        if (!pos.active) revert PositionNotActive();

        // Effects: mark inactive and compact array before external call
        positions[index].active = false;
        positions[index] = positions[positions.length - 1];
        positions.pop();

        // Interactions
        (a0, a1) = IConcentratedLiquidityPool(pos.pool).withdraw(pos.positionId, pos.liquidity);

        totalToken0 += a0;
        totalToken1 += a1;

        emit PositionClosed(pos.positionId, a0, a1);
    }

    function collectPositionFees(
        uint256 index
    ) external onlyOperator nonReentrant returns (uint256 amt0, uint256 amt1) {
        if (index >= positions.length) revert InvalidIndex();
        Position storage pos = positions[index];
        if (!pos.active) revert PositionNotActive();

        (amt0, amt1) = IConcentratedLiquidityPool(pos.pool).collect(
            pos.positionId,
            address(this),
            type(uint256).max,
            type(uint256).max
        );

        totalToken0 += amt0;
        totalToken1 += amt1;

        emit RewardsCollected(index, amt0, amt1);
    }

    function updateStrategy(
        int24 tickLower,
        int24 tickUpper,
        uint256 rebalanceThresholdBps
    ) external onlyOperator {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (rebalanceThresholdBps == 0 || rebalanceThresholdBps > BPS_DENOMINATOR) revert InvalidThreshold();

        strategy.tickLower = tickLower;
        strategy.tickUpper = tickUpper;
        strategy.rebalanceThresholdBps = rebalanceThresholdBps;
        strategy.lastRebalance = block.timestamp;

        emit StrategyUpdated(tickLower, tickUpper, rebalanceThresholdBps);
    }

    function setRewardPerBlock(uint256 newRate) external onlyManager {
        _updateRewards();
        uint256 oldRate = rewardPerBlock;
        rewardPerBlock = newRate;
        emit RewardPerBlockUpdated(oldRate, newRate);
    }

    function setOperator(address newOperator) external onlyManager {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function transferManager(address newManager) external onlyManager {
        if (newManager == address(0)) revert ZeroAddress();
        address old = manager;
        manager = newManager;
        emit ManagerUpdated(old, newManager);
    }
}
