// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ConcentratedLiquidityManager {
    uint256 public constant MAX_BINS_PER_POOL = 100;
    uint256 public constant DEFAULT_FEE_BPS = 5; // 0.05%
    uint256 public constant MAX_FEE_BPS = 1000;  // 10%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant FEE_PRECISION = 1e18;

    struct Bin {
        uint256 reserve0;
        uint256 reserve1;
        uint256 feeGrowth0;
        uint256 feeGrowth1;
        bool active;
    }

    struct Pool {
        address token0;
        address token1;
        uint256 basePrice;
        uint256 binWidthBps;
        uint256 feeBps;
        uint256 activeBinIndex;
        uint256 activeBinCount;
        uint256 reserve0;
        uint256 reserve1;
        bool initialized;
        bool paused;
    }

    struct UserBinPosition {
        uint256 liquidity0;
        uint256 liquidity1;
        uint256 feeGrowth0Last;
        uint256 feeGrowth1Last;
    }

    struct Position {
        uint256 totalLiquidity0;
        uint256 totalLiquidity1;
        uint256[] binIndices;
        mapping(uint256 => UserBinPosition) bins;
        bool exists;
    }

    event PoolCreated(uint256 indexed poolId, address indexed token0, address indexed token1, uint256 basePrice, uint256 binWidthBps);
    event Deposit(address indexed user, uint256 indexed poolId, uint256[] binIndices, uint256 amount0, uint256 amount1);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256[] binIndices, uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1);
    event Swap(address indexed user, uint256 indexed poolId, bool zeroForOne, uint256 amountIn, uint256 amountOut);
    event PoolPaused(uint256 indexed poolId, bool paused);
    event FeeTierUpdated(uint256 indexed poolId, uint256 newFeeBps);
    event BinWidthUpdated(uint256 indexed poolId, uint256 newBinWidthBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error PoolNotFound();
    error PoolPausedError();
    error InvalidPrice();
    error InvalidBinWidth();
    error InvalidFeeTier();
    error MaxBinsExceeded();
    error BinInactive();
    error LengthMismatch();
    error ZeroAmount();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error Unauthorized();
    error NothingToWithdraw();

    address public owner;
    address public operator;
    uint256 public nextPoolId;

    mapping(uint256 => Pool) private _pools;
    mapping(uint256 => mapping(uint256 => Bin)) private _bins;
    mapping(address => mapping(uint256 => Position)) private _positions;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier poolExists(uint256 poolId) {
        if (!_pools[poolId].initialized) revert PoolNotFound();
        _;
    }

    modifier notPaused(uint256 poolId) {
        if (_pools[poolId].paused) revert PoolPausedError();
        _;
    }

    constructor() {
        owner = msg.sender;
        operator = msg.sender;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function createPool(
        address token0,
        address token1,
        uint256 basePrice,
        uint256 binWidthBps
    ) external onlyOperator returns (uint256 poolId) {
        if (token0 == address(0) || token1 == address(0)) revert ZeroAddress();
        if (token0 == token1) revert ZeroAddress();
        if (basePrice == 0) revert InvalidPrice();
        if (binWidthBps == 0 || binWidthBps > 5000) revert InvalidBinWidth();

        poolId = nextPoolId++;
        Pool storage p = _pools[poolId];
        p.token0 = token0;
        p.token1 = token1;
        p.basePrice = basePrice;
        p.binWidthBps = binWidthBps;
        p.feeBps = DEFAULT_FEE_BPS;
        p.activeBinIndex = 50;
        p.initialized = true;

        emit PoolCreated(poolId, token0, token1, basePrice, binWidthBps);
    }

    function deposit(
        uint256 poolId,
        uint256[] calldata binIndices,
        uint256[] calldata amounts0,
        uint256[] calldata amounts1
    ) external poolExists(poolId) notPaused(poolId) {
        if (binIndices.length != amounts0.length || binIndices.length != amounts1.length) revert LengthMismatch();
        if (binIndices.length == 0) revert ZeroAmount();

        Pool storage pool = _pools[poolId];
        Position storage pos = _positions[msg.sender][poolId];
        if (!pos.exists) {
            pos.exists = true;
        }

        uint256 total0;
        uint256 total1;

        for (uint256 i = 0; i < binIndices.length; i++) {
            uint256 binIndex = binIndices[i];
            if (binIndex >= MAX_BINS_PER_POOL) revert MaxBinsExceeded();
            uint256 a0 = amounts0[i];
            uint256 a1 = amounts1[i];
            if (a0 == 0 && a1 == 0) revert ZeroAmount();

            Bin storage b = _bins[poolId][binIndex];
            if (!b.active) {
                if (pool.activeBinCount >= MAX_BINS_PER_POOL) revert MaxBinsExceeded();
                b.active = true;
                pool.activeBinCount += 1;
            }

            UserBinPosition storage ubp = pos.bins[binIndex];
            _harvestFees(b, ubp);

            b.reserve0 += a0;
            b.reserve1 += a1;
            ubp.liquidity0 += a0;
            ubp.liquidity1 += a1;
            ubp.feeGrowth0Last = b.feeGrowth0;
            ubp.feeGrowth1Last = b.feeGrowth1;

            if (!_positionHasBin(pos, binIndex)) {
                pos.binIndices.push(binIndex);
            }

            total0 += a0;
            total1 += a1;
        }

        pos.totalLiquidity0 += total0;
        pos.totalLiquidity1 += total1;
        pool.reserve0 += total0;
        pool.reserve1 += total1;

        if (total0 > 0) {
            _safeTransferFrom(pool.token0, msg.sender, address(this), total0);
        }
        if (total1 > 0) {
            _safeTransferFrom(pool.token1, msg.sender, address(this), total1);
        }

        emit Deposit(msg.sender, poolId, binIndices, total0, total1);
    }

    function withdraw(
        uint256 poolId,
        uint256[] calldata binIndices,
        uint256[] calldata amounts0,
        uint256[] calldata amounts1
    ) external poolExists(poolId) notPaused(poolId) {
        if (binIndices.length != amounts0.length || binIndices.length != amounts1.length) revert LengthMismatch();
        if (binIndices.length == 0) revert ZeroAmount();

        Pool storage pool = _pools[poolId];
        Position storage pos = _positions[msg.sender][poolId];
        if (!pos.exists) revert NothingToWithdraw();

        uint256 total0;
        uint256 total1;
        uint256 fee0;
        uint256 fee1;

        for (uint256 i = 0; i < binIndices.length; i++) {
            uint256 binIndex = binIndices[i];
            uint256 w0 = amounts0[i];
            uint256 w1 = amounts1[i];
            if (w0 == 0 && w1 == 0) revert ZeroAmount();

            Bin storage b = _bins[poolId][binIndex];
            if (!b.active) revert BinInactive();

            UserBinPosition storage ubp = pos.bins[binIndex];
            if (w0 > ubp.liquidity0 || w1 > ubp.liquidity1) revert InsufficientLiquidity();

            (uint256 f0, uint256 f1) = _harvestFees(b, ubp);
            fee0 += f0;
            fee1 += f1;

            b.reserve0 -= w0;
            b.reserve1 -= w1;
            ubp.liquidity0 -= w0;
            ubp.liquidity1 -= w1;
            ubp.feeGrowth0Last = b.feeGrowth0;
            ubp.feeGrowth1Last = b.feeGrowth1;

            if (ubp.liquidity0 == 0 && ubp.liquidity1 == 0) {
                if (b.reserve0 == 0 && b.reserve1 == 0) {
                    b.active = false;
                    pool.activeBinCount -= 1;
                }
            }

            total0 += w0;
            total1 += w1;
        }

        pos.totalLiquidity0 -= total0;
        pos.totalLiquidity1 -= total1;
        pool.reserve0 -= total0;
        pool.reserve1 -= total1;

        uint256 send0 = total0 + fee0;
        uint256 send1 = total1 + fee1;

        if (send0 > 0) {
            _safeTransfer(pool.token0, msg.sender, send0);
        }
        if (send1 > 0) {
            _safeTransfer(pool.token1, msg.sender, send1);
        }

        emit Withdraw(msg.sender, poolId, binIndices, total0, total1, fee0, fee1);
    }

    function swap(
        uint256 poolId,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut
    ) external poolExists(poolId) notPaused(poolId) returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        Pool storage pool = _pools[poolId];

        uint256 fee = (amountIn * pool.feeBps) / BPS_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;

        address inToken = zeroForOne ? pool.token0 : pool.token1;
        address outToken = zeroForOne ? pool.token1 : pool.token0;

        _safeTransferFrom(inToken, msg.sender, address(this), amountIn);

        uint256 accumulatedOut = _traverseBins(poolId, pool, amountInAfterFee, zeroForOne);

        amountOut = accumulatedOut;
        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (amountOut == 0) revert InsufficientLiquidity();

        _distributeFee(poolId, pool, fee, zeroForOne);

        if (zeroForOne) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        _safeTransfer(outToken, msg.sender, amountOut);

        emit Swap(msg.sender, poolId, zeroForOne, amountIn, amountOut);
    }

    function setFeeTier(uint256 poolId, uint256 newFeeBps) external onlyOperator poolExists(poolId) {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFeeTier();
        _pools[poolId].feeBps = newFeeBps;
        emit FeeTierUpdated(poolId, newFeeBps);
    }

    function setBinWidth(uint256 poolId, uint256 newBinWidthBps) external onlyOperator poolExists(poolId) {
        if (newBinWidthBps == 0 || newBinWidthBps > 5000) revert InvalidBinWidth();
        _pools[poolId].binWidthBps = newBinWidthBps;
        emit BinWidthUpdated(poolId, newBinWidthBps);
    }

    function pausePool(uint256 poolId, bool paused) external onlyOperator poolExists(poolId) {
        _pools[poolId].paused = paused;
        emit PoolPaused(poolId, paused);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        _safeTransfer(token, to, amount);
        emit TokenRescued(token, to, amount);
    }

    // ============ View functions ============

    function getPoolToken0(uint256 poolId) external view poolExists(poolId) returns (address) {
        return _pools[poolId].token0;
    }

    function getPoolToken1(uint256 poolId) external view poolExists(poolId) returns (address) {
        return _pools[poolId].token1;
    }

    function getPoolPrice(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return _pools[poolId].basePrice;
    }

    function getPoolBinWidth(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return _pools[poolId].binWidthBps;
    }

    function getPoolFee(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return _pools[poolId].feeBps;
    }

    function getPoolActiveBin(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return _pools[poolId].activeBinIndex;
    }

    function getPoolActiveCount(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return _pools[poolId].activeBinCount;
    }

    function getPoolReserves(uint256 poolId) external view poolExists(poolId) returns (uint256, uint256) {
        Pool storage p = _pools[poolId];
        return (p.reserve0, p.reserve1);
    }

    function getPoolPaused(uint256 poolId) external view poolExists(poolId) returns (bool) {
        return _pools[poolId].paused;
    }

    function getBin(uint256 poolId, uint256 binIndex) external view returns (uint256, uint256, uint256, uint256, bool) {
        Bin storage b = _bins[poolId][binIndex];
        return (b.reserve0, b.reserve1, b.feeGrowth0, b.feeGrowth1, b.active);
    }

    function getPosition(address user, uint256 poolId) external view returns (uint256, uint256, uint256[] memory) {
        Position storage pos = _positions[user][poolId];
        return (pos.totalLiquidity0, pos.totalLiquidity1, pos.binIndices);
    }

    function getUserBin(address user, uint256 poolId, uint256 binIndex) external view returns (uint256, uint256, uint256, uint256) {
        UserBinPosition storage ubp = _positions[user][poolId].bins[binIndex];
        return (ubp.liquidity0, ubp.liquidity1, ubp.feeGrowth0Last, ubp.feeGrowth1Last);
    }

    function pendingFees(address user, uint256 poolId, uint256 binIndex) external view returns (uint256 fee0, uint256 fee1) {
        UserBinPosition storage ubp = _positions[user][poolId].bins[binIndex];
        Bin storage b = _bins[poolId][binIndex];
        if (ubp.liquidity0 > 0) {
            fee0 = ((b.feeGrowth0 - ubp.feeGrowth0Last) * ubp.liquidity0) / FEE_PRECISION;
        }
        if (ubp.liquidity1 > 0) {
            fee1 = ((b.feeGrowth1 - ubp.feeGrowth1Last) * ubp.liquidity1) / FEE_PRECISION;
        }
    }

    // ============ Internal helpers ============

    function _positionHasBin(Position storage pos, uint256 binIndex) internal view returns (bool) {
        uint256[] storage arr = pos.binIndices;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == binIndex) return true;
        }
        return false;
    }

    function _harvestFees(Bin storage b, UserBinPosition storage ubp) internal returns (uint256 fee0, uint256 fee1) {
        if (ubp.liquidity0 > 0 && b.feeGrowth0 > ubp.feeGrowth0Last) {
            fee0 = ((b.feeGrowth0 - ubp.feeGrowth0Last) * ubp.liquidity0) / FEE_PRECISION;
        }
        if (ubp.liquidity1 > 0 && b.feeGrowth1 > ubp.feeGrowth1Last) {
            fee1 = ((b.feeGrowth1 - ubp.feeGrowth1Last) * ubp.liquidity1) / FEE_PRECISION;
        }
        ubp.feeGrowth0Last = b.feeGrowth0;
        ubp.feeGrowth1Last = b.feeGrowth1;
    }

    function _traverseBins(
        uint256 poolId,
        Pool storage pool,
        uint256 remainingInput,
        bool zeroForOne
    ) internal returns (uint256 accumulatedOut) {
        uint256 remaining = remainingInput;
        uint256 cursor = pool.activeBinIndex;

        for (uint256 step = 0; step < MAX_BINS_PER_POOL && remaining > 0; step++) {
            if (cursor >= MAX_BINS_PER_POOL) break;
            Bin storage b = _bins[poolId][cursor];
            if (b.active) {
                uint256 out = _swapWithinBin(pool, b, remaining, zeroForOne);
                if (out > 0) {
                    accumulatedOut += out;
                    uint256 consumed = _inputConsumedForOut(pool, out, zeroForOne);
                    remaining = remaining > consumed ? remaining - consumed : 0;
                    if (b.reserve0 == 0 && b.reserve1 == 0) {
                        b.active = false;
                        pool.activeBinCount -= 1;
                    } else {
                        pool.activeBinIndex = cursor;
                    }
                }
            }
            if (remaining == 0) break;
            if (zeroForOne) {
                if (cursor == 0) break;
                cursor -= 1;
            } else {
                cursor += 1;
            }
        }
    }

    function _swapWithinBin(
        Pool storage pool,
        Bin storage b,
        uint256 remainingInput,
        bool zeroForOne
    ) internal returns (uint256 out) {
        uint256 binPrice = _binPrice(pool, pool.activeBinIndex);
        if (zeroForOne) {
            uint256 possibleOut = (remainingInput * binPrice) / PRICE_PRECISION;
            if (possibleOut > b.reserve1) {
                out = b.reserve1;
                b.reserve1 = 0;
                uint256 consumed = (out * PRICE_PRECISION) / binPrice;
                b.reserve0 += consumed;
            } else {
                out = possibleOut;
                b.reserve1 -= out;
                b.reserve0 += remainingInput;
            }
        } else {
            uint256 possibleOut = (remainingInput * PRICE_PRECISION) / binPrice;
            if (possibleOut > b.reserve0) {
                out = b.reserve0;
                b.reserve0 = 0;
                uint256 consumed = (out * binPrice) / PRICE_PRECISION;
                b.reserve1 += consumed;
            } else {
                out = possibleOut;
                b.reserve0 -= out;
                b.reserve1 += remainingInput;
            }
        }
    }

    function _inputConsumedForOut(
        Pool storage pool,
        uint256 out,
        bool zeroForOne
    ) internal view returns (uint256 consumed) {
        uint256 binPrice = _binPrice(pool, pool.activeBinIndex);
        if (zeroForOne) {
            consumed = (out * PRICE_PRECISION) / binPrice;
        } else {
            consumed = (out * binPrice) / PRICE_PRECISION;
        }
    }

    function _binPrice(Pool storage pool, uint256 binIndex) internal view returns (uint256 price) {
        price = pool.basePrice;
        uint256 factor = BPS_DENOMINATOR + pool.binWidthBps;
        if (binIndex >= pool.activeBinIndex) {
            for (uint256 i = 0; i < binIndex - pool.activeBinIndex; i++) {
                price = (price * factor) / BPS_DENOMINATOR;
            }
        } else {
            for (uint256 i = 0; i < pool.activeBinIndex - binIndex; i++) {
                price = (price * BPS_DENOMINATOR) / factor;
            }
        }
    }

    function _distributeFee(uint256 poolId, Pool storage pool, uint256 fee, bool zeroForOne) internal {
        if (fee == 0) return;
        uint256 totalOpposite = _totalOpposite(poolId, zeroForOne);
        if (totalOpposite == 0) return;

        for (uint256 i = 0; i < MAX_BINS_PER_POOL; i++) {
            Bin storage b = _bins[poolId][i];
            if (!b.active) continue;
            uint256 share = zeroForOne ? b.reserve1 : b.reserve0;
            if (share == 0) continue;
            uint256 binFee = (fee * share) / totalOpposite;
            if (binFee == 0) continue;
            if (zeroForOne) {
                if (b.reserve1 > 0) {
                    b.feeGrowth1 += (binFee * FEE_PRECISION) / b.reserve1;
                }
            } else {
                if (b.reserve0 > 0) {
                    b.feeGrowth0 += (binFee * FEE_PRECISION) / b.reserve0;
                }
            }
        }
    }

    function _totalOpposite(uint256 poolId, bool zeroForOne) internal view returns (uint256 total) {
        for (uint256 i = 0; i < MAX_BINS_PER_POOL; i++) {
            Bin storage b = _bins[poolId][i];
            if (!b.active) continue;
            if (zeroForOne) {
                total += b.reserve1;
            } else {
                total += b.reserve0;
            }
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM_FAILED");
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
}
