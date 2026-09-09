// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedTransfer(address from, address to, uint256 value);
    error SafeERC20FailedApprove(address spender, uint256 value);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (address(token).code.length == 0) {
            revert SafeERC20FailedOperation(address(token));
        }
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedTransfer(address(0), to, value);
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (address(token).code.length == 0) {
            revert SafeERC20FailedOperation(address(token));
        }
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedTransfer(from, to, value);
        }
    }
}

contract LendingPool {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LTV = 7500;
    uint256 public constant ORIGINATION_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant RAY = 1e27;
    uint256 public constant PRECISION = 1e18;

    struct AssetConfig {
        bool supported;
        bool isCollateral;
        bool isBorrowable;
        uint16 collateralFactor;
        uint16 liquidationThreshold;
        uint256 price;
        uint256 totalDeposits;
        uint256 totalBorrow;
        uint256 borrowIndex;
        uint256 interestRateBps;
        uint40 lastAccrual;
    }

    struct UserAsset {
        uint256 deposited;
        uint256 borrowed;
        uint256 userBorrowIndex;
    }

    mapping(address => AssetConfig) public assets;
    address[] public supportedAssetsList;
    mapping(address => mapping(address => UserAsset)) public userAssets;

    address public operator;
    address public feeCollector;
    bool private _locked;

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 fee);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event AssetAdded(
        address indexed asset,
        bool isCollateral,
        bool isBorrowable,
        uint16 collateralFactor,
        uint16 liquidationThreshold,
        uint256 price,
        uint256 interestRateBps
    );
    event InterestRateUpdated(address indexed asset, uint256 newRateBps);
    event LiquidationThresholdUpdated(address indexed asset, uint16 newThreshold);
    event CollateralFactorUpdated(address indexed asset, uint16 newFactor);
    event PriceUpdated(address indexed asset, uint256 newPrice);
    event FeeCollectorUpdated(address indexed previousCollector, address indexed newCollector);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error NotCollateral();
    error NotBorrowable();
    error InvalidCollateralFactor();
    error InvalidLiquidationThreshold();
    error InvalidPrice();
    error InsufficientLiquidity();
    error InsufficientDeposit();
    error RepayExceedsDebt();
    error LTVExceeded();
    error ReentrancyDetected();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyDetected();
        _locked = true;
        _;
        _locked = false;
    }

    modifier supportedAsset(address asset) {
        if (!assets[asset].supported) revert AssetNotSupported();
        _;
    }

    constructor(address _operator, address _feeCollector) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeCollector == address(0)) revert ZeroAddress();
        operator = _operator;
        feeCollector = _feeCollector;
        emit OperatorUpdated(address(0), _operator);
        emit FeeCollectorUpdated(address(0), _feeCollector);
    }

    function addAsset(
        address asset,
        bool isCollateral,
        bool isBorrowable,
        uint16 collateralFactor,
        uint16 liquidationThreshold,
        uint256 price,
        uint256 interestRateBps
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (assets[asset].supported) revert AssetAlreadySupported();
        if (collateralFactor == 0 || collateralFactor > BPS_DENOMINATOR) revert InvalidCollateralFactor();
        if (liquidationThreshold == 0 || liquidationThreshold > BPS_DENOMINATOR) revert InvalidLiquidationThreshold();
        if (price == 0) revert InvalidPrice();

        assets[asset] = AssetConfig({
            supported: true,
            isCollateral: isCollateral,
            isBorrowable: isBorrowable,
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            price: price,
            totalDeposits: 0,
            totalBorrow: 0,
            borrowIndex: RAY,
            interestRateBps: interestRateBps,
            lastAccrual: uint40(block.timestamp)
        });
        supportedAssetsList.push(asset);

        emit AssetAdded(asset, isCollateral, isBorrowable, collateralFactor, liquidationThreshold, price, interestRateBps);
    }

    function setInterestRate(address asset, uint256 newRateBps) external onlyOperator supportedAsset(asset) {
        _accrueInterest(asset);
        assets[asset].interestRateBps = newRateBps;
        emit InterestRateUpdated(asset, newRateBps);
    }

    function setLiquidationThreshold(address asset, uint16 newThreshold) external onlyOperator supportedAsset(asset) {
        if (newThreshold == 0 || newThreshold > BPS_DENOMINATOR) revert InvalidLiquidationThreshold();
        assets[asset].liquidationThreshold = newThreshold;
        emit LiquidationThresholdUpdated(asset, newThreshold);
    }

    function setCollateralFactor(address asset, uint16 newFactor) external onlyOperator supportedAsset(asset) {
        if (newFactor == 0 || newFactor > BPS_DENOMINATOR) revert InvalidCollateralFactor();
        assets[asset].collateralFactor = newFactor;
        emit CollateralFactorUpdated(asset, newFactor);
    }

    function setPrice(address asset, uint256 newPrice) external onlyOperator supportedAsset(asset) {
        if (newPrice == 0) revert InvalidPrice();
        assets[asset].price = newPrice;
        emit PriceUpdated(asset, newPrice);
    }

    function setFeeCollector(address newCollector) external onlyOperator {
        if (newCollector == address(0)) revert ZeroAddress();
        emit FeeCollectorUpdated(feeCollector, newCollector);
        feeCollector = newCollector;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function deposit(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();
        AssetConfig storage cfg = assets[asset];
        if (!cfg.isCollateral) revert NotCollateral();

        _accrueInterest(asset);

        UserAsset storage ua = userAssets[msg.sender][asset];
        ua.deposited += amount;
        cfg.totalDeposits += amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount);
    }

    function borrow(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();
        AssetConfig storage cfg = assets[asset];
        if (!cfg.isBorrowable) revert NotBorrowable();

        _accrueInterest(asset);

        uint256 available = cfg.totalDeposits >= cfg.totalBorrow ? cfg.totalDeposits - cfg.totalBorrow : 0;
        if (amount > available) revert InsufficientLiquidity();

        UserAsset storage ua = userAssets[msg.sender][asset];
        if (ua.borrowed > 0) {
            uint256 debt = _currentDebt(msg.sender, asset);
            ua.borrowed = debt;
            ua.userBorrowIndex = cfg.borrowIndex;
        } else {
            ua.userBorrowIndex = cfg.borrowIndex;
        }

        uint256 fee = (amount * ORIGINATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        ua.borrowed += amount;
        cfg.totalBorrow += amount;

        uint256 collateralValue = _collateralValue(msg.sender);
        uint256 borrowValue = _borrowValue(msg.sender);
        if (borrowValue > (collateralValue * MAX_LTV) / BPS_DENOMINATOR) revert LTVExceeded();

        IERC20(asset).safeTransfer(msg.sender, netAmount);
        if (fee > 0) {
            IERC20(asset).safeTransfer(feeCollector, fee);
        }

        emit Borrow(msg.sender, asset, amount, fee);
    }

    function repay(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(asset);
        AssetConfig storage cfg = assets[asset];
        UserAsset storage ua = userAssets[msg.sender][asset];

        uint256 debt = _currentDebt(msg.sender, asset);
        if (debt > 0) {
            uint256 repayAmount = amount < debt ? amount : debt;

            ua.borrowed = debt - repayAmount;
            ua.userBorrowIndex = cfg.borrowIndex;
            cfg.totalBorrow -= repayAmount;

            IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);

            emit Repay(msg.sender, asset, repayAmount);
        } else {
            revert RepayExceedsDebt();
        }
    }

    function withdraw(address asset, uint256 amount) external nonReentrant supportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();
        AssetConfig storage cfg = assets[asset];
        if (!cfg.isCollateral) revert NotCollateral();

        UserAsset storage ua = userAssets[msg.sender][asset];
        if (amount > ua.deposited) revert InsufficientDeposit();

        _accrueInterest(asset);

        uint256 collateralValue = _collateralValue(msg.sender);
        uint256 removedValue = (amount * cfg.price * uint256(cfg.collateralFactor)) / (PRECISION * BPS_DENOMINATOR);
        if (collateralValue < removedValue) revert LTVExceeded();
        uint256 newCollateralValue = collateralValue - removedValue;
        uint256 borrowValue = _borrowValue(msg.sender);
        if (borrowValue > (newCollateralValue * MAX_LTV) / BPS_DENOMINATOR) revert LTVExceeded();

        ua.deposited -= amount;
        cfg.totalDeposits -= amount;

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    function _accrueInterest(address asset) internal {
        AssetConfig storage cfg = assets[asset];
        if (block.timestamp <= cfg.lastAccrual) return;

        uint256 elapsed = block.timestamp - cfg.lastAccrual;

        if (cfg.totalBorrow > 0) {
            uint256 accrued = (cfg.totalBorrow * cfg.interestRateBps * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
            cfg.totalBorrow += accrued;

            uint256 indexDelta = (cfg.borrowIndex * cfg.interestRateBps * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
            cfg.borrowIndex += indexDelta;
        }
        cfg.lastAccrual = uint40(block.timestamp);
    }

    function _currentDebt(address user, address asset) internal view returns (uint256) {
        UserAsset storage ua = userAssets[user][asset];
        if (ua.borrowed > 0) {
            if (ua.userBorrowIndex > 0) {
                return (ua.borrowed * assets[asset].borrowIndex) / ua.userBorrowIndex;
            }
            return ua.borrowed;
        }
        return 0;
    }

    function _collateralValue(address user) internal view returns (uint256 total) {
        uint256 len = supportedAssetsList.length;
        for (uint256 i = 0; i < len; ) {
            address a = supportedAssetsList[i];
            AssetConfig storage cfg = assets[a];
            if (cfg.supported && cfg.isCollateral) {
                uint256 dep = userAssets[user][a].deposited;
                if (dep > 0) {
                    total += (dep * cfg.price * uint256(cfg.collateralFactor)) / (PRECISION * BPS_DENOMINATOR);
                }
            }
            unchecked { ++i; }
        }
    }

    function _borrowValue(address user) internal view returns (uint256 total) {
        uint256 len = supportedAssetsList.length;
        for (uint256 i = 0; i < len; ) {
            address a = supportedAssetsList[i];
            AssetConfig storage cfg = assets[a];
            if (cfg.supported && cfg.isBorrowable) {
                uint256 debt = _currentDebt(user, a);
                if (debt > 0) {
                    total += (debt * cfg.price) / PRECISION;
                }
            }
            unchecked { ++i; }
        }
    }

    function getAssetConfig(address asset) external view returns (AssetConfig memory) {
        return assets[asset];
    }

    function getUserAsset(address user, address asset) external view returns (UserAsset memory) {
        return userAssets[user][asset];
    }

    function getUserDebt(address user, address asset) external view returns (uint256) {
        if (!assets[asset].supported) return 0;
        return _currentDebt(user, asset);
    }

    function getCollateralValue(address user) external view returns (uint256) {
        return _collateralValue(user);
    }

    function getBorrowValue(address user) external view returns (uint256) {
        return _borrowValue(user);
    }

    function getAccountValues(address user) external view returns (uint256 collateralValue, uint256 borrowValue) {
        return (_collateralValue(user), _borrowValue(user));
    }

    function supportedAssetsCount() external view returns (uint256) {
        return supportedAssetsList.length;
    }

    function isAssetSupported(address asset) external view returns (bool) {
        return assets[asset].supported;
    }

    function userCollateralAssets(address user) external view returns (address[] memory) {
        uint256 len = supportedAssetsList.length;
        address[] memory temp = new address[](len);
        uint256 count;
        for (uint256 i = 0; i < len; ) {
            address a = supportedAssetsList[i];
            if (assets[a].isCollateral && userAssets[user][a].deposited > 0) {
                temp[count] = a;
                unchecked { ++count; }
            }
            unchecked { ++i; }
        }
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; ) {
            result[i] = temp[i];
            unchecked { ++i; }
        }
        return result;
    }

    function userBorrowAssets(address user) external view returns (address[] memory) {
        uint256 len = supportedAssetsList.length;
        address[] memory temp = new address[](len);
        uint256 count;
        for (uint256 i = 0; i < len; ) {
            address a = supportedAssetsList[i];
            if (assets[a].isBorrowable && userAssets[user][a].borrowed > 0) {
                temp[count] = a;
                unchecked { ++count; }
            }
            unchecked { ++i; }
        }
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; ) {
            result[i] = temp[i];
            unchecked { ++i; }
        }
        return result;
    }
}
