// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
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
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(amount == 0 || token.allowance(address(this), spender) == 0, "SafeERC20: non-zero allowance");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
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

/// @title LendingMarket
/// @notice A decentralized multi-asset lending market. Users deposit ERC-20 tokens
/// and receive interest-bearing deposit shares, borrow against their collateral,
/// repay outstanding debt, and withdraw their deposits. A per-asset interest rate
/// model with a kink drives accrual, the maximum loan-to-value is 75%, and a 0.05%
/// origination fee is collected on every new borrow.
contract LendingMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //---------------------------------------------------------------------------
    // Constants
    //---------------------------------------------------------------------------
    uint256 public constant RAY = 1e27;
    uint256 public constant WAD = 1e18;
    uint256 public constant BIPS = 10_000;
    uint256 public constant SECONDS_PER_YEAR = 31_536_000;
    uint256 public constant MAX_LTV_BIPS = 7_500; // 75%
    uint256 public constant ORIGINATION_FEE_BIPS = 5; // 0.05%
    uint256 public constant MAX_RATE_COMPONENT_BIPS = 10_000; // 100%

    //---------------------------------------------------------------------------
    // Structs
    //---------------------------------------------------------------------------
    struct RateModel {
        uint64 baseRateBips;
        uint64 slope1Bips;
        uint64 slope2Bips;
        uint32 kinkBips;
        uint32 reserveFactorBips;
    }

    struct AssetState {
        bool isListed;
        bool borrowPaused;
        RateModel rateModel;
        uint256 totalCash;
        uint256 totalBorrows;
        uint256 totalReserves;
        uint256 totalDepositShares;
        uint256 borrowIndex;
        uint40 lastAccrual;
    }

    //---------------------------------------------------------------------------
    // Storage
    //---------------------------------------------------------------------------
    mapping(address => AssetState) public assets;
    address[] public listedAssets;
    mapping(address => uint256) public assetPrices;

    mapping(address => mapping(address => uint256)) public depositShares;
    mapping(address => mapping(address => uint256)) public userBorrows;
    mapping(address => mapping(address => uint256)) public userBorrowIndex;

    //---------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------
    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 proceeds, uint256 fee);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 remainingDebt);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event AssetListed(address indexed asset, uint256 price, RateModel model);
    event AssetPriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice);
    event RateModelUpdated(address indexed asset, RateModel oldModel, RateModel newModel);
    event BorrowPauseToggled(address indexed asset, bool paused);
    event ReservesWithdrawn(address indexed asset, address indexed to, uint256 amount);
    event InterestAccrued(address indexed asset, uint256 interestAccrued, uint256 reservesAccrued, uint256 newBorrowIndex);

    //---------------------------------------------------------------------------
    // Errors
    //---------------------------------------------------------------------------
    error AssetNotListed();
    error AssetAlreadyListed();
    error InvalidAddress();
    error AmountZero();
    error SharesZero();
    error InvalidDecimals();
    error PriceZero();
    error RateParameterInvalid();
    error AssetBorrowPaused();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error InsufficientShares();
    error NoDebtToRepay();

    //---------------------------------------------------------------------------
    // Constructor
    //---------------------------------------------------------------------------
    constructor() Ownable(msg.sender) {}

    //---------------------------------------------------------------------------
    // Administration
    //---------------------------------------------------------------------------
    function listAsset(address asset, uint256 price, RateModel calldata model) external onlyOwner {
        if (asset == address(0)) revert InvalidAddress();
        if (assets[asset].isListed) revert AssetAlreadyListed();
        if (IERC20Metadata(asset).decimals() != 18) revert InvalidDecimals();
        if (price == 0) revert PriceZero();
        _validateModel(model);

        AssetState storage s = assets[asset];
        s.isListed = true;
        s.borrowPaused = false;
        s.rateModel = model;
        s.borrowIndex = RAY;
        s.lastAccrual = uint40(block.timestamp);
        assetPrices[asset] = price;
        listedAssets.push(asset);

        emit AssetListed(asset, price, model);
    }

    function setRateModel(address asset, RateModel calldata model) external onlyOwner {
        if (!assets[asset].isListed) revert AssetNotListed();
        _validateModel(model);
        emit RateModelUpdated(asset, assets[asset].rateModel, model);
        assets[asset].rateModel = model;
    }

    function setAssetPrice(address asset, uint256 price) external onlyOwner {
        if (!assets[asset].isListed) revert AssetNotListed();
        if (price == 0) revert PriceZero();
        uint256 oldPrice = assetPrices[asset];
        assetPrices[asset] = price;
        emit AssetPriceUpdated(asset, oldPrice, price);
    }

    function setBorrowPaused(address asset, bool paused) external onlyOwner {
        if (!assets[asset].isListed) revert AssetNotListed();
        assets[asset].borrowPaused = paused;
        emit BorrowPauseToggled(asset, paused);
    }

    function withdrawReserves(address asset, address to, uint256 amount) external onlyOwner nonReentrant {
        if (!assets[asset].isListed) revert AssetNotListed();
        if (to == address(0)) revert InvalidAddress();
        AssetState storage s = assets[asset];
        uint256 withdrawable = s.totalReserves;
        if (withdrawable > s.totalCash) withdrawable = s.totalCash;
        if (amount > withdrawable) amount = withdrawable;
        if (amount == 0) revert AmountZero();
        s.totalReserves -= amount;
        s.totalCash -= amount;
        IERC20(asset).safeTransfer(to, amount);
        emit ReservesWithdrawn(asset, to, amount);
    }

    //---------------------------------------------------------------------------
    // Core user actions
    //---------------------------------------------------------------------------
    function deposit(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetState storage s = assets[asset];
        if (!s.isListed) revert AssetNotListed();

        _accrue(asset);
        uint256 exRate = _exchangeRate(asset);
        uint256 shares = (amount * RAY) / exRate;
        if (shares == 0) revert SharesZero();

        s.totalDepositShares += shares;
        s.totalCash += amount;
        depositShares[msg.sender][asset] += shares;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, asset, amount, shares);
    }

    function borrow(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetState storage s = assets[asset];
        if (!s.isListed) revert AssetNotListed();
        if (s.borrowPaused) revert AssetBorrowPaused();

        _accrue(asset);

        uint256 fee = (amount * ORIGINATION_FEE_BIPS) / BIPS;
        uint256 proceeds = amount - fee;
        if (proceeds > s.totalCash) revert InsufficientLiquidity();

        uint256 collateralValue = accountCollateralValue(msg.sender);
        uint256 currentDebtValue = accountDebtValue(msg.sender);
        uint256 newDebtValue = currentDebtValue + _usdValue(asset, amount);
        if (newDebtValue * BIPS > collateralValue * MAX_LTV_BIPS) revert InsufficientCollateral();

        uint256 prevDebt = _userDebt(msg.sender, asset);
        uint256 newDebt = prevDebt + amount;
        userBorrows[msg.sender][asset] = newDebt;
        userBorrowIndex[msg.sender][asset] = s.borrowIndex;

        s.totalBorrows += amount;
        s.totalReserves += fee;
        s.totalCash -= proceeds;

        IERC20(asset).safeTransfer(msg.sender, proceeds);
        emit Borrow(msg.sender, asset, amount, proceeds, fee);
    }

    function repay(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetState storage s = assets[asset];
        if (!s.isListed) revert AssetNotListed();

        _accrue(asset);

        uint256 debt = _userDebt(msg.sender, asset);
        if (debt > 0) {
            uint256 repayAmount = amount > debt ? debt : amount;
            uint256 remaining = debt - repayAmount;

            userBorrows[msg.sender][asset] = remaining;
            userBorrowIndex[msg.sender][asset] = s.borrowIndex;

            s.totalBorrows -= repayAmount;
            s.totalCash += repayAmount;

            IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);
            emit Repay(msg.sender, asset, repayAmount, remaining);
        } else {
            revert NoDebtToRepay();
        }
    }

    function withdraw(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetState storage s = assets[asset];
        if (!s.isListed) revert AssetNotListed();

        _accrue(asset);
        if (amount > s.totalCash) revert InsufficientLiquidity();

        uint256 exRate = _exchangeRate(asset);
        uint256 shares = (amount * RAY) / exRate;
        if (shares == 0) revert SharesZero();
        uint256 userShares = depositShares[msg.sender][asset];
        if (shares > userShares) revert InsufficientShares();

        depositShares[msg.sender][asset] = userShares - shares;
        s.totalDepositShares -= shares;
        s.totalCash -= amount;

        uint256 collateralValue = accountCollateralValue(msg.sender);
        uint256 debtValue = accountDebtValue(msg.sender);
        if (debtValue * BIPS > collateralValue * MAX_LTV_BIPS) revert InsufficientCollateral();

        IERC20(asset).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, asset, amount, shares);
    }

    //---------------------------------------------------------------------------
    // Interest accrual
    //---------------------------------------------------------------------------
    function accrue(address asset) external {
        if (!assets[asset].isListed) revert AssetNotListed();
        _accrue(asset);
    }

    function _accrue(address asset) internal {
        AssetState storage s = assets[asset];
        // Skip when no time has elapsed since the last accrual. Using an
        // inequality avoids fragile strict-equality checks and also guards
        // against any unexpected timestamp regressions.
        if (block.timestamp <= s.lastAccrual) return;

        uint256 dt = block.timestamp - s.lastAccrual;
        uint256 rate = _borrowRate(s); // annual rate in RAY (fraction per year)

        // Compute the growth factor numerator without an intermediate division
        // to avoid divide-before-multiply precision loss.
        uint256 rateDt = rate * dt; // RAY-scaled fraction * seconds

        if (rateDt > 0 && s.totalBorrows > 0) {
            // Full-precision product: totalBorrows * rate * dt
            uint256 borrowsRateDt = s.totalBorrows * rateDt;

            // interestAccrued = totalBorrows * rate * dt / (SECONDS_PER_YEAR * RAY)
            uint256 interestAccrued = borrowsRateDt / (SECONDS_PER_YEAR * RAY);

            // reservesAccrued derived from the unrounded product to avoid
            // multiplying a previously-rounded value.
            // = totalBorrows * rate * dt * reserveFactorBips / (SECONDS_PER_YEAR * RAY * BIPS)
            uint256 reservesAccrued =
                (borrowsRateDt * s.rateModel.reserveFactorBips) / (SECONDS_PER_YEAR * RAY * BIPS);

            s.totalBorrows += interestAccrued;
            s.totalReserves += reservesAccrued;

            // borrowIndex *= (1 + rate*dt/SECONDS_PER_YEAR), computed without
            // using the rounded `factor`.
            // = borrowIndex * (RAY*SECONDS_PER_YEAR + rate*dt) / (RAY*SECONDS_PER_YEAR)
            s.borrowIndex =
                (s.borrowIndex * (RAY * SECONDS_PER_YEAR + rateDt)) / (RAY * SECONDS_PER_YEAR);

            emit InterestAccrued(asset, interestAccrued, reservesAccrued, s.borrowIndex);
        }
        s.lastAccrual = uint40(block.timestamp);
    }

    //---------------------------------------------------------------------------
    // Views
    //---------------------------------------------------------------------------
    function exchangeRate(address asset) public view returns (uint256) {
        return _exchangeRate(asset);
    }

    function borrowRate(address asset) public view returns (uint256) {
        return _borrowRate(assets[asset]);
    }

    function utilization(address asset) public view returns (uint256) {
        AssetState storage s = assets[asset];
        uint256 total = s.totalCash + s.totalBorrows;
        if (total == 0) return 0;
        return (s.totalBorrows * BIPS) / total;
    }

    function userDebt(address user, address asset) public view returns (uint256) {
        return _userDebt(user, asset);
    }

    function userDepositAmount(address user, address asset) public view returns (uint256) {
        uint256 shares = depositShares[user][asset];
        if (shares == 0) return 0;
        return (shares * _exchangeRate(asset)) / RAY;
    }

    function accountCollateralValue(address user) public view returns (uint256 total) {
        uint256 len = listedAssets.length;
        for (uint256 i = 0; i < len; ) {
            address a = listedAssets[i];
            uint256 shares = depositShares[user][a];
            if (shares != 0) {
                uint256 assetAmount = (shares * _exchangeRate(a)) / RAY;
                total += _usdValue(a, assetAmount);
            }
            unchecked {
                ++i;
            }
        }
    }

    function accountDebtValue(address user) public view returns (uint256 total) {
        uint256 len = listedAssets.length;
        for (uint256 i = 0; i < len; ) {
            address a = listedAssets[i];
            uint256 debt = _userDebt(user, a);
            if (debt != 0) {
                total += _usdValue(a, debt);
            }
            unchecked {
                ++i;
            }
        }
    }

    function accountLTV(address user) public view returns (uint256) {
        uint256 col = accountCollateralValue(user);
        uint256 debt = accountDebtValue(user);
        if (col == 0) {
            if (debt == 0) return 0;
            return type(uint256).max;
        }
        return (debt * BIPS) / col;
    }

    function listedAssetsLength() external view returns (uint256) {
        return listedAssets.length;
    }

    function getAssetState(address asset) external view returns (AssetState memory) {
        return assets[asset];
    }

    //---------------------------------------------------------------------------
    // Internal helpers
    //---------------------------------------------------------------------------
    function _exchangeRate(address asset) internal view returns (uint256) {
        AssetState storage s = assets[asset];
        if (s.totalDepositShares == 0) return RAY;
        uint256 totalValue = s.totalCash + s.totalBorrows - s.totalReserves;
        return (totalValue * RAY) / s.totalDepositShares;
    }

    function _borrowRate(AssetState storage s) internal view returns (uint256) {
        RateModel memory m = s.rateModel;
        uint256 total = s.totalCash + s.totalBorrows;
        if (total == 0) {
            return (uint256(m.baseRateBips) * RAY) / BIPS;
        }

        // Compare utilization against the kink using cross-multiplication to
        // avoid an intermediate division that would later be multiplied.
        // utilization = totalBorrows / total ; kink = kinkBips / BIPS
        bool atOrBelowKink = (s.totalBorrows * BIPS) <= (uint256(m.kinkBips) * total);

        uint256 rateBips;
        if (atOrBelowKink) {
            // rate = base + slope1 * (totalBorrows / total)
            // Computed as slope1 * totalBorrows / total (multiply before divide).
            rateBips = uint256(m.baseRateBips)
                + (uint256(m.slope1Bips) * s.totalBorrows) / total;
        } else {
            // rate = base + slope1 * kink + slope2 * (utilization - kink)
            // The excess utilization term is computed from raw state to avoid
            // multiplying a rounded utilization value:
            // slope2 * (totalBorrows*BIPS - kinkBips*total) / (total*BIPS)
            uint256 excessScaled = (s.totalBorrows * BIPS) - (uint256(m.kinkBips) * total);
            rateBips = uint256(m.baseRateBips)
                + (uint256(m.slope1Bips) * uint256(m.kinkBips)) / BIPS
                + (uint256(m.slope2Bips) * excessScaled) / (total * BIPS);
        }
        return (rateBips * RAY) / BIPS;
    }

    function _userDebt(address user, address asset) internal view returns (uint256) {
        uint256 principal = userBorrows[user][asset];
        if (principal == 0) return 0;
        uint256 idx = userBorrowIndex[user][asset];
        if (idx == 0) return principal;
        return (principal * assets[asset].borrowIndex) / idx;
    }

    function _usdValue(address asset, uint256 amount) internal view returns (uint256) {
        return (amount * assetPrices[asset]) / WAD;
    }

    function _validateModel(RateModel calldata m) internal pure {
        if (m.baseRateBips > MAX_RATE_COMPONENT_BIPS) revert RateParameterInvalid();
        if (m.slope1Bips > MAX_RATE_COMPONENT_BIPS) revert RateParameterInvalid();
        if (m.slope2Bips > MAX_RATE_COMPONENT_BIPS) revert RateParameterInvalid();
        if (m.kinkBips > BIPS) revert RateParameterInvalid();
        if (m.reserveFactorBips > BIPS) revert RateParameterInvalid();
    }
}
