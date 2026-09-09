// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let p := mload(returndata)
                    revert(p, returndata)
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

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert("Ownable: zero address");
        }
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract DecentralizedTaskExecutor is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_STAKE = 100 * 10 ** 18;
    uint256 public constant CLAIM_WINDOW = 24 hours;

    enum JobStatus { Pending, Assigned, Completed, Cancelled, Claimed }

    struct Job {
        address creator;
        bytes parameters;
        uint256 reward;
        JobStatus status;
        address assignedKeeper;
        uint64 createdAt;
        uint64 completedAt;
        uint64 deadline;
    }

    struct Keeper {
        uint256 stakedAmount;
        bool isRegistered;
        uint256 activeJobCount;
    }

    IERC20 public immutable collateralToken;
    uint256 public baseReward;
    uint256 public rewardPool;
    uint256 public jobCount;

    mapping(uint256 => Job) public jobs;
    mapping(address => Keeper) public keepers;
    address[] public keeperList;
    mapping(address => uint256) private _keeperIndex;

    event JobRegistered(
        uint256 indexed jobId,
        address indexed creator,
        bytes parameters,
        uint256 reward,
        uint64 deadline
    );

    event JobUpdated(
        uint256 indexed jobId,
        address indexed creator,
        bytes newParameters,
        uint256 additionalReward,
        uint64 newDeadline
    );

    event JobCancelled(uint256 indexed jobId, address indexed creator, uint256 refundedReward);

    event KeeperRegistered(address indexed keeper, uint256 stakedAmount);

    event StakeIncreased(address indexed keeper, uint256 newStakedAmount);

    event StakeWithdrawn(address indexed keeper, uint256 amount);

    event KeeperUnregistered(address indexed keeper, uint256 withdrawnAmount);

    event JobAssigned(uint256 indexed jobId, address indexed keeper);

    event JobUnassigned(uint256 indexed jobId, address indexed oldKeeper);

    event JobCompleted(uint256 indexed jobId, address indexed keeper, uint256 totalReward);

    event RewardClaimed(uint256 indexed jobId, address indexed keeper, uint256 amount);

    event BaseRewardUpdated(uint256 oldBaseReward, uint256 newBaseReward);

    event RewardPoolFunded(address indexed funder, uint256 amount);

    error ZeroAddress();
    error AmountZero();
    error EmptyParameters();
    error JobNotFound();
    error NotJobCreator();
    error JobNotPending();
    error JobNotAssigned();
    error JobNotCompleted();
    error DeadlineInPast();
    error JobExpired();
    error InsufficientStake();
    error KeeperAlreadyRegistered();
    error KeeperNotRegistered();
    error ActiveJobsNonZero();
    error NotEnoughStaked();
    error NotAssignedKeeper();
    error ClaimWindowExpired();
    error ClaimWindowNotExpired();
    error InsufficientRewardPool();

    constructor(address _collateralToken, uint256 _baseReward) Ownable(msg.sender) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        baseReward = _baseReward;
    }

    function setBaseReward(uint256 _baseReward) external onlyOwner {
        uint256 old = baseReward;
        baseReward = _baseReward;
        emit BaseRewardUpdated(old, _baseReward);
    }

    function fundRewardPool(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert AmountZero();
        rewardPool += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardPoolFunded(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function registerJob(
        bytes calldata parameters,
        uint256 reward,
        uint64 deadline
    ) external whenNotPaused nonReentrant returns (uint256 jobId) {
        if (parameters.length == 0) revert EmptyParameters();
        if (deadline != 0 && deadline <= block.timestamp) revert DeadlineInPast();

        jobId = jobCount++;
        jobs[jobId] = Job({
            creator: msg.sender,
            parameters: parameters,
            reward: reward,
            status: JobStatus.Pending,
            assignedKeeper: address(0),
            createdAt: uint64(block.timestamp),
            completedAt: 0,
            deadline: deadline
        });

        if (reward > 0) {
            collateralToken.safeTransferFrom(msg.sender, address(this), reward);
        }

        emit JobRegistered(jobId, msg.sender, parameters, reward, deadline);
    }

    function updateJob(
        uint256 jobId,
        bytes calldata newParameters,
        uint256 additionalReward,
        uint64 newDeadline
    ) external whenNotPaused nonReentrant {
        Job storage job = jobs[jobId];
        if (job.creator == address(0)) revert JobNotFound();
        if (job.creator != msg.sender) revert NotJobCreator();
        if (job.status != JobStatus.Pending) revert JobNotPending();
        if (newParameters.length == 0) revert EmptyParameters();
        if (newDeadline != 0 && newDeadline <= block.timestamp) revert DeadlineInPast();

        if (additionalReward > 0) {
            job.reward += additionalReward;
        }

        job.parameters = newParameters;
        job.deadline = newDeadline;

        if (additionalReward > 0) {
            collateralToken.safeTransferFrom(msg.sender, address(this), additionalReward);
        }

        emit JobUpdated(jobId, msg.sender, newParameters, additionalReward, newDeadline);
    }

    function cancelJob(uint256 jobId) external whenNotPaused nonReentrant {
        Job storage job = jobs[jobId];
        if (job.creator == address(0)) revert JobNotFound();
        if (job.creator != msg.sender) revert NotJobCreator();
        if (job.status != JobStatus.Pending) revert JobNotPending();

        job.status = JobStatus.Cancelled;
        uint256 refund = job.reward;
        job.reward = 0;

        if (refund > 0) {
            collateralToken.safeTransfer(job.creator, refund);
        }

        emit JobCancelled(jobId, msg.sender, refund);
    }

    function registerKeeper(uint256 stakeAmount) external whenNotPaused nonReentrant {
        if (keepers[msg.sender].isRegistered) revert KeeperAlreadyRegistered();
        if (stakeAmount < MIN_STAKE) revert InsufficientStake();

        keepers[msg.sender] = Keeper({
            stakedAmount: stakeAmount,
            isRegistered: true,
            activeJobCount: 0
        });
        _keeperIndex[msg.sender] = keeperList.length;
        keeperList.push(msg.sender);

        collateralToken.safeTransferFrom(msg.sender, address(this), stakeAmount);

        emit KeeperRegistered(msg.sender, stakeAmount);
    }

    function increaseStake(uint256 amount) external whenNotPaused nonReentrant {
        Keeper storage keeper = keepers[msg.sender];
        if (!keeper.isRegistered) revert KeeperNotRegistered();
        if (amount == 0) revert AmountZero();

        keeper.stakedAmount += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit StakeIncreased(msg.sender, keeper.stakedAmount);
    }

    function withdrawStake(uint256 amount) external whenNotPaused nonReentrant {
        Keeper storage keeper = keepers[msg.sender];
        if (!keeper.isRegistered) revert KeeperNotRegistered();
        if (keeper.activeJobCount > 0) revert ActiveJobsNonZero();
        if (amount == 0 || amount > keeper.stakedAmount) revert NotEnoughStaked();

        keeper.stakedAmount -= amount;

        bool willUnregister = keeper.stakedAmount < MIN_STAKE;
        if (willUnregister) {
            keeper.isRegistered = false;
            _removeFromKeeperList(msg.sender);
        }

        collateralToken.safeTransfer(msg.sender, amount);

        if (willUnregister) {
            emit KeeperUnregistered(msg.sender, amount);
        } else {
            emit StakeWithdrawn(msg.sender, amount);
        }
    }

    function signalReadiness(uint256 jobId) external whenNotPaused {
        Job storage job = jobs[jobId];
        if (job.creator == address(0)) revert JobNotFound();
        if (job.status != JobStatus.Pending) revert JobNotPending();
        if (!keepers[msg.sender].isRegistered) revert KeeperNotRegistered();
        if (job.deadline != 0 && block.timestamp > job.deadline) revert JobExpired();

        job.status = JobStatus.Assigned;
        job.assignedKeeper = msg.sender;
        keepers[msg.sender].activeJobCount += 1;

        emit JobAssigned(jobId, msg.sender);
    }

    function revokeAssignment(uint256 jobId) external whenNotPaused {
        Job storage job = jobs[jobId];
        if (job.creator == address(0)) revert JobNotFound();
        if (job.creator != msg.sender) revert NotJobCreator();
        if (job.status != JobStatus.Assigned) revert JobNotAssigned();

        address oldKeeper = job.assignedKeeper;
        if (keepers[oldKeeper].activeJobCount > 0) {
            keepers[oldKeeper].activeJobCount -= 1;
        }

        job.status = JobStatus.Pending;
        job.assignedKeeper = address(0);

        emit JobUnassigned(jobId, oldKeeper);
    }

    function confirmCompletion(uint256 jobId) external whenNotPaused {
        Job storage job = jobs[jobId];
        if (job.creator == address(0)) revert JobNotFound();
        if (job.creator != msg.sender) revert NotJobCreator();
        if (job.status != JobStatus.Assigned) revert JobNotAssigned();

        job.status = JobStatus.Completed;
        job.completedAt = uint64(block.timestamp);

        address keeper = job.assignedKeeper;
        if (keepers[keeper].activeJobCount > 0) {
            keepers[keeper].activeJobCount -= 1;
        }

        emit JobCompleted(jobId, keeper, job.reward + baseReward);
    }

    function claimReward(uint256 jobId) external whenNotPaused nonReentrant {
        Job storage job = jobs[jobId];
        if (job.creator == address(0)) revert JobNotFound();
        if (job.status != JobStatus.Completed) revert JobNotCompleted();
        if (job.assignedKeeper != msg.sender) revert NotAssignedKeeper();
        if (block.timestamp > job.completedAt + CLAIM_WINDOW) revert ClaimWindowExpired();

        uint256 totalReward = job.reward + baseReward;
        if (baseReward > rewardPool) revert InsufficientRewardPool();

        rewardPool -= baseReward;
        job.status = JobStatus.Claimed;
        job.reward = 0;

        collateralToken.safeTransfer(msg.sender, totalReward);

        emit RewardClaimed(jobId, msg.sender, totalReward);
    }

    function reclaimExpiredReward(uint256 jobId) external whenNotPaused nonReentrant {
        Job storage job = jobs[jobId];
        if (job.creator == address(0)) revert JobNotFound();
        if (job.creator != msg.sender) revert NotJobCreator();
        if (job.status != JobStatus.Completed) revert JobNotCompleted();
        if (block.timestamp <= job.completedAt + CLAIM_WINDOW) revert ClaimWindowNotExpired();

        job.status = JobStatus.Cancelled;
        uint256 refund = job.reward;
        job.reward = 0;

        if (refund > 0) {
            collateralToken.safeTransfer(job.creator, refund);
        }

        emit JobCancelled(jobId, msg.sender, refund);
    }

    function getJob(uint256 jobId)
        external
        view
        returns (
            address creator,
            bytes memory parameters,
            uint256 reward,
            JobStatus status,
            address assignedKeeper,
            uint64 createdAt,
            uint64 completedAt,
            uint64 deadline
        )
    {
        Job storage job = jobs[jobId];
        return (
            job.creator,
            job.parameters,
            job.reward,
            job.status,
            job.assignedKeeper,
            job.createdAt,
            job.completedAt,
            job.deadline
        );
    }

    function getKeeper(address keeperAddress)
        external
        view
        returns (uint256 stakedAmount, bool isRegistered, uint256 activeJobCount)
    {
        Keeper storage k = keepers[keeperAddress];
        return (k.stakedAmount, k.isRegistered, k.activeJobCount);
    }

    function getKeeperList() external view returns (address[] memory) {
        return keeperList;
    }

    function getKeeperCount() external view returns (uint256) {
        return keeperList.length;
    }

    function isKeeper(address account) external view returns (bool) {
        return keepers[account].isRegistered;
    }

    function getTotalReward(uint256 jobId) external view returns (uint256) {
        return jobs[jobId].reward + baseReward;
    }

    function _removeFromKeeperList(address keeper) internal {
        uint256 index = _keeperIndex[keeper];
        uint256 lastIndex = keeperList.length - 1;
        if (index < lastIndex) {
            address lastKeeper = keeperList[lastIndex];
            keeperList[index] = lastKeeper;
            _keeperIndex[lastKeeper] = index;
        }
        keeperList.pop();
        _keeperIndex[keeper] = 0;
    }
}
