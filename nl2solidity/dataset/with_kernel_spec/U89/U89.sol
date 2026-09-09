// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

contract LendingPool {
    // ============ Constants ============
    uint256 public constant MAX_LTV_BPS = 7500;
    uint256 public constant ORIGINATION_FEE_BPS = 10;
    uint256 public constant LIQUIDATION_BONUS_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant RAY = 1e18;

    // ============ Access Control & Reentrancy ============
    address public owner;
    address public operator;
    address public feeRecipient;
    IPriceOracle public priceOracle;
    bool private _locked;

    // ============ Asset Pool State ============
    struct AssetPool {
        bool supported;
        uint8 decimals;
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 totalBorrowShares;
        uint256 borrowIndex;
        uint256 lastAccrual;
        uint256 interestRatePerSecond;
        uint256 liquidationThresholdBps;
    }

    struct UserPosition {
        uint256 collateral;
        uint256 borrowShares;
    }

    struct AccountData {
        uint256 totalCollateralUSD;
        uint256 totalDebtUSD;
        uint256 maxBorrowUSD;
        uint256 liquidatableCollateralUSD;
        uint256 healthFactor;
    }

    mapping(address => AssetPool) public pools;
    mapping(address => mapping(address => UserPosition)) public userPositions;
    mapping(address => address[]) internal _userCollateralAssets;
    mapping(address => mapping(address => bool)) internal _isCollateralAsset;
    mapping(address => address[]) internal _userBorrowAssets;
    mapping(address => mapping(address => bool)) internal _isBorrowAsset;
    address[] public allAssets;

    // ============ Events ============
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AssetAdded(address indexed asset, uint256 interestRatePerSecond, uint256 liquidationThresholdBps, uint8 decimals);
    event InterestRateUpdated(address indexed asset, uint256 interestRatePerSecond);
    event LiquidationThresholdUpdated(address indexed asset, uint256 liquidationThresholdBps);
    event OperatorSet(address indexed operator);
    event PriceOracleSet(address indexed priceOracle);
    event FeeRecipientSet(address indexed feeRecipient);
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 fee, uint256 shares);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Liquidation(
        address indexed liquidator,
        address indexed user,
        address indexed debtAsset,
        address collateralAsset,
        uint256 debtRepaid,
        uint256 collateralSeized
    );

    // ============ Errors ============
    error NotOwner();
    error NotOperator();
    error NotSupported(address asset);
    error AlreadySupported(address asset);
    error InsufficientLiquidity(address asset, uint256 available, uint256 needed);
    error InsufficientCollateral(address user, uint256 maxBorrowUSD, uint256 totalBorrowUSD);
    error InsufficientCollateralBalance(address user, address asset, uint256 requested, uint256 available);
    error InsufficientDebt(address user, address asset);
    error NotLiquidatable(address user);
    error AmountZero();
    error InvalidLiquidationThreshold(uint256 threshold);
    error PriceOracleNotSet();
    error PriceZero(address asset);
    error ZeroAddress();
    error InvalidDecimals();
    error ReentrantCall();
    error TransferFailed();
    error TransferFromFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    // ============ Constructor ============
    constructor(address _operator, address _priceOracle, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        priceOracle = IPriceOracle(_priceOracle);
        feeRecipient = _feeRecipient;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorSet(_operator);
        if (_priceOracle != address(0)) emit PriceOracleSet(_priceOracle);
        emit FeeRecipientSet(_feeRecipient);
    }

    // ============ Safe Transfer Helpers (from is always msg.sender) ============

    function _safePull(address token, uint256 amount) internal {
        (bool success, bytes memory returndata) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount)
        );
        if (!success) revert TransferFromFailed();
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) revert TransferFromFailed();
    }

    function _safeSend(address token, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) revert TransferFailed();
    }

    // ============ Admin Functions ============

    function addAsset(address asset, uint256 interestRatePerSecond, uint256 liquidationThresholdBps)
        external
        onlyOperator
    {
        if (asset == address(0)) revert ZeroAddress();
        if (pools[asset].supported) revert AlreadySupported(asset);
        if (liquidationThresholdBps < MAX_LTV_BPS || liquidationThresholdBps > BPS_DENOMINATOR) {
            revert InvalidLiquidationThreshold(liquidationThresholdBps);
        }
        uint8 dec = IERC20Metadata(asset).decimals();
        if (dec == 0) revert InvalidDecimals();
        pools[asset] = AssetPool({
            supported: true,
            decimals: dec,
            totalDeposits: 0,
            totalBorrows: 0,
            totalBorrowShares: 0,
            borrowIndex: RAY,
            lastAccrual: block.timestamp,
            interestRatePerSecond: interestRatePerSecond,
            liquidationThresholdBps: liquidationThresholdBps
        });
        allAssets.push(asset);
        emit AssetAdded(asset, interestRatePerSecond, liquidationThresholdBps, dec);
    }

    function setInterestRate(address asset, uint256 interestRatePerSecond) external onlyOperator {
        if (!pools[asset].supported) revert NotSupported(asset);
        _accrueInterest(asset);
        pools[asset].interestRatePerSecond = interestRatePerSecond;
        emit InterestRateUpdated(asset, interestRatePerSecond);
    }

    function setLiquidationThreshold(address asset, uint256 liquidationThresholdBps) external onlyOperator {
        if (!pools[asset].supported) revert NotSupported(asset);
        if (liquidationThresholdBps < MAX_LTV_BPS || liquidationThresholdBps > BPS_DENOMINATOR) {
            revert InvalidLiquidationThreshold(liquidationThresholdBps);
        }
        pools[asset].liquidationThresholdBps = liquidationThresholdBps;
        emit LiquidationThresholdUpdated(asset, liquidationThresholdBps);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
        emit PriceOracleSet(_priceOracle);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientSet(_feeRecipient);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    // ============ User Functions ============

    function deposit(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetPool storage p = pools[asset];
        if (!p.supported) revert NotSupported(asset);
        // Effects before interactions
        p.totalDeposits += amount;
        userPositions[asset][msg.sender].collateral += amount;
        if (!_isCollateralAsset[msg.sender][asset]) {
            _isCollateralAsset[msg.sender][asset] = true;
            _userCollateralAssets[msg.sender].push(asset);
        }
        // Interactions
        _safePull(asset, amount);
        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetPool storage p = pools[asset];
        if (!p.supported) revert NotSupported(asset);
        UserPosition storage pos = userPositions[asset][msg.sender];
        if (pos.collateral < amount) {
            revert InsufficientCollateralBalance(msg.sender, asset, amount, pos.collateral);
        }
        _accrueAllBorrows(msg.sender);
        // Effects before interactions
        pos.collateral -= amount;
        p.totalDeposits -= amount;
        _requireHealthyPosition(msg.sender);
        // Interactions
        _safeSend(asset, msg.sender, amount);
        emit Withdraw(msg.sender, asset, amount);
    }

    function borrow(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetPool storage p = pools[asset];
        if (!p.supported) revert NotSupported(asset);
        _accrueAllBorrows(msg.sender);
        _accrueInterest(asset);

        uint256 available = p.totalDeposits > p.totalBorrows ? p.totalDeposits - p.totalBorrows : 0;
        if (amount > available) revert InsufficientLiquidity(asset, available, amount);

        _checkBorrowCapacity(msg.sender, asset, amount);

        uint256 fee = (amount * ORIGINATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 shares = (amount * RAY) / p.borrowIndex;

        // Effects before interactions
        UserPosition storage pos = userPositions[asset][msg.sender];
        pos.borrowShares += shares;
        p.totalBorrowShares += shares;
        p.totalBorrows = (p.totalBorrowShares * p.borrowIndex) / RAY;

        if (!_isBorrowAsset[msg.sender][asset]) {
            _isBorrowAsset[msg.sender][asset] = true;
            _userBorrowAssets[msg.sender].push(asset);
        }

        // Interactions
        _safeSend(asset, msg.sender, amount - fee);
        if (fee > 0) {
            _safeSend(asset, feeRecipient, fee);
        }

        emit Borrow(msg.sender, asset, amount, fee, shares);
    }

    function repay(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetPool storage p = pools[asset];
        if (!p.supported) revert NotSupported(asset);
        _accrueInterest(asset);

        UserPosition storage pos = userPositions[asset][msg.sender];
        if (pos.borrowShares == 0) revert InsufficientDebt(msg.sender, asset);

        uint256 debt = (pos.borrowShares * p.borrowIndex) / RAY;
        uint256 repayAmount = amount > debt ? debt : amount;
        uint256 shares = (repayAmount * RAY) / p.borrowIndex;

        // Effects before interactions
        pos.borrowShares -= shares;
        p.totalBorrowShares -= shares;
        p.totalBorrows = (p.totalBorrowShares * p.borrowIndex) / RAY;

        // Interactions
        _safePull(asset, repayAmount);
        emit Repay(msg.sender, asset, repayAmount, shares);
    }

    // ============ Liquidation ============

    function liquidate(
        address user,
        address debtAsset,
        uint256 repayAmount,
        address collateralAsset
    ) external onlyOperator nonReentrant {
        if (repayAmount == 0) revert AmountZero();
        if (!pools[debtAsset].supported) revert NotSupported(debtAsset);
        if (!pools[collateralAsset].supported) revert NotSupported(collateralAsset);

        _accrueAllBorrows(user);

        (uint256 liquidatableCollateralUSD, uint256 totalBorrowUSD) = _userLiquidationData(user);
        if (totalBorrowUSD <= liquidatableCollateralUSD) revert NotLiquidatable(user);

        repayAmount = _capRepayAmount(user, debtAsset, repayAmount);
        uint256 seizeAmount = _calcSeizeAmount(debtAsset, repayAmount, collateralAsset, user);

        _executeLiquidation(user, debtAsset, collateralAsset, repayAmount, seizeAmount);
    }

    // ============ Internal Functions ============

    function _checkBorrowCapacity(address user, address asset, uint256 amount) internal view {
        uint256 newBorrowUSD = _usdValue(asset, amount);
        (uint256 maxBorrowUSD, uint256 currentBorrowUSD) = _userBorrowingPower(user);
        if (currentBorrowUSD + newBorrowUSD > maxBorrowUSD) {
            revert InsufficientCollateral(user, maxBorrowUSD, currentBorrowUSD + newBorrowUSD);
        }
    }

    function _capRepayAmount(address user, address debtAsset, uint256 repayAmount) internal view returns (uint256) {
        UserPosition storage dpos = userPositions[debtAsset][user];
        if (dpos.borrowShares == 0) revert InsufficientDebt(user, debtAsset);
        uint256 debt = (dpos.borrowShares * pools[debtAsset].borrowIndex) / RAY;
        if (repayAmount > debt) return debt;
        return repayAmount;
    }

    function _calcSeizeAmount(
        address debtAsset,
        uint256 repayAmount,
        address collateralAsset,
        address user
    ) internal view returns (uint256) {
        uint256 repayUSD = _usdValue(debtAsset, repayAmount);
        uint256 collateralPrice = _assetPrice(collateralAsset);
        // Multiply all numerators before dividing to avoid precision loss from divide-before-multiply
        uint256 seizeAmount = (repayUSD * (BPS_DENOMINATOR + LIQUIDATION_BONUS_BPS) * (10 ** pools[collateralAsset].decimals))
            / (BPS_DENOMINATOR * collateralPrice);
        uint256 userCollateral = userPositions[collateralAsset][user].collateral;
        if (seizeAmount > userCollateral) seizeAmount = userCollateral;
        return seizeAmount;
    }

    function _executeLiquidation(
        address user,
        address debtAsset,
        address collateralAsset,
        uint256 repayAmount,
        uint256 seizeAmount
    ) internal {
        AssetPool storage dp = pools[debtAsset];
        AssetPool storage cp = pools[collateralAsset];

        uint256 shares = (repayAmount * RAY) / dp.borrowIndex;
        // Effects before interactions
        userPositions[debtAsset][user].borrowShares -= shares;
        dp.totalBorrowShares -= shares;
        dp.totalBorrows = (dp.totalBorrowShares * dp.borrowIndex) / RAY;

        userPositions[collateralAsset][user].collateral -= seizeAmount;
        cp.totalDeposits -= seizeAmount;

        // Interactions
        _safePull(debtAsset, repayAmount);
        _safeSend(collateralAsset, msg.sender, seizeAmount);

        emit Liquidation(msg.sender, user, debtAsset, collateralAsset, repayAmount, seizeAmount);
    }

    function _accrueInterest(address asset) internal {
        AssetPool storage p = pools[asset];
        if (block.timestamp <= p.lastAccrual) return;
        if (p.totalBorrowShares == 0) {
            p.lastAccrual = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - p.lastAccrual;
        uint256 factor = p.interestRatePerSecond * elapsed;
        p.borrowIndex = p.borrowIndex + ((p.borrowIndex * factor) / RAY);
        p.totalBorrows = (p.totalBorrowShares * p.borrowIndex) / RAY;
        p.lastAccrual = block.timestamp;
    }

    function _accrueAllBorrows(address user) internal {
        address[] storage borrowAssets = _userBorrowAssets[user];
        for (uint256 i = 0; i < borrowAssets.length; i++) {
            _accrueInterest(borrowAssets[i]);
        }
    }

    function _assetPrice(address asset) internal view returns (uint256) {
        if (address(priceOracle) == address(0)) revert PriceOracleNotSet();
        uint256 price = priceOracle.getPrice(asset);
        if (price == 0) revert PriceZero(asset);
        return price;
    }

    function _usdValue(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = _assetPrice(asset);
        return (amount * price) / (10 ** pools[asset].decimals);
    }

    function _userBorrowingPower(address user)
        internal
        view
        returns (uint256 maxBorrowUSD, uint256 totalBorrowUSD)
    {
        address[] storage collateralAssets = _userCollateralAssets[user];
        for (uint256 i = 0; i < collateralAssets.length; i++) {
            address a = collateralAssets[i];
            uint256 col = userPositions[a][user].collateral;
            if (col == 0) continue;
            uint256 usd = _usdValue(a, col);
            maxBorrowUSD += (usd * MAX_LTV_BPS) / BPS_DENOMINATOR;
        }
        address[] storage borrowAssets = _userBorrowAssets[user];
        for (uint256 i = 0; i < borrowAssets.length; i++) {
            address a = borrowAssets[i];
            AssetPool storage p = pools[a];
            if (p.totalBorrowShares == 0) continue;
            uint256 debt = (userPositions[a][user].borrowShares * p.borrowIndex) / RAY;
            if (debt == 0) continue;
            totalBorrowUSD += _usdValue(a, debt);
        }
    }

    function _userLiquidationData(address user)
        internal
        view
        returns (uint256 liquidatableCollateralUSD, uint256 totalBorrowUSD)
    {
        address[] storage collateralAssets = _userCollateralAssets[user];
        for (uint256 i = 0; i < collateralAssets.length; i++) {
            address a = collateralAssets[i];
            uint256 col = userPositions[a][user].collateral;
            if (col == 0) continue;
            uint256 usd = _usdValue(a, col);
            liquidatableCollateralUSD += (usd * pools[a].liquidationThresholdBps) / BPS_DENOMINATOR;
        }
        address[] storage borrowAssets = _userBorrowAssets[user];
        for (uint256 i = 0; i < borrowAssets.length; i++) {
            address a = borrowAssets[i];
            AssetPool storage p = pools[a];
            if (p.totalBorrowShares == 0) continue;
            uint256 debt = (userPositions[a][user].borrowShares * p.borrowIndex) / RAY;
            if (debt == 0) continue;
            totalBorrowUSD += _usdValue(a, debt);
        }
    }

    function _requireHealthyPosition(address user) internal view {
        (uint256 maxBorrowUSD, uint256 totalBorrowUSD) = _userBorrowingPower(user);
        if (totalBorrowUSD > maxBorrowUSD) {
            revert InsufficientCollateral(user, maxBorrowUSD, totalBorrowUSD);
        }
    }

    // ============ View Functions ============

    function getUserPosition(address user, address asset)
        external
        view
        returns (uint256 collateral, uint256 borrowShares, uint256 currentDebt)
    {
        UserPosition storage pos = userPositions[asset][user];
        collateral = pos.collateral;
        borrowShares = pos.borrowShares;
        if (borrowShares == 0) return (collateral, 0, 0);
        AssetPool storage p = pools[asset];
        uint256 elapsed = block.timestamp > p.lastAccrual ? block.timestamp - p.lastAccrual : 0;
        uint256 currentIndex =
            p.borrowIndex + ((p.borrowIndex * p.interestRatePerSecond * elapsed) / RAY);
        currentDebt = (pos.borrowShares * currentIndex) / RAY;
    }

    function getAssetPool(address asset) external view returns (AssetPool memory) {
        return pools[asset];
    }

    function getAvailableLiquidity(address asset) external view returns (uint256) {
        AssetPool storage p = pools[asset];
        return p.totalDeposits > p.totalBorrows ? p.totalDeposits - p.totalBorrows : 0;
    }

    function isLiquidatable(address user) external view returns (bool) {
        if (address(priceOracle) == address(0)) return false;
        (uint256 liquidatableCollateralUSD, uint256 totalBorrowUSD) = _userLiquidationData(user);
        return totalBorrowUSD > liquidatableCollateralUSD;
    }

    function getUserAccountData(address user) external view returns (AccountData memory) {
        AccountData memory data = AccountData({
            totalCollateralUSD: 0,
            totalDebtUSD: 0,
            maxBorrowUSD: 0,
            liquidatableCollateralUSD: 0,
            healthFactor: 0
        });
        address[] storage collateralAssets = _userCollateralAssets[user];
        for (uint256 i = 0; i < collateralAssets.length; i++) {
            address a = collateralAssets[i];
            uint256 col = userPositions[a][user].collateral;
            if (col == 0) continue;
            uint256 usd = _usdValue(a, col);
            data.totalCollateralUSD += usd;
            data.maxBorrowUSD += (usd * MAX_LTV_BPS) / BPS_DENOMINATOR;
            data.liquidatableCollateralUSD += (usd * pools[a].liquidationThresholdBps) / BPS_DENOMINATOR;
        }
        address[] storage borrowAssets = _userBorrowAssets[user];
        for (uint256 i = 0; i < borrowAssets.length; i++) {
            address a = borrowAssets[i];
            AssetPool storage p = pools[a];
            if (p.totalBorrowShares == 0) continue;
            uint256 debt = (userPositions[a][user].borrowShares * p.borrowIndex) / RAY;
            if (debt == 0) continue;
            data.totalDebtUSD += _usdValue(a, debt);
        }
        if (data.totalDebtUSD == 0) {
            data.healthFactor = type(uint256).max;
        } else {
            data.healthFactor = (data.liquidatableCollateralUSD * RAY) / data.totalDebtUSD;
        }
        return data;
    }

    function getAllAssets() external view returns (address[] memory) {
        return allAssets;
    }

    function getUserCollateralAssets(address user) external view returns (address[] memory) {
        return _userCollateralAssets[user];
    }

    function getUserBorrowAssets(address user) external view returns (address[] memory) {
        return _userBorrowAssets[user];
    }
}
