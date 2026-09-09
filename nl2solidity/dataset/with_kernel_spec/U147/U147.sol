// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PredictionMarket {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOwner();
    error NotMarketCreator();
    error MarketNotFound(uint256 marketId);
    error InvalidOutcomeCount();
    error InvalidOutcome(uint256 outcome);
    error ZeroAmount();
    error InsufficientCollateral(uint256 provided, uint256 required);
    error MarketAlreadyResolved(uint256 marketId);
    error MarketNotResolved(uint256 marketId);
    error NoPosition(uint256 marketId, address user, uint256 outcome);
    error NothingToClaim();
    error ContractPaused();
    error TransferFailed();
    error ZeroFees();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        string resolutionSource,
        string[] outcomeStates,
        uint256 initialOutcome,
        uint256 initialAmount
    );
    event CollateralDeposited(
        uint256 indexed marketId,
        address indexed depositor,
        uint256 outcome,
        uint256 amount
    );
    event PositionWithdrawn(
        uint256 indexed marketId,
        address indexed user,
        uint256 outcome,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        address indexed resolver,
        uint256 indexed winningOutcome,
        uint256 totalCollateral
    );
    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 payout,
        uint256 fee
    );
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed owner, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_COLLATERAL = 100 ether;
    uint256 public constant FEE_BPS = 100;
    uint256 private constant BPS_DENOM = 10000;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    IERC20 public immutable stablecoin;
    bool public paused;
    uint256 public marketCreationFee;
    uint256 public nextMarketId;
    uint256 public accumulatedFees;

    struct Market {
        address creator;
        string question;
        string resolutionSource;
        string[] outcomeStates;
        uint256 totalCollateral;
        bool resolved;
        uint256 winningOutcome;
    }

    mapping(uint256 => Market) private markets;
    mapping(uint256 => mapping(uint256 => uint256)) public collateralByOutcome;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public positions;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (marketId == 0 || marketId >= nextMarketId) revert MarketNotFound(marketId);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address stablecoin_, uint256 creationFee_) {
        owner = msg.sender;
        stablecoin = IERC20(stablecoin_);
        marketCreationFee = creationFee_;
        nextMarketId = 1;
        emit CreationFeeUpdated(0, creationFee_);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            MARKET CREATION
    //////////////////////////////////////////////////////////////*/
    function createMarket(
        string calldata question,
        string calldata resolutionSource,
        string[] calldata outcomeStates,
        uint256 outcomeIndex,
        uint256 amount
    ) external whenNotPaused returns (uint256 marketId) {
        if (outcomeStates.length < 2) revert InvalidOutcomeCount();
        if (outcomeIndex >= outcomeStates.length) revert InvalidOutcome(outcomeIndex);
        if (amount < MIN_COLLATERAL) revert InsufficientCollateral(amount, MIN_COLLATERAL);

        marketId = nextMarketId++;
        Market storage m = markets[marketId];
        m.creator = msg.sender;
        m.question = question;
        m.resolutionSource = resolutionSource;
        m.outcomeStates = outcomeStates;
        m.totalCollateral = amount;
        collateralByOutcome[marketId][outcomeIndex] = amount;
        positions[marketId][msg.sender][outcomeIndex] = amount;

        uint256 totalCharge = amount + marketCreationFee;
        _safeTransferFrom(msg.sender, address(this), totalCharge);

        if (marketCreationFee > 0) {
            accumulatedFees += marketCreationFee;
        }

        emit MarketCreated(marketId, msg.sender, question, resolutionSource, outcomeStates, outcomeIndex, amount);
        emit CollateralDeposited(marketId, msg.sender, outcomeIndex, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function deposit(
        uint256 marketId,
        uint256 outcome,
        uint256 amount
    ) external whenNotPaused marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.resolved) revert MarketAlreadyResolved(marketId);
        if (outcome >= m.outcomeStates.length) revert InvalidOutcome(outcome);
        if (amount == 0) revert ZeroAmount();

        _safeTransferFrom(msg.sender, address(this), amount);

        m.totalCollateral += amount;
        collateralByOutcome[marketId][outcome] += amount;
        positions[marketId][msg.sender][outcome] += amount;

        emit CollateralDeposited(marketId, msg.sender, outcome, amount);
    }

    function withdraw(
        uint256 marketId,
        uint256 outcome,
        uint256 amount
    ) external whenNotPaused marketExists(marketId) {
        Market storage m = markets[marketId];
        if (m.resolved) revert MarketAlreadyResolved(marketId);
        if (outcome >= m.outcomeStates.length) revert InvalidOutcome(outcome);
        if (amount == 0) revert ZeroAmount();

        uint256 held = positions[marketId][msg.sender][outcome];
        if (held < amount) revert NoPosition(marketId, msg.sender, outcome);

        positions[marketId][msg.sender][outcome] = held - amount;
        collateralByOutcome[marketId][outcome] -= amount;
        m.totalCollateral -= amount;

        _safeTransfer(msg.sender, amount);

        emit PositionWithdrawn(marketId, msg.sender, outcome, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              RESOLUTION
    //////////////////////////////////////////////////////////////*/
    function resolveMarket(
        uint256 marketId,
        uint256 winningOutcome
    ) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (msg.sender != m.creator) revert NotMarketCreator();
        if (m.resolved) revert MarketAlreadyResolved(marketId);
        if (winningOutcome >= m.outcomeStates.length) revert InvalidOutcome(winningOutcome);

        m.resolved = true;
        m.winningOutcome = winningOutcome;

        emit MarketResolved(marketId, msg.sender, winningOutcome, m.totalCollateral);
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIM
    //////////////////////////////////////////////////////////////*/
    function claim(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        if (!m.resolved) revert MarketNotResolved(marketId);

        uint256 winning = m.winningOutcome;
        uint256 userAmount = positions[marketId][msg.sender][winning];
        if (userAmount == 0) revert NothingToClaim();

        uint256 winningPool = collateralByOutcome[marketId][winning];
        if (winningPool == 0) revert NothingToClaim();

        positions[marketId][msg.sender][winning] = 0;

        uint256 grossWinnings = (m.totalCollateral * userAmount) / winningPool;
        uint256 fee = (grossWinnings * FEE_BPS) / BPS_DENOM;
        uint256 payout = grossWinnings - fee;

        if (fee > 0) {
            accumulatedFees += fee;
        }

        _safeTransfer(msg.sender, payout);

        emit WinningsClaimed(marketId, msg.sender, payout, fee);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER / ADMIN CONTROLS
    //////////////////////////////////////////////////////////////*/
    function setCreationFee(uint256 newFee) external onlyOwner {
        uint256 old = marketCreationFee;
        marketCreationFee = newFee;
        emit CreationFeeUpdated(old, newFee);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) emit Paused(msg.sender);
        else emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert NotOwner();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function withdrawFees() external onlyOwner {
        uint256 fees = accumulatedFees;
        if (fees == 0) revert ZeroFees();
        accumulatedFees = 0;
        _safeTransfer(msg.sender, fees);
        emit FeesWithdrawn(msg.sender, fees);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/
    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            address creator,
            string memory question,
            string memory resolutionSource,
            string[] memory outcomeStates,
            uint256 totalCollateral,
            bool resolved,
            uint256 winningOutcome
        )
    {
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.question,
            m.resolutionSource,
            m.outcomeStates,
            m.totalCollateral,
            m.resolved,
            m.winningOutcome
        );
    }

    function getOutcomeCollateral(uint256 marketId, uint256 outcome) external view returns (uint256) {
        return collateralByOutcome[marketId][outcome];
    }

    function getPosition(uint256 marketId, address user, uint256 outcome) external view returns (uint256) {
        return positions[marketId][user][outcome];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _safeTransfer(address to, uint256 amount) internal {
        bool success = stablecoin.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool success = stablecoin.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }
}
