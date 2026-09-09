// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract GameTokenStaking {
    /* ------------------------------------------------------------------ */
    /*  State variables                                                    */
    /* ------------------------------------------------------------------ */

    IERC20 public immutable stakingToken;

    address public operator;

    uint256 public totalStaked;
    uint256 public rewardPool;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    /// @notice Reward rate in basis points per day (1 = 0.01%, 100 = 1%).
    uint256 public rateBps;

    uint256 public constant MIN_RATE_BPS = 1;    // 0.01%
    uint256 public constant MAX_RATE_BPS = 100;  // 1%
    uint256 public constant SECONDS_PER_DAY = 86_400;
    uint256 public constant PRECISION = 1e18;

    struct UserInfo {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 userRewardPerTokenPaid;
    }

    mapping(address => UserInfo) public userInfo;
    mapping(address => address) public delegates;

    /* ------------------------------------------------------------------ */
    /*  Events                                                             */
    /* ------------------------------------------------------------------ */

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardDeposited(address indexed operator, uint256 amount);
    event RateUpdated(address indexed operator, uint256 newRateBps);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    /* ------------------------------------------------------------------ */
    /*  Errors                                                             */
    /* ------------------------------------------------------------------ */

    error NotOperator();
    error InvalidRate();
    error InsufficientStake();
    error ZeroAmount();
    error ZeroAddress();
    error NoPendingReward();
    error TransferFailed();
    error ReentrantCall();

    /* ------------------------------------------------------------------ */
    /*  Modifiers                                                          */
    /* ------------------------------------------------------------------ */

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrantStatus == 2) revert ReentrantCall();
        _reentrantStatus = 2;
        _;
        _reentrantStatus = 1;
    }

    uint256 private _reentrantStatus = 1;

    /* ------------------------------------------------------------------ */
    /*  Constructor                                                        */
    /* ------------------------------------------------------------------ */

    constructor(address _stakingToken, address _operator, uint256 _initialRateBps) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialRateBps < MIN_RATE_BPS || _initialRateBps > MAX_RATE_BPS) revert InvalidRate();

        stakingToken = IERC20(_stakingToken);
        operator = _operator;
        rateBps = _initialRateBps;
        lastUpdateTime = block.timestamp;

        emit OperatorChanged(address(0), _operator);
        emit RateUpdated(_operator, _initialRateBps);
    }

    /* ------------------------------------------------------------------ */
    /*  Internal: reward accounting                                        */
    /* ------------------------------------------------------------------ */

    function _updateReward() internal {
        if (block.timestamp <= lastUpdateTime) return;
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        lastUpdateTime = block.timestamp;

        // Compute total rewards to distribute first (multiply before divide)
        // to avoid divide-before-multiply precision loss.
        uint256 totalToDistribute = (totalStaked * rateBps * timeElapsed) / (10_000 * SECONDS_PER_DAY);

        if (totalToDistribute > rewardPool) {
            totalToDistribute = rewardPool;
        }

        if (totalToDistribute > 0) {
            // totalStaked is guaranteed > 0 here because totalToDistribute > 0
            // implies totalStaked > 0 (since rateBps >= 1 and timeElapsed >= 1).
            rewardPerTokenStored += (totalToDistribute * PRECISION) / totalStaked;
            rewardPool -= totalToDistribute;
        }
    }

    function _updateUserReward(address user) internal {
        UserInfo storage info = userInfo[user];
        uint256 pending = (info.stakedAmount * (rewardPerTokenStored - info.userRewardPerTokenPaid)) / PRECISION;
        info.rewardDebt += pending;
        info.userRewardPerTokenPaid = rewardPerTokenStored;
    }

    function _safeTransfer(address to, uint256 amount) internal {
        if (!stakingToken.transfer(to, amount)) revert TransferFailed();
    }

    function _safeTransferFrom(address from, uint256 amount) internal {
        if (!stakingToken.transferFrom(from, address(this), amount)) revert TransferFailed();
    }

    /* ------------------------------------------------------------------ */
    /*  User functions                                                     */
    /* ------------------------------------------------------------------ */

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _updateReward();
        _updateUserReward(msg.sender);

        // Effects before interactions
        userInfo[msg.sender].stakedAmount += amount;
        totalStaked += amount;

        // Interaction
        _safeTransferFrom(msg.sender, amount);

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserInfo storage info = userInfo[msg.sender];
        if (info.stakedAmount < amount) revert InsufficientStake();

        _updateReward();
        _updateUserReward(msg.sender);

        // Effects before interactions
        info.stakedAmount -= amount;
        totalStaked -= amount;

        // Interaction
        _safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        _updateReward();
        _updateUserReward(msg.sender);

        UserInfo storage info = userInfo[msg.sender];
        uint256 reward = info.rewardDebt;
        if (reward == 0) revert NoPendingReward();

        // Effects before interactions
        info.rewardDebt = 0;

        // Interaction
        _safeTransfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function delegate(address delegatee) external {
        if (delegatee == address(0)) revert ZeroAddress();
        address current = delegates[msg.sender];
        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, current, delegatee);
    }

    /* ------------------------------------------------------------------ */
    /*  Operator functions                                                 */
    /* ------------------------------------------------------------------ */

    function depositRewards(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _updateReward();

        // Effects before interactions
        rewardPool += amount;

        // Interaction
        _safeTransferFrom(msg.sender, amount);

        emit RewardDeposited(msg.sender, amount);
    }

    function setRate(uint256 _rateBps) external onlyOperator {
        if (_rateBps < MIN_RATE_BPS || _rateBps > MAX_RATE_BPS) revert InvalidRate();

        _updateReward();
        rateBps = _rateBps;

        emit RateUpdated(msg.sender, _rateBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /* ------------------------------------------------------------------ */
    /*  View functions                                                     */
    /* ------------------------------------------------------------------ */

    function pendingReward(address user) external view returns (uint256) {
        UserInfo storage info = userInfo[user];

        uint256 currentRewardPerToken = rewardPerTokenStored;

        if (totalStaked > 0 && block.timestamp > lastUpdateTime) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            // Multiply before divide to avoid precision loss.
            uint256 totalToDistribute = (totalStaked * rateBps * timeElapsed) / (10_000 * SECONDS_PER_DAY);
            if (totalToDistribute > rewardPool) {
                totalToDistribute = rewardPool;
            }
            currentRewardPerToken += (totalToDistribute * PRECISION) / totalStaked;
        }

        uint256 pending = (info.stakedAmount * (currentRewardPerToken - info.userRewardPerTokenPaid)) / PRECISION;
        return pending + info.rewardDebt;
    }

    function getVotingPower(address user) external view returns (uint256) {
        return userInfo[user].stakedAmount;
    }

    function getDelegate(address user) external view returns (address) {
        return delegates[user];
    }

    function stakedBalanceOf(address user) external view returns (uint256) {
        return userInfo[user].stakedAmount;
    }
}
