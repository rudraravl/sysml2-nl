// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }
}

contract WBTCBridge {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_DEPOSIT = 0.001 * 10**8;
    uint256 public constant MAX_FEE_BPS = 50;
    uint256 private constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable wbtc;
    address public operator;
    uint256 public bridgingFeeBps;
    uint256 public totalLocked;
    uint256 public totalFeesAccrued;
    uint256 public nextTransferId;

    enum Status { None, Pending, Confirmed, Claimed }

    struct BridgeTransfer {
        address depositor;
        address destRecipient;
        uint256 amount;
        uint256 fee;
        Status status;
    }

    mapping(address => uint256) public deposits;
    mapping(uint256 => BridgeTransfer) public bridgeTransfers;

    event Deposited(address indexed depositor, uint256 amount);
    event BridgeInitiated(uint256 indexed transferId, address indexed depositor, address destRecipient, uint256 amount, uint256 fee);
    event BridgeApproved(uint256 indexed transferId, address indexed operator);
    event Claimed(uint256 indexed transferId, address indexed depositor, address destRecipient, uint256 netAmount, uint256 fee);
    event BridgingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed operator, uint256 amount);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    error Unauthorized();
    error ZeroAddress();
    error AmountBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientDeposit(uint256 available, uint256 required);
    error InvalidTransferStatus(Status expected, Status actual);
    error FeeExceedsCap(uint256 feeBps, uint256 cap);
    error NothingToWithdraw();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _wbtc, address _operator, uint256 _initialFeeBps) {
        if (_wbtc == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_initialFeeBps > MAX_FEE_BPS) revert FeeExceedsCap(_initialFeeBps, MAX_FEE_BPS);
        wbtc = IERC20(_wbtc);
        operator = _operator;
        bridgingFeeBps = _initialFeeBps;
        emit OperatorTransferred(address(0), _operator);
    }

    function deposit(uint256 amount) external {
        if (amount < MIN_DEPOSIT) revert AmountBelowMinimum(amount, MIN_DEPOSIT);
        deposits[msg.sender] += amount;
        totalLocked += amount;
        wbtc.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function initiateBridge(uint256 amount, address destRecipient) external {
        if (amount < MIN_DEPOSIT) revert AmountBelowMinimum(amount, MIN_DEPOSIT);
        if (destRecipient == address(0)) revert ZeroAddress();
        uint256 available = deposits[msg.sender];
        if (available < amount) revert InsufficientDeposit(available, amount);

        deposits[msg.sender] = available - amount;
        uint256 fee = (amount * bridgingFeeBps) / BPS_DENOMINATOR;
        uint256 transferId = nextTransferId++;

        bridgeTransfers[transferId] = BridgeTransfer({
            depositor: msg.sender,
            destRecipient: destRecipient,
            amount: amount,
            fee: fee,
            status: Status.Pending
        });

        emit BridgeInitiated(transferId, msg.sender, destRecipient, amount, fee);
    }

    function approveBridge(uint256 transferId) external onlyOperator {
        BridgeTransfer storage t = bridgeTransfers[transferId];
        if (t.status != Status.Pending) revert InvalidTransferStatus(Status.Pending, t.status);
        t.status = Status.Confirmed;
        emit BridgeApproved(transferId, operator);
    }

    function claim(uint256 transferId) external {
        BridgeTransfer storage t = bridgeTransfers[transferId];
        if (t.status != Status.Confirmed) revert InvalidTransferStatus(Status.Confirmed, t.status);
        t.status = Status.Claimed;
        totalFeesAccrued += t.fee;
        emit Claimed(transferId, t.depositor, t.destRecipient, t.amount - t.fee, t.fee);
    }

    function updateBridgingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsCap(newFeeBps, MAX_FEE_BPS);
        uint256 old = bridgingFeeBps;
        bridgingFeeBps = newFeeBps;
        emit BridgingFeeUpdated(old, newFeeBps);
    }

    function withdrawFees() external onlyOperator {
        uint256 amount = totalFeesAccrued;
        if (amount == 0) revert NothingToWithdraw();
        totalFeesAccrued = 0;
        totalLocked -= amount;
        wbtc.safeTransfer(operator, amount);
        emit FeesWithdrawn(operator, amount);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorTransferred(old, newOperator);
    }

    function getBridgeTransfer(uint256 transferId) external view returns (BridgeTransfer memory) {
        return bridgeTransfers[transferId];
    }
}
