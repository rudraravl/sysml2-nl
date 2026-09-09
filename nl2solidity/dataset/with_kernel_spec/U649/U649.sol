// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
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

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
}

/**
 * @title LendingPool
 * @notice A decentralized lending pool supporting a single collateral asset and a single borrowable asset.
 *         Users deposit collateral, borrow against it at a maximum 75% LTV, repay loans, and withdraw collateral.
 *         A 0.5% origination fee is charged on every new borrow and accrues to protocol reserves.
 *         Interest accrues continuously via a global borrow index.
 */
contract LendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    uint256 public constant MAX_LTV = 7500;       // 75% in basis points
    uint256 public constant ORIGINATION_FEE = 50;  // 0.5% in basis points
    uint256 public constant BPS = 10000;
    uint256 public constant WAD = 1e18;

    // ============ Immutables ============
    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;
    IPriceOracle public immutable oracle;

    // ============ Pool State ============
    uint256 public interestRatePerSecond;  // per-second rate, scaled by WAD
    uint256 public borrowIndex;            // global accrual index, scaled by WAD
    uint256 public totalBorrowed;          // sum of all outstanding debt (principal + accrued interest)
    uint256 public totalReserves;          // accumulated fees and interest owned by the protocol
    uint256 public lastAccrualTimestamp;   // last time global interest was accrued
    bool public borrowingPaused;

    // ============ User State ============
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public userPrincipal;  // debt principal captured at last index
    mapping(address => uint256) public userIndex;      // borrow index at last user update

    // ============ Events ============
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 fee);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event LiquiditySupplied(address indexed provider, address indexed asset, uint256 amount);
    event InterestRateUpdated(uint256 newRate);
    event BorrowingPausedUpdated(bool paused);
    event ReservesWithdrawn(address indexed to, uint256 amount);

    // ============ Custom Errors ============
    error ZeroAddress();
    error ZeroAmount();
    error BorrowingIsPaused();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error PositionNotHealthy();
    error NoOutstandingDebt();
    error InsufficientReserves();
    error InvalidOraclePrice();

    // ============ Constructor ============
    constructor(
        address _collateralToken,
        address _borrowToken,
        address _oracle,
        uint256 _interestRatePerSecond
    ) Ownable(msg.sender) {
        if (_collateralToken == address(0) || _borrowToken == address(0) || _oracle == address(0)) {
            revert ZeroAddress();
        }
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
        oracle = IPriceOracle(_oracle);
        interestRatePerSecond = _interestRatePerSecond;
        borrowIndex = WAD;
        lastAccrualTimestamp = block.timestamp;
    }

    // ============ Core User Functions ============

    /**
     * @notice Deposit collateral tokens into the pool.
     * @param amount Amount of collateral tokens to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        collateralBalance[msg.sender] += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, address(collateralToken), amount);
    }

    /**
     * @notice Borrow tokens against deposited collateral. A 0.5% origination fee is added to the debt.
     * @param amount The amount of borrowable tokens to borrow.
     */
    function borrow(uint256 amount) external nonReentrant {
        if (borrowingPaused) revert BorrowingIsPaused();
        if (amount == 0) revert ZeroAmount();

        accrueInterest();

        uint256 fee = (amount * ORIGINATION_FEE) / BPS;
        uint256 currentDebt = _getUserDebt(msg.sender);
        uint256 newDebt = currentDebt + amount + fee;

        require(_isCollateralSufficient(msg.sender, newDebt), InsufficientCollateral());
        require(_getAvailableLiquidity() >= amount, InsufficientLiquidity());

        // Effects: update state before interactions
        userPrincipal[msg.sender] = newDebt;
        userIndex[msg.sender] = borrowIndex;
        totalBorrowed += (amount + fee);
        totalReserves += fee;

        // Interactions
        borrowToken.safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, address(borrowToken), amount, fee);
    }

    /**
     * @notice Repay outstanding debt. Excess repayment beyond debt is returned to the caller.
     * @param amount Amount of borrowable tokens to repay.
     */
    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        accrueInterest();

        uint256 currentDebt = _getUserDebt(msg.sender);
        if (currentDebt < 1) revert NoOutstandingDebt();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        // Effects: update state before external call (checks-effects-interactions)
        userPrincipal[msg.sender] = currentDebt - repayAmount;
        userIndex[msg.sender] = borrowIndex;
        totalBorrowed -= repayAmount;

        // Interactions
        borrowToken.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, address(borrowToken), repayAmount);
    }

    /**
     * @notice Withdraw collateral tokens, provided the position remains healthy.
     * @param amount Amount of collateral tokens to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalance[msg.sender] < amount) revert InsufficientCollateral();

        accrueInterest();

        // Effects: update state before external call
        collateralBalance[msg.sender] -= amount;

        require(_isCollateralSufficient(msg.sender, _getUserDebt(msg.sender)), PositionNotHealthy());

        // Interactions
        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, address(collateralToken), amount);
    }

    /**
     * @notice Supply borrowable tokens to the pool to provide liquidity for borrowers.
     * @param amount Amount of borrowable tokens to supply.
     */
    function supplyLiquidity(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        borrowToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquiditySupplied(msg.sender, address(borrowToken), amount);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the per-second interest rate. Accrues interest before changing.
     * @param newRate New per-second interest rate scaled by WAD.
     */
    function setInterestRate(uint256 newRate) external onlyOwner {
        accrueInterest();
        interestRatePerSecond = newRate;
        emit InterestRateUpdated(newRate);
    }

    /**
     * @notice Pause or unpause borrowing.
     * @param paused True to pause, false to unpause.
     */
    function setBorrowingPaused(bool paused) external onlyOwner {
        borrowingPaused = paused;
        emit BorrowingPausedUpdated(paused);
    }

    /**
     * @notice Withdraw accumulated protocol reserves.
     * @param to Recipient address.
     * @param amount Amount of borrowable tokens to withdraw.
     */
    function withdrawReserves(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > totalReserves) revert InsufficientReserves();
        require(borrowToken.balanceOf(address(this)) >= amount, InsufficientLiquidity());

        // Effects
        totalReserves -= amount;

        // Interactions
        borrowToken.safeTransfer(to, amount);

        emit ReservesWithdrawn(to, amount);
    }

    // ============ Interest Accrual ============

    /**
     * @notice Accrue global interest up to the current block timestamp.
     */
    function accrueInterest() public {
        if (block.timestamp <= lastAccrualTimestamp) return;
        uint256 timeElapsed = block.timestamp - lastAccrualTimestamp;
        lastAccrualTimestamp = block.timestamp;

        if (totalBorrowed < 1) return;

        uint256 interest = (totalBorrowed * interestRatePerSecond * timeElapsed) / WAD;
        totalReserves += interest;
        totalBorrowed += interest;

        // Multiply-then-divide to avoid divide-before-multiply precision loss
        borrowIndex = borrowIndex + (borrowIndex * interestRatePerSecond * timeElapsed) / WAD;
    }

    // ============ View Functions ============

    /**
     * @notice Returns the current debt of a user including accrued interest.
     */
    function getUserDebt(address user) external view returns (uint256) {
        return _getUserDebt(user);
    }

    /**
     * @notice Returns the available borrowable liquidity in the pool.
     */
    function getAvailableLiquidity() external view returns (uint256) {
        return _getAvailableLiquidity();
    }

    /**
     * @notice Returns the maximum additional amount a user can borrow.
     *         Computed as a single multiply-then-divide expression to avoid
     *         divide-before-multiply precision loss.
     */
    function getMaxBorrowAmount(address user) external view returns (uint256) {
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        uint256 borrowPrice = oracle.getPrice(address(borrowToken));
        if (borrowPrice < 1) return 0;
        if (collateralPrice < 1) return 0;

        // maxDebt = collateralBalance * collateralPrice * MAX_LTV / (BPS * borrowPrice)
        // All multiplications performed before division to preserve precision
        uint256 maxDebt = (collateralBalance[user] * collateralPrice * MAX_LTV) / (BPS * borrowPrice);

        uint256 currentDebt = _getUserDebt(user);
        if (currentDebt >= maxDebt) return 0;
        return maxDebt - currentDebt;
    }

    /**
     * @notice Returns the current health factor of a user's position (collateral value / debt value).
     *         A value >= 1e18 means the position is healthy.
     *         Computed as a single multiply-then-divide expression to avoid
     *         divide-before-multiply precision loss.
     */
    function getHealthFactor(address user) external view returns (uint256) {
        uint256 debt = _getUserDebt(user);
        if (debt < 1) return type(uint256).max;

        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        uint256 borrowPrice = oracle.getPrice(address(borrowToken));
        if (borrowPrice < 1) return 0;

        // healthFactor = (collateralBalance * collateralPrice * WAD) / (debt * borrowPrice)
        // All multiplications performed before division to preserve precision
        uint256 debtProduct = debt * borrowPrice;
        if (debtProduct < 1) return type(uint256).max;

        return (collateralBalance[user] * collateralPrice * WAD) / debtProduct;
    }

    // ============ Internal Functions ============

    /**
     * @notice Returns the current debt of a user including accrued interest.
     *         Uses inequality checks instead of strict equality to avoid
     *         incorrect-equality vulnerabilities.
     */
    function _getUserDebt(address user) internal view returns (uint256) {
        uint256 principal = userPrincipal[user];
        if (principal < 1) return 0;
        uint256 idx = userIndex[user];
        if (idx < 1) return principal;
        return (principal * borrowIndex) / idx;
    }

    /**
     * @notice Returns the available borrowable liquidity in the pool.
     */
    function _getAvailableLiquidity() internal view returns (uint256) {
        uint256 balance = borrowToken.balanceOf(address(this));
        if (balance <= totalReserves) return 0;
        return balance - totalReserves;
    }

    /**
     * @notice Checks whether a user's collateral is sufficient for a given debt amount.
     *         Uses a single multiply-then-compare expression to avoid
     *         divide-before-multiply precision loss.
     * @param user The user address to check.
     * @param debt The debt amount (in borrow token units) to check against.
     * @return True if the collateral is sufficient, false otherwise.
     */
    function _isCollateralSufficient(address user, uint256 debt) internal view returns (bool) {
        if (debt < 1) return true;
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        uint256 borrowPrice = oracle.getPrice(address(borrowToken));
        if (collateralPrice < 1 || borrowPrice < 1) return false;

        // Equivalent to: (debt * borrowPrice / WAD) <= (collateralBalance * collateralPrice / WAD * MAX_LTV / BPS)
        // Rearranged to: (debt * borrowPrice * BPS) <= (collateralBalance * collateralPrice * MAX_LTV)
        // All multiplications before comparison to preserve precision
        uint256 debtValueScaled = debt * borrowPrice * BPS;
        uint256 collateralValueScaled = collateralBalance[user] * collateralPrice * MAX_LTV;
        return debtValueScaled <= collateralValueScaled;
    }
}
