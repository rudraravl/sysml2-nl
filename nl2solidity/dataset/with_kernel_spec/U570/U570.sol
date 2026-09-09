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

/**
 * @title UndercollateralizedCreditLines
 * @notice Establishes undercollateralized credit lines for approved borrowers.
 *         The contract itself holds no lending assets — loan capital is sourced
 *         from a designated treasury via ERC-20 allowances, and collateral is
 *         custodied by that same treasury. This contract is the accounting and
 *         access-control layer: it tracks principal, accrued interest, credit
 *         limits, collateral deposits, and default status for each borrower.
 *
 *         Interest accrues continuously at a per-borrower rate (expressed in
 *         ray, 1e27 = 100 % APR). A protocol fee (default 0.5 %) is charged on
 *         every interest payment and routed to the administrator. The maximum
 *         credit any single borrower can hold — including collateral-backed
 *         capacity — is capped at 500 000 units of the underlying token.
 */
contract UndercollateralizedCreditLines {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_CREDIT = 500_000 ether;
    uint256 public constant RAY = 1e27;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // ---------------------------------------------------------------------
    // Immutable / configurable state
    // ---------------------------------------------------------------------
    IERC20 public immutable underlying;
    address public immutable treasury;
    address public admin;
    uint256 public defaultInterestRate; // ray (1e27 == 100 %)
    uint256 public protocolFeeBps;      // bps (50 == 0.5 %)

    struct CreditLine {
        bool active;
        bool defaulted;
        uint256 creditLimit;         // maximum total debt (principal + interest)
        uint256 principal;           // outstanding borrowed principal
        uint256 accruedInterest;     // interest accrued but not yet repaid
        uint256 interestRate;        // per-borrower rate in ray
        uint256 collateralDeposited; // total collateral posted by borrower
        uint256 lastAccrualTimestamp;
    }

    mapping(address => CreditLine) internal _creditLines;

    // ---------------------------------------------------------------------
    // Reentrancy guard state
    // ---------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event CreditLineEstablished(address indexed borrower, uint256 creditLimit, uint256 interestRate);
    event CreditLimitUpdated(address indexed borrower, uint256 newCreditLimit);
    event InterestRateUpdated(address indexed borrower, uint256 newInterestRate);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, uint256 amount);
    event Borrowed(address indexed borrower, uint256 amount);
    event Repaid(address indexed borrower, uint256 principalRepaid, uint256 interestRepaid, uint256 protocolFee);
    event Defaulted(address indexed borrower, uint256 outstandingPrincipal, uint256 outstandingInterest);
    event DefaultInterestRateUpdated(uint256 newRate);
    event ProtocolFeeUpdated(uint256 newFeeBps);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error NotAdmin();
    error ZeroAddress();
    error CreditLineNotActive();
    error CreditLineAlreadyExists();
    error CreditLimitExceeded(uint256 requested, uint256 available);
    error MaxCreditExceeded(uint256 requested);
    error InsufficientCollateral();
    error InsufficientCreditLimit();
    error ZeroAmount();
    error InvalidRate();
    error InvalidFee();
    error DefaultedBorrower();
    error AlreadyDefaulted();
    error SafeTransferFromFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyActiveBorrower() {
        if (!_creditLines[msg.sender].active) revert CreditLineNotActive();
        _;
    }

    modifier onlyNonDefaulted() {
        if (_creditLines[msg.sender].defaulted) revert DefaultedBorrower();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _underlying, address _treasury, address _admin) {
        if (_underlying == address(0) || _treasury == address(0) || _admin == address(0)) {
            revert ZeroAddress();
        }
        underlying = IERC20(_underlying);
        treasury = _treasury;
        admin = _admin;
        defaultInterestRate = 0.05 * 1e27; // 5 % APR
        protocolFeeBps = 50;               // 0.5 %
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    /**
     * @notice Creates a new credit line for an approved borrower.
     * @param borrower     Recipient of the credit line.
     * @param creditLimit  Maximum debt the borrower may hold (<= MAX_CREDIT).
     * @param interestRate Per-borrower APR in ray (1e27 == 100 %). If zero,
     *                     the global default rate is used.
     */
    function createCreditLine(
        address borrower,
        uint256 creditLimit,
        uint256 interestRate
    ) external onlyAdmin {
        if (borrower == address(0)) revert ZeroAddress();
        if (_creditLines[borrower].active) revert CreditLineAlreadyExists();
        if (creditLimit > MAX_CREDIT) revert MaxCreditExceeded(creditLimit);

        uint256 rate = interestRate == 0 ? defaultInterestRate : interestRate;
        if (rate == 0) revert InvalidRate();

        _creditLines[borrower] = CreditLine({
            active: true,
            defaulted: false,
            creditLimit: creditLimit,
            principal: 0,
            accruedInterest: 0,
            interestRate: rate,
            collateralDeposited: 0,
            lastAccrualTimestamp: block.timestamp
        });

        emit CreditLineEstablished(borrower, creditLimit, rate);
    }

    /**
     * @notice Adjusts an individual borrower's interest rate (accrues first).
     */
    function setBorrowerInterestRate(address borrower, uint256 newRate) external onlyAdmin {
        CreditLine storage cl = _creditLines[borrower];
        if (!cl.active) revert CreditLineNotActive();
        if (newRate == 0) revert InvalidRate();
        _accrueInterest(cl);
        cl.interestRate = newRate;
        emit InterestRateUpdated(borrower, newRate);
    }

    /**
     * @notice Adjusts a borrower's credit limit (accrues first; new limit
     *         must cover current outstanding debt).
     */
    function setBorrowerCreditLimit(address borrower, uint256 newLimit) external onlyAdmin {
        CreditLine storage cl = _creditLines[borrower];
        if (!cl.active) revert CreditLineNotActive();
        if (newLimit > MAX_CREDIT) revert MaxCreditExceeded(newLimit);
        _accrueInterest(cl);
        uint256 currentDebt = cl.principal + cl.accruedInterest;
        if (newLimit < currentDebt) revert InsufficientCreditLimit();
        cl.creditLimit = newLimit;
        emit CreditLimitUpdated(borrower, newLimit);
    }

    /**
     * @notice Sets the global default interest rate used when no per-borrower
     *         rate is specified at creation time.
     */
    function setDefaultInterestRate(uint256 newRate) external onlyAdmin {
        if (newRate == 0) revert InvalidRate();
        defaultInterestRate = newRate;
        emit DefaultInterestRateUpdated(newRate);
    }

    /**
     * @notice Sets the protocol fee (in basis points) charged on interest
     *         repayments. Maximum 10 000 bps (100 %).
     */
    function setProtocolFeeBps(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > BPS_DENOMINATOR) revert InvalidFee();
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(newFeeBps);
    }

    /**
     * @notice Transfers administrator rights to a new address.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    /**
     * @notice Marks a borrower as in default on their obligations.
     *         Once defaulted, the borrower may still repay and deposit
     *         collateral but cannot borrow or withdraw collateral.
     */
    function declareDefault(address borrower) external onlyAdmin {
        CreditLine storage cl = _creditLines[borrower];
        if (!cl.active) revert CreditLineNotActive();
        if (cl.defaulted) revert AlreadyDefaulted();
        _accrueInterest(cl);
        cl.defaulted = true;
        emit Defaulted(borrower, cl.principal, cl.accruedInterest);
    }

    // ---------------------------------------------------------------------
    // Borrower functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposits collateral to increase borrowing capacity.
     *         Collateral is custodied by the treasury; this contract holds
     *         no assets itself.
     */
    function depositCollateral(uint256 amount) external onlyActiveBorrower nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CreditLine storage cl = _creditLines[msg.sender];
        _accrueInterest(cl);
        uint256 newLimit = cl.creditLimit + amount;
        if (newLimit > MAX_CREDIT) revert MaxCreditExceeded(newLimit);

        cl.creditLimit = newLimit;
        cl.collateralDeposited += amount;

        _safeTransferFrom(underlying, msg.sender, treasury, amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    /**
     * @notice Withdraws previously deposited collateral, provided the
     *         borrower's remaining credit limit still covers outstanding debt.
     */
    function withdrawCollateral(uint256 amount) external onlyActiveBorrower onlyNonDefaulted nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CreditLine storage cl = _creditLines[msg.sender];
        if (amount > cl.collateralDeposited) revert InsufficientCollateral();
        _accrueInterest(cl);

        uint256 currentDebt = cl.principal + cl.accruedInterest;
        if (cl.creditLimit < amount + currentDebt) revert InsufficientCreditLimit();

        cl.creditLimit -= amount;
        cl.collateralDeposited -= amount;

        _safeTransferFrom(underlying, treasury, msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Borrows funds against the established credit line. Funds are
     *         sourced from the treasury, which must have approved this
     *         contract to spend on its behalf.
     */
    function borrow(uint256 amount) external onlyActiveBorrower onlyNonDefaulted nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CreditLine storage cl = _creditLines[msg.sender];
        _accrueInterest(cl);

        uint256 avail = _availableCredit(cl);
        if (amount > avail) revert CreditLimitExceeded(amount, avail);

        cl.principal += amount;

        _safeTransferFrom(underlying, treasury, msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    /**
     * @notice Repays outstanding debt — interest first, then principal.
     *         A protocol fee (default 0.5 %) is deducted from the interest
     *         portion and routed to the admin; the remainder goes to treasury.
     */
    function repay(uint256 amount) external onlyActiveBorrower nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CreditLine storage cl = _creditLines[msg.sender];
        _accrueInterest(cl);

        uint256 totalOwed = cl.principal + cl.accruedInterest;
        if (amount > totalOwed) amount = totalOwed;

        uint256 interestRepaid;
        uint256 principalRepaid;
        if (amount <= cl.accruedInterest) {
            interestRepaid = amount;
            principalRepaid = 0;
        } else {
            interestRepaid = cl.accruedInterest;
            principalRepaid = amount - interestRepaid;
        }

        uint256 fee = (interestRepaid * protocolFeeBps) / BPS_DENOMINATOR;

        cl.accruedInterest -= interestRepaid;
        cl.principal -= principalRepaid;

        // Borrower pays `amount`; treasury receives `amount - fee`, admin receives `fee`.
        _safeTransferFrom(underlying, msg.sender, treasury, amount - fee);
        if (fee > 0) {
            _safeTransferFrom(underlying, msg.sender, admin, fee);
        }

        emit Repaid(msg.sender, principalRepaid, interestRepaid, fee);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the current available (unborrowed) credit for a borrower,
     *         accounting for accrued-but-unrealised interest.
     */
    function availableCredit(address borrower) public view returns (uint256) {
        return _availableCredit(_creditLines[borrower]);
    }

    /**
     * @notice Returns the full credit-line record for a borrower, with
     *         accrued interest updated to the current block timestamp.
     */
    function getCreditLine(address borrower)
        external
        view
        returns (
            bool active,
            bool defaulted,
            uint256 creditLimit,
            uint256 principal,
            uint256 accruedInterest,
            uint256 interestRate,
            uint256 collateralDeposited,
            uint256 lastAccrualTimestamp
        )
    {
        CreditLine storage cl = _creditLines[borrower];
        return (
            cl.active,
            cl.defaulted,
            cl.creditLimit,
            cl.principal,
            cl.accruedInterest + _calculateInterestDelta(cl),
            cl.interestRate,
            cl.collateralDeposited,
            cl.lastAccrualTimestamp
        );
    }

    /**
     * @notice Returns the total amount currently owed (principal + all
     *         accrued and pending interest).
     */
    function getTotalOwed(address borrower) external view returns (uint256) {
        CreditLine storage cl = _creditLines[borrower];
        return cl.principal + cl.accruedInterest + _calculateInterestDelta(cl);
    }

    /**
     * @notice Returns the global configuration values.
     */
    function getGlobalConfig()
        external
        view
        returns (uint256 _defaultInterestRate, uint256 _protocolFeeBps)
    {
        return (defaultInterestRate, protocolFeeBps);
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    /**
     * @dev Computes available credit = max(0, creditLimit − totalDebt).
     */
    function _availableCredit(CreditLine storage cl) internal view returns (uint256) {
        uint256 debt = cl.principal + cl.accruedInterest + _calculateInterestDelta(cl);
        if (cl.creditLimit > debt) return cl.creditLimit - debt;
        return 0;
    }

    /**
     * @dev Realises pending interest into `accruedInterest` and resets the
     *      accrual timestamp.
     */
    function _accrueInterest(CreditLine storage cl) internal {
        uint256 delta = _calculateInterestDelta(cl);
        if (delta > 0) cl.accruedInterest += delta;
        cl.lastAccrualTimestamp = block.timestamp;
    }

    /**
     * @dev Computes interest accrued since `lastAccrualTimestamp` without
     *      modifying state. Returns zero when principal is zero, the line
     *      is uninitialized, or no time has elapsed.
     */
    function _calculateInterestDelta(CreditLine storage cl) internal view returns (uint256) {
        if (cl.principal == 0 || cl.lastAccrualTimestamp == 0) return 0;
        if (block.timestamp <= cl.lastAccrualTimestamp) return 0;
        uint256 timeElapsed = block.timestamp - cl.lastAccrualTimestamp;
        // interest = principal * rate * elapsed / (SECONDS_PER_YEAR * RAY)
        return (cl.principal * cl.interestRate * timeElapsed) / (SECONDS_PER_YEAR * RAY);
    }

    /**
     * @dev Safe transferFrom wrapper that reverts with a custom error on failure.
     */
    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert SafeTransferFromFailed();
    }
}
