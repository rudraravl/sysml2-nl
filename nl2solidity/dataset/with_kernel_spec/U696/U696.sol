// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBaseAsset {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title AssetWrapper
 * @notice Wraps a base ERC-20 asset into a 1:1 backed wrapped token.
 *         Deposits mint wrapped tokens; burning them (withdraw) returns the base
 *         token minus a 0.5% fee that remains in the contract.
 * @dev Only the operator may pause/unpause wrapping and unwrapping.
 *      Only the owner may update the operator.
 */
contract AssetWrapper {
    event Deposit(address indexed account, uint256 baseAmount, uint256 wrappedAmount);
    event Withdrawal(address indexed account, uint256 wrappedAmount, uint256 baseReturned, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event PauseStatusUpdated(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EtherRescued(address indexed recipient, uint256 amount);

    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error WhenNotPaused();
    error ZeroAddress();
    error ZeroAmount();
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientBalance(address account, uint256 available, uint256 required);
    error InsufficientAllowance(address owner, address spender, uint256 available, uint256 required);
    error TransferFailed();
    error ReentrantCall();
    error NoEtherToRescue();

    uint256 public constant MINIMUM_DEPOSIT_UNITS = 100;
    uint256 public constant FEE_BASIS_POINTS = 50;
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;

    IBaseAsset public immutable baseAsset;
    uint8 public immutable decimals;
    uint256 public immutable minDepositAmount;

    string private _name;
    string private _symbol;

    address private _owner;
    address private _operator;
    bool private _paused;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _status;
    uint256 private constant _UNLOCKED = 1;
    uint256 private constant _LOCKED = 2;

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != _operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert WhenPaused();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert WhenNotPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _LOCKED) revert ReentrantCall();
        _status = _LOCKED;
        _;
        _status = _UNLOCKED;
    }

    constructor(
        address baseAsset_,
        string memory name_,
        string memory symbol_,
        address initialOperator
    ) {
        if (baseAsset_ == address(0)) revert ZeroAddress();
        if (initialOperator == address(0)) revert ZeroAddress();

        baseAsset = IBaseAsset(baseAsset_);
        _name = name_;
        _symbol = symbol_;

        uint8 d = 18;
        try IBaseAsset(baseAsset_).decimals() returns (uint8 value) {
            d = value;
        } catch {
            d = 18;
        }
        decimals = d;
        minDepositAmount = MINIMUM_DEPOSIT_UNITS * (10 ** uint256(d));

        _owner = msg.sender;
        _operator = initialOperator;
        _status = _UNLOCKED;
        _paused = false;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), initialOperator);
        emit PauseStatusUpdated(false);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = _operator;
        _operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function pause() external onlyOperator whenNotPaused {
        _paused = true;
        emit PauseStatusUpdated(true);
    }

    function unpause() external onlyOperator whenPaused {
        _paused = false;
        emit PauseStatusUpdated(false);
    }

    function setPaused(bool paused_) external onlyOperator {
        if (_paused == paused_) {
            if (paused_) revert WhenPaused();
            else revert WhenNotPaused();
        }
        _paused = paused_;
        emit PauseStatusUpdated(paused_);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function operator() public view returns (address) {
        return _operator;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant returns (uint256) {
        return _deposit(msg.sender, msg.sender, amount);
    }

    function depositFor(address account, uint256 amount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        if (account == address(0)) revert ZeroAddress();
        return _deposit(msg.sender, account, amount);
    }

    function withdraw(uint256 wrappedAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 baseReturned, uint256 fee)
    {
        return _withdraw(msg.sender, msg.sender, wrappedAmount);
    }

    function withdrawTo(address recipient, uint256 wrappedAmount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 baseReturned, uint256 fee)
    {
        if (recipient == address(0)) revert ZeroAddress();
        return _withdraw(msg.sender, recipient, wrappedAmount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) {
                revert InsufficientAllowance(from, msg.sender, allowed, amount);
            }
            _approve(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert InsufficientAllowance(msg.sender, spender, currentAllowance, subtractedValue);
        }
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function recoverExcessBaseAsset(address recipient)
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 contractBalance = baseAsset.balanceOf(address(this));
        if (contractBalance <= _totalSupply) revert ZeroAmount();
        uint256 excess = contractBalance - _totalSupply;
        _safeTransfer(recipient, excess);
        return excess;
    }

    function rescueEther(address payable recipient) external onlyOwner nonReentrant returns (uint256) {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount == 0) revert NoEtherToRescue();
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit EtherRescued(recipient, amount);
        return amount;
    }

    function _deposit(
        address payer,
        address account,
        uint256 amount
    ) internal returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        if (amount < minDepositAmount) revert DepositBelowMinimum(amount, minDepositAmount);

        _mint(account, amount);

        _safeTransferFrom(payer, address(this), amount);

        emit Deposit(account, amount, amount);
        return amount;
    }

    function _withdraw(
        address burner,
        address recipient,
        uint256 wrappedAmount
    ) internal returns (uint256 baseReturned, uint256 fee) {
        if (wrappedAmount == 0) revert ZeroAmount();

        _burn(burner, wrappedAmount);

        fee = (wrappedAmount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        baseReturned = wrappedAmount - fee;

        _safeTransfer(recipient, baseReturned);

        emit Withdrawal(burner, wrappedAmount, baseReturned, fee);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        uint256 balance = _balances[account];
        if (balance < amount) revert InsufficientBalance(account, balance, amount);
        unchecked {
            _balances[account] = balance - amount;
        }
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(from, fromBalance, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool success = baseAsset.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool success = baseAsset.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    receive() external payable {
        revert("AssetWrapper: does not accept ETH");
    }
}
