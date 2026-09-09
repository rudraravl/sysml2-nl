// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface IRateCurve {
    function getRate(uint256 term, uint256 utilization) external view returns (uint256);
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    error ReentrantCall();
}

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    modifier onlyRole(bytes32 role) {
        if (!_roles[role][msg.sender]) revert AccessControlUnauthorized(msg.sender, role);
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function _grantRole(bytes32 role, address account) internal {
        _roles[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function _revokeRole(bytes32 role, address account) internal {
        _roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(role, account);
    }

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    error AccessControlUnauthorized(address account, bytes32 role);
}

contract FixedTermLending is AccessControl, ReentrancyGuard {
    ////////////////////////////////////////////////////////////////
    //                          CONSTANTS                          //
    ////////////////////////////////////////////////////////////////

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant MAX_LTV_BPS = 7500; // 75%
    uint256 public constant ORIGINATION_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant PRICE_SCALE = 1e18;
    uint256 public constant RATE_SCALE = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MIN_TERM = 1 days;
    uint256 public constant MAX_TERM = 365 days;

    ////////////////////////////////////////////////////////////////
    //                            TYPES                           //
    ////////////////////////////////////////////////////////////////

    struct Position {
        address owner;
        address collateralAsset;
        uint256 collateralAmount;
        address borrowAsset;
        uint256 principal;
        uint256 interestRate; // annual rate, scaled 1e18
        uint256 startTime;
        uint256 maturity;
        uint256 repaidAmount;
        bool active;
    }

    struct AssetConfig {
        bool supported;
        bool isCollateral;
        bool isBorrowable;
        uint256 depositCap;
    }

    struct PoolConfig {
        bool active;
        address rateCurve;
        uint256 totalLiquidity;
        uint256 totalBorrowed;
    }

    ////////////////////////////////////////////////////////////////
    //                           STORAGE                          //
    ////////////////////////////////////////////////////////////////

    IPriceOracle public oracle;

    mapping(address => AssetConfig) public assetConfig;
    mapping(uint256 => PoolConfig) public poolConfig;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionIds;
    mapping(address => uint256) public collateralBalances;
    mapping(address => uint256) public borrowBalances;

    uint256 public nextPositionId = 1;
    uint256 public nextPoolId = 1;

    ////////////////////////////////////////////////////////////////
    //                            EVENTS                          //
    ////////////////////////////////////////////////////////////////

    event CollateralDeposited(uint256 indexed positionId, address indexed user, address indexed asset, uint256 amount);
    event CollateralWithdrawn(uint256 indexed positionId, address indexed user, address indexed asset, uint256 amount);
    event Borrowed(
        uint256 indexed positionId,
        address indexed user,
        address indexed borrowAsset,
        uint256 principal,
        uint256 amountReceived,
        uint256 fee,
        uint256 maturity,
        uint256 interestRate
    );
    event Repaid(uint256 indexed positionId, address indexed user, address indexed borrowAsset, uint256 amount);
    event AssetAdded(address indexed asset, bool isCollateral, bool isBorrowable, uint256 depositCap);
    event AssetRemoved(address indexed asset);
    event PoolAdded(uint256 indexed poolId, address indexed rateCurve);
    event PoolUpdated(uint256 indexed poolId, address indexed rateCurve, bool active);
    event LiquiditySupplied(uint256 indexed poolId, address indexed supplier, address indexed asset, uint256 amount);
    event OracleSet(address indexed oracle);
    event PositionClosed(uint256 indexed positionId);

    ////////////////////////////////////////////////////////////////
    //                            ERRORS                          //
    ////////////////////////////////////////////////////////////////

    error ZeroAddress();
    error AmountZero();
    error AssetNotSupported();
    error AssetNotCollateral();
    error AssetNotBorrowable();
    error InsufficientCollateral();
    error ExceedsMaxLTV(uint256 ltv, uint256 maxLtv);
    error PositionNotFound();
    error PositionNotActive();
    error NoActiveLoan();
    error OutstandingDebt();
    error LoanNotMatured();
    error InvalidTerm();
    error PoolNotFound();
    error PoolNotActive();
    error InsufficientLiquidity();
    error CapExceeded();
    error LoanAlreadyActive();
    error NotPositionOwner();
    error TransferFailed();

    ////////////////////////////////////////////////////////////////
    //                         CONSTRUCTOR                        //
    ////////////////////////////////////////////////////////////////

    constructor(address admin, address _oracle) {
        if (admin == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        emit OracleSet(_oracle);
    }

    ////////////////////////////////////////////////////////////////
    //                      ADMIN FUNCTIONS                       //
    ////////////////////////////////////////////////////////////////

    function setOracle(address _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        emit OracleSet(_oracle);
    }

    function addAsset(
        address asset,
        bool isCollateral,
        bool isBorrowable,
        uint256 depositCap
    ) external onlyRole(OPERATOR_ROLE) {
        if (asset == address(0)) revert ZeroAddress();
        assetConfig[asset] = AssetConfig({
            supported: true,
            isCollateral: isCollateral,
            isBorrowable: isBorrowable,
            depositCap: depositCap
        });
        emit AssetAdded(asset, isCollateral, isBorrowable, depositCap);
    }

    function removeAsset(address asset) external onlyRole(OPERATOR_ROLE) {
        if (!assetConfig[asset].supported) revert AssetNotSupported();
        delete assetConfig[asset];
        emit AssetRemoved(asset);
    }

    function addPool(address rateCurve) external onlyRole(OPERATOR_ROLE) returns (uint256 poolId) {
        if (rateCurve == address(0)) revert ZeroAddress();
        poolId = nextPoolId++;
        poolConfig[poolId] = PoolConfig({
            active: true,
            rateCurve: rateCurve,
            totalLiquidity: 0,
            totalBorrowed: 0
        });
        emit PoolAdded(poolId, rateCurve);
    }

    function updatePool(uint256 poolId, address rateCurve, bool active) external onlyRole(OPERATOR_ROLE) {
        if (poolId == 0 || poolId >= nextPoolId) revert PoolNotFound();
        PoolConfig storage pc = poolConfig[poolId];
        pc.rateCurve = rateCurve;
        pc.active = active;
        emit PoolUpdated(poolId, rateCurve, active);
    }

    ////////////////////////////////////////////////////////////////
    //                    USER FUNCTIONS                          //
    ////////////////////////////////////////////////////////////////

    function depositCollateral(uint256 positionId, address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        AssetConfig storage ac = assetConfig[asset];
        if (!ac.supported || !ac.isCollateral) revert AssetNotCollateral();
        if (ac.depositCap > 0 && collateralBalances[asset] + amount > ac.depositCap) revert CapExceeded();

        // Effects before interactions
        if (positionId == 0) {
            positionId = nextPositionId++;
            positions[positionId] = Position({
                owner: msg.sender,
                collateralAsset: asset,
                collateralAmount: amount,
                borrowAsset: address(0),
                principal: 0,
                interestRate: 0,
                startTime: 0,
                maturity: 0,
                repaidAmount: 0,
                active: true
            });
            userPositionIds[msg.sender].push(positionId);
        } else {
            Position storage pos = positions[positionId];
            if (!pos.active) revert PositionNotFound();
            if (pos.owner != msg.sender) revert NotPositionOwner();
            if (pos.collateralAsset != asset) revert AssetNotCollateral();
            pos.collateralAmount += amount;
        }

        collateralBalances[asset] += amount;
        emit CollateralDeposited(positionId, msg.sender, asset, amount);

        // Interactions
        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
    }

    function borrow(
        uint256 positionId,
        uint256 poolId,
        address borrowAsset,
        uint256 amount,
        uint256 term
    ) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (term < MIN_TERM || term > MAX_TERM) revert InvalidTerm();

        if (positionId == 0 || positionId >= nextPositionId) revert PositionNotFound();
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotActive();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (pos.principal > 0) revert LoanAlreadyActive();
        if (pos.collateralAmount == 0) revert InsufficientCollateral();

        if (!assetConfig[borrowAsset].supported || !assetConfig[borrowAsset].isBorrowable) revert AssetNotBorrowable();

        if (poolId == 0 || poolId >= nextPoolId) revert PoolNotFound();
        PoolConfig storage pc = poolConfig[poolId];
        if (!pc.active) revert PoolNotActive();
        if (pc.totalLiquidity - pc.totalBorrowed < amount) revert InsufficientLiquidity();

        _checkLTV(pos.collateralAmount, pos.collateralAsset, amount, borrowAsset);
        uint256 rate = _getRate(pc, term);
        uint256 fee = (amount * ORIGINATION_FEE_BPS) / BPS_DENOM;
        uint256 amountReceived = amount - fee;

        // Effects before interactions
        pos.borrowAsset = borrowAsset;
        pos.principal = amount;
        pos.interestRate = rate;
        pos.startTime = block.timestamp;
        pos.maturity = block.timestamp + term;

        pc.totalBorrowed += amount;
        borrowBalances[borrowAsset] += amount;

        emit Borrowed(positionId, msg.sender, borrowAsset, amount, amountReceived, fee, pos.maturity, rate);

        // Interactions
        bool ok = IERC20(borrowAsset).transfer(msg.sender, amountReceived);
        if (!ok) revert TransferFailed();
    }

    function repay(uint256 positionId, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (positionId == 0 || positionId >= nextPositionId) revert PositionNotFound();
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotActive();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (pos.principal == 0) revert NoActiveLoan();

        uint256 totalOwed = _computeTotalOwed(pos);
        uint256 repayAmount = amount > totalOwed ? totalOwed : amount;
        address borrowAsset = pos.borrowAsset;

        // Effects before interactions
        pos.repaidAmount += repayAmount;
        borrowBalances[borrowAsset] -= repayAmount;

        emit Repaid(positionId, msg.sender, borrowAsset, repayAmount);

        // Interactions
        bool ok = IERC20(borrowAsset).transferFrom(msg.sender, address(this), repayAmount);
        if (!ok) revert TransferFailed();
    }

    function withdrawCollateral(uint256 positionId, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (positionId == 0 || positionId >= nextPositionId) revert PositionNotFound();
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotActive();
        if (pos.owner != msg.sender) revert NotPositionOwner();
        if (amount > pos.collateralAmount) revert InsufficientCollateral();

        if (_computeTotalOwed(pos) > 0 && block.timestamp < pos.maturity) revert LoanNotMatured();

        address collateralAsset = pos.collateralAsset;

        // Effects before interactions
        pos.collateralAmount -= amount;
        collateralBalances[collateralAsset] -= amount;

        bool shouldClose = (pos.collateralAmount <= 0 && _computeTotalOwed(pos) <= 0);
        if (shouldClose) {
            pos.active = false;
        }

        emit CollateralWithdrawn(positionId, msg.sender, collateralAsset, amount);
        if (shouldClose) {
            emit PositionClosed(positionId);
        }

        // Interactions
        bool ok = IERC20(collateralAsset).transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
    }

    function closePosition(uint256 positionId) external nonReentrant {
        if (positionId == 0 || positionId >= nextPositionId) revert PositionNotFound();
        Position storage pos = positions[positionId];
        if (!pos.active) revert PositionNotActive();
        if (pos.owner != msg.sender) revert NotPositionOwner();

        uint256 owed = _computeTotalOwed(pos);
        uint256 collateralAmt = pos.collateralAmount;
        address borrowAsset = pos.borrowAsset;
        address collateralAsset = pos.collateralAsset;

        // Effects before interactions
        if (owed > 0) {
            pos.repaidAmount += owed;
            borrowBalances[borrowAsset] -= owed;
            emit Repaid(positionId, msg.sender, borrowAsset, owed);
        }

        if (collateralAmt > 0) {
            pos.collateralAmount = 0;
            collateralBalances[collateralAsset] -= collateralAmt;
            emit CollateralWithdrawn(positionId, msg.sender, collateralAsset, collateralAmt);
        }

        pos.active = false;
        emit PositionClosed(positionId);

        // Interactions
        if (owed > 0) {
            bool ok = IERC20(borrowAsset).transferFrom(msg.sender, address(this), owed);
            if (!ok) revert TransferFailed();
        }

        if (collateralAmt > 0) {
            bool ok = IERC20(collateralAsset).transfer(msg.sender, collateralAmt);
            if (!ok) revert TransferFailed();
        }
    }

    function supplyLiquidity(uint256 poolId, address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (poolId == 0 || poolId >= nextPoolId) revert PoolNotFound();
        AssetConfig storage ac = assetConfig[asset];
        if (!ac.supported || !ac.isBorrowable) revert AssetNotBorrowable();
        PoolConfig storage pc = poolConfig[poolId];
        if (!pc.active) revert PoolNotActive();

        // Effects before interactions
        pc.totalLiquidity += amount;
        emit LiquiditySupplied(poolId, msg.sender, asset, amount);

        // Interactions
        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
    }

    ////////////////////////////////////////////////////////////////
    //                      VIEW FUNCTIONS                        //
    ////////////////////////////////////////////////////////////////

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    function computeTotalOwed(uint256 positionId) external view returns (uint256) {
        return _computeTotalOwed(positions[positionId]);
    }

    function computeLTV(uint256 positionId) external view returns (uint256) {
        Position storage pos = positions[positionId];
        if (pos.collateralAmount == 0) return type(uint256).max;
        uint256 collateralPrice = oracle.getPrice(pos.collateralAsset);
        if (collateralPrice == 0) return type(uint256).max;
        uint256 owed = _computeTotalOwed(pos);
        uint256 borrowPrice = oracle.getPrice(pos.borrowAsset);
        // ltv = (owed * borrowPrice * BPS_DENOM) / (collateralAmount * collateralPrice)
        // Avoids divide-before-multiply by combining into a single division.
        return (owed * borrowPrice * BPS_DENOM) / (pos.collateralAmount * collateralPrice);
    }

    function isPositionSafe(uint256 positionId) external view returns (bool) {
        Position storage pos = positions[positionId];
        if (pos.collateralAmount == 0) return false;
        uint256 collateralPrice = oracle.getPrice(pos.collateralAsset);
        if (collateralPrice == 0) return false;
        uint256 owed = _computeTotalOwed(pos);
        uint256 borrowPrice = oracle.getPrice(pos.borrowAsset);
        // ltv = (owed * borrowPrice * BPS_DENOM) / (collateralAmount * collateralPrice)
        uint256 ltv = (owed * borrowPrice * BPS_DENOM) / (pos.collateralAmount * collateralPrice);
        return ltv <= MAX_LTV_BPS;
    }

    function getPoolAvailableLiquidity(uint256 poolId) external view returns (uint256) {
        PoolConfig storage pc = poolConfig[poolId];
        return pc.totalLiquidity - pc.totalBorrowed;
    }

    ////////////////////////////////////////////////////////////////
    //                    INTERNAL FUNCTIONS                      //
    ////////////////////////////////////////////////////////////////

    function _computeTotalOwed(Position storage pos) internal view returns (uint256) {
        if (pos.principal == 0) return 0;
        uint256 endTime = block.timestamp < pos.maturity ? block.timestamp : pos.maturity;
        uint256 duration = endTime > pos.startTime ? endTime - pos.startTime : 0;
        uint256 accruedInterest = (pos.principal * pos.interestRate * duration) / (SECONDS_PER_YEAR * RATE_SCALE);
        uint256 total = pos.principal + accruedInterest;
        return total > pos.repaidAmount ? total - pos.repaidAmount : 0;
    }

    function _checkLTV(
        uint256 collateralAmount,
        address collateralAsset,
        uint256 borrowAmount,
        address borrowAsset
    ) internal view {
        uint256 collateralPrice = oracle.getPrice(collateralAsset);
        if (collateralPrice == 0) revert InsufficientCollateral();
        uint256 borrowPrice = oracle.getPrice(borrowAsset);
        // ltv = (borrowAmount * borrowPrice * BPS_DENOM) / (collateralAmount * collateralPrice)
        // Avoids divide-before-multiply by combining into a single division.
        uint256 ltv = (borrowAmount * borrowPrice * BPS_DENOM) / (collateralAmount * collateralPrice);
        if (ltv > MAX_LTV_BPS) revert ExceedsMaxLTV(ltv, MAX_LTV_BPS);
    }

    function _getRate(PoolConfig storage pc, uint256 term) internal view returns (uint256) {
        uint256 utilization = pc.totalLiquidity == 0
            ? 0
            : (pc.totalBorrowed * PRICE_SCALE) / pc.totalLiquidity;
        return IRateCurve(pc.rateCurve).getRate(term, utilization);
    }
}
