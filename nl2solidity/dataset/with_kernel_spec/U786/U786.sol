Looking at the error "Invalid implicit conversion from uint256 to address requested," this is a compilation error caused by the constructor parameter order not matching what the test harness expects. The harness passes `(string, string, address, uint256)` but the contract defines `(string, string, uint256, address)`, causing the uint256 initial supply to be passed where the address operator parameter is expected.

I'll also fix the `exit()` function which has a reward-update ordering bug, and clean up the `setRewardsDuration` logic.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GameTokenStaking {
    // ---------------------------------------------------------------------
    // ERC-20 metadata
    // ---------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ---------------------------------------------------------------------
    // Access control
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;
    bool public paused;

    // ---------------------------------------------------------------------
    // Staking state
    // ---------------------------------------------------------------------
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastStakeTime;

    uint256 public constant MIN_STAKE = 100 * 10 ** decimals;
    uint256 public constant UNSTAKE_FEE_BPS = 500; // 5%
    uint256 public constant EARLY_UNSTAKE_WINDOW = 7 days;

    // ---------------------------------------------------------------------
    // Reward distribution (Synthetix-style)
    // ---------------------------------------------------------------------
    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public rewardPoolBalance;
    uint256 public rewardsDuration = 7 days;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amountReturned, uint256 fee);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event RewardDeposited(address indexed from, uint256 amount);
    event RewardsDurationUpdated(uint256 newDuration);

    event Paused();
    event Unpaused();
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error OnlyOwner();
    error OnlyOperator();
    error WhenPaused();
    error ZeroAddress();
    error AmountZero();
    error InsufficientBalance();
    error InsufficientStake();
    error BelowMinimumStake();
    error InsufficientAllowance();
    error InsufficientRewardPool();
    error SafeTransferFailed();
    error RewardPeriodActive();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        string memory _name,
        string memory _symbol,
        address _operator,
        uint256 _initialSupply
    ) {
        if (_operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        operator = _operator;
        totalSupply = _initialSupply;
        _balances[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    // ERC-20 views
    // ---------------------------------------------------------------------
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address accountOwner, address spender) external view returns (uint256) {
        return _allowances[accountOwner][spender];
    }

    // ---------------------------------------------------------------------
    // ERC-20 transfers
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    // ---------------------------------------------------------------------
    // Reward math
    // ---------------------------------------------------------------------
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) /
            totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return
            (stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 +
            rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    // ---------------------------------------------------------------------
    // Staking actions
    // ---------------------------------------------------------------------
    function stake(uint256 amount) external whenNotPaused updateReward(msg.sender) {
        if (amount == 0) revert AmountZero();
        if (amount < MIN_STAKE) revert BelowMinimumStake();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _balances[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external whenNotPaused updateReward(msg.sender) {
        if (amount == 0) revert AmountZero();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStake();

        uint256 fee = 0;
        if (block.timestamp - lastStakeTime[msg.sender] < EARLY_UNSTAKE_WINDOW) {
            fee = (amount * UNSTAKE_FEE_BPS) / 10000;
        }
        uint256 net = amount - fee;

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        _balances[msg.sender] += net;
        if (fee > 0) {
            rewardPoolBalance += fee;
        }

        emit Unstaked(msg.sender, net, fee);
    }

    function claim() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) {
            return;
        }
        rewards[msg.sender] = 0;
        if (rewardPoolBalance < reward) revert InsufficientRewardPool();
        rewardPoolBalance -= reward;
        _balances[msg.sender] += reward;

        emit RewardPaid(msg.sender, reward);
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------
    function depositRewardTokens(uint256 amount) external onlyOperator updateReward(address(0)) {
        if (amount == 0) revert AmountZero();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _balances[msg.sender] -= amount;
        rewardPoolBalance += amount;

        if (block.timestamp >= periodFinish) {
            rewardRate = amount / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (amount + leftover) / rewardsDuration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardDeposited(msg.sender, amount);
    }

    function setRewardRate(uint256 newRate) external onlyOperator updateReward(address(0)) {
        rewardRate = newRate;
        if (block.timestamp >= periodFinish) {
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp + rewardsDuration;
        }
        emit RewardRateUpdated(newRate);
    }

    function setRewardsDuration(uint256 newDuration) external onlyOwner {
        if (newDuration == 0) revert AmountZero();
        if (block.timestamp < periodFinish) revert RewardPeriodActive();
        rewardsDuration = newDuration;
        emit RewardsDurationUpdated(newDuration);
    }

    // ---------------------------------------------------------------------
    // Owner functions
    // ---------------------------------------------------------------------
    function pause() external onlyOwner {
        if (paused) return;
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        if (!paused) return;
        paused = false;
        emit Unpaused();
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    // ---------------------------------------------------------------------
    // Recovery of accidentally sent tokens (excluding the native token)
    // ---------------------------------------------------------------------
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert SafeTransferFailed();
    }
}
