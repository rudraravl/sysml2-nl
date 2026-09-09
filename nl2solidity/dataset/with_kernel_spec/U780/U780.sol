// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IYieldVenue {
    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shareAmount) external returns (uint256 amount);
    function harvest() external returns (uint256 harvested);
    function balanceOf(address account) external view returns (uint256);
    function totalShares() external view returns (uint256);
}

contract StructuredYieldVault {
    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error VenueNotApproved();
    error VenueAlreadyApproved();
    error ExceedsMaxDeposit();
    error InsufficientBalance();
    error InsufficientContractBalance();
    error NothingToWithdraw();
    error UnbondingNotComplete();
    error NoPendingWithdrawal();
    error NoProfitToDistribute();
    error TransferFailed();
    error SameVenue();
    error NoSharesMinted();
    error WithdrawalAlreadyPending();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount, uint256 totalDeposited);
    event WithdrawalRequested(address indexed user, uint256 principal, uint256 yield, uint256 unlockTime);
    event WithdrawalCompleted(address indexed user, uint256 principal, uint256 yield);
    event ProfitDistributed(uint256 grossProfit, uint256 fee, uint256 netProfit);
    event ProfitClaimed(address indexed user, uint256 amount);
    event FundsDeployed(address indexed venue, uint256 amount, uint256 sharesMinted);
    event FundsWithdrawnFromVenue(address indexed venue, uint256 sharesBurned, uint256 amount);
    event Rebalanced(address indexed fromVenue, address indexed toVenue, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event VenueApproved(address indexed venue, bool approved);
    event MaxDepositUpdated(uint256 oldMax, uint256 newMax);
    event ManagementFeeCollected(uint256 feeAmount);
    event StrategyParamsUpdated(uint256 leverage, uint256 hedgeRatio);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MANAGEMENT_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant UNBONDING_PERIOD = 7 days;
    uint256 public constant DEFAULT_MAX_DEPOSIT = 100_000 * 1e18;
    uint256 private constant PROFIT_PRECISION = 1e36;

    // -----------------------------------------------------------------------
    // Strategy parameters
    // -----------------------------------------------------------------------
    struct StrategyParams {
        uint256 leverage;   // target leverage (scaled by 1e18)
        uint256 hedgeRatio;  // target hedge ratio (scaled by 1e18)
    }

    // -----------------------------------------------------------------------
    // User position
    // -----------------------------------------------------------------------
    struct UserPosition {
        uint256 depositedBase;     // active principal
        uint256 accruedYield;      // yield credited but not yet claimed
        uint256 pendingPrincipal; // principal locked pending unbonding
        uint256 pendingYield;      // yield locked pending unbonding
        uint256 unlockTime;       // timestamp when pending withdrawal unlocks
        uint256 profitIndex;       // last profit index accounted for this user
    }

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------
    IERC20 public immutable baseToken;

    address public owner;
    address public operator;

    uint256 public maxDepositPerUser;
    uint256 public totalBaseDeposited;
    uint256 public totalYieldAccrued;
    uint256 public totalProfitDistributed;
    uint256 public profitIndex; // accumulated profit per deposited base token (scaled by 1e36)

    StrategyParams public strategyParams;

    mapping(address => bool) public approvedVenues;
    address[] public venueList;

    mapping(address => UserPosition) public positions;

    // Reentrancy guard
    uint256 private _locked = 1;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Unauthorized();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _baseToken, address _operator) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        baseToken = IERC20(_baseToken);
        owner = msg.sender;
        operator = _operator;
        maxDepositPerUser = DEFAULT_MAX_DEPOSIT;
        strategyParams = StrategyParams({leverage: 1e18, hedgeRatio: 1e18});

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit MaxDepositUpdated(0, maxDepositPerUser);
        emit StrategyParamsUpdated(1e18, 1e18);
    }

    // -----------------------------------------------------------------------
    // Owner functions
    // -----------------------------------------------------------------------
    function setMaxDepositPerUser(uint256 _max) external onlyOwner {
        uint256 old = maxDepositPerUser;
        maxDepositPerUser = _max;
        emit MaxDepositUpdated(old, _max);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function approveVenue(address venue) external onlyOwner {
        if (venue == address(0)) revert ZeroAddress();
        if (approvedVenues[venue]) revert VenueAlreadyApproved();
        approvedVenues[venue] = true;
        venueList.push(venue);
        emit VenueApproved(venue, true);
    }

    function revokeVenue(address venue) external onlyOwner {
        if (!approvedVenues[venue]) revert VenueNotApproved();
        approvedVenues[venue] = false;
        emit VenueApproved(venue, false);
    }

    function setStrategyParams(uint256 leverage, uint256 hedgeRatio) external onlyOwner {
        strategyParams.leverage = leverage;
        strategyParams.hedgeRatio = hedgeRatio;
        emit StrategyParamsUpdated(leverage, hedgeRatio);
    }

    // -----------------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------------
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        uint256 newTotal = pos.depositedBase + amount;
        if (newTotal > maxDepositPerUser) revert ExceedsMaxDeposit();

        // Credit pending profit before changing stake
        _creditProfit(msg.sender, pos);

        pos.depositedBase = newTotal;
        totalBaseDeposited += amount;

        bool ok = baseToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, amount, pos.depositedBase);
    }

    function requestWithdrawal(uint256 principalAmount) external nonReentrant {
        if (principalAmount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        if (principalAmount > pos.depositedBase) revert InsufficientBalance();
        if (pos.pendingPrincipal > 0 || pos.pendingYield > 0) revert WithdrawalAlreadyPending();

        // Credit outstanding profit first
        _creditProfit(msg.sender, pos);

        uint256 yieldPortion = pos.depositedBase == 0
            ? 0
            : (pos.accruedYield * principalAmount) / pos.depositedBase;

        pos.depositedBase -= principalAmount;
        pos.accruedYield -= yieldPortion;
        pos.pendingPrincipal = principalAmount;
        pos.pendingYield = yieldPortion;
        pos.unlockTime = block.timestamp + UNBONDING_PERIOD;

        totalBaseDeposited -= principalAmount;
        totalYieldAccrued -= yieldPortion;

        emit WithdrawalRequested(msg.sender, principalAmount, yieldPortion, pos.unlockTime);
    }

    function completeWithdrawal() external nonReentrant {
        UserPosition storage pos = positions[msg.sender];
        if (pos.pendingPrincipal == 0 && pos.pendingYield == 0) revert NoPendingWithdrawal();
        if (block.timestamp < pos.unlockTime) revert UnbondingNotComplete();

        uint256 principal = pos.pendingPrincipal;
        uint256 yield = pos.pendingYield;

        pos.pendingPrincipal = 0;
        pos.pendingYield = 0;
        pos.unlockTime = 0;

        uint256 totalOut = principal + yield;
        if (baseToken.balanceOf(address(this)) < totalOut) revert InsufficientContractBalance();

        bool ok = baseToken.transfer(msg.sender, totalOut);
        if (!ok) revert TransferFailed();

        emit WithdrawalCompleted(msg.sender, principal, yield);
    }

    function claimProfit() external nonReentrant {
        UserPosition storage pos = positions[msg.sender];
        _creditProfit(msg.sender, pos);

        uint256 profit = pos.accruedYield;
        if (profit == 0) revert NoProfitToDistribute();

        pos.accruedYield = 0;
        totalYieldAccrued -= profit;

        if (baseToken.balanceOf(address(this)) < profit) revert InsufficientContractBalance();

        bool ok = baseToken.transfer(msg.sender, profit);
        if (!ok) revert TransferFailed();

        emit ProfitClaimed(msg.sender, profit);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------
    function deployFunds(address venue, uint256 amount) external onlyOperator nonReentrant {
        if (!approvedVenues[venue]) revert VenueNotApproved();
        if (amount == 0) revert ZeroAmount();
        if (baseToken.balanceOf(address(this)) < amount) revert InsufficientContractBalance();

        bool ok = baseToken.approve(venue, amount);
        if (!ok) revert TransferFailed();

        uint256 shares = IYieldVenue(venue).deposit(amount);
        if (shares == 0) revert NoSharesMinted();

        emit FundsDeployed(venue, amount, shares);
    }

    function withdrawFromVenue(address venue, uint256 shareAmount) external onlyOperator nonReentrant {
        if (!approvedVenues[venue]) revert VenueNotApproved();
        if (shareAmount == 0) revert ZeroAmount();

        uint256 withdrawn = IYieldVenue(venue).withdraw(shareAmount);
        emit FundsWithdrawnFromVenue(venue, shareAmount, withdrawn);
    }

    function harvestProfit(address venue) external onlyOperator nonReentrant {
        if (!approvedVenues[venue]) revert VenueNotApproved();

        uint256 grossProfit = IYieldVenue(venue).harvest();
        if (grossProfit == 0) revert NoProfitToDistribute();

        _distributeProfit(grossProfit);
    }

    function rebalance(address fromVenue, address toVenue, uint256 shareAmount) external onlyOperator nonReentrant {
        if (!approvedVenues[fromVenue] || !approvedVenues[toVenue]) revert VenueNotApproved();
        if (fromVenue == toVenue) revert SameVenue();
        if (shareAmount == 0) revert ZeroAmount();

        uint256 withdrawn = IYieldVenue(fromVenue).withdraw(shareAmount);

        bool ok = baseToken.approve(toVenue, withdrawn);
        if (!ok) revert TransferFailed();

        uint256 shares = IYieldVenue(toVenue).deposit(withdrawn);
        if (shares == 0) revert NoSharesMinted();

        emit Rebalanced(fromVenue, toVenue, withdrawn);
    }

    function distributeManualProfit(uint256 grossProfit) external onlyOperator nonReentrant {
        if (grossProfit == 0) revert ZeroAmount();
        if (baseToken.balanceOf(address(this)) < grossProfit) revert InsufficientContractBalance();
        _distributeProfit(grossProfit);
    }

    // -----------------------------------------------------------------------
    // Internal functions
    // -----------------------------------------------------------------------
    function _distributeProfit(uint256 grossProfit) internal {
        if (totalBaseDeposited == 0) revert NoProfitToDistribute();

        uint256 fee = (grossProfit * MANAGEMENT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netProfit = grossProfit - fee;

        if (fee > 0) {
            bool ok = baseToken.transfer(owner, fee);
            if (!ok) revert TransferFailed();
            emit ManagementFeeCollected(fee);
        }

        uint256 indexIncrement = (netProfit * PROFIT_PRECISION) / totalBaseDeposited;
        profitIndex += indexIncrement;

        totalProfitDistributed += netProfit;
        totalYieldAccrued += netProfit;

        emit ProfitDistributed(grossProfit, fee, netProfit);
    }

    function _creditProfit(address user, UserPosition storage pos) internal {
        if (pos.depositedBase == 0) {
            pos.profitIndex = profitIndex;
            return;
        }

        uint256 owed = (pos.depositedBase * (profitIndex - pos.profitIndex)) / PROFIT_PRECISION;
        if (owed > 0) {
            pos.accruedYield += owed;
        }
        pos.profitIndex = profitIndex;
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------
    function pendingProfit(address user) external view returns (uint256) {
        UserPosition storage pos = positions[user];
        if (pos.depositedBase == 0) return pos.accruedYield;
        uint256 owed = (pos.depositedBase * (profitIndex - pos.profitIndex)) / PROFIT_PRECISION;
        return pos.accruedYield + owed;
    }

    function getUserPosition(address user)
        external
        view
        returns (
            uint256 depositedBase,
            uint256 accruedYield,
            uint256 pendingPrincipal,
            uint256 pendingYield,
            uint256 unlockTime
        )
    {
        UserPosition storage pos = positions[user];
        return (
            pos.depositedBase,
            pos.accruedYield,
            pos.pendingPrincipal,
            pos.pendingYield,
            pos.unlockTime
        );
    }

    function getVenueCount() external view returns (uint256) {
        return venueList.length;
    }

    function getVenueList() external view returns (address[] memory) {
        return venueList;
    }

    function contractBaseBalance() external view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }

    function venueShares(address venue) external view returns (uint256) {
        return IYieldVenue(venue).balanceOf(address(this));
    }
}
