// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FitnessSavingsPool {
    IERC20 public immutable stablecoin;
    address public owner;
    address public operator;

    uint256 public constant MIN_DEPOSIT = 100 * 1e18;
    uint256 public constant METERS_PER_KM = 1000;
    uint256 public constant MIN_GOAL_KM = 5;

    uint256 public totalStaked;
    mapping(address => uint256) public userBalance;

    uint256 public weeklyGoalMeters;
    uint256 public currentWeek;

    // week => user => progress in meters
    mapping(uint256 => mapping(address => uint256)) public weeklyProgress;
    // week => user => registered completion
    mapping(uint256 => mapping(address => bool)) public registeredCompletion;
    // week => user => compliant
    mapping(uint256 => mapping(address => bool)) public compliant;
    // week => user => reward claimed
    mapping(uint256 => mapping(address => bool)) public rewardClaimed;

    mapping(address => uint256) public accruedRewards;
    uint256 public totalAccruedRewards;

    struct WeekDistribution {
        uint256 yieldAmount;
        uint256 compliantStake;
        bool distributed;
    }
    mapping(uint256 => WeekDistribution) public weekDistributions;

    address[] public participants;
    mapping(address => bool) public isParticipant;

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);
    event WeeklyYieldDistributed(uint256 indexed week, uint256 yieldAmount, uint256 compliantStake);
    event GoalUpdated(uint256 newGoalMeters);
    event ComplianceMarked(uint256 indexed week, address indexed user, bool compliant);
    event ProgressRegistered(uint256 indexed week, address indexed user, uint256 progressMeters);
    event RewardClaimed(address indexed user, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotOperator();
    error InsufficientDeposit();
    error InsufficientBalance();
    error ZeroAddress();
    error GoalTooLow();
    error AlreadyDistributed();
    error AlreadyRegistered();
    error NotCompliant();
    error NoYieldToDistribute();
    error TransferFailed();
    error NothingToClaim();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        weeklyGoalMeters = MIN_GOAL_KM * METERS_PER_KM;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit GoalUpdated(weeklyGoalMeters);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setWeeklyGoal(uint256 _goalMeters) external onlyOperator {
        if (_goalMeters < MIN_GOAL_KM * METERS_PER_KM) revert GoalTooLow();
        weeklyGoalMeters = _goalMeters;
        emit GoalUpdated(_goalMeters);
    }

    function deposit(uint256 amount) external {
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();
        if (!stablecoin.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        if (!isParticipant[msg.sender]) {
            isParticipant[msg.sender] = true;
            participants.push(msg.sender);
        }

        userBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Deposited(msg.sender, amount, userBalance[msg.sender]);
    }

    function withdraw(uint256 amount) external {
        if (amount > userBalance[msg.sender]) revert InsufficientBalance();

        userBalance[msg.sender] -= amount;
        totalStaked -= amount;

        if (!stablecoin.transfer(msg.sender, amount)) revert TransferFailed();

        emit Withdrawn(msg.sender, amount, userBalance[msg.sender]);
    }

    function registerWeeklyCompletion(uint256 progressMeters) external {
        if (userBalance[msg.sender] == 0) revert InsufficientBalance();
        if (registeredCompletion[currentWeek][msg.sender]) revert AlreadyRegistered();

        registeredCompletion[currentWeek][msg.sender] = true;
        weeklyProgress[currentWeek][msg.sender] = progressMeters;

        if (progressMeters >= weeklyGoalMeters) {
            compliant[currentWeek][msg.sender] = true;
        }

        emit ProgressRegistered(currentWeek, msg.sender, progressMeters);
    }

    function markNonCompliant(address user) external onlyOperator {
        compliant[currentWeek][user] = false;
        emit ComplianceMarked(currentWeek, user, false);
    }

    function markCompliant(address user) external onlyOperator {
        compliant[currentWeek][user] = true;
        emit ComplianceMarked(currentWeek, user, true);
    }

    function distributeWeeklyYield(uint256 yieldAmount) external onlyOperator {
        WeekDistribution storage wd = weekDistributions[currentWeek];
        if (wd.distributed) revert AlreadyDistributed();
        if (yieldAmount == 0) revert NoYieldToDistribute();

        uint256 contractBalance = stablecoin.balanceOf(address(this));
        uint256 available = contractBalance - totalStaked - totalAccruedRewards;
        if (yieldAmount > available) revert NoYieldToDistribute();

        uint256 compliantStake = 0;
        uint256 len = participants.length;
        for (uint256 i = 0; i < len; i++) {
            address u = participants[i];
            if (compliant[currentWeek][u] && userBalance[u] > 0) {
                compliantStake += userBalance[u];
            }
        }
        if (compliantStake == 0) revert NoYieldToDistribute();

        wd.yieldAmount = yieldAmount;
        wd.compliantStake = compliantStake;
        wd.distributed = true;

        for (uint256 i = 0; i < len; i++) {
            address u = participants[i];
            if (compliant[currentWeek][u] && userBalance[u] > 0) {
                uint256 share = (yieldAmount * userBalance[u]) / compliantStake;
                if (share > 0) {
                    accruedRewards[u] += share;
                    totalAccruedRewards += share;
                }
            }
        }

        emit WeeklyYieldDistributed(currentWeek, yieldAmount, compliantStake);

        currentWeek += 1;
    }

    function claimReward() external {
        uint256 amount = accruedRewards[msg.sender];
        if (amount == 0) revert NothingToClaim();

        accruedRewards[msg.sender] = 0;
        totalAccruedRewards -= amount;

        if (!stablecoin.transfer(msg.sender, amount)) revert TransferFailed();

        emit RewardClaimed(msg.sender, amount);
    }

    function participantCount() external view returns (uint256) {
        return participants.length;
    }

    function isCompliant(uint256 week, address user) external view returns (bool) {
        return compliant[week][user];
    }

    function getWeekDistribution(uint256 week) external view returns (uint256 yieldAmount, uint256 compliantStake, bool distributed) {
        WeekDistribution storage wd = weekDistributions[week];
        return (wd.yieldAmount, wd.compliantStake, wd.distributed);
    }
}
