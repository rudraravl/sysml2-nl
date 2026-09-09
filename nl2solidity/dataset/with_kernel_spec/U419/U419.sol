// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IYieldSource {
    /// @notice Harvests available yield and transfers it to the caller.
    /// @return amount The amount of yield harvested and transferred.
    function harvest() external returns (uint256);
}

contract NoLossCreatorFunding {
    // ============ Constants ============
    uint256 public constant MIN_INITIAL_DEPOSIT = 0.1 ether;
    uint256 public constant FEE_BASIS_POINTS = 500; // 5%
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant ACC_PRECISION = 1e18;

    // ============ State ============
    address public owner;
    address public operator;
    address public yieldSource;
    address public feeRecipient;

    uint256 public bonusRewardRate; // bonus wei per second per allocation point
    uint256 public totalAllocationPoints;
    uint256 public totalStaked;
    uint256 public bonusBudget;
    uint256 public accumulatedFees;
    uint256 public poolCount;

    struct Pool {
        address creator;
        uint256 totalDeposits;
        uint256 allocPoints;
        uint256 accYieldPerShare;
        uint256 accBonusPerShare;
        uint256 lastRewardTime;
        uint256 pendingYield;
        uint256 pendingBonus;
    }

    struct UserInfo {
        uint256 amount;
        uint256 yieldDebt;
        uint256 bonusDebt;
    }

    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    uint256 private _status = 1;

    // ============ Events ============
    event PoolCreated(uint256 indexed poolId, address indexed creator, uint256 initialDeposit, uint256 allocPoints);
    event Deposited(uint256 indexed poolId, address indexed user, uint256 amount);
    event Withdrawn(uint256 indexed poolId, address indexed user, uint256 amount);
    event YieldClaimed(uint256 indexed poolId, address indexed user, uint256 yieldAmount, uint256 bonusAmount, uint256 fee);
    event YieldHarvested(uint256 totalYield);
    event OperatorSet(address indexed oldOperator, address indexed newOperator);
    event YieldSourceSet(address indexed oldSource, address indexed newSource);
    event BonusRewardRateSet(uint256 oldRate, uint256 newRate);
    event BonusFunded(address indexed funder, uint256 amount);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event FeeRecipientSet(address indexed oldRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Errors ============
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InsufficientInitialDeposit();
    error InsufficientBalance();
    error NoYieldSource();
    error ZeroAmount();
    error TransferFailed();
    error PoolNotFound();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");
        _status = 2;
        _;
        _status = 1;
    }

    // ============ Constructor ============
    constructor(address _operator, address _yieldSource, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        yieldSource = _yieldSource;
        feeRecipient = _feeRecipient;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    receive() external payable {}

    // ============ Admin ============
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorSet(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientSet(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setYieldSource(address _yieldSource) external onlyOperator {
        emit YieldSourceSet(yieldSource, _yieldSource);
        yieldSource = _yieldSource;
    }

    function setBonusRewardRate(uint256 _rate) external onlyOperator {
        emit BonusRewardRateSet(bonusRewardRate, _rate);
        bonusRewardRate = _rate;
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        if (amount > 0) {
            (bool success, ) = payable(feeRecipient).call{value: amount}("");
            if (!success) revert TransferFailed();
        }
        emit FeesWithdrawn(feeRecipient, amount);
    }

    // ============ Pool Creation ============
    function createPool(uint256 _allocPoints) external payable returns (uint256 pid) {
        if (msg.value < MIN_INITIAL_DEPOSIT) revert InsufficientInitialDeposit();
        if (_allocPoints == 0) revert ZeroAmount();

        pid = poolCount;
        poolCount++;

        Pool storage pool = pools[pid];
        pool.creator = msg.sender;
        pool.allocPoints = _allocPoints;
        pool.lastRewardTime = block.timestamp;
        pool.totalDeposits = msg.value;

        totalAllocationPoints += _allocPoints;
        totalStaked += msg.value;

        UserInfo storage user = userInfo[pid][msg.sender];
        user.amount = msg.value;

        emit PoolCreated(pid, msg.sender, msg.value, _allocPoints);
        emit Deposited(pid, msg.sender, msg.value);
    }

    // ============ User Actions ============
    function deposit(uint256 _pid) external payable nonReentrant {
        if (_pid >= poolCount) revert PoolNotFound();
        if (msg.value == 0) revert ZeroAmount();

        Pool storage pool = pools[_pid];
        _updatePool(_pid);

        UserInfo storage user = userInfo[_pid][msg.sender];
        (uint256 pendingYield, uint256 pendingBonus) = _pending(user, pool);

        uint256 fee = (pendingYield * FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 yieldToUser = pendingYield - fee;

        // Effects
        user.amount += msg.value;
        pool.totalDeposits += msg.value;
        totalStaked += msg.value;
        accumulatedFees += fee;
        user.yieldDebt = (user.amount * pool.accYieldPerShare) / ACC_PRECISION;
        user.bonusDebt = (user.amount * pool.accBonusPerShare) / ACC_PRECISION;

        // Interactions
        uint256 payout = yieldToUser + pendingBonus;
        if (payout > 0) {
            (bool success, ) = payable(msg.sender).call{value: payout}("");
            if (!success) revert TransferFailed();
        }

        emit Deposited(_pid, msg.sender, msg.value);
        if (pendingYield > 0 || pendingBonus > 0) {
            emit YieldClaimed(_pid, msg.sender, yieldToUser, pendingBonus, fee);
        }
    }

    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        if (_pid >= poolCount) revert PoolNotFound();
        Pool storage pool = pools[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (_amount > user.amount) revert InsufficientBalance();

        _updatePool(_pid);
        (uint256 pendingYield, uint256 pendingBonus) = _pending(user, pool);

        uint256 fee = (pendingYield * FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 yieldToUser = pendingYield - fee;

        // Effects
        user.amount -= _amount;
        pool.totalDeposits -= _amount;
        totalStaked -= _amount;
        accumulatedFees += fee;
        user.yieldDebt = (user.amount * pool.accYieldPerShare) / ACC_PRECISION;
        user.bonusDebt = (user.amount * pool.accBonusPerShare) / ACC_PRECISION;

        // Interactions
        uint256 payout = yieldToUser + pendingBonus + _amount;
        if (payout > 0) {
            (bool success, ) = payable(msg.sender).call{value: payout}("");
            if (!success) revert TransferFailed();
        }

        emit Withdrawn(_pid, msg.sender, _amount);
        if (pendingYield > 0 || pendingBonus > 0) {
            emit YieldClaimed(_pid, msg.sender, yieldToUser, pendingBonus, fee);
        }
    }

    function claim(uint256 _pid) external nonReentrant {
        if (_pid >= poolCount) revert PoolNotFound();
        Pool storage pool = pools[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        _updatePool(_pid);
        (uint256 pendingYield, uint256 pendingBonus) = _pending(user, pool);

        uint256 fee = (pendingYield * FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 yieldToUser = pendingYield - fee;

        // Effects
        accumulatedFees += fee;
        user.yieldDebt = (user.amount * pool.accYieldPerShare) / ACC_PRECISION;
        user.bonusDebt = (user.amount * pool.accBonusPerShare) / ACC_PRECISION;

        // Interactions
        uint256 payout = yieldToUser + pendingBonus;
        if (payout > 0) {
            (bool success, ) = payable(msg.sender).call{value: payout}("");
            if (!success) revert TransferFailed();
        }

        if (pendingYield > 0 || pendingBonus > 0) {
            emit YieldClaimed(_pid, msg.sender, yieldToUser, pendingBonus, fee);
        }
    }

    // ============ Yield & Bonus ============
    function harvestYield() external nonReentrant {
        if (yieldSource == address(0)) revert NoYieldSource();
        uint256 yieldAmount = IYieldSource(yieldSource).harvest();
        if (yieldAmount > 0 && totalAllocationPoints > 0) {
            for (uint256 pid = 0; pid < poolCount; pid++) {
                Pool storage pool = pools[pid];
                if (pool.allocPoints == 0) continue;
                uint256 share = (yieldAmount * pool.allocPoints) / totalAllocationPoints;
                pool.pendingYield += share;
            }
        }
        emit YieldHarvested(yieldAmount);
    }

    function fundBonus() external payable {
        if (msg.value == 0) revert ZeroAmount();
        bonusBudget += msg.value;
        emit BonusFunded(msg.sender, msg.value);
    }

    function updatePool(uint256 _pid) external {
        if (_pid >= poolCount) revert PoolNotFound();
        _updatePool(_pid);
    }

    // ============ Internal ============
    function _updatePool(uint256 _pid) internal {
        Pool storage pool = pools[_pid];
        if (block.timestamp <= pool.lastRewardTime) return;

        uint256 timeElapsed = block.timestamp - pool.lastRewardTime;

        if (pool.totalDeposits > 0) {
            if (bonusRewardRate > 0 && pool.allocPoints > 0) {
                uint256 bonus = timeElapsed * bonusRewardRate * pool.allocPoints;
                if (bonus > bonusBudget) {
                    bonus = bonusBudget;
                }
                if (bonus > 0) {
                    pool.pendingBonus += bonus;
                    bonusBudget -= bonus;
                }
            }

            if (pool.pendingYield > 0) {
                pool.accYieldPerShare += (pool.pendingYield * ACC_PRECISION) / pool.totalDeposits;
                pool.pendingYield = 0;
            }
            if (pool.pendingBonus > 0) {
                pool.accBonusPerShare += (pool.pendingBonus * ACC_PRECISION) / pool.totalDeposits;
                pool.pendingBonus = 0;
            }
        }

        pool.lastRewardTime = block.timestamp;
    }

    function _pending(UserInfo storage user, Pool storage pool)
        internal
        view
        returns (uint256 pendingYield, uint256 pendingBonus)
    {
        pendingYield = (user.amount * pool.accYieldPerShare) / ACC_PRECISION - user.yieldDebt;
        pendingBonus = (user.amount * pool.accBonusPerShare) / ACC_PRECISION - user.bonusDebt;
    }

    // ============ Views ============
    function pendingRewards(uint256 _pid, address _user)
        external
        view
        returns (uint256 yieldAmount, uint256 bonusAmount)
    {
        if (_pid >= poolCount) return (0, 0);
        Pool storage pool = pools[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accYps = pool.accYieldPerShare;
        uint256 accBps = pool.accBonusPerShare;

        if (block.timestamp > pool.lastRewardTime && pool.totalDeposits > 0) {
            if (pool.pendingYield > 0) {
                accYps += (pool.pendingYield * ACC_PRECISION) / pool.totalDeposits;
            }

            uint256 projectedPendingBonus = pool.pendingBonus;
            if (bonusRewardRate > 0 && pool.allocPoints > 0) {
                uint256 timeElapsed = block.timestamp - pool.lastRewardTime;
                uint256 bonus = timeElapsed * bonusRewardRate * pool.allocPoints;
                if (bonus > bonusBudget) bonus = bonusBudget;
                projectedPendingBonus += bonus;
            }

            if (projectedPendingBonus > 0) {
                accBps += (projectedPendingBonus * ACC_PRECISION) / pool.totalDeposits;
            }
        }

        yieldAmount = (user.amount * accYps) / ACC_PRECISION - user.yieldDebt;
        bonusAmount = (user.amount * accBps) / ACC_PRECISION - user.bonusDebt;
    }
}
