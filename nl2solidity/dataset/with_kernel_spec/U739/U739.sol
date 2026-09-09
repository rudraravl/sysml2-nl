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
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: approve failed"
        );
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract AccessControl {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public virtual {
        require(account == msg.sender, "AccessControl: can only renounce for self");
        _revokeRole(role, account);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}

contract CDPManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant RATIO_PRECISION = 10000; // basis points
    uint256 public constant MIN_COLLATERAL_RATIO = 15000; // 150% in bps
    uint256 public constant DEFAULT_LIQUIDATION_FEE = 50; // 0.5% in bps
    uint256 public constant PRICE_PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                            COLLATERAL CONFIG
    //////////////////////////////////////////////////////////////*/

    struct CollateralConfig {
        bool active;
        uint256 minCollateralRatio; // basis points, >= 15000
        uint256 liquidationFee; // basis points, applied to liquidated debt
    }

    // collateralToken => debtToken => config
    mapping(address => mapping(address => CollateralConfig)) public collateralConfigs;

    // collateralToken => debtToken => price of one unit of collateral denominated in debt tokens (1e18 precision)
    mapping(address => mapping(address => uint256)) public pairPrices;

    /*//////////////////////////////////////////////////////////////
                               POSITIONS
    //////////////////////////////////////////////////////////////*/

    struct Position {
        uint256 collateral; // amount of collateral token deposited
        uint256 debt; // amount of debt token owed
    }

    // user => collateralToken => debtToken => Position
    mapping(address => mapping(address => mapping(address => Position))) public positions;

    /*//////////////////////////////////////////////////////////////
                              GLOBAL STATE
    //////////////////////////////////////////////////////////////*/

    bool public borrowingPaused;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed user,
        address indexed collateral,
        address indexed debt,
        uint256 amount,
        uint256 newCollateral,
        uint256 newDebt
    );
    event Borrow(
        address indexed user,
        address indexed collateral,
        address indexed debt,
        uint256 amount,
        uint256 newCollateral,
        uint256 newDebt
    );
    event Repay(
        address indexed user,
        address indexed collateral,
        address indexed debt,
        uint256 amount,
        uint256 newCollateral,
        uint256 newDebt
    );
    event Withdraw(
        address indexed user,
        address indexed collateral,
        address indexed debt,
        uint256 amount,
        uint256 newCollateral,
        uint256 newDebt
    );
    event Liquidate(
        address indexed liquidator,
        address indexed user,
        address indexed collateral,
        address debt,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 feeCollected,
        uint256 newCollateral,
        uint256 newDebt
    );
    event CollateralPairAdded(
        address indexed collateral,
        address indexed debt,
        uint256 minCollateralRatio,
        uint256 liquidationFee
    );
    event CollateralRatioUpdated(address indexed collateral, address indexed debt, uint256 minCollateralRatio);
    event CollateralFeeUpdated(address indexed collateral, address indexed debt, uint256 liquidationFee);
    event PairPriceUpdated(address indexed collateral, address indexed debt, uint256 price);
    event BorrowingPausedSet(bool paused);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidAmount();
    error InvalidRatio();
    error InvalidPrice();
    error PairNotActive();
    error PairAlreadyActive();
    error InsufficientCollateral();
    error PositionSafe();
    error BorrowingPausedError();
    error ExceedsDebt();
    error ExceedsCollateral();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a new collateral/debt token pair with the given minimum ratio and liquidation fee.
    function addCollateralPair(
        address collateral,
        address debt,
        uint256 minCollateralRatio,
        uint256 liquidationFee
    ) external onlyRole(OPERATOR_ROLE) {
        if (collateral == address(0) || debt == address(0)) revert ZeroAddress();
        if (collateralConfigs[collateral][debt].active) revert PairAlreadyActive();
        if (minCollateralRatio < MIN_COLLATERAL_RATIO) revert InvalidRatio();
        if (liquidationFee > RATIO_PRECISION) revert InvalidRatio();

        collateralConfigs[collateral][debt] = CollateralConfig({
            active: true,
            minCollateralRatio: minCollateralRatio,
            liquidationFee: liquidationFee
        });

        emit CollateralPairAdded(collateral, debt, minCollateralRatio, liquidationFee);
    }

    /// @notice Adjusts the minimum collateralization ratio for an existing pair.
    function setCollateralRatio(
        address collateral,
        address debt,
        uint256 minCollateralRatio
    ) external onlyRole(OPERATOR_ROLE) {
        CollateralConfig storage cfg = collateralConfigs[collateral][debt];
        if (!cfg.active) revert PairNotActive();
        if (minCollateralRatio < MIN_COLLATERAL_RATIO) revert InvalidRatio();

        cfg.minCollateralRatio = minCollateralRatio;
        emit CollateralRatioUpdated(collateral, debt, minCollateralRatio);
    }

    /// @notice Adjusts the liquidation fee for an existing pair.
    function setCollateralFee(
        address collateral,
        address debt,
        uint256 liquidationFee
    ) external onlyRole(OPERATOR_ROLE) {
        CollateralConfig storage cfg = collateralConfigs[collateral][debt];
        if (!cfg.active) revert PairNotActive();
        if (liquidationFee > RATIO_PRECISION) revert InvalidRatio();

        cfg.liquidationFee = liquidationFee;
        emit CollateralFeeUpdated(collateral, debt, liquidationFee);
    }

    /// @notice Sets the price of one unit of collateral denominated in debt tokens (1e18 precision).
    function setPairPrice(
        address collateral,
        address debt,
        uint256 price
    ) external onlyRole(OPERATOR_ROLE) {
        if (price == 0) revert InvalidPrice();
        pairPrices[collateral][debt] = price;
        emit PairPriceUpdated(collateral, debt, price);
    }

    /// @notice Pauses or unpauses borrowing globally.
    function setBorrowingPaused(bool paused) external onlyRole(OPERATOR_ROLE) {
        borrowingPaused = paused;
        emit BorrowingPausedSet(paused);
    }

    /*//////////////////////////////////////////////////////////////
                          CDP OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits collateral into the caller's position for the given pair.
    function deposit(address collateral, address debt, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[collateral][debt];
        if (!cfg.active) revert PairNotActive();

        Position storage pos = positions[msg.sender][collateral][debt];
        pos.collateral += amount;

        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, collateral, debt, amount, pos.collateral, pos.debt);
    }

    /// @notice Borrows debt tokens against the caller's collateral.
    function borrow(address collateral, address debt, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (borrowingPaused) revert BorrowingPausedError();
        CollateralConfig storage cfg = collateralConfigs[collateral][debt];
        if (!cfg.active) revert PairNotActive();

        Position storage pos = positions[msg.sender][collateral][debt];
        pos.debt += amount;

        _requireSafe(pos, collateral, debt, cfg.minCollateralRatio);

        IERC20(debt).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, collateral, debt, amount, pos.collateral, pos.debt);
    }

    /// @notice Repays debt, transferring debt tokens from the caller into the contract.
    function repay(address collateral, address debt, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender][collateral][debt];
        if (amount > pos.debt) revert ExceedsDebt();

        pos.debt -= amount;

        IERC20(debt).safeTransferFrom(msg.sender, address(this), amount);

        emit Repay(msg.sender, collateral, debt, amount, pos.collateral, pos.debt);
    }

    /// @notice Withdraws excess collateral, provided the position remains safe.
    function withdraw(address collateral, address debt, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[collateral][debt];
        if (!cfg.active) revert PairNotActive();
        Position storage pos = positions[msg.sender][collateral][debt];
        if (amount > pos.collateral) revert ExceedsCollateral();

        pos.collateral -= amount;
        _requireSafe(pos, collateral, debt, cfg.minCollateralRatio);

        IERC20(collateral).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, collateral, debt, amount, pos.collateral, pos.debt);
    }

    /// @notice Liquidates an undercollateralized position. The caller repays debt
    ///         and receives collateral plus the liquidation fee.
    function liquidate(
        address user,
        address collateral,
        address debt,
        uint256 debtToRepay
    ) external nonReentrant {
        if (user == address(0)) revert ZeroAddress();
        if (debtToRepay == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfigs[collateral][debt];
        if (!cfg.active) revert PairNotActive();
        Position storage pos = positions[user][collateral][debt];
        if (debtToRepay > pos.debt) revert ExceedsDebt();

        // Position must be unsafe to liquidate.
        if (_isSafe(pos, collateral, debt, cfg.minCollateralRatio)) revert PositionSafe();

        uint256 price = pairPrices[collateral][debt];
        if (price == 0) revert InvalidPrice();

        // Collateral to seize = debtToRepay (in debt) converted to collateral,
        // multiplied by (1 + liquidationFee).
        uint256 collateralToSeize = (debtToRepay * PRICE_PRECISION * (RATIO_PRECISION + cfg.liquidationFee))
            / (price * RATIO_PRECISION);

        uint256 feeCollected = (collateralToSeize * cfg.liquidationFee) / (RATIO_PRECISION + cfg.liquidationFee);

        // Cap at available collateral.
        if (collateralToSeize > pos.collateral) {
            collateralToSeize = pos.collateral;
            feeCollected = (collateralToSeize * cfg.liquidationFee) / (RATIO_PRECISION + cfg.liquidationFee);
        }

        // Effects: update position state.
        pos.debt -= debtToRepay;
        pos.collateral -= collateralToSeize;

        // Interactions: pull debt from liquidator, send collateral to liquidator.
        IERC20(debt).safeTransferFrom(msg.sender, address(this), debtToRepay);
        IERC20(collateral).safeTransfer(msg.sender, collateralToSeize);

        emit Liquidate(
            msg.sender,
            user,
            collateral,
            debt,
            debtToRepay,
            collateralToSeize,
            feeCollected,
            pos.collateral,
            pos.debt
        );
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _requireSafe(
        Position storage pos,
        address collateral,
        address debt,
        uint256 minRatio
    ) internal view {
        if (!_isSafe(pos, collateral, debt, minRatio)) revert InsufficientCollateral();
    }

    function _isSafe(
        Position memory pos,
        address collateral,
        address debt,
        uint256 minRatio
    ) internal view returns (bool) {
        if (pos.debt == 0) return true;
        uint256 price = pairPrices[collateral][debt];
        if (price == 0) revert InvalidPrice();

        // Collateral value denominated in debt tokens.
        uint256 collateralValue = (pos.collateral * price) / PRICE_PRECISION;
        // Required collateral value to satisfy the minimum ratio.
        uint256 requiredValue = (pos.debt * minRatio) / RATIO_PRECISION;

        return collateralValue >= requiredValue;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPosition(
        address user,
        address collateral,
        address debt
    ) external view returns (uint256 collateralAmount, uint256 debtAmount) {
        Position memory pos = positions[user][collateral][debt];
        return (pos.collateral, pos.debt);
    }

    function isPositionSafe(
        address user,
        address collateral,
        address debt
    ) external view returns (bool) {
        Position memory pos = positions[user][collateral][debt];
        CollateralConfig memory cfg = collateralConfigs[collateral][debt];
        if (!cfg.active) return false;
        return _isSafe(pos, collateral, debt, cfg.minCollateralRatio);
    }

    function getCollateralValue(
        address user,
        address collateral,
        address debt
    ) external view returns (uint256) {
        Position memory pos = positions[user][collateral][debt];
        uint256 price = pairPrices[collateral][debt];
        if (price == 0) return 0;
        return (pos.collateral * price) / PRICE_PRECISION;
    }

    /// @notice Returns the additional debt the user can borrow while staying safe.
    function maxBorrowable(
        address user,
        address collateral,
        address debt
    ) external view returns (uint256) {
        Position memory pos = positions[user][collateral][debt];
        CollateralConfig memory cfg = collateralConfigs[collateral][debt];
        uint256 price = pairPrices[collateral][debt];
        if (price == 0 || !cfg.active) return 0;

        uint256 collateralValue = (pos.collateral * price) / PRICE_PRECISION;
        uint256 maxDebt = (collateralValue * RATIO_PRECISION) / cfg.minCollateralRatio;
        if (maxDebt <= pos.debt) return 0;
        return maxDebt - pos.debt;
    }

    /// @notice Returns the collateral amount that can be withdrawn while staying safe.
    function maxWithdrawable(
        address user,
        address collateral,
        address debt
    ) external view returns (uint256) {
        Position memory pos = positions[user][collateral][debt];
        CollateralConfig memory cfg = collateralConfigs[collateral][debt];
        uint256 price = pairPrices[collateral][debt];
        if (price == 0 || !cfg.active) return 0;
        if (pos.debt == 0) return pos.collateral;

        uint256 requiredCollateral = (pos.debt * cfg.minCollateralRatio * PRICE_PRECISION)
            / (RATIO_PRECISION * price);
        if (pos.collateral <= requiredCollateral) return 0;
        return pos.collateral - requiredCollateral;
    }
}
