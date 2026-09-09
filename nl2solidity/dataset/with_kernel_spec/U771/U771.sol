// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBaseToken {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IValidator {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claimRewards() external returns (uint256);
    function totalStaked() external view returns (uint256);
}

/// @title LiquidStakingPool
/// @notice Custodies a base ERC20 token and issues a liquid staking token (LST) in return.
///         Users deposit base tokens to mint LST, burn LST to withdraw base tokens after a
///         7-day unbonding period, and claim a proportional share of staking rewards. A
///         designated operator stakes idle base tokens with an external validator and
///         harvests rewards. The owner can adjust the staking fee (default 5%) and upgrade
///         the contract implementation pointer.
contract LiquidStakingPool {
    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error AmountZero();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferFailed();
    error UnbondingNotComplete();
    error NoPendingWithdrawal();
    error WithdrawalAlreadyClaimed();
    error WithdrawalPending();
    error FeeTooHigh();
    error ContractPaused();
    error InvalidImplementation();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event Deposited(address indexed user, uint256 baseAmount, uint256 lstMinted);
    event WithdrawalRequested(address indexed user, uint256 lstBurned, uint256 baseAmount, uint256 unbondAt);
    event WithdrawalClaimed(address indexed user, uint256 baseAmount);
    event RewardsDistributed(uint256 totalRewards, uint256 feeAmount, uint256 userShare);
    event RewardClaimed(address indexed user, uint256 amount);
    event StakedToValidator(address indexed operator, uint256 amount);
    event UnstakedFromValidator(address indexed operator, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event ImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    event PausedStateChanged(bool paused);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant UNBONDING_PERIOD = 7 days;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10%
    uint256 public constant DEFAULT_FEE_BPS = 500; // 5%
    uint256 public constant PRECISION = 1e18;

    // -------------------------------------------------------------------------
    // Token Metadata (LST)
    // -------------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------
    IBaseToken public immutable baseToken;
    IValidator public immutable validator;

    address public owner;
    address public operator;
    address public implementation;
    bool public paused;

    /// @notice Total supply of the liquid staking token.
    uint256 public totalLSTSupply;
    /// @notice Total base tokens accounted for in the pool (held + staked with validator).
    uint256 public totalStakedBase;
    /// @notice Total base tokens currently staked with the external validator.
    uint256 public totalStakedWithValidator;
    /// @notice Staking fee in basis points (default 500 = 5%).
    uint256 public feeBps;
    /// @notice Accumulated protocol fees in base token, claimable by owner.
    uint256 public accumulatedFees;

    /// @notice Per-user LST balances.
    mapping(address => uint256) public lstBalances;
    /// @notice Allowances for LST transfers.
    mapping(address => mapping(address => uint256)) public lstAllowances;

    /// @notice Accumulated rewards per LST unit (scaled by PRECISION).
    uint256 public rewardIndex;
    /// @notice Last reward index credited to each user.
    mapping(address => uint256) public userRewardIndex;

    struct Withdrawal {
        uint256 baseAmount;
        uint256 unbondAt;
        bool claimed;
    }
    mapping(address => Withdrawal) public pendingWithdrawals;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(
        address _baseToken,
        address _validator,
        string memory _name,
        string memory _symbol
    ) {
        if (_baseToken == address(0) || _validator == address(0)) revert ZeroAddress();
        baseToken = IBaseToken(_baseToken);
        validator = IValidator(_validator);
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        operator = msg.sender;
        implementation = address(this);
        feeBps = DEFAULT_FEE_BPS;
        emit OperatorUpdated(address(0), operator);
    }

    // -------------------------------------------------------------------------
    // LST ERC20-like Internal Functions
    // -------------------------------------------------------------------------
    function _mintLST(address to, uint256 amount) internal {
        totalLSTSupply += amount;
        lstBalances[to] += amount;
        // Initialize user reward index to current index so they don't claim past rewards.
        if (userRewardIndex[to] == 0 && rewardIndex > 0) {
            userRewardIndex[to] = rewardIndex;
        }
    }

    function _burnLST(address from, uint256 amount) internal {
        if (lstBalances[from] < amount) revert InsufficientBalance();
        lstBalances[from] -= amount;
        totalLSTSupply -= amount;
    }

    function _transferLST(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (lstBalances[from] < amount) revert InsufficientBalance();
        // Settle pending rewards before balance changes.
        _settleUserRewards(from);
        _settleUserRewards(to);
        lstBalances[from] -= amount;
        lstBalances[to] += amount;
    }

    // -------------------------------------------------------------------------
    // Reward Accounting
    // -------------------------------------------------------------------------
    function _settleUserRewards(address user) internal {
        userRewardIndex[user] = rewardIndex;
    }

    /// @notice Returns the pending reward for a user based on their LST balance and reward index delta.
    function pendingRewards(address user) public view returns (uint256) {
        if (totalLSTSupply == 0) return 0;
        uint256 delta = rewardIndex - userRewardIndex[user];
        return (lstBalances[user] * delta) / PRECISION;
    }

    /// @notice Distributes rewards (in base token) proportionally to LST holders.
    /// @dev Increases the reward index so that each LST holder can claim their share.
    function distributeRewards(uint256 rewardAmount) public {
        if (rewardAmount == 0) revert AmountZero();

        uint256 feeAmount = (rewardAmount * feeBps) / BPS_DENOMINATOR;
        uint256 userShare = rewardAmount - feeAmount;

        accumulatedFees += feeAmount;

        if (totalLSTSupply > 0) {
            rewardIndex += (userShare * PRECISION) / totalLSTSupply;
        } else {
            // No holders; add user share to fees as well.
            accumulatedFees += userShare;
        }

        emit RewardsDistributed(rewardAmount, feeAmount, userShare);
    }

    // -------------------------------------------------------------------------
    // User Functions
    // -------------------------------------------------------------------------

    /// @notice Deposit base tokens to receive liquid staking tokens.
    /// @param amount Amount of base tokens to deposit.
    function deposit(uint256 amount) external notPaused {
        if (amount == 0) revert AmountZero();

        // Transfer base tokens from user to pool.
        bool ok = baseToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        uint256 lstAmount;
        if (totalLSTSupply == 0 || totalStakedBase == 0) {
            lstAmount = amount;
        } else {
            lstAmount = (amount * totalLSTSupply) / totalStakedBase;
        }
        if (lstAmount == 0) revert AmountZero();

        totalStakedBase += amount;
        _mintLST(msg.sender, lstAmount);

        emit Deposited(msg.sender, amount, lstAmount);
    }

    /// @notice Request withdrawal of base tokens by burning LST. Starts a 7-day unbonding period.
    /// @param lstAmount Amount of LST to burn.
    function requestWithdrawal(uint256 lstAmount) external notPaused {
        if (lstAmount == 0) revert AmountZero();
        if (lstBalances[msg.sender] < lstAmount) revert InsufficientBalance();

        Withdrawal storage existing = pendingWithdrawals[msg.sender];
        if (existing.baseAmount > 0 && !existing.claimed) revert WithdrawalPending();

        uint256 baseAmount;
        if (totalLSTSupply == 0 || totalStakedBase == 0) {
            baseAmount = lstAmount;
        } else {
            baseAmount = (lstAmount * totalStakedBase) / totalLSTSupply;
        }

        // Settle any pending rewards before burning.
        _settleUserRewards(msg.sender);
        _burnLST(msg.sender, lstAmount);
        totalStakedBase -= baseAmount;

        pendingWithdrawals[msg.sender] = Withdrawal({
            baseAmount: baseAmount,
            unbondAt: block.timestamp + UNBONDING_PERIOD,
            claimed: false
        });

        emit WithdrawalRequested(msg.sender, lstAmount, baseAmount, block.timestamp + UNBONDING_PERIOD);
    }

    /// @notice Claim base tokens after the unbonding period has elapsed.
    function claimWithdrawal() external notPaused {
        Withdrawal storage w = pendingWithdrawals[msg.sender];
        if (w.baseAmount == 0) revert NoPendingWithdrawal();
        if (w.claimed) revert WithdrawalAlreadyClaimed();
        if (block.timestamp < w.unbondAt) revert UnbondingNotComplete();

        w.claimed = true;
        uint256 amount = w.baseAmount;

        bool ok = baseToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit WithdrawalClaimed(msg.sender, amount);
    }

    /// @notice Claim accumulated staking rewards for the caller in base token.
    function claimRewards() external notPaused {
        uint256 pending = pendingRewards(msg.sender);
        if (pending == 0) revert AmountZero();

        _settleUserRewards(msg.sender);

        bool ok = baseToken.transfer(msg.sender, pending);
        if (!ok) revert TransferFailed();

        emit RewardClaimed(msg.sender, pending);
    }

    // -------------------------------------------------------------------------
    // LST ERC20-like Public Functions
    // -------------------------------------------------------------------------

    function transfer(address to, uint256 amount) external returns (bool) {
        _transferLST(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        lstAllowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = lstAllowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            lstAllowances[from][msg.sender] = allowed - amount;
        }
        _transferLST(from, to, amount);
        return true;
    }

    function allowance(address ownerAddr, address spender) external view returns (uint256) {
        return lstAllowances[ownerAddr][spender];
    }

    function balanceOf(address user) external view returns (uint256) {
        return lstBalances[user];
    }

    function totalSupply() external view returns (uint256) {
        return totalLSTSupply;
    }

    // -------------------------------------------------------------------------
    // Operator Functions
    // -------------------------------------------------------------------------

    /// @notice Operator stakes idle base tokens with the external validator.
    function stakeToValidator(uint256 amount) external onlyOperator {
        if (amount == 0) revert AmountZero();
        if (baseToken.balanceOf(address(this)) < amount) revert InsufficientBalance();

        // Effects before interactions to prevent reentrancy issues
        totalStakedWithValidator += amount;
        validator.stake(amount);

        emit StakedToValidator(msg.sender, amount);
    }

    /// @notice Operator unstakes base tokens from the external validator.
    function unstakeFromValidator(uint256 amount) external onlyOperator {
        if (amount == 0) revert AmountZero();
        if (totalStakedWithValidator < amount) revert InsufficientBalance();

        // Effects before interactions to prevent reentrancy issues
        totalStakedWithValidator -= amount;
        validator.unstake(amount);

        emit UnstakedFromValidator(msg.sender, amount);
    }

    /// @notice Operator harvests rewards from the validator and distributes them to LST holders.
    function harvestAndDistribute() external onlyOperator {
        uint256 rewards = validator.claimRewards();
        if (rewards > 0) {
            distributeRewards(rewards);
        }
    }

    // -------------------------------------------------------------------------
    // Owner Functions
    // -------------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /// @notice Set the staking fee in basis points. Cannot exceed MAX_FEE_BPS.
    function setStakingFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    /// @notice Owner collects accumulated protocol fees.
    function collectFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert AmountZero();
        accumulatedFees = 0;
        bool ok = baseToken.transfer(owner, amount);
        if (!ok) revert TransferFailed();
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    /// @notice Upgrade the logical implementation pointer (for proxy/indexer awareness).
    function upgrade(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert InvalidImplementation();
        address old = implementation;
        implementation = newImplementation;
        emit ImplementationUpgraded(old, newImplementation);
    }

    // -------------------------------------------------------------------------
    // View Helpers
    // -------------------------------------------------------------------------

    /// @notice Returns the exchange rate: base tokens per LST (scaled by PRECISION).
    function getExchangeRate() external view returns (uint256) {
        if (totalLSTSupply == 0) return PRECISION;
        return (totalStakedBase * PRECISION) / totalLSTSupply;
    }

    /// @notice Returns the amount of idle (unstaked) base tokens in the pool.
    function idleBase() external view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }

    /// @notice Returns withdrawal info for a user.
    function withdrawalInfo(address user)
        external
        view
        returns (uint256 baseAmount, uint256 unbondAt, bool claimed)
    {
        Withdrawal storage w = pendingWithdrawals[user];
        return (w.baseAmount, w.unbondAt, w.claimed);
    }
}
