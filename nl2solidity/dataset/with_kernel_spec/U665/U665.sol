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
    function getAssetPrice(address asset) external view returns (uint256);
}

interface IRateModel {
    function getBorrowRate(uint256 utilization) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract ERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ERC20: insufficient balance");
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ERC20: burn exceeds balance");
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error InvalidOwner();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert InvalidOwner();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;

    error ReentrantCall();

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract YieldReceiptToken is ERC20 {
    address public immutable pool;

    error OnlyPool();

    constructor(address _pool, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        pool = _pool;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != pool) revert OnlyPool();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (msg.sender != pool) revert OnlyPool();
        _burn(from, amount);
    }
}

contract PooledLendingFacility is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant MIN_HEALTH_FACTOR = 1.05e18;
    uint256 public constant LIQUIDATION_PENALTY = 0.05e18;

    error AssetNotSupported(address asset);
    error AssetAlreadySupported(address asset);
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientLiquidity(address asset, uint256 requested, uint256 available);
    error InsufficientDeposit(address user, address asset, uint256 requested, uint256 available);
    error HealthFactorTooLow(address user, uint256 healthFactor);
    error HealthFactorNotBelowThreshold(address user, uint256 healthFactor);
    error BorrowingPaused(address asset);
    error InvalidRateModel(address rateModel);
    error InvalidLTV(uint256 ltv);
    error InvalidLiquidator(address liquidator);
    error NothingToLiquidate(address user);

    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address indexed receiver, address indexed asset, uint256 amount, uint256 shares);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 newDebt);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 newDebt);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        address indexed debtAsset,
        address collateralAsset,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event AssetAdded(address indexed asset, address receiptToken, address rateModel, uint256 ltv);
    event RateModelUpdated(address indexed asset, address rateModel);
    event BorrowPaused(address indexed asset, bool paused);
    event OracleUpdated(address oracle);
    event InterestAccrued(address indexed asset, uint256 borrowIndex, uint256 totalBorrows);

    struct AssetConfig {
        bool supported;
        bool borrowPaused;
        address rateModel;
        address receiptToken;
        uint256 ltv;
        uint256 totalDeposits;
        uint256 totalDepositShares;
        uint256 totalBorrows;
        uint256 borrowIndex;
        uint256 lastAccrual;
    }

    struct UserAssetData {
        uint256 depositShares;
        uint256 debt;
        uint256 userBorrowIndex;
    }

    IPriceOracle public oracle;
    address[] public supportedAssets;
    mapping(address => AssetConfig) public assetConfig;
    mapping(address => mapping(address => UserAssetData)) public userAssets;
    mapping(address => address[]) public userCollaterals;
    mapping(address => mapping(address => bool)) public isUserCollateral;

    constructor(address _oracle) Ownable(msg.sender) {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        emit OracleUpdated(_oracle);
    }

    modifier onlySupported(address asset) {
        if (!assetConfig[asset].supported) revert AssetNotSupported(asset);
        _;
    }

    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        emit OracleUpdated(_oracle);
    }

    function addAsset(
        address asset,
        address rateModel,
        string calldata receiptName,
        string calldata receiptSymbol,
        uint256 ltv
    ) external onlyOwner {
        if (asset == address(0) || rateModel == address(0)) revert ZeroAddress();
        if (assetConfig[asset].supported) revert AssetAlreadySupported(asset);
        if (ltv == 0 || ltv > WAD) revert InvalidLTV(ltv);

        try IRateModel(rateModel).getBorrowRate(0) returns (uint256) {
            // valid
        } catch {
            revert InvalidRateModel(rateModel);
        }

        YieldReceiptToken receipt = new YieldReceiptToken(address(this), receiptName, receiptSymbol);

        assetConfig[asset] = AssetConfig({
            supported: true,
            borrowPaused: false,
            rateModel: rateModel,
            receiptToken: address(receipt),
            ltv: ltv,
            totalDeposits: 0,
            totalDepositShares: 0,
            totalBorrows: 0,
            borrowIndex: WAD,
            lastAccrual: block.timestamp
        });

        supportedAssets.push(asset);
        emit AssetAdded(asset, address(receipt), rateModel, ltv);
    }

    function setRateModel(address asset, address rateModel) external onlyOwner onlySupported(asset) {
        if (rateModel == address(0)) revert ZeroAddress();
        try IRateModel(rateModel).getBorrowRate(0) returns (uint256) {
            // valid
        } catch {
            revert InvalidRateModel(rateModel);
        }
        assetConfig[asset].rateModel = rateModel;
        emit RateModelUpdated(asset, rateModel);
    }

    function setBorrowPaused(address asset, bool paused) external onlyOwner onlySupported(asset) {
        assetConfig[asset].borrowPaused = paused;
        emit BorrowPaused(asset, paused);
    }

    function accrueInterest(address asset) public onlySupported(asset) {
        AssetConfig storage cfg = assetConfig[asset];
        uint256 elapsed = block.timestamp - cfg.lastAccrual;
        if (elapsed == 0) {
            return;
        }
        if (cfg.totalBorrows == 0 || cfg.totalDeposits == 0) {
            cfg.lastAccrual = block.timestamp;
            return;
        }

        uint256 utilization = (cfg.totalBorrows * WAD) / cfg.totalDeposits;
        uint256 ratePerSecond = IRateModel(cfg.rateModel).getBorrowRate(utilization);
        uint256 interestFactor = WAD + (ratePerSecond * elapsed) / WAD;
        uint256 newBorrowIndex = (cfg.borrowIndex * interestFactor) / WAD;

        uint256 interestAccrued = (cfg.totalBorrows * (newBorrowIndex - cfg.borrowIndex)) / cfg.borrowIndex;

        cfg.borrowIndex = newBorrowIndex;
        cfg.totalBorrows += interestAccrued;
        cfg.totalDeposits += interestAccrued;
        cfg.lastAccrual = block.timestamp;

        emit InterestAccrued(asset, newBorrowIndex, cfg.totalBorrows);
    }

    function _accrueUserDebt(address user, address asset) internal {
        UserAssetData storage ud = userAssets[user][asset];
        if (ud.debt == 0) {
            ud.userBorrowIndex = assetConfig[asset].borrowIndex;
            return;
        }
        uint256 currentIndex = assetConfig[asset].borrowIndex;
        if (ud.userBorrowIndex == 0) ud.userBorrowIndex = currentIndex;
        uint256 newDebt = (ud.debt * currentIndex) / ud.userBorrowIndex;
        ud.debt = newDebt;
        ud.userBorrowIndex = currentIndex;
    }

    function deposit(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert ZeroAmount();
        accrueInterest(asset);

        AssetConfig storage cfg = assetConfig[asset];
        uint256 shares;
        if (cfg.totalDepositShares == 0 || cfg.totalDeposits == 0) {
            shares = amount;
        } else {
            shares = (amount * cfg.totalDepositShares) / cfg.totalDeposits;
        }

        cfg.totalDeposits += amount;
        cfg.totalDepositShares += shares;

        UserAssetData storage ud = userAssets[msg.sender][asset];
        ud.depositShares += shares;

        if (!isUserCollateral[msg.sender][asset]) {
            isUserCollateral[msg.sender][asset] = true;
            userCollaterals[msg.sender].push(asset);
        }

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        YieldReceiptToken(cfg.receiptToken).mint(msg.sender, shares);

        emit Deposit(msg.sender, asset, amount, shares);
    }

    function withdraw(address asset, uint256 amount, address receiver)
        external
        nonReentrant
        onlySupported(asset)
    {
        if (amount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        accrueInterest(asset);

        AssetConfig storage cfg = assetConfig[asset];
        UserAssetData storage ud = userAssets[msg.sender][asset];
        if (ud.depositShares == 0) revert InsufficientDeposit(msg.sender, asset, amount, 0);

        uint256 sharesToBurn = (amount * cfg.totalDepositShares) / cfg.totalDeposits;
        if (sharesToBurn == 0) revert InsufficientDeposit(msg.sender, asset, amount, 0);
        if (sharesToBurn > ud.depositShares) {
            sharesToBurn = ud.depositShares;
            amount = (sharesToBurn * cfg.totalDeposits) / cfg.totalDepositShares;
        }

        cfg.totalDeposits -= amount;
        cfg.totalDepositShares -= sharesToBurn;
        ud.depositShares -= sharesToBurn;

        uint256 hf = _healthFactor(msg.sender);
        if (hf < MIN_HEALTH_FACTOR && hf != type(uint256).max) revert HealthFactorTooLow(msg.sender, hf);

        YieldReceiptToken(cfg.receiptToken).burn(msg.sender, sharesToBurn);
        IERC20(asset).safeTransfer(receiver, amount);

        emit Withdraw(msg.sender, receiver, asset, amount, sharesToBurn);
    }

    function borrow(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert ZeroAmount();
        AssetConfig storage cfg = assetConfig[asset];
        if (cfg.borrowPaused) revert BorrowingPaused(asset);

        accrueInterest(asset);
        _accrueUserDebt(msg.sender, asset);

        uint256 available = cfg.totalDeposits - cfg.totalBorrows;
        if (amount > available) {
            revert InsufficientLiquidity(asset, amount, available);
        }

        UserAssetData storage ud = userAssets[msg.sender][asset];
        ud.debt += amount;
        cfg.totalBorrows += amount;

        uint256 hf = _healthFactor(msg.sender);
        if (hf < MIN_HEALTH_FACTOR) revert HealthFactorTooLow(msg.sender, hf);

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, asset, amount, ud.debt);
    }

    function repay(address asset, uint256 amount) external nonReentrant onlySupported(asset) {
        if (amount == 0) revert ZeroAmount();
        accrueInterest(asset);
        _accrueUserDebt(msg.sender, asset);

        AssetConfig storage cfg = assetConfig[asset];
        UserAssetData storage ud = userAssets[msg.sender][asset];
        if (ud.debt == 0) revert NothingToLiquidate(msg.sender);

        uint256 repayAmount = amount > ud.debt ? ud.debt : amount;
        ud.debt -= repayAmount;
        cfg.totalBorrows -= repayAmount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, asset, repayAmount, ud.debt);
    }

    function liquidate(
        address borrower,
        address debtAsset,
        address collateralAsset,
        uint256 repayAmount
    ) external nonReentrant onlySupported(debtAsset) onlySupported(collateralAsset) {
        if (repayAmount == 0) revert ZeroAmount();
        if (borrower == msg.sender) revert InvalidLiquidator(msg.sender);

        accrueInterest(debtAsset);
        accrueInterest(collateralAsset);
        _accrueUserDebt(borrower, debtAsset);

        uint256 hf = _healthFactor(borrower);
        if (hf >= MIN_HEALTH_FACTOR) revert HealthFactorNotBelowThreshold(borrower, hf);

        (uint256 actualRepay, uint256 collateralToSeize, uint256 sharesToSeize) =
            _computeLiquidation(borrower, debtAsset, collateralAsset, repayAmount);

        AssetConfig storage debtCfg = assetConfig[debtAsset];
        UserAssetData storage ud = userAssets[borrower][debtAsset];
        AssetConfig storage collCfg = assetConfig[collateralAsset];
        UserAssetData storage collateralData = userAssets[borrower][collateralAsset];

        ud.debt -= actualRepay;
        debtCfg.totalBorrows -= actualRepay;

        collCfg.totalDeposits -= collateralToSeize;
        collCfg.totalDepositShares -= sharesToSeize;
        collateralData.depositShares -= sharesToSeize;

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), actualRepay);
        YieldReceiptToken(collCfg.receiptToken).burn(borrower, sharesToSeize);
        IERC20(collateralAsset).safeTransfer(msg.sender, collateralToSeize);

        emit Liquidate(msg.sender, borrower, debtAsset, collateralAsset, actualRepay, collateralToSeize);
    }

    function _computeLiquidation(
        address borrower,
        address debtAsset,
        address collateralAsset,
        uint256 repayAmount
    )
        internal
        view
        returns (uint256 actualRepay, uint256 collateralToSeize, uint256 sharesToSeize)
    {
        UserAssetData storage ud = userAssets[borrower][debtAsset];
        if (ud.debt == 0) revert NothingToLiquidate(borrower);

        actualRepay = repayAmount > ud.debt ? ud.debt : repayAmount;

        uint256 debtPrice = oracle.getAssetPrice(debtAsset);
        uint256 collateralPrice = oracle.getAssetPrice(collateralAsset);
        uint256 debtDecimals = _decimals(debtAsset);
        uint256 collateralDecimals = _decimals(collateralAsset);

        uint256 debtValue = (actualRepay * debtPrice) / debtDecimals;
        uint256 seizeValue = (debtValue * (WAD + LIQUIDATION_PENALTY)) / WAD;
        collateralToSeize = (seizeValue * collateralDecimals) / collateralPrice;

        AssetConfig storage collCfg = assetConfig[collateralAsset];
        UserAssetData storage collateralData = userAssets[borrower][collateralAsset];
        uint256 borrowerCollateralAssets =
            (collateralData.depositShares * collCfg.totalDeposits) / collCfg.totalDepositShares;

        if (collateralToSeize > borrowerCollateralAssets) {
            collateralToSeize = borrowerCollateralAssets;
            uint256 maxSeizeValue = (collateralToSeize * collateralPrice) / collateralDecimals;
            uint256 maxDebtValue = (maxSeizeValue * WAD) / (WAD + LIQUIDATION_PENALTY);
            actualRepay = (maxDebtValue * debtDecimals) / debtPrice;
        }

        sharesToSeize = (collateralToSeize * collCfg.totalDepositShares) / collCfg.totalDeposits;
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function getUserDepositAssets(address user, address asset) public view returns (uint256) {
        UserAssetData storage ud = userAssets[user][asset];
        AssetConfig storage cfg = assetConfig[asset];
        if (cfg.totalDepositShares == 0) return 0;
        return (ud.depositShares * cfg.totalDeposits) / cfg.totalDepositShares;
    }

    function getUserDebt(address user, address asset) external view returns (uint256) {
        UserAssetData storage ud = userAssets[user][asset];
        if (ud.debt == 0) return 0;
        uint256 currentIndex = _projectedBorrowIndex(asset);
        uint256 userIndex = ud.userBorrowIndex == 0 ? currentIndex : ud.userBorrowIndex;
        return (ud.debt * currentIndex) / userIndex;
    }

    function healthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getAssetConfig(address asset)
        external
        view
        returns (
            bool supported,
            bool borrowPaused,
            address rateModel,
            address receiptToken,
            uint256 ltv,
            uint256 totalDeposits,
            uint256 totalDepositShares,
            uint256 totalBorrows,
            uint256 borrowIndex,
            uint256 lastAccrual
        )
    {
        AssetConfig storage cfg = assetConfig[asset];
        return (
            cfg.supported,
            cfg.borrowPaused,
            cfg.rateModel,
            cfg.receiptToken,
            cfg.ltv,
            cfg.totalDeposits,
            cfg.totalDepositShares,
            cfg.totalBorrows,
            cfg.borrowIndex,
            cfg.lastAccrual
        );
    }

    function _projectedBorrowIndex(address asset) internal view returns (uint256) {
        AssetConfig storage cfg = assetConfig[asset];
        uint256 elapsed = block.timestamp - cfg.lastAccrual;
        if (elapsed == 0 || cfg.totalBorrows == 0 || cfg.totalDeposits == 0) {
            return cfg.borrowIndex;
        }
        uint256 utilization = (cfg.totalBorrows * WAD) / cfg.totalDeposits;
        uint256 ratePerSecond = IRateModel(cfg.rateModel).getBorrowRate(utilization);
        uint256 interestFactor = WAD + (ratePerSecond * elapsed) / WAD;
        return (cfg.borrowIndex * interestFactor) / WAD;
    }

    function _healthFactor(address user) internal view returns (uint256) {
        uint256 totalCollateralValue = _collateralValue(user);
        uint256 totalDebtValue = _debtValue(user);

        if (totalDebtValue == 0) return type(uint256).max;
        return (totalCollateralValue * WAD) / totalDebtValue;
    }

    function _collateralValue(address user) internal view returns (uint256 totalCollateralValue) {
        address[] memory collaterals = userCollaterals[user];
        for (uint256 i = 0; i < collaterals.length; i++) {
            address asset = collaterals[i];
            AssetConfig storage cfg = assetConfig[asset];
            if (!cfg.supported) continue;

            uint256 depositAmount = getUserDepositAssets(user, asset);
            if (depositAmount == 0) continue;

            uint256 price = oracle.getAssetPrice(asset);
            uint256 decimals = _decimals(asset);
            uint256 value = (depositAmount * price) / decimals;
            totalCollateralValue += (value * cfg.ltv) / WAD;
        }
    }

    function _debtValue(address user) internal view returns (uint256 totalDebtValue) {
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            UserAssetData storage ud = userAssets[user][asset];
            if (ud.debt == 0) continue;

            uint256 projectedIndex = _projectedBorrowIndex(asset);
            uint256 userIndex = ud.userBorrowIndex == 0 ? projectedIndex : ud.userBorrowIndex;
            uint256 currentDebt = (ud.debt * projectedIndex) / userIndex;
            uint256 price = oracle.getAssetPrice(asset);
            uint256 decimals = _decimals(asset);
            totalDebtValue += (currentDebt * price) / decimals;
        }
    }

    function _decimals(address asset) internal view returns (uint256) {
        (bool success, bytes memory data) = asset.staticcall(abi.encodeWithSignature("decimals()"));
        if (success && data.length >= 32) {
            return 10 ** abi.decode(data, (uint8));
        }
        return 1e18;
    }
}
