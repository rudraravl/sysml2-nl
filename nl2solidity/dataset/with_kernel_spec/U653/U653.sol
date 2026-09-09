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
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

interface IDecentralizedIdentity {
    function isVerified(address account) external view returns (bool);
    function isOperator(address account) external view returns (bool);
}

contract BondingToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public immutable factory;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        factory = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == factory, "ONLY_FACTORY");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == factory, "ONLY_FACTORY");
        require(balanceOf[from] >= amount, "INSUFFICIENT_BALANCE");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ALLOWANCE_EXCEEDED");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "INSUFFICIENT_BALANCE");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

contract CurveMarket {
    using SafeERC20 for IERC20;

    error ErrZeroAddress();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrTokenNotFound();
    error ErrAmountZero();
    error ErrInsufficientDeposit();
    error ErrInsufficientBaseBalance();
    error ErrInvalidParameters();
    error ErrReentrant();
    error ErrInsufficientTokenBalance();

    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 slope,
        uint256 basePrice,
        uint256 initialDeposit
    );
    event Buy(address indexed token, address indexed buyer, uint256 amount, uint256 cost);
    event Sell(address indexed token, address indexed seller, uint256 amount, uint256 grossProceeds, uint256 fee);
    event CurveParametersUpdated(address indexed token, uint256 slope, uint256 basePrice);
    event Withdrawal(address indexed account, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event IdentityVerifierUpdated(address indexed newVerifier);

    uint256 public constant MIN_INITIAL_DEPOSIT = 100;
    uint256 public constant FEE_BPS = 500;

    IERC20 public immutable baseCurrency;
    address public owner;
    IDecentralizedIdentity public identityVerifier;

    struct TokenInfo {
        address creator;
        uint256 slope;
        uint256 basePrice;
        uint256 totalSupply;
        uint256 baseBalance;
        bool exists;
    }

    mapping(address => TokenInfo) public tokenInfo;
    address[] public allTokens;
    mapping(address => uint256) public withdrawable;

    uint256 private _status = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!identityVerifier.isOperator(msg.sender)) revert ErrNotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ErrReentrant();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address _baseCurrency, address _identityVerifier, address _owner) {
        if (_baseCurrency == address(0) || _identityVerifier == address(0) || _owner == address(0)) {
            revert ErrZeroAddress();
        }
        baseCurrency = IERC20(_baseCurrency);
        identityVerifier = IDecentralizedIdentity(_identityVerifier);
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function createToken(
        string calldata name_,
        string calldata symbol_,
        uint256 slope_,
        uint256 basePrice_,
        uint256 initialDeposit_
    ) external onlyOperator nonReentrant returns (address token) {
        if (initialDeposit_ < MIN_INITIAL_DEPOSIT) revert ErrInsufficientDeposit();
        if (slope_ == 0 || basePrice_ == 0) revert ErrInvalidParameters();

        BondingToken newToken = new BondingToken(name_, symbol_);
        token = address(newToken);

        tokenInfo[token] = TokenInfo({
            creator: msg.sender,
            slope: slope_,
            basePrice: basePrice_,
            totalSupply: 0,
            baseBalance: initialDeposit_,
            exists: true
        });
        allTokens.push(token);

        baseCurrency.safeTransferFrom(msg.sender, address(this), initialDeposit_);

        emit TokenCreated(token, msg.sender, name_, symbol_, slope_, basePrice_, initialDeposit_);
    }

    function buy(address token, uint256 amount) external nonReentrant {
        TokenInfo storage t = tokenInfo[token];
        if (!t.exists) revert ErrTokenNotFound();
        if (amount == 0) revert ErrAmountZero();

        uint256 cost = _getBuyCost(t, amount);
        if (cost == 0) revert ErrInvalidParameters();

        // Effects before interactions
        t.totalSupply += amount;
        t.baseBalance += cost;

        // Interactions
        baseCurrency.safeTransferFrom(msg.sender, address(this), cost);
        BondingToken(token).mint(msg.sender, amount);

        emit Buy(token, msg.sender, amount, cost);
    }

    function sell(address token, uint256 amount) external nonReentrant {
        TokenInfo storage t = tokenInfo[token];
        if (!t.exists) revert ErrTokenNotFound();
        if (amount == 0) revert ErrAmountZero();
        if (amount > t.totalSupply) revert ErrInvalidParameters();
        if (BondingToken(token).balanceOf(msg.sender) < amount) revert ErrInsufficientTokenBalance();

        uint256 gross = _getSellReturn(t, amount);
        if (gross == 0) revert ErrInvalidParameters();
        if (t.baseBalance < gross) revert ErrInsufficientBaseBalance();

        uint256 fee = (gross * FEE_BPS) / 10000;
        uint256 net = gross - fee;

        // Effects before interactions
        t.totalSupply -= amount;
        t.baseBalance -= gross;
        withdrawable[msg.sender] += net;
        withdrawable[owner] += fee;

        // Interactions
        BondingToken(token).burn(msg.sender, amount);

        emit Sell(token, msg.sender, amount, gross, fee);
    }

    function withdraw() external nonReentrant {
        uint256 amount = withdrawable[msg.sender];
        if (amount == 0) revert ErrAmountZero();
        withdrawable[msg.sender] = 0;
        baseCurrency.safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    function setCurveParameters(address token, uint256 newSlope, uint256 newBasePrice) external onlyOwner {
        TokenInfo storage t = tokenInfo[token];
        if (!t.exists) revert ErrTokenNotFound();
        if (newSlope == 0 || newBasePrice == 0) revert ErrInvalidParameters();
        t.slope = newSlope;
        t.basePrice = newBasePrice;
        emit CurveParametersUpdated(token, newSlope, newBasePrice);
    }

    function setIdentityVerifier(address newVerifier) external onlyOwner {
        if (newVerifier == address(0)) revert ErrZeroAddress();
        identityVerifier = IDecentralizedIdentity(newVerifier);
        emit IdentityVerifierUpdated(newVerifier);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function getBuyCost(address token, uint256 amount) external view returns (uint256) {
        TokenInfo storage t = tokenInfo[token];
        if (!t.exists) revert ErrTokenNotFound();
        return _getBuyCost(t, amount);
    }

    function getSellReturn(address token, uint256 amount) external view returns (uint256) {
        TokenInfo storage t = tokenInfo[token];
        if (!t.exists) revert ErrTokenNotFound();
        if (amount > t.totalSupply) revert ErrInvalidParameters();
        return _getSellReturn(t, amount);
    }

    function getTokenInfo(address token) external view returns (TokenInfo memory) {
        return tokenInfo[token];
    }

    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }

    function getWithdrawableBalance(address account) external view returns (uint256) {
        return withdrawable[account];
    }

    function _getBuyCost(TokenInfo storage t, uint256 amount) internal view returns (uint256) {
        uint256 S = t.totalSupply;
        uint256 cost = (t.slope * amount * (2 * S + amount)) / 2 + t.basePrice * amount;
        return cost;
    }

    function _getSellReturn(TokenInfo storage t, uint256 amount) internal view returns (uint256) {
        uint256 S = t.totalSupply;
        uint256 ret = (t.slope * amount * (2 * S - amount)) / 2 + t.basePrice * amount;
        return ret;
    }
}
