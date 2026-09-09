// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract YieldBTCVault {
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error BelowMinimumDeposit();
    error InsufficientBalance();
    error UnbondingNotMature();
    error InvalidIndex();
    error NothingToClaim();
    error InvalidAmount();
    error SameDelegate();
    error TransferFailed();

    event Deposit(address indexed user, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 unlockTime, uint256 index);
    event WithdrawalCompleted(address indexed user, uint256 principal, uint256 rewards);
    event RewardPaid(address indexed user, uint256 amount);
    event RewardDistributed(uint256 rewardIndex, uint256 timestamp);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct UnbondRequest {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }

    uint256 public constant MIN_DEPOSIT = 0.001 * 1e8; // 0.001 BTC (8 decimals)
    uint256 public constant UNBONDING_PERIOD = 7 days;

    IERC20 public immutable btcToken;

    address public owner;
    address public operator;

    uint256 public totalDeposits;
    uint256 public totalRewardsDistributed;

    uint256 public rewardRate;
    uint256 public rewardIndex;
    uint256 public lastRewardTime;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardDebt;
    mapping(address => uint256) public accumulatedRewards;

    mapping(address => UnbondRequest[]) public unbondRequests;
    mapping(address => uint256) public pendingUnbonding;

    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedVotes;

    bool private locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        require(!locked, "reentrant");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _btcToken, address _operator, uint256 _initialRewardRate) {
        if (_btcToken == address(0) || _operator == address(0)) revert ZeroAddress();
        btcToken = IERC20(_btcToken);
        owner = msg.sender;
        operator = _operator;
        rewardRate = _initialRewardRate;
        lastRewardTime = block.timestamp;
        emit OperatorUpdated(address(0), _operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setRewardRate(uint256 _rate) external onlyOperator {
        _updateGlobal();
        emit RewardRateUpdated(rewardRate, _rate);
        rewardRate = _rate;
    }

    function distributeRewards() external onlyOperator {
        _updateGlobal();
        emit RewardDistributed(rewardIndex, block.timestamp);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit();

        _updateUser(msg.sender);

        balances[msg.sender] += amount;
        totalDeposits += amount;
        userRewardDebt[msg.sender] = balances[msg.sender] * rewardIndex;

        _safeTransferFrom(msg.sender, address(this), amount);

        address delegatee = delegates[msg.sender];
        if (delegatee != address(0)) {
            delegatedVotes[delegatee] += amount;
        }

        emit Deposit(msg.sender, amount);
    }

    function requestWithdrawal(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        _updateUser(msg.sender);

        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        pendingUnbonding[msg.sender] += amount;
        userRewardDebt[msg.sender] = balances[msg.sender] * rewardIndex;

        uint256 unlockTime = block.timestamp + UNBONDING_PERIOD;
        unbondRequests[msg.sender].push(UnbondRequest({
            amount: amount,
            unlockTime: unlockTime,
            claimed: false
        }));

        emit WithdrawalRequested(msg.sender, amount, unlockTime, unbondRequests[msg.sender].length - 1);
    }

    function completeWithdrawal(uint256 index) external nonReentrant {
        if (index >= unbondRequests[msg.sender].length) revert InvalidIndex();
        UnbondRequest storage req = unbondRequests[msg.sender][index];
        if (req.claimed) revert InvalidIndex();
        if (block.timestamp < req.unlockTime) revert UnbondingNotMature();

        req.claimed = true;
        uint256 principal = req.amount;
        pendingUnbonding[msg.sender] -= principal;

        address delegatee = delegates[msg.sender];
        if (delegatee != address(0)) {
            delegatedVotes[delegatee] -= principal;
        }

        _updateUser(msg.sender);
        uint256 rewards = accumulatedRewards[msg.sender];
        accumulatedRewards[msg.sender] = 0;

        uint256 totalOut = principal + rewards;
        _safeTransfer(msg.sender, totalOut);

        if (rewards > 0) {
            emit RewardPaid(msg.sender, rewards);
        }
        emit WithdrawalCompleted(msg.sender, principal, rewards);
    }

    function claimRewards() external nonReentrant {
        _updateUser(msg.sender);
        uint256 rewards = accumulatedRewards[msg.sender];
        if (rewards < 1) revert NothingToClaim();
        accumulatedRewards[msg.sender] = 0;
        _safeTransfer(msg.sender, rewards);
        emit RewardPaid(msg.sender, rewards);
    }

    function delegate(address to) external {
        address current = delegates[msg.sender];
        if (to == current) revert SameDelegate();

        uint256 votingPower = balances[msg.sender] + pendingUnbonding[msg.sender];
        if (current != address(0)) {
            delegatedVotes[current] -= votingPower;
        }
        delegates[msg.sender] = to;
        if (to != address(0)) {
            delegatedVotes[to] += votingPower;
        }

        emit DelegateChanged(msg.sender, current, to);
    }

    function getVotes(address account) external view returns (uint256) {
        uint256 own = balances[account] + pendingUnbonding[account];
        if (delegates[account] != address(0)) {
            own = 0;
        }
        return own + delegatedVotes[account];
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 globalIndex = rewardIndex;
        if (totalDeposits > 0 && block.timestamp > lastRewardTime) {
            uint256 elapsed = block.timestamp - lastRewardTime;
            globalIndex += (elapsed * rewardRate) / totalDeposits;
        }
        uint256 owed = balances[user] * globalIndex - userRewardDebt[user];
        return accumulatedRewards[user] + owed;
    }

    function unbondRequestCount(address user) external view returns (uint256) {
        return unbondRequests[user].length;
    }

    function unbondRequestAt(address user, uint256 index) external view returns (uint256 amount, uint256 unlockTime, bool claimed) {
        if (index >= unbondRequests[user].length) revert InvalidIndex();
        UnbondRequest storage req = unbondRequests[user][index];
        return (req.amount, req.unlockTime, req.claimed);
    }

    function _updateGlobal() internal {
        if (block.timestamp <= lastRewardTime) {
            return;
        }
        if (totalDeposits == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastRewardTime;
        uint256 newRewards = elapsed * rewardRate;
        rewardIndex += newRewards / totalDeposits;
        totalRewardsDistributed += newRewards;
        lastRewardTime = block.timestamp;
    }

    function _updateUser(address user) internal {
        _updateGlobal();
        uint256 owed = balances[user] * rewardIndex - userRewardDebt[user];
        if (owed > 0) {
            accumulatedRewards[user] += owed;
        }
        userRewardDebt[user] = balances[user] * rewardIndex;
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(btcToken).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length > 0) {
            if (!abi.decode(data, (bool))) revert TransferFailed();
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(btcToken).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length > 0) {
            if (!abi.decode(data, (bool))) revert TransferFailed();
        }
    }
}
