// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenLocker {
    uint256 public constant MAX_LOCK_DURATION = 104 weeks;
    uint256 public constant MIN_DEPOSIT_AMOUNT = 1;
    uint256 public constant MAX_FEE_BPS = 10_000; // 100%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct Deposit {
        address depositor;
        address token;
        uint256 amount;
        uint256 unlockTime;
    }

    address public owner;
    uint256 public depositFeeBps;
    uint256 public nextDepositId;

    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256) public collectedFees;
    mapping(address => uint256[]) public userDepositIds;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    event TokensDeposited(
        uint256 indexed depositId,
        address indexed depositor,
        address indexed token,
        uint256 amount,
        uint256 unlockTime
    );
    event LockExtended(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 previousUnlockTime,
        uint256 newUnlockTime
    );
    event TokensWithdrawn(
        uint256 indexed depositId,
        address indexed depositor,
        address indexed token,
        uint256 amount
    );
    event DepositFeeUpdated(uint256 previousFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed token, address indexed recipient, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error AmountBelowMinimum(uint256 amount, uint256 minRequired);
    error InvalidLockDuration();
    error ExceedsMaxLockDuration(uint256 requested, uint256 maxAllowed);
    error DepositNotFound();
    error NotDepositor(address caller, address depositor);
    error LockNotExpired(uint256 unlockTime, uint256 currentTime);
    error FeeTooHigh(uint256 feeBps, uint256 maxFeeBps);
    error InsufficientFees(uint256 requested, uint256 available);
    error TransferFailed();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor() {
        owner = msg.sender;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function deposit(
        address token,
        uint256 amount,
        uint256 lockDuration
    ) external nonReentrant returns (uint256 depositId) {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT_AMOUNT) revert AmountBelowMinimum(amount, MIN_DEPOSIT_AMOUNT);
        if (lockDuration == 0 || lockDuration > MAX_LOCK_DURATION) revert InvalidLockDuration();

        uint256 fee = (amount * depositFeeBps) / BPS_DENOMINATOR;
        uint256 lockedAmount = amount - fee;

        _safeTransferFrom(token, msg.sender, address(this), amount);

        if (fee > 0) {
            collectedFees[token] += fee;
        }

        depositId = nextDepositId++;
        uint256 unlockTime = block.timestamp + lockDuration;
        deposits[depositId] = Deposit({
            depositor: msg.sender,
            token: token,
            amount: lockedAmount,
            unlockTime: unlockTime
        });
        userDepositIds[msg.sender].push(depositId);

        emit TokensDeposited(depositId, msg.sender, token, lockedAmount, unlockTime);
    }

    function extendLock(uint256 depositId, uint256 additionalDuration) external {
        Deposit storage dep = deposits[depositId];
        if (dep.depositor == address(0)) revert DepositNotFound();
        if (dep.depositor != msg.sender) revert NotDepositor(msg.sender, dep.depositor);
        if (additionalDuration == 0) revert InvalidLockDuration();

        uint256 newUnlockTime = dep.unlockTime + additionalDuration;
        if (newUnlockTime > block.timestamp + MAX_LOCK_DURATION) {
            revert ExceedsMaxLockDuration(newUnlockTime - block.timestamp, MAX_LOCK_DURATION);
        }

        uint256 previousUnlockTime = dep.unlockTime;
        dep.unlockTime = newUnlockTime;

        emit LockExtended(depositId, msg.sender, previousUnlockTime, newUnlockTime);
    }

    function withdraw(uint256 depositId) external nonReentrant {
        Deposit storage dep = deposits[depositId];
        if (dep.depositor == address(0)) revert DepositNotFound();
        if (dep.depositor != msg.sender) revert NotDepositor(msg.sender, dep.depositor);
        if (block.timestamp < dep.unlockTime) revert LockNotExpired(dep.unlockTime, block.timestamp);

        uint256 amount = dep.amount;
        address token = dep.token;

        delete deposits[depositId];

        _safeTransfer(token, msg.sender, amount);

        emit TokensWithdrawn(depositId, msg.sender, token, amount);
    }

    function setDepositFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        uint256 previousFee = depositFeeBps;
        depositFeeBps = newFeeBps;
        emit DepositFeeUpdated(previousFee, newFeeBps);
    }

    function withdrawFees(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 available = collectedFees[token];
        if (amount > available) revert InsufficientFees(amount, available);

        collectedFees[token] = available - amount;
        _safeTransfer(token, msg.sender, amount);

        emit FeesWithdrawn(token, msg.sender, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function getDepositIdsByUser(address user) external view returns (uint256[] memory) {
        return userDepositIds[user];
    }

    function getDeposit(uint256 depositId) external view returns (Deposit memory) {
        return deposits[depositId];
    }

    function totalDeposits() external view returns (uint256) {
        return nextDepositId;
    }

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
