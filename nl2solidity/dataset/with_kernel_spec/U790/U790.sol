// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWrappedNative {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

error NotOwner();
error NotAuthorized();
error ZeroAddress();
error Paused();
error InsufficientBalance();
error InsufficientAllowance();
error BelowMinimumDeposit();
error FeeExceedsMaximum();
error ZeroAmount();
error TransferFailed();

contract CreatorVault {
    IWrappedNative public immutable wrappedNative;
    address public owner;
    address public operator;
    bool public paused;

    uint256 public feePercentage; // in basis points (1 bp = 0.01%)
    uint256 public constant MAX_FEE_BPS = 500; // 5%
    uint256 public constant MIN_MINT_DEPOSIT = 0.01 ether;

    uint256 public totalSupply;
    mapping(address => uint256) public wrappedBalances;
    mapping(address => uint256) public projectBalances;
    mapping(address => mapping(address => uint256)) public allowances;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorSet(address indexed previousOperator, address indexed newOperator);
    event PausedStateChanged(bool paused);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);

    event Deposit(address indexed sender, address indexed recipient, uint256 amount);
    event Withdrawal(address indexed sender, address indexed recipient, uint256 amount);
    event Mint(address indexed sender, address indexed recipient, uint256 amount);
    event Burn(address indexed sender, address indexed recipient, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner && msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(address _wrappedNative, uint256 _feePercentage) {
        if (_wrappedNative == address(0)) revert ZeroAddress();
        if (_feePercentage > MAX_FEE_BPS) revert FeeExceedsMaximum();
        wrappedNative = IWrappedNative(_wrappedNative);
        owner = msg.sender;
        feePercentage = _feePercentage;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeePercentageUpdated(0, _feePercentage);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        emit OperatorSet(operator, _operator);
        operator = _operator;
    }

    function setPaused(bool _paused) external onlyOwnerOrOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        if (_feePercentage > MAX_FEE_BPS) revert FeeExceedsMaximum();
        uint256 oldFee = feePercentage;
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(oldFee, _feePercentage);
    }

    function depositWrapped(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        bool ok = wrappedNative.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        wrappedBalances[msg.sender] += amount;
        emit Deposit(msg.sender, msg.sender, amount);
    }

    function withdrawWrapped(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = wrappedBalances[msg.sender];
        if (bal < amount) revert InsufficientBalance();
        wrappedBalances[msg.sender] = bal - amount;
        bool ok = wrappedNative.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit Withdrawal(msg.sender, msg.sender, amount);
    }

    function mint(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_MINT_DEPOSIT) revert BelowMinimumDeposit();

        uint256 fee = (amount * feePercentage) / 10_000;
        uint256 locked = amount - fee;

        uint256 bal = wrappedBalances[msg.sender];
        if (bal < amount) revert InsufficientBalance();
        wrappedBalances[msg.sender] = bal - amount;

        if (fee > 0) {
            wrappedBalances[owner] += fee;
        }

        projectBalances[msg.sender] += locked;
        totalSupply += locked;

        emit Mint(msg.sender, msg.sender, locked);
        emit Transfer(address(0), msg.sender, locked);
    }

    function burn(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = projectBalances[msg.sender];
        if (bal < amount) revert InsufficientBalance();

        projectBalances[msg.sender] = bal - amount;
        totalSupply -= amount;

        uint256 fee = (amount * feePercentage) / 10_000;
        uint256 unlocked = amount - fee;

        wrappedBalances[msg.sender] += unlocked;
        if (fee > 0) {
            wrappedBalances[owner] += fee;
        }

        emit Burn(msg.sender, msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 bal = projectBalances[from];
        if (bal < amount) revert InsufficientBalance();
        projectBalances[from] = bal - amount;
        projectBalances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function projectBalanceOf(address account) external view returns (uint256) {
        return projectBalances[account];
    }

    function wrappedBalanceOf(address account) external view returns (uint256) {
        return wrappedBalances[account];
    }

    function allowance(address account, address spender) external view returns (uint256) {
        return allowances[account][spender];
    }
}
