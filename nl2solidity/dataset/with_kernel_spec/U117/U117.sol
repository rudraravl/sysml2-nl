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

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface IRateModel {
    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        require(ok, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        require(ok, "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not owner");
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero owner");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero new owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
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

contract LendingMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LTV_BPS = 7500;
    uint256 public constant LIQUIDATION_PENALTY_BPS = 500;
    uint256 public constant MAX_CLOSE_FACTOR_BPS = 5000;
    uint256 public constant RESERVE_FACTOR_BPS = 1000;
    uint256 public constant BPS = 10000;
    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    struct AssetConfig {
        bool isListed;
        uint8 decimals;
        IRateModel rateModel;
        uint256 collateralFactor;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 borrowIndex;
        uint256 supplyIndex;
        uint256 totalSupplyShares;
        uint256 totalBorrowPrincipal;
        uint256 totalReserves;
        uint256 lastAccrualTimestamp;
    }

    struct AccountSnapshot {
        uint256 totalCollateralValue;
        uint256 totalDebtValue;
        uint256 liquidationCollateralValue;
        uint256 borrowableCollateralValue;
    }

    mapping(address => AssetConfig) public assets;
    address[] public listedAssets;
    mapping(address => bool) internal _isListed;

    mapping(address => mapping(address => uint256)) public userSupplyShares;
    mapping(address => mapping(address => uint256)) public userBorrowPrincipal;

    IPriceOracle public oracle;
    address public operator;

    event AssetAdded(
        address indexed asset,
        uint8 decimals,
        address rateModel,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    );
    event RateModelUpdated(address indexed asset, address rateModel);
    event LiquidationParamsUpdated(
        address indexed asset,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    );
    event Deposit(address indexed caller, address indexed account, address indexed asset, uint256 amount, uint256 shares);
    event Borrow(address indexed account, address indexed asset, uint256 amount, uint256 principal);
    event Repay(address indexed caller, address indexed account, address indexed asset, uint256 amount, uint256 principal);
    event Withdraw(address indexed caller, address indexed account, address indexed asset, uint256 amount, uint256 shares);
    event Liquidation(
        address indexed liquidator,
        address indexed borrower,
        address debtAsset,
        address collateralAsset,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event ReservesClaimed(address indexed asset, address indexed to, uint256 amount);
    event InterestAccrued(address indexed asset, uint256 interestAccrued, uint256 reservesAdded);

    error AssetNotListed();
    error AssetAlreadyListed();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error InsufficientDeposit();
    error PositionHealthy();
    error CloseFactorExceeded();
    error ZeroAmount();
    error InvalidParams();
    error NotOperator();
    error InvalidOracle();
    error NoDebt();
    error SelfLiquidation();

    modifier onlyOperatorRole() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyListed(address asset) {
        if (!_isListed[asset]) revert AssetNotListed();
        _;
    }

    constructor(address initialOwner, address _oracle, address _operator) Ownable(initialOwner) {
        if (_oracle == address(0)) revert InvalidOracle();
        if (_operator == address(0)) revert InvalidParams();
        oracle = IPriceOracle(_oracle);
        operator = _operator;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidParams();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert InvalidOracle();
        emit OracleUpdated(address(oracle), newOracle);
        oracle = IPriceOracle(newOracle);
    }

    function addAsset(
        address asset,
        uint8 decimals,
        address rateModel,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external onlyOperatorRole {
        if (_isListed[asset]) revert AssetAlreadyListed();
        if (asset == address(0)) revert InvalidParams();
        if (rateModel == address(0)) revert InvalidParams();
        if (collateralFactor > MAX_LTV_BPS) revert InvalidParams();
        if (liquidationThreshold < collateralFactor || liquidationThreshold > BPS) revert InvalidParams();
        if (liquidationBonus > LIQUIDATION_PENALTY_BPS) revert InvalidParams();

        assets[asset] = AssetConfig({
            isListed: true,
            decimals: decimals,
            rateModel: IRateModel(rateModel),
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            borrowIndex: WAD,
            supplyIndex: WAD,
            totalSupplyShares: 0,
            totalBorrowPrincipal: 0,
            totalReserves: 0,
            lastAccrualTimestamp: block.timestamp
        });
        _isListed[asset] = true;
        listedAssets.push(asset);

        emit AssetAdded(asset, decimals, rateModel, collateralFactor, liquidationThreshold, liquidationBonus);
    }

    function setRateModel(address asset, address rateModel) external onlyOperatorRole onlyListed(asset) {
        if (rateModel == address(0)) revert InvalidParams();
        assets[asset].rateModel = IRateModel(rateModel);
        emit RateModelUpdated(asset, rateModel);
    }

    function setLiquidationParams(
        address asset,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external onlyOperatorRole onlyListed(asset) {
        if (collateralFactor > MAX_LTV_BPS) revert InvalidParams();
        if (liquidationThreshold < collateralFactor || liquidationThreshold > BPS) revert InvalidParams();
        if (liquidationBonus > LIQUIDATION_PENALTY_BPS) revert InvalidParams();
        AssetConfig storage cfg = assets[asset];
        cfg.collateralFactor = collateralFactor;
        cfg.liquidationThreshold = liquidationThreshold;
        cfg.liquidationBonus = liquidationBonus;
        emit LiquidationParamsUpdated(asset, collateralFactor, liquidationThreshold, liquidationBonus);
    }

    function accrueInterest(address asset) public onlyListed(asset) {
        AssetConfig storage cfg = assets[asset];
        if (block.timestamp == cfg.lastAccrualTimestamp) return;

        uint256 timeElapsed = block.timestamp - cfg.lastAccrualTimestamp;
        cfg.lastAccrualTimestamp = block.timestamp;

        uint256 totalBorrows = (cfg.totalBorrowPrincipal * cfg.borrowIndex) / WAD;
        if (totalBorrows == 0) return;

        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 cash = balance > cfg.totalReserves ? balance - cfg.totalReserves : 0;
        uint256 interestFactor = (cfg.rateModel.getBorrowRate(cash, totalBorrows, cfg.totalReserves) * timeElapsed) / SECONDS_PER_YEAR;
        if (interestFactor == 0) return;

        cfg.borrowIndex += (cfg.borrowIndex * interestFactor) / WAD;
        uint256 additionalBorrows = (totalBorrows * interestFactor) / WAD;
        uint256 reservesAdded = (additionalBorrows * RESERVE_FACTOR_BPS) / BPS;
        cfg.totalReserves += reservesAdded;

        uint256 totalDeposits = (cfg.totalSupplyShares * cfg.supplyIndex) / WAD;
        if (totalDeposits > 0 && additionalBorrows > reservesAdded) {
            cfg.supplyIndex += (cfg.supplyIndex * (additionalBorrows - reservesAdded)) / totalDeposits;
        }

        emit InterestAccrued(asset, additionalBorrows, reservesAdded);
    }

    function deposit(address asset, uint256 amount) external nonReentrant onlyListed(asset) {
        if (amount == 0) revert ZeroAmount();
        accrueInterest(asset);

        AssetConfig storage cfg = assets[asset];
        uint256 shares = (amount * WAD) / cfg.supplyIndex;
        if (shares == 0) revert ZeroAmount();

        userSupplyShares[asset][msg.sender] += shares;
        cfg.totalSupplyShares += shares;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, msg.sender, asset, amount, shares);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant onlyListed(asset) {
        if (amount == 0) revert ZeroAmount();
        accrueInterest(asset);

        AssetConfig storage cfg = assets[asset];
        uint256 shares = (amount * WAD + cfg.supplyIndex - 1) / cfg.supplyIndex;
        if (shares == 0 || shares > userSupplyShares[asset][msg.sender]) revert InsufficientDeposit();

        userSupplyShares[asset][msg.sender] -= shares;
        cfg.totalSupplyShares -= shares;

        AccountSnapshot memory snap = _getAccountSnapshot(msg.sender);
        if (snap.totalDebtValue > snap.borrowableCollateralValue) revert InsufficientCollateral();

        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 available = balance > cfg.totalReserves ? balance - cfg.totalReserves : 0;
        if (amount > available) revert InsufficientLiquidity();

        IERC20(asset).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, msg.sender, asset, amount, shares);
    }

    function borrow(address asset, uint256 amount) external nonReentrant onlyListed(asset) {
        if (amount == 0) revert ZeroAmount();
        accrueInterest(asset);

        AssetConfig storage cfg = assets[asset];
        uint256 principal = (amount * WAD) / cfg.borrowIndex;
        if (principal == 0) revert ZeroAmount();

        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 available = balance > cfg.totalReserves ? balance - cfg.totalReserves : 0;
        if (amount > available) revert InsufficientLiquidity();

        userBorrowPrincipal[asset][msg.sender] += principal;
        cfg.totalBorrowPrincipal += principal;

        AccountSnapshot memory snap = _getAccountSnapshot(msg.sender);
        if (snap.totalDebtValue > snap.borrowableCollateralValue) revert InsufficientCollateral();

        IERC20(asset).safeTransfer(msg.sender, amount);
        emit Borrow(msg.sender, asset, amount, principal);
    }

    function repay(address asset, uint256 amount) external nonReentrant onlyListed(asset) {
        if (amount == 0) revert ZeroAmount();
        accrueInterest(asset);

        AssetConfig storage cfg = assets[asset];
        uint256 currentDebt = (userBorrowPrincipal[asset][msg.sender] * cfg.borrowIndex) / WAD;
        if (currentDebt == 0) revert NoDebt();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;
        uint256 principal = (repayAmount * WAD + cfg.borrowIndex - 1) / cfg.borrowIndex;
        if (principal > userBorrowPrincipal[asset][msg.sender]) {
            principal = userBorrowPrincipal[asset][msg.sender];
            repayAmount = (principal * cfg.borrowIndex) / WAD;
        }

        userBorrowPrincipal[asset][msg.sender] -= principal;
        cfg.totalBorrowPrincipal -= principal;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);
        emit Repay(msg.sender, msg.sender, asset, repayAmount, principal);
    }

    function liquidate(
        address borrower,
        address debtAsset,
        address collateralAsset,
        uint256 repayAmount
    ) external nonReentrant onlyListed(debtAsset) onlyListed(collateralAsset) {
        if (repayAmount == 0) revert ZeroAmount();
        if (borrower == msg.sender) revert SelfLiquidation();

        accrueInterest(debtAsset);
        accrueInterest(collateralAsset);

        {
            AccountSnapshot memory snap = _getAccountSnapshot(borrower);
            if (snap.totalDebtValue == 0) revert PositionHealthy();
            if (snap.liquidationCollateralValue >= snap.totalDebtValue) revert PositionHealthy();
        }

        AssetConfig storage debtCfg = assets[debtAsset];
        uint256 borrowerDebt = (userBorrowPrincipal[debtAsset][borrower] * debtCfg.borrowIndex) / WAD;
        if (borrowerDebt == 0) revert NoDebt();
        uint256 maxRepay = (borrowerDebt * MAX_CLOSE_FACTOR_BPS) / BPS;
        if (repayAmount > maxRepay) revert CloseFactorExceeded();

        uint256 repayPrincipal = (repayAmount * WAD + debtCfg.borrowIndex - 1) / debtCfg.borrowIndex;
        uint256 actualRepay = repayAmount;
        if (repayPrincipal > userBorrowPrincipal[debtAsset][borrower]) {
            repayPrincipal = userBorrowPrincipal[debtAsset][borrower];
            actualRepay = (repayPrincipal * debtCfg.borrowIndex) / WAD;
        }

        userBorrowPrincipal[debtAsset][borrower] -= repayPrincipal;
        debtCfg.totalBorrowPrincipal -= repayPrincipal;

        (uint256 seizedShares, uint256 collateralSeized) = _computeSeize(
            collateralAsset, debtAsset, actualRepay, borrower
        );
        userSupplyShares[collateralAsset][borrower] -= seizedShares;
        assets[collateralAsset].totalSupplyShares -= seizedShares;

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), actualRepay);
        IERC20(collateralAsset).safeTransfer(msg.sender, collateralSeized);

        emit Liquidation(msg.sender, borrower, debtAsset, collateralAsset, actualRepay, collateralSeized);
    }

    function claimReserves(address asset, address to) external onlyOperatorRole onlyListed(asset) {
        if (to == address(0)) revert InvalidParams();
        AssetConfig storage cfg = assets[asset];
        uint256 reserves = cfg.totalReserves;
        if (reserves == 0) revert ZeroAmount();
        cfg.totalReserves = 0;
        IERC20(asset).safeTransfer(to, reserves);
        emit ReservesClaimed(asset, to, reserves);
    }

    function _getAccountSnapshot(address account) internal view returns (AccountSnapshot memory snap) {
        for (uint256 i = 0; i < listedAssets.length; i++) {
            address asset = listedAssets[i];
            AssetConfig storage cfg = assets[asset];
            uint256 supplyShares = userSupplyShares[asset][account];
            if (supplyShares > 0) {
                uint256 depositAmount = (supplyShares * cfg.supplyIndex) / WAD;
                uint256 value = _assetValue(asset, depositAmount, cfg.decimals);
                snap.totalCollateralValue += value;
                snap.liquidationCollateralValue += (value * cfg.liquidationThreshold) / BPS;
                snap.borrowableCollateralValue += (value * cfg.collateralFactor) / BPS;
            }
            uint256 borrowPrincipal = userBorrowPrincipal[asset][account];
            if (borrowPrincipal > 0) {
                uint256 borrowAmount = (borrowPrincipal * cfg.borrowIndex) / WAD;
                snap.totalDebtValue += _assetValue(asset, borrowAmount, cfg.decimals);
            }
        }
    }

    function _assetValue(address asset, uint256 amount, uint8 decimals) internal view returns (uint256) {
        if (amount == 0) return 0;
        uint256 price = oracle.getPrice(asset);
        if (price == 0) revert InvalidOracle();
        return (amount * price) / (10 ** uint256(decimals));
    }

    function _computeSeize(
        address collateralAsset,
        address debtAsset,
        uint256 repayAmount,
        address borrower
    ) internal view returns (uint256 seizedShares, uint256 collateralSeized) {
        collateralSeized = _collateralSeizeAmount(debtAsset, collateralAsset, repayAmount);
        if (collateralSeized == 0) revert InvalidParams();

        AssetConfig storage colCfg = assets[collateralAsset];
        uint256 borrowerShares = userSupplyShares[collateralAsset][borrower];
        uint256 borrowerCollateral = (borrowerShares * colCfg.supplyIndex) / WAD;
        if (collateralSeized > borrowerCollateral) {
            collateralSeized = borrowerCollateral;
        }

        seizedShares = (collateralSeized * WAD + colCfg.supplyIndex - 1) / colCfg.supplyIndex;
        if (seizedShares > borrowerShares) {
            seizedShares = borrowerShares;
            collateralSeized = (seizedShares * colCfg.supplyIndex) / WAD;
        }
        if (seizedShares == 0) revert InvalidParams();
    }

    function _collateralSeizeAmount(
        address debtAsset,
        address collateralAsset,
        uint256 repayAmount
    ) internal view returns (uint256) {
        uint256 debtPrice = oracle.getPrice(debtAsset);
        uint256 collateralPrice = oracle.getPrice(collateralAsset);
        if (debtPrice == 0 || collateralPrice == 0) revert InvalidOracle();

        AssetConfig storage debtCfg = assets[debtAsset];
        AssetConfig storage colCfg = assets[collateralAsset];
        uint256 debtValue = (repayAmount * debtPrice) / (10 ** uint256(debtCfg.decimals));
        uint256 seizeValue = (debtValue * (BPS + colCfg.liquidationBonus)) / BPS;
        return (seizeValue * (10 ** uint256(colCfg.decimals))) / collateralPrice;
    }

    function getAccountSnapshot(address account) external view returns (
        uint256 totalCollateralValue,
        uint256 totalDebtValue,
        uint256 liquidationCollateralValue,
        uint256 borrowableCollateralValue,
        uint256 healthFactor
    ) {
        AccountSnapshot memory snap = _getAccountSnapshot(account);
        totalCollateralValue = snap.totalCollateralValue;
        totalDebtValue = snap.totalDebtValue;
        liquidationCollateralValue = snap.liquidationCollateralValue;
        borrowableCollateralValue = snap.borrowableCollateralValue;
        healthFactor = totalDebtValue == 0 ? type(uint256).max : (liquidationCollateralValue * WAD) / totalDebtValue;
    }

    function getCurrentBorrow(address asset, address account) external view onlyListed(asset) returns (uint256) {
        AssetConfig storage cfg = assets[asset];
        return (userBorrowPrincipal[asset][account] * cfg.borrowIndex) / WAD;
    }

    function getCurrentDeposit(address asset, address account) external view onlyListed(asset) returns (uint256) {
        AssetConfig storage cfg = assets[asset];
        return (userSupplyShares[asset][account] * cfg.supplyIndex) / WAD;
    }

    function convertToShares(address asset, uint256 amount) external view onlyListed(asset) returns (uint256) {
        return (amount * WAD) / assets[asset].supplyIndex;
    }

    function convertToAssets(address asset, uint256 shares) external view onlyListed(asset) returns (uint256) {
        return (shares * assets[asset].supplyIndex) / WAD;
    }

    function getAvailableLiquidity(address asset) external view onlyListed(asset) returns (uint256) {
        AssetConfig storage cfg = assets[asset];
        uint256 balance = IERC20(asset).balanceOf(address(this));
        return balance > cfg.totalReserves ? balance - cfg.totalReserves : 0;
    }

    function getListedAssets() external view returns (address[] memory) {
        return listedAssets;
    }

    function isAssetListed(address asset) external view returns (bool) {
        return _isListed[asset];
    }

    function listedAssetsCount() external view returns (uint256) {
        return listedAssets.length;
    }
}
