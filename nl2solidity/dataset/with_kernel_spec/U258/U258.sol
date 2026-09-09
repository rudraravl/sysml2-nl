// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract StableLiquidityPool {
    // --------- Events ---------
    event Deposit(address indexed caller, address indexed recipient, uint256 amount);
    event Withdrawal(address indexed caller, address indexed recipient, uint256 amount);
    event ConvertToSynthetic(address indexed user, uint256 inputAmount, uint256 outputAmount, uint256 feeAmount);
    event ConvertFromSynthetic(address indexed user, uint256 inputAmount, uint256 outputAmount, uint256 feeAmount);
    event FeeUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event Paused(address indexed owner);
    event Unpaused(address indexed owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesCollected(address indexed operator, address indexed recipient, uint256 amount);

    // --------- Custom Errors ---------
    error NotOwner();
    error NotOperator();
    error IsPaused();
    error IsNotPaused();
    error FeeExceedsCap(uint256 provided, uint256 cap);
    error InsufficientStableBalance(uint256 available, uint256 required);
    error InsufficientSyntheticBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error ZeroAmount();
    error ZeroAddress();
    error NothingToCollect(uint256 available, uint256 requested);
    error StableTransferFailed();
    error StableTransferFromFailed();

    // --------- Constants ---------
    uint256 public constant FEE_CAP_BPS = 50;       // 0.5% max conversion fee
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // --------- Immutables ---------
    IERC20 public immutable stablecoin;

    // --------- Configuration ---------
    address public owner;
    address public operator;
    bool public paused;
    uint256 public conversionFeeBps;

    // --------- Balances ---------
    mapping(address => uint256) public stableBalanceOf;
    mapping(address => uint256) public syntheticBalanceOf;
    uint256 public totalStableBalance;
    uint256 public totalSyntheticBalance;
    uint256 public accruedFees;

    // --------- Modifiers ---------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert IsPaused();
        _;
    }

    // --------- Constructor ---------
    constructor(address _stablecoin, address _operator, uint256 _initialFeeBps) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialFeeBps > FEE_CAP_BPS) revert FeeExceedsCap(_initialFeeBps, FEE_CAP_BPS);

        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        conversionFeeBps = _initialFeeBps;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeUpdated(msg.sender, 0, _initialFeeBps);
    }

    // --------- Owner Functions ---------
    function pause() external onlyOwner {
        if (paused) revert IsPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert IsNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // --------- Operator Functions ---------
    function setConversionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > FEE_CAP_BPS) revert FeeExceedsCap(newFeeBps, FEE_CAP_BPS);
        uint256 oldFee = conversionFeeBps;
        conversionFeeBps = newFeeBps;
        emit FeeUpdated(msg.sender, oldFee, newFeeBps);
    }

    function collectFees(address recipient, uint256 amount) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accruedFees) revert NothingToCollect(accruedFees, amount);

        accruedFees -= amount;
        bool ok = stablecoin.transfer(recipient, amount);
        if (!ok) revert StableTransferFailed();

        emit FeesCollected(msg.sender, recipient, amount);
    }

    // --------- User Operations ---------
    function deposit(address recipient, uint256 amount) external whenNotPaused {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 allowance = stablecoin.allowance(msg.sender, address(this));
        if (allowance < amount) revert InsufficientAllowance(allowance, amount);

        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert StableTransferFromFailed();

        stableBalanceOf[recipient] += amount;
        totalStableBalance += amount;

        emit Deposit(msg.sender, recipient, amount);
    }

    function withdraw(address recipient, uint256 amount) external whenNotPaused {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 available = stableBalanceOf[msg.sender];
        if (available < amount) revert InsufficientStableBalance(available, amount);

        stableBalanceOf[msg.sender] = available - amount;
        totalStableBalance -= amount;

        bool ok = stablecoin.transfer(recipient, amount);
        if (!ok) revert StableTransferFailed();

        emit Withdrawal(msg.sender, recipient, amount);
    }

    function convertToSynthetic(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        uint256 available = stableBalanceOf[msg.sender];
        if (available < amount) revert InsufficientStableBalance(available, amount);

        uint256 fee = (amount * conversionFeeBps) / BPS_DENOMINATOR;
        uint256 output = amount - fee;

        stableBalanceOf[msg.sender] = available - amount;
        totalStableBalance -= amount;

        syntheticBalanceOf[msg.sender] += output;
        totalSyntheticBalance += output;

        accruedFees += fee;

        emit ConvertToSynthetic(msg.sender, amount, output, fee);
    }

    function convertFromSynthetic(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        uint256 available = syntheticBalanceOf[msg.sender];
        if (available < amount) revert InsufficientSyntheticBalance(available, amount);

        uint256 fee = (amount * conversionFeeBps) / BPS_DENOMINATOR;
        uint256 output = amount - fee;

        syntheticBalanceOf[msg.sender] = available - amount;
        totalSyntheticBalance -= amount;

        stableBalanceOf[msg.sender] += output;
        totalStableBalance += output;

        accruedFees += fee;

        emit ConvertFromSynthetic(msg.sender, amount, output, fee);
    }

    // --------- Views ---------
    function stableBalance(address user) external view returns (uint256) {
        return stableBalanceOf[user];
    }

    function syntheticBalance(address user) external view returns (uint256) {
        return syntheticBalanceOf[user];
    }

    function contractStablecoinBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    function expectedBacking() external view returns (uint256) {
        return totalStableBalance + totalSyntheticBalance + accruedFees;
    }

    function quoteToSynthetic(uint256 amount) external view returns (uint256 output, uint256 fee) {
        fee = (amount * conversionFeeBps) / BPS_DENOMINATOR;
        output = amount - fee;
    }

    function quoteFromSynthetic(uint256 amount) external view returns (uint256 output, uint256 fee) {
        fee = (amount * conversionFeeBps) / BPS_DENOMINATOR;
        output = amount - fee;
    }
}
