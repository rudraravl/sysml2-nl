// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedExchange {
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint24 feeRate;
        uint256 fee0Accrued;
        uint256 fee1Accrued;
        uint256 feeGrowth0;
        uint256 feeGrowth1;
        uint256 totalLiquidity;
        bool initialized;
    }

    struct Position {
        address owner;
        address token0;
        address token1;
        uint256 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 lowerPrice;
        uint256 upperPrice;
        uint256 feeGrowth0Last;
        uint256 feeGrowth1Last;
        uint256 fee0Owed;
        uint256 fee1Owed;
    }

    error OnlyOperator();
    error OnlyPositionOwner();
    error InvalidAddress();
    error InvalidTokens();
    error InvalidPriceRange();
    error InvalidAmount();
    error InvalidPosition(uint256 positionId);
    error PoolNotInitialized();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InsufficientLiquidityMinted();
    error FeeTooHigh();
    error Reentrancy();
    error TransferFailed();

    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity,
        uint256 lowerPrice,
        uint256 upperPrice
    );

    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event LiquidityWithdrawn(
        uint256 indexed positionId,
        uint256 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    event FeesCollected(
        uint256 indexed positionId,
        uint256 amount0,
        uint256 amount1
    );

    event FeeUpdated(
        address indexed token0,
        address indexed token1,
        uint24 oldFee,
        uint24 newFee
    );

    event OperatorUpdated(address indexed newOperator);

    uint256 public constant Q = 1e18;
    uint24 public constant DEFAULT_FEE = 5;
    uint24 public constant MAX_FEE = 100;

    address public operator;
    uint256 public nextPositionId;
    mapping(bytes32 => Pool) public pools;
    mapping(uint256 => Position) public positions;

    uint256 private _status;

    modifier nonReentrant() {
        if (_status == 2) revert Reentrancy();
        _status = 2;
        _;
        _status = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    constructor() {
        operator = msg.sender;
        nextPositionId = 1;
        _status = 1;
    }

    function _sortTokens(address a, address b) internal pure returns (address t0, address t1) {
        if (a == b) revert InvalidTokens();
        if (a < b) {
            (t0, t1) = (a, b);
        } else {
            (t0, t1) = (b, a);
        }
    }

    function _poolId(address t0, address t1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(t0, t1));
    }

    function _getPool(address a, address b) internal view returns (Pool storage pool) {
        if (a == b) revert InvalidTokens();
        pool = pools[a < b ? _poolId(a, b) : _poolId(b, a)];
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) >> 1;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) >> 1;
        }
        return y;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _accumulateFees(Position storage p, Pool storage pool) internal {
        if (p.liquidity > 0) {
            uint256 owed0 = (pool.feeGrowth0 - p.feeGrowth0Last) * p.liquidity / Q;
            uint256 owed1 = (pool.feeGrowth1 - p.feeGrowth1Last) * p.liquidity / Q;
            p.fee0Owed += owed0;
            p.fee1Owed += owed1;
        }
        p.feeGrowth0Last = pool.feeGrowth0;
        p.feeGrowth1Last = pool.feeGrowth1;
    }

    function _calcShares(Pool storage pool, uint256 amount0, uint256 amount1) internal view returns (uint256 shares) {
        if (pool.totalLiquidity == 0) {
            shares = _sqrt(amount0 * amount1);
        } else {
            uint256 s0 = amount0 * pool.totalLiquidity / pool.reserve0;
            uint256 s1 = amount1 * pool.totalLiquidity / pool.reserve1;
            shares = s0 < s1 ? s0 : s1;
        }
    }

    function _reducePositionAmounts(Position storage p, uint256 withdrawnLiquidity) internal {
        if (p.liquidity == 0) {
            p.amount0 = 0;
            p.amount1 = 0;
        } else {
            uint256 ratio = withdrawnLiquidity * Q / (withdrawnLiquidity + p.liquidity);
            p.amount0 -= p.amount0 * ratio / Q;
            p.amount1 -= p.amount1 * ratio / Q;
        }
    }

    function deposit(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 lowerPrice,
        uint256 upperPrice
    ) external nonReentrant returns (uint256 positionId) {
        if (amountA == 0 || amountB == 0) revert InvalidAmount();
        if (lowerPrice == 0 || lowerPrice >= upperPrice) revert InvalidPriceRange();

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        (uint256 amount0, uint256 amount1) = token0 == tokenA
            ? (amountA, amountB)
            : (amountB, amountA);

        Pool storage pool = pools[_poolId(token0, token1)];
        if (!pool.initialized) {
            pool.token0 = token0;
            pool.token1 = token1;
            pool.feeRate = DEFAULT_FEE;
            pool.initialized = true;
        }

        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        uint256 shares = _calcShares(pool, amount0, amount1);
        if (shares == 0) revert InsufficientLiquidityMinted();

        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += shares;

        positionId = nextPositionId++;
        Position storage pos = positions[positionId];
        pos.owner = msg.sender;
        pos.token0 = token0;
        pos.token1 = token1;
        pos.liquidity = shares;
        pos.amount0 = amount0;
        pos.amount1 = amount1;
        pos.lowerPrice = lowerPrice;
        pos.upperPrice = upperPrice;
        pos.feeGrowth0Last = pool.feeGrowth0;
        pos.feeGrowth1Last = pool.feeGrowth1;

        emit PositionCreated(
            positionId,
            msg.sender,
            token0,
            token1,
            amount0,
            amount1,
            shares,
            lowerPrice,
            upperPrice
        );
    }

    function withdraw(uint256 positionId, uint256 liquidity)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage p = positions[positionId];
        if (p.owner == address(0)) revert InvalidPosition(positionId);
        if (msg.sender != p.owner) revert OnlyPositionOwner();
        if (liquidity == 0 || liquidity > p.liquidity) revert InvalidAmount();

        Pool storage pool = pools[_poolId(p.token0, p.token1)];
        if (pool.totalLiquidity == 0) revert InsufficientLiquidity();

        _accumulateFees(p, pool);

        uint256 fee0 = p.fee0Owed;
        uint256 fee1 = p.fee1Owed;
        p.fee0Owed = 0;
        p.fee1Owed = 0;
        if (fee0 > 0) pool.fee0Accrued -= fee0;
        if (fee1 > 0) pool.fee1Accrued -= fee1;

        amount0 = pool.reserve0 * liquidity / pool.totalLiquidity;
        amount1 = pool.reserve1 * liquidity / pool.totalLiquidity;

        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalLiquidity -= liquidity;
        p.liquidity -= liquidity;

        _reducePositionAmounts(p, liquidity);

        _safeTransfer(p.token0, msg.sender, amount0 + fee0);
        _safeTransfer(p.token1, msg.sender, amount1 + fee1);

        emit LiquidityWithdrawn(positionId, liquidity, amount0, amount1);
        if (fee0 > 0 || fee1 > 0) {
            emit FeesCollected(positionId, fee0, fee1);
        }
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();

        Pool storage pool = _getPool(tokenIn, tokenOut);
        if (!pool.initialized || pool.reserve0 == 0 || pool.reserve1 == 0) {
            revert PoolNotInitialized();
        }

        bool zeroForOne = tokenIn == pool.token0;
        uint256 fee = amountIn * pool.feeRate / 10000;
        uint256 amountInNet = amountIn - fee;

        if (zeroForOne) {
            amountOut = pool.reserve1 * amountInNet / (pool.reserve0 + amountInNet);
            if (amountOut > pool.reserve1) revert InsufficientLiquidity();
        } else {
            amountOut = pool.reserve0 * amountInNet / (pool.reserve1 + amountInNet);
            if (amountOut > pool.reserve0) revert InsufficientLiquidity();
        }
        if (amountOut < amountOutMin) revert InsufficientOutputAmount();

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

        if (zeroForOne) {
            pool.reserve0 += amountInNet;
            pool.reserve1 -= amountOut;
            pool.fee0Accrued += fee;
            if (pool.totalLiquidity > 0) {
                pool.feeGrowth0 += fee * Q / pool.totalLiquidity;
            }
        } else {
            pool.reserve1 += amountInNet;
            pool.reserve0 -= amountOut;
            pool.fee1Accrued += fee;
            if (pool.totalLiquidity > 0) {
                pool.feeGrowth1 += fee * Q / pool.totalLiquidity;
            }
        }

        _safeTransfer(tokenOut, msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function collectFees(uint256 positionId)
        external
        nonReentrant
        returns (uint256 fee0, uint256 fee1)
    {
        Position storage p = positions[positionId];
        if (p.owner == address(0)) revert InvalidPosition(positionId);
        if (msg.sender != p.owner) revert OnlyPositionOwner();

        Pool storage pool = pools[_poolId(p.token0, p.token1)];

        _accumulateFees(p, pool);

        fee0 = p.fee0Owed;
        fee1 = p.fee1Owed;
        p.fee0Owed = 0;
        p.fee1Owed = 0;

        if (fee0 > 0) {
            pool.fee0Accrued -= fee0;
            _safeTransfer(p.token0, msg.sender, fee0);
        }
        if (fee1 > 0) {
            pool.fee1Accrued -= fee1;
            _safeTransfer(p.token1, msg.sender, fee1);
        }

        emit FeesCollected(positionId, fee0, fee1);
    }

    function setFee(address token0, address token1, uint24 newFee)
        external
        onlyOperator
        returns (uint24 oldFee)
    {
        if (newFee > MAX_FEE) revert FeeTooHigh();
        Pool storage pool = _getPool(token0, token1);
        if (!pool.initialized) revert PoolNotInitialized();

        oldFee = pool.feeRate;
        pool.feeRate = newFee;

        emit FeeUpdated(pool.token0, pool.token1, oldFee, newFee);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function getPool(address token0, address token1) external view returns (Pool memory) {
        (address t0, address t1) = _sortTokens(token0, token1);
        return pools[_poolId(t0, t1)];
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }
}
