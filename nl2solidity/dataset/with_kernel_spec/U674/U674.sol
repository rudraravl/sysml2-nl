// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeTransferLib {
    error TransferFailed();
    error TransferFromFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFromFailed();
    }
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Roles {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    error AccessControlUnauthorizedAccount(address account, bytes32 role);
    error AccessControlBadConfirmation();

    modifier onlyRole(bytes32 role) {
        _checkRole(role);
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
        if (msg.sender != account) revert AccessControlBadConfirmation();
        _revokeRole(role, account);
    }

    function _checkRole(bytes32 role) internal view {
        if (!hasRole(role, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
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

contract ERC20 {
    string private _name;
    string private _symbol;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 internal _totalSupply;

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSpender(address spender);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ERC20InvalidSpender(spender);
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert ERC20InsufficientAllowance(msg.sender, allowed, amount);
        unchecked {
            _allowances[from][msg.sender] = allowed - amount;
        }
        emit Approval(from, msg.sender, allowed - amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (to == address(0)) revert ERC20InvalidReceiver(to);
        uint256 balance = _balances[from];
        if (balance < amount) revert ERC20InsufficientBalance(from, balance, amount);
        unchecked {
            _balances[from] = balance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ERC20InvalidReceiver(to);
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ERC20InvalidSender(from);
        uint256 balance = _balances[from];
        if (balance < amount) revert ERC20InsufficientBalance(from, balance, amount);
        unchecked {
            _balances[from] = balance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}

contract StablecoinVault is ERC20, Roles, ReentrancyGuard {
    using SafeTransferLib for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public immutable collateralToken;
    IPriceOracle public immutable oracle;
    uint8 public immutable collateralDecimals;

    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 lastAccrual;
    }

    mapping(address => Position) public positions;

    uint256 public totalCollateral;
    uint256 public totalDebt;

    uint256 public minCollateralRatio;
    uint256 public stabilityFeeRate;

    bool public mintPaused;

    address public treasury;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant YEAR = 365 days;
    uint256 public constant MIN_MIN_COLLATERAL_RATIO = 10_000;
    uint256 public constant MAX_MIN_COLLATERAL_RATIO = 20_000;
    uint256 public constant MAX_STABILITY_FEE_RATE = 1_000;
    uint256 public constant PRICE_PRECISION = 1e18;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Minted(address indexed user, uint256 amount, uint256 fee);
    event Repaid(address indexed user, uint256 amount, uint256 fee);
    event MinCollateralRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event StabilityFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event MintPausedSet(bool paused);

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientCollateral();
    error MintPausedError();
    error RatioOutOfBounds();
    error FeeRateOutOfBounds();
    error InsufficientBalance();
    error InsufficientDebt();
    error InvalidDecimals();

    constructor(
        address collateral,
        address priceOracle,
        uint8 collateralDecimals_,
        address admin,
        address treasury_
    ) ERC20("Decentralized Stablecoin", "DSC") {
        if (collateral == address(0)) revert ZeroAddress();
        if (priceOracle == address(0)) revert ZeroAddress();
        if (admin == address(0)) revert ZeroAddress();
        if (treasury_ == address(0)) revert ZeroAddress();
        if (collateralDecimals_ > 18) revert InvalidDecimals();

        collateralToken = IERC20(collateral);
        oracle = IPriceOracle(priceOracle);
        collateralDecimals = collateralDecimals_;
        treasury = treasury_;

        minCollateralRatio = 15_000;
        stabilityFeeRate = 50;

        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function _accrueFee(Position storage p) internal returns (uint256 fee) {
        if (p.lastAccrual == 0) {
            p.lastAccrual = block.timestamp;
            return 0;
        }
        if (p.debt == 0) {
            p.lastAccrual = block.timestamp;
            return 0;
        }
        if (block.timestamp <= p.lastAccrual) {
            return 0;
        }

        uint256 elapsed = block.timestamp - p.lastAccrual;
        fee = (p.debt * stabilityFeeRate * elapsed) / (BASIS_POINTS * YEAR);
        if (fee > 0) {
            p.debt += fee;
            totalDebt += fee;
            _mint(treasury, fee);
        }
        p.lastAccrual = block.timestamp;
    }

    function _collateralValue(uint256 collateralAmount) internal view returns (uint256) {
        uint256 price = oracle.getPrice(address(collateralToken));
        uint256 normalized = collateralAmount * (10 ** (18 - collateralDecimals));
        return (normalized * price) / PRICE_PRECISION;
    }

    function _isSafe(uint256 collateralAmount, uint256 debt) internal view returns (bool) {
        if (debt == 0) return true;
        uint256 collateralValue = _collateralValue(collateralAmount);
        return collateralValue * BASIS_POINTS >= debt * minCollateralRatio;
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage p = positions[msg.sender];
        _accrueFee(p);

        p.collateral += amount;
        totalCollateral += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    function mint(uint256 amount) external nonReentrant {
        if (mintPaused) revert MintPausedError();
        if (amount == 0) revert ZeroAmount();

        Position storage p = positions[msg.sender];
        uint256 fee = _accrueFee(p);

        p.debt += amount;
        totalDebt += amount;

        if (!_isSafe(p.collateral, p.debt)) revert InsufficientCollateral();

        _mint(msg.sender, amount);

        emit Minted(msg.sender, amount, fee);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage p = positions[msg.sender];
        uint256 fee = _accrueFee(p);

        if (p.debt == 0) revert InsufficientDebt();

        uint256 repayAmount = amount > p.debt ? p.debt : amount;
        if (balanceOf(msg.sender) < repayAmount) revert InsufficientBalance();

        p.debt -= repayAmount;
        totalDebt -= repayAmount;

        _burn(msg.sender, repayAmount);

        emit Repaid(msg.sender, repayAmount, fee);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Position storage p = positions[msg.sender];
        _accrueFee(p);

        if (p.collateral < amount) revert InsufficientBalance();

        p.collateral -= amount;
        totalCollateral -= amount;

        if (!_isSafe(p.collateral, p.debt)) revert InsufficientCollateral();

        collateralToken.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function getPosition(address user)
        external
        view
        returns (uint256 collateral, uint256 debt, uint256 lastAccrual)
    {
        Position storage p = positions[user];
        return (p.collateral, p.debt, p.lastAccrual);
    }

    function collateralizationRatio(address user) external view returns (uint256) {
        Position storage p = positions[user];
        if (p.debt == 0) return type(uint256).max;
        uint256 collateralValue = _collateralValue(p.collateral);
        return (collateralValue * BASIS_POINTS) / p.debt;
    }

    function collateralValue(uint256 collateralAmount) external view returns (uint256) {
        return _collateralValue(collateralAmount);
    }

    function isSafe(uint256 collateralAmount, uint256 debt) external view returns (bool) {
        return _isSafe(collateralAmount, debt);
    }

    function maxMintable(address user) external view returns (uint256) {
        Position storage p = positions[user];
        uint256 collateralValue = _collateralValue(p.collateral);
        uint256 maxDebt = (collateralValue * BASIS_POINTS) / minCollateralRatio;
        if (p.debt >= maxDebt) return 0;
        return maxDebt - p.debt;
    }

    function setMinCollateralRatio(uint256 newRatio) external onlyRole(OPERATOR_ROLE) {
        if (newRatio < MIN_MIN_COLLATERAL_RATIO || newRatio > MAX_MIN_COLLATERAL_RATIO) {
            revert RatioOutOfBounds();
        }
        emit MinCollateralRatioUpdated(minCollateralRatio, newRatio);
        minCollateralRatio = newRatio;
    }

    function setStabilityFeeRate(uint256 newRate) external onlyRole(OPERATOR_ROLE) {
        if (newRate > MAX_STABILITY_FEE_RATE) revert FeeRateOutOfBounds();
        emit StabilityFeeRateUpdated(stabilityFeeRate, newRate);
        stabilityFeeRate = newRate;
    }

    function setTreasury(address newTreasury) external onlyRole(OPERATOR_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function setMintPaused(bool paused) external onlyRole(OPERATOR_ROLE) {
        mintPaused = paused;
        emit MintPausedSet(paused);
    }
}
