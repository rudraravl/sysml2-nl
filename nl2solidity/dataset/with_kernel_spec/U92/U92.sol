// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PredictionMarket {
    uint256 public constant TRADE_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_OUTCOMES = 2;
    uint256 public constant MAX_OUTCOMES = 8;
    uint256 public constant MIN_INITIAL_COLLATERAL_BASE = 100;

    struct Market {
        string question;
        address creator;
        uint8 outcomeCount;
        uint8 winningOutcome;
        bool resolved;
        uint256 totalCollateral;
        uint256 createdAt;
        uint256[] outcomeShares;
    }

    IERC20 public immutable collateralToken;
    uint256 public immutable minimumInitialCollateral;

    address public operator;
    address public treasury;
    uint256 public creationFee;
    uint256 public marketCount;

    mapping(uint256 => Market) private _markets;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) private _positions;

    uint256 private _locked;

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        uint8 outcomeCount,
        uint256 initialCollateral,
        uint256 creationFee
    );
    event CollateralDeposited(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed outcome,
        uint256 amount
    );
    event OutcomeTokensTraded(
        uint256 indexed marketId,
        address indexed trader,
        uint256 indexed fromOutcome,
        uint8 toOutcome,
        uint256 fromAmount,
        uint256 toAmount,
        uint256 feeAmount
    );
    event MarketResolved(uint256 indexed marketId, uint8 winningOutcome, uint256 totalCollateral);
    event Withdrawal(uint256 indexed marketId, address indexed user, uint256 amount);
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event EtherRecovered(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error InvalidQuestion();
    error InvalidOutcomeCount();
    error InvalidOutcome();
    error SameOutcome();
    error MarketNotFound();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error InsufficientInitialCollateral();
    error InsufficientShares();
    error InsufficientLiquidity();
    error OutputTooSmall();
    error NoWinningPosition();
    error NotOperator();
    error ReentrantCall();
    error TransferFailed();
    error EtherNotAccepted();
    error EtherTransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 0) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address _collateralToken, address _treasury) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        treasury = _treasury;
        operator = msg.sender;
        uint8 tokenDecimals = collateralToken.decimals();
        minimumInitialCollateral = MIN_INITIAL_COLLATERAL_BASE * (10 ** uint256(tokenDecimals));
    }

    receive() external payable {
        revert EtherNotAccepted();
    }

    fallback() external payable {
        revert EtherNotAccepted();
    }

    function createMarket(
        string calldata question,
        uint256 outcomeCount,
        uint256 initialCollateral
    ) external nonReentrant {
        if (bytes(question).length == 0) revert InvalidQuestion();
        if (outcomeCount < MIN_OUTCOMES || outcomeCount > MAX_OUTCOMES) revert InvalidOutcomeCount();
        if (initialCollateral < minimumInitialCollateral) revert InsufficientInitialCollateral();

        uint256 marketId = marketCount;
        Market storage m = _markets[marketId];
        m.question = question;
        m.creator = msg.sender;
        m.outcomeCount = uint8(outcomeCount);
        m.createdAt = block.timestamp;
        m.totalCollateral = initialCollateral;

        uint256 baseShare = initialCollateral / outcomeCount;
        uint256 remainder = initialCollateral % outcomeCount;
        for (uint256 i = 0; i < outcomeCount; i++) {
            uint256 share = baseShare;
            if (i == 0) {
                share += remainder;
            }
            m.outcomeShares.push(share);
            _positions[marketId][msg.sender][i] = share;
        }

        marketCount++;

        if (creationFee > 0) {
            if (!collateralToken.transferFrom(msg.sender, treasury, creationFee)) {
                revert TransferFailed();
            }
        }
        if (!collateralToken.transferFrom(msg.sender, address(this), initialCollateral)) {
            revert TransferFailed();
        }

        emit MarketCreated(marketId, msg.sender, question, uint8(outcomeCount), initialCollateral, creationFee);
    }

    function depositCollateral(uint256 marketId, uint256 outcome, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Market storage m = _getMarket(marketId);
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcome >= m.outcomeCount) revert InvalidOutcome();

        _positions[marketId][msg.sender][outcome] += amount;
        m.outcomeShares[outcome] += amount;
        m.totalCollateral += amount;

        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        emit CollateralDeposited(marketId, msg.sender, uint8(outcome), amount);
    }

    function tradeOutcomeTokens(
        uint256 marketId,
        uint256 fromOutcome,
        uint256 toOutcome,
        uint256 fromAmount
    ) external nonReentrant {
        if (fromAmount == 0) revert ZeroAmount();
        Market storage m = _getMarket(marketId);
        if (m.resolved) revert MarketAlreadyResolved();
        if (fromOutcome >= m.outcomeCount || toOutcome >= m.outcomeCount) revert InvalidOutcome();
        if (fromOutcome == toOutcome) revert SameOutcome();

        uint256 userPosition = _positions[marketId][msg.sender][fromOutcome];
        if (userPosition < fromAmount) revert InsufficientShares();

        uint256 fromTotal = m.outcomeShares[fromOutcome];
        uint256 toTotal = m.outcomeShares[toOutcome];
        if (fromTotal == 0 || toTotal == 0) revert InsufficientLiquidity();

        uint256 feeAmount = (fromAmount * TRADE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 toAmount = fromAmount - feeAmount;
        if (toAmount == 0) revert OutputTooSmall();

        _positions[marketId][msg.sender][fromOutcome] = userPosition - fromAmount;
        m.outcomeShares[fromOutcome] = fromTotal - fromAmount;

        _positions[marketId][msg.sender][toOutcome] += toAmount;
        if (feeAmount > 0) {
            _positions[marketId][treasury][toOutcome] += feeAmount;
        }
        m.outcomeShares[toOutcome] = toTotal + fromAmount;

        emit OutcomeTokensTraded(marketId, msg.sender, uint8(fromOutcome), uint8(toOutcome), fromAmount, toAmount, feeAmount);
    }

    function resolveMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator {
        Market storage m = _getMarket(marketId);
        if (m.resolved) revert MarketAlreadyResolved();
        if (winningOutcome >= m.outcomeCount) revert InvalidOutcome();
        if (m.outcomeShares[winningOutcome] == 0) revert InsufficientLiquidity();

        m.resolved = true;
        m.winningOutcome = uint8(winningOutcome);

        emit MarketResolved(marketId, uint8(winningOutcome), m.totalCollateral);
    }

    function withdraw(uint256 marketId) external nonReentrant {
        Market storage m = _getMarket(marketId);
        if (!m.resolved) revert MarketNotResolved();

        uint256 winning = m.winningOutcome;
        uint256 userShares = _positions[marketId][msg.sender][winning];
        if (userShares == 0) revert NoWinningPosition();

        uint256 totalWinningShares = m.outcomeShares[winning];
        uint256 payout = (userShares * m.totalCollateral) / totalWinningShares;
        if (payout == 0) revert ZeroAmount();

        _positions[marketId][msg.sender][winning] = 0;
        m.outcomeShares[winning] = totalWinningShares - userShares;
        m.totalCollateral -= payout;

        if (!collateralToken.transfer(msg.sender, payout)) {
            revert TransferFailed();
        }

        emit Withdrawal(marketId, msg.sender, payout);
    }

    function setCreationFee(uint256 newFee) external onlyOperator {
        uint256 oldFee = creationFee;
        creationFee = newFee;
        emit CreationFeeUpdated(oldFee, newFee);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function recoverEther(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert EtherTransferFailed();
        emit EtherRecovered(to, amount);
    }

    function getMarket(uint256 marketId)
        external
        view
        returns (
            string memory question,
            address creator,
            uint8 outcomeCount,
            uint8 winningOutcome,
            bool resolved,
            uint256 totalCollateral,
            uint256 createdAt,
            uint256[] memory outcomeShares
        )
    {
        Market storage m = _getMarket(marketId);
        return (
            m.question,
            m.creator,
            m.outcomeCount,
            m.winningOutcome,
            m.resolved,
            m.totalCollateral,
            m.createdAt,
            m.outcomeShares
        );
    }

    function getPosition(uint256 marketId, address user, uint256 outcome) external view returns (uint256) {
        Market storage m = _getMarket(marketId);
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        return _positions[marketId][user][outcome];
    }

    function getOutcomeShares(uint256 marketId, uint256 outcome) external view returns (uint256) {
        Market storage m = _getMarket(marketId);
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        return m.outcomeShares[outcome];
    }

    function _getMarket(uint256 marketId) internal view returns (Market storage m) {
        if (marketId >= marketCount) revert MarketNotFound();
        m = _markets[marketId];
    }
}
