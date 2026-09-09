// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool success = token.transfer(to, value);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bool success = token.transferFrom(from, to, value);
        require(success, "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        bool success = token.approve(spender, value);
        require(success, "SafeERC20: approve failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero address");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract DecentralizedExchange is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    ///////////////////////////////////////////////////////////////////
    // CONSTANTS
    ///////////////////////////////////////////////////////////////////

    uint256 public constant MAX_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_BASE_DEPOSIT = 100; // minimum base tokens to create a pool

    ///////////////////////////////////////////////////////////////////
    // ERRORS
    ///////////////////////////////////////////////////////////////////

    error PairAlreadyExists();
    error PairDoesNotExist();
    error InsufficientDeposit();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientLiquidity();
    error InvalidFee();
    error InvalidTokenPair();
    error SameToken();
    error ZeroAddress();
    error InsufficientOutput();
    error SlippageExceeded();

    ///////////////////////////////////////////////////////////////////
    // EVENTS
    ///////////////////////////////////////////////////////////////////

    event PairAdded(address indexed tokenA, address indexed tokenB, address indexed baseToken);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    event LiquidityDeposited(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 sharesMinted
    );

    event LiquidityWithdrawn(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 sharesBurned
    );

    event TokensSwapped(
        address indexed swapper,
        address indexed inputToken,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 feeAmount
    );

    event FeesClaimed(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 feeTokenA,
        uint256 feeTokenB
    );

    ///////////////////////////////////////////////////////////////////
    // DATA STRUCTURES
    ///////////////////////////////////////////////////////////////////

    struct Pool {
        address tokenA;
        address tokenB;
        address baseToken;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalShares;
        uint256 feeAccruedA;
        uint256 feeAccruedB;
        bool active;
    }

    struct ProviderPosition {
        uint256 shares;
        uint256 feeDebtA;
        uint256 feeDebtB;
    }

    ///////////////////////////////////////////////////////////////////
    // STATE VARIABLES
    ///////////////////////////////////////////////////////////////////

    uint256 public feeBps;
    address public treasury;

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => ProviderPosition)) public providerPositions;
    mapping(address => bool) public supportedTokens;

    ///////////////////////////////////////////////////////////////////
    // MODIFIERS
    ///////////////////////////////////////////////////////////////////

    modifier validPair(address tokenA, address tokenB) {
        if (tokenA == tokenB) revert SameToken();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        _;
    }

    ///////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    ///////////////////////////////////////////////////////////////////

    constructor(address _treasury, uint256 _feeBps) Ownable(msg.sender) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert InvalidFee();
        treasury = _treasury;
        feeBps = _feeBps;

        emit TreasuryUpdated(address(0), _treasury);
        emit FeeUpdated(0, _feeBps);
    }

    ///////////////////////////////////////////////////////////////////
    // ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////////

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 old = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function addPair(address tokenA, address tokenB, address baseToken)
        external
        onlyOwner
        validPair(tokenA, tokenB)
    {
        if (baseToken == address(0)) revert ZeroAddress();
        if (baseToken != tokenA && baseToken != tokenB) revert InvalidTokenPair();

        bytes32 pairId = _pairId(tokenA, tokenB);
        if (pools[pairId].active) revert PairAlreadyExists();

        supportedTokens[tokenA] = true;
        supportedTokens[tokenB] = true;

        pools[pairId] = Pool({
            tokenA: tokenA,
            tokenB: tokenB,
            baseToken: baseToken,
            reserveA: 0,
            reserveB: 0,
            totalShares: 0,
            feeAccruedA: 0,
            feeAccruedB: 0,
            active: true
        });

        emit PairAdded(tokenA, tokenB, baseToken);
    }

    ///////////////////////////////////////////////////////////////////
    // LIQUIDITY FUNCTIONS
    ///////////////////////////////////////////////////////////////////

    function deposit(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        nonReentrant
        validPair(tokenA, tokenB)
        returns (uint256 sharesMinted)
    {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        bytes32 pairId = _pairId(tokenA, tokenB);
        Pool storage pool = pools[pairId];
        if (!pool.active) revert PairDoesNotExist();

        (uint256 amtA, uint256 amtB) = _orderAmounts(tokenA, pool.tokenA, amountA, amountB);

        IERC20(pool.tokenA).safeTransferFrom(msg.sender, address(this), amtA);
        IERC20(pool.tokenB).safeTransferFrom(msg.sender, address(this), amtB);

        if (pool.totalShares == 0) {
            uint256 baseAmount = pool.baseToken == pool.tokenA ? amtA : amtB;
            if (baseAmount < MIN_BASE_DEPOSIT) revert InsufficientDeposit();
            sharesMinted = _sqrt(amtA * amtB);
        } else {
            uint256 sharesFromA = (amtA * pool.totalShares) / pool.reserveA;
            uint256 sharesFromB = (amtB * pool.totalShares) / pool.reserveB;
            sharesMinted = sharesFromA < sharesFromB ? sharesFromA : sharesFromB;
            if (sharesMinted == 0) revert ZeroShares();
        }

        pool.reserveA += amtA;
        pool.reserveB += amtB;
        pool.totalShares += sharesMinted;

        ProviderPosition storage pos = providerPositions[pairId][msg.sender];
        pos.shares += sharesMinted;
        (uint256 feePerShareA, uint256 feePerShareB) = _feePerShare(pool);
        pos.feeDebtA = (pos.shares * feePerShareA) / 1e18;
        pos.feeDebtB = (pos.shares * feePerShareB) / 1e18;

        emit LiquidityDeposited(msg.sender, pool.tokenA, pool.tokenB, amtA, amtB, sharesMinted);
    }

    function withdraw(address tokenA, address tokenB, uint256 sharesToBurn)
        external
        nonReentrant
        validPair(tokenA, tokenB)
        returns (uint256 amountA, uint256 amountB)
    {
        if (sharesToBurn == 0) revert ZeroShares();

        bytes32 pairId = _pairId(tokenA, tokenB);
        Pool storage pool = pools[pairId];
        if (!pool.active) revert PairDoesNotExist();

        ProviderPosition storage pos = providerPositions[pairId][msg.sender];
        if (pos.shares < sharesToBurn) revert InsufficientShares();

        amountA = (sharesToBurn * pool.reserveA) / pool.totalShares;
        amountB = (sharesToBurn * pool.reserveB) / pool.totalShares;

        if (amountA == 0 || amountB == 0) revert InsufficientLiquidity();

        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalShares -= sharesToBurn;
        pos.shares -= sharesToBurn;

        (uint256 feePerShareA, uint256 feePerShareB) = _feePerShare(pool);
        pos.feeDebtA = (pos.shares * feePerShareA) / 1e18;
        pos.feeDebtB = (pos.shares * feePerShareB) / 1e18;

        IERC20(pool.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pool.tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityWithdrawn(msg.sender, pool.tokenA, pool.tokenB, amountA, amountB, sharesToBurn);
    }

    ///////////////////////////////////////////////////////////////////
    // SWAP FUNCTIONS
    ///////////////////////////////////////////////////////////////////

    function swap(address inputToken, address outputToken, uint256 inputAmount, uint256 minOutputAmount)
        external
        nonReentrant
        validPair(inputToken, outputToken)
        returns (uint256 outputAmount)
    {
        if (inputAmount == 0) revert ZeroAmount();

        bytes32 pairId = _pairId(inputToken, outputToken);
        Pool storage pool = pools[pairId];
        if (!pool.active) revert PairDoesNotExist();

        (uint256 inputReserve, uint256 outputReserve) = _orderedReserves(pool, inputToken);

        uint256 feeAmount = (inputAmount * feeBps) / BPS_DENOMINATOR;
        uint256 inputAfterFee = inputAmount - feeAmount;

        outputAmount = (inputAfterFee * outputReserve) / (inputReserve + inputAfterFee);
        if (outputAmount == 0) revert InsufficientOutput();
        if (outputAmount < minOutputAmount) revert SlippageExceeded();

        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), inputAmount);

        if (feeAmount > 0) {
            if (inputToken == pool.tokenA) {
                pool.feeAccruedA += feeAmount;
            } else {
                pool.feeAccruedB += feeAmount;
            }
        }

        if (inputToken == pool.tokenA) {
            pool.reserveA += inputAfterFee;
            pool.reserveB -= outputAmount;
        } else {
            pool.reserveB += inputAfterFee;
            pool.reserveA -= outputAmount;
        }

        IERC20(outputToken).safeTransfer(msg.sender, outputAmount);

        emit TokensSwapped(msg.sender, inputToken, outputToken, inputAmount, outputAmount, feeAmount);
    }

    ///////////////////////////////////////////////////////////////////
    // FEE CLAIM FUNCTIONS
    ///////////////////////////////////////////////////////////////////

    function claimFees(address tokenA, address tokenB)
        external
        nonReentrant
        validPair(tokenA, tokenB)
        returns (uint256 feeTokenA, uint256 feeTokenB)
    {
        bytes32 pairId = _pairId(tokenA, tokenB);
        Pool storage pool = pools[pairId];
        if (!pool.active) revert PairDoesNotExist();

        ProviderPosition storage pos = providerPositions[pairId][msg.sender];
        if (pos.shares == 0) revert ZeroShares();

        (uint256 feePerShareA, uint256 feePerShareB) = _feePerShare(pool);

        uint256 entitledA = (pos.shares * feePerShareA) / 1e18;
        uint256 entitledB = (pos.shares * feePerShareB) / 1e18;

        feeTokenA = entitledA > pos.feeDebtA ? entitledA - pos.feeDebtA : 0;
        feeTokenB = entitledB > pos.feeDebtB ? entitledB - pos.feeDebtB : 0;

        pos.feeDebtA = entitledA;
        pos.feeDebtB = entitledB;

        if (feeTokenA > 0) {
            pool.feeAccruedA -= feeTokenA;
            IERC20(pool.tokenA).safeTransfer(msg.sender, feeTokenA);
        }
        if (feeTokenB > 0) {
            pool.feeAccruedB -= feeTokenB;
            IERC20(pool.tokenB).safeTransfer(msg.sender, feeTokenB);
        }

        emit FeesClaimed(msg.sender, pool.tokenA, pool.tokenB, feeTokenA, feeTokenB);
    }

    ///////////////////////////////////////////////////////////////////
    // VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////////

    function getPool(address tokenA, address tokenB) external view returns (Pool memory) {
        return pools[_pairId(tokenA, tokenB)];
    }

    function getProviderPosition(address provider, address tokenA, address tokenB)
        external
        view
        returns (ProviderPosition memory)
    {
        return providerPositions[_pairId(tokenA, tokenB)][provider];
    }

    function getOutputAmount(address inputToken, address outputToken, uint256 inputAmount)
        external
        view
        returns (uint256 outputAmount)
    {
        bytes32 pairId = _pairId(inputToken, outputToken);
        Pool storage pool = pools[pairId];
        if (!pool.active) revert PairDoesNotExist();

        (uint256 inputReserve, uint256 outputReserve) = _orderedReserves(pool, inputToken);
        uint256 feeAmount = (inputAmount * feeBps) / BPS_DENOMINATOR;
        uint256 inputAfterFee = inputAmount - feeAmount;
        outputAmount = (inputAfterFee * outputReserve) / (inputReserve + inputAfterFee);
    }

    function pairExists(address tokenA, address tokenB) external view returns (bool) {
        return pools[_pairId(tokenA, tokenB)].active;
    }

    ///////////////////////////////////////////////////////////////////
    // INTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////////

    function _pairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(t0, t1));
    }

    function _orderAmounts(address tokenA, address poolTokenA, uint256 amountA, uint256 amountB)
        internal
        pure
        returns (uint256 amtA, uint256 amtB)
    {
        if (tokenA == poolTokenA) {
            return (amountA, amountB);
        } else {
            return (amountB, amountA);
        }
    }

    function _orderedReserves(Pool storage pool, address inputToken)
        internal
        view
        returns (uint256 inputReserve, uint256 outputReserve)
    {
        if (inputToken == pool.tokenA) {
            return (pool.reserveA, pool.reserveB);
        } else {
            return (pool.reserveB, pool.reserveA);
        }
    }

    function _feePerShare(Pool storage pool)
        internal
        view
        returns (uint256 feePerShareA, uint256 feePerShareB)
    {
        if (pool.totalShares == 0) {
            return (0, 0);
        }
        feePerShareA = (pool.feeAccruedA * 1e18) / pool.totalShares;
        feePerShareB = (pool.feeAccruedB * 1e18) / pool.totalShares;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
