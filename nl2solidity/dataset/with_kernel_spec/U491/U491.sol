// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract PredictionMarket {
    // --- State Variables ---
    IERC20 public immutable collateralToken;
    address public operator;
    address public feeRecipient;
    bool public isPaused;
    uint256 public nextMarketId;
    uint256 private _status;

    // --- Constants ---
    uint256 public constant FEE_BPS = 100; // 1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DURATION_HOURS = 24;

    // --- Structs ---
    struct Market {
        string question;
        uint256 outcomeCount;
        uint256 endTime;
        uint256 totalCollateral;
        bool resolved;
        bool exists;
    }

    // --- Storage ---
    mapping(uint256 => Market) public markets;
    mapping(uint256 => uint256) public finalOutcome;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeTotals;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userStakes;
    mapping(address => uint256) public availableCollateral;

    // --- Events ---
    event MarketCreated(uint256 indexed marketId, string question, uint256 outcomeCount, uint256 endTime);
    event PredictionPlaced(uint256 indexed marketId, address indexed user, uint256 outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount, uint256 fee);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Paused(address caller);
    event Unpaused(address caller);
    event OperatorChanged(address oldOperator, address newOperator);

    // --- Custom Errors ---
    error NotOperator();
    error ContractIsPaused();
    error MarketDoesNotExist();
    error MarketClosed();
    error MarketNotEnded();
    error AlreadyResolved();
    error NotResolved();
    error InvalidOutcome();
    error InsufficientBalance();
    error NothingToClaim();
    error ZeroAmount();
    error TransferFailed();
    error DurationTooShort();
    error ZeroAddress();
    error ReentrancyDetected();
    error WinningPoolEmpty();

    // --- Modifiers ---
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (isPaused) revert ContractIsPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == 1) revert ReentrancyDetected();
        _status = 1;
        _;
        _status = 0;
    }

    // --- Constructor ---
    constructor(address _collateralToken, address _operator, address _feeRecipient) {
        if (_collateralToken == address(0) || _operator == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        feeRecipient = _feeRecipient;
        nextMarketId = 1;
        _status = 0; // NotEntered
    }

    // --- Operator Functions ---

    function pause() external onlyOperator {
        isPaused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        isPaused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newFeeRecipient;
    }

    // --- Collateral Management ---

    function depositCollateral(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        availableCollateral[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }
    }

    function withdrawCollateral(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (availableCollateral[msg.sender] < amount) revert InsufficientBalance();
        availableCollateral[msg.sender] -= amount;
        emit CollateralWithdrawn(msg.sender, amount);
        if (!collateralToken.transfer(msg.sender, amount)) {
            revert TransferFailed();
        }
    }

    // --- Market Functions ---

    function createMarket(
        string calldata question,
        uint256 outcomeCount,
        uint256 durationHours
    ) external whenNotPaused returns (uint256) {
        if (durationHours < MIN_DURATION_HOURS) revert DurationTooShort();
        if (outcomeCount < 2) revert InvalidOutcome();

        uint256 marketId = nextMarketId++;
        uint256 endTime = block.timestamp + durationHours * 1 hours;

        markets[marketId] = Market({
            question: question,
            outcomeCount: outcomeCount,
            endTime: endTime,
            totalCollateral: 0,
            resolved: false,
            exists: true
        });

        emit MarketCreated(marketId, question, outcomeCount, endTime);
        return marketId;
    }

    function placePrediction(
        uint256 marketId,
        uint256 outcome,
        uint256 amount
    ) external whenNotPaused nonReentrant {
        Market storage market = markets[marketId];
        if (!market.exists) revert MarketDoesNotExist();
        if (block.timestamp >= market.endTime) revert MarketClosed();
        if (market.resolved) revert AlreadyResolved();
        if (outcome >= market.outcomeCount) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();
        if (availableCollateral[msg.sender] < amount) revert InsufficientBalance();

        availableCollateral[msg.sender] -= amount;
        userStakes[marketId][msg.sender][outcome] += amount;
        outcomeTotals[marketId][outcome] += amount;
        market.totalCollateral += amount;

        emit PredictionPlaced(marketId, msg.sender, outcome, amount);
    }

    function resolveMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator {
        Market storage market = markets[marketId];
        if (!market.exists) revert MarketDoesNotExist();
        if (block.timestamp < market.endTime) revert MarketNotEnded();
        if (market.resolved) revert AlreadyResolved();
        if (winningOutcome >= market.outcomeCount) revert InvalidOutcome();

        market.resolved = true;
        finalOutcome[marketId] = winningOutcome;

        emit MarketResolved(marketId, winningOutcome);
    }

    function claimWinnings(uint256 marketId) external whenNotPaused nonReentrant {
        Market storage market = markets[marketId];
        if (!market.exists) revert MarketDoesNotExist();
        if (!market.resolved) revert NotResolved();

        uint256 winningOutcome = finalOutcome[marketId];
        uint256 stake = userStakes[marketId][msg.sender][winningOutcome];
        if (stake == 0) revert NothingToClaim();

        uint256 totalPool = market.totalCollateral;
        uint256 winningPool = outcomeTotals[marketId][winningOutcome];
        if (winningPool == 0) revert WinningPoolEmpty();

        // Effects: clear the user's stake before any external interaction so a
        // reentrant callback cannot claim the same winnings twice.
        userStakes[marketId][msg.sender][winningOutcome] = 0;

        // Gross winnings = the user's proportional share of the entire collateral
        // pool, based on their share of the winning outcome's staked amount.
        uint256 grossWinnings = (stake * totalPool) / winningPool;

        // Fee is 1% (FEE_BPS / BPS_DENOMINATOR) of the gross winnings. To avoid the
        // divide-before-multiply precision loss that occurs when multiplying an
        // already-rounded division result, the fee is computed directly from the
        // raw numerator/denominator inputs so that all multiplications happen
        // before the final (single) division.
        //
        // fee = (stake * totalPool * FEE_BPS) / (winningPool * BPS_DENOMINATOR)
        //
        // Because FEE_BPS < BPS_DENOMINATOR and stake <= winningPool, this value
        // is always <= grossWinnings, so the subtraction below is safe.
        uint256 fee = (stake * totalPool * FEE_BPS) / (winningPool * BPS_DENOMINATOR);
        if (fee > grossWinnings) {
            // Defensive guard against impossible integer-rounding edge cases.
            fee = grossWinnings;
        }
        uint256 netWinnings = grossWinnings - fee;

        // Interactions: transfer net winnings to the user and the fee to the
        // designated fee recipient. State was already updated above, so these
        // external calls follow the checks-effects-interactions pattern and are
        // additionally protected by the nonReentrant modifier.
        if (netWinnings > 0) {
            if (!collateralToken.transfer(msg.sender, netWinnings)) {
                revert TransferFailed();
            }
        }
        if (fee > 0) {
            if (!collateralToken.transfer(feeRecipient, fee)) {
                revert TransferFailed();
            }
        }

        emit WinningsClaimed(marketId, msg.sender, netWinnings, fee);
    }

    // --- View Functions ---

    function getMarket(uint256 marketId) external view returns (
        string memory question,
        uint256 outcomeCount,
        uint256 endTime,
        uint256 totalCollateral,
        bool resolved,
        bool exists
    ) {
        Market storage market = markets[marketId];
        return (
            market.question,
            market.outcomeCount,
            market.endTime,
            market.totalCollateral,
            market.resolved,
            market.exists
        );
    }

    function getOutcomeTotal(uint256 marketId, uint256 outcome) external view returns (uint256) {
        return outcomeTotals[marketId][outcome];
    }

    function getUserStake(
        uint256 marketId,
        address user,
        uint256 outcome
    ) external view returns (uint256) {
        return userStakes[marketId][user][outcome];
    }

    function getWinningOutcome(uint256 marketId) external view returns (uint256) {
        return finalOutcome[marketId];
    }
}
