// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LiquidStakingVault
 * @notice A liquid staking vault for a proof-of-stake blockchain.
 *         Users deposit native currency (ETH) and receive liquid staking tokens (LST)
 *         representing their staked position. Staked assets accrue rewards over time
 *         based on a per-second reward rate set by the operator. Withdrawals are
 *         subject to a fixed 7-day unbonding period. The owner may pause all
 *         deposit and withdrawal operations in case of emergency.
 */
contract LiquidStakingVault {
    // -----------------------------------------------------------------------
    // ERC20 metadata
    // -----------------------------------------------------------------------
    string public constant name = "Liquid Staking Token";
    string public constant symbol = "LST";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -----------------------------------------------------------------------
    // Staking configuration
    // -----------------------------------------------------------------------
    uint256 public constant MIN_DEPOSIT = 0.1 ether;
    uint256 public constant UNBONDING_PERIOD = 7 days;
    uint256 private constant ACC_REWARD_PRECISION = 1e18;

    address public owner;
    address public operator;
    bool public paused;

    // -----------------------------------------------------------------------
    // Reward accounting
    // -----------------------------------------------------------------------
    uint256 public rewardRate; // reward tokens (ETH) distributed per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerShareStored; // accumulated reward per share, scaled by 1e18
    mapping(address => uint256) public userRewardPerSharePaid;
    mapping(address => uint256) public rewards;

    // -----------------------------------------------------------------------
    // Pool state
    // -----------------------------------------------------------------------
    uint256 public totalStakedAssets;       // total native currency deposited by users
    uint256 public totalReservedForWithdrawals; // native currency locked pending unbonding
    uint256 public operatorStaked;          // native currency the operator has staked on-chain
    uint256 public totalRewardsDistributed;

    struct WithdrawalRequest {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }
    mapping(address => WithdrawalRequest) public withdrawalRequests;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed user, uint256 amount, uint256 sharesMinted);
    event WithdrawalRequested(address indexed user, uint256 shares, uint256 amount, uint256 unlockTime);
    event WithdrawalClaimed(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDistributed(uint256 amount);
    event OperatorStaked(address indexed operator, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address account);
    event Unpaused(address account);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error ContractPaused();
    error MinDepositNotMet();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferFailed();
    error WithdrawalNotReady();
    error NoWithdrawalRequest();
    error InvalidAmount();
    error ExistingWithdrawalRequest();
    error ZeroAddress();
    error InsufficientContractBalance();
    error AlreadyClaimed();
    error NoRewardsToClaim();

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

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier updateReward(address account) {
        rewardPerShareStored = _rewardPerShare();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerSharePaid[account] = rewardPerShareStored;
        }
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _operator, uint256 _initialRewardRate) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        rewardRate = _initialRewardRate;
        lastUpdateTime = block.timestamp;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit RewardRateUpdated(0, _initialRewardRate);
    }

    // -----------------------------------------------------------------------
    // Receive — accept native currency (e.g. reward funding)
    // -----------------------------------------------------------------------
    receive() external payable {}

    // -----------------------------------------------------------------------
    // ERC20 functions
    // -----------------------------------------------------------------------
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += value;
        unchecked {
            balanceOf[to] += value;
        }
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= value;
            totalSupply -= value;
        }
        emit Transfer(from, address(0), value);
    }

    // -----------------------------------------------------------------------
    // Reward calculation
    // -----------------------------------------------------------------------
    function _rewardPerShare() internal view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerShareStored;
        }
        uint256 elapsed = block.timestamp > lastUpdateTime ? block.timestamp - lastUpdateTime : 0;
        return rewardPerShareStored + (rewardRate * elapsed * ACC_REWARD_PRECISION) / totalSupply;
    }

    function rewardPerShare() public view returns (uint256) {
        return _rewardPerShare();
    }

    function earned(address account) public view returns (uint256) {
        uint256 delta = _rewardPerShare() - userRewardPerSharePaid[account];
        return (balanceOf[account] * delta) / ACC_REWARD_PRECISION + rewards[account];
    }

    // -----------------------------------------------------------------------
    // User actions
    // -----------------------------------------------------------------------
    /**
     * @notice Deposit native currency and receive LST at the current exchange rate.
     */
    function deposit() external payable whenNotPaused updateReward(msg.sender) {
        if (msg.value < MIN_DEPOSIT) revert MinDepositNotMet();

        uint256 sharesToMint;
        if (totalSupply == 0 || totalStakedAssets == 0) {
            sharesToMint = msg.value;
        } else {
            sharesToMint = (msg.value * totalSupply) / totalStakedAssets;
        }
        if (sharesToMint == 0) revert InvalidAmount();

        totalStakedAssets += msg.value;
        _mint(msg.sender, sharesToMint);

        emit Deposit(msg.sender, msg.value, sharesToMint);
    }

    /**
     * @notice Request withdrawal of staked assets. Burns LST and schedules an
     *         unbonding-period-locked withdrawal of native currency.
     * @param shares Amount of LST to redeem.
     */
    function requestWithdrawal(uint256 shares) external whenNotPaused updateReward(msg.sender) {
        if (shares == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < shares) revert InsufficientBalance();
        if (withdrawalRequests[msg.sender].amount > 0) revert ExistingWithdrawalRequest();

        uint256 assetsToWithdraw;
        if (totalSupply == 0) {
            assetsToWithdraw = shares;
        } else {
            assetsToWithdraw = (shares * totalStakedAssets) / totalSupply;
        }
        if (assetsToWithdraw == 0) revert InvalidAmount();

        _burn(msg.sender, shares);
        totalStakedAssets -= assetsToWithdraw;
        totalReservedForWithdrawals += assetsToWithdraw;

        uint256 unlockTime = block.timestamp + UNBONDING_PERIOD;
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: assetsToWithdraw,
            unlockTime: unlockTime,
            claimed: false
        });

        emit WithdrawalRequested(msg.sender, shares, assetsToWithdraw, unlockTime);
    }

    /**
     * @notice Claim unlocked native currency after the unbonding period has elapsed.
     */
    function claimWithdrawal() external whenNotPaused {
        WithdrawalRequest storage req = withdrawalRequests[msg.sender];
        if (req.amount == 0) revert NoWithdrawalRequest();
        if (req.claimed) revert AlreadyClaimed();
        if (block.timestamp < req.unlockTime) revert WithdrawalNotReady();

        uint256 amount = req.amount;
        req.claimed = true;
        totalReservedForWithdrawals -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit WithdrawalClaimed(msg.sender, amount);
    }

    /**
     * @notice Claim accumulated staking rewards in native currency.
     */
    function claimRewards() external whenNotPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward <= 0) revert NoRewardsToClaim();
        if (address(this).balance < reward) revert InsufficientContractBalance();

        rewards[msg.sender] = 0;
        totalRewardsDistributed += reward;

        (bool success, ) = payable(msg.sender).call{value: reward}("");
        if (!success) revert TransferFailed();

        emit RewardPaid(msg.sender, reward);
        emit RewardsDistributed(reward);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------
    /**
     * @notice Initiate staking of idle native currency on the underlying PoS chain.
     *         Moves idle (non-reserved) funds into the operator-staked bucket and
     *         emits an event for off-chain staking infrastructure to act upon.
     * @param amount Amount of native currency to stake.
     */
    function initiateStaking(uint256 amount) external onlyOperator whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        uint256 idle = address(this).balance - totalReservedForWithdrawals;
        if (amount > idle) revert InsufficientContractBalance();

        operatorStaked += amount;
        emit OperatorStaked(msg.sender, amount);
    }

    /**
     * @notice Update the per-second reward rate. Accrues pending rewards first.
     * @param newRate New reward rate (native currency per second).
     */
    function updateRewardRate(uint256 newRate) external onlyOperator updateReward(address(0)) {
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    // -----------------------------------------------------------------------
    // Owner functions
    // -----------------------------------------------------------------------
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    // -----------------------------------------------------------------------
    // View helpers
    // -----------------------------------------------------------------------
    function getExchangeRate() external view returns (uint256) {
        if (totalSupply == 0) return ACC_REWARD_PRECISION;
        return (totalStakedAssets * ACC_REWARD_PRECISION) / totalSupply;
    }

    function getWithdrawalRequest(address account)
        external
        view
        returns (uint256 amount, uint256 unlockTime, bool claimed, bool claimable)
    {
        WithdrawalRequest storage req = withdrawalRequests[account];
        return (
            req.amount,
            req.unlockTime,
            req.claimed,
            req.amount > 0 && !req.claimed && block.timestamp >= req.unlockTime
        );
    }
}
