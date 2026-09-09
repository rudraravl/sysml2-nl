// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ConcentratedLiquidityManager {
    error Unauthorized();
    error ZeroAddress();
    error TokensMustDiffer();
    error TokensMustBeOrdered();
    error PoolAlreadyExists();
    error PoolNotFound();
    error MaxFeeTiersExceeded();
    error FeeTierAlreadyExists();
    error InvalidFeeRate();
    error InvalidTicks();
    error InvalidActiveTick();
    error ZeroDeposit();
    error InsufficientLiquidity();
    error InvalidLiquidityToRemove();
    error NoFeesToClaim();
    error InvalidMaxFeeTiers();
    error InsufficientBalance();
    error TransferFailed();
    error ReentrantCall();

    uint256 public constant PROTOCOL_FEE_BPS = 5;
    uint256 private constant BPS_DENOM = 10000;
    uint256 private constant Q128 = 2 ** 128;
    uint256 public constant MAX_FEE_TIERS_HARD_CAP = 5;
    uint24 public constant MAX_FEE_RATE = 1_000_000;
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = 887272;

    struct Position {
        address owner;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 fee0Owed;
        uint256 fee1Owed;
    }

    struct Pool {
        bool initialized;
        int24 activeTick;
        uint128 totalLiquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
    }

    address public owner;
    address public operator;
    uint256 public maxFeeTiersPerPair;
    uint24 public baseFeeRate;

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => uint24[]) public pairFeeTiers;
    mapping(bytes32 => mapping(uint24 => bool)) public pairHasFeeTier;

    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId = 1;

    mapping(address => uint256) public protocolFeesAccrued;

    uint256 private _status = 1;

    event PoolCreated(address indexed token0, address indexed token1, uint24 indexed fee, int24 activeTick);
    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        uint128 liquidity
    );
    event LiquidityAdded(uint256 indexed positionId, uint256 amount0, uint256 amount1, uint128 liquidityAdded);
    event LiquidityRemoved(
        uint256 indexed positionId,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint128 liquidityRemoved,
        uint256 protocolFee0,
        uint256 protocolFee1
    );
    event FeesClaimed(uint256 indexed positionId, address indexed recipient, uint256 fee0, uint256 fee1);
    event FeesDistributed(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        uint256 amount0,
        uint256 amount1
    );
    event MaxFeeTiersPerPairUpdated(uint256 oldMax, uint256 newMax);
    event BaseFeeRateUpdated(uint24 oldRate, uint24 newRate);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event ProtocolFeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier onlyPositionOwner(uint256 positionId) {
        if (positions[positionId].owner != msg.sender) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status != 1) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address operator_) {
        if (operator_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = operator_;
        maxFeeTiersPerPair = MAX_FEE_TIERS_HARD_CAP;
        baseFeeRate = 3000;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), operator_);
        emit MaxFeeTiersPerPairUpdated(0, maxFeeTiersPerPair);
        emit BaseFeeRateUpdated(0, baseFeeRate);
    }

    function _pairKey(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        if (tokenA == tokenB) revert TokensMustDiffer();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    function _validateTicks(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert InvalidTicks();
        if (tickLower < MIN_TICK || tickUpper > MAX_TICK) revert InvalidTicks();
    }

    function _poolId(address token0, address token1, uint24 fee) internal pure returns (bytes32) {
        return keccak256(abi.encode(_pairKey(token0, token1), fee));
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 r = x;
        uint256 z = (x + 1) >> 1;
        while (z < r) {
            r = z;
            z = (x / z + z) >> 1;
        }
        return r;
    }

    function _computeLiquidity(uint256 amount0, uint256 amount1) internal pure returns (uint128) {
        if (amount0 == 0 && amount1 == 0) return 0;
        uint256 liq;
        if (amount0 == 0) {
            liq = amount1;
        } else if (amount1 == 0) {
            liq = amount0;
        } else {
            liq = _sqrt(amount0 * amount1);
        }
        if (liq > type(uint128).max) liq = type(uint128).max;
        return uint128(liq);
    }

    function _updatePositionFees(Position storage pos, Pool storage pool) internal {
        if (pos.liquidity == 0) {
            pos.feeGrowthInside0LastX128 = pool.feeGrowthGlobal0X128;
            pos.feeGrowthInside1LastX128 = pool.feeGrowthGlobal1X128;
            return;
        }
        uint256 delta0 = pool.feeGrowthGlobal0X128 - pos.feeGrowthInside0LastX128;
        uint256 delta1 = pool.feeGrowthGlobal1X128 - pos.feeGrowthInside1LastX128;
        if (delta0 > 0) {
            pos.fee0Owed += (uint256(pos.liquidity) * delta0) / Q128;
        }
        if (delta1 > 0) {
            pos.fee1Owed += (uint256(pos.liquidity) * delta1) / Q128;
        }
        pos.feeGrowthInside0LastX128 = pool.feeGrowthGlobal0X128;
        pos.feeGrowthInside1LastX128 = pool.feeGrowthGlobal1X128;
    }

    function _transferIn(address token, address from, uint256 amount) internal {
        if (amount == 0) return;
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        if (!IERC20(token).transferFrom(from, address(this), amount)) revert TransferFailed();
        if (IERC20(token).balanceOf(address(this)) < balBefore + amount) revert TransferFailed();
    }

    function _transferOut(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        if (balBefore < amount) revert InsufficientBalance();
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        if (IERC20(token).balanceOf(address(this)) > balBefore - amount) revert TransferFailed();
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        int24 activeTick
    ) external nonReentrant returns (bytes32 poolKey) {
        if (fee < baseFeeRate || fee > MAX_FEE_RATE) revert InvalidFeeRate();
        if (activeTick < MIN_TICK || activeTick > MAX_TICK) revert InvalidActiveTick();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        poolKey = _pairKey(token0, token1);
        if (pairHasFeeTier[poolKey][fee]) revert FeeTierAlreadyExists();
        if (pairFeeTiers[poolKey].length >= maxFeeTiersPerPair) revert MaxFeeTiersExceeded();
        bytes32 poolId = _poolId(token0, token1, fee);
        if (pools[poolId].initialized) revert PoolAlreadyExists();

        pairFeeTiers[poolKey].push(fee);
        pairHasFeeTier[poolKey][fee] = true;

        Pool storage pool = pools[poolId];
        pool.initialized = true;
        pool.activeTick = activeTick;
        pool.totalLiquidity = 0;
        pool.feeGrowthGlobal0X128 = 0;
        pool.feeGrowthGlobal1X128 = 0;

        emit PoolCreated(token0, token1, fee, activeTick);
    }

    function deposit(
        address tokenA,
        address tokenB,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external nonReentrant returns (uint256 positionId) {
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroDeposit();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        _validateTicks(tickLower, tickUpper);
        Pool storage pool = pools[_poolId(token0, token1, fee)];
        if (!pool.initialized) revert PoolNotFound();

        _transferIn(token0, msg.sender, amount0Desired);
        _transferIn(token1, msg.sender, amount1Desired);

        uint128 liquidity = _computeLiquidity(amount0Desired, amount1Desired);
        if (liquidity == 0) revert ZeroDeposit();

        positionId = nextPositionId++;
        Position storage pos = positions[positionId];
        pos.owner = msg.sender;
        pos.token0 = token0;
        pos.token1 = token1;
        pos.fee = fee;
        pos.tickLower = tickLower;
        pos.tickUpper = tickUpper;
        pos.liquidity = liquidity;
        pos.amount0 = amount0Desired;
        pos.amount1 = amount1Desired;
        pos.feeGrowthInside0LastX128 = pool.feeGrowthGlobal0X128;
        pos.feeGrowthInside1LastX128 = pool.feeGrowthGlobal1X128;

        pool.totalLiquidity += liquidity;

        emit PositionCreated(
            positionId,
            msg.sender,
            token0,
            token1,
            fee,
            tickLower,
            tickUpper,
            amount0Desired,
            amount1Desired,
            liquidity
        );
    }

    function addLiquidity(
        uint256 positionId,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external onlyPositionOwner(positionId) nonReentrant {
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroDeposit();
        Position storage pos = positions[positionId];
        Pool storage pool = pools[_poolId(pos.token0, pos.token1, pos.fee)];
        if (!pool.initialized) revert PoolNotFound();

        _updatePositionFees(pos, pool);

        _transferIn(pos.token0, msg.sender, amount0Desired);
        _transferIn(pos.token1, msg.sender, amount1Desired);

        uint128 liquidityAdded = _computeLiquidity(amount0Desired, amount1Desired);
        if (liquidityAdded == 0) revert ZeroDeposit();

        pos.amount0 += amount0Desired;
        pos.amount1 += amount1Desired;
        pos.liquidity += liquidityAdded;
        pool.totalLiquidity += liquidityAdded;

        emit LiquidityAdded(positionId, amount0Desired, amount1Desired, liquidityAdded);
    }

    function removeLiquidity(uint256 positionId, uint128 liquidityToRemove)
        external
        onlyPositionOwner(positionId)
        nonReentrant
    {
        if (liquidityToRemove == 0) revert InvalidLiquidityToRemove();
        Position storage pos = positions[positionId];
        if (liquidityToRemove > pos.liquidity) revert InsufficientLiquidity();
        Pool storage pool = pools[_poolId(pos.token0, pos.token1, pos.fee)];
        if (!pool.initialized) revert PoolNotFound();

        _updatePositionFees(pos, pool);

        uint256 amount0ToRemove = (pos.amount0 * uint256(liquidityToRemove)) / uint256(pos.liquidity);
        uint256 amount1ToRemove = (pos.amount1 * uint256(liquidityToRemove)) / uint256(pos.liquidity);

        uint256 protocolFee0 = (amount0ToRemove * PROTOCOL_FEE_BPS) / BPS_DENOM;
        uint256 protocolFee1 = (amount1ToRemove * PROTOCOL_FEE_BPS) / BPS_DENOM;

        pos.amount0 -= amount0ToRemove;
        pos.amount1 -= amount1ToRemove;
        pos.liquidity -= liquidityToRemove;
        pool.totalLiquidity -= liquidityToRemove;
        protocolFeesAccrued[pos.token0] += protocolFee0;
        protocolFeesAccrued[pos.token1] += protocolFee1;

        _transferOut(pos.token0, msg.sender, amount0ToRemove - protocolFee0);
        _transferOut(pos.token1, msg.sender, amount1ToRemove - protocolFee1);

        emit LiquidityRemoved(
            positionId,
            msg.sender,
            amount0ToRemove,
            amount1ToRemove,
            liquidityToRemove,
            protocolFee0,
            protocolFee1
        );
    }

    function claimFees(uint256 positionId) external onlyPositionOwner(positionId) nonReentrant {
        Position storage pos = positions[positionId];
        Pool storage pool = pools[_poolId(pos.token0, pos.token1, pos.fee)];
        if (!pool.initialized) revert PoolNotFound();

        _updatePositionFees(pos, pool);

        uint256 fee0 = pos.fee0Owed;
        uint256 fee1 = pos.fee1Owed;
        if (fee0 == 0 && fee1 == 0) revert NoFeesToClaim();

        pos.fee0Owed = 0;
        pos.fee1Owed = 0;

        _transferOut(pos.token0, msg.sender, fee0);
        _transferOut(pos.token1, msg.sender, fee1);

        emit FeesClaimed(positionId, msg.sender, fee0, fee1);
    }

    function distributeFees(
        address token0,
        address token1,
        uint24 fee,
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant {
        if (token0 >= token1) revert TokensMustBeOrdered();
        bytes32 poolKey = _pairKey(token0, token1);
        if (!pairHasFeeTier[poolKey][fee]) revert PoolNotFound();
        Pool storage pool = pools[_poolId(token0, token1, fee)];
        if (pool.totalLiquidity == 0) revert InsufficientLiquidity();

        _transferIn(token0, msg.sender, amount0);
        _transferIn(token1, msg.sender, amount1);

        if (amount0 > 0) {
            pool.feeGrowthGlobal0X128 += (amount0 * Q128) / pool.totalLiquidity;
        }
        if (amount1 > 0) {
            pool.feeGrowthGlobal1X128 += (amount1 * Q128) / pool.totalLiquidity;
        }

        emit FeesDistributed(token0, token1, fee, amount0, amount1);
    }

    function setMaxFeeTiersPerPair(uint256 newMax) external onlyOperator {
        if (newMax == 0 || newMax > MAX_FEE_TIERS_HARD_CAP) revert InvalidMaxFeeTiers();
        uint256 oldMax = maxFeeTiersPerPair;
        maxFeeTiersPerPair = newMax;
        emit MaxFeeTiersPerPairUpdated(oldMax, newMax);
    }

    function setBaseFeeRate(uint24 newRate) external onlyOperator {
        if (newRate > MAX_FEE_RATE) revert InvalidFeeRate();
        uint24 oldRate = baseFeeRate;
        baseFeeRate = newRate;
        emit BaseFeeRateUpdated(oldRate, newRate);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function withdrawProtocolFees(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        uint256 accrued = protocolFeesAccrued[token];
        if (amount > accrued) revert InsufficientBalance();
        protocolFeesAccrued[token] = accrued - amount;
        _transferOut(token, to, amount);
        emit ProtocolFeesWithdrawn(token, to, amount);
    }

    function getPool(address token0, address token1, uint24 fee)
        external
        view
        returns (Pool memory)
    {
        return pools[_poolId(token0, token1, fee)];
    }

    function getPairFeeTiers(address token0, address token1)
        external
        view
        returns (uint24[] memory)
    {
        return pairFeeTiers[_pairKey(token0, token1)];
    }

    function pairFeeTierCount(address token0, address token1) external view returns (uint256) {
        return pairFeeTiers[_pairKey(token0, token1)].length;
    }

    function isPoolInitialized(address token0, address token1, uint24 fee) external view returns (bool) {
        return pools[_poolId(token0, token1, fee)].initialized;
    }
}
