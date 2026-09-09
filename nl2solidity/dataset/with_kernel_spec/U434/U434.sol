// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GamingToken {
    // ============ Token Metadata ============
    string public constant name = "Gaming Platform Token";
    string public constant symbol = "GPT";
    uint8 public constant decimals = 18;

    // ============ ERC20 State ============
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ============ Access Control ============
    address public operator;

    // ============ Pause State ============
    bool public paused;

    // ============ Reward Configuration ============
    /// @notice Reward points accrued per staked token per second, in 1e18 precision
    uint256 public rewardRate;
    uint256 public constant DAILY_MINT_CAP = 10_000 * 10**18;
    uint256 public dailyMinted;
    uint256 public currentMintDay;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 50 bps = 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant POINTS_PRECISION = 1e18;

    // ============ User State ============
    struct UserInfo {
        uint256 platformBalance;          // deposited, unstaked tokens in the platform
        uint256 stakedBalance;            // staked tokens earning additional rewards
        uint256 accumulatedRewardPoints;  // unclaimed reward points (1e18 precision)
        uint256 lastRewardUpdate;         // timestamp of last reward accrual
    }
    mapping(address => UserInfo) private _userInfo;

    // ============ Aggregate State ============
    uint256 public totalStaked;
    uint256 public totalPlatformDeposits; // sum of platformBalance across all users

    // ============ Reentrancy Guard ============
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ============ Events ============
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amountWithdrawn, uint256 fee);
    event RewardClaimed(address indexed user, uint256 points, uint256 tokens);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event TokensMinted(address indexed to, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event PauseChanged(bool isPaused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event ReserveWithdrawn(address indexed to, uint256 amount);

    // ============ Custom Errors ============
    error NotOperator();
    error TransfersPaused();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientPlatformBalance();
    error InsufficientStakedBalance();
    error DailyMintCapExceeded();
    error ZeroAmount();
    error NoRewardToClaim();
    error InsufficientReserve();
    error ReentrantCall();

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TransfersPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ============ Constructor ============
    constructor(uint256 initialSupply) {
        if (msg.sender == address(0)) revert ZeroAddress();
        operator = msg.sender;
        _totalSupply = initialSupply;
        _balances[msg.sender] = initialSupply;
        _status = _NOT_ENTERED;
        currentMintDay = block.timestamp / 1 days;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    // ============ ERC20 Views ============
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    // ============ ERC20 Mutations ============
    function transfer(address to, uint256 amount) external whenNotPaused nonReentrant returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused nonReentrant returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        _allowances[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    // ============ Platform: Deposit ============
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _transfer(msg.sender, address(this), amount);
        _userInfo[msg.sender].platformBalance += amount;
        totalPlatformDeposits += amount;
        emit Deposit(msg.sender, amount);
    }

    // ============ Platform: Withdraw (0.5% fee) ============
    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserInfo storage user = _userInfo[msg.sender];
        if (user.platformBalance < amount) revert InsufficientPlatformBalance();

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountToUser = amount - fee;

        // Effects: update state before interaction
        user.platformBalance -= amount;
        totalPlatformDeposits -= amount;

        // Interaction: transfer net amount back to user; fee stays in contract as reserve
        _transfer(address(this), msg.sender, amountToUser);

        emit Withdraw(msg.sender, amountToUser, fee);
    }

    // ============ Staking ============
    function stake(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserInfo storage user = _userInfo[msg.sender];
        if (user.platformBalance < amount) revert InsufficientPlatformBalance();

        // Accrue pending rewards before changing staked balance
        _updateReward(msg.sender);

        user.platformBalance -= amount;
        user.stakedBalance += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserInfo storage user = _userInfo[msg.sender];
        if (user.stakedBalance < amount) revert InsufficientStakedBalance();

        // Accrue pending rewards before changing staked balance
        _updateReward(msg.sender);

        user.stakedBalance -= amount;
        user.platformBalance += amount;
        totalStaked -= amount;

        emit Unstaked(msg.sender, amount);
    }

    // ============ Reward Logic ============
    function _updateReward(address userAddr) internal {
        UserInfo storage user = _userInfo[userAddr];
        if (user.lastRewardUpdate == 0) {
            user.lastRewardUpdate = block.timestamp;
            return;
        }
        if (user.stakedBalance > 0 && rewardRate > 0) {
            uint256 timeElapsed = block.timestamp - user.lastRewardUpdate;
            if (timeElapsed > 0) {
                uint256 newPoints = (user.stakedBalance * rewardRate * timeElapsed) / POINTS_PRECISION;
                user.accumulatedRewardPoints += newPoints;
            }
        }
        user.lastRewardUpdate = block.timestamp;
    }

    function pendingRewardPoints(address userAddr) external view returns (uint256) {
        UserInfo storage user = _userInfo[userAddr];
        if (user.lastRewardUpdate == 0 || user.stakedBalance == 0 || rewardRate == 0) {
            return user.accumulatedRewardPoints;
        }
        uint256 timeElapsed = block.timestamp - user.lastRewardUpdate;
        uint256 pending = (user.stakedBalance * rewardRate * timeElapsed) / POINTS_PRECISION;
        return user.accumulatedRewardPoints + pending;
    }

    function claimReward() external whenNotPaused nonReentrant {
        // Accrue all pending rewards up to now
        _updateReward(msg.sender);

        UserInfo storage user = _userInfo[msg.sender];
        uint256 points = user.accumulatedRewardPoints;
        if (points < POINTS_PRECISION) revert NoRewardToClaim();

        // Compute claimable points exactly divisible by POINTS_PRECISION, preserving remainder
        uint256 remainder = points % POINTS_PRECISION;
        uint256 claimedPoints = points - remainder;
        uint256 tokenAmount = claimedPoints / POINTS_PRECISION;

        // Ensure the reserve can cover the claim
        uint256 reserve = _balances[address(this)] - totalPlatformDeposits;
        if (tokenAmount > reserve) revert InsufficientReserve();

        // Effects: deduct claimed points, keep remainder for future claims
        user.accumulatedRewardPoints = remainder;

        // Interaction: transfer tokens from reserve to user
        _transfer(address(this), msg.sender, tokenAmount);

        emit RewardClaimed(msg.sender, claimedPoints, tokenAmount);
    }

    // ============ Daily Mint Reset ============
    function _resetDailyMintIfNeeded() internal {
        uint256 today = block.timestamp / 1 days;
        if (today > currentMintDay) {
            dailyMinted = 0;
            currentMintDay = today;
        }
    }

    // ============ Operator Functions ============

    function setRewardRate(uint256 newRate) external onlyOperator {
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    function mint(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _resetDailyMintIfNeeded();
        if (dailyMinted + amount > DAILY_MINT_CAP) revert DailyMintCapExceeded();
        dailyMinted += amount;
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function setPaused(bool _paused) external onlyOperator {
        if (paused == _paused) return;
        paused = _paused;
        emit PauseChanged(_paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function withdrawReserve(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        uint256 reserve = _balances[address(this)] - totalPlatformDeposits;
        if (amount > reserve) revert InsufficientReserve();
        _transfer(address(this), to, amount);
        emit ReserveWithdrawn(to, amount);
    }

    // ============ View Functions ============
    function getUserInfo(address userAddr) external view returns (
        uint256 platformBalance,
        uint256 stakedBalance,
        uint256 accumulatedRewardPoints,
        uint256 lastRewardUpdate
    ) {
        UserInfo storage user = _userInfo[userAddr];
        return (
            user.platformBalance,
            user.stakedBalance,
            user.accumulatedRewardPoints,
            user.lastRewardUpdate
        );
    }

    function reserveBalance() external view returns (uint256) {
        return _balances[address(this)] - totalPlatformDeposits;
    }
}
