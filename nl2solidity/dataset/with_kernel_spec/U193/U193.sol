// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;

    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

contract LendingProtocol is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_LTV_BPS = 7500;            // 75% hard cap
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant DEFAULT_INTEREST_RATE_BPS = 500; // 5% APR

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error Paused();
    error NotOperator();
    error CollateralNotSupported();
    error CollateralFactorTooHigh();
    error InsufficientCollateral();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error AlreadySupported();
    error PositionUndercollateralized();
    error NoOutstandingDebt();
    error ZeroAddress();
    error InvalidPrice();
    error InvalidRecipient();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event CollateralAdded(address indexed asset, uint256 collateralFactorBps);
    event CollateralRemoved(address indexed asset);
    event InterestRateUpdated(uint256 oldRateBps, uint256 newRateBps);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event PausedStateChanged(bool paused);
    event AccruedInterest(address indexed user, address indexed asset, uint256 interest);
    event StablecoinMinted(address indexed to, uint256 amount);
    event StablecoinBurned(address indexed from, uint256 amount);
    event StablecoinTransfer(address indexed from, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    struct CollateralConfig {
        bool isSupported;
        uint16 collateralFactorBps; // <= MAX_LTV_BPS
    }

    struct Position {
        uint256 collateral;           // [token units]
        uint256 principalDebt;        // [stable units]
        uint256 accumulatedInterest;  // [stable units]
        uint256 lastAccrualTimestamp; // [seconds]
    }

    address public operator;
    IPriceOracle public oracle;
    bool public pausedFlag;

    uint256 public interestRateBps; // APR in bps (default 500 = 5%)

    mapping(address => CollateralConfig) public collateralConfigs;
    mapping(address => mapping(address => Position)) public positions; // user => collateral => Position

    uint256 public totalBorrowedPrincipal; // total outstanding principal across all positions
    uint256 public totalReserve;           // accumulated interest revenue, in stablecoin

    // ---------------------------------------------------------------------
    // Internal stablecoin (ERC20) state
    // ---------------------------------------------------------------------
    string public constant stableName = "Lending Stablecoin";
    string public constant stableSymbol = "LUSD";
    uint8 public constant stableDecimals = 18;
    mapping(address => uint256) public stableBalanceOf;
    mapping(address => mapping(address => uint256)) public stableAllowance;
    uint256 public stableTotalSupply;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier whenNotPaused() {
        if (pausedFlag) revert Paused();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address oracle_) Ownable(msg.sender) {
        if (oracle_ == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(oracle_);
        interestRateBps = DEFAULT_INTEREST_RATE_BPS;
        operator = msg.sender;
        emit OperatorUpdated(address(0), operator);
        emit InterestRateUpdated(0, interestRateBps);
    }

    // ---------------------------------------------------------------------
    // Admin (owner)
    // ---------------------------------------------------------------------
    function setPaused(bool _paused) external onlyOwner {
        pausedFlag = _paused;
        emit PausedStateChanged(_paused);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        emit OracleUpdated(address(oracle), _oracle);
        oracle = IPriceOracle(_oracle);
    }

    // ---------------------------------------------------------------------
    // Operator
    // ---------------------------------------------------------------------
    function addCollateral(address token, uint16 collateralFactorBps) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (collateralConfigs[token].isSupported) revert AlreadySupported();
        if (collateralFactorBps == 0 || collateralFactorBps > MAX_LTV_BPS) revert CollateralFactorTooHigh();
        collateralConfigs[token] = CollateralConfig({
            isSupported: true,
            collateralFactorBps: collateralFactorBps
        });
        emit CollateralAdded(token, collateralFactorBps);
    }

    function removeCollateral(address token) external onlyOperator {
        if (!collateralConfigs[token].isSupported) revert CollateralNotSupported();
        delete collateralConfigs[token];
        emit CollateralRemoved(token);
    }

    function setInterestRate(uint256 newRateBps) external onlyOperator {
        if (newRateBps == 0) revert ZeroAmount();
        uint256 old = interestRateBps;
        interestRateBps = newRateBps;
        emit InterestRateUpdated(old, newRateBps);
    }

    // ---------------------------------------------------------------------
    // Interest accrual
    // ---------------------------------------------------------------------
    function _accrueInterest(address user, address token) internal {
        Position storage p = positions[user][token];
        if (p.lastAccrualTimestamp == 0) {
            p.lastAccrualTimestamp = block.timestamp;
            return;
        }
        if (p.principalDebt == 0) {
            p.lastAccrualTimestamp = block.timestamp;
            return;
        }
        // Avoid strict equality: use <= to guard against timestamp edge cases
        if (block.timestamp <= p.lastAccrualTimestamp) return;
        uint256 elapsed = block.timestamp - p.lastAccrualTimestamp;
        // Compute interest directly without intermediate division to avoid
        // divide-before-multiply precision loss.
        uint256 interest = (p.principalDebt * interestRateBps * elapsed) /
            (SECONDS_PER_YEAR * BPS_DENOMINATOR);
        if (interest > 0) {
            p.accumulatedInterest += interest;
            emit AccruedInterest(user, token, interest);
        }
        p.lastAccrualTimestamp = block.timestamp;
    }

    function _collateralValue(address token, uint256 amount) internal view returns (uint256) {
        uint256 price = oracle.getPrice(token);
        if (price == 0) revert InvalidPrice();
        return (amount * price) / PRICE_PRECISION;
    }

    function _maxBorrow(address token, uint256 collateralAmount) internal view returns (uint256) {
        uint256 value = _collateralValue(token, collateralAmount);
        CollateralConfig memory cfg = collateralConfigs[token];
        return (value * cfg.collateralFactorBps) / BPS_DENOMINATOR;
    }

    function _isPositionSafe(address user, address token) internal view returns (bool) {
        Position storage p = positions[user][token];
        uint256 debt = p.principalDebt + p.accumulatedInterest;
        if (debt == 0) return true;
        uint256 maxBorrow = _maxBorrow(token, p.collateral);
        return debt <= maxBorrow;
    }

    // ---------------------------------------------------------------------
    // Core user actions
    // ---------------------------------------------------------------------
    function deposit(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfigs[token].isSupported) revert CollateralNotSupported();
        _accrueInterest(msg.sender, token);
        positions[msg.sender][token].collateral += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfigs[token].isSupported) revert CollateralNotSupported();
        Position storage p = positions[msg.sender][token];
        if (amount > p.collateral) revert InsufficientBalance();
        _accrueInterest(msg.sender, token);
        p.collateral -= amount;
        if (!_isPositionSafe(msg.sender, token)) revert PositionUndercollateralized();
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    function borrow(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfigs[token].isSupported) revert CollateralNotSupported();
        _accrueInterest(msg.sender, token);
        Position storage p = positions[msg.sender][token];
        p.principalDebt += amount;
        uint256 maxBorrow = _maxBorrow(token, p.collateral);
        uint256 totalDebt = p.principalDebt + p.accumulatedInterest;
        if (totalDebt > maxBorrow) revert InsufficientCollateral();
        totalBorrowedPrincipal += amount;
        _mintStable(msg.sender, amount);
        emit Borrow(msg.sender, token, amount);
    }

    function repay(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfigs[token].isSupported) revert CollateralNotSupported();
        _accrueInterest(msg.sender, token);
        Position storage p = positions[msg.sender][token];
        uint256 totalDebt = p.principalDebt + p.accumulatedInterest;
        if (totalDebt == 0) revert NoOutstandingDebt();
        uint256 repayAmount = amount > totalDebt ? totalDebt : amount;
        uint256 interestPart = p.accumulatedInterest < repayAmount
            ? p.accumulatedInterest
            : repayAmount;
        uint256 principalPart = repayAmount - interestPart;
        p.accumulatedInterest -= interestPart;
        p.principalDebt -= principalPart;
        totalBorrowedPrincipal -= principalPart;
        totalReserve += interestPart;
        _burnStable(msg.sender, repayAmount);
        emit Repay(msg.sender, token, repayAmount);
    }

    function poke(address user, address token) external nonReentrant {
        if (!collateralConfigs[token].isSupported) revert CollateralNotSupported();
        _accrueInterest(user, token);
    }

    // ---------------------------------------------------------------------
    // Stablecoin (ERC20) surface
    // ---------------------------------------------------------------------
    function stableTransfer(address to, uint256 amount) external returns (bool) {
        _transferStable(msg.sender, to, amount);
        return true;
    }

    function stableApprove(address spender, uint256 amount) external returns (bool) {
        stableAllowance[msg.sender][spender] = amount;
        return true;
    }

    function stableTransferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (stableAllowance[from][msg.sender] < amount) revert InsufficientAllowance();
        stableAllowance[from][msg.sender] -= amount;
        _transferStable(from, to, amount);
        return true;
    }

    function _mintStable(address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidRecipient();
        stableBalanceOf[to] += amount;
        stableTotalSupply += amount;
        emit StablecoinMinted(to, amount);
    }

    function _burnStable(address from, uint256 amount) internal {
        if (stableBalanceOf[from] < amount) revert InsufficientBalance();
        stableBalanceOf[from] -= amount;
        stableTotalSupply -= amount;
        emit StablecoinBurned(from, amount);
    }

    function _transferStable(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();
        if (stableBalanceOf[from] < amount) revert InsufficientBalance();
        stableBalanceOf[from] -= amount;
        stableBalanceOf[to] += amount;
        emit StablecoinTransfer(from, to, amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function getPosition(address user, address token)
        external
        view
        returns (
            uint256 collateral,
            uint256 principalDebt,
            uint256 accumulatedInterest,
            uint256 lastAccrualTimestamp
        )
    {
        Position memory p = positions[user][token];
        return (p.collateral, p.principalDebt, p.accumulatedInterest, p.lastAccrualTimestamp);
    }

    function maxBorrow(address user, address token) external view returns (uint256) {
        Position memory p = positions[user][token];
        return _maxBorrow(token, p.collateral);
    }

    function currentDebt(address user, address token) external view returns (uint256) {
        Position memory p = positions[user][token];
        // Avoid strict equality checks: compute elapsed safely.
        uint256 elapsed = block.timestamp > p.lastAccrualTimestamp
            ? block.timestamp - p.lastAccrualTimestamp
            : 0;
        // Compute interest directly without intermediate division to avoid
        // divide-before-multiply precision loss.
        uint256 pending = (p.principalDebt * interestRateBps * elapsed) /
            (SECONDS_PER_YEAR * BPS_DENOMINATOR);
        return p.principalDebt + p.accumulatedInterest + pending;
    }

    function collateralFactorBps(address token) external view returns (uint256) {
        return uint256(collateralConfigs[token].collateralFactorBps);
    }

    function isCollateralSupported(address token) external view returns (bool) {
        return collateralConfigs[token].isSupported;
    }
}
