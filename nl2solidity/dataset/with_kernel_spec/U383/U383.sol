// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title ReputationManager
 * @notice Canonical source of truth for user credibility scores within the ecosystem.
 *         Users register unique identifiers backed by staked tokens, and operators
 *         adjust scores or resolve disputes. Challenges impose a 5% fee on the
 *         challenged user's staked amount, awarded to successful challengers.
 */
contract ReputationManager is ReentrancyGuard {
    using SafeERC20 for IERC20;

    //--------------------------------------------------------------------
    // Errors
    //--------------------------------------------------------------------
    error NotOperator();
    error UserAlreadyExists(bytes32 userId);
    error UserDoesNotExist(bytes32 userId);
    error InsufficientStake(uint256 required, uint256 provided);
    error InsufficientStakedBalance(uint256 requested, uint256 available);
    error CannotStakeZero();
    error ChallengeDoesNotExist(uint256 challengeId);
    error ChallengeAlreadyResolved(uint256 challengeId);
    error CannotChallengeSelf();
    error ZeroAddress();

    //--------------------------------------------------------------------
    // Events
    //--------------------------------------------------------------------
    event UserRegistered(bytes32 indexed userId, address indexed staker, uint256 stakeAmount, uint256 initialScore);
    event StakeAdded(bytes32 indexed userId, address indexed staker, uint256 amount, uint256 newTotalStaked);
    event StakeTransferred(
        bytes32 indexed fromUserId,
        bytes32 indexed toUserId,
        address indexed staker,
        uint256 amount
    );
    event ScoreAdjusted(
        bytes32 indexed userId,
        uint256 oldScore,
        uint256 newScore,
        string reason,
        address indexed operator
    );
    event ChallengeInitiated(
        uint256 indexed challengeId,
        bytes32 indexed challengedUserId,
        address indexed challenger,
        uint256 feeAmount
    );
    event ChallengeResolved(
        uint256 indexed challengeId,
        bytes32 indexed challengedUserId,
        address indexed challenger,
        bool successful,
        uint256 feeAmount,
        address operator
    );
    event StakingTokenSet(address indexed oldToken, address indexed newToken);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    //--------------------------------------------------------------------
    // Structs
    //--------------------------------------------------------------------
    struct User {
        bool exists;
        uint256 credibilityScore;
        uint256 totalStaked;
    }

    struct ScoreAdjustment {
        uint256 oldScore;
        uint256 newScore;
        string reason;
        uint40 timestamp;
        address operator;
    }

    struct Challenge {
        bytes32 challengedUserId;
        address challenger;
        uint256 feeAmount;
        bool resolved;
        bool successful;
        uint40 initiatedAt;
        uint40 resolvedAt;
    }

    //--------------------------------------------------------------------
    // Constants
    //--------------------------------------------------------------------
    uint256 public constant MINIMUM_REGISTRATION_STAKE = 100 * 10 ** 18;
    uint256 public constant CHALLENGE_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_INITIAL_SCORE = 50;

    //--------------------------------------------------------------------
    // State
    //--------------------------------------------------------------------
    address public operator;
    IERC20 public stakingToken;

    mapping(bytes32 userId => User) public users;
    mapping(bytes32 userId => mapping(address staker => uint256 amount)) public stakes;
    mapping(bytes32 userId => ScoreAdjustment[]) public scoreHistory;

    Challenge[] public challenges;

    //--------------------------------------------------------------------
    // Modifiers
    //--------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier userExists(bytes32 userId) {
        if (!users[userId].exists) revert UserDoesNotExist(userId);
        _;
    }

    //--------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------
    constructor(address _operator, address _stakingToken) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_stakingToken == address(0)) revert ZeroAddress();
        operator = _operator;
        stakingToken = IERC20(_stakingToken);
        emit OperatorChanged(address(0), _operator);
        emit StakingTokenSet(address(0), _stakingToken);
    }

    //--------------------------------------------------------------------
    // External / Public functions
    //--------------------------------------------------------------------

    /**
     * @notice Register a new unique user identifier by staking at least the minimum
     *         required amount of tokens. The caller becomes the first staker.
     * @param userId      Unique identifier for the new user.
     * @param stakeAmount Amount of staking tokens to deposit (>= MINIMUM_REGISTRATION_STAKE).
     */
    function registerUser(bytes32 userId, uint256 stakeAmount) external nonReentrant {
        if (users[userId].exists) revert UserAlreadyExists(userId);
        if (stakeAmount < MINIMUM_REGISTRATION_STAKE) {
            revert InsufficientStake(MINIMUM_REGISTRATION_STAKE, stakeAmount);
        }

        // Effects
        users[userId] = User({
            exists: true,
            credibilityScore: DEFAULT_INITIAL_SCORE,
            totalStaked: stakeAmount
        });
        stakes[userId][msg.sender] += stakeAmount;

        scoreHistory[userId].push(
            ScoreAdjustment({
                oldScore: 0,
                newScore: DEFAULT_INITIAL_SCORE,
                reason: "Initial registration",
                timestamp: uint40(block.timestamp),
                operator: msg.sender
            })
        );

        // Interactions
        stakingToken.safeTransferFrom(msg.sender, address(this), stakeAmount);

        emit UserRegistered(userId, msg.sender, stakeAmount, DEFAULT_INITIAL_SCORE);
        emit StakeAdded(userId, msg.sender, stakeAmount, stakeAmount);
        emit ScoreAdjusted(userId, 0, DEFAULT_INITIAL_SCORE, "Initial registration", msg.sender);
    }

    /**
     * @notice Stake additional tokens to support an existing user's credibility.
     * @param userId      The user whose credibility is being supported.
     * @param amount      Tokens to stake.
     */
    function stake(bytes32 userId, uint256 amount)
        external
        nonReentrant
        userExists(userId)
    {
        if (amount == 0) revert CannotStakeZero();

        // Effects
        users[userId].totalStaked += amount;
        stakes[userId][msg.sender] += amount;

        // Interactions
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit StakeAdded(userId, msg.sender, amount, users[userId].totalStaked);
    }

    /**
     * @notice Transfer a portion of the caller's staked tokens from one user to another.
     * @param fromUserId Source user whose stake pool the caller is moving tokens from.
     * @param toUserId   Destination user.
     * @param amount     Amount to transfer.
     */
    function transferStake(
        bytes32 fromUserId,
        bytes32 toUserId,
        uint256 amount
    ) external nonReentrant userExists(fromUserId) userExists(toUserId) {
        if (amount == 0) revert CannotStakeZero();

        uint256 callerStake = stakes[fromUserId][msg.sender];
        if (callerStake < amount) revert InsufficientStakedBalance(amount, callerStake);

        // Effects
        stakes[fromUserId][msg.sender] -= amount;
        users[fromUserId].totalStaked -= amount;

        stakes[toUserId][msg.sender] += amount;
        users[toUserId].totalStaked += amount;

        emit StakeTransferred(fromUserId, toUserId, msg.sender, amount);
    }

    /**
     * @notice Initiate a challenge against a user's credibility. A 5% fee is deducted
     *         from the challenged user's total stake and held until resolution.
     * @param userId The user being challenged.
     */
    function challenge(bytes32 userId) external nonReentrant userExists(userId) {
        if (msg.sender == operator) revert CannotChallengeSelf();

        User storage user = users[userId];
        uint256 feeAmount = (user.totalStaked * CHALLENGE_FEE_BPS) / BPS_DENOMINATOR;

        // Deduct fee from the challenged user's total stake and hold it in the contract.
        user.totalStaked -= feeAmount;

        uint256 challengeId = challenges.length;
        challenges.push(
            Challenge({
                challengedUserId: userId,
                challenger: msg.sender,
                feeAmount: feeAmount,
                resolved: false,
                successful: false,
                initiatedAt: uint40(block.timestamp),
                resolvedAt: 0
            })
        );

        emit ChallengeInitiated(challengeId, userId, msg.sender, feeAmount);
    }

    /**
     * @notice Operator adjusts a user's credibility score.
     * @param userId   Target user.
     * @param newScore New credibility score.
     * @param reason   Human-readable reason for the adjustment.
     */
    function adjustScore(
        bytes32 userId,
        uint256 newScore,
        string calldata reason
    ) external onlyOperator userExists(userId) {
        User storage user = users[userId];
        uint256 oldScore = user.credibilityScore;
        user.credibilityScore = newScore;

        scoreHistory[userId].push(
            ScoreAdjustment({
                oldScore: oldScore,
                newScore: newScore,
                reason: reason,
                timestamp: uint40(block.timestamp),
                operator: msg.sender
            })
        );

        emit ScoreAdjusted(userId, oldScore, newScore, reason, msg.sender);
    }

    /**
     * @notice Operator resolves a pending challenge. If successful, the challenger
     *         receives the locked fee; otherwise the fee is returned to the
     *         challenged user's stake pool.
     * @param challengeId Identifier of the challenge.
     * @param successful  Whether the challenge is upheld.
     */
    function resolveChallenge(uint256 challengeId, bool successful)
        external
        onlyOperator
        nonReentrant
    {
        if (challengeId >= challenges.length) revert ChallengeDoesNotExist(challengeId);
        Challenge storage challenge_ = challenges[challengeId];
        if (challenge_.resolved) revert ChallengeAlreadyResolved(challengeId);

        // Effects
        challenge_.resolved = true;
        challenge_.successful = successful;
        challenge_.resolvedAt = uint40(block.timestamp);

        bytes32 challengedUserId = challenge_.challengedUserId;
        uint256 feeAmount = challenge_.feeAmount;

        if (successful) {
            // Award fee to challenger
            stakingToken.safeTransfer(challenge_.challenger, feeAmount);
        } else {
            // Return fee to the challenged user's stake pool
            users[challengedUserId].totalStaked += feeAmount;
        }

        emit ChallengeResolved(
            challengeId,
            challengedUserId,
            challenge_.challenger,
            successful,
            feeAmount,
            msg.sender
        );
    }

    /**
     * @notice Operator sets a new staking token address.
     */
    function setStakingToken(address newToken) external onlyOperator {
        if (newToken == address(0)) revert ZeroAddress();
        address old = address(stakingToken);
        stakingToken = IERC20(newToken);
        emit StakingTokenSet(old, newToken);
    }

    /**
     * @notice Transfer operator role to a new address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    //--------------------------------------------------------------------
    // View functions
    //--------------------------------------------------------------------

    function getUser(bytes32 userId)
        external
        view
        returns (bool exists, uint256 credibilityScore, uint256 totalStaked)
    {
        User storage u = users[userId];
        return (u.exists, u.credibilityScore, u.totalStaked);
    }

    function getStake(bytes32 userId, address staker) external view returns (uint256) {
        return stakes[userId][staker];
    }

    function getScoreHistoryLength(bytes32 userId) external view returns (uint256) {
        return scoreHistory[userId].length;
    }

    function getScoreAdjustment(bytes32 userId, uint256 index)
        external
        view
        returns (
            uint256 oldScore,
            uint256 newScore,
            string memory reason,
            uint40 timestamp,
            address operatorAddr
        )
    {
        ScoreAdjustment storage a = scoreHistory[userId][index];
        return (a.oldScore, a.newScore, a.reason, a.timestamp, a.operator);
    }

    function getChallengeCount() external view returns (uint256) {
        return challenges.length;
    }

    function getChallenge(uint256 challengeId)
        external
        view
        returns (
            bytes32 challengedUserId,
            address challenger,
            uint256 feeAmount,
            bool resolved,
            bool successful,
            uint40 initiatedAt,
            uint40 resolvedAt
        )
    {
        Challenge storage c = challenges[challengeId];
        return (
            c.challengedUserId,
            c.challenger,
            c.feeAmount,
            c.resolved,
            c.successful,
            c.initiatedAt,
            c.resolvedAt
        );
    }
}
