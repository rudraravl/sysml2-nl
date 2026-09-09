// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        if (address(token).code.length == 0) revert("SafeERC20: call to non-contract");
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert("SafeERC20: transfer failed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (address(token).code.length == 0) revert("SafeERC20: call to non-contract");
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert("SafeERC20: transferFrom failed");
        }
    }
}

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert("ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != _owner) revert("Ownable: caller is not the owner");
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert("Ownable: zero address");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert("Ownable: zero address");
        address previous = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }
}

contract CapitalAllocationVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_WITHDRAWAL_FEE_BPS = 50;
    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 1_000;
    uint256 public constant MIN_APPROVAL_BPS = 6_000;

    struct Member {
        uint256 deposited;
        uint256 votingPower;
        uint256 joinedAt;
    }

    struct Strategy {
        address asset;
        address provider;
        uint256 amount;
        bool executed;
        bool active;
        uint256 proposedAt;
    }

    struct Proposal {
        uint256 strategyId;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 totalVotingPowerSnapshot;
        bool passed;
        bool decided;
    }

    address public operator;
    uint256 public withdrawalFeeBps;

    mapping(address => Member) public members;
    mapping(address => mapping(address => uint256)) public userTokenDeposits;
    mapping(address => bool) public approvedTokens;
    mapping(address => bool) public approvedProviders;

    mapping(uint256 => Strategy) public strategies;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public totalDeposited;
    uint256 public totalVotingPower;
    uint256 public strategyCount;
    uint256 public proposalCount;

    event CapitalDeposited(address indexed member, address indexed token, uint256 amount, uint256 newVotingPower);
    event CapitalWithdrawn(address indexed member, address indexed token, uint256 amount, uint256 fee);
    event StrategyProposed(uint256 indexed proposalId, uint256 indexed strategyId, address indexed proposer, address asset, address provider, uint256 amount);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalPassed(uint256 indexed proposalId);
    event ProposalFailed(uint256 indexed proposalId);
    event ProposalDecided(uint256 indexed proposalId, bool passed, uint256 forVotes, uint256 againstVotes, uint256 totalVotingPowerSnapshot);
    event CapitalDeployed(uint256 indexed strategyId, address indexed asset, address indexed provider, uint256 amount);
    event CapitalRedeemed(uint256 indexed strategyId, address indexed asset, address indexed provider, uint256 amountReturned);
    event TokenApprovalUpdated(address indexed token, bool approved);
    event ProviderApprovalUpdated(address indexed provider, bool approved);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event StrategyDeactivated(uint256 indexed strategyId);

    error NotOperator();
    error ZeroAddress();
    error TokenNotApproved();
    error ProviderNotApproved();
    error InvalidAmount();
    error InsufficientCapital();
    error AlreadyVoted();
    error NoVotingPower();
    error ProposalNotPassed();
    error ProposalAlreadyDecided();
    error StrategyInactive();
    error StrategyAlreadyExecuted();
    error StrategyNotExecuted();
    error FeeTooHigh();
    error InvalidProposalId();
    error InvalidStrategyId();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        withdrawalFeeBps = DEFAULT_WITHDRAWAL_FEE_BPS;
        emit OperatorUpdated(address(0), _operator);
        emit WithdrawalFeeUpdated(0, withdrawalFeeBps);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert InvalidAmount();

        Member storage m = members[msg.sender];
        if (m.joinedAt == 0) {
            m.joinedAt = block.timestamp;
        }
        m.deposited += received;
        m.votingPower += received;
        userTokenDeposits[msg.sender][token] += received;
        totalDeposited += received;
        totalVotingPower += received;

        emit CapitalDeposited(msg.sender, token, received, m.votingPower);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 userDeposit = userTokenDeposits[msg.sender][token];
        if (userDeposit < amount) revert InsufficientCapital();
        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientCapital();

        userTokenDeposits[msg.sender][token] -= amount;
        Member storage m = members[msg.sender];
        m.deposited -= amount;
        m.votingPower -= amount;
        totalDeposited -= amount;
        totalVotingPower -= amount;

        uint256 fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        IERC20(token).safeTransfer(msg.sender, payout);

        emit CapitalWithdrawn(msg.sender, token, amount, fee);
    }

    function proposeStrategy(
        address asset,
        address provider,
        uint256 amount
    ) external returns (uint256 proposalId) {
        if (asset == address(0)) revert ZeroAddress();
        if (provider == address(0)) revert ZeroAddress();
        if (!approvedTokens[asset]) revert TokenNotApproved();
        if (!approvedProviders[provider]) revert ProviderNotApproved();
        if (amount == 0) revert InvalidAmount();

        uint256 stratId = strategyCount++;
        strategies[stratId] = Strategy({
            asset: asset,
            provider: provider,
            amount: amount,
            executed: false,
            active: true,
            proposedAt: block.timestamp
        });

        proposalId = proposalCount++;
        proposals[proposalId] = Proposal({
            strategyId: stratId,
            proposer: msg.sender,
            forVotes: 0,
            againstVotes: 0,
            totalVotingPowerSnapshot: totalVotingPower,
            passed: false,
            decided: false
        });

        emit StrategyProposed(proposalId, stratId, msg.sender, asset, provider, amount);
    }

    function vote(uint256 proposalId, bool support) external {
        if (proposalId >= proposalCount) revert InvalidProposalId();
        Proposal storage p = proposals[proposalId];
        if (p.decided) revert ProposalAlreadyDecided();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        uint256 weight = members[msg.sender].votingPower;
        if (weight == 0) revert NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);

        if (!p.passed && p.totalVotingPowerSnapshot > 0 &&
            p.forVotes * BPS_DENOMINATOR >= p.totalVotingPowerSnapshot * MIN_APPROVAL_BPS) {
            p.passed = true;
            emit ProposalPassed(proposalId);
        }
    }

    function decideProposal(uint256 proposalId) external {
        if (proposalId >= proposalCount) revert InvalidProposalId();
        Proposal storage p = proposals[proposalId];
        if (p.decided) revert ProposalAlreadyDecided();

        p.decided = true;
        bool wasPassed = p.passed;
        if (!p.passed && p.totalVotingPowerSnapshot > 0) {
            p.passed = p.forVotes * BPS_DENOMINATOR >= p.totalVotingPowerSnapshot * MIN_APPROVAL_BPS;
        }

        emit ProposalDecided(proposalId, p.passed, p.forVotes, p.againstVotes, p.totalVotingPowerSnapshot);
        if (p.passed && !wasPassed) {
            emit ProposalPassed(proposalId);
        } else if (!p.passed) {
            emit ProposalFailed(proposalId);
        }
    }

    function executeStrategy(uint256 proposalId) external onlyOperator nonReentrant {
        if (proposalId >= proposalCount) revert InvalidProposalId();
        Proposal storage p = proposals[proposalId];
        if (!p.passed) revert ProposalNotPassed();

        Strategy storage s = strategies[p.strategyId];
        if (!s.active) revert StrategyInactive();
        if (s.executed) revert StrategyAlreadyExecuted();
        if (IERC20(s.asset).balanceOf(address(this)) < s.amount) revert InsufficientCapital();

        s.executed = true;
        IERC20(s.asset).safeTransfer(s.provider, s.amount);

        emit CapitalDeployed(p.strategyId, s.asset, s.provider, s.amount);
    }

    function redeemStrategy(uint256 strategyId, uint256 amountReturned) external onlyOperator nonReentrant {
        if (strategyId >= strategyCount) revert InvalidStrategyId();
        Strategy storage s = strategies[strategyId];
        if (!s.executed) revert StrategyNotExecuted();
        if (amountReturned == 0) revert InvalidAmount();

        uint256 balanceBefore = IERC20(s.asset).balanceOf(address(this));
        IERC20(s.asset).safeTransferFrom(s.provider, address(this), amountReturned);
        uint256 received = IERC20(s.asset).balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert InvalidAmount();

        emit CapitalRedeemed(strategyId, s.asset, s.provider, received);
    }

    function deactivateStrategy(uint256 strategyId) external onlyOperator {
        if (strategyId >= strategyCount) revert InvalidStrategyId();
        Strategy storage s = strategies[strategyId];
        if (s.executed) revert StrategyAlreadyExecuted();
        if (!s.active) revert StrategyInactive();
        s.active = false;
        emit StrategyDeactivated(strategyId);
    }

    function setTokenApproval(address token, bool approved) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        approvedTokens[token] = approved;
        emit TokenApprovalUpdated(token, approved);
    }

    function setProviderApproval(address provider, bool approved) external onlyOperator {
        if (provider == address(0)) revert ZeroAddress();
        approvedProviders[provider] = approved;
        emit ProviderApprovalUpdated(provider, approved);
    }

    function setWithdrawalFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_WITHDRAWAL_FEE_BPS) revert FeeTooHigh();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(old, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function getMember(address account) external view returns (Member memory) {
        return members[account];
    }

    function getStrategy(uint256 strategyId) external view returns (Strategy memory) {
        return strategies[strategyId];
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getUserTokenDeposit(address user, address token) external view returns (uint256) {
        return userTokenDeposits[user][token];
    }

    function requiredForVotes(uint256 proposalId) external view returns (uint256) {
        if (proposalId >= proposalCount) revert InvalidProposalId();
        return (proposals[proposalId].totalVotingPowerSnapshot * MIN_APPROVAL_BPS) / BPS_DENOMINATOR;
    }

    function quoteWithdrawalFee(uint256 amount) external view returns (uint256 fee, uint256 payout) {
        fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        payout = amount - fee;
    }
}
