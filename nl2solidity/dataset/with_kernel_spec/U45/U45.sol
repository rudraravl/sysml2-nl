// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IYieldStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function claimRewards() external returns (uint256);
    function rewardToken() external view returns (address);
}

contract AutomatedLSDVault {
    // ──────────────────────────── Errors ────────────────────────────
    error Unauthorized();
    error ZeroAddress();
    error DepositTooSmall();
    error InsufficientShares();
    error FeeExceedsMaximum();
    error NoSharesToClaim();
    error NothingToHarvest();
    error TransferFailed();
    error InvalidAmount();
    error StrategyNotSet();
    error InsufficientWithdrawn();

    // ──────────────────────────── Events ────────────────────────────
    event Deposited(address indexed user, uint256 lsdAmount, uint256 sharesMinted);
    event Withdrawn(address indexed user, uint256 lsdAmount, uint256 sharesBurned, uint256 feeTaken);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event RewardsHarvested(uint256 rewardAmount);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event WithdrawalFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ──────────────────────────── Constants ─────────────────────────
    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_DEPOSIT = 1e16; // 0.01 LSD tokens (18 decimals)
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;

    // ──────────────────────────── State ─────────────────────────────
    address public owner;
    address public operator;

    IERC20 public immutable lsdToken;
    IYieldStrategy public yieldStrategy;
    IERC20 public rewardToken;

    uint256 public withdrawalFeeBps;

    uint256 public totalShares;
    uint256 public totalRewardsHarvested;
    uint256 public unclaimedRewards;

    struct UserInfo {
        uint256 shares;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userInfo;

    uint256 public accRewardPerShare;

    // ──────────────────────────── Reentrancy ────────────────────────
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Unauthorized();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ──────────────────────────── Modifiers ────────────────────────
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ──────────────────────────── Constructor ──────────────────────
    constructor(
        address _lsdToken,
        address _yieldStrategy,
        uint256 _withdrawalFeeBps
    ) {
        if (_lsdToken == address(0)) revert ZeroAddress();
        if (_yieldStrategy == address(0)) revert ZeroAddress();
        if (_withdrawalFeeBps > MAX_WITHDRAWAL_FEE_BPS) revert FeeExceedsMaximum();

        owner = msg.sender;
        operator = msg.sender;
        lsdToken = IERC20(_lsdToken);
        yieldStrategy = IYieldStrategy(_yieldStrategy);
        rewardToken = IERC20(IYieldStrategy(_yieldStrategy).rewardToken());
        withdrawalFeeBps = _withdrawalFeeBps;
        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), msg.sender);
        emit StrategyUpdated(address(0), _yieldStrategy);
        emit WithdrawalFeeUpdated(0, _withdrawalFeeBps);
    }

    // ──────────────────────────── Admin ─────────────────────────────

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setYieldStrategy(address newStrategy) external onlyOperator nonReentrant {
        if (newStrategy == address(0)) revert ZeroAddress();

        IYieldStrategy oldStrategy = yieldStrategy;

        // Harvest pending rewards from old strategy before switching
        _harvestRewards();

        // Withdraw all assets from old strategy
        uint256 strategyBalance = oldStrategy.balanceOf(address(this));
        if (strategyBalance > 0) {
            uint256 withdrawn = oldStrategy.withdraw(strategyBalance);
            if (withdrawn < strategyBalance) revert InsufficientWithdrawn();
        }

        // Update state (EFFECTS before INTERACTIONS)
        yieldStrategy = IYieldStrategy(newStrategy);
        rewardToken = IERC20(IYieldStrategy(newStrategy).rewardToken());

        // Deposit idle LSD tokens into new strategy
        uint256 idleBalance = lsdToken.balanceOf(address(this));
        if (idleBalance > 0) {
            _safeApprove(lsdToken, newStrategy, idleBalance);
            yieldStrategy.deposit(idleBalance);
        }

        emit StrategyUpdated(address(oldStrategy), newStrategy);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_WITHDRAWAL_FEE_BPS) revert FeeExceedsMaximum();
        emit WithdrawalFeeUpdated(withdrawalFeeBps, newFeeBps);
        withdrawalFeeBps = newFeeBps;
    }

    // ──────────────────────────── Core Logic ───────────────────────

    function deposit(uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert DepositTooSmall();
        if (address(yieldStrategy) == address(0)) revert StrategyNotSet();

        _harvestRewards();

        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = amount;
        } else {
            uint256 assets = _totalAssets();
            sharesToMint = (amount * totalShares) / assets;
        }
        if (sharesToMint == 0) revert InvalidAmount();

        // Update state before external transfers (checks-effects-interactions)
        userInfo[msg.sender].shares += sharesToMint;
        userInfo[msg.sender].rewardDebt =
            (userInfo[msg.sender].shares * accRewardPerShare) / PRECISION;
        totalShares += sharesToMint;

        // Transfer LSD tokens from user (INTERACTION)
        _safeTransferFrom(lsdToken, msg.sender, address(this), amount);

        // Deposit into yield strategy (INTERACTION)
        _safeApprove(lsdToken, address(yieldStrategy), amount);
        yieldStrategy.deposit(amount);

        emit Deposited(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 shareAmount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        if (shareAmount == 0 || shareAmount > user.shares) revert InsufficientShares();
        if (address(yieldStrategy) == address(0)) revert StrategyNotSet();

        _harvestRewards();

        uint256 assets = _totalAssets();

        // Calculate gross amount and fee with full precision (multiply before divide)
        // fee = (shareAmount * assets * withdrawalFeeBps) / (totalShares * BPS_DENOMINATOR)
        uint256 fee = (shareAmount * assets * withdrawalFeeBps) / (totalShares * BPS_DENOMINATOR);
        uint256 grossAmount = (shareAmount * assets) / totalShares;
        uint256 amountToUser = grossAmount - fee;

        // Update state before external transfers (checks-effects-interactions)
        user.shares -= shareAmount;
        totalShares -= shareAmount;
        user.rewardDebt = (user.shares * accRewardPerShare) / PRECISION;

        // Withdraw from yield strategy (INTERACTION)
        uint256 withdrawn = yieldStrategy.withdraw(grossAmount);
        if (withdrawn < grossAmount) revert InsufficientWithdrawn();

        // Transfer to user (INTERACTION)
        _safeTransfer(lsdToken, msg.sender, amountToUser);

        // Fee stays in vault and is redistributed (deposited back into strategy)
        if (fee > 0) {
            _safeApprove(lsdToken, address(yieldStrategy), fee);
            yieldStrategy.deposit(fee);
        }

        emit Withdrawn(msg.sender, amountToUser, shareAmount, fee);
    }

    function claimRewards() external nonReentrant {
        _harvestRewards();

        UserInfo storage user = userInfo[msg.sender];
        if (user.shares == 0) revert NoSharesToClaim();

        uint256 gross = (user.shares * accRewardPerShare) / PRECISION;
        if (gross <= user.rewardDebt) revert NothingToHarvest();
        uint256 pending = gross - user.rewardDebt;

        // Cap to available unclaimed rewards to avoid underflow from rounding
        if (pending > unclaimedRewards) {
            pending = unclaimedRewards;
        }
        if (pending == 0) revert NothingToHarvest();

        // Update state before external transfer (checks-effects-interactions)
        user.rewardDebt = gross;
        unclaimedRewards -= pending;

        // Transfer reward tokens to user (INTERACTION)
        _safeTransfer(rewardToken, msg.sender, pending);

        emit RewardsClaimed(msg.sender, pending);
    }

    // ──────────────────────────── Internal ─────────────────────────

    function _harvestRewards() internal {
        if (address(yieldStrategy) == address(0)) return;
        uint256 rewards = yieldStrategy.claimRewards();
        if (rewards == 0) return;

        if (totalShares > 0) {
            accRewardPerShare += (rewards * PRECISION) / totalShares;
        }
        totalRewardsHarvested += rewards;
        unclaimedRewards += rewards;

        emit RewardsHarvested(rewards);
    }

    function _totalAssets() internal view returns (uint256) {
        return yieldStrategy.balanceOf(address(this)) + lsdToken.balanceOf(address(this));
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool ok = token.approve(spender, amount);
        if (!ok) revert TransferFailed();
    }

    // ──────────────────────────── Views ─────────────────────────────

    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    function totalLSDInStrategy() external view returns (uint256) {
        return yieldStrategy.balanceOf(address(this));
    }

    function idleLSD() external view returns (uint256) {
        return lsdToken.balanceOf(address(this));
    }

    function pendingRewards(address userAddr) external view returns (uint256) {
        UserInfo storage user = userInfo[userAddr];
        uint256 gross = (user.shares * accRewardPerShare) / PRECISION;
        if (gross <= user.rewardDebt) return 0;
        uint256 pending = gross - user.rewardDebt;
        if (pending > unclaimedRewards) return unclaimedRewards;
        return pending;
    }

    function sharesOf(address userAddr) external view returns (uint256) {
        return userInfo[userAddr].shares;
    }

    function convertSharesToAssets(uint256 shareAmount) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shareAmount * _totalAssets()) / totalShares;
    }

    function convertAssetsToShares(uint256 assetAmount) external view returns (uint256) {
        if (totalShares == 0) return assetAmount;
        uint256 assets = _totalAssets();
        return (assetAmount * totalShares) / assets;
    }
}
