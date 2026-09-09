// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IYieldStrategy {
    function deposit(uint256 amount) external returns (uint256 receiptAmount);
    function withdraw(uint256 receiptAmount) external returns (uint256 underlyingAmount);
    function claimYield() external returns (uint256 yieldAmount);
    function receiptToken() external view returns (address);
    function underlyingToken() external view returns (address);
}

contract YieldAggregator {
    // --------- Errors ---------
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotSupported(address token);
    error TokenAlreadySupported(address token);
    error MaxSupportedTokensReached();
    error InsufficientBalance(uint256 available, uint256 requested);
    error NothingToClaim();
    error FeeTooHigh();
    error Reentrancy();
    error LendingPoolNotApproved(address pool);
    error ActivePositions();
    error TransferFailed();
    error InvalidReceiptAmount();
    error InvalidWithdrawnAmount();

    // --------- Events ---------
    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 receiptAmount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 receiptAmount);
    event YieldClaimed(address indexed user, address indexed token, uint256 grossYield, uint256 fee, uint256 netYield);
    event ReceiptStaked(address indexed user, address indexed receiptToken, uint256 amount);
    event ReceiptUnstaked(address indexed user, address indexed receiptToken, uint256 amount);
    event RewardClaimed(address indexed user, uint256 rewardAmount);
    event TokenAdded(address indexed token, address indexed strategy, address receiptToken);
    event TokenRemoved(address indexed token);
    event StrategyUpdated(address indexed token, address indexed oldStrategy, address indexed newStrategy);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event LendingPoolApproved(address indexed pool);
    event LendingPoolRevoked(address indexed pool);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardsFunded(uint256 amount);

    // --------- Constants ---------
    uint256 public constant MAX_SUPPORTED_TOKENS = 10;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_PLATFORM_FEE = 500; // 5% in bps
    uint256 private constant REWARD_PRECISION = 1e18;

    // --------- State ---------
    address public owner;
    uint256 public platformFee = DEFAULT_PLATFORM_FEE;

    struct TokenConfig {
        bool supported;
        IYieldStrategy strategy;
        address receiptToken;
    }

    mapping(address => TokenConfig) public tokenConfigs;
    address[] public supportedTokens;

    // user => token => underlying deposited
    mapping(address => mapping(address => uint256)) public userDeposits;
    // user => receiptToken => receipt balance (unstaked)
    mapping(address => mapping(address => uint256)) public userReceipts;
    // user => receiptToken => staked receipt balance
    mapping(address => mapping(address => uint256)) public stakedReceipts;
    // receiptToken => total staked
    mapping(address => uint256) public totalStakedReceipt;

    // Approved lending pools (strategies must be approved)
    mapping(address => bool) public approvedLendingPools;

    // Staking reward accounting (single reward pool funded by owner)
    address public rewardToken;
    uint256 public rewardPerBlock;
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare; // scaled by REWARD_PRECISION
    mapping(address => uint256) public userRewardDebt;

    // Reentrancy guard
    uint256 private _status = 1;

    // --------- Modifiers ---------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonZeroAddress(address a) {
        if (a == address(0)) revert ZeroAddress();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert Reentrancy();
        _status = 2;
        _;
        _status = 1;
    }

    // --------- Constructor ---------
    constructor(address _rewardToken) nonZeroAddress(_rewardToken) {
        owner = msg.sender;
        rewardToken = _rewardToken;
        lastRewardBlock = block.number;
    }

    // --------- Admin ---------
    function addSupportedToken(address token, address strategy)
        external
        onlyOwner
        nonZeroAddress(token)
        nonZeroAddress(strategy)
    {
        if (tokenConfigs[token].supported) revert TokenAlreadySupported(token);
        if (supportedTokens.length >= MAX_SUPPORTED_TOKENS) revert MaxSupportedTokensReached();
        if (!approvedLendingPools[strategy]) revert LendingPoolNotApproved(strategy);

        address receipt = IYieldStrategy(strategy).receiptToken();
        if (receipt == address(0)) revert ZeroAddress();

        tokenConfigs[token] = TokenConfig({
            supported: true,
            strategy: IYieldStrategy(strategy),
            receiptToken: receipt
        });
        supportedTokens.push(token);

        emit TokenAdded(token, strategy, receipt);
    }

    function removeSupportedToken(address token) external onlyOwner nonZeroAddress(token) {
        TokenConfig storage cfg = tokenConfigs[token];
        if (!cfg.supported) revert TokenNotSupported(token);

        address receipt = cfg.receiptToken;
        if (totalStakedReceipt[receipt] > 0) revert ActivePositions();

        cfg.supported = false;
        cfg.strategy = IYieldStrategy(address(0));
        cfg.receiptToken = address(0);

        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[len - 1];
                supportedTokens.pop();
                break;
            }
        }

        emit TokenRemoved(token);
    }

    function updateStrategy(address token, address newStrategy)
        external
        onlyOwner
        nonZeroAddress(token)
        nonZeroAddress(newStrategy)
    {
        TokenConfig storage cfg = tokenConfigs[token];
        if (!cfg.supported) revert TokenNotSupported(token);
        if (!approvedLendingPools[newStrategy]) revert LendingPoolNotApproved(newStrategy);

        address oldStrategy = address(cfg.strategy);
        address receipt = IYieldStrategy(newStrategy).receiptToken();
        if (receipt == address(0)) revert ZeroAddress();

        cfg.strategy = IYieldStrategy(newStrategy);
        cfg.receiptToken = receipt;

        emit StrategyUpdated(token, oldStrategy, newStrategy);
    }

    function setPlatformFee(uint256 newFee) external onlyOwner {
        if (newFee > FEE_DENOMINATOR) revert FeeTooHigh();
        uint256 old = platformFee;
        platformFee = newFee;
        emit PlatformFeeUpdated(old, newFee);
    }

    function approveLendingPool(address pool) external onlyOwner nonZeroAddress(pool) {
        approvedLendingPools[pool] = true;
        emit LendingPoolApproved(pool);
    }

    function revokeLendingPool(address pool) external onlyOwner nonZeroAddress(pool) {
        approvedLendingPools[pool] = false;
        emit LendingPoolRevoked(pool);
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        _updateRewardPool();
        uint256 old = rewardPerBlock;
        rewardPerBlock = _rewardPerBlock;
        emit RewardRateUpdated(old, _rewardPerBlock);
    }

    function fundRewards(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        _updateRewardPool();
        bool ok = IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit RewardsFunded(amount);
    }

    // --------- Internal: reward pool update ---------
    function _updateRewardPool() internal {
        uint256 totalStaked = _totalStakedAll();
        if (totalStaked > 0 && block.number > lastRewardBlock) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            uint256 reward = blocksPassed * rewardPerBlock;
            accRewardPerShare += (reward * REWARD_PRECISION) / totalStaked;
        }
        lastRewardBlock = block.number;
    }

    function _updateUserReward(address user) internal {
        uint256 userStaked = _userTotalStaked(user);
        userRewardDebt[user] = (userStaked * accRewardPerShare) / REWARD_PRECISION;
    }

    function _userTotalStaked(address user) internal view returns (uint256 total) {
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; i++) {
            address receipt = tokenConfigs[supportedTokens[i]].receiptToken;
            total += stakedReceipts[user][receipt];
        }
    }

    function _totalStakedAll() internal view returns (uint256 total) {
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; i++) {
            address receipt = tokenConfigs[supportedTokens[i]].receiptToken;
            total += totalStakedReceipt[receipt];
        }
    }

    // --------- User actions ---------
    function deposit(address token, uint256 amount) external nonReentrant nonZeroAddress(token) {
        if (amount == 0) revert ZeroAmount();
        TokenConfig storage cfg = tokenConfigs[token];
        if (!cfg.supported) revert TokenNotSupported(token);

        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        bool approved = IERC20(token).approve(address(cfg.strategy), amount);
        if (!approved) revert TransferFailed();

        // Trust the return value from the strategy rather than comparing balances
        // around the external call to avoid stale-balance reentrancy concerns.
        uint256 receiptMinted = cfg.strategy.deposit(amount);
        if (receiptMinted == 0) revert InvalidReceiptAmount();

        // Effects: update user accounting after the external interaction succeeds.
        userDeposits[msg.sender][token] += amount;
        userReceipts[msg.sender][cfg.receiptToken] += receiptMinted;

        emit Deposited(msg.sender, token, amount, receiptMinted);
    }

    function withdraw(address token, uint256 amount) external nonReentrant nonZeroAddress(token) {
        if (amount == 0) revert ZeroAmount();
        TokenConfig storage cfg = tokenConfigs[token];
        if (!cfg.supported) revert TokenNotSupported(token);

        uint256 userDeposit = userDeposits[msg.sender][token];
        if (userDeposit < amount) revert InsufficientBalance(userDeposit, amount);

        address receipt = cfg.receiptToken;
        uint256 userReceipt = userReceipts[msg.sender][receipt];
        uint256 receiptToBurn = (userReceipt * amount) / userDeposit;
        if (receiptToBurn == 0) receiptToBurn = 1;

        // Effects: update state BEFORE the external call (checks-effects-interactions).
        userDeposits[msg.sender][token] -= amount;
        userReceipts[msg.sender][receipt] -= receiptToBurn;

        // Interaction: withdraw from strategy. Trust the returned amount.
        uint256 withdrawn = cfg.strategy.withdraw(receiptToBurn);
        if (withdrawn == 0) revert InvalidWithdrawnAmount();

        bool ok = IERC20(token).transfer(msg.sender, withdrawn);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, token, withdrawn, receiptToBurn);
    }

    function claimYield(address token) external nonReentrant nonZeroAddress(token) {
        TokenConfig storage cfg = tokenConfigs[token];
        if (!cfg.supported) revert TokenNotSupported(token);

        // Trust the return value from the strategy; do not read balances around
        // the external call to avoid stale-balance reentrancy issues.
        uint256 grossYield = cfg.strategy.claimYield();
        if (grossYield == 0) revert NothingToClaim();

        uint256 fee = (grossYield * platformFee) / FEE_DENOMINATOR;
        uint256 netYield = grossYield - fee;

        if (fee > 0) {
            bool okFee = IERC20(token).transfer(owner, fee);
            if (!okFee) revert TransferFailed();
        }
        if (netYield > 0) {
            bool okUser = IERC20(token).transfer(msg.sender, netYield);
            if (!okUser) revert TransferFailed();
        }

        emit YieldClaimed(msg.sender, token, grossYield, fee, netYield);
    }

    function stakeReceipt(address receiptToken, uint256 amount)
        external
        nonReentrant
        nonZeroAddress(receiptToken)
    {
        if (amount == 0) revert ZeroAmount();
        if (userReceipts[msg.sender][receiptToken] < amount)
            revert InsufficientBalance(userReceipts[msg.sender][receiptToken], amount);

        _updateRewardPool();
        _updateUserReward(msg.sender);

        userReceipts[msg.sender][receiptToken] -= amount;
        stakedReceipts[msg.sender][receiptToken] += amount;
        totalStakedReceipt[receiptToken] += amount;

        _updateUserReward(msg.sender);

        emit ReceiptStaked(msg.sender, receiptToken, amount);
    }

    function unstakeReceipt(address receiptToken, uint256 amount)
        external
        nonReentrant
        nonZeroAddress(receiptToken)
    {
        if (amount == 0) revert ZeroAmount();
        if (stakedReceipts[msg.sender][receiptToken] < amount)
            revert InsufficientBalance(stakedReceipts[msg.sender][receiptToken], amount);

        _updateRewardPool();
        _updateUserReward(msg.sender);

        stakedReceipts[msg.sender][receiptToken] -= amount;
        totalStakedReceipt[receiptToken] -= amount;
        userReceipts[msg.sender][receiptToken] += amount;

        _updateUserReward(msg.sender);

        emit ReceiptUnstaked(msg.sender, receiptToken, amount);
    }

    function claimRewards() external nonReentrant {
        _updateRewardPool();
        uint256 userStaked = _userTotalStaked(msg.sender);
        uint256 pending = (userStaked * accRewardPerShare) / REWARD_PRECISION - userRewardDebt[msg.sender];
        if (pending == 0) revert NothingToClaim();

        userRewardDebt[msg.sender] = (userStaked * accRewardPerShare) / REWARD_PRECISION;

        uint256 bal = IERC20(rewardToken).balanceOf(address(this));
        uint256 payout = pending < bal ? pending : bal;
        if (payout > 0) {
            bool ok = IERC20(rewardToken).transfer(msg.sender, payout);
            if (!ok) revert TransferFailed();
        }

        emit RewardClaimed(msg.sender, payout);
    }

    // --------- Views ---------
    function isSupported(address token) external view returns (bool) {
        return tokenConfigs[token].supported;
    }

    function getStrategy(address token) external view returns (address) {
        return address(tokenConfigs[token].strategy);
    }

    function getReceiptToken(address token) external view returns (address) {
        return tokenConfigs[token].receiptToken;
    }

    function supportedTokensCount() external view returns (uint256) {
        return supportedTokens.length;
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 userStaked = _userTotalStaked(user);
        return (userStaked * accRewardPerShare) / REWARD_PRECISION - userRewardDebt[user];
    }

    function userTotalStaked(address user) external view returns (uint256) {
        return _userTotalStaked(user);
    }

    function totalStakedAll() external view returns (uint256) {
        return _totalStakedAll();
    }
}
