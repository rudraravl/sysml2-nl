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

interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    error SafeTransferFailed();
    error SafeTransferFromFailed();
    error SafeApproveFailed();

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value))) {
            revert SafeTransferFailed();
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value))) {
            revert SafeTransferFromFailed();
        }
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value))) {
            revert SafeApproveFailed();
        }
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (success) {
            if (returndata.length == 0) {
                return address(token).code.length > 0;
            }
            return abi.decode(returndata, (bool));
        }
        return false;
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount();
    error OwnableInvalidOwner();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
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

/// @title LendingPool
/// @notice Collateralized lending and borrowing protocol for fungible tokens.
contract LendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------ //
    //                              Errors                                 //
    // ------------------------------------------------------------------ //

    error AddressZero();
    error AmountZero();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error AssetNotCollateral();
    error AssetNotBorrowable();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error InsufficientBalance();
    error PositionHealthy();
    error NoOutstandingDebt();
    error LiquidationTooLarge();
    error CollateralLocked();
    error NotLiquidator();
    error InvalidPrice();
    error InvalidLiquidationParameters();
    error SelfLiquidation();

    // ------------------------------------------------------------------ //
    //                              Events                                 //
    // ------------------------------------------------------------------ //

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        address indexed debtAsset,
        address collateralAsset,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event CollateralAssetAdded(address indexed asset, uint256 price);
    event CollateralAssetRemoved(address indexed asset);
    event BorrowAssetAdded(
        address indexed asset,
        uint256 price,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear
    );
    event BorrowAssetRemoved(address indexed asset);
    event InterestRateModelUpdated(
        address indexed asset,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear
    );
    event LiquidationParametersUpdated(uint256 minHealthFactor, uint256 liquidationFee);
    event AssetPriceUpdated(address indexed asset, uint256 price);
    event LiquidatorUpdated(address indexed liquidator, bool status);
    event Rescue(address indexed token, address indexed to, uint256 amount);

    // ------------------------------------------------------------------ //
    //                            Constants                                //
    // ------------------------------------------------------------------ //

    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_LIQUIDATION_FEE = 50e16; // 50%

    // ------------------------------------------------------------------ //
    //                             Structs                                 //
    // ------------------------------------------------------------------ //

    struct AssetConfig {
        bool isCollateral;
        bool isBorrowable;
        uint8 decimals;
        uint256 decimalFactor;      // 10 ** decimals, cached for gas
        uint256 price;             // USD per whole token, 1e18 scaled
        uint256 pricePerRawX18;   // price * WAD / decimalFactor, precomputed for precision
        uint256 baseRatePerYear;  // 1e18 scaled annual base rate
        uint256 multiplierPerYear; // 1e18 scaled utilization multiplier
    }

    struct AssetPool {
        uint256 totalDeposits; // raw collateral deposited for this asset
        uint256 totalBorrows;  // raw current total debt for this asset
        uint256 cash;          // raw tokens held in escrow available to borrow
        uint256 borrowIndex;   // 1e18 scaled cumulative borrow index
        uint256 lastAccrualTime;
    }

    struct Account {
        mapping(address => uint256) deposits;     // raw collateral per asset
        mapping(address => uint256) borrows;      // raw borrow principal at snapshot index
        mapping(address => uint256) borrowIndex;   // user's index snapshot per asset
    }

    // ------------------------------------------------------------------ //
    //                             Storage                                  //
    // ------------------------------------------------------------------ //

    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => AssetPool) public pools;
    mapping(address => Account) internal accounts;
    address[] public collateralAssets;
    address[] public borrowAssets;
    mapping(address => bool) public isLiquidator;

    uint256 public minHealthFactor = 1.2e18; // 120%
    uint256 public liquidationFee = 5e16;    // 5%

    // ------------------------------------------------------------------ //
    //                            Modifiers                                //
    // ------------------------------------------------------------------ //

    modifier onlyLiquidator() {
        if (!isLiquidator[msg.sender]) revert NotLiquidator();
        _;
    }

    // ------------------------------------------------------------------ //
    //                           Constructor                               //
    // ------------------------------------------------------------------ //

    constructor() Ownable(msg.sender) {}

    // ------------------------------------------------------------------ //
    //                   Admin: Asset Management                           //
    // ------------------------------------------------------------------ //

    function addCollateralAsset(address asset, uint256 price) external onlyOwner {
        if (asset == address(0)) revert AddressZero();
        if (price == 0) revert InvalidPrice();

        AssetConfig storage cfg = assetConfigs[asset];
        if (cfg.isCollateral) revert AssetAlreadySupported();

        cfg.isCollateral = true;
        if (cfg.decimals == 0) {
            cfg.decimals = _readDecimals(asset);
            cfg.decimalFactor = 10 ** uint256(cfg.decimals);
        }
        _setPrice(cfg, price);

        collateralAssets.push(asset);
        emit CollateralAssetAdded(asset, price);
    }

    function removeCollateralAsset(address asset) external onlyOwner {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isCollateral) revert AssetNotCollateral();
        if (pools[asset].totalDeposits != 0) revert CollateralLocked();

        cfg.isCollateral = false;
        _removeFromList(collateralAssets, asset);
        emit CollateralAssetRemoved(asset);
    }

    function addBorrowAsset(
        address asset,
        uint256 price,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear
    ) external onlyOwner {
        if (asset == address(0)) revert AddressZero();
        if (price == 0) revert InvalidPrice();

        AssetConfig storage cfg = assetConfigs[asset];
        if (cfg.isBorrowable) revert AssetAlreadySupported();

        cfg.isBorrowable = true;
        if (cfg.decimals == 0) {
            cfg.decimals = _readDecimals(asset);
            cfg.decimalFactor = 10 ** uint256(cfg.decimals);
        }
        _setPrice(cfg, price);
        cfg.baseRatePerYear = baseRatePerYear;
        cfg.multiplierPerYear = multiplierPerYear;

        AssetPool storage pool = pools[asset];
        if (pool.borrowIndex == 0) {
            pool.borrowIndex = WAD;
            pool.lastAccrualTime = block.timestamp;
        }

        borrowAssets.push(asset);
        emit BorrowAssetAdded(asset, price, baseRatePerYear, multiplierPerYear);
    }

    function removeBorrowAsset(address asset) external onlyOwner {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isBorrowable) revert AssetNotBorrowable();
        if (pools[asset].totalBorrows != 0) revert CollateralLocked();

        cfg.isBorrowable = false;
        cfg.baseRatePerYear = 0;
        cfg.multiplierPerYear = 0;

        _removeFromList(borrowAssets, asset);
        emit BorrowAssetRemoved(asset);
    }

    function setInterestRateModel(
        address asset,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear
    ) external onlyOwner {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isBorrowable) revert AssetNotBorrowable();

        cfg.baseRatePerYear = baseRatePerYear;
        cfg.multiplierPerYear = multiplierPerYear;
        emit InterestRateModelUpdated(asset, baseRatePerYear, multiplierPerYear);
    }

    function setLiquidationParameters(
        uint256 _minHealthFactor,
        uint256 _liquidationFee
    ) external onlyOwner {
        if (_minHealthFactor < WAD) revert InvalidLiquidationParameters();
        if (_liquidationFee > MAX_LIQUIDATION_FEE) revert InvalidLiquidationParameters();

        minHealthFactor = _minHealthFactor;
        liquidationFee = _liquidationFee;
        emit LiquidationParametersUpdated(_minHealthFactor, _liquidationFee);
    }

    function setAssetPrice(address asset, uint256 price) external onlyOwner {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isCollateral && !cfg.isBorrowable) revert AssetNotSupported();
        if (price == 0) revert InvalidPrice();

        _setPrice(cfg, price);
        emit AssetPriceUpdated(asset, price);
    }

    function setLiquidator(address liquidator, bool status) external onlyOwner {
        if (liquidator == address(0)) revert AddressZero();
        isLiquidator[liquidator] = status;
        emit LiquidatorUpdated(liquidator, status);
    }

    function rescue(address asset, uint256 amount) external onlyOwner {
        AssetConfig storage cfg = assetConfigs[asset];
        if (cfg.isCollateral || cfg.isBorrowable) revert AssetNotSupported();
        IERC20(asset).safeTransfer(msg.sender, amount);
        emit Rescue(asset, msg.sender, amount);
    }

    // ------------------------------------------------------------------ //
    //                   Core: Deposit / Withdraw                          //
    // ------------------------------------------------------------------ //

    function deposit(address asset, uint256 amount) external nonReentrant {
        if (!assetConfigs[asset].isCollateral) revert AssetNotCollateral();
        if (amount == 0) revert AmountZero();

        accounts[msg.sender].deposits[asset] += amount;
        pools[asset].totalDeposits += amount;
        pools[asset].cash += amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant {
        if (!assetConfigs[asset].isCollateral) revert AssetNotCollateral();
        if (amount == 0) revert AmountZero();
        if (accounts[msg.sender].deposits[asset] < amount) revert InsufficientBalance();
        if (pools[asset].cash < amount) revert InsufficientLiquidity();

        _accrueAll();

        accounts[msg.sender].deposits[asset] -= amount;
        pools[asset].totalDeposits -= amount;
        pools[asset].cash -= amount;

        if (_healthFactor(msg.sender) < minHealthFactor) revert InsufficientCollateral();

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    // ------------------------------------------------------------------ //
    //                   Core: Borrow / Repay                              //
    // ------------------------------------------------------------------ //

    function borrow(address asset, uint256 amount) external nonReentrant {
        if (!assetConfigs[asset].isBorrowable) revert AssetNotBorrowable();
        if (amount == 0) revert AmountZero();

        _accrueAll();

        AssetPool storage pool = pools[asset];
        if (pool.cash < amount) revert InsufficientLiquidity();

        uint256 currentDebt = _currentDebt(msg.sender, asset);
        accounts[msg.sender].borrows[asset] = currentDebt + amount;
        accounts[msg.sender].borrowIndex[asset] = pool.borrowIndex;
        pool.totalBorrows += amount;
        pool.cash -= amount;

        if (_healthFactor(msg.sender) < minHealthFactor) revert InsufficientCollateral();

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, asset, amount);
    }

    function repay(address asset, uint256 amount) external nonReentrant {
        if (!assetConfigs[asset].isBorrowable) revert AssetNotBorrowable();
        if (amount == 0) revert AmountZero();

        _accrueAll();

        if (accounts[msg.sender].borrows[asset] == 0) revert NoOutstandingDebt();

        uint256 currentDebt = _currentDebt(msg.sender, asset);
        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        _repayDebt(msg.sender, asset, currentDebt, repayAmount);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, asset, repayAmount);
    }

    // ------------------------------------------------------------------ //
    //                      Core: Liquidation                              //
    // ------------------------------------------------------------------ //

    function liquidate(
        address borrower,
        address debtAsset,
        address collateralAsset,
        uint256 debtToRepay
    ) external nonReentrant onlyLiquidator {
        if (borrower == msg.sender) revert SelfLiquidation();
        if (!assetConfigs[debtAsset].isBorrowable) revert AssetNotBorrowable();
        if (!assetConfigs[collateralAsset].isCollateral) revert AssetNotCollateral();
        if (debtToRepay == 0) revert AmountZero();

        _accrueAll();

        if (_healthFactor(borrower) >= minHealthFactor) revert PositionHealthy();

        if (accounts[borrower].borrows[debtAsset] == 0) revert NoOutstandingDebt();

        uint256 currentDebt = _currentDebt(borrower, debtAsset);
        if (debtToRepay > currentDebt) revert LiquidationTooLarge();

        _repayDebt(borrower, debtAsset, currentDebt, debtToRepay);

        uint256 collateralSeized = _computeSeizeAmount(debtAsset, collateralAsset, debtToRepay);
        uint256 borrowerCollateral = accounts[borrower].deposits[collateralAsset];
        if (collateralSeized > borrowerCollateral) collateralSeized = borrowerCollateral;
        if (pools[collateralAsset].cash < collateralSeized) revert InsufficientLiquidity();

        accounts[borrower].deposits[collateralAsset] -= collateralSeized;
        pools[collateralAsset].totalDeposits -= collateralSeized;
        pools[collateralAsset].cash -= collateralSeized;

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), debtToRepay);
        if (collateralSeized > 0) {
            IERC20(collateralAsset).safeTransfer(msg.sender, collateralSeized);
        }

        emit Liquidate(
            msg.sender,
            borrower,
            debtAsset,
            collateralAsset,
            debtToRepay,
            collateralSeized
        );
    }

    // ------------------------------------------------------------------ //
    //                       Interest Accrual                             //
    // ------------------------------------------------------------------ //

    function _accrueAll() internal {
        address[] memory bors = borrowAssets;
        for (uint256 i = 0; i < bors.length; i++) {
            _accrueInterest(bors[i]);
        }
    }

    function _accrueInterest(address asset) internal {
        AssetPool storage pool = pools[asset];
        uint256 lastTime = pool.lastAccrualTime;
        if (lastTime == 0) {
            pool.borrowIndex = WAD;
            pool.lastAccrualTime = block.timestamp;
            return;
        }
        if (block.timestamp <= lastTime) return;

        uint256 rate = _borrowRate(asset);
        if (rate == 0) {
            pool.lastAccrualTime = block.timestamp;
            return;
        }

        uint256 timeDelta = block.timestamp - lastTime;
        // Multiply-before-divide: interestAccrued = totalBorrows * rate * timeDelta / (SECONDS_PER_YEAR * WAD)
        uint256 interestAccrued = (pool.totalBorrows * rate * timeDelta) / (SECONDS_PER_YEAR * WAD);

        pool.totalBorrows += interestAccrued;
        // newIndex = oldIndex + oldIndex * rate * timeDelta / (SECONDS_PER_YEAR * WAD)
        pool.borrowIndex =
            pool.borrowIndex +
            (pool.borrowIndex * rate * timeDelta) /
            (SECONDS_PER_YEAR * WAD);
        pool.lastAccrualTime = block.timestamp;
    }

    function _borrowRate(address asset) internal view returns (uint256) {
        AssetConfig storage cfg = assetConfigs[asset];
        AssetPool storage pool = pools[asset];
        uint256 supply = pool.totalBorrows + pool.cash;
        if (supply == 0) return cfg.baseRatePerYear;
        // Multiply-before-divide: utilMultiplier = totalBorrows * multiplierPerYear / supply
        uint256 utilMultiplier = (pool.totalBorrows * cfg.multiplierPerYear) / supply;
        return cfg.baseRatePerYear + utilMultiplier;
    }

    function _currentIndex(address asset) internal view returns (uint256) {
        AssetPool storage pool = pools[asset];
        if (pool.lastAccrualTime == 0) return WAD;
        if (block.timestamp <= pool.lastAccrualTime) return pool.borrowIndex;

        uint256 rate = _borrowRate(asset);
        if (rate == 0) return pool.borrowIndex;

        uint256 timeDelta = block.timestamp - pool.lastAccrualTime;
        // Multiply-before-divide to avoid precision loss
        return pool.borrowIndex + (pool.borrowIndex * rate * timeDelta) / (SECONDS_PER_YEAR * WAD);
    }

    // ------------------------------------------------------------------ //
    //                    Collateralization Checks                         //
    // ------------------------------------------------------------------ //

    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 collUSD, uint256 debtUSD) = _accountValues(user);
        if (debtUSD == 0) return type(uint256).max;
        return (collUSD * WAD) / debtUSD;
    }

    function _accountValues(address user)
        internal
        view
        returns (uint256 collateralValueUsd, uint256 debtValueUsd)
    {
        collateralValueUsd = _collateralValueUSD(user);
        debtValueUsd = _debtValueUSD(user);
    }

    function _collateralValueUSD(address user) internal view returns (uint256 total) {
        address[] memory colls = collateralAssets;
        for (uint256 i = 0; i < colls.length; i++) {
            uint256 amt = accounts[user].deposits[colls[i]];
            if (amt > 0) {
                total += _valueUSD(colls[i], amt);
            }
        }
    }

    function _debtValueUSD(address user) internal view returns (uint256 total) {
        address[] memory bors = borrowAssets;
        for (uint256 i = 0; i < bors.length; i++) {
            address a = bors[i];
            uint256 principal = accounts[user].borrows[a];
            if (principal > 0) {
                uint256 idx = accounts[user].borrowIndex[a];
                if (idx == 0) idx = _currentIndex(a);
                total += _valueUSD(a, (principal * _currentIndex(a)) / idx);
            }
        }
    }

    function _valueUSD(address asset, uint256 amount) internal view returns (uint256) {
        // Uses precomputed pricePerRawX18 = price * WAD / decimalFactor
        // This avoids the divide-before-multiply pattern that would arise
        // from computing (amount * price) / decimalFactor and then
        // multiplying that result in downstream functions.
        return (amount * assetConfigs[asset].pricePerRawX18) / WAD;
    }

    function _currentDebt(address borrower, address asset) internal view returns (uint256) {
        uint256 principal = accounts[borrower].borrows[asset];
        if (principal == 0) return 0;
        uint256 idx = accounts[borrower].borrowIndex[asset];
        if (idx == 0) idx = _currentIndex(asset);
        return (principal * _currentIndex(asset)) / idx;
    }

    function _repayDebt(address borrower, address asset, uint256 currentDebt, uint256 repayAmount) internal {
        accounts[borrower].borrows[asset] = currentDebt - repayAmount;
        accounts[borrower].borrowIndex[asset] = pools[asset].borrowIndex;
        pools[asset].totalBorrows -= repayAmount;
        pools[asset].cash += repayAmount;
    }

    function _computeSeizeAmount(
        address debtAsset,
        address collateralAsset,
        uint256 debtToRepay
    ) internal view returns (uint256) {
        AssetConfig storage debtCfg = assetConfigs[debtAsset];
        AssetConfig storage collCfg = assetConfigs[collateralAsset];
        // All multiplications before the single division to eliminate
        // divide-before-multiply precision loss.
        // Equivalent to:
        //   (debtToRepay * debtPrice / debtDecimalFactor) * (WAD + fee) / WAD * collDecimalFactor / collPrice
        // but performed as one rounded division on the full numerator.
        return
            (debtToRepay * debtCfg.pricePerRawX18 * (WAD + liquidationFee)) /
            (WAD * collCfg.pricePerRawX18);
    }

    // ------------------------------------------------------------------ //
    //                          View Functions                             //
    // ------------------------------------------------------------------ //

    function getAccountValues(address user)
        external
        view
        returns (uint256 collateralValueUsd, uint256 debtValueUsd)
    {
        return _accountValues(user);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function isPositionHealthy(address user) external view returns (bool) {
        return _healthFactor(user) >= minHealthFactor;
    }

    function getDeposit(address user, address asset) external view returns (uint256) {
        return accounts[user].deposits[asset];
    }

    function getBorrowBalance(address user, address asset) external view returns (uint256) {
        return _currentDebt(user, asset);
    }

    function getUserBorrowIndex(address user, address asset) external view returns (uint256) {
        return accounts[user].borrowIndex[asset];
    }

    function getBorrowRate(address asset) external view returns (uint256) {
        return _borrowRate(asset);
    }

    function getAssetConfig(address asset) external view returns (AssetConfig memory) {
        return assetConfigs[asset];
    }

    function getPool(address asset) external view returns (AssetPool memory) {
        return pools[asset];
    }

    function getCollateralAssets() external view returns (address[] memory) {
        return collateralAssets;
    }

    function getBorrowAssets() external view returns (address[] memory) {
        return borrowAssets;
    }

    function isAssetSupported(address asset) external view returns (bool) {
        return assetConfigs[asset].isCollateral || assetConfigs[asset].isBorrowable;
    }

    // ------------------------------------------------------------------ //
    //                          Internal Helpers                           //
    // ------------------------------------------------------------------ //

    function _setPrice(AssetConfig storage cfg, uint256 price) internal {
        cfg.price = price;
        cfg.pricePerRawX18 = (price * WAD) / cfg.decimalFactor;
    }

    function _removeFromList(address[] storage list, address asset) internal {
        uint256 len = list.length;
        for (uint256 i = 0; i < len; i++) {
            if (list[i] == asset) {
                if (i != len - 1) {
                    list[i] = list[len - 1];
                }
                list.pop();
                return;
            }
        }
    }

    function _readDecimals(address asset) internal view returns (uint8) {
        try IERC20Metadata(asset).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }
}
