Looking at the error, the constructor reverts during setUp. The issue is the `stakingToken.approve(_yieldProtocol, type(uint256).max)` call in the constructor — the mock token may not handle this properly. I'll move approval to `stakeToProtocol` and also fix the `available` calculation which could underflow.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IYieldProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
}

contract YieldVault {
    error OnlyOwner();
    error OnlyOperator();
    error ZeroAddress();
    error FeeExceedsMax();
    error ZeroAmount();
    error InsufficientBalance();
    error ExistingUnbondingRequest();
    error NoUnbondingRequest();
    error UnbondingPeriodNotOver();
    error NoPendingRewards();
    error InsufficientAvailableTokens();
    error ExceedsStaked();
    error TransferFailed();
    error Reentrancy();

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event UnbondRequested(address indexed user, uint256 amount, uint256 unlockTime);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event YieldProtocolUpdated(address indexed oldProtocol, address indexed newProtocol);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event StakedToProtocol(uint256 amount);
    event UnstakedFromProtocol(uint256 amount, uint256 yieldAmount);

    uint256 public constant MAX_FEE = 1000; // 10% in basis points
    uint256 public constant UNBONDING_PERIOD = 24 hours;
    uint256 private constant ACC_REWARD_PRECISION = 1e18;

    IERC20 public immutable stakingToken;
    address public owner;
    address public operator;
    address public yieldProtocol;
    uint256 public feePercentage; // basis points, 0..1000

    uint256 public totalDeposited;
    uint256 public totalStakedInProtocol;
    uint256 public totalPendingWithdrawals;
    uint256 public accRewardPerShare;
    uint256 public totalPendingRewards;

    mapping(address => uint256) public accountBalance;
    mapping(address => uint256) public rewardDebt;

    struct UnbondRequest {
        uint256 amount;
        uint256 unlockTime;
        bool active;
    }
    mapping(address => UnbondRequest) public unbondRequests;

    uint256 private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 0) revert Reentrancy();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(
        address _stakingToken,
        address _yieldProtocol,
        address _operator,
        uint256 _feePercentage
    ) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_yieldProtocol == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feePercentage > MAX_FEE) revert FeeExceedsMax();

        stakingToken = IERC20(_stakingToken);
        yieldProtocol = _yieldProtocol;
        operator = _operator;
        feePercentage = _feePercentage;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);
        emit YieldProtocolUpdated(address(0), _yieldProtocol);
        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, _feePercentage);
    }

    // ----------------------------------------------------------------------
    // User functions
    // ----------------------------------------------------------------------

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        accountBalance[msg.sender] += amount;
        totalDeposited += amount;
        rewardDebt[msg.sender] = (accountBalance[msg.sender] * accRewardPerShare) / ACC_REWARD_PRECISION;

        bool ok = stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, amount);
    }

    function requestUnstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (accountBalance[msg.sender] < amount) revert InsufficientBalance();
        if (unbondRequests[msg.sender].active) revert ExistingUnbondingRequest();

        _claimRewards(msg.sender);

        accountBalance[msg.sender] -= amount;
        totalDeposited -= amount;
        totalPendingWithdrawals += amount;

        unbondRequests[msg.sender] = UnbondRequest({
            amount: amount,
            unlockTime: block.timestamp + UNBONDING_PERIOD,
            active: true
        });

        emit UnbondRequested(msg.sender, amount, block.timestamp + UNBONDING_PERIOD);
    }

    function withdraw() external nonReentrant {
        UnbondRequest storage req = unbondRequests[msg.sender];
        if (!req.active) revert NoUnbondingRequest();
        if (block.timestamp < req.unlockTime) revert UnbondingPeriodNotOver();

        uint256 amount = req.amount;
        req.active = false;
        req.amount = 0;
        req.unlockTime = 0;
        totalPendingWithdrawals -= amount;

        bool ok = stakingToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        uint256 claimed = _claimRewards(msg.sender);
        if (claimed == 0) revert NoPendingRewards();
        emit RewardClaimed(msg.sender, claimed);
    }

    function pendingReward(address user) external view returns (uint256) {
        return _pendingReward(user);
    }

    // ----------------------------------------------------------------------
    // Operator functions
    // ----------------------------------------------------------------------

    function stakeToProtocol(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 balance = stakingToken.balanceOf(address(this));
        uint256 available = balance > totalPendingWithdrawals
            ? balance - totalPendingWithdrawals
            : 0;
        if (amount > available) revert InsufficientAvailableTokens();

        bool ok = stakingToken.approve(yieldProtocol, amount);
        if (!ok) revert TransferFailed();

        IYieldProtocol(yieldProtocol).deposit(amount);
        totalStakedInProtocol += amount;

        emit StakedToProtocol(amount);
    }

    function unstakeFromProtocol(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > totalStakedInProtocol) revert ExceedsStaked();

        uint256 balanceBefore = stakingToken.balanceOf(address(this));
        IYieldProtocol(yieldProtocol).withdraw(amount);
        uint256 balanceAfter = stakingToken.balanceOf(address(this));

        uint256 received = balanceAfter > balanceBefore
            ? balanceAfter - balanceBefore
            : 0;
        uint256 yieldAmount = received > amount ? received - amount : 0;

        totalStakedInProtocol -= amount;

        if (yieldAmount > 0) {
            uint256 fee = (yieldAmount * feePercentage) / 10000;
            uint256 distributable = yieldAmount - fee;

            if (fee > 0) {
                bool okFee = stakingToken.transfer(owner, fee);
                if (!okFee) revert TransferFailed();
            }

            if (totalDeposited > 0) {
                accRewardPerShare += (distributable * ACC_REWARD_PRECISION) / totalDeposited;
                totalPendingRewards += distributable;
            } else {
                bool okDist = stakingToken.transfer(owner, distributable);
                if (!okDist) revert TransferFailed();
            }
        }

        emit UnstakedFromProtocol(amount, yieldAmount);
    }

    // ----------------------------------------------------------------------
    // Owner functions
    // ----------------------------------------------------------------------

    function setFee(uint256 _feePercentage) external onlyOwner {
        if (_feePercentage > MAX_FEE) revert FeeExceedsMax();
        uint256 old = feePercentage;
        feePercentage = _feePercentage;
        emit FeeUpdated(old, _feePercentage);
    }

    function setYieldProtocol(address _yieldProtocol) external onlyOwner {
        if (_yieldProtocol == address(0)) revert ZeroAddress();
        address old = yieldProtocol;
        yieldProtocol = _yieldProtocol;
        emit YieldProtocolUpdated(old, _yieldProtocol);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function recoverUnsupported(address token, uint256 amount) external onlyOwner {
        if (token == address(stakingToken)) revert InsufficientBalance();
        bool ok = IERC20(token).transfer(owner, amount);
        if (!ok) revert TransferFailed();
    }

    // ----------------------------------------------------------------------
    // Internal helpers
    // ----------------------------------------------------------------------

    function _pendingReward(address user) internal view returns (uint256) {
        uint256 shares = accountBalance[user];
        uint256 owed = (shares * accRewardPerShare) / ACC_REWARD_PRECISION;
        if (owed <= rewardDebt[user]) return 0;
        return owed - rewardDebt[user];
    }

    function _claimRewards(address user) internal returns (uint256) {
        uint256 pending = _pendingReward(user);
        if (pending == 0) {
            rewardDebt[user] = (accountBalance[user] * accRewardPerShare) / ACC_REWARD_PRECISION;
            return 0;
        }

        totalPendingRewards -= pending;
        rewardDebt[user] = (accountBalance[user] * accRewardPerShare) / ACC_REWARD_PRECISION;

        bool ok = stakingToken.transfer(user, pending);
        if (!ok) revert TransferFailed();

        return pending;
    }
}
