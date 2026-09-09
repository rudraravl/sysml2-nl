// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract CommunityInitiativeFund {
    error NotOperator();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientShares();
    error InsufficientBalance();
    error ProposalFeeNotPaid();
    error ProposalNotInState();
    error VotingNotActive();
    error VotingNotEnded();
    error AlreadyVoted();
    error ProposalNotSucceeded();
    error TransferFailed();

    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, address indexed token, uint256 shares, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, address indexed token, address recipient, uint256 amount, string description);
    event ProposalApproved(uint256 indexed proposalId);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, address indexed token, address recipient, uint256 amount);
    event ProposalFeeUpdated(uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    enum ProposalState { Pending, Active, Succeeded, Defeated, Executed }

    struct Proposal {
        address proposer;
        address token;
        address recipient;
        uint256 amount;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 votingDeadline;
        ProposalState state;
        string description;
    }

    address public operator;
    uint256 public proposalFee = 0.01 ether;
    uint256 public votingDuration = 7 days;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    mapping(address => mapping(address => uint256)) public participantShares;
    mapping(address => uint256) public totalShares;
    mapping(address => uint256) public totalDeposits;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
    }

    function deposit(address token, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert ZeroAddress();

        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        uint256 shares;
        if (totalShares[token] == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares[token]) / totalDeposits[token];
        }

        participantShares[msg.sender][token] += shares;
        totalShares[token] += shares;
        totalDeposits[token] += amount;

        emit Deposited(msg.sender, token, amount, shares);
    }

    function withdraw(address token, uint256 shares) external {
        if (shares == 0) revert InvalidAmount();
        if (participantShares[msg.sender][token] < shares) revert InsufficientShares();

        uint256 tokenAmount = (shares * totalDeposits[token]) / totalShares[token];

        participantShares[msg.sender][token] -= shares;
        totalShares[token] -= shares;
        totalDeposits[token] -= tokenAmount;

        if (!IERC20(token).transfer(msg.sender, tokenAmount)) revert TransferFailed();

        emit Withdrawn(msg.sender, token, shares, tokenAmount);
    }

    function propose(
        address token,
        address recipient,
        uint256 amount,
        string calldata description
    ) external payable returns (uint256 proposalId) {
        if (msg.value < proposalFee) revert ProposalFeeNotPaid();
        if (amount == 0) revert InvalidAmount();
        if (token == address(0) || recipient == address(0)) revert ZeroAddress();

        proposalId = proposalCount++;
        Proposal storage p = proposals[proposalId];
        p.proposer = msg.sender;
        p.token = token;
        p.recipient = recipient;
        p.amount = amount;
        p.description = description;
        p.state = ProposalState.Pending;

        emit ProposalCreated(proposalId, msg.sender, token, recipient, amount, description);
    }

    function approveProposal(uint256 proposalId) external onlyOperator {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Pending) revert ProposalNotInState();

        p.state = ProposalState.Active;
        p.votingDeadline = block.timestamp + votingDuration;

        emit ProposalApproved(proposalId);
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Active) revert ProposalNotInState();
        if (block.timestamp >= p.votingDeadline) revert VotingNotActive();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        uint256 weight = participantShares[msg.sender][p.token];
        if (weight == 0) revert InsufficientShares();

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            p.yesVotes += weight;
        } else {
            p.noVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function finalizeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Active) revert ProposalNotInState();
        if (block.timestamp < p.votingDeadline) revert VotingNotEnded();

        uint256 totalVotes = p.yesVotes + p.noVotes;
        if (totalVotes > 0 && p.yesVotes * 100 >= totalVotes * 51) {
            p.state = ProposalState.Succeeded;
        } else {
            p.state = ProposalState.Defeated;
        }
    }

    function executeProposal(uint256 proposalId) external onlyOperator {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Succeeded) revert ProposalNotSucceeded();

        uint256 amount = p.amount;
        address token = p.token;
        address recipient = p.recipient;

        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientBalance();

        // Effects: update state before external interaction
        p.state = ProposalState.Executed;
        totalDeposits[token] -= amount;

        // Interactions
        if (!IERC20(token).transfer(recipient, amount)) revert TransferFailed();

        emit ProposalExecuted(proposalId, token, recipient, amount);
    }

    function setProposalFee(uint256 newFee) external onlyOperator {
        proposalFee = newFee;
        emit ProposalFeeUpdated(newFee);
    }

    function setVotingDuration(uint256 newDuration) external onlyOperator {
        votingDuration = newDuration;
    }

    function withdrawFees(address payable to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorTransferred(operator, newOperator);
        operator = newOperator;
    }

    function getParticipantTokenBalance(address user, address token) external view returns (uint256) {
        if (totalShares[token] == 0) return 0;
        return (participantShares[user][token] * totalDeposits[token]) / totalShares[token];
    }

    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        address token,
        address recipient,
        uint256 amount,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 votingDeadline,
        ProposalState state,
        string memory description
    ) {
        Proposal storage p = proposals[proposalId];
        return (
            p.proposer,
            p.token,
            p.recipient,
            p.amount,
            p.yesVotes,
            p.noVotes,
            p.votingDeadline,
            p.state,
            p.description
        );
    }
}
