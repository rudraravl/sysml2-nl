// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ScratchCardGame {
    struct Card {
        address player;
        uint256 price;
        bytes32 commitHash;
        bool revealed;
        bool won;
        uint256 prize;
        bool claimed;
    }

    IERC20 public immutable stablecoin;

    address public operator;
    bool public paused;

    uint256 public cardPrice;
    uint256 public winProbability;
    uint256 public maxInstantPrize;

    uint256 public globalPrizePool;
    uint256 public recoveryTicketPool;

    mapping(address => uint256) public playerBalance;
    mapping(address => uint256) public recoveryTickets;
    mapping(uint256 => Card) public cards;
    uint256 public nextCardId;

    uint256 public totalCardsSold;
    uint256 public totalPrizesClaimed;
    uint256 public totalRecoveryRedeemed;

    uint256 public constant BASIS_POINTS = 10_000;

    event Deposited(address indexed player, uint256 amount);
    event CardPurchased(uint256 indexed cardId, address indexed player, uint256 price);
    event CardRevealed(uint256 indexed cardId, address indexed player, bool won, uint256 prize);
    event PrizeClaimed(uint256 indexed cardId, address indexed player, uint256 amount);
    event RecoveryTicketAwarded(uint256 indexed cardId, address indexed player, uint256 tickets);
    event RecoveryTicketRedeemed(address indexed player, uint256 tickets, uint256 amount);
    event ParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue);
    event PrizePoolReplenished(address indexed from, uint256 amount);
    event RecoveryPoolReplenished(address indexed from, uint256 amount);
    event PausedStateChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event Withdrawn(address indexed to, uint256 amount);

    error ErrNotOperator();
    error ErrPaused();
    error ErrZeroAddress();
    error ErrInsufficientBalance();
    error ErrCardNotFound();
    error ErrNotCardOwner();
    error ErrAlreadyRevealed();
    error ErrAlreadyClaimed();
    error ErrInvalidReveal();
    error ErrNotRevealed();
    error ErrNotWon();
    error ErrNothingToRedeem();
    error ErrInsufficientPrizePool();
    error ErrInsufficientRecoveryPool();
    error ErrInvalidParameter();
    error ErrTransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier notPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    constructor(address _stablecoin, address _operator, uint256 _decimals) {
        if (_stablecoin == address(0)) revert ErrZeroAddress();
        if (_operator == address(0)) revert ErrZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        cardPrice = 10 * (10 ** _decimals);
        winProbability = 5_500;
        maxInstantPrize = 10_000 * (10 ** _decimals);
    }

    function deposit(uint256 amount) external notPaused {
        if (amount == 0) revert ErrInvalidParameter();
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert ErrTransferFailed();
        playerBalance[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function purchaseCard(bytes32 secretHash) external notPaused returns (uint256 cardId) {
        if (playerBalance[msg.sender] < cardPrice) revert ErrInsufficientBalance();
        playerBalance[msg.sender] -= cardPrice;
        cardId = nextCardId++;
        cards[cardId] = Card({
            player: msg.sender,
            price: cardPrice,
            commitHash: secretHash,
            revealed: false,
            won: false,
            prize: 0,
            claimed: false
        });
        totalCardsSold++;
        emit CardPurchased(cardId, msg.sender, cardPrice);
    }

    function revealCard(uint256 cardId, bytes32 secret) external notPaused {
        Card storage card = cards[cardId];
        if (card.player == address(0)) revert ErrCardNotFound();
        if (card.player != msg.sender) revert ErrNotCardOwner();
        if (card.revealed) revert ErrAlreadyRevealed();
        if (keccak256(abi.encodePacked(secret)) != card.commitHash) revert ErrInvalidReveal();

        bytes32 randomness = keccak256(abi.encodePacked(secret, blockhash(block.number - 1), cardId, msg.sender));
        uint256 roll = uint256(randomness) % BASIS_POINTS;

        card.revealed = true;

        if (roll < winProbability && globalPrizePool >= cardPrice) {
            uint256 prize = _computePrize(randomness);
            if (prize > globalPrizePool) {
                prize = globalPrizePool;
            }
            card.won = true;
            card.prize = prize;
            globalPrizePool -= prize;
            emit CardRevealed(cardId, msg.sender, true, prize);
        } else {
            recoveryTickets[msg.sender] += 1;
            emit CardRevealed(cardId, msg.sender, false, 0);
            emit RecoveryTicketAwarded(cardId, msg.sender, 1);
        }
    }

    function claimPrize(uint256 cardId) external notPaused {
        Card storage card = cards[cardId];
        if (card.player == address(0)) revert ErrCardNotFound();
        if (card.player != msg.sender) revert ErrNotCardOwner();
        if (!card.revealed) revert ErrNotRevealed();
        if (!card.won) revert ErrNotWon();
        if (card.claimed) revert ErrAlreadyClaimed();

        card.claimed = true;
        uint256 prize = card.prize;
        playerBalance[msg.sender] += prize;
        totalPrizesClaimed += prize;
        emit PrizeClaimed(cardId, msg.sender, prize);
    }

    function redeemRecoveryTickets(uint256 ticketCount) external notPaused {
        if (ticketCount == 0) revert ErrInvalidParameter();
        if (recoveryTickets[msg.sender] < ticketCount) revert ErrNothingToRedeem();
        uint256 amount = ticketCount * cardPrice;
        if (recoveryTicketPool < amount) revert ErrInsufficientRecoveryPool();

        recoveryTickets[msg.sender] -= ticketCount;
        recoveryTicketPool -= amount;
        playerBalance[msg.sender] += amount;
        totalRecoveryRedeemed += amount;
        emit RecoveryTicketRedeemed(msg.sender, ticketCount, amount);
    }

    function withdraw(uint256 amount) external notPaused {
        if (playerBalance[msg.sender] < amount) revert ErrInsufficientBalance();
        playerBalance[msg.sender] -= amount;
        bool ok = stablecoin.transfer(msg.sender, amount);
        if (!ok) revert ErrTransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function setCardPrice(uint256 newPrice) external onlyOperator {
        if (newPrice == 0) revert ErrInvalidParameter();
        emit ParameterUpdated("cardPrice", cardPrice, newPrice);
        cardPrice = newPrice;
    }

    function setWinProbability(uint256 newProbability) external onlyOperator {
        if (newProbability > BASIS_POINTS) revert ErrInvalidParameter();
        emit ParameterUpdated("winProbability", winProbability, newProbability);
        winProbability = newProbability;
    }

    function setMaxInstantPrize(uint256 newMax) external onlyOperator {
        if (newMax == 0) revert ErrInvalidParameter();
        emit ParameterUpdated("maxInstantPrize", maxInstantPrize, newMax);
        maxInstantPrize = newMax;
    }

    function replenishPrizePool(uint256 amount) external onlyOperator {
        if (amount == 0) revert ErrInvalidParameter();
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert ErrTransferFailed();
        globalPrizePool += amount;
        emit PrizePoolReplenished(msg.sender, amount);
    }

    function replenishRecoveryPool(uint256 amount) external onlyOperator {
        if (amount == 0) revert ErrInvalidParameter();
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert ErrTransferFailed();
        recoveryTicketPool += amount;
        emit RecoveryPoolReplenished(msg.sender, amount);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ErrZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function withdrawExcess(uint256 amount) external onlyOperator {
        uint256 totalReserved = globalPrizePool + recoveryTicketPool;
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (contractBalance < totalReserved) revert ErrInsufficientBalance();
        uint256 excess = contractBalance - totalReserved;
        if (amount > excess) revert ErrInsufficientBalance();
        bool ok = stablecoin.transfer(msg.sender, amount);
        if (!ok) revert ErrTransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function _computePrize(bytes32 randomness) internal view returns (uint256) {
        uint256 tierRoll = uint256(randomness >> 128) % BASIS_POINTS;
        uint256 prize;
        if (tierRoll < 5_000) {
            prize = cardPrice;
        } else if (tierRoll < 8_000) {
            prize = cardPrice * 5;
        } else if (tierRoll < 9_500) {
            prize = cardPrice * 50;
        } else if (tierRoll < 9_900) {
            prize = cardPrice * 200;
        } else {
            prize = maxInstantPrize;
        }
        if (prize > maxInstantPrize) {
            prize = maxInstantPrize;
        }
        return prize;
    }

    function getCard(uint256 cardId) external view returns (Card memory) {
        return cards[cardId];
    }

    function contractStablecoinBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    function totalReserved() external view returns (uint256) {
        return globalPrizePool + recoveryTicketPool;
    }
}
