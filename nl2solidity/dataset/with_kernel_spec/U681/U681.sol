// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IDerivativesExchange {
    function depositCollateral(address token, uint256 amount) external;
    function withdrawCollateral(address token, uint256 amount) external;
    function liquidatePosition(address account, uint256 positionId) external;
    function getAccountHealth(address account) external view returns (uint256 healthFactor);
    function rebalanceStrategy(uint256 strategyId) external;
}

contract LiquidityProviderVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    uint256 public constant WITHDRAWAL_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DIVISOR = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_PERFORMANCE_FEE_BPS = 5000; // 50%
    uint256 public constant MIN_SHARES = 1;
    uint256 public constant MIN_REWARD = 1;

    // ============ State Variables ============
    IERC20 public immutable stablecoin;
    IDerivativesExchange public immutable exchange;

    address public operator;
    uint256 public totalValueLocked;
    uint256 public totalShares;
    uint256 public totalRewardsAccrued;
    uint256 public accumulatedRewardPerShare;
    uint256 public rewardBalance;
    uint256 public performanceFeeBps;
    address public feeRecipient;
    bool public paused;
    uint256 public maxDepositLimit;

    struct UserInfo {
        uint256 deposit;
        uint256 shares;
        uint256 rewardDebt;
        uint256 lastDepositTime;
    }

    mapping(address => UserInfo) public userInfo;

    // ============ Events ============
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares, uint256 fee);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardsAdded(uint256 amount, uint256 newAccumulatedRewardPerShare);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event PerformanceFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PausedStateChanged(bool paused);
    event RebalanceInitiated(uint256 indexed strategyId, address indexed operator);
    event PositionLiquidated(address indexed account, uint256 indexed positionId, address indexed operator);
    event CollateralDepositedToExchange(uint256 amount);
    event CollateralWithdrawnFromExchange(uint256 amount);
    event MaxDepositLimitUpdated(uint256 oldLimit, uint256 newLimit);

    // ============ Custom Errors ============
    error ZeroAddress();
    error InvalidAmount();
    error DepositLimitExceeded();
    error OnlyOperator();
    error OnlyOwnerOrOperator();
    error WhenPaused();
    error WhenNotPaused();
    error InvalidFeeBps();
    error InsufficientShares();
    error InsufficientBalance();
    error NoPendingRewards();
    error PositionHealthy();

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner() && msg.sender != operator) revert OnlyOwnerOrOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert WhenNotPaused();
        _;
    }

    constructor(
        address _stablecoin,
        address _exchange,
        address _operator,
        address _feeRecipient
    ) Ownable(msg.sender) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_exchange == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        exchange = IDerivativesExchange(_exchange);
        operator = _operator;
        feeRecipient = _feeRecipient;
        performanceFeeBps = 1000; // 10% default performance fee
        maxDepositLimit = 1_000_000 * 1e18;
    }

    // ============ User Functions ============

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();

        UserInfo storage user = userInfo[msg.sender];
        uint256 newDeposit = user.deposit + amount;
        if (newDeposit > maxDepositLimit) revert DepositLimitExceeded();

        // Calculate shares to mint before any external interaction
        uint256 sharesToMint;
        if (totalShares < MIN_SHARES) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / totalValueLocked;
        }
        if (sharesToMint < MIN_SHARES) revert InvalidAmount();

        // Effects: update all state before interactions (CEI pattern)
        user.deposit = newDeposit;
        user.shares += sharesToMint;
        user.lastDepositTime = block.timestamp;
        user.rewardDebt = (user.shares * accumulatedRewardPerShare) / PRECISION;

        totalShares += sharesToMint;
        totalValueLocked += amount;

        // Interactions: pull tokens from depositor last
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 shareAmount) external nonReentrant whenNotPaused {
        if (shareAmount == 0) revert InvalidAmount();

        UserInfo storage user = userInfo[msg.sender];
        if (user.shares < shareAmount) revert InsufficientShares();

        // Compute gross amount and fee without divide-before-multiply:
        // fee = (shareAmount * totalValueLocked * WITHDRAWAL_FEE_BPS) / (totalShares * BPS_DIVISOR)
        uint256 grossAmount = (shareAmount * totalValueLocked) / totalShares;
        uint256 fee = (shareAmount * totalValueLocked * WITHDRAWAL_FEE_BPS) / (totalShares * BPS_DIVISOR);
        if (fee > grossAmount) fee = grossAmount; // safety bound
        uint256 amountAfterFee = grossAmount - fee;

        uint256 depositReduction = (shareAmount * user.deposit) / user.shares;
        if (depositReduction > user.deposit) depositReduction = user.deposit;

        // Effects: update state before interactions
        user.shares -= shareAmount;
        user.deposit -= depositReduction;
        user.rewardDebt = (user.shares * accumulatedRewardPerShare) / PRECISION;

        totalShares -= shareAmount;
        totalValueLocked -= grossAmount;

        // Interactions
        if (fee > 0) {
            stablecoin.safeTransfer(feeRecipient, fee);
        }
        stablecoin.safeTransfer(msg.sender, amountAfterFee);

        emit Withdraw(msg.sender, amountAfterFee, shareAmount, fee);
    }

    function claimRewards() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = _pendingRewards(user);
        if (pending < MIN_REWARD) revert NoPendingRewards();

        // Effects
        user.rewardDebt = (user.shares * accumulatedRewardPerShare) / PRECISION;
        totalRewardsAccrued -= pending;
        rewardBalance -= pending;

        // Interactions
        stablecoin.safeTransfer(msg.sender, pending);

        emit RewardClaimed(msg.sender, pending);
    }

    function pendingRewards(address account) external view returns (uint256) {
        return _pendingRewards(userInfo[account]);
    }

    function getVaultInfo()
        external
        view
        returns (
            uint256 _totalValueLocked,
            uint256 _totalShares,
            uint256 _totalRewardsAccrued,
            uint256 _rewardBalance,
            uint256 _accumulatedRewardPerShare
        )
    {
        return (
            totalValueLocked,
            totalShares,
            totalRewardsAccrued,
            rewardBalance,
            accumulatedRewardPerShare
        );
    }

    function getUserInfo(address account)
        external
        view
        returns (
            uint256 deposit,
            uint256 shares,
            uint256 pendingReward,
            uint256 lastDepositTime
        )
    {
        UserInfo storage user = userInfo[account];
        return (
            user.deposit,
            user.shares,
            _pendingRewards(user),
            user.lastDepositTime
        );
    }

    // ============ Operator Functions ============

    function depositCollateralToExchange(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (stablecoin.balanceOf(address(this)) < amount) revert InsufficientBalance();

        stablecoin.safeApprove(address(exchange), 0);
        stablecoin.safeApprove(address(exchange), amount);
        exchange.depositCollateral(address(stablecoin), amount);

        emit CollateralDepositedToExchange(amount);
    }

    function withdrawCollateralFromExchange(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert InvalidAmount();

        exchange.withdrawCollateral(address(stablecoin), amount);

        emit CollateralWithdrawnFromExchange(amount);
    }

    function initiateRebalance(uint256 strategyId) external onlyOperator {
        exchange.rebalanceStrategy(strategyId);
        emit RebalanceInitiated(strategyId, msg.sender);
    }

    function liquidatePosition(address account, uint256 positionId) external onlyOperator {
        uint256 healthFactor = exchange.getAccountHealth(account);
        if (healthFactor >= 10000) revert PositionHealthy();

        exchange.liquidatePosition(account, positionId);
        emit PositionLiquidated(account, positionId, msg.sender);
    }

    function addRewards(uint256 amount) external onlyOwnerOrOperator nonReentrant {
        if (amount == 0) revert InvalidAmount();

        // Effects: update reward accounting before transfer
        rewardBalance += amount;
        totalRewardsAccrued += amount;

        if (totalShares > 0) {
            accumulatedRewardPerShare += (amount * PRECISION) / totalShares;
        }

        // Interactions
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsAdded(amount, accumulatedRewardPerShare);
    }

    // ============ Admin Functions ============

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    function setPerformanceFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_PERFORMANCE_FEE_BPS) revert InvalidFeeBps();
        uint256 old = performanceFeeBps;
        performanceFeeBps = newFeeBps;
        emit PerformanceFeeUpdated(old, newFeeBps);
    }

    function setMaxDepositLimit(uint256 newLimit) external onlyOwner {
        if (newLimit == 0) revert InvalidAmount();
        uint256 old = maxDepositLimit;
        maxDepositLimit = newLimit;
        emit MaxDepositLimitUpdated(old, newLimit);
    }

    function setPaused(bool _paused) external onlyOwnerOrOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function recoverTokens(address token, uint256 amount) external onlyOwner {
        if (token == address(stablecoin)) {
            uint256 vaultBalance = stablecoin.balanceOf(address(this));
            uint256 locked = totalValueLocked + rewardBalance;
            if (vaultBalance < locked || (vaultBalance - locked) < amount) revert InsufficientBalance();
        }
        IERC20(token).safeTransfer(owner(), amount);
    }

    // ============ Internal Functions ============

    function _pendingRewards(UserInfo storage user) internal view returns (uint256) {
        if (user.shares == 0) return 0;
        uint256 totalEarned = (user.shares * accumulatedRewardPerShare) / PRECISION;
        if (totalEarned <= user.rewardDebt) return 0;
        return totalEarned - user.rewardDebt;
    }
}
