// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function harvest() external returns (uint256);
    function balanceOf() external view returns (uint256);
    function want() external view returns (address);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert SafeERC20TransferFromFailed();
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool ok = token.approve(spender, amount);
        if (!ok) revert SafeERC20ApproveFailed();
    }

    error SafeERC20TransferFailed();
    error SafeERC20TransferFromFailed();
    error SafeERC20ApproveFailed();
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    error ReentrancyGuardReentrantCall();
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    error OwnableUnauthorizedAccount(address account);
    error OwnableZeroAddress();
}

contract YieldOptimizationVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ----------------------------------------------------------------------
    // Custom errors
    // ----------------------------------------------------------------------
    error ZeroAddress();
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientShares(uint256 requested, uint256 available);
    error InsufficientVaultBalance(uint256 required, uint256 available);
    error NothingToClaim();
    error NotOperator();
    error StrategyAlreadyApproved();
    error StrategyNotApproved();
    error StrategyNotActive();
    error StrategyWeightExceedsTotal();
    error InvalidWeight();
    error ZeroAmount();
    error InvalidArrayLength();
    error AssetMismatch();
    error FeeExceedsMax(uint256 proposed, uint256 max);
    error NoStrategies();
    error UnauthorizedWithdraw();

    // ----------------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------------
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 fee);
    event ClaimReward(address indexed user, uint256 reward);
    event Rebalanced(uint256 totalAssets, uint256 timestamp);
    event StrategyApproved(address indexed strategy, uint256 weight);
    event StrategyRevoked(address indexed strategy);
    event StrategyWeightUpdated(address indexed strategy, uint256 oldWeight, uint256 newWeight);
    event Harvested(address indexed strategy, uint256 rewardAmount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event MinDepositUpdated(uint256 oldMin, uint256 newMin);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    // ----------------------------------------------------------------------
    // Constants
    // ----------------------------------------------------------------------
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 1_000; // 10%
    uint256 public constant WEIGHT_DENOMINATOR = 10_000; // 100% = 10000 bps
    uint256 public constant SHARES_PRECISION = 1e18;

    // ----------------------------------------------------------------------
    // State variables
    // ----------------------------------------------------------------------
    IERC20 public immutable asset;
    IERC20 public immutable rewardToken;

    address public operator;
    address public feeReceiver;

    uint256 public minDeposit;
    uint256 public withdrawalFeeBps;

    uint256 public totalShares;

    mapping(address => uint256) public userShares;

    // Reward accounting (standard per-share accumulator)
    uint256 public rewardPerShareStored;
    mapping(address => uint256) public userRewardPerSharePaid;
    mapping(address => uint256) public rewards;

    struct StrategyInfo {
        bool active;
        uint256 targetWeight; // in basis points relative to WEIGHT_DENOMINATOR
        uint256 allocated;     // amount of `asset` currently deployed
    }

    mapping(address => StrategyInfo) public strategies;
    address[] public strategyList;
    uint256 public totalStrategyWeight;

    // ----------------------------------------------------------------------
    // Modifiers
    // ----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    // ----------------------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------------------
    constructor(
        address _asset,
        address _rewardToken,
        address _operator,
        address _feeReceiver
    ) {
        if (_asset == address(0)) revert ZeroAddress();
        if (_rewardToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeReceiver == address(0)) revert ZeroAddress();

        asset = IERC20(_asset);
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
        feeReceiver = _feeReceiver;

        uint8 decimals = _readDecimals(_asset);
        minDeposit = 100 * (10 ** uint256(decimals));
        withdrawalFeeBps = 50; // 0.5%

        emit OperatorUpdated(address(0), _operator);
        emit FeeReceiverUpdated(address(0), _feeReceiver);
        emit MinDepositUpdated(0, minDeposit);
        emit WithdrawalFeeUpdated(0, withdrawalFeeBps);
    }

    // ----------------------------------------------------------------------
    // Admin functions (owner)
    // ----------------------------------------------------------------------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        if (_feeReceiver == address(0)) revert ZeroAddress();
        address old = feeReceiver;
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(old, _feeReceiver);
    }

    function setMinDeposit(uint256 _minDeposit) external onlyOwner {
        uint256 old = minDeposit;
        minDeposit = _minDeposit;
        emit MinDepositUpdated(old, _minDeposit);
    }

    function setWithdrawalFeeBps(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_WITHDRAWAL_FEE_BPS) revert FeeExceedsMax(_feeBps, MAX_WITHDRAWAL_FEE_BPS);
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = _feeBps;
        emit WithdrawalFeeUpdated(old, _feeBps);
    }

    // ----------------------------------------------------------------------
    // Strategy management (operator)
    // ----------------------------------------------------------------------
    function approveStrategy(address strategy, uint256 weight) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (strategies[strategy].active) revert StrategyAlreadyApproved();
        if (weight == 0) revert InvalidWeight();
        if (totalStrategyWeight + weight > WEIGHT_DENOMINATOR) revert StrategyWeightExceedsTotal();

        // Verify the strategy operates on the same asset.
        try IStrategy(strategy).want() returns (address want) {
            if (want != address(asset)) revert AssetMismatch();
        } catch {
            revert StrategyNotActive();
        }

        strategies[strategy] = StrategyInfo({active: true, targetWeight: weight, allocated: 0});
        strategyList.push(strategy);
        totalStrategyWeight += weight;

        // Approve the strategy to pull funds from the vault when depositing.
        asset.safeApprove(strategy, type(uint256).max);

        emit StrategyApproved(strategy, weight);
    }

    function revokeStrategy(address strategy) external onlyOperator nonReentrant {
        StrategyInfo storage info = strategies[strategy];
        if (!info.active) revert StrategyNotApproved();

        // Withdraw all deployed funds before revoking.
        uint256 currentlyAllocated = info.allocated;
        if (currentlyAllocated > 0) {
            // Effects first: zero out allocation before external call
            info.allocated = 0;
            uint256 withdrawn = IStrategy(strategy).withdraw(currentlyAllocated);
            // If the strategy returned less than expected, the loss is absorbed
            // by all share holders via a lower totalAssets().
            if (withdrawn < currentlyAllocated) {
                // no-op: totalAssets() recomputes from actual balances
            }
        }

        totalStrategyWeight -= info.targetWeight;
        info.active = false;
        info.targetWeight = 0;

        asset.safeApprove(strategy, 0);

        // Remove from strategyList (order not preserved).
        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; ++i) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[len - 1];
                strategyList.pop();
                break;
            }
        }

        emit StrategyRevoked(strategy);
    }

    function updateStrategyWeight(address strategy, uint256 newWeight) external onlyOperator {
        StrategyInfo storage info = strategies[strategy];
        if (!info.active) revert StrategyNotActive();
        if (newWeight == 0) revert InvalidWeight();

        uint256 oldWeight = info.targetWeight;
        if (totalStrategyWeight - oldWeight + newWeight > WEIGHT_DENOMINATOR) {
            revert StrategyWeightExceedsTotal();
        }

        info.targetWeight = newWeight;
        totalStrategyWeight = totalStrategyWeight - oldWeight + newWeight;

        emit StrategyWeightUpdated(strategy, oldWeight, newWeight);
    }

    // ----------------------------------------------------------------------
    // Rebalancing (operator)
    // ----------------------------------------------------------------------
    function rebalance() external onlyOperator nonReentrant {
        uint256 assets = totalAssets();
        uint256 idle = asset.balanceOf(address(this));

        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; ++i) {
            address strat = strategyList[i];
            StrategyInfo storage info = strategies[strat];
            if (!info.active) continue;

            uint256 desired = (assets * info.targetWeight) / WEIGHT_DENOMINATOR;

            if (desired > info.allocated) {
                uint256 toDeposit = desired - info.allocated;
                if (toDeposit > idle) {
                    toDeposit = idle;
                }
                if (toDeposit > 0) {
                    // Effects first: update allocation before external call
                    info.allocated += toDeposit;
                    idle -= toDeposit;
                    IStrategy(strat).deposit(toDeposit);
                }
            } else if (desired < info.allocated) {
                uint256 toWithdraw = info.allocated - desired;
                if (toWithdraw > 0) {
                    // Effects first: update allocation before external call
                    info.allocated -= toWithdraw;
                    uint256 withdrawn = IStrategy(strat).withdraw(toWithdraw);
                    idle += withdrawn;
                    // If withdrawn < toWithdraw, loss is absorbed by share holders.
                }
            }
        }

        emit Rebalanced(assets, block.timestamp);
    }

    function harvestAll() external onlyOperator nonReentrant {
        uint256 len = strategyList.length;
        uint256 totalHarvested = 0;

        for (uint256 i = 0; i < len; ++i) {
            address strat = strategyList[i];
            StrategyInfo storage info = strategies[strat];
            if (!info.active) continue;

            uint256 harvested = IStrategy(strat).harvest();
            if (harvested > 0) {
                totalHarvested += harvested;
                emit Harvested(strat, harvested);
            }
        }

        if (totalHarvested > 0 && totalShares > 0) {
            // Distribute rewards proportionally to shares.
            rewardPerShareStored += (totalHarvested * SHARES_PRECISION) / totalShares;
        }
    }

    function harvestStrategy(address strategy) external onlyOperator nonReentrant {
        StrategyInfo storage info = strategies[strategy];
        if (!info.active) revert StrategyNotActive();

        uint256 harvested = IStrategy(strategy).harvest();
        if (harvested > 0) {
            if (totalShares > 0) {
                rewardPerShareStored += (harvested * SHARES_PRECISION) / totalShares;
            }
            emit Harvested(strategy, harvested);
        }
    }

    // ----------------------------------------------------------------------
    // User functions
    // ----------------------------------------------------------------------
    function deposit(uint256 amount, address receiver)
        external
        nonReentrant
        updateReward(msg.sender)
        updateReward(receiver)
        returns (uint256 sharesMinted)
    {
        if (amount < minDeposit) revert DepositBelowMinimum(amount, minDeposit);
        if (receiver == address(0)) revert ZeroAddress();

        sharesMinted = _convertToShares(amount);
        if (sharesMinted < 1) revert ZeroAmount();

        // Effects
        userShares[receiver] += sharesMinted;
        totalShares += sharesMinted;

        // Interactions: transferFrom only from msg.sender (not arbitrary from)
        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, receiver, amount, sharesMinted);
    }

    function withdraw(uint256 sharesToBurn, address receiver, address owner)
        external
        nonReentrant
        updateReward(owner)
        returns (uint256 amountOut)
    {
        if (sharesToBurn < 1) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        if (userShares[owner] < sharesToBurn) revert InsufficientShares(sharesToBurn, userShares[owner]);

        // Only the owner can withdraw their own shares (no allowance system).
        if (msg.sender != owner) revert UnauthorizedWithdraw();

        amountOut = _convertToAssets(sharesToBurn);
        if (amountOut < 1) revert ZeroAmount();

        uint256 fee = (amountOut * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 toUser = amountOut - fee;

        // Effects: update shares and totals first (checks-effects-interactions)
        userShares[owner] -= sharesToBurn;
        totalShares -= sharesToBurn;

        // Ensure we have enough idle liquidity; pull from strategies if needed.
        _ensureIdleLiquidity(toUser);

        // Interactions
        if (toUser > 0) {
            asset.safeTransfer(receiver, toUser);
        }
        if (fee > 0) {
            asset.safeTransfer(feeReceiver, fee);
        }

        emit Withdraw(msg.sender, receiver, owner, toUser, sharesToBurn, fee);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) returns (uint256 claimed) {
        claimed = rewards[msg.sender];
        if (claimed < 1) revert NothingToClaim();

        rewards[msg.sender] = 0;
        rewardToken.safeTransfer(msg.sender, claimed);

        emit ClaimReward(msg.sender, claimed);
    }

    // ----------------------------------------------------------------------
    // View functions
    // ----------------------------------------------------------------------
    function totalAssets() public view returns (uint256) {
        uint256 balance = asset.balanceOf(address(this));
        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; ++i) {
            StrategyInfo storage info = strategies[strategyList[i]];
            if (info.active) {
                balance += info.allocated;
            }
        }
        return balance;
    }

    function convertToShares(uint256 amount) public view returns (uint256) {
        uint256 _totalShares = totalShares;
        uint256 _totalAssets = totalAssets();
        if (_totalShares < 1 || _totalAssets < 1) {
            return amount;
        }
        return (amount * _totalShares) / _totalAssets;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _totalShares = totalShares;
        if (_totalShares < 1) {
            return 0;
        }
        return (shares * totalAssets()) / _totalShares;
    }

    function sharesOf(address account) external view returns (uint256) {
        return userShares[account];
    }

    function balanceOf(address account) external view returns (uint256) {
        uint256 _totalShares = totalShares;
        if (_totalShares < 1) {
            return 0;
        }
        return (userShares[account] * totalAssets()) / _totalShares;
    }

    function pendingRewards(address account) external view returns (uint256) {
        return rewards[account] + _earned(account);
    }

    function getStrategyList() external view returns (address[] memory) {
        return strategyList;
    }

    function getStrategyInfo(address strategy)
        external
        view
        returns (bool active, uint256 targetWeight, uint256 allocated)
    {
        StrategyInfo storage info = strategies[strategy];
        return (info.active, info.targetWeight, info.allocated);
    }

    // ----------------------------------------------------------------------
    // Internal helpers
    // ----------------------------------------------------------------------
    function _convertToShares(uint256 amount) internal view returns (uint256) {
        uint256 _totalShares = totalShares;
        uint256 _totalAssets = totalAssets();
        if (_totalShares < 1 || _totalAssets < 1) {
            return amount;
        }
        return (amount * _totalShares) / _totalAssets;
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        uint256 _totalShares = totalShares;
        if (_totalShares < 1) {
            return 0;
        }
        return (shares * totalAssets()) / _totalShares;
    }

    function _earned(address account) internal view returns (uint256) {
        return (userShares[account] * (rewardPerShareStored - userRewardPerSharePaid[account])) / SHARES_PRECISION;
    }

    function _updateReward(address account) internal {
        uint256 accumulated = rewardPerShareStored;
        uint256 paid = userRewardPerSharePaid[account];
        if (accumulated > paid) {
            rewards[account] += (userShares[account] * (accumulated - paid)) / SHARES_PRECISION;
        }
        userRewardPerSharePaid[account] = accumulated;
    }

    function _ensureIdleLiquidity(uint256 needed) internal {
        uint256 idle = asset.balanceOf(address(this));
        if (idle >= needed) return;

        uint256 shortfall = needed - idle;
        uint256 len = strategyList.length;
        if (len < 1) revert InsufficientVaultBalance(needed, idle);

        uint256 remaining = shortfall;
        for (uint256 i = 0; i < len && remaining > 0; ++i) {
            address strat = strategyList[i];
            StrategyInfo storage info = strategies[strat];
            if (!info.active || info.allocated < 1) continue;

            uint256 toWithdraw = remaining < info.allocated ? remaining : info.allocated;
            // Effects first: update allocation before external call
            info.allocated -= toWithdraw;
            uint256 withdrawn = IStrategy(strat).withdraw(toWithdraw);
            if (withdrawn >= remaining) {
                remaining = 0;
            } else {
                remaining -= withdrawn;
            }
        }

        if (remaining > 0) revert InsufficientVaultBalance(needed, asset.balanceOf(address(this)));
    }

    function _readDecimals(address tokenAddress) internal view returns (uint8) {
        (bool success, bytes memory data) = tokenAddress.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        }
        return 18;
    }
}
