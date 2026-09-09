// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TreasuryGovernance
 * @notice Manages a treasury of the base cryptocurrency (ETH), enabling strategic
 *         deployment through governance-approved investment strategies. Users deposit
 *         ETH to acquire voting power, propose strategies, and vote on proposals.
 *         The owner approves strategies that meet the 51% voting threshold, sets
 *         per-strategy maximum allocation percentages (capped at 25%), and transfers
 *         funds to approved strategies.
 */
contract TreasuryGovernance {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev 25% in basis points — the absolute ceiling for any single strategy's allocation percentage.
    uint256 public constant MAX_STRATEGY_ALLOCATION_PCT = 2500;
    /// @dev 51% in basis points — the minimum share of total voting power required to approve a proposal.
    uint256 public constant APPROVAL_THRESHOLD_PCT = 5100;
    /// @dev Basis points denominator.
    uint256 public constant BASIS_POINTS = 10000;

    /*//////////////////////////////////////////////////////////////
                              OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          VOTING POWER STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Total voting power across all depositors.
    uint256 public totalVotingPower;
    /// @dev Voting power held by each depositor.
    mapping(address => uint256) public votingPower;

    /*//////////////////////////////////////////////////////////////
                         STRATEGY & PROPOSAL STORAGE
    //////////////////////////////////////////////////////////////*/

    enum StrategyStatus {
        Nonexistent,
        Proposed,
        Approved,
        Rejected
    }

    struct Proposal {
        address target;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        bool exists;
        bool approved;
        mapping(address => bool) hasVoted;
    }

    struct Strategy {
        address target;
        uint256 maxAllocationPct; // basis points, 0 means not yet set
        uint256 allocatedAmount;  // cumulative ETH transferred to this strategy
        StrategyStatus status;
        bool exists;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) internal _proposals;

    uint256 public strategyCount;
    mapping(uint256 => Strategy) internal _strategies;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyProposed(
        uint256 indexed proposalId,
        address indexed target,
        address indexed proposer,
        string description
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );
    event StrategyApproved(
        uint256 indexed proposalId,
        uint256 indexed strategyId,
        address indexed target
    );
    event MaxAllocationSet(uint256 indexed strategyId, uint256 maxAllocationPct);
    event FundsTransferred(
        uint256 indexed strategyId,
        address indexed target,
        uint256 amount
    );
    event VotingPowerDeposited(address indexed depositor, uint256 amount);
    event VotingPowerWithdrawn(address indexed withdrawer, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error ZeroAddress();
    error ProposalNotFound();
    error ProposalAlreadyApproved();
    error StrategyNotFound();
    error StrategyNotApproved();
    error InsufficientVotingPower();
    error AlreadyVoted();
    error InsufficientVotes();
    error ExceedsMaxAllocation();
    error InvalidMaxAllocation();
    error TransferFailed();
    error NoVotingPower();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          VOTING POWER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit ETH to acquire voting power on a 1:1 basis. The deposited
     *         ETH becomes part of the treasury balance.
     */
    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        votingPower[msg.sender] += msg.value;
        totalVotingPower += msg.value;
        emit VotingPowerDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw previously deposited ETH, reducing voting power proportionally.
     * @param amount The amount of ETH (voting power) to withdraw.
     */
    function withdrawVotingPower(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (votingPower[msg.sender] < amount) revert InsufficientVotingPower();

        // Effects
        votingPower[msg.sender] -= amount;
        totalVotingPower -= amount;

        // Interactions
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit VotingPowerWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          PROPOSAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Propose a new investment strategy targeting `target` with a human-readable
     *         `description`. The caller must hold voting power.
     * @param target       The address of the investment strategy contract.
     * @param description  A description of the strategy.
     * @return proposalId  The ID of the newly created proposal.
     */
    function proposeStrategy(
        address target,
        string calldata description
    ) external returns (uint256 proposalId) {
        if (target == address(0)) revert ZeroAddress();
        if (votingPower[msg.sender] == 0) revert NoVotingPower();

        proposalId = ++proposalCount;
        Proposal storage p = _proposals[proposalId];
        p.target = target;
        p.description = description;
        p.exists = true;

        emit StrategyProposed(proposalId, target, msg.sender, description);
    }

    /**
     * @notice Cast a vote on a proposed strategy. Each depositor may vote once per proposal.
     * @param proposalId  The ID of the proposal to vote on.
     * @param support     `true` to vote in favor, `false` to vote against.
     */
    function voteOnProposal(uint256 proposalId, bool support) external {
        Proposal storage p = _proposals[proposalId];
        if (!p.exists) revert ProposalNotFound();
        if (p.approved) revert ProposalAlreadyApproved();
        if (p.hasVoted[msg.sender]) revert AlreadyVoted();

        uint256 power = votingPower[msg.sender];
        if (power == 0) revert NoVotingPower();

        p.hasVoted[msg.sender] = true;
        if (support) {
            p.forVotes += power;
        } else {
            p.againstVotes += power;
        }

        emit VoteCast(proposalId, msg.sender, support, power);
    }

    /*//////////////////////////////////////////////////////////////
                       STRATEGY APPROVAL & CONFIG
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approve a proposed strategy. Only the owner may call this, and the
     *         proposal must have received at least 51% of the total voting power
     *         in favor.
     * @param proposalId  The ID of the proposal to approve.
     * @return strategyId The ID of the newly created approved strategy.
     */
    function approveStrategy(
        uint256 proposalId
    ) external onlyOwner returns (uint256 strategyId) {
        Proposal storage p = _proposals[proposalId];
        if (!p.exists) revert ProposalNotFound();
        if (p.approved) revert ProposalAlreadyApproved();
        if (totalVotingPower == 0) revert InsufficientVotes();

        // Require forVotes >= 51% of totalVotingPower
        if (p.forVotes * BASIS_POINTS < totalVotingPower * APPROVAL_THRESHOLD_PCT) {
            revert InsufficientVotes();
        }

        p.approved = true;

        strategyId = ++strategyCount;
        Strategy storage s = _strategies[strategyId];
        s.target = p.target;
        s.maxAllocationPct = 0; // Owner must set via setMaxAllocation
        s.allocatedAmount = 0;
        s.status = StrategyStatus.Approved;
        s.exists = true;

        emit StrategyApproved(proposalId, strategyId, p.target);
    }

    /**
     * @notice Set the maximum allocation percentage for an approved strategy.
     *         Capped at 25% (2500 basis points).
     * @param strategyId        The ID of the approved strategy.
     * @param maxAllocationPct  The max allocation in basis points (e.g., 2000 = 20%).
     */
    function setMaxAllocation(
        uint256 strategyId,
        uint256 maxAllocationPct
    ) external onlyOwner {
        Strategy storage s = _strategies[strategyId];
        if (!s.exists) revert StrategyNotFound();
        if (s.status != StrategyStatus.Approved) revert StrategyNotApproved();
        if (maxAllocationPct == 0 || maxAllocationPct > MAX_STRATEGY_ALLOCATION_PCT) {
            revert InvalidMaxAllocation();
        }

        s.maxAllocationPct = maxAllocationPct;
        emit MaxAllocationSet(strategyId, maxAllocationPct);
    }

    /*//////////////////////////////////////////////////////////////
                         FUND DEPLOYMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer ETH from the treasury to an approved investment strategy.
     *         The cumulative amount allocated to the strategy must not exceed
     *         `maxAllocationPct` of the current treasury balance.
     * @param strategyId  The ID of the approved strategy.
     * @param amount      The amount of ETH to transfer.
     */
    function transferToStrategy(uint256 strategyId, uint256 amount) external onlyOwner {
        Strategy storage s = _strategies[strategyId];
        if (!s.exists) revert StrategyNotFound();
        if (s.status != StrategyStatus.Approved) revert StrategyNotApproved();
        if (s.maxAllocationPct == 0) revert InvalidMaxAllocation();
        if (amount == 0) revert ZeroAmount();

        uint256 treasuryBalance = address(this).balance;
        if (amount > treasuryBalance) revert ExceedsMaxAllocation();

        uint256 maxAllowed = (treasuryBalance * s.maxAllocationPct) / BASIS_POINTS;
        if (s.allocatedAmount + amount > maxAllowed) revert ExceedsMaxAllocation();

        // Effects
        s.allocatedAmount += amount;

        // Interactions
        (bool success, ) = s.target.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsTransferred(strategyId, s.target, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current treasury balance (total ETH held by the contract).
     */
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns the cumulative amount allocated to a given strategy.
     */
    function getAllocation(uint256 strategyId) external view returns (uint256) {
        if (!_strategies[strategyId].exists) revert StrategyNotFound();
        return _strategies[strategyId].allocatedAmount;
    }

    /**
     * @notice Returns detailed information about a proposal.
     */
    function getProposalInfo(
        uint256 proposalId
    )
        external
        view
        returns (
            address target,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            bool approved
        )
    {
        Proposal storage p = _proposals[proposalId];
        if (!p.exists) revert ProposalNotFound();
        return (p.target, p.description, p.forVotes, p.againstVotes, p.approved);
    }

    /**
     * @notice Returns detailed information about an approved strategy.
     */
    function getStrategyInfo(
        uint256 strategyId
    )
        external
        view
        returns (
            address target,
            uint256 maxAllocationPct,
            uint256 allocatedAmount,
            StrategyStatus status
        )
    {
        Strategy storage s = _strategies[strategyId];
        if (!s.exists) revert StrategyNotFound();
        return (s.target, s.maxAllocationPct, s.allocatedAmount, s.status);
    }

    /**
     * @notice Returns the voting power of a given account.
     */
    function getVotingPower(address account) external view returns (uint256) {
        return votingPower[account];
    }

    /**
     * @notice Returns whether a voter has voted on a given proposal.
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return _proposals[proposalId].hasVoted[voter];
    }

    /*//////////////////////////////////////////////////////////////
                          OWNERSHIP TRANSFER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer contract ownership to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE ETHER
    //////////////////////////////////////////////////////////////*/

    /// @dev Allows the treasury to receive ETH directly, increasing the treasury balance.
    receive() external payable {}
}
