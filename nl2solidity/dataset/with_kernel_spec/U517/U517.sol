// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IStrategy {
    function invest(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function harvest() external returns (uint256);
}

contract YieldVault {
    /* ============================================================
                            Custom Errors
    ============================================================ */
    error ZeroAddress();
    error NotAuthorized();
    error DepositsPaused();
    error WithdrawalsPaused();
    error BelowMinimumDeposit();
    error InsufficientBalance();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error InvalidAllocation();
    error AllocationExceedsMax();
    error NothingToClaim();
    error ZeroAmount();
    error ArrayLengthMismatch();
    error ReentrantCall();

    /* ============================================================
                              Events
    ============================================================ */
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee, address indexed treasury);
    event RewardClaimed(address indexed user, uint256 amount);
    event StrategyApproved(address indexed strategy, string name);
    event StrategyRevoked(address indexed strategy);
    event AllocationChanged(address indexed strategy, uint256 oldAllocation, uint256 newAllocation);
    event StrategyInvested(address indexed strategy, uint256 amount);
    event StrategyWithdrawn(address indexed strategy, uint256 returned);
    event RewardsDistributed(uint256 amount, uint256 newAccPerShare);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event DepositPauseChanged(bool paused);
    event WithdrawalPauseChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /* ============================================================
                            Constants
    ============================================================ */
    uint256 public constant MIN_DEPOSIT = 100 * 1e18;
    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant ACC_PRECISION = 1e18;

    /* ============================================================
                             Storage
    ============================================================ */
    IERC20 public immutable stablecoin;
    address public owner;
    address public operator;
    address public treasury;

    uint256 public totalValueLocked;
    bool public depositsPaused;
    bool public withdrawalsPaused;
    uint256 private _locked = 1;

    struct Strategy {
        bool approved;
        uint256 allocationBps; // share of each new deposit sent here (max sum = 100%)
        uint256 invested;      // amount of stablecoin currently deployed
        string name;
    }

    address[] public strategiesList;
    mapping(address => Strategy) public strategies;

    mapping(address => uint256) public accountBalance;

    // Reward accumulator (MasterChef-style)
    uint256 public accRewardPerShare;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public pendingRewards;

    /* ============================================================
                            Modifiers
    ============================================================ */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }
    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotAuthorized();
        _;
    }
    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }
    modifier whenDepositsOpen() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }
    modifier whenWithdrawalsOpen() {
        if (withdrawalsPaused) revert WithdrawalsPaused();
        _;
    }

    /* ============================================================
                            Constructor
    ============================================================ */
    constructor(address _stablecoin, address _treasury, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        treasury = _treasury;
        operator = _operator;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /* ============================================================
                         Administration (Owner)
    ============================================================ */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    /* ============================================================
                       Strategy Management (Operator)
    ============================================================ */
    function approveStrategy(address strategy, string calldata name) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (strategies[strategy].approved) revert StrategyAlreadyApproved();
        strategiesList.push(strategy);
        strategies[strategy] = Strategy({
            approved: true,
            allocationBps: 0,
            invested: 0,
            name: name
        });
        emit StrategyApproved(strategy, name);
    }

    function revokeStrategy(address strategy) external onlyOperator nonReentrant {
        Strategy storage s = strategies[strategy];
        if (!s.approved) revert StrategyNotApproved();

        uint256 invested = s.invested;
        s.approved = false;
        s.allocationBps = 0;

        if (invested > 0) {
            uint256 returned = IStrategy(strategy).withdraw(invested);
            if (returned > s.invested) {
                s.invested = 0;
            } else {
                s.invested -= returned;
            }
            emit StrategyWithdrawn(strategy, returned);
        }

        // Remove from strategiesList
        uint256 len = strategiesList.length;
        for (uint256 i = 0; i < len; i++) {
            if (strategiesList[i] == strategy) {
                strategiesList[i] = strategiesList[len - 1];
                strategiesList.pop();
                break;
            }
        }

        emit StrategyRevoked(strategy);
    }

    function setAllocations(
        address[] calldata _strategies,
        uint256[] calldata _allocations
    ) external onlyOperator {
        if (_strategies.length != _allocations.length) revert ArrayLengthMismatch();
        uint256 total;
        for (uint256 i = 0; i < _strategies.length; i++) {
            Strategy storage s = strategies[_strategies[i]];
            if (!s.approved) revert StrategyNotApproved();
            if (_allocations[i] > BPS_DENOMINATOR) revert InvalidAllocation();
            uint256 old = s.allocationBps;
            s.allocationBps = _allocations[i];
            total += _allocations[i];
            emit AllocationChanged(_strategies[i], old, _allocations[i]);
        }
        if (total > BPS_DENOMINATOR) revert AllocationExceedsMax();
    }

    function pauseDeposits() external onlyOperator {
        if (!depositsPaused) {
            depositsPaused = true;
            emit DepositPauseChanged(true);
        }
    }

    function unpauseDeposits() external onlyOperator {
        if (depositsPaused) {
            depositsPaused = false;
            emit DepositPauseChanged(false);
        }
    }

    function pauseWithdrawals() external onlyOperator {
        if (!withdrawalsPaused) {
            withdrawalsPaused = true;
            emit WithdrawalPauseChanged(true);
        }
    }

    function unpauseWithdrawals() external onlyOperator {
        if (withdrawalsPaused) {
            withdrawalsPaused = false;
            emit WithdrawalPauseChanged(false);
        }
    }

    function harvest(address strategy) external onlyOperator nonReentrant {
        Strategy storage s = strategies[strategy];
        if (!s.approved) revert StrategyNotApproved();

        uint256 before = stablecoin.balanceOf(address(this));
        uint256 reported = IStrategy(strategy).harvest();
        uint256 afterBal = stablecoin.balanceOf(address(this));
        uint256 gained = afterBal > before ? afterBal - before : 0;
        uint256 distributed = gained > 0 ? gained : reported;

        if (distributed == 0) revert ZeroAmount();
        if (totalValueLocked == 0) revert InvalidAllocation();

        accRewardPerShare += (distributed * ACC_PRECISION) / totalValueLocked;
        emit RewardsDistributed(distributed, accRewardPerShare);
    }

    /* ============================================================
                            User Functions
    ============================================================ */
    function deposit(uint256 amount) external whenDepositsOpen nonReentrant {
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit();

        _harvestPending(msg.sender);

        stablecoin.transferFrom(msg.sender, address(this), amount);

        accountBalance[msg.sender] += amount;
        totalValueLocked += amount;

        _updateDebt(msg.sender);
        _deployToStrategies(amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenWithdrawalsOpen nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (accountBalance[msg.sender] < amount) revert InsufficientBalance();

        _harvestPending(msg.sender);

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 toUser = amount - fee;

        accountBalance[msg.sender] -= amount;
        totalValueLocked -= amount;

        _updateDebt(msg.sender);
        _pullFromStrategies(amount);

        stablecoin.transfer(msg.sender, toUser);
        if (fee > 0) {
            stablecoin.transfer(treasury, fee);
        }

        emit Withdraw(msg.sender, amount, fee, treasury);
    }

    function claimRewards() external whenWithdrawalsOpen nonReentrant {
        _harvestPending(msg.sender);
        _updateDebt(msg.sender);

        uint256 amount = pendingRewards[msg.sender];
        if (amount == 0) revert NothingToClaim();
        pendingRewards[msg.sender] = 0;

        stablecoin.transfer(msg.sender, amount);
        emit RewardClaimed(msg.sender, amount);
    }

    /* ============================================================
                           Internal Helpers
    ============================================================ */
    function _harvestPending(address user) internal {
        uint256 balance = accountBalance[user];
        uint256 acc = (balance * accRewardPerShare) / ACC_PRECISION;
        uint256 debt = rewardDebt[user];
        if (acc > debt) {
            pendingRewards[user] += acc - debt;
        }
    }

    function _updateDebt(address user) internal {
        rewardDebt[user] = (accountBalance[user] * accRewardPerShare) / ACC_PRECISION;
    }

    function _deployToStrategies(uint256 amount) internal {
        for (uint256 i = 0; i < strategiesList.length; i++) {
            address s = strategiesList[i];
            Strategy storage strat = strategies[s];
            if (!strat.approved || strat.allocationBps == 0) continue;

            uint256 toInvest = (amount * strat.allocationBps) / BPS_DENOMINATOR;
            if (toInvest == 0) continue;

            stablecoin.approve(s, toInvest);
            IStrategy(s).invest(toInvest);
            strat.invested += toInvest;

            emit StrategyInvested(s, toInvest);
        }
    }

    function _pullFromStrategies(uint256 amount) internal {
        // First compute how much is currently deployed.
        uint256 totalInvested = 0;
        for (uint256 i = 0; i < strategiesList.length; i++) {
            Strategy storage s = strategies[strategiesList[i]];
            if (s.approved) {
                totalInvested += s.invested;
            }
        }

        uint256 idle = stablecoin.balanceOf(address(this));

        // If there is nothing deployed, the vault's idle balance must cover it.
        if (totalInvested == 0) return;

        // If idle balance already covers the withdrawal, nothing to pull.
        if (idle >= amount) return;

        uint256 deficit = amount - idle;

        // Pull proportionally from each strategy based on its share of invested.
        for (uint256 i = 0; i < strategiesList.length; i++) {
            address s = strategiesList[i];
            Strategy storage strat = strategies[s];
            if (!strat.approved || strat.invested == 0) continue;

            uint256 toPull = (deficit * strat.invested) / totalInvested;
            if (toPull == 0) continue;

            uint256 returned = IStrategy(s).withdraw(toPull);
            if (returned > strat.invested) {
                strat.invested = 0;
            } else {
                strat.invested -= returned;
            }

            emit StrategyWithdrawn(s, returned);
        }
    }

    /* ============================================================
                            Views
    ============================================================ */
    function pendingReward(address user) external view returns (uint256) {
        uint256 balance = accountBalance[user];
        uint256 acc = (balance * accRewardPerShare) / ACC_PRECISION;
        uint256 debt = rewardDebt[user];
        uint256 accrued = acc > debt ? acc - debt : 0;
        return pendingRewards[user] + accrued;
    }

    function strategyCount() external view returns (uint256) {
        return strategiesList.length;
    }

    function getStrategy(address strategy)
        external
        view
        returns (bool approved, uint256 allocationBps, uint256 invested, string memory name)
    {
        Strategy storage s = strategies[strategy];
        return (s.approved, s.allocationBps, s.invested, s.name);
    }

    function totalInvestedAcrossStrategies() external view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < strategiesList.length; i++) {
            Strategy storage s = strategies[strategiesList[i]];
            if (s.approved) {
                total += s.invested;
            }
        }
        return total;
    }
}
