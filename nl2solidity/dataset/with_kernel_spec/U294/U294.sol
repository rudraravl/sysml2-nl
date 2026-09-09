// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract StakingPool {
    // ---------- Custom errors ----------
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferFailed();
    error LockPeriodTooShort();
    error Unauthorized();
    error InvalidPenaltyBps();
    error NothingToClaim();
    error ReentrantCall();

    // ---------- Constants ----------
    uint256 public constant MIN_LOCK_PERIOD = 30 days;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_PENALTY_BPS = 5_000; // cap at 50%
    uint256 public constant ACC_REWARD_PRECISION = 1e18;

    // ---------- Structs ----------
    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
        uint256 startTime;
        uint256 lockPeriod;
    }

    // ---------- State ----------
    IERC20 public immutable stakingToken;

    address public owner;
    address public operator;

    uint256 public rewardRate;            // reward tokens per second per staked token (scaled by 1e18)
    uint256 public accRewardPerShare;     // accumulated reward per share (scaled by 1e18)
    uint256 public lastRewardTime;        // last time rewards were updated
    uint256 public totalStaked;           // total principal staked

    uint256 public earlyWithdrawalPenaltyBps; // penalty in basis points (default 1000 = 10%)

    mapping(address => Stake) public stakes;

    bool private _locked;

    // ---------- Events ----------
    event Deposited(address indexed user, uint256 amount, uint256 lockPeriod, uint256 startTime);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 penalty, uint256 payout);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event PenaltyUpdated(uint256 oldPenaltyBps, uint256 newPenaltyBps);
    event OperatorUpdated(address oldOperator, address newOperator);
    event OwnershipTransferred(address oldOwner, address newOwner);

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    // ---------- Constructor ----------
    constructor(address _stakingToken, address _operator, uint256 _rewardRate, uint256 _penaltyBps) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_penaltyBps > MAX_PENALTY_BPS) revert InvalidPenaltyBps();

        stakingToken = IERC20(_stakingToken);
        owner = msg.sender;
        operator = _operator;
        rewardRate = _rewardRate;
        earlyWithdrawalPenaltyBps = _penaltyBps;
        lastRewardTime = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit RewardRateUpdated(0, _rewardRate);
        emit PenaltyUpdated(0, _penaltyBps);
    }

    // ---------- Owner functions ----------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    // ---------- Operator functions ----------
    function setRewardRate(uint256 newRate) external onlyOperator {
        _updateRewards();
        emit RewardRateUpdated(rewardRate, newRate);
        rewardRate = newRate;
    }

    function setPenaltySchedule(uint256 newPenaltyBps) external onlyOperator {
        if (newPenaltyBps > MAX_PENALTY_BPS) revert InvalidPenaltyBps();
        emit PenaltyUpdated(earlyWithdrawalPenaltyBps, newPenaltyBps);
        earlyWithdrawalPenaltyBps = newPenaltyBps;
    }

    // ---------- Internal: reward accrual ----------
    function _updateRewards() internal {
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastRewardTime;
        if (elapsed > 0) {
            // Multiply before divide to avoid precision loss
            accRewardPerShare += (elapsed * rewardRate * ACC_REWARD_PRECISION) / totalStaked;
            lastRewardTime = block.timestamp;
        }
    }

    function _pendingReward(address user) internal view returns (uint256) {
        Stake storage s = stakes[user];
        if (s.amount == 0) return 0;

        uint256 currentAcc = accRewardPerShare;
        if (totalStaked > 0) {
            uint256 elapsed = block.timestamp - lastRewardTime;
            if (elapsed > 0) {
                // Multiply before divide to avoid precision loss
                currentAcc += (elapsed * rewardRate * ACC_REWARD_PRECISION) / totalStaked;
            }
        }
        uint256 accumulated = (s.amount * currentAcc) / ACC_REWARD_PRECISION;
        if (accumulated <= s.rewardDebt) return 0;
        return accumulated - s.rewardDebt;
    }

    // ---------- Public views ----------
    function pendingReward(address user) external view returns (uint256) {
        return _pendingReward(user);
    }

    function getStake(address user)
        external
        view
        returns (uint256 amount, uint256 startTime, uint256 lockPeriod, uint256 unlockTime)
    {
        Stake storage s = stakes[user];
        return (s.amount, s.startTime, s.lockPeriod, s.startTime + s.lockPeriod);
    }

    // ---------- User functions ----------
    function deposit(uint256 amount, uint256 lockPeriod) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (lockPeriod < MIN_LOCK_PERIOD) revert LockPeriodTooShort();

        _updateRewards();

        Stake storage s = stakes[msg.sender];

        // Calculate pending reward before state change
        uint256 pending = 0;
        if (s.amount > 0) {
            uint256 accumulated = (s.amount * accRewardPerShare) / ACC_REWARD_PRECISION;
            if (accumulated > s.rewardDebt) {
                pending = accumulated - s.rewardDebt;
            }
        }

        // Effects: update state before external calls
        s.amount += amount;
        s.startTime = block.timestamp;
        s.lockPeriod = lockPeriod;
        s.rewardDebt = (s.amount * accRewardPerShare) / ACC_REWARD_PRECISION;
        totalStaked += amount;

        // Interactions: pull tokens from depositor
        if (stakingToken.allowance(msg.sender, address(this)) < amount) revert InsufficientAllowance();
        bool ok = stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        // Pay pending rewards after state is committed
        if (pending > 0) {
            _payReward(msg.sender, pending);
        }

        emit Deposited(msg.sender, amount, lockPeriod, s.startTime);
    }

    function claimRewards() external nonReentrant {
        _updateRewards();

        Stake storage s = stakes[msg.sender];
        if (s.amount == 0) revert NothingToClaim();

        uint256 accumulated = (s.amount * accRewardPerShare) / ACC_REWARD_PRECISION;
        // Use > comparison instead of strict equality to avoid dangerous equality
        if (accumulated <= s.rewardDebt) revert NothingToClaim();
        uint256 pending = accumulated - s.rewardDebt;

        // Effects: update reward debt before external call
        s.rewardDebt = accumulated;

        // Interactions: pay reward
        _payReward(msg.sender, pending);
    }

    function withdraw(uint256 amount) external nonReentrant {
        Stake storage s = stakes[msg.sender];
        if (amount == 0) revert ZeroAmount();
        if (amount > s.amount) revert InsufficientBalance();

        _updateRewards();

        // Calculate pending rewards before state change
        uint256 pending = 0;
        if (s.amount > 0) {
            uint256 accumulated = (s.amount * accRewardPerShare) / ACC_REWARD_PRECISION;
            if (accumulated > s.rewardDebt) {
                pending = accumulated - s.rewardDebt;
            }
        }

        // Calculate penalty and payout
        bool early = block.timestamp < s.startTime + s.lockPeriod;
        uint256 penalty = 0;
        uint256 payout = amount;
        if (early) {
            penalty = (amount * earlyWithdrawalPenaltyBps) / BPS_DENOMINATOR;
            payout = amount - penalty;
        }

        // Effects: update state before external calls
        s.amount -= amount;
        s.rewardDebt = (s.amount * accRewardPerShare) / ACC_REWARD_PRECISION;
        totalStaked -= amount;

        // Interactions: send principal to user
        bool ok = stakingToken.transfer(msg.sender, payout);
        if (!ok) revert TransferFailed();

        // Send penalty to owner (treasury)
        if (penalty > 0) {
            bool ok2 = stakingToken.transfer(owner, penalty);
            if (!ok2) revert TransferFailed();
        }

        // Pay pending rewards
        if (pending > 0) {
            _payReward(msg.sender, pending);
        }

        emit WithdrawalRequested(msg.sender, amount, penalty, payout);
    }

    // ---------- Internal helpers ----------
    function _payReward(address user, uint256 amount) internal {
        // Rewards are paid in staking token for simplicity
        bool ok = stakingToken.transfer(user, amount);
        if (!ok) revert TransferFailed();
        emit RewardClaimed(user, amount);
    }

    // ---------- Rescue (owner only) ----------
    function rescue(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        // Prevent draining staked principal
        if (token == address(stakingToken)) {
            uint256 contractBal = stakingToken.balanceOf(address(this));
            uint256 available = contractBal > totalStaked ? contractBal - totalStaked : 0;
            if (amount > available) revert InsufficientBalance();
        }
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }
}
