// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract FundManager {
    uint256 private constant MAX_MANAGEMENT_FEE = 200; // 2% in basis points
    uint256 private constant UNBONDING_PERIOD = 7 days;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    address public owner;
    address public feeRecipient;

    uint256 public managementFeeBps;
    bool public paused;

    struct UnbondingRequest {
        uint256 amount;
        uint256 unlockTime;
    }

    // token => user => deposited amount
    mapping(address => mapping(address => uint256)) public accountDeposits;

    // token => total custodied
    mapping(address => uint256) public totalCustodied;

    // token => user => unbonding request
    mapping(address => mapping(address => UnbondingRequest)) public unbondingRequests;

    // strategy proposals and approvals
    mapping(address => bool) public proposedStrategies;
    mapping(address => bool) public approvedStrategies;
    address[] public strategyList;

    event Deposit(address indexed token, address indexed account, uint256 amount);
    event Withdraw(address indexed token, address indexed account, uint256 amount);
    event UnbondingStarted(address indexed token, address indexed account, uint256 amount, uint256 unlockTime);
    event StrategyProposed(address indexed strategy);
    event StrategyApproved(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event ManagementFeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed newRecipient);
    event PausedStateChanged(bool paused);

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error UnbondingNotStarted();
    error UnbondingNotElapsed();
    error FeeTooHigh();
    error StrategyAlreadyProposed();
    error StrategyAlreadyApproved();
    error StrategyNotProposed();
    error StrategyNotApproved();
    error ContractPaused();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(uint256 _initialFeeBps, address _feeRecipient) {
        if (_initialFeeBps > MAX_MANAGEMENT_FEE) revert FeeTooHigh();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        managementFeeBps = _initialFeeBps;
        feeRecipient = _feeRecipient;
    }

    function deposit(address token, uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();

        uint256 fee = (amount * managementFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        if (!_safeTransferFrom(token, msg.sender, address(this), amount)) revert TransferFailed();

        accountDeposits[token][msg.sender] += netAmount;
        totalCustodied[token] += netAmount;

        if (fee > 0) {
            accountDeposits[token][feeRecipient] += fee;
            totalCustodied[token] += fee;
        }

        emit Deposit(token, msg.sender, amount);
    }

    function requestWithdraw(address token, uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (accountDeposits[token][msg.sender] < amount) revert InsufficientBalance();

        accountDeposits[token][msg.sender] -= amount;

        uint256 unlockTime = block.timestamp + UNBONDING_PERIOD;
        unbondingRequests[token][msg.sender] = UnbondingRequest({
            amount: amount,
            unlockTime: unlockTime
        });

        emit UnbondingStarted(token, msg.sender, amount, unlockTime);
    }

    function completeWithdraw(address token) external whenNotPaused {
        UnbondingRequest memory req = unbondingRequests[token][msg.sender];
        if (req.amount == 0) revert UnbondingNotStarted();
        if (block.timestamp < req.unlockTime) revert UnbondingNotElapsed();

        uint256 amount = req.amount;
        delete unbondingRequests[token][msg.sender];

        totalCustodied[token] -= amount;

        if (!_safeTransfer(token, msg.sender, amount)) revert TransferFailed();

        emit Withdraw(token, msg.sender, amount);
    }

    function proposeStrategy(address strategy) external whenNotPaused {
        if (strategy == address(0)) revert ZeroAddress();
        if (approvedStrategies[strategy]) revert StrategyAlreadyApproved();
        if (proposedStrategies[strategy]) revert StrategyAlreadyProposed();

        proposedStrategies[strategy] = true;
        emit StrategyProposed(strategy);
    }

    function approveStrategy(address strategy) external onlyOwner {
        if (strategy == address(0)) revert ZeroAddress();
        if (!proposedStrategies[strategy]) revert StrategyNotProposed();
        if (approvedStrategies[strategy]) revert StrategyAlreadyApproved();

        approvedStrategies[strategy] = true;
        strategyList.push(strategy);

        emit StrategyApproved(strategy);
    }

    function removeStrategy(address strategy) external onlyOwner {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();

        approvedStrategies[strategy] = false;
        proposedStrategies[strategy] = false;

        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; ++i) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[len - 1];
                strategyList.pop();
                break;
            }
        }

        emit StrategyRemoved(strategy);
    }

    function setManagementFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_MANAGEMENT_FEE) revert FeeTooHigh();
        managementFeeBps = _feeBps;
        emit ManagementFeeUpdated(_feeBps);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function getStrategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function getAccountDeposit(address token, address account) external view returns (uint256) {
        return accountDeposits[token][account];
    }

    function getUnbondingRequest(address token, address account)
        external
        view
        returns (uint256 amount, uint256 unlockTime)
    {
        UnbondingRequest memory req = unbondingRequests[token][account];
        return (req.amount, req.unlockTime);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }
}
