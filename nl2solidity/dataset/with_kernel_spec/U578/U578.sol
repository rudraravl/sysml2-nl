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

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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
        require(initialOwner != address(0), "Ownable: zero address");
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract LendingMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------- Custom Errors ----------
    error AssetNotSupported();
    error AssetAlreadySupported();
    error InsufficientDeposit();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error AmountZero();
    error ExceedsAvailable();
    error PositionHealthy();
    error InvalidParameter();
    error UnauthorizedOperator();
    error NoOutstandingDebt();
    error SelfLiquidation();

    // ---------- Constants ----------
    uint256 public constant MAX_LTV = 80; // 80%
    uint256 public constant LIQUIDATION_PENALTY = 5; // 5%
    uint256 public constant BASIS_POINTS = 100;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant WAD = 1e18;

    // ---------- Structs ----------
    struct AssetPool {
        bool supported;
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 baseRatePerSecond;
        uint256 multiplierPerSecond;
        uint256 borrowIndex;
        uint256 lastAccrualTimestamp;
    }

    struct UserAsset {
        uint256 deposit;
        uint256 borrowPrincipal;
        uint256 userBorrowIndex;
    }

    // ---------- State Variables ----------
    address public operator;

    mapping(address => AssetPool) public pools;
    mapping(address => mapping(address => UserAsset)) public userAssets;

    address[] public supportedAssets;

    // ---------- Events ----------
    event AssetAdded(address indexed asset);
    event AssetRemoved(address indexed asset);
    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 newDeposit);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 newDeposit);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 newBorrow);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 newBorrow);
    event Liquidation(
        address indexed liquidator,
        address indexed borrower,
        address indexed debtAsset,
        address collateralAsset,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event InterestRateUpdated(address indexed asset, uint256 baseRatePerSecond, uint256 multiplierPerSecond);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert UnauthorizedOperator();
        _;
    }

    modifier onlySupported(address asset) {
        if (!pools[asset].supported) revert AssetNotSupported();
        _;
    }

    // ---------- Constructor ----------
    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert InvalidParameter();
        operator = _operator;
        emit OperatorUpdated(address(0), _operator);
    }

    // ---------- Admin Functions ----------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert InvalidParameter();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function addAsset(address asset, uint256 baseRatePerSecond, uint256 multiplierPerSecond) external onlyOperator {
        if (asset == address(0)) revert InvalidParameter();
        if (pools[asset].supported) revert AssetAlreadySupported();
        pools[asset] = AssetPool({
            supported: true,
            totalDeposits: 0,
            totalBorrows: 0,
            baseRatePerSecond: baseRatePerSecond,
            multiplierPerSecond: multiplierPerSecond,
            borrowIndex: WAD,
            lastAccrualTimestamp: block.timestamp
        });
        supportedAssets.push(asset);
        emit AssetAdded(asset);
    }

    function removeAsset(address asset) external onlyOperator {
        AssetPool storage pool = pools[asset];
        if (!pool.supported) revert AssetNotSupported();
        if (pool.totalDeposits != 0 || pool.totalBorrows != 0) revert InvalidParameter();
        pool.supported = false;
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                supportedAssets[i] = supportedAssets[supportedAssets.length - 1];
                supportedAssets.pop();
                break;
            }
        }
        emit AssetRemoved(asset);
    }

    function setInterestRateParams(address asset, uint256 baseRatePerSecond, uint256 multiplierPerSecond)
        external
        onlyOperator
        onlySupported(asset)
    {
        AssetPool storage pool = pools[asset];
        _accrueInterest(pool);
        pool.baseRatePerSecond = baseRatePerSecond;
        pool.multiplierPerSecond = multiplierPerSecond;
        emit InterestRateUpdated(asset, baseRatePerSecond, multiplierPerSecond);
    }

    // ---------- Interest Accrual ----------
    function _accrueInterest(AssetPool storage pool) internal {
        if (block.timestamp <= pool.lastAccrualTimestamp) return;
        uint256 elapsed = block.timestamp - pool.lastAccrualTimestamp;
        pool.lastAccrualTimestamp = block.timestamp;

        if (pool.totalBorrows < 1) {
            return;
        }

        // Avoid divide-before-multiply: compute borrow rate directly as
        // baseRate + (multiplier * totalBorrows) / totalDeposits
        // which is mathematically equivalent to baseRate + multiplier * utilization / WAD
        // without performing a division prior to a multiplication.
        uint256 borrowRatePerSecond =
            pool.baseRatePerSecond + (pool.multiplierPerSecond * pool.totalBorrows) / pool.totalDeposits;
        uint256 interestFactor = borrowRatePerSecond * elapsed;
        uint256 interestAccrued = (pool.totalBorrows * interestFactor) / WAD;

        pool.totalBorrows += interestAccrued;
        pool.borrowIndex = (pool.borrowIndex * (WAD + interestFactor)) / WAD;
    }

    function _accrueUserBorrow(address asset, address user) internal {
        AssetPool storage pool = pools[asset];
        _accrueInterest(pool);
        UserAsset storage ua = userAssets[asset][user];
        if (ua.borrowPrincipal > 0 && ua.userBorrowIndex < pool.borrowIndex) {
            ua.borrowPrincipal = (ua.borrowPrincipal * pool.borrowIndex) / ua.userBorrowIndex;
            ua.userBorrowIndex = pool.borrowIndex;
        }
    }

    // ---------- Core Functions ----------
    function deposit(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert AmountZero();
        AssetPool storage pool = pools[asset];
        _accrueInterest(pool);

        // Effects before interactions
        pool.totalDeposits += amount;
        userAssets[asset][msg.sender].deposit += amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount, userAssets[asset][msg.sender].deposit);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert AmountZero();
        AssetPool storage pool = pools[asset];
        _accrueInterest(pool);

        UserAsset storage ua = userAssets[asset][msg.sender];
        if (amount > ua.deposit) revert InsufficientDeposit();

        // Effects before interactions
        ua.deposit -= amount;
        pool.totalDeposits -= amount;

        if (pool.totalBorrows > pool.totalDeposits) {
            revert InsufficientLiquidity();
        }

        _checkCollateralSufficient(msg.sender);

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount, ua.deposit);
    }

    function borrow(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert AmountZero();
        AssetPool storage pool = pools[asset];
        _accrueInterest(pool);

        if (amount > pool.totalDeposits - pool.totalBorrows) revert InsufficientLiquidity();

        _accrueUserBorrow(asset, msg.sender);
        UserAsset storage ua = userAssets[asset][msg.sender];

        // Effects before interactions
        ua.borrowPrincipal += amount;
        ua.userBorrowIndex = pool.borrowIndex;
        pool.totalBorrows += amount;

        _checkCollateralSufficient(msg.sender);

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, asset, amount, ua.borrowPrincipal);
    }

    function repay(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert AmountZero();
        AssetPool storage pool = pools[asset];
        _accrueInterest(pool);

        _accrueUserBorrow(asset, msg.sender);
        UserAsset storage ua = userAssets[asset][msg.sender];
        if (ua.borrowPrincipal == 0) revert NoOutstandingDebt();

        uint256 repayAmount = amount > ua.borrowPrincipal ? ua.borrowPrincipal : amount;

        // Effects before interactions
        ua.borrowPrincipal -= repayAmount;
        pool.totalBorrows -= repayAmount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, asset, repayAmount, ua.borrowPrincipal);
    }

    function liquidate(
        address borrower,
        address debtAsset,
        address collateralAsset,
        uint256 repayAmount
    ) external nonReentrant onlySupported(debtAsset) onlySupported(collateralAsset) {
        if (repayAmount == 0) revert AmountZero();
        if (msg.sender == borrower) revert SelfLiquidation();

        _accrueInterest(pools[debtAsset]);
        _accrueInterest(pools[collateralAsset]);
        _accrueUserBorrow(debtAsset, borrower);

        UserAsset storage borrowerDebt = userAssets[debtAsset][borrower];
        UserAsset storage borrowerCollateral = userAssets[collateralAsset][borrower];

        if (borrowerDebt.borrowPrincipal == 0) revert NoOutstandingDebt();
        if (borrowerCollateral.deposit == 0) revert InsufficientCollateral();
        if (_isPositionHealthy(borrower)) revert PositionHealthy();

        uint256 actualRepay = repayAmount > borrowerDebt.borrowPrincipal ? borrowerDebt.borrowPrincipal : repayAmount;
        uint256 collateralSeized = _computeSeizedCollateral(actualRepay, borrowerCollateral.deposit);

        // Effects before interactions
        borrowerDebt.borrowPrincipal -= actualRepay;
        pools[debtAsset].totalBorrows -= actualRepay;

        borrowerCollateral.deposit -= collateralSeized;
        pools[collateralAsset].totalDeposits -= collateralSeized;

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), actualRepay);
        IERC20(collateralAsset).safeTransfer(msg.sender, collateralSeized);

        emit Liquidation(msg.sender, borrower, debtAsset, collateralAsset, actualRepay, collateralSeized);
    }

    function _computeSeizedCollateral(uint256 actualRepay, uint256 availableCollateral)
        internal
        pure
        returns (uint256)
    {
        uint256 penalty = (actualRepay * LIQUIDATION_PENALTY) / BASIS_POINTS;
        uint256 totalDebtValue = actualRepay + penalty;
        if (totalDebtValue > availableCollateral) {
            return availableCollateral;
        }
        return totalDebtValue;
    }

    // ---------- View / Internal Helpers ----------
    function _getBorrowValue(address user, address asset) internal view returns (uint256) {
        UserAsset storage ua = userAssets[asset][user];
        if (ua.borrowPrincipal == 0) return 0;
        AssetPool storage pool = pools[asset];
        return (ua.borrowPrincipal * pool.borrowIndex) / ua.userBorrowIndex;
    }

    function _isPositionHealthy(address user) internal view returns (bool) {
        uint256 totalCollateralValue = 0;
        uint256 totalBorrowValue = 0;

        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            UserAsset storage ua = userAssets[asset][user];
            if (ua.deposit > 0) {
                totalCollateralValue += ua.deposit;
            }
            if (ua.borrowPrincipal > 0) {
                totalBorrowValue += _getBorrowValue(user, asset);
            }
        }

        if (totalBorrowValue == 0) return true;
        uint256 maxBorrow = (totalCollateralValue * MAX_LTV) / BASIS_POINTS;
        return totalBorrowValue <= maxBorrow;
    }

    function _checkCollateralSufficient(address user) internal view {
        if (!_isPositionHealthy(user)) revert InsufficientCollateral();
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function getUserPosition(address user, address asset)
        external
        view
        returns (uint256 deposit, uint256 borrowPrincipal, uint256 currentBorrow)
    {
        UserAsset storage ua = userAssets[asset][user];
        return (ua.deposit, ua.borrowPrincipal, _getBorrowValue(user, asset));
    }

    function getPoolState(address asset)
        external
        view
        onlySupported(asset)
        returns (uint256 totalDeposits, uint256 totalBorrows, uint256 borrowIndex, uint256 lastAccrualTimestamp)
    {
        AssetPool storage pool = pools[asset];
        return (pool.totalDeposits, pool.totalBorrows, pool.borrowIndex, pool.lastAccrualTimestamp);
    }

    function isPositionHealthy(address user) external view returns (bool) {
        return _isPositionHealthy(user);
    }
}
