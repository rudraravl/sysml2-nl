// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PredictionMarket {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error MarketNotFound();
    error InvalidOutcomesCount();
    error InvalidCloseTime();
    error InvalidOutcome();
    error ZeroAmount();
    error MarketClosed();
    error MarketNotClosed();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error MarketDisputed();
    error NotDisputed();
    error DisputeWindowClosed();
    error NoPosition();
    error IncorrectPrediction();
    error AlreadyWithdrawn();
    error NotOperator();

    uint256 public constant MIN_OUTCOMES = 2;
    uint256 public constant MAX_OUTCOMES = 10;
    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant DISPUTE_WINDOW = 3 days;

    IERC20 public immutable collateralToken;
    address public operator;
    address public treasury;
    uint256 public marketCount;

    struct Market {
        string description;
        string resolutionCriteria;
        uint256 outcomesCount;
        uint256 closeTime;
        uint256 totalPool;
        uint256 winningOutcome; // 0 = unresolved; otherwise 1-indexed
        uint256 winningPool;
        uint256 resolvedAt;
        bool resolved;
        bool disputed;
        mapping(uint256 => uint256) poolByOutcome;
        mapping(address => mapping(uint256 => uint256)) userStake;
        mapping(address => bool) withdrawn;
    }

    mapping(uint256 => Market) private markets;

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string description,
        string resolutionCriteria,
        uint256 outcomesCount,
        uint256 closeTime
    );
    event Deposited(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed outcome,
        uint256 amount,
        uint256 newTotalPool
    );
    event OutcomeSelected(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed outcome,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        address indexed resolver,
        uint256 indexed winningOutcome,
        uint256 winningPool,
        uint256 totalPool
    );
    event MarketDisputed(uint256 indexed marketId, address indexed disputer);
    event DisputeResolved(uint256 indexed marketId, address indexed resolver, uint256 indexed newWinningOutcome);
    event PayoutDistributed(uint256 indexed marketId, address indexed user, uint256 payout);
    event FeeCollected(uint256 indexed marketId, uint256 feeAmount);
    event ResolutionCriteriaUpdated(uint256 indexed marketId, string newCriteria);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (marketId == 0 || marketId > marketCount) revert MarketNotFound();
        _;
    }

    constructor(address token_, address treasury_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (treasury_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        collateralToken = IERC20(token_);
        treasury = treasury_;
        operator = operator_;
        emit TreasuryUpdated(address(0), treasury_);
        emit OperatorUpdated(address(0), operator_);
    }

    function createMarket(
        string calldata description_,
        string calldata resolutionCriteria_,
        uint256 outcomesCount_,
        uint256 closeTime_
    ) external returns (uint256 marketId) {
        if (outcomesCount_ < MIN_OUTCOMES || outcomesCount_ > MAX_OUTCOMES) revert InvalidOutcomesCount();
        if (closeTime_ <= block.timestamp) revert InvalidCloseTime();

        marketId = ++marketCount;
        Market storage m = markets[marketId];
        m.description = description_;
        m.resolutionCriteria = resolutionCriteria_;
        m.outcomesCount = outcomesCount_;
        m.closeTime = closeTime_;
        m.winningOutcome = 0;

        emit MarketCreated(marketId, msg.sender, description_, resolutionCriteria_, outcomesCount_, closeTime_);
    }

    function deposit(
        uint256 marketId,
        uint256 outcome,
        uint256 amount
    ) external marketExists(marketId) {
        if (amount == 0) revert ZeroAmount();
        Market storage m = markets[marketId];
        if (block.timestamp >= m.closeTime) revert MarketClosed();
        if (outcome == 0 || outcome > m.outcomesCount) revert InvalidOutcome();

        m.userStake[msg.sender][outcome] += amount;
        m.poolByOutcome[outcome] += amount;
        m.totalPool += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(marketId, msg.sender, outcome, amount, m.totalPool);
        emit OutcomeSelected(marketId, msg.sender, outcome, amount);
    }

    function resolveMarket(
        uint256 marketId,
        uint256 winningOutcome_
    ) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (block.timestamp < m.closeTime) revert MarketNotClosed();
        if (m.resolved) revert MarketAlreadyResolved();
        if (winningOutcome_ == 0 || winningOutcome_ > m.outcomesCount) revert InvalidOutcome();

        m.winningOutcome = winningOutcome_;
        m.winningPool = m.poolByOutcome[winningOutcome_];
        m.resolved = true;
        m.resolvedAt = block.timestamp;

        emit MarketResolved(marketId, msg.sender, winningOutcome_, m.winningPool, m.totalPool);
    }

    function disputeResolution(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.resolved) revert MarketNotResolved();
        if (m.disputed) revert MarketDisputed();
        if (block.timestamp > m.resolvedAt + DISPUTE_WINDOW) revert DisputeWindowClosed();

        bool hasPosition;
        for (uint256 i = 1; i <= m.outcomesCount; i++) {
            if (m.userStake[msg.sender][i] > 0) {
                hasPosition = true;
                break;
            }
        }
        if (!hasPosition) revert NoPosition();

        m.disputed = true;
        emit MarketDisputed(marketId, msg.sender);
    }

    function resolveDispute(
        uint256 marketId,
        uint256 newWinningOutcome
    ) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.disputed) revert NotDisputed();
        if (newWinningOutcome == 0 || newWinningOutcome > m.outcomesCount) revert InvalidOutcome();

        m.winningOutcome = newWinningOutcome;
        m.winningPool = m.poolByOutcome[newWinningOutcome];
        m.disputed = false;
        m.resolvedAt = block.timestamp;

        emit DisputeResolved(marketId, msg.sender, newWinningOutcome);
    }

    function withdraw(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.resolved) revert MarketNotResolved();
        if (m.disputed) revert MarketDisputed();
        if (m.withdrawn[msg.sender]) revert AlreadyWithdrawn();

        uint256 stakeOnWinning = m.userStake[msg.sender][m.winningOutcome];
        if (stakeOnWinning == 0) revert IncorrectPrediction();
        if (m.winningPool == 0) revert IncorrectPrediction();

        m.withdrawn[msg.sender] = true;

        uint256 grossPayout = (stakeOnWinning * m.totalPool) / m.winningPool;
        uint256 fee = (grossPayout * FEE_BPS) / BPS_DENOM;
        uint256 netPayout = grossPayout - fee;

        collateralToken.safeTransfer(msg.sender, netPayout);
        if (fee > 0) {
            collateralToken.safeTransfer(treasury, fee);
            emit FeeCollected(marketId, fee);
        }

        emit PayoutDistributed(marketId, msg.sender, netPayout);
    }

    function updateResolutionCriteria(
        uint256 marketId,
        string calldata newCriteria
    ) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (block.timestamp >= m.closeTime) revert MarketClosed();
        m.resolutionCriteria = newCriteria;
        emit ResolutionCriteriaUpdated(marketId, newCriteria);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address previous = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(previous, newTreasury);
    }

    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            string memory description,
            string memory resolutionCriteria,
            uint256 outcomesCount,
            uint256 closeTime,
            uint256 totalPool,
            uint256 winningOutcome,
            uint256 winningPool,
            uint256 resolvedAt,
            bool resolved,
            bool disputed
        )
    {
        Market storage m = markets[marketId];
        return (
            m.description,
            m.resolutionCriteria,
            m.outcomesCount,
            m.closeTime,
            m.totalPool,
            m.winningOutcome,
            m.winningPool,
            m.resolvedAt,
            m.resolved,
            m.disputed
        );
    }

    function getPoolByOutcome(
        uint256 marketId,
        uint256 outcome
    ) external view marketExists(marketId) returns (uint256) {
        return markets[marketId].poolByOutcome[outcome];
    }

    function getUserStake(
        uint256 marketId,
        address user,
        uint256 outcome
    ) external view marketExists(marketId) returns (uint256) {
        return markets[marketId].userStake[user][outcome];
    }

    function hasWithdrawn(
        uint256 marketId,
        address user
    ) external view marketExists(marketId) returns (bool) {
        return markets[marketId].withdrawn[user];
    }

    function disputeWindowEnd(uint256 marketId) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        if (!m.resolved) return 0;
        return m.resolvedAt + DISPUTE_WINDOW;
    }
}
