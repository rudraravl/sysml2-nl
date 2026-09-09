// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract L1L2Bridge {
    error ContractPaused();
    error NotOperator();
    error AmountTooLow();
    error InsufficientDeposit();
    error WithdrawalNotReady();
    error ZeroAddress();
    error TransferFailed();
    error InvalidDelay();
    error InvalidWithdrawalId();
    error AlreadyClaimed();
    error DirectDepositNotAllowed();
    error ReentrantCall();

    event Deposited(address indexed user, uint256 amount);
    event WithdrawalInitiated(address indexed user, uint256 amount, uint256 indexed withdrawalId, uint64 releaseTime);
    event WithdrawalClaimed(address indexed user, uint256 amount, uint256 indexed withdrawalId);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event MinDepositAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event WithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MIN_WITHDRAWAL_DELAY = 1 days;
    uint256 public constant MAX_WITHDRAWAL_DELAY = 30 days;
    uint256 public constant DEFAULT_MIN_DEPOSIT = 0.001 ether;
    uint256 public constant DEFAULT_WITHDRAWAL_DELAY = 7 days;

    address public operator;
    bool public paused;
    uint256 public minDepositAmount;
    uint256 public withdrawalDelay;

    struct Withdrawal {
        uint256 amount;
        uint64 releaseTime;
        bool claimed;
    }

    mapping(address => uint256) public deposits;
    mapping(address => Withdrawal[]) public withdrawals;

    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() {
        operator = msg.sender;
        minDepositAmount = DEFAULT_MIN_DEPOSIT;
        withdrawalDelay = DEFAULT_WITHDRAWAL_DELAY;
        emit OperatorUpdated(address(0), msg.sender);
        emit MinDepositAmountUpdated(0, minDepositAmount);
        emit WithdrawalDelayUpdated(0, withdrawalDelay);
    }

    function deposit() external payable whenNotPaused nonReentrant {
        if (msg.value < minDepositAmount) revert AmountTooLow();
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function initiateWithdrawal(uint256 amount) external whenNotPaused nonReentrant returns (uint256 withdrawalId) {
        if (amount == 0) revert AmountTooLow();
        uint256 available = deposits[msg.sender];
        if (amount > available) revert InsufficientDeposit();
        deposits[msg.sender] = available - amount;
        withdrawalId = withdrawals[msg.sender].length;
        uint64 releaseTime = uint64(block.timestamp + withdrawalDelay);
        withdrawals[msg.sender].push(Withdrawal({amount: amount, releaseTime: releaseTime, claimed: false}));
        emit WithdrawalInitiated(msg.sender, amount, withdrawalId, releaseTime);
    }

    function claim(uint256 withdrawalId) external whenNotPaused nonReentrant {
        if (withdrawalId >= withdrawals[msg.sender].length) revert InvalidWithdrawalId();
        Withdrawal storage w = withdrawals[msg.sender][withdrawalId];
        if (w.claimed) revert AlreadyClaimed();
        if (block.timestamp < w.releaseTime) revert WithdrawalNotReady();
        uint256 amount = w.amount;
        w.claimed = true;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit WithdrawalClaimed(msg.sender, amount, withdrawalId);
    }

    function setMinDepositAmount(uint256 newAmount) external onlyOperator {
        emit MinDepositAmountUpdated(minDepositAmount, newAmount);
        minDepositAmount = newAmount;
    }

    function setWithdrawalDelay(uint256 newDelay) external onlyOperator {
        if (newDelay < MIN_WITHDRAWAL_DELAY || newDelay > MAX_WITHDRAWAL_DELAY) revert InvalidDelay();
        emit WithdrawalDelayUpdated(withdrawalDelay, newDelay);
        withdrawalDelay = newDelay;
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function updateOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function getWithdrawal(address user, uint256 withdrawalId)
        external
        view
        returns (uint256 amount, uint64 releaseTime, bool claimed)
    {
        if (withdrawalId >= withdrawals[user].length) revert InvalidWithdrawalId();
        Withdrawal storage w = withdrawals[user][withdrawalId];
        return (w.amount, w.releaseTime, w.claimed);
    }

    function withdrawalCount(address user) external view returns (uint256) {
        return withdrawals[user].length;
    }

    receive() external payable {
        revert DirectDepositNotAllowed();
    }
}
