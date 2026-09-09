// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title WrappedBitcoinStaking
 * @notice Users stake a wrapped Bitcoin ERC-20 token to earn yield paid in the same token.
 *         The contract escrows staked tokens and distributes rewards from a funded reward
 *         pool according to a per-second reward rate. Withdrawals follow a two-phase flow:
 *         `requestWithdrawal` moves staked tokens into a pending queue (which stops earning),
 *         and `unstake` releases them to the user once the staking epoch duration has elapsed.
 *         A 0.5% fee is taken from every reward claim and forwarded to a configurable fee collector.
 */
contract WrappedBitcoinStaking {
    // --------------------------------------------------------------------------------------------
    // Custom errors
    // --------------------------------------------------------------------------------------------
    error ZeroAmount();
    error BelowMinimumDeposit();
    error InsufficientStakedBalance();
    error NoPendingWithdrawal();
    error WithdrawalNotProcessed();
    error InsufficientRewardPool();
    error NoRewardsToClaim();
    error InvalidAddress();
    error NotOperator();
    error NotOwner();
    error ContractPaused();
    error ReentrancyDetected();
    error InvalidEpochDuration();
    error CannotRecoverLockedToken();

    // --------------------------------------------------------------------------------------------
    // Constants
    // --------------------------------------------------------------------------------------------
    uint256 public constant FEE_NUMERATOR = 5;       // 0.5%
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant ACC_REWARD_PRECISION = 1e18;

    // --------------------------------------------------------------------------------------------
    // Immutable configuration
    // --------------------------------------------------------------------------------------------
    IERC20 public immutable stakingToken;           // wrapped Bitcoin asset
    uint256 public immutable minDeposit;            // 0.001 wrapped Bitcoin (decimal-adjusted at deploy)

    // --------------------------------------------------------------------------------------------
    // Access control / configuration
    // --------------------------------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeCollector;
    bool public paused;

    // --------------------------------------------------------------------------------------------
    // Reward state
    // --------------------------------------------------------------------------------------------
    uint256 public totalStaked;
    uint256 public totalPendingWithdrawal;
    uint256 public rewardPool;                       // tokens reserved for future reward payouts
    uint256 public rewardRate;                       // reward tokens per second distributed to all stakers
    uint256 public lastUpdateTime;
    uint256 public accRewardPerShare;                // accumulated reward per staked token (scaled)

    // --------------------------------------------------------------------------------------------
    // Epoch state
    // --------------------------------------------------------------------------------------------
    uint256 public epochDuration;                    // length of a staking epoch (seconds)
    uint256 public currentEpochStart;

    // --------------------------------------------------------------------------------------------
    // User state
    // --------------------------------------------------------------------------------------------
    struct UserInfo {
        uint256 stakedAmount;
        uint256 rewardDebt;          // stakedAmount * accRewardPerShare / ACC_REWARD_PRECISION at last touch
        uint256 pendingWithdrawal;   // tokens queued for unstake
        uint256 withdrawalRequestTime;
    }
    mapping(address => UserInfo) public userInfo;

    // --------------------------------------------------------------------------------------------
    // Reentrancy
    // --------------------------------------------------------------------------------------------
    uint256 private _locked; // 0 = unlocked, 1 = locked

    // --------------------------------------------------------------------------------------------
    // Events
    // --------------------------------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount, uint256 fee);
    event RewardRateUpdated(uint256 newRate);
    event EpochInitiated(uint256 startTime, uint256 duration, uint256 rewardRate);
    event RewardPoolFunded(uint256 amount);
    event PausedStateChanged(bool paused);
    event OperatorUpdated(address indexed newOperator);
    event FeeCollectorUpdated(address indexed newFeeCollector);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RecoveredERC20(address indexed token, address indexed to, uint256 amount);

    // --------------------------------------------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 0) revert ReentrancyDetected();
        _locked = 1;
        _;
        _locked = 0;
    }

    // --------------------------------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------------------------------
    constructor(
        address _stakingToken,
        address _operator,
        address _feeCollector,
        uint256 _minDeposit,
        uint256 _epochDuration,
        uint256 _rewardRate
    ) {
        if (_stakingToken == address(0)) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();
        if (_feeCollector == address(0)) revert InvalidAddress();
        if (_minDeposit == 0) revert ZeroAmount();
        if (_epochDuration == 0) revert InvalidEpochDuration();

        stakingToken = IERC20(_stakingToken);
        minDeposit = _minDeposit;
        owner = msg.sender;
        operator = _operator;
        feeCollector = _feeCollector;
        epochDuration = _epochDuration;
        rewardRate = _rewardRate;
        currentEpochStart = block.timestamp;
        lastUpdateTime = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(_operator);
        emit FeeCollectorUpdated(_feeCollector);
        emit EpochInitiated(currentEpochStart, _epochDuration, _rewardRate);
    }

    // --------------------------------------------------------------------------------------------
    // Core reward accounting
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Update the global accumulated reward per share based on elapsed time and the
     *         current reward rate. Rewards are capped by the remaining reward pool.
     */
    function updatePool() public {
        if (block.timestamp <= lastUpdateTime) {
            return;
        }
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastUpdateTime;
        uint256 rewards = elapsed * rewardRate;
        if (rewards > rewardPool) {
            rewards = rewardPool;
        }
        if (rewards > 0) {
            rewardPool -= rewards;
            accRewardPerShare += (rewards * ACC_REWARD_PRECISION) / totalStaked;
        }
        lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Compute the unclaimed reward for a user.
     */
    function pendingRewards(address user) public view returns (uint256) {
        UserInfo storage info = userInfo[user];
        uint256 acc = accRewardPerShare;
        if (totalStaked > 0 && block.timestamp > lastUpdateTime) {
            uint256 elapsed = block.timestamp - lastUpdateTime;
            uint256 rewards = elapsed * rewardRate;
            if (rewards > rewardPool) {
                rewards = rewardPool;
            }
            acc += (rewards * ACC_REWARD_PRECISION) / totalStaked;
        }
        return (info.stakedAmount * acc) / ACC_REWARD_PRECISION - info.rewardDebt;
    }

    /**
     * @dev Pay out pending rewards to a user, deducting the 0.5% claim fee.
     *      Caller is responsible for updating `rewardDebt` before calling this.
     */
    function _payReward(address to, uint256 amount) internal {
        uint256 fee = (amount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 net = amount - fee;

        if (net > 0) {
            require(stakingToken.transfer(to, net), "Reward transfer failed");
        }
        if (fee > 0) {
            require(stakingToken.transfer(feeCollector, fee), "Fee transfer failed");
        }
        emit RewardsClaimed(to, net, fee);
    }

    // --------------------------------------------------------------------------------------------
    // User actions
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Deposit wrapped Bitcoin to earn yield. Pending rewards are auto-harvested.
     * @param amount Amount of wrapped Bitcoin to stake (must be >= minDeposit).
     */
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount < minDeposit) revert BelowMinimumDeposit();

        updatePool();
        UserInfo storage info = userInfo[msg.sender];

        uint256 pending = 0;
        if (info.stakedAmount > 0) {
            pending = (info.stakedAmount * accRewardPerShare) / ACC_REWARD_PRECISION - info.rewardDebt;
        }

        // Effects: update staking state before any external interactions.
        info.stakedAmount += amount;
        totalStaked += amount;
        info.rewardDebt = (info.stakedAmount * accRewardPerShare) / ACC_REWARD_PRECISION;

        // Interactions: pull staked tokens from the user.
        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Staking transfer failed"
        );

        // Pay out any previously accrued rewards.
        if (pending > 0) {
            _payReward(msg.sender, pending);
        }

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Request a withdrawal of staked tokens. Requested tokens stop earning rewards
     *         immediately and become claimable via `unstake` after the epoch duration elapses.
     * @param amount Amount of staked tokens to withdraw.
     */
    function requestWithdrawal(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserInfo storage info = userInfo[msg.sender];
        if (info.stakedAmount < amount) revert InsufficientStakedBalance();

        updatePool();

        uint256 pending = 0;
        if (info.stakedAmount > 0) {
            pending = (info.stakedAmount * accRewardPerShare) / ACC_REWARD_PRECISION - info.rewardDebt;
        }

        // Effects: move staked tokens into the pending withdrawal queue.
        info.stakedAmount -= amount;
        totalStaked -= amount;
        info.pendingWithdrawal += amount;
        info.withdrawalRequestTime = block.timestamp;
        totalPendingWithdrawal += amount;
        info.rewardDebt = (info.stakedAmount * accRewardPerShare) / ACC_REWARD_PRECISION;

        // Interactions: pay out any previously accrued rewards.
        if (pending > 0) {
            _payReward(msg.sender, pending);
        }

        emit WithdrawalRequested(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens that were previously requested for withdrawal and whose
     *         processing period (epoch duration) has elapsed.
     */
    function unstake() external nonReentrant {
        UserInfo storage info = userInfo[msg.sender];
        uint256 amount = info.pendingWithdrawal;
        if (amount == 0) revert NoPendingWithdrawal();
        if (block.timestamp < info.withdrawalRequestTime + epochDuration) revert WithdrawalNotProcessed();

        // Effects: clear the pending withdrawal before transferring.
        info.pendingWithdrawal = 0;
        totalPendingWithdrawal -= amount;

        // Interactions: release the escrowed tokens.
        require(stakingToken.transfer(msg.sender, amount), "Unstake transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim accumulated rewards without changing the staked position.
     *         A 0.5% fee is forwarded to the fee collector.
     */
    function claimRewards() external nonReentrant {
        updatePool();
        UserInfo storage info = userInfo[msg.sender];

        uint256 pending = (info.stakedAmount * accRewardPerShare) / ACC_REWARD_PRECISION - info.rewardDebt;
        if (!(pending > 0)) revert NoRewardsToClaim();
        if (pending > rewardPool) revert InsufficientRewardPool();

        // Effects: reset reward debt and reduce the reward pool before payout.
        rewardPool -= pending;
        info.rewardDebt = (info.stakedAmount * accRewardPerShare) / ACC_REWARD_PRECISION;

        // Interactions: pay the user (net of fee).
        _payReward(msg.sender, pending);
    }

    // --------------------------------------------------------------------------------------------
    // Operator actions
    // --------------------------------------------------------------------------------------------

    /**
     * @notice Update the reward rate (tokens per second). Updates accrual first.
     */
    function updateRewardRate(uint256 newRate) external onlyOperator {
        updatePool();
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    /**
     * @notice Initiate a new staking epoch with a fresh reward rate and duration.
     * @param newRate      Reward tokens per second for the new epoch.
     * @param newDuration  Duration of the new epoch in seconds.
     */
    function initiateNewEpoch(uint256 newRate, uint256 newDuration) external onlyOperator {
        if (newDuration == 0) revert InvalidEpochDuration();
        updatePool();
        rewardRate = newRate;
        epochDuration = newDuration;
        currentEpochStart = block.timestamp;
        emit EpochInitiated(currentEpochStart, newDuration, newRate);
    }

    /**
     * @notice Fund the reward pool with tokens transferred from the caller.
     * @param amount Amount of reward tokens to deposit into the pool.
     */
    function fundRewardPool(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        // Effects before interactions.
        rewardPool += amount;
        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Funding transfer failed"
        );
        emit RewardPoolFunded(amount);
    }

    /**
     * @notice Pause or unpause staking and withdrawal requests. Claiming and unstaking
     *         already-requested withdrawals remain available so users can always exit.
     */
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    // --------------------------------------------------------------------------------------------
    // Owner / admin actions
    // --------------------------------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        if (newFeeCollector == address(0)) revert InvalidAddress();
        feeCollector = newFeeCollector;
        emit FeeCollectorUpdated(newFeeCollector);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Recover ERC-20 tokens accidentally sent to the contract. The staking token
     *         may only be recovered in excess of the locked amount
     *         (totalStaked + totalPendingWithdrawal + rewardPool).
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        if (token == address(stakingToken)) {
            uint256 contractBalance = stakingToken.balanceOf(address(this));
            uint256 locked = totalStaked + totalPendingWithdrawal + rewardPool;
            if (contractBalance < locked + amount) revert CannotRecoverLockedToken();
        }
        require(IERC20(token).transfer(owner, amount), "Recovery transfer failed");
        emit RecoveredERC20(token, owner, amount);
    }
}
