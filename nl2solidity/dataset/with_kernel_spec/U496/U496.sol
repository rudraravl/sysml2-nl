// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract TokenPairFactory {
    struct Pair {
        address creator;
        string name;
        string symbol;
        uint256 baseReserve;
        uint256 tokenReserve;
        uint256 tokenTotalSupply;
        uint256 lpTotalSupply;
        bool exists;
    }

    event PairCreated(
        uint256 indexed pairId,
        address indexed creator,
        string name,
        string symbol,
        uint256 baseReserve,
        uint256 tokenReserve,
        uint256 lpTotalSupply
    );
    event LiquidityAdded(
        uint256 indexed pairId,
        address indexed provider,
        uint256 baseAmount,
        uint256 tokenAmount,
        uint256 lpShares
    );
    event LiquidityRemoved(
        uint256 indexed pairId,
        address indexed provider,
        uint256 baseAmount,
        uint256 tokenAmount,
        uint256 lpShares
    );
    event Swap(
        uint256 indexed pairId,
        address indexed user,
        bool baseForToken,
        uint256 amountIn,
        uint256 amountOut,
        uint256 tax
    );
    event TradingPaused(bool paused);
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event TradingTaxUpdated(uint256 oldTaxBps, uint256 newTaxBps);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event OwnershipTransferred(address oldOwner, address newOwner);
    event Transfer(uint256 indexed pairId, address indexed from, address indexed to, uint256 value);
    event Approval(uint256 indexed pairId, address indexed owner, address indexed spender, uint256 value);

    error ErrZeroAddress();
    error ErrNotOwner();
    error ErrPaused();
    error ErrPairNotFound();
    error ErrInsufficientAmount();
    error ErrInsufficientBalance();
    error ErrInsufficientAllowance();
    error ErrInsufficientLiquidity();
    error ErrMinBaseNotMet();
    error ErrInvalidTax();
    error ErrTransferFailed();
    error ErrReentrant();
    error ErrZeroLiquidity();
    error ErrInvalidName();

    address public owner;
    address public treasury;
    IERC20 public immutable baseToken;

    uint256 public constant MIN_INITIAL_BASE = 1e17;

    uint256 public creationFee;
    uint256 public tradingTaxBps;
    bool public paused;

    uint256 public pairCount;
    mapping(uint256 => Pair) public pairs;
    mapping(uint256 => mapping(address => uint256)) public tokenBalances;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public tokenAllowances;
    mapping(uint256 => mapping(address => uint256)) public lpBalances;

    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 private constant MAX_TAX_BPS = 10000;
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    bool private locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ErrReentrant();
        locked = true;
        _;
        locked = false;
    }

    constructor(address _baseToken, address _treasury, uint256 _creationFee, uint256 _tradingTaxBps) {
        if (_baseToken == address(0)) revert ErrZeroAddress();
        if (_treasury == address(0)) revert ErrZeroAddress();
        if (_tradingTaxBps > MAX_TAX_BPS) revert ErrInvalidTax();

        baseToken = IERC20(_baseToken);
        treasury = _treasury;
        creationFee = _creationFee;
        tradingTaxBps = _tradingTaxBps;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);
        emit TreasuryUpdated(address(0), _treasury);
        emit CreationFeeUpdated(0, _creationFee);
        emit TradingTaxUpdated(0, _tradingTaxBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ErrZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function setCreationFee(uint256 newFee) external onlyOwner {
        emit CreationFeeUpdated(creationFee, newFee);
        creationFee = newFee;
    }

    function setTradingTax(uint256 newTaxBps) external onlyOwner {
        if (newTaxBps > MAX_TAX_BPS) revert ErrInvalidTax();
        emit TradingTaxUpdated(tradingTaxBps, newTaxBps);
        tradingTaxBps = newTaxBps;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit TradingPaused(_paused);
    }

    function getPairCount() external view returns (uint256) {
        return pairCount;
    }

    function getReserves(uint256 pairId) external view returns (uint256 baseReserve, uint256 tokenReserve) {
        if (!pairs[pairId].exists) revert ErrPairNotFound();
        Pair storage p = pairs[pairId];
        return (p.baseReserve, p.tokenReserve);
    }

    function tokenBalanceOf(uint256 pairId, address account) external view returns (uint256) {
        return tokenBalances[pairId][account];
    }

    function lpBalanceOf(uint256 pairId, address account) external view returns (uint256) {
        return lpBalances[pairId][account];
    }

    function tokenTotalSupplyOf(uint256 pairId) external view returns (uint256) {
        return pairs[pairId].tokenTotalSupply;
    }

    function createPair(
        string calldata name,
        string calldata symbol,
        uint256 initialTokenAmount,
        uint256 initialBaseAmount
    ) external nonReentrant whenNotPaused returns (uint256 pairId) {
        if (bytes(name).length == 0 || bytes(symbol).length == 0) revert ErrInvalidName();
        if (initialTokenAmount == 0) revert ErrInsufficientAmount();
        if (initialBaseAmount < MIN_INITIAL_BASE) revert ErrMinBaseNotMet();

        uint256 totalNeeded = creationFee + initialBaseAmount;
        if (baseToken.allowance(msg.sender, address(this)) < totalNeeded) revert ErrInsufficientAllowance();
        if (baseToken.balanceOf(msg.sender) < totalNeeded) revert ErrInsufficientBalance();

        pairId = pairCount++;
        Pair storage p = pairs[pairId];
        p.creator = msg.sender;
        p.name = name;
        p.symbol = symbol;
        p.baseReserve = initialBaseAmount;
        p.tokenReserve = initialTokenAmount;
        p.tokenTotalSupply = initialTokenAmount;
        p.lpTotalSupply = initialTokenAmount;
        p.exists = true;

        lpBalances[pairId][msg.sender] = initialTokenAmount;

        _safeTransferFrom(address(baseToken), msg.sender, address(this), totalNeeded);

        if (creationFee > 0) {
            _safeTransfer(address(baseToken), treasury, creationFee);
        }

        emit PairCreated(pairId, msg.sender, name, symbol, initialBaseAmount, initialTokenAmount, initialTokenAmount);
    }

    function addLiquidity(
        uint256 pairId,
        uint256 baseAmount,
        uint256 tokenAmount
    ) external nonReentrant whenNotPaused returns (uint256 lpShares) {
        Pair storage p = pairs[pairId];
        if (!p.exists) revert ErrPairNotFound();
        if (baseAmount == 0 || tokenAmount == 0) revert ErrInsufficientAmount();
        if (tokenBalances[pairId][msg.sender] < tokenAmount) revert ErrInsufficientBalance();
        if (baseToken.allowance(msg.sender, address(this)) < baseAmount) revert ErrInsufficientAllowance();
        if (p.lpTotalSupply == 0 || p.baseReserve == 0 || p.tokenReserve == 0) revert ErrInsufficientLiquidity();

        uint256 lpFromBase = (baseAmount * p.lpTotalSupply) / p.baseReserve;
        uint256 lpFromToken = (tokenAmount * p.lpTotalSupply) / p.tokenReserve;

        uint256 requiredBase;
        uint256 requiredToken;
        if (lpFromBase <= lpFromToken) {
            lpShares = lpFromBase;
            requiredBase = baseAmount;
            requiredToken = (baseAmount * p.tokenReserve) / p.baseReserve;
        } else {
            lpShares = lpFromToken;
            requiredToken = tokenAmount;
            requiredBase = (tokenAmount * p.baseReserve) / p.tokenReserve;
        }
        if (lpShares == 0) revert ErrZeroLiquidity();

        tokenBalances[pairId][msg.sender] -= requiredToken;
        p.baseReserve += requiredBase;
        p.tokenReserve += requiredToken;
        p.lpTotalSupply += lpShares;
        lpBalances[pairId][msg.sender] += lpShares;

        _safeTransferFrom(address(baseToken), msg.sender, address(this), requiredBase);

        emit LiquidityAdded(pairId, msg.sender, requiredBase, requiredToken, lpShares);
    }

    function removeLiquidity(
        uint256 pairId,
        uint256 lpAmount
    ) external nonReentrant whenNotPaused returns (uint256 baseOut, uint256 tokenOut) {
        Pair storage p = pairs[pairId];
        if (!p.exists) revert ErrPairNotFound();
        if (lpAmount == 0) revert ErrInsufficientAmount();
        if (lpBalances[pairId][msg.sender] < lpAmount) revert ErrInsufficientBalance();
        if (p.lpTotalSupply == 0) revert ErrInsufficientLiquidity();

        baseOut = (lpAmount * p.baseReserve) / p.lpTotalSupply;
        tokenOut = (lpAmount * p.tokenReserve) / p.lpTotalSupply;
        if (baseOut == 0 && tokenOut == 0) revert ErrZeroLiquidity();

        lpBalances[pairId][msg.sender] -= lpAmount;
        p.lpTotalSupply -= lpAmount;
        p.baseReserve -= baseOut;
        p.tokenReserve -= tokenOut;

        if (baseOut > 0) {
            _safeTransfer(address(baseToken), msg.sender, baseOut);
        }
        if (tokenOut > 0) {
            tokenBalances[pairId][msg.sender] += tokenOut;
        }

        emit LiquidityRemoved(pairId, msg.sender, baseOut, tokenOut, lpAmount);
    }

    function swapBaseForToken(
        uint256 pairId,
        uint256 baseAmountIn
    ) external nonReentrant whenNotPaused returns (uint256 tokenOut) {
        Pair storage p = pairs[pairId];
        if (!p.exists) revert ErrPairNotFound();
        if (baseAmountIn == 0) revert ErrInsufficientAmount();
        if (p.baseReserve == 0 || p.tokenReserve == 0) revert ErrInsufficientLiquidity();
        if (baseToken.allowance(msg.sender, address(this)) < baseAmountIn) revert ErrInsufficientAllowance();

        uint256 tax = (baseAmountIn * tradingTaxBps) / BPS_DENOMINATOR;
        uint256 effectiveIn = baseAmountIn - tax;
        if (effectiveIn == 0) revert ErrInsufficientAmount();

        tokenOut = (p.tokenReserve * effectiveIn) / (p.baseReserve + effectiveIn);
        if (tokenOut == 0 || tokenOut >= p.tokenReserve) revert ErrInsufficientLiquidity();

        p.baseReserve += effectiveIn;
        p.tokenReserve -= tokenOut;
        tokenBalances[pairId][msg.sender] += tokenOut;

        _safeTransferFrom(address(baseToken), msg.sender, address(this), baseAmountIn);
        if (tax > 0) {
            _safeTransfer(address(baseToken), treasury, tax);
        }

        emit Swap(pairId, msg.sender, true, baseAmountIn, tokenOut, tax);
    }

    function swapTokenForBase(
        uint256 pairId,
        uint256 tokenAmountIn
    ) external nonReentrant whenNotPaused returns (uint256 baseOutUser) {
        Pair storage p = pairs[pairId];
        if (!p.exists) revert ErrPairNotFound();
        if (tokenAmountIn == 0) revert ErrInsufficientAmount();
        if (p.baseReserve == 0 || p.tokenReserve == 0) revert ErrInsufficientLiquidity();
        if (tokenBalances[pairId][msg.sender] < tokenAmountIn) revert ErrInsufficientBalance();

        uint256 tax = (p.baseReserve * tokenAmountIn * tradingTaxBps) / ((p.tokenReserve + tokenAmountIn) * BPS_DENOMINATOR);
        uint256 baseOut = (p.baseReserve * tokenAmountIn) / (p.tokenReserve + tokenAmountIn);
        if (baseOut == 0 || baseOut >= p.baseReserve) revert ErrInsufficientLiquidity();

        baseOutUser = baseOut - tax;
        if (baseOutUser == 0) revert ErrInsufficientAmount();

        tokenBalances[pairId][msg.sender] -= tokenAmountIn;
        p.tokenReserve += tokenAmountIn;
        p.baseReserve -= baseOut;

        _safeTransfer(address(baseToken), msg.sender, baseOutUser);
        if (tax > 0) {
            _safeTransfer(address(baseToken), treasury, tax);
        }

        emit Swap(pairId, msg.sender, false, tokenAmountIn, baseOutUser, tax);
    }

    function transfer(uint256 pairId, address to, uint256 amount) external returns (bool) {
        if (!pairs[pairId].exists) revert ErrPairNotFound();
        if (to == address(0)) revert ErrZeroAddress();
        if (tokenBalances[pairId][msg.sender] < amount) revert ErrInsufficientBalance();
        tokenBalances[pairId][msg.sender] -= amount;
        tokenBalances[pairId][to] += amount;
        emit Transfer(pairId, msg.sender, to, amount);
        return true;
    }

    function transferFrom(uint256 pairId, address from, address to, uint256 amount) external returns (bool) {
        if (!pairs[pairId].exists) revert ErrPairNotFound();
        if (to == address(0)) revert ErrZeroAddress();
        if (tokenBalances[pairId][from] < amount) revert ErrInsufficientBalance();
        if (tokenAllowances[pairId][from][msg.sender] < amount) revert ErrInsufficientAllowance();
        tokenAllowances[pairId][from][msg.sender] -= amount;
        tokenBalances[pairId][from] -= amount;
        tokenBalances[pairId][to] += amount;
        emit Transfer(pairId, from, to, amount);
        return true;
    }

    function approve(uint256 pairId, address spender, uint256 amount) external returns (bool) {
        if (!pairs[pairId].exists) revert ErrPairNotFound();
        if (spender == address(0)) revert ErrZeroAddress();
        tokenAllowances[pairId][msg.sender][spender] = amount;
        emit Approval(pairId, msg.sender, spender, amount);
        return true;
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        if (!ok) revert ErrTransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert ErrTransferFailed();
    }
}
