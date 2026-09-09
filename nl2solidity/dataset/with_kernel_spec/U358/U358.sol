// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LiquidStaking {
    // ---------------------------------------------------------------------
    // Liquid Staking Token (LST) - internal ERC20
    // ---------------------------------------------------------------------
    string public constant lstName = "Liquid Staking Token";
    string public constant lstSymbol = "LST";
    uint8 public constant lstDecimals = 18;
    uint256 public lstTotalSupply;
    mapping(address => uint256) public lstBalanceOf;
    mapping(address => mapping(address => uint256)) public lstAllowance;

    event LSTTransfer(address indexed from, address indexed to, uint256 value);
    event LSTApproval(address indexed owner, address indexed spender, uint256 value);

    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public owner;
    address public operator;
    address public treasury;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------
    // Assets
    // ---------------------------------------------------------------------
    IERC20 public immutable baseAsset;
    IERC20 public immutable rewardToken;

    // ---------------------------------------------------------------------
    // Staking pool state
    // ---------------------------------------------------------------------
    uint256 public totalStaked;
    mapping(address => uint256) public userStakedBalance;

    // ---------------------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------------------
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_DEPOSIT = 1e16; // 0.01 units (18 decimals)
    bytes32 public strategyId;

    // ---------------------------------------------------------------------
    // Rewards (ERC20 rewards, proportional to LST balance)
    // ---------------------------------------------------------------------
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public rewardsDuration;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposited(address indexed user, uint256 baseAmount, uint256 lstMinted);
    event Withdrawn(address indexed user, uint256 baseAmount, uint256 lstBurned, uint256 fee);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event RewardsDistributed(uint256 rewardAmount, uint256 duration, uint256 newRewardRate);
    event StrategyUpdated(bytes32 oldStrategyId, bytes32 newStrategyId);
    event RewardsDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event RecoveredERC20(address indexed token, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error ReentrantCall();
    error ZeroAddress();
    error AmountZero();
    error DepositBelowMinimum();
    error InsufficientLSTBalance();
    error InsufficientAllowance();
    error InsufficientStakedBalance();
    error DurationZero();
    error RewardPeriodNotFinished();
    error TransferFailed();
    error NoRewardsToClaim();

    constructor(
        address _baseAsset,
        address _rewardToken,
        address _operator,
        address _treasury,
        bytes32 _strategyId
    ) {
        if (_baseAsset == address(0) || _rewardToken == address(0) || _operator == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        baseAsset = IERC20(_baseAsset);
        rewardToken = IERC20(_rewardToken);
        owner = msg.sender;
        operator = _operator;
        treasury = _treasury;
        strategyId = _strategyId;
        rewardsDuration = 7 days;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
        emit StrategyUpdated(bytes32(0), _strategyId);
    }

    // ---------------------------------------------------------------------
    // Safe ERC20 transfer helpers (handle non-returning tokens)
    // ---------------------------------------------------------------------
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    // LST ERC20 internal implementation
    // ---------------------------------------------------------------------
    function _mintLST(address to, uint256 amount) internal {
        lstTotalSupply += amount;
        lstBalanceOf[to] += amount;
        emit LSTTransfer(address(0), to, amount);
    }

    function _burnLST(address from, uint256 amount) internal {
        if (lstBalanceOf[from] < amount) revert InsufficientLSTBalance();
        lstBalanceOf[from] -= amount;
        lstTotalSupply -= amount;
        emit LSTTransfer(from, address(0), amount);
    }

    function lstTransfer(address to, uint256 amount) external returns (bool) {
        _transferLST(msg.sender, to, amount);
        return true;
    }

    function lstApprove(address spender, uint256 amount) external returns (bool) {
        lstAllowance[msg.sender][spender] = amount;
        emit LSTApproval(msg.sender, spender, amount);
        return true;
    }

    function lstTransferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = lstAllowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            lstAllowance[from][msg.sender] = allowed - amount;
        }
        _transferLST(from, to, amount);
        return true;
    }

    function _transferLST(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (lstBalanceOf[from] < amount) revert InsufficientLSTBalance();
        lstBalanceOf[from] -= amount;
        lstBalanceOf[to] += amount;
        emit LSTTransfer(from, to, amount);
    }

    // ---------------------------------------------------------------------
    // Rewards accounting
    // ---------------------------------------------------------------------
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (lstTotalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (
            (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / lstTotalSupply
        );
    }

    function earned(address account) public view returns (uint256) {
        return (lstBalanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18
            + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    // ---------------------------------------------------------------------
    // Core staking operations
    // ---------------------------------------------------------------------
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum();

        _updateReward(msg.sender);

        // Effects: update state before external transfer (checks-effects-interactions)
        userStakedBalance[msg.sender] += amount;
        totalStaked += amount;
        _mintLST(msg.sender, amount);

        // Interactions: transfer base asset from user to contract
        _safeTransferFrom(baseAsset, msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount, amount);
    }

    function withdraw(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert AmountZero();
        if (lstBalanceOf[msg.sender] < lstAmount) revert InsufficientLSTBalance();
        if (totalStaked < lstAmount) revert InsufficientStakedBalance();

        _updateReward(msg.sender);

        // Effects: burn LST and update staked balances before external transfer
        _burnLST(msg.sender, lstAmount);

        uint256 fee = (lstAmount * WITHDRAWAL_FEE_BPS) / FEE_DENOMINATOR;
        uint256 net = lstAmount - fee;

        totalStaked -= lstAmount;
        if (userStakedBalance[msg.sender] >= lstAmount) {
            userStakedBalance[msg.sender] -= lstAmount;
        } else {
            userStakedBalance[msg.sender] = 0;
        }

        // Interactions: transfer base asset out
        _safeTransfer(baseAsset, msg.sender, net);

        if (fee > 0) {
            _safeTransfer(baseAsset, treasury, fee);
        }

        emit Withdrawn(msg.sender, lstAmount, lstAmount, fee);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (!(reward > 0)) revert NoRewardsToClaim();

        // Effects: zero out pending rewards before external transfer
        rewards[msg.sender] = 0;

        // Interactions: transfer reward token to user
        _safeTransfer(rewardToken, msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------
    function distributeRewards(uint256 rewardAmount, uint256 duration) external onlyOperator nonReentrant {
        if (rewardAmount == 0) revert AmountZero();
        if (duration == 0) revert DurationZero();
        if (block.timestamp < periodFinish) revert RewardPeriodNotFinished();

        // Effects: update reward accounting state before external transfer
        rewardRate = rewardAmount / duration;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;

        // Interactions: pull reward tokens from operator
        _safeTransferFrom(rewardToken, msg.sender, address(this), rewardAmount);

        emit RewardsDistributed(rewardAmount, duration, rewardRate);
    }

    function updateStrategy(bytes32 newStrategyId) external onlyOperator {
        bytes32 old = strategyId;
        strategyId = newStrategyId;
        emit StrategyUpdated(old, newStrategyId);
    }

    function setRewardsDuration(uint256 newDuration) external onlyOperator {
        if (newDuration == 0) revert DurationZero();
        if (block.timestamp < periodFinish) revert RewardPeriodNotFinished();
        uint256 old = rewardsDuration;
        rewardsDuration = newDuration;
        emit RewardsDurationUpdated(old, newDuration);
    }

    // ---------------------------------------------------------------------
    // Owner functions
    // ---------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        _safeTransfer(IERC20(token), to, amount);
        emit RecoveredERC20(token, to, amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function getStakedBalance(address account) external view returns (uint256) {
        return userStakedBalance[account];
    }

    function getLSTBalance(address account) external view returns (uint256) {
        return lstBalanceOf[account];
    }

    function getPendingRewards(address account) external view returns (uint256) {
        return earned(account);
    }
}
