// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, currentAllowance + value));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < requestedDecrease) {
            revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        unchecked {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, currentAllowance - requestedDecrease));
        }
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
                revert SafeERC20FailedOperation(address(token));
            }
        }
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) {
                revert SafeERC20FailedOperation(address(token));
            }
        }
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

contract CrossChainAutomation is ReentrancyGuard, IERC165 {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error ZeroAddress();
    error InsufficientBalance(uint256 available, uint256 required);
    error TaskNotPending(uint256 taskId);
    error TaskNotCompleted(uint256 taskId);
    error InvalidFee(uint256 feeBps, uint256 maxFeeBps);
    error InvalidChainId(uint256 chainId);
    error EmptyAction();
    error TaskAlreadyProcessed(uint256 taskId);
    error NothingToClaim(address user);
    error InvalidOperator();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);
    event TaskCreated(
        uint256 indexed taskId,
        address indexed creator,
        uint256 indexed targetChainId,
        bytes actionParams,
        uint256 committedAmount
    );
    event TaskCancelled(uint256 indexed taskId, address indexed creator, uint256 refundedAmount);
    event OperationResultProcessed(
        uint256 indexed taskId,
        address indexed operator,
        bool approved,
        uint256 feeAmount,
        uint256 payoutAmount
    );
    event TokensClaimed(address indexed user, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed operator, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_FEE_BPS = 100; // 1%
    uint256 public constant DEFAULT_FEE_BPS = 10; // 0.1%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable token;

    address public operator;
    uint256 public feeBps;

    mapping(address => uint256) public depositedBalance;
    mapping(address => uint256) public claimableBalance;

    enum TaskStatus {
        Pending,
        Approved,
        Rejected,
        Cancelled
    }

    struct Task {
        address creator;
        uint256 targetChainId;
        bytes actionParams;
        uint256 committedAmount;
        TaskStatus status;
        uint256 createdAt;
    }

    uint256 public nextTaskId;
    mapping(uint256 => Task) public tasks;

    uint256 public accumulatedFees;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        operator = operator_;
        feeBps = DEFAULT_FEE_BPS;
        nextTaskId = 1;
        emit OperatorUpdated(address(0), operator_);
        emit FeeUpdated(address(0), 0, feeBps);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                              DEPOSIT/WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InsufficientBalance(0, 1);
        token.safeTransferFrom(msg.sender, address(this), amount);
        depositedBalance[msg.sender] += amount;
        emit Deposited(msg.sender, amount, depositedBalance[msg.sender]);
    }

    function withdraw(uint256 amount) external nonReentrant {
        uint256 balance = depositedBalance[msg.sender];
        if (amount > balance) revert InsufficientBalance(balance, amount);
        depositedBalance[msg.sender] = balance - amount;
        token.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, depositedBalance[msg.sender]);
    }

    /*//////////////////////////////////////////////////////////////
                              TASK CREATION
    //////////////////////////////////////////////////////////////*/
    function createTask(uint256 targetChainId, bytes calldata actionParams, uint256 amount)
        external
        nonReentrant
        returns (uint256 taskId)
    {
        if (targetChainId == 0) revert InvalidChainId(targetChainId);
        if (actionParams.length == 0) revert EmptyAction();
        if (amount == 0) revert InsufficientBalance(0, 1);

        uint256 balance = depositedBalance[msg.sender];
        if (amount > balance) revert InsufficientBalance(balance, amount);

        depositedBalance[msg.sender] = balance - amount;

        taskId = nextTaskId++;
        tasks[taskId] = Task({
            creator: msg.sender,
            targetChainId: targetChainId,
            actionParams: actionParams,
            committedAmount: amount,
            status: TaskStatus.Pending,
            createdAt: block.timestamp
        });

        emit TaskCreated(taskId, msg.sender, targetChainId, actionParams, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              TASK CANCELLATION
    //////////////////////////////////////////////////////////////*/
    function cancelTask(uint256 taskId) external nonReentrant {
        Task storage task = tasks[taskId];
        if (task.creator != msg.sender) revert Unauthorized();
        if (task.status != TaskStatus.Pending) revert TaskNotPending(taskId);

        task.status = TaskStatus.Cancelled;
        uint256 refund = task.committedAmount;
        depositedBalance[msg.sender] += refund;

        emit TaskCancelled(taskId, msg.sender, refund);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR OPERATIONS
    //////////////////////////////////////////////////////////////*/
    function processOperationResult(uint256 taskId, bool approved) external onlyOperator nonReentrant {
        Task storage task = tasks[taskId];
        if (task.status != TaskStatus.Pending) revert TaskAlreadyProcessed(taskId);

        uint256 amount = task.committedAmount;

        if (approved) {
            task.status = TaskStatus.Approved;
            uint256 feeAmount = (amount * feeBps) / BPS_DENOMINATOR;
            uint256 payoutAmount = amount - feeAmount;
            accumulatedFees += feeAmount;
            claimableBalance[task.creator] += payoutAmount;
            emit OperationResultProcessed(taskId, msg.sender, true, feeAmount, payoutAmount);
        } else {
            task.status = TaskStatus.Rejected;
            depositedBalance[task.creator] += amount;
            emit OperationResultProcessed(taskId, msg.sender, false, 0, amount);
        }
    }

    function setFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee(newFeeBps, MAX_FEE_BPS);
        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(msg.sender, oldFeeBps, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function withdrawFees(uint256 amount) external onlyOperator nonReentrant {
        if (amount > accumulatedFees) revert InsufficientBalance(accumulatedFees, amount);
        accumulatedFees -= amount;
        token.safeTransfer(msg.sender, amount);
        emit FeesWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              CLAIMING
    //////////////////////////////////////////////////////////////*/
    function claim() external nonReentrant {
        uint256 amount = claimableBalance[msg.sender];
        if (amount == 0) revert NothingToClaim(msg.sender);
        claimableBalance[msg.sender] = 0;
        token.safeTransfer(msg.sender, amount);
        emit TokensClaimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }

    function getClaimableBalance(address user) external view returns (uint256) {
        return claimableBalance[user];
    }

    function getDepositedBalance(address user) external view returns (uint256) {
        return depositedBalance[user];
    }

    function computeFee(uint256 amount) external view returns (uint256 feeAmount, uint256 payoutAmount) {
        feeAmount = (amount * feeBps) / BPS_DENOMINATOR;
        payoutAmount = amount - feeAmount;
    }
}
