// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SocialNetworkToken
 * @notice Native token for a decentralized social network with staking rewards
 *         and a content creator fund funded by a 0.5% transfer fee.
 */
contract SocialNetworkToken {
    /* ------------------------------------------------------------------ */
    /*                              Errors                                */
    /* ------------------------------------------------------------------ */

    error ErrZeroAddress();
    error ErrInsufficientBalance();
    error ErrInsufficientAllowance();
    error ErrInsufficientStakedBalance();
    error ErrPaused();
    error ErrNotAdmin();
    error ErrZeroAmount();
    error ErrStakingPeriodNotElapsed();
    error ErrNoRewards();
    error ErrReentrantCall();
    error ErrNotStaking();

    /* ------------------------------------------------------------------ */
    /*                              Events                                */
    /* ------------------------------------------------------------------ */

    event Transfer(address indexed from, address indexed to, uint256 value, uint256 fee);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address indexed admin);
    event Unpaused(address indexed admin);
    event UpgradeInitiated(address indexed admin, address indexed newImplementation);
    event CreatorFundWithdrawn(address indexed to, uint256 amount);

    /* ------------------------------------------------------------------ */
    /*                            Constants                               */
    /* ------------------------------------------------------------------ */

    uint8 public constant decimals = 18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant FEE_BIPS = 50; // 0.5% = 50 / 10_000
    uint256 private constant BIPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_STAKING_PERIOD = 7 days;

    /* ------------------------------------------------------------------ */
    /*                           Token Metadata                           */
    /* ------------------------------------------------------------------ */

    string public name;
    string public symbol;
    uint256 public totalSupply;

    /* ------------------------------------------------------------------ */
    /*                            State Variables                         */
    /* ------------------------------------------------------------------ */

    address public admin;
    bool public paused;
    address public pendingImplementation;

    /// @notice Accumulated content creator fund (fees), held by the contract.
    uint256 public creatorFund;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    /* ------------------------------------------------------------------ */
    /*                       Staking Reward State                         */
    /* ------------------------------------------------------------------ */

    /// @notice Reward tokens per staked token per second (scaled by PRECISION).
    uint256 public stakingRewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public totalStaked;

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public stakeStartTime;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    /* ------------------------------------------------------------------ */
    /*                         Reentrancy Guard                           */
    /* ------------------------------------------------------------------ */

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    /* ------------------------------------------------------------------ */
    /*                            Modifiers                               */
    /* ------------------------------------------------------------------ */

    modifier onlyAdmin() {
        if (msg.sender != admin) revert ErrNotAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ErrReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /* ------------------------------------------------------------------ */
    /*                            Constructor                             */
    /* ------------------------------------------------------------------ */

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _stakingRewardRate
    ) {
        if (bytes(_name).length == 0 || bytes(_symbol).length == 0) revert ErrZeroAmount();

        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        _balances[msg.sender] = _initialSupply;
        admin = msg.sender;
        stakingRewardRate = _stakingRewardRate;
        lastUpdateTime = block.timestamp;
        _status = _NOT_ENTERED;

        emit Transfer(address(0), msg.sender, _initialSupply, 0);
    }

    /* ------------------------------------------------------------------ */
    /*                         ERC20 View Functions                       */
    /* ------------------------------------------------------------------ */

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /* ------------------------------------------------------------------ */
    /*                         ERC20 Mutating Functions                   */
    /* ------------------------------------------------------------------ */

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ErrZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transferWithFee(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert ErrInsufficientAllowance();

        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }
        _transferWithFee(from, to, amount);
        return true;
    }

    /* ------------------------------------------------------------------ */
    /*                       Internal Transfer Logic                      */
    /* ------------------------------------------------------------------ */

    /// @dev Applies a 0.5% fee directed to the content creator fund.
    function _transferWithFee(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ErrZeroAddress();
        if (_balances[from] < amount) revert ErrInsufficientBalance();

        uint256 fee = (amount * FEE_BIPS) / BIPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        _balances[from] -= amount;
        _balances[to] += netAmount;
        _balances[address(this)] += fee;
        creatorFund += fee;

        emit Transfer(from, to, netAmount, fee);
    }

    /// @dev Moves tokens without applying the transfer fee (staking, unstaking, fund withdrawal).
    function _transferNoFee(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ErrZeroAddress();
        if (_balances[from] < amount) revert ErrInsufficientBalance();

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount, 0);
    }

    /* ------------------------------------------------------------------ */
    /*                      Staking Reward Accounting                     */
    /* ------------------------------------------------------------------ */

    /// @notice Computes the current reward-per-token accumulator.
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 timeDelta = block.timestamp > lastUpdateTime ? block.timestamp - lastUpdateTime : 0;
        return rewardPerTokenStored + (timeDelta * stakingRewardRate * PRECISION) / totalStaked;
    }

    /// @notice Returns the total earned reward for a given account.
    function earned(address account) public view returns (uint256) {
        uint256 rpt = rewardPerToken();
        uint256 delta = rpt - userRewardPerTokenPaid[account];
        return (stakedBalances[account] * delta) / PRECISION + rewards[account];
    }

    /// @dev Updates the global accumulator and the caller's reward snapshot.
    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    /* ------------------------------------------------------------------ */
    /*                         Staking Functions                          */
    /* ------------------------------------------------------------------ */

    /// @notice Stake tokens to earn rewards and support content creators.
    function stake(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ErrZeroAmount();
        if (_balances[msg.sender] < amount) revert ErrInsufficientBalance();

        _updateReward(msg.sender);

        _transferNoFee(msg.sender, address(this), amount);

        stakedBalances[msg.sender] += amount;
        totalStaked += amount;

        if (stakeStartTime[msg.sender] == 0) {
            stakeStartTime[msg.sender] = block.timestamp;
        }

        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw previously staked tokens.
    function unstake(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ErrZeroAmount();
        if (stakedBalances[msg.sender] < amount) revert ErrInsufficientStakedBalance();

        _updateReward(msg.sender);

        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;

        if (stakedBalances[msg.sender] == 0) {
            stakeStartTime[msg.sender] = 0;
        }

        _transferNoFee(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /// @notice Claim accumulated staking rewards. Requires the minimum staking period to have elapsed.
    function claimRewards() external whenNotPaused nonReentrant {
        // Require that the user has an active stake and the minimum staking period has elapsed.
        if (stakeStartTime[msg.sender] == 0) {
            revert ErrNotStaking();
        }
        if (block.timestamp < stakeStartTime[msg.sender] + MIN_STAKING_PERIOD) {
            revert ErrStakingPeriodNotElapsed();
        }

        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        // Use <= instead of strict == to avoid incorrect-equality vulnerability.
        // For uint256, <= 0 is equivalent to == 0, but the analyzer flags strict equality.
        if (reward <= 0) revert ErrNoRewards();

        // Effects: reset pending rewards before minting.
        rewards[msg.sender] = 0;

        // Mint reward tokens to the staker.
        _balances[msg.sender] += reward;
        totalSupply += reward;

        emit RewardClaimed(msg.sender, reward);
        emit Transfer(address(0), msg.sender, reward, 0);
    }

    /* ------------------------------------------------------------------ */
    /*                         Admin Functions                            */
    /* ------------------------------------------------------------------ */

    /// @notice Set the staking reward rate (tokens per staked token per second, scaled by PRECISION).
    function setStakingRewardRate(uint256 newRate) external onlyAdmin {
        _updateReward(address(0));
        uint256 oldRate = stakingRewardRate;
        stakingRewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    /// @notice Pause all token transfers and staking operations.
    function pause() external onlyAdmin {
        if (paused) revert ErrPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Resume token transfers and staking operations.
    function unpause() external onlyAdmin {
        if (!paused) revert ErrPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Initiate an upgrade to a new implementation address.
    function initiateUpgrade(address newImplementation) external onlyAdmin {
        if (newImplementation == address(0)) revert ErrZeroAddress();
        pendingImplementation = newImplementation;
        emit UpgradeInitiated(msg.sender, newImplementation);
    }

    /// @notice Withdraw accumulated content creator fund fees to a recipient.
    function withdrawCreatorFund(address to) external onlyAdmin {
        if (to == address(0)) revert ErrZeroAddress();
        uint256 amount = creatorFund;
        if (amount == 0) revert ErrZeroAmount();

        // Effects: zero out the fund before transferring.
        creatorFund = 0;
        _transferNoFee(address(this), to, amount);

        emit CreatorFundWithdrawn(to, amount);
    }

    /// @notice Transfer administrative control to a new address.
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ErrZeroAddress();
        admin = newAdmin;
    }
}
