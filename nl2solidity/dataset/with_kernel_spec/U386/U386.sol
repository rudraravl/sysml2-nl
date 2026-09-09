// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LiquidStakingVault
 * @notice A vault for staking the base-layer cryptocurrency. Users deposit native currency,
 *         earn rewards at a configurable daily rate (capped at 0.05%), and can withdraw
 *         their stake plus rewards or claim rewards independently. An operator updates the
 *         reward rate and triggers global reward distribution from the vault's excess balance.
 */
contract LiquidStakingVault {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MIN_DEPOSIT = 1 ether;
    uint256 public constant MAX_REWARD_RATE = 5; // basis points per day (5 = 0.05%)
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 private constant REWARD_PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------
    address public operator;
    uint256 public totalStaked;
    uint256 public rewardRate; // daily reward rate in basis points
    uint256 public rewardPerTokenStored; // accumulated reward per token, scaled by 1e18
    uint256 public lastDistributionTimestamp;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public rewards; // pending rewards available to claim
    mapping(address => uint256) public userRewardPerTokenPaid;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount, uint256 reward);
    event RewardClaim(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardsDistributed(uint256 amount, uint256 rewardPerToken);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error InsufficientDeposit();
    error InsufficientBalance();
    error NoRewardsToClaim();
    error RewardRateExceedsLimit();
    error NotOperator();
    error ZeroAddress();
    error TransferFailed();
    error ZeroTotalStaked();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _operator, uint256 _rewardRate) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_rewardRate > MAX_REWARD_RATE) revert RewardRateExceedsLimit();
        operator = _operator;
        rewardRate = _rewardRate;
        lastDistributionTimestamp = block.timestamp;
        emit OperatorChanged(address(0), _operator);
        emit RewardRateUpdated(0, _rewardRate);
    }

    // -----------------------------------------------------------------------
    // Receive — accept external reward top-ups
    // -----------------------------------------------------------------------
    receive() external payable {}

    // -----------------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit native currency into the vault. Minimum deposit is 1 ether.
     */
    function deposit() external payable {
        if (msg.value < MIN_DEPOSIT) revert InsufficientDeposit();
        _updateReward(msg.sender);
        deposits[msg.sender] += msg.value;
        totalStaked += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw a specified amount of the staked deposit along with all accrued rewards.
     * @param amount The amount of staked native currency to withdraw.
     */
    function withdraw(uint256 amount) external {
        if (amount == 0) revert InsufficientBalance();
        if (amount > deposits[msg.sender]) revert InsufficientBalance();

        _updateReward(msg.sender);

        deposits[msg.sender] -= amount;
        totalStaked -= amount;

        uint256 rewardAmount = rewards[msg.sender];
        rewards[msg.sender] = 0;

        uint256 totalPayout = amount + rewardAmount;
        if (address(this).balance < totalPayout) revert TransferFailed();

        (bool success, ) = payable(msg.sender).call{value: totalPayout}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, amount, rewardAmount);
    }

    /**
     * @notice Claim all accrued rewards without withdrawing the staked deposit.
     */
    function claimRewards() external {
        _updateReward(msg.sender);
        uint256 rewardAmount = rewards[msg.sender];
        if (!(rewardAmount > 0)) revert NoRewardsToClaim();

        rewards[msg.sender] = 0;

        if (address(this).balance < rewardAmount) revert TransferFailed();
        (bool success, ) = payable(msg.sender).call{value: rewardAmount}("");
        if (!success) revert TransferFailed();

        emit RewardClaim(msg.sender, rewardAmount);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------

    /**
     * @notice Update the daily reward rate. Capped at 0.05% (5 basis points).
     * @param newRate The new daily reward rate in basis points.
     */
    function setRewardRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_REWARD_RATE) revert RewardRateExceedsLimit();
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    /**
     * @notice Trigger distribution of rewards from the vault's excess balance.
     *         Updates the global reward-per-token index based on elapsed time
     *         since the last distribution, capped by available excess balance.
     */
    function distributeRewards() external onlyOperator {
        if (totalStaked == 0) revert ZeroTotalStaked();

        if (block.timestamp <= lastDistributionTimestamp) return;

        uint256 elapsed = block.timestamp - lastDistributionTimestamp;

        // Compute reward-per-token increment directly to avoid divide-before-multiply.
        // rewardPerTokenIncrement = rewardRate * elapsed * REWARD_PRECISION / (BPS_DENOMINATOR * SECONDS_PER_DAY)
        uint256 rewardPerTokenIncrement =
            (rewardRate * elapsed * REWARD_PRECISION) / (BPS_DENOMINATOR * SECONDS_PER_DAY);

        // Derive total reward amount from the increment (multiply-then-divide, no precision loss chain)
        uint256 rewardAmount = (totalStaked * rewardPerTokenIncrement) / REWARD_PRECISION;

        // Cap to available excess (balance beyond what is owed to stakers)
        uint256 excess = address(this).balance - totalStaked;
        if (rewardAmount > excess) {
            rewardAmount = excess;
            rewardPerTokenIncrement = (excess * REWARD_PRECISION) / totalStaked;
        }

        rewardPerTokenStored += rewardPerTokenIncrement;
        lastDistributionTimestamp = block.timestamp;
        emit RewardsDistributed(rewardAmount, rewardPerTokenStored);
    }

    /**
     * @notice Transfer the operator role to a new address.
     * @param newOperator The address of the new operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /**
     * @notice Returns the total accrued rewards for a user, including pending undistributed rewards.
     * @param user The address of the user.
     * @return The total rewards earned by the user.
     */
    function pendingRewards(address user) external view returns (uint256) {
        uint256 currentRewardPerToken = rewardPerTokenStored;
        uint256 userPaid = userRewardPerTokenPaid[user];
        uint256 earned = 0;
        if (currentRewardPerToken > userPaid) {
            earned = (deposits[user] * (currentRewardPerToken - userPaid)) / REWARD_PRECISION;
        }
        return rewards[user] + earned;
    }

    /**
     * @notice Returns the current vault balance.
     */
    function getVaultBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns the available excess balance that can be distributed as rewards.
     */
    function getAvailableExcess() external view returns (uint256) {
        return address(this).balance - totalStaked;
    }

    // -----------------------------------------------------------------------
    // Internal functions
    // -----------------------------------------------------------------------

    /**
     * @dev Updates the reward state for a user based on the global reward-per-token index.
     *      Credits any newly earned rewards to the user's pending rewards balance.
     */
    function _updateReward(address account) internal {
        uint256 currentRewardPerToken = rewardPerTokenStored;
        uint256 userPaid = userRewardPerTokenPaid[account];
        if (currentRewardPerToken > userPaid) {
            uint256 earned =
                (deposits[account] * (currentRewardPerToken - userPaid)) / REWARD_PRECISION;
            if (earned > 0) {
                rewards[account] += earned;
            }
        }
        userRewardPerTokenPaid[account] = currentRewardPerToken;
    }
}
