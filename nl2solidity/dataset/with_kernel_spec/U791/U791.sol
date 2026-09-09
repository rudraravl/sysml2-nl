// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract MultiChainAssetBridge {
    error OnlyOperator();
    error EnforcedPause();
    error EnforcedUnpause();
    error ZeroAddress();
    error AmountBelowMinimum();
    error TransferNotFound();
    error TransferNotApproved();
    error TransferAlreadyApproved();
    error TransferAlreadyClaimed();
    error TransferAlreadyCancelled();
    error NotTransferSender();
    error NotTransferRecipient();
    error ClaimWindowExpired();
    error TokenTransferFailed();

    event TransferInitiated(uint256 indexed nonce, address indexed sender, address indexed recipient, uint256 amount);
    event TransferApproved(uint256 indexed nonce, address indexed recipient, uint256 amount);
    event TransferClaimed(uint256 indexed nonce, address indexed recipient, uint256 amount);
    event TransferCancelled(uint256 indexed nonce, address indexed sender, uint256 amount);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    IERC20 public immutable token;
    address public operator;
    bool public paused;

    uint256 public constant MIN_TRANSFER_AMOUNT = 100;
    uint256 public constant CLAIM_WINDOW = 7 days;

    mapping(address => uint256) public lockedBalances;
    mapping(address => uint256) public bridgedBalances;
    uint256 public totalBridgedSupply;
    mapping(uint256 => bool) public isTransferClaimed;

    uint256 public nextNonce;

    struct TransferRecord {
        address sender;
        address recipient;
        uint256 amount;
        bool approved;
        bool cancelled;
        bool claimed;
        uint256 initiatedAt;
        uint256 approvedAt;
    }

    mapping(uint256 => TransferRecord) public transfers;

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert EnforcedUnpause();
        _;
    }

    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        operator = operator_;
    }

    function initiateTransfer(address recipient, uint256 amount) external whenNotPaused returns (uint256 nonce) {
        if (amount < MIN_TRANSFER_AMOUNT) revert AmountBelowMinimum();
        if (recipient == address(0)) revert ZeroAddress();

        nonce = nextNonce++;

        transfers[nonce] = TransferRecord({
            sender: msg.sender,
            recipient: recipient,
            amount: amount,
            approved: false,
            cancelled: false,
            claimed: false,
            initiatedAt: block.timestamp,
            approvedAt: 0
        });

        lockedBalances[msg.sender] += amount;

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TokenTransferFailed();

        emit TransferInitiated(nonce, msg.sender, recipient, amount);
    }

    function cancelTransfer(uint256 nonce) external whenNotPaused {
        TransferRecord storage record = transfers[nonce];

        if (record.sender == address(0)) revert TransferNotFound();
        if (record.approved) revert TransferAlreadyApproved();
        if (record.claimed) revert TransferAlreadyClaimed();
        if (record.cancelled) revert TransferAlreadyCancelled();
        if (record.sender != msg.sender) revert NotTransferSender();

        record.cancelled = true;

        uint256 amount = record.amount;
        lockedBalances[msg.sender] -= amount;

        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TokenTransferFailed();

        emit TransferCancelled(nonce, msg.sender, amount);
    }

    function approveTransfer(uint256 nonce) external onlyOperator whenNotPaused {
        TransferRecord storage record = transfers[nonce];

        if (record.sender == address(0)) revert TransferNotFound();
        if (record.approved) revert TransferAlreadyApproved();
        if (record.claimed) revert TransferAlreadyClaimed();
        if (record.cancelled) revert TransferAlreadyCancelled();

        record.approved = true;
        record.approvedAt = block.timestamp;

        emit TransferApproved(nonce, record.recipient, record.amount);
    }

    function claimTransfer(uint256 nonce) external whenNotPaused {
        TransferRecord storage record = transfers[nonce];

        if (record.sender == address(0)) revert TransferNotFound();
        if (!record.approved) revert TransferNotApproved();
        if (record.claimed) revert TransferAlreadyClaimed();
        if (record.recipient != msg.sender) revert NotTransferRecipient();
        if (block.timestamp > record.approvedAt + CLAIM_WINDOW) revert ClaimWindowExpired();

        record.claimed = true;
        isTransferClaimed[nonce] = true;

        uint256 amount = record.amount;
        bridgedBalances[msg.sender] += amount;
        totalBridgedSupply += amount;

        emit TransferClaimed(nonce, msg.sender, amount);
    }

    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function getTransfer(uint256 nonce) external view returns (TransferRecord memory) {
        return transfers[nonce];
    }

    function getRemainingClaimTime(uint256 nonce) external view returns (uint256) {
        TransferRecord storage record = transfers[nonce];
        if (!record.approved || record.claimed) return 0;
        uint256 deadline = record.approvedAt + CLAIM_WINDOW;
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
}
