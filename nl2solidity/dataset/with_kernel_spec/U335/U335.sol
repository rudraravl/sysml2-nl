// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: approve failed"
        );
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero owner");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Ownable: zero new owner");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

contract MoneyMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant INDEX_PRECISION = 1e18;
    uint256 public constant MAX_LTV = 80;
    uint256 public constant LIQUIDATION_FEE = 5;
    uint256 public constant FEE_DENOMINATOR = 1000;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error ZeroAddress();
    error TokenNotSupported();
    error DepositPaused();
    error BorrowPaused();
    error InsufficientDeposit();
    error InsufficientLiquidity();
    error Insolvent();
    error BorrowerSolvent();
    error NoDebt();
    error NotOperator();
    error FactorTooHigh();
    error ExceedsReserves();
    error AlreadySupported();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Borrow(address indexed user, address indexed token, uint256 amount);
    event Repay(address indexed user, address indexed token, uint256 amount);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        address indexed debtToken,
        address collateralToken,
        uint256 repaid,
        uint256 seized
    );
    event TokenAdded(address indexed token, uint8 decimals, uint256 baseRate, uint256 slope, uint256 reserveFactor);
    event RateModelUpdated(address indexed token, uint256 baseRate, uint256 slope);
    event PauseUpdated(address indexed token, bool depositPaused, bool borrowPaused);
    event ReserveFactorUpdated(address indexed token, uint256 factor);
    event ReservesClaimed(address indexed token, address indexed to, uint256 amount);
    event OracleUpdated(address indexed newOracle);
    event OperatorUpdated(address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              DATA TYPES
    //////////////////////////////////////////////////////////////*/

    struct Pool {
        bool active;
        bool depositPaused;
        bool borrowPaused;
        uint8 decimals;
        uint256 totalDepositShares;
        uint256 totalBorrows;
        uint256 cash;
        uint256 borrowIndex;
        uint256 depositIndex;
        uint256 lastAccrual;
        uint256 baseRatePerYear;
        uint256 slopePerYear;
        uint256 reserveFactor;
        uint256 totalReserves;
    }

    struct Account {
        uint256 depositShares;
        uint256 borrowPrincipal;
        uint256 borrowIndex;
    }

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => Pool) internal _pools;
    mapping(address => mapping(address => Account)) internal _accounts;
    address[] public supportedTokens;
    mapping(address => bool) public isSupported;

    IPriceOracle public oracle;
    address public operator;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier poolActive(address token) {
        if (!isSupported[token]) revert TokenNotSupported();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _oracle, address _operator) Ownable(msg.sender) {
        if (_oracle == address(0) || _operator == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        operator = _operator;
        emit OracleUpdated(_oracle);
        emit OperatorUpdated(_operator);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addToken(
        address token,
        uint256 baseRate,
        uint256 slope,
        uint256 reserveFactor
    ) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isSupported[token]) revert AlreadySupported();
        if (reserveFactor > INDEX_PRECISION) revert FactorTooHigh();

        isSupported[token] = true;
        supportedTokens.push(token);

        Pool storage p = _pools[token];
        p.active = true;
        p.decimals = IERC20Metadata(token).decimals();
        p.borrowIndex = INDEX_PRECISION;
        p.depositIndex = INDEX_PRECISION;
        p.lastAccrual = block.timestamp;
        p.baseRatePerYear = baseRate;
        p.slopePerYear = slope;
        p.reserveFactor = reserveFactor;

        emit TokenAdded(token, p.decimals, baseRate, slope, reserveFactor);
    }

    function setInterestRateModel(
        address token,
        uint256 baseRate,
        uint256 slope
    ) external onlyOperator poolActive(token) {
        accrueInterest(token);
        _pools[token].baseRatePerYear = baseRate;
        _pools[token].slopePerYear = slope;
        emit RateModelUpdated(token, baseRate, slope);
    }

    function setPaused(
        address token,
        bool _depositPaused,
        bool _borrowPaused
    ) external onlyOperator poolActive(token) {
        _pools[token].depositPaused = _depositPaused;
        _pools[token].borrowPaused = _borrowPaused;
        emit PauseUpdated(token, _depositPaused, _borrowPaused);
    }

    function setReserveFactor(address token, uint256 factor) external onlyOperator poolActive(token) {
        if (factor > INDEX_PRECISION) revert FactorTooHigh();
        accrueInterest(token);
        _pools[token].reserveFactor = factor;
        emit ReserveFactorUpdated(token, factor);
    }

    function claimReserves(address token, address to, uint256 amount) external nonReentrant onlyOperator poolActive(token) {
        if (to == address(0)) revert ZeroAddress();
        Pool storage p = _pools[token];
        if (amount > p.totalReserves || amount > p.cash) revert ExceedsReserves();

        p.totalReserves -= amount;
        p.cash -= amount;

        IERC20(token).safeTransfer(to, amount);
        emit ReservesClaimed(token, to, amount);
    }

    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        emit OracleUpdated(_oracle);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    /*//////////////////////////////////////////////////////////////
                       INTEREST ACCRUAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function accrueInterest(address token) public poolActive(token) {
        Pool storage p = _pools[token];
        if (p.lastAccrual == block.timestamp) return;

        uint256 timeDelta = block.timestamp - p.lastAccrual;
        p.lastAccrual = block.timestamp;

        if (p.totalBorrows == 0) return;

        uint256 totalSupply = p.cash + p.totalBorrows;

        // Compute borrow rate: baseRate + slope * utilization
        // Inlined to avoid divide-before-multiply: slope * totalBorrows / totalSupply
        // rather than computing utilization separately and multiplying
        uint256 borrowRate = p.baseRatePerYear + (p.totalBorrows * p.slopePerYear) / totalSupply;

        // rateScaledTime = borrowRate * timeDelta (no division, so no truncation loss)
        uint256 rateScaledTime = borrowRate * timeDelta;
        uint256 denom = SECONDS_PER_YEAR * INDEX_PRECISION;

        // interestAccrued = totalBorrows * borrowRate * timeDelta / (SECONDS_PER_YEAR * INDEX_PRECISION)
        // Computed from raw values to avoid using a truncated intermediate in a multiplication
        uint256 interestAccrued = (p.totalBorrows * rateScaledTime) / denom;

        // reservesAccrued = totalBorrows * borrowRate * timeDelta * reserveFactor / (SECONDS_PER_YEAR * INDEX_PRECISION * INDEX_PRECISION)
        // Computed from raw values to avoid using truncated interestAccrued in a multiplication
        uint256 reservesAccrued = (p.totalBorrows * rateScaledTime * p.reserveFactor) / (denom * INDEX_PRECISION);

        // Update borrow index: borrowIndex * (1 + rateScaledTime / denom)
        p.borrowIndex += (p.borrowIndex * rateScaledTime) / denom;

        // Update totals
        p.totalBorrows += interestAccrued;
        p.totalReserves += reservesAccrued;

        // Update deposit index
        uint256 depositGrowth = interestAccrued - reservesAccrued;
        if (p.totalDepositShares > 0) {
            p.depositIndex += (depositGrowth * INDEX_PRECISION) / p.totalDepositShares;
        }
    }

    function currentBorrowIndex(address token) public view poolActive(token) returns (uint256) {
        Pool storage p = _pools[token];
        if (p.totalBorrows == 0 || p.lastAccrual == block.timestamp) return p.borrowIndex;

        uint256 timeDelta = block.timestamp - p.lastAccrual;
        uint256 totalSupply = p.cash + p.totalBorrows;

        // Inlined utilization to avoid divide-before-multiply
        uint256 borrowRate = p.baseRatePerYear + (p.totalBorrows * p.slopePerYear) / totalSupply;

        // rateScaledTime = borrowRate * timeDelta (no division, no truncation)
        uint256 rateScaledTime = borrowRate * timeDelta;
        uint256 denom = SECONDS_PER_YEAR * INDEX_PRECISION;

        // borrowIndex + borrowIndex * borrowRate * timeDelta / (SECONDS_PER_YEAR * INDEX_PRECISION)
        return p.borrowIndex + (p.borrowIndex * rateScaledTime) / denom;
    }

    function currentDepositIndex(address token) public view poolActive(token) returns (uint256) {
        Pool storage p = _pools[token];
        if (p.totalBorrows == 0 || p.lastAccrual == block.timestamp || p.totalDepositShares == 0) {
            return p.depositIndex;
        }

        uint256 timeDelta = block.timestamp - p.lastAccrual;
        uint256 totalSupply = p.cash + p.totalBorrows;

        // Inlined utilization to avoid divide-before-multiply
        uint256 borrowRate = p.baseRatePerYear + (p.totalBorrows * p.slopePerYear) / totalSupply;

        // rateScaledTime = borrowRate * timeDelta (no division, no truncation)
        uint256 rateScaledTime = borrowRate * timeDelta;
        uint256 denom = SECONDS_PER_YEAR * INDEX_PRECISION;

        // Compute interest and reserves from raw values to avoid divide-before-multiply
        uint256 interestAccrued = (p.totalBorrows * rateScaledTime) / denom;
        uint256 reservesAccrued = (p.totalBorrows * rateScaledTime * p.reserveFactor) / (denom * INDEX_PRECISION);
        uint256 depositGrowth = interestAccrued - reservesAccrued;

        return p.depositIndex + (depositGrowth * INDEX_PRECISION) / p.totalDepositShares;
    }

    /*//////////////////////////////////////////////////////////////
                       BALANCE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositBalanceCurrent(address user, address token) public view returns (uint256) {
        return (_accounts[user][token].depositShares * currentDepositIndex(token)) / INDEX_PRECISION;
    }

    function borrowBalanceCurrent(address user, address token) public view returns (uint256) {
        Account storage a = _accounts[user][token];
        if (a.borrowPrincipal == 0) return 0;
        return (a.borrowPrincipal * currentBorrowIndex(token)) / a.borrowIndex;
    }

    function getCollateralValue(address user) public view returns (uint256 total) {
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; ) {
            address token = supportedTokens[i];
            uint256 amount = depositBalanceCurrent(user, token);
            if (amount > 0) {
                total += (amount * oracle.getPrice(token)) / (10 ** _pools[token].decimals);
            }
            unchecked { ++i; }
        }
    }

    function getDebtValue(address user) public view returns (uint256 total) {
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; ) {
            address token = supportedTokens[i];
            uint256 amount = borrowBalanceCurrent(user, token);
            if (amount > 0) {
                total += (amount * oracle.getPrice(token)) / (10 ** _pools[token].decimals);
            }
            unchecked { ++i; }
        }
    }

    function isSolvent(address user) external view returns (bool) {
        return _isSolvent(user);
    }

    function _isSolvent(address user) internal view returns (bool) {
        uint256 collateralValue = getCollateralValue(user);
        uint256 debtValue = getDebtValue(user);
        return debtValue * 100 <= collateralValue * MAX_LTV;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(address token, uint256 amount) external nonReentrant poolActive(token) {
        if (amount == 0) revert ZeroAmount();
        if (_pools[token].depositPaused) revert DepositPaused();

        accrueInterest(token);

        Pool storage p = _pools[token];
        uint256 shares = (amount * INDEX_PRECISION) / p.depositIndex;

        _accounts[msg.sender][token].depositShares += shares;
        p.totalDepositShares += shares;
        p.cash += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant poolActive(token) {
        if (amount == 0) revert ZeroAmount();

        accrueInterest(token);

        Pool storage p = _pools[token];
        Account storage a = _accounts[msg.sender][token];

        uint256 depositAmount = (a.depositShares * p.depositIndex) / INDEX_PRECISION;
        if (amount > depositAmount) revert InsufficientDeposit();

        uint256 shares = (amount * INDEX_PRECISION) / p.depositIndex;
        a.depositShares -= shares;
        p.totalDepositShares -= shares;
        p.cash -= amount;

        if (!_isSolvent(msg.sender)) revert Insolvent();

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    function borrow(address token, uint256 amount) external nonReentrant poolActive(token) {
        if (amount == 0) revert ZeroAmount();
        if (_pools[token].borrowPaused) revert BorrowPaused();

        accrueInterest(token);

        Pool storage p = _pools[token];
        if (amount > p.cash) revert InsufficientLiquidity();

        Account storage a = _accounts[msg.sender][token];
        if (a.borrowPrincipal == 0) {
            a.borrowIndex = p.borrowIndex;
        }

        uint256 principalIncrease = (amount * a.borrowIndex) / p.borrowIndex;
        a.borrowPrincipal += principalIncrease;
        p.totalBorrows += amount;
        p.cash -= amount;

        if (!_isSolvent(msg.sender)) revert Insolvent();

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, token, amount);
    }

    function repay(address token, uint256 amount) external nonReentrant poolActive(token) {
        if (amount == 0) revert ZeroAmount();

        accrueInterest(token);

        Pool storage p = _pools[token];
        Account storage a = _accounts[msg.sender][token];

        uint256 debt = borrowBalanceCurrent(msg.sender, token);
        if (debt == 0) revert NoDebt();

        uint256 repayAmount = amount > debt ? debt : amount;
        uint256 principalDecrease = (repayAmount * a.borrowIndex) / p.borrowIndex;

        a.borrowPrincipal -= principalDecrease;
        p.totalBorrows -= repayAmount;
        p.cash += repayAmount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, token, repayAmount);
    }

    function liquidate(
        address borrower,
        address debtToken,
        address collateralToken,
        uint256 repayAmount
    ) external nonReentrant {
        if (!isSupported[debtToken] || !isSupported[collateralToken]) revert TokenNotSupported();
        if (repayAmount == 0) revert ZeroAmount();

        accrueInterest(debtToken);
        accrueInterest(collateralToken);

        if (_isSolvent(borrower)) revert BorrowerSolvent();

        uint256 debt = borrowBalanceCurrent(borrower, debtToken);
        if (debt == 0) revert NoDebt();

        uint256 actualRepay = repayAmount > debt ? debt : repayAmount;
        uint256 seizeAmount = _computeSeizeAmount(debtToken, collateralToken, actualRepay);

        uint256 depositAmount = depositBalanceCurrent(borrower, collateralToken);
        if (seizeAmount > depositAmount) {
            seizeAmount = depositAmount;
            actualRepay = _computeRepayFromSeize(debtToken, collateralToken, seizeAmount);
            if (actualRepay > debt) actualRepay = debt;
        }

        if (actualRepay == 0) revert ZeroAmount();

        _executeLiquidation(borrower, debtToken, collateralToken, actualRepay, seizeAmount);

        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), actualRepay);
        IERC20(collateralToken).safeTransfer(msg.sender, seizeAmount);

        emit Liquidate(msg.sender, borrower, debtToken, collateralToken, actualRepay, seizeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _computeSeizeAmount(
        address debtToken,
        address collateralToken,
        uint256 repayAmount
    ) internal view returns (uint256) {
        uint256 debtPrice = oracle.getPrice(debtToken);
        uint256 collateralPrice = oracle.getPrice(collateralToken);
        uint256 debtUnit = 10 ** _pools[debtToken].decimals;
        uint256 collUnit = 10 ** _pools[collateralToken].decimals;

        // Combined expression: all multiplications before divisions to avoid
        // divide-before-multiply precision loss
        // seizeAmount = repayAmount * debtPrice * (FEE_DENOMINATOR + LIQUIDATION_FEE) * collUnit
        //              / (debtUnit * FEE_DENOMINATOR * collateralPrice)
        return (repayAmount * debtPrice * (FEE_DENOMINATOR + LIQUIDATION_FEE) * collUnit)
            / (debtUnit * FEE_DENOMINATOR * collateralPrice);
    }

    function _computeRepayFromSeize(
        address debtToken,
        address collateralToken,
        uint256 seizeAmount
    ) internal view returns (uint256) {
        uint256 debtPrice = oracle.getPrice(debtToken);
        uint256 collateralPrice = oracle.getPrice(collateralToken);
        uint256 debtUnit = 10 ** _pools[debtToken].decimals;
        uint256 collUnit = 10 ** _pools[collateralToken].decimals;

        // Combined expression: all multiplications before divisions to avoid
        // divide-before-multiply precision loss
        // repayAmount = seizeAmount * collateralPrice * FEE_DENOMINATOR * debtUnit
        //             / (collUnit * (FEE_DENOMINATOR + LIQUIDATION_FEE) * debtPrice)
        return (seizeAmount * collateralPrice * FEE_DENOMINATOR * debtUnit)
            / (collUnit * (FEE_DENOMINATOR + LIQUIDATION_FEE) * debtPrice);
    }

    function _executeLiquidation(
        address borrower,
        address debtToken,
        address collateralToken,
        uint256 actualRepay,
        uint256 seizeAmount
    ) internal {
        Pool storage pDebt = _pools[debtToken];
        Account storage aDebt = _accounts[borrower][debtToken];

        uint256 principalDecrease = (actualRepay * aDebt.borrowIndex) / pDebt.borrowIndex;
        aDebt.borrowPrincipal -= principalDecrease;
        pDebt.totalBorrows -= actualRepay;
        pDebt.cash += actualRepay;

        Pool storage pCol = _pools[collateralToken];
        Account storage aCol = _accounts[borrower][collateralToken];

        uint256 colShares = (seizeAmount * INDEX_PRECISION) / pCol.depositIndex;
        aCol.depositShares -= colShares;
        pCol.totalDepositShares -= colShares;
        pCol.cash -= seizeAmount;
    }

    /*//////////////////////////////////////////////////////////////
                           MISC GETTERS
    //////////////////////////////////////////////////////////////*/

    function supportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }

    function getPool(address token) external view returns (Pool memory) {
        return _pools[token];
    }

    function getAccount(address user, address token)
        external
        view
        returns (uint256 depositShares, uint256 borrowPrincipal, uint256 borrowIndex)
    {
        Account storage a = _accounts[user][token];
        return (a.depositShares, a.borrowPrincipal, a.borrowIndex);
    }
}
