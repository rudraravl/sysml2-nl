// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error NotOwner();
error NotOperator();
error TransferFromZeroAddress();
error TransferToZeroAddress();
error ApproveFromZeroAddress();
error ApproveToZeroAddress();
error InsufficientBalance();
error InsufficientAllowance();
error MintExceedsHardCap();
error MintToZeroAddress();
error BurnFromZeroAddress();
error BurnExceedsBalance();
error EnforcedPause();
error ExpectedPause();
error InvalidOwnerAddress();
error InvalidOperatorAddress();
error InvalidAmount();

/**
 * @title VentureFundToken
 * @dev Transferable digital token representing an indirect fractional non-voting
 *      economic interest in a venture fund. Implements ERC-20 with operator-gated
 *      minting up to a hard cap, operator-gated burning, and owner-controlled pause.
 */
contract VentureFundToken {
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;
    uint256 public constant HARD_CAP = 1_000_000_000 * 10 ** 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address private _owner;
    address private _operator;
    bool private _paused;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint256 value
    );
    event TotalSupplyChange(uint256 previousSupply, uint256 newSupply);
    event Paused(address account);
    event Unpaused(address account);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event OperatorChanged(
        address indexed previousOperator,
        address indexed newOperator
    );

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != _operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert ExpectedPause();
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        address operator_
    ) {
        if (operator_ == address(0)) revert InvalidOperatorAddress();
        _name = name_;
        _symbol = symbol_;
        _owner = msg.sender;
        _operator = operator_;
        if (initialSupply_ > 0) {
            if (initialSupply_ > HARD_CAP) revert MintExceedsHardCap();
            _totalSupply = initialSupply_;
            _balances[msg.sender] = initialSupply_;
            emit Transfer(address(0), msg.sender, initialSupply_);
            emit TotalSupplyChange(0, initialSupply_);
        }
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), operator_);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[tokenOwner][spender];
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function operator() external view returns (address) {
        return _operator;
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function transfer(address to, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function mint(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert MintToZeroAddress();
        if (amount == 0) revert InvalidAmount();
        uint256 newSupply = _totalSupply + amount;
        if (newSupply > HARD_CAP) revert MintExceedsHardCap();
        uint256 oldSupply = _totalSupply;
        _totalSupply = newSupply;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
        emit TotalSupplyChange(oldSupply, newSupply);
    }

    function burn(address from, uint256 amount) external onlyOperator {
        if (from == address(0)) revert BurnFromZeroAddress();
        if (amount == 0) revert InvalidAmount();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert BurnExceedsBalance();
        uint256 oldSupply = _totalSupply;
        uint256 newSupply = oldSupply - amount;
        _balances[from] = fromBalance - amount;
        _totalSupply = newSupply;
        emit Transfer(from, address(0), amount);
        emit TotalSupplyChange(oldSupply, newSupply);
    }

    function pause() external onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidOwnerAddress();
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address oldOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidOperatorAddress();
        address oldOperator = _operator;
        _operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert TransferFromZeroAddress();
        if (to == address(0)) revert TransferToZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount)
        internal
    {
        if (tokenOwner == address(0)) revert ApproveFromZeroAddress();
        if (spender == address(0)) revert ApproveToZeroAddress();
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _spendAllowance(
        address tokenOwner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = _allowances[tokenOwner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            unchecked {
                _allowances[tokenOwner][spender] = currentAllowance - amount;
            }
        }
    }
}
