// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/**
 * @title ParimutuelPredictionMarket
 * @notice A parimutuel prediction market for asset price movements. Users stake ETH
 *         on whether an asset's price will be "Up" or "Down" relative to a reference
 *         price recorded at market creation. After the prediction window closes, a
 *         designated operator settles the market with the final price. Winners split
 *         the total pool (minus a 2% fee) in proportion to their stake.
 */
contract ParimutuelPredictionMarket {
    // ============ Enums ============
    enum Outcome {
        None,
        Up,
        Down
    }

    // ============ Structs ============
    struct Market {
        address asset;
        uint256 creationPrice;
        uint256 finalPrice;
        uint256 predictionStart;
        uint256 predictionEnd;
        uint256 settlementEnd;
        uint256 totalUpStake;
        uint256 totalDownStake;
        bool settled;
        Outcome outcome;
        uint256 feeCollected;
    }

    struct Position {
        uint256 amount;
        Outcome side;
        bool claimed;
    }

    // ============ Constants ============
    uint256 public constant MIN_PREDICTION_WINDOW = 30 minutes;
    uint256 public constant MAX_PREDICTION_WINDOW = 24 hours;
    uint256 public constant FEE_BPS = 200; // 2%

    // ============ State Variables ============
    address public owner;
    address public operator;
    address public feeRecipient;
    bool public creationPaused;
    uint256 public marketCount;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Position)) public positions;

    // ============ Events ============
    event MarketCreated(
        uint256 indexed marketId,
        address indexed asset,
        uint256 creationPrice,
        uint256 predictionStart,
        uint256 predictionEnd,
        uint256 settlementEnd
    );
    event Staked(
        uint256 indexed marketId,
        address indexed user,
        Outcome side,
        uint256 amount
    );
    event MarketSettled(
        uint256 indexed marketId,
        uint256 finalPrice,
        Outcome outcome,
        uint256 feeCollected
    );
    event Claimed(uint256 indexed marketId, address indexed user, uint256 amount);
    event CreationPaused();
    event CreationUnpaused();
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Custom Errors ============
    error OnlyOwner();
    error OnlyOperator();
    error CreationPausedError();
    error InvalidPredictionWindow();
    error InvalidSettlementWindow();
    error MarketNotExists();
    error PredictionWindowClosed();
    error PredictionWindowOpen();
    error SettlementWindowClosed();
    error AlreadySettled();
    error AlreadyStaked();
    error InvalidSide();
    error MarketNotSettled();
    error AlreadyClaimed();
    error NotWinner();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroPrice();
    error TransferFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // ============ Constructor ============
    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
    }

    // ============ External Functions ============

    /**
     * @notice Create a new prediction market.
     * @param asset The address of the underlying asset being predicted.
     * @param creationPrice The reference price of the asset at market creation.
     * @param predictionDuration Duration of the prediction window (30 min to 24 hours).
     * @param settlementDuration Duration of the settlement window after prediction ends.
     * @return marketId The ID of the newly created market.
     */
    function createMarket(
        address asset,
        uint256 creationPrice,
        uint256 predictionDuration,
        uint256 settlementDuration
    ) external returns (uint256 marketId) {
        if (creationPaused) revert CreationPausedError();
        if (asset == address(0)) revert ZeroAddress();
        if (creationPrice == 0) revert ZeroPrice();
        if (
            predictionDuration < MIN_PREDICTION_WINDOW ||
            predictionDuration > MAX_PREDICTION_WINDOW
        ) revert InvalidPredictionWindow();
        if (settlementDuration == 0) revert InvalidSettlementWindow();

        marketId = marketCount++;
        uint256 start = block.timestamp;
        uint256 predEnd = start + predictionDuration;
        uint256 settleEnd = predEnd + settlementDuration;

        markets[marketId] = Market({
            asset: asset,
            creationPrice: creationPrice,
            finalPrice: 0,
            predictionStart: start,
            predictionEnd: predEnd,
            settlementEnd: settleEnd,
            totalUpStake: 0,
            totalDownStake: 0,
            settled: false,
            outcome: Outcome.None,
            feeCollected: 0
        });

        emit MarketCreated(marketId, asset, creationPrice, start, predEnd, settleEnd);
    }

    /**
     * @notice Stake ETH on a specific price outcome during the prediction window.
     * @param marketId The market ID to stake on.
     * @param side The predicted outcome (Up or Down).
     */
    function stake(uint256 marketId, Outcome side) external payable {
        if (marketId >= marketCount) revert MarketNotExists();
        if (side != Outcome.Up && side != Outcome.Down) revert InvalidSide();
        if (msg.value == 0) revert ZeroAmount();

        Market storage m = markets[marketId];
        if (block.timestamp >= m.predictionEnd) revert PredictionWindowClosed();

        Position storage pos = positions[marketId][msg.sender];
        if (pos.amount > 0) revert AlreadyStaked();

        pos.amount = msg.value;
        pos.side = side;
        pos.claimed = false;

        if (side == Outcome.Up) {
            m.totalUpStake += msg.value;
        } else {
            m.totalDownStake += msg.value;
        }

        emit Staked(marketId, msg.sender, side, msg.value);
    }

    /**
     * @notice Settle a market by providing the final asset price. Only callable by the operator.
     * @param marketId The market ID to settle.
     * @param finalPrice The final price of the asset at settlement.
     */
    function settleMarket(uint256 marketId, uint256 finalPrice) external onlyOperator {
        if (marketId >= marketCount) revert MarketNotExists();
        Market storage m = markets[marketId];
        if (m.settled) revert AlreadySettled();
        if (block.timestamp < m.predictionEnd) revert PredictionWindowOpen();
        if (block.timestamp >= m.settlementEnd) revert SettlementWindowClosed();

        m.finalPrice = finalPrice;
        m.outcome = finalPrice >= m.creationPrice ? Outcome.Up : Outcome.Down;
        m.settled = true;

        uint256 losingStake = m.outcome == Outcome.Up
            ? m.totalDownStake
            : m.totalUpStake;
        uint256 fee = (losingStake * FEE_BPS) / 10000;
        m.feeCollected = fee;

        if (fee > 0) {
            (bool ok, ) = feeRecipient.call{value: fee}("");
            if (!ok) revert TransferFailed();
        }

        emit MarketSettled(marketId, finalPrice, m.outcome, fee);
    }

    /**
     * @notice Claim winnings from a settled market. Only winners can claim.
     * @param marketId The market ID to claim from.
     */
    function claim(uint256 marketId) external {
        if (marketId >= marketCount) revert MarketNotExists();
        Market storage m = markets[marketId];
        if (!m.settled) revert MarketNotSettled();

        Position storage pos = positions[marketId][msg.sender];
        if (pos.amount == 0) revert ZeroAmount();
        if (pos.claimed) revert AlreadyClaimed();
        if (pos.side != m.outcome) revert NotWinner();

        pos.claimed = true;

        uint256 winningSideTotal = m.outcome == Outcome.Up
            ? m.totalUpStake
            : m.totalDownStake;
        uint256 losingStake = m.outcome == Outcome.Up
            ? m.totalDownStake
            : m.totalUpStake;
        uint256 fee = (losingStake * FEE_BPS) / 10000;
        uint256 distributable = winningSideTotal + losingStake - fee;
        uint256 payout = (pos.amount * distributable) / winningSideTotal;

        (bool ok, ) = msg.sender.call{value: payout}("");
        if (!ok) revert TransferFailed();

        emit Claimed(marketId, msg.sender, payout);
    }

    /**
     * @notice Pause new market creation. Only callable by the operator.
     */
    function pauseCreation() external onlyOperator {
        if (creationPaused) revert CreationPausedError();
        creationPaused = true;
        emit CreationPaused();
    }

    /**
     * @notice Unpause new market creation. Only callable by the operator.
     */
    function unpauseCreation() external onlyOperator {
        if (!creationPaused) revert CreationPausedError();
        creationPaused = false;
        emit CreationUnpaused();
    }

    /**
     * @notice Set a new operator. Only callable by the owner.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Set a new fee recipient. Only callable by the owner.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /**
     * @notice Transfer contract ownership. Only callable by the owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ============ View Functions ============

    /**
     * @notice Get the full market details.
     */
    function getMarket(uint256 marketId) external view returns (Market memory) {
        if (marketId >= marketCount) revert MarketNotExists();
        return markets[marketId];
    }

    /**
     * @notice Get a user's position in a market.
     */
    function getPosition(uint256 marketId, address user) external view returns (Position memory) {
        if (marketId >= marketCount) revert MarketNotExists();
        return positions[marketId][user];
    }

    /**
     * @notice Get the asset's symbol label for display purposes.
     */
    function getAssetLabel(uint256 marketId) external view returns (string memory) {
        if (marketId >= marketCount) revert MarketNotExists();
        address asset = markets[marketId].asset;
        try IERC20Metadata(asset).symbol() returns (string memory sym) {
            return sym;
        } catch {
            return "UNKNOWN";
        }
    }

    /**
     * @notice Calculate the pending payout for a user in a settled market.
     */
    function pendingPayout(uint256 marketId, address user) external view returns (uint256) {
        if (marketId >= marketCount) revert MarketNotExists();
        Market storage m = markets[marketId];
        if (!m.settled) return 0;
        Position storage pos = positions[marketId][user];
        if (pos.amount == 0 || pos.claimed || pos.side != m.outcome) return 0;

        uint256 winningSideTotal = m.outcome == Outcome.Up
            ? m.totalUpStake
            : m.totalDownStake;
        if (winningSideTotal == 0) return 0;
        uint256 losingStake = m.outcome == Outcome.Up
            ? m.totalDownStake
            : m.totalUpStake;
        uint256 fee = (losingStake * FEE_BPS) / 10000;
        uint256 distributable = winningSideTotal + losingStake - fee;
        return (pos.amount * distributable) / winningSideTotal;
    }

    /**
     * @notice Get the total ETH staked in a market (both sides combined).
     */
    function totalPool(uint256 marketId) external view returns (uint256) {
        if (marketId >= marketCount) revert MarketNotExists();
        Market storage m = markets[marketId];
        return m.totalUpStake + m.totalDownStake;
    }

    // ============ Receive ============
    receive() external payable {}
}
