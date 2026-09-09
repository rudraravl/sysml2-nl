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

abstract contract ReentrancyGuard {
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero owner");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero new owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract SingleTokenLendingPool is Ownable, ReentrancyGuard {
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientDeposit();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error PositionHealthy();
    error NoOutstandingDebt();
    error ExceedsMaxBorrowRate();
    error BelowMinCollateralRatio();
    error InvalidLiquidationBonus();
    error NotOperator();
    error TransferFailed();

    event Deposit(address indexed user, uint256 amount, uint256 newDeposit);
    event Withdraw(address indexed user, address indexed to, uint256 amount, uint256 newDeposit);
    event Borrow(address indexed borrower, address indexed to, uint256 amount, uint256 newDebt);
    event Repay(address indexed borrower, uint256 amount, uint256 newDebt);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 remainingDeposit
    );
    event BorrowRateUpdated(uint256 oldRate, uint256 newRate);
    event CollateralRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event LiquidationBonusUpdated(uint256 oldBonus, uint256 newBonus);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MAX_BORROW_RATE_BPS = 1500;
    uint256 public constant MIN_COLLATERAL_RATIO_BPS = 15000;
    uint256 public constant MAX_LIQUIDATION_BONUS_BPS = 2000;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    IERC20 public immutable token;

    address public operator;

    uint256 public borrowRateBps;
    uint256 public collateralRatioBps;
    uint256 public liquidationBonusBps;

    struct Position {
        uint256 deposit;
        uint256 debt;
        uint256 lastAccrualTimestamp;
    }

    mapping(address => Position) public positions;

    uint256 public totalDeposits;
    uint256 public totalDebt;
    uint256 public availableLiquidity;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(
        address token_,
        address operator_,
        uint256 borrowRateBps_,
        uint256 collateralRatioBps_,
        uint256 liquidationBonusBps_
    ) Ownable(msg.sender) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (borrowRateBps_ > MAX_BORROW_RATE_BPS) revert ExceedsMaxBorrowRate();
        if (collateralRatioBps_ < MIN_COLLATERAL_RATIO_BPS) revert BelowMinCollateralRatio();
        if (liquidationBonusBps_ > MAX_LIQUIDATION_BONUS_BPS) revert InvalidLiquidationBonus();

        token = IERC20(token_);
        operator = operator_;
        borrowRateBps = borrowRateBps_;
        collateralRatioBps = collateralRatioBps_;
        liquidationBonusBps = liquidationBonusBps_;
    }

    function setBorrowRate(uint256 newRateBps) external onlyOperator {
        if (newRateBps > MAX_BORROW_RATE_BPS) revert ExceedsMaxBorrowRate();
        emit BorrowRateUpdated(borrowRateBps, newRateBps);
        borrowRateBps = newRateBps;
    }

    function setCollateralRatio(uint256 newRatioBps) external onlyOperator {
        if (newRatioBps < MIN_COLLATERAL_RATIO_BPS) revert BelowMinCollateralRatio();
        emit CollateralRatioUpdated(collateralRatioBps, newRatioBps);
        collateralRatioBps = newRatioBps;
    }

    function setLiquidationBonus(uint256 newBonusBps) external onlyOperator {
        if (newBonusBps > MAX_LIQUIDATION_BONUS_BPS) revert InvalidLiquidationBonus();
        emit LiquidationBonusUpdated(liquidationBonusBps, newBonusBps);
        liquidationBonusBps = newBonusBps;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender];
        _accrueInterest(pos);

        pos.deposit += amount;
        totalDeposits += amount;
        availableLiquidity += amount;

        _safeTransferFrom(address(this), amount);

        emit Deposit(msg.sender, amount, pos.deposit);
    }

    function withdraw(uint256 amount, address to) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        Position storage pos = positions[msg.sender];
        _accrueInterest(pos);

        if (amount > pos.deposit) revert InsufficientDeposit();

        uint256 remainingDeposit = pos.deposit - amount;
        if (!_isCollateralSufficient(remainingDeposit, pos.debt)) {
            revert InsufficientCollateral();
        }

        pos.deposit = remainingDeposit;
        totalDeposits -= amount;
        availableLiquidity -= amount;

        _safeTransfer(to, amount);

        emit Withdraw(msg.sender, to, amount, pos.deposit);
    }

    function borrow(uint256 amount, address to) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        Position storage pos = positions[msg.sender];
        _accrueInterest(pos);

        if (amount > availableLiquidity) revert InsufficientLiquidity();

        uint256 newDebt = pos.debt + amount;
        if (!_isCollateralSufficient(pos.deposit, newDebt)) {
            revert InsufficientCollateral();
        }

        pos.debt = newDebt;
        totalDebt += amount;
        availableLiquidity -= amount;

        _safeTransfer(to, amount);

        emit Borrow(msg.sender, to, amount, pos.debt);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender];
        _accrueInterest(pos);

        if (pos.debt < 1) revert NoOutstandingDebt();

        uint256 repayAmount = amount > pos.debt ? pos.debt : amount;

        pos.debt -= repayAmount;
        totalDebt -= repayAmount;
        availableLiquidity += repayAmount;

        _safeTransferFrom(address(this), repayAmount);

        emit Repay(msg.sender, repayAmount, pos.debt);
    }

    function liquidate(address borrower, uint256 repayAmount) external nonReentrant {
        if (borrower == address(0)) revert ZeroAddress();
        if (repayAmount == 0) revert ZeroAmount();

        Position storage pos = positions[borrower];
        _accrueInterest(pos);

        if (pos.debt < 1) revert NoOutstandingDebt();
        if (_isCollateralSufficient(pos.deposit, pos.debt)) revert PositionHealthy();

        uint256 debtToRepay = repayAmount > pos.debt ? pos.debt : repayAmount;

        uint256 collateralSeized = (debtToRepay * (BPS_DENOMINATOR + liquidationBonusBps)) / BPS_DENOMINATOR;
        if (collateralSeized > pos.deposit) {
            collateralSeized = pos.deposit;
        }

        pos.debt -= debtToRepay;
        pos.deposit -= collateralSeized;
        totalDebt -= debtToRepay;
        totalDeposits -= collateralSeized;
        availableLiquidity += debtToRepay;
        availableLiquidity -= collateralSeized;

        _safeTransferFrom(address(this), debtToRepay);
        _safeTransfer(msg.sender, collateralSeized);

        emit Liquidate(msg.sender, borrower, debtToRepay, collateralSeized, pos.deposit);
    }

    function getDeposit(address user) external view returns (uint256) {
        return positions[user].deposit;
    }

    function getCurrentDebt(address user) external view returns (uint256) {
        return _previewDebt(positions[user]);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        uint256 debt = _previewDebt(pos);
        if (debt < 1) return type(uint256).max;
        return (pos.deposit * BPS_DENOMINATOR) / debt;
    }

    function isLiquidatable(address user) external view returns (bool) {
        Position storage pos = positions[user];
        uint256 debt = _previewDebt(pos);
        if (debt < 1) return false;
        return !_isCollateralSufficient(pos.deposit, debt);
    }

    function _accrueInterest(Position storage pos) internal {
        if (pos.lastAccrualTimestamp < 1) {
            pos.lastAccrualTimestamp = block.timestamp;
            return;
        }
        if (pos.debt < 1) {
            pos.lastAccrualTimestamp = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - pos.lastAccrualTimestamp;
        uint256 interest = (pos.debt * borrowRateBps * elapsed) / (SECONDS_PER_YEAR * BPS_DENOMINATOR);
        if (interest > 0) {
            pos.debt += interest;
            totalDebt += interest;
        }
        pos.lastAccrualTimestamp = block.timestamp;
    }

    function _previewDebt(Position storage pos) internal view returns (uint256) {
        if (pos.debt < 1) return 0;
        if (pos.lastAccrualTimestamp < 1) return pos.debt;
        uint256 elapsed = block.timestamp - pos.lastAccrualTimestamp;
        uint256 interest = (pos.debt * borrowRateBps * elapsed) / (SECONDS_PER_YEAR * BPS_DENOMINATOR);
        return pos.debt + interest;
    }

    function _isCollateralSufficient(uint256 depositAmount, uint256 debtAmount) internal view returns (bool) {
        if (debtAmount < 1) return true;
        return depositAmount * BPS_DENOMINATOR >= debtAmount * collateralRatioBps;
    }

    function _safeTransferFrom(address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }
}
