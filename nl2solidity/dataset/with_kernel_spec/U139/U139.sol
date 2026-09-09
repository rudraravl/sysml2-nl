// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @dev Minimal ERC-20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that revert on failure.
 */
library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function _call(address target, bytes memory data) private returns (bool, bytes memory) {
        (bool success, bytes memory returndata) = target.call(data);
        return (success, returndata);
    }

    function _verifyCallResult(bool success, bytes memory returndata, address token) private pure {
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), returndatasize())
                }
            }
            revert SafeERC20FailedOperation(token);
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(token);
        }
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = _call(
            address(token),
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        _verifyCallResult(success, returndata, address(token));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = _call(
            address(token),
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        _verifyCallResult(success, returndata, address(token));
    }
}

/**
 * @title ReentrancyGuard
 * @dev Prevents reentrant calls via status flag.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    error ReentrantCall();

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title CrossChainAssetBridge
 * @notice Holds user-deposited ERC-20 tokens in escrow on the source chain and
 *         coordinates cross-chain transfers to a destination chain. A privileged
 *         operator relays claims on the destination chain and manages global
 *         transfer parameters such as the fee and pause state.
 */
contract CrossChainAssetBridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error AmountBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 required);
    error Unauthorized();
    error EnforcedPause();
    error FeeCapExceeded(uint256 provided, uint256 cap);
    error TransferAlreadyClaimed(bytes32 transferId);
    error AmountExceedsFeesCollected(uint256 amount, uint256 collected);

    event Deposited(address indexed sender, address indexed recipient, uint256 amount);
    event TransferInitiated(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 fee
    );
    event TransferClaimed(bytes32 indexed transferId, address indexed recipient, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    uint256 public constant MIN_TRANSFER_AMOUNT = 100;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant DEFAULT_FEE_BPS = 10;

    IERC20 public immutable token;
    address public operator;
    bool public paused;
    uint256 public transferFeeBps;
    uint256 public totalFeesCollected;

    mapping(address => uint256) public balances;
    mapping(bytes32 => bool) public claimedTransfers;
    mapping(bytes32 => uint256) public pendingTransferAmounts;
    mapping(bytes32 => address) public pendingTransferSender;
    mapping(bytes32 => address) public pendingTransferRecipient;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        operator = operator_;
        transferFeeBps = DEFAULT_FEE_BPS;
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposited(msg.sender, msg.sender, amount);
    }

    function depositFor(address recipient, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[recipient] += amount;
        emit Deposited(msg.sender, recipient, amount);
    }

    function initiateTransfer(address recipient, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount < MIN_TRANSFER_AMOUNT) revert AmountBelowMinimum(amount, MIN_TRANSFER_AMOUNT);

        uint256 available = balances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        uint256 fee = (amount * transferFeeBps) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        balances[msg.sender] = available - amount;
        totalFeesCollected += fee;

        bytes32 transferId = _computeTransferId(msg.sender, recipient, netAmount, block.chainid, block.number);
        pendingTransferAmounts[transferId] = netAmount;
        pendingTransferSender[transferId] = msg.sender;
        pendingTransferRecipient[transferId] = recipient;

        emit TransferInitiated(transferId, msg.sender, recipient, netAmount, fee);
    }

    function claimTransfer(bytes32 transferId, address recipient, uint256 amount) external nonReentrant onlyOperator {
        if (claimedTransfers[transferId]) revert TransferAlreadyClaimed(transferId);
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        claimedTransfers[transferId] = true;
        token.safeTransfer(recipient, amount);
        emit TransferClaimed(transferId, recipient, amount);
    }

    function setTransferFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeCapExceeded(newFeeBps, MAX_FEE_BPS);
        uint256 old = transferFeeBps;
        transferFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function withdrawFees(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > totalFeesCollected) revert AmountExceedsFeesCollected(amount, totalFeesCollected);
        totalFeesCollected -= amount;
        token.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function computeTransferId(
        address sender,
        address recipient,
        uint256 amount,
        uint256 chainId,
        uint256 blockNumber
    ) external pure returns (bytes32) {
        return _computeTransferId(sender, recipient, amount, chainId, blockNumber);
    }

    function _computeTransferId(
        address sender,
        address recipient,
        uint256 amount,
        uint256 chainId,
        uint256 blockNumber
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, recipient, amount, chainId, blockNumber));
    }
}
