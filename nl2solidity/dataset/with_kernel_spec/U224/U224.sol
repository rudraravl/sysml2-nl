// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ConfidentialComputationVault {
    // ============ Constants ============
    uint256 public constant MAX_FEE = 0.05 ether;
    uint256 public constant WITHDRAWAL_TIMELOCK = 24 hours;

    // ============ State Variables ============
    IERC20 public immutable token;
    address public operator;
    uint256 public computationFee;
    bool public depositsPaused;
    uint256 public totalDeposits;

    mapping(address => uint256) public balances;

    struct WithdrawRequest {
        uint256 amount;
        uint256 requestedAt;
        bool active;
    }
    mapping(address => WithdrawRequest) public withdrawRequests;

    // ============ Events ============
    event Deposit(address indexed user, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount);
    event ComputationRequestSubmitted(address indexed user, bytes encryptedRequest, uint256 fee);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event DepositsPausedChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ============ Custom Errors ============
    error NotOperator();
    error DepositsPaused();
    error InsufficientBalance();
    error NoActiveWithdrawRequest();
    error TimelockNotExpired();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error InvalidFee();
    error InvalidEncryptedRequest();

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    // ============ Constructor ============
    constructor(address token_, address operator_, uint256 initialFee) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (initialFee > MAX_FEE) revert InvalidFee();

        token = IERC20(token_);
        operator = operator_;
        computationFee = initialFee;

        emit OperatorChanged(address(0), operator_);
        emit FeeUpdated(0, initialFee);
    }

    // ============ User Functions ============

    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        balances[msg.sender] += amount;
        totalDeposits += amount;

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit Deposit(msg.sender, amount);
    }

    function requestWithdrawal(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        WithdrawRequest storage req = withdrawRequests[msg.sender];
        req.amount = amount;
        req.requestedAt = block.timestamp;
        req.active = true;

        emit WithdrawalRequested(msg.sender, amount, block.timestamp + WITHDRAWAL_TIMELOCK);
    }

    function executeWithdrawal() external {
        WithdrawRequest storage req = withdrawRequests[msg.sender];
        if (!req.active) revert NoActiveWithdrawRequest();
        if (block.timestamp < req.requestedAt + WITHDRAWAL_TIMELOCK) revert TimelockNotExpired();

        uint256 amount = req.amount;
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        req.active = false;
        req.amount = 0;
        req.requestedAt = 0;

        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function cancelWithdrawalRequest() external {
        WithdrawRequest storage req = withdrawRequests[msg.sender];
        if (!req.active) revert NoActiveWithdrawRequest();

        req.active = false;
        req.amount = 0;
        req.requestedAt = 0;
    }

    function submitComputationRequest(bytes calldata encryptedRequest) external payable {
        if (encryptedRequest.length == 0) revert InvalidEncryptedRequest();
        if (msg.value != computationFee) revert InvalidFee();

        emit ComputationRequestSubmitted(msg.sender, encryptedRequest, msg.value);
    }

    // ============ Operator Functions ============

    function setFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint256 oldFee = computationFee;
        computationFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function setDepositsPaused(bool paused) external onlyOperator {
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function withdrawFees(address payable to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount > 0) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert TransferFailed();
        }
    }

    // ============ View Functions ============

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function getWithdrawalUnlockTime(address user) external view returns (uint256) {
        WithdrawRequest storage req = withdrawRequests[user];
        if (!req.active) return 0;
        return req.requestedAt + WITHDRAWAL_TIMELOCK;
    }
}
