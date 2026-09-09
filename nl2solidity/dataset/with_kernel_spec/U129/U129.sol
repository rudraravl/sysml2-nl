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
    error ErrZeroAddress();
    error ErrIdenticalAddresses();
    error ErrPoolExists();
    error ErrPoolNotFound();
    error ErrInsufficientLiquidity();
    error ErrInsufficientInputAmount();
    error ErrInsufficientOutputAmount();
    error ErrInsufficientAllowance();
    error ErrTransferFailed();
    error ErrFeeTooHigh();
    error ErrPaused();
    error ErrNotOwner();
    error ErrNoLiquidity();
    error ErrAmountZero();
    error ErrSlippageExceeded();
    error ErrNotERC20();

    event PoolCreated(address indexed tokenA, address indexed tokenB, uint256 swapFee, address indexed creator);
    event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );
    event FeesCollected(address indexed collector, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event PausedStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    uint256 public constant MAX_SWAP_FEE = 50; // 0.5% in basis points
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    address public owner;
    bool public paused;
    uint256 public protocolSwapFee;

    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        uint256 feeAccruedA;
        uint256 feeAccruedB;
        bool exists;
    }

    struct Position {
        uint256 liquidity;
        uint256 lastTotalLiquidity;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => Position)) public positions;
    mapping(address => mapping(address => uint256)) public userBalances;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    constructor(uint256 initialSwapFee) {
        if (initialSwapFee > MAX_SWAP_FEE) revert ErrFeeTooHigh();
        owner = msg.sender;
        protocolSwapFee = initialSwapFee;
        paused = false;
        emit OwnershipTransferred(address(0), msg.sender);
        emit SwapFeeUpdated(0, initialSwapFee);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setSwapFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_SWAP_FEE) revert ErrFeeTooHigh();
        uint256 old = protocolSwapFee;
        protocolSwapFee = newFee;
        emit SwapFeeUpdated(old, newFee);
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit PausedStateChanged(state);
    }

    function poolId(address tokenA, address tokenB) public pure returns (bytes32) {
        if (tokenA == address(0) || tokenB == address(0)) revert ErrZeroAddress();
        if (tokenA == tokenB) revert ErrIdenticalAddresses();
        return tokenA < tokenB
            ? keccak256(abi.encodePacked(tokenA, tokenB))
            : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    function getPool(address tokenA, address tokenB) external view returns (
        address a,
        address b,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalLiquidity,
        uint256 feeAccruedA,
        uint256 feeAccruedB,
        bool exists
    ) {
        bytes32 id = poolId(tokenA, tokenB);
        Pool storage p = pools[id];
        return (p.tokenA, p.tokenB, p.reserveA, p.reserveB, p.totalLiquidity, p.feeAccruedA, p.feeAccruedB, p.exists);
    }

    function getPosition(address tokenA, address tokenB, address user) external view returns (uint256 liquidity, uint256 lastTotalLiquidity) {
        bytes32 id = poolId(tokenA, tokenB);
        Position storage pos = positions[id][user];
        return (pos.liquidity, pos.lastTotalLiquidity);
    }

    function createPool(address tokenA, address tokenB) external onlyOwner returns (bytes32 id) {
        id = poolId(tokenA, tokenB);
        if (pools[id].exists) revert ErrPoolExists();

        try IERC20(tokenA).totalSupply() returns (uint256) {} catch { revert ErrNotERC20(); }
        try IERC20(tokenB).totalSupply() returns (uint256) {} catch { revert ErrNotERC20(); }

        (address a, address b) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pools[id] = Pool({
            tokenA: a,
            tokenB: b,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            feeAccruedA: 0,
            feeAccruedB: 0,
            exists: true
        });

        emit PoolCreated(a, b, protocolSwapFee, msg.sender);
    }

    function _pullToken(address token, address from, uint256 amount) internal {
        if (amount == 0) revert ErrAmountZero();
        uint256 allowance = IERC20(token).allowance(from, address(this));
        if (allowance < amount) revert ErrInsufficientAllowance();
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), amount));
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert ErrTransferFailed();
        if (IERC20(token).balanceOf(address(this)) < balBefore + amount) revert ErrTransferFailed();
    }

    function _sendToken(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert ErrTransferFailed();
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 minLiquidity
    ) external whenNotPaused returns (uint256 liquidity) {
        if (amountA == 0 || amountB == 0) revert ErrAmountZero();
        bytes32 id = poolId(tokenA, tokenB);
        Pool storage p = pools[id];
        if (!p.exists) revert ErrPoolNotFound();

        _pullToken(p.tokenA, msg.sender, amountA);
        _pullToken(p.tokenB, msg.sender, amountB);

        if (p.totalLiquidity == 0) {
            liquidity = _sqrt(amountA * amountB);
            if (liquidity <= MINIMUM_LIQUIDITY) revert ErrInsufficientLiquidity();
            positions[id][owner].liquidity += MINIMUM_LIQUIDITY;
            positions[id][owner].lastTotalLiquidity = MINIMUM_LIQUIDITY;
            liquidity -= MINIMUM_LIQUIDITY;
            p.totalLiquidity = MINIMUM_LIQUIDITY;
        } else {
            uint256 lA = (amountA * p.totalLiquidity) / p.reserveA;
            uint256 lB = (amountB * p.totalLiquidity) / p.reserveB;
            liquidity = lA < lB ? lA : lB;
            if (liquidity == 0) revert ErrInsufficientLiquidity();
        }

        if (liquidity < minLiquidity) revert ErrSlippageExceeded();

        p.reserveA += amountA;
        p.reserveB += amountB;
        p.totalLiquidity += liquidity;

        Position storage pos = positions[id][msg.sender];
        pos.liquidity += liquidity;
        pos.lastTotalLiquidity = p.totalLiquidity;

        emit LiquidityAdded(msg.sender, p.tokenA, p.tokenB, amountA, amountB, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 minAmountA,
        uint256 minAmountB
    ) external whenNotPaused returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert ErrAmountZero();
        bytes32 id = poolId(tokenA, tokenB);
        Pool storage p = pools[id];
        if (!p.exists) revert ErrPoolNotFound();

        Position storage pos = positions[id][msg.sender];
        if (pos.liquidity < liquidity) revert ErrInsufficientLiquidity();

        amountA = (liquidity * p.reserveA) / p.totalLiquidity;
        amountB = (liquidity * p.reserveB) / p.totalLiquidity;
        if (amountA == 0 || amountB == 0) revert ErrInsufficientLiquidity();
        if (amountA < minAmountA || amountB < minAmountB) revert ErrSlippageExceeded();

        pos.liquidity -= liquidity;
        p.totalLiquidity -= liquidity;
        p.reserveA -= amountA;
        p.reserveB -= amountB;
        pos.lastTotalLiquidity = p.totalLiquidity;

        _sendToken(p.tokenA, msg.sender, amountA);
        _sendToken(p.tokenB, msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, p.tokenA, p.tokenB, amountA, amountB, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external whenNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert ErrAmountZero();
        if (to == address(0)) revert ErrZeroAddress();
        bytes32 id = poolId(tokenIn, tokenOut);
        Pool storage p = pools[id];
        if (!p.exists) revert ErrPoolNotFound();

        bool inIsA = (tokenIn == p.tokenA);
        (uint256 reserveIn, uint256 reserveOut) = inIsA
            ? (p.reserveA, p.reserveB)
            : (p.reserveB, p.reserveA);

        if (reserveIn == 0 || reserveOut == 0) revert ErrInsufficientLiquidity();

        _pullToken(tokenIn, msg.sender, amountIn);

        uint256 fee = (amountIn * protocolSwapFee) / FEE_DENOMINATOR;
        uint256 amountInWithFee = amountIn - fee;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);

        if (amountOut < minAmountOut) revert ErrSlippageExceeded();
        if (amountOut >= reserveOut) revert ErrInsufficientLiquidity();

        if (inIsA) {
            p.feeAccruedA += fee;
            p.reserveA += amountInWithFee;
            p.reserveB -= amountOut;
        } else {
            p.feeAccruedB += fee;
            p.reserveB += amountInWithFee;
            p.reserveA -= amountOut;
        }

        _sendToken(tokenOut, to, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, to);
    }

    function collectFees(address tokenA, address tokenB) external returns (uint256 amountA, uint256 amountB) {
        bytes32 id = poolId(tokenA, tokenB);
        Pool storage p = pools[id];
        if (!p.exists) revert ErrPoolNotFound();

        Position storage pos = positions[id][msg.sender];
        if (pos.liquidity == 0) revert ErrNoLiquidity();

        uint256 share = (pos.liquidity * FEE_DENOMINATOR) / p.totalLiquidity;
        amountA = (p.feeAccruedA * share) / FEE_DENOMINATOR;
        amountB = (p.feeAccruedB * share) / FEE_DENOMINATOR;

        p.feeAccruedA -= amountA;
        p.feeAccruedB -= amountB;

        _sendToken(p.tokenA, msg.sender, amountA);
        _sendToken(p.tokenB, msg.sender, amountB);

        emit FeesCollected(msg.sender, p.tokenA, p.tokenB, amountA, amountB);
    }

    function deposit(address token, uint256 amount) external {
        _pullToken(token, msg.sender, amount);
        userBalances[msg.sender][token] += amount;
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        if (userBalances[msg.sender][token] < amount) revert ErrInsufficientLiquidity();
        userBalances[msg.sender][token] -= amount;
        _sendToken(token, msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        bytes32 id = poolId(tokenIn, tokenOut);
        Pool storage p = pools[id];
        if (!p.exists) revert ErrPoolNotFound();
        (uint256 reserveIn, uint256 reserveOut) = tokenIn == p.tokenA
            ? (p.reserveA, p.reserveB)
            : (p.reserveB, p.reserveA);
        if (reserveIn == 0 || reserveOut == 0) return 0;
        uint256 fee = (amountIn * protocolSwapFee) / FEE_DENOMINATOR;
        uint256 amountInWithFee = amountIn - fee;
        return (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
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
