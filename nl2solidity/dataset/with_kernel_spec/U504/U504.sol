// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CollectibleGameCards
/// @notice Manages unique collectible game cards and an associated in-game currency.
/// Players purchase packs with currency, open packs to receive random cards, and
/// transfer cards to other players. A designated operator mints cards, sets pack
/// prices, and distributes in-game currency.
contract CollectibleGameCards {
    ////////////////////////////////////////////////////////////////
    //                          ACCESS CONTROL                     //
    ////////////////////////////////////////////////////////////////

    address public operator;
    address public feeRecipient;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                          CONSTANTS                          //
    ////////////////////////////////////////////////////////////////

    uint256 public constant MAX_CARDS_PER_PLAYER = 500;
    uint256 public constant TRANSFER_FEE = 10;
    uint256 public constant PRECISION = 100;

    uint256 public constant RARITY_COMMON = 1;
    uint256 public constant RARITY_RARE = 2;
    uint256 public constant RARITY_LEGENDARY = 3;

    ////////////////////////////////////////////////////////////////
    //                          STORAGE                           //
    ////////////////////////////////////////////////////////////////

    uint256 public packPrice;
    uint256 public nextTokenId = 1;
    uint256 public totalPacksSold;
    uint256 public totalCardsMinted;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public cardBalance;
    mapping(uint256 => uint256) public cardRarity;

    mapping(address => uint256) public currencyBalance;
    mapping(address => uint256) public pendingPacks;

    ////////////////////////////////////////////////////////////////
    //                           EVENTS                            //
    ////////////////////////////////////////////////////////////////

    event PackPurchased(address indexed buyer, uint256 packPrice, uint256 count, uint256 totalPending);
    event CardMinted(address indexed to, uint256 indexed tokenId, uint256 rarity);
    event CardTransferred(address indexed from, address indexed to, uint256 indexed tokenId);
    event PackPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event CurrencyDistributed(address indexed to, uint256 amount);
    event CurrencyTransferred(address indexed from, address indexed to, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);

    ////////////////////////////////////////////////////////////////
    //                           ERRORS                            //
    ////////////////////////////////////////////////////////////////

    error NotOperator();
    error ZeroAddress();
    error InvalidPrice();
    error InvalidRarity();
    error InvalidCount();
    error InsufficientCurrency(uint256 required, uint256 available);
    error CardLimitExceeded(uint256 current, uint256 attempted);
    error NotCardOwner();
    error CardDoesNotExist();
    error NoPendingPacks();
    error InvalidRecipient();

    ////////////////////////////////////////////////////////////////
    //                         CONSTRUCTOR                         //
    ////////////////////////////////////////////////////////////////

    constructor(
        address _operator,
        address _feeRecipient,
        uint256 _packPrice
    ) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        if (_packPrice == 0) revert InvalidPrice();

        operator = _operator;
        feeRecipient = _feeRecipient;
        packPrice = _packPrice;

        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
        emit PackPriceUpdated(0, _packPrice);
    }

    ////////////////////////////////////////////////////////////////
    //                       OPERATOR ACTIONS                     //
    ////////////////////////////////////////////////////////////////

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address previous = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(previous, newRecipient);
    }

    function setPackPrice(uint256 newPrice) external onlyOperator {
        if (newPrice == 0) revert InvalidPrice();
        uint256 old = packPrice;
        packPrice = newPrice;
        emit PackPriceUpdated(old, newPrice);
    }

    function distributeCurrency(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidCount();
        currencyBalance[to] += amount;
        emit CurrencyDistributed(to, amount);
    }

    function mintCard(address to, uint256 rarity) external onlyOperator returns (uint256) {
        if (to == address(0)) revert ZeroAddress();
        if (rarity == 0 || rarity > RARITY_LEGENDARY) revert InvalidRarity();
        if (cardBalance[to] >= MAX_CARDS_PER_PLAYER) {
            revert CardLimitExceeded(cardBalance[to], cardBalance[to] + 1);
        }

        uint256 id = nextTokenId++;
        ownerOf[id] = to;
        cardRarity[id] = rarity;
        cardBalance[to] += 1;
        totalCardsMinted += 1;

        emit CardMinted(to, id, rarity);
        return id;
    }

    function mintBatch(
        address to,
        uint256 rarity,
        uint256 count
    ) external onlyOperator returns (uint256 firstId) {
        if (to == address(0)) revert ZeroAddress();
        if (rarity == 0 || rarity > RARITY_LEGENDARY) revert InvalidRarity();
        if (count == 0) revert InvalidCount();
        if (cardBalance[to] + count > MAX_CARDS_PER_PLAYER) {
            revert CardLimitExceeded(cardBalance[to], cardBalance[to] + count);
        }

        firstId = nextTokenId;
        for (uint256 i = 0; i < count; i++) {
            uint256 id = nextTokenId++;
            ownerOf[id] = to;
            cardRarity[id] = rarity;
            emit CardMinted(to, id, rarity);
        }
        cardBalance[to] += count;
        totalCardsMinted += count;
    }

    ////////////////////////////////////////////////////////////////
    //                        PLAYER ACTIONS                       //
    ////////////////////////////////////////////////////////////////

    function buyPack(uint256 count) external {
        if (count == 0) revert InvalidCount();
        uint256 cost = packPrice * count;
        if (currencyBalance[msg.sender] < cost) {
            revert InsufficientCurrency(cost, currencyBalance[msg.sender]);
        }

        currencyBalance[msg.sender] -= cost;
        pendingPacks[msg.sender] += count;
        totalPacksSold += count;

        emit PackPurchased(msg.sender, packPrice, count, pendingPacks[msg.sender]);
    }

    function openPack() external returns (uint256) {
        if (pendingPacks[msg.sender] == 0) revert NoPendingPacks();
        if (cardBalance[msg.sender] >= MAX_CARDS_PER_PLAYER) {
            revert CardLimitExceeded(cardBalance[msg.sender], cardBalance[msg.sender] + 1);
        }

        pendingPacks[msg.sender] -= 1;
        uint256 rarity = _randomRarity();
        uint256 id = nextTokenId++;
        ownerOf[id] = msg.sender;
        cardRarity[id] = rarity;
        cardBalance[msg.sender] += 1;
        totalCardsMinted += 1;

        emit CardMinted(msg.sender, id, rarity);
        return id;
    }

    function transferCard(address to, uint256 tokenId) external {
        if (to == address(0)) revert InvalidRecipient();
        if (to == msg.sender) revert InvalidRecipient();

        address currentOwner = ownerOf[tokenId];
        if (currentOwner == address(0)) revert CardDoesNotExist();
        if (currentOwner != msg.sender) revert NotCardOwner();

        if (cardBalance[to] >= MAX_CARDS_PER_PLAYER) {
            revert CardLimitExceeded(cardBalance[to], cardBalance[to] + 1);
        }
        if (currencyBalance[msg.sender] < TRANSFER_FEE) {
            revert InsufficientCurrency(TRANSFER_FEE, currencyBalance[msg.sender]);
        }

        // Effects: charge transfer fee to the designated fee recipient.
        currencyBalance[msg.sender] -= TRANSFER_FEE;
        currencyBalance[feeRecipient] += TRANSFER_FEE;
        emit CurrencyTransferred(msg.sender, feeRecipient, TRANSFER_FEE);

        // Effects: update ownership and balances.
        cardBalance[msg.sender] -= 1;
        cardBalance[to] += 1;
        ownerOf[tokenId] = to;

        emit CardTransferred(msg.sender, to, tokenId);
    }

    ////////////////////////////////////////////////////////////////
    //                           VIEWS                            //
    ////////////////////////////////////////////////////////////////

    function getCurrencyBalance(address account) external view returns (uint256) {
        return currencyBalance[account];
    }

    function getCardBalance(address account) external view returns (uint256) {
        return cardBalance[account];
    }

    function getPendingPacks(address account) external view returns (uint256) {
        return pendingPacks[account];
    }

    function getCardRarity(uint256 tokenId) external view returns (uint256) {
        if (ownerOf[tokenId] == address(0)) revert CardDoesNotExist();
        return cardRarity[tokenId];
    }

    function ownerOfCard(uint256 tokenId) external view returns (address) {
        address cardOwner = ownerOf[tokenId];
        if (cardOwner == address(0)) revert CardDoesNotExist();
        return cardOwner;
    }

    function totalSupply() external view returns (uint256) {
        return totalCardsMinted;
    }

    ////////////////////////////////////////////////////////////////
    //                          INTERNALS                         //
    ////////////////////////////////////////////////////////////////

    function _randomRarity() internal view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.number,
                    msg.sender,
                    nextTokenId,
                    totalPacksSold
                )
            )
        );
        uint256 roll = seed % PRECISION;
        if (roll < 60) return RARITY_COMMON; // 60% common
        if (roll < 90) return RARITY_RARE; // 30% rare
        return RARITY_LEGENDARY; // 10% legendary
    }
}
