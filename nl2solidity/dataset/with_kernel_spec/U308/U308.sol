// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract WrappedStakedAsset {
    // ---------- Custom Errors ----------
    error ZeroAddress();
    error ZeroAmount();
    error EnforcedPause();
    error NotOperator();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientExcess();
    error UnderlyingTransferFailed();
    error ReentrantCall();

    // ---------- Events ----------
    event Deposit(address indexed sender, address indexed recipient, uint256 amount);
    event Mint(address indexed caller, address indexed recipient, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Redeem(address indexed sender, address indexed recipient, uint256 amount);
    event ForcedRedeem(address indexed operator, address indexed recipient, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ---------- Metadata ----------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ---------- Underlying & Operator ----------
    IERC20 public immutable underlying;
    address public operator;
    bool public paused;

    // ---------- Supply & Holdings ----------
    uint256 public totalSupply;
    uint256 public totalUnderlyingHeld;

    // ---------- Balances & Allowances ----------
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------- Fee Configuration ----------
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ---------- Reentrancy Guard ----------
    uint256 private _status = 1;

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    // ---------- Constructor ----------
    constructor(address _underlying, string memory _name, string memory _symbol) {
        if (_underlying == address(0)) revert ZeroAddress();
        underlying = IERC20(_underlying);
        name = _name;
        symbol = _symbol;
        operator = msg.sender;
        emit OperatorChanged(address(0), msg.sender);
    }

    // ---------- Deposit ----------
    function deposit(uint256 amount) external nonReentrant returns (uint256) {
        return _deposit(msg.sender, msg.sender, amount);
    }

    function depositTo(address recipient, uint256 amount) external nonReentrant returns (uint256) {
        if (recipient == address(0)) revert ZeroAddress();
        return _deposit(msg.sender, recipient, amount);
    }

    function _deposit(address sender, address recipient, uint256 amount) internal returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        bool ok = underlying.transferFrom(sender, address(this), amount);
        if (!ok) revert UnderlyingTransferFailed();
        totalUnderlyingHeld += amount;
        _mint(sender, recipient, amount);
        emit Deposit(sender, recipient, amount);
        return amount;
    }

    // ---------- Redeem ----------
    function redeem(uint256 amount) external nonReentrant whenNotPaused returns (uint256) {
        return _redeem(msg.sender, msg.sender, amount);
    }

    function redeemTo(address recipient, uint256 amount) external nonReentrant whenNotPaused returns (uint256) {
        if (recipient == address(0)) revert ZeroAddress();
        return _redeem(msg.sender, recipient, amount);
    }

    function _redeem(address from, address recipient, uint256 amount) internal returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        uint256 fee = (amount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 underlyingOut = amount - fee;
        _burn(from, amount);
        totalUnderlyingHeld -= amount;
        bool ok = underlying.transfer(recipient, underlyingOut);
        if (!ok) revert UnderlyingTransferFailed();
        emit Redeem(from, recipient, underlyingOut);
        return underlyingOut;
    }

    // ---------- Forced Redemption (Operator only) ----------
    function forceRedeem(address recipient, uint256 amount) external onlyOperator nonReentrant returns (uint256) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 excess = underlying.balanceOf(address(this)) - totalUnderlyingHeld;
        if (amount > excess) revert InsufficientExcess();
        bool ok = underlying.transfer(recipient, amount);
        if (!ok) revert UnderlyingTransferFailed();
        emit ForcedRedeem(msg.sender, recipient, amount);
        return amount;
    }

    // ---------- ERC20 Transfer ----------
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // ---------- ERC20 Approval ----------
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 added) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + added;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtracted) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 current = allowance[msg.sender][spender];
        if (current < subtracted) revert InsufficientAllowance();
        uint256 newAllowance = current - subtracted;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    // ---------- Pause Controls ----------
    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // ---------- View Helpers ----------
    function underlyingBalance() external view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    function accumulatedFees() external view returns (uint256) {
        return underlying.balanceOf(address(this)) - totalUnderlyingHeld;
    }

    // ---------- Internal Helpers ----------
    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address caller, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Mint(caller, to, amount);
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            allowance[owner][spender] = currentAllowance - amount;
        }
    }
}
