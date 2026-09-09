// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract ContentCreatorRewards {
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_REWARD_RATE = 5e16; // 0.05 tokens per engagement unit, scaled by PRECISION
    uint16 public constant FEE_BIPS = 1000; // 10%
    uint16 public constant BIPS_DENOMINATOR = 10000;

    address public owner;
    address public rewardToken;
    address public treasury;
    uint256 public rewardRate;
    uint8 public tokenDecimals;
    bool public claimingPaused;

    uint256 public totalDeposited;
    uint256 public totalPendingRewards;
    uint256 public totalClaimed;
    uint256 public totalFeesCollected;
    uint256 public totalDistributed;

    mapping(address => uint256) public rewardBalance;
    mapping(address => uint256) public engagementScore;
    mapping(address => uint256) public totalClaimedByUser;
    mapping(address => bool) public isRegisteredCreator;

    address[] public creatorList;
    bool private _locked;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RewardTokenSet(address indexed previousToken, address indexed newToken);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event RewardRateUpdated(uint256 previousRate, uint256 newRate);
    event ClaimingPausedSet(bool paused);
    event RewardTokensDeposited(address indexed from, uint256 amount);
    event CreatorRegistered(address indexed creator);
    event EngagementRecorded(address indexed creator, uint256 engagementUnits, uint256 rewardAmount);
    event RewardsClaimed(address indexed user, uint256 netAmount, uint256 feeAmount);
    event TokenRecovered(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error NotOwner();
    error AlreadyRegistered();
    error NotRegisteredCreator();
    error RewardTokenNotSet();
    error RewardRateNotSet();
    error ZeroAmount();
    error RewardRateExceeded(uint256 rate, uint256 maxRate);
    error NoPendingRewards();
    error ClaimingPaused();
    error InsufficientPool();
    error TransferFailed();
    error PendingRewardsOutstanding();
    error TokenNotRecoverable();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (claimingPaused) revert ClaimingPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _owner, address _treasury) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        owner = _owner;
        treasury = _treasury;
        emit OwnershipTransferred(address(0), _owner);
        emit TreasuryUpdated(address(0), _treasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setRewardToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (rewardToken != address(0) && totalPendingRewards > 0) revert PendingRewardsOutstanding();
        uint8 decimals = IERC20(token).decimals();
        address previous = rewardToken;
        rewardToken = token;
        tokenDecimals = decimals;
        emit RewardTokenSet(previous, token);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address previous = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(previous, newTreasury);
    }

    function setRewardRate(uint256 rate) external onlyOwner {
        if (rate > MAX_REWARD_RATE) revert RewardRateExceeded(rate, MAX_REWARD_RATE);
        uint256 previous = rewardRate;
        rewardRate = rate;
        emit RewardRateUpdated(previous, rate);
    }

    function setClaimingPaused(bool paused) external onlyOwner {
        claimingPaused = paused;
        emit ClaimingPausedSet(paused);
    }

    function depositRewardTokens(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (rewardToken == address(0)) revert RewardTokenNotSet();

        // Effects: update internal accounting before the external transfer (CEI).
        totalDeposited += amount;

        // Interactions: pull tokens from the caller; revert on failure.
        IERC20 token = IERC20(rewardToken);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit RewardTokensDeposited(msg.sender, amount);
    }

    function registerCreator() external {
        if (isRegisteredCreator[msg.sender]) revert AlreadyRegistered();
        isRegisteredCreator[msg.sender] = true;
        creatorList.push(msg.sender);
        emit CreatorRegistered(msg.sender);
    }

    function recordEngagement(address creator, uint256 engagementUnits) external onlyOwner {
        if (creator == address(0)) revert ZeroAddress();
        if (!isRegisteredCreator[creator]) revert NotRegisteredCreator();
        if (engagementUnits == 0) revert ZeroAmount();
        if (rewardToken == address(0)) revert RewardTokenNotSet();
        if (rewardRate == 0) revert RewardRateNotSet();

        uint256 reward = (engagementUnits * rewardRate * (10 ** tokenDecimals)) / PRECISION;
        if (reward == 0) revert ZeroAmount();

        engagementScore[creator] += engagementUnits;
        rewardBalance[creator] += reward;
        totalPendingRewards += reward;

        emit EngagementRecorded(creator, engagementUnits, reward);
    }

    function claimRewards() external nonReentrant whenNotPaused {
        if (rewardToken == address(0)) revert RewardTokenNotSet();
        if (!isRegisteredCreator[msg.sender]) revert NotRegisteredCreator();

        uint256 amount = rewardBalance[msg.sender];
        if (amount == 0) revert NoPendingRewards();

        IERC20 token = IERC20(rewardToken);
        uint256 pool = token.balanceOf(address(this));
        if (pool < amount) revert InsufficientPool();

        uint256 fee = (amount * FEE_BIPS) / BIPS_DENOMINATOR;
        uint256 net = amount - fee;

        // Effects
        rewardBalance[msg.sender] = 0;
        totalPendingRewards -= amount;
        totalClaimed += amount;
        totalFeesCollected += fee;
        totalDistributed += net;
        totalClaimedByUser[msg.sender] += net;

        // Interactions
        if (fee > 0) {
            bool feeSuccess = token.transfer(treasury, fee);
            if (!feeSuccess) revert TransferFailed();
        }
        if (net > 0) {
            bool userSuccess = token.transfer(msg.sender, net);
            if (!userSuccess) revert TransferFailed();
        }

        emit RewardsClaimed(msg.sender, net, fee);
    }

    function recoverToken(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token == rewardToken) revert TokenNotRecoverable();
        bool success = IERC20(token).transfer(to, amount);
        if (!success) revert TransferFailed();
        emit TokenRecovered(token, to, amount);
    }

    function pendingRewards(address user) external view returns (uint256) {
        return rewardBalance[user];
    }

    function availablePool() external view returns (uint256) {
        if (rewardToken == address(0)) return 0;
        return IERC20(rewardToken).balanceOf(address(this));
    }

    function getCreatorCount() external view returns (uint256) {
        return creatorList.length;
    }

    function creatorAt(uint256 index) external view returns (address) {
        return creatorList[index];
    }

    function previewClaim(uint256 grossAmount) external pure returns (uint256 net, uint256 fee) {
        fee = (grossAmount * FEE_BIPS) / BIPS_DENOMINATOR;
        net = grossAmount - fee;
    }
}
