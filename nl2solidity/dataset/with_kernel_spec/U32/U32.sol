// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IMintableBurnableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) {
            revert("SafeERC20: transfer failed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) {
            revert("SafeERC20: transferFrom failed");
        }
    }
}

contract StableBridge {
    using SafeERC20 for IMintableBurnableERC20;

    error NotOwner();
    error NotOperator();
    error NotAuthorized(address caller);
    error ZeroAddress();
    error ZeroAmount();
    error AmountExceedsLimit(uint256 amount, uint256 limit);
    error AmountMustExceedFee(uint256 amount, uint256 fee);
    error InvalidDecimals(uint256 decimals);
    error InvalidOperation(uint256 operation);
    error TransferAlreadyApproved(bytes32 transferId);
    error TransferNotApproved(bytes32 transferId);
    error WrongOperation(bytes32 transferId, uint256 expected, uint256 actual);
    error InsufficientLockedBalance(address user, uint256 requested, uint256 available);
    error InsufficientFeeBalance(uint256 requested, uint256 available);
    error ReentrantCall();

    event Locked(address indexed user, uint256 grossAmount, uint256 fee, uint256 netAmount);
    event Unlocked(address indexed user, uint256 amount);
    event Minted(address indexed to, uint256 amount);
    event TransferApproved(bytes32 indexed transferId, address indexed from, address indexed to, uint256 amount, uint256 operation);
    event OperatorSet(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientSet(address indexed oldRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);

    uint256 public constant OP_MINT = 0;
    uint256 public constant OP_BURN = 1;

    IMintableBurnableERC20 public immutable stablecoin;
    address public owner;
    address public operator;
    address public feeRecipient;

    uint256 public immutable FEE;
    uint256 public immutable MAX_TRANSFER;

    mapping(address => uint256) public lockedBalanceOf;
    uint256 public totalLocked;
    uint256 public accumulatedFees;

    struct TransferApproval {
        address from;
        address to;
        uint256 amount;
        uint256 operation;
    }
    mapping(bytes32 => TransferApproval) private _approvals;
    mapping(bytes32 => bool) private _executed;

    uint256 private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(
        address stablecoin_,
        address operator_,
        address feeRecipient_,
        uint256 decimals_
    ) {
        if (stablecoin_ == address(0) || operator_ == address(0) || feeRecipient_ == address(0)) {
            revert ZeroAddress();
        }
        if (decimals_ < 2 || decimals_ > 36) revert InvalidDecimals(decimals_);
        stablecoin = IMintableBurnableERC20(stablecoin_);
        owner = msg.sender;
        operator = operator_;
        feeRecipient = feeRecipient_;
        FEE = 10 ** (decimals_ - 2);
        MAX_TRANSFER = 1_000_000 * (10 ** decimals_);
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorSet(address(0), operator_);
        emit FeeRecipientSet(address(0), feeRecipient_);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorSet(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientSet(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function lock(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_TRANSFER) revert AmountExceedsLimit(amount, MAX_TRANSFER);
        uint256 fee = FEE;
        if (amount <= fee) revert AmountMustExceedFee(amount, fee);
        uint256 net = amount - fee;
        lockedBalanceOf[msg.sender] += net;
        totalLocked += net;
        accumulatedFees += fee;
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit Locked(msg.sender, amount, fee, net);
    }

    function approveTransfer(
        bytes32 transferId,
        address from,
        address to,
        uint256 amount,
        uint256 operation
    ) external onlyOperator {
        if (operation != OP_MINT && operation != OP_BURN) revert InvalidOperation(operation);
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_TRANSFER) revert AmountExceedsLimit(amount, MAX_TRANSFER);
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (_approvals[transferId].amount != 0 || _executed[transferId]) {
            revert TransferAlreadyApproved(transferId);
        }
        _approvals[transferId] = TransferApproval({
            from: from,
            to: to,
            amount: amount,
            operation: operation
        });
        emit TransferApproved(transferId, from, to, amount, operation);
    }

    function executeBurn(bytes32 transferId) external nonReentrant {
        TransferApproval memory approval = _approvals[transferId];
        if (approval.amount == 0 || _executed[transferId]) revert TransferNotApproved(transferId);
        if (approval.operation != OP_BURN) revert WrongOperation(transferId, OP_BURN, approval.operation);
        address from = approval.from;
        uint256 amount = approval.amount;
        uint256 available = lockedBalanceOf[from];
        if (available < amount) revert InsufficientLockedBalance(from, amount, available);
        _executed[transferId] = true;
        delete _approvals[transferId];
        lockedBalanceOf[from] -= amount;
        totalLocked -= amount;
        stablecoin.burn(amount);
        emit Unlocked(from, amount);
    }

    function executeMint(bytes32 transferId) external nonReentrant {
        TransferApproval memory approval = _approvals[transferId];
        if (approval.amount == 0 || _executed[transferId]) revert TransferNotApproved(transferId);
        if (approval.operation != OP_MINT) revert WrongOperation(transferId, OP_MINT, approval.operation);
        address to = approval.to;
        uint256 amount = approval.amount;
        _executed[transferId] = true;
        delete _approvals[transferId];
        stablecoin.mint(to, amount);
        emit Minted(to, amount);
    }

    function withdrawFees(address to, uint256 amount) external nonReentrant {
        if (msg.sender != feeRecipient && msg.sender != owner) revert NotAuthorized(msg.sender);
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accumulatedFees) revert InsufficientFeeBalance(amount, accumulatedFees);
        accumulatedFees -= amount;
        stablecoin.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    function getApproval(bytes32 transferId) external view returns (TransferApproval memory) {
        return _approvals[transferId];
    }

    function isExecuted(bytes32 transferId) external view returns (bool) {
        return _executed[transferId];
    }

    function isApproved(bytes32 transferId) external view returns (bool) {
        return _approvals[transferId].amount != 0;
    }
}
