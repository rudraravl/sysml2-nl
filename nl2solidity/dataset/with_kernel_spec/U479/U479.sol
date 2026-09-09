// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IYieldSource {
    function deposit(uint256 assets) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 assets);
    function balanceOf(address account) external view returns (uint256);
    function balanceOfUnderlying(address account) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (success && (returndata.length == 0 || abi.decode(returndata, (bool)))) {
            return;
        }
        revert("SafeERC20: low-level call failed");
    }
}

contract YieldOptimizationVault {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant WITHDRAWAL_DELAY = 24 hours;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant REWARD_PRECISION = 1e18;

    IERC20 public immutable stablecoin;
    IERC20 public immutable rewardToken;
    IYieldSource public immutable yieldSource;

    address public owner;
    address public operator;

    uint256 public withdrawalFeeBps;

    uint256 public totalShares;
    uint256 public totalUserStableDeposits;
    mapping(address => uint256) public userStableDeposits;
    mapping(address => uint256) public userShares;

    uint256 public accRewardPerShare;
    mapping(address => uint256) public userRewardDebt;
    mapping(address => uint256) public claimableRewards;

    struct StrategyParams {
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 totalDepositCap;
        uint256 minRebalanceAmount;
        uint256 maxSlippageBps;
    }
    StrategyParams public strategyParams;

    struct WithdrawalRequest {
        uint256 shares;
        uint256 stableAmount;
        uint256 timestamp;
        bool active;
    }
    mapping(address => WithdrawalRequest) public withdrawalRequests;

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event WithdrawalRequested(
        address indexed user,
        uint256 shares,
        uint256 stableAmount,
        uint256 timestamp
    );
    event WithdrawalExecuted(address indexed user, uint256 stableAmountAfterFee, uint256 fee);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsAdded(address indexed operator, uint256 amount, uint256 accRewardPerShare);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event StrategyParamsUpdated(StrategyParams params);
    event Rebalanced(address indexed operator, uint256 stableAmount, uint256 yieldShares, bool toYield);
    event EmergencyWithdrawal(address indexed operator, address token, uint256 amount);

    error NotOwner();
    error NotOperator();
    error AmountZero();
    error ExceedsDepositCap();
    error BelowMinDeposit();
    error AboveMaxDeposit();
    error ExceedsMaxWithdrawalFee();
    error InsufficientShares();
    error InsufficientStablecoinBalance();
    error InsufficientYieldShares();
    error WithdrawalAlreadyActive();
    error NoWithdrawalRequest();
    error WithdrawalNotReady(uint256 readyAt);
    error NoRewards();
    error InvalidAddress();
    error InvalidStrategyParams();
    error StrategyInsolvent();
    error Reentrancy();
    error ZeroShares();
    error InvalidToken();

    uint256 private _reentrancyStatus;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus != 0) revert Reentrancy();
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 0;
    }

    constructor(
        address _stablecoin,
        address _rewardToken,
        address _yieldSource,
        address _owner,
        address _operator,
        uint256 _withdrawalFeeBps
    ) {
        if (
            _stablecoin == address(0) ||
            _rewardToken == address(0) ||
            _yieldSource == address(0) ||
            _owner == address(0) ||
            _operator == address(0) ||
            _stablecoin == _rewardToken
        ) {
            revert InvalidAddress();
        }
        if (_withdrawalFeeBps > MAX_WITHDRAWAL_FEE_BPS) revert ExceedsMaxWithdrawalFee();

        stablecoin = IERC20(_stablecoin);
        rewardToken = IERC20(_rewardToken);
        yieldSource = IYieldSource(_yieldSource);

        owner = _owner;
        operator = _operator;
        withdrawalFeeBps = _withdrawalFeeBps;

        strategyParams = StrategyParams({
            minDeposit: 1,
            maxDeposit: type(uint256).max,
            totalDepositCap: type(uint256).max,
            minRebalanceAmount: 1,
            maxSlippageBps: 100
        });
    }

    function totalAssets() public view returns (uint256) {
        return stablecoin.balanceOf(address(this)) + yieldSource.balanceOfUnderlying(address(this));
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 newDebt = userShares[user] * accRewardPerShare / REWARD_PRECISION;
        uint256 accrued = newDebt > userRewardDebt[user] ? newDebt - userRewardDebt[user] : 0;
        return claimableRewards[user] + accrued;
    }

    function getWithdrawalRequest(address user)
        external
        view
        returns (uint256 shares, uint256 stableAmount, uint256 timestamp, bool active)
    {
        WithdrawalRequest storage req = withdrawalRequests[user];
        return (req.shares, req.stableAmount, req.timestamp, req.active);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount < 1) revert AmountZero();
        if (amount < strategyParams.minDeposit) revert BelowMinDeposit();
        if (amount > strategyParams.maxDeposit) revert AboveMaxDeposit();
        if (totalUserStableDeposits + amount > strategyParams.totalDepositCap) revert ExceedsDepositCap();

        _updateReward(msg.sender);

        uint256 shares = _sharesForAmount(amount);
        if (shares < 1) revert ZeroShares();

        // Effects: update state before external transfer
        userStableDeposits[msg.sender] += amount;
        totalUserStableDeposits += amount;
        userShares[msg.sender] += shares;
        totalShares += shares;
        userRewardDebt[msg.sender] = userShares[msg.sender] * accRewardPerShare / REWARD_PRECISION;

        // Interactions
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, shares);
    }

    function requestWithdrawal(uint256 stableAmount) external nonReentrant {
        if (stableAmount < 1) revert AmountZero();
        if (withdrawalRequests[msg.sender].active) revert WithdrawalAlreadyActive();

        _updateReward(msg.sender);

        uint256 shares = _sharesForAmount(stableAmount);
        if (shares < 1) revert ZeroShares();
        if (userShares[msg.sender] < shares) revert InsufficientShares();

        // Effects
        userShares[msg.sender] -= shares;
        totalShares -= shares;

        if (userStableDeposits[msg.sender] >= stableAmount) {
            userStableDeposits[msg.sender] -= stableAmount;
        } else {
            userStableDeposits[msg.sender] = 0;
        }

        if (totalUserStableDeposits >= stableAmount) {
            totalUserStableDeposits -= stableAmount;
        } else {
            totalUserStableDeposits = 0;
        }

        userRewardDebt[msg.sender] = userShares[msg.sender] * accRewardPerShare / REWARD_PRECISION;

        withdrawalRequests[msg.sender] = WithdrawalRequest({
            shares: shares,
            stableAmount: stableAmount,
            timestamp: block.timestamp,
            active: true
        });

        emit WithdrawalRequested(msg.sender, shares, stableAmount, block.timestamp);
    }

    function executeWithdrawal() external nonReentrant {
        WithdrawalRequest memory request = withdrawalRequests[msg.sender];
        if (!request.active) revert NoWithdrawalRequest();

        uint256 readyAt = request.timestamp + WITHDRAWAL_DELAY;
        if (block.timestamp < readyAt) revert WithdrawalNotReady(readyAt);

        _updateReward(msg.sender);

        uint256 fee = request.stableAmount * withdrawalFeeBps / BPS_DENOMINATOR;
        uint256 amountAfterFee = request.stableAmount - fee;

        // Effects: clear request before external calls
        delete withdrawalRequests[msg.sender];

        // Interactions: ensure liquidity then transfer
        _ensureStablecoinLiquidity(request.stableAmount);

        stablecoin.safeTransfer(msg.sender, amountAfterFee);
        if (fee > 0) {
            stablecoin.safeTransfer(owner, fee);
        }

        emit WithdrawalExecuted(msg.sender, amountAfterFee, fee);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);

        uint256 amount = claimableRewards[msg.sender];
        if (amount < 1) revert NoRewards();

        // Effects
        claimableRewards[msg.sender] = 0;

        // Interactions
        rewardToken.safeTransfer(msg.sender, amount);

        emit RewardsClaimed(msg.sender, amount);
    }

    function addRewards(uint256 amount) external onlyOperator nonReentrant {
        if (amount < 1) revert AmountZero();
        if (totalShares < 1) revert InsufficientShares();

        // Effects
        accRewardPerShare += amount * REWARD_PRECISION / totalShares;

        // Interactions
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsAdded(msg.sender, amount, accRewardPerShare);
    }

    function rebalanceToYield(uint256 stableAmount) external onlyOperator nonReentrant {
        if (stableAmount < 1) revert AmountZero();
        if (stableAmount < strategyParams.minRebalanceAmount) revert BelowMinDeposit();
        if (stablecoin.balanceOf(address(this)) < stableAmount) revert InsufficientStablecoinBalance();

        stablecoin.safeApprove(address(yieldSource), stableAmount);
        uint256 shares = yieldSource.deposit(stableAmount);

        emit Rebalanced(msg.sender, stableAmount, shares, true);
    }

    function rebalanceFromYield(uint256 yieldShares) external onlyOperator nonReentrant {
        if (yieldShares < 1) revert AmountZero();
        if (yieldSource.balanceOf(address(this)) < yieldShares) revert InsufficientYieldShares();

        uint256 stableAmount = yieldSource.withdraw(yieldShares);

        emit Rebalanced(msg.sender, stableAmount, yieldShares, false);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOperator nonReentrant {
        if (amount < 1) revert AmountZero();
        if (
            token != address(stablecoin) &&
            token != address(rewardToken) &&
            token != address(yieldSource)
        ) {
            revert InvalidToken();
        }

        if (token == address(yieldSource)) {
            if (yieldSource.balanceOf(address(this)) < amount) revert InsufficientYieldShares();
            yieldSource.withdraw(amount);
        } else {
            IERC20(token).safeTransfer(owner, amount);
        }

        emit EmergencyWithdrawal(msg.sender, token, amount);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();

        address oldOperator = operator;
        operator = newOperator;

        emit OperatorUpdated(oldOperator, newOperator);
    }

    function setWithdrawalFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_WITHDRAWAL_FEE_BPS) revert ExceedsMaxWithdrawalFee();

        uint256 oldFeeBps = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;

        emit WithdrawalFeeUpdated(oldFeeBps, newFeeBps);
    }

    function updateStrategyParams(
        uint256 _minDeposit,
        uint256 _maxDeposit,
        uint256 _totalDepositCap,
        uint256 _minRebalanceAmount,
        uint256 _maxSlippageBps
    ) external onlyOperator {
        if (
            _minDeposit < 1 ||
            _maxDeposit < _minDeposit ||
            _totalDepositCap < _minDeposit ||
            _minRebalanceAmount < 1 ||
            _maxSlippageBps > BPS_DENOMINATOR
        ) {
            revert InvalidStrategyParams();
        }

        strategyParams = StrategyParams({
            minDeposit: _minDeposit,
            maxDeposit: _maxDeposit,
            totalDepositCap: _totalDepositCap,
            minRebalanceAmount: _minRebalanceAmount,
            maxSlippageBps: _maxSlippageBps
        });

        emit StrategyParamsUpdated(strategyParams);
    }

    function _sharesForAmount(uint256 amount) internal view returns (uint256) {
        if (totalShares < 1) return amount;

        uint256 assets = totalAssets();
        if (assets < 1) revert StrategyInsolvent();

        return amount * totalShares / assets;
    }

    function _updateReward(address user) internal {
        uint256 newDebt = userShares[user] * accRewardPerShare / REWARD_PRECISION;
        if (newDebt > userRewardDebt[user]) {
            claimableRewards[user] += newDebt - userRewardDebt[user];
        }
        userRewardDebt[user] = newDebt;
    }

    function _ensureStablecoinLiquidity(uint256 requiredAmount) internal {
        uint256 idleStable = stablecoin.balanceOf(address(this));
        if (idleStable >= requiredAmount) {
            return;
        }

        uint256 needed = requiredAmount - idleStable;
        uint256 underlyingInYield = yieldSource.balanceOfUnderlying(address(this));
        uint256 yieldSharesHeld = yieldSource.balanceOf(address(this));

        if (underlyingInYield < 1 || yieldSharesHeld < 1) revert InsufficientStablecoinBalance();

        // Round up to ensure enough shares are withdrawn
        uint256 sharesNeeded = (needed * yieldSharesHeld + underlyingInYield - 1) / underlyingInYield;

        if (sharesNeeded > yieldSharesHeld) revert InsufficientYieldShares();

        yieldSource.withdraw(sharesNeeded);

        // Re-read balance after external call to avoid stale data
        uint256 newIdleStable = stablecoin.balanceOf(address(this));
        if (newIdleStable < requiredAmount) revert InsufficientStablecoinBalance();
    }
}
