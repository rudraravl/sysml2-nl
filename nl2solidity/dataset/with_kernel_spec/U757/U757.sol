// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Reentrancy guard.
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != ENTERED, "REENTRANT");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/// @notice Simple access control with a single administrator.
abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error ErrNotOwner();

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrNotOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/**
 * @title TokenVault
 * @dev A secure vault for locking fungible tokens with time-based release.
 *      Users create locks specifying a token, an amount, and a duration
 *      (>= 30 days). Locks may be extended but not shortened. Once the unlock
 *      date passes, the beneficiary may withdraw the tokens, optionally paying
 *      a global withdrawal fee set by the administrator (capped at 5%).
 */
contract TokenVault is Ownable, ReentrancyGuard {
    struct Lock {
        uint256 amount;
        uint256 unlockDate;
        address beneficiary;
        bool withdrawn;
    }

    // --- Events ---
    event Deposited(
        address indexed user,
        address indexed token,
        uint256 indexed lockId,
        uint256 amount,
        uint256 unlockDate,
        address beneficiary
    );
    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 indexed lockId,
        uint256 amount,
        uint256 fee
    );
    event LockExtended(
        address indexed user,
        address indexed token,
        uint256 indexed lockId,
        uint256 oldUnlockDate,
        uint256 newUnlockDate
    );
    event Paused();
    event Unpaused();
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    // --- Errors ---
    error ErrZeroAmount();
    error ErrZeroAddress();
    error ErrDurationTooShort();
    error ErrNotUnlocked();
    error ErrAlreadyWithdrawn();
    error ErrNotLockOwner();
    error ErrCannotShortenLock();
    error ErrPaused();
    error ErrFeeTooHigh();
    error ErrInvalidLockId();
    error ErrTransferFailed();

    // --- Constants ---
    uint256 public constant MIN_LOCK_DURATION = 30 days;
    uint256 public constant MAX_FEE_BPS = 500; // 5%

    // --- State ---
    bool public paused;
    uint256 public withdrawalFeeBps; // basis points, max 500
    address public feeRecipient;

    // user => token => Lock[]
    mapping(address => mapping(address => Lock[])) private _locks;

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    constructor(address _feeRecipient, uint256 _withdrawalFeeBps) {
        if (_feeRecipient == address(0)) revert ErrZeroAddress();
        if (_withdrawalFeeBps > MAX_FEE_BPS) revert ErrFeeTooHigh();
        feeRecipient = _feeRecipient;
        withdrawalFeeBps = _withdrawalFeeBps;
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit WithdrawalFeeUpdated(0, _withdrawalFeeBps);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function setWithdrawalFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert ErrFeeTooHigh();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = _feeBps;
        emit WithdrawalFeeUpdated(old, _feeBps);
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        if (_recipient == address(0)) revert ErrZeroAddress();
        address old = feeRecipient;
        feeRecipient = _recipient;
        emit FeeRecipientUpdated(old, _recipient);
    }

    // ---------------------------------------------------------------------
    // User functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit tokens into a new lock.
     * @param token The ERC-20 token to lock.
     * @param amount The amount to lock.
     * @param durationSeconds The lock duration; must be >= MIN_LOCK_DURATION.
     * @param beneficiary Optional beneficiary; if zero address, caller is used.
     */
    function deposit(
        address token,
        uint256 amount,
        uint256 durationSeconds,
        address beneficiary
    ) external whenNotPaused nonReentrant returns (uint256 lockId) {
        if (amount == 0) revert ErrZeroAmount();
        if (durationSeconds < MIN_LOCK_DURATION) revert ErrDurationTooShort();
        if (token == address(0)) revert ErrZeroAddress();

        address bene = beneficiary == address(0) ? msg.sender : beneficiary;

        // Transfer tokens from caller into the vault.
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert ErrTransferFailed();

        uint256 unlockDate = block.timestamp + durationSeconds;
        lockId = _locks[msg.sender][token].length;

        _locks[msg.sender][token].push(
            Lock({
                amount: amount,
                unlockDate: unlockDate,
                beneficiary: bene,
                withdrawn: false
            })
        );

        emit Deposited(msg.sender, token, lockId, amount, unlockDate, bene);
    }

    /**
     * @notice Extend the duration of an existing lock. The new unlock date
     *         must be later than the current one.
     */
    function extendLock(
        address token,
        uint256 lockId,
        uint256 additionalSeconds
    ) external whenNotPaused nonReentrant {
        if (additionalSeconds == 0) revert ErrZeroAmount();
        Lock[] storage locks = _locks[msg.sender][token];
        if (lockId >= locks.length) revert ErrInvalidLockId();

        Lock storage l = locks[lockId];
        if (l.withdrawn) revert ErrAlreadyWithdrawn();
        if (l.beneficiary != msg.sender) revert ErrNotLockOwner();

        uint256 oldUnlock = l.unlockDate;
        uint256 newUnlock = oldUnlock + additionalSeconds;
        if (newUnlock <= oldUnlock) revert ErrCannotShortenLock();

        l.unlockDate = newUnlock;
        emit LockExtended(msg.sender, token, lockId, oldUnlock, newUnlock);
    }

    /**
     * @notice Withdraw tokens from a lock that has matured.
     */
    function withdraw(
        address token,
        uint256 lockId
    ) external whenNotPaused nonReentrant {
        Lock[] storage locks = _locks[msg.sender][token];
        if (lockId >= locks.length) revert ErrInvalidLockId();

        Lock storage l = locks[lockId];
        if (l.withdrawn) revert ErrAlreadyWithdrawn();
        if (block.timestamp < l.unlockDate) revert ErrNotUnlocked();
        if (l.beneficiary != msg.sender) revert ErrNotLockOwner();

        uint256 amount = l.amount;
        l.withdrawn = true;

        uint256 fee = (amount * withdrawalFeeBps) / 10_000;
        uint256 payout = amount - fee;

        if (fee > 0) {
            bool okFee = IERC20(token).transfer(feeRecipient, fee);
            if (!okFee) revert ErrTransferFailed();
        }

        bool ok = IERC20(token).transfer(msg.sender, payout);
        if (!ok) revert ErrTransferFailed();

        emit Withdrawn(msg.sender, token, lockId, payout, fee);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    function getLockCount(address user, address token) external view returns (uint256) {
        return _locks[user][token].length;
    }

    function getLock(
        address user,
        address token,
        uint256 lockId
    )
        external
        view
        returns (
            uint256 amount,
            uint256 unlockDate,
            address beneficiary,
            bool withdrawn
        )
    {
        Lock storage l = _locks[user][token][lockId];
        return (l.amount, l.unlockDate, l.beneficiary, l.withdrawn);
    }

    function isUnlocked(address user, address token, uint256 lockId) external view returns (bool) {
        return block.timestamp >= _locks[user][token][lockId].unlockDate;
    }
}
