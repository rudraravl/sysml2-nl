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

contract BitcoinReserveToken {
    string public constant name = "Bitcoin Reserve Token";
    string public constant symbol = "BTCR";
    uint8 public immutable decimals;

    IERC20 public immutable wrappedBitcoin;

    uint256 internal constant FEE_DIVISOR = 10000;
    uint256 public constant MAX_DAILY_WITHDRAWAL_BTC = 10;
    uint256 public immutable maxDailyWithdrawal;
    uint256 public constant MAX_FEE_BPS = 1000;

    uint256 public withdrawalFeeBps;
    uint256 public reserveBalance;

    address public owner;
    address public operator;
    bool public paused;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    mapping(address => uint256) public dailyWithdrawn;
    mapping(address => uint256) public lastWithdrawalDay;

    uint256 private _reentrancyStatus;

    event Deposit(address indexed sender, address indexed recipient, uint256 amount);
    event Withdrawal(address indexed sender, address indexed recipient, uint256 amount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event ReserveSynced(uint256 newReserveBalance);
    event ExcessSwept(address indexed recipient, uint256 amount);

    error ZeroAddress();
    error InvalidAccount();
    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error ExpectedPause();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DailyLimitExceeded();
    error InvalidUnderlying();
    error WithdrawalFeeTooHigh();
    error TransferFailed();
    error AmountMustBePositive();
    error ReentrancyGuard();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == 1) revert ReentrancyGuard();
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 0;
    }

    constructor(address _wrappedBitcoin, address _operator, uint8 _decimals) {
        if (_wrappedBitcoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_decimals > 18) revert InvalidUnderlying();

        wrappedBitcoin = IERC20(_wrappedBitcoin);
        decimals = _decimals;
        maxDailyWithdrawal = MAX_DAILY_WITHDRAWAL_BTC * (10 ** uint256(_decimals));

        withdrawalFeeBps = 10;
        owner = msg.sender;
        operator = _operator;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit WithdrawalFeeUpdated(0, 10);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address account, address spender) external view returns (uint256) {
        return _allowances[account][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = _allowances[msg.sender][spender] + addedValue;
        _allowances[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 requestedDecrease) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < requestedDecrease) revert InsufficientAllowance();
        _allowances[msg.sender][spender] = currentAllowance - requestedDecrease;
        emit Approval(msg.sender, spender, currentAllowance - requestedDecrease);
        return true;
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant returns (bool) {
        return _deposit(msg.sender, amount);
    }

    function depositFor(address account, uint256 amount) external whenNotPaused nonReentrant returns (bool) {
        if (account == address(0) || account == address(this)) revert InvalidAccount();
        return _deposit(account, amount);
    }

    function _deposit(address account, uint256 amount) internal returns (bool) {
        if (amount == 0) revert AmountMustBePositive();
        _safeTransferFrom(wrappedBitcoin, msg.sender, address(this), amount);
        _mint(account, amount);
        reserveBalance = wrappedBitcoin.balanceOf(address(this));
        emit Deposit(msg.sender, account, amount);
        return true;
    }

    function withdraw(address recipient, uint256 amount) external whenNotPaused nonReentrant returns (bool) {
        if (recipient == address(0) || recipient == address(this)) revert InvalidAccount();
        if (amount == 0) revert AmountMustBePositive();

        uint256 currentDay = block.timestamp / 1 days;
        if (lastWithdrawalDay[msg.sender] != currentDay) {
            dailyWithdrawn[msg.sender] = 0;
            lastWithdrawalDay[msg.sender] = currentDay;
        }
        if (dailyWithdrawn[msg.sender] + amount > maxDailyWithdrawal) revert DailyLimitExceeded();
        dailyWithdrawn[msg.sender] += amount;

        _burn(msg.sender, amount);

        uint256 fee = (amount * withdrawalFeeBps) / FEE_DIVISOR;
        uint256 net = amount - fee;

        _safeTransfer(wrappedBitcoin, recipient, net);
        reserveBalance = wrappedBitcoin.balanceOf(address(this));

        emit Withdrawal(msg.sender, recipient, amount, fee);
        return true;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert WithdrawalFeeTooHigh();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(old, newFeeBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address previous = owner;
        owner = address(0);
        emit OwnershipTransferred(previous, address(0));
    }

    function pause() external onlyOperator {
        if (paused) revert EnforcedPause();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert ExpectedPause();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function syncReserve() external {
        reserveBalance = wrappedBitcoin.balanceOf(address(this));
        emit ReserveSynced(reserveBalance);
    }

    function recoverExcess(address recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountMustBePositive();
        uint256 actual = wrappedBitcoin.balanceOf(address(this));
        uint256 excess = actual > _totalSupply ? actual - _totalSupply : 0;
        if (amount > excess) revert InsufficientBalance();
        _safeTransfer(wrappedBitcoin, recipient, amount);
        reserveBalance = wrappedBitcoin.balanceOf(address(this));
        emit ExcessSwept(recipient, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert InsufficientBalance();
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
            revert TransferFailed();
        }
        if (!_isSuccessReturn(returndata)) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
            revert TransferFailed();
        }
        if (!_isSuccessReturn(returndata)) revert TransferFailed();
    }

    function _isSuccessReturn(bytes memory returndata) private pure returns (bool) {
        if (returndata.length == 0) return true;
        bytes32 firstWord;
        assembly {
            firstWord := mload(add(returndata, 32))
        }
        return firstWord != bytes32(0);
    }
}
