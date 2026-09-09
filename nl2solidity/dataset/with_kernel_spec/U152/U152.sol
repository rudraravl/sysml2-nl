Looking at the errors: "Invalid implicit conversion from uint256 to address requested" - this is because the `Borrowed` and `Repaid` events declared `amount` as `address indexed` instead of `uint256`, so `emit Borrowed(msg.sender, amount)` and `emit Repaid(msg.sender, repayAmount)` fail since `amount`/`repayAmount` are `uint256` being passed to an `address`-typed parameter. I'll fix the event declarations.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert TransferFromFailed();
    }

    error TransferFailed();
    error TransferFromFailed();
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    error ReentrantCall();
}

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    modifier onlyRole(bytes32 role) {
        if (!_roles[role][msg.sender]) revert Unauthorized();
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function _grantRole(bytes32 role, address account) internal {
        _roles[role][account] = true;
        emit RoleGranted(role, account);
    }

    function _revokeRole(bytes32 role, address account) internal {
        _roles[role][account] = false;
        emit RoleRevoked(role, account);
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(role, account);
    }

    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    error Unauthorized();
}

contract CreditLine is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_LTV = 0.5e18; // 50% maximum loan-to-value
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_INTEREST_RATE = 1e18; // 100% cap

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable stablecoin;
    uint8 public immutable stableDecimals;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public interestRate; // annual rate in WAD (0.12e18 = 12%)
    uint256 public totalDebt;
    uint256 public totalInterestAccrued;

    struct CollateralConfig {
        bool supported;
        uint8 decimals;
        uint256 price; // USD value of 1 whole token, in WAD
    }

    mapping(address => CollateralConfig) public collateralConfig;
    address[] public supportedTokens;
    mapping(address => uint256) private _tokenIndex; // token => array index + 1

    struct Account {
        uint256 debt; // outstanding credit in stablecoin units
        uint256 lastAccrual; // timestamp of last interest accrual
    }

    mapping(address => Account) public accounts;
    mapping(address => mapping(address => uint256)) public collateralBalances; // user => token => amount
    mapping(address => uint256) public totalCollateralDeposited; // token => total deposited

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 debtRepaid, uint256 collateralValueSeized);
    event CollateralTokenAdded(address indexed token, uint8 decimals, uint256 price);
    event CollateralTokenRemoved(address indexed token);
    event CollateralPriceUpdated(address indexed token, uint256 newPrice);
    event InterestRateUpdated(uint256 oldRate, uint256 newRate);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error TokenNotSupported();
    error TokenAlreadySupported();
    error TokenInUse();
    error InsufficientCollateral();
    error InsufficientBalance();
    error InsufficientDebt();
    error PositionHealthy();
    error InvalidPrice();
    error InvalidRate();
    error InvalidDecimals();
    error InsufficientLiquidity();

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        stableDecimals = stablecoin.decimals();
        interestRate = 0.12e18; // 12% APR default

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);

        emit InterestRateUpdated(0, interestRate);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN — COLLATERAL MGMT
    //////////////////////////////////////////////////////////////*/

    function addCollateralToken(address token, uint8 decimals_, uint256 price) external onlyRole(OPERATOR_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (collateralConfig[token].supported) revert TokenAlreadySupported();
        if (decimals_ == 0 || decimals_ > 36) revert InvalidDecimals();
        if (price == 0) revert InvalidPrice();
        if (token == address(stablecoin)) revert TokenAlreadySupported();

        collateralConfig[token] = CollateralConfig({
            supported: true,
            decimals: decimals_,
            price: price
        });

        _tokenIndex[token] = supportedTokens.length + 1; // 1-based to distinguish from default 0
        supportedTokens.push(token);

        emit CollateralTokenAdded(token, decimals_, price);
    }

    function removeCollateralToken(address token) external onlyRole(OPERATOR_ROLE) {
        if (!collateralConfig[token].supported) revert TokenNotSupported();
        if (totalCollateralDeposited[token] > 0) revert TokenInUse();

        collateralConfig[token].supported = false;

        uint256 idx = _tokenIndex[token] - 1;
        uint256 lastIdx = supportedTokens.length - 1;

        if (idx != lastIdx) {
            address lastToken = supportedTokens[lastIdx];
            supportedTokens[idx] = lastToken;
            _tokenIndex[lastToken] = idx + 1;
        }

        supportedTokens.pop();
        delete _tokenIndex[token];

        emit CollateralTokenRemoved(token);
    }

    function setCollateralPrice(address token, uint256 newPrice) external onlyRole(OPERATOR_ROLE) {
        if (!collateralConfig[token].supported) revert TokenNotSupported();
        if (newPrice == 0) revert InvalidPrice();

        collateralConfig[token].price = newPrice;

        emit CollateralPriceUpdated(token, newPrice);
    }

    function setInterestRate(uint256 newRate) external onlyRole(OPERATOR_ROLE) {
        if (newRate > MAX_INTEREST_RATE) revert InvalidRate();

        emit InterestRateUpdated(interestRate, newRate);
        interestRate = newRate;
    }

    /*//////////////////////////////////////////////////////////////
                        USER — DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function depositCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfig[token].supported) revert TokenNotSupported();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        collateralBalances[msg.sender][token] += amount;
        totalCollateralDeposited[token] += amount;

        emit CollateralDeposited(msg.sender, token, amount);
    }

    function withdrawCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfig[token].supported) revert TokenNotSupported();
        if (collateralBalances[msg.sender][token] < amount) revert InsufficientBalance();

        _accrueInterest(msg.sender);

        // Effects
        collateralBalances[msg.sender][token] -= amount;
        totalCollateralDeposited[token] -= amount;

        // Check health after withdrawal
        uint256 collateralValue = _getCollateralValue(msg.sender);
        uint256 debt = accounts[msg.sender].debt;
        if (debt > 0 && (collateralValue * MAX_LTV) / WAD < debt) {
            revert InsufficientCollateral();
        }

        // Interaction
        IERC20(token).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        USER — BORROW / REPAY
    //////////////////////////////////////////////////////////////*/

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        uint256 collateralValue = _getCollateralValue(msg.sender);
        uint256 maxBorrow = (collateralValue * MAX_LTV) / WAD;
        if (accounts[msg.sender].debt + amount > maxBorrow) revert InsufficientCollateral();

        if (stablecoin.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        // Effects
        accounts[msg.sender].debt += amount;
        totalDebt += amount;

        // Interaction
        stablecoin.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);

        uint256 debt = accounts[msg.sender].debt;
        if (debt == 0) revert InsufficientDebt();

        uint256 repayAmount = amount > debt ? debt : amount;

        // Effects
        accounts[msg.sender].debt -= repayAmount;
        totalDebt -= repayAmount;

        // Interaction
        stablecoin.safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repaid(msg.sender, repayAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR — LIQUIDATION
    //////////////////////////////////////////////////////////////*/

    function liquidate(address user) external onlyRole(OPERATOR_ROLE) nonReentrant {
        if (user == address(0)) revert ZeroAddress();

        _accrueInterest(user);

        uint256 debt = accounts[user].debt;
        if (debt == 0) revert InsufficientDebt();

        uint256 collateralValue = _getCollateralValue(user);
        uint256 maxDebt = (collateralValue * MAX_LTV) / WAD;
        if (debt <= maxDebt) revert PositionHealthy();

        // Operator repays the full debt
        stablecoin.safeTransferFrom(msg.sender, address(this), debt);

        // Seize all collateral
        uint256 totalSeizedValue = 0;
        address[] memory tokens = supportedTokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 balance = collateralBalances[user][token];
            if (balance > 0) {
                CollateralConfig storage cfg = collateralConfig[token];
                uint256 value = _tokenValueInStable(balance, cfg);
                totalSeizedValue += value;

                collateralBalances[user][token] = 0;
                totalCollateralDeposited[token] -= balance;

                IERC20(token).safeTransfer(msg.sender, balance);
            }
        }

        // Clear debt
        accounts[user].debt = 0;
        accounts[user].lastAccrual = block.timestamp;
        totalDebt -= debt;

        emit Liquidated(user, msg.sender, debt, totalSeizedValue);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAccountDebt(address user) external view returns (uint256) {
        return accounts[user].debt + _pendingInterest(user);
    }

    function getCollateralValue(address user) external view returns (uint256) {
        return _getCollateralValue(user);
    }

    function getMaxBorrow(address user) external view returns (uint256) {
        return (_getCollateralValue(user) * MAX_LTV) / WAD;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        uint256 debt = accounts[user].debt + _pendingInterest(user);
        if (debt == 0) return type(uint256).max;
        uint256 collateralValue = _getCollateralValue(user);
        return (collateralValue * WAD) / debt;
    }

    function isLiquidatable(address user) external view returns (bool) {
        uint256 debt = accounts[user].debt + _pendingInterest(user);
        if (debt == 0) return false;
        uint256 maxDebt = (_getCollateralValue(user) * MAX_LTV) / WAD;
        return debt > maxDebt;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getCollateralBalance(address user, address token) external view returns (uint256) {
        return collateralBalances[user][token];
    }

    function getSupportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _accrueInterest(address user) internal {
        Account storage acc = accounts[user];
        if (acc.lastAccrual == 0) {
            acc.lastAccrual = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - acc.lastAccrual;
        if (elapsed == 0) return;

        if (acc.debt > 0) {
            uint256 interest = (acc.debt * interestRate * elapsed) / (SECONDS_PER_YEAR * WAD);
            acc.debt += interest;
            totalDebt += interest;
            totalInterestAccrued += interest;
        }

        acc.lastAccrual = block.timestamp;
    }

    function _pendingInterest(address user) internal view returns (uint256) {
        Account storage acc = accounts[user];
        if (acc.debt == 0 || acc.lastAccrual == 0) return 0;

        uint256 elapsed = block.timestamp - acc.lastAccrual;
        if (elapsed == 0) return 0;

        return (acc.debt * interestRate * elapsed) / (SECONDS_PER_YEAR * WAD);
    }

    function _tokenValueInStable(uint256 balance, CollateralConfig storage cfg)
        internal
        view
        returns (uint256)
    {
        // value = (balance * price * 10^stableDecimals) / (10^decimals * WAD)
        uint256 usdWad = (balance * cfg.price) / (10 ** uint256(cfg.decimals));
        return (usdWad * (10 ** uint256(stableDecimals))) / WAD;
    }

    function _getCollateralValue(address user) internal view returns (uint256 totalValue) {
        address[] memory tokens = supportedTokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            CollateralConfig storage cfg = collateralConfig[token];
            if (!cfg.supported) continue;

            uint256 balance = collateralBalances[user][token];
            if (balance == 0) continue;

            totalValue += _tokenValueInStable(balance, cfg);
        }
    }
}
