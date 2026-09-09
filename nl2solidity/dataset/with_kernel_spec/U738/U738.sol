// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract LiquidStaking {
    error ZeroAddress();
    error Unauthorized();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InvalidExchangeRate();
    error NoRebaseDelta();
    error TransferFailed();

    uint256 private constant MIN_DEPOSIT = 1e15;
    uint256 private constant REDEMPTION_FEE_BIPS = 10;
    uint256 private constant BIPS_DENOMINATOR = 10_000;

    string public constant name = "Liquid Staked Token";
    string public constant symbol = "LST";
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public owner;
    address public operator;
    IERC20 public immutable baseAsset;
    uint256 public exchangeRate;
    uint256 public accruedFees;

    event Deposit(address indexed caller, address indexed owner, uint256 baseAmount, uint256 receiptAmount);
    event Redeem(address indexed caller, address indexed receiver, address indexed owner, uint256 receiptAmount, uint256 baseAmount, uint256 feeAmount);
    event Rebase(address indexed operator, uint256 oldRate, uint256 newRate, int256 delta);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event Recovered(address indexed token, address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address baseAsset_, address operator_) {
        if (baseAsset_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        baseAsset = IERC20(baseAsset_);
        operator = operator_;
        owner = msg.sender;
        exchangeRate = 1e18;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), operator_);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdrawFees(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees;
        if (amount == 0) revert ZeroAmount();
        accruedFees = 0;
        _safeTransferBase(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    function recover(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (token == address(baseAsset)) {
            uint256 owed = _totalBaseOwed() + accruedFees;
            uint256 balance = baseAsset.balanceOf(address(this));
            uint256 excess = balance > owed ? balance - owed : 0;
            if (amount > excess) revert InsufficientBalance();
        }
        _safeTransfer(token, to, amount);
        emit Recovered(token, to, amount);
    }

    function rebase(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 oldRate = exchangeRate;
        if (newRate == oldRate) revert NoRebaseDelta();
        exchangeRate = newRate;
        int256 delta = newRate > oldRate ? int256(newRate - oldRate) : -int256(oldRate - newRate);
        emit Rebase(msg.sender, oldRate, newRate, delta);
    }

    function deposit(address to, uint256 baseAmount) external returns (uint256 receiptAmount) {
        if (to == address(0)) revert ZeroAddress();
        if (baseAmount < MIN_DEPOSIT) revert DepositTooSmall();

        receiptAmount = _convertBaseToReceipt(baseAmount);
        if (receiptAmount == 0) revert ZeroAmount();

        _safeTransferFromBase(msg.sender, address(this), baseAmount);
        _mint(to, receiptAmount);

        emit Deposit(msg.sender, to, baseAmount, receiptAmount);
    }

    function redeem(address to, uint256 receiptAmount) external returns (uint256 baseOut) {
        if (to == address(0)) revert ZeroAddress();
        if (receiptAmount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < receiptAmount) revert InsufficientBalance();

        uint256 grossBase = _convertReceiptToBase(receiptAmount);
        uint256 fee = (grossBase * REDEMPTION_FEE_BIPS) / BIPS_DENOMINATOR;
        baseOut = grossBase - fee;

        _burn(msg.sender, receiptAmount);
        accruedFees += fee;

        _safeTransferBase(to, baseOut);

        emit Redeem(msg.sender, to, msg.sender, receiptAmount, baseOut, fee);
    }

    function redeemFrom(address from, address to, uint256 receiptAmount) external returns (uint256 baseOut) {
        if (to == address(0)) revert ZeroAddress();
        if (from == address(0)) revert ZeroAddress();
        if (receiptAmount == 0) revert ZeroAmount();
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < receiptAmount) revert InsufficientAllowance();
        if (_balances[from] < receiptAmount) revert InsufficientBalance();

        uint256 grossBase = _convertReceiptToBase(receiptAmount);
        uint256 fee = (grossBase * REDEMPTION_FEE_BIPS) / BIPS_DENOMINATOR;
        baseOut = grossBase - fee;

        if (allowed != type(uint256).max) {
            _approve(from, msg.sender, allowed - receiptAmount);
        }
        _burn(from, receiptAmount);
        accruedFees += fee;

        _safeTransferBase(to, baseOut);

        emit Redeem(msg.sender, to, from, receiptAmount, baseOut, fee);
    }

    function _convertBaseToReceipt(uint256 baseAmount) internal view returns (uint256) {
        return (baseAmount * 1e18) / exchangeRate;
    }

    function _convertReceiptToBase(uint256 receiptAmount) internal view returns (uint256) {
        return (receiptAmount * exchangeRate) / 1e18;
    }

    function _totalBaseOwed() internal view returns (uint256) {
        return _convertReceiptToBase(_totalSupply);
    }

    function previewDeposit(uint256 baseAmount) external view returns (uint256) {
        return _convertBaseToReceipt(baseAmount);
    }

    function previewRedeem(uint256 receiptAmount) external view returns (uint256 baseOut, uint256 fee) {
        uint256 grossBase = _convertReceiptToBase(receiptAmount);
        fee = (grossBase * REDEMPTION_FEE_BIPS) / BIPS_DENOMINATOR;
        baseOut = grossBase - fee;
    }

    function _mint(address to, uint256 amount) internal {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        _balances[from] -= amount;
        _totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (from == address(0)) revert ZeroAddress();
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (_balances[from] < amount) revert InsufficientBalance();

        if (allowed != type(uint256).max) {
            _approve(from, msg.sender, allowed - amount);
        }
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function _safeTransferBase(address to, uint256 amount) internal {
        bool success = baseAsset.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFromBase(address from, address to, uint256 amount) internal {
        bool success = baseAsset.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
