// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface IInterestRateModel {
    function getBorrowRate(uint256 totalDeposits, uint256 totalBorrows) external view returns (uint256);
}

contract ReentrancyGuard {
    uint256 private _locked = 1;
    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }
    error ReentrantCall();
}

contract LendingPlatform is ReentrancyGuard {
    uint256 public constant MAX_LTV = 7500; // 75% in basis points
    uint256 public constant LIQUIDATION_FEE = 5; // 0.05% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    address public operator;
    address public oracle;
    address public feeRecipient;

    struct AssetConfig {
        bool isSupported;
        bool borrowPaused;
        uint256 collateralFactor;
        address interestRateModel;
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 borrowIndex;
        uint256 lastAccrual;
    }

    struct Account {
        uint256 collateral;
        uint256 debt;
        uint256 interestIndex;
    }

    mapping(address => AssetConfig) public assetConfig;
    mapping(address => mapping(address => Account)) public accounts;
    address[] public supportedAssets;
    mapping(address => bool) private _isSupported;

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Liquidate(
        address indexed liquidator,
        address indexed user,
        address collateralAsset,
        address borrowAsset,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 feeAmount
    );
    event AssetAdded(address indexed asset, uint256 collateralFactor, address interestRateModel);
    event BorrowPaused(address indexed asset, bool paused);
    event InterestRateModelUpdated(address indexed asset, address model);
    event CollateralFactorUpdated(address indexed asset, uint256 collateralFactor);
    event OperatorUpdated(address indexed newOperator);
    event OracleUpdated(address indexed newOracle);
    event FeeRecipientUpdated(address indexed newFeeRecipient);

    error Unauthorized();
    error ZeroAddress();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error BorrowPaused();
    error InsufficientCollateral();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error ZeroAmount();
    error InvalidParameter();
    error CollateralFactorTooHigh();
    error NotUnderwater();
    error LTVExceeded();
    error TransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier onlySupported(address asset) {
        if (!_isSupported[asset]) revert AssetNotSupported();
        _;
    }

    constructor(address _operator, address _oracle, address _feeRecipient) {
        if (_operator == address(0) || _oracle == address(0) || _feeRecipient == address(0))
            revert ZeroAddress();
        operator = _operator;
        oracle = _oracle;
        feeRecipient = _feeRecipient;
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setOracle(address _oracle) external onlyOperator {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = _oracle;
        emit OracleUpdated(_oracle);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function addAsset(
        address asset,
        uint256 collateralFactor,
        address interestRateModel
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (_isSupported[asset]) revert AssetAlreadySupported();
        if (collateralFactor > MAX_LTV) revert CollateralFactorTooHigh();
        if (interestRateModel == address(0)) revert ZeroAddress();

        assetConfig[asset] = AssetConfig({
            isSupported: true,
            borrowPaused: false,
            collateralFactor: collateralFactor,
            interestRateModel: interestRateModel,
            totalDeposits: 0,
            totalBorrows: 0,
            borrowIndex: PRECISION,
            lastAccrual: block.timestamp
        });
        _isSupported[asset] = true;
        supportedAssets.push(asset);

        emit AssetAdded(asset, collateralFactor, interestRateModel);
    }

    function setBorrowPaused(address asset, bool paused) external onlyOperator onlySupported(asset) {
        assetConfig[asset].borrowPaused = paused;
        emit BorrowPaused(asset, paused);
    }

    function setInterestRateModel(address asset, address model) external onlyOperator onlySupported(asset) {
        if (model == address(0)) revert ZeroAddress();
        _accrueInterest(asset);
        assetConfig[asset].interestRateModel = model;
        emit InterestRateModelUpdated(asset, model);
    }

    function setCollateralFactor(address asset, uint256 collateralFactor) external onlyOperator onlySupported(asset) {
        if (collateralFactor > MAX_LTV) revert CollateralFactorTooHigh();
        _accrueInterest(asset);
        assetConfig[asset].collateralFactor = collateralFactor;
        emit CollateralFactorUpdated(asset, collateralFactor);
    }

    function accrueInterest(address asset) public onlySupported(asset) {
        _accrueInterest(asset);
    }

    function accrueInterestAll() public {
        uint256 len = supportedAssets.length;
        for (uint256 i = 0; i < len; ) {
            _accrueInterest(supportedAssets[i]);
            unchecked { ++i; }
        }
    }

    function _accrueInterest(address asset) internal {
        AssetConfig storage config = assetConfig[asset];
        if (block.timestamp <= config.lastAccrual) return;

        uint256 timeDelta = block.timestamp - config.lastAccrual;
        uint256 rate = IInterestRateModel(config.interestRateModel).getBorrowRate(
            config.totalDeposits,
            config.totalBorrows
        );
        uint256 interestFactor = (rate * timeDelta) / SECONDS_PER_YEAR;

        if (interestFactor > 0 && config.totalBorrows > 0) {
            uint256 newIndex = (config.borrowIndex * (PRECISION + interestFactor)) / PRECISION;
            uint256 additionalDebt = (config.totalBorrows * (newIndex - config.borrowIndex)) / PRECISION;
            config.borrowIndex = newIndex;
            config.totalBorrows += additionalDebt;
        }
        config.lastAccrual = block.timestamp;
    }

    function deposit(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(asset);

        accounts[msg.sender][asset].collateral += amount;
        assetConfig[asset].totalDeposits += amount;

        _safeTransferFrom(asset, msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(asset);

        Account storage account = accounts[msg.sender][asset];
        if (account.collateral < amount) revert InsufficientBalance();

        account.collateral -= amount;
        assetConfig[asset].totalDeposits -= amount;

        _checkLiquidity(msg.sender);

        _safeTransfer(asset, msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    function borrow(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert ZeroAmount();
        AssetConfig storage config = assetConfig[asset];
        if (config.borrowPaused) revert BorrowPaused();

        _accrueInterest(asset);

        if (config.totalDeposits < config.totalBorrows + amount) revert InsufficientLiquidity();

        _updateDebt(msg.sender, asset);

        Account storage account = accounts[msg.sender][asset];
        account.debt += amount;
        config.totalBorrows += amount;

        _checkLiquidity(msg.sender);

        _safeTransfer(asset, msg.sender, amount);

        emit Borrow(msg.sender, asset, amount);
    }

    function repay(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert ZeroAmount();
        _accrueInterest(asset);

        _updateDebt(msg.sender, asset);
        Account storage account = accounts[msg.sender][asset];

        uint256 debt = account.debt;
        if (debt == 0) revert InsufficientBalance();

        uint256 repayAmount = amount > debt ? debt : amount;

        account.debt -= repayAmount;
        assetConfig[asset].totalBorrows -= repayAmount;

        _safeTransferFrom(asset, msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, asset, repayAmount);
    }

    function liquidate(
        address user,
        address collateralAsset,
        address borrowAsset,
        uint256 repayAmount
    ) external nonReentrant onlySupported(collateralAsset) onlySupported(borrowAsset) {
        if (repayAmount == 0) revert ZeroAmount();

        accrueInterestAll();

        (uint256 collateralValue, uint256 debtValue) = getAccountLiquidity(user);
        if (debtValue * BASIS_POINTS <= collateralValue * MAX_LTV) revert NotUnderwater();

        _updateDebt(user, borrowAsset);
        Account storage borrowAccount = accounts[user][borrowAsset];
        uint256 userDebt = borrowAccount.debt;
        if (userDebt == 0) revert InsufficientBalance();

        uint256 debtToRepay = repayAmount > userDebt ? userDebt : repayAmount;

        uint256 priceBorrow = IOracle(oracle).getPrice(borrowAsset);
        uint256 priceCollateral = IOracle(oracle).getPrice(collateralAsset);
        if (priceBorrow == 0 || priceCollateral == 0) revert InvalidParameter();

        uint256 repayValue = (debtToRepay * priceBorrow) / PRECISION;
        uint256 seizeValue = (repayValue * (BASIS_POINTS + LIQUIDATION_FEE)) / BASIS_POINTS;
        uint256 collateralToSeize = (seizeValue * PRECISION) / priceCollateral;

        Account storage collateralAccount = accounts[user][collateralAsset];
        if (collateralToSeize > collateralAccount.collateral) {
            collateralToSeize = collateralAccount.collateral;
        }

        borrowAccount.debt -= debtToRepay;
        assetConfig[borrowAsset].totalBorrows -= debtToRepay;

        collateralAccount.collateral -= collateralToSeize;
        assetConfig[collateralAsset].totalDeposits -= collateralToSeize;

        _safeTransferFrom(borrowAsset, msg.sender, address(this), debtToRepay);
        _safeTransfer(collateralAsset, msg.sender, collateralToSeize);

        emit Liquidate(
            msg.sender,
            user,
            collateralAsset,
            borrowAsset,
            debtToRepay,
            collateralToSeize,
            0
        );
    }

    function _updateDebt(address user, address asset) internal {
        Account storage account = accounts[user][asset];
        uint256 currentIndex = assetConfig[asset].borrowIndex;
        if (account.debt > 0 && account.interestIndex > 0 && account.interestIndex != currentIndex) {
            account.debt = (account.debt * currentIndex) / account.interestIndex;
        }
        account.interestIndex = currentIndex;
    }

    function _checkLiquidity(address user) internal view {
        (uint256 collateralValue, uint256 debtValue) = getAccountLiquidity(user);
        if (debtValue * BASIS_POINTS > collateralValue * MAX_LTV) revert LTVExceeded();
    }

    function getAccountLiquidity(address user) public view returns (uint256 collateralValue, uint256 debtValue) {
        uint256 len = supportedAssets.length;
        for (uint256 i = 0; i < len; ) {
            address asset = supportedAssets[i];
            Account memory account = accounts[user][asset];
            AssetConfig memory config = assetConfig[asset];

            if (account.collateral > 0) {
                uint256 price = IOracle(oracle).getPrice(asset);
                collateralValue += (account.collateral * price * config.collateralFactor) / (PRECISION * BASIS_POINTS);
            }

            if (account.debt > 0) {
                uint256 currentDebt = account.debt;
                if (account.interestIndex > 0 && account.interestIndex != config.borrowIndex) {
                    currentDebt = (account.debt * config.borrowIndex) / account.interestIndex;
                }
                uint256 price = IOracle(oracle).getPrice(asset);
                debtValue += (currentDebt * price) / PRECISION;
            }

            unchecked { ++i; }
        }
    }

    function getDebt(address user, address asset) external view onlySupported(asset) returns (uint256) {
        Account memory account = accounts[user][asset];
        if (account.debt == 0) return 0;
        uint256 currentIndex = assetConfig[asset].borrowIndex;
        if (account.interestIndex == 0) return account.debt;
        return (account.debt * currentIndex) / account.interestIndex;
    }

    function getCollateral(address user, address asset) external view onlySupported(asset) returns (uint256) {
        return accounts[user][asset].collateral;
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function isAssetSupported(address asset) external view returns (bool) {
        return _isSupported[asset];
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
