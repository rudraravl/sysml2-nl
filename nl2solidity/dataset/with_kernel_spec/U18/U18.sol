// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenLocker {
    using SafeERC20 for IERC20;

    struct Lock {
        address token;
        address owner;
        address recipient;
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    event LockCreated(
        uint256 indexed lockId,
        address indexed token,
        address indexed owner,
        address recipient,
        uint256 amount,
        uint256 unlockTime,
        uint256 fee
    );
    event LockExtended(uint256 indexed lockId, uint256 newUnlockTime);
    event Withdrawn(uint256 indexed lockId, address indexed recipient, uint256 amount);
    event FeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotLockOwner();
    error NotRecipient();
    error ZeroAddress();
    error ZeroAmount();
    error DurationTooShort();
    error LockNotExpired();
    error AlreadyWithdrawn();
    error NewUnlockTooSoon();
    error InvalidFeeBps();
    error LockNotFound();

    uint256 public constant MIN_LOCK_DURATION = 30 days;
    uint256 public constant MAX_FEE_BPS = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 100;

    address public owner;
    address public feeRecipient;
    uint256 public feeBps;
    uint256 public nextLockId;
    mapping(uint256 => Lock) public locks;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        feeBps = DEFAULT_FEE_BPS;
        nextLockId = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeRecipientUpdated(_feeRecipient);
        emit FeeUpdated(DEFAULT_FEE_BPS);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function createLock(
        address token,
        address recipient,
        uint256 amount,
        uint256 duration
    ) external returns (uint256 lockId) {
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (duration < MIN_LOCK_DURATION) revert DurationTooShort();

        uint256 fee = (amount * feeBps) / MAX_FEE_BPS;
        uint256 lockedAmount = amount - fee;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        if (fee > 0) {
            IERC20(token).safeTransfer(feeRecipient, fee);
        }

        lockId = nextLockId++;
        uint256 unlockTime = block.timestamp + duration;

        locks[lockId] = Lock({
            token: token,
            owner: msg.sender,
            recipient: recipient,
            amount: lockedAmount,
            unlockTime: unlockTime,
            withdrawn: false
        });

        emit LockCreated(lockId, token, msg.sender, recipient, lockedAmount, unlockTime, fee);
    }

    function extendLock(uint256 lockId, uint256 additionalDuration) external {
        Lock storage lock = locks[lockId];
        if (lock.token == address(0)) revert LockNotFound();
        if (msg.sender != lock.owner) revert NotLockOwner();
        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (additionalDuration == 0) revert NewUnlockTooSoon();

        lock.unlockTime += additionalDuration;
        emit LockExtended(lockId, lock.unlockTime);
    }

    function withdraw(uint256 lockId) external {
        Lock storage lock = locks[lockId];
        if (lock.token == address(0)) revert LockNotFound();
        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (msg.sender != lock.recipient) revert NotRecipient();
        if (block.timestamp < lock.unlockTime) revert LockNotExpired();

        uint256 amount = lock.amount;
        address recipient = lock.recipient;
        address token = lock.token;

        lock.withdrawn = true;
        lock.amount = 0;

        IERC20(token).safeTransfer(recipient, amount);

        emit Withdrawn(lockId, recipient, amount);
    }

    function getLock(uint256 lockId)
        external
        view
        returns (
            address token,
            address lockOwner,
            address recipient,
            uint256 amount,
            uint256 unlockTime,
            bool withdrawn
        )
    {
        Lock storage lock = locks[lockId];
        return (lock.token, lock.owner, lock.recipient, lock.amount, lock.unlockTime, lock.withdrawn);
    }
}
