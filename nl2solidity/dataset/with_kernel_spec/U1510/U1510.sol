// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDEXToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeDEXToken {
    function safeTransfer(IDEXToken token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IDEXToken token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IDEXToken token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeDEXToken: low-level call failed");
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeDEXToken: ERC20 operation did not succeed");
        }
    }
}

contract DecentralizedExchange {
    using SafeDEXToken for IDEXToken;

    error NotAdmin();
    error PairNotSupported();
    error PairAlreadyExists();
    error PairPaused();
    error PairHasLiquidity();
    error InsufficientLiquidity();
    error InvalidAmount();
    error SlippageExceeded();
    error InsufficientLiquidityMinted();
    error ZeroAddress();
    error IdenticalAddresses();
    error InsufficientBalance();
    error MinTradeSizeNotMet();
    error ReentrantCall();

    struct Pair {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        bool paused;
        bool exists;
    }

    mapping(bytes32 => Pair) public pairs;
    mapping(bytes32 => mapping(address => uint256)) public liquidityBalances;

    address public admin;
    uint256 public feeRate; // in basis points, default 30 (0.3%)
    uint256 public minTradeSize; // default 100

    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    event PairAdded(address indexed token0, address indexed token1, bytes32 indexed pairId);
    event PairRemoved(address indexed token0, address indexed token1, bytes32 indexed pairId);
    event PairPausedToggled(address indexed token0, address indexed token1, bytes32 indexed pairId, bool paused);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event MinTradeSizeUpdated(uint256 oldMin, uint256 newMin);
    event LiquidityAdded(
        address indexed provider,
        bytes32 indexed pairId,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        bytes32 indexed pairId,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    event Swap(
        address indexed sender,
        bytes32 indexed pairId,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

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
        feeRate = 30; // 0.3%
        minTradeSize = 100;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    function _getPairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return keccak256(abi.encodePacked(token0, token1));
    }

    function addPair(address tokenA, address tokenB) external onlyAdmin {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _getPairId(token0, token1);
        if (pairs[pairId].exists) revert PairAlreadyExists();
        pairs[pairId] = Pair({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            totalLiquidity: 0,
            paused: false,
            exists: true
        });
        emit PairAdded(token0, token1, pairId);
    }

    function removePair(address tokenA, address tokenB) external onlyAdmin {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _getPairId(token0, token1);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        if (pair.totalLiquidity > 0) revert PairHasLiquidity();
        delete pairs[pairId];
        emit PairRemoved(token0, token1, pairId);
    }

    function pausePair(address tokenA, address tokenB) external onlyAdmin {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        pair.paused = true;
        emit PairPausedToggled(pair.token0, pair.token1, pairId, true);
    }

    function unpausePair(address tokenA, address tokenB) external onlyAdmin {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        pair.paused = false;
        emit PairPausedToggled(pair.token0, pair.token1, pairId, false);
    }

    function setFee(uint256 newFee) external onlyAdmin {
        if (newFee > 1000) revert InvalidAmount(); // cap at 10%
        emit FeeUpdated(feeRate, newFee);
        feeRate = newFee;
    }

    function setMinTradeSize(uint256 newMin) external onlyAdmin {
        emit MinTradeSizeUpdated(minTradeSize, newMin);
        minTradeSize = newMin;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant returns (uint256 liquidity) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _getPairId(token0, token1);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        if (pair.paused) revert PairPaused();
        if (amountA == 0 || amountB == 0) revert InvalidAmount();

        (uint256 amount0, uint256 amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);

        if (pair.totalLiquidity == 0) {
            liquidity = _sqrt(amount0 * amount1);
            if (liquidity < MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
            // permanently lock minimum liquidity
            liquidity -= MINIMUM_LIQUIDITY;
            pair.totalLiquidity += MINIMUM_LIQUIDITY;
        } else {
            uint256 liq0 = (amount0 * pair.totalLiquidity) / pair.reserve0;
            uint256 liq1 = (amount1 * pair.totalLiquidity) / pair.reserve1;
            liquidity = liq0 < liq1 ? liq0 : liq1;
        }
        if (liquidity == 0) revert InsufficientLiquidityMinted();

        // Effects: update state before interactions
        pair.reserve0 += amount0;
        pair.reserve1 += amount1;
        pair.totalLiquidity += liquidity;
        liquidityBalances[pairId][msg.sender] += liquidity;

        // Interactions
        IDEXToken(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IDEXToken(token1).safeTransferFrom(msg.sender, address(this), amount1);

        emit LiquidityAdded(msg.sender, pairId, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _getPairId(token0, token1);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        if (liquidity == 0) revert InvalidAmount();
        if (liquidityBalances[pairId][msg.sender] < liquidity) revert InsufficientBalance();

        amount0 = (liquidity * pair.reserve0) / pair.totalLiquidity;
        amount1 = (liquidity * pair.reserve1) / pair.totalLiquidity;
        if (amount0 == 0 && amount1 == 0) revert InvalidAmount();

        // Effects
        liquidityBalances[pairId][msg.sender] -= liquidity;
        pair.totalLiquidity -= liquidity;
        pair.reserve0 -= amount0;
        pair.reserve1 -= amount1;

        // Interactions
        IDEXToken(token0).safeTransfer(msg.sender, amount0);
        IDEXToken(token1).safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, pairId, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        if (tokenIn == tokenOut) revert IdenticalAddresses();
        if (amountIn < minTradeSize) revert MinTradeSizeNotMet();

        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        bytes32 pairId = _getPairId(token0, token1);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        if (pair.paused) revert PairPaused();

        bool isToken0In = tokenIn == pair.token0;
        (uint256 reserveIn, uint256 reserveOut) = isToken0In
            ? (pair.reserve0, pair.reserve1)
            : (pair.reserve1, pair.reserve0);

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        // Effects: update state before interactions
        if (isToken0In) {
            pair.reserve0 += amountIn;
            pair.reserve1 -= amountOut;
        } else {
            pair.reserve1 += amountIn;
            pair.reserve0 -= amountOut;
        }

        // Interactions
        IDEXToken(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IDEXToken(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, pairId, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public view returns (uint256) {
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    function getPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        bytes32 pairId = _getPairId(token0, token1);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        (uint256 reserveIn, uint256 reserveOut) = tokenIn == pair.token0
            ? (pair.reserve0, pair.reserve1)
            : (pair.reserve1, pair.reserve0);
        return getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getReserves(
        address tokenA,
        address tokenB
    ) external view returns (uint256 reserve0, uint256 reserve1) {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        Pair storage pair = pairs[pairId];
        if (!pair.exists) revert PairNotSupported();
        return (pair.reserve0, pair.reserve1);
    }

    function getLiquidity(
        address tokenA,
        address tokenB,
        address provider
    ) external view returns (uint256) {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        return liquidityBalances[pairId][provider];
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
