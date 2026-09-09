// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title L1WrappedTokenBridge
 * @notice Cross-chain bridge that holds Layer-1 native tokens as collateral
 *         and facilitates an equivalent wrapped token on Layer-2. Users deposit
 *         L1 native tokens to receive wrapped tokens on L2, and burn wrapped
 *         tokens on L2 to withdraw L1 native tokens. A designated operator can
 *         pause deposits and withdrawals, update the L2 bridge address, and
 *         withdraw accrued fees.
 */
contract L1WrappedTokenBridge {
    // ---------------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------------

    /// @notice Maximum native tokens permitted in a single deposit.
    uint256 public constant MAX_DEPOSIT = 10_000 ether;

    /// @notice Withdrawal fee in basis points (0.1% = 10 bps).
    uint256 public constant WITHDRAWAL_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // ---------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------

    address public operator;
    address public l2Bridge;
    bool public paused;

    /// @notice Total supply of the wrapped token minted on Layer-2.
    uint256 public totalL2Supply;

    /// @notice Cumulative withdrawal fees accrued, withdrawable by the operator.
    uint256 public collectedFees;

    /// @notice Per-user native tokens deposited but not yet relayed to L2.
    mapping(address => uint256) public pendingDeposits;

    /// @notice Per-user native tokens finalized and minted as wrapped tokens on L2.
    mapping(address => uint256) public finalizedDeposits;

    /// @notice Tracks processed L2 burn IDs to prevent double-withdrawal.
    mapping(bytes32 => bool) public processedWithdrawals;

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------

    event Deposit(address indexed depositor, uint256 amount, address indexed l2Recipient);
    event DepositFinalized(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed l1Recipient, uint256 amount, uint256 fee);
    event L2BridgeUpdated(address indexed previousL2Bridge, address indexed newL2Bridge);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed operator, uint256 amount);

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------

    error EnforcedPause();
    error ExpectedPause();
    error NotOperator();
    error NotL2Bridge();
    error ZeroAddress();
    error ZeroAmount();
    error ExceedsMaxDeposit(uint256 amount, uint256 max);
    error InsufficientPendingDeposit(address depositor, uint256 available, uint256 requested);
    error InsufficientL2Supply(uint256 available, uint256 requested);
    error InsufficientContractBalance(uint256 available, uint256 requested);
    error WithdrawalAlreadyProcessed(bytes32 burnId);
    error EthTransferFailed();

    // ---------------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyL2Bridge() {
        if (msg.sender != l2Bridge) revert NotL2Bridge();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------

    constructor(address _operator, address _l2Bridge) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_l2Bridge == address(0)) revert ZeroAddress();
        operator = _operator;
        l2Bridge = _l2Bridge;
        emit L2BridgeUpdated(address(0), _l2Bridge);
    }

    // ---------------------------------------------------------------------------
    // Deposit
    // ---------------------------------------------------------------------------

    /**
     * @notice Deposit L1 native tokens to receive an equivalent amount of
     *         wrapped tokens on Layer-2. The native tokens are held as collateral.
     * @param l2Recipient Address on Layer-2 that will receive the wrapped tokens.
     */
    function deposit(address l2Recipient) external payable whenNotPaused {
        if (l2Recipient == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert ZeroAmount();
        if (msg.value > MAX_DEPOSIT) revert ExceedsMaxDeposit(msg.value, MAX_DEPOSIT);

        pendingDeposits[msg.sender] += msg.value;

        emit Deposit(msg.sender, msg.value, l2Recipient);
    }

    /**
     * @notice Finalize a pending deposit after the wrapped tokens have been
     *         minted on Layer-2. Only callable by the operator.
     * @param depositor The address that deposited on L1.
     * @param amount    The amount to finalize.
     */
    function finalizeDeposit(address depositor, uint256 amount) external onlyOperator {
        if (depositor == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 available = pendingDeposits[depositor];
        if (available < amount) revert InsufficientPendingDeposit(depositor, available, amount);

        pendingDeposits[depositor] = available - amount;
        finalizedDeposits[depositor] += amount;
        totalL2Supply += amount;

        emit DepositFinalized(depositor, amount);
    }

    // ---------------------------------------------------------------------------
    // Withdrawal
    // ---------------------------------------------------------------------------

    /**
     * @notice Process a withdrawal after the caller has burned wrapped tokens
     *         on Layer-2. The L2 bridge submits the unique `burnId` to prevent
     *         double-processing. A 0.1% fee is deducted from the released amount.
     * @param l1Recipient Address on Layer-1 to receive the native tokens.
     * @param amount      Gross amount of wrapped tokens burned on L2.
     * @param burnId      Unique identifier of the L2 burn event.
     */
    function withdraw(
        address l1Recipient,
        uint256 amount,
        bytes32 burnId
    ) external onlyL2Bridge whenNotPaused {
        if (l1Recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (processedWithdrawals[burnId]) revert WithdrawalAlreadyProcessed(burnId);
        if (totalL2Supply < amount) revert InsufficientL2Supply(totalL2Supply, amount);

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        if (address(this).balance < payout) revert InsufficientContractBalance(address(this).balance, payout);

        // Effects
        processedWithdrawals[burnId] = true;
        totalL2Supply -= amount;
        collectedFees += fee;

        // Interactions
        (bool ok, ) = l1Recipient.call{value: payout}("");
        if (!ok) revert EthTransferFailed();

        emit Withdrawal(l1Recipient, payout, fee);
    }

    // ---------------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------------

    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Update the Layer-2 bridge address.
     */
    function setL2Bridge(address newL2Bridge) external onlyOperator {
        if (newL2Bridge == address(0)) revert ZeroAddress();
        address previous = l2Bridge;
        l2Bridge = newL2Bridge;
        emit L2BridgeUpdated(previous, newL2Bridge);
    }

    /**
     * @notice Transfer operator role to a new address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    /**
     * @notice Withdraw accrued withdrawal fees to the operator.
     */
    function withdrawFees() external onlyOperator {
        uint256 amount = collectedFees;
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientContractBalance(address(this).balance, amount);

        // Effects
        collectedFees = 0;

        // Interactions
        (bool ok, ) = operator.call{value: amount}("");
        if (!ok) revert EthTransferFailed();

        emit FeesWithdrawn(operator, amount);
    }

    // ---------------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------------

    /**
     * @notice Returns the native token balance held by the contract.
     */
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns the total pending deposits across all users.
     */
    function totalPendingDeposits() external view returns (uint256) {
        uint256 locked = totalL2Supply + collectedFees;
        if (address(this).balance < locked) return 0;
        return address(this).balance - locked;
    }

    // ---------------------------------------------------------------------------
    // Receive
    // ---------------------------------------------------------------------------

    /**
     * @dev Reject direct Ether transfers; users must call `deposit` with an
     *      L2 recipient address.
     */
    receive() external payable {
        revert("L1WrappedTokenBridge: use deposit() with an L2 recipient");
    }
}
