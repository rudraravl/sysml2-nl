// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract Launchpad {
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrZeroAddress();
    error ErrNotApprovedCreator();
    error ErrInsufficientStake();
    error ErrInsufficientBalance();
    error ErrMilestoneNotMet();
    error ErrNoRewardsDue();
    error ErrDeploymentFailed();
    error ErrAmountZero();
    error ErrTransferFailed();
    error ErrInvalidIndex();

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event RewardPerMilestoneUpdated(uint256 oldReward, uint256 newReward);
    event CreatorApproved(address indexed creator, bool status);
    event TokenDeployed(address indexed creator, address indexed token);
    event MarketCapThresholdSet(address indexed token, uint256 threshold);
    event MarketCapReported(address indexed token, uint256 marketCap, bool milestoneMet);
    event MarketCapMilestoneMet(address indexed token, uint256 marketCap, uint256 reward);
    event RewardsClaimed(address indexed creator, address indexed token, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    IERC20 public immutable platformToken;
    address public owner;
    address public operator;

    uint256 public constant MIN_STAKE = 1000 * 10 ** 18;
    uint256 public constant DEFAULT_MARKET_CAP_THRESHOLD = 1_000_000 * 10 ** 18;

    uint256 public rewardPerMilestone;
    uint256 public totalStaked;

    struct TokenInfo {
        address token;
        uint256 marketCap;
        uint256 marketCapThreshold;
        bool milestoneMet;
        bool rewardClaimed;
        uint256 rewardDue;
    }

    mapping(address => TokenInfo[]) public creatorTokens;
    mapping(address => bool) public approvedCreators;
    mapping(address => uint256) public stakedBalance;

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier onlyGovernance() {
        if (stakedBalance[msg.sender] < MIN_STAKE) revert ErrInsufficientStake();
        _;
    }

    constructor(address platformToken_, address operator_) {
        if (platformToken_ == address(0)) revert ErrZeroAddress();
        if (operator_ == address(0)) revert ErrZeroAddress();
        platformToken = IERC20(platformToken_);
        owner = msg.sender;
        operator = operator_;
        emit OperatorChanged(address(0), operator_);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setRewardPerMilestone(uint256 reward) external onlyOperator {
        emit RewardPerMilestoneUpdated(rewardPerMilestone, reward);
        rewardPerMilestone = reward;
    }

    function approveCreator(address creator, bool status) external onlyOperator {
        if (creator == address(0)) revert ErrZeroAddress();
        approvedCreators[creator] = status;
        emit CreatorApproved(creator, status);
    }

    function deployToken(bytes calldata bytecode) external onlyGovernance returns (address token) {
        if (!approvedCreators[msg.sender]) revert ErrNotApprovedCreator();

        bytes memory code = bytecode;
        assembly {
            token := create(0, add(code, 0x20), mload(code))
        }
        if (token == address(0)) revert ErrDeploymentFailed();

        creatorTokens[msg.sender].push(
            TokenInfo({
                token: token,
                marketCap: 0,
                marketCapThreshold: DEFAULT_MARKET_CAP_THRESHOLD,
                milestoneMet: false,
                rewardClaimed: false,
                rewardDue: 0
            })
        );

        emit TokenDeployed(msg.sender, token);
    }

    function setMarketCapThreshold(address creator, uint256 tokenIndex, uint256 threshold) external onlyOperator {
        TokenInfo[] storage tokens = creatorTokens[creator];
        if (tokenIndex >= tokens.length) revert ErrInvalidIndex();
        TokenInfo storage info = tokens[tokenIndex];
        info.marketCapThreshold = threshold;
        emit MarketCapThresholdSet(info.token, threshold);
    }

    function reportMarketCap(address creator, uint256 tokenIndex, uint256 marketCap) external onlyOperator {
        TokenInfo[] storage tokens = creatorTokens[creator];
        if (tokenIndex >= tokens.length) revert ErrInvalidIndex();
        TokenInfo storage info = tokens[tokenIndex];

        info.marketCap = marketCap;

        bool meetsThreshold = marketCap >= info.marketCapThreshold;
        if (meetsThreshold && !info.milestoneMet) {
            info.milestoneMet = true;
            uint256 reward = rewardPerMilestone;
            info.rewardDue = reward;
            emit MarketCapMilestoneMet(info.token, marketCap, reward);
        }

        emit MarketCapReported(info.token, marketCap, meetsThreshold);
    }

    function claimRewards(uint256 tokenIndex) external {
        TokenInfo[] storage tokens = creatorTokens[msg.sender];
        if (tokenIndex >= tokens.length) revert ErrInvalidIndex();
        TokenInfo storage info = tokens[tokenIndex];

        if (!info.milestoneMet) revert ErrMilestoneNotMet();
        if (info.rewardClaimed) revert ErrNoRewardsDue();

        uint256 reward = info.rewardDue;
        if (reward == 0) revert ErrNoRewardsDue();

        info.rewardClaimed = true;
        info.rewardDue = 0;

        uint256 contractBalance = platformToken.balanceOf(address(this));
        if (contractBalance < reward) revert ErrInsufficientBalance();

        if (!platformToken.transfer(msg.sender, reward)) revert ErrTransferFailed();

        emit RewardsClaimed(msg.sender, info.token, reward);
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ErrAmountZero();
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        if (!platformToken.transferFrom(msg.sender, address(this), amount)) revert ErrTransferFailed();
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        if (amount == 0) revert ErrAmountZero();
        if (stakedBalance[msg.sender] < amount) revert ErrInsufficientBalance();

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        if (!platformToken.transfer(msg.sender, amount)) revert ErrTransferFailed();
        emit Unstaked(msg.sender, amount);
    }

    function getCreatorTokenCount(address creator) external view returns (uint256) {
        return creatorTokens[creator].length;
    }

    function getCreatorToken(address creator, uint256 index) external view returns (
        address token,
        uint256 marketCap,
        uint256 marketCapThreshold,
        bool milestoneMet,
        bool rewardClaimed,
        uint256 rewardDue
    ) {
        TokenInfo storage info = creatorTokens[creator][index];
        return (info.token, info.marketCap, info.marketCapThreshold, info.milestoneMet, info.rewardClaimed, info.rewardDue);
    }

    function isGovernanceParticipant(address user) external view returns (bool) {
        return stakedBalance[user] >= MIN_STAKE;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        owner = newOwner;
    }
}
