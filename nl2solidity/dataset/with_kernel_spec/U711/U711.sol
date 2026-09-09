// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function invest(address token, uint256 amount, address stablecoin, uint256 stableAmount) external returns (bool);
    function divest(address token, uint256 amount) external returns (uint256 returned);
    function harvest(address token) external returns (uint256 profit);
    function totalAssets(address token) external view returns (uint256);
}

contract AssetManagementVault {
    error NotOwner();
    error NotOperator();
    error NotApprovedStrategy();
    error TokenNotSupported();
    error StrategyNotApproved();
    error InsufficientBalance();
    error InsufficientStableAllocation();
    error AmountZero();
    error Paused();
    error NoPendingUpgrade();
    error UpgradeNotReady();
    error NothingToClaim();
    error StrategyInactive();
    error InvalidFee();
    error ReentrantCall();
    error InvalidAddress();
    error TransferFailed();

    event Deposited(address indexed token, address indexed user, uint256 amount);
    event Withdrawn(address indexed token, address indexed user, uint256 amount);
    event StrategyInitiated(uint256 indexed strategyId, address indexed strategy, address indexed token, uint256 amount, uint256 stableAmount);
    event StrategyRebalanced(uint256 indexed strategyId, uint256 amount);
    event StrategyClosed(uint256 indexed strategyId, uint256 returnedAmount, uint256 profit);
    event ProfitDistributed(address indexed token, uint256 profitAmount, uint256 feeAmount);
    event ProfitsClaimed(address indexed token, address indexed user, uint256 amount);
    event StrategyApproved(address indexed strategy, bool approved);
    event TokenSupported(address indexed token, bool supported);
    event ManagementFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PausedStatusChanged(bool paused);
    event UpgradeProposed(address indexed newImplementation, uint256 effectiveTime);
    event UpgradeConfirmed(address indexed newImplementation);
    event FundsMigrated(address indexed newVault, address indexed token, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event EthRescued(address indexed to, uint256 amount);

    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant MIN_STABLE_RATIO = 10; // 10%
    uint256 public constant UPGRADE_DELAY = 2 days;
    uint256 public constant ACC_PRECISION = 1e18;

    address public owner;
    address public operator;
    address public stablecoin;

    uint256 public managementFeeBps = 50; // 0.5%

    bool public paused;

    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public approvedStrategies;

    mapping(address => uint256) public totalDeposits;
    mapping(address => uint256) public availableBalance;
    mapping(address => mapping(address => uint256)) public userDeposits;

    mapping(address => uint256) public profitPerShare;
    mapping(address => mapping(address => uint256)) public userRewardDebt;
    mapping(address => mapping(address => uint256)) public userClaimable;

    struct StrategyPosition {
        address strategy;
        address token;
        uint256 allocated;
        uint256 stableAllocated;
        bool active;
    }

    StrategyPosition[] public strategies;

    address public pendingImplementation;
    uint256 public upgradeEffectiveTime;

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier validToken(address token) {
        if (!supportedTokens[token]) revert TokenNotSupported();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _owner, address _operator, address _stablecoin) {
        if (_owner == address(0) || _operator == address(0) || _stablecoin == address(0)) {
            revert InvalidAddress();
        }
        owner = _owner;
        operator = _operator;
        stablecoin = _stablecoin;
        supportedTokens[_stablecoin] = true;
        emit TokenSupported(_stablecoin, true);
        emit ManagementFeeUpdated(0, managementFeeBps);
    }

    function setSupportedToken(address token, bool supported) external onlyOwner {
        if (token == address(0)) revert InvalidAddress();
        supportedTokens[token] = supported;
        emit TokenSupported(token, supported);
    }

    function approveStrategy(address strategy, bool approved) external onlyOwner {
        if (strategy == address(0)) revert InvalidAddress();
        approvedStrategies[strategy] = approved;
        emit StrategyApproved(strategy, approved);
    }

    function setManagementFee(uint256 feeBps) external onlyOwner {
        if (feeBps > 2000) revert InvalidFee();
        uint256 old = managementFeeBps;
        managementFeeBps = feeBps;
        emit ManagementFeeUpdated(old, feeBps);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStatusChanged(_paused);
    }

    function transferOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function _updateProfit(address user, address token) internal {
        uint256 deposit = userDeposits[token][user];
        uint256 pending = (deposit * profitPerShare[token]) / ACC_PRECISION - userRewardDebt[token][user];
        if (pending > 0) {
            userClaimable[token][user] += pending;
        }
        userRewardDebt[token][user] = (deposit * profitPerShare[token]) / ACC_PRECISION;
    }

    function deposit(address token, uint256 amount) external whenNotPaused validToken(token) nonReentrant {
        if (amount == 0) revert AmountZero();

        _updateProfit(msg.sender, token);

        // Effects: update state before external call
        userDeposits[token][msg.sender] += amount;
        totalDeposits[token] += amount;
        availableBalance[token] += amount;
        userRewardDebt[token][msg.sender] = (userDeposits[token][msg.sender] * profitPerShare[token]) / ACC_PRECISION;

        // Interactions: pull tokens from depositor
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        emit Deposited(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external whenNotPaused validToken(token) nonReentrant {
        if (amount == 0) revert AmountZero();
        if (userDeposits[token][msg.sender] < amount) revert InsufficientBalance();
        if (availableBalance[token] < amount) revert InsufficientBalance();

        _updateProfit(msg.sender, token);

        // Effects: update state before external call
        userDeposits[token][msg.sender] -= amount;
        totalDeposits[token] -= amount;
        availableBalance[token] -= amount;
        userRewardDebt[token][msg.sender] = (userDeposits[token][msg.sender] * profitPerShare[token]) / ACC_PRECISION;

        // Interactions: send tokens to withdrawer
        if (!IERC20(token).transfer(msg.sender, amount)) {
            revert TransferFailed();
        }

        emit Withdrawn(token, msg.sender, amount);
    }

    function initiateStrategy(
        address strategy,
        address token,
        uint256 amount,
        uint256 stableAmount
    ) external onlyOperator validToken(token) nonReentrant {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (amount == 0) revert AmountZero();
        if (availableBalance[token] < amount) revert InsufficientBalance();
        if (availableBalance[stablecoin] < stableAmount) revert InsufficientBalance();
        if (stableAmount < (amount * MIN_STABLE_RATIO) / 100) revert InsufficientStableAllocation();

        // Effects: update state before external calls
        availableBalance[token] -= amount;
        availableBalance[stablecoin] -= stableAmount;

        strategies.push(
            StrategyPosition({
                strategy: strategy,
                token: token,
                allocated: amount,
                stableAllocated: stableAmount,
                active: true
            })
        );

        // Interactions
        if (!IERC20(token).approve(strategy, amount)) revert TransferFailed();
        if (!IERC20(stablecoin).approve(strategy, stableAmount)) revert TransferFailed();
        if (!IStrategy(strategy).invest(token, amount, stablecoin, stableAmount)) {
            revert TransferFailed();
        }

        emit StrategyInitiated(strategies.length - 1, strategy, token, amount, stableAmount);
    }

    function rebalanceStrategy(uint256 strategyId, uint256 newAmount) external onlyOperator nonReentrant {
        if (strategyId >= strategies.length) revert AmountZero();
        StrategyPosition storage pos = strategies[strategyId];
        if (!pos.active) revert StrategyInactive();
        if (!approvedStrategies[pos.strategy]) revert StrategyNotApproved();

        if (newAmount > pos.allocated) {
            uint256 delta = newAmount - pos.allocated;
            if (availableBalance[pos.token] < delta) revert InsufficientBalance();

            // Effects: update state before external calls
            availableBalance[pos.token] -= delta;
            pos.allocated = newAmount;

            // Interactions
            if (!IERC20(pos.token).approve(pos.strategy, delta)) revert TransferFailed();
            if (!IStrategy(pos.strategy).invest(pos.token, delta, stablecoin, 0)) {
                revert TransferFailed();
            }
        } else if (newAmount < pos.allocated) {
            uint256 delta = pos.allocated - newAmount;

            // Effects: update allocated before external call
            pos.allocated = newAmount;

            // Interactions
            uint256 returned = IStrategy(pos.strategy).divest(pos.token, delta);

            // Effects: update available balance after divest returns
            availableBalance[pos.token] += returned;
        }

        emit StrategyRebalanced(strategyId, newAmount);
    }

    function closeStrategy(uint256 strategyId) external onlyOperator nonReentrant {
        if (strategyId >= strategies.length) revert AmountZero();
        StrategyPosition storage pos = strategies[strategyId];
        if (!pos.active) revert StrategyInactive();

        // Effects: capture and update state before external call
        uint256 allocatedToDivest = pos.allocated;
        pos.active = false;
        pos.allocated = 0;
        pos.stableAllocated = 0;

        // Interactions
        uint256 returned = IStrategy(pos.strategy).divest(pos.token, allocatedToDivest);

        // Effects: update available balance after divest returns
        availableBalance[pos.token] += returned;

        emit StrategyClosed(strategyId, returned, 0);
    }

    function recordProfit(uint256 strategyId, uint256 profitAmount) external nonReentrant {
        if (strategyId >= strategies.length) revert AmountZero();
        StrategyPosition storage pos = strategies[strategyId];
        if (!pos.active) revert StrategyInactive();
        if (msg.sender != pos.strategy) revert NotApprovedStrategy();
        if (!approvedStrategies[pos.strategy]) revert StrategyNotApproved();
        if (profitAmount == 0) revert AmountZero();

        // Verify the strategy has transferred profit tokens to the vault
        if (IERC20(pos.token).balanceOf(address(this)) < availableBalance[pos.token] + profitAmount) {
            revert InsufficientBalance();
        }

        uint256 fee = (profitAmount * managementFeeBps) / FEE_PRECISION;
        uint256 distributable = profitAmount - fee;
        bool hasDepositors = totalDeposits[pos.token] > 0;

        // Effects: update all state before external calls
        availableBalance[pos.token] += profitAmount;
        availableBalance[pos.token] -= fee;

        if (hasDepositors) {
            profitPerShare[pos.token] += (distributable * ACC_PRECISION) / totalDeposits[pos.token];
        } else {
            availableBalance[pos.token] -= distributable;
        }

        // Interactions: transfer fee and distributable to owner
        if (fee > 0) {
            if (!IERC20(pos.token).transfer(owner, fee)) revert TransferFailed();
        }
        if (!hasDepositors) {
            if (!IERC20(pos.token).transfer(owner, distributable)) revert TransferFailed();
        }

        emit ProfitDistributed(pos.token, distributable, fee);
    }

    function claimProfits(address token) external validToken(token) nonReentrant {
        _updateProfit(msg.sender, token);
        uint256 amount = userClaimable[token][msg.sender];
        if (amount == 0) revert NothingToClaim();

        // Effects: update state before external call
        userClaimable[token][msg.sender] = 0;
        if (availableBalance[token] < amount) revert InsufficientBalance();
        availableBalance[token] -= amount;

        // Interactions
        if (!IERC20(token).transfer(msg.sender, amount)) revert TransferFailed();

        emit ProfitsClaimed(token, msg.sender, amount);
    }

    function pendingProfit(address token, address user) external view returns (uint256) {
        uint256 deposit = userDeposits[token][user];
        uint256 pending = (deposit * profitPerShare[token]) / ACC_PRECISION - userRewardDebt[token][user];
        return userClaimable[token][user] + pending;
    }

    function strategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function proposeUpgrade(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert InvalidAddress();
        pendingImplementation = newImplementation;
        upgradeEffectiveTime = block.timestamp + UPGRADE_DELAY;
        emit UpgradeProposed(newImplementation, upgradeEffectiveTime);
    }

    function confirmUpgrade() external onlyOwner {
        if (pendingImplementation == address(0)) revert NoPendingUpgrade();
        if (block.timestamp < upgradeEffectiveTime) revert UpgradeNotReady();
        address impl = pendingImplementation;
        pendingImplementation = address(0);
        upgradeEffectiveTime = 0;
        emit UpgradeConfirmed(impl);
    }

    function migrateFunds(address newVault, address token) external onlyOwner nonReentrant {
        if (newVault == address(0)) revert InvalidAddress();
        uint256 amount = availableBalance[token];
        if (amount == 0) revert AmountZero();

        // Effects: update state before external call
        availableBalance[token] = 0;

        // Interactions
        if (!IERC20(token).transfer(newVault, amount)) revert TransferFailed();

        emit FundsMigrated(newVault, token, amount);
    }

    function rescueEth(address payable to) external onlyOwner {
        if (to == address(0)) revert InvalidAddress();
        uint256 bal = address(this).balance;
        // Avoid strict equality check; proceed with whatever balance exists
        (bool ok, ) = to.call{value: bal}("");
        if (!ok) revert TransferFailed();
        emit EthRescued(to, bal);
    }
}
