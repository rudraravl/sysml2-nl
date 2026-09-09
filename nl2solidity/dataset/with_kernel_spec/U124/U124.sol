// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IStrategy {
    function invest(uint256 amount) external;
    function divest(uint256 amount) external returns (uint256);
    function harvest() external returns (uint256);
    function investedBalance() external view returns (uint256);
    function pendingRewards() external view returns (uint256);
}

contract AutomatedYieldVault {
    // ============ Custom Errors ============
    error Unauthorized();
    error Paused();
    error NotPaused();
    error ZeroAddress();
    error AmountZero();
    error InsufficientShares();
    error InsufficientBalance();
    error FeeTooHigh();
    error DepositTooSmall();
    error NoStrategies();
    error StrategyExists();
    error StrategyNotFound();
    error TransferFailed();
    error ReentrantCall();

    // ============ Events ============
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event StrategyAdded(address indexed strategy, uint256 allocationPoints);
    event StrategyAllocationUpdated(address indexed strategy, uint256 allocationPoints);
    event StrategyRemoved(address indexed strategy);
    event PerformanceFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event PausedStateChanged(bool paused);
    event Harvested(uint256 grossRewards, uint256 feeAmount, uint256 netRewards);
    event Invested(address indexed strategy, uint256 amount);
    event Divested(address indexed strategy, uint256 amount);

    // ============ Constants ============
    uint256 public constant MAX_PERFORMANCE_FEE = 1000; // 10% in basis points
    uint256 public constant MIN_DEPOSIT = 1e16; // 0.01 base tokens (18 decimals)
    uint256 private constant REWARD_PRECISION = 1e18;
    uint256 private constant BPS_DENOMINATOR = 10000;

    // ============ State Variables ============
    IERC20 public immutable baseToken;
    IERC20 public immutable rewardToken;

    address public owner;
    address public operator;
    uint256 public performanceFee; // in basis points
    bool public paused;

    uint256 public totalShares;
    mapping(address => uint256) public shares;

    uint256 public rewardPerShareStored;
    mapping(address => uint256) public userRewardPerSharePaid;
    mapping(address => uint256) public rewards;

    struct StrategyInfo {
        IStrategy strategy;
        uint256 allocationPoints;
        bool active;
    }
    StrategyInfo[] public strategies;
    uint256 public totalAllocationPoints;

    // ============ Reentrancy Guard ============
    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // ============ Constructor ============
    constructor(
        address _baseToken,
        address _rewardToken,
        address _operator,
        uint256 _performanceFee
    ) {
        if (_baseToken == address(0) || _rewardToken == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_performanceFee > MAX_PERFORMANCE_FEE) revert FeeTooHigh();

        baseToken = IERC20(_baseToken);
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
        performanceFee = _performanceFee;
        owner = msg.sender;

        emit OperatorUpdated(address(0), _operator);
        emit PerformanceFeeUpdated(0, _performanceFee);
    }

    // ============ Admin Functions ============

    function setOwner(address _owner) external onlyOwner {
        if (_owner == address(0)) revert ZeroAddress();
        owner = _owner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setPerformanceFee(uint256 _fee) external onlyOwner {
        if (_fee > MAX_PERFORMANCE_FEE) revert FeeTooHigh();
        emit PerformanceFeeUpdated(performanceFee, _fee);
        performanceFee = _fee;
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    // ============ Strategy Management ============

    function strategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function addStrategy(address _strategy, uint256 _allocationPoints) external onlyOwner {
        if (_strategy == address(0)) revert ZeroAddress();
        for (uint256 i = 0; i < strategies.length; i++) {
            if (address(strategies[i].strategy) == _strategy) revert StrategyExists();
        }
        strategies.push(StrategyInfo({
            strategy: IStrategy(_strategy),
            allocationPoints: _allocationPoints,
            active: true
        }));
        totalAllocationPoints += _allocationPoints;

        emit StrategyAdded(_strategy, _allocationPoints);
        emit StrategyAllocationUpdated(_strategy, _allocationPoints);
    }

    function updateStrategyAllocation(uint256 index, uint256 _allocationPoints) external onlyOwner {
        if (index >= strategies.length) revert StrategyNotFound();
        if (!strategies[index].active) revert StrategyNotFound();

        totalAllocationPoints = totalAllocationPoints - strategies[index].allocationPoints + _allocationPoints;
        strategies[index].allocationPoints = _allocationPoints;

        emit StrategyAllocationUpdated(address(strategies[index].strategy), _allocationPoints);
    }

    function removeStrategy(uint256 index) external onlyOwner nonReentrant {
        if (index >= strategies.length) revert StrategyNotFound();
        StrategyInfo storage si = strategies[index];
        IStrategy strategy = si.strategy;
        uint256 invested = strategy.investedBalance();
        uint256 allocation = si.allocationPoints;

        // Effects: update state before external calls
        totalAllocationPoints -= allocation;
        strategies[index] = strategies[strategies.length - 1];
        strategies.pop();

        emit StrategyRemoved(address(strategy));

        // Interactions: external call after state update
        if (invested > 0) {
            strategy.divest(invested);
        }
    }

    // ============ View Functions ============

    function totalValueLocked() public view returns (uint256) {
        uint256 idle = baseToken.balanceOf(address(this));
        uint256 invested = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                invested += strategies[i].strategy.investedBalance();
            }
        }
        return idle + invested;
    }

    function idleBalance() public view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }

    function pendingRewards(address user) public view returns (uint256) {
        return rewards[user] + (shares[user] * (rewardPerShareStored - userRewardPerSharePaid[user])) / REWARD_PRECISION;
    }

    function sharePrice() external view returns (uint256) {
        if (totalShares <= 0) return 1e18;
        return (totalValueLocked() * REWARD_PRECISION) / totalShares;
    }

    // ============ Internal Helpers ============

    function _updateReward(address user) internal {
        rewardPerShareStored = _currentRewardPerShare();
        if (user != address(0)) {
            rewards[user] = pendingRewards(user);
            userRewardPerSharePaid[user] = rewardPerShareStored;
        }
    }

    function _currentRewardPerShare() internal view returns (uint256) {
        if (totalShares <= 0) return rewardPerShareStored;
        uint256 pending = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                pending += strategies[i].strategy.pendingRewards();
            }
        }
        if (pending <= 0) return rewardPerShareStored;
        uint256 net = pending - (pending * performanceFee) / BPS_DENOMINATOR;
        return rewardPerShareStored + (net * REWARD_PRECISION) / totalShares;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        if (!token.transfer(to, amount)) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (!token.transferFrom(from, to, amount)) revert TransferFailed();
    }

    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        if (token.allowance(address(this), spender) < amount) {
            if (!token.approve(spender, type(uint256).max)) revert TransferFailed();
        }
    }

    function _investIdle() internal {
        if (totalAllocationPoints <= 0) return;
        uint256 idle = baseToken.balanceOf(address(this));
        if (idle <= 0) return;

        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            uint256 allocation = (idle * strategies[i].allocationPoints) / totalAllocationPoints;
            if (allocation <= 0) continue;
            _safeApprove(baseToken, address(strategies[i].strategy), allocation);
            strategies[i].strategy.invest(allocation);
            emit Invested(address(strategies[i].strategy), allocation);
        }
    }

    function _divestFromStrategies(uint256 amountNeeded) internal {
        uint256 remaining = amountNeeded;
        for (uint256 i = 0; i < strategies.length && remaining > 0; i++) {
            if (!strategies[i].active) continue;
            uint256 invested = strategies[i].strategy.investedBalance();
            if (invested <= 0) continue;

            uint256 toDivest = remaining;
            if (toDivest > invested) {
                toDivest = invested;
            }
            uint256 returned = strategies[i].strategy.divest(toDivest);
            if (returned > remaining) returned = remaining;
            remaining -= returned;
            emit Divested(address(strategies[i].strategy), returned);
        }
        if (remaining > 0) revert InsufficientBalance();
    }

    // ============ Core Vault Functions ============

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount < MIN_DEPOSIT) revert DepositTooSmall();
        if (strategies.length <= 0) revert NoStrategies();

        _updateReward(msg.sender);

        // Calculate shares before external transfer
        uint256 mintShares;
        if (totalShares <= 0) {
            mintShares = amount;
        } else {
            uint256 tvl = totalValueLocked();
            if (tvl <= 0) {
                mintShares = amount;
            } else {
                mintShares = (amount * totalShares) / tvl;
            }
        }
        if (mintShares <= 0) revert AmountZero();

        // Effects: update state before external call
        shares[msg.sender] += mintShares;
        totalShares += mintShares;

        // Interactions: transfer tokens in
        _safeTransferFrom(baseToken, msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, mintShares);

        _investIdle();
    }

    function withdraw(uint256 shareAmount) external whenNotPaused nonReentrant {
        if (shareAmount <= 0) revert AmountZero();
        if (shareAmount > shares[msg.sender]) revert InsufficientShares();

        _updateReward(msg.sender);

        uint256 tvl = totalValueLocked();
        uint256 amount = (shareAmount * tvl) / totalShares;
        if (amount <= 0) revert AmountZero();

        // Effects: update state before external calls
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        // Interactions: ensure sufficient idle, then transfer
        uint256 idle = baseToken.balanceOf(address(this));
        if (idle < amount) {
            _divestFromStrategies(amount - idle);
        }

        _safeTransfer(baseToken, msg.sender, amount);

        emit Withdraw(msg.sender, shareAmount, amount);
    }

    function claimRewards() external whenNotPaused nonReentrant {
        _updateReward(msg.sender);
        uint256 amount = rewards[msg.sender];
        if (amount <= 0) revert AmountZero();

        // Effects: update state before external call
        rewards[msg.sender] = 0;

        // Interactions
        _safeTransfer(rewardToken, msg.sender, amount);

        emit ClaimRewards(msg.sender, amount);
    }

    // ============ Harvest & Rebalance ============

    function harvest() external nonReentrant {
        uint256 gross = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                gross += strategies[i].strategy.harvest();
            }
        }
        if (gross <= 0) return;

        uint256 fee = (gross * performanceFee) / BPS_DENOMINATOR;
        uint256 net = gross - fee;

        // Effects: update reward state before external transfers
        if (totalShares > 0 && net > 0) {
            rewardPerShareStored += (net * REWARD_PRECISION) / totalShares;
        }

        // Interactions
        if (fee > 0) {
            _safeTransfer(rewardToken, owner, fee);
        }

        emit Harvested(gross, fee, net);
    }

    function rebalance() external nonReentrant {
        _investIdle();
    }

    function recoverToken(address token, uint256 amount) external onlyOwner nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        _safeTransfer(IERC20(token), msg.sender, amount);
    }
}
