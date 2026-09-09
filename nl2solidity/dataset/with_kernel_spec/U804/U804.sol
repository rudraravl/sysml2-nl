// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SingleAssetLendingPool
 * @notice A single-asset lending pool where depositors supply liquidity and
 *         approved borrowers draw loans against pre-configured credit lines.
 *         Interest accrues continuously based on an owner-set annual rate
 *         (capped at 25% APR). A borrower's outstanding principal plus accrued
 *         interest may not exceed 110% of their approved credit line.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SingleAssetLendingPool {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant RATE_PRECISION = 1e18;          // 1e18 = 100%
    uint256 public constant MAX_ANNUAL_RATE = 0.25e18;       // 25% APR
    uint256 public constant CREDIT_LINE_RATIO = 110;         // 110%
    uint256 public constant CREDIT_LINE_DIVISOR = 100;

    // ---------------------------------------------------------------------
    // Immutable state
    // ---------------------------------------------------------------------
    IERC20 public immutable token;

    // ---------------------------------------------------------------------
    // Ownership
    // ---------------------------------------------------------------------
    address public owner;

    // ---------------------------------------------------------------------
    // Global state
    // ---------------------------------------------------------------------
    uint256 public totalDeposits;
    uint256 public totalBorrowed;
    uint256 public interestRate; // annual rate in RATE_PRECISION (1e18 = 100%)
    bool public paused;

    struct Borrower {
        uint256 principal;
        uint256 accruedInterest;
        uint256 lastAccrualTime;
        uint256 creditLine;
    }

    mapping(address => uint256) public deposits;
    mapping(address => Borrower) public borrowers;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);
    event Borrow(address indexed account, uint256 amount);
    event Repayment(address indexed account, uint256 amount);
    event CreditLineUpdated(address indexed borrower, uint256 newCreditLine);
    event InterestRateUpdated(uint256 newRate);
    event PauseUpdated(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error PausedError();
    error InterestRateTooHigh();
    error ExceedsCreditLine();
    error InsufficientLiquidity();
    error InsufficientDeposit();
    error NoOutstandingDebt();
    error NotOwner();
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _token, address _owner) {
        if (_token == address(0) || _owner == address(0)) revert ZeroAddress();
        token = IERC20(_token);
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    // ---------------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit tokens into the pool to supply liquidity.
     * @param amount Amount of tokens to deposit.
     */
    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _safeTransferFrom(msg.sender, address(this), amount);

        deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw previously deposited tokens.
     * @param amount Amount of tokens to withdraw.
     */
    function withdraw(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (deposits[msg.sender] < amount) revert InsufficientDeposit();

        uint256 available = totalDeposits - totalBorrowed;
        if (available < amount) revert InsufficientLiquidity();

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        _safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Borrow tokens against the caller's approved credit line.
     * @param amount Amount of tokens to borrow.
     */
    function borrow(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);
        Borrower storage b = borrowers[msg.sender];

        uint256 currentDebt = b.principal + b.accruedInterest;
        uint256 newDebt = currentDebt + amount;

        if (b.creditLine == 0) revert ExceedsCreditLine();
        if (newDebt > (b.creditLine * CREDIT_LINE_RATIO) / CREDIT_LINE_DIVISOR) {
            revert ExceedsCreditLine();
        }

        uint256 available = totalDeposits - totalBorrowed;
        if (available < amount) revert InsufficientLiquidity();

        b.principal += amount;
        totalBorrowed += amount;

        _safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    /**
     * @notice Repay outstanding debt. Excess input is refunded to the caller.
     * @param amount Amount of tokens to repay (capped at outstanding debt).
     */
    function repay(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);
        Borrower storage b = borrowers[msg.sender];

        uint256 totalDebt = b.principal + b.accruedInterest;
        if (totalDebt == 0) revert NoOutstandingDebt();

        uint256 repayAmount = amount > totalDebt ? totalDebt : amount;

        if (repayAmount <= b.accruedInterest) {
            b.accruedInterest -= repayAmount;
        } else {
            b.principal -= (repayAmount - b.accruedInterest);
            b.accruedInterest = 0;
        }

        totalBorrowed -= repayAmount;

        _safeTransferFrom(msg.sender, address(this), repayAmount);

        if (amount > repayAmount) {
            _safeTransfer(msg.sender, amount - repayAmount);
        }

        emit Repayment(msg.sender, repayAmount);
    }

    // ---------------------------------------------------------------------
    // Owner-only configuration
    // ---------------------------------------------------------------------

    /**
     * @notice Set the annual interest rate (in 1e18 precision).
     * @param newRate New annual interest rate, must not exceed 25%.
     */
    function setInterestRate(uint256 newRate) external onlyOwner {
        if (newRate > MAX_ANNUAL_RATE) revert InterestRateTooHigh();
        interestRate = newRate;
        emit InterestRateUpdated(newRate);
    }

    /**
     * @notice Set the credit line for a borrower.
     * @param borrower Address of the borrower.
     * @param creditLine New credit limit in underlying token units.
     */
    function setCreditLine(address borrower, uint256 creditLine) external onlyOwner {
        if (borrower == address(0)) revert ZeroAddress();
        _accrueInterest(borrower);
        borrowers[borrower].creditLine = creditLine;
        emit CreditLineUpdated(borrower, creditLine);
    }

    /**
     * @notice Pause or unpause deposit, withdraw, borrow, and repay operations.
     * @param _paused New paused state.
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseUpdated(_paused);
    }

    /**
     * @notice Transfer ownership to a new address.
     * @param newOwner Address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    // ---------------------------------------------------------------------
    // Public view helpers
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the current outstanding debt (principal + accrued interest)
     *         for a borrower, including interest accrued up to now.
     * @param borrower Address of the borrower.
     */
    function getDebt(address borrower) external view returns (uint256) {
        Borrower storage b = borrowers[borrower];
        uint256 debt = b.principal + b.accruedInterest;
        if (block.timestamp <= b.lastAccrualTime) {
            return debt;
        }
        uint256 timeElapsed = block.timestamp - b.lastAccrualTime;
        uint256 interest = (b.principal * interestRate * timeElapsed) / (SECONDS_PER_YEAR * RATE_PRECISION);
        return debt + interest;
    }

    /**
     * @notice Returns the total tokens currently available for withdrawal.
     */
    function availableLiquidity() external view returns (uint256) {
        return totalDeposits - totalBorrowed;
    }

    // ---------------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------------

    /**
     * @dev Accrues interest for a borrower since their last accrual timestamp.
     *      Uses inequality checks to avoid dangerous strict-equality on
     *      timestamps and balances.
     */
    function _accrueInterest(address borrower) internal {
        Borrower storage b = borrowers[borrower];

        if (block.timestamp <= b.lastAccrualTime) {
            return;
        }

        uint256 timeElapsed = block.timestamp - b.lastAccrualTime;
        uint256 interest = (b.principal * interestRate * timeElapsed) / (SECONDS_PER_YEAR * RATE_PRECISION);

        if (interest > 0) {
            b.accruedInterest += interest;
            totalBorrowed += interest;
        }

        b.lastAccrualTime = block.timestamp;
    }

    /**
     * @dev Safe transfer wrapper that reverts on failure.
     */
    function _safeTransfer(address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert SafeTransferFailed();
    }

    /**
     * @dev Safe transferFrom wrapper that reverts on failure.
     */
    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert SafeTransferFromFailed();
    }
}
