// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract TokenVault {
    // ---------------------------------------------------------------------
    // Immutable & constant configuration
    // ---------------------------------------------------------------------
    IERC20 public immutable stakingToken;
    address public operator;
    address public owner;

    uint256 public constant MIN_DEPOSIT = 100e18;
    uint256 public constant MAX_REWARD_RATE = 5e16; // 0.05 tokens per second per staked token
    uint256 public constant REWARD_SCALE = 1e18;

    // ---------------------------------------------------------------------
    // Reward accounting
    // ---------------------------------------------------------------------
    uint256 public rewardRate; // reward tokens per staked token per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;

    mapping(address => uint256) public depositedBalance;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    bool public stakingPaused;
    uint256 private _locked = 1;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposited(address indexed user, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event StakingPaused(bool paused);
    event RewardsClaimed(address indexed user, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error DepositTooSmall(uint256 amount, uint256 minRequired);
    error InsufficientBalance(uint256 available, uint256 requested);
    error RewardRateTooHigh(uint256 provided, uint256 maximum);
    error StakingIsPaused();
    error Unauthorized(address caller);
    error TransferFailed();
    error ReentrancyDetected();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized(msg.sender);
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _stakingToken, address _operator) {
        if (_stakingToken == address(0) || _operator == address(0)) revert ZeroAddress();
        stakingToken = IERC20(_stakingToken);
        operator = _operator;
        owner = msg.sender;
        lastUpdateTime = block.timestamp;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    // View helpers
    // ---------------------------------------------------------------------
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 timeDelta = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + (rewardRate * timeDelta);
    }

    function earned(address user) public view returns (uint256) {
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 userPaid = userRewardPerTokenPaid[user];
        if (currentRewardPerToken < userPaid) {
            return rewards[user];
        }
        return (stakedBalance[user] * (currentRewardPerToken - userPaid)) / REWARD_SCALE + rewards[user];
    }

    // ---------------------------------------------------------------------
    // Internal accounting
    // ---------------------------------------------------------------------
    function _updateReward(address user) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (user != address(0)) {
            rewards[user] = earned(user);
            userRewardPerTokenPaid[user] = rewardPerTokenStored;
        }
    }

    // ---------------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------------
    function deposit(uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);
        depositedBalance[msg.sender] += amount;
        bool ok = stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit Deposited(msg.sender, amount);
    }

    function stake(uint256 amount) external nonReentrant {
        if (stakingPaused) revert StakingIsPaused();
        if (amount == 0) revert ZeroAmount();
        if (depositedBalance[msg.sender] < amount)
            revert InsufficientBalance(depositedBalance[msg.sender], amount);

        _updateReward(msg.sender);

        depositedBalance[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount)
            revert InsufficientBalance(stakedBalance[msg.sender], amount);

        _updateReward(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        depositedBalance[msg.sender] += amount;

        emit Unstaked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (depositedBalance[msg.sender] < amount)
            revert InsufficientBalance(depositedBalance[msg.sender], amount);

        depositedBalance[msg.sender] -= amount;
        bool ok = stakingToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            bool ok = stakingToken.transfer(msg.sender, reward);
            if (!ok) revert TransferFailed();
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    // ---------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------
    function setRewardRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_REWARD_RATE)
            revert RewardRateTooHigh(newRate, MAX_REWARD_RATE);

        _updateReward(address(0));

        uint256 oldRate = rewardRate;
        rewardRate = newRate;

        emit RewardRateUpdated(oldRate, newRate);
    }

    function setStakingPaused(bool paused) external onlyOperator {
        stakingPaused = paused;
        emit StakingPaused(paused);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
