// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library FullMath {
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                require(denominator > 0, "FullMath: divide by zero");
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            require(denominator > prod1, "FullMath: overflow");

            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }

            if (prod0 < remainder) {
                prod0 = prod0 - remainder;
                prod1 = prod1 - 1;
            } else {
                prod0 = prod0 - remainder;
            }

            uint256 twos = (0 - denominator) & denominator;
            assembly {
                denominator := div(denominator, twos)
            }
            assembly {
                prod0 := div(prod0, twos)
            }

            prod0 = prod0 + (prod1 & (twos - 1)) * ((type(uint256).max / twos) + 1);

            uint256 inv = (3 * denominator) ^ 2;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;

            assembly {
                result := mul(prod0, inv)
            }
        }
    }
}

contract ConcentratedLiquidityManager {
    uint24 public constant MIN_FEE_BPS = 1;
    uint24 public constant MAX_FEE_BPS = 100;
    uint24 public constant PROTOCOL_FEE_BPS = 25;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_TICK_RANGES = 100;
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = 887272;
    uint256 private constant Q128 = 1 << 128;
    uint256 private constant Q96 = 1 << 96;

    struct Pair {
        address token0;
        address token1;
        uint24 fee;
        uint256 reserve0;
        uint256 reserve1;
        uint256 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint256 protocolFees0;
        uint256 protocolFees1;
    }

    struct TickRange {
        int24 tickLower;
        int24 tickUpper;
        uint256 liquidity;
    }

    struct Position {
        address owner;
        uint256 pairId;
        uint256 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        TickRange[] ticks;
    }

    struct PairView {
        address token0;
        address token1;
        uint24 fee;
        uint256 reserve0;
        uint256 reserve1;
        uint256 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint256 protocolFees0;
        uint256 protocolFees1;
    }

    struct PositionView {
        address owner;
        uint256 pairId;
        uint256 liquidity;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        uint256 tickCount;
    }

    address public owner;
    address public operator;
    address public implementation;
    bool public paused;

    uint256 public nextPairId = 1;
    uint256 public nextPositionId = 1;

    mapping(uint256 => Pair) public pairs;
    mapping(address => mapping(address => mapping(uint24 => uint256))) public pairIdByTokensFee;
    mapping(uint256 => Position) private _positions;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event Upgraded(address indexed oldImplementation, address indexed newImplementation);

    event PairAdded(uint256 indexed pairId, address indexed token0, address indexed token1, uint24 fee);
    event FeeUpdated(uint256 indexed pairId, uint24 oldFee, uint24 newFee);

    event PositionCreated(uint256 indexed positionId, address indexed owner, uint256 indexed pairId, uint256 tickCount);
    event LiquidityAdded(uint256 indexed positionId, address indexed owner, uint256 tickIndex, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(uint256 indexed positionId, address indexed owner, uint256 tickIndex, uint256 amount0, uint256 amount1, uint256 liquidity);
    event FeesCollected(uint256 indexed positionId, address indexed recipient, uint256 amount0, uint256 amount1, uint256 protocolFee0, uint256 protocolFee1);
    event Swap(uint256 indexed pairId, address indexed sender, address indexed recipient, bool zeroForOne, uint256 amountIn, uint256 amountOut, uint256 fee);
    event ProtocolFeesWithdrawn(uint256 indexed pairId, address indexed to, uint256 amount0, uint256 amount1);

    error Unauthorized();
    error ZeroAddress();
    error ContractPaused();
    error PairNotFound();
    error PairAlreadyExists();
    error InvalidFeeTier();
    error InvalidTokens();
    error InvalidTickRange();
    error TickRangeLimitExceeded();
    error DuplicateTickRange();
    error PositionNotFound();
    error NotPositionOwner();
    error ZeroLiquidity();
    error InsufficientLiquidity();
    error InsufficientAmount();
    error SlippageExceeded();
    error InvalidSwapAmount();
    error TransferFailed();
    error Reentrancy();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        implementation = address(this);
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function upgradeImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        emit Upgraded(implementation, newImplementation);
        implementation = newImplementation;
    }

    function withdrawProtocolFees(uint256 pairId) external onlyOwner {
        Pair storage pair = pairs[pairId];
        if (pair.token0 == address(0)) revert PairNotFound();
        uint256 amt0 = pair.protocolFees0;
        uint256 amt1 = pair.protocolFees1;
        pair.protocolFees0 = 0;
        pair.protocolFees1 = 0;
        if (amt0 > 0) _safeTransfer(pair.token0, owner, amt0);
        if (amt1 > 0) _safeTransfer(pair.token1, owner, amt1);
        emit ProtocolFeesWithdrawn(pairId, owner, amt0, amt1);
    }

    function addPair(address tokenA, address tokenB, uint24 fee) external onlyOperator returns (uint256 pairId) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert InvalidTokens();
        if (fee < MIN_FEE_BPS || fee > MAX_FEE_BPS) revert InvalidFeeTier();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (pairIdByTokensFee[token0][token1][fee] != 0) revert PairAlreadyExists();

        pairId = nextPairId++;
        pairs[pairId] = Pair({
            token0: token0,
            token1: token1,
            fee: fee,
            reserve0: 0,
            reserve1: 0,
            liquidity: 0,
            feeGrowthGlobal0X128: 0,
            feeGrowthGlobal1X128: 0,
            protocolFees0: 0,
            protocolFees1: 0
        });
        pairIdByTokensFee[token0][token1][fee] = pairId;

        emit PairAdded(pairId, token0, token1, fee);
    }

    function setPairFee(uint256 pairId, uint24 newFee) external onlyOperator {
        Pair storage pair = pairs[pairId];
        if (pair.token0 == address(0)) revert PairNotFound();
        if (newFee < MIN_FEE_BPS || newFee > MAX_FEE_BPS) revert InvalidFeeTier();
        uint24 oldFee = pair.fee;
        pair.fee = newFee;
        emit FeeUpdated(pairId, oldFee, newFee);
    }

    function createPosition(uint256 pairId, int24[] calldata tickLowers, int24[] calldata tickUppers)
        external whenNotPaused nonReentrant returns (uint256 positionId)
    {
        Pair storage pair = pairs[pairId];
        if (pair.token0 == address(0)) revert PairNotFound();
        if (tickLowers.length != tickUppers.length) revert InvalidTickRange();
        if (tickLowers.length == 0 || tickLowers.length > MAX_TICK_RANGES) revert TickRangeLimitExceeded();

        positionId = nextPositionId++;
        Position storage pos = _positions[positionId];
        pos.owner = msg.sender;
        pos.pairId = pairId;
        pos.feeGrowthInside0LastX128 = pair.feeGrowthGlobal0X128;
        pos.feeGrowthInside1LastX128 = pair.feeGrowthGlobal1X128;

        for (uint256 i = 0; i < tickLowers.length; i++) {
            _validateTickRange(tickLowers[i], tickUppers[i]);
            for (uint256 j = 0; j < i; j++) {
                if (tickLowers[i] == tickLowers[j] && tickUppers[i] == tickUppers[j]) revert DuplicateTickRange();
            }
            pos.ticks.push(TickRange({tickLower: tickLowers[i], tickUpper: tickUppers[i], liquidity: 0}));
        }

        emit PositionCreated(positionId, msg.sender, pairId, tickLowers.length);
    }

    function addLiquidity(
        uint256 positionId,
        uint256 tickIndex,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external whenNotPaused nonReentrant returns (uint256 liquidity, uint256 amount0, uint256 amount1) {
        if (amount0Desired == 0 || amount1Desired == 0) revert InsufficientAmount();

        Position storage pos = _positions[positionId];
        if (pos.owner == address(0)) revert PositionNotFound();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (tickIndex >= pos.ticks.length) revert InvalidTickRange();

        Pair storage pair = pairs[pos.pairId];
        if (pair.token0 == address(0)) revert PairNotFound();

        if (pair.liquidity == 0) {
            if (pair.reserve0 != 0 || pair.reserve1 != 0) revert InsufficientLiquidity();
            if (amount1Desired > type(uint256).max / amount0Desired) revert InsufficientAmount();
            liquidity = _sqrt(amount0Desired * amount1Desired);
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 liq0 = FullMath.mulDiv(amount0Desired, pair.liquidity, pair.reserve0);
            uint256 liq1 = FullMath.mulDiv(amount1Desired, pair.liquidity, pair.reserve1);
            liquidity = liq0 < liq1 ? liq0 : liq1;
            amount0 = FullMath.mulDiv(liquidity, pair.reserve0, pair.liquidity);
            amount1 = FullMath.mulDiv(liquidity, pair.reserve1, pair.liquidity);
        }

        if (amount0 < amount0Min || amount1 < amount1Min) revert SlippageExceeded();
        if (amount0 > amount0Desired || amount1 > amount1Desired) revert SlippageExceeded();

        _accrueFees(pos, pair);

        pos.ticks[tickIndex].liquidity += liquidity;
        pos.liquidity += liquidity;
        pair.liquidity += liquidity;
        pair.reserve0 += amount0;
        pair.reserve1 += amount1;

        _safeTransferFrom(pair.token0, msg.sender, address(this), amount0);
        _safeTransferFrom(pair.token1, msg.sender, address(this), amount1);

        emit LiquidityAdded(positionId, msg.sender, tickIndex, amount0, amount1, liquidity);
    }

    function removeLiquidity(uint256 positionId, uint256 tickIndex, uint256 liquidityDelta)
        external whenNotPaused nonReentrant returns (uint256 amount0, uint256 amount1)
    {
        if (liquidityDelta == 0) revert ZeroLiquidity();

        Position storage pos = _positions[positionId];
        if (pos.owner == address(0)) revert PositionNotFound();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (tickIndex >= pos.ticks.length) revert InvalidTickRange();

        TickRange storage tr = pos.ticks[tickIndex];
        if (tr.liquidity < liquidityDelta) revert InsufficientLiquidity();

        Pair storage pair = pairs[pos.pairId];
        if (pair.token0 == address(0)) revert PairNotFound();
        if (pair.liquidity == 0) revert InsufficientLiquidity();

        amount0 = FullMath.mulDiv(liquidityDelta, pair.reserve0, pair.liquidity);
        amount1 = FullMath.mulDiv(liquidityDelta, pair.reserve1, pair.liquidity);

        _accrueFees(pos, pair);

        tr.liquidity -= liquidityDelta;
        pos.liquidity -= liquidityDelta;
        pair.liquidity -= liquidityDelta;
        pair.reserve0 -= amount0;
        pair.reserve1 -= amount1;

        _safeTransfer(pair.token0, msg.sender, amount0);
        _safeTransfer(pair.token1, msg.sender, amount1);

        emit LiquidityRemoved(positionId, msg.sender, tickIndex, amount0, amount1, liquidityDelta);
    }

    function collectFees(uint256 positionId, address recipient)
        external whenNotPaused nonReentrant returns (uint256 amount0, uint256 amount1)
    {
        if (recipient == address(0)) revert ZeroAddress();

        Position storage pos = _positions[positionId];
        if (pos.owner == address(0)) revert PositionNotFound();
        if (pos.owner != msg.sender) revert NotPositionOwner();

        Pair storage pair = pairs[pos.pairId];
        if (pair.token0 == address(0)) revert PairNotFound();

        _accrueFees(pos, pair);

        amount0 = pos.tokensOwed0;
        amount1 = pos.tokensOwed1;
        if (amount0 == 0 && amount1 == 0) revert InsufficientAmount();

        uint256 protocolFee0 = FullMath.mulDiv(amount0, PROTOCOL_FEE_BPS, BPS_DENOMINATOR);
        uint256 protocolFee1 = FullMath.mulDiv(amount1, PROTOCOL_FEE_BPS, BPS_DENOMINATOR);
        uint256 payout0 = amount0 - protocolFee0;
        uint256 payout1 = amount1 - protocolFee1;

        pos.tokensOwed0 = 0;
        pos.tokensOwed1 = 0;
        unchecked {
            pair.protocolFees0 += protocolFee0;
            pair.protocolFees1 += protocolFee1;
        }

        if (payout0 > 0) _safeTransfer(pair.token0, recipient, payout0);
        if (payout1 > 0) _safeTransfer(pair.token1, recipient, payout1);

        emit FeesCollected(positionId, recipient, payout0, payout1, protocolFee0, protocolFee1);
    }

    function swap(
        uint256 pairId,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidSwapAmount();
        if (recipient == address(0)) revert ZeroAddress();

        Pair storage pair = pairs[pairId];
        if (pair.token0 == address(0)) revert PairNotFound();
        if (pair.liquidity == 0) revert InsufficientLiquidity();

        (uint256 reserveIn, uint256 reserveOut) = zeroForOne
            ? (pair.reserve0, pair.reserve1)
            : (pair.reserve1, pair.reserve0);

        uint256 fee = FullMath.mulDiv(amountIn, pair.fee, BPS_DENOMINATOR);
        uint256 amountInAfterFee = amountIn - fee;
        if (amountInAfterFee == 0) revert InvalidSwapAmount();

        uint256 denominator = reserveIn + amountInAfterFee;
        amountOut = FullMath.mulDiv(amountInAfterFee, reserveOut, denominator);
        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();
        if (amountOut < minAmountOut) revert SlippageExceeded();

        if (zeroForOne) {
            pair.reserve0 = pair.reserve0 + amountInAfterFee;
            pair.reserve1 = pair.reserve1 - amountOut;
            unchecked {
                pair.feeGrowthGlobal0X128 += FullMath.mulDiv(fee, Q128, pair.liquidity);
            }
        } else {
            pair.reserve1 = pair.reserve1 + amountInAfterFee;
            pair.reserve0 = pair.reserve0 - amountOut;
            unchecked {
                pair.feeGrowthGlobal1X128 += FullMath.mulDiv(fee, Q128, pair.liquidity);
            }
        }

        address tokenIn = zeroForOne ? pair.token0 : pair.token1;
        address tokenOut = zeroForOne ? pair.token1 : pair.token0;
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, recipient, amountOut);

        emit Swap(pairId, msg.sender, recipient, zeroForOne, amountIn, amountOut, fee);
    }

    function getPairId(address tokenA, address tokenB, uint24 fee) external view returns (uint256) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return pairIdByTokensFee[token0][token1][fee];
    }

    function getPair(uint256 pairId) external view returns (PairView memory) {
        Pair storage p = pairs[pairId];
        return PairView({
            token0: p.token0,
            token1: p.token1,
            fee: p.fee,
            reserve0: p.reserve0,
            reserve1: p.reserve1,
            liquidity: p.liquidity,
            feeGrowthGlobal0X128: p.feeGrowthGlobal0X128,
            feeGrowthGlobal1X128: p.feeGrowthGlobal1X128,
            protocolFees0: p.protocolFees0,
            protocolFees1: p.protocolFees1
        });
    }

    function getPosition(uint256 positionId) external view returns (PositionView memory) {
        Position storage pos = _positions[positionId];
        return PositionView({
            owner: pos.owner,
            pairId: pos.pairId,
            liquidity: pos.liquidity,
            tokensOwed0: pos.tokensOwed0,
            tokensOwed1: pos.tokensOwed1,
            tickCount: pos.ticks.length
        });
    }

    function getTickRange(uint256 positionId, uint256 index) external view returns (
        int24 tickLower, int24 tickUpper, uint256 liquidity
    ) {
        Position storage pos = _positions[positionId];
        if (index >= pos.ticks.length) revert InvalidTickRange();
        TickRange storage tr = pos.ticks[index];
        return (tr.tickLower, tr.tickUpper, tr.liquidity);
    }

    function getSqrtPriceX96(uint256 pairId) external view returns (uint256) {
        Pair storage p = pairs[pairId];
        if (p.token0 == address(0) || p.reserve0 == 0) return 0;
        return (_sqrt(p.reserve1) * Q96) / _sqrt(p.reserve0);
    }

    function totalProtocolFees(uint256 pairId) external view returns (uint256, uint256) {
        Pair storage p = pairs[pairId];
        return (p.protocolFees0, p.protocolFees1);
    }

    function _validateTickRange(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (tickLower < MIN_TICK || tickLower > MAX_TICK) revert InvalidTickRange();
        if (tickUpper < MIN_TICK || tickUpper > MAX_TICK) revert InvalidTickRange();
    }

    function _accrueFees(Position storage pos, Pair storage pair) internal {
        if (pos.liquidity == 0) {
            pos.feeGrowthInside0LastX128 = pair.feeGrowthGlobal0X128;
            pos.feeGrowthInside1LastX128 = pair.feeGrowthGlobal1X128;
            return;
        }
        unchecked {
            uint256 growth0 = pair.feeGrowthGlobal0X128 - pos.feeGrowthInside0LastX128;
            uint256 growth1 = pair.feeGrowthGlobal1X128 - pos.feeGrowthInside1LastX128;
            if (growth0 > 0) {
                pos.tokensOwed0 += FullMath.mulDiv(growth0, pos.liquidity, Q128);
            }
            if (growth1 > 0) {
                pos.tokensOwed1 += FullMath.mulDiv(growth1, pos.liquidity, Q128);
            }
        }
        pos.feeGrowthInside0LastX128 = pair.feeGrowthGlobal0X128;
        pos.feeGrowthInside1LastX128 = pair.feeGrowthGlobal1X128;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
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
