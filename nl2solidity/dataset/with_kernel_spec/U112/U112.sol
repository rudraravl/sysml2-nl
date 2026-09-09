// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PredictionMarket
/// @notice A trustless prediction market where users bet on the outcome of
/// future events. User stakes are held in escrow until the market is resolved
/// by a designated operator. Winners receive a pro-rata share of the losing
/// pool on top of their original stake.
contract PredictionMarket {
    // ------------------------------------------------------------------
    // Types
    // ------------------------------------------------------------------

    /// @dev Outcome identifier. `None` is reserved for the unresolved state.
    enum Outcome {
        None,
        Yes,
        No
    }

    /// @dev Per-user position within a single market.
    struct Position {
        uint256 yesStake;
        uint256 noStake;
        bool claimed;
    }

    /// @dev A single prediction market.
    struct Market {
        address creator;
        string question;
        uint256 endTime;
        uint256 totalPool;
        uint256 yesStake;
        uint256 noStake;
        bool resolved;
        Outcome winningOutcome;
        mapping(address => Position) positions;
    }

    // ------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------

    address public owner;
    address public operator;

    uint256 public creationFee;
    uint256 internal _totalFees;
    uint256 public marketCount;

    mapping(uint256 => Market) internal _markets;

    uint256 public constant WITHDRAWAL_LOCK_PERIOD = 24 hours;
    uint256 public constant DEFAULT_CREATION_FEE = 0.01 ether;

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        uint256 endTime,
        uint256 feePaid
    );
    event BetPlaced(
        uint256 indexed marketId,
        address indexed bettor,
        uint256 outcome,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        uint256 winningOutcome,
        uint256 totalPool
    );
    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed claimer,
        uint256 amount
    );
    event StakeWithdrawn(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );
    event OperatorChanged(
        address indexed previousOperator,
        address indexed newOperator
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InvalidEndTime();
    error InvalidOutcome();
    error InvalidQuestion();
    error InsufficientFee();
    error MarketNotResolved();
    error MarketAlreadyResolved();
    error MarketClosed();
    error AlreadyClaimed();
    error NothingToClaim();
    error NoStake();
    error WithdrawalLocked();
    error MarketDoesNotExist();
    error NoWinningBets();
    error TransferFailed();

    // ------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        creationFee = DEFAULT_CREATION_FEE;
        emit OwnershipTransferred(address(0), owner);
        emit OperatorChanged(address(0), operator);
        emit CreationFeeUpdated(0, creationFee);
    }

    // ------------------------------------------------------------------
    // Market lifecycle
    // ------------------------------------------------------------------

    /// @notice Creates a new prediction market.
    /// @param question Human-readable description of the event being predicted.
    /// @param endTime Timestamp at which the market is scheduled to resolve.
    /// @return marketId The id of the newly created market.
    function createMarket(
        string calldata question,
        uint256 endTime
    ) external payable returns (uint256 marketId) {
        if (msg.value < creationFee) revert InsufficientFee();
        if (bytes(question).length == 0) revert InvalidQuestion();
        if (endTime <= block.timestamp) revert InvalidEndTime();

        marketId = marketCount++;
        Market storage m = _markets[marketId];
        m.creator = msg.sender;
        m.question = question;
        m.endTime = endTime;
        m.resolved = false;
        m.winningOutcome = Outcome.None;

        _totalFees += msg.value;

        emit MarketCreated(marketId, msg.sender, question, endTime, msg.value);
    }

    /// @notice Places a bet on a market outcome.
    /// @param marketId The target market.
    /// @param outcome The outcome to bet on (1 = Yes, 2 = No).
    function placeBet(uint256 marketId, uint256 outcome) external payable {
        if (marketId >= marketCount) revert MarketDoesNotExist();
        if (msg.value == 0) revert NoStake();
        if (outcome != uint256(Outcome.Yes) && outcome != uint256(Outcome.No))
            revert InvalidOutcome();

        Market storage m = _markets[marketId];
        if (m.resolved) revert MarketAlreadyResolved();
        if (block.timestamp >= m.endTime) revert MarketClosed();

        Position storage pos = m.positions[msg.sender];
        if (outcome == uint256(Outcome.Yes)) {
            pos.yesStake += msg.value;
            m.yesStake += msg.value;
        } else {
            pos.noStake += msg.value;
            m.noStake += msg.value;
        }
        m.totalPool += msg.value;

        emit BetPlaced(marketId, msg.sender, outcome, msg.value);
    }

    /// @notice Resolves a market by declaring the winning outcome.
    /// @dev Only the operator may resolve. The market must have reached its
    /// scheduled end time and the declared winning side must have at least
    /// one bet if any bets were placed.
    function resolveMarket(
        uint256 marketId,
        uint256 winningOutcome
    ) external onlyOperator {
        if (marketId >= marketCount) revert MarketDoesNotExist();
        if (
            winningOutcome != uint256(Outcome.Yes) &&
            winningOutcome != uint256(Outcome.No)
        ) revert InvalidOutcome();

        Market storage m = _markets[marketId];
        if (m.resolved) revert MarketAlreadyResolved();
        if (block.timestamp < m.endTime) revert InvalidEndTime();
        if (m.totalPool > 0) {
            if (winningOutcome == uint256(Outcome.Yes) && m.yesStake == 0)
                revert NoWinningBets();
            if (winningOutcome == uint256(Outcome.No) && m.noStake == 0)
                revert NoWinningBets();
        }

        m.resolved = true;
        m.winningOutcome = Outcome(winningOutcome);

        emit MarketResolved(marketId, winningOutcome, m.totalPool);
    }

    /// @notice Claims winnings from a resolved market. Winners receive their
    /// original stake back plus a pro-rata share of the losing pool.
    function claimWinnings(uint256 marketId) external {
        if (marketId >= marketCount) revert MarketDoesNotExist();
        Market storage m = _markets[marketId];
        if (!m.resolved) revert MarketNotResolved();

        Position storage pos = m.positions[msg.sender];
        if (pos.claimed) revert AlreadyClaimed();

        uint256 winningStake;
        uint256 totalWinning;
        if (m.winningOutcome == Outcome.Yes) {
            winningStake = pos.yesStake;
            totalWinning = m.yesStake;
        } else {
            winningStake = pos.noStake;
            totalWinning = m.noStake;
        }

        if (winningStake == 0) revert NothingToClaim();

        uint256 totalLosing = m.totalPool - totalWinning;
        uint256 payout = winningStake + (winningStake * totalLosing) / totalWinning;

        // Effects before interactions.
        pos.claimed = true;

        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert TransferFailed();

        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    /// @notice Withdraws a user's stake from an unresolved market. Not
    /// permitted within 24 hours of the scheduled resolution time.
    function withdrawStake(uint256 marketId) external {
        if (marketId >= marketCount) revert MarketDoesNotExist();
        Market storage m = _markets[marketId];
        if (m.resolved) revert MarketAlreadyResolved();
        if (block.timestamp + WITHDRAWAL_LOCK_PERIOD >= m.endTime)
            revert WithdrawalLocked();

        Position storage pos = m.positions[msg.sender];
        uint256 stake = pos.yesStake + pos.noStake;
        if (stake == 0) revert NoStake();

        // Effects before interactions.
        m.yesStake -= pos.yesStake;
        m.noStake -= pos.noStake;
        m.totalPool -= stake;
        pos.yesStake = 0;
        pos.noStake = 0;

        (bool ok, ) = payable(msg.sender).call{value: stake}("");
        if (!ok) revert TransferFailed();

        emit StakeWithdrawn(marketId, msg.sender, stake);
    }

    // ------------------------------------------------------------------
    // Administration
    // ------------------------------------------------------------------

    /// @notice Updates the market creation fee. Operator only.
    function setCreationFee(uint256 newFee) external onlyOperator {
        emit CreationFeeUpdated(creationFee, newFee);
        creationFee = newFee;
    }

    /// @notice Transfers the operator role to a new address. Owner only.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Transfers contract ownership. Owner only.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Withdraws accumulated creation fees. Owner only.
    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = _totalFees;
        if (amount == 0) revert NothingToClaim();

        // Effects before interactions.
        _totalFees = 0;

        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice Returns aggregated information about a market.
    function getMarket(
        uint256 marketId
    )
        external
        view
        returns (
            address creator,
            string memory question,
            uint256 endTime,
            uint256 totalPool,
            uint256 yesStake,
            uint256 noStake,
            bool resolved,
            uint256 winningOutcome
        )
    {
        if (marketId >= marketCount) revert MarketDoesNotExist();
        Market storage m = _markets[marketId];
        return (
            m.creator,
            m.question,
            m.endTime,
            m.totalPool,
            m.yesStake,
            m.noStake,
            m.resolved,
            uint256(m.winningOutcome)
        );
    }

    /// @notice Returns a user's position in a given market.
    function getUserPosition(
        uint256 marketId,
        address user
    ) external view returns (uint256 yesStake, uint256 noStake, bool claimed) {
        if (marketId >= marketCount) revert MarketDoesNotExist();
        Position storage pos = _markets[marketId].positions[user];
        return (pos.yesStake, pos.noStake, pos.claimed);
    }

    /// @notice Returns the amount of fees available for the owner to withdraw.
    function availableFees() external view returns (uint256) {
        return _totalFees;
    }
}
