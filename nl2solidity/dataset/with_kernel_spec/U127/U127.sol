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

library SafeERC20 {
    error SafeERC20Failed();

    function _check(bool ok, bytes memory data) private pure {
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20Failed();
        }
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        _check(ok, data);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        _check(ok, data);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/// @title RiskBufferPool
/// @notice A stablecoin pool that acts as a capital buffer for real-world
///         insurance risks. Users deposit stablecoins and accrue rewards from
///         settled risk tranches. A designated operator deploys capital into
///         tranches and reports settlement outcomes (profit or loss). Total
///         deployed capital is capped at 80% of total deposited capital. A
///         0.5% fee is deducted from every withdrawal and retained by the pool.
contract RiskBufferPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error NotOperator();
    error InsufficientDeposit();
    error InsufficientLiquidity();
    error ExceedsMaxDeployment();
    error InvalidBps();
    error TrancheNotFound();
    error TrancheNotActive();
    error TrancheAlreadySettled();
    error LossExceedsCapital();
    error NoPendingRewards();

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount, uint256 fee, uint256 net);
    event RewardClaimed(address indexed user, uint256 amount);
    event TrancheInitiated(uint256 indexed trancheId, uint256 capitalDeployed);
    event TrancheSettled(uint256 indexed trancheId, uint256 capitalReturned, uint256 premium, uint256 loss);
    event MaxCapitalDeploymentUpdated(uint256 oldBps, uint256 newBps);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------
    uint16 public constant MAX_DEPLOYMENT_BPS_CAP = 8000; // 80% hard cap
    uint16 public constant WITHDRAW_FEE_BPS = 50;         // 0.5%
    uint16 private constant BPS_DENOMINATOR = 10000;
    uint256 private constant REWARD_PRECISION = 1e18;

    // ------------------------------------------------------------------
    // Configuration
    // ------------------------------------------------------------------
    IERC20 public immutable stablecoin;
    address public operator;
    uint16 public maxCapitalDeploymentBps;

    // ------------------------------------------------------------------
    // Capital accounting
    // ------------------------------------------------------------------
    uint256 public totalDepositedCapital; // recorded total stablecoin deposited
    uint256 public totalShares;           // total share units minted (1:1 at first deposit)
    uint256 public totalDeployedCapital;  // capital currently deployed in active tranches
    uint256 public accRewardPerShare;     // reward accumulator, scaled by REWARD_PRECISION
    uint256 public rewardPoolBalance;     // stablecoin earmarked for future reward payouts

    mapping(address => uint256) public shares;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public unclaimedRewards;

    struct RiskTranche {
        uint256 capitalDeployed;
        bool active;
        bool settled;
    }
    mapping(uint256 => RiskTranche) public tranches;
    uint256 public trancheCount;

    // ------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        maxCapitalDeploymentBps = MAX_DEPLOYMENT_BPS_CAP;
    }

    // ------------------------------------------------------------------
    // Share math
    // ------------------------------------------------------------------
    function _assetsToShares(uint256 assets) internal view returns (uint256) {
        if (totalShares == 0) return assets;
        return (assets * totalShares) / totalDepositedCapital;
    }

    function _sharesToAssets(uint256 sh) internal view returns (uint256) {
        if (totalShares == 0) return 0;
        return (sh * totalDepositedCapital) / totalShares;
    }

    // ------------------------------------------------------------------
    // Reward accounting
    // ------------------------------------------------------------------
    function _settlePending(address user) internal {
        uint256 owed = (shares[user] * accRewardPerShare) / REWARD_PRECISION;
        if (owed > rewardDebt[user]) {
            unclaimedRewards[user] += owed - rewardDebt[user];
        }
    }

    function _syncDebt(address user) internal {
        rewardDebt[user] = (shares[user] * accRewardPerShare) / REWARD_PRECISION;
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------
    function depositedOf(address user) external view returns (uint256) {
        return _sharesToAssets(shares[user]);
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 owed = (shares[user] * accRewardPerShare) / REWARD_PRECISION;
        uint256 pend = owed > rewardDebt[user] ? owed - rewardDebt[user] : 0;
        return unclaimedRewards[user] + pend;
    }

    /// @notice Stablecoin currently recorded as deposited but not deployed.
    function availableLiquidity() public view returns (uint256) {
        return totalDepositedCapital - totalDeployedCapital;
    }

    /// @notice Additional capital that can be deployed without breaching the cap.
    function deployableCapacity() public view returns (uint256) {
        uint256 maxDeploy = (totalDepositedCapital * maxCapitalDeploymentBps) / BPS_DENOMINATOR;
        if (totalDeployedCapital >= maxDeploy) return 0;
        return maxDeploy - totalDeployedCapital;
    }

    // ------------------------------------------------------------------
    // User actions
    // ------------------------------------------------------------------
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _settlePending(msg.sender);

        uint256 sh = _assetsToShares(amount);
        shares[msg.sender] += sh;
        totalShares += sh;
        totalDepositedCapital += amount;

        _syncDebt(msg.sender);

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 userShares = shares[msg.sender];
        if (userShares == 0 || amount > _sharesToAssets(userShares)) revert InsufficientDeposit();
        if (amount > availableLiquidity()) revert InsufficientLiquidity();

        _settlePending(msg.sender);

        uint256 sh = _assetsToShares(amount);
        if (sh > shares[msg.sender]) sh = shares[msg.sender]; // rounding safety

        shares[msg.sender] -= sh;
        totalShares -= sh;
        totalDepositedCapital -= amount;

        uint256 fee = (amount * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        _syncDebt(msg.sender);

        stablecoin.safeTransfer(msg.sender, payout);
        // fee is deducted from the withdrawn amount and retained by the pool

        emit Withdrawal(msg.sender, amount, fee, payout);
    }

    function claimRewards() external nonReentrant returns (uint256 claimed) {
        _settlePending(msg.sender);
        claimed = unclaimedRewards[msg.sender];
        if (claimed == 0) {
            _syncDebt(msg.sender);
            revert NoPendingRewards();
        }
        unclaimedRewards[msg.sender] = 0;
        _syncDebt(msg.sender);

        rewardPoolBalance -= claimed;
        stablecoin.safeTransfer(msg.sender, claimed);

        emit RewardClaimed(msg.sender, claimed);
    }

    // ------------------------------------------------------------------
    // Operator actions
    // ------------------------------------------------------------------
    function initiateTranche(uint256 capitalAmount)
        external
        onlyOperator
        nonReentrant
        returns (uint256 trancheId)
    {
        if (capitalAmount == 0) revert ZeroAmount();
        if (capitalAmount > deployableCapacity()) revert ExceedsMaxDeployment();
        if (capitalAmount > availableLiquidity()) revert InsufficientLiquidity();

        trancheId = trancheCount;
        tranches[trancheId] = RiskTranche({
            capitalDeployed: capitalAmount,
            active: true,
            settled: false
        });
        trancheCount += 1;
        totalDeployedCapital += capitalAmount;

        stablecoin.safeTransfer(msg.sender, capitalAmount);

        emit TrancheInitiated(trancheId, capitalAmount);
    }

    /// @notice Settles a risk tranche. The caller (operator) must have approved
    ///         the pool to pull `returnedAmount` stablecoin from their own
    ///         account. If `returnedAmount` exceeds the deployed capital, the
    ///         surplus is distributed to depositors as rewards. If it is less,
    ///         the shortfall is treated as a loss and absorbed proportionally
    ///         by depositors via a reduction of total deposited capital.
    function settleTranche(uint256 trancheId, uint256 returnedAmount) external onlyOperator nonReentrant {
        if (trancheId >= trancheCount) revert TrancheNotFound();
        RiskTranche storage t = tranches[trancheId];
        if (!t.active) revert TrancheNotActive();
        if (t.settled) revert TrancheAlreadySettled();

        uint256 deployed = t.capitalDeployed;

        uint256 premium = 0;
        uint256 loss = 0;
        if (returnedAmount >= deployed) {
            premium = returnedAmount - deployed;
        } else {
            loss = deployed - returnedAmount;
            if (loss > totalDepositedCapital) revert LossExceedsCapital();
        }

        // Determine whether premium goes to depositors or back to operator
        bool premiumToOperator = (premium > 0 && totalShares == 0);

        // ----------------------------------------------------------------
        // Effects: update all state before any external calls
        // ----------------------------------------------------------------
        t.active = false;
        t.settled = true;
        totalDeployedCapital -= deployed;

        if (loss > 0) {
            totalDepositedCapital -= loss;
        }

        if (premium > 0 && !premiumToOperator) {
            accRewardPerShare += (premium * REWARD_PRECISION) / totalShares;
            rewardPoolBalance += premium;
        }

        // ----------------------------------------------------------------
        // Interactions: external token transfers using msg.sender (the
        // verified operator) as the source, not the operator state variable
        // ----------------------------------------------------------------
        stablecoin.safeTransferFrom(msg.sender, address(this), returnedAmount);

        if (premiumToOperator) {
            stablecoin.safeTransfer(msg.sender, premium);
        }

        emit TrancheSettled(trancheId, returnedAmount, premium, loss);
    }

    function setMaxCapitalDeployment(uint16 newBps) external onlyOperator {
        if (newBps > MAX_DEPLOYMENT_BPS_CAP) revert InvalidBps();
        uint16 old = maxCapitalDeploymentBps;
        maxCapitalDeploymentBps = newBps;
        emit MaxCapitalDeploymentUpdated(old, newBps);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }
}
