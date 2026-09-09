// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PredictionMarket {
    // --- Custom Errors ---
    error ErrZeroAddress();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrMarketNotExists();
    error ErrInvalidOutcome();
    error ErrMarketResolved();
    error ErrMarketNotResolved();
    error ErrDepositLimitExceeded();
    error ErrInsufficientPosition();
    error ErrNothingToClaim();
    error ErrNotWinner();
    error ErrTransferFailed();
    error ErrZeroAmount();
    error ErrReentrantCall();

    // --- Events ---
    event MarketCreated(uint256 indexed marketId, address indexed creator, string question, uint8 numOutcomes);
    event Deposited(uint256 indexed marketId, address indexed user, uint256 indexed outcome, uint256 amount);
    event Withdrawn(uint256 indexed marketId, address indexed user, uint256 indexed outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint8 indexed winningOutcome, uint256 totalPool);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount, uint256 fee);
    event OperatorChanged(address indexed newOperator);
    event FeeRecipientChanged(address indexed newFeeRecipient);

    // --- Constants ---
    uint256 public constant MAX_DEPOSIT_PER_USER = 1000 * 1e18;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;

    // --- State Variables ---
    address public owner;
    address public operator;
    address public feeRecipient;
    IERC20 public immutable baseToken;

    uint256 private _locked = 1; // Reentrancy guard: 1 = unlocked, 2 = locked

    // --- Structs ---
    struct Market {
        address creator;
        string question;
        uint8 numOutcomes;
        bool resolved;
        uint8 winningOutcome;
        uint256 totalPool;
        mapping(uint256 => uint256) outcomeLiquidity;
        mapping(address => mapping(uint256 => uint256)) userPositions;
        mapping(address => bool) claimed;
    }

    mapping(uint256 => Market) private markets;
    uint256[] private marketIds;

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (markets[marketId].numOutcomes == 0) revert ErrMarketNotExists();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ErrReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // --- Constructor ---
    constructor(address _baseToken, address _operator, address _feeRecipient) {
        if (_baseToken == address(0)) revert ErrZeroAddress();
        if (_operator == address(0)) revert ErrZeroAddress();
        if (_feeRecipient == address(0)) revert ErrZeroAddress();
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        baseToken = IERC20(_baseToken);
    }

    // --- Admin Functions ---
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        operator = newOperator;
        emit OperatorChanged(newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ErrZeroAddress();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientChanged(newFeeRecipient);
    }

    // --- Market Functions ---
    function createMarket(string calldata question, uint8 numOutcomes) external returns (uint256 marketId) {
        if (numOutcomes < 2) revert ErrInvalidOutcome();
        if (bytes(question).length == 0) revert ErrZeroAmount();

        marketId = marketIds.length;
        marketIds.push(marketId);

        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.question = question;
        m.numOutcomes = numOutcomes;

        emit MarketCreated(marketId, msg.sender, question, numOutcomes);
    }

    function deposit(uint256 marketId, uint256 outcome, uint256 amount) external nonReentrant marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.resolved) revert ErrMarketResolved();
        if (outcome >= m.numOutcomes) revert ErrInvalidOutcome();
        if (amount == 0) revert ErrZeroAmount();

        uint256 currentUserTotal = _userTotalPosition(m, msg.sender);
        if (currentUserTotal + amount > MAX_DEPOSIT_PER_USER) revert ErrDepositLimitExceeded();

        // Effects: update state before external call (checks-effects-interactions)
        m.outcomeLiquidity[outcome] += amount;
        m.userPositions[msg.sender][outcome] += amount;
        m.totalPool += amount;

        // Interactions: pull tokens from depositor
        bool success = baseToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert ErrTransferFailed();

        emit Deposited(marketId, msg.sender, outcome, amount);
    }

    function withdraw(uint256 marketId, uint256 outcome, uint256 amount) external nonReentrant marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.resolved) revert ErrMarketResolved();
        if (outcome >= m.numOutcomes) revert ErrInvalidOutcome();
        if (amount == 0) revert ErrZeroAmount();
        if (m.userPositions[msg.sender][outcome] < amount) revert ErrInsufficientPosition();

        // Effects: update state before external call
        m.userPositions[msg.sender][outcome] -= amount;
        m.outcomeLiquidity[outcome] -= amount;
        m.totalPool -= amount;

        // Interactions: send tokens to user
        bool success = baseToken.transfer(msg.sender, amount);
        if (!success) revert ErrTransferFailed();

        emit Withdrawn(marketId, msg.sender, outcome, amount);
    }

    function resolveMarket(uint256 marketId, uint8 winningOutcome) external onlyOperator marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.resolved) revert ErrMarketResolved();
        if (winningOutcome >= m.numOutcomes) revert ErrInvalidOutcome();

        m.resolved = true;
        m.winningOutcome = winningOutcome;

        emit MarketResolved(marketId, winningOutcome, m.totalPool);
    }

    function claimWinnings(uint256 marketId) external nonReentrant marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.resolved) revert ErrMarketNotResolved();
        if (m.claimed[msg.sender]) revert ErrNothingToClaim();

        uint256 winning = m.winningOutcome;
        uint256 userWinningPosition = m.userPositions[msg.sender][winning];
        if (userWinningPosition == 0) revert ErrNotWinner();

        // Effects: mark claimed before external calls (checks-effects-interactions)
        m.claimed[msg.sender] = true;

        uint256 winningPool = m.outcomeLiquidity[winning];
        uint256 totalPool = m.totalPool;

        // Compute gross payout and fee from the raw numerator to avoid
        // divide-before-multiply precision loss. Since FEE_BASIS_POINTS <
        // BASIS_POINTS_DENOMINATOR, fee < grossPayout and netPayout > 0.
        uint256 numerator = userWinningPosition * totalPool;
        uint256 grossPayout = numerator / winningPool;
        uint256 fee = (numerator * FEE_BASIS_POINTS) / (winningPool * BASIS_POINTS_DENOMINATOR);
        uint256 netPayout = grossPayout - fee;

        if (netPayout == 0) revert ErrNothingToClaim();

        // Interactions: transfer fee to feeRecipient and net payout to user
        if (fee > 0) {
            bool feeSuccess = baseToken.transfer(feeRecipient, fee);
            if (!feeSuccess) revert ErrTransferFailed();
        }

        bool success = baseToken.transfer(msg.sender, netPayout);
        if (!success) revert ErrTransferFailed();

        emit WinningsClaimed(marketId, msg.sender, netPayout, fee);
    }

    // --- View Functions ---
    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            address creator,
            string memory question,
            uint8 numOutcomes,
            bool resolved,
            uint8 winningOutcome,
            uint256 totalPool
        )
    {
        Market storage m = markets[marketId];
        return (m.creator, m.question, m.numOutcomes, m.resolved, m.winningOutcome, m.totalPool);
    }

    function getOutcomeLiquidity(uint256 marketId, uint256 outcome) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        if (outcome >= m.numOutcomes) revert ErrInvalidOutcome();
        return m.outcomeLiquidity[outcome];
    }

    function getUserPosition(uint256 marketId, address user, uint256 outcome) external view marketExists(marketId) returns (uint256) {
        Market storage m = markets[marketId];
        if (outcome >= m.numOutcomes) revert ErrInvalidOutcome();
        return m.userPositions[user][outcome];
    }

    function hasClaimed(uint256 marketId, address user) external view marketExists(marketId) returns (bool) {
        return markets[marketId].claimed[user];
    }

    function getMarketCount() external view returns (uint256) {
        return marketIds.length;
    }

    function getMarketIds() external view returns (uint256[] memory) {
        return marketIds;
    }

    // --- Internal Functions ---
    function _userTotalPosition(Market storage m, address user) internal view returns (uint256 total) {
        for (uint8 i = 0; i < m.numOutcomes; i++) {
            total += m.userPositions[user][i];
        }
    }
}
