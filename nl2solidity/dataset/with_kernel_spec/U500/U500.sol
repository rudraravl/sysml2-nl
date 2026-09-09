// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StableLendingPool {
    /* ---------- Constants ---------- */
    uint256 public constant MAX_DEPOSIT_PER_TX = 100_000 * 1e18;
    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MIN_INTEREST_RATE = 0.0001e18; // 0.01% APR floor
    uint256 public constant MAX_INTEREST_RATE = 0.50e18;   // 50% APR ceiling
    uint256 public constant PRECISION = 1e18;

    /* ---------- Custom Errors ---------- */
    error ZeroAddress();
    error DepositPaused();
    error ExceedsMaxDeposit(uint256 amount, uint256 max);
    error InsufficientBalance(uint256 available, uint256 requested);
    error InsufficientPoolLiquidity(uint256 available, uint256 requested);
    error InterestRateOutOfRange(uint256 rate, uint256 min, uint256 max);
    error LengthMismatch();
    error ZeroAmount();
    error NoPendingInterest();
    error Unauthorized();
    error SafeTransferFailed();
    error ReentrantCall();

    /* ---------- Events ---------- */
    event Deposited(address indexed lender, uint256 amount, uint256 newPrincipal);
    event Withdrawn(address indexed lender, uint256 amount, uint256 newPrincipal);
    event InterestClaimed(address indexed lender, uint256 grossInterest, uint256 fee, uint256 net);
    event InterestRateUpdated(uint256 oldRate, uint256 newRate, address indexed operator);
    event DepositsPaused(address indexed operator);
    event DepositsUnpaused(address indexed operator);
    event BulkDisbursed(address indexed borrower, uint256 amount, address indexed operator);
    event Repaid(address indexed caller, uint256 amount);
    event FeesSwept(address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /* ---------- Storage ---------- */
    IERC20 public immutable stablecoin;

    address public owner;
    address public operator;
    address public feeRecipient;

    uint256 public interestRate;       // annualized rate in 1e18 precision
    uint256 public poolBalance;        // sum of all lender principal
    uint256 public outstandingLoans;   // total disbursed to borrowers (not yet repaid)
    uint256 public accumulatedFees;    // fees reserved for the fee recipient

    bool public depositsPaused;

    uint256 private _reentrancyGuard;

    struct Lender {
        uint256 principal;          // deposited amount
        uint256 accruedInterest;    // gross interest accrued but not yet claimed
        uint256 pendingWithdrawal;  // in-flight withdrawal amount (CEI accounting)
        uint256 lastAccrual;        // last timestamp interest was accrued
    }

    mapping(address => Lender) public lenders;

    constructor(
        address _stablecoin,
        address _owner,
        address _operator,
        address _feeRecipient,
        uint256 _initialInterestRate
    ) {
        if (
            _stablecoin == address(0) ||
            _owner == address(0) ||
            _operator == address(0) ||
            _feeRecipient == address(0)
        ) revert ZeroAddress();
        if (_initialInterestRate < MIN_INTEREST_RATE || _initialInterestRate > MAX_INTEREST_RATE) {
            revert InterestRateOutOfRange(_initialInterestRate, MIN_INTEREST_RATE, MAX_INTEREST_RATE);
        }
        stablecoin = IERC20(_stablecoin);
        owner = _owner;
        operator = _operator;
        feeRecipient = _feeRecipient;
        interestRate = _initialInterestRate;
        emit InterestRateUpdated(0, _initialInterestRate, msg.sender);
        emit OwnershipTransferred(address(0), _owner);
    }

    /* ---------- Modifiers ---------- */
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier notPaused() {
        if (depositsPaused) revert DepositPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyGuard == 1) revert ReentrantCall();
        _reentrancyGuard = 1;
        _;
        _reentrancyGuard = 0;
    }

    /* ---------- Internal Safe Transfers ---------- */
    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool success;
        bytes memory data;
        (success, data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!success) revert SafeTransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert SafeTransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool success;
        bytes memory data;
        (success, data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!success) revert SafeTransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert SafeTransferFailed();
    }

    /* ---------- Internal ---------- */
    function _accrueInterest(address _lender) internal {
        Lender storage l = lenders[_lender];
        if (l.lastAccrual == 0) {
            l.lastAccrual = block.timestamp;
            return;
        }
        if (block.timestamp <= l.lastAccrual) return;
        if (l.principal == 0) {
            l.lastAccrual = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - l.lastAccrual;
        uint256 gross = (l.principal * interestRate * elapsed) / (SECONDS_PER_YEAR * PRECISION);
        l.accruedInterest += gross;
        l.lastAccrual = block.timestamp;
    }

    function _availableLiquidity() internal view returns (uint256) {
        uint256 bal = stablecoin.balanceOf(address(this));
        if (bal <= accumulatedFees) return 0;
        return bal - accumulatedFees;
    }

    /* ---------- Lender functions ---------- */
    function deposit(uint256 amount) external notPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_DEPOSIT_PER_TX) revert ExceedsMaxDeposit(amount, MAX_DEPOSIT_PER_TX);
        _accrueInterest(msg.sender);
        // Effects before interactions
        lenders[msg.sender].principal += amount;
        poolBalance += amount;
        // Interactions
        _safeTransferFrom(address(stablecoin), msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount, lenders[msg.sender].principal);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(msg.sender);
        Lender storage l = lenders[msg.sender];
        if (l.principal < amount) revert InsufficientBalance(l.principal, amount);
        uint256 liq = _availableLiquidity();
        if (liq < amount) revert InsufficientPoolLiquidity(liq, amount);
        // Effects before interactions
        l.principal -= amount;
        poolBalance -= amount;
        l.pendingWithdrawal = amount;
        // Interactions
        _safeTransfer(address(stablecoin), msg.sender, amount);
        // Clear in-flight flag after successful transfer (guard prevents reentry)
        l.pendingWithdrawal = 0;
        emit Withdrawn(msg.sender, amount, l.principal);
    }

    function claimInterest() external nonReentrant {
        _accrueInterest(msg.sender);
        Lender storage l = lenders[msg.sender];
        uint256 gross = l.accruedInterest;
        if (gross == 0) revert NoPendingInterest();
        uint256 fee = (gross * FEE_BPS) / BPS_DENOMINATOR;
        uint256 net = gross - fee;
        // Checks
        uint256 liq = _availableLiquidity();
        if (liq < net) revert InsufficientPoolLiquidity(liq, net);
        // Effects before interactions
        l.accruedInterest = 0;
        accumulatedFees += fee;
        // Interactions
        _safeTransfer(address(stablecoin), msg.sender, net);
        emit InterestClaimed(msg.sender, gross, fee, net);
    }

    function pendingInterest(address _lender) external view returns (uint256) {
        Lender storage l = lenders[_lender];
        if (l.principal == 0 || block.timestamp <= l.lastAccrual) {
            return l.accruedInterest;
        }
        uint256 elapsed = block.timestamp - l.lastAccrual;
        uint256 gross = (l.principal * interestRate * elapsed) / (SECONDS_PER_YEAR * PRECISION);
        return l.accruedInterest + gross;
    }

    /* ---------- Operator functions ---------- */
    function setInterestRate(uint256 newRate) external onlyOperator {
        if (newRate < MIN_INTEREST_RATE || newRate > MAX_INTEREST_RATE) {
            revert InterestRateOutOfRange(newRate, MIN_INTEREST_RATE, MAX_INTEREST_RATE);
        }
        uint256 old = interestRate;
        interestRate = newRate;
        emit InterestRateUpdated(old, newRate, msg.sender);
    }

    function pauseDeposits() external onlyOperator {
        depositsPaused = true;
        emit DepositsPaused(msg.sender);
    }

    function unpauseDeposits() external onlyOperator {
        depositsPaused = false;
        emit DepositsUnpaused(msg.sender);
    }

    function bulkDisburse(address[] calldata borrowers, uint256[] calldata amounts) external onlyOperator nonReentrant {
        if (borrowers.length != amounts.length) revert LengthMismatch();
        // Compute total and validate all inputs up front (no balance read inside the transfer loop)
        uint256 totalDisbursed = 0;
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            totalDisbursed += amounts[i];
        }
        // Single liquidity check against the total — balance read once, before any external call
        uint256 liq = _availableLiquidity();
        if (liq < totalDisbursed) revert InsufficientPoolLiquidity(liq, totalDisbursed);
        // Effects before interactions
        outstandingLoans += totalDisbursed;
        // Interactions — no state reads or writes after external calls
        for (uint256 i = 0; i < borrowers.length; i++) {
            _safeTransfer(address(stablecoin), borrowers[i], amounts[i]);
            emit BulkDisbursed(borrowers[i], amounts[i], msg.sender);
        }
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        // Effects before interactions
        if (outstandingLoans < amount) {
            outstandingLoans = 0;
        } else {
            outstandingLoans -= amount;
        }
        // Interactions
        _safeTransferFrom(address(stablecoin), msg.sender, address(this), amount);
        emit Repaid(msg.sender, amount);
    }

    function sweepFees() external onlyOwner nonReentrant {
        uint256 fees = accumulatedFees;
        if (fees == 0) revert ZeroAmount();
        // Effects before interactions
        accumulatedFees = 0;
        // Interactions
        _safeTransfer(address(stablecoin), feeRecipient, fees);
        emit FeesSwept(feeRecipient, fees);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(old, newRecipient);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /* ---------- Views ---------- */
    function getLender(address _lender)
        external
        view
        returns (uint256 principal, uint256 accruedInterest, uint256 pendingWithdrawal, uint256 lastAccrual)
    {
        Lender storage l = lenders[_lender];
        return (l.principal, l.accruedInterest, l.pendingWithdrawal, l.lastAccrual);
    }

    function totalPoolAssets() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    function availableLiquidity() external view returns (uint256) {
        return _availableLiquidity();
    }
}
