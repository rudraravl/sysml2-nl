// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract PredictionMarket {
    // ============ Custom Errors ============
    error NotOwner();
    error NotResolver();
    error Paused();
    error Reentrancy();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidQuestion();
    error InvalidNumOutcomes();
    error InvalidOutcome();
    error MarketDoesNotExist();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error StakingClosed();
    error ResolutionTooEarly();
    error InsufficientStake();
    error AlreadyClaimed();
    error NothingToClaim();
    error NoFeesToWithdraw();
    error TransferFailed();

    // ============ Constants ============
    uint256 public constant FEE_BPS = 100; // 1% in basis points
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant STAKING_WINDOW = 24 hours;

    // ============ State Variables ============
    IERC20 public immutable stablecoin;
    address public owner;
    address public resolver;
    bool public paused;
    uint256 public marketCount;
    uint256 public accumulatedFees;
    uint256 private _locked;

    struct Market {
        address creator;
        string question;
        string[] outcomes;
        uint256 creationTime;
        uint256 stakingDeadline;
        bool resolved;
        uint256 winningOutcome;
        uint256 totalStaked;
        uint256 winningOutcomeStake;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeTotals;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userStakes;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    // ============ Events ============
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        uint256 creationTime,
        uint256 stakingDeadline
    );
    event Staked(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed outcomeIndex,
        uint256 amount,
        uint256 totalStaked
    );
    event Withdrawn(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed outcomeIndex,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        uint256 winningOutcome,
        address indexed resolver,
        uint256 totalStaked,
        uint256 winningOutcomeStake,
        uint256 resolutionTime
    );
    event Claimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 grossPayout,
        uint256 fee,
        uint256 netPayout
    );
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event PausedStateChanged(bool paused);
    event ResolverUpdated(address indexed oldResolver, address indexed newResolver);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyResolver() {
        if (msg.sender != resolver) revert NotResolver();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier marketExists(uint256 marketId) {
        if (marketId == 0 || marketId > marketCount) revert MarketDoesNotExist();
        _;
    }

    // ============ Constructor ============
    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        _locked = 1;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============ Owner Functions ============
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    function setResolver(address newResolver) external onlyOwner {
        if (newResolver == address(0)) revert ZeroAddress();
        address old = resolver;
        resolver = newResolver;
        emit ResolverUpdated(old, newResolver);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();
        accumulatedFees = 0;
        bool success = stablecoin.transfer(owner, amount);
        if (!success) revert TransferFailed();
        emit FeesWithdrawn(owner, amount);
    }

    // ============ Market Functions ============
    function createMarket(string calldata question, string[] calldata outcomes)
        external
        whenNotPaused
        returns (uint256 marketId)
    {
        if (bytes(question).length == 0) revert InvalidQuestion();
        if (outcomes.length < 2) revert InvalidNumOutcomes();

        marketId = ++marketCount;
        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.question = question;
        for (uint256 i = 0; i < outcomes.length; i++) {
            m.outcomes.push(outcomes[i]);
        }
        m.creationTime = block.timestamp;
        m.stakingDeadline = block.timestamp + STAKING_WINDOW;

        emit MarketCreated(marketId, msg.sender, question, m.creationTime, m.stakingDeadline);
    }

    function stake(uint256 marketId, uint256 outcomeIndex, uint256 amount)
        external
        whenNotPaused
        nonReentrant
        marketExists(marketId)
    {
        Market storage m = markets[marketId];
        if (amount == 0) revert ZeroAmount();
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcomeIndex >= m.outcomes.length) revert InvalidOutcome();
        if (block.timestamp >= m.stakingDeadline) revert StakingClosed();

        // Effects: update state before external call (checks-effects-interactions)
        m.totalStaked += amount;
        outcomeTotals[marketId][outcomeIndex] += amount;
        userStakes[marketId][msg.sender][outcomeIndex] += amount;

        // Interactions: transfer stablecoin from user to contract
        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit Staked(marketId, msg.sender, outcomeIndex, amount, m.totalStaked);
    }

    function withdraw(uint256 marketId, uint256 outcomeIndex, uint256 amount)
        external
        whenNotPaused
        nonReentrant
        marketExists(marketId)
    {
        Market storage m = markets[marketId];
        if (amount == 0) revert ZeroAmount();
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcomeIndex >= m.outcomes.length) revert InvalidOutcome();

        uint256 current = userStakes[marketId][msg.sender][outcomeIndex];
        if (current < amount) revert InsufficientStake();

        // Effects: update state before external call
        userStakes[marketId][msg.sender][outcomeIndex] = current - amount;
        outcomeTotals[marketId][outcomeIndex] -= amount;
        m.totalStaked -= amount;

        // Interactions
        bool success = stablecoin.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Withdrawn(marketId, msg.sender, outcomeIndex, amount);
    }

    function resolveMarket(uint256 marketId, uint256 winningOutcomeIndex)
        external
        onlyResolver
        whenNotPaused
        marketExists(marketId)
    {
        Market storage m = markets[marketId];
        if (m.resolved) revert MarketAlreadyResolved();
        if (block.timestamp < m.stakingDeadline) revert ResolutionTooEarly();
        if (winningOutcomeIndex >= m.outcomes.length) revert InvalidOutcome();

        m.resolved = true;
        m.winningOutcome = winningOutcomeIndex;
        m.winningOutcomeStake = outcomeTotals[marketId][winningOutcomeIndex];

        emit MarketResolved(
            marketId,
            winningOutcomeIndex,
            msg.sender,
            m.totalStaked,
            m.winningOutcomeStake,
            block.timestamp
        );
    }

    function claim(uint256 marketId) external nonReentrant marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.resolved) revert MarketNotResolved();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        // Effect: mark as claimed before any external call
        hasClaimed[marketId][msg.sender] = true;

        if (m.winningOutcomeStake == 0) {
            // No one staked on the winning outcome; refund each staker their original stake
            uint256 userTotal = 0;
            for (uint256 i = 0; i < m.outcomes.length; i++) {
                userTotal += userStakes[marketId][msg.sender][i];
            }
            if (userTotal == 0) revert NothingToClaim();
            bool success = stablecoin.transfer(msg.sender, userTotal);
            if (!success) revert TransferFailed();
            emit Claimed(marketId, msg.sender, userTotal, 0, userTotal);
            return;
        }

        uint256 userWinningStake = userStakes[marketId][msg.sender][m.winningOutcome];
        if (userWinningStake == 0) revert NothingToClaim();

        // Compute gross payout
        uint256 grossPayout = (userWinningStake * m.totalStaked) / m.winningOutcomeStake;
        // Fix divide-before-multiply: compute fee with all multiplications before division
        // fee = (userWinningStake * m.totalStaked * FEE_BPS) / (m.winningOutcomeStake * BPS_DENOM)
        // This ensures no precision is lost from an intermediate division
        uint256 fee = (userWinningStake * m.totalStaked * FEE_BPS) / (m.winningOutcomeStake * BPS_DENOM);
        uint256 netPayout = grossPayout - fee;

        accumulatedFees += fee;

        bool success = stablecoin.transfer(msg.sender, netPayout);
        if (!success) revert TransferFailed();

        emit Claimed(marketId, msg.sender, grossPayout, fee, netPayout);
    }

    // ============ View Functions ============
    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            address creator,
            string memory question,
            string[] memory outcomes,
            uint256 creationTime,
            uint256 stakingDeadline,
            bool resolved,
            uint256 winningOutcome,
            uint256 totalStaked,
            uint256 winningOutcomeStake
        )
    {
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.question,
            m.outcomes,
            m.creationTime,
            m.stakingDeadline,
            m.resolved,
            m.winningOutcome,
            m.totalStaked,
            m.winningOutcomeStake
        );
    }

    function getOutcomeTotal(uint256 marketId, uint256 outcomeIndex)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        if (outcomeIndex >= markets[marketId].outcomes.length) revert InvalidOutcome();
        return outcomeTotals[marketId][outcomeIndex];
    }

    function getUserStake(uint256 marketId, uint256 outcomeIndex, address user)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        if (outcomeIndex >= markets[marketId].outcomes.length) revert InvalidOutcome();
        return userStakes[marketId][user][outcomeIndex];
    }

    function getPendingPayout(uint256 marketId, address user)
        external
        view
        marketExists(marketId)
        returns (uint256 netPayout, uint256 fee)
    {
        Market storage m = markets[marketId];
        if (!m.resolved || hasClaimed[marketId][user]) {
            return (0, 0);
        }
        if (m.winningOutcomeStake == 0) {
            uint256 userTotal = 0;
            for (uint256 i = 0; i < m.outcomes.length; i++) {
                userTotal += userStakes[marketId][user][i];
            }
            return (userTotal, 0);
        }
        uint256 userWinningStake = userStakes[marketId][user][m.winningOutcome];
        if (userWinningStake == 0) {
            return (0, 0);
        }
        uint256 grossPayout = (userWinningStake * m.totalStaked) / m.winningOutcomeStake;
        // Fix divide-before-multiply: compute fee with all multiplications before division
        fee = (userWinningStake * m.totalStaked * FEE_BPS) / (m.winningOutcomeStake * BPS_DENOM);
        netPayout = grossPayout - fee;
    }

    function getNumOutcomes(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        return markets[marketId].outcomes.length;
    }

    function getOutcomeLabel(uint256 marketId, uint256 outcomeIndex)
        external
        view
        marketExists(marketId)
        returns (string memory)
    {
        if (outcomeIndex >= markets[marketId].outcomes.length) revert InvalidOutcome();
        return markets[marketId].outcomes[outcomeIndex];
    }
}
