// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

contract LendingPool {
    using SafeERC20 for IERC20;

    error Unauthorized();
    error BorrowingPaused();
    error InsufficientCollateral();
    error CollateralUndercollateralized();
    error InsufficientPoolBalance();
    error ZeroAmount();
    error InvalidRate();
    error InvalidAddress();
    error ReentrantCall();

    event Deposit(address indexed user, uint256 amount, string txType);
    event Borrow(address indexed user, uint256 amount, uint256 fee, string txType);
    event Repay(address indexed user, uint256 amount, string txType);
    event Withdraw(address indexed user, uint256 amount, string txType);
    event InterestRateUpdated(uint256 newRatePerSecond);
    event BorrowingPaused(bool paused);
    event FeeRecipientUpdated(address newFeeRecipient);
    event PoolFunded(address indexed funder, uint256 amount);
    event OperatorUpdated(address newOperator);

    uint256 public constant MIN_COLLATERAL_RATIO = 150e16;
    uint256 public constant FEE_BASIS_POINTS = 10;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant RATE_SCALE = 1e18;

    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowableToken;
    IOracle public immutable oracle;

    address public operator;
    address public feeRecipient;
    uint256 public interestRatePerSecond;
    bool public borrowingPaused;

    uint256 public totalCollateral;
    uint256 public totalBorrowed;

    struct UserPosition {
        uint256 collateral;
        uint256 debt;
        uint256 lastUpdate;
    }

    mapping(address => UserPosition) public positions;

    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier whenBorrowNotPaused() {
        if (borrowingPaused) revert BorrowingPaused();
        _;
    }

    constructor(
        address _collateralToken,
        address _borrowableToken,
        address _oracle,
        address _operator,
        address _feeRecipient,
        uint256 _initialInterestRatePerSecond
    ) {
        if (
            _collateralToken == address(0) ||
            _borrowableToken == address(0) ||
            _oracle == address(0) ||
            _operator == address(0) ||
            _feeRecipient == address(0)
        ) revert InvalidAddress();

        collateralToken = IERC20(_collateralToken);
        borrowableToken = IERC20(_borrowableToken);
        oracle = IOracle(_oracle);
        operator = _operator;
        feeRecipient = _feeRecipient;
        interestRatePerSecond = _initialInterestRatePerSecond;
    }

    function _accrueInterest(address user) internal {
        UserPosition storage pos = positions[user];
        if (pos.debt == 0) {
            pos.lastUpdate = block.timestamp;
            return;
        }

        uint256 timeDelta = block.timestamp - pos.lastUpdate;
        if (timeDelta == 0) return;

        uint256 interest = (pos.debt * interestRatePerSecond * timeDelta) / RATE_SCALE;
        pos.debt += interest;
        pos.lastUpdate = block.timestamp;
        totalBorrowed += interest;
    }

    function _getCollateralValue(uint256 collateralAmount) internal view returns (uint256) {
        uint256 price = oracle.getPrice(address(collateralToken));
        return (collateralAmount * price) / RATE_SCALE;
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        if (pos.debt == 0) {
            pos.lastUpdate = block.timestamp;
        }

        pos.collateral += amount;
        totalCollateral += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, "DEPOSIT_COLLATERAL");
    }

    function borrow(uint256 amount) external nonReentrant whenBorrowNotPaused {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        _accrueInterest(msg.sender);

        uint256 collateral = pos.collateral;
        uint256 currentDebt = pos.debt;
        uint256 newDebt = currentDebt + amount;

        uint256 collateralValue = _getCollateralValue(collateral);
        if (collateralValue * RATE_SCALE < newDebt * MIN_COLLATERAL_RATIO) {
            revert CollateralUndercollateralized();
        }

        uint256 poolBalance = borrowableToken.balanceOf(address(this));
        if (poolBalance < amount) revert InsufficientPoolBalance();

        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 netAmount = amount - fee;

        pos.debt = newDebt;
        pos.lastUpdate = block.timestamp;
        totalBorrowed += amount;

        borrowableToken.safeTransfer(msg.sender, netAmount);
        if (fee > 0) {
            borrowableToken.safeTransfer(feeRecipient, fee);
        }

        emit Borrow(msg.sender, amount, fee, "BORROW");
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        _accrueInterest(msg.sender);

        uint256 currentDebt = pos.debt;
        if (currentDebt == 0) revert ZeroAmount();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        borrowableToken.safeTransferFrom(msg.sender, address(this), repayAmount);

        pos.debt = currentDebt - repayAmount;
        pos.lastUpdate = block.timestamp;
        totalBorrowed -= repayAmount;

        emit Repay(msg.sender, repayAmount, "REPAY");
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender];
        _accrueInterest(msg.sender);

        uint256 currentCollateral = pos.collateral;
        if (amount > currentCollateral) revert InsufficientCollateral();

        uint256 debt = pos.debt;
        if (debt > 0) {
            uint256 newCollateral = currentCollateral - amount;
            uint256 newCollateralValue = _getCollateralValue(newCollateral);
            if (newCollateralValue * RATE_SCALE < debt * MIN_COLLATERAL_RATIO) {
                revert CollateralUndercollateralized();
            }
        }

        pos.collateral = currentCollateral - amount;
        totalCollateral -= amount;

        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, "WITHDRAW_COLLATERAL");
    }

    function fundPool(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        borrowableToken.safeTransferFrom(msg.sender, address(this), amount);
        emit PoolFunded(msg.sender, amount);
    }

    function setInterestRate(uint256 newRatePerSecond) external onlyOperator {
        uint256 maxRatePerSecond = (1000 * RATE_SCALE) / SECONDS_PER_YEAR;
        if (newRatePerSecond > maxRatePerSecond) revert InvalidRate();
        interestRatePerSecond = newRatePerSecond;
        emit InterestRateUpdated(newRatePerSecond);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert InvalidAddress();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    function toggleBorrowingPause() external onlyOperator {
        borrowingPaused = !borrowingPaused;
        emit BorrowingPaused(borrowingPaused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function getUserDebt(address user) public view returns (uint256) {
        UserPosition storage pos = positions[user];
        if (pos.debt == 0) return 0;
        uint256 timeDelta = block.timestamp - pos.lastUpdate;
        if (timeDelta == 0) return pos.debt;
        uint256 interest = (pos.debt * interestRatePerSecond * timeDelta) / RATE_SCALE;
        return pos.debt + interest;
    }

    function getUserCollateralRatio(address user) external view returns (uint256) {
        uint256 debt = getUserDebt(user);
        if (debt == 0) return type(uint256).max;
        uint256 collateralValue = _getCollateralValue(positions[user].collateral);
        return (collateralValue * RATE_SCALE) / debt;
    }

    function getAvailableCollateral(address user) external view returns (uint256) {
        UserPosition storage pos = positions[user];
        uint256 debt = getUserDebt(user);
        if (debt == 0) return pos.collateral;

        uint256 price = oracle.getPrice(address(collateralToken));
        if (price == 0) revert InvalidAddress();
        uint256 minCollateralNeeded = (debt * MIN_COLLATERAL_RATIO) / price;
        if (minCollateralNeeded >= pos.collateral) return 0;
        return pos.collateral - minCollateralNeeded;
    }

    function poolBorrowableBalance() external view returns (uint256) {
        return borrowableToken.balanceOf(address(this));
    }

    function poolCollateralBalance() external view returns (uint256) {
        return collateralToken.balanceOf(address(this));
    }
}
