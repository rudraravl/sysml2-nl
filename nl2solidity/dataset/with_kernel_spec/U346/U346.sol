Looking at the error: the constructor declares `uint8 _decimals`, but the test harness calls it with the literal `1000`, which doesn't fit in a `uint8`. Interpreting the third constructor argument as the minimum deposit amount directly (a `uint256`) resolves the type mismatch and still satisfies the "minimum deposit" requirement (the deployer sets the threshold; the contract enforces it).

I'll also keep the rest of the proven logic from the previous candidate intact: tranche-based yield accounting with `accYieldPerShare`, `availableYield`, and a `trancheYieldReserve` that tracks tokens physically held for distribution; the 0.5% withdrawal fee; operator/owner access control; and round lifecycle management.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PrincipalProtectedYield {
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error Unauthorized();
    error NoYieldToClaim();
    error InvalidWeight();
    error DepositBelowMinimum();
    error RoundActive();
    error RoundNotActive();
    error InvalidTranche();
    error CapacityExceeded();
    error TransferFailed();

    enum TrancheType { Senior, Mezzanine, Junior }

    uint256 private constant TRANCHE_COUNT = 3;

    IERC20 public immutable stablecoin;
    uint256 public immutable minDeposit;

    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant ACC_PRECISION = 1e18;

    address public owner;
    address public operator;

    struct Tranche {
        uint256 totalPrincipal;
        uint256 availableYield;
        uint256 totalClaimedYield;
        uint256 weight;
        uint256 accYieldPerShare;
        uint256 maxCapacity;
    }

    struct UserData {
        uint256 principal;
        uint256 yieldDebt;
    }

    mapping(TrancheType => Tranche) public tranches;
    mapping(address => mapping(TrancheType => UserData)) public userDeposits;
    mapping(TrancheType => uint256) public trancheYieldReserve;

    uint256 public totalWeight;
    uint256 public currentRound;
    bool public roundActive;
    uint256 public totalFeesCollected;

    event Deposit(address indexed user, TrancheType indexed tranche, uint256 amount);
    event Withdraw(address indexed user, TrancheType indexed tranche, uint256 principal, uint256 yield, uint256 fee);
    event YieldClaimed(address indexed user, TrancheType indexed tranche, uint256 amount);
    event RoundStarted(uint256 indexed round, uint256 totalYield);
    event RoundEnded(uint256 indexed round);
    event TrancheWeightUpdated(TrancheType indexed tranche, uint256 oldWeight, uint256 newWeight);
    event TrancheCapacityUpdated(TrancheType indexed tranche, uint256 newCapacity);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesSwept(address indexed recipient, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address _stablecoin, address _operator, uint256 _minDeposit) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_minDeposit == 0) revert InvalidAmount();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        minDeposit = _minDeposit;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);

        tranches[TrancheType.Senior].weight = 50;
        tranches[TrancheType.Mezzanine].weight = 30;
        tranches[TrancheType.Junior].weight = 20;
        totalWeight = 100;

        tranches[TrancheType.Senior].maxCapacity = type(uint256).max;
        tranches[TrancheType.Mezzanine].maxCapacity = type(uint256).max;
        tranches[TrancheType.Junior].maxCapacity = type(uint256).max;
    }

    function _accrueYield(TrancheType _tranche) internal {
        Tranche storage t = tranches[_tranche];
        if (t.totalPrincipal == 0 || t.availableYield == 0) return;
        t.accYieldPerShare += (t.availableYield * ACC_PRECISION) / t.totalPrincipal;
        t.availableYield = 0;
    }

    function _pendingYield(address _user, TrancheType _tranche) internal view returns (uint256) {
        UserData storage u = userDeposits[_user][_tranche];
        Tranche storage t = tranches[_tranche];
        uint256 currAcc = t.accYieldPerShare;
        if (t.totalPrincipal > 0 && t.availableYield > 0) {
            currAcc += (t.availableYield * ACC_PRECISION) / t.totalPrincipal;
        }
        uint256 gross = (u.principal * currAcc) / ACC_PRECISION;
        if (gross <= u.yieldDebt) return 0;
        return gross - u.yieldDebt;
    }

    function _claimYield(TrancheType _tranche) internal returns (uint256) {
        uint256 pending = _pendingYield(msg.sender, _tranche);
        if (pending == 0) return 0;

        Tranche storage t = tranches[_tranche];
        UserData storage u = userDeposits[msg.sender][_tranche];

        u.yieldDebt = (u.principal * t.accYieldPerShare) / ACC_PRECISION;
        trancheYieldReserve[_tranche] -= pending;
        t.totalClaimedYield += pending;

        if (!stablecoin.transfer(msg.sender, pending)) revert TransferFailed();
        emit YieldClaimed(msg.sender, _tranche, pending);
        return pending;
    }

    function deposit(TrancheType _tranche, uint256 _amount) external {
        if (uint256(_tranche) >= TRANCHE_COUNT) revert InvalidTranche();
        if (_amount < minDeposit) revert DepositBelowMinimum();

        Tranche storage t = tranches[_tranche];
        if (t.totalPrincipal + _amount > t.maxCapacity) revert CapacityExceeded();

        _accrueYield(_tranche);
        _claimYield(_tranche);

        if (!stablecoin.transferFrom(msg.sender, address(this), _amount)) revert TransferFailed();

        UserData storage u = userDeposits[msg.sender][_tranche];
        u.principal += _amount;
        t.totalPrincipal += _amount;
        u.yieldDebt = (u.principal * t.accYieldPerShare) / ACC_PRECISION;

        emit Deposit(msg.sender, _tranche, _amount);
    }

    function withdraw(TrancheType _tranche) external {
        if (uint256(_tranche) >= TRANCHE_COUNT) revert InvalidTranche();

        _accrueYield(_tranche);

        Tranche storage t = tranches[_tranche];
        UserData storage u = userDeposits[msg.sender][_tranche];

        if (u.principal == 0) revert InsufficientBalance();

        uint256 yieldClaimed = _claimYield(_tranche);

        uint256 principal = u.principal;
        u.principal = 0;
        u.yieldDebt = 0;
        t.totalPrincipal -= principal;

        uint256 fee = (principal * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = principal - fee;
        totalFeesCollected += fee;

        if (!stablecoin.transfer(msg.sender, payout)) revert TransferFailed();

        emit Withdraw(msg.sender, _tranche, principal, yieldClaimed, fee);
    }

    function claimYield(TrancheType _tranche) external {
        if (uint256(_tranche) >= TRANCHE_COUNT) revert InvalidTranche();

        _accrueYield(_tranche);

        uint256 pending = _pendingYield(msg.sender, _tranche);
        if (pending == 0) revert NoYieldToClaim();

        Tranche storage t = tranches[_tranche];
        UserData storage u = userDeposits[msg.sender][_tranche];

        u.yieldDebt = (u.principal * t.accYieldPerShare) / ACC_PRECISION;
        trancheYieldReserve[_tranche] -= pending;
        t.totalClaimedYield += pending;

        if (!stablecoin.transfer(msg.sender, pending)) revert TransferFailed();

        emit YieldClaimed(msg.sender, _tranche, pending);
    }

    function startRound(uint256 _yieldAmount) external onlyOperator {
        if (roundActive) revert RoundActive();
        if (_yieldAmount == 0) revert InvalidAmount();
        if (totalWeight == 0) revert InvalidWeight();

        if (!stablecoin.transferFrom(msg.sender, address(this), _yieldAmount)) revert TransferFailed();

        for (uint256 i = 0; i < TRANCHE_COUNT; i++) {
            Tranche storage t = tranches[TrancheType(i)];
            uint256 share = (_yieldAmount * t.weight) / totalWeight;
            if (share > 0) {
                t.availableYield += share;
                trancheYieldReserve[TrancheType(i)] += share;
            }
        }

        currentRound += 1;
        roundActive = true;
        emit RoundStarted(currentRound, _yieldAmount);
    }

    function endRound() external onlyOperator {
        if (!roundActive) revert RoundNotActive();
        roundActive = false;
        emit RoundEnded(currentRound);
    }

    function setTrancheWeight(TrancheType _tranche, uint256 _newWeight) external onlyOperator {
        if (uint256(_tranche) >= TRANCHE_COUNT) revert InvalidTranche();
        Tranche storage t = tranches[_tranche];
        uint256 oldWeight = t.weight;
        totalWeight = totalWeight - oldWeight + _newWeight;
        t.weight = _newWeight;
        emit TrancheWeightUpdated(_tranche, oldWeight, _newWeight);
    }

    function setTrancheCapacity(TrancheType _tranche, uint256 _newCapacity) external onlyOperator {
        if (uint256(_tranche) >= TRANCHE_COUNT) revert InvalidTranche();
        if (tranches[_tranche].totalPrincipal > _newCapacity) revert CapacityExceeded();
        tranches[_tranche].maxCapacity = _newCapacity;
        emit TrancheCapacityUpdated(_tranche, _newCapacity);
    }

    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function sweepFees(address _recipient, uint256 _amount) external onlyOwner {
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();
        if (_amount > totalFeesCollected) revert InsufficientBalance();
        totalFeesCollected -= _amount;
        if (!stablecoin.transfer(_recipient, _amount)) revert TransferFailed();
        emit FeesSwept(_recipient, _amount);
    }

    function pendingYield(address _user, TrancheType _tranche) external view returns (uint256) {
        return _pendingYield(_user, _tranche);
    }

    function getUserDeposit(address _user, TrancheType _tranche)
        external
        view
        returns (uint256 principal, uint256 yieldDebt)
    {
        UserData storage u = userDeposits[_user][_tranche];
        return (u.principal, u.yieldDebt);
    }

    function getTrancheInfo(TrancheType _tranche)
        external
        view
        returns (
            uint256 totalPrincipal,
            uint256 availableYield,
            uint256 totalClaimedYield,
            uint256 weight,
            uint256 accYieldPerShare,
            uint256 maxCapacity
        )
    {
        Tranche storage t = tranches[_tranche];
        return (
            t.totalPrincipal,
            t.availableYield,
            t.totalClaimedYield,
            t.weight,
            t.accYieldPerShare,
            t.maxCapacity
        );
    }

    function trancheAvailableForDistribution(TrancheType _tranche) external view returns (uint256) {
        return trancheYieldReserve[_tranche];
    }
}
