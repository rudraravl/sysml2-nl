// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract YieldFarm {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 unclaimed;
    }

    IERC20 public immutable depositToken;
    IERC20 public rewardToken;
    address public owner;

    uint256 public rewardRate;
    uint256 public constant MAX_REWARD_RATE = 1000 * 1e18;
    uint256 public constant PRECISION = 1e18;

    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;

    bool public paused;
    bool private _locked;

    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardTokenUpdated(address indexed oldToken, address indexed newToken);
    event PauseStatusChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error IsPaused();
    error ZeroAddress();
    error RewardRateExceedsMax();
    error InsufficientStaked();
    error NoPendingReward();
    error TransferFailed();
    error CannotRecoverDepositToken();
    error ReentrancyDetected();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier notPaused() {
        if (paused) revert IsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyDetected();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address _depositToken,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _startBlock
    ) {
        if (_depositToken == address(0) || _rewardToken == address(0)) revert ZeroAddress();
        if (_rewardRate > MAX_REWARD_RATE) revert RewardRateExceedsMax();
        depositToken = IERC20(_depositToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
        owner = msg.sender;
        lastRewardBlock = _startBlock == 0 ? block.number : _startBlock;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) return;
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 blocksPassed = block.number - lastRewardBlock;
        uint256 reward = blocksPassed * rewardRate;
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        if (reward > rewardBalance) {
            reward = rewardBalance;
        }
        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardBlock = block.number;
    }

    function _updateUserPending(address _user) internal {
        UserInfo storage user = userInfo[_user];
        uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
        if (pending > 0) {
            user.unclaimed += pending;
        }
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
    }

    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        if (totalStaked == 0) return user.unclaimed;
        uint256 blocksPassed = block.number > lastRewardBlock ? block.number - lastRewardBlock : 0;
        uint256 reward = blocksPassed * rewardRate;
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        if (reward > rewardBalance) reward = rewardBalance;
        uint256 newAcc = accRewardPerShare + (reward * PRECISION) / totalStaked;
        uint256 pending = (user.amount * newAcc) / PRECISION - user.rewardDebt;
        return user.unclaimed + pending;
    }

    function deposit(uint256 _amount) external notPaused nonReentrant {
        _updatePool();
        UserInfo storage user = userInfo[msg.sender];
        _updateUserPending(msg.sender);
        if (_amount > 0) {
            user.amount += _amount;
            totalStaked += _amount;
            user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
            if (!depositToken.transferFrom(msg.sender, address(this), _amount)) {
                revert TransferFailed();
            }
        }
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external notPaused nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        if (_amount > user.amount) revert InsufficientStaked();
        _updatePool();
        _updateUserPending(msg.sender);
        if (_amount > 0) {
            user.amount -= _amount;
            totalStaked -= _amount;
            user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
            if (!depositToken.transfer(msg.sender, _amount)) {
                revert TransferFailed();
            }
        }
        emit Withdraw(msg.sender, _amount);
    }

    function claimReward() external nonReentrant {
        _updatePool();
        UserInfo storage user = userInfo[msg.sender];
        _updateUserPending(msg.sender);
        uint256 toPay = user.unclaimed;
        if (toPay == 0) revert NoPendingReward();
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 actualPay = toPay > balance ? balance : toPay;
        user.unclaimed -= actualPay;
        if (actualPay > 0) {
            if (!rewardToken.transfer(msg.sender, actualPay)) revert TransferFailed();
        }
        emit ClaimReward(msg.sender, actualPay);
    }

    function setRewardRate(uint256 _rate) external onlyOwner {
        if (_rate > MAX_REWARD_RATE) revert RewardRateExceedsMax();
        _updatePool();
        emit RewardRateUpdated(rewardRate, _rate);
        rewardRate = _rate;
    }

    function setRewardToken(address _token) external onlyOwner {
        if (_token == address(0)) revert ZeroAddress();
        _updatePool();
        emit RewardTokenUpdated(address(rewardToken), _token);
        rewardToken = IERC20(_token);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseStatusChanged(_paused);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function recoverExcessToken(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(depositToken)) revert CannotRecoverDepositToken();
        if (!IERC20(_token).transfer(owner, _amount)) revert TransferFailed();
    }
}
