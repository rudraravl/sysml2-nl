// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LiquidStakingVault
 * @notice A liquid staking vault that accepts native tokens, issues a 1:1 liquid staking
 *         derivative token, and distributes staking rewards with a 0.5% fee.
 */
contract LiquidStakingVault {
    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error ExceedsMaxDeposit();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferFailed();
    error InvalidYieldRate();
    error NoPendingRewards();
    error InvalidWithdrawalId();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposited(address indexed user, uint256 nativeAmount, uint256 derivativeAmount);
    event Withdrawn(address indexed user, uint256 derivativeAmount, uint256 nativeAmount);
    event RewardsClaimed(address indexed user, uint256 rewardAmount, uint256 feeAmount);
    event RewardsDeposited(address indexed from, uint256 amount);
    event YieldRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event UnderlyingWithdrawalInitiated(uint256 amount, bytes32 indexed withdrawalId);
    event WithdrawalMarkedReady(bytes32 indexed withdrawalId);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MAX_DEPOSIT_PER_TX = 1000 ether;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint8 public constant DECIMALS = 18;
    uint256 private constant ACC_REWARD_PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // Roles
    // -----------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeRecipient;

    // -----------------------------------------------------------------------
    // Derivative token state (ERC20-like)
    // -----------------------------------------------------------------------
    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -----------------------------------------------------------------------
    // Reward state
    // -----------------------------------------------------------------------
    uint256 public yieldRate; // reward per block per staked token, scaled by 1e18
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare; // accumulated reward per share, scaled by ACC_REWARD_PRECISION
    uint256 public rewardReserve; // native tokens reserved for reward payouts

    // -----------------------------------------------------------------------
    // User info
    // -----------------------------------------------------------------------
    struct UserInfo {
        uint256 depositedNative; // total native tokens deposited historically
        uint256 rewardDebt;      // reward debt for accounting
        uint256 pendingRewards;  // rewards accrued but not yet claimed
    }
    mapping(address => UserInfo) public userInfo;

    // -----------------------------------------------------------------------
    // Underlying withdrawal tracking
    // -----------------------------------------------------------------------
    struct PendingWithdrawal {
        uint256 amount;
        bool ready;
    }
    mapping(bytes32 => PendingWithdrawal) public pendingWithdrawals;

    // -----------------------------------------------------------------------
    // Reentrancy guard
    // -----------------------------------------------------------------------
    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert Unauthorized();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Access control modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    /**
     * @param _name            Name of the derivative token.
     * @param _symbol          Symbol of the derivative token.
     * @param _operator        Address authorized to update yield rate and manage withdrawals.
     * @param _feeRecipient    Address that receives the 0.5% reward fee.
     * @param _initialYieldRate Initial yield rate (reward per block per staked token, scaled by 1e18).
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _operator,
        address _feeRecipient,
        uint256 _initialYieldRate
    ) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        if (_initialYieldRate == 0) revert InvalidYieldRate();

        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        yieldRate = _initialYieldRate;
        name = _name;
        symbol = _symbol;
        lastRewardBlock = block.number;

        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit YieldRateUpdated(0, _initialYieldRate);
    }

    // -----------------------------------------------------------------------
    // Admin functions
    // -----------------------------------------------------------------------

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function updateYieldRate(uint256 _newRate) external onlyOperator {
        if (_newRate == 0) revert InvalidYieldRate();
        _updateRewards();
        emit YieldRateUpdated(yieldRate, _newRate);
        yieldRate = _newRate;
    }

    // -----------------------------------------------------------------------
    // Reward funding
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit native tokens into the reward reserve.
     * @dev Typically called by the operator after withdrawing rewards from the
     *      underlying PoS staking mechanism. Anyone may contribute rewards.
     */
    function depositRewards() external payable {
        if (msg.value == 0) revert ZeroAmount();
        rewardReserve += msg.value;
        emit RewardsDeposited(msg.sender, msg.value);
    }

    // -----------------------------------------------------------------------
    // Reward accrual (internal)
    // -----------------------------------------------------------------------

    function _updateRewards() internal {
        // No new blocks to process; avoids strict equality on elapsed blocks.
        if (block.number <= lastRewardBlock) return;

        // When there are no staked shares, simply advance the checkpoint.
        if (totalSupply < 1) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocksElapsed = block.number - lastRewardBlock;

        // Compute the per-share increment directly from the yield rate so we never
        // multiply a value that was just truncated by a division. The per-share
        // increment is in ACC_REWARD_PRECISION units (1e18), matching accRewardPerShare.
        uint256 perShareInc = yieldRate * blocksElapsed;

        // Total native rewards that would be distributed this update.
        uint256 rewards = (perShareInc * totalSupply) / ACC_REWARD_PRECISION;

        // Cap by the available reserve. When capping, derive the per-share increment
        // from the capped native amount so accounting stays consistent.
        if (rewards > rewardReserve) {
            rewards = rewardReserve;
            perShareInc = (rewards * ACC_REWARD_PRECISION) / totalSupply;
        }

        // Apply accrual only when there is something to distribute. Using a
        // positive threshold avoids strict-equality comparisons on derived values.
        if (rewards > 0) {
            rewardReserve -= rewards;
            accRewardPerShare += perShareInc;
        }

        lastRewardBlock = block.number;
    }

    /// Settle a user's pending rewards at their current balance without updating rewardDebt.
    function _settleUser(address _user) internal {
        UserInfo storage info = userInfo[_user];
        uint256 owed = (balanceOf[_user] * accRewardPerShare) / ACC_REWARD_PRECISION;
        if (owed >= info.rewardDebt) {
            info.pendingRewards += owed - info.rewardDebt;
        }
    }

    /// Set rewardDebt to match the user's current balance at the current accRewardPerShare.
    function _syncRewardDebt(address _user) internal {
        userInfo[_user].rewardDebt = (balanceOf[_user] * accRewardPerShare) / ACC_REWARD_PRECISION;
    }

    /// Settle a user and immediately sync their rewardDebt (use when balance is not changing).
    function _settleAndSync(address _user) internal {
        _settleUser(_user);
        _syncRewardDebt(_user);
    }

    // -----------------------------------------------------------------------
    // User functions: deposit
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit native tokens and receive an equivalent amount of derivative tokens.
     * @dev Mints derivative tokens 1:1 with the deposited native amount.
     */
    function deposit() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (msg.value > MAX_DEPOSIT_PER_TX) revert ExceedsMaxDeposit();

        _updateRewards();
        _settleUser(msg.sender);

        uint256 derivativeAmount = msg.value;
        userInfo[msg.sender].depositedNative += msg.value;
        _mint(msg.sender, derivativeAmount);
        _syncRewardDebt(msg.sender);

        emit Deposited(msg.sender, msg.value, derivativeAmount);
    }

    // -----------------------------------------------------------------------
    // User functions: withdraw
    // -----------------------------------------------------------------------

    /**
     * @notice Withdraw native tokens by burning derivative tokens.
     * @param derivativeAmount Amount of derivative tokens to burn.
     */
    function withdraw(uint256 derivativeAmount) external nonReentrant {
        if (derivativeAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < derivativeAmount) revert InsufficientBalance();

        _updateRewards();
        _settleUser(msg.sender);

        _burn(msg.sender, derivativeAmount);
        _syncRewardDebt(msg.sender);

        // Checks-effects-interactions: transfer after state updates
        (bool success, ) = payable(msg.sender).call{value: derivativeAmount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, derivativeAmount, derivativeAmount);
    }

    // -----------------------------------------------------------------------
    // User functions: claim rewards
    // -----------------------------------------------------------------------

    /**
     * @notice Claim accrued staking rewards. A 0.5% fee is deducted and sent to the fee recipient.
     */
    function claimRewards() external nonReentrant {
        _updateRewards();
        _settleAndSync(msg.sender);

        UserInfo storage info = userInfo[msg.sender];
        uint256 amount = info.pendingRewards;
        if (amount == 0) revert NoPendingRewards();

        // Effects: clear pending before external transfers
        info.pendingRewards = 0;

        uint256 fee = (amount * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
        uint256 netReward = amount - fee;

        // Interactions
        if (fee > 0) {
            (bool feeSuccess, ) = payable(feeRecipient).call{value: fee}("");
            if (!feeSuccess) revert TransferFailed();
        }
        (bool rewardSuccess, ) = payable(msg.sender).call{value: netReward}("");
        if (!rewardSuccess) revert TransferFailed();

        emit RewardsClaimed(msg.sender, netReward, fee);
    }

    // -----------------------------------------------------------------------
    // Operator functions: underlying staking withdrawals
    // -----------------------------------------------------------------------

    /**
     * @notice Initiate a withdrawal from the underlying PoS staking mechanism.
     * @param amount       Amount of native tokens to withdraw from staking.
     * @param withdrawalId  Unique identifier for tracking this withdrawal.
     */
    function initiateUnderlyingWithdrawal(uint256 amount, bytes32 withdrawalId)
        external
        onlyOperator
    {
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientBalance();
        pendingWithdrawals[withdrawalId] = PendingWithdrawal({amount: amount, ready: false});
        emit UnderlyingWithdrawalInitiated(amount, withdrawalId);
    }

    /**
     * @notice Mark a previously initiated underlying withdrawal as ready.
     * @param withdrawalId Identifier of the withdrawal to mark as ready.
     */
    function markWithdrawalReady(bytes32 withdrawalId) external onlyOperator {
        PendingWithdrawal storage pw = pendingWithdrawals[withdrawalId];
        if (pw.amount == 0) revert InvalidWithdrawalId();
        pw.ready = true;
        emit WithdrawalMarkedReady(withdrawalId);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /**
     * @notice Returns the pending (unclaimed) rewards for a user.
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage info = userInfo[_user];
        uint256 currentAccRewardPerShare = accRewardPerShare;

        // Mirror _updateRewards without mutating state. Compute the per-share
        // increment directly to avoid divide-before-multiply precision loss.
        if (totalSupply > 0 && block.number > lastRewardBlock) {
            uint256 blocksElapsed = block.number - lastRewardBlock;
            uint256 perShareInc = yieldRate * blocksElapsed;
            uint256 rewards = (perShareInc * totalSupply) / ACC_REWARD_PRECISION;
            if (rewards > rewardReserve) {
                rewards = rewardReserve;
                perShareInc = (rewards * ACC_REWARD_PRECISION) / totalSupply;
            }
            if (rewards > 0) {
                currentAccRewardPerShare += perShareInc;
            }
        }

        uint256 owed = (balanceOf[_user] * currentAccRewardPerShare) / ACC_REWARD_PRECISION;
        if (owed >= info.rewardDebt) {
            return info.pendingRewards + (owed - info.rewardDebt);
        }
        return info.pendingRewards;
    }

    /**
     * @notice Returns the total native tokens deposited by a user historically.
     */
    function depositedNativeOf(address _user) external view returns (uint256) {
        return userInfo[_user].depositedNative;
    }

    /**
     * @notice Returns the details of a pending underlying withdrawal.
     */
    function getPendingWithdrawal(bytes32 withdrawalId)
        external
        view
        returns (uint256 amount, bool ready)
    {
        PendingWithdrawal storage pw = pendingWithdrawals[withdrawalId];
        return (pw.amount, pw.ready);
    }

    // -----------------------------------------------------------------------
    // ERC20 internal helpers
    // -----------------------------------------------------------------------

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // -----------------------------------------------------------------------
    // ERC20 external functions
    // -----------------------------------------------------------------------

    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        _updateRewards();
        _settleUser(msg.sender);
        _settleUser(to);

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        _syncRewardDebt(msg.sender);
        _syncRewardDebt(to);

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        nonReentrant
        returns (bool)
    {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        _updateRewards();
        _settleUser(from);
        _settleUser(to);

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        _syncRewardDebt(from);
        _syncRewardDebt(to);

        emit Transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Receive — reject direct sends to preserve accounting integrity
    // -----------------------------------------------------------------------
    receive() external payable {
        revert();
    }
}
