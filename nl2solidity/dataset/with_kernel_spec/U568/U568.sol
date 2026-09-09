// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CreditDelegation
 * @notice A ledger-based credit delegation contract. Lenders delegate unused
 *         borrowing capacity to borrowers. The contract records delegations,
 *         loans, and repayments but does not custody any assets directly.
 */
contract CreditDelegation {
    /* ------------------------------------------------------------------ */
    /*                              Errors                                */
    /* ------------------------------------------------------------------ */

    error ZeroAddress();
    error ZeroAmount();
    error ExceedsMaxDelegation(uint256 requested, uint256 maximum);
    error InsufficientAvailableCredit(uint256 requested, uint256 available);
    error InsufficientActiveLoan(uint256 requested, uint256 outstanding);
    error FeeTooHigh(uint256 requested, uint256 maximum);
    error DelegationsPaused();
    error NoActiveDelegation();
    error NotOwner();
    error EnforcedPause();
    error ExpectedPause();
    error ReentrancyGuardReentrantCall();
    error InvalidOwner();

    /* ------------------------------------------------------------------ */
    /*                              Events                                 */
    /* ------------------------------------------------------------------ */

    event CreditDelegated(
        address indexed lender,
        address indexed borrower,
        uint256 amount,
        uint256 fee
    );

    event LoanOriginated(
        address indexed borrower,
        address indexed lender,
        uint256 principal
    );

    event LoanRepaid(
        address indexed borrower,
        address indexed lender,
        uint256 amount,
        uint256 remainingPrincipal
    );

    event DelegationWithdrawn(
        address indexed lender,
        address indexed borrower,
        uint256 amount,
        uint256 remainingDelegation
    );

    event DelegationFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MaxDelegationUpdated(uint256 oldMax, uint256 newMax);
    event DelegationsPaused();
    event DelegationsUnpaused();
    event ContractPaused(address account);
    event ContractUnpaused(address account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /* ------------------------------------------------------------------ */
    /*                            Constants                               */
    /* ------------------------------------------------------------------ */

    /// @notice Hard cap on the delegation fee in basis points (10%).
    uint256 public constant MAX_FEE_BPS = 1000;

    /// @notice Hard cap on the maximum delegation amount per lender-borrower pair.
    uint256 public constant ABSOLUTE_MAX_DELEGATION = 100_000 * 1e18;

    /// @notice Basis points denominator (100% = 10,000 bps).
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /* ------------------------------------------------------------------ */
    /*                            State variables                         */
    /* ------------------------------------------------------------------ */

    /// @notice Contract owner.
    address public owner;

    /// @notice Whether the contract is paused.
    bool public isPaused;

    /// @notice Delegation fee in basis points applied to each new delegation.
    uint256 public delegationFeeBps;

    /// @notice Maximum delegation amount a single lender may grant to a single borrower.
    uint256 public maxDelegationAmount;

    /// @notice Whether new delegations are paused.
    bool public delegationsPaused;

    /**
     * @notice Total credit a lender has delegated to a borrower.
     *         lender => borrower => amount
     */
    mapping(address => mapping(address => uint256)) public delegatedCredit;

    /**
     * @notice Outstanding principal a borrower owes to a lender.
     *         borrower => lender => principal
     */
    mapping(address => mapping(address => uint256)) public activeLoans;

    /**
     * @notice Cumulative fees owed by lenders (recorded, not custodied).
     *         lender => feesAccrued
     */
    mapping(address => uint256) public accruedFees;

    /**
     * @notice Total delegated credit outstanding for a lender across all borrowers.
     */
    mapping(address => uint256) public totalDelegatedByLender;

    /**
     * @notice Total outstanding principal for a borrower across all lenders.
     */
    mapping(address => uint256) public totalBorrowedByBorrower;

    /**
     * @dev Reentrancy guard status. True while a protected function is executing.
     */
    uint256 private _status;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    /* ------------------------------------------------------------------ */
    /*                            Modifiers                                */
    /* ------------------------------------------------------------------ */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (isPaused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!isPaused) revert ExpectedPause();
        _;
    }

    modifier whenDelegationsNotPaused() {
        if (delegationsPaused) revert DelegationsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /* ------------------------------------------------------------------ */
    /*                            Constructor                             */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Deploys the contract with a default 0.5% delegation fee and a
     *         maximum delegation amount of 100,000 units per lender-borrower pair.
     */
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        delegationFeeBps = 50; // 0.5%
        maxDelegationAmount = 100_000 * 1e18;

        _status = _NOT_ENTERED;
    }

    /* ------------------------------------------------------------------ */
    /*                         Lender functions                           */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Delegate borrowing capacity to a borrower. A delegation fee is
     *         recorded against the lender (not custodied by this contract).
     * @param borrower The address receiving the delegated credit.
     * @param amount   The amount of credit to delegate.
     */
    function delegateCredit(address borrower, uint256 amount)
        external
        whenNotPaused
        whenDelegationsNotPaused
        nonReentrant
    {
        if (borrower == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > maxDelegationAmount) {
            revert ExceedsMaxDelegation(amount, maxDelegationAmount);
        }

        uint256 fee = (amount * delegationFeeBps) / BPS_DENOMINATOR;

        delegatedCredit[msg.sender][borrower] += amount;
        totalDelegatedByLender[msg.sender] += amount;
        accruedFees[msg.sender] += fee;

        emit CreditDelegated(msg.sender, borrower, amount, fee);
    }

    /**
     * @notice Withdraw previously delegated, unused credit from a borrower.
     *         The withdrawn amount cannot exceed the available (unused) credit.
     * @param borrower The borrower whose delegation is being reduced.
     * @param amount   The amount of delegation to withdraw.
     */
    function withdrawDelegation(address borrower, uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        if (borrower == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 currentDelegation = delegatedCredit[msg.sender][borrower];
        if (currentDelegation == 0) revert NoActiveDelegation();

        uint256 outstandingLoan = activeLoans[borrower][msg.sender];
        uint256 available = currentDelegation - outstandingLoan;
        if (amount > available) revert InsufficientAvailableCredit(amount, available);

        delegatedCredit[msg.sender][borrower] = currentDelegation - amount;
        totalDelegatedByLender[msg.sender] -= amount;

        emit DelegationWithdrawn(
            msg.sender,
            borrower,
            amount,
            delegatedCredit[msg.sender][borrower]
        );
    }

    /* ------------------------------------------------------------------ */
    /*                         Borrower functions                         */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Borrow against credit delegated by a lender. The contract records
     *         the loan but does not transfer any assets.
     * @param lender The lender whose delegated credit is being drawn down.
     * @param amount The principal to borrow.
     */
    function borrow(address lender, uint256 amount) external whenNotPaused nonReentrant {
        if (lender == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 delegation = delegatedCredit[lender][msg.sender];
        uint256 outstanding = activeLoans[msg.sender][lender];
        uint256 available = delegation - outstanding;
        if (amount > available) revert InsufficientAvailableCredit(amount, available);

        activeLoans[msg.sender][lender] = outstanding + amount;
        totalBorrowedByBorrower[msg.sender] += amount;

        emit LoanOriginated(msg.sender, lender, amount);
    }

    /**
     * @notice Repay part or all of an outstanding loan to a lender. The contract
     *         records the repayment but does not transfer any assets.
     * @param lender The lender to whom the repayment is credited.
     * @param amount The amount to repay.
     */
    function repay(address lender, uint256 amount) external whenNotPaused nonReentrant {
        if (lender == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 outstanding = activeLoans[msg.sender][lender];
        if (amount > outstanding) revert InsufficientActiveLoan(amount, outstanding);

        uint256 remaining = outstanding - amount;
        activeLoans[msg.sender][lender] = remaining;
        totalBorrowedByBorrower[msg.sender] -= amount;

        emit LoanRepaid(msg.sender, lender, amount, remaining);
    }

    /* ------------------------------------------------------------------ */
    /*                          View functions                            */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Returns the available (unused) credit a borrower has from a lender.
     */
    function availableCredit(address lender, address borrower)
        external
        view
        returns (uint256)
    {
        return delegatedCredit[lender][borrower] - activeLoans[borrower][lender];
    }

    /**
     * @notice Returns the outstanding principal a borrower owes a lender.
     */
    function outstandingLoan(address borrower, address lender)
        external
        view
        returns (uint256)
    {
        return activeLoans[borrower][lender];
    }

    /* ------------------------------------------------------------------ */
    /*                       Owner-only configuration                     */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Set the delegation fee in basis points.
     * @param newFeeBps The new fee in basis points (max 1000 = 10%).
     */
    function setDelegationFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        uint256 old = delegationFeeBps;
        delegationFeeBps = newFeeBps;
        emit DelegationFeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Set the maximum delegation amount per lender-borrower pair.
     * @param newMax The new maximum delegation amount (capped at 100,000 units).
     */
    function setMaxDelegation(uint256 newMax) external onlyOwner {
        if (newMax > ABSOLUTE_MAX_DELEGATION) {
            revert ExceedsMaxDelegation(newMax, ABSOLUTE_MAX_DELEGATION);
        }
        uint256 old = maxDelegationAmount;
        maxDelegationAmount = newMax;
        emit MaxDelegationUpdated(old, newMax);
    }

    /**
     * @notice Pause new delegations. Existing delegations and loans remain actionable.
     */
    function pauseDelegations() external onlyOwner {
        if (delegationsPaused) revert DelegationsPaused();
        delegationsPaused = true;
        emit DelegationsPaused();
    }

    /**
     * @notice Unpause new delegations.
     */
    function unpauseDelegations() external onlyOwner {
        if (!delegationsPaused) revert DelegationsPaused();
        delegationsPaused = false;
        emit DelegationsUnpaused();
    }

    /**
     * @notice Pause the contract. Disables delegation, borrowing, and repayment.
     */
    function pauseContract() external onlyOwner whenNotPaused {
        isPaused = true;
        emit ContractPaused(msg.sender);
    }

    /**
     * @notice Unpause the contract.
     */
    function unpauseContract() external onlyOwner whenPaused {
        isPaused = false;
        emit ContractUnpaused(msg.sender);
    }

    /**
     * @notice Transfer ownership of the contract to a new account.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidOwner();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /**
     * @notice Renounce ownership. The contract will no longer have an owner.
     */
    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }
}
