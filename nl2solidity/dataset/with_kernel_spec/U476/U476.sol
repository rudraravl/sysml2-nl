// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract StablecoinSettlementPool {
    // --- Immutable & Configuration ---
    IERC20 public immutable stablecoin;
    address public owner;
    address public operator;
    address public feeRecipient;

    uint256 public totalBalance;
    uint256 public settlementFeeBps;

    uint256 public constant MAX_SPENDING_LIMIT = 10_000 * 1e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5%

    // --- User State ---
    mapping(address => uint256) public spendingLimit;

    struct SettlementRequest {
        address requester;
        uint256 amount;
        address recipient;
        uint256 fee;
        bool processed;
        bool approved;
    }

    mapping(uint256 => SettlementRequest) public requests;
    uint256 public nextRequestId;

    // --- Events ---
    event Deposited(address indexed user, uint256 amount, uint256 newLimit);
    event SettlementRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint256 amount,
        address indexed recipient
    );
    event SettlementApproved(
        uint256 indexed requestId,
        address indexed requester,
        uint256 amount,
        uint256 fee,
        address recipient
    );
    event SettlementRejected(uint256 indexed requestId, address indexed requester, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address oldOperator, address newOperator);
    event FeeRecipientUpdated(address oldFeeRecipient, address newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- Errors ---
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InvalidAmount();
    error FeeTooHigh(uint256 feeBps);
    error ExceedsMaxSpendingLimit(uint256 currentLimit, uint256 depositAmount, uint256 max);
    error InsufficientSpendingLimit(uint256 requested, uint256 available);
    error RequestNotFound(uint256 requestId);
    error RequestAlreadyProcessed(uint256 requestId);
    error TransferFailed();

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // --- Constructor ---
    constructor(address _stablecoin, address _operator, address _feeRecipient) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        settlementFeeBps = DEFAULT_FEE_BPS;
        nextRequestId = 1;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    // --- User Functions ---
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        uint256 currentLimit = spendingLimit[msg.sender];
        uint256 newLimit = currentLimit + amount;
        if (newLimit > MAX_SPENDING_LIMIT) {
            revert ExceedsMaxSpendingLimit(currentLimit, amount, MAX_SPENDING_LIMIT);
        }

        spendingLimit[msg.sender] = newLimit;
        totalBalance += amount;

        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposited(msg.sender, amount, newLimit);
    }

    function requestSettlement(uint256 amount, address recipient)
        external
        returns (uint256 requestId)
    {
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 fee = (amount * settlementFeeBps) / BPS_DENOMINATOR;
        uint256 totalNeeded = amount + fee;

        uint256 available = spendingLimit[msg.sender];
        if (available < totalNeeded) {
            revert InsufficientSpendingLimit(totalNeeded, available);
        }

        spendingLimit[msg.sender] = available - totalNeeded;

        requestId = nextRequestId++;
        requests[requestId] = SettlementRequest({
            requester: msg.sender,
            amount: amount,
            recipient: recipient,
            fee: fee,
            processed: false,
            approved: false
        });

        emit SettlementRequested(requestId, msg.sender, amount, recipient);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        uint256 available = spendingLimit[msg.sender];
        if (available < amount) revert InsufficientSpendingLimit(amount, available);

        spendingLimit[msg.sender] = available - amount;
        totalBalance -= amount;

        bool ok = stablecoin.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    // --- Operator Functions ---
    function approveSettlement(uint256 requestId) external onlyOperator {
        SettlementRequest storage req = requests[requestId];
        if (req.requester == address(0)) revert RequestNotFound(requestId);
        if (req.processed) revert RequestAlreadyProcessed(requestId);

        req.processed = true;
        req.approved = true;

        uint256 totalOut = req.amount + req.fee;
        totalBalance -= totalOut;

        bool ok = stablecoin.transfer(req.recipient, req.amount);
        if (!ok) revert TransferFailed();

        if (req.fee > 0) {
            bool feeOk = stablecoin.transfer(feeRecipient, req.fee);
            if (!feeOk) revert TransferFailed();
        }

        emit SettlementApproved(requestId, req.requester, req.amount, req.fee, req.recipient);
    }

    function rejectSettlement(uint256 requestId) external onlyOperator {
        SettlementRequest storage req = requests[requestId];
        if (req.requester == address(0)) revert RequestNotFound(requestId);
        if (req.processed) revert RequestAlreadyProcessed(requestId);

        req.processed = true;
        req.approved = false;

        spendingLimit[req.requester] += (req.amount + req.fee);

        emit SettlementRejected(requestId, req.requester, req.amount);
    }

    // --- Owner Functions ---
    function setSettlementFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > BPS_DENOMINATOR) revert FeeTooHigh(_feeBps);
        emit FeeUpdated(settlementFeeBps, _feeBps);
        settlementFeeBps = _feeBps;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // --- View Functions ---
    function getSpendingLimit(address user) external view returns (uint256) {
        return spendingLimit[user];
    }

    function getRequest(uint256 requestId) external view returns (SettlementRequest memory) {
        return requests[requestId];
    }

    function contractBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }
}
