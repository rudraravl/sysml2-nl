// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BlockHashPredictionGame
 * @notice A prediction game where users wager on the parity (even/odd) of a
 *         future block hash. Wagers are held in escrow; winners receive a
 *         proportional share of the total pool minus a commission on profit.
 *         If a block hash becomes unavailable (256-block lookback exceeded) or
 *         the winning side has no bets, all wagers are refunded.
 */
contract BlockHashPredictionGame {
    // ============================ Custom Errors ============================ //
    error NotOwner();
    error ZeroAddress();
    error WagerBelowMinimum();
    error InvalidGameDuration();
    error InvalidCommission();
    error IncorrectWagerAmount();
    error RoundDoesNotExist();
    error RoundNotOpen();
    error RoundAlreadyResolved();
    error RoundNotReady();
    error RoundNotResolved();
    error AlreadyClaimed();
    error NothingToClaim();
    error InsufficientBalance();
    error TransferFailed();
    error ReentrantCall();

    // ============================== Constants ============================== //
    uint256 public constant MIN_WAGER = 0.01 ether;
    uint256 public constant MAX_BLOCK_LOOKBACK = 256;
    uint256 public constant COMMISSION_DENOMINATOR = 100;

    // =========================== State Variables =========================== //
    address public owner;
    uint256 public wagerAmount;
    uint256 public gameDuration;
    uint256 public commissionPercentage;
    uint256 public totalRounds;

    struct Round {
        uint256 targetBlock;
        uint256 totalEvenPool;
        uint256 totalOddPool;
        bool resolved;
        bool evenWon;
        bool refunded;
        bytes32 winningHash;
        mapping(address => uint256) evenWagers;
        mapping(address => uint256) oddWagers;
        mapping(address => bool) claimed;
    }

    mapping(uint256 => Round) internal _rounds;
    mapping(address => uint256) public balances;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // =============================== Events ================================ //
    event RoundStarted(uint256 indexed roundId, uint256 targetBlock, uint256 startedAtBlock);
    event WagerPlaced(uint256 indexed roundId, address indexed user, bool betEven, uint256 amount);
    event RoundResolved(uint256 indexed roundId, bytes32 winningHash, bool evenWon, bool refunded);
    event WinningsClaimed(uint256 indexed roundId, address indexed user, uint256 payout, uint256 commission);
    event Withdrawn(address indexed user, uint256 amount);
    event WagerAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event GameDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event CommissionPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============================== Modifiers ============================== //
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ============================== Constructor ============================ //
    constructor(uint256 _wagerAmount, uint256 _gameDuration) {
        if (_wagerAmount < MIN_WAGER) revert WagerBelowMinimum();
        if (_gameDuration == 0 || _gameDuration > MAX_BLOCK_LOOKBACK) revert InvalidGameDuration();

        owner = msg.sender;
        wagerAmount = _wagerAmount;
        gameDuration = _gameDuration;
        commissionPercentage = 5;
        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ========================== Admin Functions =========================== //
    function setWagerAmount(uint256 _wagerAmount) external onlyOwner {
        if (_wagerAmount < MIN_WAGER) revert WagerBelowMinimum();
        emit WagerAmountUpdated(wagerAmount, _wagerAmount);
        wagerAmount = _wagerAmount;
    }

    function setGameDuration(uint256 _gameDuration) external onlyOwner {
        if (_gameDuration == 0 || _gameDuration > MAX_BLOCK_LOOKBACK) revert InvalidGameDuration();
        emit GameDurationUpdated(gameDuration, _gameDuration);
        gameDuration = _gameDuration;
    }

    function setCommissionPercentage(uint256 _commissionPercentage) external onlyOwner {
        if (_commissionPercentage > COMMISSION_DENOMINATOR) revert InvalidCommission();
        emit CommissionPercentageUpdated(commissionPercentage, _commissionPercentage);
        commissionPercentage = _commissionPercentage;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // =========================== Game Functions ============================ //
    /**
     * @notice Starts a new prediction round. The target block is set to
     *         block.number + gameDuration. Anyone may start a round.
     * @return roundId The ID of the newly created round.
     */
    function startRound() external returns (uint256 roundId) {
        roundId = totalRounds++;
        Round storage round = _rounds[roundId];
        round.targetBlock = block.number + gameDuration;
        emit RoundStarted(roundId, round.targetBlock, block.number);
    }

    /**
     * @notice Places a wager on the parity of the target block hash.
     * @param roundId The round to bet on.
     * @param betEven True for even, false for odd.
     */
    function placeWager(uint256 roundId, bool betEven) external payable {
        if (msg.value != wagerAmount) revert IncorrectWagerAmount();

        Round storage round = _rounds[roundId];
        if (round.targetBlock == 0) revert RoundDoesNotExist();
        if (round.resolved) revert RoundAlreadyResolved();
        if (block.number >= round.targetBlock) revert RoundNotOpen();

        if (betEven) {
            round.evenWagers[msg.sender] += msg.value;
            round.totalEvenPool += msg.value;
        } else {
            round.oddWagers[msg.sender] += msg.value;
            round.totalOddPool += msg.value;
        }

        emit WagerPlaced(roundId, msg.sender, betEven, msg.value);
    }

    /**
     * @notice Resolves a round after its target block has been mined.
     *         If the blockhash is unavailable or the winning side has no
     *         bets, all wagers are refunded.
     * @param roundId The round to resolve.
     */
    function resolveRound(uint256 roundId) external {
        Round storage round = _rounds[roundId];
        if (round.targetBlock == 0) revert RoundDoesNotExist();
        if (round.resolved) revert RoundAlreadyResolved();
        if (block.number <= round.targetBlock) revert RoundNotReady();

        bytes32 hash = blockhash(round.targetBlock);

        if (hash == bytes32(0)) {
            round.resolved = true;
            round.refunded = true;
            emit RoundResolved(roundId, hash, false, true);
        } else {
            bool evenWon = uint256(hash) % 2 == 0;
            bool winningSideHasBets = evenWon ? round.totalEvenPool > 0 : round.totalOddPool > 0;

            round.resolved = true;
            round.winningHash = hash;
            round.evenWon = evenWon;

            if (!winningSideHasBets) {
                round.refunded = true;
            }

            emit RoundResolved(roundId, hash, evenWon, round.refunded);
        }
    }

    /**
     * @notice Claims winnings from a resolved round. Winners receive a
     *         proportional share of the total pool minus commission on profit.
     *         Losers receive nothing. In refund mode, all participants get
     *         their wagers back.
     * @param roundId The round to claim from.
     */
    function claimWinnings(uint256 roundId) external nonReentrant {
        Round storage round = _rounds[roundId];
        if (!round.resolved) revert RoundNotResolved();
        if (round.claimed[msg.sender]) revert AlreadyClaimed();

        uint256 totalUserWager = round.evenWagers[msg.sender] + round.oddWagers[msg.sender];
        if (totalUserWager == 0) revert NothingToClaim();

        round.claimed[msg.sender] = true;

        if (round.refunded) {
            balances[msg.sender] += totalUserWager;
            emit WinningsClaimed(roundId, msg.sender, totalUserWager, 0);
            return;
        }

        uint256 userWager;
        uint256 winningPool;

        if (round.evenWon) {
            userWager = round.evenWagers[msg.sender];
            winningPool = round.totalEvenPool;
        } else {
            userWager = round.oddWagers[msg.sender];
            winningPool = round.totalOddPool;
        }

        if (userWager == 0) {
            return;
        }

        uint256 totalPool = round.totalEvenPool + round.totalOddPool;
        uint256 grossPayout = (userWager * totalPool) / winningPool;
        uint256 profit = grossPayout - userWager;
        uint256 commission = (profit * commissionPercentage) / COMMISSION_DENOMINATOR;
        uint256 netPayout = grossPayout - commission;

        balances[msg.sender] += netPayout;
        if (commission > 0) {
            balances[owner] += commission;
        }

        emit WinningsClaimed(roundId, msg.sender, netPayout, commission);
    }

    /**
     * @notice Withdraws a specified amount from the caller's available balance.
     * @param amount The amount of ETH to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount > balances[msg.sender]) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Withdraws the caller's entire available balance.
     */
    function withdrawAll() external nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert InsufficientBalance();
        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    // =========================== View Functions =========================== //
    function getRoundInfo(uint256 roundId)
        external
        view
        returns (
            uint256 targetBlock,
            uint256 totalEvenPool,
            uint256 totalOddPool,
            bool resolved,
            bool evenWon,
            bool refunded,
            bytes32 winningHash
        )
    {
        Round storage round = _rounds[roundId];
        return (
            round.targetBlock,
            round.totalEvenPool,
            round.totalOddPool,
            round.resolved,
            round.evenWon,
            round.refunded,
            round.winningHash
        );
    }

    function getUserWager(uint256 roundId, address user)
        external
        view
        returns (uint256 evenWager, uint256 oddWager)
    {
        return (_rounds[roundId].evenWagers[user], _rounds[roundId].oddWagers[user]);
    }

    function hasClaimed(uint256 roundId, address user) external view returns (bool) {
        return _rounds[roundId].claimed[user];
    }

    function getPendingPayout(uint256 roundId, address user) external view returns (uint256) {
        Round storage round = _rounds[roundId];
        if (!round.resolved || round.claimed[user]) return 0;

        if (round.refunded) {
            return round.evenWagers[user] + round.oddWagers[user];
        }

        uint256 userWager;
        uint256 winningPool;

        if (round.evenWon) {
            userWager = round.evenWagers[user];
            winningPool = round.totalEvenPool;
        } else {
            userWager = round.oddWagers[user];
            winningPool = round.totalOddPool;
        }

        if (userWager == 0 || winningPool == 0) return 0;

        uint256 totalPool = round.totalEvenPool + round.totalOddPool;
        uint256 grossPayout = (userWager * totalPool) / winningPool;
        uint256 profit = grossPayout - userWager;
        uint256 commission = (profit * commissionPercentage) / COMMISSION_DENOMINATOR;
        return grossPayout - commission;
    }

    function getLatestRoundId() external view returns (uint256) {
        if (totalRounds == 0) return type(uint256).max;
        return totalRounds - 1;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
