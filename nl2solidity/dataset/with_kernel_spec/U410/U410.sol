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

interface IPriceOracle {
    /// @notice Returns the USD price of a token with 18 decimals precision.
    function getPrice(address token) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(_callOptionalReturn(token.transfer(to, value)), "SafeERC20: transfer failed");
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(_callOptionalReturn(token.transferFrom(from, to, value)), "SafeERC20: transferFrom failed");
    }
    function _callOptionalReturn(bool ok) internal pure returns (bool) {
        return ok;
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

contract InstitutionalLending is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_LOAN_TERM = 180 days;
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 1.2e18; // 120%
    uint256 public constant LIQUIDATION_BONUS = 0.05e18; // 5%
    uint256 public constant MAX_INTEREST_RATE = 1e18; // 100% APY cap (exclusive)

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable collateralToken;
    IERC20 public immutable loanToken;
    IPriceOracle public immutable oracle;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public operator;
    bool public paused;

    uint256 public interestRate; // annual rate in WAD (e.g. 0.05e18 = 5%)
    uint256 public totalLiquidity; // available loan tokens held by contract
    uint256 public totalCollateral; // total collateral tokens held
    uint256 public totalOutstandingDebt; // sum of principal + accrued interest

    struct LoanRequest {
        uint256 principal;
        uint256 termSeconds;
        uint256 requestedAt;
        bool active;
    }

    struct Position {
        uint256 collateral; // collateral tokens deposited
        uint256 principal; // outstanding loan principal
        uint256 accruedInterest; // interest accrued since origination
        uint256 lastAccrualTime; // last time interest was accrued
        uint256 dueTime; // timestamp at which loan is due
        bool active; // whether an active loan exists
    }

    mapping(address => Position) public positions;
    mapping(address => LoanRequest) public loanRequests;
    mapping(address => uint256) public liquiditySuppliers;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LiquiditySupplied(address indexed supplier, uint256 amount);
    event LiquidityWithdrawn(address indexed supplier, uint256 amount);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, uint256 amount);
    event LoanRequested(address indexed borrower, uint256 principal, uint256 termSeconds);
    event LoanRequestCancelled(address indexed borrower);
    event LoanOriginated(address indexed borrower, uint256 principal, uint256 dueTime);
    event LoanRepaid(
        address indexed borrower,
        uint256 principalPaid,
        uint256 interestPaid,
        bool fullyRepaid
    );
    event CollateralLiquidated(
        address indexed borrower,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event InterestRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error NotOperator();
    error ContractPaused();
    error ZeroAddress();
    error AmountZero();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InsufficientSupplierBalance();
    error NoActiveLoan();
    error ActiveLoanExists();
    error PendingRequestExists();
    error NoPendingRequest();
    error LoanTermExceeded();
    error ExcessWithdrawalTooLarge();
    error PositionSafe();
    error AmountExceedsDebt();
    error RateTooHigh();
    error RateZero();
    error SameRate();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _collateralToken,
        address _loanToken,
        address _oracle,
        address _operator,
        uint256 _initialInterestRate
    ) {
        if (
            _collateralToken == address(0) ||
            _loanToken == address(0) ||
            _oracle == address(0) ||
            _operator == address(0)
        ) revert ZeroAddress();
        if (_initialInterestRate == 0) revert RateZero();
        if (_initialInterestRate >= MAX_INTEREST_RATE) revert RateTooHigh();

        collateralToken = IERC20(_collateralToken);
        loanToken = IERC20(_loanToken);
        oracle = IPriceOracle(_oracle);
        operator = _operator;
        owner = msg.sender;
        interestRate = _initialInterestRate;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit InterestRateUpdated(0, _initialInterestRate);
    }

    /*//////////////////////////////////////////////////////////////
                         LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function supplyLiquidity(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();
        liquiditySuppliers[msg.sender] += amount;
        totalLiquidity += amount;
        loanToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquiditySupplied(msg.sender, amount);
    }

    function withdrawLiquidity(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();
        if (amount > liquiditySuppliers[msg.sender]) revert InsufficientSupplierBalance();
        if (amount > totalLiquidity) revert InsufficientLiquidity();

        liquiditySuppliers[msg.sender] -= amount;
        totalLiquidity -= amount;
        loanToken.safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function depositCollateral(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();
        positions[msg.sender].collateral += amount;
        totalCollateral += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawExcessCollateral(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();
        Position storage p = positions[msg.sender];
        if (amount > p.collateral) revert InsufficientCollateral();

        if (p.active) {
            _accrueInterest(p);
            uint256 totalDebt = p.principal + p.accruedInterest;
            if (totalDebt > 0) {
                uint256 remainingCollateral = p.collateral - amount;
                if (!_isCollateralSufficient(remainingCollateral, totalDebt)) {
                    revert ExcessWithdrawalTooLarge();
                }
            }
        }

        p.collateral -= amount;
        totalCollateral -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          LOAN REQUEST & APPROVAL
    //////////////////////////////////////////////////////////////*/

    function requestLoan(uint256 principal, uint256 termSeconds) external whenNotPaused nonReentrant {
        if (principal == 0) revert AmountZero();
        if (termSeconds == 0 || termSeconds > MAX_LOAN_TERM) revert LoanTermExceeded();
        if (positions[msg.sender].collateral == 0) revert InsufficientCollateral();
        if (positions[msg.sender].active) revert ActiveLoanExists();
        if (loanRequests[msg.sender].active) revert PendingRequestExists();

        loanRequests[msg.sender] = LoanRequest({
            principal: principal,
            termSeconds: termSeconds,
            requestedAt: block.timestamp,
            active: true
        });

        emit LoanRequested(msg.sender, principal, termSeconds);
    }

    function cancelLoanRequest() external whenNotPaused nonReentrant {
        if (!loanRequests[msg.sender].active) revert NoPendingRequest();
        loanRequests[msg.sender].active = false;
        emit LoanRequestCancelled(msg.sender);
    }

    function approveLoan(address borrower) external onlyOperator whenNotPaused nonReentrant {
        if (borrower == address(0)) revert ZeroAddress();
        LoanRequest storage req = loanRequests[borrower];
        if (!req.active) revert NoPendingRequest();

        Position storage p = positions[borrower];
        if (p.active) revert ActiveLoanExists();
        if (req.principal > totalLiquidity) revert InsufficientLiquidity();

        if (!_isCollateralSufficient(p.collateral, req.principal)) {
            revert InsufficientCollateral();
        }

        req.active = false;
        p.principal = req.principal;
        p.accruedInterest = 0;
        p.lastAccrualTime = block.timestamp;
        p.dueTime = block.timestamp + req.termSeconds;
        p.active = true;

        totalLiquidity -= req.principal;
        totalOutstandingDebt += req.principal;

        loanToken.safeTransfer(borrower, req.principal);

        emit LoanOriginated(borrower, req.principal, p.dueTime);
    }

    function operatorCancelLoanRequest(address borrower) external onlyOperator whenNotPaused {
        if (borrower == address(0)) revert ZeroAddress();
        if (!loanRequests[borrower].active) revert NoPendingRequest();
        loanRequests[borrower].active = false;
        emit LoanRequestCancelled(borrower);
    }

    /*//////////////////////////////////////////////////////////////
                              LOAN REPAYMENT
    //////////////////////////////////////////////////////////////*/

    function repayLoan(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AmountZero();
        Position storage p = positions[msg.sender];
        if (!p.active) revert NoActiveLoan();

        _accrueInterest(p);
        uint256 totalDebt = p.principal + p.accruedInterest;
        uint256 toRepay = amount > totalDebt ? totalDebt : amount;

        uint256 interestPortion = toRepay > p.accruedInterest ? p.accruedInterest : toRepay;
        uint256 principalPortion = toRepay - interestPortion;

        p.accruedInterest -= interestPortion;
        p.principal -= principalPortion;
        totalOutstandingDebt -= toRepay;
        totalLiquidity += toRepay;

        bool fullyRepaid = (p.principal == 0 && p.accruedInterest == 0);
        if (fullyRepaid) {
            p.active = false;
            p.dueTime = 0;
            p.lastAccrualTime = 0;
        }

        loanToken.safeTransferFrom(msg.sender, address(this), toRepay);

        if (amount > toRepay) {
            loanToken.safeTransfer(msg.sender, amount - toRepay);
        }

        emit LoanRepaid(msg.sender, principalPortion, interestPortion, fullyRepaid);
    }

    /*//////////////////////////////////////////////////////////////
                              LIQUIDATION
    //////////////////////////////////////////////////////////////*/

    function liquidate(address borrower, uint256 repayAmount) external whenNotPaused nonReentrant {
        if (borrower == address(0)) revert ZeroAddress();
        if (repayAmount == 0) revert AmountZero();

        Position storage p = positions[borrower];
        if (!p.active) revert NoActiveLoan();

        _accrueInterest(p);
        uint256 totalDebt = p.principal + p.accruedInterest;
        if (repayAmount > totalDebt) revert AmountExceedsDebt();

        bool overdue = block.timestamp > p.dueTime;
        if (!overdue) {
            if (_isCollateralSufficient(p.collateral, totalDebt)) {
                revert PositionSafe();
            }
        }

        uint256 debtValueUsd = repayAmount * _loanPrice() / WAD;
        uint256 seizeValueUsd = (debtValueUsd * (WAD + LIQUIDATION_BONUS)) / WAD;
        uint256 collateralToSeize = (seizeValueUsd * WAD) / _collateralPrice();
        if (collateralToSeize > p.collateral) {
            collateralToSeize = p.collateral;
        }

        uint256 interestPortion = repayAmount > p.accruedInterest ? p.accruedInterest : repayAmount;
        uint256 principalPortion = repayAmount - interestPortion;

        p.accruedInterest -= interestPortion;
        p.principal -= principalPortion;
        p.collateral -= collateralToSeize;

        totalOutstandingDebt -= repayAmount;
        totalCollateral -= collateralToSeize;
        totalLiquidity += repayAmount;

        bool fullyRepaid = (p.principal == 0 && p.accruedInterest == 0);
        if (fullyRepaid) {
            p.active = false;
            p.dueTime = 0;
            p.lastAccrualTime = 0;
        }

        loanToken.safeTransferFrom(msg.sender, address(this), repayAmount);
        collateralToken.safeTransfer(msg.sender, collateralToSeize);

        emit CollateralLiquidated(borrower, msg.sender, repayAmount, collateralToSeize);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN / CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function setInterestRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert RateZero();
        if (newRate >= MAX_INTEREST_RATE) revert RateTooHigh();
        if (newRate == interestRate) revert SameRate();
        emit InterestRateUpdated(interestRate, newRate);
        interestRate = newRate;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPosition(address borrower) external view returns (Position memory) {
        return positions[borrower];
    }

    function getLoanRequest(address borrower) external view returns (LoanRequest memory) {
        return loanRequests[borrower];
    }

    function outstandingDebt(address borrower) external view returns (uint256) {
        Position storage p = positions[borrower];
        if (!p.active) return 0;
        uint256 elapsed = block.timestamp - p.lastAccrualTime;
        uint256 additional = (p.principal * interestRate * elapsed) /
            (SECONDS_PER_YEAR * WAD);
        return p.principal + p.accruedInterest + additional;
    }

    function collateralizationRatio(address borrower) external view returns (uint256) {
        Position storage p = positions[borrower];
        if (!p.active) return type(uint256).max;
        uint256 debt = this.outstandingDebt(borrower);
        if (debt == 0) return type(uint256).max;
        uint256 collateralValue = (p.collateral * _collateralPrice()) / WAD;
        uint256 debtValue = (debt * _loanPrice()) / WAD;
        if (debtValue == 0) return type(uint256).max;
        return (collateralValue * WAD) / debtValue;
    }

    function isPositionSafe(address borrower) external view returns (bool) {
        Position storage p = positions[borrower];
        if (!p.active) return true;
        uint256 debt = this.outstandingDebt(borrower);
        if (debt == 0) return true;
        return _isCollateralSufficient(p.collateral, debt) && block.timestamp <= p.dueTime;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _loanPrice() internal view returns (uint256) {
        return oracle.getPrice(address(loanToken));
    }

    function _collateralPrice() internal view returns (uint256) {
        return oracle.getPrice(address(collateralToken));
    }

    function _isCollateralSufficient(uint256 collateralAmount, uint256 debtAmount)
        internal
        view
        returns (bool)
    {
        if (debtAmount == 0) return true;
        uint256 collateralValueUsd = (collateralAmount * _collateralPrice()) / WAD;
        uint256 requiredValueUsd = (debtAmount * _loanPrice() * MIN_COLLATERALIZATION_RATIO) /
            (WAD * WAD);
        return collateralValueUsd >= requiredValueUsd;
    }

    function _accrueInterest(Position storage p) internal {
        if (p.lastAccrualTime == 0) return;
        uint256 elapsed = block.timestamp - p.lastAccrualTime;
        if (elapsed == 0) return;
        uint256 additional = (p.principal * interestRate * elapsed) /
            (SECONDS_PER_YEAR * WAD);
        if (additional > 0) {
            p.accruedInterest += additional;
            totalOutstandingDebt += additional;
        }
        p.lastAccrualTime = block.timestamp;
    }
}
