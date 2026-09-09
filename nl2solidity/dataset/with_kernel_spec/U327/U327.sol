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

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool ok = token.approve(spender, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    error SafeERC20FailedOperation(address token);
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

abstract contract Ownable {
    address public owner;

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
}

contract CollateralVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LTV_CAP = 0.75e18;
    uint256 public constant ORIGINATION_FEE = 0.005e18;
    uint256 private constant WAD = 1e18;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    struct CollateralConfig {
        bool    supported;
        uint256 collateralFactor;
        uint256 liquidationThreshold;
        uint256 price;
        uint8   decimals;
    }

    struct Account {
        mapping(address => uint256) collateral;
        uint256 debt;
        uint256 userIndex;
    }

    address public operator;
    IERC20 public immutable borrowToken;
    uint8  public immutable borrowDecimals;

    mapping(address => CollateralConfig) public collateralConfigs;
    address[] public supportedTokensList;
    mapping(address => bool) public isSupported;

    mapping(address => Account) private _accounts;

    uint256 public baseInterestRate;
    uint256 public interestIndex;
    uint256 public lastAccrual;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 principal, uint256 fee);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event CollateralTokenAdded(address indexed token, uint256 collateralFactor, uint256 liquidationThreshold, uint256 price);
    event CollateralTokenRemoved(address indexed token);
    event CollateralTokenUpdated(address indexed token, uint256 collateralFactor, uint256 liquidationThreshold, uint256 price);
    event InterestRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address oldOperator, address newOperator);

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotSupported();
    error TokenAlreadySupported();
    error InsufficientBalance();
    error ExceedsBorrowingLimit();
    error NoOutstandingDebt();
    error InvalidFactor();
    error InvalidThreshold();
    error InvalidPrice();
    error InvalidDecimals();
    error InvalidTokenDecimals();
    error InsufficientBorrowToken();

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert NotOperator();
        _;
    }

    constructor(address _operator, address _borrowToken) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_borrowToken == address(0)) revert ZeroAddress();
        IERC20Metadata bt = IERC20Metadata(_borrowToken);
        uint8 dec = bt.decimals();
        if (dec != 18) revert InvalidTokenDecimals();
        operator = _operator;
        borrowToken = IERC20(_borrowToken);
        borrowDecimals = dec;
        baseInterestRate = 0;
        interestIndex = WAD;
        lastAccrual = block.timestamp;
        emit OperatorUpdated(address(0), _operator);
    }

    function _accrueGlobal() internal {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0) return;
        uint256 growth = WAD + (baseInterestRate * dt) / SECONDS_PER_YEAR;
        interestIndex = (interestIndex * growth) / WAD;
        lastAccrual = block.timestamp;
    }

    function _accrueAccount(address user) internal {
        Account storage a = _accounts[user];
        uint256 idx = a.userIndex;
        if (a.debt > 0 && idx != 0 && idx < interestIndex) {
            a.debt = (a.debt * interestIndex) / idx;
        }
        a.userIndex = interestIndex;
    }

    function _projectedIndex() internal view returns (uint256) {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0) return interestIndex;
        uint256 growth = WAD + (baseInterestRate * dt) / SECONDS_PER_YEAR;
        return (interestIndex * growth) / WAD;
    }

    function _tokenValue18(address token, uint256 balance) internal view returns (uint256) {
        CollateralConfig storage c = collateralConfigs[token];
        if (!c.supported || balance == 0) return 0;
        uint256 normalized = balance;
        if (c.decimals < 18) {
            normalized = balance * (10 ** (18 - c.decimals));
        } else if (c.decimals > 18) {
            normalized = balance / (10 ** (c.decimals - 18));
        }
        return (normalized * c.price) / WAD;
    }

    function _borrowingPower(address user, bool useThreshold) internal view returns (uint256) {
        Account storage a = _accounts[user];
        uint256 total;
        for (uint256 i = 0; i < supportedTokensList.length; i++) {
            address t = supportedTokensList[i];
            uint256 bal = a.collateral[t];
            if (bal == 0) continue;
            uint256 value = _tokenValue18(t, bal);
            uint256 factor = useThreshold
                ? collateralConfigs[t].liquidationThreshold
                : collateralConfigs[t].collateralFactor;
            total += (value * factor) / WAD;
        }
        return total;
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!isSupported[token]) revert TokenNotSupported();
        _accrueGlobal();
        _accrueAccount(msg.sender);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _accounts[msg.sender].collateral[token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!isSupported[token]) revert TokenNotSupported();
        _accrueGlobal();
        _accrueAccount(msg.sender);
        Account storage a = _accounts[msg.sender];
        if (a.collateral[token] < amount) revert InsufficientBalance();
        a.collateral[token] -= amount;
        if (a.debt > 0) {
            uint256 power = _borrowingPower(msg.sender, false);
            if (a.debt > power) revert ExceedsBorrowingLimit();
        }
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueGlobal();
        _accrueAccount(msg.sender);
        Account storage a = _accounts[msg.sender];
        uint256 fee = (amount * ORIGINATION_FEE) / WAD;
        uint256 newDebt = a.debt + amount + fee;
        uint256 power = _borrowingPower(msg.sender, false);
        if (newDebt > power) revert ExceedsBorrowingLimit();
        uint256 vaultBalance = borrowToken.balanceOf(address(this));
        if (vaultBalance < amount) revert InsufficientBorrowToken();
        a.debt = newDebt;
        borrowToken.safeTransfer(msg.sender, amount);
        emit Borrow(msg.sender, address(borrowToken), amount, fee);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrueGlobal();
        _accrueAccount(msg.sender);
        Account storage a = _accounts[msg.sender];
        if (a.debt == 0) revert NoOutstandingDebt();
        uint256 repayAmount = amount > a.debt ? a.debt : amount;
        borrowToken.safeTransferFrom(msg.sender, address(this), repayAmount);
        a.debt -= repayAmount;
        emit Repay(msg.sender, address(borrowToken), repayAmount);
    }

    function addCollateralToken(
        address token,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 price
    ) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isSupported[token]) revert TokenAlreadySupported();
        if (collateralFactor > MAX_LTV_CAP) revert InvalidFactor();
        if (liquidationThreshold < collateralFactor || liquidationThreshold > WAD) revert InvalidThreshold();
        if (price == 0) revert InvalidPrice();
        uint8 dec = IERC20Metadata(token).decimals();
        if (dec > 36) revert InvalidDecimals();
        collateralConfigs[token] = CollateralConfig({
            supported: true,
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            price: price,
            decimals: dec
        });
        isSupported[token] = true;
        supportedTokensList.push(token);
        emit CollateralTokenAdded(token, collateralFactor, liquidationThreshold, price);
    }

    function updateCollateralToken(
        address token,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 price
    ) external onlyOperator {
        if (!isSupported[token]) revert TokenNotSupported();
        if (collateralFactor > MAX_LTV_CAP) revert InvalidFactor();
        if (liquidationThreshold < collateralFactor || liquidationThreshold > WAD) revert InvalidThreshold();
        if (price == 0) revert InvalidPrice();
        CollateralConfig storage c = collateralConfigs[token];
        c.collateralFactor = collateralFactor;
        c.liquidationThreshold = liquidationThreshold;
        c.price = price;
        emit CollateralTokenUpdated(token, collateralFactor, liquidationThreshold, price);
    }

    function removeCollateralToken(address token) external onlyOperator {
        if (!isSupported[token]) revert TokenNotSupported();
        delete collateralConfigs[token];
        isSupported[token] = false;
        uint256 len = supportedTokensList.length;
        for (uint256 i = 0; i < len; i++) {
            if (supportedTokensList[i] == token) {
                supportedTokensList[i] = supportedTokensList[len - 1];
                supportedTokensList.pop();
                break;
            }
        }
        emit CollateralTokenRemoved(token);
    }

    function setBaseInterestRate(uint256 newRate) external onlyOperator {
        if (newRate > WAD) revert InvalidFactor();
        _accrueGlobal();
        uint256 old = baseInterestRate;
        baseInterestRate = newRate;
        emit InterestRateUpdated(old, newRate);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function supportedTokensCount() external view returns (uint256) {
        return supportedTokensList.length;
    }

    function getAccount(address user) external view returns (uint256 debt, uint256 userIndex) {
        return (_accounts[user].debt, _accounts[user].userIndex);
    }

    function getCollateral(address user, address token) external view returns (uint256) {
        return _accounts[user].collateral[token];
    }

    function borrowingPower(address user) external view returns (uint256) {
        return _borrowingPower(user, false);
    }

    function liquidationPower(address user) external view returns (uint256) {
        return _borrowingPower(user, true);
    }

    function currentDebt(address user) external view returns (uint256) {
        Account storage a = _accounts[user];
        if (a.debt == 0 || a.userIndex == 0) return a.debt;
        return (a.debt * _projectedIndex()) / a.userIndex;
    }

    function isLiquidatable(address user) external view returns (bool) {
        if (_accounts[user].debt == 0) return false;
        uint256 projected = _projectedIndex();
        uint256 idx = _accounts[user].userIndex;
        uint256 debt = idx == 0 ? _accounts[user].debt : (_accounts[user].debt * projected) / idx;
        return debt > _borrowingPower(user, true);
    }

    function projectedInterestIndex() external view returns (uint256) {
        return _projectedIndex();
    }
}
