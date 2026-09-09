// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidStakingDerivative {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    uint256 public contractETHBalance;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public operator;
    address public feeRecipient;

    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant FEE_BPS = 10; // 0.1% = 10 basis points
    uint256 public constant BPS_DENOMINATOR = 10000;

    bool private locked;

    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed sender, uint256 amount, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event WithdrawalInitiated(address indexed operator, uint256 amount);
    event RewardsProcessed(address indexed operator, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error NotOperator();
    error ReentrantCall();
    error EthTransferFailed();
    error InsufficientContractEth();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        name = "Liquid Staked Ether";
        symbol = "lsETH";
        operator = _operator;
        feeRecipient = _feeRecipient;
        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    receive() external payable {
        contractETHBalance += msg.value;
    }

    function deposit() external payable {
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall();
        contractETHBalance += msg.value;
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        if (contractETHBalance < amount) revert InsufficientContractEth();
        if (address(this).balance < amount) revert InsufficientContractEth();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        _burn(msg.sender, amount);
        contractETHBalance -= amount;

        if (fee > 0) {
            (bool s, ) = payable(feeRecipient).call{value: fee}("");
            if (!s) revert EthTransferFailed();
        }
        if (payout > 0) {
            (bool ok, ) = payable(msg.sender).call{value: payout}("");
            if (!ok) revert EthTransferFailed();
        }

        emit Withdrawal(msg.sender, amount, fee);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
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

    function initiateWithdrawal(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        emit WithdrawalInitiated(operator, amount);
    }

    function processRewards() external payable onlyOperator {
        if (msg.value == 0) revert ZeroAmount();
        contractETHBalance += msg.value;
        emit RewardsProcessed(operator, msg.value);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
