// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MoonwellGovernor — a high-level governance model inspired by Moonwell Vaults.
 *
 * Core mechanism (high level)
 * ---------------------------
 * 1. Voting power is sourced from an external VotingEscrow (veWELL). Users lock
 *    WELL in the escrow and receive time-weighted, per-block snapshotted voting
 *    power, queried here via `balanceOfAt` / `totalSupplyAt`.
 * 2. A proposal is a bundle of {target, value, calldata} actions plus a
 *    human-readable description. Proposals can be created by:
 *      a) Any address in the `proposers` whitelist (e.g. the Moonwell Foundation
 *         / safety multisig), or
 *      b) Any community member whose veWELL weight at the previous block is
 *         greater than or equal to `proposalThreshold`.
 * 3. A proposal walks through the following states:
 *      Pending  — voting delay (`votingDelay` blocks) not yet elapsed.
 *      Active   — voting window (`votingPeriod` blocks) is open.
 *      Succeeded — voting closed, quorum met AND for > against.
 *      Defeated — voting closed but conditions not met.
 *      Queued   — scheduled on the timelock, awaiting minimum delay.
 *      Executed — the timelock has been asked to run the actions.
 *      Canceled — withdrawn by proposer / whitelisted proposer before queue.
 * 4. Quorum is `veWELL total supply at the voting-start snapshot *
 *    quorumNumerator / 10_000`. A proposal passes iff
 *    (forVotes + abstainVotes) >= quorum AND forVotes > againstVotes.
 * 5. Vote weight is snapshotted at `startBlock`, so the act of creating a
 *    proposal cannot be front-run by last-minute escrow adjustments.
 * 6. Successful proposals are buffered by an external Timelock before
 *    execution, giving the community a final escape hatch and protecting
 *    against flash-loan style last-minute governance attacks.
 * 7. Mutable governance parameters (quorum numerator, proposer whitelist) are
 *    only modifiable by the timelock itself — i.e. through a successful
 *    proposal — bootstrapping the standard "govern the governance" recursion.
 */

interface IVotingEscrow {
    function balanceOfAt(address account, uint256 timepoint) external view returns (uint256);
    function totalSupplyAt(uint256 timepoint) external view returns (uint256);
}

interface ITimelock {
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 salt
    ) external;
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 salt
    ) external payable;
    function getMinDelay() external view returns (uint256);
}

contract MoonwellGovernor {
    // ---------------------------------------------------------------------
    // Enums & structs
    // ---------------------------------------------------------------------
    enum Support {
        Against,
        For,
        Abstain
    }

    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Queued,
        Executed,
        Canceled
    }

    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 eta;
        bool canceled;
        bool executed;
    }

    struct Receipt {
        bool hasVoted;
        Support support;
        uint256 votes;
    }

    // ---------------------------------------------------------------------
    // Immutable configuration
    // ---------------------------------------------------------------------
    IVotingEscrow public immutable votingEscrow;
    ITimelock public immutable timelock;
    uint256 public immutable votingDelay;
    uint256 public immutable votingPeriod;
    uint256 public immutable proposalThreshold;
    uint256 public constant QUORUM_DENOMINATOR = 10_000;

    // ---------------------------------------------------------------------
    // Mutable governance parameters (only mutable via the timelock)
    // ---------------------------------------------------------------------
    uint256 public quorumNumerator;
    mapping(address => bool) public proposers;

    // ---------------------------------------------------------------------
    // Proposal storage
    // ---------------------------------------------------------------------
    mapping(uint256 => Proposal) internal _proposals;
    mapping(uint256 => mapping(address => Receipt)) internal _receipts;
    mapping(uint256 => uint256) public forVotes;
    mapping(uint256 => uint256) public againstVotes;
    mapping(uint256 => uint256) public abstainVotes;
    uint256 public proposalCount;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes
    );
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event QuorumNumeratorUpdated(uint256 oldNumerator, uint256 newNumerator);
    event ProposerUpdated(address indexed account, bool isProposer);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error BelowProposalThreshold(uint256 weight, uint256 threshold);
    error InvalidState(ProposalState expected, ProposalState actual);
    error AlreadyVoted(address voter);
    error InvalidVote(uint8 support);
    error ArraysLengthMismatch();
    error EmptyProposal();
    error Unauthorized();
    error NotFound(uint256 proposalId);
    error NotEnoughVotingPower(uint256 have, uint256 want);
    error TimelockNotElapsed(uint256 eta, uint256 current);
    error InvalidQuorumNumerator(uint256 value);
    error InvalidParameters();
    error ZeroAddress();

    modifier onlyTimelock() {
        if (msg.sender != address(timelock)) revert Unauthorized();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        address veWELL,
        address timelock_,
        address admin,
        uint256 votingDelay_,
        uint256 votingPeriod_,
        uint256 proposalThreshold_,
        uint256 quorumNumerator_
    ) {
        if (veWELL == address(0) || timelock_ == address(0) || admin == address(0)) revert ZeroAddress();
        if (votingDelay_ == 0 || votingPeriod_ == 0) revert InvalidParameters();
        if (quorumNumerator_ == 0 || quorumNumerator_ > QUORUM_DENOMINATOR) {
            revert InvalidQuorumNumerator(quorumNumerator_);
        }

        votingEscrow = IVotingEscrow(veWELL);
        timelock = ITimelock(timelock_);
        votingDelay = votingDelay_;
        votingPeriod = votingPeriod_;
        proposalThreshold = proposalThreshold_;
        quorumNumerator = quorumNumerator_;
        proposers[admin] = true;

        emit ProposerUpdated(admin, true);
        emit QuorumNumeratorUpdated(0, quorumNumerator_);
    }

    // ---------------------------------------------------------------------
    // Proposal creation
    // ---------------------------------------------------------------------

    /**
     * @notice Create a new governance proposal.
     * @dev Accessible to whitelisted proposers, or any address holding at least
     *      `proposalThreshold` veWELL at the previous block.
     */
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) external returns (uint256) {
        if (targets.length == 0) revert EmptyProposal();
        if (targets.length != values.length || targets.length != calldatas.length) {
            revert ArraysLengthMismatch();
        }

        if (!proposers[msg.sender]) {
            uint256 weight = votingEscrow.balanceOfAt(msg.sender, block.number > 0 ? block.number - 1 : 0);
            if (weight < proposalThreshold) revert BelowProposalThreshold(weight, proposalThreshold);
        }

        uint256 proposalId = ++proposalCount;
        Proposal storage p = _proposals[proposalId];
        p.id = proposalId;
        p.proposer = msg.sender;
        p.targets = targets;
        p.values = values;
        p.calldatas = calldatas;
        p.description = description;
        p.startBlock = block.number + votingDelay;
        p.endBlock = p.startBlock + votingPeriod;

        emit ProposalCreated(proposalId, msg.sender, p.startBlock, p.endBlock, description);

        return proposalId;
    }

    // ---------------------------------------------------------------------
    // Voting
    // ---------------------------------------------------------------------

    /**
     * @notice Cast a vote on an active proposal.
     * @dev Voting power is snapshotted at `startBlock` to prevent last-minute
     *      escrow adjustments from influencing the outcome.
     */
    function castVote(uint256 proposalId, Support support) external returns (uint256) {
        ProposalState s = state(proposalId);
        if (s != ProposalState.Active) revert InvalidState(ProposalState.Active, s);

        Receipt storage r = _receipts[proposalId][msg.sender];
        if (r.hasVoted) revert AlreadyVoted(msg.sender);

        uint256 snapshot = _proposals[proposalId].startBlock;
        uint256 weight = votingEscrow.balanceOfAt(msg.sender, snapshot);
        if (weight == 0) revert NotEnoughVotingPower(0, 1);

        r.hasVoted = true;
        r.support = support;
        r.votes = weight;

        if (support == Support.For) {
            forVotes[proposalId] += weight;
        } else if (support == Support.Against) {
            againstVotes[proposalId] += weight;
        } else if (support == Support.Abstain) {
            abstainVotes[proposalId] += weight;
        } else {
            revert InvalidVote(uint8(support));
        }

        emit VoteCast(msg.sender, proposalId, uint8(support), weight);
        return weight;
    }

    // ---------------------------------------------------------------------
    // State & quorum
    // ---------------------------------------------------------------------

    /**
     * @notice Compute the lifecycle state of a proposal.
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage p = _proposals[proposalId];
        if (p.id == 0) revert NotFound(proposalId);
        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (block.number <= p.startBlock) return ProposalState.Pending;
        if (block.number <= p.endBlock) return ProposalState.Active;
        if (p.eta == 0) {
            return _proposalPassed(proposalId) ? ProposalState.Succeeded : ProposalState.Defeated;
        }
        return ProposalState.Queued;
    }

    function _proposalPassed(uint256 proposalId) internal view returns (bool) {
        return forVotes[proposalId] > againstVotes[proposalId] &&
            (forVotes[proposalId] + abstainVotes[proposalId]) >= quorumVotes(proposalId);
    }

    /**
     * @notice Quorum (in veWELL units) for a given proposal, computed at the
     *         voting-start snapshot.
     */
    function quorumVotes(uint256 proposalId) public view returns (uint256) {
        uint256 startBlock = _proposals[proposalId].startBlock;
        uint256 total = votingEscrow.totalSupplyAt(startBlock);
        return (total * quorumNumerator) / QUORUM_DENOMINATOR;
    }

    // ---------------------------------------------------------------------
    // Queue & execute
    // ---------------------------------------------------------------------

    /**
     * @notice Queue a successful proposal on the timelock.
     */
    function queue(uint256 proposalId) external {
        ProposalState s = state(proposalId);
        if (s != ProposalState.Succeeded) revert InvalidState(ProposalState.Succeeded, s);

        Proposal storage p = _proposals[proposalId];
        uint256 eta = block.timestamp + timelock.getMinDelay();
        p.eta = eta;

        timelock.scheduleBatch(p.targets, p.values, p.calldatas, bytes32(proposalId));

        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @notice Execute a queued proposal through the timelock once the minimum
     *         delay has elapsed.
     */
    function execute(uint256 proposalId) external payable {
        ProposalState s = state(proposalId);
        if (s != ProposalState.Queued) revert InvalidState(ProposalState.Queued, s);

        Proposal storage p = _proposals[proposalId];
        if (block.timestamp < p.eta) revert TimelockNotElapsed(p.eta, block.timestamp);

        p.executed = true;

        timelock.executeBatch{value: msg.value}(p.targets, p.values, p.calldatas, bytes32(proposalId));

        emit ProposalExecuted(proposalId);
    }

    // ---------------------------------------------------------------------
    // Cancel
    // ---------------------------------------------------------------------

    /**
     * @notice Cancel a pending / active / succeeded proposal. Only the proposer
     *         or a whitelisted proposer may call. Queued or executed proposals
     *         cannot be canceled from the governor.
     */
    function cancel(uint256 proposalId) external {
        Proposal storage p = _proposals[proposalId];
        if (p.id == 0) revert NotFound(proposalId);
        if (msg.sender != p.proposer && !proposers[msg.sender]) revert Unauthorized();

        ProposalState s = state(proposalId);
        if (s == ProposalState.Queued || s == ProposalState.Executed) {
            revert InvalidState(ProposalState.Pending, s);
        }

        p.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    // ---------------------------------------------------------------------
    // Parameter administration (timelock-gated)
    // ---------------------------------------------------------------------

    /**
     * @notice Update the quorum numerator. Callable only through a governance
     *         proposal that has executed via the timelock.
     */
    function updateQuorumNumerator(uint256 newNumerator) external onlyTimelock {
        if (newNumerator == 0 || newNumerator > QUORUM_DENOMINATOR) {
            revert InvalidQuorumNumerator(newNumerator);
        }
        uint256 old = quorumNumerator;
        quorumNumerator = newNumerator;
        emit QuorumNumeratorUpdated(old, newNumerator);
    }

    /**
     * @notice Add or remove an address from the proposer whitelist. Callable
     *         only through a governance proposal that has executed via the
     *         timelock.
     */
    function setProposer(address account, bool isProposer) external onlyTimelock {
        if (account == address(0)) revert ZeroAddress();
        proposers[account] = isProposer;
        emit ProposerUpdated(account, isProposer);
    }

    // ---------------------------------------------------------------------
    // View helpers
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the scalar fields of a proposal (arrays excluded to
     *         avoid stack-too-deep).
     */
    function getProposalCore(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            uint256 startBlock,
            uint256 endBlock,
            uint256 eta,
            bool canceled,
            bool executed
        )
    {
        Proposal storage p = _proposals[proposalId];
        return (p.proposer, p.startBlock, p.endBlock, p.eta, p.canceled, p.executed);
    }

    /**
     * @notice Returns the array fields (targets, values, calldatas) of a proposal.
     */
    function getActions(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values_, bytes[] memory calldatas_)
    {
        Proposal storage p = _proposals[proposalId];
        return (p.targets, p.values, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return _receipts[proposalId][voter];
    }

    function proposalVotes(uint256 proposalId)
        external
        view
        returns (uint256 for_, uint256 against, uint256 abstain)
    {
        return (forVotes[proposalId], againstVotes[proposalId], abstainVotes[proposalId]);
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return _receipts[proposalId][voter].hasVoted;
    }

    function proposalSnapshot(uint256 proposalId) public view returns (uint256) {
        return _proposals[proposalId].startBlock;
    }

    function proposalDeadline(uint256 proposalId) public view returns (uint256) {
        return _proposals[proposalId].endBlock;
    }

    function proposalEta(uint256 proposalId) public view returns (uint256) {
        return _proposals[proposalId].eta;
    }
}
