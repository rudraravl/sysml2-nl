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

contract DAppGovernance {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Executed
    }

    struct Proposal {
        address proposer;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 voteStart;
        uint256 voteEnd;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
    }

    error Unauthorized();
    error InvalidAddress();
    error InvalidParameterValue();
    error InsufficientStakeAmount(uint256 required, uint256 provided);
    error InsufficientStakedBalance(uint256 requested, uint256 available);
    error InsufficientVotingPower(uint256 required, uint256 actual);
    error ArrayLengthMismatch();
    error ProposalNotFound();
    error VotingNotActive();
    error AlreadyVoted();
    error NoVotingPower();
    error InvalidVoteType();
    error ProposalAlreadyHandled();
    error VotingNotEnded();
    error QuorumNotReached(uint256 required, uint256 actual);
    error ProposalNotPassed();
    error OnlyProposerCanCancel();
    error CannotCancelActiveProposal();
    error InvalidFeePercent();
    error TransferFailed();
    error ReentrantCall();
    error ExecutionFailed();

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 fee);
    event ProposalSubmitted(
        uint256 indexed proposalId,
        address indexed proposer,
        string description
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event ParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event FeesWithdrawn(address indexed to, uint256 amount);

    uint8 public constant VOTE_AGAINST = 0;
    uint8 public constant VOTE_FOR = 1;
    uint8 public constant VOTE_ABSTAIN = 2;
    uint256 private constant _BASIS_POINTS = 10000;

    IERC20 public immutable governanceToken;
    address public admin;

    mapping(address => uint256) public stakedBalance;
    uint256 public totalStaked;

    uint256 public minStakeAmount = 100 * 10 ** 18;
    uint256 public unstakeFeePercent = 2;
    uint256 public proposalSubmissionFee = 10 * 10 ** 18;
    uint256 public votingDelay = 1 days;
    uint256 public votingPeriod = 7 days;
    uint256 public quorumNumerator = 400;

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor(address _governanceToken, address _admin) {
        if (_governanceToken == address(0)) revert InvalidAddress();
        if (_admin == address(0)) revert InvalidAddress();
        governanceToken = IERC20(_governanceToken);
        admin = _admin;
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount < minStakeAmount) {
            revert InsufficientStakeAmount(minStakeAmount, amount);
        }

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        _safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidParameterValue();

        uint256 userBalance = stakedBalance[msg.sender];
        if (amount > userBalance) {
            revert InsufficientStakedBalance(amount, userBalance);
        }

        uint256 fee = (amount * unstakeFeePercent) / 100;
        uint256 amountAfterFee = amount - fee;

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        if (amountAfterFee > 0) {
            _safeTransfer(msg.sender, amountAfterFee);
        }

        emit Unstaked(msg.sender, amount, fee);
    }

    function submitProposal(
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external nonReentrant returns (uint256 proposalId) {
        if (targets.length != values.length || targets.length != calldatas.length) {
            revert ArrayLengthMismatch();
        }
        if (targets.length == 0) revert ArrayLengthMismatch();
        if (stakedBalance[msg.sender] < minStakeAmount) {
            revert InsufficientVotingPower(minStakeAmount, stakedBalance[msg.sender]);
        }

        proposalId = ++proposalCount;
        Proposal storage prop = proposals[proposalId];
        prop.proposer = msg.sender;
        prop.description = description;
        prop.voteStart = block.timestamp + votingDelay;
        prop.voteEnd = block.timestamp + votingDelay + votingPeriod;

        uint256 len = targets.length;
        for (uint256 i; i < len; ) {
            prop.targets.push(targets[i]);
            prop.values.push(values[i]);
            prop.calldatas.push(calldatas[i]);
            unchecked {
                ++i;
            }
        }

        if (proposalSubmissionFee > 0) {
            _safeTransferFrom(msg.sender, address(this), proposalSubmissionFee);
        }

        emit ProposalSubmitted(proposalId, msg.sender, description);
    }

    function castVote(uint256 proposalId, uint8 support) external nonReentrant {
        Proposal storage prop = proposals[proposalId];
        if (prop.proposer == address(0)) revert ProposalNotFound();
        if (prop.executed || prop.canceled) revert ProposalAlreadyHandled();

        uint256 currentTime = block.timestamp;
        if (currentTime < prop.voteStart || currentTime >= prop.voteEnd) {
            revert VotingNotActive();
        }
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        if (support > VOTE_ABSTAIN) revert InvalidVoteType();

        uint256 weight = stakedBalance[msg.sender];
        if (weight == 0) revert NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;

        if (support == VOTE_FOR) {
            prop.forVotes += weight;
        } else if (support == VOTE_AGAINST) {
            prop.againstVotes += weight;
        } else {
            prop.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    function execute(uint256 proposalId) external nonReentrant {
        Proposal storage prop = proposals[proposalId];
        if (prop.proposer == address(0)) revert ProposalNotFound();
        if (prop.executed || prop.canceled) revert ProposalAlreadyHandled();
        if (block.timestamp < prop.voteEnd) revert VotingNotEnded();

        uint256 totalVotes = prop.forVotes + prop.againstVotes + prop.abstainVotes;
        uint256 requiredQuorum = (quorumNumerator * totalStaked) / _BASIS_POINTS;
        if (totalVotes < requiredQuorum) {
            revert QuorumNotReached(requiredQuorum, totalVotes);
        }
        if (prop.forVotes <= prop.againstVotes) revert ProposalNotPassed();

        prop.executed = true;

        uint256 len = prop.targets.length;
        for (uint256 i; i < len; ) {
            (bool success, ) = prop.targets[i].call{value: prop.values[i]}(
                prop.calldatas[i]
            );
            if (!success) revert ExecutionFailed();
            unchecked {
                ++i;
            }
        }

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external nonReentrant {
        Proposal storage prop = proposals[proposalId];
        if (prop.proposer == address(0)) revert ProposalNotFound();
        if (msg.sender != prop.proposer) revert OnlyProposerCanCancel();
        if (block.timestamp >= prop.voteStart) revert CannotCancelActiveProposal();
        if (prop.executed || prop.canceled) revert ProposalAlreadyHandled();

        prop.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage prop = proposals[proposalId];
        if (prop.proposer == address(0)) revert ProposalNotFound();

        if (prop.executed) return ProposalState.Executed;
        if (prop.canceled) return ProposalState.Canceled;

        uint256 currentTime = block.timestamp;
        if (currentTime < prop.voteStart) return ProposalState.Pending;
        if (currentTime < prop.voteEnd) return ProposalState.Active;

        uint256 totalVotes = prop.forVotes + prop.againstVotes + prop.abstainVotes;
        uint256 requiredQuorum = (quorumNumerator * totalStaked) / _BASIS_POINTS;
        if (totalVotes >= requiredQuorum && prop.forVotes > prop.againstVotes) {
            return ProposalState.Succeeded;
        }
        return ProposalState.Defeated;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        if (proposals[proposalId].proposer == address(0)) revert ProposalNotFound();
        return proposals[proposalId];
    }

    function votingPowerOf(address account) external view returns (uint256) {
        return stakedBalance[account];
    }

    function getProposalStats(uint256 proposalId)
        external
        view
        returns (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes)
    {
        Proposal storage prop = proposals[proposalId];
        if (prop.proposer == address(0)) revert ProposalNotFound();
        return (prop.forVotes, prop.againstVotes, prop.abstainVotes);
    }

    function setMinStakeAmount(uint256 _minStakeAmount) external onlyAdmin {
        uint256 old = minStakeAmount;
        minStakeAmount = _minStakeAmount;
        emit ParameterUpdated("minStakeAmount", old, _minStakeAmount);
    }

    function setProposalSubmissionFee(uint256 _fee) external onlyAdmin {
        uint256 old = proposalSubmissionFee;
        proposalSubmissionFee = _fee;
        emit ParameterUpdated("proposalSubmissionFee", old, _fee);
    }

    function setUnstakeFeePercent(uint256 _feePercent) external onlyAdmin {
        if (_feePercent > 100) revert InvalidFeePercent();
        uint256 old = unstakeFeePercent;
        unstakeFeePercent = _feePercent;
        emit ParameterUpdated("unstakeFeePercent", old, _feePercent);
    }

    function setVotingDelay(uint256 _votingDelay) external onlyAdmin {
        uint256 old = votingDelay;
        votingDelay = _votingDelay;
        emit ParameterUpdated("votingDelay", old, _votingDelay);
    }

    function setVotingPeriod(uint256 _votingPeriod) external onlyAdmin {
        if (_votingPeriod == 0) revert InvalidParameterValue();
        uint256 old = votingPeriod;
        votingPeriod = _votingPeriod;
        emit ParameterUpdated("votingPeriod", old, _votingPeriod);
    }

    function setQuorumNumerator(uint256 _quorumNumerator) external onlyAdmin {
        if (_quorumNumerator > _BASIS_POINTS) revert InvalidParameterValue();
        uint256 old = quorumNumerator;
        quorumNumerator = _quorumNumerator;
        emit ParameterUpdated("quorumNumerator", old, _quorumNumerator);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidAddress();
        address old = admin;
        admin = newAdmin;
        emit AdminTransferred(old, newAdmin);
    }

    function withdrawAccruedFees(address to) external onlyAdmin {
        if (to == address(0)) revert InvalidAddress();
        uint256 contractBalance = governanceToken.balanceOf(address(this));
        if (contractBalance <= totalStaked) revert InvalidParameterValue();
        uint256 withdrawable = contractBalance - totalStaked;
        _safeTransfer(to, withdrawable);
        emit FeesWithdrawn(to, withdrawable);
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(governanceToken).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(governanceToken).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    receive() external payable {}
}
