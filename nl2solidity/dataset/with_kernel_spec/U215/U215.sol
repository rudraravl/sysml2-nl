// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract LiquidStakingWrapper {
    // ==================== Constants ====================
    uint256 public constant PROTOCOL_FEE_BPS = 50;            // 0.5%
    uint256 public constant MAX_LEVERAGE_X = 5;               // 5x hard cap
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant ACC_PRECISION = 1e18;
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // ==================== Token References ====================
    IERC20 public baseToken;
    IERC20 public rewardToken;

    // ==================== LST Supply ====================
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    // ==================== Total Staked Base (gross) ====================
    uint256 public totalStakedBase;

    // ==================== Access Control ====================
    address public owner;
    address public operator;

    // ==================== Looping Strategy ====================
    struct LoopingConfig {
        uint256 targetLeverageBps;  // target leverage in bps (e.g. 30000 = 3x)
        bool isActive;              // whether looping is enabled
    }
    LoopingConfig public loopingConfig;

    struct LoopingPosition {
        uint256 collateralAmount;  // base token collateral allocated
        uint256 borrowedAmount;     // amount borrowed for looping
        uint256 createdAt;          // creation timestamp
        bool isActive;              // whether position is still open
    }
    LoopingPosition[] public loopingPositions;
    uint256 public totalBorrowedValue;
    uint256 public totalCollateralValue;

    // ==================== Rewards ====================
    uint256 public accRewardPerShare;
    mapping(address => uint256) public userRewardDebt;
    mapping(address => uint256) public pendingRewards;

    // ==================== Fees ====================
    uint256 public accumulatedProtocolFees;

    // ==================== Reentrancy Guard ====================
    uint256 private _reentrancyStatus;

    // ==================== Events ====================
    event Deposit(address indexed user, uint256 baseAmount, uint256 lstAmount, uint256 fee);
    event Redeem(address indexed user, uint256 lstAmount, uint256 baseAmount, uint256 fee);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardNotified(uint256 amount, uint256 newAccRewardPerShare);
    event LoopingInitiated(uint256 indexed positionId, uint256 collateral, uint256 borrowed);
    event LoopingClosed(uint256 indexed positionId, uint256 returnedAmount);
    event LoopingConfigUpdated(uint256 targetLeverageBps, bool isActive);
    event ProtocolFeesWithdrawn(address indexed to, uint256 amount);
    event OperatorSet(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Upgraded(address indexed newImplementation);

    // ==================== Errors ====================
    error ErrZeroAmount();
    error ErrInsufficientBalance();
    error ErrInsufficientLiquidity();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrInvalidAddress();
    error ErrLeverageExceeded();
    error ErrTargetLeverageExceeded();
    error ErrLoopingNotActive();
    error ErrPositionNotActive();
    error ErrInvalidPositionId();
    error ErrNoRewards();
    error ErrTransferFailed();
    error ErrReentrancy();

    // ==================== Modifiers ====================
    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus != 0) revert ErrReentrancy();
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 0;
    }

    // ==================== Constructor ====================
    constructor(address _baseToken, address _rewardToken, address _operator) {
        if (_baseToken == address(0)) revert ErrInvalidAddress();
        if (_rewardToken == address(0)) revert ErrInvalidAddress();
        if (_operator == address(0)) revert ErrInvalidAddress();

        baseToken = IERC20(_baseToken);
        rewardToken = IERC20(_rewardToken);
        owner = msg.sender;
        operator = _operator;

        // Default looping config: active at 5x target leverage
        loopingConfig.targetLeverageBps = MAX_LEVERAGE_X * BPS_DENOMINATOR;
        loopingConfig.isActive = true;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorSet(address(0), _operator);
    }

    // ==================== Safe Transfer Helpers ====================

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert ErrTransferFailed();
        }
        if (data.length != 0 && !abi.decode(data, (bool))) revert ErrTransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert ErrTransferFailed();
        }
        if (data.length != 0 && !abi.decode(data, (bool))) revert ErrTransferFailed();
    }

    // ==================== User Functions ====================

    function deposit(uint256 baseAmount) external nonReentrant returns (uint256 lstAmount) {
        if (baseAmount == 0) revert ErrZeroAmount();

        // Settle pending rewards before balance change (effects)
        _updateUserPending(msg.sender);

        uint256 fee = (baseAmount * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = baseAmount - fee;

        // Mint LST 1:1 with net deposited amount (effects before interactions)
        lstAmount = netAmount;
        totalSupply += lstAmount;
        balanceOf[msg.sender] += lstAmount;

        accumulatedProtocolFees += fee;
        totalStakedBase += baseAmount;

        // Update reward debt for new balance (effects)
        userRewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        // Pull base tokens from user (interaction)
        _safeTransferFrom(baseToken, msg.sender, address(this), baseAmount);

        emit Deposit(msg.sender, baseAmount, lstAmount, fee);
    }

    function redeem(uint256 lstAmount) external nonReentrant returns (uint256 baseReturned) {
        if (lstAmount == 0) revert ErrZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert ErrInsufficientBalance();

        // Settle pending rewards before balance change (effects)
        _updateUserPending(msg.sender);

        // Fee deducted from the base amount (1:1 LST to base before fee)
        uint256 fee = (lstAmount * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        baseReturned = lstAmount - fee;

        // Verify sufficient liquid base tokens (excluding accumulated fees)
        uint256 contractBalance = baseToken.balanceOf(address(this));
        if (contractBalance < accumulatedProtocolFees) revert ErrInsufficientLiquidity();
        uint256 available = contractBalance - accumulatedProtocolFees;
        if (available < lstAmount) revert ErrInsufficientLiquidity();

        // Burn LST (effects)
        balanceOf[msg.sender] -= lstAmount;
        totalSupply -= lstAmount;
        totalStakedBase -= lstAmount;

        // Update reward debt for new balance (effects)
        userRewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        accumulatedProtocolFees += fee;

        // Transfer base tokens to user (interaction)
        _safeTransfer(baseToken, msg.sender, baseReturned);

        emit Redeem(msg.sender, lstAmount, baseReturned, fee);
    }

    function claimRewards() external nonReentrant returns (uint256 reward) {
        // Settle pending rewards (effects)
        _updateUserPending(msg.sender);

        reward = pendingRewards[msg.sender];
        if (reward == 0) revert ErrNoRewards();

        // Effects: zero out pending and update debt
        pendingRewards[msg.sender] = 0;
        userRewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        // Interaction: transfer reward tokens
        _safeTransfer(rewardToken, msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    // ==================== Operator Functions ====================

    function notifyRewardAmount(uint256 rewardAmount) external onlyOperator nonReentrant {
        if (rewardAmount == 0) revert ErrZeroAmount();
        if (totalSupply == 0) revert ErrZeroAmount();

        // Effects: update reward accumulator before pulling tokens
        uint256 rewardPerShare = (rewardAmount * ACC_PRECISION) / totalSupply;
        accRewardPerShare += rewardPerShare;

        // Interaction: pull reward tokens from operator
        _safeTransferFrom(rewardToken, msg.sender, address(this), rewardAmount);

        emit RewardNotified(rewardAmount, accRewardPerShare);
    }

    function initiateLooping(
        uint256 collateralAmount,
        uint256 borrowAmount
    ) external onlyOperator nonReentrant returns (uint256 positionId) {
        if (!loopingConfig.isActive) revert ErrLoopingNotActive();
        if (collateralAmount == 0) revert ErrZeroAmount();
        if (borrowAmount == 0) revert ErrZeroAmount();

        uint256 newTotalBorrowed = totalBorrowedValue + borrowAmount;

        // Hard maximum: total borrowed <= 5x total staked base tokens
        uint256 maxBorrow = totalStakedBase * MAX_LEVERAGE_X;
        if (newTotalBorrowed > maxBorrow) revert ErrLeverageExceeded();

        // Target leverage from strategy config
        uint256 targetMax =
            (totalStakedBase * loopingConfig.targetLeverageBps) / BPS_DENOMINATOR;
        if (newTotalBorrowed > targetMax) revert ErrTargetLeverageExceeded();

        positionId = loopingPositions.length;
        loopingPositions.push(LoopingPosition({
            collateralAmount: collateralAmount,
            borrowedAmount: borrowAmount,
            createdAt: block.timestamp,
            isActive: true
        }));

        totalBorrowedValue = newTotalBorrowed;
        totalCollateralValue += collateralAmount;

        emit LoopingInitiated(positionId, collateralAmount, borrowAmount);
    }

    function closeLooping(uint256 positionId)
        external
        onlyOperator
        nonReentrant
        returns (uint256 returnedAmount)
    {
        if (positionId >= loopingPositions.length) revert ErrInvalidPositionId();
        LoopingPosition storage pos = loopingPositions[positionId];
        if (!pos.isActive) revert ErrPositionNotActive();

        pos.isActive = false;
        totalBorrowedValue -= pos.borrowedAmount;
        totalCollateralValue -= pos.collateralAmount;
        returnedAmount = pos.collateralAmount;

        emit LoopingClosed(positionId, returnedAmount);
    }

    function setLoopingConfig(uint256 _targetLeverageBps, bool _isActive) external onlyOperator {
        if (_targetLeverageBps > MAX_LEVERAGE_X * BPS_DENOMINATOR) revert ErrLeverageExceeded();

        loopingConfig.targetLeverageBps = _targetLeverageBps;
        loopingConfig.isActive = _isActive;

        emit LoopingConfigUpdated(_targetLeverageBps, _isActive);
    }

    function withdrawProtocolFees(address to) external onlyOperator nonReentrant {
        if (to == address(0)) revert ErrInvalidAddress();
        uint256 amount = accumulatedProtocolFees;
        if (amount == 0) revert ErrZeroAmount();

        // Effects
        accumulatedProtocolFees = 0;

        // Interaction
        _safeTransfer(baseToken, to, amount);

        emit ProtocolFeesWithdrawn(to, amount);
    }

    // ==================== Owner Functions ====================

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrInvalidAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorSet(prev, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrInvalidAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ErrInvalidAddress();
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
        emit Upgraded(newImplementation);
    }

    function getImplementation() external view returns (address impl) {
        assembly {
            impl := sload(_IMPLEMENTATION_SLOT)
        }
    }

    // ==================== Internal ====================

    function _updateUserPending(address user) internal {
        if (balanceOf[user] > 0) {
            uint256 entitled = (balanceOf[user] * accRewardPerShare) / ACC_PRECISION;
            uint256 debt = userRewardDebt[user];
            if (entitled > debt) {
                pendingRewards[user] += entitled - debt;
            }
        }
        userRewardDebt[user] = (balanceOf[user] * accRewardPerShare) / ACC_PRECISION;
    }

    // ==================== View Functions ====================

    function getPendingRewards(address user) external view returns (uint256) {
        if (balanceOf[user] == 0) return pendingRewards[user];
        uint256 entitled = (balanceOf[user] * accRewardPerShare) / ACC_PRECISION;
        uint256 debt = userRewardDebt[user];
        uint256 unsettled = entitled > debt ? entitled - debt : 0;
        return pendingRewards[user] + unsettled;
    }

    function currentLeverage() external view returns (uint256) {
        if (totalStakedBase == 0) return 0;
        return (totalBorrowedValue * BPS_DENOMINATOR) / totalStakedBase;
    }

    function getLoopingPosition(uint256 positionId)
        external
        view
        returns (
            uint256 collateralAmount,
            uint256 borrowedAmount,
            uint256 createdAt,
            bool isActive
        )
    {
        if (positionId >= loopingPositions.length) revert ErrInvalidPositionId();
        LoopingPosition storage pos = loopingPositions[positionId];
        return (pos.collateralAmount, pos.borrowedAmount, pos.createdAt, pos.isActive);
    }

    function loopingPositionCount() external view returns (uint256) {
        return loopingPositions.length;
    }

    function getAvailableLiquidity() external view returns (uint256) {
        uint256 balance = baseToken.balanceOf(address(this));
        if (balance < accumulatedProtocolFees) return 0;
        return balance - accumulatedProtocolFees;
    }
}
