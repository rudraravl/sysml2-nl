// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Minimal inline ERC-20 interface to avoid external dependencies.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @dev Minimal inline SafeERC20 library.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

/**
 * @dev Minimal inline Context contract.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/**
 * @dev Minimal inline Pausable contract.
 */
abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual {
        require(_paused, "Pausable: not paused");
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @dev Minimal inline ReentrancyGuard.
 */
abstract contract ReentrancyGuard is Context {
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
 * @title RecurringEscrow
 * @notice Facilitates scheduled, recurring token transfers by acting as an escrow
 *         for tokens designated for future payments. Each sender may define multiple
 *         independent schedules describing a recipient, per-period amount, frequency
 *         and start time. Tokens are held by the contract until the recipient claims
 *         them or the sender cancels the schedule.
 */
contract RecurringEscrow is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant SETUP_FEE = 0.05 ether;
    uint256 public constant MAX_ACTIVE_SCHEDULES = 100;
    uint256 public constant BASIS_POINTS = 10000;

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    IERC20 public immutable token;
    address public operator;
    uint256 public feePercentage; // in basis points, applied to recipient claims
    uint256 public totalEscrow;
    uint256 public nextScheduleId;
    uint256 public accumulatedFees;

    struct Schedule {
        address sender;
        address recipient;
        uint256 amountPerPeriod;
        uint256 frequency;
        uint256 startTime;
        uint256 deposited;
        uint256 claimed;
        bool active;
        bool exists;
    }

    mapping(uint256 => Schedule) public schedules;
    mapping(address => uint256) public activeScheduleCount;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event ScheduleCreated(
        uint256 indexed scheduleId,
        address indexed sender,
        address indexed recipient,
        uint256 amountPerPeriod,
        uint256 frequency,
        uint256 startTime
    );
    event Deposited(uint256 indexed scheduleId, address indexed sender, uint256 amount);
    event PaymentExecuted(
        uint256 indexed scheduleId,
        address indexed recipient,
        uint256 grossAmount,
        uint256 fee,
        uint256 netAmount
    );
    event UnclaimedWithdrawn(uint256 indexed scheduleId, address indexed sender, uint256 amount);
    event ScheduleCancelled(uint256 indexed scheduleId, address indexed sender, uint256 refundedAmount);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error ScheduleNotFound();
    error ScheduleNotActive();
    error MaxSchedulesReached();
    error NotAuthorized();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidFrequency();
    error InvalidStartTime();
    error NothingToWithdraw();
    error IncorrectFee();
    error FeeTooHigh();
    error EthTransferFailed();

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOperator() {
        if (_msgSender() != operator) revert NotAuthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param _token The ERC-20 token used for escrowed payments.
     * @param _operator The operator who can pause and adjust fees.
     * @param _feePercentage Fee (in basis points) applied to recipient claims.
     */
    constructor(address _token, address _operator, uint256 _feePercentage) {
        if (_token == address(0)) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();
        if (_feePercentage > BASIS_POINTS) revert FeeTooHigh();
        token = IERC20(_token);
        operator = _operator;
        feePercentage = _feePercentage;
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /**
     * @notice Creates a new recurring payment schedule. A flat 0.05 ETH setup fee
     *         is forwarded to the operator.
     * @param recipient Recipient of the recurring payments.
     * @param amountPerPeriod Tokens unlocked for the recipient each period.
     * @param frequency Seconds between two consecutive payment unlocks.
     * @param startTime Timestamp at which the first period begins.
     * @return scheduleId The id of the newly created schedule.
     */
    function createSchedule(
        address recipient,
        uint256 amountPerPeriod,
        uint256 frequency,
        uint256 startTime
    ) external payable whenNotPaused returns (uint256) {
        if (msg.value != SETUP_FEE) revert IncorrectFee();
        if (recipient == address(0)) revert InvalidAddress();
        if (amountPerPeriod == 0) revert InvalidAmount();
        if (frequency == 0) revert InvalidFrequency();
        if (startTime <= block.timestamp) revert InvalidStartTime();
        if (activeScheduleCount[_msgSender()] >= MAX_ACTIVE_SCHEDULES) revert MaxSchedulesReached();

        uint256 scheduleId = nextScheduleId++;
        schedules[scheduleId] = Schedule({
            sender: _msgSender(),
            recipient: recipient,
            amountPerPeriod: amountPerPeriod,
            frequency: frequency,
            startTime: startTime,
            deposited: 0,
            claimed: 0,
            active: true,
            exists: true
        });
        activeScheduleCount[_msgSender()] += 1;

        emit ScheduleCreated(scheduleId, _msgSender(), recipient, amountPerPeriod, frequency, startTime);

        (bool success, ) = payable(operator).call{value: SETUP_FEE}("");
        if (!success) revert EthTransferFailed();

        return scheduleId;
    }

    /**
     * @notice Deposits tokens into an existing schedule. Caller must be the schedule sender.
     * @param scheduleId Id of the schedule to fund.
     * @param amount Number of tokens to deposit.
     */
    function deposit(uint256 scheduleId, uint256 amount) external whenNotPaused nonReentrant {
        Schedule storage s = schedules[scheduleId];
        if (!s.exists) revert ScheduleNotFound();
        if (!s.active) revert ScheduleNotActive();
        if (s.sender != _msgSender()) revert NotAuthorized();
        if (amount == 0) revert InvalidAmount();

        s.deposited += amount;
        totalEscrow += amount;

        token.safeTransferFrom(_msgSender(), address(this), amount);

        emit Deposited(scheduleId, _msgSender(), amount);
    }

    /**
     * @notice Recipient claims the tokens that have accrued up to the current block.
     * @param scheduleId Id of the schedule to claim from.
     */
    function claim(uint256 scheduleId) external whenNotPaused nonReentrant {
        Schedule storage s = schedules[scheduleId];
        if (!s.exists) revert ScheduleNotFound();
        if (!s.active) revert ScheduleNotActive();
        if (s.recipient != _msgSender()) revert NotAuthorized();

        uint256 available = _availableAmount(s);
        if (available < 1) revert NothingToWithdraw();

        uint256 fee = (available * feePercentage) / BASIS_POINTS;
        uint256 payout = available - fee;

        s.claimed += available;
        totalEscrow -= available;
        accumulatedFees += fee;

        if (payout > 0) {
            token.safeTransfer(s.recipient, payout);
        }
        if (fee > 0) {
            token.safeTransfer(operator, fee);
        }

        emit PaymentExecuted(scheduleId, s.recipient, available, fee, payout);
    }

    /**
     * @notice Sender withdraws tokens from a schedule that the recipient has not yet claimed.
     *         Only unvested tokens (those not yet due) can be withdrawn by the sender.
     * @param scheduleId Id of the schedule to withdraw from.
     */
    function withdrawUnclaimed(uint256 scheduleId) external whenNotPaused nonReentrant {
        Schedule storage s = schedules[scheduleId];
        if (!s.exists) revert ScheduleNotFound();
        if (!s.active) revert ScheduleNotActive();
        if (s.sender != _msgSender()) revert NotAuthorized();

        uint256 claimable = _availableAmount(s);
        uint256 remaining = s.deposited - s.claimed;
        uint256 unclaimed = remaining > claimable ? remaining - claimable : 0;

        if (unclaimed < 1) revert NothingToWithdraw();

        s.deposited -= unclaimed;
        totalEscrow -= unclaimed;

        token.safeTransfer(s.sender, unclaimed);

        emit UnclaimedWithdrawn(scheduleId, s.sender, unclaimed);
    }

    /**
     * @notice Sender cancels an active schedule and reclaims all remaining tokens.
     * @param scheduleId Id of the schedule to cancel.
     */
    function cancel(uint256 scheduleId) external nonReentrant {
        Schedule storage s = schedules[scheduleId];
        if (!s.exists) revert ScheduleNotFound();
        if (!s.active) revert ScheduleNotActive();
        if (s.sender != _msgSender()) revert NotAuthorized();

        uint256 remaining = s.deposited - s.claimed;

        s.active = false;
        activeScheduleCount[s.sender] -= 1;
        totalEscrow -= remaining;

        if (remaining > 0) {
            token.safeTransfer(s.sender, remaining);
        }

        emit ScheduleCancelled(scheduleId, s.sender, remaining);
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------

    /**
     * @notice Computes the amount of tokens currently claimable by the recipient.
     */
    function availableAmount(uint256 scheduleId) external view returns (uint256) {
        Schedule storage s = schedules[scheduleId];
        if (!s.exists) return 0;
        return _availableAmount(s);
    }

    /**
     * @notice Returns the schedule struct for inspection.
     */
    function getSchedule(uint256 scheduleId) external view returns (Schedule memory) {
        return schedules[scheduleId];
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /**
     * @dev Computes the claimable amount by multiplying before dividing to avoid
     *      precision loss from divide-before-multiply. The product
     *      `elapsed * s.amountPerPeriod` is bounded by realistic timestamp and
     *      token-amount magnitudes, well within uint256 range.
     */
    function _availableAmount(Schedule storage s) internal view returns (uint256) {
        if (block.timestamp < s.startTime) return 0;
        if (s.deposited <= s.claimed) return 0;

        uint256 elapsed = block.timestamp - s.startTime;
        // Multiply first, then divide to preserve precision.
        uint256 totalClaimable = (elapsed * s.amountPerPeriod) / s.frequency;
        if (totalClaimable > s.deposited) totalClaimable = s.deposited;
        if (totalClaimable <= s.claimed) return 0;
        return totalClaimable - s.claimed;
    }

    // -------------------------------------------------------------------------
    // Operator Functions
    // -------------------------------------------------------------------------

    /**
     * @notice Pauses all creating, depositing, claiming and withdrawing operations.
     */
    function pause() external onlyOperator {
        _pause();
    }

    /**
     * @notice Resumes normal operation after a pause.
     */
    function unpause() external onlyOperator {
        _unpause();
    }

    /**
     * @notice Updates the fee percentage applied to recipient claims.
     * @param _feePercentage New fee in basis points (0 - 10000).
     */
    function setFeePercentage(uint256 _feePercentage) external onlyOperator {
        if (_feePercentage > BASIS_POINTS) revert FeeTooHigh();
        uint256 old = feePercentage;
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(old, _feePercentage);
    }

    /**
     * @notice Updates the operator address.
     * @param _operator New operator address.
     */
    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert InvalidAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    /**
     * @notice Allows the operator to withdraw accumulated token fees.
     */
    function withdrawFees() external onlyOperator nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount < 1) revert InvalidAmount();
        accumulatedFees = 0;
        token.safeTransfer(operator, amount);
        emit FeesWithdrawn(operator, amount);
    }

    /**
     * @dev Accepts plain ETH transfers so the contract can receive setup fees
     *      and accidental sends. Not used for escrow logic.
     */
    receive() external payable {}
}
