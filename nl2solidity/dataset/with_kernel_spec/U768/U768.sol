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

contract LiquidStaking {
    error LiquidStaking__ZeroAddress();
    error LiquidStaking__NotOperator();
    error LiquidStaking__NotOwner();
    error LiquidStaking__ZeroAmount();
    error LiquidStaking__InsufficientBalance();
    error LiquidStaking__InsufficientAllowance();
    error LiquidStaking__NotReady(uint256 availableAt);
    error LiquidStaking__AlreadyClaimed();
    error LiquidStaking__NotRequestOwner();
    error LiquidStaking__FeeTooHigh(uint256 proposed, uint256 max);
    error LiquidStaking__InsufficientBaseAsset(uint256 available, uint256 required);
    error LiquidStaking__ExchangeRateZero();
    error LiquidStaking__TransferFailed();
    error LiquidStaking__ReentrantCall();
    error LiquidStaking__ExchangeRateCanOnlyIncrease(uint256 oldRate, uint256 newRate);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed user, uint256 baseAmount, uint256 lstMinted, uint256 exchangeRate);
    event Redeem(address indexed user, uint256 indexed requestId, uint256 lstAmount, uint256 baseAmount, uint256 fee, uint256 availableAt);
    event Claimed(address indexed user, uint256 indexed requestId, uint256 baseAmount);
    event ExchangeRateUpdated(uint256 oldExchangeRate, uint256 newExchangeRate, address indexed operator);
    event Staked(address indexed operator, address indexed target, uint256 amount);
    event Unstaked(address indexed operator, address indexed source, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event ProtocolFeeUpdated(uint256 previousBps, uint256 newBps);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
    uint256 public constant REDEMPTION_DELAY = 7 days;
    uint256 public constant MAX_PROTOCOL_FEE_BPS = 1000;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable baseAsset;
    address public owner;
    address public operator;
    address public feeRecipient;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public exchangeRate;
    uint256 public totalBaseAsset;
    uint256 public stakedBaseAsset;
    uint256 public accruedFees;
    uint256 public protocolFeeBps;

    struct WithdrawalRequest {
        address user;
        uint256 baseAmount;
        uint256 availableAt;
        bool claimed;
    }

    uint256 public nextRequestId;
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    mapping(address => uint256[]) public userRequestIds;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier onlyOwner() {
        if (msg.sender != owner) revert LiquidStaking__NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert LiquidStaking__NotOperator();
        _;
    }

    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) revert LiquidStaking__ZeroAddress();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert LiquidStaking__ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(
        address _baseAsset,
        address _operator,
        address _feeRecipient,
        string memory lstName,
        string memory lstSymbol
    ) nonZeroAddress(_baseAsset) nonZeroAddress(_operator) nonZeroAddress(_feeRecipient) {
        baseAsset = IERC20(_baseAsset);
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        name = lstName;
        symbol = lstSymbol;
        exchangeRate = EXCHANGE_RATE_PRECISION;
        protocolFeeBps = 10;
        nextRequestId = 1;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 accountBalance = _balances[from];
        if (accountBalance < amount) revert LiquidStaking__InsufficientBalance();
        unchecked {
            _balances[from] = accountBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[tokenOwner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert LiquidStaking__InsufficientAllowance();
            unchecked { _approve(tokenOwner, spender, currentAllowance - amount); }
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert LiquidStaking__TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert LiquidStaking__TransferFailed();
    }

    function balanceOf(address account) external view returns (uint256) { return _balances[account]; }
    function allowance(address tokenOwner, address spender) external view returns (uint256) { return _allowances[tokenOwner][spender]; }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert LiquidStaking__ZeroAddress();
        uint256 senderBalance = _balances[msg.sender];
        if (senderBalance < amount) revert LiquidStaking__InsufficientBalance();
        unchecked { _balances[msg.sender] = senderBalance - amount; _balances[to] += amount; }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert LiquidStaking__ZeroAddress();
        _spendAllowance(from, msg.sender, amount);
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert LiquidStaking__InsufficientBalance();
        unchecked { _balances[from] = fromBalance - amount; _balances[to] += amount; }
        emit Transfer(from, to, amount);
        return true;
    }

    function deposit(uint256 baseAmount) external nonReentrant returns (uint256 lstMinted) {
        if (baseAmount == 0) revert LiquidStaking__ZeroAmount();
        uint256 rate = exchangeRate;
        if (rate == 0) revert LiquidStaking__ExchangeRateZero();
        _safeTransferFrom(address(baseAsset), msg.sender, address(this), baseAmount);
        lstMinted = (baseAmount * EXCHANGE_RATE_PRECISION) / rate;
        if (lstMinted == 0) revert LiquidStaking__ZeroAmount();
        totalBaseAsset += baseAmount;
        _mint(msg.sender, lstMinted);
        emit Deposit(msg.sender, baseAmount, lstMinted, rate);
    }

    function redeem(uint256 lstAmount) external nonReentrant returns (uint256 requestId) {
        if (lstAmount == 0) revert LiquidStaking__ZeroAmount();
        if (_balances[msg.sender] < lstAmount) revert LiquidStaking__InsufficientBalance();
        uint256 rate = exchangeRate;
        if (rate == 0) revert LiquidStaking__ExchangeRateZero();

        // Compute base amount and fee using full-precision numerator to avoid
        // divide-before-multiply rounding errors.
        uint256 numerator = lstAmount * rate;
        uint256 baseAmount = numerator / EXCHANGE_RATE_PRECISION;
        if (baseAmount == 0) revert LiquidStaking__ZeroAmount();
        uint256 fee = (numerator * protocolFeeBps) / (EXCHANGE_RATE_PRECISION * BPS_DENOMINATOR);
        uint256 redeemable = baseAmount - fee;

        _burn(msg.sender, lstAmount);
        totalBaseAsset -= baseAmount;
        accruedFees += fee;

        requestId = nextRequestId++;
        withdrawalRequests[requestId] = WithdrawalRequest({
            user: msg.sender,
            baseAmount: redeemable,
            availableAt: block.timestamp + REDEMPTION_DELAY,
            claimed: false
        });
        userRequestIds[msg.sender].push(requestId);

        emit Redeem(msg.sender, requestId, lstAmount, redeemable, fee, block.timestamp + REDEMPTION_DELAY);
    }

    function claimRedemption(uint256 requestId) external nonReentrant {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.user == address(0)) revert LiquidStaking__NotRequestOwner();
        if (req.user != msg.sender) revert LiquidStaking__NotRequestOwner();
        if (req.claimed) revert LiquidStaking__AlreadyClaimed();
        if (block.timestamp < req.availableAt) revert LiquidStaking__NotReady(req.availableAt);
        uint256 amount = req.baseAmount;
        uint256 contractBalance = baseAsset.balanceOf(address(this));
        if (contractBalance < amount) revert LiquidStaking__InsufficientBaseAsset(contractBalance, amount);
        req.claimed = true;
        _safeTransfer(address(baseAsset), msg.sender, amount);
        emit Claimed(msg.sender, requestId, amount);
    }

    function stake(uint256 amount, address target) external onlyOperator nonZeroAddress(target) nonReentrant {
        if (amount == 0) revert LiquidStaking__ZeroAmount();
        uint256 available = baseAsset.balanceOf(address(this));
        if (available < amount) revert LiquidStaking__InsufficientBaseAsset(available, amount);
        stakedBaseAsset += amount;
        _safeTransfer(address(baseAsset), target, amount);
        emit Staked(msg.sender, target, amount);
    }

    function unstake(uint256 amount, address source) external onlyOperator nonZeroAddress(source) nonReentrant {
        if (amount == 0) revert LiquidStaking__ZeroAmount();
        if (stakedBaseAsset < amount) revert LiquidStaking__InsufficientBalance();
        stakedBaseAsset -= amount;
        _safeTransferFrom(address(baseAsset), source, address(this), amount);
        emit Unstaked(msg.sender, source, amount);
    }

    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert LiquidStaking__ExchangeRateZero();
        if (newRate <= exchangeRate) revert LiquidStaking__ExchangeRateCanOnlyIncrease(exchangeRate, newRate);
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate, msg.sender);
    }

    function setOperator(address newOperator) external onlyOwner nonZeroAddress(newOperator) {
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function setProtocolFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_PROTOCOL_FEE_BPS) revert LiquidStaking__FeeTooHigh(newFeeBps, MAX_PROTOCOL_FEE_BPS);
        uint256 previous = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(previous, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner nonZeroAddress(newRecipient) {
        address previous = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(previous, newRecipient);
    }

    function transferOwnership(address newOwner) external onlyOwner nonZeroAddress(newOwner) {
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accruedFees;
        if (amount == 0) revert LiquidStaking__ZeroAmount();
        uint256 contractBalance = baseAsset.balanceOf(address(this));
        if (contractBalance < amount) revert LiquidStaking__InsufficientBaseAsset(contractBalance, amount);
        accruedFees = 0;
        _safeTransfer(address(baseAsset), feeRecipient, amount);
        emit FeesWithdrawn(feeRecipient, amount);
    }

    function getUserRequestIds(address user) external view returns (uint256[] memory) { return userRequestIds[user]; }

    function getWithdrawalRequest(uint256 requestId) external view returns (address user, uint256 baseAmount, uint256 availableAt, bool claimed) {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        return (req.user, req.baseAmount, req.availableAt, req.claimed);
    }

    function contractBaseBalance() external view returns (uint256) { return baseAsset.balanceOf(address(this)); }

    function previewDeposit(uint256 baseAmount) external view returns (uint256) {
        if (exchangeRate == 0) return 0;
        return (baseAmount * EXCHANGE_RATE_PRECISION) / exchangeRate;
    }

    function previewRedeem(uint256 lstAmount) external view returns (uint256 redeemable, uint256 fee) {
        if (exchangeRate == 0) return (0, 0);
        // Use full-precision numerator to avoid divide-before-multiply rounding.
        uint256 numerator = lstAmount * exchangeRate;
        uint256 baseAmount = numerator / EXCHANGE_RATE_PRECISION;
        fee = (numerator * protocolFeeBps) / (EXCHANGE_RATE_PRECISION * BPS_DENOMINATOR);
        redeemable = baseAmount - fee;
    }
}
