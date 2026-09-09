// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract DEXTreasury {
    // ---------------------------------------------------------------------
    // Access control
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MIN_DEPOSIT = 100;           // minimum reserve deposit (smallest unit)
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;     // 0.5% withdrawal fee
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant RATE_PRECISION = 1e18;       // scaling for exchange rates

    // ---------------------------------------------------------------------
    // Native token (internal ERC20 ledger)
    // ---------------------------------------------------------------------
    string public constant NAME = "DEX Treasury Native";
    string public constant SYMBOL = "DXT";
    uint8 public constant DECIMALS = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------
    // Reserves & exchange rates
    // ---------------------------------------------------------------------
    address[] public reserveList;
    mapping(address => bool) public isSupportedReserve;
    mapping(address => uint256) public exchangeRate; // native tokens per 1 reserve unit (scaled by RATE_PRECISION)

    // ---------------------------------------------------------------------
    // Staking
    // ---------------------------------------------------------------------
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;

    // ---------------------------------------------------------------------
    // Reward parameters (synthetix-style)
    // ---------------------------------------------------------------------
    address public rewardToken;
    uint256 public rewardRate;          // reward tokens per second
    uint256 public periodFinish;        // timestamp when current reward period ends
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public rewardDuration;      // length of a reward period in seconds

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public userRewards;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, address indexed reserve, uint256 reserveAmount, uint256 nativeMinted);
    event Withdraw(address indexed user, address indexed reserve, uint256 nativeBurned, uint256 reserveOut, uint256 fee);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event ExchangeRateUpdated(address indexed reserve, uint256 newRate);
    event ReserveAdded(address indexed reserve);
    event RewardParamsUpdated(uint256 rewardRate, uint256 duration);
    event RewardDurationUpdated(uint256 duration);
    event RewardNotified(uint256 amount, uint256 rewardRate);
    event RewardTokenUpdated(address indexed token);
    event OperatorUpdated(address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RecoveredToken(address indexed token, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error ReserveNotSupported();
    error AmountTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientStake();
    error ZeroAddress();
    error InvalidRate();
    error InvalidAmount();
    error TransferFailed();
    error RewardPeriodActive();
    error RewardTokenNotSet();
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

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            userRewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, address _rewardToken) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        rewardToken = _rewardToken;
        _reentrancyStatus = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(_operator);
        if (_rewardToken != address(0)) {
            emit RewardTokenUpdated(_rewardToken);
        }
    }

    // ---------------------------------------------------------------------
    // Owner administration
    // ---------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function addReserve(address reserve, uint256 rate) external onlyOwner {
        if (reserve == address(0)) revert ZeroAddress();
        if (rate == 0) revert InvalidRate();
        if (!isSupportedReserve[reserve]) {
            isSupportedReserve[reserve] = true;
            reserveList.push(reserve);
            emit ReserveAdded(reserve);
        }
        exchangeRate[reserve] = rate;
        emit ExchangeRateUpdated(reserve, rate);
    }

    function recoverToken(address token, uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        if (!IERC20(token).transfer(owner, amount)) revert TransferFailed();
        emit RecoveredToken(token, owner, amount);
    }

    // ---------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------
    function setExchangeRate(address reserve, uint256 rate) external onlyOperator {
        if (!isSupportedReserve[reserve]) revert ReserveNotSupported();
        if (rate == 0) revert InvalidRate();
        exchangeRate[reserve] = rate;
        emit ExchangeRateUpdated(reserve, rate);
    }

    function setRewardToken(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        rewardToken = token;
        emit RewardTokenUpdated(token);
    }

    function setRewardDuration(uint256 _duration) external onlyOperator {
        if (block.timestamp < periodFinish) revert RewardPeriodActive();
        if (_duration == 0) revert InvalidAmount();
        rewardDuration = _duration;
        emit RewardDurationUpdated(_duration);
    }

    function notifyRewardAmount(uint256 amount) external onlyOperator updateReward(address(0)) nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (rewardToken == address(0)) revert RewardTokenNotSet();
        if (rewardDuration == 0) revert InvalidAmount();

        // Effects: update reward state before the external transferFrom call.
        if (block.timestamp >= periodFinish) {
            rewardRate = amount / rewardDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (amount + leftover) / rewardDuration;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardDuration;

        // Interaction: pull reward tokens from the operator.
        if (!IERC20(rewardToken).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit RewardNotified(amount, rewardRate);
        emit RewardParamsUpdated(rewardRate, rewardDuration);
    }

    // ---------------------------------------------------------------------
    // Staking math
    // ---------------------------------------------------------------------
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime) * RATE_PRECISION) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / RATE_PRECISION
            + userRewards[account];
    }

    // ---------------------------------------------------------------------
    // User actions: deposit reserve to mint native
    // ---------------------------------------------------------------------
    function deposit(address reserve, uint256 amount) external nonReentrant {
        if (!isSupportedReserve[reserve]) revert ReserveNotSupported();
        if (amount < MIN_DEPOSIT) revert AmountTooSmall();

        uint256 nativeToMint = (amount * exchangeRate[reserve]) / RATE_PRECISION;
        if (nativeToMint == 0) revert InvalidAmount();

        if (!IERC20(reserve).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        _mint(msg.sender, nativeToMint);

        emit Deposit(msg.sender, reserve, amount, nativeToMint);
    }

    // ---------------------------------------------------------------------
    // User actions: withdraw reserve by burning native (0.5% fee)
    // ---------------------------------------------------------------------
    function withdraw(address reserve, uint256 nativeAmount) external nonReentrant {
        if (!isSupportedReserve[reserve]) revert ReserveNotSupported();
        if (nativeAmount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < nativeAmount) revert InsufficientBalance();

        uint256 rate = exchangeRate[reserve];
        // Compute gross reserve amount and fee independently at full precision to
        // avoid divide-before-multiply rounding loss.
        uint256 reserveAmount = (nativeAmount * RATE_PRECISION) / rate;
        uint256 fee = (nativeAmount * RATE_PRECISION * WITHDRAWAL_FEE_BPS) / (rate * BPS_DENOMINATOR);
        uint256 reserveOut = reserveAmount - fee;

        _burn(msg.sender, nativeAmount);

        if (reserveOut > 0) {
            if (!IERC20(reserve).transfer(msg.sender, reserveOut)) revert TransferFailed();
        }
        if (fee > 0) {
            if (!IERC20(reserve).transfer(owner, fee)) revert TransferFailed();
        }

        emit Withdraw(msg.sender, reserve, nativeAmount, reserveOut, fee);
    }

    // ---------------------------------------------------------------------
    // User actions: staking
    // ---------------------------------------------------------------------
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert InvalidAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStake();

        stakedBalance[msg.sender] -= amount;
        balanceOf[msg.sender] += amount;
        totalStaked -= amount;

        emit Unstaked(msg.sender, amount);
    }

    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = userRewards[msg.sender];
        userRewards[msg.sender] = 0;
        if (reward > 0) {
            if (rewardToken == address(0)) revert RewardTokenNotSet();
            if (!IERC20(rewardToken).transfer(msg.sender, reward)) revert TransferFailed();
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external nonReentrant updateReward(msg.sender) {
        uint256 staked = stakedBalance[msg.sender];
        if (staked > 0) {
            stakedBalance[msg.sender] = 0;
            balanceOf[msg.sender] += staked;
            totalStaked -= staked;
            emit Unstaked(msg.sender, staked);
        }
        uint256 reward = userRewards[msg.sender];
        if (reward > 0) {
            userRewards[msg.sender] = 0;
            if (rewardToken == address(0)) revert RewardTokenNotSet();
            if (!IERC20(rewardToken).transfer(msg.sender, reward)) revert TransferFailed();
            emit RewardPaid(msg.sender, reward);
        }
    }

    // ---------------------------------------------------------------------
    // Native token ERC20 interface
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        allowance[from][msg.sender] = currentAllowance - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // ---------------------------------------------------------------------
    // Internal mint / burn
    // ---------------------------------------------------------------------
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function getReserveCount() external view returns (uint256) {
        return reserveList.length;
    }

    function getReserves() external view returns (address[] memory) {
        return reserveList;
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardDuration;
    }
}
