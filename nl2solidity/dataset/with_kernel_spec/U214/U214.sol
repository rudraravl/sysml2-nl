// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPriceOracle {
    function price() external view returns (uint256);
}

interface IStablecoin {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}

contract CDPVault is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ------------------------------ Constants ----------------------------- */
    uint256 public constant RAY = 1e27;
    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 31_536_000;
    uint256 public constant LIQUIDATION_PENALTY = 1.05e18; // 5% bonus to liquidator
    uint256 public constant MIN_DEBT = 1e18; // dust limit [stablecoin units]
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ------------------------------ Immutables ----------------------------- */
    IERC20 public immutable collateralToken;
    IStablecoin public immutable stablecoin;
    IPriceOracle public immutable oracle;
    uint256 public immutable collateralScale; // 10 ** collateralDecimals

    /* --------------------------- System Parameters ------------------------ */
    struct SystemParams {
        uint256 stabilityFeeRate; // annual rate in RAY (e.g. 5e24 = 0.5%)
        uint256 liquidationRatio; // minimum collateralization ratio in WAD (1.5e18 = 150%)
        uint256 stabilityFeeIndex; // continuously compounded accumulator index [RAY]
        uint256 lastUpdate; // timestamp of last index update
    }

    SystemParams public params;
    uint256 public totalCollateral; // total collateral deposited [collateral units]
    uint256 public totalDebt; // total outstanding debt [stablecoin units, WAD]

    /* ------------------------------- Positions ----------------------------- */
    struct Position {
        uint256 collateral; // deposited collateral [collateral units]
        uint256 debt; // outstanding debt [stablecoin units, WAD]
        uint256 lastStabilityIndex; // index at last accrual [RAY]
    }

    mapping(address => Position) public positions;

    /* -------------------------------- Events ------------------------------- */
    event Deposit(address indexed user, uint256 amount, uint256 collateralAfter);
    event Withdraw(address indexed user, uint256 amount, uint256 collateralAfter);
    event Borrow(address indexed user, uint256 amount, uint256 debtAfter);
    event Repay(address indexed user, uint256 amount, uint256 debtAfter);
    event Liquidate(
        address indexed user,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 debtRemaining
    );
    event StabilityFeeUpdated(uint256 oldRate, uint256 newRate);
    event LiquidationRatioUpdated(uint256 oldRatio, uint256 newRatio);

    /* -------------------------------- Errors ------------------------------- */
    error ZeroAmount();
    error ZeroAddress();
    error PositionUnsafe();
    error PositionSafe();
    error DebtBelowDust();
    error InsufficientCollateral();
    error InvalidLiquidationRatio();
    error InvalidStabilityFee();
    error CollateralValueZero();
    error NotOperator();

    /* ------------------------------ Constructor --------------------------- */
    constructor(
        address collateral_,
        address stablecoin_,
        address oracle_,
        address admin_
    ) {
        if (
            collateral_ == address(0) || stablecoin_ == address(0) || oracle_ == address(0) || admin_ == address(0)
        ) revert ZeroAddress();
        collateralToken = IERC20(collateral_);
        stablecoin = IStablecoin(stablecoin_);
        oracle = IPriceOracle(oracle_);
        collateralScale = uint256(10) ** uint256(IERC20Metadata(collateral_).decimals());

        // 0.5% per year stability fee expressed in RAY
        params.stabilityFeeRate = (5 * RAY) / 1000;
        // 150% minimum collateralization ratio
        params.liquidationRatio = (15 * WAD) / 10;
        params.stabilityFeeIndex = RAY;
        params.lastUpdate = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);
    }

    /* ------------------------------- Modifiers ----------------------------- */
    modifier onlyOperator() {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) revert NotOperator();
        _;
    }

    /* ----------------------- Internal: Index & Accrual -------------------- */
    function _updateIndex() internal {
        uint256 elapsed = block.timestamp - params.lastUpdate;
        if (elapsed == 0) return;
        // factor = 1 + rate * elapsed / SECONDS_PER_YEAR  (all in RAY)
        uint256 factor = RAY + (params.stabilityFeeRate * elapsed) / SECONDS_PER_YEAR;
        params.stabilityFeeIndex = (params.stabilityFeeIndex * factor) / RAY;
        params.lastUpdate = block.timestamp;
    }

    function _accrueUser(address user) internal {
        Position storage pos = positions[user];
        if (pos.debt == 0) {
            pos.lastStabilityIndex = params.stabilityFeeIndex;
            return;
        }
        if (pos.lastStabilityIndex == 0) {
            pos.lastStabilityIndex = params.stabilityFeeIndex;
            return;
        }
        uint256 newDebt = (pos.debt * params.stabilityFeeIndex) / pos.lastStabilityIndex;
        uint256 accrued = newDebt - pos.debt;
        pos.debt = newDebt;
        pos.lastStabilityIndex = params.stabilityFeeIndex;
        totalDebt += accrued;
    }

    function _collateralValue(uint256 collateralAmount) internal view returns (uint256) {
        uint256 price = oracle.price();
        if (price == 0) revert CollateralValueZero();
        return (collateralAmount * price) / collateralScale;
    }

    function _isSafe(address user) internal view returns (bool) {
        Position storage pos = positions[user];
        if (pos.debt == 0) return true;
        uint256 collateralValue = _collateralValue(pos.collateral);
        return collateralValue >= (pos.debt * params.liquidationRatio) / WAD;
    }

    /* ----------------------- User: Collateral & Debt ---------------------- */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateIndex();
        _accrueUser(msg.sender);
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        positions[msg.sender].collateral += amount;
        totalCollateral += amount;
        emit Deposit(msg.sender, amount, positions[msg.sender].collateral);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateIndex();
        _accrueUser(msg.sender);
        Position storage pos = positions[msg.sender];
        pos.debt += amount;
        if (pos.debt < MIN_DEBT) revert DebtBelowDust();
        if (!_isSafe(msg.sender)) revert PositionUnsafe();
        stablecoin.mint(msg.sender, amount);
        totalDebt += amount;
        emit Borrow(msg.sender, amount, pos.debt);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateIndex();
        _accrueUser(msg.sender);
        Position storage pos = positions[msg.sender];
        uint256 debt = pos.debt;
        if (debt == 0) revert ZeroAmount();
        uint256 repayAmount = amount > debt ? debt : amount;
        pos.debt -= repayAmount;
        totalDebt -= repayAmount;
        stablecoin.burnFrom(msg.sender, repayAmount);
        if (pos.debt > 0 && pos.debt < MIN_DEBT) revert DebtBelowDust();
        emit Repay(msg.sender, repayAmount, pos.debt);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateIndex();
        _accrueUser(msg.sender);
        Position storage pos = positions[msg.sender];
        if (amount > pos.collateral) revert InsufficientCollateral();
        pos.collateral -= amount;
        if (pos.debt > 0) {
            if (!_isSafe(msg.sender)) revert PositionUnsafe();
        }
        totalCollateral -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, pos.collateral);
    }

    /* ------------------------- Operator: Liquidation --------------------- */
    function liquidate(address user, uint256 debtToRepay) external nonReentrant onlyOperator {
        if (debtToRepay == 0) revert ZeroAmount();
        _updateIndex();
        _accrueUser(user);
        Position storage pos = positions[user];
        uint256 debt = pos.debt;
        if (debt == 0) revert ZeroAmount();
        if (_isSafe(user)) revert PositionSafe();

        uint256 actualRepay = debtToRepay > debt ? debt : debtToRepay;
        uint256 price = oracle.price();
        if (price == 0) revert CollateralValueZero();

        // collateralToSeize = actualRepay * LIQUIDATION_PENALTY * collateralScale / (WAD * price)
        uint256 collateralToSeize = (actualRepay * LIQUIDATION_PENALTY * collateralScale) / (WAD * price);
        if (collateralToSeize > pos.collateral) {
            collateralToSeize = pos.collateral;
        }

        // effects
        pos.debt -= actualRepay;
        pos.collateral -= collateralToSeize;
        totalDebt -= actualRepay;
        totalCollateral -= collateralToSeize;

        // interactions
        stablecoin.burnFrom(msg.sender, actualRepay);
        collateralToken.safeTransfer(msg.sender, collateralToSeize);

        emit Liquidate(user, msg.sender, actualRepay, collateralToSeize, pos.debt);
    }

    /* ---------------------- Operator: Parameter Admin --------------------- */
    function setStabilityFee(uint256 newRate) external onlyOperator {
        if (newRate > RAY) revert InvalidStabilityFee();
        _updateIndex();
        uint256 oldRate = params.stabilityFeeRate;
        params.stabilityFeeRate = newRate;
        emit StabilityFeeUpdated(oldRate, newRate);
    }

    function setLiquidationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < WAD) revert InvalidLiquidationRatio();
        uint256 oldRatio = params.liquidationRatio;
        params.liquidationRatio = newRatio;
        emit LiquidationRatioUpdated(oldRatio, newRatio);
    }

    /* ----------------------------- View Functions ------------------------- */
    function getCollateralValue(address user) external view returns (uint256) {
        return _collateralValue(positions[user].collateral);
    }

    function pendingDebt(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        if (pos.debt == 0 || pos.lastStabilityIndex == 0) return pos.debt;
        uint256 elapsed = block.timestamp - params.lastUpdate;
        uint256 factor = RAY + (params.stabilityFeeRate * elapsed) / SECONDS_PER_YEAR;
        uint256 currentIndex = (params.stabilityFeeIndex * factor) / RAY;
        return (pos.debt * currentIndex) / pos.lastStabilityIndex;
    }

    function isSafe(address user) external view returns (bool) {
        return _isSafe(user);
    }

    function healthFactor(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        if (pos.debt == 0) return type(uint256).max;
        uint256 collateralValue = _collateralValue(pos.collateral);
        uint256 requiredCollateral = (pos.debt * params.liquidationRatio) / WAD;
        if (requiredCollateral == 0) return type(uint256).max;
        return (collateralValue * WAD) / requiredCollateral;
    }

    function getPosition(address user)
        external
        view
        returns (uint256 collateral, uint256 debt, uint256 lastStabilityIndex)
    {
        Position storage pos = positions[user];
        return (pos.collateral, pos.debt, pos.lastStabilityIndex);
    }

    function getSystemParams()
        external
        view
        returns (uint256 stabilityFeeRate, uint256 liquidationRatio, uint256 stabilityFeeIndex, uint256 lastUpdate)
    {
        return (params.stabilityFeeRate, params.liquidationRatio, params.stabilityFeeIndex, params.lastUpdate);
    }
}
