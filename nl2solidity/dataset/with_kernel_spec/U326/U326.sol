// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract SportsPredictionMarket {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error Paused();
    error MarketNotFound();
    error MarketAlreadySettled();
    error MarketNotSettled();
    error InvalidOutcome();
    error InvalidOutcomeCount();
    error BetTooSmall();
    error InsufficientBalance();
    error NoWinnings();
    error AlreadyClaimed();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------
    struct Market {
        string description;
        address creator;
        uint256 outcomeCount;
        bool settled;
        uint256 winningOutcome;
        uint256 totalPool;
        uint256 createdAt;
        mapping(uint256 => uint256) outcomePools;
        mapping(address => mapping(uint256 => uint256)) userBets;
        mapping(address => bool) claimed;
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    IERC20 public immutable usdc;
    address public owner;
    address public operator;

    uint256 public marketCreationFee; // 10 USDC (6 decimals)
    uint256 public minBet;            // 5 USDC (6 decimals)
    bool public bettingPaused;

    uint256 public marketCount;
    mapping(uint256 => Market) private markets;

    mapping(address => uint256) public userBalances;

    uint8 private constant USDC_DECIMALS = 6;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event MarketCreated(uint256 indexed marketId, address indexed creator, string description, uint256 outcomeCount, uint256 fee);
    event BetPlaced(uint256 indexed marketId, address indexed bettor, uint256 outcome, uint256 amount);
    event MarketSettled(uint256 indexed marketId, uint256 winningOutcome, uint256 totalPool);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event MinBetUpdated(uint256 oldMin, uint256 newMin);
    event BettingPausedStateChanged(bool paused);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (bettingPaused) revert Paused();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _usdc, address _operator) {
        if (_usdc == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        usdc = IERC20(_usdc);
        owner = msg.sender;
        operator = _operator;
        marketCreationFee = 10 * (10 ** USDC_DECIMALS);
        minBet = 5 * (10 ** USDC_DECIMALS);
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, marketCreationFee);
        emit MinBetUpdated(0, minBet);
    }

    // -----------------------------------------------------------------------
    // Deposit / Withdraw
    // -----------------------------------------------------------------------
    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (!usdc.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        userBalances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (userBalances[msg.sender] < amount) revert InsufficientBalance();
        userBalances[msg.sender] -= amount;
        if (!usdc.transfer(msg.sender, amount)) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // Market lifecycle
    // -----------------------------------------------------------------------
    function createMarket(string calldata description, uint256 outcomeCount)
        external
        whenNotPaused
        returns (uint256 marketId)
    {
        if (outcomeCount < 2) revert InvalidOutcomeCount();
        if (userBalances[msg.sender] < marketCreationFee) revert InsufficientBalance();

        userBalances[msg.sender] -= marketCreationFee;

        marketId = marketCount++;
        Market storage m = markets[marketId];
        m.description = description;
        m.creator = msg.sender;
        m.outcomeCount = outcomeCount;
        m.settled = false;
        m.winningOutcome = 0;
        m.totalPool = 0;
        m.createdAt = block.timestamp;

        emit MarketCreated(marketId, msg.sender, description, outcomeCount, marketCreationFee);
    }

    function placeBet(uint256 marketId, uint256 outcome, uint256 amount) external whenNotPaused {
        if (marketId >= marketCount) revert MarketNotFound();
        if (amount < minBet) revert BetTooSmall();
        if (userBalances[msg.sender] < amount) revert InsufficientBalance();

        Market storage m = markets[marketId];
        if (m.settled) revert MarketAlreadySettled();
        if (outcome >= m.outcomeCount) revert InvalidOutcome();

        userBalances[msg.sender] -= amount;

        m.outcomePools[outcome] += amount;
        m.totalPool += amount;
        m.userBets[msg.sender][outcome] += amount;

        emit BetPlaced(marketId, msg.sender, outcome, amount);
    }

    function settleMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator {
        if (marketId >= marketCount) revert MarketNotFound();

        Market storage m = markets[marketId];
        if (m.settled) revert MarketAlreadySettled();
        if (winningOutcome >= m.outcomeCount) revert InvalidOutcome();

        m.settled = true;
        m.winningOutcome = winningOutcome;

        emit MarketSettled(marketId, winningOutcome, m.totalPool);
    }

    function claimWinnings(uint256 marketId) external {
        if (marketId >= marketCount) revert MarketNotFound();

        Market storage m = markets[marketId];
        if (!m.settled) revert MarketNotSettled();
        if (m.claimed[msg.sender]) revert AlreadyClaimed();

        m.claimed[msg.sender] = true;

        uint256 winning = m.winningOutcome;
        uint256 userBet = m.userBets[msg.sender][winning];
        if (userBet == 0) revert NoWinnings();

        uint256 winningPool = m.outcomePools[winning];
        if (winningPool == 0) revert NoWinnings();

        // Pro-rata share of the total pool
        uint256 winnings = (userBet * m.totalPool) / winningPool;

        userBalances[msg.sender] += winnings;

        emit WinningsClaimed(marketId, msg.sender, winnings);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------
    function getMarket(uint256 marketId)
        external
        view
        returns (
            string memory description,
            address creator,
            uint256 outcomeCount,
            bool settled,
            uint256 winningOutcome,
            uint256 totalPool,
            uint256 createdAt
        )
    {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        return (
            m.description,
            m.creator,
            m.outcomeCount,
            m.settled,
            m.winningOutcome,
            m.totalPool,
            m.createdAt
        );
    }

    function getOutcomePool(uint256 marketId, uint256 outcome) external view returns (uint256) {
        if (marketId >= marketCount) revert MarketNotFound();
        return markets[marketId].outcomePools[outcome];
    }

    function getUserBet(uint256 marketId, address user, uint256 outcome) external view returns (uint256) {
        if (marketId >= marketCount) revert MarketNotFound();
        return markets[marketId].userBets[user][outcome];
    }

    function hasClaimed(uint256 marketId, address user) external view returns (bool) {
        if (marketId >= marketCount) revert MarketNotFound();
        return markets[marketId].claimed[user];
    }

    function getContractBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    // -----------------------------------------------------------------------
    // Admin
    // -----------------------------------------------------------------------
    function setMarketCreationFee(uint256 newFee) external onlyOwner {
        uint256 old = marketCreationFee;
        marketCreationFee = newFee;
        emit FeeUpdated(old, newFee);
    }

    function setMinBet(uint256 newMin) external onlyOwner {
        uint256 old = minBet;
        minBet = newMin;
        emit MinBetUpdated(old, newMin);
    }

    function setBettingPaused(bool paused) external onlyOwner {
        bettingPaused = paused;
        emit BettingPausedStateChanged(paused);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

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
}
