// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DecentralizedLottery {
    error NotOperator();
    error RoundNotOpen();
    error RoundNotClosed();
    error RoundNotConcluded();
    error InsufficientDeposit();
    error InvalidPrediction();
    error AlreadyPredicted();
    error NoPrediction();
    error NotAWinner();
    error AlreadyClaimed();
    error FeeAlreadyWithdrawn();
    error TransferFailed();
    error NoWinners();

    event RoundStarted(uint256 indexed roundId, uint256 prizePool);
    event RoundClosed(uint256 indexed roundId, uint256 prizePool);
    event WinningNumberSet(uint256 indexed roundId, uint256 winningNumber);
    event PredictionMade(uint256 indexed roundId, address indexed user, uint256 number, uint256 amount);
    event PredictionWithdrawn(uint256 indexed roundId, address indexed user, uint256 amount);
    event WinningsClaimed(uint256 indexed roundId, address indexed user, uint256 amount);
    event PlatformFeeWithdrawn(uint256 indexed roundId, address indexed operator, uint256 amount);

    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant PLATFORM_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOM = 10000;

    enum RoundState { Open, Closed, Concluded }

    struct Round {
        RoundState state;
        uint256 prizePool;
        uint256 winningNumber;
        uint256 totalWinningDeposits;
        bool feeWithdrawn;
    }

    struct Prediction {
        uint256 number;
        uint256 amount;
        bool claimed;
    }

    address public operator;
    uint256 public currentRoundId;

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => Prediction)) public predictions;
    mapping(uint256 => address[]) public participants;
    mapping(uint256 => mapping(address => bool)) public isParticipant;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor() {
        operator = msg.sender;
        currentRoundId = 1;
        rounds[1].state = RoundState.Open;
        emit RoundStarted(1, 0);
    }

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    function predict(uint256 number) external payable {
        uint256 roundId = currentRoundId;
        Round storage round = rounds[roundId];
        if (round.state != RoundState.Open) revert RoundNotOpen();
        if (msg.value < MIN_DEPOSIT) revert InsufficientDeposit();
        if (number == 0) revert InvalidPrediction();

        Prediction storage existing = predictions[roundId][msg.sender];
        if (existing.amount != 0) revert AlreadyPredicted();

        existing.number = number;
        existing.amount = msg.value;

        if (!isParticipant[roundId][msg.sender]) {
            isParticipant[roundId][msg.sender] = true;
            participants[roundId].push(msg.sender);
        }

        round.prizePool += msg.value;

        emit PredictionMade(roundId, msg.sender, number, msg.value);
    }

    function withdrawPrediction() external {
        uint256 roundId = currentRoundId;
        Round storage round = rounds[roundId];
        if (round.state != RoundState.Open) revert RoundNotOpen();

        Prediction storage p = predictions[roundId][msg.sender];
        if (p.amount == 0) revert NoPrediction();

        uint256 amount = p.amount;
        round.prizePool -= amount;
        p.amount = 0;
        p.number = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit PredictionWithdrawn(roundId, msg.sender, amount);
    }

    function claimWinnings(uint256 roundId) external {
        Round storage round = rounds[roundId];
        if (round.state != RoundState.Concluded) revert RoundNotConcluded();

        Prediction storage p = predictions[roundId][msg.sender];
        if (p.amount == 0) revert NoPrediction();
        if (p.claimed) revert AlreadyClaimed();
        if (p.number != round.winningNumber) revert NotAWinner();
        if (round.totalWinningDeposits == 0) revert NoWinners();

        p.claimed = true;

        uint256 fee = (round.prizePool * PLATFORM_FEE_BPS) / BPS_DENOM;
        uint256 distributable = round.prizePool - fee;
        uint256 payout = (distributable * p.amount) / round.totalWinningDeposits;

        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert TransferFailed();

        emit WinningsClaimed(roundId, msg.sender, payout);
    }

    function closeRound() external onlyOperator {
        uint256 roundId = currentRoundId;
        Round storage round = rounds[roundId];
        if (round.state != RoundState.Open) revert RoundNotOpen();
        round.state = RoundState.Closed;
        emit RoundClosed(roundId, round.prizePool);
    }

    function setWinningNumber(uint256 winningNumber) external onlyOperator {
        uint256 roundId = currentRoundId;
        Round storage round = rounds[roundId];
        if (round.state != RoundState.Closed) revert RoundNotClosed();
        if (winningNumber == 0) revert InvalidPrediction();

        round.winningNumber = winningNumber;

        uint256 totalWinning = 0;
        address[] storage users = participants[roundId];
        for (uint256 i = 0; i < users.length; i++) {
            Prediction storage p = predictions[roundId][users[i]];
            if (p.amount != 0 && p.number == winningNumber) {
                totalWinning += p.amount;
            }
        }
        round.totalWinningDeposits = totalWinning;
        round.state = RoundState.Concluded;

        emit WinningNumberSet(roundId, winningNumber);
    }

    function withdrawPlatformFee(uint256 roundId) external onlyOperator {
        Round storage round = rounds[roundId];
        if (round.state != RoundState.Concluded) revert RoundNotConcluded();
        if (round.feeWithdrawn) revert FeeAlreadyWithdrawn();

        round.feeWithdrawn = true;
        uint256 fee = (round.prizePool * PLATFORM_FEE_BPS) / BPS_DENOM;

        (bool ok, ) = payable(operator).call{value: fee}("");
        if (!ok) revert TransferFailed();

        emit PlatformFeeWithdrawn(roundId, operator, fee);
    }

    function startNewRound() external onlyOperator {
        uint256 prevId = currentRoundId;
        if (rounds[prevId].state != RoundState.Concluded) revert RoundNotConcluded();

        uint256 newId = prevId + 1;
        currentRoundId = newId;
        rounds[newId].state = RoundState.Open;

        emit RoundStarted(newId, 0);
    }

    function getRound(uint256 roundId)
        external
        view
        returns (
            RoundState state,
            uint256 prizePool,
            uint256 winningNumber,
            uint256 totalWinningDeposits,
            bool feeWithdrawn
        )
    {
        Round storage r = rounds[roundId];
        return (r.state, r.prizePool, r.winningNumber, r.totalWinningDeposits, r.feeWithdrawn);
    }

    function getPrediction(uint256 roundId, address user)
        external
        view
        returns (uint256 number, uint256 amount, bool claimed)
    {
        Prediction storage p = predictions[roundId][user];
        return (p.number, p.amount, p.claimed);
    }

    function participantCount(uint256 roundId) external view returns (uint256) {
        return participants[roundId].length;
    }
}
