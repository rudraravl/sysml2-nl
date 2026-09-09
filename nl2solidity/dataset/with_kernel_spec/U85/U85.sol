// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DistributedValidatorCluster
/// @notice Manages distributed validator clusters for Ethereum staking,
///         custodying deposited Ether and associated validator credentials.
contract DistributedValidatorCluster {
    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------
    error NotOwner();
    error ZeroAddress();
    error ClusterDoesNotExist();
    error InvalidOperatorCount(uint256 provided, uint256 min, uint256 max);
    error OperatorNotApproved(address operator);
    error DuplicateOperator(address operator);
    error DepositsPaused();
    error ClusterNotActive();
    error ClusterNotCompleted();
    error InsufficientStake();
    error NotClusterOperator();
    error AlreadyAttested();
    error LengthMismatch();
    error InsufficientRewards();
    error NothingToWithdraw();
    error InvalidFee(uint256 provided, uint256 max);
    error AlreadyApproved();
    error NotApproved();
    error TransferFailed();
    error ReentrantCall();
    error SameState();

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------
    event ClusterCreated(
        uint256 indexed clusterId,
        address indexed creator,
        address[] operators,
        uint256 operatorCount,
        bytes32 withdrawalCredentials
    );
    event Deposited(uint256 indexed clusterId, address indexed depositor, uint256 amount, uint256 totalStaked);
    event Withdrawn(
        uint256 indexed clusterId,
        address indexed user,
        uint256 stakeAmount,
        uint256 rewardAmount,
        uint256 feeAmount
    );
    event DutyAttested(uint256 indexed clusterId, address indexed operator, uint256 attestationCount);
    event ClusterCompleted(uint256 indexed clusterId, uint256 totalStaked, uint256 totalRewards);
    event RewardsDistributed(uint256 indexed clusterId, address indexed distributor, uint256 totalDistributed);
    event StakingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event DepositPauseToggled(bool paused);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    uint256 public constant MIN_OPERATORS = 4;
    uint256 public constant MAX_OPERATORS = 7;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 1000; // 10%

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------
    struct Cluster {
        address creator;
        uint256 totalStaked;
        uint256 totalRewards;
        uint256 operatorCount;
        uint256 attestationCount;
        bool isCompleted;
        bool exists;
    }

    struct ClusterInfoView {
        address creator;
        uint256 totalStaked;
        uint256 totalRewards;
        uint256 operatorCount;
        uint256 attestationCount;
        bool isCompleted;
        bytes32 withdrawalCredentials;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------
    address public owner;
    uint256 public stakingFeeBps;
    bool public depositsPaused;
    uint256 public clusterCount;

    mapping(address => bool) public approvedOperators;
    address[] internal _approvedOperatorList;

    mapping(uint256 => Cluster) public clusters;
    mapping(uint256 => bytes32) public clusterWithdrawalCredentials;
    mapping(uint256 => address[]) public clusterOperators;
    mapping(uint256 => mapping(address => bool)) public isClusterOperator;
    mapping(uint256 => mapping(address => bool)) public operatorAttested;
    mapping(uint256 => mapping(address => uint256)) public userStaked;
    mapping(uint256 => mapping(address => uint256)) public userRewards;
    mapping(uint256 => address[]) internal _clusterParticipants;

    // ---------------------------------------------------------------
    // Reentrancy Guard
    // ---------------------------------------------------------------
    uint256 private _status = 1;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier clusterExists(uint256 clusterId) {
        if (!clusters[clusterId].exists) revert ClusterDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------
    constructor() {
        owner = msg.sender;
        stakingFeeBps = DEFAULT_FEE_BPS;
        emit OwnershipTransferred(address(0), msg.sender);
        emit StakingFeeUpdated(0, stakingFeeBps);
    }

    // ---------------------------------------------------------------
    // Internal Helpers
    // ---------------------------------------------------------------
    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    // ---------------------------------------------------------------
    // Owner / Administrative Functions
    // ---------------------------------------------------------------

    /// @notice Transfers contract ownership to a new address.
    /// @param newOwner The address of the new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /// @notice Sets the global staking fee in basis points (max 10000 = 100%).
    /// @param newFeeBps New fee expressed in basis points.
    function setStakingFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > BASIS_POINTS) revert InvalidFee(newFeeBps, BASIS_POINTS);
        uint256 old = stakingFeeBps;
        stakingFeeBps = newFeeBps;
        emit StakingFeeUpdated(old, newFeeBps);
    }

    /// @notice Pauses or unpauses all deposits across every cluster.
    /// @param paused True to pause deposits, false to resume.
    function setDepositsPaused(bool paused) external onlyOwner {
        if (depositsPaused == paused) revert SameState();
        depositsPaused = paused;
        emit DepositPauseToggled(paused);
    }

    /// @notice Adds an address to the globally approved operator set.
    /// @param operator The address to approve as an operator.
    function addOperator(address operator) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        if (approvedOperators[operator]) revert AlreadyApproved();
        approvedOperators[operator] = true;
        _approvedOperatorList.push(operator);
        emit OperatorAdded(operator);
    }

    /// @notice Removes an address from the globally approved operator set.
    /// @param operator The address to remove from the approved operator set.
    function removeOperator(address operator) external onlyOwner {
        if (!approvedOperators[operator]) revert NotApproved();
        approvedOperators[operator] = false;
        uint256 len = _approvedOperatorList.length;
        for (uint256 i = 0; i < len; ) {
            if (_approvedOperatorList[i] == operator) {
                _approvedOperatorList[i] = _approvedOperatorList[len - 1];
                _approvedOperatorList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit OperatorRemoved(operator);
    }

    /// @notice Force-completes a cluster, enabling withdrawals.
    /// @param clusterId The id of the cluster to complete.
    function completeCluster(uint256 clusterId) external onlyOwner clusterExists(clusterId) {
        Cluster storage c = clusters[clusterId];
        if (c.isCompleted) revert ClusterNotActive();
        c.isCompleted = true;
        emit ClusterCompleted(clusterId, c.totalStaked, c.totalRewards);
    }

    // ---------------------------------------------------------------
    // Cluster Lifecycle Functions
    // ---------------------------------------------------------------

    /// @notice Creates a new validator cluster with 4–7 approved operators.
    /// @param operators The list of approved operator addresses for this cluster.
    /// @param withdrawalCredentials The validator withdrawal credentials associated with the cluster.
    /// @return clusterId The id assigned to the newly created cluster.
    function createCluster(address[] calldata operators, bytes32 withdrawalCredentials)
        external
        returns (uint256)
    {
        uint256 opCount = operators.length;
        if (opCount < MIN_OPERATORS || opCount > MAX_OPERATORS) {
            revert InvalidOperatorCount(opCount, MIN_OPERATORS, MAX_OPERATORS);
        }

        uint256 clusterId = clusterCount++;
        Cluster storage cluster = clusters[clusterId];
        cluster.creator = msg.sender;
        cluster.operatorCount = opCount;
        cluster.exists = true;

        for (uint256 i = 0; i < opCount; ) {
            address op = operators[i];
            if (op == address(0)) revert ZeroAddress();
            if (!approvedOperators[op]) revert OperatorNotApproved(op);
            if (isClusterOperator[clusterId][op]) revert DuplicateOperator(op);
            isClusterOperator[clusterId][op] = true;
            clusterOperators[clusterId].push(op);
            unchecked {
                ++i;
            }
        }

        clusterWithdrawalCredentials[clusterId] = withdrawalCredentials;

        emit ClusterCreated(clusterId, msg.sender, operators, opCount, withdrawalCredentials);
        return clusterId;
    }

    /// @notice Deposits Ether into an active cluster.
    /// @param clusterId The id of the cluster to deposit into.
    function deposit(uint256 clusterId) external payable clusterExists(clusterId) nonReentrant {
        if (depositsPaused) revert DepositsPaused();
        Cluster storage cluster = clusters[clusterId];
        if (cluster.isCompleted) revert ClusterNotActive();
        if (msg.value == 0) revert InsufficientStake();

        if (userStaked[clusterId][msg.sender] == 0) {
            _clusterParticipants[clusterId].push(msg.sender);
        }
        userStaked[clusterId][msg.sender] += msg.value;
        cluster.totalStaked += msg.value;

        emit Deposited(clusterId, msg.sender, msg.value, cluster.totalStaked);
    }

    /// @notice Allows a cluster operator to attest to validator duties.
    /// @dev Auto-completes the cluster when all operators have attested.
    /// @param clusterId The id of the cluster the operator is attesting for.
    function attestDuty(uint256 clusterId) external clusterExists(clusterId) {
        if (!isClusterOperator[clusterId][msg.sender]) revert NotClusterOperator();
        if (operatorAttested[clusterId][msg.sender]) revert AlreadyAttested();
        Cluster storage cluster = clusters[clusterId];
        if (cluster.isCompleted) revert ClusterNotActive();

        operatorAttested[clusterId][msg.sender] = true;
        cluster.attestationCount += 1;

        emit DutyAttested(clusterId, msg.sender, cluster.attestationCount);

        if (cluster.attestationCount == cluster.operatorCount) {
            cluster.isCompleted = true;
            emit ClusterCompleted(clusterId, cluster.totalStaked, cluster.totalRewards);
        }
    }

    /// @notice Distributes rewards to specified recipients within a completed cluster.
    /// @param clusterId The id of the cluster to distribute rewards for.
    /// @param recipients The list of recipient addresses.
    /// @param amounts The list of reward amounts corresponding to each recipient.
    function distributeRewards(
        uint256 clusterId,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable clusterExists(clusterId) nonReentrant {
        if (recipients.length != amounts.length) revert LengthMismatch();
        if (msg.sender != owner && !isClusterOperator[clusterId][msg.sender]) revert NotClusterOperator();
        Cluster storage cluster = clusters[clusterId];
        if (!cluster.isCompleted) revert ClusterNotCompleted();
        if (msg.value == 0) revert InsufficientRewards();

        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; ) {
            if (amounts[i] == 0) revert InsufficientRewards();
            if (recipients[i] == address(0)) revert ZeroAddress();
            userRewards[clusterId][recipients[i]] += amounts[i];
            total += amounts[i];
            unchecked {
                ++i;
            }
        }
        if (total > msg.value) revert InsufficientRewards();

        cluster.totalRewards += total;

        uint256 refund = msg.value - total;
        if (refund > 0) {
            _safeTransfer(msg.sender, refund);
        }

        emit RewardsDistributed(clusterId, msg.sender, total);
    }

    /// @notice Withdraws staked Ether and earned rewards from a completed cluster.
    /// @dev A staking fee is applied to the reward portion and sent to the owner.
    /// @param clusterId The id of the cluster to withdraw from.
    /// @param stakeAmount The amount of staked Ether to withdraw.
    function withdraw(uint256 clusterId, uint256 stakeAmount)
        external
        clusterExists(clusterId)
        nonReentrant
    {
        Cluster storage cluster = clusters[clusterId];
        if (!cluster.isCompleted) revert ClusterNotCompleted();

        uint256 staked = userStaked[clusterId][msg.sender];
        uint256 rewards = userRewards[clusterId][msg.sender];
        if (stakeAmount > staked) revert InsufficientStake();
        if (stakeAmount == 0 && rewards == 0) revert NothingToWithdraw();

        uint256 fee = (rewards * stakingFeeBps) / BASIS_POINTS;

        // Effects
        userStaked[clusterId][msg.sender] = staked - stakeAmount;
        userRewards[clusterId][msg.sender] = 0;
        cluster.totalStaked -= stakeAmount;
        cluster.totalRewards -= rewards;

        // Interactions
        if (fee > 0) {
            _safeTransfer(owner, fee);
        }
        uint256 payout = stakeAmount + rewards - fee;
        if (payout > 0) {
            _safeTransfer(msg.sender, payout);
        }

        emit Withdrawn(clusterId, msg.sender, stakeAmount, rewards - fee, fee);
    }

    // ---------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------

    /// @notice Returns the operators of a given cluster.
    /// @param clusterId The id of the cluster.
    /// @return The array of operator addresses for the cluster.
    function getClusterOperators(uint256 clusterId)
        external
        view
        clusterExists(clusterId)
        returns (address[] memory)
    {
        return clusterOperators[clusterId];
    }

    /// @notice Returns the list of participants who have staked in a cluster.
    /// @param clusterId The id of the cluster.
    /// @return The array of participant addresses.
    function getClusterParticipants(uint256 clusterId)
        external
        view
        clusterExists(clusterId)
        returns (address[] memory)
    {
        return _clusterParticipants[clusterId];
    }

    /// @notice Returns aggregated information about a cluster.
    /// @param clusterId The id of the cluster.
    /// @return A struct containing the cluster's key state fields.
    function getClusterInfo(uint256 clusterId)
        external
        view
        clusterExists(clusterId)
        returns (ClusterInfoView memory)
    {
        Cluster storage c = clusters[clusterId];
        return ClusterInfoView({
            creator: c.creator,
            totalStaked: c.totalStaked,
            totalRewards: c.totalRewards,
            operatorCount: c.operatorCount,
            attestationCount: c.attestationCount,
            isCompleted: c.isCompleted,
            withdrawalCredentials: clusterWithdrawalCredentials[clusterId]
        });
    }

    /// @notice Returns a user's staked and reward balances for a cluster.
    /// @param clusterId The id of the cluster.
    /// @param user The address of the user.
    /// @return staked The amount of Ether staked by the user.
    /// @return rewards The amount of rewards accrued by the user.
    function getUserPosition(uint256 clusterId, address user)
        external
        view
        clusterExists(clusterId)
        returns (uint256 staked, uint256 rewards)
    {
        return (userStaked[clusterId][user], userRewards[clusterId][user]);
    }

    /// @notice Returns whether a given operator has attested for a cluster.
    /// @param clusterId The id of the cluster.
    /// @param operator The address of the operator.
    /// @return True if the operator has attested, false otherwise.
    function hasOperatorAttested(uint256 clusterId, address operator)
        external
        view
        clusterExists(clusterId)
        returns (bool)
    {
        return operatorAttested[clusterId][operator];
    }

    /// @notice Returns the number of globally approved operators.
    /// @return The count of approved operators.
    function approvedOperatorCount() external view returns (uint256) {
        return _approvedOperatorList.length;
    }

    /// @notice Returns the full list of approved operators.
    /// @return The array of approved operator addresses.
    function getApprovedOperators() external view returns (address[] memory) {
        return _approvedOperatorList;
    }

    // ---------------------------------------------------------------
    // Fallback
    // ---------------------------------------------------------------
    /// @notice Accepts raw Ether transfers (e.g., beacon chain rewards).
    receive() external payable {}
}
