// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IStrategy {
    function withdraw(uint256 amount) external returns (uint256);
}

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract DAOTreasury is ReentrancyGuard {
    // ========== Custom Errors ==========
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error TreasuryPaused();
    error TreasuryNotPaused();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error StrategyAlreadyPending();
    error StrategyNotPending();
    error StrategyHasAllocation();
    error ApprovalDelayNotElapsed();
    error ExceedsMaxAllocation();
    error ExceedsRiskLimit();
    error InsufficientBalance();
    error TransferFailed();
    error EtherTransferFailed();

    // ========== Events ==========
    event Deposited(address indexed from, uint256 amount, uint256 newTotalTreasuryBalance);
    event Withdrawn(address indexed to, uint256 amount, uint256 newTotalTreasuryBalance);
    event StrategyApprovalQueued(address indexed strategy, uint64 activationTime);
    event StrategyApproved(address indexed strategy);
    event StrategyRevoked(address indexed strategy);
    event StrategyFundsAllocated(address indexed strategy, uint256 amount, uint256 newAllocation);
    event StrategyFundsRedeemed(address indexed strategy, uint256 amount, uint256 newAllocation);
    event RiskLimitUpdated(address indexed strategy, uint256 newRiskLimit);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event EtherRescued(address indexed to, uint256 amount);

    // ========== Constants ==========
    uint256 public constant MAX_STRATEGY_ALLOCATION_PERCENT = 30;
    uint256 public constant APPROVAL_DELAY = 24 hours;
    uint256 private constant UNLIMITED = type(uint256).max;

    // ========== State ==========
    IERC20 public immutable stablecoin;
    address public operator;
    bool public paused;

    uint256 public totalTreasuryBalance;
    uint256 public totalAllocated;

    struct StrategyInfo {
        bool approved;
        bool pending;
        uint64 activationTime;
        uint256 riskLimit;
        uint256 allocatedAmount;
    }

    mapping(address => StrategyInfo) public strategies;
    address[] public approvedStrategies;

    // ========== Modifiers ==========
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TreasuryPaused();
        _;
    }

    // ========== Constructor ==========
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        emit OperatorUpdated(address(0), _operator);
    }

    // ========== Operator Management ==========
    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    // ========== Pause / Unpause ==========
    function pause() external onlyOperator {
        if (paused) revert TreasuryPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert TreasuryNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ========== Treasury Operations ==========
    function deposit(uint256 _amount) external nonReentrant whenNotPaused {
        if (_amount == 0) revert ZeroAmount();
        // Use msg.sender explicitly to avoid arbitrary-from transferFrom
        if (!stablecoin.transferFrom(msg.sender, address(this), _amount)) revert TransferFailed();
        totalTreasuryBalance += _amount;
        emit Deposited(msg.sender, _amount, totalTreasuryBalance);
    }

    function withdraw(address _to, uint256 _amount) external onlyOperator nonReentrant whenNotPaused {
        if (_to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        if (_amount > _directBalance()) revert InsufficientBalance();
        totalTreasuryBalance -= _amount;
        if (!stablecoin.transfer(_to, _amount)) revert TransferFailed();
        emit Withdrawn(_to, _amount, totalTreasuryBalance);
    }

    // ========== Strategy Approval Flow ==========
    function queueStrategyApproval(address _strategy) external onlyOperator whenNotPaused {
        if (_strategy == address(0)) revert ZeroAddress();
        StrategyInfo storage info = strategies[_strategy];
        if (info.approved) revert StrategyAlreadyApproved();
        if (info.pending) revert StrategyAlreadyPending();
        info.pending = true;
        info.activationTime = uint64(block.timestamp + APPROVAL_DELAY);
        emit StrategyApprovalQueued(_strategy, info.activationTime);
    }

    function activateStrategy(address _strategy) external onlyOperator whenNotPaused {
        if (_strategy == address(0)) revert ZeroAddress();
        StrategyInfo storage info = strategies[_strategy];
        if (!info.pending) revert StrategyNotPending();
        if (block.timestamp < info.activationTime) revert ApprovalDelayNotElapsed();
        info.pending = false;
        info.approved = true;
        info.riskLimit = UNLIMITED;
        approvedStrategies.push(_strategy);
        emit StrategyApproved(_strategy);
    }

    function revokeStrategy(address _strategy) external onlyOperator whenNotPaused {
        if (_strategy == address(0)) revert ZeroAddress();
        StrategyInfo storage info = strategies[_strategy];
        if (!info.approved && !info.pending) revert StrategyNotApproved();
        if (info.allocatedAmount > 0) revert StrategyHasAllocation();
        info.approved = false;
        info.pending = false;
        info.activationTime = 0;
        info.riskLimit = 0;
        _removeFromList(_strategy);
        emit StrategyRevoked(_strategy);
    }

    // ========== Risk Limit ==========
    function setRiskLimit(address _strategy, uint256 _riskLimit) external onlyOperator whenNotPaused {
        if (_strategy == address(0)) revert ZeroAddress();
        StrategyInfo storage info = strategies[_strategy];
        if (!info.approved) revert StrategyNotApproved();
        info.riskLimit = _riskLimit;
        emit RiskLimitUpdated(_strategy, _riskLimit);
    }

    // ========== Strategy Allocations ==========
    function allocateToStrategy(address _strategy, uint256 _amount) external onlyOperator nonReentrant whenNotPaused {
        if (_amount == 0) revert ZeroAmount();
        StrategyInfo storage info = strategies[_strategy];
        if (!info.approved) revert StrategyNotApproved();
        uint256 newAllocation = info.allocatedAmount + _amount;
        uint256 maxAlloc = _maxAllocation();
        if (newAllocation > maxAlloc) revert ExceedsMaxAllocation();
        if (newAllocation > info.riskLimit) revert ExceedsRiskLimit();
        if (_amount > _directBalance()) revert InsufficientBalance();
        info.allocatedAmount = newAllocation;
        totalAllocated += _amount;
        if (!stablecoin.transfer(_strategy, _amount)) revert TransferFailed();
        emit StrategyFundsAllocated(_strategy, _amount, newAllocation);
    }

    function redeemFromStrategy(address _strategy, uint256 _amount) external onlyOperator nonReentrant whenNotPaused {
        if (_amount == 0) revert ZeroAmount();
        StrategyInfo storage info = strategies[_strategy];
        if (!info.approved) revert StrategyNotApproved();
        if (_amount > info.allocatedAmount) revert InsufficientBalance();

        info.allocatedAmount -= _amount;
        totalAllocated -= _amount;

        uint256 returned = IStrategy(_strategy).withdraw(_amount);
        if (returned == 0) returned = _amount;

        totalTreasuryBalance = totalTreasuryBalance - _amount + returned;

        emit StrategyFundsRedeemed(_strategy, _amount, info.allocatedAmount);
    }

    // ========== Ether Rescue ==========
    function rescueEther(address _to) external onlyOperator {
        if (_to == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (balance == 0) revert ZeroAmount();
        (bool success, ) = _to.call{value: balance}("");
        if (!success) revert EtherTransferFailed();
        emit EtherRescued(_to, balance);
    }

    // ========== Internal ==========
    function _directBalance() internal view returns (uint256) {
        return totalTreasuryBalance - totalAllocated;
    }

    function _maxAllocation() internal view returns (uint256) {
        return (totalTreasuryBalance * MAX_STRATEGY_ALLOCATION_PERCENT) / 100;
    }

    function _removeFromList(address _strategy) internal {
        uint256 len = approvedStrategies.length;
        for (uint256 i = 0; i < len; i++) {
            if (approvedStrategies[i] == _strategy) {
                approvedStrategies[i] = approvedStrategies[len - 1];
                approvedStrategies.pop();
                break;
            }
        }
    }

    // ========== Views ==========
    function directBalance() external view returns (uint256) {
        return _directBalance();
    }

    function strategyAllocatedAmount(address _strategy) external view returns (uint256) {
        return strategies[_strategy].allocatedAmount;
    }

    function isStrategyApproved(address _strategy) external view returns (bool) {
        return strategies[_strategy].approved;
    }

    function isStrategyPending(address _strategy) external view returns (bool) {
        return strategies[_strategy].pending;
    }

    function strategyRiskLimit(address _strategy) external view returns (uint256) {
        return strategies[_strategy].riskLimit;
    }

    function strategyCount() external view returns (uint256) {
        return approvedStrategies.length;
    }

    function maxAllocationForStrategy(address _strategy) external view returns (uint256) {
        if (!strategies[_strategy].approved) return 0;
        return _maxAllocation();
    }

    receive() external payable {}
}
