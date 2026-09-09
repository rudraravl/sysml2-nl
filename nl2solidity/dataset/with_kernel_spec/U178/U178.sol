// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract RealAssetDEX {
    using SafeERC20 for IERC20;

    error Unauthorized();
    error ZeroAddress();
    error TokenNotApproved();
    error TokenAlreadyApproved();
    error IdenticalAddresses();
    error PairExists();
    error PairDoesNotExist();
    error MaxPairsReached();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error InsufficientInitialLiquidity();
    error FeeOutOfRange();
    error ZeroAmount();
    error SlippageExceeded();
    error TradingPaused();
    error AlreadyPaused();
    error NotPaused();

    uint256 public constant MAX_PAIRS = 100;
    uint256 public constant MIN_INITIAL_LIQUIDITY = 100;
    uint16  public constant MIN_FEE  = 5;
    uint16  public constant MAX_FEE  = 50;
    uint256 private constant FEE_DENOMINATOR = 10000;

    struct Pair {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        uint16  fee;
        bool    exists;
    }

    address public owner;
    address public operator;
    address public governanceToken;
    bool    public paused;

    mapping(address => bool) public approvedTokens;
    mapping(address => mapping(address => uint256)) public balances;

    mapping(bytes32 => Pair) public pairs;
    mapping(bytes32 => mapping(address => uint256)) public lpBalances;
    mapping(address => mapping(address => bytes32)) public pairIdByTokens;
    bytes32[] public allPairIds;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TokenApproved(address indexed token);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);
    event PairCreated(address indexed token0, address indexed token1, bytes32 pairId, uint256 amount0, uint256 amount1, uint16 fee, address indexed creator);
    event LiquidityAdded(address indexed provider, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event PairFeeUpdated(address indexed token0, address indexed token1, uint16 newFee);
    event Paused(address indexed account);
    event Unpaused(address indexed account);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    constructor(address _governanceToken, address _operator) {
        if (_governanceToken == address(0) || _operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        governanceToken = _governanceToken;
        approvedTokens[_governanceToken] = true;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit TokenApproved(_governanceToken);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorUpdated(prev, newOperator);
    }

    function approveToken(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (approvedTokens[token]) revert TokenAlreadyApproved();
        approvedTokens[token] = true;
        emit TokenApproved(token);
    }

    function setPairFee(address tokenA, address tokenB, uint16 newFee) external onlyOperator {
        if (newFee < MIN_FEE || newFee > MAX_FEE) revert FeeOutOfRange();
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _pairId(t0, t1);
        Pair storage p = pairs[pairId];
        if (!p.exists) revert PairDoesNotExist();
        p.fee = newFee;
        emit PairFeeUpdated(t0, t1, newFee);
    }

    function pause() external onlyOperator {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function deposit(address token, uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (!approvedTokens[token]) revert TokenNotApproved();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (!approvedTokens[token]) revert TokenNotApproved();
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();
        balances[msg.sender][token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, token, amount);
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint16  fee
    ) external whenNotPaused returns (bytes32 pairId) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        if (!approvedTokens[tokenA] || !approvedTokens[tokenB]) revert TokenNotApproved();
        if (fee < MIN_FEE || fee > MAX_FEE) revert FeeOutOfRange();
        if (amountA < MIN_INITIAL_LIQUIDITY || amountB < MIN_INITIAL_LIQUIDITY) revert InsufficientInitialLiquidity();
        if (allPairIds.length >= MAX_PAIRS) revert MaxPairsReached();

        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        pairId = _pairId(t0, t1);
        if (pairs[pairId].exists) revert PairExists();

        (uint256 amount0, uint256 amount1) = tokenA == t0
            ? (amountA, amountB)
            : (amountB, amountA);

        if (balances[msg.sender][t0] < amount0 || balances[msg.sender][t1] < amount1) revert InsufficientBalance();

        uint256 liquidity = _sqrt(amount0 * amount1);
        if (liquidity == 0) revert InsufficientInitialLiquidity();

        balances[msg.sender][t0] -= amount0;
        balances[msg.sender][t1] -= amount1;

        pairs[pairId] = Pair({
            token0:         t0,
            token1:         t1,
            reserve0:       amount0,
            reserve1:       amount1,
            totalLiquidity: liquidity,
            fee:            fee,
            exists:         true
        });
        lpBalances[pairId][msg.sender] = liquidity;
        pairIdByTokens[t0][t1] = pairId;
        pairIdByTokens[t1][t0] = pairId;
        allPairIds.push(pairId);

        emit PairCreated(t0, t1, pairId, amount0, amount1, fee, msg.sender);
        emit LiquidityAdded(msg.sender, t0, t1, amount0, amount1, liquidity);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external whenNotPaused returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (amountADesired == 0 || amountBDesired == 0) revert ZeroAmount();
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _pairId(t0, t1);
        Pair storage p = pairs[pairId];
        if (!p.exists) revert PairDoesNotExist();

        bool aIs0 = tokenA == t0;
        (uint256 amount0, uint256 amount1) = _calcLiquidityAmounts(
            aIs0 ? amountADesired : amountBDesired,
            aIs0 ? amountBDesired : amountADesired,
            aIs0 ? amountAMin : amountBMin,
            aIs0 ? amountBMin : amountAMin,
            p.reserve0,
            p.reserve1
        );

        if (balances[msg.sender][t0] < amount0 || balances[msg.sender][t1] < amount1) revert InsufficientBalance();

        liquidity = _calcLiquidityMint(amount0, amount1, p.totalLiquidity, p.reserve0, p.reserve1);
        if (liquidity == 0) revert InsufficientLiquidity();

        balances[msg.sender][t0] -= amount0;
        balances[msg.sender][t1] -= amount1;
        p.reserve0       += amount0;
        p.reserve1       += amount1;
        p.totalLiquidity += liquidity;
        lpBalances[pairId][msg.sender] += liquidity;

        amountA = aIs0 ? amount0 : amount1;
        amountB = aIs0 ? amount1 : amount0;

        emit LiquidityAdded(msg.sender, t0, t1, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external whenNotPaused returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert ZeroAmount();
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        bytes32 pairId = _pairId(t0, t1);
        Pair storage p = pairs[pairId];
        if (!p.exists) revert PairDoesNotExist();
        if (lpBalances[pairId][msg.sender] < liquidity) revert InsufficientLiquidity();
        if (p.totalLiquidity < liquidity) revert InsufficientLiquidity();

        uint256 amount0 = (liquidity * p.reserve0) / p.totalLiquidity;
        uint256 amount1 = (liquidity * p.reserve1) / p.totalLiquidity;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        bool aIs0 = tokenA == t0;
        amountA = aIs0 ? amount0 : amount1;
        amountB = aIs0 ? amount1 : amount0;
        if (amountA < amountAMin || amountB < amountBMin) revert SlippageExceeded();

        p.reserve0       -= amount0;
        p.reserve1       -= amount1;
        p.totalLiquidity -= liquidity;
        lpBalances[pairId][msg.sender] -= liquidity;
        balances[msg.sender][t0] += amount0;
        balances[msg.sender][t1] += amount1;

        emit LiquidityRemoved(msg.sender, t0, t1, amount0, amount1, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external whenNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert IdenticalAddresses();
        if (!approvedTokens[tokenIn] || !approvedTokens[tokenOut]) revert TokenNotApproved();
        if (balances[msg.sender][tokenIn] < amountIn) revert InsufficientBalance();

        (address t0, ) = _sortTokens(tokenIn, tokenOut);
        bytes32 pairId = pairIdByTokens[t0][tokenIn == t0 ? tokenOut : tokenIn];
        if (pairId == bytes32(0) || !pairs[pairId].exists) revert PairDoesNotExist();

        Pair storage p = pairs[pairId];
        bool isToken0In = tokenIn == p.token0;
        uint256 reserveIn  = isToken0In ? p.reserve0 : p.reserve1;
        uint256 reserveOut = isToken0In ? p.reserve1 : p.reserve0;

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut, p.fee);
        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut > reserveOut) revert InsufficientLiquidity();
        if (amountOut < amountOutMin) revert SlippageExceeded();

        balances[msg.sender][tokenIn]  -= amountIn;
        balances[msg.sender][tokenOut] += amountOut;
        if (isToken0In) {
            p.reserve0 += amountIn;
            p.reserve1 -= amountOut;
        } else {
            p.reserve1 += amountIn;
            p.reserve0 -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getPairId(address tokenA, address tokenB) external view returns (bytes32) {
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        return _pairId(t0, t1);
    }

    function getPair(address tokenA, address tokenB) external view returns (
        address token0,
        address token1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalLiquidity,
        uint16  fee,
        bool    exists
    ) {
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        Pair storage p = pairs[_pairId(t0, t1)];
        return (p.token0, p.token1, p.reserve0, p.reserve1, p.totalLiquidity, p.fee, p.exists);
    }

    function getPairCount() external view returns (uint256) {
        return allPairIds.length;
    }

    function getLpBalance(bytes32 pairId, address user) external view returns (uint256) {
        return lpBalances[pairId][user];
    }

    function balanceOf(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint16 fee) external pure returns (uint256) {
        return _getAmountOut(amountIn, reserveIn, reserveOut, fee);
    }

    function _sortTokens(address a, address b) internal pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }

    function _pairId(address t0, address t1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(t0, t1));
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint16 fee) internal pure returns (uint256) {
        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - fee)) / FEE_DENOMINATOR;
        return (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
    }

    function _calcLiquidityAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            return (amount0Desired, amount1Desired);
        }
        uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
        if (amount1Optimal <= amount1Desired) {
            if (amount1Optimal < amount1Min) revert SlippageExceeded();
            return (amount0Desired, amount1Optimal);
        } else {
            uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
            if (amount0Optimal > amount0Desired) revert SlippageExceeded();
            if (amount0Optimal < amount0Min) revert SlippageExceeded();
            return (amount0Optimal, amount1Desired);
        }
    }

    function _calcLiquidityMint(
        uint256 amount0,
        uint256 amount1,
        uint256 totalLiquidity,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 liquidity) {
        if (totalLiquidity == 0) {
            return _sqrt(amount0 * amount1);
        }
        uint256 liq0 = (amount0 * totalLiquidity) / reserve0;
        uint256 liq1 = (amount1 * totalLiquidity) / reserve1;
        return liq0 < liq1 ? liq0 : liq1;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y == 0) return 0;
        z = y;
        uint256 x = (y + 1) / 2;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }
}
