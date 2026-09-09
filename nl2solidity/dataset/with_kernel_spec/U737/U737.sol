// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, value)));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert SafeERC20FailedOperation(address(token));
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), SafeERC20FailedOperation(address(token)));
        }
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

abstract contract ReentrancyGuard {
    error ReentrancyGuardReentrantCall();

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title PredictionPools
 * @notice Manages prediction pools where participants stake USD stablecoins on
 *         event outcomes. An operator finalizes pools and configures the fee.
 */
contract PredictionPools is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE_BPS = 200; // 2% cap
    uint256 public constant MIN_STAKE_TO_FINALIZE = 100 * 10 ** 18; // 100 USD (18 decimals)

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidOutcomeCount();
    error InvalidOutcome();
    error PoolNotOpen();
    error PoolNotFinalized();
    error InsufficientStake();
    error MinStakeNotReached();
    error AlreadyClaimed();
    error NothingToClaim();
    error FeeExceedsMax();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event PoolCreated(
        uint256 indexed poolId,
        address indexed creator,
        string description,
        uint256 outcomeCount,
        uint256 createdAt
    );
    event ParticipantJoined(
        uint256 indexed poolId,
        address indexed participant,
        uint256 indexed outcome,
        uint256 amount
    );
    event ParticipantWithdrew(
        uint256 indexed poolId,
        address indexed participant,
        uint256 indexed outcome,
        uint256 amount
    );
    event PoolFinalized(
        uint256 indexed poolId,
        uint256 winningOutcome,
        uint256 totalStaked,
        uint256 feeCollected,
        uint256 payoutPool,
        uint256 finalizedAt
    );
    event WinningsClaimed(uint256 indexed poolId, address indexed participant, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------
    enum PoolState {
        Open,
        Finalized
    }

    struct Pool {
        string description;
        uint256 outcomeCount;
        uint256 totalStaked;
        uint256 winningOutcome;
        uint256 winningOutcomeStaked;
        uint256 payoutPool;
        uint256 feeCollected;
        uint256 createdAt;
        uint256 finalizedAt;
        PoolState state;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    IERC20 public immutable stablecoin;

    address public operator;
    uint256 public feeBps;
    uint256 public poolCount;

    mapping(uint256 => Pool) internal _pools;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeStaked;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userStakeOnOutcome;
    mapping(uint256 => mapping(address => uint256)) public userTotalStaked;
    mapping(uint256 => mapping(address => bool)) public userClaimed;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _stablecoin, address _operator, address _owner) Ownable(_owner) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        feeBps = MAX_FEE_BPS;

        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, feeBps);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setFeeBps(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMax();
        emit FeeUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    // ---------------------------------------------------------------------
    // Core functions
    // ---------------------------------------------------------------------

    function createPool(string calldata description, uint256 outcomeCount)
        external
        returns (uint256 poolId)
    {
        if (outcomeCount < 2) revert InvalidOutcomeCount();

        poolId = poolCount++;
        Pool storage p = _pools[poolId];
        p.description = description;
        p.outcomeCount = outcomeCount;
        p.state = PoolState.Open;
        p.createdAt = block.timestamp;

        emit PoolCreated(poolId, msg.sender, description, outcomeCount, block.timestamp);
    }

    function joinPool(uint256 poolId, uint256 outcome, uint256 amount) external nonReentrant {
        Pool storage p = _pools[poolId];
        if (p.state != PoolState.Open) revert PoolNotOpen();
        if (outcome >= p.outcomeCount) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();

        // Effects: update state before external interaction
        userStakeOnOutcome[poolId][msg.sender][outcome] += amount;
        userTotalStaked[poolId][msg.sender] += amount;
        outcomeStaked[poolId][outcome] += amount;
        p.totalStaked += amount;

        // Interaction
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit ParticipantJoined(poolId, msg.sender, outcome, amount);
    }

    function withdraw(uint256 poolId, uint256 outcome, uint256 amount) external nonReentrant {
        Pool storage p = _pools[poolId];
        if (p.state != PoolState.Open) revert PoolNotOpen();
        if (outcome >= p.outcomeCount) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();

        uint256 staked = userStakeOnOutcome[poolId][msg.sender][outcome];
        if (staked < amount) revert InsufficientStake();

        // Effects
        userStakeOnOutcome[poolId][msg.sender][outcome] = staked - amount;
        userTotalStaked[poolId][msg.sender] -= amount;
        outcomeStaked[poolId][outcome] -= amount;
        p.totalStaked -= amount;

        // Interaction
        stablecoin.safeTransfer(msg.sender, amount);

        emit ParticipantWithdrew(poolId, msg.sender, outcome, amount);
    }

    function finalizePool(uint256 poolId, uint256 winningOutcome)
        external
        onlyOperator
        nonReentrant
    {
        Pool storage p = _pools[poolId];
        if (p.state != PoolState.Open) revert PoolNotOpen();
        if (winningOutcome >= p.outcomeCount) revert InvalidOutcome();
        if (p.totalStaked < MIN_STAKE_TO_FINALIZE) revert MinStakeNotReached();

        uint256 winningStaked = outcomeStaked[poolId][winningOutcome];
        if (winningStaked == 0) revert InvalidOutcome();

        uint256 fee = (p.totalStaked * feeBps) / BASIS_POINTS;
        uint256 payout = p.totalStaked - fee;

        // Effects
        p.winningOutcome = winningOutcome;
        p.winningOutcomeStaked = winningStaked;
        p.feeCollected = fee;
        p.payoutPool = payout;
        p.state = PoolState.Finalized;
        p.finalizedAt = block.timestamp;

        // Interaction
        if (fee > 0) {
            stablecoin.safeTransfer(operator, fee);
        }

        emit PoolFinalized(poolId, winningOutcome, p.totalStaked, fee, payout, block.timestamp);
    }

    function claimWinnings(uint256 poolId) external nonReentrant {
        Pool storage p = _pools[poolId];
        if (p.state != PoolState.Finalized) revert PoolNotFinalized();
        if (userClaimed[poolId][msg.sender]) revert AlreadyClaimed();

        uint256 userStake = userStakeOnOutcome[poolId][msg.sender][p.winningOutcome];
        if (userStake == 0) revert NothingToClaim();

        // Effects
        userClaimed[poolId][msg.sender] = true;

        uint256 winnings = (userStake * p.payoutPool) / p.winningOutcomeStaked;

        // Interaction
        stablecoin.safeTransfer(msg.sender, winnings);

        emit WinningsClaimed(poolId, msg.sender, winnings);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    function getPool(uint256 poolId)
        external
        view
        returns (
            string memory description,
            uint256 outcomeCount,
            uint256 totalStaked,
            uint256 winningOutcome,
            uint256 winningOutcomeStaked,
            uint256 payoutPool,
            uint256 feeCollected,
            uint256 createdAt,
            uint256 finalizedAt,
            PoolState state
        )
    {
        Pool storage p = _pools[poolId];
        return (
            p.description,
            p.outcomeCount,
            p.totalStaked,
            p.winningOutcome,
            p.winningOutcomeStaked,
            p.payoutPool,
            p.feeCollected,
            p.createdAt,
            p.finalizedAt,
            p.state
        );
    }

    function getOutcomeStaked(uint256 poolId, uint256 outcome) external view returns (uint256) {
        return outcomeStaked[poolId][outcome];
    }

    function getUserStakeOnOutcome(uint256 poolId, address user, uint256 outcome)
        external
        view
        returns (uint256)
    {
        return userStakeOnOutcome[poolId][user][outcome];
    }

    function getUserTotalStaked(uint256 poolId, address user) external view returns (uint256) {
        return userTotalStaked[poolId][user];
    }

    function hasUserClaimed(uint256 poolId, address user) external view returns (bool) {
        return userClaimed[poolId][user];
    }

    function pendingWinnings(uint256 poolId, address user) external view returns (uint256) {
        Pool storage p = _pools[poolId];
        if (p.state != PoolState.Finalized) return 0;
        if (userClaimed[poolId][user]) return 0;
        uint256 userStake = userStakeOnOutcome[poolId][user][p.winningOutcome];
        if (userStake == 0 || p.winningOutcomeStaked == 0) return 0;
        return (userStake * p.payoutPool) / p.winningOutcomeStaked;
    }
}
