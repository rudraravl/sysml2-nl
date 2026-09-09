// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenLaunchpad
 * @notice Facilitates the creation and launch of new fungible tokens. The owner
 *         creates a launch by supplying a project token (which is held in escrow
 *         by this contract) and a base token that participants deposit in order
 *         to receive a proportional allocation of the project token. A launch
 *         must reach a minimum funding goal of 100 base tokens within 72 hours
 *         to be considered successful; otherwise all deposited base tokens are
 *         refundable to their original depositors.
 */
contract TokenLaunchpad {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error LaunchNotFound();
    error LaunchNotActive();
    error LaunchAlreadyFinalized();
    error GoalTooLow();
    error GoalAlreadyReached();
    error NothingToClaim();
    error AlreadyClaimed();
    error NoRefundAvailable();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LaunchCreated(
        uint256 indexed launchId,
        address indexed projectToken,
        address indexed baseToken,
        uint256 goal,
        uint256 deadline
    );
    event MinFundingGoalSet(uint256 indexed launchId, uint256 oldGoal, uint256 newGoal);
    event TokensDeposited(
        uint256 indexed launchId,
        address indexed participant,
        uint256 amount,
        uint256 totalRaised
    );
    event LaunchFinalized(
        uint256 indexed launchId,
        bool successful,
        uint256 totalRaised,
        uint256 projectTokenSupply
    );
    event ProjectTokensClaimed(
        uint256 indexed launchId,
        address indexed participant,
        uint256 projectTokenAmount
    );
    event BaseTokensRefunded(
        uint256 indexed launchId,
        address indexed participant,
        uint256 baseTokenAmount
    );
    event UnclaimedProjectTokensWithdrawn(
        uint256 indexed launchId,
        address indexed recipient,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            LAUNCH STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Launch {
        address projectToken;
        address baseToken;
        uint256 goal;
        uint256 deadline;
        uint256 totalRaised;
        uint256 projectTokenSupply;
        bool finalized;
        bool successful;
        mapping(address => uint256) contributions;
        mapping(address => bool) claimed;
    }

    /// @notice Minimum funding goal enforced for every launch (100 base tokens).
    uint256 public constant MIN_FUNDING_GOAL = 100;

    /// @notice Duration of each launch's funding window (72 hours).
    uint256 public constant LAUNCH_DURATION = 72 hours;

    address public owner;

    uint256 public launchCount;

    mapping(uint256 => Launch) private _launches;

    /*//////////////////////////////////////////////////////////////
                              ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                              OWNER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new token launch. The caller must have approved this
     *         contract to transfer `projectTokenAmount` of `projectToken`.
     * @param projectToken   The address of the token being launched.
     * @param baseToken      The address of the token accepted for funding.
     * @param goal           The minimum funding goal in base tokens (>= 100).
     * @param projectTokenAmount The amount of project tokens to escrow.
     * @return launchId     The identifier of the newly created launch.
     */
    function createLaunch(
        address projectToken,
        address baseToken,
        uint256 goal,
        uint256 projectTokenAmount
    ) external onlyOwner returns (uint256 launchId) {
        if (projectToken == address(0) || baseToken == address(0)) revert ZeroAddress();
        if (projectTokenAmount == 0) revert ZeroAmount();
        if (goal < MIN_FUNDING_GOAL) revert GoalTooLow();

        launchId = launchCount++;

        Launch storage launch = _launches[launchId];
        launch.projectToken = projectToken;
        launch.baseToken = baseToken;
        launch.goal = goal;
        launch.deadline = block.timestamp + LAUNCH_DURATION;
        launch.projectTokenSupply = projectTokenAmount;

        _safeTransferFrom(projectToken, msg.sender, address(this), projectTokenAmount);

        emit LaunchCreated(launchId, projectToken, baseToken, goal, launch.deadline);
    }

    /**
     * @notice Sets (or updates) the minimum funding goal for a launch. The goal
     *         may only be adjusted while the launch is still active and has not
     *         yet reached its current goal.
     * @param launchId The identifier of the launch.
     * @param newGoal  The new minimum funding goal (>= 100).
     */
    function setMinFundingGoal(uint256 launchId, uint256 newGoal) external onlyOwner {
        Launch storage launch = _getLaunch(launchId);
        if (newGoal < MIN_FUNDING_GOAL) revert GoalTooLow();
        if (launch.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp >= launch.deadline) revert LaunchNotActive();
        if (launch.totalRaised >= launch.goal) revert GoalAlreadyReached();

        uint256 oldGoal = launch.goal;
        launch.goal = newGoal;

        emit MinFundingGoalSet(launchId, oldGoal, newGoal);
    }

    /**
     * @notice Finalizes a launch after its deadline. If the funding goal was
     *         met, the launch is marked successful and participants may claim
     *         their proportional share of the project tokens. Otherwise the
     *         launch is marked failed and participants may withdraw refunds.
     * @param launchId The identifier of the launch.
     */
    function finalizeLaunch(uint256 launchId) external onlyOwner {
        Launch storage launch = _getLaunch(launchId);
        if (launch.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp < launch.deadline) revert LaunchNotActive();

        launch.finalized = true;
        launch.successful = launch.totalRaised >= launch.goal;

        emit LaunchFinalized(
            launchId,
            launch.successful,
            launch.totalRaised,
            launch.projectTokenSupply
        );
    }

    /**
     * @notice Allows the owner to withdraw any remaining unclaimed project
     *         tokens after a successful launch has been finalized. This
     *         handles dust from rounding as well as tokens that were never
     *         claimed by participants.
     * @param launchId The identifier of the launch.
     */
    function withdrawUnclaimedProjectTokens(uint256 launchId) external onlyOwner {
        Launch storage launch = _getLaunch(launchId);
        if (!launch.finalized) revert LaunchNotActive();
        if (!launch.successful) revert LaunchNotActive();

        uint256 balance = _balanceOf(launch.projectToken, address(this));
        if (balance == 0) revert ZeroAmount();

        _safeTransfer(launch.projectToken, msg.sender, balance);

        emit UnclaimedProjectTokensWithdrawn(launchId, msg.sender, balance);
    }

    /*//////////////////////////////////////////////////////////////
                            PARTICIPANT ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits base tokens into an active launch. The caller must
     *         have approved this contract to spend `amount` of the base token.
     * @param launchId The identifier of the launch.
     * @param amount   The amount of base tokens to deposit.
     */
    function deposit(uint256 launchId, uint256 amount) external {
        Launch storage launch = _getLaunch(launchId);
        if (amount == 0) revert ZeroAmount();
        if (launch.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp >= launch.deadline) revert LaunchNotActive();

        launch.contributions[msg.sender] += amount;
        launch.totalRaised += amount;

        _safeTransferFrom(launch.baseToken, msg.sender, address(this), amount);

        emit TokensDeposited(launchId, msg.sender, amount, launch.totalRaised);
    }

    /**
     * @notice Claims a participant's allocated share of the project tokens
     *         after a launch has been successfully finalized.
     * @param launchId The identifier of the launch.
     * @return claimedAmount The amount of project tokens transferred.
     */
    function claimTokens(uint256 launchId) external returns (uint256 claimedAmount) {
        Launch storage launch = _getLaunch(launchId);
        if (!launch.finalized) revert LaunchNotActive();
        if (!launch.successful) revert LaunchNotActive();
        if (launch.claimed[msg.sender]) revert AlreadyClaimed();

        uint256 contribution = launch.contributions[msg.sender];
        if (contribution == 0) revert NothingToClaim();

        launch.claimed[msg.sender] = true;

        claimedAmount =
            (launch.projectTokenSupply * contribution) /
            launch.totalRaised;

        _safeTransfer(launch.projectToken, msg.sender, claimedAmount);

        emit ProjectTokensClaimed(launchId, msg.sender, claimedAmount);
    }

    /**
     * @notice Withdraws a participant's deposited base tokens when a launch
     *         failed to meet its funding goal.
     * @param launchId The identifier of the launch.
     * @return refundAmount The amount of base tokens refunded.
     */
    function withdrawRefund(uint256 launchId) external returns (uint256 refundAmount) {
        Launch storage launch = _getLaunch(launchId);
        if (!launch.finalized) revert LaunchNotActive();
        if (launch.successful) revert GoalAlreadyReached();

        refundAmount = launch.contributions[msg.sender];
        if (refundAmount == 0) revert NoRefundAvailable();

        launch.contributions[msg.sender] = 0;

        _safeTransfer(launch.baseToken, msg.sender, refundAmount);

        emit BaseTokensRefunded(launchId, msg.sender, refundAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the core parameters of a launch.
     */
    function getLaunch(uint256 launchId)
        external
        view
        returns (
            address projectToken,
            address baseToken,
            uint256 goal,
            uint256 deadline,
            uint256 totalRaised,
            uint256 projectTokenSupply,
            bool finalized,
            bool successful
        )
    {
        Launch storage launch = _getLaunch(launchId);
        return (
            launch.projectToken,
            launch.baseToken,
            launch.goal,
            launch.deadline,
            launch.totalRaised,
            launch.projectTokenSupply,
            launch.finalized,
            launch.successful
        );
    }

    /**
     * @notice Returns a participant's base token contribution to a launch.
     */
    function contributionOf(uint256 launchId, address participant)
        external
        view
        returns (uint256)
    {
        return _getLaunch(launchId).contributions[participant];
    }

    /**
     * @notice Returns whether a participant has claimed their project tokens.
     */
    function hasClaimed(uint256 launchId, address participant) external view returns (bool) {
        return _getLaunch(launchId).claimed[participant];
    }

    /**
     * @notice Returns the amount of project tokens a participant would receive
     *         if the launch were finalized successfully right now.
     */
    function previewClaim(uint256 launchId, address participant)
        external
        view
        returns (uint256)
    {
        Launch storage launch = _getLaunch(launchId);
        uint256 contribution = launch.contributions[participant];
        if (contribution == 0 || launch.totalRaised == 0) return 0;
        return (launch.projectTokenSupply * contribution) / launch.totalRaised;
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _getLaunch(uint256 launchId) internal view returns (Launch storage) {
        if (launchId >= launchCount) revert LaunchNotFound();
        return _launches[launchId];
    }

    function _balanceOf(address token, address account) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(0x70a08231, account)
        );
        if (!success || data.length == 0) return 0;
        return abi.decode(data, (uint256));
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
