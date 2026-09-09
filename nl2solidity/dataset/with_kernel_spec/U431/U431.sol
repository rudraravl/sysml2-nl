// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SocialImpactPaymentNetwork
 * @notice Manages a payment network where a configurable percentage of each
 *         transaction is collected as a fee. 33% of collected fees are
 *         automatically distributed to approved social impact projects
 *         proportional to their allocation weights, while the remainder is
 *         forwarded to a treasury. Projects may claim their accumulated share
 *         at any time.
 */
contract SocialImpactPaymentNetwork {
    /* ------------------------------------------------------------------ */
    /*                            Constants                               */
    /* ------------------------------------------------------------------ */

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10% cap

    /* ------------------------------------------------------------------ */
    /*                            Types                                    */
    /* ------------------------------------------------------------------ */

    struct Project {
        bool approved;
        uint96 allocation; // weight used to split the project fee pool
        uint160 claimableFunds; // wei available for the project to claim
    }

    struct PaymentRecord {
        address sender;
        address recipient;
        uint256 amount;
        uint256 fee;
        uint256 projectContribution;
        uint256 timestamp;
    }

    /* ------------------------------------------------------------------ */
    /*                          State Variables                           */
    /* ------------------------------------------------------------------ */

    address public owner;
    address public treasury;

    /// @notice Global transaction fee in basis points (50 = 0.5%).
    uint256 public globalFeeBps;

    /// @notice Portion of collected fees routed to projects (3300 = 33%).
    uint256 public projectAllocationBps;

    mapping(address => Project) internal _projects;
    address[] internal _projectList;
    uint256 public totalProjectAllocation;

    mapping(address => PaymentRecord[]) internal _history;

    uint256 public totalFeesCollected;
    uint256 public totalProjectFundsDistributed;

    uint256 private _locked = 1;

    /* ------------------------------------------------------------------ */
    /*                            Events                                   */
    /* ------------------------------------------------------------------ */

    event PaymentProcessed(
        uint256 indexed transactionId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 fee,
        uint256 projectContribution
    );

    event FundsClaimed(address indexed project, uint256 amount);

    event GlobalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    event ProjectAllocationBpsUpdated(uint256 oldBps, uint256 newBps);

    event ProjectAdded(address indexed project, uint256 allocation);

    event ProjectRemoved(address indexed project);

    event ProjectAllocationUpdated(address indexed project, uint256 oldAllocation, uint256 newAllocation);

    event TreasuryUpdated(address oldTreasury, address newTreasury);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /* ------------------------------------------------------------------ */
    /*                            Errors                                   */
    /* ------------------------------------------------------------------ */

    error NotOwner();
    error ZeroAddress();
    error FeeTooHigh();
    error ProjectNotApproved();
    error ProjectAlreadyApproved();
    error InvalidAllocation();
    error NoFundsToClaim();
    error ZeroPaymentAmount();
    error RecipientEqualsSender();
    error ReentrantCall();
    error TransferFailed();

    /* ------------------------------------------------------------------ */
    /*                           Modifiers                                 */
    /* ------------------------------------------------------------------ */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    /* ------------------------------------------------------------------ */
    /*                          Constructor                               */
    /* ------------------------------------------------------------------ */

    constructor(address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();

        owner = msg.sender;
        treasury = _treasury;
        globalFeeBps = 50; // 0.5%
        projectAllocationBps = 3300; // 33%

        emit OwnershipTransferred(address(0), msg.sender);
        emit TreasuryUpdated(address(0), _treasury);
        emit GlobalFeeUpdated(0, globalFeeBps);
        emit ProjectAllocationBpsUpdated(0, projectAllocationBps);
    }

    /* ------------------------------------------------------------------ */
    /*                       Owner — Fee & Treasury                       */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Update the global transaction fee (basis points).
     * @param _feeBps New fee in basis points. Must be ≤ MAX_FEE_BPS.
     */
    function setGlobalFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit GlobalFeeUpdated(globalFeeBps, _feeBps);
        globalFeeBps = _feeBps;
    }

    /**
     * @notice Update the percentage of fees routed to the project pool.
     * @param _bps New allocation in basis points (e.g. 3300 for 33%).
     */
    function setProjectAllocationBps(uint256 _bps) external onlyOwner {
        if (_bps > BPS_DENOMINATOR) revert FeeTooHigh();
        emit ProjectAllocationBpsUpdated(projectAllocationBps, _bps);
        projectAllocationBps = _bps;
    }

    /**
     * @notice Update the treasury address that receives the non-project
     *         portion of collected fees.
     */
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    /* ------------------------------------------------------------------ */
    /*                       Owner — Project Management                   */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Approve a new social impact project and assign its allocation
     *         weight for sharing the project fee pool.
     */
    function addProject(address _project, uint96 _allocation) external onlyOwner {
        if (_project == address(0)) revert ZeroAddress();
        if (_projects[_project].approved) revert ProjectAlreadyApproved();
        if (_allocation == 0) revert InvalidAllocation();

        _projects[_project] = Project({
            approved: true,
            allocation: _allocation,
            claimableFunds: 0
        });
        _projectList.push(_project);
        totalProjectAllocation += _allocation;

        emit ProjectAdded(_project, _allocation);
    }

    /**
     * @notice Remove a project from the approved list. The project may still
     *         claim funds that were allocated to it before removal.
     */
    function removeProject(address _project) external onlyOwner {
        if (!_projects[_project].approved) revert ProjectNotApproved();

        totalProjectAllocation -= _projects[_project].allocation;
        _projects[_project].approved = false;
        _projects[_project].allocation = 0;

        uint256 len = _projectList.length;
        for (uint256 i = 0; i < len; i++) {
            if (_projectList[i] == _project) {
                _projectList[i] = _projectList[len - 1];
                _projectList.pop();
                break;
            }
        }

        emit ProjectRemoved(_project);
    }

    /**
     * @notice Adjust an approved project's allocation weight.
     */
    function setProjectAllocation(address _project, uint96 _allocation) external onlyOwner {
        if (!_projects[_project].approved) revert ProjectNotApproved();
        if (_allocation == 0) revert InvalidAllocation();

        uint96 oldAllocation = _projects[_project].allocation;
        totalProjectAllocation = totalProjectAllocation - oldAllocation + _allocation;
        _projects[_project].allocation = _allocation;

        emit ProjectAllocationUpdated(_project, oldAllocation, _allocation);
    }

    /* ------------------------------------------------------------------ */
    /*                       Payment Processing                           */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Process a payment of `msg.value` wei to `_recipient`.
     *
     * A fee equal to `globalFeeBps` basis points of the payment is deducted.
     * 33% (or `projectAllocationBps` bps) of that fee is split among approved
     * projects proportional to their allocation weights; the remainder is
     * forwarded to the treasury. The net amount is sent to the recipient.
     *
     * @param _recipient Address that will receive the payment net of fees.
     */
    function processPayment(address _recipient) external payable nonReentrant {
        if (msg.value == 0) revert ZeroPaymentAmount();
        if (_recipient == address(0)) revert ZeroAddress();
        if (_recipient == msg.sender) revert RecipientEqualsSender();

        uint256 amount = msg.value;

        // Fee: single division, used only for net amount / treasury accounting.
        uint256 fee = (amount * globalFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        uint256 projectContribution = 0;
        uint256 treasuryShare = fee;

        // --- Distribute project portion ---
        // To avoid divide-before-multiply precision loss, compute the full
        // numerator (amount * globalFeeBps * projectAllocationBps) first and
        // divide only once by (BPS_DENOMINATOR * BPS_DENOMINATOR). Per-project
        // shares are derived from this numerator before any division, so the
        // multiplication always precedes the division.
        if (totalProjectAllocation > 0 && _projectList.length > 0) {
            uint256 projectNumerator = amount * globalFeeBps * projectAllocationBps;
            uint256 projectDenom = BPS_DENOMINATOR * BPS_DENOMINATOR;
            projectContribution = projectNumerator / projectDenom;
            treasuryShare = fee - projectContribution;

            uint256 len = _projectList.length;
            uint256 distributed = 0;
            for (uint256 i = 0; i < len; i++) {
                address p = _projectList[i];
                if (!_projects[p].approved) continue;

                uint256 share;
                if (i == len - 1) {
                    // Last project receives the remainder to avoid dust.
                    share = projectContribution - distributed;
                } else {
                    // Multiply-then-divide on the unrounded numerator.
                    share = (projectNumerator * _projects[p].allocation) /
                        (projectDenom * totalProjectAllocation);
                }

                _projects[p].claimableFunds += uint160(share);
                distributed += share;
            }
        }

        // --- Effects ---
        totalFeesCollected += fee;

        uint256 txId = _history[msg.sender].length;
        PaymentRecord memory record = PaymentRecord({
            sender: msg.sender,
            recipient: _recipient,
            amount: amount,
            fee: fee,
            projectContribution: projectContribution,
            timestamp: block.timestamp
        });
        _history[msg.sender].push(record);
        _history[_recipient].push(record);

        emit PaymentProcessed(txId, msg.sender, _recipient, amount, fee, projectContribution);

        // --- Interactions ---
        (bool okRecipient, ) = _recipient.call{value: netAmount}("");
        if (!okRecipient) revert TransferFailed();

        if (treasuryShare > 0) {
            (bool okTreasury, ) = treasury.call{value: treasuryShare}("");
            if (!okTreasury) revert TransferFailed();
        }
    }

    /* ------------------------------------------------------------------ */
    /*                       Project Claim                                */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Allows a project (or former project with residual funds) to
     *         withdraw its accumulated share of collected fees.
     */
    function claimFunds() external nonReentrant {
        uint256 amount = _projects[msg.sender].claimableFunds;
        if (amount == 0) revert NoFundsToClaim();

        // Effects
        _projects[msg.sender].claimableFunds = 0;
        totalProjectFundsDistributed += amount;

        emit FundsClaimed(msg.sender, amount);

        // Interactions
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /* ------------------------------------------------------------------ */
    /*                          View Functions                            */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Returns the full payment history for a given user (as sender
     *         or recipient).
     */
    function getTransactionHistory(address _user) external view returns (PaymentRecord[] memory) {
        return _history[_user];
    }

    /**
     * @notice Returns the number of transactions recorded for `_user`.
     */
    function getTransactionCount(address _user) external view returns (uint256) {
        return _history[_user].length;
    }

    /**
     * @notice Returns project details.
     */
    function getProjectInfo(address _project)
        external
        view
        returns (bool approved, uint96 allocation, uint160 claimableFunds)
    {
        Project memory p = _projects[_project];
        return (p.approved, p.allocation, p.claimableFunds);
    }

    /**
     * @notice Returns the list of all approved project addresses.
     */
    function getProjects() external view returns (address[] memory) {
        return _projectList;
    }

    /**
     * @notice Returns the number of approved projects.
     */
    function getProjectCount() external view returns (uint256) {
        return _projectList.length;
    }

    /**
     * @notice Returns the total fees collected across all payments.
     */
    function getTotalFeesCollected() external view returns (uint256) {
        return totalFeesCollected;
    }

    /**
     * @notice Returns the total project funds that have been claimed.
     */
    function getTotalProjectFundsDistributed() external view returns (uint256) {
        return totalProjectFundsDistributed;
    }

    /* ------------------------------------------------------------------ */
    /*                          Receive Guard                             */
    /* ------------------------------------------------------------------ */

    /// @dev Reject direct ETH transfers; use `processPayment` instead.
    receive() external payable {
        revert ZeroPaymentAmount();
    }
}
