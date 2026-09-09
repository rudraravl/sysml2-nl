// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function claimRewards() external returns (uint256);
}

contract StableYieldVault {
    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant LOCK_PERIOD = 24 hours;
    uint256 public constant ACC_PRECISION = 1e18;

    // ------------------------------------------------------------------
    // Custom errors
    // ------------------------------------------------------------------
    error ZeroAmount();
    error ZeroAddress();
    error SameToken();
    error NotOwner();
    error NotOperator();
    error DepositsPaused();
    error WithdrawalsPaused();
    error LockActive();
    error InsufficientShares();
    error InsufficientIdleLiquidity();
    error InsufficientRewardBalance();
    error NoPendingRewards();
    error InvalidAllocation();
    error StrategyNotFound();
    error StrategyNotActive();
    error TransferFailed();
    error ReentrantCall();

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares, uint256 fee, uint256 payout);
    event ClaimRewards(address indexed user, uint256 amount);
    event StrategyAdded(uint256 indexed index, address indexed strategy, uint256 allocationBps);
    event StrategyAllocationUpdated(uint256 indexed index, address indexed strategy, uint256 allocationBps);
    event StrategyActiveUpdated(uint256 indexed index, address indexed strategy, bool active);
    event StrategyRemoved(uint256 indexed index, address indexed strategy);
    event Rebalance(address indexed caller, uint256 totalAssets, uint256 idleAssets);
    event Harvested(address indexed caller, uint256 amount);
    event RewardsDistributed(address indexed caller, uint256 amount);
    event DepositsPausedSet(bool paused);
    event WithdrawalsPausedSet(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    // ------------------------------------------------------------------
    // Immutable & access control
    // ------------------------------------------------------------------
    IERC20 public immutable asset;
    IERC20 public immutable rewardToken;

    address public owner;
    address public operator;
    bool public depositsPaused;
    bool public withdrawalsPaused;

    // ------------------------------------------------------------------
    // Vault accounting
    // ------------------------------------------------------------------
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public userDeposited;
    mapping(address => uint256) public lastDepositTime;

    // ------------------------------------------------------------------
    // Reward accounting (dividend style)
    // ------------------------------------------------------------------
    uint256 public accRewardPerShare;
    uint256 public pendingRewardPool;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public accruedRewards;

    // ------------------------------------------------------------------
    // Strategies
    // ------------------------------------------------------------------
    struct Strategy {
        address adapter;
        uint256 allocationBps;
        bool active;
    }
    Strategy[] public strategies;
    uint256 public totalActiveAllocationBps;

    // ------------------------------------------------------------------
    // Reentrancy guard
    // ------------------------------------------------------------------
    uint256 private _locked = 1;

    // ------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    modifier whenWithdrawalsNotPaused() {
        if (withdrawalsPaused) revert WithdrawalsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------
    constructor(address asset_, address rewardToken_, address operator_) {
        if (asset_ == address(0) || rewardToken_ == address(0) || operator_ == address(0)) revert ZeroAddress();
        if (asset_ == rewardToken_) revert SameToken();

        asset = IERC20(asset_);
        rewardToken = IERC20(rewardToken_);
        owner = msg.sender;
        operator = operator_;

        emit OwnerChanged(address(0), owner);
        emit OperatorChanged(address(0), operator);
    }

    // ------------------------------------------------------------------
    // User actions
    // ------------------------------------------------------------------
    function deposit(uint256 amount) external whenDepositsNotPaused nonReentrant returns (uint256 sharesMinted) {
        if (amount == 0) revert ZeroAmount();

        // Accrue any pending rewards for existing shares before minting new ones.
        _harvestPending(msg.sender);

        uint256 total = totalAssets();
        if (totalShares == 0) {
            sharesMinted = amount;
        } else {
            // Division by zero reverts naturally if total is 0 with shares outstanding (insolvent).
            sharesMinted = (amount * totalShares) / total;
            if (sharesMinted == 0) revert ZeroAmount();
        }

        _safeTransferFrom(asset, msg.sender, address(this), amount);

        shares[msg.sender] += sharesMinted;
        totalShares += sharesMinted;
        userDeposited[msg.sender] += amount;
        lastDepositTime[msg.sender] = block.timestamp;

        // New shares should not earn past rewards.
        rewardDebt[msg.sender] = (shares[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        emit Deposit(msg.sender, amount, sharesMinted);
        return sharesMinted;
    }

    function withdraw(uint256 sharesAmount) external whenWithdrawalsNotPaused nonReentrant returns (uint256 payout) {
        if (sharesAmount == 0) revert ZeroAmount();
        if (shares[msg.sender] < sharesAmount) revert InsufficientShares();
        if (block.timestamp < lastDepositTime[msg.sender] + LOCK_PERIOD) revert LockActive();

        // Accrue rewards before burning shares.
        _harvestPending(msg.sender);

        uint256 total = totalAssets();
        uint256 amount = (sharesAmount * total) / totalShares;
        if (amount == 0) revert ZeroAmount();

        // Compute fee with multiply-before-divide to avoid precision loss from
        // an intermediate division result being reused in a multiplication.
        uint256 fee = (sharesAmount * total * WITHDRAWAL_FEE_BPS) / totalShares / BPS_DENOMINATOR;
        payout = amount - fee;

        // Read idle balance fresh right before the liquidity check.
        if (asset.balanceOf(address(this)) < payout) revert InsufficientIdleLiquidity();

        // Effects: burn shares, fee stays in vault.
        shares[msg.sender] -= sharesAmount;
        totalShares -= sharesAmount;
        rewardDebt[msg.sender] = (shares[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        // Interaction: transfer stablecoins back to user.
        _safeTransfer(asset, msg.sender, payout);

        emit Withdraw(msg.sender, amount, sharesAmount, fee, payout);
        return payout;
    }

    function claimRewards() external nonReentrant returns (uint256 amount) {
        _harvestPending(msg.sender);
        amount = accruedRewards[msg.sender];
        if (!(amount > 0)) revert NoPendingRewards();
        if (rewardToken.balanceOf(address(this)) < amount) revert InsufficientRewardBalance();

        accruedRewards[msg.sender] = 0;
        _safeTransfer(rewardToken, msg.sender, amount);

        emit ClaimRewards(msg.sender, amount);
        return amount;
    }

    // ------------------------------------------------------------------
    // Operator: strategy management
    // ------------------------------------------------------------------
    function addStrategy(address adapter, uint256 allocationBps) external onlyOperator returns (uint256 index) {
        if (adapter == address(0)) revert ZeroAddress();
        if (allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();
        if (totalActiveAllocationBps + allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();

        strategies.push(Strategy({adapter: adapter, allocationBps: allocationBps, active: true}));
        totalActiveAllocationBps += allocationBps;

        index = strategies.length - 1;
        emit StrategyAdded(index, adapter, allocationBps);
        return index;
    }

    function updateStrategyAllocation(uint256 index, uint256 allocationBps) external onlyOperator {
        if (index >= strategies.length) revert StrategyNotFound();
        Strategy storage s = strategies[index];
        if (!s.active) revert StrategyNotActive();
        if (allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();

        uint256 newTotal = totalActiveAllocationBps - s.allocationBps + allocationBps;
        if (newTotal > BPS_DENOMINATOR) revert InvalidAllocation();

        s.allocationBps = allocationBps;
        totalActiveAllocationBps = newTotal;

        emit StrategyAllocationUpdated(index, s.adapter, allocationBps);
    }

    function setStrategyActive(uint256 index, bool active) external onlyOperator {
        if (index >= strategies.length) revert StrategyNotFound();
        Strategy storage s = strategies[index];
        if (s.active == active) return;

        if (active) {
            if (totalActiveAllocationBps + s.allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();
            s.active = true;
            totalActiveAllocationBps += s.allocationBps;
        } else {
            s.active = false;
            totalActiveAllocationBps -= s.allocationBps;
        }

        emit StrategyActiveUpdated(index, s.adapter, active);
    }

    function removeStrategy(uint256 index) external onlyOperator nonReentrant {
        if (index >= strategies.length) revert StrategyNotFound();
        Strategy storage s = strategies[index];

        if (s.active) {
            s.active = false;
            totalActiveAllocationBps -= s.allocationBps;
        }

        uint256 balance = IStrategy(s.adapter).balanceOf(address(this));
        if (balance > 0) {
            IStrategy(s.adapter).withdraw(balance);
        }

        address removedAdapter = s.adapter;
        uint256 lastIndex = strategies.length - 1;
        if (index != lastIndex) {
            strategies[index] = strategies[lastIndex];
        }
        strategies.pop();

        emit StrategyRemoved(index, removedAdapter);
    }

    function rebalance() external onlyOperator nonReentrant {
        uint256 len = strategies.length;

        // Phase 1: Withdraw from overallocated strategies to free idle liquidity.
        // Read balances fresh in every iteration so no stale values are used
        // after external calls.
        for (uint256 i = 0; i < len; i++) {
            if (!strategies[i].active) continue;
            uint256 current = IStrategy(strategies[i].adapter).balanceOf(address(this));
            if (current == 0) continue;
            uint256 total = totalAssets();
            uint256 target = (total * strategies[i].allocationBps) / BPS_DENOMINATOR;
            if (current > target) {
                IStrategy(strategies[i].adapter).withdraw(current - target);
            }
        }

        // Phase 2: Deposit into underallocated strategies using freed idle funds.
        // Read total, current, and idle fresh in every iteration to avoid
        // using stale balances after external calls.
        for (uint256 i = 0; i < len; i++) {
            if (!strategies[i].active) continue;
            uint256 current = IStrategy(strategies[i].adapter).balanceOf(address(this));
            uint256 total = totalAssets();
            uint256 target = (total * strategies[i].allocationBps) / BPS_DENOMINATOR;
            if (target > current) {
                uint256 diff = target - current;
                uint256 idle = asset.balanceOf(address(this));
                if (idle < diff) revert InsufficientIdleLiquidity();
                _forceApprove(asset, strategies[i].adapter, diff);
                IStrategy(strategies[i].adapter).deposit(diff);
            }
        }

        emit Rebalance(msg.sender, totalAssets(), asset.balanceOf(address(this)));
    }

    function harvest() external onlyOperator nonReentrant returns (uint256 harvested) {
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            if (!strategies[i].active) continue;
            uint256 amount = IStrategy(strategies[i].adapter).claimRewards();
            if (amount > 0) {
                harvested += amount;
            }
        }

        if (harvested > 0) {
            pendingRewardPool += harvested;
            emit Harvested(msg.sender, harvested);
        }
        return harvested;
    }

    function distributeRewards(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        pendingRewardPool += amount;
        emit RewardsDistributed(msg.sender, amount);
    }

    // ------------------------------------------------------------------
    // Operator: pause controls
    // ------------------------------------------------------------------
    function setDepositsPaused(bool paused) external onlyOperator {
        depositsPaused = paused;
        emit DepositsPausedSet(paused);
    }

    function setWithdrawalsPaused(bool paused) external onlyOperator {
        withdrawalsPaused = paused;
        emit WithdrawalsPausedSet(paused);
    }

    // ------------------------------------------------------------------
    // Owner controls
    // ------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnerChanged(previous, newOwner);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------
    function totalAssets() public view returns (uint256) {
        uint256 total = asset.balanceOf(address(this));
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            total += IStrategy(strategies[i].adapter).balanceOf(address(this));
        }
        return total;
    }

    function idleAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function allocatedAssets() external view returns (uint256) {
        uint256 total;
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            total += IStrategy(strategies[i].adapter).balanceOf(address(this));
        }
        return total;
    }

    function strategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function getStrategy(uint256 index)
        external
        view
        returns (address adapter, uint256 allocationBps, bool active)
    {
        if (index >= strategies.length) revert StrategyNotFound();
        Strategy storage s = strategies[index];
        return (s.adapter, s.allocationBps, s.active);
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 rps = accRewardPerShare;
        if (totalShares > 0 && pendingRewardPool > 0) {
            rps += (pendingRewardPool * ACC_PRECISION) / totalShares;
        }
        uint256 pending = (shares[user] * rps) / ACC_PRECISION;
        uint256 debt = rewardDebt[user];
        if (pending > debt) {
            return (pending - debt) + accruedRewards[user];
        }
        return accruedRewards[user];
    }

    function convertToShares(uint256 amount) external view returns (uint256) {
        uint256 total = totalAssets();
        if (totalShares == 0 || total == 0) return amount;
        return (amount * totalShares) / total;
    }

    function convertToAssets(uint256 sharesAmount) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (sharesAmount * totalAssets()) / totalShares;
    }

    function availableToWithdraw(address user) external view returns (uint256) {
        if (block.timestamp < lastDepositTime[user] + LOCK_PERIOD) return 0;
        if (shares[user] == 0 || totalShares == 0) return 0;
        uint256 total = totalAssets();
        uint256 amount = (shares[user] * total) / totalShares;
        // Compute fee with multiply-before-divide to avoid precision loss.
        uint256 fee = (shares[user] * total * WITHDRAWAL_FEE_BPS) / totalShares / BPS_DENOMINATOR;
        return amount - fee;
    }

    // ------------------------------------------------------------------
    // Internal reward accounting
    // ------------------------------------------------------------------
    function _updatePool() internal {
        if (totalShares > 0 && pendingRewardPool > 0) {
            accRewardPerShare += (pendingRewardPool * ACC_PRECISION) / totalShares;
            pendingRewardPool = 0;
        }
    }

    function _harvestPending(address user) internal {
        _updatePool();
        if (user != address(0)) {
            uint256 pending = (shares[user] * accRewardPerShare) / ACC_PRECISION;
            uint256 debt = rewardDebt[user];
            if (pending > debt) {
                accruedRewards[user] += pending - debt;
            }
            rewardDebt[user] = (shares[user] * accRewardPerShare) / ACC_PRECISION;
        }
    }

    // ------------------------------------------------------------------
    // Safe ERC20 helpers
    // ------------------------------------------------------------------
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _forceApprove(IERC20 token, address spender, uint256 amount) internal {
        _safeApprove(token, spender, 0);
        _safeApprove(token, spender, amount);
    }

    // ------------------------------------------------------------------
    // Receive
    // ------------------------------------------------------------------
    receive() external payable {
        revert TransferFailed();
    }
}
