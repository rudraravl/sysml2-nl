// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IStrategy {
    function deposit(uint256 amount) external returns (uint256 receiptTokensMinted);
    function withdraw(uint256 receiptAmount) external returns (uint256 tokensReturned);
    function claimRewards() external returns (uint256 rewardsClaimed);
    function totalReceiptTokens() external view returns (uint256);
    function totalUnderlying() external view returns (uint256);
    function receiptToken() external view returns (address);
    function underlyingToken() external view returns (address);
}

contract YieldStrategyManager {
    error Unauthorized();
    error StrategyNotFound();
    error StrategyPaused();
    error StrategyNotPaused();
    error ZeroAddress();
    error ZeroAmount();
    error ExceedsStrategyCapacity();
    error InsufficientDeposit();
    error InsufficientReceiptBalance();
    error TransferFailed();
    error NothingToClaim();
    error ReentrantCall();
    error InsufficientReturned();

    event StrategyAdded(uint256 indexed strategyId, address indexed strategy, address indexed underlyingToken, address receiptToken);
    event StrategyConfigUpdated(uint256 indexed strategyId, uint256 capacity);
    event StrategyPauseToggled(uint256 indexed strategyId, bool paused);
    event Deposited(uint256 indexed strategyId, address indexed user, uint256 amount, uint256 receiptAmount);
    event Withdrawn(uint256 indexed strategyId, address indexed user, uint256 amount, uint256 fee, uint256 receiptAmount);
    event RewardsClaimed(uint256 indexed strategyId, address indexed user, uint256 rewardAmount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    struct StrategyConfig {
        IStrategy strategy;
        IERC20 underlyingToken;
        IERC20 receiptToken;
        uint8 baseTokenDecimals;
        uint256 totalDeposited;
        uint256 capacity;
        bool paused;
        bool exists;
    }

    uint256 public constant MAX_CAPACITY = 1_000_000;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public operator;
    uint256 public strategyCount;

    mapping(uint256 => StrategyConfig) public strategies;
    mapping(uint256 => mapping(address => uint256)) public userDeposits;
    mapping(uint256 => mapping(address => uint256)) public userReceiptBalances;
    mapping(uint256 => mapping(address => uint256)) public pendingRewards;

    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier strategyExists(uint256 strategyId) {
        if (!strategies[strategyId].exists) revert StrategyNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function addStrategy(address _strategy, uint256 _capacity)
        external
        onlyOperator
        returns (uint256 strategyId)
    {
        if (_strategy == address(0)) revert ZeroAddress();
        if (_capacity == 0 || _capacity > MAX_CAPACITY) revert ExceedsStrategyCapacity();

        IStrategy strategy = IStrategy(_strategy);
        address underlying = strategy.underlyingToken();
        address receipt = strategy.receiptToken();
        if (underlying == address(0) || receipt == address(0)) revert ZeroAddress();

        uint8 decimals = IERC20(underlying).decimals();
        uint256 scaledCapacity = _capacity * (10 ** decimals);

        strategyId = strategyCount++;
        strategies[strategyId] = StrategyConfig({
            strategy: strategy,
            underlyingToken: IERC20(underlying),
            receiptToken: IERC20(receipt),
            baseTokenDecimals: decimals,
            totalDeposited: 0,
            capacity: scaledCapacity,
            paused: false,
            exists: true
        });

        emit StrategyAdded(strategyId, _strategy, underlying, receipt);
    }

    function updateStrategyConfig(uint256 strategyId, uint256 _capacity)
        external
        onlyOperator
        strategyExists(strategyId)
    {
        if (_capacity == 0 || _capacity > MAX_CAPACITY) revert ExceedsStrategyCapacity();
        uint256 scaledCapacity = _capacity * (10 ** strategies[strategyId].baseTokenDecimals);
        strategies[strategyId].capacity = scaledCapacity;
        emit StrategyConfigUpdated(strategyId, _capacity);
    }

    function pauseStrategy(uint256 strategyId) external onlyOperator strategyExists(strategyId) {
        if (strategies[strategyId].paused) revert StrategyPaused();
        strategies[strategyId].paused = true;
        emit StrategyPauseToggled(strategyId, true);
    }

    function unpauseStrategy(uint256 strategyId) external onlyOperator strategyExists(strategyId) {
        if (!strategies[strategyId].paused) revert StrategyNotPaused();
        strategies[strategyId].paused = false;
        emit StrategyPauseToggled(strategyId, false);
    }

    function deposit(uint256 strategyId, uint256 amount)
        external
        nonReentrant
        strategyExists(strategyId)
    {
        StrategyConfig storage config = strategies[strategyId];
        if (config.paused) revert StrategyPaused();
        if (amount == 0) revert ZeroAmount();
        if (config.totalDeposited + amount > config.capacity) revert ExceedsStrategyCapacity();

        // Effects: update state before external interactions
        userDeposits[strategyId][msg.sender] += amount;
        config.totalDeposited += amount;

        // Interactions
        if (!config.underlyingToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        if (!config.underlyingToken.approve(address(config.strategy), amount)) revert TransferFailed();

        uint256 receiptAmount = config.strategy.deposit(amount);
        if (receiptAmount == 0) revert ZeroAmount();

        // Update receipt balance after interaction
        userReceiptBalances[strategyId][msg.sender] += receiptAmount;

        emit Deposited(strategyId, msg.sender, amount, receiptAmount);
    }

    function withdraw(uint256 strategyId, uint256 amount)
        external
        nonReentrant
        strategyExists(strategyId)
    {
        StrategyConfig storage config = strategies[strategyId];
        if (amount == 0) revert ZeroAmount();
        if (userDeposits[strategyId][msg.sender] < amount) revert InsufficientDeposit();

        uint256 totalReceipts = config.strategy.totalReceiptTokens();
        uint256 totalUnderlying = config.strategy.totalUnderlying();
        if (totalUnderlying == 0) revert ZeroAmount();

        uint256 receiptAmount = (amount * totalReceipts) / totalUnderlying;
        if (receiptAmount == 0) revert ZeroAmount();
        if (userReceiptBalances[strategyId][msg.sender] < receiptAmount) revert InsufficientReceiptBalance();

        // Effects: update state before external interactions
        userDeposits[strategyId][msg.sender] -= amount;
        userReceiptBalances[strategyId][msg.sender] -= receiptAmount;
        config.totalDeposited -= amount;

        // Interactions
        uint256 tokensReturned = config.strategy.withdraw(receiptAmount);
        if (tokensReturned == 0) revert ZeroAmount();

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        if (tokensReturned < fee) revert InsufficientReturned();
        uint256 netAmount = tokensReturned - fee;

        if (fee > 0) {
            if (!config.underlyingToken.transfer(operator, fee)) revert TransferFailed();
        }
        if (!config.underlyingToken.transfer(msg.sender, netAmount)) revert TransferFailed();

        emit Withdrawn(strategyId, msg.sender, amount, fee, receiptAmount);
    }

    function claimRewards(uint256 strategyId)
        external
        nonReentrant
        strategyExists(strategyId)
        returns (uint256 claimed)
    {
        StrategyConfig storage config = strategies[strategyId];

        // Interactions: rely on return value instead of balance reads to avoid reentrancy-balance
        claimed = config.strategy.claimRewards();
        if (claimed == 0) revert NothingToClaim();

        // Effects
        pendingRewards[strategyId][msg.sender] += claimed;

        // Transfer rewards to user
        if (!config.receiptToken.transfer(msg.sender, claimed)) revert TransferFailed();

        emit RewardsClaimed(strategyId, msg.sender, claimed);
    }

    function getStrategy(uint256 strategyId)
        external
        view
        strategyExists(strategyId)
        returns (
            address strategy,
            address underlyingToken,
            address receiptToken,
            uint256 totalDeposited,
            uint256 capacity,
            bool paused
        )
    {
        StrategyConfig storage config = strategies[strategyId];
        return (
            address(config.strategy),
            address(config.underlyingToken),
            address(config.receiptToken),
            config.totalDeposited,
            config.capacity,
            config.paused
        );
    }

    function getUserPosition(uint256 strategyId, address user)
        external
        view
        strategyExists(strategyId)
        returns (uint256 deposited, uint256 receiptBalance, uint256 rewards)
    {
        return (
            userDeposits[strategyId][user],
            userReceiptBalances[strategyId][user],
            pendingRewards[strategyId][user]
        );
    }
}
