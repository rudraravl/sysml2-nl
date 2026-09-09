// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title ClimateDAOTreasury
 * @notice Manages a DAO treasury holding a governance token and a stablecoin in distinct pools.
 *         Members stake governance tokens and contribute stablecoins to climate initiatives to
 *         acquire voting power. Members may propose new initiatives, operators approve initiatives
 *         for voting, and members vote on active proposals.
 */
contract ClimateDAOTreasury {
    // ----------------------------------------------------------------------
    // Custom errors
    // ----------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientStake();
    error NoVotingPower();
    error InvalidFee();
    error FeeTooHigh();
    error InitiativeNotFound();
    error InitiativeNotApproved();
    error InitiativeAlreadyApproved();
    error InitiativeAlreadyExecuted();
    error ProposalNotFound();
    error ProposalNotActive();
    error ProposalAlreadyExecuted();
    error VotingNotStarted();
    error VotingEnded();
    error AlreadyVoted();
    error ProposalDefeated();
    error TransferFailed();
    error ReentrantCall();

    // ----------------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------------
    event Staked(address indexed member, uint256 amount);
    event Unstaked(address indexed member, uint256 amount);
    event StablecoinContributed(
        address indexed member,
        uint256 indexed initiativeId,
        uint256 amount,
        uint256 feeTaken
    );
    event InitiativeProposed(uint256 indexed initiativeId, address indexed proposer, string description);
    event InitiativeApproved(uint256 indexed initiativeId, address indexed operator);
    event ProposalCreated(uint256 indexed proposalId, uint256 indexed initiativeId, uint256 voteStart, uint256 voteEnd);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, uint256 indexed initiativeId, uint256 fundsReleased);
    event ContributionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorSet(address indexed operator, bool status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ----------------------------------------------------------------------
    // Constants
    // ----------------------------------------------------------------------
    uint16 public constant MAX_FEE_BPS = 200;     // 2%
    uint16 public constant INITIAL_FEE_BPS = 50;  // 0.5%
    uint256 public constant VOTING_PERIOD = 7 days;

    // ----------------------------------------------------------------------
    // State variables
    // ----------------------------------------------------------------------
    IERC20 public immutable governanceToken;
    IERC20 public immutable stablecoin;

    address public owner;
    uint16 public contributionFeeBps;

    uint256 public governancePoolBalance;
    uint256 public stablecoinPoolBalance;

    uint256 public nextInitiativeId;
    uint256 public nextProposalId;

    uint256 private _locked = 1;

    struct Initiative {
        address proposer;
        string description;
        uint256 totalStablecoin; // net contributions held for this initiative
        bool approved;
        bool executed;
    }

    struct Proposal {
        uint256 initiativeId;
        uint256 voteStart;
        uint256 voteEnd;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Initiative) private initiatives;
    mapping(uint256 => Proposal) private proposals;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public votingPower;
    mapping(address => bool) public isOperator;

    // member => initiativeId => net stablecoin contributed
    mapping(address => mapping(uint256 => uint256)) public memberInitiativeContributions;

    // ----------------------------------------------------------------------
    // Modifiers
    // ----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ----------------------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------------------
    constructor(address _governanceToken, address _stablecoin) {
        if (_governanceToken == address(0) || _stablecoin == address(0)) revert ZeroAddress();
        governanceToken = IERC20(_governanceToken);
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        contributionFeeBps = INITIAL_FEE_BPS;
        isOperator[msg.sender] = true;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorSet(msg.sender, true);
    }

    // ----------------------------------------------------------------------
    // Owner functions
    // ----------------------------------------------------------------------
    function setContributionFee(uint16 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint16 oldFee = contributionFeeBps;
        contributionFeeBps = _feeBps;
        emit ContributionFeeUpdated(oldFee, _feeBps);
    }

    function setOperator(address _operator, bool _status) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        isOperator[_operator] = _status;
        emit OperatorSet(_operator, _status);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    // ----------------------------------------------------------------------
    // Staking functions
    // ----------------------------------------------------------------------
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        stakedBalance[msg.sender] += amount;
        votingPower[msg.sender] += amount;
        governancePoolBalance += amount;

        if (!governanceToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientBalance();

        stakedBalance[msg.sender] -= amount;
        votingPower[msg.sender] -= amount;
        governancePoolBalance -= amount;

        if (!governanceToken.transfer(msg.sender, amount)) revert TransferFailed();

        emit Unstaked(msg.sender, amount);
    }

    // ----------------------------------------------------------------------
    // Stablecoin contribution
    // ----------------------------------------------------------------------
    function contribute(uint256 initiativeId, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        Initiative storage initiative = initiatives[initiativeId];
        if (initiative.proposer == address(0)) revert InitiativeNotFound();
        if (!initiative.approved) revert InitiativeNotApproved();
        if (initiative.executed) revert InitiativeAlreadyExecuted();

        uint256 fee = (amount * contributionFeeBps) / 10000;
        uint256 net = amount - fee;

        // Effects: update state before the external interaction (checks-effects-interactions)
        stablecoinPoolBalance += amount;
        initiative.totalStablecoin += net;
        memberInitiativeContributions[msg.sender][initiativeId] += net;
        votingPower[msg.sender] += net;

        // Interactions
        if (!stablecoin.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit StablecoinContributed(msg.sender, initiativeId, net, fee);
    }

    // ----------------------------------------------------------------------
    // Initiative functions
    // ----------------------------------------------------------------------
    function proposeInitiative(string calldata description) external returns (uint256 initiativeId) {
        if (votingPower[msg.sender] == 0) revert NoVotingPower();

        initiativeId = nextInitiativeId++;
        initiatives[initiativeId] = Initiative({
            proposer: msg.sender,
            description: description,
            totalStablecoin: 0,
            approved: false,
            executed: false
        });

        emit InitiativeProposed(initiativeId, msg.sender, description);
    }

    function approveInitiative(uint256 initiativeId) external onlyOperator {
        Initiative storage initiative = initiatives[initiativeId];
        if (initiative.proposer == address(0)) revert InitiativeNotFound();
        if (initiative.approved) revert InitiativeAlreadyApproved();

        initiative.approved = true;

        uint256 proposalId = nextProposalId++;
        Proposal storage proposal = proposals[proposalId];
        proposal.initiativeId = initiativeId;
        proposal.voteStart = block.timestamp;
        proposal.voteEnd = block.timestamp + VOTING_PERIOD;

        emit InitiativeApproved(initiativeId, msg.sender);
        emit ProposalCreated(proposalId, initiativeId, proposal.voteStart, proposal.voteEnd);
    }

    // ----------------------------------------------------------------------
    // Voting
    // ----------------------------------------------------------------------
    function vote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.voteEnd == 0) revert ProposalNotFound();
        if (block.timestamp < proposal.voteStart) revert VotingNotStarted();
        if (block.timestamp > proposal.voteEnd) revert VotingEnded();
        if (proposal.hasVoted[msg.sender]) revert AlreadyVoted();
        if (proposal.executed) revert ProposalAlreadyExecuted();

        uint256 weight = votingPower[msg.sender];
        if (weight == 0) revert NoVotingPower();

        proposal.hasVoted[msg.sender] = true;
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    // ----------------------------------------------------------------------
    // Execution
    // ----------------------------------------------------------------------
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.voteEnd == 0) revert ProposalNotFound();
        if (block.timestamp <= proposal.voteEnd) revert VotingEnded();
        if (proposal.executed) revert ProposalAlreadyExecuted();

        Initiative storage initiative = initiatives[proposal.initiativeId];
        if (initiative.executed) revert InitiativeAlreadyExecuted();

        if (proposal.forVotes <= proposal.againstVotes) revert ProposalDefeated();

        proposal.executed = true;
        initiative.executed = true;

        uint256 funds = initiative.totalStablecoin;
        if (funds > 0) {
            initiative.totalStablecoin = 0;
            stablecoinPoolBalance -= funds;
            if (!stablecoin.transfer(initiative.proposer, funds)) revert TransferFailed();
        }

        emit ProposalExecuted(proposalId, proposal.initiativeId, funds);
    }

    // ----------------------------------------------------------------------
    // View functions
    // ----------------------------------------------------------------------
    function getVotingPower(address account) external view returns (uint256) {
        return votingPower[account];
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return stakedBalance[account];
    }

    function getInitiative(uint256 initiativeId)
        external
        view
        returns (
            address proposer,
            string memory description,
            uint256 totalStablecoin,
            bool approved,
            bool executed
        )
    {
        Initiative storage initiative = initiatives[initiativeId];
        if (initiative.proposer == address(0)) revert InitiativeNotFound();
        return (initiative.proposer, initiative.description, initiative.totalStablecoin, initiative.approved, initiative.executed);
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            uint256 initiativeId,
            uint256 voteStart,
            uint256 voteEnd,
            uint256 forVotes,
            uint256 againstVotes,
            bool executed
        )
    {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.voteEnd == 0) revert ProposalNotFound();
        return (proposal.initiativeId, proposal.voteStart, proposal.voteEnd, proposal.forVotes, proposal.againstVotes, proposal.executed);
    }

    function hasVoted(uint256 proposalId, address account) external view returns (bool) {
        return proposals[proposalId].hasVoted[account];
    }

    function getMemberContribution(address member, uint256 initiativeId) external view returns (uint256) {
        return memberInitiativeContributions[member][initiativeId];
    }

    function proposalState(uint256 proposalId) external view returns (string memory) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.voteEnd == 0) revert ProposalNotFound();
        if (proposal.executed) return "Executed";
        if (block.timestamp < proposal.voteStart) return "Pending";
        if (block.timestamp <= proposal.voteEnd) return "Active";
        if (proposal.forVotes > proposal.againstVotes) return "Succeeded";
        return "Defeated";
    }
}
