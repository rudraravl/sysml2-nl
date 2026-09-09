// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
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

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
}

contract TokenLocker is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_LOCK_DURATION = 24 hours;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant MAX_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_OPERATORS = 5;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    struct Lock {
        address token;
        uint256 amount;
        uint256 unlockTime;
        address beneficiary;
        address depositor;
        bool withdrawn;
    }

    mapping(uint256 => Lock) public locks;
    mapping(address => bool) public isOperator;
    address[] public operators;
    mapping(address => uint256[]) public beneficiaryLocks;

    uint256 public feeBps;
    address public feeRecipient;
    uint256 public nextLockId;

    event TokensDeposited(
        uint256 indexed lockId,
        address indexed token,
        uint256 amount,
        uint256 fee,
        address indexed beneficiary,
        address depositor,
        uint256 unlockTime
    );
    event TokensWithdrawn(
        uint256 indexed lockId,
        address indexed beneficiary,
        address token,
        uint256 amount
    );
    event LockExtended(
        uint256 indexed lockId,
        uint256 newUnlockTime,
        uint256 additionalDuration
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event EmergencyWithdrawal(
        uint256 indexed lockId,
        address indexed operator,
        address indexed beneficiary,
        address token,
        uint256 amount
    );

    error LockNotFound();
    error LockNotExpired();
    error LockAlreadyWithdrawn();
    error NotAuthorized();
    error InvalidLockDuration();
    error InvalidDurationExtension();
    error ZeroAmount();
    error ZeroAddress();
    error MaxOperatorsExceeded();
    error NotOperator();
    error FeeExceedsMax();
    error AlreadyOperator();
    error NotAnOperator();

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert NotOperator();
        _;
    }

    modifier validLock(uint256 lockId) {
        if (lockId == 0 || lockId >= nextLockId) revert LockNotFound();
        _;
    }

    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        feeBps = MAX_FEE_BPS;
        nextLockId = 1;
    }

    function deposit(
        address token,
        uint256 amount,
        uint256 duration,
        address beneficiary
    ) external nonReentrant returns (uint256 lockId) {
        if (amount == 0) revert ZeroAmount();
        if (beneficiary == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (duration < MIN_LOCK_DURATION || duration > MAX_LOCK_DURATION)
            revert InvalidLockDuration();

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 lockAmount = amount - fee;
        if (lockAmount == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        if (fee > 0) {
            IERC20(token).safeTransfer(feeRecipient, fee);
        }

        lockId = nextLockId++;
        uint256 unlockTime = block.timestamp + duration;

        locks[lockId] = Lock({
            token: token,
            amount: lockAmount,
            unlockTime: unlockTime,
            beneficiary: beneficiary,
            depositor: msg.sender,
            withdrawn: false
        });

        beneficiaryLocks[beneficiary].push(lockId);

        emit TokensDeposited(lockId, token, lockAmount, fee, beneficiary, msg.sender, unlockTime);
    }

    function withdraw(uint256 lockId) external nonReentrant validLock(lockId) {
        Lock storage lock = locks[lockId];
        if (lock.withdrawn) revert LockAlreadyWithdrawn();
        if (msg.sender != lock.beneficiary) revert NotAuthorized();
        if (block.timestamp < lock.unlockTime) revert LockNotExpired();

        lock.withdrawn = true;
        uint256 amount = lock.amount;
        address token = lock.token;
        address beneficiary = lock.beneficiary;

        IERC20(token).safeTransfer(beneficiary, amount);

        emit TokensWithdrawn(lockId, beneficiary, token, amount);
    }

    function extendLock(uint256 lockId, uint256 additionalDuration)
        external
        nonReentrant
        validLock(lockId)
    {
        Lock storage lock = locks[lockId];
        if (lock.withdrawn) revert LockAlreadyWithdrawn();
        if (msg.sender != lock.depositor && msg.sender != lock.beneficiary)
            revert NotAuthorized();
        if (additionalDuration == 0) revert InvalidDurationExtension();

        uint256 newUnlockTime = lock.unlockTime + additionalDuration;
        if (newUnlockTime > block.timestamp + MAX_LOCK_DURATION)
            revert InvalidDurationExtension();

        lock.unlockTime = newUnlockTime;

        emit LockExtended(lockId, newUnlockTime, additionalDuration);
    }

    function emergencyWithdraw(uint256 lockId)
        external
        onlyOperator
        nonReentrant
        validLock(lockId)
    {
        Lock storage lock = locks[lockId];
        if (lock.withdrawn) revert LockAlreadyWithdrawn();

        lock.withdrawn = true;
        uint256 amount = lock.amount;
        address token = lock.token;
        address beneficiary = lock.beneficiary;

        IERC20(token).safeTransfer(beneficiary, amount);

        emit EmergencyWithdrawal(lockId, msg.sender, beneficiary, token, amount);
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMax();
        uint256 oldFee = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(oldFee, _feeBps);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(old, _feeRecipient);
    }

    function addOperator(address operator) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        if (isOperator[operator]) revert AlreadyOperator();
        if (operators.length >= MAX_OPERATORS) revert MaxOperatorsExceeded();
        isOperator[operator] = true;
        operators.push(operator);
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        if (!isOperator[operator]) revert NotAnOperator();
        isOperator[operator] = false;
        uint256 len = operators.length;
        for (uint256 i = 0; i < len; i++) {
            if (operators[i] == operator) {
                operators[i] = operators[len - 1];
                operators.pop();
                break;
            }
        }
        emit OperatorRemoved(operator);
    }

    function getOperators() external view returns (address[] memory) {
        return operators;
    }

    function getLock(uint256 lockId) external view validLock(lockId) returns (Lock memory) {
        return locks[lockId];
    }

    function getBeneficiaryLocks(address beneficiary)
        external
        view
        returns (uint256[] memory)
    {
        return beneficiaryLocks[beneficiary];
    }

    function operatorCount() external view returns (uint256) {
        return operators.length;
    }

    function totalLocks() external view returns (uint256) {
        return nextLockId - 1;
    }
}
