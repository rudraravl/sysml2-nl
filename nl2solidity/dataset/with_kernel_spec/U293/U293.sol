//
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

interface IPriceFeed {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract LendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------------------------

    uint256 public constant MAX_LTV_BPS = 7500;            // 75% maximum loan-to-value
    uint256 public constant LIQUIDATION_PENALTY_BPS = 500; // 5% liquidation bonus on seized collateral
    uint256 public constant CLOSE_FACTOR_BPS = 5000;       // 50% of debt repayable per liquidation
    uint256 public constant BPS = 10000;
    uint256 public constant INDEX_PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant PRICE_STALENESS = 1 hours;

    // -----------------------------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------------------------

    error AssetNotSupported();
    error AssetAlreadySupported();
    error AmountZero();
    error InsufficientLiquidity();
    error ExceedsMaxLTV();
    error BorrowingPaused();
    error LiquidationPaused();
    error NotOperator();
    error ZeroAddress();
    error PositionHealthy();
    error InvalidLiquidation();
    error RepayExceedsDebt();
    error WithdrawExceedsAvailable();
    error StalePrice();
    error NegativePrice();
    error LTVTooHigh();
    error LiquidationThresholdInvalid();
    error NotEnoughCollateralForSeize();
    error RateTooHigh();
    error InvalidFeedDecimals();

    // -----------------------------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------------------------

    struct AssetConfig {
        bool supported;
        uint8 decimals;
        uint256 ltvBps;                   // max loan-to-value in bps (<= MAX_LTV_BPS)
        uint256 liquidationThresholdBps;  // liquidation threshold in bps (>= ltvBps, <= BPS)
        address priceFeed;                // Chainlink-style price feed
    }

    struct AssetState {
        uint256 borrowIndex;     // accumulated borrow index (INDEX_PRECISION)
        uint256 lastAccrual;     // last timestamp interest was accrued
        uint256 ratePerSecond;   // per-second borrow rate (INDEX_PRECISION)
        uint256 totalScaledDebt; // total scaled principal debt across all borrowers
    }

    // -----------------------------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------------------------

    address public operator;
    bool public borrowingPaused;
    bool public liquidationPaused;

    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => AssetState) public assetStates;
    address[] public supportedAssets;

    /// @dev user => asset => deposited collateral balance (in asset base units)
    mapping(address => mapping(address => uint256)) public deposits;
    /// @dev user => asset => scaled principal debt (debt = scaled * borrowIndex / INDEX_PRECISION)
    mapping(address => mapping(address => uint256)) public scaledDebt;

    // -----------------------------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------------------------

    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 timestamp);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 debtIndex, uint256 timestamp);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 debtIndex, uint256 timestamp);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        address indexed debtAsset,
        address collateralAsset,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 timestamp
    );
    event AssetAdded(
        address indexed asset,
        uint8 decimals,
        uint256 ltvBps,
        uint256 liquidationThresholdBps,
        address indexed priceFeed
    );
    event InterestRateModelUpdated(address indexed asset, uint256 newRatePerSecond);
    event LiquidationThresholdUpdated(address indexed asset, uint256 newThresholdBps);
    event LTVUpdated(address indexed asset, uint256 newLtvBps);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event BorrowingPausedChanged(bool paused);
    event LiquidationPausedChanged(bool paused);

    // -----------------------------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------------------------

    modifier onlyOperatorRole() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!assetConfigs[asset].supported) revert AssetNotSupported();
        _;
    }

    // -----------------------------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------------------------

    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(address(0), _operator);
    }

    // -----------------------------------------------------------------------------------------
    // Admin functions
    // -----------------------------------------------------------------------------------------

    /**
     * @notice Adds a new supported asset to the pool.
     * @param asset                    The ERC20 token address.
     * @param decimals                 Token decimals (used for USD normalization).
     * @param ltvBps                   Loan-to-value ratio in bps (cannot exceed MAX_LTV_BPS).
     * @param liquidationThresholdBps Liquidation threshold in bps (>= ltvBps, <= BPS).
     * @param priceFeed                Chainlink-style price feed for the asset.
     * @param annualRateBps            Annual borrow rate in bps (e.g. 500 = 5% APR).
     */
    function addAsset(
        address asset,
        uint8 decimals,
        uint256 ltvBps,
        uint256 liquidationThresholdBps,
        address priceFeed,
        uint256 annualRateBps
    ) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (priceFeed == address(0)) revert ZeroAddress();
        if (assetConfigs[asset].supported) revert AssetAlreadySupported();
        if (ltvBps == 0 || ltvBps > MAX_LTV_BPS) revert LTVTooHigh();
        if (liquidationThresholdBps < ltvBps || liquidationThresholdBps > BPS) {
            revert LiquidationThresholdInvalid();
        }
        if (annualRateBps > BPS) revert RateTooHigh();

        uint8 feedDecimals = IPriceFeed(priceFeed).decimals();
        if (feedDecimals > 18) revert InvalidFeedDecimals();
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = IPriceFeed(priceFeed).latestRoundData();
        if (answer <= 0) revert NegativePrice();
        if (updatedAt == 0 || block.timestamp < updatedAt) revert StalePrice();
        if (answeredInRound < roundId) revert StalePrice();

        assetConfigs[asset] = AssetConfig({
            supported: true,
            decimals: decimals,
            ltvBps: ltvBps,
            liquidationThresholdBps: liquidationThresholdBps,
            priceFeed: priceFeed
        });

        assetStates[asset] = AssetState({
            borrowIndex: INDEX_PRECISION,
            lastAccrual: block.timestamp,
            ratePerSecond: (annualRateBps * INDEX_PRECISION) / BPS / SECONDS_PER_YEAR,
            totalScaledDebt: 0
        });

        supportedAssets.push(asset);

        emit AssetAdded(asset, decimals, ltvBps, liquidationThresholdBps, priceFeed);
    }

    /**
     * @notice Updates the borrow rate model for an asset.
     * @param asset         Supported asset.
     * @param annualRateBps New annual borrow rate in bps.
     */
    function setInterestRateModel(address asset, uint256 annualRateBps)
        external
        onlyOwner
        onlySupportedAsset(asset)
    {
        if (annualRateBps > BPS) revert RateTooHigh();
        _accrueAsset(asset);
        uint256 newRate = (annualRateBps * INDEX_PRECISION) / BPS / SECONDS_PER_YEAR;
        assetStates[asset].ratePerSecond = newRate;
        emit InterestRateModelUpdated(asset, newRate);
    }

    /**
     * @notice Updates the liquidation threshold for an asset.
     */
    function setLiquidationThreshold(address asset, uint256 newThresholdBps)
        external
        onlyOwner
        onlySupportedAsset(asset)
    {
        if (newThresholdBps < assetConfigs[asset].ltvBps || newThresholdBps > BPS) {
            revert LiquidationThresholdInvalid();
        }
        assetConfigs[asset].liquidationThresholdBps = newThresholdBps;
        emit LiquidationThresholdUpdated(asset, newThresholdBps);
    }

    /**
     * @notice Updates the loan-to-value ratio for an asset (capped at MAX_LTV_BPS).
     */
    function setLTV(address asset, uint256 newLtvBps) external onlyOwner onlySupportedAsset(asset) {
        if (newLtvBps == 0 || newLtvBps > MAX_LTV_BPS) revert LTVTooHigh();
        if (newLtvBps > assetConfigs[asset].liquidationThresholdBps) revert LiquidationThresholdInvalid();
        assetConfigs[asset].ltvBps = newLtvBps;
        emit LTVUpdated(asset, newLtvBps);
    }

    /**
     * @notice Updates the designated operator (who may pause borrow/liquidations).
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Pauses or unpauses borrowing.
     */
    function setBorrowingPaused(bool paused) external onlyOperatorRole {
        borrowingPaused = paused;
        emit BorrowingPausedChanged(paused);
    }

    /**
     * @notice Pauses or unpauses liquidations.
     */
    function setLiquidationPaused(bool paused) external onlyOperatorRole {
        liquidationPaused = paused;
        emit LiquidationPausedChanged(paused);
    }

    // -----------------------------------------------------------------------------------------
    // User actions
    // -----------------------------------------------------------------------------------------

    /**
     * @notice Deposits `amount` of `asset` as collateral.
     */
    function deposit(address asset, uint256 amount) external nonReentrant onlySupportedAsset(asset) {
        if (amount == 0) revert AmountZero();
        // effects before interactions
        deposits[msg.sender][asset] += amount;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, asset, amount, block.timestamp);
    }

    /**
     * @notice Withdraws `amount` of `asset` provided the position remains healthy.
     */
    function withdraw(address asset, uint256 amount) external nonReentrant onlySupportedAsset(asset) {
        if (amount == 0) revert AmountZero();
        if (deposits[msg.sender][asset] < amount) revert WithdrawExceedsAvailable();

        // effects before interactions
        deposits[msg.sender][asset] -= amount;

        (, uint256 debtUSD, ) = getAccountLiquidity(msg.sender);
        if (debtUSD > 0) {
            uint256 maxBorrowUSD = _maxBorrowUSD(msg.sender);
            if (debtUSD > maxBorrowUSD) revert ExceedsMaxLTV();
        }

        IERC20(asset).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, asset, amount, block.timestamp);
    }

    /**
     * @notice Borrows `amount` of `asset` against the caller's collateral.
     */
    function borrow(address asset, uint256 amount) external nonReentrant onlySupportedAsset(asset) {
        if (borrowingPaused) revert BorrowingPaused();
        if (amount == 0) revert AmountZero();

        _accrueAsset(asset);
        AssetState storage s = assetStates[asset];

        (, , uint256 availableUSD) = getAccountLiquidity(msg.sender);
        uint256 borrowUSD = (amount * _getPrice(asset)) / (10 ** assetConfigs[asset].decimals);
        if (borrowUSD > availableUSD) revert ExceedsMaxLTV();

        // effects before interactions
        uint256 scaledIncrease = (amount * INDEX_PRECISION) / s.borrowIndex;
        scaledDebt[msg.sender][asset] += scaledIncrease;
        s.totalScaledDebt += scaledIncrease;

        if (IERC20(asset).balanceOf(address(this)) < amount) {
            revert InsufficientLiquidity();
        }

        IERC20(asset).safeTransfer(msg.sender, amount);
        emit Borrow(msg.sender, asset, amount, s.borrowIndex, block.timestamp);
    }

    /**
     * @notice Repays up to `amount` of the caller's outstanding debt in `asset`.
     */
    function repay(address asset, uint256 amount) external nonReentrant onlySupportedAsset(asset) {
        if (amount == 0) revert AmountZero();

        _accrueAsset(asset);
        AssetState storage s = assetStates[asset];

        uint256 debt = (scaledDebt[msg.sender][asset] * s.borrowIndex) / INDEX_PRECISION;
        if (debt == 0) revert RepayExceedsDebt();
        uint256 repay = amount > debt ? debt : amount;

        uint256 scaledRepay = _ceilDiv(repay * INDEX_PRECISION, s.borrowIndex);
        if (scaledRepay > scaledDebt[msg.sender][asset]) {
            scaledRepay = scaledDebt[msg.sender][asset];
        }

        // effects before interactions
        scaledDebt[msg.sender][asset] -= scaledRepay;
        s.totalScaledDebt -= scaledRepay;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repay);
        emit Repay(msg.sender, asset, repay, s.borrowIndex, block.timestamp);
    }

    /**
     * @notice Liquidates an unhealthy position by repaying debt and seizing collateral.
     * @param borrower        The owner of the unhealthy position.
     * @param debtAsset       The asset whose debt is being repaid.
     * @param collateralAsset The collateral asset to seize.
     * @param repayAmount     The amount of debt to repay (capped by close factor).
     */
    function liquidate(
        address borrower,
        address debtAsset,
        address collateralAsset,
        uint256 repayAmount
    ) external nonReentrant {
        if (liquidationPaused) revert LiquidationPaused();
        if (!assetConfigs[debtAsset].supported || !assetConfigs[collateralAsset].supported) {
            revert AssetNotSupported();
        }
        if (repayAmount == 0) revert AmountZero();
        if (borrower == address(0)) revert ZeroAddress();

        _accrueAsset(debtAsset);
        uint256 repay = _computeRepay(borrower, debtAsset, repayAmount);

        (, uint256 debtUSD, ) = getAccountLiquidity(borrower);
        if (debtUSD <= _liquidationThresholdUSD(borrower)) revert PositionHealthy();

        uint256 seizeAmount = _computeSeizeAmount(repay, debtAsset, collateralAsset);
        if (seizeAmount == 0) revert InvalidLiquidation();
        if (deposits[borrower][collateralAsset] < seizeAmount) revert NotEnoughCollateralForSeize();

        _executeLiquidation(msg.sender, borrower, debtAsset, collateralAsset, repay, seizeAmount);
    }

    // -----------------------------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------------------------

    function supportedAssetsLength() external view returns (uint256) {
        return supportedAssets.length;
    }

    /**
     * @notice Returns the current (accrued) debt of `user` in `asset`.
     */
    function getDebt(address user, address asset) external view returns (uint256) {
        return _currentDebt(user, asset);
    }

    /**
     * @notice Returns the current total debt of `asset` across all borrowers.
     */
    function totalDebt(address asset) external view returns (uint256) {
        return (assetStates[asset].totalScaledDebt * _projectedIndex(asset)) / INDEX_PRECISION;
    }

    /**
     * @notice Computes the account's collateral value, debt value, and available
     *         borrowing capacity (all in USD with 18 decimals of precision).
     */
    function getAccountLiquidity(address user)
        public
        view
        returns (uint256 collateralUSD, uint256 debtUSD, uint256 availableUSD)
    {
        for (uint256 i = 0; i < supportedAssets.length; ++i) {
            address asset = supportedAssets[i];
            (uint256 col, uint256 dbt) = _assetUSD(user, asset);
            collateralUSD += col;
            debtUSD += dbt;
        }
        uint256 maxBorrow = _maxBorrowUSD(user);
        if (maxBorrow > debtUSD) {
            availableUSD = maxBorrow - debtUSD;
        }
    }

    /**
     * @notice Returns the position's health factor (collateral*threshold / debt). A value
     *         below 1e18 indicates the position is eligible for liquidation.
     */
    function getHealthFactor(address user) external view returns (uint256) {
        (, uint256 debtUSD, ) = getAccountLiquidity(user);
        if (debtUSD < 1) return type(uint256).max;
        uint256 ltUSD = _liquidationThresholdUSD(user);
        return (ltUSD * INDEX_PRECISION) / debtUSD;
    }

    // -----------------------------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------------------------

    function _assetUSD(address user, address asset)
        internal
        view
        returns (uint256 collateralUSD, uint256 debtUSD)
    {
        uint256 dep = deposits[user][asset];
        uint256 dbt = _currentDebt(user, asset);
        uint256 unit = 10 ** assetConfigs[asset].decimals;
        bool priceFetched;
        uint256 price;
        if (dep > 0) {
            price = _getPrice(asset);
            priceFetched = true;
            collateralUSD = (dep * price) / unit;
        }
        if (dbt > 0) {
            if (!priceFetched) {
                price = _getPrice(asset);
            }
            debtUSD = (dbt * price) / unit;
        }
    }

    function _computeRepay(address borrower, address debtAsset, uint256 repayAmount)
        internal
        view
        returns (uint256)
    {
        AssetState storage ds = assetStates[debtAsset];
        uint256 debt = (scaledDebt[borrower][debtAsset] * ds.borrowIndex) / INDEX_PRECISION;
        if (debt == 0) revert InvalidLiquidation();
        uint256 repay = repayAmount > debt ? debt : repayAmount;
        // Compute maxRepay directly from raw values to avoid divide-before-multiply precision loss.
        uint256 maxRepay =
            (scaledDebt[borrower][debtAsset] * ds.borrowIndex * CLOSE_FACTOR_BPS) / (INDEX_PRECISION * BPS);
        if (repay > maxRepay) repay = maxRepay;
        if (repay == 0) revert InvalidLiquidation();
        return repay;
    }

    function _computeSeizeAmount(uint256 repay, address debtAsset, address collateralAsset)
        internal
        view
        returns (uint256)
    {
        uint256 debtPrice = _getPrice(debtAsset);
        uint256 colPrice = _getPrice(collateralAsset);
        uint256 debtUnit = 10 ** assetConfigs[debtAsset].decimals;
        uint256 colUnit = 10 ** assetConfigs[collateralAsset].decimals;
        // Combine all multiplications before divisions to avoid divide-before-multiply.
        return (repay * debtPrice * (BPS + LIQUIDATION_PENALTY_BPS) * colUnit) / (debtUnit * BPS * colPrice);
    }

    function _executeLiquidation(
        address liquidator,
        address borrower,
        address debtAsset,
        address collateralAsset,
        uint256 repay,
        uint256 seizeAmount
    ) internal {
        AssetState storage ds = assetStates[debtAsset];

        uint256 scaledRepay = _ceilDiv(repay * INDEX_PRECISION, ds.borrowIndex);
        if (scaledRepay > scaledDebt[borrower][debtAsset]) {
            scaledRepay = scaledDebt[borrower][debtAsset];
        }

        // effects before interactions
        scaledDebt[borrower][debtAsset] -= scaledRepay;
        ds.totalScaledDebt -= scaledRepay;
        deposits[borrower][collateralAsset] -= seizeAmount;

        IERC20(debtAsset).safeTransferFrom(liquidator, address(this), repay);
        IERC20(collateralAsset).safeTransfer(liquidator, seizeAmount);

        emit Liquidate(liquidator, borrower, debtAsset, collateralAsset, repay, seizeAmount, block.timestamp);
    }

    function _accrueAsset(address asset) internal {
        AssetState storage s = assetStates[asset];
        if (s.lastAccrual == 0) {
            s.lastAccrual = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - s.lastAccrual;
        // Multiplying by zero elapsed yields zero interest; no strict-equality guard required.
        s.borrowIndex = s.borrowIndex + ((s.borrowIndex * s.ratePerSecond * elapsed) / INDEX_PRECISION);
        s.lastAccrual = block.timestamp;
    }

    function _projectedIndex(address asset) internal view returns (uint256) {
        AssetState storage s = assetStates[asset];
        if (s.lastAccrual == 0) return INDEX_PRECISION;
        uint256 elapsed = block.timestamp - s.lastAccrual;
        return s.borrowIndex + ((s.borrowIndex * s.ratePerSecond * elapsed) / INDEX_PRECISION);
    }

    function _currentDebt(address user, address asset) internal view returns (uint256) {
        return (scaledDebt[user][asset] * _projectedIndex(asset)) / INDEX_PRECISION;
    }

    function _maxBorrowUSD(address user) internal view returns (uint256 total) {
        for (uint256 i = 0; i < supportedAssets.length; ++i) {
            address asset = supportedAssets[i];
            uint256 dep = deposits[user][asset];
            if (dep == 0) continue;
            uint256 price = _getPrice(asset);
            uint256 unit = 10 ** assetConfigs[asset].decimals;
            // Multiply before dividing to avoid divide-before-multiply precision loss.
            total += (dep * price * assetConfigs[asset].ltvBps) / (unit * BPS);
        }
    }

    function _liquidationThresholdUSD(address user) internal view returns (uint256 total) {
        for (uint256 i = 0; i < supportedAssets.length; ++i) {
            address asset = supportedAssets[i];
            uint256 dep = deposits[user][asset];
            if (dep == 0) continue;
            uint256 price = _getPrice(asset);
            uint256 unit = 10 ** assetConfigs[asset].decimals;
            // Multiply before dividing to avoid divide-before-multiply precision loss.
            total += (dep * price * assetConfigs[asset].liquidationThresholdBps) / (unit * BPS);
        }
    }

    function _getPrice(address asset) internal view returns (uint256) {
        AssetConfig storage c = assetConfigs[asset];
        IPriceFeed feed = IPriceFeed(c.priceFeed);
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();
        if (answer <= 0) revert NegativePrice();
        if (updatedAt == 0 || block.timestamp < updatedAt) revert StalePrice();
        if (block.timestamp - updatedAt > PRICE_STALENESS) revert StalePrice();
        if (answeredInRound < roundId) revert StalePrice();
        uint8 feedDecimals = feed.decimals();
        if (feedDecimals > 18) revert InvalidFeedDecimals();
        // Normalize to 18-decimal USD precision.
        return uint256(int256(answer)) * (10 ** (18 - feedDecimals));
    }

    function _ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) return 0;
        return (a + b - 1) / b;
    }
}
