// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract LendingPool {
    // ---------- Custom errors ----------
    error ZeroAddress();
    error InsufficientCollateral();
    error InsufficientBalance();
    error LoanTooLarge();
    error NotOperator();
    error NotOwner();
    error NoOutstandingDebt();
    error PositionHealthy();
    error AmountZero();
    error TransferFailed();
    error ReentrantCall();

    // ---------- Constants ----------
    uint256 public constant MAX_LTV = 7500;
    uint256 public constant ORIGINATION_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant RAY = 1e27;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    // ---------- State ----------
    IERC20 public immutable collateralToken;
    IERC20 public immutable loanToken;

    address public owner;
    address public operator;

    uint256 public borrowIndex;
    uint256 public lastAccrualTimestamp;

    uint256 public borrowRateBps;
    uint256 public collateralFactorBps;
    uint256 public liquidationBonusBps;

    uint256 public totalCollateralDeposited;
    uint256 public totalDebtPrincipal;
    uint256 public totalFeesCollected;

    struct Account {
        uint256 collateral;
        uint256 principalDebt;
        uint256 lastBorrowIndex;
    }

    mapping(address => Account) public accounts;

    uint256 private _locked = 1;

    // ---------- Events ----------
    event Deposit(address indexed account, address indexed asset, uint256 amount);
    event Withdraw(address indexed account, address indexed asset, uint256 amount);
    event Borrow(address indexed account, address indexed asset, uint256 amount, uint256 fee);
    event Repay(address indexed account, address indexed asset, uint256 amount);
    event Liquidate(
        address indexed liquidator,
        address indexed account,
        address indexed asset,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event SetBorrowRate(uint256 newRateBps);
    event SetCollateralFactor(uint256 newFactorBps);
    event SetLiquidationBonus(uint256 newBonusBps);
    event OperatorUpdated(address newOperator);
    event OwnershipTransferred(address newOwner);
    event FeesWithdrawn(address to, uint256 amount);

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert AmountZero();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------- Constructor ----------
    constructor(
        address _collateralToken,
        address _loanToken,
        address _operator,
        uint256 _borrowRateBps,
        uint256 _collateralFactorBps,
        uint256 _liquidationBonusBps
    ) {
        if (_collateralToken == address(0) || _loanToken == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        if (_collateralFactorBps > MAX_LTV) revert LoanTooLarge();

        collateralToken = IERC20(_collateralToken);
        loanToken = IERC20(_loanToken);
        owner = msg.sender;
        operator = _operator;
        borrowRateBps = _borrowRateBps;
        collateralFactorBps = _collateralFactorBps;
        liquidationBonusBps = _liquidationBonusBps;

        borrowIndex = RAY;
        lastAccrualTimestamp = block.timestamp;

        emit OwnershipTransferred(msg.sender);
        emit OperatorUpdated(_operator);
        emit SetBorrowRate(_borrowRateBps);
        emit SetCollateralFactor(_collateralFactorBps);
        emit SetLiquidationBonus(_liquidationBonusBps);
    }

    // ---------- Safe transfer helpers ----------
    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    // ---------- Interest accrual ----------
    function _accrueGlobal() internal {
        uint256 elapsed = block.timestamp - lastAccrualTimestamp;
        lastAccrualTimestamp = block.timestamp;
        if (elapsed < 1) return;

        if (totalDebtPrincipal > 0) {
            // Multiply before dividing to preserve precision.
            // accruedRay = rateBps * elapsed * RAY / (BPS_DENOMINATOR * SECONDS_PER_YEAR)
            uint256 accruedRay = (borrowRateBps * elapsed * RAY) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
            // borrowIndex = borrowIndex * (RAY + accruedRay) / RAY
            borrowIndex = (borrowIndex * (RAY + accruedRay)) / RAY;
        }
    }

    function _accrueAccount(address accountAddr) internal {
        Account storage a = accounts[accountAddr];
        if (a.principalDebt < 1) {
            a.lastBorrowIndex = borrowIndex;
            return;
        }
        if (a.lastBorrowIndex < 1) {
            a.lastBorrowIndex = borrowIndex;
            return;
        }
        uint256 currentDebt = _currentDebt(accountAddr);
        a.principalDebt = currentDebt;
        a.lastBorrowIndex = borrowIndex;
    }

    function _currentDebt(address accountAddr) internal view returns (uint256) {
        Account storage a = accounts[accountAddr];
        if (a.principalDebt < 1 || a.lastBorrowIndex < 1) return a.principalDebt;
        return (a.principalDebt * borrowIndex) / a.lastBorrowIndex;
    }

    // ---------- External functions ----------

    function deposit(uint256 amount) external nonReentrant nonZeroAmount(amount) {
        _accrueGlobal();
        _accrueAccount(msg.sender);

        // Effects before interactions
        accounts[msg.sender].collateral += amount;
        totalCollateralDeposited += amount;

        _safeTransferFrom(collateralToken, msg.sender, address(this), amount);

        emit Deposit(msg.sender, address(collateralToken), amount);
    }

    function withdraw(uint256 amount) external nonReentrant nonZeroAmount(amount) {
        _accrueGlobal();
        _accrueAccount(msg.sender);

        Account storage a = accounts[msg.sender];
        if (a.collateral < amount) revert InsufficientBalance();

        // Effects before interactions
        a.collateral -= amount;
        totalCollateralDeposited -= amount;

        uint256 debt = _currentDebt(msg.sender);
        if (debt > 0) {
            uint256 maxBorrowable = (a.collateral * collateralFactorBps) / BPS_DENOMINATOR;
            if (debt > maxBorrowable) revert InsufficientCollateral();
        }

        _safeTransfer(collateralToken, msg.sender, amount);

        emit Withdraw(msg.sender, address(collateralToken), amount);
    }

    function borrow(uint256 amount) external nonReentrant nonZeroAmount(amount) {
        _accrueGlobal();
        _accrueAccount(msg.sender);

        Account storage a = accounts[msg.sender];

        uint256 fee = (amount * ORIGINATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        uint256 currentDebt = _currentDebt(msg.sender);
        uint256 newDebt = currentDebt + amount;

        uint256 maxBorrowable = (a.collateral * collateralFactorBps) / BPS_DENOMINATOR;
        if (newDebt > maxBorrowable) revert InsufficientCollateral();

        uint256 hardCap = (a.collateral * MAX_LTV) / BPS_DENOMINATOR;
        if (newDebt > hardCap) revert LoanTooLarge();

        if (loanToken.balanceOf(address(this)) < netAmount) revert InsufficientBalance();

        // Effects before interactions
        a.principalDebt = newDebt;
        a.lastBorrowIndex = borrowIndex;
        totalDebtPrincipal += amount;
        totalFeesCollected += fee;

        _safeTransfer(loanToken, msg.sender, netAmount);

        emit Borrow(msg.sender, address(loanToken), amount, fee);
    }

    function repay(uint256 amount) external nonReentrant nonZeroAmount(amount) {
        _accrueGlobal();
        _accrueAccount(msg.sender);

        Account storage a = accounts[msg.sender];
        if (a.principalDebt < 1) revert NoOutstandingDebt();

        uint256 currentDebt = _currentDebt(msg.sender);
        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        // Effects before interactions
        a.principalDebt = currentDebt - repayAmount;
        a.lastBorrowIndex = borrowIndex;
        totalDebtPrincipal = totalDebtPrincipal > repayAmount
            ? totalDebtPrincipal - repayAmount
            : 0;

        _safeTransferFrom(loanToken, msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, address(loanToken), repayAmount);
    }

    function liquidate(address accountAddr, uint256 repayAmount)
        external
        nonReentrant
        onlyOperator
        nonZeroAmount(repayAmount)
    {
        _accrueGlobal();
        _accrueAccount(accountAddr);

        Account storage a = accounts[accountAddr];
        if (a.principalDebt < 1) revert NoOutstandingDebt();

        uint256 currentDebt = _currentDebt(accountAddr);

        uint256 maxSafe = (a.collateral * collateralFactorBps) / BPS_DENOMINATOR;
        if (currentDebt <= maxSafe) revert PositionHealthy();

        uint256 actualRepay = repayAmount > currentDebt ? currentDebt : repayAmount;

        uint256 collateralSeized =
            (actualRepay * (BPS_DENOMINATOR + liquidationBonusBps)) / BPS_DENOMINATOR;
        if (collateralSeized > a.collateral) collateralSeized = a.collateral;

        // Effects before interactions
        a.principalDebt = currentDebt - actualRepay;
        a.lastBorrowIndex = borrowIndex;
        a.collateral -= collateralSeized;
        totalDebtPrincipal = totalDebtPrincipal > actualRepay
            ? totalDebtPrincipal - actualRepay
            : 0;
        totalCollateralDeposited -= collateralSeized;

        _safeTransferFrom(loanToken, msg.sender, address(this), actualRepay);
        _safeTransfer(collateralToken, msg.sender, collateralSeized);

        emit Liquidate(msg.sender, accountAddr, address(collateralToken), actualRepay, collateralSeized);
    }

    // ---------- Admin / operator functions ----------

    function setBorrowRate(uint256 newRateBps) external onlyOperator {
        _accrueGlobal();
        borrowRateBps = newRateBps;
        emit SetBorrowRate(newRateBps);
    }

    function setCollateralFactor(uint256 newFactorBps) external onlyOperator {
        if (newFactorBps > MAX_LTV) revert LoanTooLarge();
        collateralFactorBps = newFactorBps;
        emit SetCollateralFactor(newFactorBps);
    }

    function setLiquidationBonus(uint256 newBonusBps) external onlyOperator {
        liquidationBonusBps = newBonusBps;
        emit SetLiquidationBonus(newBonusBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
        emit OwnershipTransferred(newOwner);
    }

    function withdrawFees(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = totalFeesCollected;
        totalFeesCollected = 0;
        if (amount > 0) {
            _safeTransfer(loanToken, to, amount);
        }
        emit FeesWithdrawn(to, amount);
    }

    // ---------- View functions ----------

    function getAccount(address accountAddr)
        external
        view
        returns (
            uint256 collateral,
            uint256 principalDebt,
            uint256 currentDebt,
            uint256 lastBorrowIndex
        )
    {
        Account storage a = accounts[accountAddr];
        return (a.collateral, a.principalDebt, _currentDebt(accountAddr), a.lastBorrowIndex);
    }

    function maxBorrowable(address accountAddr) external view returns (uint256) {
        Account storage a = accounts[accountAddr];
        uint256 debt = _currentDebt(accountAddr);
        uint256 limit = (a.collateral * collateralFactorBps) / BPS_DENOMINATOR;
        if (debt >= limit) return 0;
        return limit - debt;
    }

    function isHealthy(address accountAddr) external view returns (bool) {
        Account storage a = accounts[accountAddr];
        uint256 debt = _currentDebt(accountAddr);
        uint256 maxSafe = (a.collateral * collateralFactorBps) / BPS_DENOMINATOR;
        return debt <= maxSafe;
    }
}
