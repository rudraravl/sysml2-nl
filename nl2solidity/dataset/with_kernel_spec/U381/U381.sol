// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PublicGoodsDonationMatcher {
    error Unauthorized();
    error ProjectNotFound();
    error ProjectNotApproved();
    error ProjectAlreadyApproved();
    error ProjectAlreadyRejected();
    error DonationTooSmall();
    error SelfDonationNotAllowed();
    error InsufficientMatchingFunds();
    error NothingToClaim();
    error AlreadyClaimedThisRound();
    error InvalidAmount();
    error ZeroAddress();
    error TransferFailed();
    error EmptyString();
    error ReentrantCall();

    enum ProjectStatus {
        Pending,
        Approved,
        Rejected
    }

    struct Project {
        address payable owner;
        string name;
        string description;
        ProjectStatus status;
        uint256 totalDonated;
        uint256 donatedThisRound;
        uint256 matchedThisRound;
        bool claimedThisRound;
        uint256 lastResetRound;
    }

    address public operator;
    uint256 public fundingRound;
    uint256 public matchingPoolBalance;
    uint256 public projectCount;

    mapping(uint256 => Project) internal projects;

    uint256 private _locked = 1;

    uint256 public constant MIN_DONATION = 0.01 ether;
    uint256 public constant MAX_MATCH_PER_PROJECT_PER_ROUND = 10 ether;

    event ProjectRegistered(
        uint256 indexed projectId,
        address indexed owner,
        string name,
        string description
    );
    event ProjectApproved(uint256 indexed projectId);
    event ProjectRejected(uint256 indexed projectId);
    event DonationReceived(
        uint256 indexed projectId,
        address indexed donor,
        uint256 amount
    );
    event MatchingFundsDisbursed(
        uint256 indexed projectId,
        address indexed recipient,
        uint256 amount,
        uint256 fundingRound
    );
    event FundingRoundStarted(uint256 indexed round);
    event MatchingFundsDeposited(address indexed from, uint256 amount);
    event MatchingFundsWithdrawn(address indexed operator, uint256 amount);
    event OperatorChanged(
        address indexed previousOperator,
        address indexed newOperator
    );

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() payable {
        operator = msg.sender;
        if (msg.value > 0) {
            matchingPoolBalance += msg.value;
            emit MatchingFundsDeposited(msg.sender, msg.value);
        }
    }

    function registerProject(
        string calldata name,
        string calldata description
    ) external returns (uint256 projectId) {
        if (bytes(name).length == 0) revert EmptyString();
        if (bytes(description).length == 0) revert EmptyString();
        projectId = projectCount++;
        Project storage p = projects[projectId];
        p.owner = payable(msg.sender);
        p.name = name;
        p.description = description;
        p.status = ProjectStatus.Pending;
        p.lastResetRound = fundingRound;
        emit ProjectRegistered(projectId, msg.sender, name, description);
    }

    function approveProject(uint256 projectId) external onlyOperator {
        if (projectId >= projectCount) revert ProjectNotFound();
        Project storage p = projects[projectId];
        if (p.status == ProjectStatus.Approved) revert ProjectAlreadyApproved();
        if (p.status == ProjectStatus.Rejected) revert ProjectAlreadyRejected();
        p.status = ProjectStatus.Approved;
        emit ProjectApproved(projectId);
    }

    function rejectProject(uint256 projectId) external onlyOperator {
        if (projectId >= projectCount) revert ProjectNotFound();
        Project storage p = projects[projectId];
        if (p.status == ProjectStatus.Rejected) revert ProjectAlreadyRejected();
        p.status = ProjectStatus.Rejected;
        emit ProjectRejected(projectId);
    }

    function _syncRound(uint256 projectId) internal {
        Project storage p = projects[projectId];
        if (p.lastResetRound != fundingRound) {
            p.donatedThisRound = 0;
            p.matchedThisRound = 0;
            p.claimedThisRound = false;
            p.lastResetRound = fundingRound;
        }
    }

    function _eligibleMatch(uint256 projectId) internal view returns (uint256) {
        Project storage p = projects[projectId];
        uint256 roundDonations = (p.lastResetRound == fundingRound)
            ? p.donatedThisRound
            : 0;
        uint256 eligible = roundDonations;
        if (eligible > MAX_MATCH_PER_PROJECT_PER_ROUND) {
            eligible = MAX_MATCH_PER_PROJECT_PER_ROUND;
        }
        if (eligible > matchingPoolBalance) {
            eligible = matchingPoolBalance;
        }
        return eligible;
    }

    function donate(uint256 projectId) external payable nonReentrant {
        if (projectId >= projectCount) revert ProjectNotFound();
        if (msg.value < MIN_DONATION) revert DonationTooSmall();
        Project storage p = projects[projectId];
        if (p.status != ProjectStatus.Approved) revert ProjectNotApproved();
        if (msg.sender == p.owner) revert SelfDonationNotAllowed();
        _syncRound(projectId);
        p.totalDonated += msg.value;
        p.donatedThisRound += msg.value;
        emit DonationReceived(projectId, msg.sender, msg.value);
        (bool ok, ) = p.owner.call{value: msg.value}("");
        if (!ok) revert TransferFailed();
    }

    function claimMatchingFunds(uint256 projectId) external nonReentrant {
        if (projectId >= projectCount) revert ProjectNotFound();
        Project storage p = projects[projectId];
        if (msg.sender != p.owner) revert Unauthorized();
        if (p.status != ProjectStatus.Approved) revert ProjectNotApproved();
        _syncRound(projectId);
        if (p.claimedThisRound) revert AlreadyClaimedThisRound();
        uint256 amount = _eligibleMatch(projectId);
        if (amount == 0) revert NothingToClaim();
        p.matchedThisRound = amount;
        p.claimedThisRound = true;
        matchingPoolBalance -= amount;
        emit MatchingFundsDisbursed(projectId, p.owner, amount, fundingRound);
        (bool ok, ) = p.owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function disburseMatchingFunds(uint256 projectId) external onlyOperator nonReentrant {
        if (projectId >= projectCount) revert ProjectNotFound();
        Project storage p = projects[projectId];
        if (p.status != ProjectStatus.Approved) revert ProjectNotApproved();
        _syncRound(projectId);
        if (p.claimedThisRound) revert AlreadyClaimedThisRound();
        uint256 amount = _eligibleMatch(projectId);
        if (amount == 0) revert NothingToClaim();
        p.matchedThisRound = amount;
        p.claimedThisRound = true;
        matchingPoolBalance -= amount;
        emit MatchingFundsDisbursed(projectId, p.owner, amount, fundingRound);
        (bool ok, ) = p.owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function startNewFundingRound() external onlyOperator {
        fundingRound += 1;
        emit FundingRoundStarted(fundingRound);
    }

    function depositMatchingFunds() external payable {
        if (msg.value == 0) revert InvalidAmount();
        matchingPoolBalance += msg.value;
        emit MatchingFundsDeposited(msg.sender, msg.value);
    }

    function withdrawMatchingFunds(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (amount > matchingPoolBalance) revert InsufficientMatchingFunds();
        matchingPoolBalance -= amount;
        emit MatchingFundsWithdrawn(msg.sender, amount);
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorChanged(prev, newOperator);
    }

    function getProject(uint256 projectId) external view returns (Project memory) {
        if (projectId >= projectCount) revert ProjectNotFound();
        return projects[projectId];
    }

    function eligibleMatch(uint256 projectId) external view returns (uint256) {
        if (projectId >= projectCount) revert ProjectNotFound();
        return _eligibleMatch(projectId);
    }

    receive() external payable {
        if (msg.value > 0) {
            matchingPoolBalance += msg.value;
            emit MatchingFundsDeposited(msg.sender, msg.value);
        }
    }
}
