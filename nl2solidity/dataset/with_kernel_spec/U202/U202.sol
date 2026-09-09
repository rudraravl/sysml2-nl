// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
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

contract RealWorldAssetCollateralizer is ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(bytes32 => mapping(address => bool)) private _roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return DEFAULT_ADMIN_ROLE;
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function _setupRole(bytes32 role, address account) internal {
        _grantRole(role, account);
    }

    uint256 public constant MIN_COLLATERALIZATION_RATIO = 15000;
    uint256 public constant LIQUIDATION_PENALTY_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable stablecoin;

    struct Asset {
        bool isApproved;
        uint256 valuation;
        uint256 totalDebt;
    }

    struct Position {
        uint256 collateral;
        uint256 debt;
    }

    mapping(address => Asset) public assets;
    mapping(address => mapping(address => Position)) public positions;

    event AssetApproved(address indexed asset, uint256 valuation);
    event AssetValuationUpdated(address indexed asset, uint256 oldValuation, uint256 newValuation);
    event CollateralizationRatioChanged(address indexed asset, address indexed user, uint256 newRatio);
    event CollateralDeposited(address indexed asset, address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed asset, address indexed user, uint256 amount);
    event DebtDrawn(address indexed asset, address indexed user, uint256 amount);
    event DebtRepaid(address indexed asset, address indexed user, uint256 amount);
    event Liquidation(
        address indexed asset,
        address indexed user,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 penalty
    );

    error AssetNotApproved();
    error AssetAlreadyApproved();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error Undercollateralized();
    error PositionHealthy();
    error DebtCeilingExceeded(uint256 requested, uint256 available);
    error InsufficientLiquidity(uint256 requested, uint256 available);

    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    function approveAsset(address asset, uint256 valuation) external onlyRole(OPERATOR_ROLE) {
        if (asset == address(0)) revert ZeroAddress();
        if (assets[asset].isApproved) revert AssetAlreadyApproved();
        if (valuation == 0) revert ZeroAmount();

        assets[asset] = Asset({
            isApproved: true,
            valuation: valuation,
            totalDebt: 0
        });

        emit AssetApproved(asset, valuation);
    }

    function updateValuation(address asset, uint256 newValuation) external onlyRole(OPERATOR_ROLE) {
        Asset storage a = assets[asset];
        if (!a.isApproved) revert AssetNotApproved();
        if (newValuation == 0) revert ZeroAmount();

        uint256 oldValuation = a.valuation;
        a.valuation = newValuation;

        emit AssetValuationUpdated(asset, oldValuation, newValuation);
    }

    function liquidate(address asset, address user) external onlyRole(OPERATOR_ROLE) nonReentrant {
        Asset storage a = assets[asset];
        if (!a.isApproved) revert AssetNotApproved();

        Position storage pos = positions[user][asset];
        if (pos.debt == 0) revert ZeroAmount();

        uint256 ratio = _getCollateralizationRatio(pos.collateral, pos.debt);
        if (ratio >= MIN_COLLATERALIZATION_RATIO) revert PositionHealthy();

        uint256 debtRepaid = pos.debt;
        uint256 penalty = (debtRepaid * LIQUIDATION_PENALTY_BPS) / BPS_DENOMINATOR;
        uint256 totalSeized = debtRepaid + penalty;

        uint256 seized = totalSeized > pos.collateral ? pos.collateral : totalSeized;

        pos.collateral -= seized;
        pos.debt = 0;
        a.totalDebt -= debtRepaid;

        stablecoin.safeTransfer(msg.sender, seized);

        emit Liquidation(asset, user, msg.sender, debtRepaid, seized, penalty);
        emit CollateralizationRatioChanged(asset, user, _getCollateralizationRatio(pos.collateral, pos.debt));
    }

    function depositCollateral(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!assets[asset].isApproved) revert AssetNotApproved();

        Position storage pos = positions[msg.sender][asset];
        pos.collateral += amount;

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(asset, msg.sender, amount);
        emit CollateralizationRatioChanged(
            asset,
            msg.sender,
            _getCollateralizationRatio(pos.collateral, pos.debt)
        );
    }

    function withdrawCollateral(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!assets[asset].isApproved) revert AssetNotApproved();

        Position storage pos = positions[msg.sender][asset];
        if (pos.collateral < amount) revert InsufficientCollateral();

        uint256 newCollateral = pos.collateral - amount;
        uint256 newRatio = _getCollateralizationRatio(newCollateral, pos.debt);
        if (pos.debt > 0 && newRatio < MIN_COLLATERALIZATION_RATIO) revert Undercollateralized();

        pos.collateral = newCollateral;
        stablecoin.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(asset, msg.sender, amount);
        emit CollateralizationRatioChanged(asset, msg.sender, newRatio);
    }

    function drawDebt(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Asset storage a = assets[asset];
        if (!a.isApproved) revert AssetNotApproved();

        if (a.totalDebt + amount > a.valuation) {
            uint256 available = a.valuation > a.totalDebt ? a.valuation - a.totalDebt : 0;
            revert DebtCeilingExceeded(amount, available);
        }

        Position storage pos = positions[msg.sender][asset];
        uint256 newDebt = pos.debt + amount;
        uint256 newRatio = _getCollateralizationRatio(pos.collateral, newDebt);
        if (newRatio < MIN_COLLATERALIZATION_RATIO) revert Undercollateralized();

        uint256 balance = stablecoin.balanceOf(address(this));
        if (balance < amount) revert InsufficientLiquidity(amount, balance);

        pos.debt = newDebt;
        a.totalDebt += amount;

        stablecoin.safeTransfer(msg.sender, amount);

        emit DebtDrawn(asset, msg.sender, amount);
        emit CollateralizationRatioChanged(asset, msg.sender, newRatio);
    }

    function repayDebt(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Asset storage a = assets[asset];
        if (!a.isApproved) revert AssetNotApproved();

        Position storage pos = positions[msg.sender][asset];
        uint256 repayAmount = amount > pos.debt ? pos.debt : amount;
        if (repayAmount == 0) revert ZeroAmount();

        pos.debt -= repayAmount;
        a.totalDebt -= repayAmount;

        stablecoin.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit DebtRepaid(asset, msg.sender, repayAmount);
        emit CollateralizationRatioChanged(
            asset,
            msg.sender,
            _getCollateralizationRatio(pos.collateral, pos.debt)
        );
    }

    function getCollateralizationRatio(address asset, address user) external view returns (uint256) {
        Position storage pos = positions[user][asset];
        return _getCollateralizationRatio(pos.collateral, pos.debt);
    }

    function getAssetInfo(address asset) external view returns (bool isApproved, uint256 valuation, uint256 totalDebt) {
        Asset storage a = assets[asset];
        return (a.isApproved, a.valuation, a.totalDebt);
    }

    function getPosition(address asset, address user) external view returns (uint256 collateral, uint256 debt) {
        Position storage pos = positions[user][asset];
        return (pos.collateral, pos.debt);
    }

    function _getCollateralizationRatio(uint256 collateral, uint256 debt) internal pure returns (uint256) {
        if (debt == 0) return type(uint256).max;
        return (collateral * BPS_DENOMINATOR) / debt;
    }
}
