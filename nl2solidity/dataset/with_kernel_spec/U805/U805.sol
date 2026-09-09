// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title WrappedAssetBridge
 * @notice Cross-chain bridge for a specific wrapped ERC-20 asset. The bridge takes custody of
 *         wrapped assets on this network when users initiate transfers to the other network,
 *         and releases custody when users claim assets received from the other network.
 *
 *         A designated operator is responsible for approving incoming transfers (crediting
 *         recipients with claimable assets) and finalizing outgoing withdrawals (confirming
 *         that the assets have been released on the other network).
 *
 *         A 0.1% fee is charged on every transfer initiated from this network. The maximum
 *         amount that can be transferred in a single transaction is 1000 wrapped assets.
 */
contract WrappedAssetBridge {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotOperator();
    error NotWithdrawalOwner();
    error WithdrawalAlreadyFinalized();
    error WithdrawalAlreadyCancelled();
    error WithdrawalNotFound();
    error AmountExceedsMaximum();
    error ZeroAmount();
    error ZeroAddress();
    error NothingToClaim();
    error InsufficientFeeBalance();
    error TransferFailed();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event TransferInitiated(
        uint256 indexed withdrawalId,
        address indexed sender,
        uint256 amount,
        uint256 fee,
        uint256 totalBridged
    );
    event TransferApproved(address indexed recipient, uint256 amount, uint256 totalBridged);
    event WithdrawalFinalized(uint256 indexed withdrawalId, address indexed sender, uint256 amount);
    event WithdrawalCancelled(uint256 indexed withdrawalId, address indexed sender, uint256 amount);
    event Claimed(address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    /// @notice Fee in basis points: 1 bps over a 1000 denominator => 0.1%.
    uint256 public constant FEE_BPS = 1;
    uint256 public constant BPS_DENOMINATOR = 1000;

    /// @notice Maximum amount of wrapped assets that can be transferred in a single transaction.
    uint256 public constant MAX_TRANSFER = 1000 * 10 ** 18;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    /// @notice The wrapped asset managed by this bridge.
    IERC20 public immutable token;

    /// @notice The designated operator authorized to approve incoming transfers and finalize withdrawals.
    address public operator;

    /// @notice Total wrapped assets bridged out to the other network (net of cancellations).
    uint256 public totalBridged;

    /// @notice Accumulated fees collected from initiated transfers, available for the operator to withdraw.
    uint256 public accumulatedFees;

    /// @notice Counter for the next withdrawal identifier.
    uint256 private _nextWithdrawalId;

    struct PendingWithdrawal {
        address sender;
        uint256 amount;
        bool finalized;
        bool cancelled;
    }

    /// @notice Mapping from withdrawal id to the pending withdrawal details.
    mapping(uint256 => PendingWithdrawal) public pendingWithdrawals;

    /// @notice Mapping from recipient to the amount of wrapped assets they can claim.
    mapping(address => uint256) public pendingClaims;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    /**
     * @param token_    The address of the wrapped ERC-20 asset managed by this bridge.
     * @param operator_ The address of the designated operator.
     */
    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        operator = operator_;
        _nextWithdrawalId = 1;
    }

    // -------------------------------------------------------------------------
    // User functions
    // -------------------------------------------------------------------------

    /**
     * @notice Initiate a cross-chain transfer of wrapped assets to the other network.
     *         A 0.1% fee is charged on top of the specified amount. The assets (amount + fee)
     *         are pulled into this contract's custody and a pending withdrawal is recorded.
     *         The withdrawal can be cancelled by the sender until the operator finalizes it.
     * @param amount The amount of wrapped assets to transfer (before fee), in wei.
     * @return withdrawalId The identifier of the created pending withdrawal.
     */
    function initiateTransfer(uint256 amount) external returns (uint256 withdrawalId) {
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_TRANSFER) revert AmountExceedsMaximum();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 totalPull = amount + fee;

        // Effects: record the pending withdrawal before interacting with the token.
        withdrawalId = _nextWithdrawalId++;
        pendingWithdrawals[withdrawalId] = PendingWithdrawal({
            sender: msg.sender,
            amount: amount,
            finalized: false,
            cancelled: false
        });

        accumulatedFees += fee;
        totalBridged += amount;

        emit TransferInitiated(withdrawalId, msg.sender, amount, fee, totalBridged);

        // Interactions: pull the wrapped assets from the sender into custody.
        if (!token.transferFrom(msg.sender, address(this), totalPull)) revert TransferFailed();
    }

    /**
     * @notice Cancel a pending withdrawal before it is finalized by the operator.
     *         The locked principal is returned to the original sender. The fee is
     *         non-refundable and remains in the bridge as accumulated fees.
     * @param withdrawalId The identifier of the pending withdrawal to cancel.
     */
    function cancelPendingWithdrawal(uint256 withdrawalId) external {
        PendingWithdrawal storage wd = pendingWithdrawals[withdrawalId];
        if (wd.sender == address(0)) revert WithdrawalNotFound();
        if (wd.sender != msg.sender) revert NotWithdrawalOwner();
        if (wd.finalized) revert WithdrawalAlreadyFinalized();
        if (wd.cancelled) revert WithdrawalAlreadyCancelled();

        wd.cancelled = true;
        totalBridged -= wd.amount;

        emit WithdrawalCancelled(withdrawalId, msg.sender, wd.amount);

        // Interactions: refund the principal to the original sender.
        if (!token.transfer(msg.sender, wd.amount)) revert TransferFailed();
    }

    /**
     * @notice Claim wrapped assets that were approved by the operator as having been
     *         received from the other network.
     */
    function claim() external {
        uint256 amount = pendingClaims[msg.sender];
        if (amount == 0) revert NothingToClaim();

        // Effects: reset the claimable balance before transferring.
        pendingClaims[msg.sender] = 0;

        emit Claimed(msg.sender, amount);

        // Interactions: release custody of the wrapped assets to the claimant.
        if (!token.transfer(msg.sender, amount)) revert TransferFailed();
    }

    // -------------------------------------------------------------------------
    // Operator functions
    // -------------------------------------------------------------------------

    /**
     * @notice Approve a transfer originating from the other network. Credits the
     *         recipient with claimable wrapped assets held in custody.
     * @param recipient The address entitled to claim the assets on this network.
     * @param amount    The amount of wrapped assets to credit, in wei.
     */
    function approveTransfer(address recipient, uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        pendingClaims[recipient] += amount;
        totalBridged += amount;

        emit TransferApproved(recipient, amount, totalBridged);
    }

    /**
     * @notice Finalize a pending withdrawal, confirming that the assets have been
     *         released to the other network. After finalization the sender can no
     *         longer cancel the withdrawal.
     * @param withdrawalId The identifier of the pending withdrawal to finalize.
     */
    function finalizeWithdrawal(uint256 withdrawalId) external onlyOperator {
        PendingWithdrawal storage wd = pendingWithdrawals[withdrawalId];
        if (wd.sender == address(0)) revert WithdrawalNotFound();
        if (wd.cancelled) revert WithdrawalAlreadyCancelled();
        if (wd.finalized) revert WithdrawalAlreadyFinalized();

        wd.finalized = true;

        emit WithdrawalFinalized(withdrawalId, wd.sender, wd.amount);
    }

    /**
     * @notice Withdraw accumulated fees to a designated recipient. Only the operator
     *         may call this function.
     * @param to     The recipient of the fees.
     * @param amount The amount of fees to withdraw, in wei.
     */
    function withdrawFees(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accumulatedFees) revert InsufficientFeeBalance();

        // Effects: reduce accumulated fees before transferring.
        accumulatedFees -= amount;

        emit FeesWithdrawn(to, amount);

        // Interactions: transfer fees to the recipient.
        if (!token.transfer(to, amount)) revert TransferFailed();
    }

    /**
     * @notice Transfer the operator role to a new account.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice Returns the identifier that will be assigned to the next initiated withdrawal.
    function nextWithdrawalId() external view returns (uint256) {
        return _nextWithdrawalId;
    }

    /// @notice Returns the details of a pending withdrawal.
    function getPendingWithdrawal(uint256 withdrawalId)
        external
        view
        returns (address sender, uint256 amount, bool finalized, bool cancelled)
    {
        PendingWithdrawal storage wd = pendingWithdrawals[withdrawalId];
        return (wd.sender, wd.amount, wd.finalized, wd.cancelled);
    }

    /// @notice Computes the fee that would be charged for a given transfer amount.
    function computeFee(uint256 amount) external pure returns (uint256 fee) {
        return (amount * FEE_BPS) / BPS_DENOMINATOR;
    }
}
