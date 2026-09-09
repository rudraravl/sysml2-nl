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

contract LiquidRestakingToken {
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidExchangeRate();
    error ExchangeRateCooldown();
    error ContractPaused();
    error ContractNotPaused();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientLiquidity();
    error InsufficientFees();
    error Reentrant();
    error BaseTransferFailed();

    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant SCALE = 1e18;
    uint256 public constant EXCHANGE_RATE_UPDATE_COOLDOWN = 24 hours;

    IERC20 public immutable baseToken;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => uint256) public baseTokenDeposits;

    uint256 public exchangeRate;
    uint256 public lastExchangeRateUpdate;
    uint256 public accumulatedFees;

    address public owner;
    address public operator;
    bool public paused;

    bool private _locked;

    event Deposit(address indexed account, uint256 baseAmount, uint256 lstAmount);
    event Withdrawal(address indexed account, uint256 lstAmount, uint256 netBaseAmount, uint256 feeAmount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event ProtocolWithdrawal(address indexed to, uint256 amount);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address baseToken_,
        uint256 initialExchangeRate_,
        string memory name_,
        string memory symbol_
    ) {
        if (baseToken_ == address(0)) revert ZeroAddress();
        if (initialExchangeRate_ == 0) revert InvalidExchangeRate();

        owner = msg.sender;
        operator = msg.sender;
        paused = false;

        baseToken = IERC20(baseToken_);
        exchangeRate = initialExchangeRate_;
        lastExchangeRateUpdate = block.timestamp;

        name = name_;
        symbol = symbol_;

        emit OperatorUpdated(address(0), operator);
    }

    function deposit(uint256 baseAmount) external nonReentrant whenNotPaused returns (uint256 lstAmount) {
        if (baseAmount == 0) revert ZeroAmount();

        lstAmount = (baseAmount * SCALE) / exchangeRate;
        if (lstAmount == 0) revert InvalidExchangeRate();

        baseTokenDeposits[msg.sender] += baseAmount;
        _mint(msg.sender, lstAmount);

        if (!baseToken.transferFrom(msg.sender, address(this), baseAmount)) {
            revert BaseTransferFailed();
        }

        emit Deposit(msg.sender, baseAmount, lstAmount);
    }

    function withdraw(uint256 lstAmount) external nonReentrant whenNotPaused returns (uint256 netBaseAmount) {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();

        uint256 grossBaseAmount = (lstAmount * exchangeRate) / SCALE;
        if (grossBaseAmount == 0) revert InvalidExchangeRate();

        uint256 feeAmount = (lstAmount * exchangeRate * WITHDRAWAL_FEE_BPS) / (SCALE * BPS_DENOMINATOR);
        netBaseAmount = grossBaseAmount - feeAmount;
        if (netBaseAmount == 0) revert ZeroAmount();

        if (baseToken.balanceOf(address(this)) < grossBaseAmount) revert InsufficientLiquidity();

        _burn(msg.sender, lstAmount);
        accumulatedFees += feeAmount;

        if (!baseToken.transfer(msg.sender, netBaseAmount)) {
            revert BaseTransferFailed();
        }

        emit Withdrawal(msg.sender, lstAmount, netBaseAmount, feeAmount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            if (allowance[from][msg.sender] < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] -= amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        allowance[msg.sender][spender] = currentAllowance - subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function withdrawToProtocol(address to, uint256 amount) external onlyOperator nonReentrant whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > availableForRestaking()) revert InsufficientLiquidity();

        if (!baseToken.transfer(to, amount)) {
            revert BaseTransferFailed();
        }

        emit ProtocolWithdrawal(to, amount);
    }

    function setExchangeRate(uint256 newRate) external onlyOwner {
        if (newRate == 0) revert InvalidExchangeRate();
        if (block.timestamp <= lastExchangeRateUpdate + EXCHANGE_RATE_UPDATE_COOLDOWN) {
            revert ExchangeRateCooldown();
        }

        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        lastExchangeRateUpdate = block.timestamp;

        emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();

        address oldOperator = operator;
        operator = newOperator;

        emit OperatorUpdated(oldOperator, newOperator);
    }

    function pause() external onlyOwner {
        if (paused) revert ContractPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert ContractNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function withdrawFees(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accumulatedFees) revert InsufficientFees();
        if (baseToken.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        accumulatedFees -= amount;

        if (!baseToken.transfer(to, amount)) {
            revert BaseTransferFailed();
        }

        emit FeesWithdrawn(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function previewDeposit(uint256 baseAmount) external view returns (uint256) {
        return (baseAmount * SCALE) / exchangeRate;
    }

    function previewWithdraw(uint256 lstAmount) external view returns (uint256 netBaseAmount, uint256 feeAmount) {
        uint256 grossBaseAmount = (lstAmount * exchangeRate) / SCALE;
        feeAmount = (lstAmount * exchangeRate * WITHDRAWAL_FEE_BPS) / (SCALE * BPS_DENOMINATOR);
        netBaseAmount = grossBaseAmount - feeAmount;
    }

    function underlyingBalanceOf(address account) external view returns (uint256) {
        return (balanceOf[account] * exchangeRate) / SCALE;
    }

    function totalBaseAssets() external view returns (uint256) {
        return (totalSupply * exchangeRate) / SCALE;
    }

    function availableForRestaking() public view returns (uint256) {
        uint256 balance = baseToken.balanceOf(address(this));
        if (balance < accumulatedFees) return 0;
        return balance - accumulatedFees;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }
}
