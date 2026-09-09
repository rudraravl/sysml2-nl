// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract LiquidStaking {
    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error BelowMinimumDeposit();
    error InsufficientBalance(uint256 requested, uint256 available);
    error InvalidFeePercent(uint256 fee);
    error ZeroAddress();
    error ZeroAmount();
    error TransferFailed();
    error InvalidExchangeRate();
    error RecoverForbidden();
    error NoRewards();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposit(address indexed user, uint256 nativeAmount, uint256 fee, uint256 derivativeAmount);
    event Withdrawal(address indexed user, uint256 derivativeAmount, uint256 nativeAmount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event FeePercentUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event Paused(address account);
    event Unpaused(address account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    address public operator;
    address public feeRecipient;
    uint256 public feePercent;
    uint256 public constant MIN_DEPOSIT = 100 ether;
    uint256 public exchangeRate;
    bool public paused;

    mapping(address => uint256) public depositedNative;

    IERC20 public immutable rewardToken;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public constant REWARDS_DURATION = 7 days;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

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

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _rewardToken,
        uint256 _initialExchangeRate,
        address _feeRecipient,
        address _operator,
        string memory _name,
        string memory _symbol
    ) {
        if (_rewardToken == address(0) || _feeRecipient == address(0) || _operator == address(0))
            revert ZeroAddress();
        if (_initialExchangeRate == 0) revert InvalidExchangeRate();

        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        feePercent = 50;
        exchangeRate = _initialExchangeRate;
        rewardToken = IERC20(_rewardToken);
        name = _name;
        symbol = _symbol;
        paused = false;

        emit OwnershipTransferred(address(0), owner);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        uint256 allowed = allowance[_from][msg.sender];
        if (allowed < _value) revert InsufficientBalance(_value, allowed);
        if (allowed != type(uint256).max) {
            unchecked {
                allowance[_from][msg.sender] = allowed - _value;
            }
        }
        _transfer(_from, _to, _value);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        if (_from == address(0) || _to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[_from];
        if (fromBalance < _value) revert InsufficientBalance(_value, fromBalance);
        unchecked {
            balanceOf[_from] = fromBalance - _value;
            balanceOf[_to] += _value;
        }
        emit Transfer(_from, _to, _value);
    }

    function _mint(address _to, uint256 _value) internal {
        if (_to == address(0)) revert ZeroAddress();
        totalSupply += _value;
        balanceOf[_to] += _value;
        emit Transfer(address(0), _to, _value);
    }

    function _burn(address _from, uint256 _value) internal {
        if (_from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[_from];
        if (fromBalance < _value) revert InsufficientBalance(_value, fromBalance);
        unchecked {
            balanceOf[_from] = fromBalance - _value;
            totalSupply -= _value;
        }
        emit Transfer(_from, address(0), _value);
    }

    function deposit() external payable whenNotPaused updateReward(msg.sender) {
        uint256 amount = msg.value;
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit();

        uint256 fee = (amount * feePercent) / 10000;
        uint256 net = amount - fee;

        uint256 derivativeAmount = (net * exchangeRate) / 1e18;
        if (derivativeAmount == 0) revert ZeroAmount();

        // Effects
        _mint(msg.sender, derivativeAmount);
        depositedNative[msg.sender] += net;

        // Interactions
        if (fee > 0) {
            (bool success, ) = feeRecipient.call{value: fee}("");
            if (!success) revert TransferFailed();
        }

        emit Deposit(msg.sender, amount, fee, derivativeAmount);
    }

    function withdraw(uint256 derivativeAmount) external whenNotPaused updateReward(msg.sender) {
        if (derivativeAmount == 0) revert ZeroAmount();

        uint256 nativeAmount = (derivativeAmount * 1e18) / exchangeRate;
        uint256 contractBalance = address(this).balance;
        if (nativeAmount > contractBalance) revert InsufficientBalance(nativeAmount, contractBalance);

        // Effects
        _burn(msg.sender, derivativeAmount);

        if (depositedNative[msg.sender] >= nativeAmount) {
            depositedNative[msg.sender] -= nativeAmount;
        } else {
            depositedNative[msg.sender] = 0;
        }

        // Interactions
        (bool success, ) = msg.sender.call{value: nativeAmount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, derivativeAmount, nativeAmount);
    }

    function claimRewards() external whenNotPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (!(reward > 0)) revert NoRewards();

        // Effects
        rewards[msg.sender] = 0;

        // Interactions
        if (!rewardToken.transfer(msg.sender, reward)) revert TransferFailed();

        emit RewardPaid(msg.sender, reward);
    }

    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    function notifyRewardAmount(uint256 reward) external onlyOperator updateReward(address(0)) {
        if (reward == 0) revert ZeroAmount();

        // Effects: update reward distribution state first
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / REWARDS_DURATION;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / REWARDS_DURATION;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + REWARDS_DURATION;

        // Interactions: pull reward tokens after state is updated
        if (!rewardToken.transferFrom(msg.sender, address(this), reward)) revert TransferFailed();

        emit RewardAdded(reward);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function setFeePercent(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert InvalidFeePercent(newFee);
        uint256 oldFee = feePercent;
        feePercent = newFee;
        emit FeePercentUpdated(oldFee, newFee);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function setPaused(bool _paused) external onlyOwner {
        if (paused == _paused) return;
        paused = _paused;
        if (_paused) emit Paused(msg.sender);
        else emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (token == address(rewardToken) || token == address(this)) revert RecoverForbidden();
        if (!IERC20(token).transfer(owner, amount)) revert TransferFailed();
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
    }

    function earned(address _account) public view returns (uint256) {
        return
            ((balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    receive() external payable {
        revert();
    }
}
