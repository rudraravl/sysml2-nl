// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PredictionMarket {
    // --------- Errors ---------
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error MarketNotFound();
    error MarketAlreadyExists();
    error TooManyOutcomes();
    error ZeroOutcomes();
    error InvalidOutcome();
    error MarketNotResolved();
    error MarketAlreadyResolved();
    error InvalidWinningOutcome();
    error InsufficientBalance();
    error TransferFailed();
    error ZeroAmount();
    error MarketClosed();
    error NothingToRedeem();
    error DuplicateOutcomeLabel();

    // --------- Events ---------
    event MarketCreated(uint256 indexed marketId, address indexed creator, string question, uint256 outcomeCount, uint256 feePaid);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event BetPlaced(uint256 indexed marketId, address indexed bettor, uint256 outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome, uint256 totalPool);
    event Redeemed(uint256 indexed marketId, address indexed bettor, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --------- Constants ---------
    uint256 public constant MAX_OUTCOMES = 10;
    uint256 public constant FEE_DENOMINATOR = 1e18;

    // --------- State ---------
    address public owner;
    address public operator;
    IERC20 public immutable collateral;

    uint256 public marketCreationFee; // in collateral token base units
    uint256 public nextMarketId;

    struct Market {
        address creator;
        string question;
        string[] outcomeLabels;
        uint256 outcomeCount;
        uint256[] outcomePools;      // total collateral staked per outcome
        uint256 winningOutcome;      // index of winning outcome
        bool resolved;
        bool exists;
        uint256 createdAt;
        uint256 resolvedAt;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userBets; // marketId => user => outcome => amount
    mapping(uint256 => mapping(address => bool)) public hasRedeemed;                     // marketId => user => redeemed
    mapping(address => uint256) public balances;                                        // available collateral per user

    // --------- Modifiers ---------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (marketId == 0 || marketId >= nextMarketId) revert MarketNotFound();
        _;
    }

    // --------- Constructor ---------
    constructor(address collateralToken, address initialOperator) {
        if (collateralToken == address(0)) revert ZeroAddress();
        if (initialOperator == address(0)) revert ZeroAddress();
        collateral = IERC20(collateralToken);
        owner = msg.sender;
        operator = initialOperator;
        // Default fee: 0.01 collateral tokens assuming 18 decimals.
        marketCreationFee = (1e18 * 1) / 100;
        nextMarketId = 1;
    }

    // --------- Owner functions ---------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setMarketCreationFee(uint256 newFee) external onlyOwner {
        uint256 old = marketCreationFee;
        marketCreationFee = newFee;
        emit CreationFeeUpdated(old, newFee);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    // --------- Deposit / Withdraw ---------
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        bool ok = collateral.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        balances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        bool ok = collateral.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    // --------- Market creation ---------
    function createMarket(
        string calldata question,
        string[] calldata outcomeLabels
    ) external returns (uint256 marketId) {
        uint256 count = outcomeLabels.length;
        if (count == 0) revert ZeroOutcomes();
        if (count > MAX_OUTCOMES) revert TooManyOutcomes();

        // Ensure no duplicate labels.
        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                if (keccak256(bytes(outcomeLabels[i])) == keccak256(bytes(outcomeLabels[j]))) {
                    revert DuplicateOutcomeLabel();
                }
            }
        }

        if (marketCreationFee > 0) {
            if (balances[msg.sender] < marketCreationFee) revert InsufficientBalance();
            balances[msg.sender] -= marketCreationFee;
            // Fee remains in contract as protocol revenue.
        }

        marketId = nextMarketId++;
        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.question = question;
        m.outcomeCount = count;
        m.winningOutcome = type(uint256).max; // sentinel: unresolved
        m.exists = true;
        m.createdAt = block.timestamp;

        for (uint256 i = 0; i < count; i++) {
            m.outcomeLabels.push(outcomeLabels[i]);
            m.outcomePools.push(0);
        }

        emit MarketCreated(marketId, msg.sender, question, count, marketCreationFee);
    }

    // --------- Betting ---------
    function placeBet(uint256 marketId, uint256 outcome, uint256 amount) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.resolved) revert MarketClosed();
        if (amount == 0) revert ZeroAmount();
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;
        m.outcomePools[outcome] += amount;
        userBets[marketId][msg.sender][outcome] += amount;

        emit BetPlaced(marketId, msg.sender, outcome, amount);
    }

    // --------- Resolution ---------
    function resolveMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.resolved) revert MarketAlreadyResolved();
        if (winningOutcome >= m.outcomeCount) revert InvalidWinningOutcome();

        m.resolved = true;
        m.winningOutcome = winningOutcome;
        m.resolvedAt = block.timestamp;

        uint256 totalPool = 0;
        for (uint256 i = 0; i < m.outcomeCount; i++) {
            totalPool += m.outcomePools[i];
        }

        emit MarketResolved(marketId, winningOutcome, totalPool);
    }

    // --------- Redemption ---------
    function redeem(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.resolved) revert MarketNotResolved();
        if (hasRedeemed[marketId][msg.sender]) revert NothingToRedeem();

        uint256 winning = m.winningOutcome;
        uint256 userStake = userBets[marketId][msg.sender][winning];
        if (userStake == 0) revert NothingToRedeem();

        uint256 winningPool = m.outcomePools[winning];
        uint256 totalPool = 0;
        for (uint256 i = 0; i < m.outcomeCount; i++) {
            totalPool += m.outcomePools[i];
        }

        // Pro-rata share of entire market pool.
        uint256 payout;
        if (winningPool == 0 || totalPool == 0) {
            payout = userStake;
        } else {
            payout = (userStake * totalPool) / winningPool;
        }

        // Mark redeemed before transfer (checks-effects-interactions).
        hasRedeemed[marketId][msg.sender] = true;
        userBets[marketId][msg.sender][winning] = 0;

        balances[msg.sender] += payout;

        emit Redeemed(marketId, msg.sender, payout);
    }

    // --------- Views ---------
    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            address creator,
            string memory question,
            uint256 outcomeCount,
            uint256 winningOutcome,
            bool resolved,
            uint256 createdAt,
            uint256 resolvedAt
        )
    {
        Market storage m = markets[marketId];
        return (m.creator, m.question, m.outcomeCount, m.winningOutcome, m.resolved, m.createdAt, m.resolvedAt);
    }

    function getOutcomeLabels(uint256 marketId) external view marketExists(marketId) returns (string[] memory) {
        return markets[marketId].outcomeLabels;
    }

    function getOutcomePools(uint256 marketId) external view marketExists(marketId) returns (uint256[] memory) {
        return markets[marketId].outcomePools;
    }

    function getOutcomePool(uint256 marketId, uint256 outcome) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        return m.outcomePools[outcome];
    }

    function getUserBet(uint256 marketId, address user, uint256 outcome)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        Market storage m = markets[marketId];
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        return userBets[marketId][user][outcome];
    }

    function getPendingPayout(uint256 marketId, address user) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        if (!m.resolved) return 0;
        if (hasRedeemed[marketId][user]) return 0;

        uint256 winning = m.winningOutcome;
        uint256 userStake = userBets[marketId][user][winning];
        if (userStake == 0) return 0;

        uint256 winningPool = m.outcomePools[winning];
        uint256 totalPool = 0;
        for (uint256 i = 0; i < m.outcomeCount; i++) {
            totalPool += m.outcomePools[i];
        }

        if (winningPool == 0 || totalPool == 0) {
            return userStake;
        }
        return (userStake * totalPool) / winningPool;
    }

    function totalMarketPool(uint256 marketId) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        uint256 total = 0;
        for (uint256 i = 0; i < m.outcomeCount; i++) {
            total += m.outcomePools[i];
        }
        return total;
    }

    function marketCount() external view returns (uint256) {
        return nextMarketId - 1;
    }
}
