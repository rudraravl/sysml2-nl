// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title TokenTimelockEscrow
/// @notice Escrow contract that locks arbitrary ERC-20 tokens until a configurable unlock time.
///         A protocol-defined fee (in basis points) is deducted from each new deposit and
///         forwarded to the contract owner. Designated operators may extend an existing
///         lock's unlock time, but only before the original unlock time has elapsed.
contract TokenTimelockEscrow {
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_PERCENT_BPS = 500; // 5%
    uint256 public constant DEFAULT_FEE_PERCENT_BPS = 50; // 0.5%

    struct Lock {
        address depositor;
        address token;
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    address public owner;
    uint256 public feePercentBps;
    mapping(address => bool) public operators;
    mapping(uint256 => Lock) public locks;
    uint256 public nextLockId;

    event LockCreated(
        uint256 indexed lockId,
        address indexed depositor,
        address indexed token,
        uint256 amount,
        uint256 unlockTime,
        uint256 fee
    );
    event LockExtended(uint256 indexed lockId, uint256 oldUnlockTime, uint256 newUnlockTime);
    event LockWithdrawn(
        uint256 indexed lockId,
        address indexed depositor,
        address indexed token,
        uint256 amount
    );
    event FeePercentUpdated(uint256 oldFeePercentBps, uint256 newFeePercentBps);
    event OperatorUpdated(address indexed operator, bool indexed active);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Unauthorized();
    error InvalidAddress();
    error InvalidDuration();
    error InvalidFeePercent();
    error InsufficientAmount();
    error LockDoesNotExist();
    error LockAlreadyWithdrawn();
    error LockNotExpired();
    error LockAlreadyExpired();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != owner && !operators[msg.sender]) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
        feePercentBps = DEFAULT_FEE_PERCENT_BPS;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeePercentUpdated(0, DEFAULT_FEE_PERCENT_BPS);
    }

    /// @notice Sets the fee percentage (in basis points) applied to new lock deposits.
    /// @param newFeePercentBps Fee in basis points; must be <= MAX_FEE_PERCENT_BPS (500).
    function setFeePercent(uint256 newFeePercentBps) external onlyOwner {
        if (newFeePercentBps > MAX_FEE_PERCENT_BPS) revert InvalidFeePercent();
        uint256 oldFeePercentBps = feePercentBps;
        feePercentBps = newFeePercentBps;
        emit FeePercentUpdated(oldFeePercentBps, newFeePercentBps);
    }

    /// @notice Grants or revokes operator privileges. Operators may extend existing locks.
    function setOperator(address operator, bool active) external onlyOwner {
        if (operator == address(0)) revert InvalidAddress();
        operators[operator] = active;
        emit OperatorUpdated(operator, active);
    }

    /// @notice Transfers contract ownership to a new address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Creates a new token lock by pulling tokens from the caller and escrowing them.
    /// @param token The ERC-20 token to lock.
    /// @param amount The gross deposit amount; a fee is taken off the top before locking.
    /// @param duration Lock duration in seconds; must be greater than zero.
    /// @return lockId The identifier of the newly created lock.
    function createLock(address token, uint256 amount, uint256 duration) external returns (uint256 lockId) {
        if (token == address(0)) revert InvalidAddress();
        if (amount == 0) revert InsufficientAmount();
        if (duration == 0) revert InvalidDuration();

        uint256 fee = (amount * feePercentBps) / FEE_DENOMINATOR;
        uint256 lockedAmount = amount - fee;
        if (lockedAmount == 0) revert InsufficientAmount();

        _safeTransferFrom(token, msg.sender, address(this), amount);
        if (fee > 0) {
            _safeTransfer(token, owner, fee);
        }

        uint256 unlockTime = block.timestamp + duration;
        lockId = nextLockId++;
        locks[lockId] = Lock({
            depositor: msg.sender,
            token: token,
            amount: lockedAmount,
            unlockTime: unlockTime,
            withdrawn: false
        });

        emit LockCreated(lockId, msg.sender, token, lockedAmount, unlockTime, fee);
    }

    /// @notice Withdraws the locked tokens after the unlock time has passed. Only the
    ///         original depositor may call this.
    function withdraw(uint256 lockId) external {
        Lock storage lockRecord = locks[lockId];
        if (lockRecord.depositor == address(0)) revert LockDoesNotExist();
        if (msg.sender != lockRecord.depositor) revert Unauthorized();
        if (lockRecord.withdrawn) revert LockAlreadyWithdrawn();
        if (block.timestamp < lockRecord.unlockTime) revert LockNotExpired();

        lockRecord.withdrawn = true;
        _safeTransfer(lockRecord.token, lockRecord.depositor, lockRecord.amount);

        emit LockWithdrawn(lockId, lockRecord.depositor, lockRecord.token, lockRecord.amount);
    }

    /// @notice Extends the unlock time of an existing, non-expired, non-withdrawn lock.
    ///         Callable only by an authorized operator or the owner.
    /// @param lockId The lock to extend.
    /// @param additionalDuration Number of seconds to add to the current unlock time.
    function extendLock(uint256 lockId, uint256 additionalDuration) external onlyOperator {
        Lock storage lockRecord = locks[lockId];
        if (lockRecord.depositor == address(0)) revert LockDoesNotExist();
        if (lockRecord.withdrawn) revert LockAlreadyWithdrawn();
        if (block.timestamp >= lockRecord.unlockTime) revert LockAlreadyExpired();
        if (additionalDuration == 0) revert InvalidDuration();

        uint256 oldUnlockTime = lockRecord.unlockTime;
        uint256 newUnlockTime = oldUnlockTime + additionalDuration;
        lockRecord.unlockTime = newUnlockTime;

        emit LockExtended(lockId, oldUnlockTime, newUnlockTime);
    }

    /// @notice Returns the full state of a lock by id.
    function getLock(uint256 lockId)
        external
        view
        returns (address depositor, address token, uint256 amount, uint256 unlockTime, bool withdrawn)
    {
        Lock storage lockRecord = locks[lockId];
        return (
            lockRecord.depositor,
            lockRecord.token,
            lockRecord.amount,
            lockRecord.unlockTime,
            lockRecord.withdrawn
        );
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
