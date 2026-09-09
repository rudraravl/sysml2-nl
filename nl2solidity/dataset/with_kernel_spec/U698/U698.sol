// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract YieldAggregator {
    // ============ Custom Errors ============
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error WhenNotPaused();
    error InsufficientDeposit();
    error FeeRateTooHigh();
    error InsufficientBalance();
    error TransferFailed();
    error NoYieldToClaim();
    error ZeroAmount();
    error ReentrantCall();

    // ============ Events ============
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 yieldAmount, uint256 feeAmount);
    event WrapperStaked(address indexed user, uint256 amount);
    event WrapperUnstaked(address indexed user, uint256 amount);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event YieldAccrued(address indexed user, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Constants ============
    uint256 public constant FEE_RATE_CAP = 1000; // 10% in basis points
    uint256 public constant MIN_DEPOSIT = 100 * 10 ** 18; // 100 governance tokens

    // ============ Immutables ============
    IERC20 public immutable governanceToken;
    IERC20 public immutable wrapperToken;

    // ============ Access Control ============
    address public owner;
    address public operator;
    bool public paused;

    // ============ Fee State ============
    uint256 public feeRate; // in basis points (e.g., 100 = 1%)

    // ============ Aggregate State ============
    uint256 public totalDeposited;
    uint256 public totalWrapperStaked;

    // ============ User State ============
    struct UserInfo {
        uint256 deposited;
        uint256 claimableYield;
        uint256 wrapperStaked;
    }

    mapping(address => UserInfo) public userInfo;

    // ============ Reentrancy Guard ============
    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ============ Modifiers ============
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

    modifier whenPaused() {
        if (!paused) revert WhenNotPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ============ Constructor ============
    constructor(
        address _governanceToken,
        address _wrapperToken,
        address _operator,
        uint256 _initialFeeRate
    ) {
        if (_governanceToken == address(0) || _wrapperToken == address(0) || _operator == address(0))
            revert ZeroAddress();
        if (_initialFeeRate > FEE_RATE_CAP) revert FeeRateTooHigh();

        governanceToken = IERC20(_governanceToken);
        wrapperToken = IERC20(_wrapperToken);
        owner = msg.sender;
        operator = _operator;
        feeRate = _initialFeeRate;
        _reentrancyStatus = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRateUpdated(0, _initialFeeRate);
    }

    // ============ Owner Functions ============

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function pause() external onlyOwner {
        if (paused) revert WhenPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert WhenNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ============ Operator Functions ============

    function setFeeRate(uint256 newRate) external onlyOperator {
        if (newRate > FEE_RATE_CAP) revert FeeRateTooHigh();
        uint256 old = feeRate;
        feeRate = newRate;
        emit FeeRateUpdated(old, newRate);
    }

    function distributeYield(address user, uint256 amount) external onlyOperator {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        userInfo[user].claimableYield += amount;
        emit YieldAccrued(user, amount);
    }

    // ============ User Functions ============

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();

        UserInfo storage info = userInfo[msg.sender];

        bool ok = governanceToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        info.deposited += amount;
        totalDeposited += amount;

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage info = userInfo[msg.sender];
        if (info.deposited < amount) revert InsufficientBalance();

        info.deposited -= amount;
        totalDeposited -= amount;

        bool ok = governanceToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function claimYield() external whenNotPaused nonReentrant {
        UserInfo storage info = userInfo[msg.sender];
        uint256 pending = info.claimableYield;
        if (pending == 0) revert NoYieldToClaim();

        info.claimableYield = 0;

        uint256 fee = (pending * feeRate) / 10000;
        uint256 net = pending - fee;

        if (fee > 0) {
            bool feeOk = governanceToken.transfer(owner, fee);
            if (!feeOk) revert TransferFailed();
        }

        if (net > 0) {
            bool ok = governanceToken.transfer(msg.sender, net);
            if (!ok) revert TransferFailed();
        }

        emit YieldClaimed(msg.sender, net, fee);
    }

    function stakeWrapper(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage info = userInfo[msg.sender];

        bool ok = wrapperToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        info.wrapperStaked += amount;
        totalWrapperStaked += amount;

        emit WrapperStaked(msg.sender, amount);
    }

    function unstakeWrapper(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage info = userInfo[msg.sender];
        if (info.wrapperStaked < amount) revert InsufficientBalance();

        info.wrapperStaked -= amount;
        totalWrapperStaked -= amount;

        bool ok = wrapperToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit WrapperUnstaked(msg.sender, amount);
    }

    // ============ View Functions ============

    function getUserInfo(address user) external view returns (uint256, uint256, uint256) {
        UserInfo storage info = userInfo[user];
        return (info.deposited, info.claimableYield, info.wrapperStaked);
    }

    function pendingYield(address user) external view returns (uint256) {
        return userInfo[user].claimableYield;
    }

    // ============ Recovery ============

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        bool ok = IERC20(token).transfer(owner, amount);
        if (!ok) revert TransferFailed();
    }
}
