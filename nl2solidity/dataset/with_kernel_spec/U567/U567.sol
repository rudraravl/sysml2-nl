// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PredictionMarket {
    error OnlyOperator();
    error OnlyMarketCreatorOrOperator();
    error WhenPaused();
    error ReentrantCall();
    error MarketDoesNotExist();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error InvalidOutcome();
    error InvalidOutcomes();
    error InsufficientDeposit();
    error ZeroAmount();
    error AlreadyClaimed();
    error NoWinnings();
    error InvalidFeeBps();
    error TransferFailed();
    error EmptyQuestion();
    error InvalidAddress();

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        string[] outcomes,
        uint256 depositAmount,
        uint256 feeAmount
    );
    event PredictionPlaced(
        uint256 indexed marketId,
        address indexed predictor,
        uint256 outcomeIndex,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        address indexed resolver,
        uint256 winningOutcome
    );
    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed claimer,
        uint256 amount
    );
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event FeeUpdated(address indexed operator, uint16 newFeeBps);
    event TreasuryUpdated(address indexed operator, address newTreasury);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    uint256 public constant MIN_CREATION_DEPOSIT = 100 * 10 ** 18;
    uint16 public constant MAX_FEE_BPS = 1000;
    uint16 public constant DEFAULT_FEE_BPS = 50;

    IERC20 public immutable baseToken;
    address public operator;
    address public treasury;
    uint16 public feeBps;
    bool public paused;
    uint256 public nextMarketId;

    struct Market {
        address creator;
        string question;
        string[] outcomes;
        uint256 totalEscrow;
        bool resolved;
        uint256 winningOutcome;
        uint256 createdAt;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomePools;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userPredictions;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(uint256 => mapping(address => uint256)) public userMarketBalance;

    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (markets[marketId].creator == address(0)) revert MarketDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _baseToken, address _treasury) {
        if (_baseToken == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        baseToken = IERC20(_baseToken);
        treasury = _treasury;
        operator = msg.sender;
        feeBps = DEFAULT_FEE_BPS;
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setFeeBps(uint16 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        feeBps = _feeBps;
        emit FeeUpdated(msg.sender, _feeBps);
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert InvalidAddress();
        treasury = _treasury;
        emit TreasuryUpdated(msg.sender, _treasury);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function createMarket(
        string calldata question,
        string[] calldata outcomes,
        uint256 depositAmount,
        uint256 initialOutcome
    ) external whenNotPaused nonReentrant returns (uint256 marketId) {
        if (bytes(question).length == 0) revert EmptyQuestion();
        if (outcomes.length < 2) revert InvalidOutcomes();
        if (depositAmount < MIN_CREATION_DEPOSIT) revert InsufficientDeposit();
        if (initialOutcome >= outcomes.length) revert InvalidOutcome();

        uint256 feeAmount = (depositAmount * feeBps) / 10000;
        uint256 depositAfterFee = depositAmount - feeAmount;

        marketId = nextMarketId++;

        // Effects: record market and balances before external interactions
        markets[marketId] = Market({
            creator: msg.sender,
            question: question,
            outcomes: outcomes,
            totalEscrow: depositAfterFee,
            resolved: false,
            winningOutcome: 0,
            createdAt: block.timestamp
        });

        outcomePools[marketId][initialOutcome] += depositAfterFee;
        userPredictions[marketId][msg.sender][initialOutcome] += depositAfterFee;
        userMarketBalance[marketId][msg.sender] += depositAfterFee;

        emit MarketCreated(marketId, msg.sender, question, outcomes, depositAmount, feeAmount);
        emit PredictionPlaced(marketId, msg.sender, initialOutcome, depositAfterFee);

        // Interactions: pull deposit from creator
        _safeTransferFrom(address(baseToken), msg.sender, address(this), depositAmount);

        // Send fee to treasury
        if (feeAmount > 0) {
            _safeTransfer(address(baseToken), treasury, feeAmount);
        }
    }

    function placePrediction(
        uint256 marketId,
        uint256 outcomeIndex,
        uint256 amount
    ) external whenNotPaused nonReentrant marketExists(marketId) {
        Market storage market = markets[marketId];
        if (market.resolved) revert MarketAlreadyResolved();
        if (amount == 0) revert ZeroAmount();
        if (outcomeIndex >= market.outcomes.length) revert InvalidOutcome();

        // Effects: update state before external transfer
        market.totalEscrow += amount;
        outcomePools[marketId][outcomeIndex] += amount;
        userPredictions[marketId][msg.sender][outcomeIndex] += amount;
        userMarketBalance[marketId][msg.sender] += amount;

        emit PredictionPlaced(marketId, msg.sender, outcomeIndex, amount);

        // Interactions: pull tokens from predictor
        _safeTransferFrom(address(baseToken), msg.sender, address(this), amount);
    }

    function resolveMarket(
        uint256 marketId,
        uint256 winningOutcome
    ) external whenNotPaused marketExists(marketId) {
        Market storage market = markets[marketId];
        if (market.resolved) revert MarketAlreadyResolved();
        if (msg.sender != market.creator && msg.sender != operator) revert OnlyMarketCreatorOrOperator();
        if (winningOutcome >= market.outcomes.length) revert InvalidOutcome();

        market.resolved = true;
        market.winningOutcome = winningOutcome;

        emit MarketResolved(marketId, msg.sender, winningOutcome);
    }

    function claimWinnings(uint256 marketId) external nonReentrant marketExists(marketId) {
        Market storage market = markets[marketId];
        if (!market.resolved) revert MarketNotResolved();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        uint256 winningOutcome = market.winningOutcome;
        uint256 userStake = userPredictions[marketId][msg.sender][winningOutcome];
        if (userStake == 0) revert NoWinnings();

        uint256 winningPool = outcomePools[marketId][winningOutcome];
        if (winningPool == 0) revert NoWinnings();

        // Effects: mark claimed before transfer
        hasClaimed[marketId][msg.sender] = true;

        uint256 payout = (userStake * market.totalEscrow) / winningPool;

        emit WinningsClaimed(marketId, msg.sender, payout);

        // Interactions: send payout
        _safeTransfer(address(baseToken), msg.sender, payout);
    }

    function getOutcomeCount(uint256 marketId) external view marketExists(marketId) returns (uint256) {
        return markets[marketId].outcomes.length;
    }

    function getOutcomeLabel(
        uint256 marketId,
        uint256 outcomeIndex
    ) external view marketExists(marketId) returns (string memory) {
        if (outcomeIndex >= markets[marketId].outcomes.length) revert InvalidOutcome();
        return markets[marketId].outcomes[outcomeIndex];
    }

    function getOutcomePool(
        uint256 marketId,
        uint256 outcomeIndex
    ) external view marketExists(marketId) returns (uint256) {
        return outcomePools[marketId][outcomeIndex];
    }

    function getUserPrediction(
        uint256 marketId,
        address user,
        uint256 outcomeIndex
    ) external view marketExists(marketId) returns (uint256) {
        return userPredictions[marketId][user][outcomeIndex];
    }

    function getUserMarketBalance(
        uint256 marketId,
        address user
    ) external view marketExists(marketId) returns (uint256) {
        return userMarketBalance[marketId][user];
    }

    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            address creator,
            string memory question,
            string[] memory outcomes,
            uint256 totalEscrow,
            bool resolved,
            uint256 winningOutcome,
            uint256 createdAt
        )
    {
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.question,
            m.outcomes,
            m.totalEscrow,
            m.resolved,
            m.winningOutcome,
            m.createdAt
        );
    }

    function calculatePotentialPayout(
        uint256 marketId,
        address user,
        uint256 outcomeIndex
    ) external view marketExists(marketId) returns (uint256 payout) {
        Market storage m = markets[marketId];
        if (outcomeIndex >= m.outcomes.length) revert InvalidOutcome();

        uint256 userStake = userPredictions[marketId][user][outcomeIndex];
        if (userStake == 0) return 0;

        uint256 winningPool = outcomePools[marketId][outcomeIndex];
        if (winningPool == 0) return 0;

        return (userStake * m.totalEscrow) / winningPool;
    }
}
