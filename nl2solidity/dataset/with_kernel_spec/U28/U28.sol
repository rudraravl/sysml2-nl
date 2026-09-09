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
        require(address(token).code.length > 0, "SafeERC20: call to non-contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(address(token).code.length > 0, "SafeERC20: call to non-contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
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

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

contract FixedRateLendingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Constants ---
    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    // --- Immutables ---
    IERC20 public immutable collateralToken;
    IERC20 public immutable stablecoinToken;
    IOracle public immutable oracle;

    // --- Global Config ---
    uint256 public fixedInterestRate; // APR in 1e18 precision (0.005e18 = 0.5%)
    uint256 public minCollateralizationRatio; // in 1e18 precision (1.5e18 = 150%)

    // --- Totals ---
    uint256 public totalCollateral;
    uint256 public totalBorrowed;

    // --- Access Control ---
    address public admin;
    address public operator;

    // --- Position ---
    struct Position {
        uint256 collateral;
        uint256 principal;
        uint256 interestAccrued;
        uint256 lastAccrualTime;
        uint256 interestRate; // Fixed at loan origination
    }

    mapping(address => Position) public positions;

    // --- Events ---
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event LoanBorrowed(address indexed user, uint256 amount, uint256 interestRate);
    event LoanRepaid(address indexed user, uint256 principalRepaid, uint256 interestRepaid);
    event InterestRateUpdated(uint256 oldRate, uint256 newRate);
    event MinCollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    // --- Errors ---
    error ZeroAmount();
    error InvalidAddress();
    error InsufficientCollateral();
    error InsufficientCollateralForWithdrawal();
    error PositionNotSafe();
    error NoDebtToRepay();
    error InvalidParameter();
    error Unauthorized();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(
        address _collateralToken,
        address _stablecoinToken,
        address _oracle,
        address _admin
    ) {
        if (
            _collateralToken == address(0) ||
            _stablecoinToken == address(0) ||
            _oracle == address(0) ||
            _admin == address(0)
        ) {
            revert InvalidAddress();
        }

        collateralToken = IERC20(_collateralToken);
        stablecoinToken = IERC20(_stablecoinToken);
        oracle = IOracle(_oracle);

        fixedInterestRate = 0.005e18; // 0.5% APR
        minCollateralizationRatio = 1.5e18; // 150%

        admin = _admin;
        operator = _admin;
    }

    // --- Internal ---

    function _accrueInterest(address user) internal {
        Position storage pos = positions[user];
        if (pos.lastAccrualTime == 0) {
            pos.lastAccrualTime = block.timestamp;
            return;
        }
        if (pos.principal > 0) {
            uint256 timeElapsed = block.timestamp - pos.lastAccrualTime;
            if (timeElapsed > 0) {
                uint256 interest =
                    (pos.principal * pos.interestRate * timeElapsed) / (SECONDS_PER_YEAR * PRECISION);
                pos.interestAccrued += interest;
            }
        }
        pos.lastAccrualTime = block.timestamp;
    }

    function _pendingInterest(address user) internal view returns (uint256) {
        Position storage pos = positions[user];
        if (pos.principal == 0 || pos.lastAccrualTime == 0) return 0;
        uint256 timeElapsed = block.timestamp - pos.lastAccrualTime;
        if (timeElapsed == 0) return 0;
        return (pos.principal * pos.interestRate * timeElapsed) / (SECONDS_PER_YEAR * PRECISION);
    }

    function _isPositionSafe(address user) internal view returns (bool) {
        Position storage pos = positions[user];
        uint256 debt = pos.principal + pos.interestAccrued + _pendingInterest(user);
        if (debt == 0) return true;

        uint256 collateralValue =
            (pos.collateral * oracle.getPrice(address(collateralToken))) / PRECISION;
        uint256 requiredCollateralValue = (debt * minCollateralizationRatio) / PRECISION;

        return collateralValue >= requiredCollateralValue;
    }

    // --- Public ---

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        Position storage pos = positions[msg.sender];
        pos.collateral += amount;
        totalCollateral += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];

        if (pos.principal == 0) {
            pos.interestRate = fixedInterestRate;
        }

        pos.principal += amount;
        totalBorrowed += amount;

        if (!_isPositionSafe(msg.sender)) revert InsufficientCollateral();

        stablecoinToken.safeTransfer(msg.sender, amount);

        emit LoanBorrowed(msg.sender, amount, pos.interestRate);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];
        uint256 totalDebt = pos.principal + pos.interestAccrued;
        if (totalDebt == 0) revert NoDebtToRepay();

        uint256 repayAmount = amount > totalDebt ? totalDebt : amount;

        stablecoinToken.safeTransferFrom(msg.sender, address(this), repayAmount);

        uint256 interestRepaid =
            repayAmount < pos.interestAccrued ? repayAmount : pos.interestAccrued;
        uint256 principalRepaid = repayAmount - interestRepaid;

        pos.interestAccrued -= interestRepaid;
        pos.principal -= principalRepaid;
        totalBorrowed -= principalRepaid;

        emit LoanRepaid(msg.sender, principalRepaid, interestRepaid);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];
        if (amount > pos.collateral) revert InsufficientCollateralForWithdrawal();

        pos.collateral -= amount;
        totalCollateral -= amount;

        if (!_isPositionSafe(msg.sender)) revert PositionNotSafe();

        collateralToken.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    // --- Operator ---

    function setFixedInterestRate(uint256 newRate) external onlyOperator {
        if (newRate > PRECISION) revert InvalidParameter();
        uint256 oldRate = fixedInterestRate;
        fixedInterestRate = newRate;
        emit InterestRateUpdated(oldRate, newRate);
    }

    function setMinCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < PRECISION) revert InvalidParameter();
        uint256 oldRatio = minCollateralizationRatio;
        minCollateralizationRatio = newRatio;
        emit MinCollateralizationRatioUpdated(oldRatio, newRatio);
    }

    // --- Admin ---

    function setOperator(address newOperator) external onlyAdmin {
        if (newOperator == address(0)) revert InvalidAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(oldAdmin, newAdmin);
    }

    // --- Views ---

    function getCurrentDebt(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        return pos.principal + pos.interestAccrued + _pendingInterest(user);
    }

    function getCollateralizationRatio(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        uint256 debt = pos.principal + pos.interestAccrued + _pendingInterest(user);
        if (debt == 0) return type(uint256).max;

        uint256 collateralValue =
            (pos.collateral * oracle.getPrice(address(collateralToken))) / PRECISION;
        if (collateralValue == 0) return 0;
        return (collateralValue * PRECISION) / debt;
    }

    function getPosition(address user)
        external
        view
        returns (
            uint256 collateral,
            uint256 principal,
            uint256 interestAccrued,
            uint256 lastAccrualTime,
            uint256 interestRate
        )
    {
        Position storage pos = positions[user];
        return (
            pos.collateral,
            pos.principal,
            pos.interestAccrued,
            pos.lastAccrualTime,
            pos.interestRate
        );
    }
}
