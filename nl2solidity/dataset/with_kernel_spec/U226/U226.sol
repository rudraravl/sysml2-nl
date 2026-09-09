// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract LendingPool {
    // -----------------------------------------------------------
    // Errors
    // -----------------------------------------------------------
    error NotOperator();
    error EnforcedPause();
    error DepositTooSmall(uint256 amount, uint256 minimum);
    error RateAboveCap(uint16 rate, uint16 cap);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error ZeroAddress();
    error AmountZero();
    error InsufficientLiquidity(uint256 available, uint256 required);
    error Reentrant();
    error TransferFailed();

    // -----------------------------------------------------------
    // Constants
    // -----------------------------------------------------------
    uint16 public constant MAX_ANNUAL_RATE_BP = 1500; // 15% cap expressed in basis points
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BP_BASE = 10000;
    uint256 public constant MIN_DEPOSIT_SCALAR = 100; // 100 whole units of the base asset

    // -----------------------------------------------------------
    // Events
    // -----------------------------------------------------------
    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event RateUpdated(uint16 oldRate, uint16 newRate);
    event PauseStateChanged(bool paused);
    event Donated(address indexed donor, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // -----------------------------------------------------------
    // Storage
    // -----------------------------------------------------------
    IERC20Minimal public immutable baseAsset;
    address public operator;
    bool public paused;
    uint256 public poolBalance; // total base assets currently held by the pool
    uint16 public annualRateBp; // current annual interest rate in basis points
    uint256 public totalPrincipal; // sum of all account principals
    uint256 public totalYieldSupply; // total outstanding yield tokens
    uint256 public immutable MIN_DEPOSIT;
    uint8 public immutable decimals;
    string public name;
    string public symbol;

    struct Account {
        uint256 principal; // deposited base assets backing this account
        uint256 yieldBalance; // issued yield tokens (transferable ERC20-like balance)
        uint256 accruedInterest; // interest accrued but not yet claimed, in base assets
        uint256 lastAccrual; // last timestamp at which interest was accrued for this account
    }

    mapping(address => Account) internal _accounts;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 private _locked = 1;

    // -----------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrant();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------
    constructor(
        address baseAsset_,
        address operator_,
        string memory name_,
        string memory symbol_,
        uint16 initialRateBp
    ) {
        if (baseAsset_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (initialRateBp > MAX_ANNUAL_RATE_BP) revert RateAboveCap(initialRateBp, MAX_ANNUAL_RATE_BP);

        baseAsset = IERC20Minimal(baseAsset_);
        operator = operator_;
        name = name_;
        symbol = symbol_;
        annualRateBp = initialRateBp;
        decimals = baseAsset.decimals();
        MIN_DEPOSIT = MIN_DEPOSIT_SCALAR * (10 ** uint256(decimals));

        emit RateUpdated(0, initialRateBp);
    }

    // -----------------------------------------------------------
    // Internal interest accounting
    // -----------------------------------------------------------
    function _accrue(address account) internal {
        Account storage a = _accounts[account];
        uint256 last = a.lastAccrual;
        if (last == 0) {
            a.lastAccrual = block.timestamp;
            return;
        }
        if (block.timestamp <= last) return;
        uint256 elapsed = block.timestamp - last;
        if (a.principal > 0) {
            a.accruedInterest += (a.principal * uint256(annualRateBp) * elapsed) / (SECONDS_PER_YEAR * BP_BASE);
        }
        a.lastAccrual = block.timestamp;
    }

    function _pending(address account) internal view returns (uint256) {
        Account storage a = _accounts[account];
        uint256 last = a.lastAccrual;
        if (last == 0) return a.accruedInterest;
        if (block.timestamp <= last) return a.accruedInterest;
        if (a.principal == 0) return a.accruedInterest;
        uint256 elapsed = block.timestamp - last;
        return a.accruedInterest + (a.principal * uint256(annualRateBp) * elapsed) / (SECONDS_PER_YEAR * BP_BASE);
    }

    // -----------------------------------------------------------
    // Deposit
    // -----------------------------------------------------------
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);

        _accrue(msg.sender);

        // Effects: update state before external interaction (CEI)
        Account storage a = _accounts[msg.sender];
        a.principal += amount;
        a.yieldBalance += amount;
        poolBalance += amount;
        totalPrincipal += amount;
        totalYieldSupply += amount;

        // Interaction: pull base assets from depositor
        if (!baseAsset.transferFrom(msg.sender, address(this), amount)) {
            // Revert state on failure
            a.principal -= amount;
            a.yieldBalance -= amount;
            poolBalance -= amount;
            totalPrincipal -= amount;
            totalYieldSupply -= amount;
            revert TransferFailed();
        }

        emit Deposit(msg.sender, amount);
        emit Transfer(address(0), msg.sender, amount);
    }

    // -----------------------------------------------------------
    // Withdraw base assets plus proportional accrued interest
    // -----------------------------------------------------------
    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();

        _accrue(msg.sender);
        Account storage a = _accounts[msg.sender];

        if (a.yieldBalance < amount) revert InsufficientBalance(a.yieldBalance, amount);
        if (a.principal < amount) revert InsufficientBalance(a.principal, amount);

        uint256 interestPortion = a.accruedInterest > 0
            ? (a.accruedInterest * amount) / a.yieldBalance
            : 0;
        uint256 payout = amount + interestPortion;

        // Check liquidity BEFORE state changes
        uint256 available = baseAsset.balanceOf(address(this));
        if (available < payout) revert InsufficientLiquidity(available, payout);

        // Effects
        a.principal -= amount;
        a.yieldBalance -= amount;
        a.accruedInterest -= interestPortion;
        totalPrincipal -= amount;
        totalYieldSupply -= amount;

        // Interaction
        if (!baseAsset.transfer(msg.sender, payout)) revert InsufficientLiquidity(0, payout);

        // Sync poolBalance with actual balance after transfer
        poolBalance = baseAsset.balanceOf(address(this));

        emit Withdrawal(msg.sender, payout);
        emit Transfer(msg.sender, address(0), amount);
    }

    // -----------------------------------------------------------
    // Yield token transfers
    // -----------------------------------------------------------
    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        _accrue(msg.sender);
        _accrue(to);

        Account storage from = _accounts[msg.sender];
        Account storage toAcc = _accounts[to];
        if (from.yieldBalance < amount) revert InsufficientBalance(from.yieldBalance, amount);

        uint256 interestShare = from.accruedInterest > 0
            ? (from.accruedInterest * amount) / from.yieldBalance
            : 0;
        from.yieldBalance -= amount;
        from.principal -= amount;
        from.accruedInterest -= interestShare;
        toAcc.yieldBalance += amount;
        toAcc.principal += amount;
        toAcc.accruedInterest += interestShare;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external nonReentrant returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(allowed, amount);

        _accrue(from);
        _accrue(to);

        Account storage fromAcc = _accounts[from];
        Account storage toAcc = _accounts[to];
        if (fromAcc.yieldBalance < amount) revert InsufficientBalance(fromAcc.yieldBalance, amount);

        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }

        uint256 interestShare = fromAcc.accruedInterest > 0
            ? (fromAcc.accruedInterest * amount) / fromAcc.yieldBalance
            : 0;
        fromAcc.yieldBalance -= amount;
        fromAcc.principal -= amount;
        fromAcc.accruedInterest -= interestShare;
        toAcc.yieldBalance += amount;
        toAcc.principal += amount;
        toAcc.accruedInterest += interestShare;

        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // -----------------------------------------------------------
    // Operator controls
    // -----------------------------------------------------------
    function setAnnualRate(uint16 rateBp) external onlyOperator {
        if (rateBp > MAX_ANNUAL_RATE_BP) revert RateAboveCap(rateBp, MAX_ANNUAL_RATE_BP);
        uint16 old = annualRateBp;
        annualRateBp = rateBp;
        emit RateUpdated(old, rateBp);
    }

    function setPaused(bool paused_) external onlyOperator {
        paused = paused_;
        emit PauseStateChanged(paused_);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // -----------------------------------------------------------
    // Yield reserve funding (anyone may donate base assets to back interest)
    // -----------------------------------------------------------
    function donate(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        // Effects first
        poolBalance += amount;
        // Interaction
        if (!baseAsset.transferFrom(msg.sender, address(this), amount)) {
            poolBalance -= amount;
            revert TransferFailed();
        }
        emit Donated(msg.sender, amount);
    }

    // -----------------------------------------------------------
    // Views
    // -----------------------------------------------------------
    function balanceOf(address account) external view returns (uint256) {
        return _accounts[account].yieldBalance;
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function totalSupply() external view returns (uint256) {
        return totalYieldSupply;
    }

    function totalAssets() external view returns (uint256) {
        return poolBalance;
    }

    function principalOf(address account) external view returns (uint256) {
        return _accounts[account].principal;
    }

    function accruedInterestOf(address account) external view returns (uint256) {
        return _pending(account);
    }

    function accountInfo(address account)
        external
        view
        returns (uint256 principal, uint256 yieldBalance, uint256 accruedInterest, uint256 lastAccrual)
    {
        Account storage a = _accounts[account];
        return (a.principal, a.yieldBalance, _pending(account), a.lastAccrual);
    }
}
