// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract YieldOptimizer {
    // ----------------------------------------------------------------------
    // Errors
    // ----------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error StrategyNotFound();
    error StrategyPaused();
    error StrategyNotPaused();
    error CapExceeded();
    error InsufficientPrincipal();
    error NothingToClaim();
    error SameValue();
    error InvalidCap();
    error TransferFailed();
    error NoDepositors();
    error Reentrancy();

    // ----------------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------------
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event StrategyAdded(uint256 indexed strategyId, address indexed token, uint256 cap);
    event StrategyUpdated(uint256 indexed strategyId, uint256 newCap, bool paused);
    event StrategyPausedEvent(uint256 indexed strategyId);
    event StrategyUnpausedEvent(uint256 indexed strategyId);
    event YieldAdded(uint256 indexed strategyId, uint256 amount);
    event Deposit(address indexed user, uint256 indexed strategyId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed strategyId, uint256 principal, uint256 yieldAmount, uint256 fee);
    event YieldClaimed(address indexed user, uint256 indexed strategyId, uint256 amount);

    // ----------------------------------------------------------------------
    // Constants
    // ----------------------------------------------------------------------
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public constant MAX_CAP_UNITS = 10_000; // 10,000 units of the underlying token

    // ----------------------------------------------------------------------
    // Structs
    // ----------------------------------------------------------------------
    struct Strategy {
        address token;
        uint256 cap;
        uint256 totalDeposited;
        uint256 accYieldPerShare;
        bool paused;
        bool exists;
    }

    struct UserPosition {
        uint256 principal;
        uint256 yieldDebt;
        uint256 accruedYield;
    }

    // ----------------------------------------------------------------------
    // State Variables
    // ----------------------------------------------------------------------
    address public owner;
    address public operator;
    address public feeRecipient;

    uint256 public nextStrategyId;
    mapping(uint256 => Strategy) public strategies;
    mapping(address => mapping(uint256 => UserPosition)) public positions;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    // ----------------------------------------------------------------------
    // Modifiers
    // ----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier strategyExists(uint256 strategyId) {
        if (!strategies[strategyId].exists) revert StrategyNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ----------------------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------------------
    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        nextStrategyId = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    // ----------------------------------------------------------------------
    // Admin — Ownership & Roles
    // ----------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        if (newOwner == owner) revert SameValue();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        if (_operator == operator) revert SameValue();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feeRecipient == feeRecipient) revert SameValue();
        emit FeeRecipientChanged(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    // ----------------------------------------------------------------------
    // Operator — Strategy Management
    // ----------------------------------------------------------------------
    function addStrategy(address token, uint256 cap) external onlyOperator returns (uint256 strategyId) {
        if (token == address(0)) revert ZeroAddress();
        uint256 maxCap = _maxCapFor(token);
        if (cap == 0 || cap > maxCap) revert InvalidCap();

        strategyId = nextStrategyId++;
        strategies[strategyId] = Strategy({
            token: token,
            cap: cap,
            totalDeposited: 0,
            accYieldPerShare: 0,
            paused: false,
            exists: true
        });

        emit StrategyAdded(strategyId, token, cap);
    }

    function updateStrategy(uint256 strategyId, uint256 newCap, bool paused) external onlyOperator strategyExists(strategyId) {
        Strategy storage s = strategies[strategyId];
        uint256 maxCap = _maxCapFor(s.token);
        if (newCap == 0 || newCap > maxCap) revert InvalidCap();
        if (newCap < s.totalDeposited) revert CapExceeded();

        s.cap = newCap;
        s.paused = paused;

        emit StrategyUpdated(strategyId, newCap, paused);
    }

    function pauseStrategy(uint256 strategyId) external onlyOperator strategyExists(strategyId) {
        if (strategies[strategyId].paused) revert StrategyPaused();
        strategies[strategyId].paused = true;
        emit StrategyPausedEvent(strategyId);
    }

    function unpauseStrategy(uint256 strategyId) external onlyOperator strategyExists(strategyId) {
        if (!strategies[strategyId].paused) revert StrategyNotPaused();
        strategies[strategyId].paused = false;
        emit StrategyUnpausedEvent(strategyId);
    }

    function addYield(uint256 strategyId, uint256 amount) external onlyOperator strategyExists(strategyId) {
        if (amount == 0) revert ZeroAmount();
        Strategy storage s = strategies[strategyId];
        if (s.totalDeposited == 0) revert NoDepositors();

        // Effects before interactions: update yield accounting first
        s.accYieldPerShare += (amount * ACC_PRECISION) / s.totalDeposited;

        // Interaction: pull yield tokens from operator
        _safeTransferFrom(s.token, msg.sender, address(this), amount);

        emit YieldAdded(strategyId, amount);
    }

    // ----------------------------------------------------------------------
    // User — Deposit
    // ----------------------------------------------------------------------
    function deposit(uint256 strategyId, uint256 amount) external nonReentrant strategyExists(strategyId) {
        if (amount == 0) revert ZeroAmount();

        Strategy storage s = strategies[strategyId];
        if (s.paused) revert StrategyPaused();
        if (s.totalDeposited + amount > s.cap) revert CapExceeded();

        // Effects before interactions: update position and totals first
        _updatePosition(msg.sender, strategyId, positions[msg.sender][strategyId].principal + amount);
        s.totalDeposited += amount;

        // Interaction: pull deposit tokens from user
        _safeTransferFrom(s.token, msg.sender, address(this), amount);

        emit Deposit(msg.sender, strategyId, amount);
    }

    // ----------------------------------------------------------------------
    // User — Withdraw (principal + accumulated yield, with 0.5% fee on principal)
    // ----------------------------------------------------------------------
    function withdraw(uint256 strategyId, uint256 principalAmount) external nonReentrant strategyExists(strategyId) {
        if (principalAmount == 0) revert ZeroAmount();

        UserPosition storage pos = positions[msg.sender][strategyId];
        if (principalAmount > pos.principal) revert InsufficientPrincipal();

        // Effects before interactions
        _updatePosition(msg.sender, strategyId, pos.principal - principalAmount);

        Strategy storage s = strategies[strategyId];
        s.totalDeposited -= principalAmount;

        uint256 fee = (principalAmount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netPrincipal = principalAmount - fee;

        uint256 yieldAmount = pos.accruedYield;
        pos.accruedYield = 0;

        uint256 toUser = netPrincipal + yieldAmount;

        // Interactions
        if (toUser > 0) {
            _safeTransfer(s.token, msg.sender, toUser);
        }
        if (fee > 0) {
            _safeTransfer(s.token, feeRecipient, fee);
        }

        emit Withdraw(msg.sender, strategyId, principalAmount, yieldAmount, fee);
    }

    // ----------------------------------------------------------------------
    // User — Claim Yield (without withdrawing principal)
    // ----------------------------------------------------------------------
    function claimYield(uint256 strategyId) external nonReentrant strategyExists(strategyId) {
        // Effects first: settle pending yield into accruedYield
        _updatePosition(msg.sender, strategyId, positions[msg.sender][strategyId].principal);

        UserPosition storage pos = positions[msg.sender][strategyId];
        uint256 yieldAmount = pos.accruedYield;
        if (yieldAmount == 0) revert NothingToClaim();

        // Effects before interactions
        pos.accruedYield = 0;

        // Interaction
        address token = strategies[strategyId].token;
        _safeTransfer(token, msg.sender, yieldAmount);

        emit YieldClaimed(msg.sender, strategyId, yieldAmount);
    }

    // ----------------------------------------------------------------------
    // Views
    // ----------------------------------------------------------------------
    function pendingYield(address user, uint256 strategyId) external view strategyExists(strategyId) returns (uint256) {
        UserPosition storage pos = positions[user][strategyId];
        Strategy storage s = strategies[strategyId];

        uint256 pending = (pos.principal * s.accYieldPerShare) / ACC_PRECISION;
        uint256 unrealized = pending > pos.yieldDebt ? pending - pos.yieldDebt : 0;
        return pos.accruedYield + unrealized;
    }

    function getUserPosition(address user, uint256 strategyId) external view strategyExists(strategyId) returns (
        uint256 principal,
        uint256 accruedYield,
        uint256 yieldDebt
    ) {
        UserPosition storage pos = positions[user][strategyId];
        return (pos.principal, pos.accruedYield, pos.yieldDebt);
    }

    function getStrategy(uint256 strategyId) external view strategyExists(strategyId) returns (
        address token,
        uint256 cap,
        uint256 totalDeposited,
        uint256 accYieldPerShare,
        bool paused
    ) {
        Strategy storage s = strategies[strategyId];
        return (s.token, s.cap, s.totalDeposited, s.accYieldPerShare, s.paused);
    }

    // ----------------------------------------------------------------------
    // Internal — Position Update (harvest yield before changing principal)
    // ----------------------------------------------------------------------
    function _updatePosition(address user, uint256 strategyId, uint256 newPrincipal) internal {
        UserPosition storage pos = positions[user][strategyId];
        Strategy storage s = strategies[strategyId];

        uint256 pending = (pos.principal * s.accYieldPerShare) / ACC_PRECISION;
        if (pending > pos.yieldDebt) {
            pos.accruedYield += pending - pos.yieldDebt;
        }

        pos.principal = newPrincipal;
        pos.yieldDebt = (newPrincipal * s.accYieldPerShare) / ACC_PRECISION;
    }

    function _maxCapFor(address token) internal view returns (uint256) {
        return MAX_CAP_UNITS * (10 ** uint256(_decimals(token)));
    }

    function _decimals(address token) internal view returns (uint8) {
        try IERC20(token).decimals() returns (uint8 d) {
            if (d == 0) return 18;
            return d;
        } catch {
            return 18;
        }
    }

    // ----------------------------------------------------------------------
    // Internal — Safe ERC20 transfers (no stale-balance checks)
    // ----------------------------------------------------------------------
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 0x20), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 0x20), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }
}
