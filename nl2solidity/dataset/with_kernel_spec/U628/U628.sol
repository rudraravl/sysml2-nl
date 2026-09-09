// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract SocialTokenManager {
    error NotAuthorized();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountMustBeGreaterThanZero();
    error RewardRateExceedsCap();
    error FeeExceedsCap();
    error NothingToClaim();
    error ReentrantCall();
    error StakeExceedsBalance();
    error TransferFailed();

    event Deposited(address indexed user, uint256 amount);
    event Transferred(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event FeeDeducted(address indexed from, uint256 fee);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event TransferFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TreasuryWithdrawn(address indexed by, uint256 amount);

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant MAX_REWARD_RATE_BPS = 10;    // 0.1% per day
    uint256 public constant MAX_TRANSFER_FEE_BPS = 1000; // 10% hard cap
    uint256 public constant DEFAULT_TRANSFER_FEE_BPS = 500; // 5%

    IERC20 public immutable token;

    address public owner;
    address public operator;

    uint256 public transferFeeBps;
    uint256 public rewardRateBps;

    uint256 public treasury;
    uint256 public totalStaked;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastRewardTime;
    mapping(address => uint256) public accumulatedReward;

    uint256 private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 0) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address _token, address _operator, uint256 _initialRewardRateBps) {
        if (_token == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_initialRewardRateBps > MAX_REWARD_RATE_BPS) revert RewardRateExceedsCap();

        token = IERC20(_token);
        owner = msg.sender;
        operator = _operator;
        transferFeeBps = DEFAULT_TRANSFER_FEE_BPS;
        rewardRateBps = _initialRewardRateBps;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit TransferFeeUpdated(0, transferFeeBps);
        emit RewardRateUpdated(0, rewardRateBps);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();

        uint256 allowance = token.allowance(msg.sender, address(this));
        if (allowance < amount) revert InsufficientAllowance();

        bool ok = token.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        balances[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    function transferTokens(address to, uint256 amount) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountMustBeGreaterThanZero();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * transferFeeBps) / BPS_DENOMINATOR;
        uint256 received = amount - fee;

        balances[msg.sender] -= amount;
        balances[to] += received;
        treasury += fee;

        emit FeeDeducted(msg.sender, fee);
        emit Transferred(msg.sender, to, received, fee);
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();
        if (balances[msg.sender] < amount) revert StakeExceedsBalance();

        _updateReward(msg.sender);

        balances[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();
        if (stakedBalance[msg.sender] < amount) revert InsufficientBalance();

        _updateReward(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        balances[msg.sender] += amount;

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = accumulatedReward[msg.sender];
        if (reward < 1) revert NothingToClaim();

        accumulatedReward[msg.sender] = 0;

        uint256 payout = reward;
        if (payout > treasury) {
            payout = treasury;
        }
        treasury -= payout;

        balances[msg.sender] += payout;
        emit RewardClaimed(msg.sender, payout);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;

        bool ok = token.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function setRewardRate(uint256 rateBps) external onlyOperator {
        if (rateBps > MAX_REWARD_RATE_BPS) revert RewardRateExceedsCap();
        uint256 old = rewardRateBps;
        rewardRateBps = rateBps;
        emit RewardRateUpdated(old, rateBps);
    }

    function setTransferFee(uint256 feeBps) external onlyOperator {
        if (feeBps > MAX_TRANSFER_FEE_BPS) revert FeeExceedsCap();
        uint256 old = transferFeeBps;
        transferFeeBps = feeBps;
        emit TransferFeeUpdated(old, feeBps);
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

    function withdrawTreasury(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();
        if (treasury < amount) revert InsufficientBalance();

        treasury -= amount;

        bool ok = token.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit TreasuryWithdrawn(msg.sender, amount);
    }

    function pendingRewards(address user) external view returns (uint256) {
        if (stakedBalance[user] == 0) return accumulatedReward[user];
        uint256 elapsed = block.timestamp - lastRewardTime[user];
        uint256 newReward = (stakedBalance[user] * rewardRateBps * elapsed) /
            (BPS_DENOMINATOR * SECONDS_PER_DAY);
        return accumulatedReward[user] + newReward;
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function totalPlatformBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _updateReward(address user) internal {
        if (stakedBalance[user] == 0) {
            lastRewardTime[user] = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastRewardTime[user];
        if (elapsed > 0) {
            uint256 newReward = (stakedBalance[user] * rewardRateBps * elapsed) /
                (BPS_DENOMINATOR * SECONDS_PER_DAY);
            if (newReward > 0) {
                accumulatedReward[user] += newReward;
            }
            lastRewardTime[user] = block.timestamp;
        }
    }
}
