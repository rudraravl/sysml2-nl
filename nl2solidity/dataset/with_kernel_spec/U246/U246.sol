// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title L1L2Bridge
 * @notice A bridge for transferring Ether between a Layer-1 network and a Layer-2 rollup.
 *         Deposits are held in escrow pending transfer to L2. Withdrawals initiated on L2
 *         are relayed to L1 by a designated operator and become claimable after a waiting period.
 */
abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

abstract contract Pausable {
    bool public paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    function _pause() internal whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract L1L2Bridge is Ownable, Pausable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_DEPOSIT = 0.001 ether;
    uint256 public constant WITHDRAWAL_FEE = 0.0005 ether;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Designated operator responsible for relaying L2 withdrawals and pausing.
    address public operator;

    /// @notice Address of the corresponding L2 bridge contract.
    address public l2Bridge;

    /// @notice Address that receives collected withdrawal fees.
    address public feeRecipient;

    /// @notice Waiting period (in seconds) before a withdrawal can be claimed.
    uint256 public immutable claimWaitingPeriod;

    /// @notice Whether deposits are paused independently.
    bool public depositsPaused;

    /// @notice Whether withdrawals are paused independently.
    bool public withdrawalsPaused;

    /// @notice Total Ether held in escrow awaiting transfer to L2.
    uint256 public totalEscrow;

    /// @notice Total accumulated withdrawal fees.
    uint256 public totalFees;

    /// @notice Amount of Ether deposited by each user awaiting transfer to L2.
    mapping(address => uint256) public pendingDeposits;

    struct PendingWithdrawal {
        address recipient;       // L1 recipient of the withdrawn Ether
        uint256 amount;          // Net amount claimable after fee
        uint256 claimableAt;     // Timestamp when withdrawal becomes claimable
        bool claimed;            // Whether the withdrawal has been claimed
        bool exists;             // Whether an entry exists
    }

    /// @notice Pending withdrawals keyed by a unique withdrawal id.
    mapping(uint256 => PendingWithdrawal) public pendingWithdrawals;

    /// @notice Maps a user to the list of withdrawal ids initiated for them.
    mapping(address => uint256[]) internal _userWithdrawalIds;

    /// @notice Counter for generating unique withdrawal ids.
    uint256 public nextWithdrawalId;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(address indexed user, uint256 amount, uint256 newEscrowTotal);
    event WithdrawalInitiated(
        uint256 indexed withdrawalId,
        address indexed to,
        uint256 grossAmount,
        uint256 fee,
        uint256 netAmount,
        uint256 claimableAt
    );
    event WithdrawalClaimed(uint256 indexed withdrawalId, address indexed to, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event L2BridgeUpgraded(address indexed previousL2Bridge, address indexed newL2Bridge);
    event FeeRecipientUpdated(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event DepositsPaused();
    event DepositsUnpaused();
    event WithdrawalsPaused();
    event WithdrawalsUnpaused();

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error L1L2Bridge__DepositBelowMinimum();
    error L1L2Bridge__DepositsPaused();
    error L1L2Bridge__WithdrawalsPaused();
    error L1L2Bridge__Unauthorized();
    error L1L2Bridge__ZeroAddress();
    error L1L2Bridge__InsufficientEscrow();
    error L1L2Bridge__WithdrawalNotFound();
    error L1L2Bridge__WithdrawalAlreadyClaimed();
    error L1L2Bridge__ClaimNotYetAvailable();
    error L1L2Bridge__NotWithdrawalRecipient();
    error L1L2Bridge__TransferFailed();
    error L1L2Bridge__NoFeesToWithdraw();
    error L1L2Bridge__AmountTooSmall();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert L1L2Bridge__Unauthorized();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert L1L2Bridge__DepositsPaused();
        _;
    }

    modifier whenWithdrawalsNotPaused() {
        if (withdrawalsPaused) revert L1L2Bridge__WithdrawalsPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _operator,
        address _l2Bridge,
        address _feeRecipient,
        uint256 _claimWaitingPeriod
    ) Ownable(msg.sender) {
        if (_operator == address(0)) revert L1L2Bridge__ZeroAddress();
        if (_l2Bridge == address(0)) revert L1L2Bridge__ZeroAddress();
        if (_feeRecipient == address(0)) revert L1L2Bridge__ZeroAddress();

        operator = _operator;
        l2Bridge = _l2Bridge;
        feeRecipient = _feeRecipient;
        claimWaitingPeriod = _claimWaitingPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits Ether on L1 for transfer to L2. The deposited amount is held in escrow
     *         until the L2 minting is confirmed off-chain.
     * @dev Emits a {Deposited} event for off-chain relayers to mint on L2.
     */
    function deposit() external payable nonReentrant whenDepositsNotPaused whenNotPaused {
        if (msg.value < MIN_DEPOSIT) revert L1L2Bridge__DepositBelowMinimum();

        pendingDeposits[msg.sender] += msg.value;
        totalEscrow += msg.value;

        emit Deposited(msg.sender, msg.value, totalEscrow);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a withdrawal from L2 back to L1. Called by the operator after verifying
     *         the corresponding L2 withdrawal. A fixed fee is deducted and the net amount is
     *         recorded as claimable after the waiting period.
     * @param to The L1 recipient of the withdrawn Ether.
     * @param grossAmount The gross withdrawal amount (before fee).
     * @return withdrawalId The id of the created pending withdrawal.
     */
    function initiateWithdrawal(address to, uint256 grossAmount)
        external
        onlyOperator
        nonReentrant
        whenWithdrawalsNotPaused
        whenNotPaused
        returns (uint256 withdrawalId)
    {
        if (to == address(0)) revert L1L2Bridge__ZeroAddress();
        if (grossAmount < WITHDRAWAL_FEE) revert L1L2Bridge__AmountTooSmall();

        uint256 fee = WITHDRAWAL_FEE;
        uint256 netAmount = grossAmount - fee;

        if (address(this).balance - totalFees < netAmount) {
            revert L1L2Bridge__InsufficientEscrow();
        }

        withdrawalId = nextWithdrawalId++;
        uint256 claimableAt = block.timestamp + claimWaitingPeriod;

        pendingWithdrawals[withdrawalId] = PendingWithdrawal({
            recipient: to,
            amount: netAmount,
            claimableAt: claimableAt,
            claimed: false,
            exists: true
        });

        _userWithdrawalIds[to].push(withdrawalId);

        totalFees += fee;

        emit WithdrawalInitiated(withdrawalId, to, grossAmount, fee, netAmount, claimableAt);
    }

    /**
     * @notice Claims a pending withdrawal after the waiting period has elapsed.
     * @param withdrawalId The id of the withdrawal to claim.
     */
    function claimWithdrawal(uint256 withdrawalId) external nonReentrant {
        PendingWithdrawal storage w = pendingWithdrawals[withdrawalId];

        if (!w.exists) revert L1L2Bridge__WithdrawalNotFound();
        if (w.claimed) revert L1L2Bridge__WithdrawalAlreadyClaimed();
        if (block.timestamp < w.claimableAt) revert L1L2Bridge__ClaimNotYetAvailable();
        if (w.recipient != msg.sender) revert L1L2Bridge__NotWithdrawalRecipient();

        // Effects
        w.claimed = true;
        uint256 amount = w.amount;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert L1L2Bridge__TransferFailed();

        emit WithdrawalClaimed(withdrawalId, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR / ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses deposits. Only callable by the operator.
     */
    function pauseDeposits() external onlyOperator {
        if (depositsPaused) revert L1L2Bridge__DepositsPaused();
        depositsPaused = true;
        emit DepositsPaused();
    }

    /**
     * @notice Unpauses deposits. Only callable by the operator.
     */
    function unpauseDeposits() external onlyOperator {
        if (!depositsPaused) revert L1L2Bridge__DepositsPaused();
        depositsPaused = false;
        emit DepositsUnpaused();
    }

    /**
     * @notice Pauses withdrawals. Only callable by the operator.
     */
    function pauseWithdrawals() external onlyOperator {
        if (withdrawalsPaused) revert L1L2Bridge__WithdrawalsPaused();
        withdrawalsPaused = true;
        emit WithdrawalsPaused();
    }

    /**
     * @notice Unpauses withdrawals. Only callable by the operator.
     */
    function unpauseWithdrawals() external onlyOperator {
        if (!withdrawalsPaused) revert L1L2Bridge__WithdrawalsPaused();
        withdrawalsPaused = false;
        emit WithdrawalsUnpaused();
    }

    /**
     * @notice Upgrades the L2 bridge contract address. Only callable by the operator.
     * @param newL2Bridge The address of the new L2 bridge contract.
     */
    function upgradeL2Bridge(address newL2Bridge) external onlyOperator {
        if (newL2Bridge == address(0)) revert L1L2Bridge__ZeroAddress();
        address previous = l2Bridge;
        l2Bridge = newL2Bridge;
        emit L2BridgeUpgraded(previous, newL2Bridge);
    }

    /**
     * @notice Updates the operator address. Only callable by the owner.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert L1L2Bridge__ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    /**
     * @notice Updates the fee recipient. Only callable by the owner.
     * @param newFeeRecipient The address of the new fee recipient.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert L1L2Bridge__ZeroAddress();
        address previous = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(previous, newFeeRecipient);
    }

    /**
     * @notice Withdraws accumulated fees to the fee recipient. Only callable by the fee recipient.
     */
    function withdrawFees() external nonReentrant {
        if (msg.sender != feeRecipient) revert L1L2Bridge__Unauthorized();
        uint256 amount = totalFees;
        if (amount == 0) revert L1L2Bridge__NoFeesToWithdraw();

        // Effects
        totalFees = 0;

        // Interactions
        (bool success, ) = payable(feeRecipient).call{value: amount}("");
        if (!success) revert L1L2Bridge__TransferFailed();

        emit FeesWithdrawn(feeRecipient, amount);
    }

    /**
     * @notice Emergency pause for all operations. Only callable by the owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Emergency unpause for all operations. Only callable by the owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the list of withdrawal ids for a given user.
     */
    function getUserWithdrawalIds(address user) external view returns (uint256[] memory) {
        return _userWithdrawalIds[user];
    }

    /**
     * @notice Returns the pending deposit amount for a given user.
     */
    function getPendingDeposit(address user) external view returns (uint256) {
        return pendingDeposits[user];
    }

    /**
     * @notice Returns the available Ether balance that can be used for withdrawals
     *         (total balance minus accumulated fees).
     */
    function availableForWithdrawals() external view returns (uint256) {
        return address(this).balance - totalFees;
    }

    /**
     * @notice Returns whether a withdrawal is claimable at the current block timestamp.
     */
    function isClaimable(uint256 withdrawalId) external view returns (bool) {
        PendingWithdrawal storage w = pendingWithdrawals[withdrawalId];
        return w.exists && !w.claimed && block.timestamp >= w.claimableAt;
    }

    receive() external payable {
        // Direct sends are disallowed to avoid inflating escrow inconsistently.
        revert L1L2Bridge__Unauthorized();
    }
}
