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

contract StakingPool {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_RATE_BPS = 1000;       // 10% per day max reward rate
    uint256 public constant WITHDRAW_FEE_BPS = 50;     // 0.5% withdrawal fee
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant ACC_PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // Immutable / core state
    // ---------------------------------------------------------------------
    IERC20 public immutable stakingToken;

    address public owner;
    address public operator;
    address public treasury;

    uint256 public rateBps;            // reward rate in basis points per day
    uint256 public accRewardPerShare;  // accumulated reward per staked token, scaled by ACC_PRECISION
    uint256 public lastRewardTime;     // last time the accumulator was updated
    uint256 public totalStaked;        // total amount of tokens staked in the pool

    bool public paused;

    struct UserInfo {
        uint256 amount;       // staked tokens
        uint256 rewardDebt;   // snapshot used for incremental reward calc
        uint256 unclaimed;    // accumulated but not yet claimed rewards
    }

    mapping(address => UserInfo) public users;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event Claim(address indexed user, uint256 amount);
    event RateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event OperatorUpdated(address oldOperator, address newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error ZeroAddress();
    error ZeroAmount();
    error RateTooHigh();
    error InsufficientStake();
    error InsufficientBalance();
    error TransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        address _stakingToken,
        address _operator,
        address _treasury,
        uint256 _initialRateBps
    ) {
        if (_stakingToken == address(0) || _operator == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        if (_initialRateBps > MAX_RATE_BPS) revert RateTooHigh();

        stakingToken = IERC20(_stakingToken);
        owner = msg.sender;
        operator = _operator;
        treasury = _treasury;
        rateBps = _initialRateBps;
        lastRewardTime = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
        emit RateUpdated(0, _initialRateBps);
    }

    // ---------------------------------------------------------------------
    // Pool update / harvest internals
    // ---------------------------------------------------------------------
    function updatePool() public {
        if (block.timestamp <= lastRewardTime) return;
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 timeElapsed = block.timestamp - lastRewardTime;
        uint256 rewardPerShare = (timeElapsed * rateBps * ACC_PRECISION) /
            (BPS_DENOMINATOR * SECONDS_PER_DAY);
        accRewardPerShare += rewardPerShare;
        lastRewardTime = block.timestamp;
    }

    function _harvest(address userAddr) internal {
        UserInfo storage u = users[userAddr];
        uint256 acc = accRewardPerShare;
        if (u.amount > 0) {
            uint256 pending = (u.amount * acc) / ACC_PRECISION - u.rewardDebt;
            if (pending > 0) {
                u.unclaimed += pending;
            }
        }
        u.rewardDebt = (u.amount * acc) / ACC_PRECISION;
    }

    function _safeTransfer(address to, uint256 amount) internal {
        if (amount > 0) {
            uint256 bal = stakingToken.balanceOf(address(this));
            if (bal < amount) revert InsufficientBalance();
            if (!stakingToken.transfer(to, amount)) revert TransferFailed();
        }
    }

    // ---------------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------------
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Effects
        updatePool();
        UserInfo storage u = users[msg.sender];
        _harvest(msg.sender);
        u.amount += amount;
        u.rewardDebt = (u.amount * accRewardPerShare) / ACC_PRECISION;
        totalStaked += amount;

        // Interactions
        if (!stakingToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserInfo storage u = users[msg.sender];
        if (u.amount < amount) revert InsufficientStake();

        // Effects
        updatePool();
        _harvest(msg.sender);
        u.amount -= amount;
        u.rewardDebt = (u.amount * accRewardPerShare) / ACC_PRECISION;
        totalStaked -= amount;

        uint256 fee = (amount * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        uint256 toUser = amount - fee;

        // Interactions
        if (fee > 0) _safeTransfer(treasury, fee);
        if (toUser > 0) _safeTransfer(msg.sender, toUser);

        emit Withdraw(msg.sender, amount, fee);
    }

    function claim() external nonReentrant {
        // Effects
        updatePool();
        _harvest(msg.sender);
        uint256 toPay = users[msg.sender].unclaimed;
        users[msg.sender].unclaimed = 0;

        // Interactions
        _safeTransfer(msg.sender, toPay);

        emit Claim(msg.sender, toPay);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function pendingReward(address userAddr) external view returns (uint256) {
        UserInfo storage u = users[userAddr];
        uint256 acc = accRewardPerShare;
        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 rewardPerShare = (timeElapsed * rateBps * ACC_PRECISION) /
                (BPS_DENOMINATOR * SECONDS_PER_DAY);
            acc += rewardPerShare;
        }
        uint256 live = 0;
        if (u.amount > 0) {
            live = (u.amount * acc) / ACC_PRECISION - u.rewardDebt;
        }
        return u.unclaimed + live;
    }

    function rewardPoolSize() external view returns (uint256) {
        uint256 bal = stakingToken.balanceOf(address(this));
        if (bal <= totalStaked) return 0;
        return bal - totalStaked;
    }

    function userInfo(address userAddr) external view returns (
        uint256 amount,
        uint256 rewardDebt,
        uint256 unclaimed
    ) {
        UserInfo storage u = users[userAddr];
        return (u.amount, u.rewardDebt, u.unclaimed);
    }

    // ---------------------------------------------------------------------
    // Operator actions
    // ---------------------------------------------------------------------
    function setRate(uint256 newRateBps) external onlyOperator {
        if (newRateBps > MAX_RATE_BPS) revert RateTooHigh();
        updatePool();
        uint256 old = rateBps;
        rateBps = newRateBps;
        emit RateUpdated(old, newRateBps);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    // ---------------------------------------------------------------------
    // Owner actions
    // ---------------------------------------------------------------------
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}
