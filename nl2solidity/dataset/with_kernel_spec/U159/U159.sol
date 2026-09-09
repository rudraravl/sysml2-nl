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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        require(ok, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        require(ok, "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() public onlyOwner {
        address old = _owner;
        _owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }
}

abstract contract ReentrancyGuard {
    bool private _locked;

    constructor() {
        _locked = false;
    }

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
}

contract BaseAssetStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientStake();
    error NoPendingRewards();
    error UnbondingNotReady();
    error NoUnbondingRequest();
    error AlreadyUnbonding();
    error NotOperator();
    error UnbondingPeriodTooShort();
    error InvalidDuration();

    event StakeInitiated(address indexed staker, uint256 amount);
    event RewardsClaimed(address indexed staker, uint256 rewardAmount, uint256 fee);
    event UnbondingRequested(address indexed staker, uint256 amount, uint256 withdrawableAt);
    event UnbondedWithdrawn(address indexed staker, uint256 amount);
    event RewardsDeposited(address indexed operator, uint256 amount, uint256 duration);
    event UnbondingPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);

    uint256 public constant FEE_BASIS_POINTS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_UNBONDING_PERIOD = 1 days;
    uint256 public constant MIN_REWARDS_DURATION = 1 hours;
    uint256 public constant REWARD_PRECISION = 1e18;

    IERC20 public immutable baseAsset;
    IERC20 public immutable rewardToken;

    address public operator;
    address public feeCollector;
    uint256 public unbondingPeriod;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    uint256 public pendingRewards;

    struct StakerPosition {
        uint256 stakedAmount;
        uint256 rewardPerTokenPaid;
        uint256 accumulatedRewards;
        uint256 unbondingAmount;
        uint256 unbondRequestTime;
    }

    mapping(address => StakerPosition) public stakers;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(
        address _baseAsset,
        address _rewardToken,
        address _operator,
        address _feeCollector
    ) Ownable(msg.sender) ReentrancyGuard() {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_rewardToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeCollector == address(0)) revert ZeroAddress();

        baseAsset = IERC20(_baseAsset);
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
        feeCollector = _feeCollector;
        unbondingPeriod = 14 days;

        emit OperatorUpdated(address(0), _operator);
        emit UnbondingPeriodUpdated(0, unbondingPeriod);
        emit FeeCollectorUpdated(address(0), _feeCollector);
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _updateReward(msg.sender);

        stakers[msg.sender].stakedAmount += amount;
        totalStaked += amount;

        if (pendingRewards > 0) {
            rewardPerTokenStored += (pendingRewards * REWARD_PRECISION) / totalStaked;
            pendingRewards = 0;
        }

        baseAsset.safeTransferFrom(address(this), amount);

        emit StakeInitiated(msg.sender, amount);
    }

    function claimRewards() external nonReentrant returns (uint256 netReward) {
        _updateReward(msg.sender);

        StakerPosition storage staker = stakers[msg.sender];
        uint256 reward = staker.accumulatedRewards;

        if (reward == 0) revert NoPendingRewards();

        staker.accumulatedRewards = 0;

        uint256 fee = (reward * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
        netReward = reward - fee;

        if (fee > 0) {
            rewardToken.safeTransfer(feeCollector, fee);
        }
        rewardToken.safeTransfer(msg.sender, netReward);

        emit RewardsClaimed(msg.sender, netReward, fee);
    }

    function requestUnbonding(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        StakerPosition storage staker = stakers[msg.sender];
        if (staker.stakedAmount < amount) revert InsufficientStake();
        if (staker.unbondingAmount > 0) revert AlreadyUnbonding();

        _updateReward(msg.sender);

        staker.stakedAmount -= amount;
        staker.unbondingAmount = amount;
        staker.unbondRequestTime = block.timestamp;
        totalStaked -= amount;

        emit UnbondingRequested(msg.sender, amount, block.timestamp + unbondingPeriod);
    }

    function withdrawUnbonded() external nonReentrant {
        StakerPosition storage staker = stakers[msg.sender];

        if (staker.unbondingAmount == 0) revert NoUnbondingRequest();
        if (block.timestamp < staker.unbondRequestTime + unbondingPeriod) revert UnbondingNotReady();

        uint256 amount = staker.unbondingAmount;
        staker.unbondingAmount = 0;
        staker.unbondRequestTime = 0;

        baseAsset.safeTransfer(msg.sender, amount);

        emit UnbondedWithdrawn(msg.sender, amount);
    }

    function depositRewards(uint256 amount, uint256 duration) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (duration < MIN_REWARDS_DURATION) revert InvalidDuration();

        _updateReward(address(0));

        if (block.timestamp >= periodFinish) {
            rewardRate = amount / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (amount + leftover) / duration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;

        rewardToken.safeTransferFrom(address(this), amount);

        emit RewardsDeposited(msg.sender, amount, duration);
    }

    function setUnbondingPeriod(uint256 newPeriod) external onlyOperator {
        if (newPeriod < MIN_UNBONDING_PERIOD) revert UnbondingPeriodTooShort();
        uint256 oldPeriod = unbondingPeriod;
        unbondingPeriod = newPeriod;
        emit UnbondingPeriodUpdated(oldPeriod, newPeriod);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        if (newFeeCollector == address(0)) revert ZeroAddress();
        address old = feeCollector;
        feeCollector = newFeeCollector;
        emit FeeCollectorUpdated(old, newFeeCollector);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * REWARD_PRECISION) /
            totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        StakerPosition storage staker = stakers[account];
        return
            (staker.stakedAmount * (rewardPerToken() - staker.rewardPerTokenPaid)) /
            REWARD_PRECISION +
            staker.accumulatedRewards;
    }

    function getRewardForDuration() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        return rewardRate * (periodFinish - block.timestamp);
    }

    function unbondingReadyAt(address account) external view returns (uint256) {
        StakerPosition storage staker = stakers[account];
        if (staker.unbondingAmount == 0) return 0;
        return staker.unbondRequestTime + unbondingPeriod;
    }

    function _updateReward(address account) internal {
        uint256 applicableTime = lastTimeRewardApplicable();

        if (totalStaked == 0) {
            if (applicableTime > lastUpdateTime) {
                pendingRewards += (applicableTime - lastUpdateTime) * rewardRate;
            }
        } else if (pendingRewards > 0) {
            rewardPerTokenStored += (pendingRewards * REWARD_PRECISION) / totalStaked;
            pendingRewards = 0;
        }

        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = applicableTime;

        if (account != address(0)) {
            StakerPosition storage staker = stakers[account];
            staker.accumulatedRewards = earned(account);
            staker.rewardPerTokenPaid = rewardPerTokenStored;
        }
    }
}
