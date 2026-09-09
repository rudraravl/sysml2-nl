// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PredictionMarket {
    // ------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error InvalidOutcomeCount();
    error TooManyOutcomes();
    error InvalidOutcome();
    error MarketNotFound();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error InsufficientBalance();
    error AlreadyClaimed();
    error NothingToClaim();
    error NoWinningBets();
    error Unauthorized();
    error FeeTooHigh();
    error TransferFailed();

    // ------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------
    uint256 public constant MAX_OUTCOMES = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant CREATION_FEE_BPS = 50; // 0.5%

    // ------------------------------------------------------------
    // State
    // ------------------------------------------------------------
    address public operator;
    address public feeRecipient;
    uint256 public feeBps;

    struct Market {
        address creator;
        address collateralToken;
        uint256 numOutcomes;
        uint256 totalCollateral;
        uint256 initialCollateral;
        bool resolved;
        uint256 winningOutcome;
        uint256 createdAt;
        uint256 resolvedAt;
    }

    uint256 public marketCount;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeTotals;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public positions;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(address => mapping(address => uint256)) public balances;

    // ------------------------------------------------------------
    // Events
    // ------------------------------------------------------------
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        address indexed collateralToken,
        uint256 numOutcomes,
        uint256 initialCollateral,
        uint256 creationFee
    );
    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        uint256 outcome,
        uint256 amount,
        uint256 fee,
        uint256 netAmount
    );
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome, uint256 totalCollateral);
    event Claimed(uint256 indexed marketId, address indexed user, uint256 winningOutcome, uint256 amount);

    // ------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------
    constructor(address _operator, address _feeRecipient, uint256 _feeBps) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > BPS_DENOMINATOR) revert FeeTooHigh();
        operator = _operator;
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;
    }

    // ------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    // ------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------
    function setFeePercentage(uint256 _feeBps) external onlyOperator {
        if (_feeBps > BPS_DENOMINATOR) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(old, _feeRecipient);
    }

    function transferOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    // ------------------------------------------------------------
    // Deposit / Withdraw
    // ------------------------------------------------------------
    function deposit(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        _safeTransferFrom(token, msg.sender, address(this), amount);
        balances[msg.sender][token] += amount;
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        uint256 avail = balances[msg.sender][token];
        if (avail < amount) revert InsufficientBalance();
        balances[msg.sender][token] = avail - amount;
        _safeTransfer(token, msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    // ------------------------------------------------------------
    // Market Lifecycle
    // ------------------------------------------------------------
    function createMarket(
        address collateralToken,
        uint256 numOutcomes,
        uint256 initialCollateral
    ) external returns (uint256 marketId) {
        if (collateralToken == address(0)) revert ZeroAddress();
        if (numOutcomes < 2) revert InvalidOutcomeCount();
        if (numOutcomes > MAX_OUTCOMES) revert TooManyOutcomes();
        if (initialCollateral == 0) revert ZeroAmount();

        uint256 avail = balances[msg.sender][collateralToken];
        if (avail < initialCollateral) revert InsufficientBalance();

        uint256 creationFee = (initialCollateral * CREATION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netSeed = initialCollateral - creationFee;

        balances[msg.sender][collateralToken] = avail - initialCollateral;
        balances[feeRecipient][collateralToken] += creationFee;

        marketId = marketCount++;
        markets[marketId] = Market({
            creator: msg.sender,
            collateralToken: collateralToken,
            numOutcomes: numOutcomes,
            totalCollateral: netSeed,
            initialCollateral: netSeed,
            resolved: false,
            winningOutcome: 0,
            createdAt: block.timestamp,
            resolvedAt: 0
        });

        emit MarketCreated(marketId, msg.sender, collateralToken, numOutcomes, initialCollateral, creationFee);
    }

    function placeBet(uint256 marketId, uint256 outcome, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Market storage m = markets[marketId];
        if (m.collateralToken == address(0)) revert MarketNotFound();
        if (m.resolved) revert MarketAlreadyResolved();
        if (outcome >= m.numOutcomes) revert InvalidOutcome();

        uint256 avail = balances[msg.sender][m.collateralToken];
        if (avail < amount) revert InsufficientBalance();

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        balances[msg.sender][m.collateralToken] = avail - amount;
        balances[feeRecipient][m.collateralToken] += fee;
        m.totalCollateral += netAmount;
        outcomeTotals[marketId][outcome] += netAmount;
        positions[marketId][msg.sender][outcome] += netAmount;

        emit BetPlaced(marketId, msg.sender, outcome, amount, fee, netAmount);
    }

    function resolveMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator {
        Market storage m = markets[marketId];
        if (m.collateralToken == address(0)) revert MarketNotFound();
        if (m.resolved) revert MarketAlreadyResolved();
        if (winningOutcome >= m.numOutcomes) revert InvalidOutcome();

        m.resolved = true;
        m.winningOutcome = winningOutcome;
        m.resolvedAt = block.timestamp;

        emit MarketResolved(marketId, winningOutcome, m.totalCollateral);
    }

    function claim(uint256 marketId) external {
        Market storage m = markets[marketId];
        if (m.collateralToken == address(0)) revert MarketNotFound();
        if (!m.resolved) revert MarketNotResolved();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        uint256 winner = m.winningOutcome;
        uint256 userBet = positions[marketId][msg.sender][winner];
        if (userBet == 0) revert NothingToClaim();

        uint256 totalOnWinner = outcomeTotals[marketId][winner];
        if (totalOnWinner == 0) revert NoWinningBets();

        uint256 payout = (userBet * m.totalCollateral) / totalOnWinner;

        hasClaimed[marketId][msg.sender] = true;
        balances[msg.sender][m.collateralToken] += payout;

        emit Claimed(marketId, msg.sender, winner, payout);
    }

    // ------------------------------------------------------------
    // Views
    // ------------------------------------------------------------
    function getMarket(uint256 marketId) external view returns (Market memory) {
        return markets[marketId];
    }

    function getOutcomeTotal(uint256 marketId, uint256 outcome) external view returns (uint256) {
        return outcomeTotals[marketId][outcome];
    }

    function getPosition(uint256 marketId, address user, uint256 outcome) external view returns (uint256) {
        return positions[marketId][user][outcome];
    }

    function balanceOf(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }
}
