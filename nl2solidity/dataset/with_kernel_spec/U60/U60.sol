// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedExchange {
    error ZeroAddress();
    error IdenticalAddresses();
    error PairNotFound();
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error Unauthorized();
    error InvalidFeePercent();
    error InvalidTwapParams();
    error TwapOrderNotActive();
    error TwapIntervalNotElapsed();
    error TransferFailed();
    error SlippageExceeded();
    error NothingToCollect();
    error AmountTooLarge();
    error ReentrantCall();

    uint256 public constant SWAP_FEE_BPS = 30;
    uint256 public constant MAX_PROTOCOL_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 internal constant MAX_UINT112 = type(uint112).max;

    address public operator;
    uint256 public protocolFeePercent;

    struct Pair {
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint112 protocolFee0;
        uint112 protocolFee1;
        uint256 totalLiquidity;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
        uint32  blockTimestampLast;
    }

    struct TwapOrder {
        bytes32 pairId;
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountInPerInterval;
        uint256 amountInRemaining;
        uint256 amountOutReceived;
        uint32  intervalCount;
        uint32  intervalDuration;
        uint32  nextExecutionTime;
        uint32  intervalsExecuted;
        uint256 minAmountOutPerInterval;
        bool    active;
    }

    mapping(bytes32 => Pair) public pairs;
    mapping(bytes32 => mapping(address => uint256)) public liquidity;
    bytes32[] public allPairs;
    mapping(uint256 => TwapOrder) public twapOrders;
    uint256 public nextTwapOrderId;

    uint256 private _locked = 1;

    event PairCreated(bytes32 indexed pairId, address indexed token0, address indexed token1);
    event LiquidityAdded(
        address indexed provider,
        bytes32 indexed pairId,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted,
        uint256 totalLiquidity
    );
    event LiquidityRemoved(
        address indexed provider,
        bytes32 indexed pairId,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned,
        uint256 totalLiquidity
    );
    event Swap(
        bytes32 indexed pairId,
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 protocolFee,
        address to
    );
    event Sync(bytes32 indexed pairId, uint112 reserve0, uint112 reserve1);
    event ProtocolFeeUpdated(address indexed operator, uint256 oldPercent, uint256 newPercent);
    event ProtocolFeesCollected(bytes32 indexed pairId, address indexed collector, uint256 amount0, uint256 amount1);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event TwapOrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        bytes32 indexed pairId,
        address tokenIn,
        address tokenOut,
        uint256 totalAmountIn,
        uint32 intervalCount,
        uint32 intervalDuration
    );
    event TwapIntervalExecuted(uint256 indexed orderId, uint256 amountIn, uint256 amountOut);
    event TwapOrderCompleted(uint256 indexed orderId, uint256 totalAmountIn, uint256 totalAmountOut);
    event TwapOrderCancelled(uint256 indexed orderId, address indexed trader);

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 0;
        _;
        _locked = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _operator, uint256 _protocolFeePercent) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_protocolFeePercent > MAX_PROTOCOL_FEE_BPS) revert InvalidFeePercent();
        operator = _operator;
        protocolFeePercent = _protocolFeePercent;
        nextTwapOrderId = 1;
    }

    function setProtocolFeePercent(uint256 _newPercent) external onlyOperator {
        if (_newPercent > MAX_PROTOCOL_FEE_BPS) revert InvalidFeePercent();
        uint256 old = protocolFeePercent;
        protocolFeePercent = _newPercent;
        emit ProtocolFeeUpdated(msg.sender, old, _newPercent);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function pairId(address tokenA, address tokenB) public pure returns (bytes32) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        if (tokenA < tokenB) {
            return keccak256(abi.encodePacked(tokenA, tokenB));
        }
        return keccak256(abi.encodePacked(tokenB, tokenA));
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function _ensurePair(address tokenA, address tokenB) internal returns (Pair storage p, bytes32 id) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        id = pairId(tokenA, tokenB);
        p = pairs[id];
        if (p.token0 == address(0)) {
            (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
            p.token0 = t0;
            p.token1 = t1;
            p.blockTimestampLast = uint32(block.timestamp);
            allPairs.push(id);
            emit PairCreated(id, t0, t1);
        }
    }

    function _updatePriceOracle(bytes32 id, Pair storage p) internal {
        uint32 timeElapsed = uint32(block.timestamp) - p.blockTimestampLast;
        if (timeElapsed > 0 && p.reserve0 != 0 && p.reserve1 != 0) {
            unchecked {
                p.price0CumulativeLast += (uint256(p.reserve1) * PRICE_PRECISION / uint256(p.reserve0)) * timeElapsed;
                p.price1CumulativeLast += (uint256(p.reserve0) * PRICE_PRECISION / uint256(p.reserve1)) * timeElapsed;
            }
        }
        p.blockTimestampLast = uint32(block.timestamp);
        emit Sync(id, p.reserve0, p.reserve1);
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

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256)
    {
        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - SWAP_FEE_BPS);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * BPS_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    function _getProtocolFee(uint256 amountIn) internal view returns (uint256) {
        return (amountIn * SWAP_FEE_BPS * protocolFeePercent) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
    }

    function _applySwap(
        Pair storage p,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOut,
        uint256 protocolFee
    ) internal {
        if (zeroForOne) {
            p.reserve0 += uint112(amountIn - protocolFee);
            p.reserve1 -= uint112(amountOut);
            p.protocolFee0 += uint112(protocolFee);
        } else {
            p.reserve1 += uint112(amountIn - protocolFee);
            p.reserve0 -= uint112(amountOut);
            p.protocolFee1 += uint112(protocolFee);
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 minLiquidity
    ) external nonReentrant returns (uint256 liquidityMinted) {
        if (amountA == 0 || amountB == 0) revert InsufficientAmount();
        (Pair storage p, bytes32 id) = _ensurePair(tokenA, tokenB);

        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        liquidityMinted = _computeMinted(p, tokenA, amountA, amountB);
        if (liquidityMinted == 0) revert InsufficientLiquidityMinted();
        if (liquidityMinted < minLiquidity) revert InsufficientLiquidityMinted();

        liquidity[id][msg.sender] += liquidityMinted;
        p.totalLiquidity += liquidityMinted;

        _updatePriceOracle(id, p);

        emit LiquidityAdded(msg.sender, id, amountA, amountB, liquidityMinted, p.totalLiquidity);
    }

    function _computeMinted(
        Pair storage p,
        address tokenA,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 minted) {
        (uint256 amount0, uint256 amount1) = p.token0 == tokenA ? (amountA, amountB) : (amountB, amountA);
        if (amount0 > MAX_UINT112 || amount1 > MAX_UINT112) revert AmountTooLarge();

        if (p.totalLiquidity == 0) {
            minted = _sqrt(amount0 * amount1);
            if (minted < MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
            unchecked {
                minted -= MINIMUM_LIQUIDITY;
            }
            liquidity[pairId(p.token0, p.token1)][address(0)] = MINIMUM_LIQUIDITY;
            p.reserve0 = uint112(amount0);
            p.reserve1 = uint112(amount1);
        } else {
            uint256 minted0 = (amount0 * p.totalLiquidity) / p.reserve0;
            uint256 minted1 = (amount1 * p.totalLiquidity) / p.reserve1;
            minted = minted0 < minted1 ? minted0 : minted1;
            p.reserve0 += uint112(amount0);
            p.reserve1 += uint112(amount1);
        }
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 lpAmount,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        if (lpAmount == 0) revert InsufficientAmount();
        bytes32 id = pairId(tokenA, tokenB);
        Pair storage p = pairs[id];
        if (p.token0 == address(0)) revert PairNotFound();
        if (liquidity[id][msg.sender] < lpAmount) revert InsufficientLiquidityBurned();
        if (p.totalLiquidity < MINIMUM_LIQUIDITY) revert InsufficientLiquidityBurned();
        if (p.totalLiquidity - lpAmount < MINIMUM_LIQUIDITY) revert InsufficientLiquidityBurned();

        uint256 total = p.totalLiquidity;
        amount0 = (lpAmount * p.reserve0) / total;
        amount1 = (lpAmount * p.reserve1) / total;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        _checkSlippage(p, tokenA, amount0, amount1, amountAMin, amountBMin);

        liquidity[id][msg.sender] -= lpAmount;
        p.totalLiquidity -= lpAmount;
        p.reserve0 -= uint112(amount0);
        p.reserve1 -= uint112(amount1);

        _safeTransfer(p.token0, msg.sender, amount0);
        _safeTransfer(p.token1, msg.sender, amount1);

        _updatePriceOracle(id, p);

        emit LiquidityRemoved(msg.sender, id, amount0, amount1, lpAmount, p.totalLiquidity);
    }

    function _checkSlippage(
        Pair storage p,
        address tokenA,
        uint256 amount0,
        uint256 amount1,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal pure {
        if (p.token0 == tokenA) {
            if (amount0 < amountAMin || amount1 < amountBMin) revert InsufficientOutputAmount();
        } else {
            if (amount1 < amountAMin || amount0 < amountBMin) revert InsufficientOutputAmount();
        }
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (to == address(0)) revert ZeroAddress();
        if (tokenIn == tokenOut) revert IdenticalAddresses();
        if (amountIn > MAX_UINT112) revert AmountTooLarge();

        bytes32 id = pairId(tokenIn, tokenOut);
        Pair storage p = pairs[id];
        if (p.token0 == address(0)) revert PairNotFound();

        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

        bool zeroForOne = tokenIn == p.token0;
        (uint256 reserveIn, uint256 reserveOut) = _getReserves(p, zeroForOne);

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        uint256 protocolFee = _getProtocolFee(amountIn);

        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut > reserveOut) revert InsufficientLiquidity();
        if (amountOut < minAmountOut) revert SlippageExceeded();

        _applySwap(p, zeroForOne, amountIn, amountOut, protocolFee);

        _safeTransfer(tokenOut, to, amountOut);
        _updatePriceOracle(id, p);

        emit Swap(id, msg.sender, tokenIn, tokenOut, amountIn, amountOut, protocolFee, to);
    }

    function _getReserves(Pair storage p, bool zeroForOne)
        internal
        view
        returns (uint256 reserveIn, uint256 reserveOut)
    {
        if (zeroForOne) {
            return (uint256(p.reserve0), uint256(p.reserve1));
        }
        return (uint256(p.reserve1), uint256(p.reserve0));
    }

    function createTwapOrder(
        address tokenIn,
        address tokenOut,
        uint256 totalAmountIn,
        uint32 intervalCount,
        uint32 intervalDuration,
        uint256 minAmountOutPerInterval
    ) external nonReentrant returns (uint256 orderId) {
        if (totalAmountIn == 0) revert InsufficientAmount();
        if (tokenIn == tokenOut) revert IdenticalAddresses();
        if (intervalCount == 0 || intervalDuration == 0) revert InvalidTwapParams();
        if (totalAmountIn > MAX_UINT112) revert AmountTooLarge();
        if (totalAmountIn % uint256(intervalCount) != 0) revert InvalidTwapParams();

        bytes32 id = pairId(tokenIn, tokenOut);
        if (pairs[id].token0 == address(0)) revert PairNotFound();

        _safeTransferFrom(tokenIn, msg.sender, address(this), totalAmountIn);

        orderId = nextTwapOrderId++;
        twapOrders[orderId] = TwapOrder({
            pairId: id,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountInPerInterval: totalAmountIn / uint256(intervalCount),
            amountInRemaining: totalAmountIn,
            amountOutReceived: 0,
            intervalCount: intervalCount,
            intervalDuration: intervalDuration,
            nextExecutionTime: uint32(block.timestamp) + intervalDuration,
            intervalsExecuted: 0,
            minAmountOutPerInterval: minAmountOutPerInterval,
            active: true
        });

        emit TwapOrderCreated(
            orderId,
            msg.sender,
            id,
            tokenIn,
            tokenOut,
            totalAmountIn,
            intervalCount,
            intervalDuration
        );
    }

    function executeTwapInterval(uint256 orderId) external nonReentrant returns (uint256 amountOut) {
        TwapOrder storage o = twapOrders[orderId];
        if (!o.active) revert TwapOrderNotActive();
        if (block.timestamp < o.nextExecutionTime) revert TwapIntervalNotElapsed();

        bytes32 id = o.pairId;
        Pair storage p = pairs[id];
        if (p.token0 == address(0)) revert PairNotFound();

        uint256 amountIn = o.amountInPerInterval;
        bool zeroForOne = o.tokenIn == p.token0;
        (uint256 reserveIn, uint256 reserveOut) = _getReserves(p, zeroForOne);

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        uint256 protocolFee = _getProtocolFee(amountIn);

        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut > reserveOut) revert InsufficientLiquidity();
        if (amountOut < o.minAmountOutPerInterval) revert SlippageExceeded();

        _applySwap(p, zeroForOne, amountIn, amountOut, protocolFee);

        o.amountInRemaining -= amountIn;
        o.amountOutReceived += amountOut;
        o.intervalsExecuted += 1;
        o.nextExecutionTime += o.intervalDuration;

        _safeTransfer(o.tokenOut, o.trader, amountOut);
        _updatePriceOracle(id, p);

        emit TwapIntervalExecuted(orderId, amountIn, amountOut);
        emit Swap(id, msg.sender, o.tokenIn, o.tokenOut, amountIn, amountOut, protocolFee, o.trader);

        if (o.intervalsExecuted == o.intervalCount) {
            o.active = false;
            emit TwapOrderCompleted(
                orderId,
                o.amountInPerInterval * uint256(o.intervalCount),
                o.amountOutReceived
            );
        }
    }

    function cancelTwapOrder(uint256 orderId) external nonReentrant {
        TwapOrder storage o = twapOrders[orderId];
        if (o.trader != msg.sender) revert Unauthorized();
        if (!o.active) revert TwapOrderNotActive();
        o.active = false;
        uint256 refund = o.amountInRemaining;
        o.amountInRemaining = 0;
        if (refund > 0) {
            _safeTransfer(o.tokenIn, o.trader, refund);
        }
        emit TwapOrderCancelled(orderId, o.trader);
    }

    function collectProtocolFees(
        address tokenA,
        address tokenB,
        address recipient
    ) external onlyOperator returns (uint256 amount0, uint256 amount1) {
        if (recipient == address(0)) revert ZeroAddress();
        bytes32 id = pairId(tokenA, tokenB);
        Pair storage p = pairs[id];
        if (p.token0 == address(0)) revert PairNotFound();

        amount0 = p.protocolFee0;
        amount1 = p.protocolFee1;
        if (amount0 == 0 && amount1 == 0) revert NothingToCollect();

        p.protocolFee0 = 0;
        p.protocolFee1 = 0;

        if (amount0 > 0) _safeTransfer(p.token0, recipient, amount0);
        if (amount1 > 0) _safeTransfer(p.token1, recipient, amount1);

        emit ProtocolFeesCollected(id, recipient, amount0, amount1);
    }

    function getTwapOrder(uint256 orderId) external view returns (TwapOrder memory) {
        return twapOrders[orderId];
    }

    function getReserves(address tokenA, address tokenB)
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
    {
        bytes32 id = pairId(tokenA, tokenB);
        Pair storage p = pairs[id];
        return (p.reserve0, p.reserve1, p.blockTimestampLast);
    }

    function getProtocolFees(address tokenA, address tokenB)
        external
        view
        returns (uint112 fee0, uint112 fee1)
    {
        bytes32 id = pairId(tokenA, tokenB);
        Pair storage p = pairs[id];
        return (p.protocolFee0, p.protocolFee1);
    }

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address token0, address token1, uint256 totalLiquidity)
    {
        bytes32 id = pairId(tokenA, tokenB);
        Pair storage p = pairs[id];
        return (p.token0, p.token1, p.totalLiquidity);
    }
}
