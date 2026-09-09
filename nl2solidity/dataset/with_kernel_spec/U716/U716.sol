// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

/**
 * @title ResearchFunding
 * @notice A crowdfunding platform for scientific research projects. Users deposit
 *         stablecoins into approved projects. Successful projects distribute reward
 *         tokens pro-rata to contributors and forward raised stablecoins (minus a 5%
 *         platform fee) to the project beneficiary. Failed projects allow refunds.
 */
contract ResearchFunding {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @notice Minimum stablecoin amount a project must raise to be marked successful.
    uint256 public constant MINIMUM_GOAL = 10_000 * 1e18;

    /// @notice Platform fee in basis points (5%).
    uint256 public constant PLATFORM_FEE_BPS = 500;

    /// @notice Basis points denominator.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // -----------------------------------------------------------------------
    // Enums
    // -----------------------------------------------------------------------

    enum ProjectStatus {
        Funding,
        Successful,
        Failed
    }

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------

    struct Project {
        address beneficiary;
        address rewardToken;
        uint256 fundingGoal;
        uint256 deadline;
        uint256 totalRaised;
        uint256 totalRewardTokens;
        uint256 totalClaimedTokens;
        ProjectStatus status;
        bool exists;
    }

    struct Contributor {
        uint256 contribution;
        bool claimedTokens;
        bool withdrawnRefund;
    }

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------

    /// @notice The stablecoin used for all project funding.
    IERC20 public immutable stablecoin;

    /// @notice Administrator who approves and finalizes projects.
    address public admin;

    /// @notice Recipient of the 5% platform fee.
    address public feeRecipient;

    /// @notice Counter for the next project ID.
    uint256 public nextProjectId;

    /// @notice Reentrancy guard status.
    uint256 private _status;

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => Contributor)) public contributors;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event ProjectApproved(
        uint256 indexed projectId,
        address indexed beneficiary,
        address indexed rewardToken,
        uint256 fundingGoal,
        uint256 deadline
    );
    event ContributionMade(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );
    event ProjectStatusChanged(uint256 indexed projectId, ProjectStatus newStatus);
    event ProjectFunded(
        uint256 indexed projectId,
        uint256 amountToBeneficiary,
        uint256 feeAmount
    );
    event TokensClaimed(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 tokenAmount
    );
    event RefundWithdrawn(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 refundAmount
    );
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error ErrNotAdmin();
    error ErrZeroAddress();
    error ErrProjectDoesNotExist();
    error ErrProjectNotFunding();
    error ErrProjectNotSuccessful();
    error ErrProjectNotFailed();
    error ErrDeadlinePassed();
    error ErrDeadlineNotPassed();
    error ErrGoalBelowMinimum();
    error ErrGoalNotMet();
    error ErrZeroAmount();
    error ErrAlreadyClaimed();
    error ErrAlreadyWithdrawn();
    error ErrNoContribution();
    error ErrTransferFailed();
    error ErrReentrantCall();

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyAdmin() {
        if (msg.sender != admin) revert ErrNotAdmin();
        _;
    }

    modifier projectExists(uint256 projectId) {
        if (!projects[projectId].exists) revert ErrProjectDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ErrReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param stablecoin_   The ERC20 stablecoin used for contributions.
     * @param admin_        The initial administrator.
     * @param feeRecipient_ The initial fee recipient.
     */
    constructor(address stablecoin_, address admin_, address feeRecipient_) {
        if (stablecoin_ == address(0)) revert ErrZeroAddress();
        if (admin_ == address(0)) revert ErrZeroAddress();
        if (feeRecipient_ == address(0)) revert ErrZeroAddress();

        stablecoin = IERC20(stablecoin_);
        admin = admin_;
        feeRecipient = feeRecipient_;
        _status = 1;
    }

    // -----------------------------------------------------------------------
    // Admin functions
    // -----------------------------------------------------------------------

    /**
     * @notice Approve a new research project. Only callable by the admin.
     * @param beneficiary   Address that will receive raised stablecoins on success.
     * @param rewardToken   ERC20 token distributed pro-rata to contributors on success.
     * @param fundingGoal   Minimum stablecoin amount the project aims to raise.
     * @param deadline      UNIX timestamp after which deposits are rejected.
     * @return projectId    The ID of the newly created project.
     */
    function approveProject(
        address beneficiary,
        address rewardToken,
        uint256 fundingGoal,
        uint256 deadline
    ) external onlyAdmin returns (uint256 projectId) {
        if (beneficiary == address(0)) revert ErrZeroAddress();
        if (rewardToken == address(0)) revert ErrZeroAddress();
        if (fundingGoal < MINIMUM_GOAL) revert ErrGoalBelowMinimum();
        if (deadline <= block.timestamp) revert ErrDeadlinePassed();

        projectId = nextProjectId++;
        projects[projectId] = Project({
            beneficiary: beneficiary,
            rewardToken: rewardToken,
            fundingGoal: fundingGoal,
            deadline: deadline,
            totalRaised: 0,
            totalRewardTokens: 0,
            totalClaimedTokens: 0,
            status: ProjectStatus.Funding,
            exists: true
        });

        emit ProjectApproved(projectId, beneficiary, rewardToken, fundingGoal, deadline);
        emit ProjectStatusChanged(projectId, ProjectStatus.Funding);
    }

    /**
     * @notice Mark a project as successful after its deadline has passed and the
     *         funding goal has been met. Pulls reward tokens from the admin and
     *         distributes raised stablecoins: 95% to the beneficiary, 5% to the
     *         fee recipient.
     * @param projectId         The project to finalize.
     * @param rewardTokenAmount Total reward tokens to distribute to contributors.
     */
    function markSuccessful(uint256 projectId, uint256 rewardTokenAmount)
        external
        onlyAdmin
        projectExists(projectId)
        nonReentrant
    {
        Project storage project = projects[projectId];
        if (project.status != ProjectStatus.Funding) revert ErrProjectNotFunding();
        if (block.timestamp < project.deadline) revert ErrDeadlineNotPassed();
        if (project.totalRaised < project.fundingGoal) revert ErrGoalNotMet();
        if (rewardTokenAmount == 0) revert ErrZeroAmount();

        // Effects: update status and reward supply before external interactions.
        project.status = ProjectStatus.Successful;
        project.totalRewardTokens = rewardTokenAmount;

        // Interactions: pull reward tokens from the admin into this contract.
        bool rewardOk = IERC20(project.rewardToken).transferFrom(
            msg.sender,
            address(this),
            rewardTokenAmount
        );
        if (!rewardOk) revert ErrTransferFailed();

        // Distribute raised stablecoins: 5% fee, 95% to beneficiary.
        uint256 feeAmount = (project.totalRaised * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountToBeneficiary = project.totalRaised - feeAmount;

        bool feeOk = stablecoin.transfer(feeRecipient, feeAmount);
        if (!feeOk) revert ErrTransferFailed();

        bool benOk = stablecoin.transfer(project.beneficiary, amountToBeneficiary);
        if (!benOk) revert ErrTransferFailed();

        emit ProjectFunded(projectId, amountToBeneficiary, feeAmount);
        emit ProjectStatusChanged(projectId, ProjectStatus.Successful);
    }

    /**
     * @notice Mark a project as failed after its deadline has passed. Contributors
     *         may then withdraw their stablecoin contributions.
     * @param projectId The project to mark as failed.
     */
    function markFailed(uint256 projectId) external onlyAdmin projectExists(projectId) {
        Project storage project = projects[projectId];
        if (project.status != ProjectStatus.Funding) revert ErrProjectNotFunding();
        if (block.timestamp < project.deadline) revert ErrDeadlineNotPassed();

        project.status = ProjectStatus.Failed;
        emit ProjectStatusChanged(projectId, ProjectStatus.Failed);
    }

    /**
     * @notice Update the fee recipient address.
     * @param newFeeRecipient The new fee recipient.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyAdmin {
        if (newFeeRecipient == address(0)) revert ErrZeroAddress();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    /**
     * @notice Transfer the admin role to a new address.
     * @param newAdmin The new administrator.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ErrZeroAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    // -----------------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit stablecoins into an active project.
     * @param projectId The project to fund.
     * @param amount    The amount of stablecoins to deposit.
     */
    function deposit(uint256 projectId, uint256 amount)
        external
        projectExists(projectId)
        nonReentrant
    {
        Project storage project = projects[projectId];
        if (project.status != ProjectStatus.Funding) revert ErrProjectNotFunding();
        if (block.timestamp >= project.deadline) revert ErrDeadlinePassed();
        if (amount == 0) revert ErrZeroAmount();

        // Effects: update state before the external transfer.
        project.totalRaised += amount;
        contributors[projectId][msg.sender].contribution += amount;

        // Interactions: pull stablecoins from the contributor.
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert ErrTransferFailed();

        emit ContributionMade(projectId, msg.sender, amount);
    }

    /**
     * @notice Claim a pro-rata share of reward tokens from a successful project.
     * @param projectId The successful project.
     */
    function claimTokens(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage project = projects[projectId];
        if (project.status != ProjectStatus.Successful) revert ErrProjectNotSuccessful();

        Contributor storage c = contributors[projectId][msg.sender];
        if (c.contribution == 0) revert ErrNoContribution();
        if (c.claimedTokens) revert ErrAlreadyClaimed();

        uint256 tokenAmount = (c.contribution * project.totalRewardTokens) / project.totalRaised;

        // Effects: mark claimed and update totals before transfer.
        c.claimedTokens = true;
        project.totalClaimedTokens += tokenAmount;

        // Interactions: transfer reward tokens to the contributor.
        bool ok = IERC20(project.rewardToken).transfer(msg.sender, tokenAmount);
        if (!ok) revert ErrTransferFailed();

        emit TokensClaimed(projectId, msg.sender, tokenAmount);
    }

    /**
     * @notice Withdraw a stablecoin refund from a failed project.
     * @param projectId The failed project.
     */
    function withdrawRefund(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage project = projects[projectId];
        if (project.status != ProjectStatus.Failed) revert ErrProjectNotFailed();

        Contributor storage c = contributors[projectId][msg.sender];
        if (c.contribution == 0) revert ErrNoContribution();
        if (c.withdrawnRefund) revert ErrAlreadyWithdrawn();

        // Effects: zero out contribution before sending funds.
        uint256 refundAmount = c.contribution;
        c.withdrawnRefund = true;
        c.contribution = 0;

        // Interactions: return the contributor's stablecoins.
        bool ok = stablecoin.transfer(msg.sender, refundAmount);
        if (!ok) revert ErrTransferFailed();

        emit RefundWithdrawn(projectId, msg.sender, refundAmount);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /**
     * @notice Retrieve full project details.
     */
    function getProject(uint256 projectId)
        external
        view
        projectExists(projectId)
        returns (
            address beneficiary,
            address rewardToken,
            uint256 fundingGoal,
            uint256 deadline,
            uint256 totalRaised,
            uint256 totalRewardTokens,
            uint256 totalClaimedTokens,
            ProjectStatus status
        )
    {
        Project storage p = projects[projectId];
        return (
            p.beneficiary,
            p.rewardToken,
            p.fundingGoal,
            p.deadline,
            p.totalRaised,
            p.totalRewardTokens,
            p.totalClaimedTokens,
            p.status
        );
    }

    /**
     * @notice Retrieve a contributor's state for a project.
     */
    function getContribution(uint256 projectId, address contributor)
        external
        view
        projectExists(projectId)
        returns (uint256 contribution, bool claimedTokens, bool withdrawnRefund)
    {
        Contributor storage c = contributors[projectId][contributor];
        return (c.contribution, c.claimedTokens, c.withdrawnRefund);
    }

    /**
     * @notice Preview the reward token amount a contributor would receive.
     */
    function pendingTokenClaim(uint256 projectId, address contributor)
        external
        view
        projectExists(projectId)
        returns (uint256)
    {
        Project storage p = projects[projectId];
        Contributor storage c = contributors[projectId][contributor];
        if (p.status != ProjectStatus.Successful || c.contribution == 0 || c.claimedTokens) {
            return 0;
        }
        return (c.contribution * p.totalRewardTokens) / p.totalRaised;
    }
}
