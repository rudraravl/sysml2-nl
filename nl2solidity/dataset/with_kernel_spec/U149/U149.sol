// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(address(token).code.length != 0, "SafeERC20: call to non-contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success, "SafeERC20: transfer failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transfer returned false");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(address(token).code.length != 0, "SafeERC20: call to non-contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success, "SafeERC20: transferFrom failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transferFrom returned false");
        }
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

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: account is missing role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
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

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "AccessControl: can only renounce for self");
        _revokeRole(role, account);
    }

    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return DEFAULT_ADMIN_ROLE;
    }
}

contract ERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to zero address");
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}

contract SelfRepayingLoanVault is ERC20, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Roles ============
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ============ Constants ============
    uint256 public constant YEAR = 365 days;
    uint256 public constant BPS = 10_000;
    uint256 public constant WAD = 1e18;
    uint256 public constant MINT_FEE_BPS = 50;        // 0.5%
    uint256 public constant MIN_RATIO_BPS = 12_000;    // 120%
    uint256 public constant MAX_RATIO_BPS = 20_000;    // 200%

    // ============ Structs ============
    struct CollateralConfig {
        uint256 annualYieldRateBps;
        uint256 cumulativeYieldIndex;
        uint256 lastYieldUpdate;
        bool enabled;
    }

    struct Position {
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 accruedYield;
        uint256 yieldIndex;
    }

    // ============ State ============
    uint256 public collateralizationRatioBps;
    address public treasury;

    mapping(address => CollateralConfig) public collateralConfigs;
    address[] public supportedCollateralList;
    mapping(address => bool) public isSupportedCollateral;

    mapping(address => mapping(address => Position)) public positions;

    // ============ Events ============
    event CollateralDeposited(address indexed borrower, address indexed collateral, uint256 amount);
    event LoanCreated(address indexed borrower, address indexed collateral, uint256 collateralAmount, uint256 syntheticAmount);
    event LoanRepaid(address indexed borrower, address indexed collateral, uint256 syntheticAmount, uint256 remainingDebt);
    event CollateralWithdrawn(address indexed borrower, address indexed collateral, uint256 amount);
    event YieldApplied(address indexed borrower, address indexed collateral, uint256 yieldAmount, uint256 remainingDebt);
    event CollateralTypeAdded(address indexed collateral, uint256 annualYieldRateBps);
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    // ============ Errors ============
    error ZeroAmount();
    error ZeroAddress();
    error CollateralNotSupported(address collateral);
    error CollateralAlreadySupported(address collateral);
    error InsufficientCollateral(uint256 required, uint256 available);
    error DebtOutstanding(uint256 remainingDebt);
    error AmountExceedsDebt(uint256 amount, uint256 debt);
    error RatioOutOfBounds(uint256 ratio);
    error NotOperator();
    error InvalidYieldRate();

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) revert NotOperator();
        _;
    }

    // ============ Constructor ============
    constructor(
        string memory name_,
        string memory symbol_,
        address _treasury,
        uint256 _initialRatioBps
    ) ERC20(name_, symbol_) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_initialRatioBps < MIN_RATIO_BPS || _initialRatioBps > MAX_RATIO_BPS)
            revert RatioOutOfBounds(_initialRatioBps);

        treasury = _treasury;
        collateralizationRatioBps = _initialRatioBps;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // ============ Operator Functions ============

    function addCollateralType(address collateral, uint256 annualYieldRateBps) external onlyOperator {
        if (collateral == address(0)) revert ZeroAddress();
        if (isSupportedCollateral[collateral]) revert CollateralAlreadySupported(collateral);
        if (annualYieldRateBps > BPS) revert InvalidYieldRate();

        isSupportedCollateral[collateral] = true;
        supportedCollateralList.push(collateral);

        CollateralConfig storage config = collateralConfigs[collateral];
        config.annualYieldRateBps = annualYieldRateBps;
        config.cumulativeYieldIndex = WAD;
        config.lastYieldUpdate = block.timestamp;
        config.enabled = true;

        emit CollateralTypeAdded(collateral, annualYieldRateBps);
    }

    function setCollateralizationRatio(uint256 newRatioBps) external onlyOperator {
        if (newRatioBps < MIN_RATIO_BPS || newRatioBps > MAX_RATIO_BPS)
            revert RatioOutOfBounds(newRatioBps);
        uint256 old = collateralizationRatioBps;
        collateralizationRatioBps = newRatioBps;
        emit CollateralizationRatioUpdated(old, newRatioBps);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    // ============ User Functions ============

    function depositCollateral(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!isSupportedCollateral[collateral]) revert CollateralNotSupported(collateral);

        _accrueYield(msg.sender, collateral);

        Position storage pos = positions[msg.sender][collateral];
        pos.collateralAmount += amount;

        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, collateral, amount);
    }

    function mintSynthetic(address collateral, uint256 syntheticAmount) external nonReentrant {
        if (syntheticAmount == 0) revert ZeroAmount();
        if (!isSupportedCollateral[collateral]) revert CollateralNotSupported(collateral);

        _accrueYield(msg.sender, collateral);

        Position storage pos = positions[msg.sender][collateral];

        uint256 feeAmount = (syntheticAmount * MINT_FEE_BPS) / BPS;
        uint256 netAmount = syntheticAmount - feeAmount;

        uint256 newDebt = pos.debtAmount + syntheticAmount;
        uint256 maxDebt = (pos.collateralAmount * BPS) / collateralizationRatioBps;

        if (newDebt > maxDebt) revert InsufficientCollateral(newDebt, maxDebt);

        pos.debtAmount = newDebt;

        _mint(msg.sender, netAmount);
        _mint(treasury, feeAmount);

        emit LoanCreated(msg.sender, collateral, pos.collateralAmount, syntheticAmount);
    }

    function repaySynthetic(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!isSupportedCollateral[collateral]) revert CollateralNotSupported(collateral);

        _accrueYield(msg.sender, collateral);

        Position storage pos = positions[msg.sender][collateral];
        if (amount > pos.debtAmount) revert AmountExceedsDebt(amount, pos.debtAmount);

        _burn(msg.sender, amount);
        pos.debtAmount -= amount;

        emit LoanRepaid(msg.sender, collateral, amount, pos.debtAmount);
    }

    function withdrawCollateral(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!isSupportedCollateral[collateral]) revert CollateralNotSupported(collateral);

        _accrueYield(msg.sender, collateral);

        Position storage pos = positions[msg.sender][collateral];
        if (pos.debtAmount > 0) revert DebtOutstanding(pos.debtAmount);
        if (amount > pos.collateralAmount) revert InsufficientCollateral(amount, pos.collateralAmount);

        pos.collateralAmount -= amount;

        IERC20(collateral).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, collateral, amount);
    }

    // ============ View Functions ============

    function getPosition(address user, address collateral)
        external
        view
        returns (uint256 collateralAmount, uint256 debtAmount, uint256 accruedYield)
    {
        Position storage pos = positions[user][collateral];
        return (pos.collateralAmount, pos.debtAmount, pos.accruedYield);
    }

    function getSupportedCollaterals() external view returns (address[] memory) {
        return supportedCollateralList;
    }

    function getCollateralConfig(address collateral)
        external
        view
        returns (uint256 annualYieldRateBps, uint256 cumulativeYieldIndex, uint256 lastYieldUpdate, bool enabled)
    {
        CollateralConfig storage config = collateralConfigs[collateral];
        return (config.annualYieldRateBps, config.cumulativeYieldIndex, config.lastYieldUpdate, config.enabled);
    }

    function getMaxMintable(address user, address collateral) external view returns (uint256) {
        Position storage pos = positions[user][collateral];
        if (pos.collateralAmount == 0) return 0;
        uint256 maxDebt = (pos.collateralAmount * BPS) / collateralizationRatioBps;
        if (maxDebt <= pos.debtAmount) return 0;
        return maxDebt - pos.debtAmount;
    }

    function getPendingYield(address user, address collateral) external view returns (uint256) {
        Position storage pos = positions[user][collateral];
        if (pos.collateralAmount == 0) return 0;

        CollateralConfig storage config = collateralConfigs[collateral];
        if (!config.enabled) return 0;

        uint256 currentIndex = _previewYieldIndex(collateral);
        if (currentIndex <= pos.yieldIndex) return 0;

        return (pos.collateralAmount * (currentIndex - pos.yieldIndex)) / WAD;
    }

    // ============ Internal Functions ============

    function _accrueYield(address user, address collateral) internal {
        CollateralConfig storage config = collateralConfigs[collateral];
        if (!config.enabled) revert CollateralNotSupported(collateral);

        _updateYieldIndex(collateral);

        Position storage pos = positions[user][collateral];

        if (pos.collateralAmount == 0) {
            pos.yieldIndex = config.cumulativeYieldIndex;
            return;
        }

        if (config.cumulativeYieldIndex <= pos.yieldIndex) {
            return;
        }

        uint256 deltaIndex = config.cumulativeYieldIndex - pos.yieldIndex;
        uint256 accrued = (pos.collateralAmount * deltaIndex) / WAD;

        pos.accruedYield += accrued;

        if (pos.debtAmount > 0) {
            uint256 applied = accrued > pos.debtAmount ? pos.debtAmount : accrued;
            pos.debtAmount -= applied;
            emit YieldApplied(user, collateral, applied, pos.debtAmount);
        }

        pos.yieldIndex = config.cumulativeYieldIndex;
    }

    function _updateYieldIndex(address collateral) internal {
        CollateralConfig storage config = collateralConfigs[collateral];

        if (config.lastYieldUpdate == 0 || config.annualYieldRateBps == 0) {
            config.lastYieldUpdate = block.timestamp;
            return;
        }

        if (block.timestamp <= config.lastYieldUpdate) {
            return;
        }

        uint256 elapsed = block.timestamp - config.lastYieldUpdate;
        uint256 delta = (elapsed * config.annualYieldRateBps * WAD) / (YEAR * BPS);
        config.cumulativeYieldIndex += delta;
        config.lastYieldUpdate = block.timestamp;
    }

    function _previewYieldIndex(address collateral) internal view returns (uint256) {
        CollateralConfig storage config = collateralConfigs[collateral];
        if (config.lastYieldUpdate == 0 || config.annualYieldRateBps == 0) {
            return config.cumulativeYieldIndex;
        }
        if (block.timestamp <= config.lastYieldUpdate) {
            return config.cumulativeYieldIndex;
        }
        uint256 elapsed = block.timestamp - config.lastYieldUpdate;
        uint256 delta = (elapsed * config.annualYieldRateBps * WAD) / (YEAR * BPS);
        return config.cumulativeYieldIndex + delta;
    }
}
