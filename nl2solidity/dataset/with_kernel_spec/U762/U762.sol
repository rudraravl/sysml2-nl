// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract PredictionMarkets {
    enum MarketState { Open, Resolved, Disputed }

    struct Market {
        address creator;
        string question;
        uint256[] outcomeIds;
        uint256 creationTime;
        uint256 resolutionTime;
        MarketState state;
        uint256 winningOutcome;
        uint256 totalCollateral;
        uint256 feeBpsAtResolution;
    }

    struct Dispute {
        address disputer;
        uint256 stake;
    }

    IERC20 public immutable collateralToken;
    address public operator;
    address public feeRecipient;
    uint256 public feeBps;
    uint256 public constant MIN_CREATION_COLLATERAL = 100;
    uint256 public constant DISPUTE_STAKE = 100;
    uint256 public constant DISPUTE_WINDOW = 1 days;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;

    uint256 public marketCount;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeTotals;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public positions;
    mapping(uint256 => mapping(address => bool)) public hasWithdrawn;
    mapping(uint256 => Dispute[]) public disputes;
    mapping(uint256 => uint256) public totalDisputeStake;

    uint256 private _locked = 1;

    event MarketCreated(uint256 indexed marketId, address indexed creator, string question, uint256[] outcomeIds, uint256 initialOutcome, uint256 initialAmount);
    event Deposited(uint256 indexed marketId, address indexed user, uint256 indexed outcomeId, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 indexed winningOutcome, uint256 totalCollateral, uint256 feeBps);
    event MarketDisputed(uint256 indexed marketId, address indexed disputer, uint256 stake);
    event MarketReResolved(uint256 indexed marketId, uint256 indexed newWinningOutcome);
    event Withdrawn(uint256 indexed marketId, address indexed user, uint256 amount, uint256 fee);
    event FeeSet(uint256 newFeeBps);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed newFeeRecipient);
    event DisputeStakeResolved(uint256 indexed marketId, address indexed disputer, bool rewarded, uint256 amount);

    error NotOperator();
    error ZeroAddress();
    error FeeTooHigh();
    error MarketNotFound();
    error MarketNotOpen();
    error MarketNotResolved();
    error InvalidOutcome();
    error InsufficientInitialCollateral();
    error TransferFailed();
    error AlreadyWithdrawn();
    error DisputeWindowClosed();
    error NothingToWithdraw();
    error DuplicateOutcome();
    error NoOutcomes();
    error AlreadyResolved();
    error NotDisputed();
    error OutcomeUnchanged();
    error ZeroAmount();
    error ReentrantCall();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _collateralToken, address _operator, address _feeRecipient) {
        if (_collateralToken == address(0) || _operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        feeRecipient = _feeRecipient;
        feeBps = 100;
        emit FeeSet(100);
    }

    function setFeeBps(uint256 _newFeeBps) external onlyOperator {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = _newFeeBps;
        emit FeeSet(_newFeeBps);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _newOperator);
        operator = _newOperator;
    }

    function setFeeRecipient(address _newFeeRecipient) external onlyOperator {
        if (_newFeeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientChanged(_newFeeRecipient);
    }

    function createMarket(
        string calldata question,
        uint256[] calldata outcomeIds,
        uint256 initialOutcome,
        uint256 initialAmount
    ) external nonReentrant returns (uint256 marketId) {
        if (outcomeIds.length == 0) revert NoOutcomes();
        if (initialAmount < MIN_CREATION_COLLATERAL) revert InsufficientInitialCollateral();
        if (!_isValidOutcomeCalldata(outcomeIds, initialOutcome)) revert InvalidOutcome();

        for (uint256 i = 0; i < outcomeIds.length; i++) {
            for (uint256 j = i + 1; j < outcomeIds.length; j++) {
                if (outcomeIds[i] == outcomeIds[j]) revert DuplicateOutcome();
            }
        }

        marketId = marketCount++;

        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.question = question;
        m.outcomeIds = outcomeIds;
        m.creationTime = block.timestamp;
        m.state = MarketState.Open;
        m.totalCollateral = initialAmount;
        m.feeBpsAtResolution = 0;

        outcomeTotals[marketId][initialOutcome] = initialAmount;
        positions[marketId][msg.sender][initialOutcome] = initialAmount;

        emit MarketCreated(marketId, msg.sender, question, outcomeIds, initialOutcome, initialAmount);
        emit Deposited(marketId, msg.sender, initialOutcome, initialAmount);

        bool ok = collateralToken.transferFrom(msg.sender, address(this), initialAmount);
        if (!ok) revert TransferFailed();
    }

    function deposit(uint256 marketId, uint256 outcomeId, uint256 amount) external nonReentrant {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (!_isValidOutcome(m.outcomeIds, outcomeId)) revert InvalidOutcome();
        if (amount == 0) revert ZeroAmount();

        m.totalCollateral += amount;
        outcomeTotals[marketId][outcomeId] += amount;
        positions[marketId][msg.sender][outcomeId] += amount;

        emit Deposited(marketId, msg.sender, outcomeId, amount);

        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
    }

    function resolveMarket(uint256 marketId, uint256 winningOutcome) external onlyOperator {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        if (m.state != MarketState.Open) revert AlreadyResolved();
        if (!_isValidOutcome(m.outcomeIds, winningOutcome)) revert InvalidOutcome();

        m.state = MarketState.Resolved;
        m.winningOutcome = winningOutcome;
        m.resolutionTime = block.timestamp;
        m.feeBpsAtResolution = feeBps;

        emit MarketResolved(marketId, winningOutcome, m.totalCollateral, m.feeBpsAtResolution);
    }

    function disputeMarket(uint256 marketId) external nonReentrant {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        if (m.state != MarketState.Resolved) revert MarketNotResolved();
        if (block.timestamp > m.resolutionTime + DISPUTE_WINDOW) revert DisputeWindowClosed();

        // Effects before interactions
        m.state = MarketState.Disputed;
        disputes[marketId].push(Dispute({disputer: msg.sender, stake: DISPUTE_STAKE}));
        totalDisputeStake[marketId] += DISPUTE_STAKE;

        emit MarketDisputed(marketId, msg.sender, DISPUTE_STAKE);

        // Interaction
        bool ok = collateralToken.transferFrom(msg.sender, address(this), DISPUTE_STAKE);
        if (!ok) revert TransferFailed();
    }

    function reResolveMarket(uint256 marketId, uint256 newWinningOutcome) external onlyOperator nonReentrant {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        if (m.state != MarketState.Disputed) revert NotDisputed();
        if (!_isValidOutcome(m.outcomeIds, newWinningOutcome)) revert InvalidOutcome();
        if (newWinningOutcome == m.winningOutcome) revert OutcomeUnchanged();

        // Effects before interactions
        m.winningOutcome = newWinningOutcome;
        m.state = MarketState.Resolved;
        m.resolutionTime = block.timestamp;
        m.feeBpsAtResolution = feeBps;

        uint256 stakePool = totalDisputeStake[marketId];
        totalDisputeStake[marketId] = 0;

        emit MarketReResolved(marketId, newWinningOutcome);

        // Interactions: reward disputers with their stakes back
        if (stakePool > 0) {
            Dispute[] storage ds = disputes[marketId];
            for (uint256 i = 0; i < ds.length; i++) {
                bool ok = collateralToken.transfer(ds[i].disputer, ds[i].stake);
                if (ok) {
                    emit DisputeStakeResolved(marketId, ds[i].disputer, true, ds[i].stake);
                } else {
                    emit DisputeStakeResolved(marketId, ds[i].disputer, false, 0);
                }
            }
        }
    }

    function confirmResolution(uint256 marketId) external onlyOperator nonReentrant {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        if (m.state != MarketState.Disputed) revert NotDisputed();

        // Effects before interactions
        m.state = MarketState.Resolved;

        uint256 stakePool = totalDisputeStake[marketId];
        totalDisputeStake[marketId] = 0;

        emit MarketResolved(marketId, m.winningOutcome, m.totalCollateral, m.feeBpsAtResolution);

        // Interaction: disputers forfeit stake to fee recipient
        if (stakePool > 0) {
            bool ok = collateralToken.transfer(feeRecipient, stakePool);
            if (ok) {
                Dispute[] storage ds = disputes[marketId];
                for (uint256 i = 0; i < ds.length; i++) {
                    emit DisputeStakeResolved(marketId, ds[i].disputer, false, ds[i].stake);
                }
            } else {
                // Restore state if transfer failed
                totalDisputeStake[marketId] = stakePool;
                m.state = MarketState.Disputed;
                revert TransferFailed();
            }
        }
    }

    function withdraw(uint256 marketId) external nonReentrant {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        if (m.state != MarketState.Resolved) revert MarketNotResolved();
        if (hasWithdrawn[marketId][msg.sender]) revert AlreadyWithdrawn();

        uint256 winningOutcome = m.winningOutcome;
        uint256 userPosition = positions[marketId][msg.sender][winningOutcome];
        if (userPosition == 0) revert NothingToWithdraw();

        uint256 winningTotal = outcomeTotals[marketId][winningOutcome];
        if (winningTotal == 0) revert NothingToWithdraw();

        // Compute fee and net payout with multiply-before-divide to avoid precision loss.
        // fee = (userPosition * totalCollateral * feeBpsAtResolution) / (winningTotal * FEE_DENOMINATOR)
        // netPayout = (userPosition * totalCollateral * (FEE_DENOMINATOR - feeBpsAtResolution)) / (winningTotal * FEE_DENOMINATOR)
        uint256 feeBps = m.feeBpsAtResolution;
        uint256 numerator;
        uint256 fee;
        uint256 netPayout;

        if (feeBps == 0) {
            // No fee: grossPayout = (userPosition * totalCollateral) / winningTotal
            netPayout = (userPosition * m.totalCollateral) / winningTotal;
            fee = 0;
        } else {
            numerator = userPosition * m.totalCollateral;
            fee = (numerator * feeBps) / (winningTotal * FEE_DENOMINATOR);
            netPayout = (numerator * (FEE_DENOMINATOR - feeBps)) / (winningTotal * FEE_DENOMINATOR);
        }

        // Effects
        hasWithdrawn[marketId][msg.sender] = true;
        positions[marketId][msg.sender][winningOutcome] = 0;

        emit Withdrawn(marketId, msg.sender, netPayout, fee);

        // Interactions
        if (fee > 0) {
            bool okFee = collateralToken.transfer(feeRecipient, fee);
            if (!okFee) revert TransferFailed();
        }
        if (netPayout > 0) {
            bool ok = collateralToken.transfer(msg.sender, netPayout);
            if (!ok) revert TransferFailed();
        }
    }

    function getMarket(uint256 marketId) external view returns (
        address creator,
        string memory question,
        uint256[] memory outcomeIds,
        uint256 creationTime,
        uint256 resolutionTime,
        MarketState state,
        uint256 winningOutcome,
        uint256 totalCollateral,
        uint256 feeBpsAtResolution
    ) {
        if (marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.question,
            m.outcomeIds,
            m.creationTime,
            m.resolutionTime,
            m.state,
            m.winningOutcome,
            m.totalCollateral,
            m.feeBpsAtResolution
        );
    }

    function getUserPosition(uint256 marketId, address user, uint256 outcomeId) external view returns (uint256) {
        return positions[marketId][user][outcomeId];
    }

    function getOutcomeTotal(uint256 marketId, uint256 outcomeId) external view returns (uint256) {
        return outcomeTotals[marketId][outcomeId];
    }

    function getDisputeCount(uint256 marketId) external view returns (uint256) {
        return disputes[marketId].length;
    }

    function _isValidOutcome(uint256[] storage outcomeIds, uint256 outcomeId) internal view returns (bool) {
        for (uint256 i = 0; i < outcomeIds.length; i++) {
            if (outcomeIds[i] == outcomeId) return true;
        }
        return false;
    }

    function _isValidOutcomeCalldata(uint256[] calldata outcomeIds, uint256 outcomeId) internal pure returns (bool) {
        for (uint256 i = 0; i < outcomeIds.length; i++) {
            if (outcomeIds[i] == outcomeId) return true;
        }
        return false;
    }
}
