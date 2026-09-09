// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SpendingPolicyRegistry
 * @notice A secure, on-chain registry for user-defined spending policies.
 *         Enables automated transaction execution without custodying assets.
 *         Each policy specifies a beneficiary and a maximum daily spending
 *         limit (capped at 10 ether). Updates to a policy's spending limit
 *         are subject to a 24-hour cooldown.
 */
contract SpendingPolicyRegistry {
    // ----------------------------------------------------------------------
    // Custom Errors
    // ----------------------------------------------------------------------

    error Unauthorized();
    error ZeroAddress();
    error PolicyNotFound();
    error InvalidBeneficiary();
    error InvalidSpendingLimit();
    error SpendingLimitExceedsMaximum();
    error CooldownNotElapsed();
    error EmergencyPaused();

    // ----------------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------------

    event PolicyCreated(
        address indexed user,
        uint256 indexed policyId,
        address beneficiary,
        uint256 dailyLimit
    );

    event PolicyUpdated(
        address indexed user,
        uint256 indexed policyId,
        address newBeneficiary,
        uint256 newDailyLimit
    );

    event PolicyRevoked(
        address indexed user,
        uint256 indexed policyId
    );

    event OperatorChanged(
        address indexed previousOperator,
        address indexed newOperator
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event EmergencyPauseToggled(bool paused);

    // ----------------------------------------------------------------------
    // Structs
    // ----------------------------------------------------------------------

    struct SpendingPolicy {
        address beneficiary;
        uint256 dailyLimit;
        uint256 lastLimitUpdate;
        bool exists;
    }

    // ----------------------------------------------------------------------
    // Constants
    // ----------------------------------------------------------------------

    uint256 public constant MAX_DAILY_LIMIT = 10 ether;
    uint256 public constant LIMIT_UPDATE_COOLDOWN = 24 hours;

    // ----------------------------------------------------------------------
    // State Variables
    // ----------------------------------------------------------------------

    address public owner;
    address public operator;
    bool public emergencyPaused;

    /// @notice List of policy IDs owned by each user.
    mapping(address => uint256[]) private userPolicyIds;

    /// @notice Mapping from user to policy ID to SpendingPolicy.
    mapping(address => mapping(uint256 => SpendingPolicy)) private policies;

    /// @notice Next policy ID to assign for each user.
    mapping(address => uint256) private nextPolicyId;

    // ----------------------------------------------------------------------
    // Modifiers
    // ----------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (emergencyPaused) revert EmergencyPaused();
        _;
    }

    modifier policyExists(address user, uint256 policyId) {
        if (!policies[user][policyId].exists) revert PolicyNotFound();
        _;
    }

    // ----------------------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------------------

    constructor(address operator_) {
        if (operator_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = operator_;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), operator_);
    }

    // ----------------------------------------------------------------------
    // External / Public Functions
    // ----------------------------------------------------------------------

    /**
     * @notice Creates a new spending policy for the caller.
     * @param beneficiary_ Address authorized to spend under this policy.
     * @param dailyLimit_  Maximum daily spending limit in wei (1 <= limit <= 10 ether).
     * @return policyId The ID of the newly created policy.
     */
    function createPolicy(
        address beneficiary_,
        uint256 dailyLimit_
    ) external whenNotPaused returns (uint256 policyId) {
        if (beneficiary_ == address(0)) revert InvalidBeneficiary();
        if (dailyLimit_ == 0) revert InvalidSpendingLimit();
        if (dailyLimit_ > MAX_DAILY_LIMIT) revert SpendingLimitExceedsMaximum();

        address user = msg.sender;
        policyId = nextPolicyId[user]++;

        SpendingPolicy storage policy = policies[user][policyId];
        policy.beneficiary = beneficiary_;
        policy.dailyLimit = dailyLimit_;
        policy.lastLimitUpdate = block.timestamp;
        policy.exists = true;

        userPolicyIds[user].push(policyId);

        emit PolicyCreated(user, policyId, beneficiary_, dailyLimit_);
    }

    /**
     * @notice Updates an existing policy's beneficiary and/or daily limit.
     * @param policyId_        ID of the policy to update.
     * @param newBeneficiary_  New beneficiary address.
     * @param newDailyLimit_   New daily spending limit. If different from the
     *                         current limit, the 24-hour cooldown must have elapsed.
     */
    function updatePolicy(
        uint256 policyId_,
        address newBeneficiary_,
        uint256 newDailyLimit_
    ) external whenNotPaused policyExists(msg.sender, policyId_) {
        if (newBeneficiary_ == address(0)) revert InvalidBeneficiary();
        if (newDailyLimit_ == 0) revert InvalidSpendingLimit();
        if (newDailyLimit_ > MAX_DAILY_LIMIT) revert SpendingLimitExceedsMaximum();

        SpendingPolicy storage policy = policies[msg.sender][policyId_];

        // Enforce cooldown only when the spending limit is being changed.
        if (newDailyLimit_ != policy.dailyLimit) {
            if (block.timestamp < policy.lastLimitUpdate + LIMIT_UPDATE_COOLDOWN) {
                revert CooldownNotElapsed();
            }
            policy.lastLimitUpdate = block.timestamp;
        }

        policy.beneficiary = newBeneficiary_;
        policy.dailyLimit = newDailyLimit_;

        emit PolicyUpdated(msg.sender, policyId_, newBeneficiary_, newDailyLimit_);
    }

    /**
     * @notice Revokes an existing policy, removing it from the user's registry.
     * @param policyId_ ID of the policy to revoke.
     */
    function revokePolicy(
        uint256 policyId_
    ) external policyExists(msg.sender, policyId_) {
        delete policies[msg.sender][policyId_];

        uint256[] storage ids = userPolicyIds[msg.sender];
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; i++) {
            if (ids[i] == policyId_) {
                ids[i] = ids[length - 1];
                ids.pop();
                break;
            }
        }

        emit PolicyRevoked(msg.sender, policyId_);
    }

    /**
     * @notice Toggles the emergency pause state. Only callable by the operator.
     */
    function toggleEmergencyPause() external onlyOperator {
        emergencyPaused = !emergencyPaused;
        emit EmergencyPauseToggled(emergencyPaused);
    }

    /**
     * @notice Changes the designated operator. Only callable by the owner.
     * @param newOperator_ Address of the new operator.
     */
    function setOperator(address newOperator_) external onlyOwner {
        if (newOperator_ == address(0)) revert ZeroAddress();
        address previousOperator = operator;
        operator = newOperator_;
        emit OperatorChanged(previousOperator, newOperator_);
    }

    /**
     * @notice Transfers ownership of the contract to a new address.
     * @param newOwner_ Address of the new owner.
     */
    function transferOwnership(address newOwner_) external onlyOwner {
        if (newOwner_ == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner_;
        emit OwnershipTransferred(previousOwner, newOwner_);
    }

    // ----------------------------------------------------------------------
    // View Functions
    // ----------------------------------------------------------------------

    /**
     * @notice Returns the total number of policies for a given user.
     */
    function getPolicyCount(address user_) external view returns (uint256) {
        return userPolicyIds[user_].length;
    }

    /**
     * @notice Returns the policy ID at a specific index for a user.
     */
    function getPolicyIdAtIndex(
        address user_,
        uint256 index_
    ) external view returns (uint256) {
        return userPolicyIds[user_][index_];
    }

    /**
     * @notice Retrieves full details of a specific policy.
     */
    function getPolicy(
        address user_,
        uint256 policyId_
    )
        external
        view
        returns (
            address beneficiary,
            uint256 dailyLimit,
            uint256 lastLimitUpdate,
            bool exists
        )
    {
        SpendingPolicy storage policy = policies[user_][policyId_];
        return (
            policy.beneficiary,
            policy.dailyLimit,
            policy.lastLimitUpdate,
            policy.exists
        );
    }

    /**
     * @notice Returns whether a policy's spending limit can be updated now.
     */
    function canUpdateLimit(
        address user_,
        uint256 policyId_
    ) external view returns (bool) {
        if (!policies[user_][policyId_].exists) return false;
        return block.timestamp >=
            policies[user_][policyId_].lastLimitUpdate + LIMIT_UPDATE_COOLDOWN;
    }

    /**
     * @notice Returns the number of seconds remaining until the policy's
     *         spending limit can be updated. Returns 0 if already updatable
     *         or if the policy does not exist.
     */
    function secondsUntilUpdatable(
        address user_,
        uint256 policyId_
    ) external view returns (uint256) {
        if (!policies[user_][policyId_].exists) return 0;
        uint256 elapsed = block.timestamp - policies[user_][policyId_].lastLimitUpdate;
        if (elapsed >= LIMIT_UPDATE_COOLDOWN) return 0;
        return LIMIT_UPDATE_COOLDOWN - elapsed;
    }
}
