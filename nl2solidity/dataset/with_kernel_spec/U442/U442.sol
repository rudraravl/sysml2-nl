// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract RWAVault {
    // ============ Access Control ============
    address public owner;
    address public operator;

    // ============ Constants ============
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_STRATEGIES_PER_MONTH = 10;
    uint256 public constant MONTH_DURATION = 30 days;
    uint256 internal constant YIELD_PRECISION = 1e18;

    // ============ Strategy Configuration ============
    struct Strategy {
        bool exists;
        bool active;
        uint64 addedAt;
        uint64 targetWeightBps;
        address strategyAddress;
    }

    IERC20[] public supportedTokens;
    mapping(IERC20 => Strategy) public strategies;

    // ============ Share Accounting (per token) ============
    mapping(IERC20 => uint256) public totalShares;
    mapping(IERC20 => mapping(address => uint256)) public userShares;
    mapping(IERC20 => uint256) public totalDeposited;

    // ============ Yield Accounting (per token) ============
    mapping(IERC20 => uint256) public yieldPerShare; // cumulative, scaled by 1e18
    mapping(IERC20 => uint256) public totalYieldPool;
    mapping(IERC20 => mapping(address => uint256)) public userYieldDebt;

    // ============ Fee Accounting (per token) ============
    mapping(IERC20 => uint256) public accumulatedFees;

    // ============ Monthly Strategy Addition Limit ============
    uint256 public monthStartTimestamp;
    uint256 public strategiesAddedThisMonth;

    // ============ Reentrancy Guard ============
    uint256 private _locked = 1;

    // ============ Custom Errors ============
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error TokenNotSupported();
    error StrategyInactive();
    error StrategyExists();
    error StrategyNotFound();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientLiquidity();
    error NoYield();
    error NoFees();
    error InvalidWeight();
    error MonthlyLimitExceeded();
    error TransferFailed();
    error Reentrancy();

    // ============ Events ============
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address indexed token, uint256 shares, uint256 amount, uint256 fee);
    event YieldClaimed(address indexed user, address indexed token, uint256 amount);
    event YieldReported(address indexed token, uint256 amount, uint256 newYieldPerShare);
    event StrategyAdded(address indexed token, address indexed strategyAddress, uint64 targetWeightBps, uint64 addedAt);
    event StrategyUpdated(address indexed token, uint64 targetWeightBps, bool active, address strategyAddress);
    event Rebalance(address indexed token, uint256 amountToStrategy, uint256 amountFromStrategy);
    event FeesClaimed(address indexed token, address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Constructor ============
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        monthStartTimestamp = block.timestamp;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    // ============ Owner Administration ============
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function claimFees(IERC20 token) external onlyOwner returns (uint256 amount) {
        amount = accumulatedFees[token];
        if (amount == 0) revert NoFees();
        accumulatedFees[token] = 0;
        _safeTransfer(token, owner, amount);
        emit FeesClaimed(address(token), owner, amount);
    }

    // ============ Operator: Strategy Management ============
    function addStrategy(IERC20 token, address strategyAddress, uint64 targetWeightBps) external onlyOperator {
        if (address(token) == address(0)) revert ZeroAddress();
        if (strategies[token].exists) revert StrategyExists();
        if (targetWeightBps > BPS_DENOMINATOR) revert InvalidWeight();
        _enforceMonthlyLimit();

        strategies[token] = Strategy({
            exists: true,
            active: true,
            addedAt: uint64(block.timestamp),
            targetWeightBps: targetWeightBps,
            strategyAddress: strategyAddress
        });
        supportedTokens.push(token);

        emit StrategyAdded(address(token), strategyAddress, targetWeightBps, uint64(block.timestamp));
    }

    function updateStrategy(IERC20 token, uint64 targetWeightBps, bool active, address strategyAddress) external onlyOperator {
        if (!strategies[token].exists) revert StrategyNotFound();
        if (targetWeightBps > BPS_DENOMINATOR) revert InvalidWeight();
        strategies[token].targetWeightBps = targetWeightBps;
        strategies[token].active = active;
        strategies[token].strategyAddress = strategyAddress;
        emit StrategyUpdated(address(token), targetWeightBps, active, strategyAddress);
    }

    function rebalance(IERC20 token, uint256 amountToStrategy, uint256 amountFromStrategy) external onlyOperator {
        if (!strategies[token].exists) revert StrategyNotFound();
        address strat = strategies[token].strategyAddress;
        if (strat == address(0)) revert ZeroAddress();

        if (amountToStrategy > 0) {
            _safeTransfer(token, strat, amountToStrategy);
        }
        if (amountFromStrategy > 0) {
            _safeTransferFrom(token, strat, address(this), amountFromStrategy);
        }
        emit Rebalance(address(token), amountToStrategy, amountFromStrategy);
    }

    function reportYield(IERC20 token, uint256 yieldAmount) external onlyOperator {
        if (!strategies[token].exists) revert StrategyNotFound();
        if (yieldAmount == 0) revert ZeroAmount();
        uint256 ts = totalShares[token];
        if (ts == 0) revert ZeroShares();

        _safeTransferFrom(token, msg.sender, address(this), yieldAmount);
        yieldPerShare[token] += (yieldAmount * YIELD_PRECISION) / ts;
        totalYieldPool[token] += yieldAmount;
        emit YieldReported(address(token), yieldAmount, yieldPerShare[token]);
    }

    // ============ User: Deposit ============
    function deposit(IERC20 token, uint256 amount) external nonReentrant returns (uint256 shares) {
        if (!strategies[token].exists) revert TokenNotSupported();
        if (!strategies[token].active) revert StrategyInactive();
        if (amount == 0) revert ZeroAmount();

        uint256 ts = totalShares[token];
        uint256 td = totalDeposited[token];
        uint256 yieldDebtDelta;
        if (ts == 0) {
            shares = amount;
            yieldDebtDelta = 0;
        } else {
            shares = (amount * ts) / td;
            // Single division to avoid divide-before-multiply precision loss.
            yieldDebtDelta = (amount * ts * yieldPerShare[token]) / (td * YIELD_PRECISION);
        }
        if (shares == 0) revert ZeroShares();

        // Effects
        totalShares[token] = ts + shares;
        userShares[token][msg.sender] += shares;
        totalDeposited[token] = td + amount;
        userYieldDebt[token][msg.sender] += yieldDebtDelta;

        // Interactions
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit Deposit(msg.sender, address(token), amount, shares);
    }

    // ============ User: Withdraw ============
    function withdraw(IERC20 token, uint256 shares) external nonReentrant returns (uint256 amountOut) {
        if (!strategies[token].exists) revert TokenNotSupported();
        if (shares == 0) revert ZeroShares();

        uint256 userShares_ = userShares[token][msg.sender];
        if (userShares_ < shares) revert InsufficientShares();

        uint256 ts = totalShares[token];
        uint256 td = totalDeposited[token];
        amountOut = (shares * td) / ts;
        if (amountOut == 0) revert ZeroAmount();

        // Single division to avoid divide-before-multiply precision loss.
        uint256 fee = (shares * td * WITHDRAWAL_FEE_BPS) / (ts * BPS_DENOMINATOR);
        uint256 net = amountOut - fee;

        if (token.balanceOf(address(this)) < net) revert InsufficientLiquidity();

        // Effects: reduce yield debt proportionally to avoid underflow and
        // preserve pending yield on remaining shares.
        uint256 remainingShares = userShares_ - shares;
        uint256 newDebt = (userYieldDebt[token][msg.sender] * remainingShares) / userShares_;
        userYieldDebt[token][msg.sender] = newDebt;

        totalShares[token] = ts - shares;
        userShares[token][msg.sender] = remainingShares;
        totalDeposited[token] = td - amountOut;
        accumulatedFees[token] += fee;

        // Interactions
        _safeTransfer(token, msg.sender, net);
        emit Withdraw(msg.sender, address(token), shares, amountOut, fee);
    }

    // ============ User: Claim Yield ============
    function claimYield(IERC20 token) external nonReentrant returns (uint256 claimed) {
        if (!strategies[token].exists) revert TokenNotSupported();
        claimed = _pendingYield(token, msg.sender);
        if (claimed == 0) revert NoYield();

        // Effects
        totalYieldPool[token] -= claimed;
        userYieldDebt[token][msg.sender] = (userShares[token][msg.sender] * yieldPerShare[token]) / YIELD_PRECISION;

        // Interactions
        _safeTransfer(token, msg.sender, claimed);
        emit YieldClaimed(msg.sender, address(token), claimed);
    }

    // ============ View Functions ============
    function pendingYield(IERC20 token, address user) external view returns (uint256) {
        return _pendingYield(token, user);
    }

    function amountToShares(IERC20 token, uint256 amount) public view returns (uint256) {
        uint256 ts = totalShares[token];
        if (ts == 0) return amount;
        return (amount * ts) / totalDeposited[token];
    }

    function sharesToAmount(IERC20 token, uint256 shares) public view returns (uint256) {
        uint256 ts = totalShares[token];
        if (ts == 0) return 0;
        return (shares * totalDeposited[token]) / ts;
    }

    function getStrategy(IERC20 token) external view returns (Strategy memory) {
        return strategies[token];
    }

    function supportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }

    function totalAssetsUnderManagement() external view returns (uint256 total) {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            total += totalDeposited[supportedTokens[i]];
        }
    }

    function userShareOf(IERC20 token, address user) external view returns (uint256) {
        uint256 ts = totalShares[token];
        if (ts == 0) return 0;
        return (userShares[token][user] * BPS_DENOMINATOR) / ts;
    }

    // ============ Internal Helpers ============
    function _pendingYield(IERC20 token, address user) internal view returns (uint256) {
        return (userShares[token][user] * yieldPerShare[token]) / YIELD_PRECISION - userYieldDebt[token][user];
    }

    function _enforceMonthlyLimit() internal {
        if (block.timestamp >= monthStartTimestamp + MONTH_DURATION) {
            // Advance to the most recent month boundary without divide-before-multiply.
            monthStartTimestamp = block.timestamp - ((block.timestamp - monthStartTimestamp) % MONTH_DURATION);
            strategiesAddedThisMonth = 0;
        }
        if (strategiesAddedThisMonth >= MAX_STRATEGIES_PER_MONTH) revert MonthlyLimitExceeded();
        strategiesAddedThisMonth++;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
