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
            amount == 0 || token.allowance(address(this), spender) == 0,
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
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
    error NewOwnerIsZeroAddress();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert NewOwnerIsZeroAddress();
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

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert NewOwnerIsZeroAddress();
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        address oldOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
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

contract LendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_LTV = 7500; // 75% in basis points
    uint256 public constant LIQUIDATION_FEE = 50; // 0.5% in basis points
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable collateralToken;
    IERC20 public immutable loanToken;

    struct LoanPosition {
        uint256 collateral;      // [token units]
        uint256 debt;            // [token units]
        uint256 lastAccrualTime; // [timestamp]
    }

    mapping(address => LoanPosition) public positions;

    uint256 public totalCollateral;
    uint256 public totalDebt;

    uint256 public baseInterestRate;      // [wad] annual rate, e.g. 0.05e18 = 5%
    uint256 public liquidationThreshold;  // [bps] e.g. 8000 = 80%

    address public operator;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed account, uint256 amount, uint256 collateral);
    event Withdraw(address indexed account, uint256 amount, uint256 collateral);
    event Borrow(address indexed account, uint256 amount, uint256 debt);
    event Repay(address indexed account, uint256 amount, uint256 debt);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        uint256 collateralSeized,
        uint256 debtRepaid,
        uint256 fee
    );
    event SetBaseInterestRate(uint256 oldRate, uint256 newRate);
    event SetLiquidationThreshold(uint256 oldThreshold, uint256 newThreshold);
    event SetOperator(address oldOperator, address newOperator);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error PositionSafe();
    error InsufficientCollateralBalance();
    error ExceedsMaxLTV();
    error InvalidRate();
    error InvalidThreshold();
    error NoOutstandingDebt();
    error InsufficientLiquidity();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _collateralToken,
        address _loanToken,
        address _operator,
        uint256 _baseInterestRate,
        uint256 _liquidationThreshold
    ) Ownable(msg.sender) {
        if (
            _collateralToken == address(0) ||
            _loanToken == address(0) ||
            _operator == address(0)
        ) revert ZeroAddress();
        if (_baseInterestRate > WAD) revert InvalidRate();
        if (_liquidationThreshold == 0 || _liquidationThreshold > BPS_DENOMINATOR)
            revert InvalidThreshold();
        if (_liquidationThreshold <= MAX_LTV) revert InvalidThreshold();

        collateralToken = IERC20(_collateralToken);
        loanToken = IERC20(_loanToken);
        operator = _operator;
        baseInterestRate = _baseInterestRate;
        liquidationThreshold = _liquidationThreshold;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        LoanPosition storage pos = positions[msg.sender];
        pos.collateral += amount;
        totalCollateral += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, pos.collateral);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        LoanPosition storage pos = positions[msg.sender];

        uint256 newDebt = pos.debt + amount;
        uint256 maxBorrow = (pos.collateral * MAX_LTV) / BPS_DENOMINATOR;
        if (newDebt > maxBorrow) revert ExceedsMaxLTV();

        if (loanToken.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        pos.debt = newDebt;
        totalDebt += amount;

        loanToken.safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount, pos.debt);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        LoanPosition storage pos = positions[msg.sender];
        uint256 debt = pos.debt;
        if (debt == 0) revert NoOutstandingDebt();

        uint256 repayAmount = amount > debt ? debt : amount;

        pos.debt -= repayAmount;
        totalDebt -= repayAmount;

        loanToken.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, repayAmount, pos.debt);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        LoanPosition storage pos = positions[msg.sender];
        if (pos.collateral < amount) revert InsufficientCollateralBalance();

        uint256 newCollateral = pos.collateral - amount;

        if (pos.debt > 0) {
            uint256 maxBorrow = (newCollateral * MAX_LTV) / BPS_DENOMINATOR;
            if (pos.debt > maxBorrow) revert InsufficientCollateral();
        }

        pos.collateral = newCollateral;
        totalCollateral -= amount;

        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, pos.collateral);
    }

    function liquidate(address borrower) external nonReentrant onlyOperator {
        if (borrower == address(0)) revert ZeroAddress();

        _accrueInterest(borrower);

        LoanPosition storage pos = positions[borrower];
        uint256 debt = pos.debt;
        uint256 collateral = pos.collateral;
        if (debt == 0 || collateral == 0) revert ZeroAmount();

        if (!_isLiquidatable(borrower)) revert PositionSafe();

        uint256 fee = (debt * LIQUIDATION_FEE) / BPS_DENOMINATOR;
        uint256 totalOwed = debt + fee;

        uint256 collateralSeized;
        if (totalOwed >= collateral) {
            collateralSeized = collateral;
        } else {
            collateralSeized = totalOwed;
        }

        pos.collateral -= collateralSeized;
        pos.debt = 0;

        totalCollateral -= collateralSeized;
        totalDebt -= debt;

        collateralToken.safeTransfer(msg.sender, collateralSeized);

        emit Liquidate(msg.sender, borrower, collateralSeized, debt, fee);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setBaseInterestRate(uint256 newRate) external onlyOperator {
        if (newRate > WAD) revert InvalidRate();
        uint256 oldRate = baseInterestRate;
        baseInterestRate = newRate;
        emit SetBaseInterestRate(oldRate, newRate);
    }

    function setLiquidationThreshold(uint256 newThreshold) external onlyOperator {
        if (newThreshold == 0 || newThreshold > BPS_DENOMINATOR)
            revert InvalidThreshold();
        if (newThreshold <= MAX_LTV) revert InvalidThreshold();
        uint256 oldThreshold = liquidationThreshold;
        liquidationThreshold = newThreshold;
        emit SetLiquidationThreshold(oldThreshold, newThreshold);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit SetOperator(oldOperator, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPosition(address account) external view returns (
        uint256 collateral,
        uint256 debt,
        uint256 lastAccrualTime
    ) {
        LoanPosition storage pos = positions[account];
        return (pos.collateral, pos.debt, pos.lastAccrualTime);
    }

    function isLiquidatable(address borrower) external view returns (bool) {
        return _isLiquidatable(borrower);
    }

    function maxBorrowAmount(address borrower) external view returns (uint256) {
        LoanPosition storage pos = positions[borrower];
        uint256 currentDebt = _currentDebt(borrower);
        uint256 maxBorrow = (pos.collateral * MAX_LTV) / BPS_DENOMINATOR;
        return currentDebt >= maxBorrow ? 0 : maxBorrow - currentDebt;
    }

    function availableLiquidity() external view returns (uint256) {
        return loanToken.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _accrueInterest(address borrower) internal {
        LoanPosition storage pos = positions[borrower];
        if (pos.debt == 0) {
            pos.lastAccrualTime = block.timestamp;
            return;
        }
        if (pos.lastAccrualTime == 0) {
            pos.lastAccrualTime = block.timestamp;
            return;
        }

        if (block.timestamp <= pos.lastAccrualTime) return;

        uint256 timeElapsed = block.timestamp - pos.lastAccrualTime;
        uint256 interest = (pos.debt * baseInterestRate * timeElapsed) / (WAD * SECONDS_PER_YEAR);
        pos.debt += interest;
        totalDebt += interest;
        pos.lastAccrualTime = block.timestamp;
    }

    function _currentDebt(address borrower) internal view returns (uint256) {
        LoanPosition storage pos = positions[borrower];
        if (pos.debt == 0 || pos.lastAccrualTime == 0) return pos.debt;

        if (block.timestamp <= pos.lastAccrualTime) return pos.debt;

        uint256 timeElapsed = block.timestamp - pos.lastAccrualTime;
        uint256 interest = (pos.debt * baseInterestRate * timeElapsed) / (WAD * SECONDS_PER_YEAR);
        return pos.debt + interest;
    }

    function _isLiquidatable(address borrower) internal view returns (bool) {
        LoanPosition storage pos = positions[borrower];
        if (pos.debt == 0) return false;

        uint256 currentDebt = _currentDebt(borrower);
        uint256 maxAllowedDebt = (pos.collateral * liquidationThreshold) / BPS_DENOMINATOR;
        return currentDebt > maxAllowedDebt;
    }
}
