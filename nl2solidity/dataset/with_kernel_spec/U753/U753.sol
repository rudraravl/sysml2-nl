// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title PredictionMarket
 * @notice A prediction market where users stake ERC-20 tokens on outcomes of real-world events.
 * Only the operator can create events, cancel them, or declare the winning outcome.
 * A 5% fee is deducted from the winning pool before distribution.
 */
contract PredictionMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotOperator();
    error InvalidOutcomesCount(uint256 count);
    error EventNotActive(uint256 eventId);
    error EventNotCancelled(uint256 eventId);
    error EventNotResolved(uint256 eventId);
    error AlreadyStakedDifferentOutcome(uint256 eventId, uint8 currentOutcome, uint8 newOutcome);
    error NoStake(uint256 eventId);
    error AlreadyClaimed(uint256 eventId);
    error NotWinningOutcome(uint256 eventId, uint8 userOutcome, uint8 winningOutcome);
    error NoWinningPool(uint256 eventId);
    error NotFeeRecipient();
    error ZeroAmount();
    error InvalidOutcomeIndex(uint256 eventId, uint8 outcomeIndex);
    error InvalidAddress();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event EventCreated(uint256 indexed eventId, string description, string[] outcomes, address indexed creator);
    event Staked(uint256 indexed eventId, address indexed user, uint8 outcomeIndex, uint256 amount);
    event EventCancelled(uint256 indexed eventId);
    event OutcomeDeclared(uint256 indexed eventId, uint8 winningOutcome);
    event Withdrawn(uint256 indexed eventId, address indexed user, uint256 amount);
    event WinningsClaimed(uint256 indexed eventId, address indexed user, uint256 amount);
    event FeesClaimed(address indexed feeRecipient, uint256 amount);

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------
    IERC20 public immutable token;
    address public immutable operator;
    address public immutable feeRecipient;
    uint256 public constant FEE_PERCENT = 5; // 5% fee on winnings

    uint256 public nextEventId;
    uint256 public accumulatedFees;

    enum Status { Active, Cancelled, Resolved }

    mapping(uint256 => string) public eventDescription;
    mapping(uint256 => string[]) public eventOutcomes;
    mapping(uint256 => Status) public eventStatus;
    mapping(uint256 => uint8) public eventWinningOutcome;
    mapping(uint256 => uint256) public eventTotalWinningPool;
    mapping(uint256 => uint256) public eventWinningPoolAfterFee;

    // outcomeIndex => total staked
    mapping(uint256 => mapping(uint8 => uint256)) public totalStakesPerOutcome;
    // user => total staked in event
    mapping(uint256 => mapping(address => uint256)) public userStake;
    // user => chosen outcome index (0 means not set)
    mapping(uint256 => mapping(address => uint8)) public userOutcome;
    // user => claimed status
    mapping(uint256 => mapping(address => bool)) public claimed;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    /**
     * @param _token The ERC-20 token used for staking and rewards.
     * @param _operator The address allowed to create events, cancel, and declare outcomes.
     * @param _feeRecipient The address that receives accumulated fees.
     */
    constructor(IERC20 _token, address _operator, address _feeRecipient) {
        if (address(_token) == address(0)) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();
        if (_feeRecipient == address(0)) revert InvalidAddress();
        token = _token;
        operator = _operator;
        feeRecipient = _feeRecipient;
    }

    // -----------------------------------------------------------------------
    // External functions
    // -----------------------------------------------------------------------

    /**
     * @notice Creates a new prediction event.
     * @param description A human-readable description of the event.
     * @param outcomes Array of outcome strings (length between 2 and 5).
     * @return eventId The ID of the newly created event.
     */
    function createEvent(
        string calldata description,
        string[] memory outcomes
    ) external onlyOperator returns (uint256 eventId) {
        uint256 len = outcomes.length;
        if (len < 2 || len > 5) revert InvalidOutcomesCount(len);

        eventId = nextEventId++;
        eventDescription[eventId] = description;
        eventOutcomes[eventId] = outcomes;
        eventStatus[eventId] = Status.Active;

        emit EventCreated(eventId, description, outcomes, msg.sender);
    }

    /**
     * @notice Stakes tokens on a specific outcome of an active event.
     * @param eventId The ID of the event.
     * @param outcomeIndex The index of the chosen outcome.
     * @param amount The amount of tokens to stake.
     */
    function stake(uint256 eventId, uint8 outcomeIndex, uint256 amount) external nonReentrant {
        if (eventStatus[eventId] != Status.Active) revert EventNotActive(eventId);
        if (outcomeIndex >= eventOutcomes[eventId].length) revert InvalidOutcomeIndex(eventId, outcomeIndex);
        if (amount == 0) revert ZeroAmount();

        uint8 currentOutcome = userOutcome[eventId][msg.sender];
        if (currentOutcome != 0) {
            // User already staked on an outcome; must be the same one
            if (currentOutcome != outcomeIndex) {
                revert AlreadyStakedDifferentOutcome(eventId, currentOutcome, outcomeIndex);
            }
        } else {
            userOutcome[eventId][msg.sender] = outcomeIndex;
        }

        userStake[eventId][msg.sender] += amount;
        totalStakesPerOutcome[eventId][outcomeIndex] += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(eventId, msg.sender, outcomeIndex, amount);
    }

    /**
     * @notice Cancels an active event, allowing users to withdraw their stakes.
     * @param eventId The ID of the event to cancel.
     */
    function cancelEvent(uint256 eventId) external onlyOperator {
        if (eventStatus[eventId] != Status.Active) revert EventNotActive(eventId);
        eventStatus[eventId] = Status.Cancelled;
        emit EventCancelled(eventId);
    }

    /**
     * @notice Withdraws the caller's stake from a cancelled event.
     * @param eventId The ID of the cancelled event.
     */
    function withdraw(uint256 eventId) external nonReentrant {
        if (eventStatus[eventId] != Status.Cancelled) revert EventNotCancelled(eventId);

        uint256 amount = userStake[eventId][msg.sender];
        if (amount == 0) revert NoStake(eventId);

        uint8 outcome = userOutcome[eventId][msg.sender];
        // Reset user state
        userStake[eventId][msg.sender] = 0;
        totalStakesPerOutcome[eventId][outcome] -= amount;

        token.safeTransfer(msg.sender, amount);
        emit Withdrawn(eventId, msg.sender, amount);
    }

    /**
     * @notice Declares the winning outcome of an active event and calculates fees.
     * @param eventId The ID of the event.
     * @param winningOutcomeIndex The index of the winning outcome.
     */
    function declareOutcome(uint256 eventId, uint8 winningOutcomeIndex) external onlyOperator {
        if (eventStatus[eventId] != Status.Active) revert EventNotActive(eventId);
        if (winningOutcomeIndex >= eventOutcomes[eventId].length)
            revert InvalidOutcomeIndex(eventId, winningOutcomeIndex);

        eventStatus[eventId] = Status.Resolved;
        eventWinningOutcome[eventId] = winningOutcomeIndex;

        uint256 totalWinning = totalStakesPerOutcome[eventId][winningOutcomeIndex];
        eventTotalWinningPool[eventId] = totalWinning;

        if (totalWinning > 0) {
            uint256 fee = (totalWinning * FEE_PERCENT) / 100;
            accumulatedFees += fee;
            eventWinningPoolAfterFee[eventId] = totalWinning - fee;
        } else {
            eventWinningPoolAfterFee[eventId] = 0;
        }

        emit OutcomeDeclared(eventId, winningOutcomeIndex);
    }

    /**
     * @notice Claims winnings for a resolved event if the caller staked on the winning outcome.
     * @param eventId The ID of the resolved event.
     */
    function claimWinnings(uint256 eventId) external nonReentrant {
        if (eventStatus[eventId] != Status.Resolved) revert EventNotResolved(eventId);
        if (claimed[eventId][msg.sender]) revert AlreadyClaimed(eventId);

        uint8 userOutcomeIdx = userOutcome[eventId][msg.sender];
        uint8 winningOutcomeIdx = eventWinningOutcome[eventId];
        if (userOutcomeIdx != winningOutcomeIdx)
            revert NotWinningOutcome(eventId, userOutcomeIdx, winningOutcomeIdx);

        uint256 userStakeAmount = userStake[eventId][msg.sender];
        if (userStakeAmount == 0) revert NoStake(eventId);

        uint256 totalWinningPool = eventTotalWinningPool[eventId];
        if (totalWinningPool == 0) revert NoWinningPool(eventId);

        claimed[eventId][msg.sender] = true;

        uint256 winningPoolAfterFee = eventWinningPoolAfterFee[eventId];
        uint256 reward = (userStakeAmount * winningPoolAfterFee) / totalWinningPool;

        token.safeTransfer(msg.sender, reward);
        emit WinningsClaimed(eventId, msg.sender, reward);
    }

    /**
     * @notice Allows the fee recipient to withdraw accumulated fees.
     */
    function claimFees() external nonReentrant {
        if (msg.sender != feeRecipient) revert NotFeeRecipient();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        token.safeTransfer(feeRecipient, amount);
        emit FeesClaimed(feeRecipient, amount);
    }
}
