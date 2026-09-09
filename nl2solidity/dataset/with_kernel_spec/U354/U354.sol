// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract PuzzlePlatform {
    using SafeERC20 for IERC20;

    enum PuzzleState {
        Open,
        Solved,
        Expired
    }

    struct Puzzle {
        address creator;
        bytes32 solutionHash;
        uint256 deposit;
        uint256 createdAt;
        uint256 solvedAt;
        PuzzleState state;
        address[] solvers;
        mapping(address => bool) hasSolved;
        mapping(address => bool) hasClaimed;
        uint256 totalClaimed;
    }

    IERC20 public immutable rewardToken;
    address public operator;
    uint256 public creationFee;
    uint256 public minDeposit;
    uint256 public puzzleTimeout;
    bool public creationPaused;
    uint256 public totalFeesCollected;
    uint256 public totalRewardsDistributed;

    uint256 public nextPuzzleId;
    mapping(uint256 => Puzzle) private puzzles;
    uint256[] private puzzleIds;

    event PuzzleCreated(
        uint256 indexed puzzleId,
        address indexed creator,
        uint256 deposit,
        uint256 fee,
        bytes32 solutionHash,
        uint256 expiresAt
    );
    event SolutionSubmitted(
        uint256 indexed puzzleId,
        address indexed solver,
        bool correct
    );
    event RewardClaimed(
        uint256 indexed puzzleId,
        address indexed solver,
        uint256 amount
    );
    event DepositWithdrawn(
        uint256 indexed puzzleId,
        address indexed creator,
        uint256 amount
    );
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event PuzzleTimeoutUpdated(uint256 oldTimeout, uint256 newTimeout);
    event MinDepositUpdated(uint256 oldMin, uint256 newMin);
    event CreationPaused(bool paused);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OperatorUpdated(address oldOperator, address newOperator);

    error ZeroAddress();
    error InvalidTimeout();
    error InsufficientDeposit();
    error CreationPausedError();
    error PuzzleNotFound();
    error PuzzleNotOpen();
    error PuzzleNotSolved();
    error PuzzleNotExpired();
    error AlreadySolved();
    error AlreadyClaimed();
    error NotSolver();
    error NotCreator();
    error NotOperator();
    error NoRewardToClaim();
    error NothingToWithdraw();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier puzzleExists(uint256 puzzleId) {
        if (puzzles[puzzleId].creator == address(0)) revert PuzzleNotFound();
        _;
    }

    constructor(address token, address _operator, uint256 _puzzleTimeout) {
        if (token == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_puzzleTimeout == 0) revert InvalidTimeout();

        rewardToken = IERC20(token);
        operator = _operator;

        uint8 decimals = IERC20(token).decimals();
        uint256 unit = 10 ** uint256(decimals);
        creationFee = 5 * unit;
        minDeposit = 100 * unit;
        puzzleTimeout = _puzzleTimeout;

        nextPuzzleId = 1;
    }

    function createPuzzle(
        bytes32 solutionHash,
        uint256 depositAmount
    ) external returns (uint256 puzzleId) {
        if (creationPaused) revert CreationPausedError();
        if (depositAmount < minDeposit) revert InsufficientDeposit();

        uint256 totalRequired = depositAmount + creationFee;
        rewardToken.safeTransferFrom(msg.sender, address(this), totalRequired);

        puzzleId = nextPuzzleId++;
        Puzzle storage puzzle = puzzles[puzzleId];
        puzzle.creator = msg.sender;
        puzzle.solutionHash = solutionHash;
        puzzle.deposit = depositAmount;
        puzzle.createdAt = block.timestamp;
        puzzle.state = PuzzleState.Open;

        puzzleIds.push(puzzleId);
        totalFeesCollected += creationFee;

        emit PuzzleCreated(
            puzzleId,
            msg.sender,
            depositAmount,
            creationFee,
            solutionHash,
            block.timestamp + puzzleTimeout
        );
    }

    function submitSolution(
        uint256 puzzleId,
        bytes32 solution
    ) external puzzleExists(puzzleId) {
        Puzzle storage puzzle = puzzles[puzzleId];

        _expireIfNeeded(puzzleId);

        if (puzzle.state != PuzzleState.Open) revert PuzzleNotOpen();
        if (puzzle.hasSolved[msg.sender]) revert AlreadySolved();

        bool correct = (keccak256(abi.encodePacked(solution)) == puzzle.solutionHash);

        if (correct) {
            puzzle.hasSolved[msg.sender] = true;
            puzzle.solvers.push(msg.sender);
            puzzle.state = PuzzleState.Solved;
            puzzle.solvedAt = block.timestamp;
        }

        emit SolutionSubmitted(puzzleId, msg.sender, correct);
    }

    function claimReward(uint256 puzzleId) external puzzleExists(puzzleId) {
        Puzzle storage puzzle = puzzles[puzzleId];

        _expireIfNeeded(puzzleId);

        if (puzzle.state != PuzzleState.Solved) revert PuzzleNotSolved();
        if (!puzzle.hasSolved[msg.sender]) revert NotSolver();
        if (puzzle.hasClaimed[msg.sender]) revert AlreadyClaimed();

        uint256 solverCount = puzzle.solvers.length;
        if (solverCount == 0) revert NoRewardToClaim();

        uint256 rewardPerSolver = puzzle.deposit / solverCount;
        if (rewardPerSolver == 0) revert NoRewardToClaim();

        puzzle.hasClaimed[msg.sender] = true;
        puzzle.totalClaimed += rewardPerSolver;

        rewardToken.safeTransfer(msg.sender, rewardPerSolver);
        totalRewardsDistributed += rewardPerSolver;

        emit RewardClaimed(puzzleId, msg.sender, rewardPerSolver);
    }

    function withdrawDeposit(uint256 puzzleId) external puzzleExists(puzzleId) {
        Puzzle storage puzzle = puzzles[puzzleId];

        _expireIfNeeded(puzzleId);

        if (puzzle.state != PuzzleState.Expired) revert PuzzleNotExpired();
        if (msg.sender != puzzle.creator) revert NotCreator();
        if (puzzle.deposit == 0) revert NothingToWithdraw();

        uint256 amount = puzzle.deposit;
        puzzle.deposit = 0;

        rewardToken.safeTransfer(msg.sender, amount);

        emit DepositWithdrawn(puzzleId, msg.sender, amount);
    }

    function _expireIfNeeded(uint256 puzzleId) internal {
        Puzzle storage puzzle = puzzles[puzzleId];
        if (
            puzzle.state == PuzzleState.Open &&
            block.timestamp >= puzzle.createdAt + puzzleTimeout
        ) {
            puzzle.state = PuzzleState.Expired;
        }
    }

    function setCreationFee(uint256 newFee) external onlyOperator {
        emit CreationFeeUpdated(creationFee, newFee);
        creationFee = newFee;
    }

    function setPuzzleTimeout(uint256 newTimeout) external onlyOperator {
        if (newTimeout == 0) revert InvalidTimeout();
        emit PuzzleTimeoutUpdated(puzzleTimeout, newTimeout);
        puzzleTimeout = newTimeout;
    }

    function setMinDeposit(uint256 newMin) external onlyOperator {
        emit MinDepositUpdated(minDeposit, newMin);
        minDeposit = newMin;
    }

    function setCreationPaused(bool paused) external onlyOperator {
        creationPaused = paused;
        emit CreationPaused(paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function withdrawFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (totalFeesCollected == 0) revert NothingToWithdraw();

        uint256 amount = totalFeesCollected;
        totalFeesCollected = 0;

        rewardToken.safeTransfer(to, amount);

        emit FeesWithdrawn(to, amount);
    }

    function getPuzzle(
        uint256 puzzleId
    )
        external
        view
        puzzleExists(puzzleId)
        returns (
            address creator,
            uint256 deposit,
            uint256 createdAt,
            uint256 solvedAt,
            PuzzleState state,
            uint256 solverCount
        )
    {
        Puzzle storage puzzle = puzzles[puzzleId];
        return (
            puzzle.creator,
            puzzle.deposit,
            puzzle.createdAt,
            puzzle.solvedAt,
            puzzle.state,
            puzzle.solvers.length
        );
    }

    function getPuzzleSolvers(
        uint256 puzzleId
    ) external view puzzleExists(puzzleId) returns (address[] memory) {
        return puzzles[puzzleId].solvers;
    }

    function hasUserSolved(
        uint256 puzzleId,
        address user
    ) external view puzzleExists(puzzleId) returns (bool) {
        return puzzles[puzzleId].hasSolved[user];
    }

    function hasUserClaimed(
        uint256 puzzleId,
        address user
    ) external view puzzleExists(puzzleId) returns (bool) {
        return puzzles[puzzleId].hasClaimed[user];
    }

    function getPuzzleState(
        uint256 puzzleId
    ) external view puzzleExists(puzzleId) returns (PuzzleState) {
        Puzzle storage puzzle = puzzles[puzzleId];
        if (
            puzzle.state == PuzzleState.Open &&
            block.timestamp >= puzzle.createdAt + puzzleTimeout
        ) {
            return PuzzleState.Expired;
        }
        return puzzle.state;
    }

    function getRewardPerSolver(
        uint256 puzzleId
    ) external view puzzleExists(puzzleId) returns (uint256) {
        Puzzle storage puzzle = puzzles[puzzleId];
        if (puzzle.solvers.length == 0) return 0;
        return puzzle.deposit / puzzle.solvers.length;
    }

    function getPendingReward(
        uint256 puzzleId,
        address solver
    ) external view puzzleExists(puzzleId) returns (uint256) {
        Puzzle storage puzzle = puzzles[puzzleId];
        if (puzzle.state != PuzzleState.Solved) return 0;
        if (!puzzle.hasSolved[solver]) return 0;
        if (puzzle.hasClaimed[solver]) return 0;
        if (puzzle.solvers.length == 0) return 0;
        return puzzle.deposit / puzzle.solvers.length;
    }

    function getTotalPuzzles() external view returns (uint256) {
        return puzzleIds.length;
    }
}
