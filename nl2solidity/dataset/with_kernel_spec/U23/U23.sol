// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CoinFlipPredictionMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Side {
        Heads,
        Tails
    }

    enum Outcome {
        None,
        Heads,
        Tails
    }

    struct Flip {
        uint256 id;
        uint64 startedAt;
        uint64 closedAt;
        Outcome outcome;
        uint256 headsStake;
        uint256 tailsStake;
        bool active;
        bool resolved;
    }

    struct UserBet {
        uint256 headsStake;
        uint256 tailsStake;
        bool claimed;
    }

    uint256 public constant HOUSE_EDGE_FIXED_BIPS = 250; // 2.5%
    uint256 public constant BIPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_BET = 100;

    IERC20 public immutable betToken;
    address public operator;
    uint256 public houseEdgeBps;
    uint256 public nextFlipId;
    uint256 public accumulatedHouseProfit;

    mapping(uint256 => Flip) public flips;
    mapping(uint256 => mapping(address => UserBet)) public userBets;

    event FlipInitiated(uint256 indexed flipId, uint256 startedAt);
    event BetPlaced(uint256 indexed flipId, address indexed user, Side side, uint256 amount);
    event OutcomeRecorded(
        uint256 indexed flipId,
        Outcome outcome,
        uint256 headsStake,
        uint256 tailsStake
    );
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event HouseEdgeUpdated(uint256 oldEdgeBps, uint256 newEdgeBps);
    event WinningsClaimed(uint256 indexed flipId, address indexed user, uint256 amount);
    event HouseProfitWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error NotOperator();
    error FlipNotActive();
    error FlipAlreadyResolved();
    error FlipNotResolved();
    error AlreadyClaimed();
    error InvalidOutcome();
    error BetTooSmall(uint256 amount, uint256 minimum);
    error NothingToClaim();
    error HouseEdgeIsFixed();
    error NoHouseProfit();

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotOperator();
        _;
    }

    constructor(address betToken_, address operator_) Ownable(msg.sender) {
        if (betToken_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        betToken = IERC20(betToken_);
        operator = operator_;
        houseEdgeBps = HOUSE_EDGE_FIXED_BIPS;
        nextFlipId = 1;
        emit OperatorUpdated(address(0), operator_);
        emit HouseEdgeUpdated(0, houseEdgeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setHouseEdge(uint256 newHouseEdgeBps) external onlyOperator {
        if (newHouseEdgeBps != HOUSE_EDGE_FIXED_BIPS) revert HouseEdgeIsFixed();
        emit HouseEdgeUpdated(houseEdgeBps, newHouseEdgeBps);
        houseEdgeBps = newHouseEdgeBps;
    }

    function initiateFlip() external onlyOperator returns (uint256 flipId) {
        flipId = nextFlipId++;
        Flip storage f = flips[flipId];
        f.id = flipId;
        f.startedAt = uint64(block.timestamp);
        f.active = true;
        emit FlipInitiated(flipId, f.startedAt);
    }

    function recordOutcome(uint256 flipId, Outcome outcome) external onlyOperator {
        if (outcome == Outcome.None) revert InvalidOutcome();
        Flip storage f = flips[flipId];
        if (!f.active) revert FlipNotActive();
        if (f.resolved) revert FlipAlreadyResolved();

        f.outcome = outcome;
        f.resolved = true;
        f.active = false;
        f.closedAt = uint64(block.timestamp);

        uint256 totalPot = f.headsStake + f.tailsStake;
        uint256 winningTotal = (outcome == Outcome.Heads) ? f.headsStake : f.tailsStake;
        if (winningTotal > 0) {
            uint256 houseEdge = (totalPot * houseEdgeBps) / BIPS_DENOMINATOR;
            accumulatedHouseProfit += houseEdge;
        }

        emit OutcomeRecorded(flipId, outcome, f.headsStake, f.tailsStake);
    }

    function placeBet(uint256 flipId, Side side, uint256 amount) external nonReentrant {
        if (amount < MIN_BET) revert BetTooSmall(amount, MIN_BET);
        Flip storage f = flips[flipId];
        if (!f.active || f.resolved) revert FlipNotActive();

        betToken.safeTransferFrom(msg.sender, address(this), amount);

        UserBet storage ub = userBets[flipId][msg.sender];
        if (side == Side.Heads) {
            f.headsStake += amount;
            ub.headsStake += amount;
        } else {
            f.tailsStake += amount;
            ub.tailsStake += amount;
        }

        emit BetPlaced(flipId, msg.sender, side, amount);
    }

    function claim(uint256 flipId) external nonReentrant {
        Flip storage f = flips[flipId];
        if (!f.resolved) revert FlipNotResolved();
        UserBet storage ub = userBets[flipId][msg.sender];
        if (ub.claimed) revert AlreadyClaimed();

        uint256 userTotalBet = ub.headsStake + ub.tailsStake;
        if (userTotalBet == 0) revert NothingToClaim();

        ub.claimed = true;

        uint256 totalPot = f.headsStake + f.tailsStake;
        uint256 winningStake;
        uint256 totalWinning;

        if (f.outcome == Outcome.Heads) {
            winningStake = ub.headsStake;
            totalWinning = f.headsStake;
        } else {
            winningStake = ub.tailsStake;
            totalWinning = f.tailsStake;
        }

        uint256 payout;
        if (totalWinning == 0) {
            payout = userTotalBet;
        } else if (winningStake > 0) {
            uint256 houseEdge = (totalPot * houseEdgeBps) / BIPS_DENOMINATOR;
            uint256 distributable = totalPot - houseEdge;
            payout = (winningStake * distributable) / totalWinning;
        }

        if (payout > 0) {
            betToken.safeTransfer(msg.sender, payout);
        }
        emit WinningsClaimed(flipId, msg.sender, payout);
    }

    function withdrawHouseProfit(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0 || amount > accumulatedHouseProfit) revert NoHouseProfit();
        accumulatedHouseProfit -= amount;
        betToken.safeTransfer(to, amount);
        emit HouseProfitWithdrawn(to, amount);
    }

    function getFlip(uint256 flipId) external view returns (Flip memory) {
        return flips[flipId];
    }

    function getUserBet(uint256 flipId, address user) external view returns (UserBet memory) {
        return userBets[flipId][user];
    }
}
