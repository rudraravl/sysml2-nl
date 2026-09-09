// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IStrategy {
    function asset() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract DAOTreasury {
    //-------------------------------------------------------------------------
    // Events
    //-------------------------------------------------------------------------
    event StrategyProposed(uint256 indexed strategyId, address indexed proposer, address strategy, address asset);
    event StrategyApproved(uint256 indexed strategyId, address indexed operator, uint256 approvedAt);
    event StrategyPaused(uint256 indexed strategyId, address indexed operator);
    event StrategyUnpaused(uint256 indexed strategyId, address indexed operator);
    event MaxCapitalSet(uint256 indexed strategyId, uint256 maxCapital);
    event FundsDeposited(uint256 indexed strategyId, address indexed caller, uint256 amount, uint256 shares);
    event FundsWithdrawn(uint256 indexed strategyId, address indexed caller, uint256 assetsReceived, uint256 sharesBurned);
    event TreasuryDeposit(address indexed asset, address indexed depositor, uint256 amount, uint256 shares);
    event TreasuryRedeem(address indexed asset, address indexed redeemer, uint256 shares, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    //-------------------------------------------------------------------------
    // Errors
    //-------------------------------------------------------------------------
    error NotOperator();
    error StrategyNotApproved();
    error StrategyIsPaused();
    error StrategyNotPaused();
    error StrategyAlreadyApproved();
    error ReviewPeriodNotElapsed();
    error MaxCapitalExceeded();
    error InsufficientShares();
    error InsufficientFreeBalance();
    error ZeroAmount();
    error ZeroAddress();
    error InvalidStrategy();
    error ExceedsMaxCapital();
    error ReentrancyDetected();
    error TransferFailed();

    //-------------------------------------------------------------------------
    // Constants
    //-------------------------------------------------------------------------
    uint256 public constant REVIEW_PERIOD = 48 hours;
    uint256 public constant MAX_STRATEGY_PERCENT = 25;
    uint256 public constant PERCENT_DENOMINATOR = 100;

    //-------------------------------------------------------------------------
    // Storage
    //-------------------------------------------------------------------------
    address public operator;
    uint256 public nextStrategyId;
    uint256 private _locked;

    struct Strategy {
        address strategy;
        address asset;
        bool approved;
        bool paused;
        uint64 proposedAt;
        uint64 approvedAt;
        uint256 maxCapital;
        uint256 allocatedCapital;
    }

    mapping(uint256 => Strategy) public strategies;
    mapping(address => uint256) public totalShares;
    mapping(address => mapping(address => uint256)) public userShares;

    //-------------------------------------------------------------------------
    // Modifiers
    //-------------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        nextStrategyId = 1;
        _locked = 1;
    }

    //-------------------------------------------------------------------------
    // Operator Management
    //-------------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    //-------------------------------------------------------------------------
    // Strategy Lifecycle
    //-------------------------------------------------------------------------
    function proposeStrategy(address strategy) external returns (uint256 strategyId) {
        if (strategy == address(0)) revert ZeroAddress();
        address asset = IStrategy(strategy).asset();
        if (asset == address(0)) revert InvalidStrategy();

        strategyId = nextStrategyId++;
        strategies[strategyId] = Strategy({
            strategy: strategy,
            asset: asset,
            approved: false,
            paused: false,
            proposedAt: uint64(block.timestamp),
            approvedAt: 0,
            maxCapital: 0,
            allocatedCapital: 0
        });

        emit StrategyProposed(strategyId, msg.sender, strategy, asset);
    }

    function approveStrategy(uint256 strategyId) external onlyOperator {
        Strategy storage s = strategies[strategyId];
        if (s.strategy == address(0)) revert InvalidStrategy();
        if (s.approved) revert StrategyAlreadyApproved();
        if (block.timestamp < uint256(s.proposedAt) + REVIEW_PERIOD) revert ReviewPeriodNotElapsed();

        s.approved = true;
        s.approvedAt = uint64(block.timestamp);

        emit StrategyApproved(strategyId, msg.sender, block.timestamp);
    }

    function pauseStrategy(uint256 strategyId) external onlyOperator {
        Strategy storage s = strategies[strategyId];
        if (!s.approved) revert StrategyNotApproved();
        if (s.paused) revert StrategyIsPaused();
        s.paused = true;
        emit StrategyPaused(strategyId, msg.sender);
    }

    function unpauseStrategy(uint256 strategyId) external onlyOperator {
        Strategy storage s = strategies[strategyId];
        if (!s.approved) revert StrategyNotApproved();
        if (!s.paused) revert StrategyNotPaused();
        s.paused = false;
        emit StrategyUnpaused(strategyId, msg.sender);
    }

    function setMaxCapital(uint256 strategyId, uint256 maxCapital) external onlyOperator {
        Strategy storage s = strategies[strategyId];
        if (!s.approved) revert StrategyNotApproved();
        if (s.allocatedCapital > maxCapital) revert ExceedsMaxCapital();
        s.maxCapital = maxCapital;
        emit MaxCapitalSet(strategyId, maxCapital);
    }

    //-------------------------------------------------------------------------
    // View Functions
    //-------------------------------------------------------------------------
    function freeBalance(address asset) public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function totalAllocated(address asset) public view returns (uint256 total) {
        for (uint256 i = 1; i < nextStrategyId; i++) {
            if (strategies[i].asset == asset) {
                total += strategies[i].allocatedCapital;
            }
        }
    }

    function totalTreasuryValue(address asset) public view returns (uint256) {
        return freeBalance(asset) + totalAllocated(asset);
    }

    function strategyCurrentValue(uint256 strategyId) public view returns (uint256) {
        Strategy storage s = strategies[strategyId];
        address strategy = s.strategy;
        if (strategy == address(0)) return 0;
        uint256 held = IStrategy(strategy).balanceOf(address(this));
        if (held < 1) return 0;
        uint256 ta = IStrategy(strategy).totalAssets();
        uint256 ts = IStrategy(strategy).totalSupply();
        if (ts < 1) return 0;
        return (held * ta) / ts;
    }

    function totalTreasuryCurrentValue(address asset) public view returns (uint256 total) {
        total = freeBalance(asset);
        for (uint256 i = 1; i < nextStrategyId; i++) {
            if (strategies[i].asset == asset) {
                total += strategyCurrentValue(i);
            }
        }
    }

    function getUserShares(address asset, address user) external view returns (uint256) {
        return userShares[asset][user];
    }

    //-------------------------------------------------------------------------
    // Treasury Deposit / Redeem
    //-------------------------------------------------------------------------
    function deposit(address asset, uint256 amount) external nonReentrant returns (uint256 shares) {
        if (amount < 1) revert ZeroAmount();
        if (asset == address(0)) revert ZeroAddress();

        uint256 totalValue = totalTreasuryCurrentValue(asset);
        uint256 totalShares_ = totalShares[asset];

        if (totalShares_ < 1 || totalValue < 1) {
            shares = amount;
        } else {
            shares = (amount * totalShares_) / totalValue;
        }
        if (shares < 1) revert ZeroAmount();

        userShares[asset][msg.sender] += shares;
        totalShares[asset] += shares;

        _safeTransferFrom(asset, msg.sender, address(this), amount);

        emit TreasuryDeposit(asset, msg.sender, amount, shares);
    }

    function redeem(address asset, uint256 shares) external nonReentrant returns (uint256 amount) {
        if (shares < 1) revert ZeroAmount();
        if (userShares[asset][msg.sender] < shares) revert InsufficientShares();

        uint256 totalValue = totalTreasuryCurrentValue(asset);
        uint256 totalShares_ = totalShares[asset];
        if (totalShares_ < 1) revert InsufficientShares();

        amount = (shares * totalValue) / totalShares_;
        if (amount < 1) revert ZeroAmount();

        uint256 free = freeBalance(asset);
        if (amount > free) revert InsufficientFreeBalance();

        userShares[asset][msg.sender] -= shares;
        totalShares[asset] -= shares;

        _safeTransfer(asset, msg.sender, amount);

        emit TreasuryRedeem(asset, msg.sender, shares, amount);
    }

    //-------------------------------------------------------------------------
    // Strategy Allocation / Withdrawal
    //-------------------------------------------------------------------------
    function depositIntoStrategy(uint256 strategyId, uint256 amount)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (amount < 1) revert ZeroAmount();

        Strategy storage s = strategies[strategyId];
        if (!s.approved) revert StrategyNotApproved();
        if (s.paused) revert StrategyIsPaused();

        address asset = s.asset;
        address strategy = s.strategy;

        uint256 free = freeBalance(asset);
        if (amount > free) revert InsufficientFreeBalance();

        if (s.maxCapital > 0 && s.allocatedCapital + amount > s.maxCapital) {
            revert ExceedsMaxCapital();
        }

        uint256 treasuryValue = totalTreasuryValue(asset);
        if (s.allocatedCapital + amount > (treasuryValue * MAX_STRATEGY_PERCENT) / PERCENT_DENOMINATOR) {
            revert MaxCapitalExceeded();
        }

        // Pre-compute expected shares from the strategy's current share price (checks).
        uint256 stratTA = IStrategy(strategy).totalAssets();
        uint256 stratTS = IStrategy(strategy).totalSupply();
        if (stratTS < 1 || stratTA < 1) {
            shares = amount;
        } else {
            shares = (amount * stratTS) / stratTA;
        }
        if (shares < 1) revert InvalidStrategy();

        // Effects before interactions.
        s.allocatedCapital += amount;

        // Interactions: approve, deposit, then reset approval to zero.
        _safeApprove(asset, strategy, amount);
        uint256 receivedShares = IStrategy(strategy).deposit(amount, address(this));
        _safeApprove(asset, strategy, 0);

        if (receivedShares < 1) revert InvalidStrategy();

        emit FundsDeposited(strategyId, msg.sender, amount, shares);
    }

    function withdrawFromStrategy(uint256 strategyId, uint256 amount)
        external
        nonReentrant
        returns (uint256 sharesBurned, uint256 assetsReceived)
    {
        if (amount < 1) revert ZeroAmount();

        Strategy storage s = strategies[strategyId];
        if (!s.approved) revert StrategyNotApproved();

        address asset = s.asset;
        address strategy = s.strategy;

        uint256 ta = IStrategy(strategy).totalAssets();
        uint256 ts = IStrategy(strategy).totalSupply();
        if (ts < 1 || ta < 1) revert InvalidStrategy();

        uint256 held = IStrategy(strategy).balanceOf(address(this));
        if (held < 1) revert InvalidStrategy();

        // Shares needed to receive at least `amount`, rounded up.
        sharesBurned = (amount * ts + ta - 1) / ta;
        if (sharesBurned > held) {
            sharesBurned = held;
        }

        // Expected assets to be received (used for accounting; matches standard strategies).
        assetsReceived = (sharesBurned * ta) / ts;
        if (assetsReceived < 1) revert InvalidStrategy();

        // Effects before interactions.
        s.allocatedCapital = s.allocatedCapital > assetsReceived
            ? s.allocatedCapital - assetsReceived
            : 0;

        // Interactions.
        uint256 received = IStrategy(strategy).redeem(sharesBurned, address(this), address(this));
        if (received < 1) revert InvalidStrategy();

        emit FundsWithdrawn(strategyId, msg.sender, assetsReceived, sharesBurned);
    }

    //-------------------------------------------------------------------------
    // Internal Safe Transfer Helpers
    //-------------------------------------------------------------------------
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!ok) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        if (!ok) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, spender, amount));
        if (!ok) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }
}
