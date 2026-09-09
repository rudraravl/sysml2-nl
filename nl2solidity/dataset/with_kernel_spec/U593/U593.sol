// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(
            (amount == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function forceApprove(IERC20 token, address spender, uint256 amount) internal {
        bytes memory approvalCheck = abi.encodeWithSelector(
            token.allowance.selector,
            address(this),
            spender
        );
        (bool allowanceOk, bytes memory allowanceData) = address(token).staticcall(approvalCheck);
        if (!allowanceOk || abi.decode(allowanceData, (uint256)) != 0) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
        }
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract ERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view virtual override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner_ = msg.sender;
        _transfer(owner_, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner_ = msg.sender;
        _approve(owner_, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner_ = msg.sender;
        _approve(owner_, spender, allowance(owner_, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner_ = msg.sender;
        uint256 currentAllowance = allowance(owner_, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner_, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(address(0));
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert ERC20InsufficientBalance(from, fromBalance, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }
        emit Transfer(address(0), to, amount);
        _afterTokenTransfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(address(0));

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert ERC20InsufficientBalance(from, fromBalance, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
        _afterTokenTransfer(from, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual {
        if (owner_ == address(0)) revert ERC20InvalidApprover(address(0));
        if (spender == address(0)) revert ERC20InvalidSpender(address(0));

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner_, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            unchecked {
                _approve(owner_, spender, currentAllowance - amount);
            }
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

/**
 * @title FixedRateBorrowingMarket
 * @notice A fixed-rate borrowing market where users deposit approved collateral tokens,
 *         borrow a stablecoin at a fixed 5% annual interest rate, and hold borrowing
 *         right tokens (BRT). The maximum loan-to-value for any collateral type is 75%.
 */
contract FixedRateBorrowingMarket is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice 1e18 representing 100%.
    uint256 private constant ONE = 1e18;

    /// @notice Maximum loan-to-value ratio (75%).
    uint256 public constant MAX_LTV = 0.75e18;

    /// @notice Fixed annual interest rate (5%).
    uint256 public constant FIXED_ANNUAL_RATE = 0.05e18;

    /// @notice Seconds in a 365-day year.
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    // -------------------------------------------------------------------------
    // Immutable state
    // -------------------------------------------------------------------------

    /// @notice The stablecoin that users borrow and repay.
    IERC20 public immutable stablecoin;

    // -------------------------------------------------------------------------
    // Collateral configuration
    // -------------------------------------------------------------------------

    struct CollateralConfig {
        bool approved;
        uint256 collateralFactor; // in 18 decimals, max MAX_LTV
    }

    /// @notice Per-token collateral configuration.
    mapping(address => CollateralConfig) public collateralConfigs;

    /// @notice Enumerable list of all collateral tokens ever approved.
    address[] public collateralTokenList;

    /// @notice Per-user, per-token collateral balances.
    mapping(address => mapping(address => uint256)) public collateralBalances;

    // -------------------------------------------------------------------------
    // Loan state
    // -------------------------------------------------------------------------

    /// @notice Principal + accrued interest owed by each borrower.
    mapping(address => uint256) public borrowedAmount;

    /// @notice Last timestamp at which interest was accrued for a borrower.
    mapping(address => uint256) public lastInterestAccrual;

    /// @notice Total stablecoin borrowed across all users.
    uint256 public totalBorrowed;

    // -------------------------------------------------------------------------
    // Pause flags
    // -------------------------------------------------------------------------

    bool public borrowingPaused;
    bool public depositingPaused;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount, uint256 interestPaid);
    event BorrowingRightsTransferred(address indexed from, address indexed to, uint256 amount);
    event BorrowingRightsMinted(address indexed to, uint256 amount);
    event CollateralTokenApproved(address indexed token, uint256 factor);
    event CollateralTokenRevoked(address indexed token);
    event CollateralFactorUpdated(address indexed token, uint256 newFactor);
    event BorrowingPausedSet(bool paused);
    event DepositingPausedSet(bool paused);
    event LiquidityDeposited(address indexed provider, uint256 amount);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);

    // -------------------------------------------------------------------------
    // Custom errors
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error CollateralNotApproved();
    error CollateralFactorTooHigh();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error BorrowExceedsLimit();
    error InsufficientBalance();
    error NothingToRepay();
    error BorrowingPaused();
    error DepositingPaused();

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier whenBorrowingNotPaused() {
        if (borrowingPaused) revert BorrowingPaused();
        _;
    }

    modifier whenDepositingNotPaused() {
        if (depositingPaused) revert DepositingPaused();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param _stablecoin  Address of the stablecoin ERC20 token.
     * @param _admin       Initial administrator.
     */
    constructor(address _stablecoin, address _admin)
        ERC20("Borrowing Right Token", "BRT")
        Ownable(_admin)
        ReentrancyGuard()
    {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        emit AdminTransferred(address(0), _admin);
    }

    // -------------------------------------------------------------------------
    // Admin functions
    // -------------------------------------------------------------------------

    /// @notice Approve a collateral token with a collateral factor (max LTV).
    function approveCollateralToken(address token, uint256 factor) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (factor > MAX_LTV) revert CollateralFactorTooHigh();
        if (!collateralConfigs[token].approved) {
            collateralTokenList.push(token);
        }
        collateralConfigs[token] = CollateralConfig({approved: true, collateralFactor: factor});
        emit CollateralTokenApproved(token, factor);
    }

    /// @notice Revoke a collateral token.
    function revokeCollateralToken(address token) external onlyOwner {
        if (!collateralConfigs[token].approved) revert CollateralNotApproved();
        collateralConfigs[token].approved = false;
        emit CollateralTokenRevoked(token);
    }

    /// @notice Update the collateral factor for an approved token.
    function setCollateralFactor(address token, uint256 newFactor) external onlyOwner {
        if (!collateralConfigs[token].approved) revert CollateralNotApproved();
        if (newFactor > MAX_LTV) revert CollateralFactorTooHigh();
        collateralConfigs[token].collateralFactor = newFactor;
        emit CollateralFactorUpdated(token, newFactor);
    }

    /// @notice Pause or unpause borrowing.
    function setBorrowingPaused(bool paused) external onlyOwner {
        borrowingPaused = paused;
        emit BorrowingPausedSet(paused);
    }

    /// @notice Pause or unpause depositing.
    function setDepositingPaused(bool paused) external onlyOwner {
        depositingPaused = paused;
        emit DepositingPausedSet(paused);
    }

    /// @notice Deposit stablecoin liquidity into the market.
    function depositLiquidity(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityDeposited(msg.sender, amount);
    }

    /// @notice Mint borrowing right tokens (BRT) to a user.
    function mintBorrowingRights(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
        emit BorrowingRightsMinted(to, amount);
    }

    /// @notice Transfer admin role.
    function transferAdmin(address newAdmin) external onlyOwner {
        if (newAdmin == address(0)) revert ZeroAddress();
        address old = owner();
        transferOwnership(newAdmin);
        emit AdminTransferred(old, newAdmin);
    }

    // -------------------------------------------------------------------------
    // User functions
    // -------------------------------------------------------------------------

    /// @notice Deposit an approved collateral token.
    function depositCollateral(address token, uint256 amount)
        external
        nonReentrant
        whenDepositingNotPaused
    {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfigs[token].approved) revert CollateralNotApproved();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender][token] += amount;
        emit CollateralDeposited(msg.sender, token, amount);
    }

    /// @notice Borrow stablecoins against deposited collateral.
    function borrow(uint256 amount) external nonReentrant whenBorrowingNotPaused {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(msg.sender);

        uint256 borrowingPower = _getBorrowingPower(msg.sender);
        uint256 debt = borrowedAmount[msg.sender];
        uint256 available = borrowingPower > debt ? borrowingPower - debt : 0;
        if (amount > available) revert BorrowExceedsLimit();

        if (amount > stablecoin.balanceOf(address(this))) revert InsufficientLiquidity();

        borrowedAmount[msg.sender] = debt + amount;
        totalBorrowed += amount;
        stablecoin.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    /// @notice Repay stablecoin debt (capped at total outstanding debt).
    /// @dev Follows checks-effects-interactions: state is updated before the
    ///      external token transfer to prevent reentrancy.
    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(msg.sender);

        uint256 debt = borrowedAmount[msg.sender];
        uint256 repayAmount = amount > debt ? debt : amount;
        if (repayAmount < 1) revert NothingToRepay();

        // Effects: update state before interactions
        borrowedAmount[msg.sender] = debt - repayAmount;
        totalBorrowed -= repayAmount;

        // Interactions: pull stablecoin from the borrower
        stablecoin.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repaid(msg.sender, repayAmount, 0);
    }

    /// @notice Withdraw excess collateral, provided LTV is still satisfied.
    function withdrawCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfigs[token].approved) revert CollateralNotApproved();
        if (collateralBalances[msg.sender][token] < amount) revert InsufficientBalance();

        _accrueInterest(msg.sender);

        uint256 debt = borrowedAmount[msg.sender];
        uint256 currentPower = _getBorrowingPower(msg.sender);
        uint256 factor = collateralConfigs[token].collateralFactor;
        uint256 powerReduction = (amount * factor) / ONE;
        uint256 newPower = currentPower - powerReduction;

        if (newPower < debt) revert InsufficientCollateral();

        collateralBalances[msg.sender][token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /// @notice Transfer borrowing right tokens (BRT).
    function transferBorrowingRights(address to, uint256 amount) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();
        _transfer(msg.sender, to, amount);
        emit BorrowingRightsTransferred(msg.sender, to, amount);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    /// @notice Returns the total outstanding debt (principal + pending interest).
    function getTotalDebt(address user) external view returns (uint256) {
        return _getTotalDebt(user);
    }

    /// @notice Returns the total borrowing power for a user.
    function getBorrowingPower(address user) external view returns (uint256) {
        return _getBorrowingPower(user);
    }

    /// @notice Returns the maximum additional stablecoin a user can borrow.
    function getMaxBorrowable(address user) external view returns (uint256) {
        uint256 power = _getBorrowingPower(user);
        uint256 debt = _getTotalDebt(user);
        return power > debt ? power - debt : 0;
    }

    /// @notice Returns the number of approved collateral tokens.
    function collateralTokenCount() external view returns (uint256) {
        return collateralTokenList.length;
    }

    /// @notice Returns the available stablecoin liquidity in the contract.
    function availableLiquidity() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    // -------------------------------------------------------------------------
    // Internal functions
    // -------------------------------------------------------------------------

    /// @dev Accrue interest for a user, compounding into borrowedAmount.
    ///      Uses inequality checks instead of strict equality to avoid
    ///      incorrect-equality vulnerabilities.
    function _accrueInterest(address user) internal {
        uint256 lastTs = lastInterestAccrual[user];
        // Only proceed when time has advanced (avoids elapsed == 0 check)
        if (lastTs < block.timestamp) {
            uint256 principal = borrowedAmount[user];
            // Accrue interest only when there is an established principal
            // and a valid prior accrual timestamp (avoids principal == 0
            // and lastTs == 0 strict-equality checks).
            if (principal > 0 && lastTs > 0) {
                uint256 elapsed = block.timestamp - lastTs;
                uint256 interest = (principal * FIXED_ANNUAL_RATE * elapsed) / (SECONDS_PER_YEAR * ONE);
                if (interest > 0) {
                    borrowedAmount[user] = principal + interest;
                }
            }
            lastInterestAccrual[user] = block.timestamp;
        }
    }

    /// @dev View-only total debt including pending interest.
    ///      Uses inequality checks instead of strict equality.
    function _getTotalDebt(address user) internal view returns (uint256) {
        uint256 principal = borrowedAmount[user];
        uint256 lastTs = lastInterestAccrual[user];
        // Guard with inequalities: only compute pending interest when there
        // is a positive principal, a valid last accrual timestamp, and time
        // has advanced since the last accrual.
        if (principal > 0 && lastTs > 0 && lastTs < block.timestamp) {
            uint256 elapsed = block.timestamp - lastTs;
            uint256 interest = (principal * FIXED_ANNUAL_RATE * elapsed) / (SECONDS_PER_YEAR * ONE);
            return principal + interest;
        }
        return principal;
    }

    /// @dev Sum of (collateralBalance * collateralFactor) for all approved tokens.
    function _getBorrowingPower(address user) internal view returns (uint256) {
        uint256 total = 0;
        uint256 len = collateralTokenList.length;
        for (uint256 i = 0; i < len; i++) {
            address token = collateralTokenList[i];
            CollateralConfig storage cfg = collateralConfigs[token];
            if (!cfg.approved) continue;
            uint256 bal = collateralBalances[user][token];
            if (bal > 0) {
                total += (bal * cfg.collateralFactor) / ONE;
            }
        }
        return total;
    }
}
