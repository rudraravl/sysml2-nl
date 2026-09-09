// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PredictionMarket
 * @notice Peer-to-peer prediction market contract. Users create events with a
 *         set of possible outcomes, place bets on those outcomes while the
 *         event is open, cancel their own open bets, and claim winnings once
 *         a designated operator resolves the event. A 1% fee is withheld from
 *         every winning payout and accrues to a configurable fee recipient.
 */
contract PredictionMarket {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    enum Status {
        Open,
        Closed,
        Resolved
    }

    struct EventData {
        address creator;
        string description;
        uint256 numOutcomes;
        uint256 totalStaked;
        Status status;
        uint256 winningOutcome;
        uint256 totalPayout;
        uint256 createdAt;
        bool exists;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_BET = 0.01 ether;
    uint256 public constant FEE_BPS = 100; // 1% = 100 / 10000
    uint256 public constant BPS_DENOM = 10000;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public operator;
    address public feeRecipient;
    uint256 public accumulatedFees;
    uint256 public eventCount;

    mapping(uint256 => EventData) internal _events;
    mapping(uint256 => mapping(uint256 => uint256)) public totalStakedOnOutcome;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userStake;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event EventCreated(uint256 indexed eventId, address indexed creator, string description, uint256 numOutcomes);
    event BetPlaced(uint256 indexed eventId, address indexed bettor, uint256 outcome, uint256 amount);
    event BetCancelled(uint256 indexed eventId, address indexed bettor, uint256 outcome, uint256 amount);
    event EventClosed(uint256 indexed eventId);
    event EventResolved(uint256 indexed eventId, uint256 winningOutcome, uint256 totalPayout);
    event WinningsClaimed(uint256 indexed eventId, address indexed claimer, uint256 amount);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error NotAuthorized();
    error EventNotFound();
    error InvalidStatus();
    error InvalidOutcome();
    error InvalidOutcomeCount();
    error InsufficientBet();
    error NoStake();
    error EmptyPool();
    error AlreadyClaimed();
    error NothingClaimable();
    error ZeroAddress();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier eventExists(uint256 eventId) {
        if (!_events[eventId].exists) revert EventNotFound();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        operator = msg.sender;
        feeRecipient = _feeRecipient;
        emit OperatorChanged(address(0), msg.sender);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getEvent(uint256 eventId)
        external
        view
        eventExists(eventId)
        returns (
            address creator,
            string memory description,
            uint256 numOutcomes,
            uint256 totalStaked,
            Status status,
            uint256 winningOutcome,
            uint256 totalPayout,
            uint256 createdAt
        )
    {
        EventData storage e = _events[eventId];
        return (
            e.creator,
            e.description,
            e.numOutcomes,
            e.totalStaked,
            e.status,
            e.winningOutcome,
            e.totalPayout,
            e.createdAt
        );
    }

    function previewWinnings(uint256 eventId, address account)
        external
        view
        eventExists(eventId)
        returns (uint256)
    {
        EventData storage e = _events[eventId];
        if (e.status != Status.Resolved) return 0;
        if (hasClaimed[eventId][account]) return 0;
        uint256 stake = userStake[eventId][account][e.winningOutcome];
        if (stake == 0) return 0;
        uint256 winningPool = totalStakedOnOutcome[eventId][e.winningOutcome];
        if (winningPool == 0) return 0;
        return (e.totalPayout * stake) / winningPool;
    }

    /*//////////////////////////////////////////////////////////////
                          EVENT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function createEvent(string calldata description, uint256 numOutcomes) external returns (uint256) {
        if (numOutcomes < 2) revert InvalidOutcomeCount();
        uint256 eventId = eventCount++;
        EventData storage e = _events[eventId];
        e.creator = msg.sender;
        e.description = description;
        e.numOutcomes = numOutcomes;
        e.status = Status.Open;
        e.winningOutcome = type(uint256).max;
        e.createdAt = block.timestamp;
        e.exists = true;
        emit EventCreated(eventId, msg.sender, description, numOutcomes);
        return eventId;
    }

    function closeEvent(uint256 eventId) external onlyOperator eventExists(eventId) {
        EventData storage e = _events[eventId];
        if (e.status != Status.Open) revert InvalidStatus();
        e.status = Status.Closed;
        emit EventClosed(eventId);
    }

    function resolveEvent(uint256 eventId, uint256 winningOutcome)
        external
        onlyOperator
        eventExists(eventId)
    {
        EventData storage e = _events[eventId];
        if (e.status != Status.Closed) revert InvalidStatus();
        if (winningOutcome >= e.numOutcomes) revert InvalidOutcome();

        uint256 winningPool = totalStakedOnOutcome[eventId][winningOutcome];
        if (winningPool == 0) revert EmptyPool();

        e.winningOutcome = winningOutcome;
        e.status = Status.Resolved;

        uint256 fee = (e.totalStaked * FEE_BPS) / BPS_DENOM;
        uint256 totalPayout = e.totalStaked - fee;
        e.totalPayout = totalPayout;
        accumulatedFees += fee;

        emit EventResolved(eventId, winningOutcome, totalPayout);
    }

    /*//////////////////////////////////////////////////////////////
                              BETTING
    //////////////////////////////////////////////////////////////*/

    function placeBet(uint256 eventId, uint256 outcome) external payable eventExists(eventId) {
        EventData storage e = _events[eventId];
        if (e.status != Status.Open) revert InvalidStatus();
        if (outcome >= e.numOutcomes) revert InvalidOutcome();
        if (msg.value < MIN_BET) revert InsufficientBet();

        e.totalStaked += msg.value;
        totalStakedOnOutcome[eventId][outcome] += msg.value;
        userStake[eventId][msg.sender][outcome] += msg.value;

        emit BetPlaced(eventId, msg.sender, outcome, msg.value);
    }

    function cancelBet(uint256 eventId, uint256 outcome) external eventExists(eventId) {
        EventData storage e = _events[eventId];
        if (e.status != Status.Open) revert InvalidStatus();
        if (outcome >= e.numOutcomes) revert InvalidOutcome();

        uint256 stake = userStake[eventId][msg.sender][outcome];
        if (stake == 0) revert NoStake();

        userStake[eventId][msg.sender][outcome] = 0;
        e.totalStaked -= stake;
        totalStakedOnOutcome[eventId][outcome] -= stake;

        (bool success, ) = payable(msg.sender).call{value: stake}("");
        if (!success) revert TransferFailed();

        emit BetCancelled(eventId, msg.sender, outcome, stake);
    }

    function claimWinnings(uint256 eventId) external eventExists(eventId) {
        EventData storage e = _events[eventId];
        if (e.status != Status.Resolved) revert InvalidStatus();
        if (hasClaimed[eventId][msg.sender]) revert AlreadyClaimed();

        uint256 stake = userStake[eventId][msg.sender][e.winningOutcome];
        if (stake == 0) revert NothingClaimable();

        uint256 winningPool = totalStakedOnOutcome[eventId][e.winningOutcome];
        if (winningPool == 0) revert NothingClaimable();

        uint256 payout = (e.totalPayout * stake) / winningPool;

        hasClaimed[eventId][msg.sender] = true;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) revert TransferFailed();

        emit WinningsClaimed(eventId, msg.sender, payout);
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN / FEES
    //////////////////////////////////////////////////////////////*/

    function withdrawFees() external {
        if (msg.sender != operator && msg.sender != feeRecipient) revert NotAuthorized();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingClaimable();
        accumulatedFees = 0;
        (bool success, ) = payable(feeRecipient).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FeesWithdrawn(feeRecipient, amount);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }
}
