// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
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

/**
 * @title YieldBoostVault
 * @notice A yield-boosting vault that accepts a liquid staking token (LST) and distributes
 *         an associated reward token to depositors over time according to a configurable
 *         strategy. A 0.5% fee is applied to every reward claim and routed to a fee recipient.
 */
contract YieldBoostVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error ExceedsMaxDeposit(uint256 attempted, uint256 max);
    error InsufficientBalance(uint256 requested, uint256 available);
    error NoRewardsToClaim();
    error Unauthorized();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event RewardsClaimed(
        address indexed user,
        address indexed rewardToken,
        uint256 grossAmount,
        uint256 feeAmount,
        uint256 netAmount,
        address indexed feeRecipient
    );
    event RewardStrategyUpdated(address indexed operator, uint256 oldRate, uint256 newRate);
    event RewardsDistributed(address indexed operator, address indexed rewardToken, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    /// @notice Maximum LST a single user may deposit.
    uint256 public constant MAX_DEPOSIT_PER_USER = 100_000 ether; // 100,000 LST
    /// @notice Fee applied to reward claims, in basis points (0.5%).
    uint256 public constant FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant REWARD_PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // Immutables
    // -----------------------------------------------------------------------
    IERC20 public immutable lstToken;
    IERC20 public immutable rewardToken;

    // -----------------------------------------------------------------------
    // Access control / configuration
    // -----------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeRecipient;

    // -----------------------------------------------------------------------
    // Reward distribution strategy (time-based accrual)
    // -----------------------------------------------------------------------
    uint256 public rewardRate; // reward tokens per second (whole-token units)
    uint256 public lastUpdateTimestamp;
    uint256 public rewardPerTokenStored;

    // -----------------------------------------------------------------------
    // Staking state
    // -----------------------------------------------------------------------
    uint256 public totalDeposited;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public userRewards;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = _rewardPerToken();
        lastUpdateTimestamp = block.timestamp;
        if (account != address(0)) {
            userRewards[account] = _earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    /**
     * @param _lstToken      Liquid staking token accepted for deposits.
     * @param _rewardToken   Reward token distributed to depositors.
     * @param _operator      Address authorized to update the strategy and trigger distributions.
     * @param _feeRecipient  Address that receives the 0.5% claim fee.
     * @param _initialRate   Initial reward rate (reward tokens per second).
     */
    constructor(
        address _lstToken,
        address _rewardToken,
        address _operator,
        address _feeRecipient,
        uint256 _initialRate
    ) {
        if (
            _lstToken == address(0) ||
            _rewardToken == address(0) ||
            _operator == address(0) ||
            _feeRecipient == address(0)
        ) revert ZeroAddress();

        lstToken = IERC20(_lstToken);
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
        feeRecipient = _feeRecipient;
        rewardRate = _initialRate;
        lastUpdateTimestamp = block.timestamp;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // User actions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit LST into the vault, up to the per-user maximum.
     * @param amount Amount of LST to deposit.
     */
    function deposit(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        uint256 newBalance = userDeposits[msg.sender] + amount;
        if (newBalance > MAX_DEPOSIT_PER_USER) {
            revert ExceedsMaxDeposit(newBalance, MAX_DEPOSIT_PER_USER);
        }

        userDeposits[msg.sender] = newBalance;
        totalDeposited += amount;

        lstToken.safeTransferFrom(address(this), amount);

        emit Deposited(msg.sender, address(lstToken), amount);
    }

    /**
     * @notice Withdraw previously deposited LST.
     * @param amount Amount of LST to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (userDeposits[msg.sender] < amount) {
            revert InsufficientBalance(amount, userDeposits[msg.sender]);
        }

        userDeposits[msg.sender] -= amount;
        totalDeposited -= amount;

        lstToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, address(lstToken), amount);
    }

    /**
     * @notice Claim accumulated reward tokens. A 0.5% fee is deducted and sent to the fee recipient.
     */
    function claimRewards() external nonReentrant updateReward(msg.sender) {
        uint256 reward = userRewards[msg.sender];
        if (reward < 1) revert NoRewardsToClaim();

        userRewards[msg.sender] = 0;

        uint256 feeAmount = (reward * FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = reward - feeAmount;

        rewardToken.safeTransfer(msg.sender, netAmount);
        if (feeAmount > 0) {
            rewardToken.safeTransfer(feeRecipient, feeAmount);
        }

        emit RewardsClaimed(msg.sender, address(rewardToken), reward, feeAmount, netAmount, feeRecipient);
    }

    // -----------------------------------------------------------------------
    // Operator actions
    // -----------------------------------------------------------------------

    /**
     * @notice Update the reward distribution strategy by setting a new emission rate.
     * @param newRate New reward rate in reward tokens per second.
     */
    function updateRewardStrategy(uint256 newRate) external onlyOperator updateReward(address(0)) {
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardStrategyUpdated(msg.sender, oldRate, newRate);
    }

    /**
     * @notice Trigger the distribution of reward tokens by funding the vault. The operator
     *         transfers `amount` reward tokens from their own balance into the vault to back
     *         ongoing emissions.
     * @param amount Amount of reward tokens to fund.
     */
    function distributeRewards(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        rewardToken.safeTransferFrom(address(this), amount);
        emit RewardsDistributed(msg.sender, address(rewardToken), amount);
    }

    // -----------------------------------------------------------------------
    // Admin actions
    // -----------------------------------------------------------------------

    /**
     * @notice Transfer contract ownership to a new address.
     * @param newOwner Address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /**
     * @notice Update the operator address.
     * @param newOperator Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Update the fee recipient address.
     * @param newFeeRecipient Address of the new fee recipient.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    /**
     * @notice Current accumulated reward per staked LST, scaled by 1e18.
     */
    function rewardPerToken() external view returns (uint256) {
        return _rewardPerToken();
    }

    /**
     * @notice Total earned (claimable + already-accrued) rewards for an account.
     * @param account Address to query.
     */
    function earned(address account) external view returns (uint256) {
        return _earned(account);
    }

    /**
     * @notice Alias for `earned`, representing pending claimable rewards.
     * @param account Address to query.
     */
    function pendingRewards(address account) external view returns (uint256) {
        return _earned(account);
    }

    /**
     * @notice Reward token balance currently held by the vault.
     */
    function rewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    /**
     * @notice LST balance currently held by the vault.
     */
    function depositedTokenBalance() external view returns (uint256) {
        return lstToken.balanceOf(address(this));
    }

    // -----------------------------------------------------------------------
    // Internal logic
    // -----------------------------------------------------------------------

    function _rewardPerToken() internal view returns (uint256) {
        if (totalDeposited == 0) {
            return rewardPerTokenStored;
        }
        uint256 elapsed = block.timestamp - lastUpdateTimestamp;
        return rewardPerTokenStored + ((elapsed * rewardRate * REWARD_PRECISION) / totalDeposited);
    }

    function _earned(address account) internal view returns (uint256) {
        uint256 rpt = _rewardPerToken();
        uint256 unpaid = rpt - userRewardPerTokenPaid[account];
        return
            (userDeposits[account] * unpaid) / REWARD_PRECISION +
            userRewards[account];
    }
}
