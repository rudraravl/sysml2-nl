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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFromSender(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transferFrom(msg.sender, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidAccount(address account);

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidAccount(address(0));
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address previousOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
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

contract StakingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_REWARD_RATE = 100;
    uint256 public constant MIN_STAKE_BLOCKS = 100;
    uint256 private constant PRECISION = 1e18;

    IERC20 public immutable stakingToken;
    address public operator;

    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public lastDepositBlock;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardsDistributed(address indexed operator, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error ZeroAmount();
    error InsufficientStake();
    error StakingPeriodNotElapsed(uint256 remaining);
    error RewardRateTooHigh(uint256 rate);
    error NoRewardsToClaim();
    error InvalidAddress();
    error TransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stakingToken, address _operator, uint256 _initialRate) {
        if (_stakingToken == address(0) || _operator == address(0)) revert InvalidAddress();
        if (_initialRate > MAX_REWARD_RATE) revert RewardRateTooHigh(_initialRate);

        stakingToken = IERC20(_stakingToken);
        operator = _operator;
        rewardRate = _initialRate;
        lastUpdateBlock = block.number;

        emit OperatorUpdated(address(0), _operator);
        emit RewardRateUpdated(0, _initialRate);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((block.number - lastUpdateBlock) * rewardRate * PRECISION) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / PRECISION + rewards[account];
    }

    function getStakeInfo(address account) external view returns (uint256 staked, uint256 pending) {
        staked = stakedBalance[account];
        pending = earned(account);
    }

    function getRewardPerToken() external view returns (uint256) {
        return rewardPerToken();
    }

    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateReward(msg.sender);

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        lastDepositBlock[msg.sender] = block.number;

        SafeERC20.safeTransferFromSender(stakingToken, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStake();

        uint256 elapsed = block.number - lastDepositBlock[msg.sender];
        if (elapsed < MIN_STAKE_BLOCKS) revert StakingPeriodNotElapsed(MIN_STAKE_BLOCKS - elapsed);

        _updateReward(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward < 1) revert NoRewardsToClaim();

        rewards[msg.sender] = 0;

        stakingToken.safeTransfer(msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    function setRewardRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_REWARD_RATE) revert RewardRateTooHigh(newRate);

        _updateReward(address(0));

        uint256 oldRate = rewardRate;
        rewardRate = newRate;

        emit RewardRateUpdated(oldRate, newRate);
    }

    function distributeRewards(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();

        SafeERC20.safeTransferFromSender(stakingToken, address(this), amount);

        emit RewardsDistributed(msg.sender, amount);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();

        address oldOperator = operator;
        operator = newOperator;

        emit OperatorUpdated(oldOperator, newOperator);
    }
}
