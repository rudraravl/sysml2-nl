// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        require(
            returndata.length == 0 || abi.decode(returndata, (bool)),
            "SafeERC20: ERC20 operation did not succeed"
        );
    }
}

abstract contract ReentrancyGuard {
    bool private _inNonReentrant;

    modifier nonReentrant() {
        require(!_inNonReentrant, "ReentrancyGuard: reentrant call");
        _inNonReentrant = true;
        _;
        _inNonReentrant = false;
    }
}

contract GameStakingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ========== Constants ========== */

    uint256 public constant MIN_LOCK_PERIOD = 90 days;
    uint256 public constant PENALTY_BPS = 1000; // 10% of principal
    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 private constant REWARD_PRECISION = 1e18;

    /* ========== State Variables ========== */

    IERC20 public immutable token;

    address public operator;
    address public treasury;

    uint256 public rewardRate;
    uint256 public rewardsDuration;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 public totalSupply;
    uint256 public totalPenaltyCollected;

    struct Staker {
        uint256 balance;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
        uint256 lockEndTime;
    }

    mapping(address => Staker) private _stakers;

    /* ========== Events ========== */

    event Deposited(address indexed user, uint256 amount, uint256 newLockEndTime);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty, uint256 rewardPaid);
    event RewardClaimed(address indexed user, uint256 reward);
    event LockExtended(address indexed user, uint256 oldLockEndTime, uint256 newLockEndTime);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardsDistributed(uint256 amount, uint256 newRate, uint256 periodFinish);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    /* ========== Errors ========== */

    error ErrZeroAmount();
    error ErrNotOperator();
    error ErrZeroAddress();
    error ErrInvalidLockExtension();
    error ErrInsufficientBalance();
    error ErrInvalidRewardsDuration();
    error ErrRewardPeriodActive();
    error ErrNothingToClaim();

    /* ========== Modifiers ========== */

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            Staker storage s = _stakers[account];
            s.rewards = earned(account);
            s.rewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    /* ========== Constructor ========== */

    constructor(
        address token_,
        address operator_,
        address treasury_,
        uint256 rewardsDuration_
    ) {
        if (token_ == address(0)) revert ErrZeroAddress();
        if (operator_ == address(0)) revert ErrZeroAddress();
        if (treasury_ == address(0)) revert ErrZeroAddress();
        if (rewardsDuration_ == 0) revert ErrInvalidRewardsDuration();

        token = IERC20(token_);
        operator = operator_;
        treasury = treasury_;
        rewardsDuration = rewardsDuration_;
    }

    /* ========== User Functions ========== */

    function deposit(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ErrZeroAmount();

        Staker storage s = _stakers[msg.sender];

        uint256 newLockEndTime = block.timestamp + MIN_LOCK_PERIOD;
        if (newLockEndTime > s.lockEndTime) {
            s.lockEndTime = newLockEndTime;
        }

        s.balance += amount;
        totalSupply += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount, s.lockEndTime);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ErrZeroAmount();

        Staker storage s = _stakers[msg.sender];
        if (amount > s.balance) revert ErrInsufficientBalance();

        uint256 penalty = 0;
        if (block.timestamp < s.lockEndTime) {
            penalty = (amount * PENALTY_BPS) / BPS_DENOMINATOR;
        }

        uint256 reward = s.rewards;

        // Effects
        s.balance -= amount;
        totalSupply -= amount;
        s.rewards = 0;

        uint256 principalOut = amount - penalty;

        // Interactions
        if (penalty > 0) {
            totalPenaltyCollected += penalty;
            token.safeTransfer(treasury, penalty);
        }

        if (principalOut > 0) {
            token.safeTransfer(msg.sender, principalOut);
        }

        if (reward > 0) {
            token.safeTransfer(msg.sender, reward);
        }

        emit Withdrawn(msg.sender, principalOut, penalty, reward);
    }

    function claim() external nonReentrant updateReward(msg.sender) {
        Staker storage s = _stakers[msg.sender];
        uint256 reward = s.rewards;
        if (reward == 0) revert ErrNothingToClaim();

        // Effects
        s.rewards = 0;

        // Interactions
        token.safeTransfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function extendLock(uint256 additionalSeconds) external nonReentrant {
        if (additionalSeconds == 0) revert ErrInvalidLockExtension();

        Staker storage s = _stakers[msg.sender];
        if (s.balance == 0) revert ErrInsufficientBalance();

        uint256 oldLockEndTime = s.lockEndTime;
        uint256 base = block.timestamp > oldLockEndTime ? block.timestamp : oldLockEndTime;
        uint256 newLockEndTime = base + additionalSeconds;

        if (newLockEndTime <= oldLockEndTime) revert ErrInvalidLockExtension();

        s.lockEndTime = newLockEndTime;

        emit LockExtended(msg.sender, oldLockEndTime, newLockEndTime);
    }

    /* ========== Operator Functions ========== */

    function setRewardRate(uint256 newRate) external onlyOperator updateReward(address(0)) {
        if (block.timestamp < periodFinish) revert ErrRewardPeriodActive();

        uint256 oldRate = rewardRate;
        rewardRate = newRate;

        emit RewardRateUpdated(oldRate, newRate);
    }

    function distributeRewards(uint256 amount) external onlyOperator nonReentrant updateReward(address(0)) {
        if (amount == 0) revert ErrZeroAmount();

        // Effects: compute and store new rate/period before the external transfer
        if (block.timestamp >= periodFinish) {
            rewardRate = amount / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (amount + leftover) / rewardsDuration;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        // Interactions
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsDistributed(amount, rewardRate, periodFinish);
    }

    function setRewardsDuration(uint256 newDuration) external onlyOperator {
        if (newDuration == 0) revert ErrInvalidRewardsDuration();
        if (block.timestamp < periodFinish) revert ErrRewardPeriodActive();

        rewardsDuration = newDuration;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ErrZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ErrZeroAddress();
        address previous = treasury;
        treasury = newTreasury;
        emit TreasuryChanged(previous, newTreasury);
    }

    function recoverERC20(address tokenAddress, address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ErrZeroAddress();

        uint256 contractBalance = IERC20(tokenAddress).balanceOf(address(this));
        uint256 recoverable = contractBalance;

        if (tokenAddress == address(token)) {
            uint256 locked = totalSupply + pendingRewards();
            if (contractBalance <= locked) revert ErrInsufficientBalance();
            recoverable = contractBalance - locked;
        }

        if (amount > recoverable) revert ErrInsufficientBalance();

        IERC20(tokenAddress).safeTransfer(to, amount);
        emit Recovered(tokenAddress, to, amount);
    }

    /* ========== View Functions ========== */

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * REWARD_PRECISION) /
            totalSupply;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function earned(address account) public view returns (uint256) {
        Staker storage s = _stakers[account];
        return
            (s.balance * (rewardPerToken() - s.rewardPerTokenPaid)) /
            REWARD_PRECISION +
            s.rewards;
    }

    function pendingRewards() public view returns (uint256) {
        if (block.timestamp >= periodFinish) {
            return 0;
        }
        uint256 remaining = periodFinish - block.timestamp;
        return remaining * rewardRate;
    }

    function getStaker(
        address account
    )
        external
        view
        returns (
            uint256 balance,
            uint256 rewards,
            uint256 lockEndTime,
            uint256 rewardPerTokenPaid
        )
    {
        Staker storage s = _stakers[account];
        return (s.balance, earned(account), s.lockEndTime, s.rewardPerTokenPaid);
    }

    function stakerBalance(address account) external view returns (uint256) {
        return _stakers[account].balance;
    }

    function stakerLockEndTime(address account) external view returns (uint256) {
        return _stakers[account].lockEndTime;
    }

    function stakerRewards(address account) external view returns (uint256) {
        return earned(account);
    }
}
