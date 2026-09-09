// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LastContributorGame
/// @notice A native-currency prize-pool game where each valid contribution extends
///         the round timer; when the timer expires, the last contributor may claim
///         a portion of the accumulated pot.
contract LastContributorGame {
    // ============ Constants ============
    uint256 public constant MINIMUM_CONTRIBUTION_DEFAULT = 0.01 ether;
    uint256 public constant EXTENSION_DURATION_DEFAULT = 10 minutes;
    uint256 public constant WINNER_SHARE_BPS = 9_000; // 90 %
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // ============ State ============
    address public operator;
    uint256 public minimumContribution;
    uint256 public extensionDuration;

    uint256 public currentRound;
    uint256 public totalPot;
    address public lastContributor;
    uint256 public roundStart;
    uint256 public roundEnd;
    bool public roundActive; // true once the first contribution of a round sets the timer
    uint256 public operatorFees;

    bool private locked;

    // ============ Events ============
    event NewRound(uint256 indexed roundNumber, uint256 startTimestamp, uint256 endTimestamp, bool active);
    event Contributed(
        address indexed contributor,
        uint256 amount,
        uint256 indexed roundNumber,
        uint256 newPot,
        uint256 newRoundEnd
    );
    event WinnerPaid(
        address indexed winner,
        uint256 prizeAmount,
        uint256 feeCollected,
        uint256 indexed roundNumber
    );
    event MinimumContributionChanged(uint256 oldValue, uint256 newValue);
    event ExtensionDurationChanged(uint256 oldValue, uint256 newValue);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OperatorFeesWithdrawn(address indexed operator, uint256 amount);

    // ============ Custom Errors ============
    error NotOperator();
    error ContributionTooLow();
    error RoundNotOver();
    error NotLastContributor();
    error NoPot();
    error NoFees();
    error InvalidParameter();
    error TransferFailed();
    error ReentrantCall();

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    // ============ Constructor ============
    constructor(address _operator) {
        if (_operator == address(0)) revert InvalidParameter();
        operator = _operator;
        minimumContribution = MINIMUM_CONTRIBUTION_DEFAULT;
        extensionDuration = EXTENSION_DURATION_DEFAULT;
        currentRound = 1;
        roundStart = block.timestamp;
        roundEnd = 0;
        roundActive = false; // no active timer until the first contribution
        emit NewRound(currentRound, roundStart, roundEnd, roundActive);
    }

    // ============ Receive ============
    /// @dev Direct native transfers are treated as contributions.
    receive() external payable {
        contribute();
    }

    // ============ Core Game ============

    /// @notice Contribute native currency to the pot and extend the round timer.
    function contribute() public payable nonReentrant {
        if (msg.value < minimumContribution) revert ContributionTooLow();
        // If a timer is active and has already expired, the round must be claimed
        // before any further contributions are accepted.
        if (roundActive && block.timestamp >= roundEnd) revert RoundNotOver();

        totalPot += msg.value;
        lastContributor = msg.sender;
        roundActive = true;
        roundEnd = block.timestamp + extensionDuration;

        emit Contributed(msg.sender, msg.value, currentRound, totalPot, roundEnd);
    }

    /// @notice Claim the winner's portion of the pot after the round timer expires.
    function claimPrize() external nonReentrant {
        if (!roundActive || block.timestamp < roundEnd) revert RoundNotOver();
        if (msg.sender != lastContributor) revert NotLastContributor();
        if (totalPot == 0) revert NoPot();

        address winner = lastContributor;
        uint256 pot = totalPot;
        uint256 winnerAmount = (pot * WINNER_SHARE_BPS) / BPS_DENOMINATOR;
        uint256 fee = pot - winnerAmount;
        uint256 finishedRound = currentRound;

        // effects
        totalPot = 0;
        lastContributor = address(0);
        roundEnd = 0;
        roundActive = false;
        operatorFees += fee;
        currentRound += 1;
        roundStart = block.timestamp;

        emit WinnerPaid(winner, winnerAmount, fee, finishedRound);
        emit NewRound(currentRound, roundStart, roundEnd, roundActive);

        // interaction
        (bool success, ) = payable(winner).call{value: winnerAmount}("");
        if (!success) revert TransferFailed();
    }

    // ============ Operator Administration ============

    /// @notice Set the minimum contribution required for a valid contribution.
    function setMinimumContribution(uint256 _newMinimum) external onlyOperator {
        if (_newMinimum == 0) revert InvalidParameter();
        emit MinimumContributionChanged(minimumContribution, _newMinimum);
        minimumContribution = _newMinimum;
    }

    /// @notice Set the duration added to the round timer on each contribution.
    function setExtensionDuration(uint256 _newDuration) external onlyOperator {
        if (_newDuration == 0) revert InvalidParameter();
        emit ExtensionDurationChanged(extensionDuration, _newDuration);
        extensionDuration = _newDuration;
    }

    /// @notice Withdraw accumulated operator fees (the non-winner portion of past pots).
    function withdrawOperatorFees() external onlyOperator nonReentrant {
        uint256 amount = operatorFees;
        if (amount == 0) revert NoFees();
        operatorFees = 0;
        (bool success, ) = payable(operator).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit OperatorFeesWithdrawn(operator, amount);
    }

    /// @notice Transfer the operator role to a new address.
    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert InvalidParameter();
        emit OperatorChanged(operator, _newOperator);
        operator = _newOperator;
    }

    // ============ Views ============

    /// @dev Remaining seconds on the current round timer; 0 if expired or inactive.
    function timeRemaining() external view returns (uint256) {
        if (!roundActive || block.timestamp >= roundEnd) return 0;
        return roundEnd - block.timestamp;
    }

    /// @dev Whether `account` is eligible to call `claimPrize` right now.
    function canClaim(address account) external view returns (bool) {
        return
            roundActive &&
            block.timestamp >= roundEnd &&
            lastContributor != address(0) &&
            account == lastContributor;
    }
}
