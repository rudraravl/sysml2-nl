// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(0x20, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract StreamEscrow {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error RateNotPositive();
    error RateExceedsMax();
    error StreamNotActive();
    error InsufficientWithdrawable();
    error InvalidAmount();
    error InvalidFeeBps();
    error AlreadyPaused();
    error NotPausedState();
    error NotOwner();
    error ReentrantCall();

    event Deposited(address indexed sender, uint256 amount);
    event StreamCreated(address indexed sender, address indexed recipient, uint256 rate, uint256 startTime);
    event StreamUpdated(address indexed sender, address indexed recipient, uint256 rate);
    event Withdrawn(address indexed user, uint256 amount);
    event Streamed(address indexed sender, address indexed recipient, uint256 streamAmount, uint256 fee);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MAX_RATE = 1000 * 10 ** 18;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 250;

    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    struct Stream {
        address recipient;
        uint256 rate;
        uint256 startTime;
        uint256 lastStreamClock;
        bool active;
    }

    IERC20 public immutable token;
    address public owner;
    address public feeRecipient;
    uint256 public feeBps;

    bool public paused;
    uint256 public pauseStart;
    uint256 public accumulatedPause;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public received;
    mapping(address => Stream) public streams;

    uint256 private _reentrancyStatus = _NOT_ENTERED;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    constructor(address token_, address feeRecipient_) {
        if (token_ == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        feeRecipient = feeRecipient_;
        feeBps = DEFAULT_FEE_BPS;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeRecipientUpdated(address(0), feeRecipient_);
        emit FeeUpdated(0, feeBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        if (paused) revert AlreadyPaused();
        paused = true;
        pauseStart = block.timestamp;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert NotPausedState();
        accumulatedPause += block.timestamp - pauseStart;
        pauseStart = 0;
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > FEE_DENOMINATOR) revert InvalidFeeBps();
        emit FeeUpdated(feeBps, newFeeBps);
        feeBps = newFeeBps;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        _settle(msg.sender);
        balanceOf[msg.sender] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function createStream(address recipient, uint256 rate) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (rate == 0) revert RateNotPositive();
        if (rate > MAX_RATE) revert RateExceedsMax();
        _settle(msg.sender);
        streams[msg.sender] = Stream({
            recipient: recipient,
            rate: rate,
            startTime: block.timestamp,
            lastStreamClock: _streamClock(),
            active: true
        });
        emit StreamCreated(msg.sender, recipient, rate, block.timestamp);
    }

    function updateStream(address recipient, uint256 rate) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (rate == 0) revert RateNotPositive();
        if (rate > MAX_RATE) revert RateExceedsMax();
        Stream storage s = streams[msg.sender];
        if (!s.active) revert StreamNotActive();
        _settle(msg.sender);
        s.recipient = recipient;
        s.rate = rate;
        emit StreamUpdated(msg.sender, recipient, rate);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        _settle(msg.sender);
        uint256 senderBalance = balanceOf[msg.sender];
        uint256 receivable = received[msg.sender];
        uint256 available = senderBalance + receivable;
        if (amount > available) revert InsufficientWithdrawable();
        if (amount <= receivable) {
            received[msg.sender] = receivable - amount;
        } else {
            received[msg.sender] = 0;
            balanceOf[msg.sender] = senderBalance - (amount - receivable);
        }
        token.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function settle(address sender) external nonReentrant {
        _settle(sender);
    }

    function streamClock() public view returns (uint256) {
        return _streamClock();
    }

    function withdrawable(address account) external view returns (uint256) {
        return balanceOf[account] + received[account];
    }

    function getStream(address sender)
        external
        view
        returns (
            address recipient,
            uint256 rate,
            uint256 startTime,
            uint256 lastStreamClock,
            bool active,
            uint256 depositedBalance
        )
    {
        Stream storage s = streams[sender];
        recipient = s.recipient;
        rate = s.rate;
        startTime = s.startTime;
        lastStreamClock = s.lastStreamClock;
        active = s.active;
        depositedBalance = balanceOf[sender];
    }

    function previewSettle(address sender)
        external
        view
        returns (uint256 streamAmount, uint256 fee, uint256 remainingAfter)
    {
        Stream storage s = streams[sender];
        uint256 bal = balanceOf[sender];
        if (!s.active) {
            return (0, 0, bal);
        }
        uint256 clockNow = _streamClock();
        uint256 elapsed = clockNow - s.lastStreamClock;
        if (elapsed == 0 || bal == 0) {
            return (0, 0, bal);
        }
        uint256 timeStreamed = s.rate * elapsed;
        uint256 maxStreamable = (bal * FEE_DENOMINATOR) / (FEE_DENOMINATOR + feeBps);
        streamAmount = timeStreamed <= maxStreamable ? timeStreamed : maxStreamable;
        fee = (streamAmount * feeBps) / FEE_DENOMINATOR;
        remainingAfter = bal - streamAmount - fee;
    }

    function _streamClock() internal view returns (uint256) {
        if (paused) {
            return pauseStart - accumulatedPause;
        }
        return block.timestamp - accumulatedPause;
    }

    function _settle(address sender) internal {
        Stream storage s = streams[sender];
        if (!s.active) {
            s.lastStreamClock = _streamClock();
            return;
        }
        uint256 clockNow = _streamClock();
        uint256 elapsed = clockNow - s.lastStreamClock;
        if (elapsed == 0) {
            return;
        }
        uint256 bal = balanceOf[sender];
        if (bal == 0) {
            s.lastStreamClock = clockNow;
            return;
        }
        uint256 timeStreamed = s.rate * elapsed;
        uint256 maxStreamable = (bal * FEE_DENOMINATOR) / (FEE_DENOMINATOR + feeBps);
        uint256 streamAmount;
        if (timeStreamed <= maxStreamable) {
            streamAmount = timeStreamed;
        } else {
            streamAmount = maxStreamable;
        }
        uint256 fee = (streamAmount * feeBps) / FEE_DENOMINATOR;
        balanceOf[sender] = bal - streamAmount - fee;
        received[s.recipient] += streamAmount;
        received[feeRecipient] += fee;
        s.lastStreamClock = clockNow;
        emit Streamed(sender, s.recipient, streamAmount, fee);
    }
}
