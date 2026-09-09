// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract DecentralizedExchange {
    // ---------- Custom errors ----------
    error Unauthorized();
    error PairExists();
    error PairNotFound();
    error InvalidPair();
    error InvalidAmount();
    error InsufficientInitialLiquidity();
    error InsufficientLiquidity();
    error InsufficientLiquidityMinted();
    error InsufficientAllowance();
    error InsufficientBalance();
    error SlippageExceeded();
    error TransferFailed();
    error ZeroAddress();

    // ---------- Events ----------
    event PairAdded(address indexed token0, address indexed token1, bytes32 indexed pairId);
    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    );
    event LPApproval(address indexed owner, address indexed spender, bytes32 indexed pairId, uint256 amount);
    event LPTransfer(address indexed from, address indexed to, bytes32 indexed pairId, uint256 amount);
    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------- Constants ----------
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_SWAP_FEE = 30; // 0.3%
    uint256 public constant MAX_SWAP_FEE = 1000; // 10%
    uint256 public constant MINIMUM_INITIAL_LIQUIDITY = 100;

    // ---------- Structs ----------
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        bool exists;
    }

    // ---------- State ----------
    address public owner;
    uint256 public swapFee; // in basis points

    mapping(bytes32 => Pool) private pools;
    mapping(bytes32 => mapping(address => uint256)) private lpBalances;
    mapping(bytes32 => mapping(address => mapping(address => uint256))) private lpAllowances;

    uint256 private _locked = 1;

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Unauthorized();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------- Constructor ----------
    constructor() {
        owner = msg.sender;
        swapFee = DEFAULT_SWAP_FEE;
        emit OwnershipTransferred(address(0), msg.sender);
        emit SwapFeeUpdated(0, DEFAULT_SWAP_FEE);
    }

    // ---------- Admin functions ----------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setSwapFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_SWAP_FEE) revert InvalidAmount();
        uint256 old = swapFee;
        swapFee = newFee;
        emit SwapFeeUpdated(old, newFee);
    }

    function addPair(address tokenA, address tokenB) external onlyOwner returns (bytes32 pairId) {
        if (tokenA == tokenB) revert InvalidPair();
        if (tokenA == address(0) || tokenB == address(0)) revert InvalidPair();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pairId = keccak256(abi.encodePacked(token0, token1));

        if (pools[pairId].exists) revert PairExists();

        pools[pairId] = Pool({
            token0: token0,
            token1: token1,
            reserve0: 0,
            reserve1: 0,
            totalSupply: 0,
            exists: true
        });

        emit PairAdded(token0, token1, pairId);
    }

    // ---------- View functions ----------
    function getPairId(address tokenA, address tokenB) public pure returns (bytes32) {
        if (tokenA == tokenB) revert InvalidPair();
        if (tokenA == address(0) || tokenB == address(0)) revert InvalidPair();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }

    function getPool(address tokenA, address tokenB) external view returns (
        address token0,
        address token1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        bool exists
    ) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        Pool storage p = pools[pairId];
        return (p.token0, p.token1, p.reserve0, p.reserve1, p.totalSupply, p.exists);
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        Pool storage p = pools[pairId];
        if (!p.exists) revert PairNotFound();
        bool aIsToken0 = (tokenA == p.token0);
        return (aIsToken0 ? p.reserve0 : p.reserve1, aIsToken0 ? p.reserve1 : p.reserve0);
    }

    function lpBalanceOf(address user, address tokenA, address tokenB) external view returns (uint256) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        return lpBalances[pairId][user];
    }

    function lpAllowanceOf(address ownerAddr, address spender, address tokenA, address tokenB) external view returns (uint256) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        return lpAllowances[pairId][ownerAddr][spender];
    }

    function lpTotalSupply(address tokenA, address tokenB) external view returns (uint256) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        return pools[pairId].totalSupply;
    }

    // ---------- LP token internal helpers ----------
    function _mintLp(bytes32 pairId, address to, uint256 amount) internal {
        Pool storage p = pools[pairId];
        p.totalSupply += amount;
        lpBalances[pairId][to] += amount;
    }

    function _burnLp(bytes32 pairId, address from, uint256 amount) internal {
        Pool storage p = pools[pairId];
        if (lpBalances[pairId][from] < amount) revert InsufficientBalance();
        p.totalSupply -= amount;
        lpBalances[pairId][from] -= amount;
    }

    // ---------- Safe transfer helpers ----------
    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    // ---------- Add liquidity ----------
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        Pool storage p = pools[pairId];
        if (!p.exists) revert PairNotFound();
        if (amountADesired == 0 || amountBDesired == 0) revert InvalidAmount();

        bool aIsToken0 = (tokenA == p.token0);

        if (p.totalSupply == 0) {
            if (amountADesired < MINIMUM_INITIAL_LIQUIDITY || amountBDesired < MINIMUM_INITIAL_LIQUIDITY) {
                revert InsufficientInitialLiquidity();
            }
            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = _sqrt(amountA * amountB);
        } else {
            uint256 reserveA = aIsToken0 ? p.reserve0 : p.reserve1;
            uint256 reserveB = aIsToken0 ? p.reserve1 : p.reserve0;
            uint256 ts = p.totalSupply;

            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                amountA = amountADesired;
                amountB = amountBOptimal;
                liquidity = (amountADesired * ts) / reserveA;
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                if (amountAOptimal > amountADesired) revert SlippageExceeded();
                amountA = amountAOptimal;
                amountB = amountBDesired;
                liquidity = (amountBDesired * ts) / reserveB;
            }
        }

        if (liquidity == 0) revert InsufficientLiquidityMinted();

        // Effects: update state before interactions
        if (aIsToken0) {
            p.reserve0 += amountA;
            p.reserve1 += amountB;
        } else {
            p.reserve0 += amountB;
            p.reserve1 += amountA;
        }
        _mintLp(pairId, msg.sender, liquidity);

        // Interactions
        _safeTransferFrom(IERC20(tokenA), msg.sender, address(this), amountA);
        _safeTransferFrom(IERC20(tokenB), msg.sender, address(this), amountB);

        emit LiquidityAdded(msg.sender, p.token0, p.token1, amountA, amountB, liquidity);
    }

    // ---------- Remove liquidity ----------
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        Pool storage p = pools[pairId];
        if (!p.exists) revert PairNotFound();
        if (p.totalSupply == 0) revert InsufficientLiquidity();
        if (liquidity == 0) revert InvalidAmount();

        bool aIsToken0 = (tokenA == p.token0);

        uint256 amount0 = (liquidity * p.reserve0) / p.totalSupply;
        uint256 amount1 = (liquidity * p.reserve1) / p.totalSupply;

        if (aIsToken0) {
            amountA = amount0;
            amountB = amount1;
        } else {
            amountA = amount1;
            amountB = amount0;
        }

        if (amountA == 0 && amountB == 0) revert InsufficientLiquidity();

        // Effects: update state before interactions
        _burnLp(pairId, msg.sender, liquidity);
        p.reserve0 -= amount0;
        p.reserve1 -= amount1;

        // Interactions
        _safeTransfer(IERC20(p.token0), msg.sender, amount0);
        _safeTransfer(IERC20(p.token1), msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, p.token0, p.token1, amountA, amountB, liquidity);
    }

    // ---------- Swap ----------
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant returns (uint256 amountOut) {
        bytes32 pairId = getPairId(tokenIn, tokenOut);
        Pool storage p = pools[pairId];
        if (!p.exists) revert PairNotFound();
        if (amountIn == 0) revert InvalidAmount();

        bool inIsToken0 = (tokenIn == p.token0);
        uint256 reserveIn = inIsToken0 ? p.reserve0 : p.reserve1;
        uint256 reserveOut = inIsToken0 ? p.reserve1 : p.reserve0;

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 feeAmount = (amountIn * swapFee) / BASIS_POINTS;
        uint256 amountInWithFee = amountIn - feeAmount;

        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        if (amountOut < amountOutMin) revert SlippageExceeded();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        // Effects: update state before interactions
        if (inIsToken0) {
            p.reserve0 += amountIn;
            p.reserve1 -= amountOut;
        } else {
            p.reserve1 += amountIn;
            p.reserve0 -= amountOut;
        }

        // Interactions
        _safeTransferFrom(IERC20(tokenIn), msg.sender, address(this), amountIn);
        _safeTransfer(IERC20(tokenOut), msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeAmount);
    }

    // ---------- LP token approvals & transfers ----------
    function approveLp(address tokenA, address tokenB, address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        bytes32 pairId = getPairId(tokenA, tokenB);
        lpAllowances[pairId][msg.sender][spender] = amount;
        emit LPApproval(msg.sender, spender, pairId, amount);
        return true;
    }

    function transferLp(address tokenA, address tokenB, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        bytes32 pairId = getPairId(tokenA, tokenB);
        if (lpBalances[pairId][msg.sender] < amount) revert InsufficientBalance();
        lpBalances[pairId][msg.sender] -= amount;
        lpBalances[pairId][to] += amount;
        emit LPTransfer(msg.sender, to, pairId, amount);
        return true;
    }

    function transferFromLp(
        address tokenA,
        address tokenB,
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        bytes32 pairId = getPairId(tokenA, tokenB);
        if (lpBalances[pairId][from] < amount) revert InsufficientBalance();
        uint256 allowed = lpAllowances[pairId][from][msg.sender];
        if (msg.sender != from && allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            lpAllowances[pairId][from][msg.sender] = allowed - amount;
        }
        lpBalances[pairId][from] -= amount;
        lpBalances[pairId][to] += amount;
        emit LPTransfer(from, to, pairId, amount);
        return true;
    }

    // ---------- Math helpers ----------
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

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
