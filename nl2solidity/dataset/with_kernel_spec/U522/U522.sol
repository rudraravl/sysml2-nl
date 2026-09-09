// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TreasuryGovernance
 * @notice Manages a treasury of governance tokens, delegation of voting power
 *         to delegates, and a proposal lifecycle with a 48-hour execution timelock.
 *
 * Lifecycle:
 *   Pending  --[operator cancel]-->  Canceled
 *   Pending  --[operator queue ]-->  Queued --[operator execute, after 48h]--> Executed
 *
 * Users deposit governance tokens into the treasury to receive voting power, which
 * they may delegate to a representative. A minimum delegation of 100 governance
 * tokens is enforced. Only the designated operator may move proposals through the
 * queue and execution stages, ensuring a controlled, auditable process.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract TreasuryGovernance is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @notice Minimum number of governance tokens that may be delegated at once.
    uint256 public constant MIN_DELEGATION_AMOUNT = 100 * 10 ** 18;

    /// @notice Minimum delay between queuing a proposal and executing it.
    uint256 public constant EXECUTION_TIMELOCK = 48 hours;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountIsZero();
    error AmountBelowMinimum(uint256 provided, uint256 required);
    error NotDelegated();
    error AlreadyDelegated(address currentDelegatee);
    error NoVotingPower();
    error NotOperator();
    error ProposalNotFound();
    error ProposalNotPending();
    error ProposalNotQueued();
    error TimelockNotElapsed(uint256 elapsed, uint256 required);
    error ExecutionFailed();
    error DelegateeCannotBeCaller();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event VotingPowerDelegated(address indexed delegator, address indexed delegatee, uint256 amount);
    event VotingPowerUndelegated(address indexed delegator, address indexed formerDelegatee, uint256 amount);
    event ProposalSubmitted(uint256 indexed proposalId, address indexed proposer, address target, uint256 value, bytes data);
    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 queuedAt, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId, uint256 executedAt);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    enum ProposalState {
        Pending,
        Queued,
        Executed,
        Canceled
    }

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        uint256 queuedAt;
        ProposalState state;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    IERC20 public immutable governanceToken;
    address public operator;

    uint256 public totalSupply;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public votingPower;
    mapping(address => address) public delegateeOf;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) internal proposals;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        if (proposalId >= proposalCount) revert ProposalNotFound();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address _governanceToken, address _operator) {
        if (_governanceToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        governanceToken = IERC20(_governanceToken);
        operator = _operator;
    }

    // ---------------------------------------------------------------------
    // Staking / Treasury
    // ---------------------------------------------------------------------

    /// @notice Deposit governance tokens into the treasury to receive voting power.
    /// @param amount The quantity of governance tokens to deposit.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountIsZero();
        if (governanceToken.allowance(msg.sender, address(this)) < amount) {
            revert InsufficientAllowance();
        }

        governanceToken.safeTransferFrom(msg.sender, address(this), amount);

        stakedBalance[msg.sender] += amount;
        totalSupply += amount;
        votingPower[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw previously deposited governance tokens from the treasury.
    /// @param amount The quantity of governance tokens to withdraw.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountIsZero();
        if (stakedBalance[msg.sender] < amount) revert InsufficientBalance();

        address currentDelegate = delegateeOf[msg.sender];
        if (currentDelegate != address(0)) {
            if (votingPower[currentDelegate] < amount) revert InsufficientBalance();
            votingPower[currentDelegate] -= amount;
        } else {
            if (votingPower[msg.sender] < amount) revert InsufficientBalance();
            votingPower[msg.sender] -= amount;
        }

        stakedBalance[msg.sender] -= amount;
        totalSupply -= amount;

        governanceToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Delegation
    // ---------------------------------------------------------------------

    /// @notice Delegate the caller's entire voting power to another address.
    /// @dev Enforces a minimum staked balance equal to MIN_DELEGATION_AMOUNT.
    function delegate(address to) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert DelegateeCannotBeCaller();
        if (delegateeOf[msg.sender] != address(0)) revert AlreadyDelegated(delegateeOf[msg.sender]);

        uint256 balance = stakedBalance[msg.sender];
        if (balance < MIN_DELEGATION_AMOUNT) {
            revert AmountBelowMinimum(balance, MIN_DELEGATION_AMOUNT);
        }
        if (votingPower[msg.sender] < balance) revert InsufficientBalance();

        delegateeOf[msg.sender] = to;
        votingPower[msg.sender] -= balance;
        votingPower[to] += balance;

        emit VotingPowerDelegated(msg.sender, to, balance);
    }

    /// @notice Undelegate the caller's voting power from its current representative.
    function undelegate() external nonReentrant {
        address currentDelegate = delegateeOf[msg.sender];
        if (currentDelegate == address(0)) revert NotDelegated();

        uint256 balance = stakedBalance[msg.sender];
        if (votingPower[currentDelegate] < balance) revert InsufficientBalance();

        votingPower[currentDelegate] -= balance;
        votingPower[msg.sender] += balance;
        delegateeOf[msg.sender] = address(0);

        emit VotingPowerUndelegated(msg.sender, currentDelegate, balance);
    }

    // ---------------------------------------------------------------------
    // Proposal Lifecycle
    // ---------------------------------------------------------------------

    /// @notice Submit a new proposal for consideration by the operator.
    /// @param target Contract address that will be called upon execution.
    /// @param value  Amount of ETH to send with the call.
    /// @param data   Calldata to send to the target.
    function submitProposal(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (uint256 proposalId) {
        if (target == address(0)) revert ZeroAddress();
        if (votingPower[msg.sender] == 0 && stakedBalance[msg.sender] == 0) revert NoVotingPower();

        proposalId = proposalCount++;
        Proposal storage p = proposals[proposalId];
        p.proposer = msg.sender;
        p.target = target;
        p.value = value;
        p.data = data;
        p.state = ProposalState.Pending;

        emit ProposalSubmitted(proposalId, msg.sender, target, value, data);
    }

    /// @notice Cancel a pending proposal. Only callable by the operator.
    function cancelProposal(uint256 proposalId) external onlyOperator proposalExists(proposalId) {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Pending) revert ProposalNotPending();

        p.state = ProposalState.Canceled;

        emit ProposalCanceled(proposalId);
    }

    /// @notice Queue an approved (pending) proposal for execution after the timelock.
    function queueProposal(uint256 proposalId) external onlyOperator proposalExists(proposalId) {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Pending) revert ProposalNotPending();

        p.state = ProposalState.Queued;
        p.queuedAt = block.timestamp;

        emit ProposalQueued(proposalId, block.timestamp, block.timestamp + EXECUTION_TIMELOCK);
    }

    /// @notice Execute a queued proposal once the 48-hour timelock has elapsed.
    function executeProposal(uint256 proposalId)
        external
        payable
        onlyOperator
        proposalExists(proposalId)
        nonReentrant
    {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Queued) revert ProposalNotQueued();

        uint256 elapsed = block.timestamp - p.queuedAt;
        if (elapsed < EXECUTION_TIMELOCK) {
            revert TimelockNotElapsed(elapsed, EXECUTION_TIMELOCK);
        }

        // Effects before interactions: mark as executed to prevent re-entrance.
        p.state = ProposalState.Executed;

        emit ProposalExecuted(proposalId, block.timestamp);

        (bool success, ) = p.target.call{value: p.value}(p.data);
        if (!success) revert ExecutionFailed();
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Returns the full proposal struct for a given proposal id.
    function getProposal(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (Proposal memory)
    {
        return proposals[proposalId];
    }

    /// @notice Returns the current state of a proposal.
    function getProposalState(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (ProposalState)
    {
        return proposals[proposalId].state;
    }

    /// @notice Returns the timestamp at which a queued proposal may be executed.
    function proposalEta(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (uint256)
    {
        Proposal storage p = proposals[proposalId];
        if (p.state != ProposalState.Queued) return 0;
        return p.queuedAt + EXECUTION_TIMELOCK;
    }

    /// @notice Returns the current voting power of an account.
    function getVotingPower(address account) external view returns (uint256) {
        return votingPower[account];
    }

    /// @notice Returns the address to which an account has delegated its voting power.
    function getDelegatee(address account) external view returns (address) {
        return delegateeOf[account];
    }

    /// @notice Returns whether a queued proposal is currently executable.
    function canExecute(uint256 proposalId) external view proposalExists(proposalId) returns (bool) {
        Proposal storage p = proposals[proposalId];
        return p.state == ProposalState.Queued && block.timestamp >= p.queuedAt + EXECUTION_TIMELOCK;
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------

    /// @notice Transfer operator role to a new address. Only callable by the current operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // ---------------------------------------------------------------------
    // Receive
    // ---------------------------------------------------------------------

    /// @notice Allows the contract to receive ETH, used for proposal execution with value.
    receive() external payable {}
}
