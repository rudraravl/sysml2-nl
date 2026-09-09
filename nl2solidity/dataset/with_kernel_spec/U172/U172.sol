// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DecentralizedLottery {
    error NotOwner();
    error NotOperator();
    error InsufficientPayment();
    error InvalidTicketCount();
    error InvalidAddress();
    error PreviousRoundInsufficientTickets();
    error RoundAlreadyDrawn();
    error RoundNotDrawn();
    error NoTicketsSold();
    error TransferFailed();
    error InvalidWinningNumbers();

    event RoundStarted(uint256 indexed round, uint256 startTime);
    event TicketsPurchased(address indexed participant, uint256 indexed round, uint256 count, uint256 totalPaid);
    event WinningNumbersDrawn(uint256 indexed round, uint256[] winningNumbers, uint256 prizePool);
    event TicketPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    address public owner;
    address public operator;

    uint256 public ticketPrice;
    uint256 public currentRound;

    uint256 public constant MIN_TICKETS_PER_ROUND = 100;
    uint256 public constant WINNING_NUMBERS_COUNT = 5;
    uint256 public constant MAX_NUMBER = 99;

    struct RoundData {
        uint256 prizePool;
        uint256 ticketsSold;
        uint256 startTime;
        bool drawn;
        uint256[] winningNumbers;
        address[] participants;
    }

    mapping(uint256 => RoundData) private rounds;
    mapping(uint256 => mapping(address => uint256)) private ticketsPurchased;
    mapping(uint256 => mapping(address => bool)) private isParticipant;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert InvalidAddress();
        owner = msg.sender;
        operator = _operator;
        ticketPrice = 0.01 ether;
        currentRound = 1;
        rounds[currentRound].startTime = block.timestamp;
        emit RoundStarted(currentRound, block.timestamp);
        emit OperatorUpdated(address(0), _operator);
    }

    function setTicketPrice(uint256 _newPrice) external onlyOwner {
        if (_newPrice == 0) revert InvalidTicketCount();
        emit TicketPriceUpdated(ticketPrice, _newPrice);
        ticketPrice = _newPrice;
    }

    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert InvalidAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function buyTickets(uint256 _count) external payable {
        if (_count == 0) revert InvalidTicketCount();
        uint256 totalCost = _count * ticketPrice;
        if (msg.value < totalCost) revert InsufficientPayment();

        RoundData storage round = rounds[currentRound];
        if (!isParticipant[currentRound][msg.sender]) {
            isParticipant[currentRound][msg.sender] = true;
            round.participants.push(msg.sender);
        }

        ticketsPurchased[currentRound][msg.sender] += _count;
        round.ticketsSold += _count;
        round.prizePool += totalCost;

        uint256 excess = msg.value - totalCost;
        if (excess > 0) {
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert TransferFailed();
        }

        emit TicketsPurchased(msg.sender, currentRound, _count, totalCost);
    }

    function startNewRound() external onlyOperator {
        RoundData storage prev = rounds[currentRound];
        if (prev.ticketsSold < MIN_TICKETS_PER_ROUND) {
            revert PreviousRoundInsufficientTickets();
        }
        if (!prev.drawn) {
            revert RoundNotDrawn();
        }

        currentRound += 1;
        rounds[currentRound].startTime = block.timestamp;
        emit RoundStarted(currentRound, block.timestamp);
    }

    function drawWinningNumbers(uint256[] calldata _winningNumbers) external onlyOperator {
        RoundData storage round = rounds[currentRound];
        if (round.ticketsSold == 0) revert NoTicketsSold();
        if (round.drawn) revert RoundAlreadyDrawn();
        if (_winningNumbers.length != WINNING_NUMBERS_COUNT) revert InvalidWinningNumbers();

        uint256 seen;
        for (uint256 i = 0; i < WINNING_NUMBERS_COUNT; i++) {
            uint256 num = _winningNumbers[i];
            if (num == 0 || num > MAX_NUMBER) revert InvalidWinningNumbers();
            uint256 mask = 1 << num;
            if ((seen & mask) != 0) revert InvalidWinningNumbers();
            seen |= mask;
            round.winningNumbers.push(num);
        }

        round.drawn = true;
        emit WinningNumbersDrawn(currentRound, _winningNumbers, round.prizePool);
    }

    function getRoundData(uint256 _round)
        external
        view
        returns (
            uint256 prizePool,
            uint256 ticketsSold,
            uint256 startTime,
            bool drawn,
            uint256[] memory winningNumbers
        )
    {
        RoundData storage r = rounds[_round];
        return (r.prizePool, r.ticketsSold, r.startTime, r.drawn, r.winningNumbers);
    }

    function getTicketsPurchased(uint256 _round, address _participant) external view returns (uint256) {
        return ticketsPurchased[_round][_participant];
    }

    function getParticipants(uint256 _round) external view returns (address[] memory) {
        return rounds[_round].participants;
    }

    function getCurrentPrizePool() external view returns (uint256) {
        return rounds[currentRound].prizePool;
    }

    function getCurrentTicketsSold() external view returns (uint256) {
        return rounds[currentRound].ticketsSold;
    }

    function getWinningNumbers(uint256 _round) external view returns (uint256[] memory) {
        return rounds[_round].winningNumbers;
    }

    receive() external payable {
        rounds[currentRound].prizePool += msg.value;
    }
}
