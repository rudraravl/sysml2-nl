// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CrossChainTokenEscrow
 * @dev Escrow-based bridge that locks transferred ERC-20 tokens on the origin domain
 *      until a corresponding release is authorized on the destination domain.
 */
contract CrossChainTokenEscrow {
    enum TransferStatus {
        Pending,
        Completed,
        Disputed,
        Released,
        Refunded
    }

    struct TransferRecord {
        address token;
        uint256 amount;
        address sender;
        address recipient;
        uint256 destinationDomain;
        TransferStatus status;
        uint256 initiatedBlock;
        uint256 confirmedBlock;
    }

    uint256 public constant MIN_CONFIRMATION_BLOCKS = 10;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% hard cap
    uint256 public constant DEFAULT_FEE_BPS = 5; // 0.05%

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _BPS_DENOMINATOR = 10000;

    address private _owner;
    uint256 public feeBps;
    uint256 private _nextTransferId;

    mapping(address => bool) private _operators;
    mapping(bytes32 => TransferRecord) private _transfers;
    mapping(bytes32 => bool) private _transferExists;

    uint256 private _reentrancyStatus;

    event TransferInitiated(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 destinationDomain,
        address recipient
    );
    event TransferConfirmed(bytes32 indexed transferId, address indexed operator);
    event TransferDisputed(bytes32 indexed transferId, address indexed operator);
    event TransferReleased(
        bytes32 indexed transferId,
        address indexed recipient,
        uint256 netAmount,
        uint256 feeAmount
    );
    event TransferRefunded(bytes32 indexed transferId, address indexed sender, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed operator, bool status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotOperator();
    error TransferNotFound();
    error NotPending();
    error NotCompleted();
    error NotDisputed();
    error InsufficientConfirmations();
    error ZeroAmount();
    error ZeroAddress();
    error InvalidRecipient();
    error TransferFailed();
    error FeeTooHigh();
    error ReentrancyDetected();

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!_operators[msg.sender]) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrancyDetected();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    constructor() {
        _owner = msg.sender;
        feeBps = DEFAULT_FEE_BPS;
        _nextTransferId = 1;
        _reentrancyStatus = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeUpdated(0, feeBps);
    }

    function initiateTransfer(
        address token,
        uint256 amount,
        uint256 destinationDomain,
        address recipient
    ) external nonReentrant returns (bytes32 transferId) {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert InvalidRecipient();

        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        transferId = bytes32(_nextTransferId++);
        _transfers[transferId] = TransferRecord({
            token: token,
            amount: amount,
            sender: msg.sender,
            recipient: recipient,
            destinationDomain: destinationDomain,
            status: TransferStatus.Pending,
            initiatedBlock: block.number,
            confirmedBlock: 0
        });
        _transferExists[transferId] = true;

        emit TransferInitiated(transferId, msg.sender, token, amount, destinationDomain, recipient);
    }

    function confirmTransfer(bytes32 transferId) external onlyOperator {
        if (!_transferExists[transferId]) revert TransferNotFound();
        TransferRecord storage t = _transfers[transferId];
        if (t.status != TransferStatus.Pending) revert NotPending();

        t.status = TransferStatus.Completed;
        t.confirmedBlock = block.number;

        emit TransferConfirmed(transferId, msg.sender);
    }

    function disputeTransfer(bytes32 transferId) external onlyOperator {
        if (!_transferExists[transferId]) revert TransferNotFound();
        TransferRecord storage t = _transfers[transferId];
        if (t.status != TransferStatus.Pending) revert NotPending();

        t.status = TransferStatus.Disputed;

        emit TransferDisputed(transferId, msg.sender);
    }

    function approveRelease(bytes32 transferId) external onlyOperator nonReentrant {
        if (!_transferExists[transferId]) revert TransferNotFound();
        TransferRecord storage t = _transfers[transferId];
        if (t.status != TransferStatus.Completed) revert NotCompleted();
        if (block.number < t.confirmedBlock + MIN_CONFIRMATION_BLOCKS) revert InsufficientConfirmations();

        t.status = TransferStatus.Released;

        uint256 fee = (t.amount * feeBps) / _BPS_DENOMINATOR;
        uint256 net = t.amount - fee;

        if (fee > 0) {
            if (!IERC20(t.token).transfer(_owner, fee)) revert TransferFailed();
        }
        if (net > 0) {
            if (!IERC20(t.token).transfer(t.recipient, net)) revert TransferFailed();
        }

        emit TransferReleased(transferId, t.recipient, net, fee);
    }

    function refundDisputedTransfer(bytes32 transferId) external onlyOperator nonReentrant {
        if (!_transferExists[transferId]) revert TransferNotFound();
        TransferRecord storage t = _transfers[transferId];
        if (t.status != TransferStatus.Disputed) revert NotDisputed();

        t.status = TransferStatus.Refunded;

        if (!IERC20(t.token).transfer(t.sender, t.amount)) revert TransferFailed();

        emit TransferRefunded(transferId, t.sender, t.amount);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        _operators[operator] = status;
        emit OperatorUpdated(operator, status);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = _owner;
        _owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function isOperator(address account) public view returns (bool) {
        return _operators[account];
    }

    function transferExists(bytes32 transferId) public view returns (bool) {
        return _transferExists[transferId];
    }

    function getTransfer(bytes32 transferId) public view returns (TransferRecord memory) {
        if (!_transferExists[transferId]) revert TransferNotFound();
        return _transfers[transferId];
    }

    function nextTransferId() public view returns (uint256) {
        return _nextTransferId;
    }
}
