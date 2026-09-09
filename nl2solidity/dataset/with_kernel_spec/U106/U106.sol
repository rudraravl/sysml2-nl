// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title CrossChainTokenEscrow
 * @notice Facilitates the transfer of a specific fungible token between two
 *         distinct blockchain networks by holding tokens in escrow on this chain.
 *         Users deposit tokens, initiate withdrawal requests, and claim tokens
 *         after the designated operator approves the cross-chain transfer.
 *         The operator can approve, cancel pending requests, and update the
 *         fee percentage (capped at 0.5%). A withdrawal request must remain
 *         pending for at least 30 minutes before it can be approved.
 */
contract CrossChainTokenEscrow {
    // ─────────────────────────── Custom Errors ─────────────────────────────
    error ZeroAddress();
    error ZeroAmount();
    error NotOperator();
    error InsufficientDepositedBalance(uint256 available, uint256 required);
    error ActiveWithdrawalExists();
    error NoPendingWithdrawal();
    error PendingPeriodNotElapsed(uint256 remaining);
    error WithdrawalNotApproved();
    error FeeExceedsMaximum(uint256 provided, uint256 maximum);
    error TransferFailed();

    // ────────────────────────────── Enums ──────────────────────────────────
    enum WithdrawalStatus {
        None,
        Pending,
        Approved,
        Cancelled,
        Claimed
    }

    // ───────────────────────────── Structs ─────────────────────────────────
    struct WithdrawalRequest {
        uint256 amount;
        uint256 initiatedAt;
        WithdrawalStatus status;
    }

    // ────────────────────────────── Events ─────────────────────────────────
    event Deposited(address indexed user, uint256 amount);
    event WithdrawalInitiated(address indexed user, uint256 amount);
    event WithdrawalApproved(address indexed user, uint256 amount);
    event WithdrawalCancelled(address indexed user, uint256 amount);
    event WithdrawalClaimed(address indexed user, address recipient, uint256 payout, uint256 fee);
    event FeePercentageUpdated(uint256 oldFeePercentage, uint256 newFeePercentage);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ──────────────────────────── Constants ───────────────────────────────
    /// @dev Maximum fee in basis points: 50 bps = 0.5%.
    uint256 public constant MAX_FEE_PERCENTAGE = 50;
    /// @dev Minimum pending duration before a withdrawal can be approved.
    uint256 public constant MIN_PENDING_DURATION = 30 minutes;
    /// @dev Basis points denominator.
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ────────────────────────── State Variables ───────────────────────────
    IERC20 public immutable token;
    address public operator;
    uint256 public feePercentage;

    mapping(address => uint256) public depositedBalance;
    mapping(address => WithdrawalRequest) public withdrawalRequests;
    /// @dev Tracks whether a user currently has an active (Pending or Approved)
    ///      withdrawal request. Avoids brittle status strict-equality checks.
    mapping(address => bool) public hasActiveWithdrawal;

    // ──────────────────────────── Modifiers ────────────────────────────────
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ──────────────────────────── Constructor ──────────────────────────────
    /**
     * @param token_         The ERC-20 token to escrow.
     * @param operator_      The operator who approves/cancels withdrawals and sets fees.
     * @param feePercentage_ Initial fee percentage in basis points (max 50 = 0.5%).
     */
    constructor(address token_, address operator_, uint256 feePercentage_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (feePercentage_ > MAX_FEE_PERCENTAGE) revert FeeExceedsMaximum(feePercentage_, MAX_FEE_PERCENTAGE);
        token = IERC20(token_);
        operator = operator_;
        feePercentage = feePercentage_;
        emit FeePercentageUpdated(0, feePercentage_);
    }

    // ────────────────────────── External Functions ─────────────────────────

    /**
     * @notice Deposit tokens into the escrow. Caller must have approved this
     *         contract to spend `amount` tokens via the underlying ERC-20.
     * @param amount The amount of tokens to deposit.
     */
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        // Checks-effects-interactions: update state before external call.
        depositedBalance[msg.sender] += amount;
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Initiate a withdrawal request. Locks the requested amount from
     *         the caller's deposited balance until the request is resolved.
     *         Reverts if the caller already has an active (pending or approved) request.
     * @param amount The amount of tokens to request for cross-chain withdrawal.
     */
    function initiateWithdrawal(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        // Use a dedicated boolean flag to detect an active withdrawal rather
        // than relying on strict equality against multiple enum values.
        if (hasActiveWithdrawal[msg.sender]) revert ActiveWithdrawalExists();

        uint256 available = depositedBalance[msg.sender];
        if (available < amount) revert InsufficientDepositedBalance(available, amount);

        // Checks-effects-interactions: lock funds and mark active before any external interaction.
        depositedBalance[msg.sender] = available - amount;
        hasActiveWithdrawal[msg.sender] = true;
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: amount,
            initiatedAt: block.timestamp,
            status: WithdrawalStatus.Pending
        });

        emit WithdrawalInitiated(msg.sender, amount);
    }

    /**
     * @notice Approve a user's pending withdrawal request. Only callable by
     *         the operator and only after the minimum pending duration has elapsed.
     * @param user The address whose withdrawal request to approve.
     */
    function approveWithdrawal(address user) external onlyOperator {
        WithdrawalRequest storage req = withdrawalRequests[user];
        if (req.status != WithdrawalStatus.Pending) revert NoPendingWithdrawal();
        uint256 elapsed = block.timestamp - req.initiatedAt;
        if (elapsed < MIN_PENDING_DURATION) {
            revert PendingPeriodNotElapsed(MIN_PENDING_DURATION - elapsed);
        }
        req.status = WithdrawalStatus.Approved;
        emit WithdrawalApproved(user, req.amount);
    }

    /**
     * @notice Cancel a user's pending withdrawal request and restore the locked
     *         amount to their deposited balance. Only callable by the operator.
     * @param user The address whose withdrawal request to cancel.
     */
    function cancelWithdrawal(address user) external onlyOperator {
        WithdrawalRequest storage req = withdrawalRequests[user];
        if (req.status != WithdrawalStatus.Pending) revert NoPendingWithdrawal();
        uint256 amount = req.amount;
        req.status = WithdrawalStatus.Cancelled;
        hasActiveWithdrawal[user] = false;
        depositedBalance[user] += amount;
        emit WithdrawalCancelled(user, amount);
    }

    /**
     * @notice Claim tokens from an approved withdrawal request. The fee is
     *         deducted and sent to the operator; the remainder goes to the caller.
     */
    function claim() external {
        WithdrawalRequest storage req = withdrawalRequests[msg.sender];
        if (req.status != WithdrawalStatus.Approved) revert WithdrawalNotApproved();
        uint256 amount = req.amount;
        uint256 fee = (amount * feePercentage) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        // Checks-effects-interactions: mark as claimed and clear active flag before transfers.
        req.status = WithdrawalStatus.Claimed;
        hasActiveWithdrawal[msg.sender] = false;

        bool ok1 = token.transfer(msg.sender, payout);
        if (!ok1) revert TransferFailed();
        if (fee > 0) {
            bool ok2 = token.transfer(operator, fee);
            if (!ok2) revert TransferFailed();
        }

        emit WithdrawalClaimed(msg.sender, msg.sender, payout, fee);
    }

    /**
     * @notice Update the fee percentage. Only callable by the operator.
     * @param newFeePercentage The new fee in basis points (max 50 = 0.5%).
     */
    function setFeePercentage(uint256 newFeePercentage) external onlyOperator {
        if (newFeePercentage > MAX_FEE_PERCENTAGE) {
            revert FeeExceedsMaximum(newFeePercentage, MAX_FEE_PERCENTAGE);
        }
        uint256 old = feePercentage;
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(old, newFeePercentage);
    }

    /**
     * @notice Transfer operator role to a new address. Only callable by the
     *         current operator.
     * @param newOperator The new operator address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    // ──────────────────────────── View Functions ───────────────────────────

    /**
     * @notice Returns the withdrawal request details for a given user.
     */
    function getWithdrawalRequest(address user) external view returns (WithdrawalRequest memory) {
        return withdrawalRequests[user];
    }

    /**
     * @notice Returns the available (non-locked) deposited balance for a user.
     */
    function getAvailableBalance(address user) external view returns (uint256) {
        return depositedBalance[user];
    }

    /**
     * @notice Calculates the fee that would be applied to a given amount
     *         using the current fee percentage.
     */
    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * feePercentage) / BPS_DENOMINATOR;
    }
}
