// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
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

contract SingleAssetLendingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOAN_TO_VALUE = 75;
    uint256 public constant LIQUIDATION_PENALTY = 8;
    uint256 public constant PERCENTAGE_BASE = 100;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant WAD = 1e18;

    IERC20 public immutable asset;
    address public admin;

    uint256 public baseRatePerYear;
    uint256 public multiplierPerYear;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public lastAccrualTimestamp;
    uint256 public borrowIndex;

    bool public depositsPaused;
    bool public borrowsPaused;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public borrowPrincipal;
    mapping(address => uint256) public userBorrowIndex;

    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized();
    error DepositsPaused();
    error BorrowsPaused();
    error InsufficientDepositBalance();
    error InsufficientPoolLiquidity();
    error BorrowExceedsLoanToValue();
    error LoanNotUndercollateralized();
    error NoOutstandingDebt();

    event Deposit(address indexed user, uint256 amount, uint256 newDepositBalance);
    event Withdraw(address indexed user, uint256 amount, uint256 newDepositBalance);
    event Borrow(address indexed user, uint256 amount, uint256 newDebt);
    event Repay(address indexed user, uint256 amount, uint256 newDebt);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 debtRepaid, uint256 collateralSeized);
    event AccrueInterest(uint256 interestAccrued, uint256 newTotalBorrows, uint256 newBorrowIndex);
    event InterestRateModelUpdated(uint256 baseRatePerYear, uint256 multiplierPerYear);
    event DepositsPauseToggled(bool paused);
    event BorrowsPauseToggled(bool paused);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    modifier whenBorrowsNotPaused() {
        if (borrowsPaused) revert BorrowsPaused();
        _;
    }

    constructor(address _asset, address _admin) {
        if (_asset == address(0) || _admin == address(0)) revert ZeroAddress();
        asset = IERC20(_asset);
        admin = _admin;
        baseRatePerYear = 2e16;
        multiplierPerYear = 5e16;
        borrowIndex = WAD;
        lastAccrualTimestamp = block.timestamp;
    }

    function accrueInterest() public {
        uint256 currentTimestamp = block.timestamp;
        if (currentTimestamp == lastAccrualTimestamp) return;

        uint256 timeDelta = currentTimestamp - lastAccrualTimestamp;

        if (totalBorrows > 0 && totalDeposits > 0) {
            uint256 utilization = (totalBorrows * WAD) / totalDeposits;
            if (utilization > WAD) utilization = WAD;

            uint256 borrowRatePerSecond =
                (baseRatePerYear + (multiplierPerYear * utilization) / WAD) / SECONDS_PER_YEAR;

            uint256 borrowInterestFactor = borrowRatePerSecond * timeDelta;
            uint256 interestAccrued = (totalBorrows * borrowInterestFactor) / WAD;

            totalBorrows += interestAccrued;
            borrowIndex = borrowIndex + ((borrowIndex * borrowInterestFactor) / WAD);

            emit AccrueInterest(interestAccrued, totalBorrows, borrowIndex);
        }

        lastAccrualTimestamp = currentTimestamp;
    }

    function getBorrowBalance(address user) public view returns (uint256) {
        if (borrowPrincipal[user] == 0) return 0;
        return (borrowPrincipal[user] * borrowIndex) / userBorrowIndex[user];
    }

    function isLiquidatable(address user) public view returns (bool) {
        uint256 userCollateral = deposits[user];
        if (userCollateral == 0) return getBorrowBalance(user) > 0;
        uint256 maxDebt = (userCollateral * MAX_LOAN_TO_VALUE) / PERCENTAGE_BASE;
        return getBorrowBalance(user) > maxDebt;
    }

    function availableLiquidity() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function deposit(uint256 amount) external nonReentrant whenDepositsNotPaused {
        if (amount == 0) revert ZeroAmount();
        accrueInterest();

        asset.safeTransferFrom(msg.sender, address(this), amount);

        deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount, deposits[msg.sender]);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        accrueInterest();

        if (deposits[msg.sender] < amount) revert InsufficientDepositBalance();

        uint256 newDepositBalance = deposits[msg.sender] - amount;
        uint256 currentDebt = getBorrowBalance(msg.sender);

        if (currentDebt > 0) {
            uint256 maxDebt = (newDepositBalance * MAX_LOAN_TO_VALUE) / PERCENTAGE_BASE;
            if (currentDebt > maxDebt) revert BorrowExceedsLoanToValue();
        }

        deposits[msg.sender] = newDepositBalance;
        totalDeposits -= amount;

        asset.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, deposits[msg.sender]);
    }

    function borrow(uint256 amount) external nonReentrant whenBorrowsNotPaused {
        if (amount == 0) revert ZeroAmount();
        accrueInterest();

        uint256 currentDebt = getBorrowBalance(msg.sender);
        uint256 newDebt = currentDebt + amount;

        uint256 maxBorrow = (deposits[msg.sender] * MAX_LOAN_TO_VALUE) / PERCENTAGE_BASE;
        if (newDebt > maxBorrow) revert BorrowExceedsLoanToValue();

        if (amount > availableLiquidity()) revert InsufficientPoolLiquidity();

        borrowPrincipal[msg.sender] = newDebt;
        userBorrowIndex[msg.sender] = borrowIndex;
        totalBorrows += amount;

        asset.safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount, newDebt);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        accrueInterest();

        uint256 currentDebt = getBorrowBalance(msg.sender);
        if (currentDebt == 0) revert NoOutstandingDebt();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        asset.safeTransferFrom(msg.sender, address(this), repayAmount);

        borrowPrincipal[msg.sender] = currentDebt - repayAmount;
        userBorrowIndex[msg.sender] = borrowIndex;
        totalBorrows -= repayAmount;

        emit Repay(msg.sender, repayAmount, borrowPrincipal[msg.sender]);
    }

    function liquidate(address borrower) external nonReentrant {
        accrueInterest();

        if (!isLiquidatable(borrower)) revert LoanNotUndercollateralized();

        uint256 currentDebt = getBorrowBalance(borrower);
        if (currentDebt == 0) revert NoOutstandingDebt();

        uint256 penalty = (currentDebt * LIQUIDATION_PENALTY) / PERCENTAGE_BASE;
        uint256 collateralToSeize = currentDebt + penalty;

        uint256 borrowerCollateral = deposits[borrower];
        if (collateralToSeize > borrowerCollateral) {
            collateralToSeize = borrowerCollateral;
        }

        asset.safeTransferFrom(msg.sender, address(this), currentDebt);

        borrowPrincipal[borrower] = 0;
        userBorrowIndex[borrower] = borrowIndex;
        totalBorrows -= currentDebt;

        deposits[borrower] -= collateralToSeize;
        totalDeposits -= collateralToSeize;

        asset.safeTransfer(msg.sender, collateralToSeize);

        emit Liquidate(msg.sender, borrower, currentDebt, collateralToSeize);
    }

    function setInterestRateModel(uint256 _baseRatePerYear, uint256 _multiplierPerYear) external onlyAdmin {
        accrueInterest();
        baseRatePerYear = _baseRatePerYear;
        multiplierPerYear = _multiplierPerYear;
        emit InterestRateModelUpdated(_baseRatePerYear, _multiplierPerYear);
    }

    function setDepositsPaused(bool _paused) external onlyAdmin {
        depositsPaused = _paused;
        emit DepositsPauseToggled(_paused);
    }

    function setBorrowsPaused(bool _paused) external onlyAdmin {
        borrowsPaused = _paused;
        emit BorrowsPauseToggled(_paused);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }
}
