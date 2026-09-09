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

contract Token is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    address public immutable launcher;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address _launcher
    ) {
        name = _name;
        symbol = _symbol;
        launcher = _launcher;
        totalSupply = _supply;
        balanceOf[_launcher] = _supply;
        emit Transfer(address(0), _launcher, _supply);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == launcher, "Token: only launcher");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[sender][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "Token: insufficient allowance");
            allowance[sender][msg.sender] = allowed - amount;
        }
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(balanceOf[sender] >= amount, "Token: insufficient balance");
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
}

contract TokenLauncher {
    IERC20 public immutable baseToken;
    address public owner;
    uint256 public platformFeePct; // expressed in percent (1 = 1%)
    uint256 public constant MAX_FEE = 5;
    uint256 public collectedFees; // collected platform fees in base token

    struct TokenRecord {
        address token;
        address creator;
        uint256 totalSupply;
        uint256 baseReserve;
        uint256 tokenReserve;
        bool exists;
    }

    mapping(address => TokenRecord) public tokens;
    address[] public allTokens;

    uint256 private _locked = 1;

    event TokenLaunched(address indexed token, address indexed creator, uint256 totalSupply, uint256 initialBaseAmount);
    event LiquidityAdded(address indexed token, address indexed contributor, uint256 baseAdded, uint256 tokensMinted);
    event Swap(address indexed user, address indexed token, bool baseToToken, uint256 amountIn, uint256 amountOut, uint256 fee);
    event PlatformFeeUpdated(uint256 newFeePct);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error NotOwner();
    error ZeroAddress();
    error TokenNotFound(address token);
    error FeeTooHigh(uint256 pct);
    error InsufficientInput();
    error SlippageExceeded();
    error TransferFailed();
    error Reentrancy();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _baseToken) {
        if (_baseToken == address(0)) revert ZeroAddress();
        baseToken = IERC20(_baseToken);
        owner = msg.sender;
        platformFeePct = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit PlatformFeeUpdated(1);
    }

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }

    function getTokenRecord(address token) external view returns (TokenRecord memory) {
        return tokens[token];
    }

    function launchToken(
        string calldata _name,
        string calldata _symbol,
        uint256 _initialSupply,
        uint256 _initialBaseAmount
    ) external nonReentrant returns (address token) {
        if (_initialSupply == 0 || _initialBaseAmount == 0) revert InsufficientInput();

        Token t = new Token(_name, _symbol, _initialSupply, address(this));
        token = address(t);

        tokens[token] = TokenRecord({
            token: token,
            creator: msg.sender,
            totalSupply: _initialSupply,
            baseReserve: _initialBaseAmount,
            tokenReserve: _initialSupply,
            exists: true
        });
        allTokens.push(token);

        bool ok = baseToken.transferFrom(msg.sender, address(this), _initialBaseAmount);
        if (!ok) revert TransferFailed();

        emit TokenLaunched(token, msg.sender, _initialSupply, _initialBaseAmount);
    }

    function contributeLiquidity(address token, uint256 baseAmount) external nonReentrant {
        TokenRecord storage r = tokens[token];
        if (!r.exists) revert TokenNotFound(token);
        if (baseAmount == 0) revert InsufficientInput();

        uint256 newTokenReserve = (r.tokenReserve * (r.baseReserve + baseAmount)) / r.baseReserve;
        uint256 mintAmount = newTokenReserve - r.tokenReserve;

        r.baseReserve += baseAmount;
        r.tokenReserve = newTokenReserve;
        r.totalSupply += mintAmount;

        bool ok = baseToken.transferFrom(msg.sender, address(this), baseAmount);
        if (!ok) revert TransferFailed();

        Token(token).mint(address(this), mintAmount);

        emit LiquidityAdded(token, msg.sender, baseAmount, mintAmount);
    }

    function swapBaseForToken(address token, uint256 baseIn, uint256 minTokenOut)
        external
        nonReentrant
        returns (uint256 tokenOut)
    {
        TokenRecord storage r = tokens[token];
        if (!r.exists) revert TokenNotFound(token);
        if (baseIn == 0) revert InsufficientInput();

        uint256 fee = (baseIn * platformFeePct) / 100;
        uint256 effectiveIn = baseIn - fee;

        tokenOut = (r.tokenReserve * effectiveIn) / (r.baseReserve + effectiveIn);
        if (tokenOut < minTokenOut) revert SlippageExceeded();

        collectedFees += fee;
        r.baseReserve += effectiveIn;
        r.tokenReserve -= tokenOut;

        bool ok = baseToken.transferFrom(msg.sender, address(this), baseIn);
        if (!ok) revert TransferFailed();

        ok = Token(token).transfer(msg.sender, tokenOut);
        if (!ok) revert TransferFailed();

        emit Swap(msg.sender, token, true, effectiveIn, tokenOut, fee);
    }

    function swapTokenForBase(address token, uint256 tokenIn, uint256 minBaseOut)
        external
        nonReentrant
        returns (uint256 baseOut)
    {
        TokenRecord storage r = tokens[token];
        if (!r.exists) revert TokenNotFound(token);
        if (tokenIn == 0) revert InsufficientInput();

        uint256 fee = (tokenIn * platformFeePct) / 100;
        uint256 effectiveIn = tokenIn - fee;

        baseOut = (r.baseReserve * effectiveIn) / (r.tokenReserve + effectiveIn);
        if (baseOut < minBaseOut) revert SlippageExceeded();

        r.tokenReserve += effectiveIn;
        r.baseReserve -= baseOut;

        bool ok = Token(token).transferFrom(msg.sender, address(this), tokenIn);
        if (!ok) revert TransferFailed();

        ok = baseToken.transfer(msg.sender, baseOut);
        if (!ok) revert TransferFailed();

        emit Swap(msg.sender, token, false, effectiveIn, baseOut, fee);
    }

    function setPlatformFeePct(uint256 _pct) external onlyOwner {
        if (_pct > MAX_FEE) revert FeeTooHigh(_pct);
        platformFeePct = _pct;
        emit PlatformFeeUpdated(_pct);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdrawCollectedFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = collectedFees;
        collectedFees = 0;
        bool ok = baseToken.transfer(to, amount);
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    function withdrawExcessTokenFees(address token, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        TokenRecord storage r = tokens[token];
        if (!r.exists) revert TokenNotFound(token);
        uint256 contractBalance = Token(token).balanceOf(address(this));
        require(contractBalance >= r.tokenReserve, "TokenLauncher: no excess");
        uint256 excess = contractBalance - r.tokenReserve;
        bool ok = Token(token).transfer(to, excess);
        if (!ok) revert TransferFailed();
    }
}
