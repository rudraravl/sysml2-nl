// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PredictionGame {
    uint256 public constant MIN_PREDICTION = 0.01 ether;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MIN_NUMBER = 1;
    uint256 public constant MAX_NUMBER = 100;

    address public operator;
    uint256 public feeBps; // default 500 = 5%
    uint256 public currentRoundId;
    uint256 private _reentrancyStatus;

    struct Round {
        uint256 pool;
        bool active;
        bool finalized;
        uint256 winningNumber;
        uint256 totalWinningStake;
        uint256 prizePerUnit;
        uint256 feeCollected;
    }

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => address[]) internal _participants;
    mapping(uint256 => mapping(address => bool)) internal _isParticipant;
    mapping(uint256 => mapping(address => uint256)) public predictionNumber;
    mapping(uint256 => mapping(address => uint256)) public predictionStake;
    mapping(uint256 => mapping(address => uint256)) public claimableWinnings;
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event PredictionMade(address indexed user, uint256 indexed roundId, uint256 number, uint256 amount);
    event RoundStarted(uint256 indexed roundId);
    event RoundFinalized(
        uint256 indexed roundId,
        uint256 winningNumber,
        uint256 totalPool,
        uint256 totalWinningStake,
        uint256 feeCollected,
        uint256 prizePerUnit
    );
    event WinningsClaimed(address indexed user, uint256 indexed roundId, uint256 amount);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    error NotOperator();
    error InvalidNumber();
    error InsufficientBalance(uint256 available, uint256 required);
    error PredictionTooSmall(uint256 amount);
    error RoundNotActive();
    error RoundAlreadyFinalized();
    error RoundStillActive();
    error AlreadyPredicted();
    error NothingToClaim();
    error ZeroAmount();
    error InvalidFee();
    error TransferFailed();
    error ReentrantCall();

    modifier nonReentrant() {
        if (_reentrancyStatus == 2) revert ReentrantCall();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator, uint256 _feeBps) {
        if (_operator == address(0)) revert NotOperator();
        if (_feeBps > BASIS_POINTS) revert InvalidFee();
        operator = _operator;
        feeBps = _feeBps;
        _reentrancyStatus = 1;
        currentRoundId = 1;
        rounds[currentRoundId].active = true;
        emit RoundStarted(currentRoundId);
    }

    receive() external payable {
        _credit(msg.sender, msg.value);
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        _credit(msg.sender, msg.value);
    }

    function _credit(address user, uint256 amount) internal {
        balances[user] += amount;
        emit Deposited(user, amount);
    }

    function makePrediction(uint256 number, uint256 amount) external nonReentrant {
        if (number < MIN_NUMBER || number > MAX_NUMBER) revert InvalidNumber();
        if (amount < MIN_PREDICTION) revert PredictionTooSmall(amount);

        uint256 roundId = currentRoundId;
        Round storage round = rounds[roundId];
        if (!round.active || round.finalized) revert RoundNotActive();
        if (predictionStake[roundId][msg.sender] > 0) revert AlreadyPredicted();

        uint256 available = balances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        balances[msg.sender] = available - amount;
        round.pool += amount;
        predictionNumber[roundId][msg.sender] = number;
        predictionStake[roundId][msg.sender] = amount;

        if (!_isParticipant[roundId][msg.sender]) {
            _isParticipant[roundId][msg.sender] = true;
            _participants[roundId].push(msg.sender);
        }

        emit PredictionMade(msg.sender, roundId, number, amount);
    }

    function startRound() external onlyOperator {
        uint256 roundId = currentRoundId;
        if (rounds[roundId].active && !rounds[roundId].finalized) revert RoundStillActive();

        uint256 newRoundId = roundId + 1;
        currentRoundId = newRoundId;
        rounds[newRoundId].active = true;
        emit RoundStarted(newRoundId);
    }

    function finalizeRound(uint256 winningNumber) external onlyOperator nonReentrant {
        uint256 roundId = currentRoundId;
        Round storage round = rounds[roundId];
        if (!round.active) revert RoundNotActive();
        if (round.finalized) revert RoundAlreadyFinalized();
        if (winningNumber < MIN_NUMBER || winningNumber > MAX_NUMBER) revert InvalidNumber();

        round.winningNumber = winningNumber;
        round.finalized = true;
        round.active = false;

        address[] memory participants = _participants[roundId];
        uint256 totalWinningStake = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            if (predictionNumber[roundId][user] == winningNumber) {
                totalWinningStake += predictionStake[roundId][user];
            }
        }

        round.totalWinningStake = totalWinningStake;

        uint256 fee = (round.pool * feeBps) / BASIS_POINTS;
        uint256 prizePool = round.pool - fee;
        round.feeCollected = fee;

        if (totalWinningStake > 0) {
            round.prizePerUnit = prizePool / totalWinningStake;
            for (uint256 i = 0; i < participants.length; i++) {
                address user = participants[i];
                if (predictionNumber[roundId][user] == winningNumber) {
                    uint256 winnings = round.prizePerUnit * predictionStake[roundId][user];
                    claimableWinnings[roundId][user] = winnings;
                }
            }
        } else {
            for (uint256 i = 0; i < participants.length; i++) {
                address user = participants[i];
                uint256 stake = predictionStake[roundId][user];
                if (stake > 0) {
                    balances[user] += stake;
                }
            }
        }

        if (fee > 0) {
            (bool ok, ) = payable(operator).call{value: fee}("");
            if (!ok) revert TransferFailed();
        }

        emit RoundFinalized(
            roundId,
            winningNumber,
            round.pool,
            totalWinningStake,
            fee,
            round.prizePerUnit
        );
    }

    function claimWinnings(uint256 roundId) external nonReentrant {
        Round storage round = rounds[roundId];
        if (!round.finalized) revert RoundStillActive();

        uint256 amount = claimableWinnings[roundId][msg.sender];
        if (amount == 0) revert NothingToClaim();

        claimableWinnings[roundId][msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit WinningsClaimed(msg.sender, roundId, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 available = balances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        balances[msg.sender] = available - amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function setFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > BASIS_POINTS) revert InvalidFee();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert NotOperator();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function getParticipants(uint256 roundId) external view returns (address[] memory) {
        return _participants[roundId];
    }

    function participantCount(uint256 roundId) external view returns (uint256) {
        return _participants[roundId].length;
    }
}
