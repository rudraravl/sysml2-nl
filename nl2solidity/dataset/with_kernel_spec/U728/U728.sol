// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
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

/**
 * @title StreamingPayment
 * @notice Manages a streaming payment system where deposited tokens are continuously
 *         disbursed to a recipient over a fixed time window. The contract charges a
 *         configurable fee (default 0.1%) on each newly created stream.
 */
contract StreamingPayment is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant MIN_STREAM_DURATION = 1 minutes;
    uint256 public constant MAX_STREAM_DURATION = 5 * 365 days;
    uint256 public constant FEE_PRECISION = 10_000; // 100% = 10_000
    uint256 public constant MAX_FEE_BPS = 1_000; // 10%
    uint256 public constant DEFAULT_FEE_BPS = 10; // 0.1%

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------

    struct Stream {
        address sender;
        address recipient;
        IERC20 token;
        uint256 totalAmount; // net amount after fee, streamed to recipient
        uint256 withdrawnAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }

    // -----------------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------------

    uint256 private _nextStreamId;
    uint256 public feeBps;
    bool public paused;

    mapping(uint256 => Stream) private _streams;
    mapping(address => uint256) public accruedFees;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 totalAmount,
        uint256 fee,
        uint256 startTime,
        uint256 endTime
    );

    event StreamDeposited(
        uint256 indexed streamId,
        address indexed from,
        uint256 amount,
        uint256 newTotalAmount
    );

    event Withdrawn(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );

    event StreamCancelled(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 senderRefund,
        uint256 recipientPayout
    );

    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PausedStateChanged(bool paused);
    event FeesClaimed(address indexed token, address indexed to, uint256 amount);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error DurationOutOfBounds();
    error StartTimeInPast();
    error StopTimeBeforeStartTime();
    error FeeTooHigh();
    error ContractPaused();
    error StreamDoesNotExist();
    error StreamNotActive();
    error CallerNotSender();
    error CallerNotRecipient();
    error NoFundsToWithdraw();
    error WithdrawExceedsAvailable();
    error NoFeesToClaim();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier streamExists(uint256 streamId) {
        if (!_streams[streamId].isActive) revert StreamDoesNotExist();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor() Ownable(msg.sender) {
        feeBps = DEFAULT_FEE_BPS;
        _nextStreamId = 1;
    }

    // -----------------------------------------------------------------------
    // Owner Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Pauses or unpauses stream creation.
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    /**
     * @notice Updates the fee percentage (in basis points) charged on new streams.
     * @param _feeBps New fee in basis points (max 1000 = 10%).
     */
    function setFeeBps(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    /**
     * @notice Allows the owner to claim accumulated fees for a given token.
     */
    function claimFees(address token, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees[token];
        if (amount == 0) revert NoFeesToClaim();
        accruedFees[token] = 0;
        IERC20(token).safeTransfer(to, amount);
        emit FeesClaimed(token, to, amount);
    }

    // -----------------------------------------------------------------------
    // Public / External Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Creates a new stream by pulling tokens from the caller.
     * @param recipient The address that will receive the streamed tokens.
     * @param token The ERC20 token to stream.
     * @param amount The total amount of tokens to deposit (fee is deducted from this).
     * @param startTime The unix timestamp when streaming begins (must be >= now).
     * @param endTime The unix timestamp when streaming ends.
     * @return streamId The ID of the newly created stream.
     */
    function createStream(
        address recipient,
        IERC20 token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    ) external whenNotPaused nonReentrant returns (uint256 streamId) {
        if (recipient == address(0)) revert ZeroAddress();
        if (address(token) == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (startTime < block.timestamp) revert StartTimeInPast();
        if (endTime <= startTime) revert StopTimeBeforeStartTime();

        uint256 duration = endTime - startTime;
        if (duration < MIN_STREAM_DURATION || duration > MAX_STREAM_DURATION) {
            revert DurationOutOfBounds();
        }

        uint256 fee = (amount * feeBps) / FEE_PRECISION;
        uint256 netAmount = amount - fee;

        // Pull the full amount from the sender.
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Accrue the fee for the owner to claim later.
        if (fee > 0) {
            accruedFees[address(token)] += fee;
        }

        streamId = _nextStreamId++;
        _streams[streamId] = Stream({
            sender: msg.sender,
            recipient: recipient,
            token: token,
            totalAmount: netAmount,
            withdrawnAmount: 0,
            startTime: startTime,
            endTime: endTime,
            isActive: true
        });

        emit StreamCreated(
            streamId,
            msg.sender,
            recipient,
            address(token),
            netAmount,
            fee,
            startTime,
            endTime
        );
    }

    /**
     * @notice Deposits additional tokens into an existing active stream.
     *         Only the original sender may top up. The new tokens are added to
     *         the stream's total and extend the end time proportionally so the
     *         streaming rate remains unchanged.
     * @param streamId The ID of the stream to deposit into.
     * @param amount The amount of additional tokens to deposit.
     */
    function depositIntoStream(uint256 streamId, uint256 amount)
        external
        streamExists(streamId)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        Stream storage s = _streams[streamId];
        if (msg.sender != s.sender) revert CallerNotSender();
        if (block.timestamp >= s.endTime) revert StreamNotActive();

        // Effects: compute and update state before the external call.
        uint256 oldDuration = s.endTime - s.startTime;
        uint256 newTotal = s.totalAmount + amount;
        uint256 newDuration = (newTotal * oldDuration) / s.totalAmount;

        s.totalAmount = newTotal;
        s.endTime = s.startTime + newDuration;

        // Interactions: pull tokens after state is updated.
        s.token.safeTransferFrom(msg.sender, address(this), amount);

        emit StreamDeposited(streamId, msg.sender, amount, newTotal);
    }

    /**
     * @notice Withdraws a specified amount of available tokens from a stream.
     *         Only the stream's recipient may call this.
     * @param streamId The ID of the stream to withdraw from.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawFromStream(uint256 streamId, uint256 amount)
        external
        streamExists(streamId)
        nonReentrant
    {
        Stream storage s = _streams[streamId];
        if (msg.sender != s.recipient) revert CallerNotRecipient();
        if (amount == 0) revert ZeroAmount();

        uint256 available = _withdrawableAmount(s);
        if (amount > available) revert WithdrawExceedsAvailable();

        // Effects before interactions.
        s.withdrawnAmount += amount;

        s.token.safeTransfer(s.recipient, amount);

        emit Withdrawn(streamId, s.recipient, amount);
    }

    /**
     * @notice Cancels a stream. The recipient receives all tokens streamed so far
     *         (whether or not previously withdrawn), and the sender receives the
     *         remaining unstreamed balance. Only the stream's sender may call this.
     * @param streamId The ID of the stream to cancel.
     */
    function cancelStream(uint256 streamId)
        external
        streamExists(streamId)
        nonReentrant
    {
        Stream storage s = _streams[streamId];
        if (msg.sender != s.sender) revert CallerNotSender();

        uint256 streamed = _streamedAmount(s);
        uint256 recipientPayout = streamed > s.withdrawnAmount
            ? streamed - s.withdrawnAmount
            : 0;
        uint256 senderRefund = s.totalAmount - streamed;

        // Cache token and addresses before deleting.
        IERC20 token = s.token;
        address recipient = s.recipient;
        address sender = s.sender;

        // Effects: mark stream as inactive and fully withdrawn.
        s.isActive = false;
        s.withdrawnAmount = s.totalAmount;

        // Interactions.
        if (recipientPayout > 0) {
            token.safeTransfer(recipient, recipientPayout);
        }
        if (senderRefund > 0) {
            token.safeTransfer(sender, senderRefund);
        }

        emit StreamCancelled(streamId, sender, recipient, senderRefund, recipientPayout);
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Returns the next stream ID that will be assigned.
     */
    function nextStreamId() external view returns (uint256) {
        return _nextStreamId;
    }

    /**
     * @notice Returns the full stream record for a given ID.
     */
    function getStream(uint256 streamId) external view returns (Stream memory) {
        return _streams[streamId];
    }

    /**
     * @notice Returns the amount of tokens currently available to withdraw
     *         from a stream (streamed portion minus already withdrawn).
     */
    function withdrawableAmount(uint256 streamId)
        external
        view
        streamExists(streamId)
        returns (uint256)
    {
        return _withdrawableAmount(_streams[streamId]);
    }

    /**
     * @notice Returns the total amount streamed so far for a given stream.
     */
    function streamedAmount(uint256 streamId)
        external
        view
        streamExists(streamId)
        returns (uint256)
    {
        return _streamedAmount(_streams[streamId]);
    }

    // -----------------------------------------------------------------------
    // Internal Functions
    // -----------------------------------------------------------------------

    /**
     * @dev Calculates the total amount streamed based on elapsed time.
     *      Returns 0 before start, totalAmount after end, and a pro-rata
     *      amount in between.
     */
    function _streamedAmount(Stream storage s) internal view returns (uint256) {
        if (block.timestamp <= s.startTime) {
            return 0;
        }
        if (block.timestamp >= s.endTime) {
            return s.totalAmount;
        }
        uint256 elapsed = block.timestamp - s.startTime;
        uint256 duration = s.endTime - s.startTime;
        return (s.totalAmount * elapsed) / duration;
    }

    /**
     * @dev Calculates the withdrawable amount: streamed minus already withdrawn.
     */
    function _withdrawableAmount(Stream storage s) internal view returns (uint256) {
        uint256 streamed = _streamedAmount(s);
        if (streamed <= s.withdrawnAmount) {
            return 0;
        }
        return streamed - s.withdrawnAmount;
    }
}
