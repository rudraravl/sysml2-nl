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

interface IStakingPool {
    function stake(uint256 amount) external returns (bool);
    function unstake(uint256 amount) external returns (uint256);
    function claimRewards() external returns (uint256);
}

contract LiquidStakingProtocol {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus;

    string public constant name = "Liquid Staked Token";
    string public constant symbol = "LST";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable underlyingAsset;
    IStakingPool public stakingPool;

    uint256 public totalDeposited;
    uint256 public totalStaked;
    uint256 public totalUnbonded;
    uint256 public totalRewardsDistributed;

    address public owner;
    address public pendingOwner;
    address public operator;

    uint256 public protocolFeeBps;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public accruedFees;

    bool public paused;
    address public implementation;
    uint256 public version;

    uint256 public constant UNBONDING_PERIOD = 7 days;

    uint256 public rewardIndex;
    mapping(address => uint256) public userRewardIndex;
    mapping(address => uint256) public userRewardsPending;

    struct WithdrawalRequest {
        address requester;
        uint256 underlyingAmount;
        uint256 requestTime;
        bool claimed;
    }
    WithdrawalRequest[] public withdrawalRequests;
    mapping(address => uint256[]) public userWithdrawalRequests;

    event Deposit(address indexed user, uint256 underlyingAmount, uint256 lstMinted);
    event WithdrawalRequested(address indexed user, uint256 indexed requestId, uint256 underlyingAmount);
    event WithdrawalClaimed(address indexed user, uint256 indexed requestId, uint256 underlyingAmount);
    event RewardsDistributed(address indexed operator, uint256 rewardAmount, uint256 feeAmount);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event Staked(address indexed operator, uint256 amount);
    event Unstaked(address indexed operator, uint256 amount);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed operator, address indexed to, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event Upgraded(address indexed newImplementation, uint256 newVersion);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error NotOwner();
    error NotOperator();
    error NotPendingOwner();
    error EnforcedPause();
    error ExpectedPause();
    error ZeroAddress();
    error FeeExceedsMax();
    error AmountIsZero();
    error TransferFailed();
    error InsufficientUnbonded();
    error InsufficientBalance();
    error InsufficientAllowance();
    error UnbondingNotComplete();
    error AlreadyClaimed();
    error RequestNotFound();
    error NotRequester();
    error NoStakers();
    error NoPendingRewards();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    constructor(address _underlyingAsset, address _stakingPool, address _operator) {
        if (_underlyingAsset == address(0)) revert ZeroAddress();
        if (_stakingPool == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        _reentrancyStatus = _NOT_ENTERED;
        underlyingAsset = IERC20(_underlyingAsset);
        stakingPool = IStakingPool(_stakingPool);
        operator = _operator;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        _updateReward(from);
        _updateReward(to);
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _updateReward(address user) internal {
        uint256 idx = rewardIndex;
        if (balanceOf[user] > 0 && idx > userRewardIndex[user]) {
            uint256 owed = (balanceOf[user] * (idx - userRewardIndex[user])) / 1e18;
            userRewardsPending[user] += owed;
        }
        userRewardIndex[user] = idx;
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant returns (uint256) {
        if (amount == 0) revert AmountIsZero();

        _updateReward(msg.sender);
        _mint(msg.sender, amount);
        totalDeposited += amount;
        totalUnbonded += amount;

        if (!underlyingAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(msg.sender, amount, amount);
        return amount;
    }

    function stake(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert AmountIsZero();
        if (totalUnbonded < amount) revert InsufficientUnbonded();

        totalUnbonded -= amount;
        totalStaked += amount;

        if (!underlyingAsset.approve(address(stakingPool), amount)) revert TransferFailed();
        if (!stakingPool.stake(amount)) revert TransferFailed();

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert AmountIsZero();
        if (totalStaked < amount) revert InsufficientBalance();

        totalStaked -= amount;

        uint256 received = stakingPool.unstake(amount);
        if (received < amount) revert TransferFailed();

        totalUnbonded += received;

        emit Unstaked(msg.sender, received);
    }

    function distributeRewards() external onlyOperator nonReentrant returns (uint256) {
        if (totalSupply == 0) revert NoStakers();

        uint256 received = stakingPool.claimRewards();
        if (received < 1) revert AmountIsZero();

        uint256 fee = (received * protocolFeeBps) / 10000;
        uint256 distributable = received - fee;

        accruedFees += fee;
        totalUnbonded += received;
        rewardIndex += (distributable * 1e18) / totalSupply;
        totalRewardsDistributed += distributable;

        emit RewardsDistributed(msg.sender, distributable, fee);
        return distributable;
    }

    function claimRewards() external nonReentrant returns (uint256) {
        _updateReward(msg.sender);
        uint256 pending = userRewardsPending[msg.sender];
        if (pending < 1) revert NoPendingRewards();

        userRewardsPending[msg.sender] = 0;
        if (totalUnbonded < pending) revert InsufficientUnbonded();
        totalUnbonded -= pending;

        if (!underlyingAsset.transfer(msg.sender, pending)) revert TransferFailed();

        emit RewardsClaimed(msg.sender, pending);
        return pending;
    }

    function requestWithdrawal(uint256 lstAmount) external whenNotPaused nonReentrant returns (uint256) {
        if (lstAmount == 0) revert AmountIsZero();

        _updateReward(msg.sender);
        _burn(msg.sender, lstAmount);

        uint256 requestId = withdrawalRequests.length;
        withdrawalRequests.push(
            WithdrawalRequest({
                requester: msg.sender,
                underlyingAmount: lstAmount,
                requestTime: block.timestamp,
                claimed: false
            })
        );
        userWithdrawalRequests[msg.sender].push(requestId);

        emit WithdrawalRequested(msg.sender, requestId, lstAmount);
        return requestId;
    }

    function claimWithdrawal(uint256 requestId) external whenNotPaused nonReentrant returns (uint256) {
        if (requestId >= withdrawalRequests.length) revert RequestNotFound();
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requester != msg.sender) revert NotRequester();
        if (req.claimed) revert AlreadyClaimed();
        if (block.timestamp < req.requestTime + UNBONDING_PERIOD) revert UnbondingNotComplete();
        if (totalUnbonded < req.underlyingAmount) revert InsufficientUnbonded();

        req.claimed = true;
        totalUnbonded -= req.underlyingAmount;

        if (!underlyingAsset.transfer(msg.sender, req.underlyingAmount)) revert TransferFailed();

        emit WithdrawalClaimed(msg.sender, requestId, req.underlyingAmount);
        return req.underlyingAmount;
    }

    function setProtocolFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMax();
        uint256 old = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(old, newFeeBps);
    }

    function withdrawFees(address to) external onlyOperator nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees;
        if (amount < 1) revert AmountIsZero();
        if (totalUnbonded < amount) revert InsufficientUnbonded();

        accruedFees = 0;
        totalUnbonded -= amount;

        if (!underlyingAsset.transfer(to, amount)) revert TransferFailed();

        emit FeesWithdrawn(msg.sender, to, amount);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert ExpectedPause();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        implementation = newImplementation;
        unchecked {
            version += 1;
        }
        emit Upgraded(newImplementation, version);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 idx = rewardIndex;
        uint256 owed = 0;
        if (balanceOf[user] > 0 && idx > userRewardIndex[user]) {
            owed = (balanceOf[user] * (idx - userRewardIndex[user])) / 1e18;
        }
        return userRewardsPending[user] + owed;
    }

    function getWithdrawalRequest(uint256 requestId)
        external
        view
        returns (address requester, uint256 underlyingAmount, uint256 requestTime, bool claimed)
    {
        if (requestId >= withdrawalRequests.length) revert RequestNotFound();
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        return (req.requester, req.underlyingAmount, req.requestTime, req.claimed);
    }

    function withdrawalRequestCount() external view returns (uint256) {
        return withdrawalRequests.length;
    }

    function getUserWithdrawalRequests(address user) external view returns (uint256[] memory) {
        return userWithdrawalRequests[user];
    }

    function totalUnderlying() external view returns (uint256) {
        return totalUnbonded + totalStaked;
    }
}
