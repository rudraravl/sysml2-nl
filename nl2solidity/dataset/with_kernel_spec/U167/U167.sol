// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title DecentralizedLendingPool
 * @notice A decentralized lending pool allowing users to deposit supported ERC-20 tokens
 *         as collateral, borrow against that collateral, repay loans, and withdraw excess
 *         collateral. Interest accrues continuously via a borrow-index model.
 */
contract DecentralizedLendingPool {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant MAX_LTV_BPS = 7500;          // 75%
    uint256 public constant PROTOCOL_FEE_BPS = 5;        // 0.05%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant INDEX_SCALE = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 31_536_000;

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------

    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error BorrowingPaused();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error InsufficientDeposit();
    error InsufficientDebt();
    error NoPendingOperator();
    error InvalidCollateralFactor();
    error TransferFailed();
    error Reentrancy();

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------

    struct AssetConfig {
        bool isSupported;
        bool borrowPaused;
        uint256 collateralFactor;
        uint256 interestRate;
        uint256 totalDeposited;
        uint256 totalBorrowed;
        uint256 borrowIndex;
        uint256 lastAccrual;
    }

    struct AccountPosition {
        uint256 deposited;
        uint256 borrowedScaled;
        uint256 borrowIndexSnapshot;
    }

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------

    address public operator;
    address public pendingOperator;

    mapping(address => AssetConfig) public assets;
    mapping(address => mapping(address => AccountPosition)) public positions;
    mapping(address => uint256) public accruedFees;
    address[] public supportedAssets;

    uint256 private _locked = 1;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 fee);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event AssetAdded(address indexed asset, uint256 collateralFactor, uint256 interestRate);
    event InterestRateUpdated(address indexed asset, uint256 newRate);
    event CollateralFactorUpdated(address indexed asset, uint256 newCollateralFactor);
    event BorrowPaused(address indexed asset, bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OperatorPending(address indexed pendingOperator);
    event FeesWithdrawn(address indexed asset, address indexed to, uint256 amount);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier assetSupported(address asset) {
        if (!assets[asset].isSupported) revert AssetNotSupported();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor() {
        operator = msg.sender;
        emit OperatorChanged(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // Operator / admin functions
    // -----------------------------------------------------------------------

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        pendingOperator = newOperator;
        emit OperatorPending(newOperator);
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NoPendingOperator();
        address previous = operator;
        operator = pendingOperator;
        delete pendingOperator;
        emit OperatorChanged(previous, operator);
    }

    function addAsset(
        address asset,
        uint256 collateralFactor,
        uint256 interestRate
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (assets[asset].isSupported) revert AssetAlreadySupported();
        if (collateralFactor > MAX_LTV_BPS) revert InvalidCollateralFactor();

        assets[asset] = AssetConfig({
            isSupported: true,
            borrowPaused: false,
            collateralFactor: collateralFactor,
            interestRate: interestRate,
            totalDeposited: 0,
            totalBorrowed: 0,
            borrowIndex: INDEX_SCALE,
            lastAccrual: block.timestamp
        });

        supportedAssets.push(asset);
        emit AssetAdded(asset, collateralFactor, interestRate);
    }

    function updateInterestRate(address asset, uint256 newRate)
        external
        onlyOperator
        assetSupported(asset)
    {
        _accrueInterest(asset);
        assets[asset].interestRate = newRate;
        emit InterestRateUpdated(asset, newRate);
    }

    function updateCollateralFactor(address asset, uint256 newCollateralFactor)
        external
        onlyOperator
        assetSupported(asset)
    {
        if (newCollateralFactor > MAX_LTV_BPS) revert InvalidCollateralFactor();
        _accrueInterest(asset);
        assets[asset].collateralFactor = newCollateralFactor;
        emit CollateralFactorUpdated(asset, newCollateralFactor);
    }

    function setBorrowPaused(address asset, bool paused)
        external
        onlyOperator
        assetSupported(asset)
    {
        assets[asset].borrowPaused = paused;
        emit BorrowPaused(asset, paused);
    }

    function withdrawFees(address asset, address to)
        external
        onlyOperator
        assetSupported(asset)
    {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees[asset];
        if (amount == 0) revert ZeroAmount();

        accruedFees[asset] = 0;
        _safeTransfer(asset, to, amount);
        emit FeesWithdrawn(asset, to, amount);
    }

    // -----------------------------------------------------------------------
    // Core user functions
    // -----------------------------------------------------------------------

    function deposit(address asset, uint256 amount)
        external
        nonReentrant
        assetSupported(asset)
    {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(asset);

        AssetConfig storage config = assets[asset];
        AccountPosition storage position = positions[asset][msg.sender];

        // Effects before interactions
        position.deposited += amount;
        config.totalDeposited += amount;

        _safeTransferFrom(asset, msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount);
    }

    function borrow(address asset, uint256 amount)
        external
        nonReentrant
        assetSupported(asset)
    {
        if (amount == 0) revert ZeroAmount();

        AssetConfig storage config = assets[asset];
        if (config.borrowPaused) revert BorrowingPaused();

        _accrueInterest(asset);

        uint256 fee = (amount * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 totalObligation = amount + fee;

        uint256 available = config.totalDeposited - config.totalBorrowed;
        if (totalObligation > available) revert InsufficientLiquidity();

        if (!_hasSufficientCollateral(msg.sender, asset, totalObligation, true)) {
            revert InsufficientCollateral();
        }

        AccountPosition storage position = positions[asset][msg.sender];
        uint256 scaledBorrow = (totalObligation * INDEX_SCALE) / config.borrowIndex;
        position.borrowedScaled += scaledBorrow;
        position.borrowIndexSnapshot = config.borrowIndex;

        config.totalBorrowed += totalObligation;
        accruedFees[asset] += fee;

        // Interaction last
        _safeTransfer(asset, msg.sender, amount);

        emit Borrow(msg.sender, asset, amount, fee);
    }

    function repay(address asset, uint256 amount)
        external
        nonReentrant
        assetSupported(asset)
    {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(asset);

        AccountPosition storage position = positions[asset][msg.sender];
        uint256 currentDebt = _currentDebt(asset, msg.sender);
        if (currentDebt < 1) revert InsufficientDebt();

        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        // Effects before interactions
        uint256 scaledRepay = (repayAmount * INDEX_SCALE) / assets[asset].borrowIndex;
        position.borrowedScaled -= scaledRepay;
        position.borrowIndexSnapshot = assets[asset].borrowIndex;
        assets[asset].totalBorrowed -= repayAmount;

        _safeTransferFrom(asset, msg.sender, address(this), repayAmount);

        emit Repay(msg.sender, asset, repayAmount);
    }

    function withdraw(address asset, uint256 amount)
        external
        nonReentrant
        assetSupported(asset)
    {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(asset);

        AccountPosition storage position = positions[asset][msg.sender];
        if (amount > position.deposited) revert InsufficientDeposit();

        if (!_hasSufficientCollateral(msg.sender, asset, amount, false)) {
            revert InsufficientCollateral();
        }

        // Effects before interactions
        position.deposited -= amount;
        assets[asset].totalDeposited -= amount;

        _safeTransfer(asset, msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    function currentDebt(address asset, address user)
        external
        view
        assetSupported(asset)
        returns (uint256)
    {
        return _currentDebt(asset, user);
    }

    function totalCollateralValue(address user) external view returns (uint256 totalValue) {
        uint256 len = supportedAssets.length;
        for (uint256 i = 0; i < len; ) {
            address asset = supportedAssets[i];
            uint256 deposited = positions[asset][user].deposited;
            if (deposited > 0) {
                totalValue += (deposited * assets[asset].collateralFactor) / BPS_DENOMINATOR;
            }
            unchecked {
                ++i;
            }
        }
    }

    function totalDebtValue(address user) external view returns (uint256 totalDebt) {
        uint256 len = supportedAssets.length;
        for (uint256 i = 0; i < len; ) {
            address asset = supportedAssets[i];
            totalDebt += _currentDebt(asset, user);
            unchecked {
                ++i;
            }
        }
    }

    function getAvailableLiquidity(address asset)
        external
        view
        assetSupported(asset)
        returns (uint256)
    {
        AssetConfig storage config = assets[asset];
        return config.totalDeposited - config.totalBorrowed;
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function supportedAssetsCount() external view returns (uint256) {
        return supportedAssets.length;
    }

    function getPosition(address asset, address user)
        external
        view
        returns (uint256 deposited, uint256 borrowedScaled, uint256 borrowIndexSnapshot)
    {
        AccountPosition storage position = positions[asset][user];
        return (position.deposited, position.borrowedScaled, position.borrowIndexSnapshot);
    }

    function getAssetConfig(address asset)
        external
        view
        returns (
            bool isSupported,
            bool borrowPaused,
            uint256 collateralFactor,
            uint256 interestRate,
            uint256 totalDeposited,
            uint256 totalBorrowed,
            uint256 borrowIndex,
            uint256 lastAccrual
        )
    {
        AssetConfig storage config = assets[asset];
        return (
            config.isSupported,
            config.borrowPaused,
            config.collateralFactor,
            config.interestRate,
            config.totalDeposited,
            config.totalBorrowed,
            config.borrowIndex,
            config.lastAccrual
        );
    }

    // -----------------------------------------------------------------------
    // Internal functions
    // -----------------------------------------------------------------------

    function _accrueInterest(address asset) internal {
        AssetConfig storage config = assets[asset];

        // Guard against unsafe strict equality / future timestamps; only proceed
        // when strictly more time has elapsed since the last accrual.
        if (block.timestamp <= config.lastAccrual) {
            return;
        }

        uint256 timeDelta = block.timestamp - config.lastAccrual;
        config.lastAccrual = block.timestamp;

        if (config.totalBorrowed > 0) {
            // Full multiply-then-divide to avoid divide-before-multiply precision loss.
            uint256 interestDelta = (config.borrowIndex *
                config.interestRate *
                timeDelta) / (SECONDS_PER_YEAR * BPS_DENOMINATOR);
            config.borrowIndex = config.borrowIndex + interestDelta;
        }
    }

    function _currentDebt(address asset, address user) internal view returns (uint256) {
        AccountPosition storage position = positions[asset][user];
        if (position.borrowedScaled == 0) return 0;

        AssetConfig storage config = assets[asset];
        uint256 currentIndex = config.borrowIndex;
        uint256 snapshotIndex = position.borrowIndexSnapshot;

        uint256 effectiveIndex = currentIndex > snapshotIndex ? currentIndex : snapshotIndex;
        return (position.borrowedScaled * effectiveIndex) / INDEX_SCALE;
    }

    function _hasSufficientCollateral(
        address user,
        address actionAsset,
        uint256 amount,
        bool isBorrow
    ) internal view returns (bool) {
        uint256 totalCollateral = 0;
        uint256 totalDebt = 0;

        uint256 len = supportedAssets.length;
        for (uint256 i = 0; i < len; ) {
            address asset = supportedAssets[i];
            AccountPosition storage position = positions[asset][user];
            AssetConfig storage config = assets[asset];

            uint256 deposited = position.deposited;
            uint256 debt = _currentDebt(asset, user);

            if (asset == actionAsset) {
                if (isBorrow) {
                    debt += amount;
                } else {
                    if (amount > deposited) return false;
                    deposited -= amount;
                }
            }

            totalCollateral += (deposited * config.collateralFactor) / BPS_DENOMINATOR;
            totalDebt += debt;

            unchecked {
                ++i;
            }
        }

        return totalDebt <= totalCollateral;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
