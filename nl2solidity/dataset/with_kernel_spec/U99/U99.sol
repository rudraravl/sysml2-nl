// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract GamingEcosystemStaking {
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientStakedBalance();
    error InsufficientContractBalance();
    error RewardRateTooHigh();
    error NotOperator();
    error TransferFailed();
    error InvalidDuration();
    error Reentrancy();

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 fee);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event RewardPeriodStarted(uint256 rewardAmount, uint256 duration);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TokensRecovered(address indexed token, uint256 amount);

    uint256 public constant MAX_ANNUAL_RATE_BPS = 1000;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant BPS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    IERC20 public immutable stakingToken;
    address public operator;

    uint256 public totalStaked;
    uint256 public annualRewardRateBps;
    uint256 public periodFinish;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public accruedRewards;
    mapping(address => uint256) public lastUpdateTime;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    constructor(address _stakingToken, address _operator) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stakingToken = IERC20(_stakingToken);
        operator = _operator;
        _status = _NOT_ENTERED;
        emit OperatorUpdated(address(0), _operator);
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    function _lastTimeRewardApplicable() internal view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function _updateReward(address _user) internal {
        uint256 effectiveTime = _lastTimeRewardApplicable();
        if (lastUpdateTime[_user] == 0) {
            lastUpdateTime[_user] = block.timestamp;
        }
        if (effectiveTime <= lastUpdateTime[_user]) return;

        uint256 timeElapsed = effectiveTime - lastUpdateTime[_user];
        uint256 staked = stakedBalance[_user];
        if (staked > 0 && annualRewardRateBps > 0) {
            uint256 newReward = (staked * annualRewardRateBps * timeElapsed) / (BPS * SECONDS_PER_YEAR);
            accruedRewards[_user] += newReward;
        }
        lastUpdateTime[_user] = effectiveTime;
    }

    function stake(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        _updateReward(msg.sender);
        stakedBalance[msg.sender] += _amount;
        totalStaked += _amount;
        _safeTransferFrom(address(stakingToken), msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < _amount) revert InsufficientStakedBalance();
        _updateReward(msg.sender);
        stakedBalance[msg.sender] -= _amount;
        totalStaked -= _amount;
        uint256 fee = (_amount * WITHDRAWAL_FEE_BPS) / BPS;
        uint256 amountAfterFee = _amount - fee;
        _safeTransfer(address(stakingToken), msg.sender, amountAfterFee);
        emit Unstaked(msg.sender, _amount, fee);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = accruedRewards[msg.sender];
        if (reward > 0) {
            accruedRewards[msg.sender] = 0;
            _safeTransfer(address(stakingToken), msg.sender, reward);
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 _rate) external onlyOperator {
        if (_rate > MAX_ANNUAL_RATE_BPS) revert RewardRateTooHigh();
        annualRewardRateBps = _rate;
        emit RewardRateUpdated(_rate);
    }

    function startRewardPeriod(uint256 _rewardAmount, uint256 _duration) external onlyOperator {
        if (_duration == 0) revert InvalidDuration();
        if (_rewardAmount > 0) {
            _safeTransferFrom(address(stakingToken), msg.sender, address(this), _rewardAmount);
        }
        periodFinish = block.timestamp + _duration;
        emit RewardPeriodStarted(_rewardAmount, _duration);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function recoverTokens(address _token, uint256 _amount) external onlyOperator {
        if (_token == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        if (_token == address(stakingToken)) {
            uint256 balance = stakingToken.balanceOf(address(this));
            uint256 excess = balance > totalStaked ? balance - totalStaked : 0;
            if (_amount > excess) revert InsufficientContractBalance();
        }
        _safeTransfer(_token, msg.sender, _amount);
        emit TokensRecovered(_token, _amount);
    }

    function earned(address _account) external view returns (uint256) {
        uint256 effectiveTime = _lastTimeRewardApplicable();
        uint256 userLastUpdate = lastUpdateTime[_account];
        if (userLastUpdate == 0) userLastUpdate = block.timestamp;
        uint256 pending = 0;
        if (effectiveTime > userLastUpdate && stakedBalance[_account] > 0 && annualRewardRateBps > 0) {
            uint256 timeElapsed = effectiveTime - userLastUpdate;
            pending = (stakedBalance[_account] * annualRewardRateBps * timeElapsed) / (BPS * SECONDS_PER_YEAR);
        }
        return accruedRewards[_account] + pending;
    }

    function availableRewards() external view returns (uint256) {
        uint256 balance = stakingToken.balanceOf(address(this));
        return balance > totalStaked ? balance - totalStaked : 0;
    }

    function totalReserves() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function _safeTransfer(address _token, address _to, uint256 _amount) private {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address _token, address _from, address _to, uint256 _amount) private {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
