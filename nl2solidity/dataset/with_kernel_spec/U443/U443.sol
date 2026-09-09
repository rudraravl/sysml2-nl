// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title PublicGoodsFundingRound
 * @notice Manages a public goods funding round: collects stablecoin deposits,
 *         registers project proposals, lets an operator approve/reject them,
 *         allocates funds to approved projects, and lets projects claim their
 *         allocated stablecoins. A 2% fee is diverted to a treasury on every deposit.
 */
contract PublicGoodsFundingRound {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant FEE_BPS = 200; // 2%
    uint256 private constant BPS_DIVISOR = 10_000;
    uint256 public constant DEFAULT_MAX_FUNDING = 100_000 * 10 ** 18;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    IERC20 public immutable stablecoin;
    address public treasury;
    address public operator;
    uint256 public maxFundingPerProject;
    uint256 public totalAvailable;

    mapping(address => uint256) public contributorDeposits;

    enum ProjectStatus {
        None,        // 0 – not registered
        Pending,     // 1 – registered, awaiting review
        Approved,    // 2 – approved by operator
        Rejected,    // 3 – rejected by operator
        Distributed  // 4 – funds claimed by project
    }

    struct Project {
        uint256 requestedAmount;
        uint256 allocatedAmount;
        ProjectStatus status;
    }

    mapping(address => Project) public projects;
    address[] public projectList;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Deposited(address indexed contributor, uint256 amount, uint256 fee, uint256 netAmount);
    event ProjectRegistered(address indexed project, uint256 requestedAmount);
    event ProjectApproved(address indexed project);
    event ProjectRejected(address indexed project);
    event FundsDistributed(address indexed project, uint256 amount);
    event FundsClaimed(address indexed project, uint256 amount);
    event MaxFundingUpdated(uint256 oldMax, uint256 newMax);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error ProjectAlreadyRegistered();
    error ProjectNotRegistered();
    error ProjectNotApproved();
    error ProjectAlreadyReviewed();
    error ExceedsMaxFunding(uint256 requested, uint256 maxAllowed);
    error AllocationExceedsMax(uint256 totalAllocated, uint256 maxAllowed);
    error InsufficientAvailableFunds(uint256 available, uint256 required);
    error NoFundsToClaim();
    error TransferFailed();

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param _stablecoin  Address of the ERC20 stablecoin used for deposits and distributions.
     * @param _treasury    Address that receives the 2% deposit fee.
     * @param _operator    Initial operator address (approves/rejects projects, distributes funds).
     */
    constructor(address _stablecoin, address _treasury, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        treasury = _treasury;
        operator = _operator;
        maxFundingPerProject = DEFAULT_MAX_FUNDING;
    }

    // -------------------------------------------------------------------------
    // Internal: safe transfers
    // -------------------------------------------------------------------------

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool ok = stablecoin.transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool ok = stablecoin.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    // -------------------------------------------------------------------------
    // Deposit
    // -------------------------------------------------------------------------

    /**
     * @notice Deposits stablecoins into the round. A 2% fee is sent to the treasury
     *         and the remainder is credited to the contributor and made available
     *         for distribution to projects.
     * @param amount Amount of stablecoins to deposit (smallest unit).
     */
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * FEE_BPS) / BPS_DIVISOR;
        uint256 netAmount = amount - fee;

        _safeTransferFrom(msg.sender, address(this), amount);
        if (fee > 0) {
            _safeTransfer(treasury, fee);
        }

        contributorDeposits[msg.sender] += netAmount;
        totalAvailable += netAmount;

        emit Deposited(msg.sender, amount, fee, netAmount);
    }

    // -------------------------------------------------------------------------
    // Project registration
    // -------------------------------------------------------------------------

    /**
     * @notice Registers a new project proposal under the caller's address.
     * @param requestedAmount Requested funding amount (must be > 0 and <= maxFundingPerProject).
     */
    function registerProject(uint256 requestedAmount) external {
        if (projects[msg.sender].status != ProjectStatus.None) revert ProjectAlreadyRegistered();
        if (requestedAmount == 0) revert ZeroAmount();
        if (requestedAmount > maxFundingPerProject) {
            revert ExceedsMaxFunding(requestedAmount, maxFundingPerProject);
        }

        projects[msg.sender] = Project({
            requestedAmount: requestedAmount,
            allocatedAmount: 0,
            status: ProjectStatus.Pending
        });
        projectList.push(msg.sender);

        emit ProjectRegistered(msg.sender, requestedAmount);
    }

    // -------------------------------------------------------------------------
    // Operator: approve / reject
    // -------------------------------------------------------------------------

    /**
     * @notice Approves a pending project.
     * @param project Address of the project to approve.
     */
    function approveProject(address project) external onlyOperator {
        if (project == address(0)) revert ZeroAddress();
        Project storage p = projects[project];
        if (p.status == ProjectStatus.None) revert ProjectNotRegistered();
        if (p.status != ProjectStatus.Pending) revert ProjectAlreadyReviewed();

        p.status = ProjectStatus.Approved;
        emit ProjectApproved(project);
    }

    /**
     * @notice Rejects a pending project.
     * @param project Address of the project to reject.
     */
    function rejectProject(address project) external onlyOperator {
        if (project == address(0)) revert ZeroAddress();
        Project storage p = projects[project];
        if (p.status == ProjectStatus.None) revert ProjectNotRegistered();
        if (p.status != ProjectStatus.Pending) revert ProjectAlreadyReviewed();

        p.status = ProjectStatus.Rejected;
        emit ProjectRejected(project);
    }

    // -------------------------------------------------------------------------
    // Operator: distribute funds (allocate to approved project)
    // -------------------------------------------------------------------------

    /**
     * @notice Allocates stablecoins to an approved project. The allocated amount
     *         is deducted from `totalAvailable` and credited to the project's
     *         `allocatedAmount`. The project owner must call `claimFunds` to
     *         receive the tokens.
     * @param project Address of the approved project.
     * @param amount  Amount to allocate.
     */
    function distributeFunds(address project, uint256 amount) external onlyOperator {
        if (project == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        Project storage p = projects[project];
        if (p.status == ProjectStatus.None) revert ProjectNotRegistered();
        if (p.status != ProjectStatus.Approved) revert ProjectNotApproved();
        if (amount > totalAvailable) revert InsufficientAvailableFunds(totalAvailable, amount);
        if (p.allocatedAmount + amount > maxFundingPerProject) {
            revert AllocationExceedsMax(p.allocatedAmount + amount, maxFundingPerProject);
        }

        p.allocatedAmount += amount;
        totalAvailable -= amount;

        emit FundsDistributed(project, amount);
    }

    // -------------------------------------------------------------------------
    // Project owner: claim allocated funds
    // -------------------------------------------------------------------------

    /**
     * @notice Lets an approved project claim its allocated stablecoins.
     *         Transfers the full `allocatedAmount` to the caller and marks
     *         the project as `Distributed`.
     */
    function claimFunds() external {
        Project storage p = projects[msg.sender];
        uint256 amount = p.allocatedAmount;
        if (amount == 0) revert NoFundsToClaim();

        // Effects
        p.allocatedAmount = 0;
        p.status = ProjectStatus.Distributed;

        // Interactions
        _safeTransfer(msg.sender, amount);

        emit FundsClaimed(msg.sender, amount);
    }

    // -------------------------------------------------------------------------
    // Operator: admin
    // -------------------------------------------------------------------------

    /**
     * @notice Updates the maximum funding amount for any single project.
     * @param newMax New maximum allocation per project (smallest units).
     */
    function setMaxFundingPerProject(uint256 newMax) external onlyOperator {
        if (newMax == 0) revert ZeroAmount();
        uint256 old = maxFundingPerProject;
        maxFundingPerProject = newMax;
        emit MaxFundingUpdated(old, newMax);
    }

    /**
     * @notice Transfers the operator role to a new address.
     * @param newOperator New operator address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Updates the treasury address that receives the 2% deposit fee.
     * @param newTreasury New treasury address.
     */
    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Returns project details for a given address.
     */
    function getProject(address project)
        external
        view
        returns (uint256 requestedAmount, uint256 allocatedAmount, ProjectStatus status)
    {
        Project storage p = projects[project];
        return (p.requestedAmount, p.allocatedAmount, p.status);
    }

    /**
     * @notice Returns the total number of registered projects.
     */
    function projectCount() external view returns (uint256) {
        return projectList.length;
    }

    /**
     * @notice Returns the project address at a given index in the registry.
     */
    function projectAtIndex(uint256 index) external view returns (address) {
        return projectList[index];
    }

    /**
     * @notice Returns the stablecoin balance held by the contract.
     */
    function contractBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }
}
