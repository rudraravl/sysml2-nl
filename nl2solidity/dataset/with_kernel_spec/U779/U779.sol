// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NativeStaking
 * @notice A non-custodial, fee-free native staking contract allowing users to delegate
 *         base layer assets to a curated set of validators without relinquishing control.
 * @dev Users retain full custody. Delegations are tracked per user and per validator.
 *      Undelegation requires a 7-day cooldown before assets can be claimed.
 */
contract NativeStaking {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error InvalidValidator();
    error ValidatorAlreadyExists();
    error ValidatorNotFound();
    error InvalidAmount();
    error InsufficientDelegationAmount();
    error InsufficientDelegation();
    error NoClaimableAssets();
    error CooldownNotElapsed();
    error InvalidRequestIndex();
    error TransferFailed();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event DelegationInitiated(address indexed user, address indexed validator, uint256 amount);
    event UndelegationRequested(address indexed user, address indexed validator, uint256 amount, uint256 claimableAt);
    event UndelegatedAssetsClaimed(address indexed user, address indexed validator, uint256 amount);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event MinDelegationAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------
    struct UndelegationRequest {
        address validator;
        uint256 amount;
        uint256 claimableAt;
        bool claimed;
    }

    // -----------------------------------------------------------------------
    // Constants & Immutables
    // -----------------------------------------------------------------------
    uint256 public constant UNDELEGATION_COOLDOWN = 7 days;
    uint256 public constant MIN_MIN_DELEGATION_AMOUNT = 100;

    // -----------------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------------
    address public operator;
    uint256 public minDelegationAmount;

    mapping(address => bool) public isValidator;
    mapping(address => uint256) public validatorTotalDelegated;
    mapping(address => mapping(address => uint256)) public userDelegations; // user => validator => active amount
    mapping(address => UndelegationRequest[]) public undelegationRequests;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier onlyValidValidator(address validator) {
        if (!isValidator[validator]) revert InvalidValidator();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        minDelegationAmount = MIN_MIN_DELEGATION_AMOUNT;
        emit MinDelegationAmountUpdated(0, minDelegationAmount);
    }

    // -----------------------------------------------------------------------
    // Operator Administration
    // -----------------------------------------------------------------------

    /**
     * @notice Transfers operator privileges to a new address.
     * @param newOperator The address of the new operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorTransferred(previous, newOperator);
    }

    /**
     * @notice Adds a validator to the approved list.
     * @param validator The address of the validator to add.
     */
    function addValidator(address validator) external onlyOperator {
        if (validator == address(0)) revert ZeroAddress();
        if (isValidator[validator]) revert ValidatorAlreadyExists();
        isValidator[validator] = true;
        emit ValidatorAdded(validator);
    }

    /**
     * @notice Removes a validator from the approved list.
     * @param validator The address of the validator to remove.
     */
    function removeValidator(address validator) external onlyOperator {
        if (!isValidator[validator]) revert ValidatorNotFound();
        isValidator[validator] = false;
        emit ValidatorRemoved(validator);
    }

    /**
     * @notice Sets the minimum delegation amount required for new delegations.
     * @param amount The new minimum delegation amount (must be >= 100).
     */
    function setMinDelegationAmount(uint256 amount) external onlyOperator {
        if (amount < MIN_MIN_DELEGATION_AMOUNT) revert InsufficientDelegationAmount();
        uint256 oldAmount = minDelegationAmount;
        minDelegationAmount = amount;
        emit MinDelegationAmountUpdated(oldAmount, amount);
    }

    // -----------------------------------------------------------------------
    // User Staking Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Initiates a delegation of native assets to a validator.
     * @param validator The address of the validator to delegate to.
     */
    function initiateDelegation(address validator) external payable onlyValidValidator(validator) {
        if (msg.value == 0) revert InvalidAmount();
        if (msg.value < minDelegationAmount) revert InsufficientDelegationAmount();

        userDelegations[msg.sender][validator] += msg.value;
        validatorTotalDelegated[validator] += msg.value;

        emit DelegationInitiated(msg.sender, validator, msg.value);
    }

    /**
     * @notice Requests to undelegate a specified amount of assets from a validator.
     *         The assets enter a 7-day cooldown before becoming claimable.
     * @param validator The address of the validator.
     * @param amount The amount of assets to undelegate.
     */
    function requestUndelegation(address validator, uint256 amount) external onlyValidValidator(validator) {
        if (amount == 0) revert InvalidAmount();
        if (userDelegations[msg.sender][validator] < amount) revert InsufficientDelegation();

        // Effects
        userDelegations[msg.sender][validator] -= amount;
        validatorTotalDelegated[validator] -= amount;

        uint256 claimableAt = block.timestamp + UNDELEGATION_COOLDOWN;
        undelegationRequests[msg.sender].push(
            UndelegationRequest({
                validator: validator,
                amount: amount,
                claimableAt: claimableAt,
                claimed: false
            })
        );

        emit UndelegationRequested(msg.sender, validator, amount, claimableAt);
    }

    /**
     * @notice Claims undelegated assets after the cooldown period has elapsed.
     * @param index The index of the undelegation request in the caller's list.
     */
    function claimUndelegated(uint256 index) external {
        UndelegationRequest[] storage requests = undelegationRequests[msg.sender];
        if (index >= requests.length) revert InvalidRequestIndex();

        UndelegationRequest storage req = requests[index];
        if (req.claimed) revert NoClaimableAssets();
        if (req.amount == 0) revert NoClaimableAssets();
        if (block.timestamp < req.claimableAt) revert CooldownNotElapsed();

        // Effects
        uint256 amount = req.amount;
        req.claimed = true;
        req.amount = 0;

        emit UndelegatedAssetsClaimed(msg.sender, req.validator, amount);

        // Interactions
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Returns the active delegation amount for a user and validator.
     * @param user The address of the delegator.
     * @param validator The address of the validator.
     * @return The currently delegated amount.
     */
    function getUserDelegation(address user, address validator) external view returns (uint256) {
        return userDelegations[user][validator];
    }

    /**
     * @notice Returns the total amount delegated to a validator.
     * @param validator The address of the validator.
     * @return The total delegated amount.
     */
    function getValidatorTotalDelegated(address validator) external view returns (uint256) {
        return validatorTotalDelegated[validator];
    }

    /**
     * @notice Returns the number of undelegation requests for a user.
     * @param user The address of the delegator.
     * @return The count of undelegation requests.
     */
    function getUndelegationRequestCount(address user) external view returns (uint256) {
        return undelegationRequests[user].length;
    }

    /**
     * @notice Returns a specific undelegation request for a user.
     * @param user The address of the delegator.
     * @param index The index of the request.
     * @return validator The validator address.
     * @return amount The undelegated amount.
     * @return claimableAt The timestamp when the amount becomes claimable.
     * @return claimed Whether the request has been claimed.
     */
    function getUndelegationRequest(address user, uint256 index)
        external
        view
        returns (address validator, uint256 amount, uint256 claimableAt, bool claimed)
    {
        UndelegationRequest storage req = undelegationRequests[user][index];
        return (req.validator, req.amount, req.claimableAt, req.claimed);
    }

    /**
     * @notice Returns all undelegation requests for a user.
     * @param user The address of the delegator.
     * @return An array of undelegation requests.
     */
    function getUndelegationRequests(address user) external view returns (UndelegationRequest[] memory) {
        return undelegationRequests[user];
    }

    // -----------------------------------------------------------------------
    // Receive
    // -----------------------------------------------------------------------

    /// @dev Allows the contract to receive native assets directly, though the primary flow is via initiateDelegation.
    receive() external payable {}
}
