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

/**
 * @title LendingPool
 * @notice A pool-based lending facility that custodies supplied digital assets.
 *         Users can supply assets to earn interest, borrow against their collateral,
 *         repay outstanding loans, and withdraw unencumbered deposits.
 * @dev    Uses share-based accounting with cumulative interest indices. A global
 *         75% maximum loan-to-value ratio is enforced on every borrow and withdraw.
 *         A 0.05% origination fee is charged on all new borrows and accrued to the
 *         asset's fee reserve, withdrawable by the operator.
 */
contract LendingPool {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant MAX_LTV_BPS = 7500;            // 75.00%
    uint256 public constant ORIGINATION_FEE_BPS = 5;       // 0.05%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant INDEX_SCALE = 1e18;

    // ---------------------------------------------------------------------
    // Structures
    // ---------------------------------------------------------------------

    struct AssetData {
        uint256 annualSupplyRateBPS;     // annual supply APR in basis points
        uint256 annualBorrowRateBPS;     // annual borrow APR in basis points
        uint256 liquidationThresholdBPS; // per-asset liquidation threshold in basis points
        uint256 price;                   // asset price in base currency (1e18 scale)
        uint256 supplyIndex;             // cumulative supply index (starts at INDEX_SCALE)
        uint256 borrowIndex;             // cumulative borrow index (starts at INDEX_SCALE)
        uint256 lastUpdateTimestamp;     // last interest accrual timestamp
        uint256 totalSupplyShares;       // total outstanding supply shares
        uint256 totalBorrowShares;       // total outstanding borrow shares
        uint256 accumulatedFees;         // collected origination fees in asset units
        bool isActive;                   // whether the asset is registered and active
    }

    struct UserAssetData {
        uint256 supplyShares;       // user's supply shares for the asset
        uint256 borrowShares;       // user's borrow shares for the asset
        uint256 lastSupplyIndex;    // informative: index at last supply/withdraw
        uint256 lastBorrowIndex;    // informative: index at last borrow/repay
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    address public operator;

    mapping(address => AssetData) public assets;
    mapping(address => mapping(address => UserAssetData)) public userAssetData;

    address[] public assetList;
    mapping(address => uint256) internal _assetIndexPlusOne; // 1-based; 0 means absent

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Supply(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Borrow(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 shares,
        uint256 fee
    );
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event AssetAdded(address indexed asset, uint256 supplyRateBPS, uint256 borrowRateBPS, uint256 thresholdBPS, uint256 price);
    event InterestRatesUpdated(address indexed asset, uint256 supplyRateBPS, uint256 borrowRateBPS);
    event LiquidationThresholdUpdated(address indexed asset, uint256 oldThresholdBPS, uint256 newThresholdBPS);
    event PriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed asset, address indexed recipient, uint256 amount);
    event InterestAccrued(address indexed asset, uint256 newSupplyIndex, uint256 newBorrowIndex, uint256 timestamp);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotInitialized();
    error AssetAlreadyAdded();
    error InvalidRate();
    error InvalidThreshold();
    error InvalidPrice();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error BorrowExceedsMaxLTV();
    error NoBorrowToRepay();
    error NoFees();
    error ReentrancyGuard();
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrancyGuard();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    modifier onlyActiveAsset(address asset) {
        if (!assets[asset].isActive) revert AssetNotInitialized();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        _reentrancyStatus = _NOT_ENTERED;
        emit OperatorUpdated(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    // External: user actions
    // ---------------------------------------------------------------------

    /**
     * @notice Supply an asset to the pool to earn interest.
     * @param asset  The token to supply.
     * @param amount The amount of tokens to supply.
     */
    function supply(address asset, uint256 amount)
        external
        nonReentrant
        onlyActiveAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        accrueInterest(asset);

        AssetData storage aData = assets[asset];
        UserAssetData storage uData = userAssetData[msg.sender][asset];

        // Calculate shares based on the stated amount (not on a post-call balance)
        uint256 shares = (amount * INDEX_SCALE) / aData.supplyIndex;
        if (shares < 1) revert ZeroAmount();

        // Effects: update state before the external transfer (checks-effects-interactions)
        uData.supplyShares += shares;
        uData.lastSupplyIndex = aData.supplyIndex;
        aData.totalSupplyShares += shares;

        // Interactions
        _safeTransferFrom(msg.sender, address(this), asset, amount);

        emit Supply(msg.sender, asset, amount, shares);
    }

    /**
     * @notice Withdraw supplied assets, provided the position remains healthy.
     * @param asset  The token to withdraw.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(address asset, uint256 amount)
        external
        nonReentrant
        onlyActiveAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        accrueInterest(asset);

        AssetData storage aData = assets[asset];
        UserAssetData storage uData = userAssetData[msg.sender][asset];

        uint256 currentBalance = (uData.supplyShares * aData.supplyIndex) / INDEX_SCALE;
        if (currentBalance < amount) revert InsufficientBalance();
        if (IERC20(asset).balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        // Effects: burn shares first (checks-effects-interactions)
        uint256 sharesToBurn = (amount * INDEX_SCALE) / aData.supplyIndex;
        uData.supplyShares -= sharesToBurn;
        aData.totalSupplyShares -= sharesToBurn;

        // Validate collateral health after withdrawal
        if (!_isPositionHealthy(msg.sender)) revert InsufficientCollateral();

        // Interactions
        _safeTransfer(msg.sender, asset, amount);

        emit Withdraw(msg.sender, asset, amount, sharesToBurn);
    }

    /**
     * @notice Borrow an asset against supplied collateral. A 0.05% origination
     *         fee is added to the debt principal and accrued to the fee reserve.
     * @param asset  The token to borrow.
     * @param amount The amount of tokens to borrow.
     */
    function borrow(address asset, uint256 amount)
        external
        nonReentrant
        onlyActiveAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        accrueInterest(asset);

        AssetData storage aData = assets[asset];

        if (IERC20(asset).balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        uint256 fee = (amount * ORIGINATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 debtIncrease = amount + fee;

        // Validate collateral against projected debt
        (uint256 totalCollateral, uint256 totalBorrow) = getAccountLiquidity(msg.sender);
        uint256 newBorrowValue = (debtIncrease * aData.price) / INDEX_SCALE;
        uint256 projectedBorrow = totalBorrow + newBorrowValue;

        if (totalCollateral == 0) revert InsufficientCollateral();
        if (projectedBorrow > (totalCollateral * MAX_LTV_BPS) / BPS_DENOMINATOR) {
            revert BorrowExceedsMaxLTV();
        }

        // Effects: mint borrow shares
        uint256 borrowShares = (debtIncrease * INDEX_SCALE) / aData.borrowIndex;
        UserAssetData storage uData = userAssetData[msg.sender][asset];
        uData.borrowShares += borrowShares;
        uData.lastBorrowIndex = aData.borrowIndex;
        aData.totalBorrowShares += borrowShares;
        aData.accumulatedFees += fee;

        // Interactions: transfer principal (net of fee) to borrower
        _safeTransfer(msg.sender, asset, amount);

        emit Borrow(msg.sender, asset, amount, borrowShares, fee);
    }

    /**
     * @notice Repay an outstanding loan. Excess payment beyond debt is returned
     *         to the caller (only the exact debt is taken).
     * @param asset  The token to repay.
     * @param amount The amount of tokens to repay.
     */
    function repay(address asset, uint256 amount)
        external
        nonReentrant
        onlyActiveAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        accrueInterest(asset);

        AssetData storage aData = assets[asset];
        UserAssetData storage uData = userAssetData[msg.sender][asset];

        uint256 currentDebt = (uData.borrowShares * aData.borrowIndex) / INDEX_SCALE;
        if (currentDebt == 0) revert NoBorrowToRepay();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        // Effects: burn borrow shares proportionally before the external call
        uint256 sharesToRepay = (repayAmount * INDEX_SCALE) / aData.borrowIndex;
        if (sharesToRepay > uData.borrowShares) sharesToRepay = uData.borrowShares;
        uData.borrowShares -= sharesToRepay;
        aData.totalBorrowShares -= sharesToRepay;

        // Interactions
        _safeTransferFrom(msg.sender, address(this), asset, repayAmount);

        emit Repay(msg.sender, asset, repayAmount, sharesToRepay);
    }

    // ---------------------------------------------------------------------
    // Public: interest accrual
    // ---------------------------------------------------------------------

    /**
     * @notice Accrue interest for a given asset using a linear model.
     * @param asset The asset address.
     */
    function accrueInterest(address asset) public onlyActiveAsset(asset) {
        AssetData storage aData = assets[asset];

        if (block.timestamp <= aData.lastUpdateTimestamp) return;

        uint256 timeDelta = block.timestamp - aData.lastUpdateTimestamp;

        uint256 supplyFactor =
            (aData.annualSupplyRateBPS * timeDelta * INDEX_SCALE) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        uint256 borrowFactor =
            (aData.annualBorrowRateBPS * timeDelta * INDEX_SCALE) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);

        aData.supplyIndex = (aData.supplyIndex * (INDEX_SCALE + supplyFactor)) / INDEX_SCALE;
        aData.borrowIndex = (aData.borrowIndex * (INDEX_SCALE + borrowFactor)) / INDEX_SCALE;
        aData.lastUpdateTimestamp = block.timestamp;

        emit InterestAccrued(asset, aData.supplyIndex, aData.borrowIndex, block.timestamp);
    }

    // ---------------------------------------------------------------------
    // Public: account liquidity views
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the total collateral and borrow values (in base currency,
     *         1e18 scale) for a user across all registered assets.
     */
    function getAccountLiquidity(address user)
        public
        view
        returns (uint256 totalCollateral, uint256 totalBorrow)
    {
        for (uint256 i = 0; i < assetList.length; i++) {
            address asset = assetList[i];
            AssetData storage aData = assets[asset];
            UserAssetData storage uData = userAssetData[user][asset];

            // Multiply before dividing to avoid precision loss
            if (uData.supplyShares > 0) {
                uint256 supplyValue = (uData.supplyShares * aData.supplyIndex * aData.price) / (INDEX_SCALE * INDEX_SCALE);
                totalCollateral += supplyValue;
            }
            if (uData.borrowShares > 0) {
                uint256 borrowValue = (uData.borrowShares * aData.borrowIndex * aData.price) / (INDEX_SCALE * INDEX_SCALE);
                totalBorrow += borrowValue;
            }
        }
    }

    /**
     * @notice Returns a user's supply balance for a specific asset, including
     *         accrued interest.
     */
    function supplyBalanceOf(address user, address asset) public view returns (uint256) {
        AssetData storage aData = assets[asset];
        if (!aData.isActive) return 0;
        return (userAssetData[user][asset].supplyShares * aData.supplyIndex) / INDEX_SCALE;
    }

    /**
     * @notice Returns a user's borrow balance for a specific asset, including
     *         accrued interest.
     */
    function borrowBalanceOf(address user, address asset) public view returns (uint256) {
        AssetData storage aData = assets[asset];
        if (!aData.isActive) return 0;
        return (userAssetData[user][asset].borrowShares * aData.borrowIndex) / INDEX_SCALE;
    }

    /**
     * @notice Health factor: (collateral * MAX_LTV) / debt, in 1e18 scale.
     *         A value >= 1e18 indicates a healthy position.
     */
    function healthFactor(address user) external view returns (uint256) {
        (uint256 totalCollateral, uint256 totalBorrow) = getAccountLiquidity(user);
        if (totalBorrow == 0) return type(uint256).max;
        return (totalCollateral * MAX_LTV_BPS * INDEX_SCALE) / (totalBorrow * BPS_DENOMINATOR);
    }

    /**
     * @notice Number of registered assets.
     */
    function assetCount() external view returns (uint256) {
        return assetList.length;
    }

    // ---------------------------------------------------------------------
    // Operator: asset management
    // ---------------------------------------------------------------------

    /**
     * @notice Register a new asset with its initial configuration.
     */
    function addAsset(
        address asset,
        uint256 annualSupplyRateBPS,
        uint256 annualBorrowRateBPS,
        uint256 liquidationThresholdBPS,
        uint256 initialPrice
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (assets[asset].isActive) revert AssetAlreadyAdded();
        if (annualSupplyRateBPS > BPS_DENOMINATOR || annualBorrowRateBPS > BPS_DENOMINATOR) {
            revert InvalidRate();
        }
        if (liquidationThresholdBPS > BPS_DENOMINATOR) revert InvalidThreshold();
        if (initialPrice == 0) revert InvalidPrice();

        AssetData storage aData = assets[asset];
        aData.annualSupplyRateBPS = annualSupplyRateBPS;
        aData.annualBorrowRateBPS = annualBorrowRateBPS;
        aData.liquidationThresholdBPS = liquidationThresholdBPS;
        aData.price = initialPrice;
        aData.supplyIndex = INDEX_SCALE;
        aData.borrowIndex = INDEX_SCALE;
        aData.lastUpdateTimestamp = block.timestamp;
        aData.isActive = true;

        assetList.push(asset);
        _assetIndexPlusOne[asset] = assetList.length;

        emit AssetAdded(asset, annualSupplyRateBPS, annualBorrowRateBPS, liquidationThresholdBPS, initialPrice);
    }

    /**
     * @notice Update the supply and borrow interest rates for an asset.
     */
    function setInterestRates(
        address asset,
        uint256 annualSupplyRateBPS,
        uint256 annualBorrowRateBPS
    ) external onlyOperator onlyActiveAsset(asset) {
        if (annualSupplyRateBPS > BPS_DENOMINATOR || annualBorrowRateBPS > BPS_DENOMINATOR) {
            revert InvalidRate();
        }
        accrueInterest(asset);
        AssetData storage aData = assets[asset];
        aData.annualSupplyRateBPS = annualSupplyRateBPS;
        aData.annualBorrowRateBPS = annualBorrowRateBPS;
        emit InterestRatesUpdated(asset, annualSupplyRateBPS, annualBorrowRateBPS);
    }

    /**
     * @notice Update the liquidation threshold for an asset.
     */
    function setLiquidationThreshold(address asset, uint256 liquidationThresholdBPS)
        external
        onlyOperator
        onlyActiveAsset(asset)
    {
        if (liquidationThresholdBPS > BPS_DENOMINATOR) revert InvalidThreshold();
        AssetData storage aData = assets[asset];
        uint256 old = aData.liquidationThresholdBPS;
        aData.liquidationThresholdBPS = liquidationThresholdBPS;
        emit LiquidationThresholdUpdated(asset, old, liquidationThresholdBPS);
    }

    /**
     * @notice Update the price of an asset.
     */
    function setPrice(address asset, uint256 price)
        external
        onlyOperator
        onlyActiveAsset(asset)
    {
        if (price == 0) revert InvalidPrice();
        AssetData storage aData = assets[asset];
        uint256 old = aData.price;
        aData.price = price;
        emit PriceUpdated(asset, old, price);
    }

    /**
     * @notice Transfer the operator role to a new address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Withdraw accumulated origination fees for an asset.
     */
    function withdrawFees(address asset) external onlyOperator onlyActiveAsset(asset) {
        AssetData storage aData = assets[asset];
        uint256 fees = aData.accumulatedFees;
        if (fees == 0) revert NoFees();
        aData.accumulatedFees = 0;
        _safeTransfer(operator, asset, fees);
        emit FeesWithdrawn(asset, operator, fees);
    }

    // ---------------------------------------------------------------------
    // Internal: health check
    // ---------------------------------------------------------------------

    /**
     * @dev Validates that the user's total debt does not exceed MAX_LTV of
     *      their total collateral, using current (non-accrued) indices. This
     *      is conservative because interest accrual only increases debt.
     */
    function _isPositionHealthy(address user) internal view returns (bool) {
        (uint256 totalCollateral, uint256 totalBorrow) = getAccountLiquidity(user);
        if (totalBorrow == 0) return true;
        if (totalCollateral == 0) return false;
        uint256 maxBorrow = (totalCollateral * MAX_LTV_BPS) / BPS_DENOMINATOR;
        return totalBorrow <= maxBorrow;
    }

    // ---------------------------------------------------------------------
    // Internal: safe ERC20 transfers
    // ---------------------------------------------------------------------

    function _safeTransfer(address to, address asset, uint256 amount) internal {
        (bool ok, bytes memory data) =
            asset.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address from, address to, address asset, uint256 amount) internal {
        (bool ok, bytes memory data) =
            asset.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
