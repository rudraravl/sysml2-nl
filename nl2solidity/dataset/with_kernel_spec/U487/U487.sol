// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPriceOracle {
    /// @notice USD-denominated price for `asset` scaled to 1e18.
    function getPrice(address asset) external view returns (uint256);
}

contract LendingMarket {
    using SafeMath for uint256;

    /* ============================================================== *
     *                       Constants & Immutables                   *
     * ============================================================== */
    uint256 public constant MAX_COLLATERAL_FACTOR = 8000; // 80.00% in bps
    uint256 public constant PROTOCOL_FEE_BPS = 50;         // 0.50% of accrued interest
    uint256 public constant BPS_DIVISOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant WAD = 1e18;
    uint16 public constant MAX_RATE_BPS = 50000; // 500% APR ceiling

    address public immutable operator;
    address public immutable treasury;
    IPriceOracle public immutable oracle;

    /* ============================================================== *
     *                           Storage                               *
     * ============================================================== */
    struct AssetMarket {
        bool listed;
        bool depositPaused;
        bool borrowPaused;
        uint16 baseRateBps;       // base APR component in bps
        uint16 slopeBps;          // utilization-curve slope in bps
        uint16 collateralFactor;  // 0..MAX_COLLATERAL_FACTOR in bps
        uint256 totalDeposits;    // sum of all supplied collateral
        uint256 totalBorrows;     // outstanding debt (incl. accrued interest)
        uint256 totalBorrowShares;
        uint256 lastAccrual;
        uint256 depositCap;
        uint256 borrowCap;
    }

    struct UserPosition {
        uint256 collateral;     // amount of `asset` supplied as collateral
        uint256 borrowShares;   // share of the asset's outstanding borrows
    }

    mapping(address => AssetMarket) public markets;
    mapping(address => mapping(address => UserPosition)) public positions; // user => asset => position
    mapping(address => uint256) public protocolRevenue; // asset => claimable protocol fees
    address[] public listedAssets;

    uint256 internal _locked = 1;

    /* ============================================================== *
     *                            Events                               *
     * ============================================================== */
    event Deposit(address indexed caller, address indexed asset, uint256 amount);
    event Withdraw(address indexed caller, address indexed asset, uint256 amount);
    event Borrow(address indexed caller, address indexed asset, uint256 amount, uint256 shares);
    event Repay(address indexed caller, address indexed asset, uint256 amount, uint256 shares);
    event AssetListed(
        address indexed asset,
        uint16 collateralFactor,
        uint16 baseRateBps,
        uint16 slopeBps,
        uint256 depositCap,
        uint256 borrowCap
    );
    event MarketParamsUpdated(
        address indexed asset,
        uint16 baseRateBps,
        uint16 slopeBps,
        uint16 collateralFactor
    );
    event CapsUpdated(address indexed asset, uint256 depositCap, uint256 borrowCap);
    event DepositPaused(address indexed asset, bool paused);
    event BorrowPaused(address indexed asset, bool paused);
    event ProtocolRevenueClaimed(address indexed asset, address indexed to, uint256 amount);

    /* ============================================================== *
     *                            Errors                               *
     * ============================================================== */
    error NotOperator();
    error ZeroAddress();
    error AssetNotListed();
    error AssetAlreadyListed();
    error DepositPausedError();
    error BorrowPausedError();
    error InsufficientCollateral();
    error ExceedsDepositCap();
    error ExceedsBorrowCap();
    error ZeroAmount();
    error InvalidCollateralFactor(uint16);
    error InvalidRate(uint16);
    error InsufficientBalance();
    error InsufficientLiquidity();
    error Reentrancy();
    error TransferFailed();

    /* ============================================================== *
     *                          Modifiers                             *
     * ============================================================== */
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    /* ============================================================== *
     *                          Constructor                           *
     * ============================================================== */
    constructor(address _operator, address _treasury, address _oracle) {
        if (_operator == address(0) || _treasury == address(0) || _oracle == address(0)) {
            revert ZeroAddress();
        }
        operator = _operator;
        treasury = _treasury;
        oracle = IPriceOracle(_oracle);
    }

    /* ============================================================== *
     *                       Administrative funcs                     *
     * ============================================================== */

    /// @notice Lists a new supported asset in the market.
    function listAsset(
        address asset,
        uint16 collateralFactor,
        uint16 baseRateBps,
        uint16 slopeBps,
        uint256 depositCap,
        uint256 borrowCap
    ) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (markets[asset].listed) revert AssetAlreadyListed();
        if (collateralFactor > MAX_COLLATERAL_FACTOR) revert InvalidCollateralFactor(collateralFactor);
        if (baseRateBps > MAX_RATE_BPS || slopeBps > MAX_RATE_BPS) revert InvalidRate(baseRateBps);

        AssetMarket storage m = markets[asset];
        m.listed = true;
        m.collateralFactor = collateralFactor;
        m.baseRateBps = baseRateBps;
        m.slopeBps = slopeBps;
        m.depositCap = depositCap;
        m.borrowCap = borrowCap;
        m.lastAccrual = block.timestamp;

        listedAssets.push(asset);
        emit AssetListed(asset, collateralFactor, baseRateBps, slopeBps, depositCap, borrowCap);
    }

    /// @notice Updates the interest rate and collateral factor for an asset.
    function setMarketParams(
        address asset,
        uint16 baseRateBps,
        uint16 slopeBps,
        uint16 collateralFactor
    ) external onlyOperator {
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        if (collateralFactor > MAX_COLLATERAL_FACTOR) revert InvalidCollateralFactor(collateralFactor);
        if (baseRateBps > MAX_RATE_BPS || slopeBps > MAX_RATE_BPS) revert InvalidRate(baseRateBps);

        _accrueInterest(asset);
        m.baseRateBps = baseRateBps;
        m.slopeBps = slopeBps;
        m.collateralFactor = collateralFactor;
        emit MarketParamsUpdated(asset, baseRateBps, slopeBps, collateralFactor);
    }

    /// @notice Updates the deposit and borrow caps for an asset.
    function setCaps(address asset, uint256 depositCap, uint256 borrowCap) external onlyOperator {
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        m.depositCap = depositCap;
        m.borrowCap = borrowCap;
        emit CapsUpdated(asset, depositCap, borrowCap);
    }

    /// @notice Pauses or unpauses deposits for an asset (emergency control).
    function setDepositPaused(address asset, bool paused) external onlyOperator {
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        m.depositPaused = paused;
        emit DepositPaused(asset, paused);
    }

    /// @notice Pauses or unpauses borrowing for an asset (emergency control).
    function setBorrowPaused(address asset, bool paused) external onlyOperator {
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        m.borrowPaused = paused;
        emit BorrowPaused(asset, paused);
    }

    /// @notice Claims accrued protocol fees for an asset to the treasury.
    function claimProtocolRevenue(address asset) external onlyOperator returns (uint256) {
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        uint256 amount = protocolRevenue[asset];
        if (amount == 0) revert ZeroAmount();
        protocolRevenue[asset] = 0;
        bool ok = IERC20(asset).transfer(treasury, amount);
        if (!ok) revert TransferFailed();
        emit ProtocolRevenueClaimed(asset, treasury, amount);
        return amount;
    }

    /* ============================================================== *
     *                      Core user operations                      *
     * ============================================================== */

    /// @notice Supplies `amount` of `asset` to be used as collateral.
    function deposit(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        if (m.depositPaused) revert DepositPausedError();
        _accrueInterest(asset);
        if (m.depositCap != 0 && m.totalDeposits.add(amount) > m.depositCap) revert ExceedsDepositCap();

        m.totalDeposits = m.totalDeposits.add(amount);
        positions[msg.sender][asset].collateral = positions[msg.sender][asset].collateral.add(amount);

        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit Deposit(msg.sender, asset, amount);
    }

    /// @notice Withdraws `amount` of `asset` from caller's collateral, subject to health.
    function withdraw(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        _accrueInterest(asset);

        UserPosition storage p = positions[msg.sender][asset];
        if (amount > p.collateral) revert InsufficientBalance();

        p.collateral = p.collateral.sub(amount);
        m.totalDeposits = m.totalDeposits.sub(amount);

        _requireAccountHealthy(msg.sender);

        bool ok = IERC20(asset).transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit Withdraw(msg.sender, asset, amount);
    }

    /// @notice Borrows `amount` of `asset` against the caller's collateral.
    function borrow(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        if (m.borrowPaused) revert BorrowPausedError();
        _accrueInterest(asset);

        if (m.borrowCap != 0 && m.totalBorrows.add(amount) > m.borrowCap) revert ExceedsBorrowCap();

        uint256 available = _availableLiquidity(asset);
        if (amount > available) revert InsufficientLiquidity();

        uint256 shares;
        if (m.totalBorrowShares == 0 || m.totalBorrows == 0) {
            shares = amount;
        } else {
            shares = amount.mul(m.totalBorrowShares).div(m.totalBorrows);
        }

        m.totalBorrows = m.totalBorrows.add(amount);
        m.totalBorrowShares = m.totalBorrowShares.add(shares);
        positions[msg.sender][asset].borrowShares = positions[msg.sender][asset].borrowShares.add(shares);

        _requireAccountHealthy(msg.sender);

        bool ok = IERC20(asset).transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit Borrow(msg.sender, asset, amount, shares);
    }

    /// @notice Repays up to `amount` of the caller's outstanding debt in `asset`.
    function repay(address asset, uint256 amount) external nonReentrant returns (uint256 repaid) {
        if (amount == 0) revert ZeroAmount();
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        _accrueInterest(asset);

        UserPosition storage p = positions[msg.sender][asset];
        if (p.borrowShares == 0) revert ZeroAmount();

        uint256 userDebt = _debtFromShares(asset, p.borrowShares);
        repaid = amount > userDebt ? userDebt : amount;
        if (repaid == 0) revert ZeroAmount();

        uint256 sharesToBurn = repaid.mul(m.totalBorrowShares).div(m.totalBorrows);

        p.borrowShares = p.borrowShares.sub(sharesToBurn);
        m.totalBorrowShares = m.totalBorrowShares.sub(sharesToBurn);
        m.totalBorrows = m.totalBorrows.sub(repaid);

        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), repaid);
        if (!ok) revert TransferFailed();
        emit Repay(msg.sender, asset, repaid, sharesToBurn);
    }

    /* ============================================================== *
     *                       Internal helpers                         *
     * ============================================================== */

    function _accrueInterest(address asset) internal {
        AssetMarket storage m = markets[asset];
        if (m.lastAccrual >= block.timestamp) return;
        uint256 dt = block.timestamp - m.lastAccrual;
        m.lastAccrual = block.timestamp;

        uint256 denom = BPS_DIVISOR.mul(SECONDS_PER_YEAR);
        uint256 borrows = m.totalBorrows;
        uint256 deposits = m.totalDeposits;

        uint256 interest;
        uint256 fee;

        if (borrows >= deposits) {
            // Utilization is at 100%: rate = base + slope (constants, no division).
            uint256 rateBps = uint256(m.baseRateBps).add(uint256(m.slopeBps));
            // interest = borrows * rate * dt / (BPS * SEC_PER_YEAR), multiply before divide.
            interest = borrows.mul(rateBps).mul(dt).div(denom);
            // fee = borrows * rate * dt * PROTOCOL_FEE / (BPS * SEC_PER_YEAR * BPS), multiply before divide.
            fee = borrows.mul(rateBps).mul(dt).mul(PROTOCOL_FEE_BPS).div(denom.mul(BPS_DIVISOR));
        } else {
            // Utilization < 100%: rate = base + slope * (borrows / deposits).
            // Combine the base and slope components over a common denominator so that
            // every multiplication happens before any division (no divide-before-multiply).
            // interest = (borrows * base * dt * deposits + slope * borrows * borrows * dt)
            //            / (deposits * BPS * SEC_PER_YEAR)
            uint256 num = borrows
                .mul(uint256(m.baseRateBps))
                .mul(dt)
                .mul(deposits)
                .add(uint256(m.slopeBps).mul(borrows).mul(borrows).mul(dt));
            uint256 fullDenom = deposits.mul(denom);
            interest = num.div(fullDenom);
            // fee = num * PROTOCOL_FEE / (deposits * BPS * SEC_PER_YEAR * BPS)
            fee = num.mul(PROTOCOL_FEE_BPS).div(fullDenom.mul(BPS_DIVISOR));
        }

        m.totalBorrows = m.totalBorrows.add(interest);
        protocolRevenue[asset] = protocolRevenue[asset].add(fee);
    }

    function _availableLiquidity(address asset) internal view returns (uint256) {
        uint256 bal = IERC20(asset).balanceOf(address(this));
        uint256 reserved = protocolRevenue[asset];
        if (bal <= reserved) return 0;
        return bal - reserved;
    }

    function _debtFromShares(address asset, uint256 shares) internal view returns (uint256) {
        AssetMarket storage m = markets[asset];
        if (m.totalBorrowShares == 0) return 0;
        return shares.mul(m.totalBorrows).div(m.totalBorrowShares);
    }

    function _assetValue(address asset, uint256 amount) internal view returns (uint256) {
        uint8 d = IERC20(asset).decimals();
        uint256 p = oracle.getPrice(asset);
        if (p == 0) return 0;
        return amount.mul(p).div(10 ** uint256(d));
    }

    function _accountCollateralValue(address user) internal view returns (uint256 total) {
        uint256 len = listedAssets.length;
        for (uint256 i = 0; i < len; i++) {
            address a = listedAssets[i];
            uint256 collateral = positions[user][a].collateral;
            if (collateral == 0) continue;
            uint16 cf = markets[a].collateralFactor;
            total = total.add(_assetValue(a, collateral).mul(cf).div(BPS_DIVISOR));
        }
    }

    function _accountBorrowValue(address user) internal view returns (uint256 total) {
        uint256 len = listedAssets.length;
        for (uint256 i = 0; i < len; i++) {
            address a = listedAssets[i];
            uint256 shares = positions[user][a].borrowShares;
            if (shares == 0) continue;
            uint256 debt = _debtFromShares(a, shares);
            total = total.add(_assetValue(a, debt));
        }
    }

    function _requireAccountHealthy(address user) internal view {
        uint256 borrowValue = _accountBorrowValue(user);
        if (borrowValue == 0) return;
        uint256 collateralValue = _accountCollateralValue(user);
        if (borrowValue > collateralValue) revert InsufficientCollateral();
    }

    /* ============================================================== *
     *                          Public views                          *
     * ============================================================== */

    /// @notice Forces interest accrual for an asset; callable by anyone.
    function accrueInterest(address asset) external {
        AssetMarket storage m = markets[asset];
        if (!m.listed) revert AssetNotListed();
        _accrueInterest(asset);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        uint256 coll = _accountCollateralValue(user);
        uint256 borrows = _accountBorrowValue(user);
        if (borrows == 0) return type(uint256).max;
        return coll.mul(WAD).div(borrows);
    }

    function getAccountLiquidity(address user)
        external
        view
        returns (uint256 collateralValue, uint256 borrowValue)
    {
        return (_accountCollateralValue(user), _accountBorrowValue(user));
    }

    function getUserDebt(address user, address asset) external view returns (uint256) {
        return _debtFromShares(asset, positions[user][asset].borrowShares);
    }

    /// @notice Current borrow rate in basis points. Utilization is computed as a
    ///         single multiply-then-divide ratio to avoid divide-before-multiply.
    function getBorrowRate(address asset) external view returns (uint256) {
        AssetMarket storage m = markets[asset];
        if (!m.listed) return 0;
        if (m.totalBorrows == 0) return uint256(m.baseRateBps);
        if (m.totalBorrows >= m.totalDeposits) {
            // 100% utilization: rate = base + slope.
            return uint256(m.baseRateBps).add(uint256(m.slopeBps));
        }
        // rate = base + slope * (borrows / deposits): multiply before divide.
        return uint256(m.baseRateBps).add(
            uint256(m.slopeBps).mul(m.totalBorrows).div(m.totalDeposits)
        );
    }

    function getUtilization(address asset) external view returns (uint256 utilBps) {
        AssetMarket storage m = markets[asset];
        if (m.totalDeposits == 0) return 0;
        utilBps = m.totalBorrows.mul(BPS_DIVISOR).div(m.totalDeposits);
        if (utilBps > BPS_DIVISOR) utilBps = BPS_DIVISOR;
    }

    function listedAssetsLength() external view returns (uint256) {
        return listedAssets.length;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction underflow");
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}
