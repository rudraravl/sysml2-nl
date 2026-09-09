// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

/**
 * @title ComputeProviderNetwork
 * @notice Manages a decentralized network of compute providers and their staked collateral.
 *         Providers stake tokens to join the network, earn rewards proportional to their
 *         stake at a configurable per-block yield rate, and may delegate their compute
 *         power to other entities. An operator governs global parameters.
 */
contract ComputeProviderNetwork {
    // ────────────────────────────────────────────────────────────────
    // Constants
    // ────────────────────────────────────────────────────────────────
    /// @dev Maximum reward rate: 0.05% per block = 5 basis points.
    uint256 public constant MAX_REWARD_RATE_BPS = 5;
    /// @dev Basis points denominator.
    uint256 public constant BPS_DENOMINATOR = 10_000;
    /// @dev Minimum allowed value for `minStakeAmount`.
    uint256 public constant MIN_MIN_STAKE = 1000;
    /// @dev Precision used for the reward-per-token accumulator.
    uint256 public constant REWARD_PRECISION = 1e18;

    // ────────────────────────────────────────────────────────────────
    // Types
    // ────────────────────────────────────────────────────────────────
    struct ProviderInfo {
        uint256 stakedAmount;
        uint256 rewardPerTokenPaid;
        uint256 rewards;            // pending, unclaimed rewards
        uint256 computePowerRating; // set by operator
        address delegatee;           // recipient of compute power delegation
        uint256 lastStakeTime;      // timestamp of last stake (for cooldown)
        bool isProvider;
    }

    // ────────────────────────────────────────────────────────────────
    // State variables
    // ────────────────────────────────────────────────────────────────
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    address public operator;

    uint256 public rewardRateBPS;       // basis points per block (0..MAX_REWARD_RATE_BPS)
    uint256 public minStakeAmount;      // minimum stake to be a provider
    uint256 public cooldownDuration;    // unstake cooldown in seconds

    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateBlock;
    uint256 public totalStaked;

    mapping(address => ProviderInfo) public providers;

    /// @dev Reentrancy guard.
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ────────────────────────────────────────────────────────────────
    // Events
    // ────────────────────────────────────────────────────────────────
    event Staked(address indexed provider, uint256 amount);
    event Unstaked(address indexed provider, uint256 amount);
    event RewardsClaimed(address indexed provider, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event MinStakeAmountUpdated(uint256 newMinStake);
    event CooldownDurationUpdated(uint256 newDuration);
    event ComputePowerUpdated(address indexed provider, uint256 newRating);
    event ComputeDelegated(address indexed provider, address indexed delegatee);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event RewardTokensDeposited(address indexed depositor, uint256 amount);

    // ────────────────────────────────────────────────────────────────
    // Custom errors
    // ────────────────────────────────────────────────────────────────
    error NotOperator();
    error TransferFailed();
    error InsufficientStaked();
    error CooldownNotMet();
    error ZeroAmount();
    error NoRewards();
    error ExceedsMaxRate();
    error MinStakeTooLow();
    error InvalidAddress();
    error StakeBelowMinimum();
    error NotProvider();
    error InvalidDelegate();
    error ReentrantCall();

    // ────────────────────────────────────────────────────────────────
    // Modifiers
    // ────────────────────────────────────────────────────────────────
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /**
     * @notice Updates the global reward accumulator and the user's pending rewards.
     * @param account Address to update; use address(0) for global-only update.
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        if (account != address(0)) {
            ProviderInfo storage provider = providers[account];
            provider.rewards = earned(account);
            provider.rewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    // ────────────────────────────────────────────────────────────────
    // Constructor
    // ────────────────────────────────────────────────────────────────
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _operator,
        uint256 _rewardRateBPS,
        uint256 _minStakeAmount,
        uint256 _cooldownDuration
    ) {
        if (_stakingToken == address(0) || _rewardToken == address(0)) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();
        if (_rewardRateBPS > MAX_REWARD_RATE_BPS) revert ExceedsMaxRate();
        if (_minStakeAmount < MIN_MIN_STAKE) revert MinStakeTooLow();

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
        rewardRateBPS = _rewardRateBPS;
        minStakeAmount = _minStakeAmount;
        cooldownDuration = _cooldownDuration;
        lastUpdateBlock = block.number;
        _status = _NOT_ENTERED;

        emit RewardRateUpdated(0, _rewardRateBPS);
        emit MinStakeAmountUpdated(_minStakeAmount);
        emit CooldownDurationUpdated(_cooldownDuration);
    }

    // ────────────────────────────────────────────────────────────────
    // View functions
    // ────────────────────────────────────────────────────────────────

    /**
     * @notice Returns the current reward-per-staked-token accumulator (1e18 precision).
     * @dev Because the reward rate is a percentage yield per block, the accumulator
     *      grows by `rewardRateBPS / BPS_DENOMINATOR` per block, independent of total stake.
     */
    function rewardPerToken() public view returns (uint256) {
        return
            rewardPerTokenStored +
            ((block.number - lastUpdateBlock) * rewardRateBPS * REWARD_PRECISION) /
            BPS_DENOMINATOR;
    }

    /**
     * @notice Calculates the total earned rewards for a provider.
     * @param account Provider address.
     * @return amount of reward tokens earned but not yet claimed.
     */
    function earned(address account) public view returns (uint256) {
        ProviderInfo storage provider = providers[account];
        return
            (provider.stakedAmount *
                (rewardPerToken() - provider.rewardPerTokenPaid)) /
            REWARD_PRECISION +
            provider.rewards;
    }

    /**
     * @notice Returns a snapshot of a provider's state.
     */
    function getProvider(address account)
        external
        view
        returns (
            uint256 stakedAmount,
            uint256 computePowerRating,
            uint256 rewards,
            address delegatee,
            uint256 lastStakeTime,
            bool isProvider
        )
    {
        ProviderInfo storage p = providers[account];
        return (
            p.stakedAmount,
            p.computePowerRating,
            p.rewards,
            p.delegatee,
            p.lastStakeTime,
            p.isProvider
        );
    }

    // ────────────────────────────────────────────────────────────────
    // User functions
    // ────────────────────────────────────────────────────────────────

    /**
     * @notice Stake tokens to become (or add to) a provider. Resets the unstake cooldown.
     * @param amount Amount of staking tokens to deposit.
     */
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        ProviderInfo storage provider = providers[msg.sender];

        // Effects: update state before external transfer (checks-effects-interactions)
        provider.stakedAmount += amount;
        totalStaked += amount;
        provider.lastStakeTime = block.timestamp;
        if (!provider.isProvider) provider.isProvider = true;

        if (provider.stakedAmount < minStakeAmount) revert StakeBelowMinimum();

        // Interactions: pull tokens after state is updated
        if (!stakingToken.transferFrom(msg.sender, address(this), amount))
            revert TransferFailed();

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens after the cooldown period has elapsed.
     * @param amount Amount to withdraw.
     */
    function unstake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        ProviderInfo storage provider = providers[msg.sender];
        if (!provider.isProvider || provider.stakedAmount < amount)
            revert InsufficientStaked();
        if (block.timestamp < provider.lastStakeTime + cooldownDuration)
            revert CooldownNotMet();

        // Effects
        provider.stakedAmount -= amount;
        totalStaked -= amount;
        if (provider.stakedAmount == 0) {
            provider.isProvider = false;
        }

        // Interactions
        if (!stakingToken.transfer(msg.sender, amount)) revert TransferFailed();

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim all pending rewards.
     */
    function claimRewards() external nonReentrant updateReward(msg.sender) {
        ProviderInfo storage provider = providers[msg.sender];
        uint256 reward = provider.rewards;
        if (reward == 0) revert NoRewards();

        // Effects
        provider.rewards = 0;

        // Interactions
        if (!rewardToken.transfer(msg.sender, reward)) revert TransferFailed();

        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Delegate the provider's compute power to another address.
     * @param delegatee Address to receive the compute power delegation.
     */
    function delegate(address delegatee) external nonReentrant {
        ProviderInfo storage provider = providers[msg.sender];
        if (!provider.isProvider || provider.stakedAmount < minStakeAmount)
            revert NotProvider();
        if (delegatee == address(0)) revert InvalidDelegate();
        if (delegatee == msg.sender) revert InvalidDelegate();

        provider.delegatee = delegatee;
        emit ComputeDelegated(msg.sender, delegatee);
    }

    // ────────────────────────────────────────────────────────────────
    // Operator functions
    // ────────────────────────────────────────────────────────────────

    /**
     * @notice Set the compute power rating for a provider.
     * @param providerAddr Address of the provider.
     * @param rating New compute power rating.
     */
    function setComputePowerRating(
        address providerAddr,
        uint256 rating
    ) external onlyOperator {
        if (!providers[providerAddr].isProvider) revert NotProvider();
        providers[providerAddr].computePowerRating = rating;
        emit ComputePowerUpdated(providerAddr, rating);
    }

    /**
     * @notice Update the global reward rate (basis points per block), capped at 5 (0.05%).
     * @param _rewardRateBPS New rate in basis points.
     */
    function setRewardRate(uint256 _rewardRateBPS) external onlyOperator {
        if (_rewardRateBPS > MAX_REWARD_RATE_BPS) revert ExceedsMaxRate();
        // Snapshot the current reward accumulator before changing the rate.
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        uint256 oldRate = rewardRateBPS;
        rewardRateBPS = _rewardRateBPS;
        emit RewardRateUpdated(oldRate, _rewardRateBPS);
    }

    /**
     * @notice Set the minimum staking amount. Must be at least 1000.
     * @param _minStakeAmount New minimum stake.
     */
    function setMinStakeAmount(uint256 _minStakeAmount) external onlyOperator {
        if (_minStakeAmount < MIN_MIN_STAKE) revert MinStakeTooLow();
        minStakeAmount = _minStakeAmount;
        emit MinStakeAmountUpdated(_minStakeAmount);
    }

    /**
     * @notice Set the cooldown duration required before unstaking.
     * @param _cooldownDuration Duration in seconds.
     */
    function setCooldownDuration(uint256 _cooldownDuration) external onlyOperator {
        cooldownDuration = _cooldownDuration;
        emit CooldownDurationUpdated(_cooldownDuration);
    }

    /**
     * @notice Transfer operator rights to a new address.
     * @param newOperator Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Deposit reward tokens into the contract to fund the reward pool.
     * @param amount Amount of reward tokens to transfer from the caller.
     */
    function depositRewardTokens(uint256 amount) external nonReentrant onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (!rewardToken.transferFrom(msg.sender, address(this), amount))
            revert TransferFailed();
        emit RewardTokensDeposited(msg.sender, amount);
    }

    /**
     * @notice Recover accidentally sent ERC20 tokens. Cannot recover the staking
     *         or reward tokens (those are managed by the contract logic).
     * @param token Address of the token to recover.
     * @param to Recipient address.
     * @param amount Amount to recover.
     */
    function recoverERC20(address token, address to, uint256 amount) external nonReentrant onlyOperator {
        if (token == address(0)) revert InvalidAddress();
        if (to == address(0)) revert InvalidAddress();
        if (token == address(stakingToken) || token == address(rewardToken))
            revert InvalidAddress();
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
    }
}
