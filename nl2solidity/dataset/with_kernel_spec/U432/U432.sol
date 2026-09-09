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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            } else {
                revert("SafeERC20: call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: operation failed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract LendingMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MANTISSA = 1e18;
    uint256 public constant MAX_COLLATERAL_FACTOR = 0.9e18;
    uint256 public constant LIQUIDATION_FEE_MANTISSA = 0.005e18;
    uint256 public constant CLOSE_FACTOR_MANTISSA = 0.5e18;
    uint256 public constant LIQUIDATION_INCENTIVE_MANTISSA = 1.1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    IERC20 public immutable token;

    address public operator;
    address public pendingOperator;

    bool public borrowPaused;
    bool public depositPaused;

    uint256 public collateralFactorMantissa;
    uint256 public borrowRateAPR;
    uint256 public reserveFactorMantissa;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public borrowIndex;
    uint256 public accrualTimestamp;

    mapping(address => uint256) public accountDeposits;

    struct BorrowSnapshot {
        uint256 principal;
        uint256 interestIndex;
    }
    mapping(address => BorrowSnapshot) public accountBorrows;

    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);
    event Borrow(address indexed borrower, uint256 amount, uint256 accountBorrows, uint256 totalBorrows);
    event RepayBorrow(address indexed payer, address indexed borrower, uint256 amount, uint256 accountBorrows, uint256 totalBorrows);
    event LiquidateBorrow(
        address indexed liquidator,
        address indexed borrower,
        uint256 repayAmount,
        uint256 collateralSeized,
        uint256 feeAmount
    );
    event AccrueInterest(uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);

    event NewPendingOperator(address oldPendingOperator, address newPendingOperator);
    event NewOperator(address oldOperator, address newOperator);
    event NewCollateralFactor(uint256 oldFactor, uint256 newFactor);
    event NewBorrowRate(uint256 oldRate, uint256 newRate);
    event NewReserveFactor(uint256 oldFactor, uint256 newFactor);
    event BorrowPausedChanged(bool paused);
    event DepositPausedChanged(bool paused);
    event ReservesReduced(address indexed admin, uint256 reduceAmount, uint256 newTotalReserves);

    error Unauthorized();
    error BorrowPausedError();
    error DepositPausedError();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InsufficientBalance();
    error NotLiquidatable();
    error InvalidParameter();
    error ZeroAddress();
    error NoPendingOperator();
    error ZeroAmount();
    error SelfLiquidation();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notBorrowPaused() {
        if (borrowPaused) revert BorrowPausedError();
        _;
    }

    modifier notDepositPaused() {
        if (depositPaused) revert DepositPausedError();
        _;
    }

    constructor(
        address _token,
        address _operator,
        uint256 _collateralFactorMantissa,
        uint256 _borrowRateAPR,
        uint256 _reserveFactorMantissa
    ) {
        if (_token == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_collateralFactorMantissa > MAX_COLLATERAL_FACTOR) revert InvalidParameter();
        if (_reserveFactorMantissa > MANTISSA) revert InvalidParameter();
        if (_borrowRateAPR > BASIS_POINTS_DIVISOR) revert InvalidParameter();

        token = IERC20(_token);
        operator = _operator;
        collateralFactorMantissa = _collateralFactorMantissa;
        borrowRateAPR = _borrowRateAPR;
        reserveFactorMantissa = _reserveFactorMantissa;
        borrowIndex = MANTISSA;
        accrualTimestamp = block.timestamp;
    }

    function accrueInterest() public returns (uint256) {
        uint256 current = block.timestamp;
        if (current <= accrualTimestamp) return 0;
        uint256 timeDelta = current - accrualTimestamp;

        uint256 interestAccumulated =
            (totalBorrows * borrowRateAPR * timeDelta) / (SECONDS_PER_YEAR * BASIS_POINTS_DIVISOR);

        uint256 reservesAdded =
            (totalBorrows * borrowRateAPR * timeDelta * reserveFactorMantissa)
            / (SECONDS_PER_YEAR * BASIS_POINTS_DIVISOR * MANTISSA);

        uint256 indexDelta =
            (borrowIndex * borrowRateAPR * timeDelta) / (SECONDS_PER_YEAR * BASIS_POINTS_DIVISOR);

        totalBorrows += interestAccumulated;
        totalReserves += reservesAdded;
        borrowIndex += indexDelta;
        accrualTimestamp = current;

        emit AccrueInterest(interestAccumulated, borrowIndex, totalBorrows);
        return interestAccumulated;
    }

    function getCash() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function borrowBalanceStored(address account) public view returns (uint256) {
        BorrowSnapshot memory snap = accountBorrows[account];
        if (snap.principal < 1 || snap.interestIndex < 1) return 0;
        return (snap.principal * borrowIndex) / snap.interestIndex;
    }

    function maxBorrowFor(address account) public view returns (uint256) {
        return (accountDeposits[account] * collateralFactorMantissa) / MANTISSA;
    }

    function accountLiquidity(address account) public view returns (uint256) {
        uint256 debt = borrowBalanceStored(account);
        uint256 max = maxBorrowFor(account);
        if (debt >= max) return 0;
        return max - debt;
    }

    function healthFactor(address account) public view returns (uint256) {
        uint256 debt = borrowBalanceStored(account);
        if (debt < 1) return type(uint256).max;
        return (accountDeposits[account] * MANTISSA) / debt;
    }

    function getAccountData(address account)
        external
        view
        returns (uint256 depositBalance, uint256 borrowBalance, uint256 availableLiquidity)
    {
        depositBalance = accountDeposits[account];
        borrowBalance = borrowBalanceStored(account);
        availableLiquidity = accountLiquidity(account);
    }

    function deposit(uint256 amount) external notDepositPaused nonReentrant {
        if (amount < 1) revert ZeroAmount();
        accrueInterest();

        accountDeposits[msg.sender] += amount;
        totalDeposits += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        accrueInterest();

        uint256 balance = accountDeposits[msg.sender];
        if (amount > balance) revert InsufficientBalance();

        uint256 remaining = balance - amount;
        uint256 debt = borrowBalanceStored(msg.sender);
        if (debt > 0) {
            uint256 maxBorrow = (remaining * collateralFactorMantissa) / MANTISSA;
            if (debt > maxBorrow) revert InsufficientCollateral();
        }

        accountDeposits[msg.sender] = remaining;
        totalDeposits -= amount;

        token.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external notBorrowPaused nonReentrant {
        if (amount < 1) revert ZeroAmount();
        accrueInterest();

        if (amount > getCash()) revert InsufficientLiquidity();

        uint256 currentDebt = borrowBalanceStored(msg.sender);
        uint256 max = maxBorrowFor(msg.sender);
        if (currentDebt + amount > max) revert InsufficientCollateral();

        accountBorrows[msg.sender] = BorrowSnapshot({
            principal: currentDebt + amount,
            interestIndex: borrowIndex
        });
        totalBorrows += amount;

        token.safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount, currentDebt + amount, totalBorrows);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        accrueInterest();

        uint256 currentDebt = borrowBalanceStored(msg.sender);
        if (currentDebt < 1) revert InvalidParameter();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        accountBorrows[msg.sender] = BorrowSnapshot({
            principal: currentDebt - repayAmount,
            interestIndex: borrowIndex
        });
        totalBorrows -= repayAmount;

        token.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit RepayBorrow(msg.sender, msg.sender, repayAmount, currentDebt - repayAmount, totalBorrows);
    }

    function liquidate(address borrower, uint256 repayAmount) external nonReentrant {
        if (borrower == msg.sender) revert SelfLiquidation();
        if (borrower == address(0)) revert ZeroAddress();
        if (repayAmount < 1) revert ZeroAmount();
        accrueInterest();

        uint256 debt = borrowBalanceStored(borrower);
        if (debt < 1) revert NotLiquidatable();

        uint256 collateral = accountDeposits[borrower];
        if (collateral < 1) revert NotLiquidatable();

        uint256 maxBorrow = (collateral * collateralFactorMantissa) / MANTISSA;
        if (debt <= maxBorrow) revert NotLiquidatable();

        uint256 maxRepay = (debt * CLOSE_FACTOR_MANTISSA) / MANTISSA;
        uint256 actualRepay = repayAmount > maxRepay ? maxRepay : repayAmount;
        if (actualRepay > debt) actualRepay = debt;
        if (actualRepay < 1) revert ZeroAmount();

        uint256 grossSeized = (actualRepay * LIQUIDATION_INCENTIVE_MANTISSA) / MANTISSA;
        uint256 feeAmount;
        uint256 collateralSeized;
        if (grossSeized > collateral) {
            collateralSeized = collateral;
            feeAmount = (collateral * LIQUIDATION_FEE_MANTISSA) / MANTISSA;
        } else {
            collateralSeized = grossSeized;
            feeAmount =
                (actualRepay * LIQUIDATION_INCENTIVE_MANTISSA * LIQUIDATION_FEE_MANTISSA)
                / (MANTISSA * MANTISSA);
        }
        uint256 liquidatorReward = collateralSeized - feeAmount;

        accountBorrows[borrower] = BorrowSnapshot({
            principal: debt - actualRepay,
            interestIndex: borrowIndex
        });
        totalBorrows -= actualRepay;

        accountDeposits[borrower] -= collateralSeized;
        totalDeposits -= collateralSeized;

        totalReserves += feeAmount;

        token.safeTransferFrom(msg.sender, address(this), actualRepay);
        token.safeTransfer(msg.sender, liquidatorReward);

        emit LiquidateBorrow(msg.sender, borrower, actualRepay, collateralSeized, feeAmount);
    }

    function setCollateralFactor(uint256 newFactorMantissa) external onlyOperator {
        if (newFactorMantissa > MAX_COLLATERAL_FACTOR) revert InvalidParameter();
        uint256 old = collateralFactorMantissa;
        collateralFactorMantissa = newFactorMantissa;
        emit NewCollateralFactor(old, newFactorMantissa);
    }

    function setBorrowRate(uint256 newRateAPR) external onlyOperator {
        if (newRateAPR > BASIS_POINTS_DIVISOR) revert InvalidParameter();
        accrueInterest();
        uint256 old = borrowRateAPR;
        borrowRateAPR = newRateAPR;
        emit NewBorrowRate(old, newRateAPR);
    }

    function setReserveFactor(uint256 newFactorMantissa) external onlyOperator {
        if (newFactorMantissa > MANTISSA) revert InvalidParameter();
        uint256 old = reserveFactorMantissa;
        reserveFactorMantissa = newFactorMantissa;
        emit NewReserveFactor(old, newFactorMantissa);
    }

    function setBorrowPaused(bool paused) external onlyOperator {
        borrowPaused = paused;
        emit BorrowPausedChanged(paused);
    }

    function setDepositPaused(bool paused) external onlyOperator {
        depositPaused = paused;
        emit DepositPausedChanged(paused);
    }

    function setPendingOperator(address newPendingOperator) external onlyOperator {
        if (newPendingOperator == address(0)) revert ZeroAddress();
        address old = pendingOperator;
        pendingOperator = newPendingOperator;
        emit NewPendingOperator(old, newPendingOperator);
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NoPendingOperator();
        address old = operator;
        operator = pendingOperator;
        pendingOperator = address(0);
        emit NewOperator(old, operator);
    }

    function reduceReserves(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount < 1) revert ZeroAmount();
        if (amount > totalReserves) revert InsufficientBalance();
        if (amount > getCash()) revert InsufficientLiquidity();
        totalReserves -= amount;
        token.safeTransfer(to, amount);
        emit ReservesReduced(operator, amount, totalReserves);
    }
}
