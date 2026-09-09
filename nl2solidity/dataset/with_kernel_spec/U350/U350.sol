// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

contract PredictionMarket {
    error NotOperator();
    error ZeroAddress();
    error MarketNotFound();
    error MarketNotActive();
    error MarketNotResolved();
    error MarketNotCanceled();
    error InvalidOutcome();
    error InsufficientFreeCollateral();
    error AlreadyRedeemed();
    error NothingToRedeem();
    error NothingToWithdraw();
    error InsufficientCollateralToResolve();
    error WinningOutcomeHasNoCollateral();
    error ZeroAmount();
    error TransferFailed();

    uint256 public constant FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_COLLATERAL_UNITS = 100;

    IERC20 public immutable collateralToken;
    uint8 public immutable collateralDecimals;
    uint256 public immutable minCollateralToResolve;
    address public operator;
    uint256 public nextMarketId;
    uint256 public accumulatedFees;

    enum State { Active, Resolved, Canceled }

    struct Market {
        uint256 id;
        uint256 outcomeCount;
        uint256 totalCollateral;
        uint256 winningOutcome;
        uint64 resolvedAt;
        State state;
        string description;
        mapping(uint256 => uint256) outcomeTotals;
        mapping(address => uint256) freeCollateral;
        mapping(address => mapping(uint256 => uint256)) predictions;
        mapping(address => bool) redeemed;
    }

    mapping(uint256 => Market) private markets;

    event MarketCreated(uint256 indexed marketId, address indexed creator, uint256 outcomeCount, string description);
    event CollateralDeposited(uint256 indexed marketId, address indexed depositor, uint256 amount);
    event Prediction(uint256 indexed marketId, address indexed predictor, uint256 indexed outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome, uint256 totalCollateral);
    event MarketCanceled(uint256 indexed marketId);
    event Redeemed(uint256 indexed marketId, address indexed user, uint256 stake, uint256 grossPayout, uint256 fee);
    event Withdrawn(uint256 indexed marketId, address indexed user, uint256 amount);
    event FeesCollected(address indexed operator, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier marketActive(uint256 marketId) {
        Market storage m = markets[marketId];
        if (m.id == 0) revert MarketNotFound();
        if (m.state != State.Active) revert MarketNotActive();
        _;
    }

    constructor(address collateralToken_) {
        if (collateralToken_ == address(0)) revert ZeroAddress();
        collateralToken = IERC20(collateralToken_);
        uint8 dec = 18;
        try IERC20Metadata(collateralToken_).decimals() returns (uint8 d) {
            dec = d;
        } catch {}
        collateralDecimals = dec;
        minCollateralToResolve = MIN_COLLATERAL_UNITS * 10 ** uint256(dec);
        operator = msg.sender;
        nextMarketId = 1;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function createMarket(uint256 outcomeCount, string calldata description) external onlyOperator returns (uint256 marketId) {
        if (outcomeCount < 2) revert InvalidOutcome();
        marketId = nextMarketId++;
        Market storage m = markets[marketId];
        m.id = marketId;
        m.outcomeCount = outcomeCount;
        m.state = State.Active;
        m.description = description;
        emit MarketCreated(marketId, msg.sender, outcomeCount, description);
    }

    function resolveMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator returns (uint256) {
        Market storage m = markets[marketId];
        if (m.id == 0) revert MarketNotFound();
        if (m.state != State.Active) revert MarketNotActive();
        if (m.totalCollateral < minCollateralToResolve) revert InsufficientCollateralToResolve();
        if (winningOutcome >= m.outcomeCount) revert InvalidOutcome();
        if (m.outcomeTotals[winningOutcome] == 0) revert WinningOutcomeHasNoCollateral();
        m.state = State.Resolved;
        m.winningOutcome = winningOutcome;
        m.resolvedAt = uint64(block.timestamp);
        emit MarketResolved(marketId, winningOutcome, m.totalCollateral);
        return marketId;
    }

    function cancelMarket(uint256 marketId) external onlyOperator returns (uint256) {
        Market storage m = markets[marketId];
        if (m.id == 0) revert MarketNotFound();
        if (m.state != State.Active) revert MarketNotActive();
        m.state = State.Canceled;
        emit MarketCanceled(marketId);
        return marketId;
    }

    function deposit(uint256 marketId, uint256 amount) external marketActive(marketId) {
        if (amount == 0) revert ZeroAmount();
        Market storage m = markets[marketId];
        m.freeCollateral[msg.sender] += amount;
        m.totalCollateral += amount;
        _safeTransferFrom(collateralToken, msg.sender, address(this), amount);
        emit CollateralDeposited(marketId, msg.sender, amount);
    }

    function predict(uint256 marketId, uint256 outcome, uint256 amount) external marketActive(marketId) {
        if (amount == 0) revert ZeroAmount();
        Market storage m = markets[marketId];
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        if (m.freeCollateral[msg.sender] < amount) revert InsufficientFreeCollateral();
        m.freeCollateral[msg.sender] -= amount;
        m.predictions[msg.sender][outcome] += amount;
        m.outcomeTotals[outcome] += amount;
        emit Prediction(marketId, msg.sender, outcome, amount);
    }

    function redeem(uint256 marketId) external returns (uint256 netPayout) {
        Market storage m = markets[marketId];
        if (m.id == 0) revert MarketNotFound();
        if (m.state != State.Resolved) revert MarketNotResolved();
        if (m.redeemed[msg.sender]) revert AlreadyRedeemed();
        uint256 stake = m.predictions[msg.sender][m.winningOutcome];
        if (stake == 0) revert NothingToRedeem();
        m.redeemed[msg.sender] = true;
        uint256 winningTotal = m.outcomeTotals[m.winningOutcome];
        uint256 numerator = stake * m.totalCollateral;
        uint256 grossPayout = numerator / winningTotal;
        uint256 fee = (numerator * FEE_BPS) / (winningTotal * BPS_DENOMINATOR);
        netPayout = grossPayout - fee;
        accumulatedFees += fee;
        if (netPayout > 0) {
            _safeTransfer(collateralToken, msg.sender, netPayout);
        }
        emit Redeemed(marketId, msg.sender, stake, grossPayout, fee);
    }

    function withdraw(uint256 marketId) external returns (uint256 amount) {
        Market storage m = markets[marketId];
        if (m.id == 0) revert MarketNotFound();
        if (m.state != State.Canceled) revert MarketNotCanceled();
        amount = m.freeCollateral[msg.sender];
        m.freeCollateral[msg.sender] = 0;
        for (uint256 i = 0; i < m.outcomeCount; i++) {
            uint256 pred = m.predictions[msg.sender][i];
            if (pred > 0) {
                m.predictions[msg.sender][i] = 0;
                amount += pred;
            }
        }
        if (amount == 0) revert NothingToWithdraw();
        m.totalCollateral -= amount;
        _safeTransfer(collateralToken, msg.sender, amount);
        emit Withdrawn(marketId, msg.sender, amount);
    }

    function collectFees() external onlyOperator returns (uint256 amount) {
        amount = accumulatedFees;
        accumulatedFees = 0;
        if (amount > 0) {
            _safeTransfer(collateralToken, operator, amount);
        }
        emit FeesCollected(operator, amount);
    }

    function getMarketInfo(uint256 marketId) external view returns (
        uint256 id,
        uint256 outcomeCount,
        uint256 totalCollateral,
        uint256 winningOutcome,
        uint64 resolvedAt,
        State state,
        string memory description
    ) {
        Market storage m = markets[marketId];
        return (m.id, m.outcomeCount, m.totalCollateral, m.winningOutcome, m.resolvedAt, m.state, m.description);
    }

    function getOutcomeTotal(uint256 marketId, uint256 outcome) external view returns (uint256) {
        return markets[marketId].outcomeTotals[outcome];
    }

    function getFreeCollateral(uint256 marketId, address user) external view returns (uint256) {
        return markets[marketId].freeCollateral[user];
    }

    function getPrediction(uint256 marketId, address user, uint256 outcome) external view returns (uint256) {
        return markets[marketId].predictions[user][outcome];
    }

    function hasRedeemed(uint256 marketId, address user) external view returns (bool) {
        return markets[marketId].redeemed[user];
    }
}
