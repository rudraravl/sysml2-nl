// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract CommunityGovernance {
    error ErrNotAdmin();
    error ErrZeroAmount();
    error ErrDepositsPaused();
    error ErrInsufficientLocked();
    error ErrNothingToWithdraw();
    error ErrProposalNotActive();
    error ErrAlreadyVoted();
    error ErrNothingToClaim();
    error ErrTransferFailed();
    error ErrReentrantCall();
    error ErrZeroAddress();
    error ErrInsufficientRewardBalance();

    event Deposited(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address indexed creator, string description, uint256 startTime, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RoundInitiated(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event RewardClaimed(address indexed user, uint256 amount);
    event DepositsPaused(bool paused);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    struct Lock {
        uint256 amount;
        uint256 unlockTime;
    }

    struct Proposal {
        uint256 id;
        address creator;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool exists;
        mapping(address => bool) hasVoted;
    }

    uint256 public constant MIN_LOCK_AMOUNT = 100;
    uint256 public constant PROPOSAL_DURATION = 7 days;
    uint256 public constant LOCK_DURATION = 7 days;
    uint256 public constant REWARDS_DURATION = 7 days;

    IERC20 public immutable depositToken;
    IERC20 public immutable rewardToken;

    address public admin;
    bool public depositsPaused;
    uint256 private _locked;

    uint256 public currentRoundId;
    uint256 public lastProposalId;

    mapping(address => Lock[]) public locks;
    mapping(address => uint256) public lockedBalanceOf;
    uint256 public totalLocked;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    mapping(uint256 => Proposal) internal _proposals;
    uint256[] public proposalIds;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert ErrNotAdmin();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert ErrDepositsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ErrReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address depositToken_, address rewardToken_, address admin_) {
        if (depositToken_ == address(0) || rewardToken_ == address(0) || admin_ == address(0)) revert ErrZeroAddress();
        depositToken = IERC20(depositToken_);
        rewardToken = IERC20(rewardToken_);
        admin = admin_;
        lastUpdateTime = block.timestamp;
        emit AdminChanged(address(0), admin_);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ErrZeroAddress();
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function setDepositsPaused(bool paused) external onlyAdmin {
        depositsPaused = paused;
        emit DepositsPaused(paused);
    }

    function setRewardRate(uint256 newRate) external onlyAdmin {
        _updateReward(address(0));
        emit RewardRateUpdated(rewardRate, newRate);
        rewardRate = newRate;
    }

    function initiateVotingRound() external onlyAdmin {
        _updateReward(address(0));
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + REWARDS_DURATION;
        currentRoundId += 1;
        emit RoundInitiated(currentRoundId, startTime, endTime);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalLocked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalLocked;
    }

    function earned(address user) public view returns (uint256) {
        return (lockedBalanceOf[user] * (rewardPerToken() - userRewardPerTokenPaid[user])) / 1e18 + rewards[user];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * REWARDS_DURATION;
    }

    function deposit(uint256 amount) external nonReentrant whenDepositsNotPaused {
        if (amount == 0) revert ErrZeroAmount();
        _updateReward(msg.sender);

        uint256 unlockTime = block.timestamp + LOCK_DURATION;
        locks[msg.sender].push(Lock({amount: amount, unlockTime: unlockTime}));

        lockedBalanceOf[msg.sender] += amount;
        totalLocked += amount;

        if (!depositToken.transferFrom(msg.sender, address(this), amount)) revert ErrTransferFailed();

        emit Deposited(msg.sender, amount, unlockTime);
    }

    function withdrawUnlocked() external nonReentrant {
        _updateReward(msg.sender);

        Lock[] storage userLocks = locks[msg.sender];
        uint256 totalWithdrawable = 0;
        uint256 writeIndex = 0;
        for (uint256 i = 0; i < userLocks.length; i++) {
            if (userLocks[i].unlockTime <= block.timestamp) {
                totalWithdrawable += userLocks[i].amount;
            } else {
                if (writeIndex != i) {
                    userLocks[writeIndex] = userLocks[i];
                }
                writeIndex++;
            }
        }
        if (totalWithdrawable < 1) revert ErrNothingToWithdraw();

        for (uint256 i = writeIndex; i < userLocks.length; i++) {
            userLocks.pop();
        }

        lockedBalanceOf[msg.sender] -= totalWithdrawable;
        totalLocked -= totalWithdrawable;

        if (!depositToken.transfer(msg.sender, totalWithdrawable)) revert ErrTransferFailed();

        emit Withdrawn(msg.sender, totalWithdrawable);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;

        uint256 balance = rewardToken.balanceOf(address(this));
        if (reward > balance) {
            if (balance < 1) revert ErrInsufficientRewardBalance();
            reward = balance;
        }
        if (reward < 1) revert ErrNothingToClaim();

        if (!rewardToken.transfer(msg.sender, reward)) revert ErrTransferFailed();

        emit RewardClaimed(msg.sender, reward);
    }

    function createProposal(string calldata description) external nonReentrant {
        if (lockedBalanceOf[msg.sender] < MIN_LOCK_AMOUNT) revert ErrInsufficientLocked();
        if (bytes(description).length == 0) revert ErrZeroAmount();

        lastProposalId += 1;
        uint256 proposalId = lastProposalId;
        Proposal storage p = _proposals[proposalId];
        p.id = proposalId;
        p.creator = msg.sender;
        p.description = description;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + PROPOSAL_DURATION;
        p.exists = true;

        proposalIds.push(proposalId);

        emit ProposalCreated(proposalId, msg.sender, description, p.startTime, p.endTime);
    }

    function vote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage p = _proposals[proposalId];
        if (!p.exists) revert ErrProposalNotActive();
        if (block.timestamp < p.startTime || block.timestamp >= p.endTime) revert ErrProposalNotActive();
        if (p.hasVoted[msg.sender]) revert ErrAlreadyVoted();
        if (lockedBalanceOf[msg.sender] < MIN_LOCK_AMOUNT) revert ErrInsufficientLocked();

        _updateReward(msg.sender);

        uint256 weight = lockedBalanceOf[msg.sender];
        p.hasVoted[msg.sender] = true;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit Voted(proposalId, msg.sender, support, weight);
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address creator,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            uint256 forVotes,
            uint256 againstVotes,
            bool exists
        )
    {
        Proposal storage p = _proposals[proposalId];
        return (p.creator, p.description, p.startTime, p.endTime, p.forVotes, p.againstVotes, p.exists);
    }

    function hasVoted(uint256 proposalId, address user) external view returns (bool) {
        return _proposals[proposalId].hasVoted[user];
    }

    function getLockCount(address user) external view returns (uint256) {
        return locks[user].length;
    }

    function getLock(address user, uint256 index) external view returns (uint256 amount, uint256 unlockTime) {
        Lock memory l = locks[user][index];
        return (l.amount, l.unlockTime);
    }

    function recoverERC20(address token, address to, uint256 amount) external onlyAdmin {
        if (token == address(0) || to == address(0)) revert ErrZeroAddress();
        if (amount == 0) revert ErrZeroAmount();
        if (!IERC20(token).transfer(to, amount)) revert ErrTransferFailed();
        emit Recovered(token, to, amount);
    }

    function _updateReward(address user) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (user != address(0)) {
            rewards[user] = earned(user);
            userRewardPerTokenPaid[user] = rewardPerTokenStored;
        }
    }
}
