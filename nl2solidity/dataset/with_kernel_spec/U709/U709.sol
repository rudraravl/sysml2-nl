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
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        require(ok, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        require(ok, "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        require(
            currentAllowance == 0 || amount == 0,
            "SafeERC20: approve from non-zero"
        );
        bool ok = token.approve(spender, amount);
        require(ok, "SafeERC20: approve failed");
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
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
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

interface IStablecoin is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

contract StablecoinVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LTV = 7500; // 75% in basis points
    uint256 public constant LIQUIDATION_BONUS = 500; // 5% bonus
    uint256 public constant ORIGINATION_FEE = 50; // 0.5% in basis points
    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BPS_DENOMINATOR = 10000;

    IStablecoin public immutable stablecoin;
    IPriceOracle public oracle;
    address public operator;

    struct CollateralConfig {
        bool active;
        uint256 ltv; // basis points, max 7500
        uint256 liquidationThreshold; // basis points
        uint256 interestRate; // annual rate in basis points
        uint256 totalDeposited;
        uint256 totalBorrowed;
    }

    struct Position {
        uint256 collateral;
        uint256 borrowed; // principal borrowed
        uint256 interestAccrued;
        uint256 lastInterestTs;
    }

    mapping(address => CollateralConfig) public collateralConfigs;
    mapping(address => mapping(address => Position)) public positions;

    event CollateralAdded(address indexed asset, uint256 ltv, uint256 liquidationThreshold, uint256 interestRate);
    event CollateralUpdated(address indexed asset, uint256 ltv, uint256 liquidationThreshold, uint256 interestRate);
    event CollateralDeactivated(address indexed asset);
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 fee);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Liquidate(
        address indexed liquidator,
        address indexed user,
        address indexed asset,
        uint256 collateralSeized,
        uint256 debtRepaid
    );
    event OperatorSet(address indexed operator);
    event OracleSet(address indexed oracle);

    error NotOperator();
    error CollateralNotActive();
    error CollateralAlreadyExists();
    error LtvTooHigh();
    error InvalidThreshold();
    error InsufficientCollateral();
    error PositionNotLiquidatable();
    error ZeroAmount();
    error ZeroAddress();
    error ExceedsBorrowable();
    error NothingToWithdraw();
    error NoOutstandingDebt();
    error InvalidPrice();
    error UnauthorizedFrom(address from);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stablecoin, address _oracle) Ownable(msg.sender) {
        if (_stablecoin == address(0) || _oracle == address(0)) revert ZeroAddress();
        stablecoin = IStablecoin(_stablecoin);
        oracle = IPriceOracle(_oracle);
        emit OracleSet(_oracle);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        emit OracleSet(_oracle);
    }

    function addCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 interestRate
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (collateralConfigs[asset].active) revert CollateralAlreadyExists();
        if (ltv == 0 || ltv > MAX_LTV) revert LtvTooHigh();
        if (liquidationThreshold < ltv || liquidationThreshold > BPS_DENOMINATOR) revert InvalidThreshold();
        if (interestRate > BPS_DENOMINATOR) revert InvalidThreshold();

        collateralConfigs[asset] = CollateralConfig({
            active: true,
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            interestRate: interestRate,
            totalDeposited: 0,
            totalBorrowed: 0
        });

        emit CollateralAdded(asset, ltv, liquidationThreshold, interestRate);
    }

    function updateCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 interestRate
    ) external onlyOperator {
        CollateralConfig storage cfg = collateralConfigs[asset];
        if (!cfg.active) revert CollateralNotActive();
        if (ltv == 0 || ltv > MAX_LTV) revert LtvTooHigh();
        if (liquidationThreshold < ltv || liquidationThreshold > BPS_DENOMINATOR) revert InvalidThreshold();
        if (interestRate > BPS_DENOMINATOR) revert InvalidThreshold();

        cfg.ltv = ltv;
        cfg.liquidationThreshold = liquidationThreshold;
        cfg.interestRate = interestRate;

        emit CollateralUpdated(asset, ltv, liquidationThreshold, interestRate);
    }

    function deactivateCollateral(address asset) external onlyOperator {
        if (!collateralConfigs[asset].active) revert CollateralNotActive();
        collateralConfigs[asset].active = false;
        emit CollateralDeactivated(asset);
    }

    function deposit(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[asset];
        if (!cfg.active) revert CollateralNotActive();

        Position storage pos = positions[asset][msg.sender];
        _accrueInterest(pos, cfg);

        // Effects: update state before external interactions
        pos.collateral += amount;
        cfg.totalDeposited += amount;

        // Interactions
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[asset];
        if (!cfg.active) revert CollateralNotActive();

        Position storage pos = positions[asset][msg.sender];
        _accrueInterest(pos, cfg);

        if (amount > pos.collateral) revert NothingToWithdraw();

        // Effects: update state before external interactions
        pos.collateral -= amount;
        cfg.totalDeposited -= amount;

        if (!_isPositionHealthy(asset, pos, cfg)) {
            revert InsufficientCollateral();
        }

        // Interactions
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    function borrow(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[asset];
        if (!cfg.active) revert CollateralNotActive();

        Position storage pos = positions[asset][msg.sender];
        _accrueInterest(pos, cfg);

        uint256 fee = (amount * ORIGINATION_FEE) / BPS_DENOMINATOR;
        uint256 totalDebtIncrease = amount + fee;

        // Effects: update state before external interactions
        pos.borrowed += totalDebtIncrease;
        cfg.totalBorrowed += totalDebtIncrease;

        if (!_isPositionHealthy(asset, pos, cfg)) {
            revert ExceedsBorrowable();
        }

        // Interactions
        stablecoin.mint(msg.sender, amount);

        emit Borrow(msg.sender, asset, amount, fee);
    }

    function repay(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[asset];
        if (!cfg.active) revert CollateralNotActive();

        Position storage pos = positions[asset][msg.sender];
        _accrueInterest(pos, cfg);

        uint256 totalDebt = pos.borrowed + pos.interestAccrued;
        if (totalDebt == 0) revert NoOutstandingDebt();

        uint256 repayAmount = amount > totalDebt ? totalDebt : amount;

        // Effects: update state before external interactions
        if (repayAmount <= pos.interestAccrued) {
            pos.interestAccrued -= repayAmount;
        } else {
            uint256 principalPortion = repayAmount - pos.interestAccrued;
            pos.interestAccrued = 0;
            pos.borrowed -= principalPortion;
            cfg.totalBorrowed -= principalPortion;
        }

        // Interactions
        IERC20(address(stablecoin)).safeTransferFrom(msg.sender, address(this), repayAmount);
        stablecoin.burn(address(this), repayAmount);

        emit Repay(msg.sender, asset, repayAmount);
    }

    function liquidate(address asset, address user, uint256 repayAmount) external nonReentrant onlyOperator {
        if (repayAmount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[asset];
        if (!cfg.active) revert CollateralNotActive();

        Position storage pos = positions[asset][user];
        _accrueInterest(pos, cfg);

        uint256 totalDebt = pos.borrowed + pos.interestAccrued;
        if (totalDebt == 0) revert NoOutstandingDebt();

        uint256 collateralValue = _getCollateralValue(asset, pos.collateral);
        uint256 debtValue = _getDebtValue(totalDebt);
        // Position is liquidatable when debt exceeds the liquidation threshold:
        //   debtValue * BPS_DENOMINATOR > collateralValue * liquidationThreshold
        if (debtValue * BPS_DENOMINATOR <= collateralValue * cfg.liquidationThreshold) {
            revert PositionNotLiquidatable();
        }

        uint256 actualRepay = repayAmount > totalDebt ? totalDebt : repayAmount;

        uint256 collateralPrice = oracle.getPrice(asset);
        uint256 stablecoinPrice = oracle.getPrice(address(stablecoin));
        if (collateralPrice == 0 || stablecoinPrice == 0) revert InvalidPrice();

        uint256 collateralSeized =
            (actualRepay * (BPS_DENOMINATOR + LIQUIDATION_BONUS) * stablecoinPrice) / (BPS_DENOMINATOR * collateralPrice);

        if (collateralSeized > pos.collateral) {
            collateralSeized = pos.collateral;
        }

        // Effects: update state before external interactions
        if (actualRepay <= pos.interestAccrued) {
            pos.interestAccrued -= actualRepay;
        } else {
            uint256 principalPortion = actualRepay - pos.interestAccrued;
            pos.interestAccrued = 0;
            pos.borrowed -= principalPortion;
            cfg.totalBorrowed -= principalPortion;
        }

        pos.collateral -= collateralSeized;
        cfg.totalDeposited -= collateralSeized;

        // Interactions
        IERC20(address(stablecoin)).safeTransferFrom(msg.sender, address(this), actualRepay);
        stablecoin.burn(address(this), actualRepay);
        IERC20(asset).safeTransfer(operator, collateralSeized);

        emit Liquidate(operator, user, asset, collateralSeized, actualRepay);
    }

    function _accrueInterest(Position storage pos, CollateralConfig storage cfg) internal {
        if (pos.borrowed == 0 && pos.interestAccrued == 0) {
            pos.lastInterestTs = block.timestamp;
            return;
        }

        // Use <= to avoid dangerous strict equality and handle any timestamp edge cases
        if (block.timestamp <= pos.lastInterestTs) {
            return;
        }

        uint256 elapsed = block.timestamp - pos.lastInterestTs;

        if (pos.borrowed > 0) {
            uint256 newInterest = (pos.borrowed * cfg.interestRate * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
            pos.interestAccrued += newInterest;
        }

        pos.lastInterestTs = block.timestamp;
    }

    function _isPositionHealthy(address asset, Position storage pos, CollateralConfig storage cfg)
        internal
        view
        returns (bool)
    {
        uint256 totalDebt = pos.borrowed + pos.interestAccrued;
        if (totalDebt == 0) return true;

        uint256 collateralValue = _getCollateralValue(asset, pos.collateral);
        uint256 debtValue = _getDebtValue(totalDebt);

        // Healthy when: collateralValue * ltv >= debtValue * BPS_DENOMINATOR
        // i.e. debt/collateral <= ltv / BPS_DENOMINATOR
        return collateralValue * cfg.ltv >= debtValue * BPS_DENOMINATOR;
    }

    function _getCollateralValue(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = oracle.getPrice(asset);
        return (amount * price) / PRECISION;
    }

    function _getDebtValue(uint256 debtAmount) internal view returns (uint256) {
        uint256 stablecoinPrice = oracle.getPrice(address(stablecoin));
        return (debtAmount * stablecoinPrice) / PRECISION;
    }

    function getPosition(address asset, address user)
        external
        view
        returns (uint256 collateral, uint256 borrowed, uint256 interestAccrued, uint256 lastInterestTs)
    {
        Position storage pos = positions[asset][user];
        return (pos.collateral, pos.borrowed, pos.interestAccrued, pos.lastInterestTs);
    }

    function getCollateralConfig(address asset)
        external
        view
        returns (
            bool active,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 interestRate,
            uint256 totalDeposited,
            uint256 totalBorrowed
        )
    {
        CollateralConfig storage cfg = collateralConfigs[asset];
        return (cfg.active, cfg.ltv, cfg.liquidationThreshold, cfg.interestRate, cfg.totalDeposited, cfg.totalBorrowed);
    }

    function getPendingInterest(address asset, address user) external view returns (uint256) {
        Position storage pos = positions[asset][user];
        CollateralConfig storage cfg = collateralConfigs[asset];
        if (pos.borrowed == 0) return pos.interestAccrued;

        if (block.timestamp <= pos.lastInterestTs) return pos.interestAccrued;

        uint256 elapsed = block.timestamp - pos.lastInterestTs;
        uint256 newInterest = (pos.borrowed * cfg.interestRate * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        return pos.interestAccrued + newInterest;
    }

    function isPositionLiquidatable(address asset, address user) external view returns (bool) {
        CollateralConfig storage cfg = collateralConfigs[asset];
        Position storage pos = positions[asset][user];
        uint256 totalDebt = pos.borrowed + pos.interestAccrued;
        if (totalDebt == 0) return false;

        uint256 collateralValue = _getCollateralValue(asset, pos.collateral);
        uint256 debtValue = _getDebtValue(totalDebt);
        return debtValue * BPS_DENOMINATOR > collateralValue * cfg.liquidationThreshold;
    }
}
