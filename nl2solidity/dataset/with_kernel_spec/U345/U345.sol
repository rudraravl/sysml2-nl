// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract InstantSwap {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_FEE_BPS = 5;            // 0.05%
    uint256 public constant MAX_FEE_BPS = 100;          // 1.00%
    uint256 public constant MAX_PRICE_IMPACT_BPS = 500; // 5.00%

    struct Pool {
        uint256 reserveA;
        uint256 reserveB;
        uint256 feeBps;
        uint256 totalShares;
        bool exists;
    }

    address public owner;
    bool public swappingPaused;
    uint256 private _locked = 1;

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => address[2]) public poolTokens;
    mapping(bytes32 => mapping(address => uint256)) public lpShares;

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeBps
    );
    event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 sharesMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 sharesBurned
    );
    event PoolAdded(address indexed tokenA, address indexed tokenB, uint256 feeBps);
    event FeeUpdated(address indexed tokenA, address indexed tokenB, uint256 feeBps);
    event SwappingPaused(address indexed by, bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error SameToken();
    error PoolExists();
    error PoolDoesNotExist();
    error InvalidFee();
    error SwappingPausedState();
    error InsufficientLiquidity();
    error InsufficientShares();
    error ZeroAmount();
    error PriceImpactExceeded(uint256 impactBps, uint256 maxImpactBps);
    error InsufficientOutputAmount();
    error TransferFailed();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (swappingPaused) revert SwappingPausedState();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function setSwappingPaused(bool paused) external onlyOwner {
        swappingPaused = paused;
        emit SwappingPaused(msg.sender, paused);
    }

    function _pairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address a, address b) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(a, b));
    }

    function _ordered(address tokenA, address tokenB) internal pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function addPool(address tokenA, address tokenB, uint256 feeBps) external onlyOwner {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert SameToken();
        if (feeBps < MIN_FEE_BPS || feeBps > MAX_FEE_BPS) revert InvalidFee();

        bytes32 id = _pairId(tokenA, tokenB);
        if (pools[id].exists) revert PoolExists();

        (address a, address b) = _ordered(tokenA, tokenB);
        pools[id] = Pool({
            reserveA: 0,
            reserveB: 0,
            feeBps: feeBps,
            totalShares: 0,
            exists: true
        });
        poolTokens[id] = [a, b];
        emit PoolAdded(a, b, feeBps);
    }

    function setFee(address tokenA, address tokenB, uint256 feeBps) external onlyOwner {
        if (feeBps < MIN_FEE_BPS || feeBps > MAX_FEE_BPS) revert InvalidFee();
        bytes32 id = _pairId(tokenA, tokenB);
        if (!pools[id].exists) revert PoolDoesNotExist();
        pools[id].feeBps = feeBps;
        (address a, address b) = _ordered(tokenA, tokenB);
        emit FeeUpdated(a, b, feeBps);
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();
        if (tokenA == tokenB) revert SameToken();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();

        bytes32 id = _pairId(tokenA, tokenB);
        Pool storage pool = pools[id];
        if (!pool.exists) revert PoolDoesNotExist();

        (address a, address b) = _ordered(tokenA, tokenB);
        uint256 amtA = tokenA < tokenB ? amountA : amountB;
        uint256 amtB = tokenA < tokenB ? amountB : amountA;

        if (pool.totalShares == 0) {
            shares = _sqrt(amtA * amtB);
        } else {
            uint256 sA = (amtA * pool.totalShares) / pool.reserveA;
            uint256 sB = (amtB * pool.totalShares) / pool.reserveB;
            shares = sA < sB ? sA : sB;
        }
        if (shares == 0) revert InsufficientLiquidity();

        // Effects: update state before interactions
        pool.reserveA += amtA;
        pool.reserveB += amtB;
        pool.totalShares += shares;
        lpShares[id][msg.sender] += shares;

        // Interactions
        if (!_safeTransferFrom(a, msg.sender, address(this), amtA)) revert TransferFailed();
        if (!_safeTransferFrom(b, msg.sender, address(this), amtB)) revert TransferFailed();

        emit LiquidityAdded(msg.sender, a, b, amtA, amtB, shares);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 shares)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        if (shares == 0) revert ZeroAmount();
        if (tokenA == tokenB) revert SameToken();

        bytes32 id = _pairId(tokenA, tokenB);
        Pool storage pool = pools[id];
        if (!pool.exists) revert PoolDoesNotExist();
        if (pool.totalShares == 0) revert InsufficientLiquidity();
        if (lpShares[id][msg.sender] < shares) revert InsufficientShares();

        amountA = (shares * pool.reserveA) / pool.totalShares;
        amountB = (shares * pool.reserveB) / pool.totalShares;

        // Effects: update state before interactions
        lpShares[id][msg.sender] -= shares;
        pool.totalShares -= shares;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;

        // Interactions
        (address a, address b) = _ordered(tokenA, tokenB);
        if (amountA > 0) {
            if (!_safeTransfer(a, msg.sender, amountA)) revert TransferFailed();
        }
        if (amountB > 0) {
            if (!_safeTransfer(b, msg.sender, amountB)) revert TransferFailed();
        }

        emit LiquidityRemoved(msg.sender, a, b, amountA, amountB, shares);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert SameToken();
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();

        bytes32 id = _pairId(tokenIn, tokenOut);
        Pool storage pool = pools[id];
        if (!pool.exists) revert PoolDoesNotExist();
        if (pool.reserveA == 0 || pool.reserveB == 0) revert InsufficientLiquidity();

        (address a, ) = _ordered(tokenIn, tokenOut);
        bool inIsA = (tokenIn == a);

        uint256 reserveIn = inIsA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = inIsA ? pool.reserveB : pool.reserveA;

        // Avoid divide-before-multiply: keep fee factor in numerator
        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - pool.feeBps);
        uint256 denominator = reserveIn * BPS_DENOMINATOR + amountInWithFee;
        amountOut = (reserveOut * amountInWithFee) / denominator;

        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut > reserveOut) revert InsufficientLiquidity();
        if (amountOut < minAmountOut) revert InsufficientOutputAmount();

        uint256 impactBps = (amountIn * BPS_DENOMINATOR) / (reserveIn + amountIn);
        if (impactBps > MAX_PRICE_IMPACT_BPS) {
            revert PriceImpactExceeded(impactBps, MAX_PRICE_IMPACT_BPS);
        }

        // Effects: update state before interactions
        if (inIsA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }

        // Interactions
        if (!_safeTransferFrom(tokenIn, msg.sender, address(this), amountIn)) revert TransferFailed();
        if (!_safeTransfer(tokenOut, msg.sender, amountOut)) revert TransferFailed();

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, pool.feeBps);
    }

    function getPool(address tokenA, address tokenB)
        external
        view
        returns (uint256 reserveA, uint256 reserveB, uint256 feeBps, uint256 totalShares, bool exists)
    {
        bytes32 id = _pairId(tokenA, tokenB);
        Pool storage p = pools[id];
        return (p.reserveA, p.reserveB, p.feeBps, p.totalShares, p.exists);
    }

    function getShares(address tokenA, address tokenB, address user) external view returns (uint256) {
        return lpShares[_pairId(tokenA, tokenB)][user];
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _safeTransfer(address token, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
