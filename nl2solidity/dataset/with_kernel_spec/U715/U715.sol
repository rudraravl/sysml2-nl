// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DAOGovernance {
    // --- Custom Errors ---
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientVotingPower();
    error ProposalNotFound();
    error ProposalNotActive();
    error ProposalNotSucceeded();
    error AlreadyVoted();
    error InvalidVoteType();
    error ArrayLengthMismatch();
    error EmptyProposal();
    error OnlyDAO();
    error ExecutionFailed();
    error VotesOverflow();
    error ReentrantCall();
    error FutureLookup();

    // --- Events ---
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description,
        uint256 voteStart,
        uint256 voteEnd
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);

    event Staked(address indexed account, uint256 amount);

    event Unstaked(address indexed account, uint256 amount);

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    event ProposalFeeUpdated(uint256 oldFee, uint256 newFee);

    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);

    event TreasuryTokenTransferred(address indexed token, address indexed to, uint256 amount);

    // --- Constants ---
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 * 1e18;
    uint256 public constant VOTING_PERIOD = 72 hours;

    // --- Enums ---
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }

    // --- Structs ---
    struct Checkpoint {
        uint64 fromBlock;
        uint192 votes;
    }

    struct Proposal {
        address proposer;
        uint256 voteStart;
        uint256 voteEnd;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 snapshotBlock;
        bool executed;
    }

    // --- State Variables ---
    IERC20 public immutable governanceToken;

    uint256 public proposalFee;
    uint256 public quorumVotes;

    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => address[]) internal _proposalTargets;
    mapping(uint256 => uint256[]) internal _proposalValues;
    mapping(uint256 => bytes[]) internal _proposalCalldatas;
    mapping(uint256 => string) internal _proposalDescriptions;
    mapping(uint256 => mapping(address => uint8)) public proposalVoteOf;

    mapping(address => uint256) public stakedBalance;
    mapping(address => address) public delegates;

    mapping(address => Checkpoint[]) private _checkpoints;
    Checkpoint[] private _totalCheckpoints;

    uint256 private _locked;

    // --- Modifiers ---
    modifier onlyDAO() {
        if (msg.sender != address(this)) revert OnlyDAO();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // --- Constructor ---
    constructor(address _governanceToken, uint256 _proposalFee, uint256 _quorumVotes) {
        if (_governanceToken == address(0)) revert ZeroAddress();
        governanceToken = IERC20(_governanceToken);
        proposalFee = _proposalFee;
        quorumVotes = _quorumVotes;
        _locked = 1;
    }

    // --- Receive ETH ---
    receive() external payable {}

    // --- Staking ---
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        governanceToken.transferFrom(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        address delegatee = _effectiveDelegate(msg.sender);
        _writeCheckpoint(_checkpoints[delegatee], _currentVotes(delegatee) + amount);
        _writeCheckpoint(_totalCheckpoints, _currentTotalVotes() + amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientBalance();
        stakedBalance[msg.sender] -= amount;
        address delegatee = _effectiveDelegate(msg.sender);
        _writeCheckpoint(_checkpoints[delegatee], _currentVotes(delegatee) - amount);
        _writeCheckpoint(_totalCheckpoints, _currentTotalVotes() - amount);
        governanceToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    // --- Delegation ---
    function delegate(address to) external {
        address current = delegates[msg.sender];
        address oldDelegate = (current == address(0)) ? msg.sender : current;
        address newDelegate = (to == address(0)) ? msg.sender : to;
        if (oldDelegate == newDelegate) return;
        uint256 amount = stakedBalance[msg.sender];
        if (amount > 0) {
            _writeCheckpoint(_checkpoints[oldDelegate], _currentVotes(oldDelegate) - amount);
            _writeCheckpoint(_checkpoints[newDelegate], _currentVotes(newDelegate) + amount);
        }
        delegates[msg.sender] = (to == msg.sender) ? address(0) : to;
        emit DelegateChanged(msg.sender, oldDelegate, newDelegate);
    }

    // --- Proposals ---
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) external nonReentrant returns (uint256) {
        if (targets.length == 0) revert EmptyProposal();
        if (targets.length != values.length || targets.length != calldatas.length) {
            revert ArrayLengthMismatch();
        }
        if (_currentVotes(msg.sender) < PROPOSAL_THRESHOLD) revert InsufficientVotingPower();

        if (proposalFee > 0) {
            governanceToken.transferFrom(msg.sender, address(this), proposalFee);
        }

        uint256 proposalId = ++proposalCount;
        uint256 snapshot = block.number - 1;

        Proposal storage p = proposals[proposalId];
        p.proposer = msg.sender;
        p.snapshotBlock = snapshot;
        p.voteStart = block.timestamp;
        p.voteEnd = block.timestamp + VOTING_PERIOD;

        // Copy calldata arrays element-by-element into storage
        // (direct calldata dynamic array -> storage assignment is unsupported).
        address[] storage tStore = _proposalTargets[proposalId];
        uint256[] storage vStore = _proposalValues[proposalId];
        bytes[] storage cStore = _proposalCalldatas[proposalId];
        for (uint256 i = 0; i < targets.length; i++) {
            tStore.push(targets[i]);
            vStore.push(values[i]);
            cStore.push(calldatas[i]);
        }
        _proposalDescriptions[proposalId] = description;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            calldatas,
            description,
            p.voteStart,
            p.voteEnd
        );

        return proposalId;
    }

    // --- Voting ---
    function castVote(uint256 proposalId, uint8 support) external returns (uint256) {
        return _castVote(proposalId, msg.sender, support);
    }

    function _castVote(uint256 proposalId, address voter, uint8 support)
        internal
        returns (uint256)
    {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        if (state(proposalId) != ProposalState.Active) revert ProposalNotActive();
        if (proposalVoteOf[proposalId][voter] != 0) revert AlreadyVoted();
        if (support > uint8(VoteType.Abstain)) revert InvalidVoteType();

        Proposal storage p = proposals[proposalId];
        uint256 weight = getVotesAtBlock(voter, p.snapshotBlock);

        proposalVoteOf[proposalId][voter] = support + 1;

        if (support == uint8(VoteType.For)) {
            p.forVotes += weight;
        } else if (support == uint8(VoteType.Against)) {
            p.againstVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(voter, proposalId, support, weight);
        return weight;
    }

    // --- Execution ---
    function execute(uint256 proposalId) external payable nonReentrant returns (uint256) {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        if (state(proposalId) != ProposalState.Succeeded) revert ProposalNotSucceeded();

        Proposal storage p = proposals[proposalId];
        p.executed = true;

        address[] memory targets = _proposalTargets[proposalId];
        uint256[] memory values = _proposalValues[proposalId];
        bytes[] memory calldatas = _proposalCalldatas[proposalId];

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory returndata) =
                targets[i].call{value: values[i]}(calldatas[i]);
            if (!success) {
                if (returndata.length > 0) {
                    assembly {
                        revert(add(returndata, 0x20), mload(returndata))
                    }
                }
                revert ExecutionFailed();
            }
        }

        emit ProposalExecuted(proposalId);
        return proposalId;
    }

    // --- Proposal State ---
    function state(uint256 proposalId) public view returns (ProposalState) {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        Proposal storage p = proposals[proposalId];

        if (p.executed) return ProposalState.Executed;
        if (block.timestamp < p.voteStart) return ProposalState.Pending;
        if (block.timestamp < p.voteEnd) return ProposalState.Active;

        if (p.forVotes > p.againstVotes && p.forVotes >= quorumVotes) {
            return ProposalState.Succeeded;
        }
        return ProposalState.Defeated;
    }

    // --- Configuration (only callable via successful proposal) ---
    function setProposalFee(uint256 newFee) external onlyDAO {
        uint256 old = proposalFee;
        proposalFee = newFee;
        emit ProposalFeeUpdated(old, newFee);
    }

    function setQuorum(uint256 newQuorum) external onlyDAO {
        uint256 old = quorumVotes;
        quorumVotes = newQuorum;
        emit QuorumUpdated(old, newQuorum);
    }

    function transferTreasuryToken(address token, address to, uint256 amount) external onlyDAO {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        IERC20(token).transfer(to, amount);
        emit TreasuryTokenTransferred(token, to, amount);
    }

    // --- View Functions ---
    function getVotes(address account) external view returns (uint256) {
        return _currentVotes(account);
    }

    function getVotesAtBlock(address account, uint256 blockNumber) public view returns (uint256) {
        return _getVotesAtBlock(_checkpoints[account], blockNumber);
    }

    function getTotalVotes() external view returns (uint256) {
        return _currentTotalVotes();
    }

    function getTotalVotesAtBlock(uint256 blockNumber) public view returns (uint256) {
        return _getVotesAtBlock(_totalCheckpoints, blockNumber);
    }

    function proposalSnapshot(uint256 proposalId) external view returns (uint256) {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        return proposals[proposalId].snapshotBlock;
    }

    function proposalDeadline(uint256 proposalId) external view returns (uint256) {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        return proposals[proposalId].voteEnd;
    }

    function getProposalActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        )
    {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        return (
            _proposalTargets[proposalId],
            _proposalValues[proposalId],
            _proposalCalldatas[proposalId],
            _proposalDescriptions[proposalId]
        );
    }

    function hasVoted(uint256 proposalId, address account) external view returns (bool) {
        return proposalVoteOf[proposalId][account] != 0;
    }

    function proposalVotes(uint256 proposalId)
        external
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        Proposal storage p = proposals[proposalId];
        return (p.againstVotes, p.forVotes, p.abstainVotes);
    }

    function treasuryBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // --- Internal Helpers ---
    function _effectiveDelegate(address account) internal view returns (address) {
        address d = delegates[account];
        return d == address(0) ? account : d;
    }

    function _currentVotes(address account) internal view returns (uint256) {
        uint256 len = _checkpoints[account].length;
        return len == 0 ? 0 : uint256(_checkpoints[account][len - 1].votes);
    }

    function _currentTotalVotes() internal view returns (uint256) {
        uint256 len = _totalCheckpoints.length;
        return len == 0 ? 0 : uint256(_totalCheckpoints[len - 1].votes);
    }

    function _writeCheckpoint(Checkpoint[] storage ckpts, uint256 newVotes) internal {
        if (newVotes > type(uint192).max) revert VotesOverflow();
        uint256 len = ckpts.length;
        if (len > 0 && ckpts[len - 1].fromBlock == block.number) {
            ckpts[len - 1].votes = uint192(newVotes);
        } else {
            ckpts.push(Checkpoint({fromBlock: uint64(block.number), votes: uint192(newVotes)}));
        }
    }

    function _getVotesAtBlock(Checkpoint[] storage ckpts, uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        if (blockNumber >= block.number) revert FutureLookup();
        uint256 high = ckpts.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (ckpts[mid].fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high == 0 ? 0 : uint256(ckpts[high - 1].votes);
    }
}
