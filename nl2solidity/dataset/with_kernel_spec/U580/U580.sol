// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MoneyMarketFundToken
 * @notice Tokenizes shares of an institutional money market fund. The underlying
 *         fund shares are custodied off-chain; this contract represents on-chain
 *         claims that can be minted against fiat deposits and redeemed for fiat.
 *         Transfers are restricted to authorized participants, redemptions are
 *         subject to a 24-hour waiting period, and aggregate daily redemptions
 *         are capped at a configurable limit not exceeding 1,000,000 units.
 */
contract MoneyMarketFundToken {
    //-------------------------------------------------------------------------
    // Metadata
    //-------------------------------------------------------------------------
    string public constant name = "Institutional Money Market Fund Share";
    string public constant symbol = "IMMFS";
    uint8 public constant decimals = 6; // fiat-precision

    //-------------------------------------------------------------------------
    // ERC-20 state
    //-------------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    //-------------------------------------------------------------------------
    // Access control & operational state
    //-------------------------------------------------------------------------
    address public operator;
    bool public paused;

    mapping(address => bool) public isAuthorizedParticipant;

    uint256 public dailyRedemptionLimit;
    uint256 public constant MAX_DAILY_REDEMPTION = 1_000_000 * 10 ** decimals;

    //-------------------------------------------------------------------------
    // Redemption requests
    //-------------------------------------------------------------------------
    struct RedemptionRequest {
        uint256 amount;
        uint256 requestedAt;
        bool active;
    }
    mapping(address => RedemptionRequest) public redemptionRequests;

    uint256 public constant REDEMPTION_WAIT = 24 hours;

    // Rolling 24-hour redemption window accounting
    uint256 public redemptionWindowStart;
    uint256 public redeemedInWindow;

    //-------------------------------------------------------------------------
    // Events
    //-------------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Minted(address indexed to, uint256 tokenAmount, uint256 fiatAmount);
    event RedemptionRequested(address indexed requester, uint256 amount, uint256 requestTime);
    event RedemptionProcessed(address indexed requester, uint256 tokenAmount, uint256 fiatAmount);
    event RedemptionCancelled(address indexed requester, uint256 amount);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event DailyLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event ParticipantAuthorized(address indexed participant);
    event ParticipantRevoked(address indexed participant);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    //-------------------------------------------------------------------------
    // Custom errors
    //-------------------------------------------------------------------------
    error NotOperator();
    error NotParticipant();
    error EnforcedPause();
    error ExpectedPause();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DailyLimitExceeded();
    error LimitTooHigh();
    error PendingRedemption();
    error NoActiveRedemption();
    error RedemptionNotReady();
    error ZeroAmount();

    //-------------------------------------------------------------------------
    // Modifiers
    //-------------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
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

    modifier onlyParticipant() {
        if (!isAuthorizedParticipant[msg.sender]) revert NotParticipant();
        _;
    }

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    constructor(address _operator, uint256 _dailyRedemptionLimit) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_dailyRedemptionLimit > MAX_DAILY_REDEMPTION) revert LimitTooHigh();

        operator = _operator;
        dailyRedemptionLimit = _dailyRedemptionLimit;
        redemptionWindowStart = block.timestamp;

        emit OperatorChanged(address(0), _operator);
        emit DailyLimitUpdated(0, _dailyRedemptionLimit);
    }

    //-------------------------------------------------------------------------
    // ERC-20 core
    //-------------------------------------------------------------------------
    function transfer(address to, uint256 value) external whenNotPaused onlyParticipant returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (!isAuthorizedParticipant[to]) revert NotParticipant();
        if (balanceOf[msg.sender] < value) revert InsufficientBalance();

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external whenNotPaused returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (!isAuthorizedParticipant[from] || !isAuthorizedParticipant[to]) revert NotParticipant();
        if (balanceOf[from] < value) revert InsufficientBalance();
        if (allowance[from][msg.sender] < value) revert InsufficientAllowance();

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 current = allowance[msg.sender][spender];
        if (current < subtractedValue) revert InsufficientAllowance();
        uint256 newAllowance = current - subtractedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    //-------------------------------------------------------------------------
    // Minting against fiat deposit (operator-only)
    //-------------------------------------------------------------------------
    /**
     * @notice Mints tokens to an authorized participant upon receipt of fiat.
     *         The operator is responsible for confirming off-chain fiat settlement.
     *         Tokens are minted 1:1 with fiat units (both at 6 decimals).
     */
    function depositFiat(address to, uint256 fiatAmount) external onlyOperator whenNotPaused returns (uint256) {
        if (to == address(0)) revert ZeroAddress();
        if (!isAuthorizedParticipant[to]) revert NotParticipant();
        if (fiatAmount == 0) revert ZeroAmount();

        uint256 tokenAmount = fiatAmount; // 1:1
        totalSupply += tokenAmount;
        balanceOf[to] += tokenAmount;

        emit Minted(to, tokenAmount, fiatAmount);
        emit Transfer(address(0), to, tokenAmount);
        return tokenAmount;
    }

    //-------------------------------------------------------------------------
    // Redemption flow
    //-------------------------------------------------------------------------
    /**
     * @notice Requests redemption of `amount` tokens. Tokens are locked and a
     *         24-hour waiting period begins. The request can be processed by
     *         anyone once the waiting period has elapsed.
     */
    function requestRedemption(uint256 amount) external onlyParticipant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        RedemptionRequest storage r = redemptionRequests[msg.sender];
        if (r.active) revert PendingRedemption();

        // Lock the tokens by removing them from the caller's balance.
        balanceOf[msg.sender] -= amount;
        r.amount = amount;
        r.requestedAt = block.timestamp;
        r.active = true;

        emit RedemptionRequested(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Processes a matured redemption request, burning the locked tokens
     *         and recording the fiat obligation. Subject to the daily cap.
     */
    function processRedemption(address participant) external whenNotPaused {
        RedemptionRequest storage r = redemptionRequests[participant];
        if (!r.active) revert NoActiveRedemption();
        if (block.timestamp < r.requestedAt + REDEMPTION_WAIT) revert RedemptionNotReady();

        _refreshRedemptionWindow();

        uint256 amount = r.amount;
        if (redeemedInWindow + amount > dailyRedemptionLimit) revert DailyLimitExceeded();

        redeemedInWindow += amount;

        // Clear the request before external effects.
        r.active = false;
        r.amount = 0;
        r.requestedAt = 0;

        totalSupply -= amount;

        emit RedemptionProcessed(participant, amount, amount);
        emit Transfer(participant, address(0), amount);
    }

    /**
     * @notice Cancels the caller's pending redemption request and returns the
     *         locked tokens. Available even while paused so participants can
     *         recover locked funds.
     */
    function cancelRedemption() external onlyParticipant {
        RedemptionRequest storage r = redemptionRequests[msg.sender];
        if (!r.active) revert NoActiveRedemption();

        uint256 amount = r.amount;
        r.active = false;
        r.amount = 0;
        r.requestedAt = 0;

        balanceOf[msg.sender] += amount;

        emit RedemptionCancelled(msg.sender, amount);
        emit Transfer(address(0), msg.sender, amount);
    }

    /**
     * @dev Resets the rolling 24-hour redemption window if it has elapsed.
     */
    function _refreshRedemptionWindow() internal {
        if (block.timestamp >= redemptionWindowStart + 24 hours) {
            redemptionWindowStart = block.timestamp;
            redeemedInWindow = 0;
        }
    }

    //-------------------------------------------------------------------------
    // Operator controls
    //-------------------------------------------------------------------------
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setDailyRedemptionLimit(uint256 newLimit) external onlyOperator {
        if (newLimit > MAX_DAILY_REDEMPTION) revert LimitTooHigh();
        emit DailyLimitUpdated(dailyRedemptionLimit, newLimit);
        dailyRedemptionLimit = newLimit;
    }

    function authorizeParticipant(address participant) external onlyOperator {
        if (participant == address(0)) revert ZeroAddress();
        isAuthorizedParticipant[participant] = true;
        emit ParticipantAuthorized(participant);
    }

    function revokeParticipant(address participant) external onlyOperator {
        isAuthorizedParticipant[participant] = false;
        emit ParticipantRevoked(participant);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    //-------------------------------------------------------------------------
    // Views
    //-------------------------------------------------------------------------
    function getRedemptionRequest(address participant)
        external
        view
        returns (uint256 amount, uint256 requestedAt, bool active, uint256 readyAt)
    {
        RedemptionRequest storage r = redemptionRequests[participant];
        return (r.amount, r.requestedAt, r.active, r.requestedAt + REDEMPTION_WAIT);
    }

    function redemptionWindowEndsAt() external view returns (uint256) {
        return redemptionWindowStart + 24 hours;
    }

    function remainingDailyRedemption() external view returns (uint256) {
        if (block.timestamp >= redemptionWindowStart + 24 hours) {
            return dailyRedemptionLimit;
        }
        if (redeemedInWindow >= dailyRedemptionLimit) {
            return 0;
        }
        return dailyRedemptionLimit - redeemedInWindow;
    }
}
