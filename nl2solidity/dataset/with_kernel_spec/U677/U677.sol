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

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: failed approval"
        );
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
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
        if (_msgSender() != _owner) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address indexed account);
    event Unpaused(address indexed account);

    error EnforcedPause();
    error ExpectedPause();

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        if (paused()) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused()) revert ExpectedPause();
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
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
 * @title TokenVestingManager
 * @dev Manages token vesting schedules and streaming payments for multiple recipients.
 * Holds custody of ERC-20 tokens designated for distribution according to linear vesting
 * schedules. Only the owner can set the default vesting duration and pause/unpause claims.
 * Vesting schedules must have a duration of at least 30 days, and recipients can claim
 * vested tokens no more frequently than once every 24 hours.
 */
contract TokenVestingManager is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_DURATION = 30 days;
    uint256 public constant CLAIM_COOLDOWN = 24 hours;

    IERC20 public immutable token;
    uint256 public defaultVestingDuration;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 lastClaimTime;
        bool initialized;
    }

    mapping(address => VestingSchedule) private _schedules;

    event TokensDeposited(address indexed recipient, address indexed depositor, uint256 amount);
    event VestingScheduleCreated(address indexed recipient, uint256 totalAmount, uint256 startTime, uint256 duration);
    event TokensClaimed(address indexed recipient, uint256 amount);
    event DefaultVestingDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event ClaimsPaused();
    event ClaimsUnpaused();

    error ZeroAddress();
    error ZeroAmount();
    error DurationTooShort();
    error ScheduleAlreadyExists();
    error ScheduleDoesNotExist();
    error NothingToClaim();
    error ClaimOnCooldown();
    error StartTimeInPast();

    constructor(address tokenAddress, uint256 _defaultVestingDuration) Ownable(msg.sender) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (_defaultVestingDuration < MIN_DURATION) revert DurationTooShort();

        token = IERC20(tokenAddress);
        defaultVestingDuration = _defaultVestingDuration;
    }

    modifier validRecipient(address recipient) {
        if (recipient == address(0)) revert ZeroAddress();
        _;
    }

    function setDefaultVestingDuration(uint256 newDuration) external onlyOwner {
        if (newDuration < MIN_DURATION) revert DurationTooShort();
        uint256 oldDuration = defaultVestingDuration;
        defaultVestingDuration = newDuration;
        emit DefaultVestingDurationUpdated(oldDuration, newDuration);
    }

    function pause() external onlyOwner {
        _pause();
        emit ClaimsPaused();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ClaimsUnpaused();
    }

    function depositFor(address recipient, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        validRecipient(recipient)
    {
        if (amount == 0) revert ZeroAmount();

        VestingSchedule storage schedule = _schedules[recipient];

        if (!schedule.initialized) {
            _schedules[recipient] = VestingSchedule({
                totalAmount: amount,
                releasedAmount: 0,
                startTime: block.timestamp,
                duration: defaultVestingDuration,
                lastClaimTime: block.timestamp,
                initialized: true
            });
            emit VestingScheduleCreated(recipient, amount, block.timestamp, defaultVestingDuration);
        } else {
            schedule.totalAmount += amount;
        }

        token.safeTransferFrom(msg.sender, address(this), amount);
        emit TokensDeposited(recipient, msg.sender, amount);
    }

    function createVestingSchedule(
        address recipient,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner nonReentrant whenNotPaused validRecipient(recipient) {
        if (totalAmount == 0) revert ZeroAmount();
        if (duration < MIN_DURATION) revert DurationTooShort();
        if (startTime < block.timestamp) revert StartTimeInPast();
        if (_schedules[recipient].initialized) revert ScheduleAlreadyExists();

        _schedules[recipient] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            lastClaimTime: startTime,
            initialized: true
        });

        token.safeTransferFrom(msg.sender, address(this), totalAmount);

        emit VestingScheduleCreated(recipient, totalAmount, startTime, duration);
        emit TokensDeposited(recipient, msg.sender, totalAmount);
    }

    function claim() external nonReentrant whenNotPaused {
        address recipient = msg.sender;
        VestingSchedule storage schedule = _schedules[recipient];
        if (!schedule.initialized) revert ScheduleDoesNotExist();

        if (block.timestamp < schedule.lastClaimTime + CLAIM_COOLDOWN) {
            revert ClaimOnCooldown();
        }

        uint256 vested = _vestedAmount(schedule);
        if (vested <= schedule.releasedAmount) revert NothingToClaim();
        uint256 releasable = vested - schedule.releasedAmount;

        schedule.releasedAmount += releasable;
        schedule.lastClaimTime = block.timestamp;

        token.safeTransfer(recipient, releasable);

        emit TokensClaimed(recipient, releasable);
    }

    function vestedAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = _schedules[beneficiary];
        if (!schedule.initialized) return 0;
        return _vestedAmount(schedule);
    }

    function releasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = _schedules[beneficiary];
        if (!schedule.initialized) return 0;
        uint256 vested = _vestedAmount(schedule);
        if (vested <= schedule.releasedAmount) return 0;
        return vested - schedule.releasedAmount;
    }

    function getSchedule(address beneficiary)
        external
        view
        returns (
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 startTime,
            uint256 duration,
            uint256 lastClaimTime,
            bool initialized
        )
    {
        VestingSchedule storage schedule = _schedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.lastClaimTime,
            schedule.initialized
        );
    }

    function _vestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime) return 0;
        uint256 elapsed = block.timestamp - schedule.startTime;
        if (elapsed >= schedule.duration) return schedule.totalAmount;
        return (schedule.totalAmount * elapsed) / schedule.duration;
    }
}
