// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PredictionMarkets {
    enum MarketState { Open, Closed, Resolved }

    struct Market {
        address creator;
        string question;
        uint256 outcomeCount;
        uint256 closingTime;
        uint256 resolutionTime;
        MarketState state;
        uint256 winningOutcome;
        uint256 totalPool;
        uint256 totalCollateral;
        mapping(uint256 => uint256) outcomePool;
        mapping(address => uint256) userCollateral;
        mapping(address => mapping(uint256 => uint256)) userPredictions;
        mapping(address => uint256) userTotalPredicted;
        mapping(address => bool) userClaimed;
    }

    address public owner;
    uint256 public marketCreationFee;
    uint256 public marketCount;
    uint256 public accumulatedFees;

    mapping(address => bool) public operators;
    mapping(uint256 => Market) private markets;

    event MarketCreated(uint256 indexed marketId, address indexed creator, string question, uint256 outcomeCount, uint256 closingTime);
    event CollateralDeposited(uint256 indexed marketId, address indexed user, uint256 amount);
    event PredictionMade(uint256 indexed marketId, address indexed user, uint256 outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome, uint256 resolutionTime);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event UnallocatedWithdrawn(uint256 indexed marketId, address indexed user, uint256 amount);

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InsufficientFee(uint256 required, uint256 provided);
    error InvalidOutcomeCount();
    error InvalidClosingTime();
    error MarketNotFound();
    error MarketNotOpen();
    error MarketNotClosed();
    error MarketNotResolved();
    error MarketAlreadyResolved();
    error InvalidOutcome();
    error PredictionWindowClosed();
    error InsufficientCollateral(uint256 available, uint256 requested);
    error ZeroAmount();
    error NoWinnings();
    error AlreadyClaimed();
    error NothingToWithdraw();
    error ClosingTimeNotReached();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperatorOrOwner() {
        if (!operators[msg.sender] && msg.sender != owner) revert NotOperator();
        _;
    }

    constructor() {
        owner = msg.sender;
        marketCreationFee = 0.01 ether;
    }

    function setMarketCreationFee(uint256 _fee) external onlyOwner {
        marketCreationFee = _fee;
    }

    function setOperator(address _operator, bool _status) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operators[_operator] = _status;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        owner = _newOwner;
    }

    function createMarket(
        string calldata _question,
        uint256 _outcomeCount,
        uint256 _closingTime
    ) external payable returns (uint256 marketId) {
        if (msg.value < marketCreationFee) revert InsufficientFee(marketCreationFee, msg.value);
        if (_outcomeCount < 2) revert InvalidOutcomeCount();
        if (_closingTime <= block.timestamp) revert InvalidClosingTime();

        marketId = marketCount++;
        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.question = _question;
        m.outcomeCount = _outcomeCount;
        m.closingTime = _closingTime;
        m.state = MarketState.Open;

        accumulatedFees += marketCreationFee;

        uint256 excess = msg.value - marketCreationFee;
        if (excess > 0) {
            (bool succ, ) = payable(msg.sender).call{value: excess}("");
            if (!succ) revert TransferFailed();
        }

        emit MarketCreated(marketId, msg.sender, _question, _outcomeCount, _closingTime);
    }

    function depositCollateral(uint256 _marketId) external payable {
        if (_marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[_marketId];
        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (msg.value == 0) revert ZeroAmount();

        m.userCollateral[msg.sender] += msg.value;
        m.totalCollateral += msg.value;

        emit CollateralDeposited(_marketId, msg.sender, msg.value);
    }

    function predict(uint256 _marketId, uint256 _outcome, uint256 _amount) external {
        if (_marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[_marketId];
        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (block.timestamp >= m.closingTime) revert PredictionWindowClosed();
        if (_outcome >= m.outcomeCount) revert InvalidOutcome();
        if (_amount == 0) revert ZeroAmount();
        if (m.userCollateral[msg.sender] < _amount) revert InsufficientCollateral(m.userCollateral[msg.sender], _amount);

        m.userCollateral[msg.sender] -= _amount;
        m.userPredictions[msg.sender][_outcome] += _amount;
        m.userTotalPredicted[msg.sender] += _amount;
        m.outcomePool[_outcome] += _amount;
        m.totalPool += _amount;

        emit PredictionMade(_marketId, msg.sender, _outcome, _amount);
    }

    function closeMarket(uint256 _marketId) external {
        if (_marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[_marketId];
        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (block.timestamp < m.closingTime) revert ClosingTimeNotReached();
        m.state = MarketState.Closed;
    }

    function resolveMarket(uint256 _marketId, uint256 _winningOutcome) external onlyOperatorOrOwner {
        if (_marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[_marketId];
        if (m.state == MarketState.Resolved) revert MarketAlreadyResolved();
        if (m.state != MarketState.Closed) revert MarketNotClosed();
        if (_winningOutcome >= m.outcomeCount) revert InvalidOutcome();

        m.winningOutcome = _winningOutcome;
        m.state = MarketState.Resolved;
        m.resolutionTime = block.timestamp;

        emit MarketResolved(_marketId, _winningOutcome, block.timestamp);
    }

    function claimWinnings(uint256 _marketId) external {
        if (_marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[_marketId];
        if (m.state != MarketState.Resolved) revert MarketNotResolved();
        if (m.userClaimed[msg.sender]) revert AlreadyClaimed();

        uint256 winningPool = m.outcomePool[m.winningOutcome];
        uint256 userWin = m.userPredictions[msg.sender][m.winningOutcome];
        uint256 userTotalPredicted = m.userTotalPredicted[msg.sender];
        uint256 userUnallocated = m.userCollateral[msg.sender];

        if (userWin == 0 && userUnallocated == 0 && userTotalPredicted == 0) revert NoWinnings();

        m.userClaimed[msg.sender] = true;

        uint256 payout;
        if (winningPool == 0) {
            payout = userTotalPredicted + userUnallocated;
        } else {
            payout = (userWin * m.totalPool) / winningPool + userUnallocated;
        }

        m.userCollateral[msg.sender] = 0;
        m.userTotalPredicted[msg.sender] = 0;
        m.userPredictions[msg.sender][m.winningOutcome] = 0;

        if (payout == 0) revert NoWinnings();

        (bool succ, ) = payable(msg.sender).call{value: payout}("");
        if (!succ) revert TransferFailed();
    }

    function withdrawUnallocated(uint256 _marketId) external {
        if (_marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[_marketId];
        if (m.state == MarketState.Resolved) revert MarketAlreadyResolved();

        uint256 unallocated = m.userCollateral[msg.sender];
        if (unallocated == 0) revert NothingToWithdraw();

        m.userCollateral[msg.sender] = 0;
        m.totalCollateral -= unallocated;

        (bool succ, ) = payable(msg.sender).call{value: unallocated}("");
        if (!succ) revert TransferFailed();

        emit UnallocatedWithdrawn(_marketId, msg.sender, unallocated);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool succ, ) = payable(owner).call{value: amount}("");
        if (!succ) revert TransferFailed();
        emit FeesWithdrawn(owner, amount);
    }

    function getMarketInfo(uint256 _marketId)
        external
        view
        returns (
            address creator,
            string memory question,
            uint256 outcomeCount,
            uint256 closingTime,
            uint256 resolutionTime,
            MarketState state,
            uint256 winningOutcome,
            uint256 totalPool,
            uint256 totalCollateral
        )
    {
        if (_marketId >= marketCount) revert MarketNotFound();
        Market storage m = markets[_marketId];
        return (
            m.creator,
            m.question,
            m.outcomeCount,
            m.closingTime,
            m.resolutionTime,
            m.state,
            m.winningOutcome,
            m.totalPool,
            m.totalCollateral
        );
    }

    function getOutcomePool(uint256 _marketId, uint256 _outcome) external view returns (uint256) {
        if (_marketId >= marketCount) revert MarketNotFound();
        return markets[_marketId].outcomePool[_outcome];
    }

    function getUserCollateral(uint256 _marketId, address _user) external view returns (uint256) {
        if (_marketId >= marketCount) revert MarketNotFound();
        return markets[_marketId].userCollateral[_user];
    }

    function getUserPrediction(uint256 _marketId, address _user, uint256 _outcome) external view returns (uint256) {
        if (_marketId >= marketCount) revert MarketNotFound();
        return markets[_marketId].userPredictions[_user][_outcome];
    }

    function getUserTotalPredicted(uint256 _marketId, address _user) external view returns (uint256) {
        if (_marketId >= marketCount) revert MarketNotFound();
        return markets[_marketId].userTotalPredicted[_user];
    }

    function hasUserClaimed(uint256 _marketId, address _user) external view returns (bool) {
        if (_marketId >= marketCount) revert MarketNotFound();
        return markets[_marketId].userClaimed[_user];
    }

    function getMarketState(uint256 _marketId) external view returns (MarketState) {
        if (_marketId >= marketCount) revert MarketNotFound();
        return markets[_marketId].state;
    }
}
