// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInterestBearingVault {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract NoLossLottery {
    error NotOperator();
    error NoActiveRound();
    error RoundEnded();
    error RoundNotEnded();
    error RoundNotFinalized();
    error WinnerAlreadySelected();
    error WinnerNotSelected();
    error PrizeAlreadyClaimed();
    error NotWinner();
    error ZeroAmount();
    error InsufficientDeposit();
    error ZeroAddress();
    error TransferFailed();
    error ReentrantCall();

    uint256 public constant ROUND_DURATION = 7 days;

    address public operator;
    IInterestBearingVault public vault;

    uint256 public currentRoundId;
    uint256 public totalPooled;
    uint256 public totalUnclaimedPrizes;

    struct Round {
        uint256 startTime;
        uint256 endTime;
        address winner;
        uint256 prize;
        uint256 interestAtStart;
        bool winnerSelected;
        bool prizeClaimed;
    }

    mapping(uint256 => Round) public rounds;
    mapping(address => uint256) public deposits;

    uint256 private locked = 1;

    event RoundStarted(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event WinnerSelected(uint256 indexed roundId, address indexed winner, uint256 prize);
    event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint256 amount);
    event Deposited(uint256 indexed roundId, address indexed depositor, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event VaultUpdated(address oldVault, address newVault);
    event OperatorUpdated(address oldOperator, address newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (locked != 1) revert ReentrantCall();
        locked = 2;
        _;
        locked = 1;
    }

    constructor(address _vault) {
        if (_vault == address(0)) revert ZeroAddress();
        vault = IInterestBearingVault(_vault);
        operator = msg.sender;

        currentRoundId = 1;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + ROUND_DURATION;
        Round storage firstRound = rounds[1];
        firstRound.startTime = startTime;
        firstRound.endTime = endTime;
        firstRound.interestAtStart = 0;
        emit RoundStarted(1, startTime, endTime);
    }

    receive() external payable {}

    function _accumulatedInterest() internal view returns (uint256) {
        uint256 vaultValue = vault.balanceOf(address(this));
        uint256 liabilities = totalPooled + totalUnclaimedPrizes;
        if (vaultValue <= liabilities) return 0;
        return vaultValue - liabilities;
    }

    function accumulatedInterest() external view returns (uint256) {
        return _accumulatedInterest();
    }

    function startRound() external onlyOperator nonReentrant {
        if (currentRoundId > 0) {
            if (!rounds[currentRoundId].winnerSelected) revert RoundNotFinalized();
        }

        currentRoundId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + ROUND_DURATION;

        Round storage newRound = rounds[currentRoundId];
        newRound.startTime = startTime;
        newRound.endTime = endTime;
        newRound.interestAtStart = _accumulatedInterest();

        emit RoundStarted(currentRoundId, startTime, endTime);
    }

    function deposit() external payable nonReentrant {
        if (currentRoundId == 0) revert NoActiveRound();
        if (block.timestamp >= rounds[currentRoundId].endTime) revert RoundEnded();
        if (msg.value == 0) revert ZeroAmount();

        deposits[msg.sender] += msg.value;
        totalPooled += msg.value;

        vault.deposit{value: msg.value}();

        emit Deposited(currentRoundId, msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (deposits[msg.sender] < amount) revert InsufficientDeposit();

        deposits[msg.sender] -= amount;
        totalPooled -= amount;

        vault.withdraw(amount);

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function selectWinner(address winner) external onlyOperator nonReentrant {
        if (currentRoundId == 0) revert NoActiveRound();
        Round storage round = rounds[currentRoundId];
        if (block.timestamp < round.endTime) revert RoundNotEnded();
        if (round.winnerSelected) revert WinnerAlreadySelected();
        if (winner == address(0)) revert ZeroAddress();

        uint256 currentInterest = _accumulatedInterest();
        uint256 prize = currentInterest > round.interestAtStart
            ? currentInterest - round.interestAtStart
            : 0;

        round.winner = winner;
        round.prize = prize;
        round.winnerSelected = true;
        totalUnclaimedPrizes += prize;

        emit WinnerSelected(currentRoundId, winner, prize);
    }

    function claimPrize(uint256 roundId) external nonReentrant {
        Round storage round = rounds[roundId];
        if (!round.winnerSelected) revert WinnerNotSelected();
        if (round.prizeClaimed) revert PrizeAlreadyClaimed();
        if (msg.sender != round.winner) revert NotWinner();

        uint256 prize = round.prize;
        round.prizeClaimed = true;
        totalUnclaimedPrizes -= prize;

        if (prize > 0) {
            vault.withdraw(prize);
            (bool success, ) = payable(round.winner).call{value: prize}("");
            if (!success) revert TransferFailed();
        }

        emit PrizeClaimed(roundId, round.winner, prize);
    }

    function updateVault(address newVault) external onlyOperator nonReentrant {
        if (newVault == address(0)) revert ZeroAddress();

        IInterestBearingVault oldVault = vault;
        address oldVaultAddress = address(oldVault);

        // Effects: update state before any external interaction.
        vault = IInterestBearingVault(newVault);

        uint256 vaultBalance = oldVault.balanceOf(address(this));
        if (vaultBalance > 0) {
            oldVault.withdraw(vaultBalance);
            vault.deposit{value: vaultBalance}();
        }

        emit VaultUpdated(oldVaultAddress, newVault);
    }

    function updateOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function getRound(uint256 roundId)
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            address winner,
            uint256 prize,
            uint256 interestAtStart,
            bool winnerSelected,
            bool prizeClaimed
        )
    {
        Round storage round = rounds[roundId];
        return (
            round.startTime,
            round.endTime,
            round.winner,
            round.prize,
            round.interestAtStart,
            round.winnerSelected,
            round.prizeClaimed
        );
    }
}
