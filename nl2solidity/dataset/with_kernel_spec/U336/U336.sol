// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenLiquidityLocker {
    // ============ Constants ============
    uint256 public constant MIN_LOCK_DURATION = 30 days;
    uint256 public constant MAX_LOCK_DURATION = 1095 days;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 100; // 1%

    // ============ Structs ============
    struct Lock {
        address token;
        address depositor;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool withdrawn;
    }

    // ============ State Variables ============
    mapping(uint256 => Lock) public locks;
    uint256 public nextLockId;

    mapping(address => uint256[]) public userLockIds;

    uint256 public feeBps;
    address public owner;

    uint256 private _guard;

    // ============ Events ============
    event LockCreated(
        uint256 indexed lockId,
        address indexed depositor,
        address indexed token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    );
    event LockExtended(uint256 indexed lockId, address indexed depositor, uint256 newEndTime);
    event TokensWithdrawn(
        uint256 indexed lockId,
        address indexed depositor,
        address indexed token,
        uint256 payout,
        uint256 fee
    );
    event FeePercentageUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Custom Errors ============
    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error InvalidDuration();
    error InvalidFeePercentage();
    error LockNotExpired();
    error AlreadyWithdrawn();
    error LockNotFound();
    error TransferFailed();
    error ReentrantCall();

    // ============ Modifiers ============
    modifier nonReentrant() {
        if (_guard == 2) revert ReentrantCall();
        _guard = 2;
        _;
        _guard = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // ============ Constructor ============
    constructor() {
        owner = msg.sender;
        feeBps = DEFAULT_FEE_BPS;
        _guard = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeePercentageUpdated(0, DEFAULT_FEE_BPS);
    }

    // ============ Core Functions ============

    /**
     * @notice Deposit tokens to create a new lock.
     * @param token Address of the token to lock (supports fungible tokens and LP tokens).
     * @param amount Amount of tokens to lock.
     * @param duration Lock duration in seconds (min 30 days, max 1095 days).
     * @return lockId The ID of the newly created lock.
     */
    function deposit(address token, uint256 amount, uint256 duration)
        external
        nonReentrant
        returns (uint256 lockId)
    {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (duration < MIN_LOCK_DURATION || duration > MAX_LOCK_DURATION) revert InvalidDuration();

        uint256 start = block.timestamp;
        uint256 end = start + duration;

        lockId = nextLockId++;
        locks[lockId] = Lock({
            token: token,
            depositor: msg.sender,
            amount: amount,
            startTime: start,
            endTime: end,
            withdrawn: false
        });
        userLockIds[msg.sender].push(lockId);

        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit LockCreated(lockId, msg.sender, token, amount, start, end);
    }

    /**
     * @notice Extend the duration of an existing active lock.
     * @param lockId The ID of the lock to extend.
     * @param additionalDuration Additional seconds to add to the lock (total duration
     *        measured from original start time must not exceed MAX_LOCK_DURATION).
     */
    function extendLock(uint256 lockId, uint256 additionalDuration) external nonReentrant {
        Lock storage lock = locks[lockId];
        if (lock.depositor == address(0)) revert LockNotFound();
        if (lock.depositor != msg.sender) revert Unauthorized();
        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (additionalDuration == 0) revert ZeroAmount();

        uint256 newEndTime = lock.endTime + additionalDuration;
        if (newEndTime - lock.startTime > MAX_LOCK_DURATION) revert InvalidDuration();

        lock.endTime = newEndTime;

        emit LockExtended(lockId, msg.sender, newEndTime);
    }

    /**
     * @notice Withdraw tokens from an expired lock. A fee is deducted from the withdrawn
     *         amount and sent to the owner; the remainder is returned to the depositor.
     * @param lockId The ID of the lock to withdraw from.
     */
    function withdraw(uint256 lockId) external nonReentrant {
        Lock storage lock = locks[lockId];
        if (lock.depositor == address(0)) revert LockNotFound();
        if (lock.depositor != msg.sender) revert Unauthorized();
        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < lock.endTime) revert LockNotExpired();

        // Effects
        lock.withdrawn = true;

        uint256 amount = lock.amount;
        uint256 fee = (amount * feeBps) / FEE_DENOMINATOR;
        uint256 payout = amount - fee;

        // Interactions
        if (payout > 0) {
            _safeTransfer(lock.token, msg.sender, payout);
        }
        if (fee > 0) {
            _safeTransfer(lock.token, owner, fee);
        }

        emit TokensWithdrawn(lockId, msg.sender, lock.token, payout, fee);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the global fee percentage (in basis points). Only callable by owner.
     * @param newFeeBps New fee percentage in basis points (e.g., 100 = 1%).
     */
    function setFeePercentage(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > FEE_DENOMINATOR) revert InvalidFeePercentage();
        uint256 oldFee = feeBps;
        feeBps = newFeeBps;
        emit FeePercentageUpdated(oldFee, newFeeBps);
    }

    /**
     * @notice Transfer ownership to a new address. Only callable by current owner.
     * @param newOwner Address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // ============ View Functions ============

    /**
     * @notice Get details of a specific lock.
     */
    function getLock(uint256 lockId)
        external
        view
        returns (
            address token,
            address depositor,
            uint256 amount,
            uint256 startTime,
            uint256 endTime,
            bool withdrawn
        )
    {
        Lock storage lock = locks[lockId];
        return (lock.token, lock.depositor, lock.amount, lock.startTime, lock.endTime, lock.withdrawn);
    }

    /**
     * @notice Get all lock IDs created by a user.
     */
    function getUserLockIds(address user) external view returns (uint256[] memory) {
        return userLockIds[user];
    }

    /**
     * @notice Get the total number of locks created.
     */
    function getLockCount() external view returns (uint256) {
        return nextLockId;
    }

    /**
     * @notice Check whether a lock has expired (end time reached).
     */
    function isLockExpired(uint256 lockId) external view returns (bool) {
        if (locks[lockId].depositor == address(0)) return false;
        return block.timestamp >= locks[lockId].endTime;
    }

    // ============ Internal Helpers ============

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
