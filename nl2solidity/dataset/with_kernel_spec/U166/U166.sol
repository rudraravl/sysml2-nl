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
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (returndata.length == 0 || abi.decode(returndata, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, to, value)
        );
        require(
            success && (returndata.length == 0 || abi.decode(returndata, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, value)
        );
        require(
            success && (returndata.length == 0 || abi.decode(returndata, (bool))),
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

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    function _pause() internal {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) internal _roles;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

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

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: sender must have role");
        _;
    }
}

interface IStrategy {
    function farm(uint256 baseAmount, uint256 quoteAmount) external returns (uint256 shares);
    function exit(uint256 shares) external returns (uint256 baseReturned, uint256 quoteReturned);
}

contract LeveragedYieldVault is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant MAX_LEVERAGE = 5e18;
    uint256 public constant FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PRECISION = 1e18;

    IERC20 public immutable baseToken;
    IERC20 public immutable quoteToken;

    struct StrategyParams {
        uint256 maxLeverage;
        uint256 riskParameter;
        bool active;
    }

    struct StrategyInfo {
        StrategyParams params;
        uint256 totalBaseAllocated;
        uint256 totalQuoteAllocated;
    }

    struct UserPosition {
        uint256 depositedBase;
        uint256 borrowedQuote;
        uint256 positionBase;
        uint256 positionQuote;
        uint256 strategyShares;
        address strategy;
        uint256 leverage;
    }

    mapping(address => UserPosition) public positions;
    mapping(address => StrategyInfo) public strategies;
    address[] public strategyList;

    uint256 public totalBaseDeposited;
    uint256 public totalQuoteBorrowed;
    address public feeRecipient;

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        address indexed strategy,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 leverage
    );
    event PositionClosed(
        address indexed user,
        address indexed strategy,
        uint256 baseReturned,
        uint256 quoteReturned,
        uint256 profit,
        uint256 fee
    );
    event Withdrawn(address indexed user, uint256 baseAmount);
    event StrategyAdded(address indexed strategy, uint256 maxLeverage, uint256 riskParameter);
    event StrategyUpdated(address indexed strategy, uint256 maxLeverage, uint256 riskParameter, bool active);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    error ZeroAddress();
    error AmountZero();
    error InsufficientDeposit();
    error InsufficientBalance();
    error InsufficientCollateral();
    error LeverageExceeded(uint256 requested, uint256 maxAllowed);
    error StrategyNotActive();
    error StrategyAlreadyExists();
    error StrategyNotFound();
    error PositionAlreadyOpen();
    error NoOpenPosition();
    error InvalidLeverage();

    modifier noOpenPosition(address user) {
        if (positions[user].strategy != address(0)) revert PositionAlreadyOpen();
        _;
    }

    modifier hasOpenPosition(address user) {
        if (positions[user].strategy == address(0)) revert NoOpenPosition();
        _;
    }

    constructor(
        address _baseToken,
        address _quoteToken,
        address _admin,
        address _feeRecipient
    ) {
        if (_baseToken == address(0) || _quoteToken == address(0) || _admin == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }
        baseToken = IERC20(_baseToken);
        quoteToken = IERC20(_quoteToken);
        feeRecipient = _feeRecipient;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        positions[msg.sender].depositedBase += amount;
        totalBaseDeposited += amount;
        baseToken.safeTransferFrom(address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant noOpenPosition(msg.sender) {
        if (amount == 0) revert AmountZero();
        UserPosition storage pos = positions[msg.sender];
        if (pos.depositedBase == 0) revert InsufficientDeposit();

        uint256 maxBorrow = (pos.depositedBase * (MAX_LEVERAGE - PRECISION)) / PRECISION;
        if (pos.borrowedQuote + amount > maxBorrow) {
            revert LeverageExceeded(pos.borrowedQuote + amount, maxBorrow);
        }

        if (quoteToken.balanceOf(address(this)) < amount) revert InsufficientBalance();

        pos.borrowedQuote += amount;
        totalQuoteBorrowed += amount;
        quoteToken.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        UserPosition storage pos = positions[msg.sender];
        if (pos.borrowedQuote == 0) revert InsufficientBalance();

        uint256 repayAmount = amount > pos.borrowedQuote ? pos.borrowedQuote : amount;
        pos.borrowedQuote -= repayAmount;
        totalQuoteBorrowed -= repayAmount;
        quoteToken.safeTransferFrom(address(this), repayAmount);
        emit Repaid(msg.sender, repayAmount);
    }

    function openPosition(
        address strategy,
        uint256 baseAmount,
        uint256 quoteAmount
    ) external nonReentrant whenNotPaused noOpenPosition(msg.sender) {
        if (baseAmount == 0) revert AmountZero();
        if (strategy == address(0)) revert ZeroAddress();

        StrategyInfo storage info = strategies[strategy];
        if (!info.params.active) revert StrategyNotActive();

        UserPosition storage pos = positions[msg.sender];
        if (pos.depositedBase < baseAmount) revert InsufficientBalance();

        uint256 leverage = ((baseAmount + quoteAmount) * PRECISION) / baseAmount;
        if (leverage > info.params.maxLeverage) {
            revert LeverageExceeded(leverage, info.params.maxLeverage);
        }
        if (leverage > MAX_LEVERAGE) {
            revert LeverageExceeded(leverage, MAX_LEVERAGE);
        }

        uint256 totalDebtAfter = pos.borrowedQuote + quoteAmount;
        uint256 maxDebt = (pos.depositedBase * (MAX_LEVERAGE - PRECISION)) / PRECISION;
        if (totalDebtAfter > maxDebt) {
            revert LeverageExceeded(totalDebtAfter, maxDebt);
        }

        if (quoteAmount > 0 && quoteToken.balanceOf(address(this)) < quoteAmount) {
            revert InsufficientBalance();
        }

        pos.depositedBase -= baseAmount;
        pos.borrowedQuote += quoteAmount;
        pos.positionBase = baseAmount;
        pos.positionQuote = quoteAmount;
        pos.strategy = strategy;
        pos.leverage = leverage;
        pos.strategyShares = 0;

        info.totalBaseAllocated += baseAmount;
        info.totalQuoteAllocated += quoteAmount;
        totalQuoteBorrowed += quoteAmount;

        baseToken.safeTransfer(strategy, baseAmount);
        if (quoteAmount > 0) {
            quoteToken.safeTransfer(strategy, quoteAmount);
        }

        uint256 shares = IStrategy(strategy).farm(baseAmount, quoteAmount);
        pos.strategyShares = shares;

        emit PositionOpened(msg.sender, strategy, baseAmount, quoteAmount, leverage);
    }

    function closePosition() external nonReentrant hasOpenPosition(msg.sender) {
        UserPosition storage pos = positions[msg.sender];
        address strategy = pos.strategy;
        uint256 shares = pos.strategyShares;
        uint256 pBase = pos.positionBase;
        uint256 pQuote = pos.positionQuote;

        pos.positionBase = 0;
        pos.positionQuote = 0;
        pos.strategy = address(0);
        pos.strategyShares = 0;
        pos.leverage = 0;

        (uint256 baseReturned, uint256 quoteReturned) = IStrategy(strategy).exit(shares);

        StrategyInfo storage info = strategies[strategy];

        if (info.totalBaseAllocated >= pBase) {
            info.totalBaseAllocated -= pBase;
        } else {
            info.totalBaseAllocated = 0;
        }

        uint256 quoteToUser = 0;
        if (quoteReturned >= pQuote) {
            pos.borrowedQuote -= pQuote;
            totalQuoteBorrowed -= pQuote;
            if (info.totalQuoteAllocated >= pQuote) {
                info.totalQuoteAllocated -= pQuote;
            } else {
                info.totalQuoteAllocated = 0;
            }
            quoteToUser = quoteReturned - pQuote;
        } else {
            pos.borrowedQuote -= quoteReturned;
            totalQuoteBorrowed -= quoteReturned;
            if (info.totalQuoteAllocated >= quoteReturned) {
                info.totalQuoteAllocated -= quoteReturned;
            } else {
                info.totalQuoteAllocated = 0;
            }
        }

        pos.depositedBase += baseReturned;

        if (baseReturned >= pBase) {
            totalBaseDeposited += baseReturned - pBase;
        } else {
            totalBaseDeposited -= pBase - baseReturned;
        }

        int256 profit = int256(baseReturned) - int256(pBase) + int256(quoteReturned) - int256(pQuote);

        uint256 fee = 0;
        if (profit > 0) {
            fee = (uint256(profit) * FEE_BPS) / BPS_DENOMINATOR;
            if (fee > 0 && pos.depositedBase >= fee) {
                pos.depositedBase -= fee;
                totalBaseDeposited -= fee;
                baseToken.safeTransfer(feeRecipient, fee);
            }
        }

        if (quoteToUser > 0) {
            quoteToken.safeTransfer(msg.sender, quoteToUser);
        }

        emit PositionClosed(
            msg.sender,
            strategy,
            baseReturned,
            quoteReturned,
            profit > 0 ? uint256(profit) : 0,
            fee
        );
    }

    function withdraw(uint256 baseAmount) external nonReentrant noOpenPosition(msg.sender) {
        if (baseAmount == 0) revert AmountZero();
        UserPosition storage pos = positions[msg.sender];
        if (pos.depositedBase < baseAmount) revert InsufficientBalance();

        if (pos.borrowedQuote > 0) {
            uint256 remainingBase = pos.depositedBase - baseAmount;
            uint256 maxBorrow = (remainingBase * (MAX_LEVERAGE - PRECISION)) / PRECISION;
            if (pos.borrowedQuote > maxBorrow) revert InsufficientCollateral();
        }

        pos.depositedBase -= baseAmount;
        totalBaseDeposited -= baseAmount;
        baseToken.safeTransfer(msg.sender, baseAmount);
        emit Withdrawn(msg.sender, baseAmount);
    }

    function addStrategy(
        address strategy,
        uint256 maxLeverage,
        uint256 riskParameter
    ) external onlyRole(OPERATOR_ROLE) {
        if (strategy == address(0)) revert ZeroAddress();
        if (strategies[strategy].params.maxLeverage != 0) revert StrategyAlreadyExists();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();

        strategies[strategy].params = StrategyParams({
            maxLeverage: maxLeverage,
            riskParameter: riskParameter,
            active: true
        });
        strategyList.push(strategy);
        emit StrategyAdded(strategy, maxLeverage, riskParameter);
    }

    function updateStrategy(
        address strategy,
        uint256 maxLeverage,
        uint256 riskParameter,
        bool active
    ) external onlyRole(OPERATOR_ROLE) {
        if (strategies[strategy].params.maxLeverage == 0) revert StrategyNotFound();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();

        StrategyParams storage params = strategies[strategy].params;
        params.maxLeverage = maxLeverage;
        params.riskParameter = riskParameter;
        params.active = active;
        emit StrategyUpdated(strategy, maxLeverage, riskParameter, active);
    }

    function setFeeRecipient(address newRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(role, account);
    }

    function getStrategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function getUserPosition(address user) external view returns (
        uint256 depositedBase,
        uint256 borrowedQuote,
        uint256 positionBase,
        uint256 positionQuote,
        uint256 strategyShares,
        address strategy,
        uint256 leverage
    ) {
        UserPosition storage pos = positions[user];
        return (
            pos.depositedBase,
            pos.borrowedQuote,
            pos.positionBase,
            pos.positionQuote,
            pos.strategyShares,
            pos.strategy,
            pos.leverage
        );
    }

    function getStrategyInfo(address strategy) external view returns (
        uint256 maxLeverage,
        uint256 riskParameter,
        bool active,
        uint256 totalBaseAllocated,
        uint256 totalQuoteAllocated
    ) {
        StrategyInfo storage info = strategies[strategy];
        return (
            info.params.maxLeverage,
            info.params.riskParameter,
            info.params.active,
            info.totalBaseAllocated,
            info.totalQuoteAllocated
        );
    }

    function getVaultBalances() external view returns (uint256 baseBalance, uint256 quoteBalance) {
        return (baseToken.balanceOf(address(this)), quoteToken.balanceOf(address(this)));
    }
}
