// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title Launchpad
 * @dev Manages a launchpad for new token projects, holding deposited base currency
 *      and distributing newly minted project tokens to participants upon a
 *      successful launch.
 */
contract Launchpad {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error Unauthorized();
    error ProjectDoesNotExist();
    error ZeroAddress();
    error ZeroAmount();
    error LaunchNotActive();
    error LaunchStillActive();
    error LaunchNotFinalized();
    error LaunchAlreadyFinalized();
    error LaunchFailed();
    error LaunchSuccessful();
    error FinalizationWindowClosed();
    error NothingToClaim();
    error NothingToWithdraw();
    error AllocationNotSet();
    error InvalidLaunchPeriod();
    error ReentrancyGuardReentrantCall();
    error TransferFailed();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        address token,
        uint256 launchStart,
        uint256 launchEnd
    );
    event Deposited(uint256 indexed projectId, address indexed depositor, uint256 amount);
    event ProjectFinalized(
        uint256 indexed projectId,
        bool successful,
        uint256 totalRaised,
        address recipient
    );
    event TokensClaimed(uint256 indexed projectId, address indexed claimant, uint256 tokenAmount);
    event BaseWithdrawn(uint256 indexed projectId, address indexed withdrawer, uint256 amount);
    event AllocationSet(uint256 indexed projectId, uint256 tokensPerBaseUnit);
    event LaunchPeriodSet(uint256 indexed projectId, uint256 launchStart, uint256 launchEnd);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant MINIMUM_RAISE = 100;
    uint256 public constant FINALIZATION_WINDOW = 7 days;

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------

    struct Project {
        address creator;
        address token;             // project token (must be mintable by this contract)
        address recipient;         // recipient of raised base currency on finalize
        uint256 tokensPerBaseUnit; // project tokens minted per 1 base currency unit
        uint256 launchStart;
        uint256 launchEnd;
        uint256 totalRaised;
        bool allocationSet;
        bool finalized;
        bool successful;
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    IERC20 public immutable baseCurrency;

    uint256 public nextProjectId;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public deposits;
    mapping(uint256 => mapping(address => uint256)) public claimedTokens;

    uint256 private _reentrancyStatus;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier nonReentrant() {
        if (_reentrancyStatus != 0) revert ReentrancyGuardReentrantCall();
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 0;
    }

    modifier projectExists(uint256 projectId) {
        if (projects[projectId].creator == address(0)) revert ProjectDoesNotExist();
        _;
    }

    modifier onlyCreator(uint256 projectId) {
        if (projects[projectId].creator != msg.sender) revert Unauthorized();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address _baseCurrency) {
        if (_baseCurrency == address(0)) revert ZeroAddress();
        baseCurrency = IERC20(_baseCurrency);
        nextProjectId = 1;
    }

    // -----------------------------------------------------------------------
    // External / Public functions
    // -----------------------------------------------------------------------

    /**
     * @notice Creates a new launch project.
     * @param token The project token contract (must implement IMintableERC20).
     * @param recipient The address that will receive the raised base currency.
     * @param tokensPerBaseUnit Project tokens minted per 1 base currency unit.
     * @param launchStart Timestamp when deposits open.
     * @param launchEnd Timestamp when deposits close.
     * @return projectId The id of the newly created project.
     */
    function createProject(
        address token,
        address recipient,
        uint256 tokensPerBaseUnit,
        uint256 launchStart,
        uint256 launchEnd
    ) external nonReentrant returns (uint256 projectId) {
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (tokensPerBaseUnit == 0) revert ZeroAmount();
        if (launchStart <= block.timestamp) revert InvalidLaunchPeriod();
        if (launchEnd <= launchStart) revert InvalidLaunchPeriod();

        projectId = nextProjectId++;
        Project storage p = projects[projectId];
        p.creator = msg.sender;
        p.token = token;
        p.recipient = recipient;
        p.tokensPerBaseUnit = tokensPerBaseUnit;
        p.launchStart = launchStart;
        p.launchEnd = launchEnd;
        p.allocationSet = true;

        emit ProjectCreated(projectId, msg.sender, token, launchStart, launchEnd);
        emit AllocationSet(projectId, tokensPerBaseUnit);
        emit LaunchPeriodSet(projectId, launchStart, launchEnd);
    }

    /**
     * @notice Sets the token allocation rate for a project.
     * @dev Only callable by the project creator before the launch starts.
     */
    function setAllocation(
        uint256 projectId,
        uint256 tokensPerBaseUnit
    ) external projectExists(projectId) onlyCreator(projectId) nonReentrant {
        if (tokensPerBaseUnit == 0) revert ZeroAmount();
        if (block.timestamp >= projects[projectId].launchStart) revert LaunchNotActive();
        projects[projectId].tokensPerBaseUnit = tokensPerBaseUnit;
        projects[projectId].allocationSet = true;
        emit AllocationSet(projectId, tokensPerBaseUnit);
    }

    /**
     * @notice Defines or updates the launch period for a project.
     * @dev Only callable by the project creator before the launch starts.
     */
    function setLaunchPeriod(
        uint256 projectId,
        uint256 launchStart,
        uint256 launchEnd
    ) external projectExists(projectId) onlyCreator(projectId) nonReentrant {
        if (block.timestamp >= projects[projectId].launchStart) revert LaunchNotActive();
        if (launchStart <= block.timestamp) revert InvalidLaunchPeriod();
        if (launchEnd <= launchStart) revert InvalidLaunchPeriod();
        projects[projectId].launchStart = launchStart;
        projects[projectId].launchEnd = launchEnd;
        emit LaunchPeriodSet(projectId, launchStart, launchEnd);
    }

    /**
     * @notice Deposits base currency into a project to participate in the launch.
     * @param projectId The project to deposit into.
     * @param amount The amount of base currency to deposit.
     */
    function deposit(
        uint256 projectId,
        uint256 amount
    ) external projectExists(projectId) nonReentrant {
        Project storage p = projects[projectId];
        if (amount == 0) revert ZeroAmount();
        if (block.timestamp < p.launchStart || block.timestamp >= p.launchEnd)
            revert LaunchNotActive();
        if (!p.allocationSet) revert AllocationNotSet();

        // Effects
        deposits[projectId][msg.sender] += amount;
        p.totalRaised += amount;

        // Interactions
        if (!baseCurrency.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        emit Deposited(projectId, msg.sender, amount);
    }

    /**
     * @notice Finalizes a project launch after the deposit period ends.
     * @dev The project creator must finalize within 7 days of the launch period ending.
     *      If total raised >= MINIMUM_RAISE, the launch is successful and raised base
     *      currency is transferred to the recipient. Otherwise, the launch fails and
     *      depositors may withdraw their base currency.
     */
    function finalize(
        uint256 projectId
    ) external projectExists(projectId) onlyCreator(projectId) nonReentrant {
        Project storage p = projects[projectId];
        if (p.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp < p.launchEnd) revert LaunchStillActive();
        if (block.timestamp > p.launchEnd + FINALIZATION_WINDOW)
            revert FinalizationWindowClosed();

        p.finalized = true;
        p.successful = p.totalRaised >= MINIMUM_RAISE;

        if (p.successful) {
            uint256 raised = p.totalRaised;
            if (!baseCurrency.transfer(p.recipient, raised)) {
                revert TransferFailed();
            }
        }

        emit ProjectFinalized(projectId, p.successful, p.totalRaised, p.recipient);
    }

    /**
     * @notice Claims allocated project tokens after a successful launch.
     * @param projectId The project to claim tokens from.
     */
    function claim(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage p = projects[projectId];
        if (!p.finalized) revert LaunchNotFinalized();
        if (!p.successful) revert LaunchFailed();

        uint256 deposited = deposits[projectId][msg.sender];
        if (deposited == 0) revert NothingToClaim();

        uint256 tokenAmount = deposited * p.tokensPerBaseUnit;
        if (tokenAmount == 0) revert NothingToClaim();

        // Effects: mark as claimed by zeroing the deposit record.
        deposits[projectId][msg.sender] = 0;
        claimedTokens[projectId][msg.sender] += tokenAmount;

        // Interactions: mint project tokens to the claimant.
        IMintableERC20(p.token).mint(msg.sender, tokenAmount);

        emit TokensClaimed(projectId, msg.sender, tokenAmount);
    }

    /**
     * @notice Withdraws deposited base currency if the launch failed or the user
     *         chooses to exit before finalization.
     * @param projectId The project to withdraw from.
     */
    function withdraw(uint256 projectId) external projectExists(projectId) nonReentrant {
        Project storage p = projects[projectId];

        if (p.finalized) {
            if (p.successful) revert LaunchSuccessful();
        }

        uint256 deposited = deposits[projectId][msg.sender];
        if (deposited == 0) revert NothingToWithdraw();

        // Effects
        deposits[projectId][msg.sender] = 0;
        p.totalRaised -= deposited;

        // Interactions
        if (!baseCurrency.transfer(msg.sender, deposited)) {
            revert TransferFailed();
        }

        emit BaseWithdrawn(projectId, msg.sender, deposited);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    function getProject(
        uint256 projectId
    )
        external
        view
        projectExists(projectId)
        returns (
            address creator,
            address token,
            address recipient,
            uint256 tokensPerBaseUnit,
            uint256 launchStart,
            uint256 launchEnd,
            uint256 totalRaised,
            bool allocationSet,
            bool finalized,
            bool successful
        )
    {
        Project storage p = projects[projectId];
        return (
            p.creator,
            p.token,
            p.recipient,
            p.tokensPerBaseUnit,
            p.launchStart,
            p.launchEnd,
            p.totalRaised,
            p.allocationSet,
            p.finalized,
            p.successful
        );
    }

    function userDeposit(uint256 projectId, address user) external view returns (uint256) {
        return deposits[projectId][user];
    }

    function userClaimedTokens(
        uint256 projectId,
        address user
    ) external view returns (uint256) {
        return claimedTokens[projectId][user];
    }

    function pendingTokens(
        uint256 projectId,
        address user
    ) external view returns (uint256) {
        Project storage p = projects[projectId];
        if (!p.finalized || !p.successful) return 0;
        uint256 deposited = deposits[projectId][user];
        if (deposited == 0) return 0;
        return deposited * p.tokensPerBaseUnit;
    }
}
