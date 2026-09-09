// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PredictionMarket {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_ACTIVE_MARKETS = 100;
    uint256 public constant CREATION_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_INTERACTION_FEE_BPS = 1000; // 10%
    uint256 private constant BPS_DENOMINATOR = 10000;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Market {
        address creator;
        uint256 outcomeCount;
        uint256 totalLiquidity;
        uint256 totalBets;
        uint256 closeTime;
        bool resolved;
        uint256 winningOutcome;
        uint256 resolutionFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => uint256)) public liquidityPositions;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userBets;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeBets;
    mapping(uint256 => mapping(address => bool)) public hasWithdrawn;

    uint256 public activeMarketCount;
    uint256 public interactionFeeBps;
    address public operator;
    uint256 public nextMarketId;
    uint256 public operatorFees;

    bool private _locked;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        uint256 outcomeCount,
        uint256 initialLiquidity,
        uint256 closeTime
    );
    event LiquidityAdded(uint256 indexed marketId, address indexed provider, uint256 amount);
    event BetPlaced(uint256 indexed marketId, address indexed bettor, uint256 outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint8 winningOutcome, uint256 totalPool);
    event Withdrawn(uint256 indexed marketId, address indexed account, uint256 amount);
    event FeePercentageUpdated(uint256 newFeeBps);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OperatorFeesWithdrawn(uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    modifier marketExists(uint256 marketId) {
        require(markets[marketId].creator != address(0), "MARKET_NOT_FOUND");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "REENTRANT");
        _locked = true;
        _;
        _locked = false;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 _interactionFeeBps) {
        require(_interactionFeeBps <= MAX_INTERACTION_FEE_BPS, "FEE_TOO_HIGH");
        operator = msg.sender;
        interactionFeeBps = _interactionFeeBps;
        nextMarketId = 1;
        emit OperatorChanged(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           MARKET FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new prediction market. A 0.5% creation fee is deducted from the
    ///         sent ETH and credited to the operator; the remainder becomes initial liquidity.
    /// @param outcomeCount Number of possible outcomes (must be >= 2).
    /// @param closeTime Timestamp after which the market can be resolved.
    /// @return marketId The ID of the newly created market.
    function createMarket(uint256 outcomeCount, uint256 closeTime)
        external
        payable
        returns (uint256 marketId)
    {
        require(outcomeCount >= 2, "NEED_AT_LEAST_2_OUTCOMES");
        require(closeTime > block.timestamp, "CLOSE_TIME_IN_PAST");
        require(msg.value > 0, "MUST_PROVIDE_LIQUIDITY");
        require(activeMarketCount < MAX_ACTIVE_MARKETS, "MAX_MARKETS_REACHED");

        uint256 creationFee = (msg.value * CREATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 initialLiquidity = msg.value - creationFee;
        require(initialLiquidity >= outcomeCount, "LIQUIDITY_TOO_LOW");

        operatorFees += creationFee;

        marketId = nextMarketId++;
        markets[marketId] = Market({
            creator: msg.sender,
            outcomeCount: outcomeCount,
            totalLiquidity: initialLiquidity,
            totalBets: 0,
            closeTime: closeTime,
            resolved: false,
            winningOutcome: 0,
            resolutionFeeBps: 0
        });

        liquidityPositions[marketId][msg.sender] = initialLiquidity;
        activeMarketCount++;

        emit MarketCreated(marketId, msg.sender, outcomeCount, initialLiquidity, closeTime);
        emit LiquidityAdded(marketId, msg.sender, initialLiquidity);
    }

    /// @notice Adds liquidity to an existing, unresolved market.
    /// @param marketId The ID of the market to provide liquidity for.
    function addLiquidity(uint256 marketId) external payable marketExists(marketId) {
        Market storage market = markets[marketId];
        require(!market.resolved, "MARKET_RESOLVED");
        require(block.timestamp < market.closeTime, "MARKET_CLOSED");
        require(msg.value > 0, "MUST_PROVIDE_LIQUIDITY");

        market.totalLiquidity += msg.value;
        liquidityPositions[marketId][msg.sender] += msg.value;

        emit LiquidityAdded(marketId, msg.sender, msg.value);
    }

    /// @notice Places a bet on a specific outcome of an unresolved market.
    /// @param marketId The ID of the market.
    /// @param outcome The outcome index to bet on.
    function placeBet(uint256 marketId, uint256 outcome)
        external
        payable
        marketExists(marketId)
    {
        Market storage market = markets[marketId];
        require(!market.resolved, "MARKET_RESOLVED");
        require(block.timestamp < market.closeTime, "MARKET_CLOSED");
        require(outcome < market.outcomeCount, "INVALID_OUTCOME");
        require(msg.value > 0, "MUST_BET_POSITIVE");

        market.totalBets += msg.value;
        outcomeBets[marketId][outcome] += msg.value;
        userBets[marketId][msg.sender][outcome] += msg.value;

        emit BetPlaced(marketId, msg.sender, outcome, msg.value);
    }

    /// @notice Resolves a market by setting the winning outcome. Only callable by the operator.
    /// @param marketId The ID of the market to resolve.
    /// @param winningOutcome The index of the winning outcome.
    function resolveMarket(uint256 marketId, uint8 winningOutcome)
        external
        onlyOperator
        marketExists(marketId)
    {
        Market storage market = markets[marketId];
        require(!market.resolved, "ALREADY_RESOLVED");
        require(block.timestamp >= market.closeTime, "MARKET_NOT_CLOSED");
        require(winningOutcome < market.outcomeCount, "INVALID_OUTCOME");

        market.resolved = true;
        market.winningOutcome = winningOutcome;
        market.resolutionFeeBps = interactionFeeBps;
        activeMarketCount--;

        uint256 totalPool = market.totalLiquidity + market.totalBets;
        uint256 feeAmount = (totalPool * interactionFeeBps) / BPS_DENOMINATOR;
        operatorFees += feeAmount;

        emit MarketResolved(marketId, winningOutcome, totalPool);
    }

    /// @notice Withdraws a user's winnings (if they bet on the winning outcome) and/or
    ///         their liquidity provider share after the market has been resolved.
    /// @param marketId The ID of the resolved market.
    function withdraw(uint256 marketId)
        external
        nonReentrant
        marketExists(marketId)
    {
        Market storage market = markets[marketId];
        require(market.resolved, "MARKET_NOT_RESOLVED");
        require(!hasWithdrawn[marketId][msg.sender], "ALREADY_WITHDRAWN");

        hasWithdrawn[marketId][msg.sender] = true;

        uint256 totalPool = market.totalLiquidity + market.totalBets;
        uint256 feeBps = market.resolutionFeeBps;
        uint256 payoutMultiplier = BPS_DENOMINATOR - feeBps;

        // Scale the winning pool by outcomeCount to avoid divide-before-multiply
        // precision loss. winningPoolScaled = winningBets * outcomeCount + totalLiquidity
        uint256 winningBets = outcomeBets[marketId][market.winningOutcome];
        uint256 winningPoolScaled = winningBets * market.outcomeCount + market.totalLiquidity;

        uint256 payout = 0;

        if (winningPoolScaled > 0) {
            // Bettor payout: proportional share of the total pool based on winning bet size.
            uint256 userBet = userBets[marketId][msg.sender][market.winningOutcome];
            if (userBet > 0) {
                payout +=
                    (userBet * totalPool * payoutMultiplier * market.outcomeCount) /
                    (winningPoolScaled * BPS_DENOMINATOR);
            }

            // Liquidity provider payout: proportional share based on liquidity contribution.
            uint256 userLiquidity = liquidityPositions[marketId][msg.sender];
            if (userLiquidity > 0) {
                payout +=
                    (userLiquidity * totalPool * payoutMultiplier) /
                    (winningPoolScaled * BPS_DENOMINATOR);
            }
        }

        if (payout > 0) {
            (bool success, ) = payable(msg.sender).call{value: payout}("");
            require(success, "TRANSFER_FAILED");
        }

        emit Withdrawn(marketId, msg.sender, payout);
    }

    /*//////////////////////////////////////////////////////////////
                         OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the interaction fee percentage applied to market payouts.
    /// @param _feeBps New fee in basis points (max 10%).
    function setFeePercentage(uint256 _feeBps) external onlyOperator {
        require(_feeBps <= MAX_INTERACTION_FEE_BPS, "FEE_TOO_HIGH");
        interactionFeeBps = _feeBps;
        emit FeePercentageUpdated(_feeBps);
    }

    /// @notice Transfers operator privileges to a new address.
    /// @param newOperator The address of the new operator.
    function transferOperator(address newOperator) external onlyOperator {
        require(newOperator != address(0), "INVALID_OPERATOR");
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /// @notice Withdraws all accumulated operator fees (creation fees + resolution fees).
    function withdrawOperatorFees() external onlyOperator nonReentrant {
        uint256 amount = operatorFees;
        require(amount > 0, "NO_FEES");
        operatorFees = 0;
        (bool success, ) = payable(operator).call{value: amount}("");
        require(success, "TRANSFER_FAILED");
        emit OperatorFeesWithdrawn(amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns full market details.
    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (Market memory)
    {
        return markets[marketId];
    }

    /// @notice Returns the scaled winning pool size for a resolved market.
    ///         Scaled value = winningBets * outcomeCount + totalLiquidity.
    function getWinningPoolScaled(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        Market storage market = markets[marketId];
        return outcomeBets[marketId][market.winningOutcome] * market.outcomeCount + market.totalLiquidity;
    }

    /// @notice Returns a user's total position in a market (liquidity + all bets).
    function getUserPosition(uint256 marketId, address user)
        external
        view
        marketExists(marketId)
        returns (uint256 liquidity, uint256[] memory bets_)
    {
        Market storage market = markets[marketId];
        liquidity = liquidityPositions[marketId][user];
        bets_ = new uint256[](market.outcomeCount);
        for (uint256 i = 0; i < market.outcomeCount; i++) {
            bets_[i] = userBets[marketId][user][i];
        }
    }

    /// @notice Returns the total pool size (liquidity + bets) for a market.
    function getTotalPool(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (uint256)
    {
        Market storage market = markets[marketId];
        return market.totalLiquidity + market.totalBets;
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Accepts direct ETH transfers (e.g., from selfdestruct or beacon withdrawals).
    receive() external payable {}
}
