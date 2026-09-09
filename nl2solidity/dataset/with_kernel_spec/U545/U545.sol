// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IGovernanceToken is IERC20 {
    function delegate(address delegatee) external;
    function getCurrentVotes(address account) external view returns (uint256);
}

contract GovernanceDelegation {
    error ZeroAddress();
    error InsufficientDeposit();
    error InsufficientBalance();
    error FeeExceedsCap();
    error NoPendingYield();
    error NotOwner();
    error SafeTransferFailed();
    error InvalidAmount();
    error ReentrantCall();

    event Deposit(address indexed user, uint256 amount, uint256 totalDeposited);
    event Withdraw(address indexed user, uint256 amount, uint256 totalDeposited);
    event YieldClaimed(address indexed user, uint256 amount);
    event DelegationTargetChanged(address indexed oldTarget, address indexed newTarget);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event YieldDistributed(uint256 grossYield, uint256 feeAmount, uint256 distributable);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Delegated(address indexed delegatee, uint256 votes);

    uint256 public constant FEE_CAP = 500;
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DEPOSIT = 10e18;
    uint256 public constant MIN_DUST = 1;

    IGovernanceToken public immutable governanceToken;
    IERC20 public immutable yieldToken;

    address public owner;
    address public delegationTarget;
    uint256 public platformFee;

    uint256 public totalDeposited;
    uint256 public accYieldPerShare;
    uint256 public totalYieldPending;
    uint256 public totalYieldDistributed;

    bool public delegationActive;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 delegatedPower;
    }

    mapping(address => UserInfo) public userInfo;

    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address _governanceToken,
        address _yieldToken,
        address _delegationTarget,
        uint256 _platformFee
    ) {
        if (_governanceToken == address(0)) revert ZeroAddress();
        if (_yieldToken == address(0)) revert ZeroAddress();
        if (_delegationTarget == address(0)) revert ZeroAddress();
        if (_platformFee > FEE_CAP) revert FeeExceedsCap();

        governanceToken = IGovernanceToken(_governanceToken);
        yieldToken = IERC20(_yieldToken);
        delegationTarget = _delegationTarget;
        platformFee = _platformFee;
        owner = msg.sender;

        emit DelegationTargetChanged(address(0), _delegationTarget);
        emit PlatformFeeUpdated(0, _platformFee);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function pendingYield(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return (user.amount * accYieldPerShare) / ACC_PRECISION - user.rewardDebt;
    }

    function getUserInfo(address _user)
        external
        view
        returns (uint256 amount, uint256 rewardDebt, uint256 delegatedPower)
    {
        UserInfo storage user = userInfo[_user];
        return (user.amount, user.rewardDebt, user.delegatedPower);
    }

    function _updateUserDebt(address _user) internal {
        UserInfo storage user = userInfo[_user];
        user.rewardDebt = (user.amount * accYieldPerShare) / ACC_PRECISION;
    }

    function _distributeYield() internal {
        uint256 currentBalance = yieldToken.balanceOf(address(this));
        if (currentBalance <= totalYieldPending || totalDeposited < MIN_DUST) return;
        uint256 newYield = currentBalance - totalYieldPending;

        uint256 feeAmount = (newYield * platformFee) / BPS_DENOMINATOR;
        uint256 distributable = newYield - feeAmount;

        accYieldPerShare += (distributable * ACC_PRECISION) / totalDeposited;
        totalYieldPending += distributable;
        totalYieldDistributed += distributable;

        if (feeAmount > MIN_DUST) {
            if (!yieldToken.transfer(owner, feeAmount)) {
                revert SafeTransferFailed();
            }
        }

        emit YieldDistributed(newYield, feeAmount, distributable);
    }

    function _claimYield(address _user) internal {
        UserInfo storage user = userInfo[_user];
        uint256 pending = (user.amount * accYieldPerShare) / ACC_PRECISION - user.rewardDebt;
        if (pending < MIN_DUST) return;

        totalYieldPending -= pending;
        user.rewardDebt = (user.amount * accYieldPerShare) / ACC_PRECISION;

        _safeYieldTransfer(_user, pending);
        emit YieldClaimed(_user, pending);
    }

    function _safeYieldTransfer(address _to, uint256 _amount) internal {
        uint256 balance = yieldToken.balanceOf(address(this));
        if (balance < _amount) {
            _amount = balance;
        }
        if (!yieldToken.transfer(_to, _amount)) {
            revert SafeTransferFailed();
        }
    }

    function _delegate() internal {
        delegationActive = true;
        governanceToken.delegate(delegationTarget);
        emit Delegated(delegationTarget, governanceToken.getCurrentVotes(delegationTarget));
    }

    function deposit(uint256 _amount) external nonReentrant {
        if (_amount < MIN_DEPOSIT) revert InsufficientDeposit();

        uint256 balanceBefore = governanceToken.balanceOf(address(this));
        if (!governanceToken.transferFrom(msg.sender, address(this), _amount)) {
            revert SafeTransferFailed();
        }
        uint256 received = governanceToken.balanceOf(address(this)) - balanceBefore;

        _distributeYield();
        _claimYield(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        user.amount += received;
        user.delegatedPower += received;
        totalDeposited += received;

        _updateUserDebt(msg.sender);

        if (!delegationActive) {
            _delegate();
        }

        emit Deposit(msg.sender, received, totalDeposited);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        if (_amount < MIN_DUST) revert InvalidAmount();

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount < _amount) revert InsufficientBalance();

        _distributeYield();
        _claimYield(msg.sender);

        user.amount -= _amount;
        user.delegatedPower -= _amount;
        totalDeposited -= _amount;

        _updateUserDebt(msg.sender);

        if (!governanceToken.transfer(msg.sender, _amount)) {
            revert SafeTransferFailed();
        }

        emit Withdraw(msg.sender, _amount, totalDeposited);
    }

    function claimYield() external nonReentrant {
        _distributeYield();

        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * accYieldPerShare) / ACC_PRECISION - user.rewardDebt;
        if (pending < MIN_DUST) revert NoPendingYield();

        totalYieldPending -= pending;
        user.rewardDebt = (user.amount * accYieldPerShare) / ACC_PRECISION;

        _safeYieldTransfer(msg.sender, pending);
        emit YieldClaimed(msg.sender, pending);
    }

    function refreshDelegation() external nonReentrant {
        _delegate();
    }

    function setDelegationTarget(address _newTarget) external onlyOwner {
        if (_newTarget == address(0)) revert ZeroAddress();
        address oldTarget = delegationTarget;
        delegationTarget = _newTarget;
        if (totalDeposited > MIN_DUST) {
            _delegate();
        } else {
            delegationActive = false;
        }
        emit DelegationTargetChanged(oldTarget, _newTarget);
    }

    function setPlatformFee(uint256 _newFee) external onlyOwner {
        if (_newFee > FEE_CAP) revert FeeExceedsCap();
        uint256 oldFee = platformFee;
        platformFee = _newFee;
        emit PlatformFeeUpdated(oldFee, _newFee);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }

    function rescueTokens(address _token, uint256 _amount) external onlyOwner {
        if (_amount < MIN_DUST) revert InvalidAmount();

        if (_token == address(governanceToken)) {
            uint256 balance = governanceToken.balanceOf(address(this));
            if (balance < totalDeposited) revert InsufficientBalance();
            uint256 excess = balance - totalDeposited;
            if (_amount > excess) revert InsufficientBalance();
        } else if (_token == address(yieldToken)) {
            uint256 balance = yieldToken.balanceOf(address(this));
            if (balance < totalYieldPending) revert InsufficientBalance();
            uint256 excess = balance - totalYieldPending;
            if (_amount > excess) revert InsufficientBalance();
        }

        if (!IERC20(_token).transfer(msg.sender, _amount)) {
            revert SafeTransferFailed();
        }
    }
}
