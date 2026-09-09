// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Minimal ERC20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Minimal SafeERC20 wrapper that reverts on failed calls.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }

        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @dev Minimal ReentrancyGuard.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title CrossChainEscrow
 * @dev Facilitates cross-chain asset transfers by holding wrapped tokens in escrow
 * on the source chain until they are minted on the destination chain.
 *
 * Each transfer incurs a flat fee of 0.05 wrapped tokens (overridable per chain).
 * Refunded transfers must be claimed within 7 days, otherwise funds are swept to treasury.
 */
contract CrossChainEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status {
        Pending,
        Completed,
        Refunded,
        Cancelled,
        Claimed,
        Expired
    }

    struct Transfer {
        address sender;
        address asset;
        uint256 amount;
        uint256 fee;
        uint256 destChainId;
        address recipient;
        Status status;
        uint256 refundTime;
    }

    address public operator;
    address public treasury;

    uint256 public globalFee;
    uint256 public nextTransferId;

    mapping(uint256 => bool) public isSupportedChain;
    mapping(uint256 => uint256) public chainFees;
    mapping(uint256 => Transfer) public transfers;

    uint256 public constant REFUND_CLAIM_PERIOD = 7 days;
    uint256 public constant DEFAULT_FEE = 0.05 ether; // 5e16

    event TransferInitiated(
        uint256 indexed transferId,
        address indexed sender,
        address indexed recipient,
        uint256 destChainId,
        address asset,
        uint256 amount,
        uint256 fee
    );
    event TransferCompleted(uint256 indexed transferId);
    event TransferRefunded(uint256 indexed transferId);
    event TransferCancelled(uint256 indexed transferId);
    event TransferClaimed(uint256 indexed transferId, address indexed claimer);
    event TransferExpired(uint256 indexed transferId);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event ChainConfigUpdated(uint256 indexed chainId, bool supported, uint256 fee);
    event GlobalFeeUpdated(uint256 fee);

    error NotOperator();
    error NotSender();
    error ChainNotSupported();
    error InvalidAmount();
    error TransferNotPending();
    error TransferNotRefunded();
    error RefundNotExpired();
    error RefundExpired();
    error ZeroAddress();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();
        operator = msg.sender;
        treasury = _treasury;
        globalFee = DEFAULT_FEE;
        nextTransferId = 1;
    }

    /**
     * @dev Initiates a cross-chain transfer by locking wrapped tokens in escrow.
     * @param asset The address of the wrapped ERC20 token to transfer.
     * @param amount The amount of tokens to transfer (principal, excluding fee).
     * @param destChainId The destination chain identifier.
     * @param recipient The recipient address on the destination chain.
     */
    function initiateTransfer(
        address asset,
        uint256 amount,
        uint256 destChainId,
        address recipient
    ) external nonReentrant returns (uint256 transferId) {
        if (!isSupportedChain[destChainId]) revert ChainNotSupported();
        if (asset == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 fee = chainFees[destChainId] > 0 ? chainFees[destChainId] : globalFee;
        uint256 totalAmount = amount + fee;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), totalAmount);

        transferId = nextTransferId++;
        transfers[transferId] = Transfer({
            sender: msg.sender,
            asset: asset,
            amount: amount,
            fee: fee,
            destChainId: destChainId,
            recipient: recipient,
            status: Status.Pending,
            refundTime: 0
        });

        emit TransferInitiated(transferId, msg.sender, recipient, destChainId, asset, amount, fee);
    }

    /**
     * @dev Cancels a pending transfer and refunds the locked tokens to the sender.
     * @param transferId The ID of the transfer to cancel.
     */
    function cancelTransfer(uint256 transferId) external nonReentrant {
        Transfer storage t = transfers[transferId];
        if (t.sender != msg.sender) revert NotSender();
        if (t.status != Status.Pending) revert TransferNotPending();

        t.status = Status.Cancelled;
        uint256 totalAmount = t.amount + t.fee;
        IERC20(t.asset).safeTransfer(t.sender, totalAmount);

        emit TransferCancelled(transferId);
    }

    /**
     * @dev Marks a transfer as completed. The principal amount remains locked,
     * while the fee is sent to the treasury. Only callable by the operator.
     * @param transferId The ID of the transfer to complete.
     */
    function completeTransfer(uint256 transferId) external onlyOperator nonReentrant {
        Transfer storage t = transfers[transferId];
        if (t.status != Status.Pending) revert TransferNotPending();

        t.status = Status.Completed;

        if (t.fee > 0) {
            IERC20(t.asset).safeTransfer(treasury, t.fee);
        }

        emit TransferCompleted(transferId);
    }

    /**
     * @dev Marks a pending transfer as refunded, allowing the sender to claim
     * their tokens back. Only callable by the operator.
     * @param transferId The ID of the transfer to refund.
     */
    function refundTransfer(uint256 transferId) external onlyOperator {
        Transfer storage t = transfers[transferId];
        if (t.status != Status.Pending) revert TransferNotPending();

        t.status = Status.Refunded;
        t.refundTime = block.timestamp;

        emit TransferRefunded(transferId);
    }

    /**
     * @dev Allows the sender to claim refunded tokens from a failed transfer.
     * Must be claimed within 7 days of the refund.
     * @param transferId The ID of the transfer to claim.
     */
    function claimRefund(uint256 transferId) external nonReentrant {
        Transfer storage t = transfers[transferId];
        if (t.sender != msg.sender) revert NotSender();
        if (t.status != Status.Refunded) revert TransferNotRefunded();
        if (block.timestamp > t.refundTime + REFUND_CLAIM_PERIOD) revert RefundExpired();

        t.status = Status.Claimed;
        uint256 totalAmount = t.amount + t.fee;
        IERC20(t.asset).safeTransfer(t.sender, totalAmount);

        emit TransferClaimed(transferId, msg.sender);
    }

    /**
     * @dev Allows the operator to sweep unclaimed refunded tokens to the treasury
     * after the 7-day claim period has elapsed.
     * @param transferId The ID of the expired transfer.
     */
    function claimExpiredTransfer(uint256 transferId) external onlyOperator nonReentrant {
        Transfer storage t = transfers[transferId];
        if (t.status != Status.Refunded) revert TransferNotRefunded();
        if (block.timestamp <= t.refundTime + REFUND_CLAIM_PERIOD) revert RefundNotExpired();

        t.status = Status.Expired;
        uint256 totalAmount = t.amount + t.fee;
        IERC20(t.asset).safeTransfer(treasury, totalAmount);

        emit TransferExpired(transferId);
    }

    /**
     * @dev Updates the designated operator address.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @dev Updates the treasury address where fees and expired funds are collected.
     * @param newTreasury The address of the new treasury.
     */
    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    /**
     * @dev Updates the global fallback fee for transfers.
     * @param fee The new global fee amount.
     */
    function setGlobalFee(uint256 fee) external onlyOperator {
        globalFee = fee;
        emit GlobalFeeUpdated(fee);
    }

    /**
     * @dev Updates the configuration for a specific destination chain.
     * @param chainId The destination chain identifier.
     * @param supported Whether the chain is supported for transfers.
     * @param fee The specific fee associated with transfers to this chain.
     */
    function updateSupportedChain(uint256 chainId, bool supported, uint256 fee) external onlyOperator {
        isSupportedChain[chainId] = supported;
        chainFees[chainId] = fee;
        emit ChainConfigUpdated(chainId, supported, fee);
    }

    /**
     * @dev Returns the full transfer record.
     */
    function getTransfer(uint256 transferId) external view returns (Transfer memory) {
        return transfers[transferId];
    }
}
