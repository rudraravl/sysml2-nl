// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PredictionMarketEscrow
 * @notice Manages prediction markets with escrow-style deposits, predictions,
 *         and payout claims. A designated operator closes and resolves markets
 *         by declaring the winning outcome and setting payout ratios. A 0.5%
 *         fee on all winning payouts is directed to a treasury address. A
 *         maximum of 100 active (open or closed) markets may exist at any time.
 */
contract PredictionMarketEscrow {
    ////////////////////////////////////////////////////////////////
    //                           TYPES                             //
    ////////////////////////////////////////////////////////////////

    enum MarketState { Open, Closed, Resolved }

    struct Market {
        address creator;
        string description;
        uint256 outcomeCount;
        MarketState state;
        uint256 deadline;
        uint256 totalPool;       // total ETH locked in this market
        uint256 winningOutcome;  // winning outcome index (valid when Resolved)
        uint256 payoutRatio;     // multiplier in 1e18 applied to winning stakes
    }

    struct UserPosition {
        uint256 amount;          // amount staked
        uint256 outcome;         // chosen outcome index
    }

    ////////////////////////////////////////////////////////////////
    //                         CONSTANTS                          //
    ////////////////////////////////////////////////////////////////

    uint256 public constant MAX_ACTIVE_MARKETS = 100;
    uint256 public constant FEE_BPS = 50;          // 0.5% = 50 basis points
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant RATIO_DENOM = 1e18;

    ////////////////////////////////////////////////////////////////
    //                         STORAGE                            //
    ////////////////////////////////////////////////////////////////

    address public operator;
    address public treasury;

    uint256 public marketCount;
    uint256 public activeMarketCount;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomePools; // marketId => outcome => total staked
    mapping(uint256 => mapping(address => UserPosition)) public positions;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(address => uint256) public uncommittedBalance;

    uint256[] internal _activeMarketIds;
    mapping(uint256 => uint256) internal _activeIndex; // marketId => index+1 (0 = not active)

    ////////////////////////////////////////////////////////////////
    //                           EVENTS                           //
    ////////////////////////////////////////////////////////////////

    event MarketCreated(uint256 indexed marketId, address indexed creator, string description, uint256 outcomeCount, uint256 deadline);
    event PredictionPlaced(uint256 indexed marketId, address indexed user, uint256 outcome, uint256 amount);
    event MarketClosed(uint256 indexed marketId);
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome, uint256 payoutRatio);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 grossPayout, uint256 fee, uint256 netPayout);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    ////////////////////////////////////////////////////////////////
    //                          ERRORS                            //
    ////////////////////////////////////////////////////////////////

    error NotOperator();
    error ZeroAddress();
    error MaxActiveMarketsReached();
    error MarketNotOpen();
    error MarketNotClosed();
    error MarketNotResolved();
    error MarketExpired();
    error MarketNotExpired();
    error InvalidOutcome();
    error InvalidOutcomeCount();
    error InvalidDeadline();
    error InvalidPayoutRatio();
    error ZeroAmount();
    error AlreadyPredicted();
    error AlreadyClaimed();
    error NoPrediction();
    error NotWinningOutcome();
    error InsufficientBalance();
    error TransferFailed();

    ////////////////////////////////////////////////////////////////
    //                        MODIFIERS                           //
    ////////////////////////////////////////////////////////////////

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                        CONSTRUCTOR                         //
    ////////////////////////////////////////////////////////////////

    constructor(address _operator, address _treasury) {
        if (_operator == address(0) || _treasury == address(0)) revert ZeroAddress();
        operator = _operator;
        treasury = _treasury;
        emit OperatorUpdated(address(0), _operator);
        emit TreasuryUpdated(address(0), _treasury);
    }

    ////////////////////////////////////////////////////////////////
    //                      DEPOSIT / RECEIVE                     //
    ////////////////////////////////////////////////////////////////

    receive() external payable {
        uncommittedBalance[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        uncommittedBalance[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (uncommittedBalance[msg.sender] < amount) revert InsufficientBalance();

        // Effects
        uncommittedBalance[msg.sender] -= amount;

        // Interactions
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    ////////////////////////////////////////////////////////////////
    //                       MARKET LIFECYCLE                     //
    ////////////////////////////////////////////////////////////////

    function createMarket(
        string calldata description,
        uint256 outcomeCount,
        uint256 deadline
    ) external returns (uint256 marketId) {
        if (activeMarketCount >= MAX_ACTIVE_MARKETS) revert MaxActiveMarketsReached();
        if (outcomeCount < 2) revert InvalidOutcomeCount();
        if (deadline <= block.timestamp) revert InvalidDeadline();

        marketId = marketCount++;
        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.description = description;
        m.outcomeCount = outcomeCount;
        m.state = MarketState.Open;
        m.deadline = deadline;

        _activeMarketIds.push(marketId);
        _activeIndex[marketId] = _activeMarketIds.length; // 1-based
        activeMarketCount++;

        emit MarketCreated(marketId, msg.sender, description, outcomeCount, deadline);
    }

    function placePrediction(uint256 marketId, uint256 outcome, uint256 amount) external {
        Market storage m = markets[marketId];
        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (block.timestamp >= m.deadline) revert MarketExpired();
        if (outcome >= m.outcomeCount) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();
        if (uncommittedBalance[msg.sender] < amount) revert InsufficientBalance();
        if (positions[marketId][msg.sender].amount > 0) revert AlreadyPredicted();

        // Effects
        uncommittedBalance[msg.sender] -= amount;
        m.totalPool += amount;
        outcomePools[marketId][outcome] += amount;
        positions[marketId][msg.sender] = UserPosition({amount: amount, outcome: outcome});

        emit PredictionPlaced(marketId, msg.sender, outcome, amount);
    }

    function closeMarket(uint256 marketId) external {
        Market storage m = markets[marketId];
        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (block.timestamp < m.deadline) revert MarketNotExpired();

        m.state = MarketState.Closed;
        _removeFromActive(marketId);

        emit MarketClosed(marketId);
    }

    function resolveMarket(
        uint256 marketId,
        uint256 winningOutcome,
        uint256 payoutRatio
    ) external onlyOperator {
        Market storage m = markets[marketId];
        if (m.state == MarketState.Resolved) revert MarketNotClosed();
        if (winningOutcome >= m.outcomeCount) revert InvalidOutcome();

        uint256 winningPool = outcomePools[marketId][winningOutcome];
        uint256 totalPayout = (winningPool * payoutRatio) / RATIO_DENOM;
        if (totalPayout > m.totalPool) revert InvalidPayoutRatio();

        if (m.state == MarketState.Open) {
            _removeFromActive(marketId);
        }

        m.state = MarketState.Resolved;
        m.winningOutcome = winningOutcome;
        m.payoutRatio = payoutRatio;

        emit MarketResolved(marketId, winningOutcome, payoutRatio);
    }

    function claimWinnings(uint256 marketId) external {
        Market storage m = markets[marketId];
        if (m.state != MarketState.Resolved) revert MarketNotResolved();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        UserPosition storage pos = positions[marketId][msg.sender];
        if (pos.amount == 0) revert NoPrediction();
        if (pos.outcome != m.winningOutcome) revert NotWinningOutcome();

        // Effects: mark claimed before any external calls
        hasClaimed[marketId][msg.sender] = true;

        // Compute payout using full-precision intermediate to avoid
        // divide-before-multiply rounding loss.
        //   grossPayout = (stake * ratio) / RATIO_DENOM
        //   fee         = (stake * ratio * FEE_BPS) / (RATIO_DENOM * BPS_DENOM)
        //   netPayout   = grossPayout - fee
        uint256 stake = pos.amount;
        uint256 ratio = m.payoutRatio;

        uint256 grossPayout = (stake * ratio) / RATIO_DENOM;
        if (grossPayout > m.totalPool) revert InvalidPayoutRatio();

        uint256 fee = (stake * ratio * FEE_BPS) / (RATIO_DENOM * BPS_DENOM);
        if (fee > grossPayout) revert InvalidPayoutRatio();

        uint256 netPayout = grossPayout - fee;

        m.totalPool -= grossPayout;

        // Interactions
        (bool feeOk, ) = payable(treasury).call{value: fee}("");
        if (!feeOk) revert TransferFailed();

        (bool payoutOk, ) = payable(msg.sender).call{value: netPayout}("");
        if (!payoutOk) revert TransferFailed();

        emit WinningsClaimed(marketId, msg.sender, grossPayout, fee, netPayout);
    }

    ////////////////////////////////////////////////////////////////
    //                       ADMIN FUNCTIONS                      //
    ////////////////////////////////////////////////////////////////

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    ////////////////////////////////////////////////////////////////
    //                         VIEW FUNCTIONS                     //
    ////////////////////////////////////////////////////////////////

    function getMarketInfo(uint256 marketId)
        external
        view
        returns (
            address creator,
            string memory description,
            uint256 outcomeCount,
            MarketState state,
            uint256 deadline,
            uint256 totalPool,
            uint256 winningOutcome,
            uint256 payoutRatio
        )
    {
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.description,
            m.outcomeCount,
            m.state,
            m.deadline,
            m.totalPool,
            m.winningOutcome,
            m.payoutRatio
        );
    }

    function getPosition(uint256 marketId, address user)
        external
        view
        returns (uint256 amount, uint256 outcome)
    {
        UserPosition storage pos = positions[marketId][user];
        return (pos.amount, pos.outcome);
    }

    function getOutcomePool(uint256 marketId, uint256 outcome) external view returns (uint256) {
        return outcomePools[marketId][outcome];
    }

    function getActiveMarketIds() external view returns (uint256[] memory) {
        return _activeMarketIds;
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    ////////////////////////////////////////////////////////////////
    //                        INTERNAL HELPERS                    //
    ////////////////////////////////////////////////////////////////

    function _removeFromActive(uint256 marketId) internal {
        uint256 idx = _activeIndex[marketId];
        if (idx == 0) return; // not in active list

        uint256 lastIdx = _activeMarketIds.length - 1;
        if (idx - 1 != lastIdx) {
            uint256 lastId = _activeMarketIds[lastIdx];
            _activeMarketIds[idx - 1] = lastId;
            _activeIndex[lastId] = idx;
        }
        _activeMarketIds.pop();
        delete _activeIndex[marketId];
        activeMarketCount--;
    }
}
