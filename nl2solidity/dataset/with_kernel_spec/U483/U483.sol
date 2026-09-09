// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error NotAdmin();
error CardDoesNotExist();
error CardAlreadyExists();
error MaxCardsReached();
error NotCardOwner();
error CardNotForSale();
error CardAlreadyForSale();
error InvalidPrice();
error InsufficientPayment();
error InvalidFeeBps();
error ZeroAddress();
error SelfPurchase();
error FeeTransferFailed();
error SellerTransferFailed();
error RefundFailed();
error AlreadyRedeeming();
error NotInRedemption();
error ReentrancyDetected();

contract CollectibleCardMarketplace {
    uint256 public constant MAX_CARDS = 1000;
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 200;
    uint256 public constant MAX_FEE_BPS = 1000;

    address public admin;
    address public feeRecipient;
    uint256 public saleFeeBps;

    struct Card {
        address owner;
        string physicalLocation;
        bool exists;
    }

    struct Listing {
        uint256 price;
        bool active;
    }

    mapping(uint256 => Card) private _cards;
    mapping(uint256 => Listing) private _listings;
    mapping(address => uint256[]) private _ownedCards;
    mapping(uint256 => uint256) private _ownedCardIndex;
    mapping(uint256 => bool) private _redemptionInitiated;
    mapping(uint256 => uint256) private _redemptionTimestamp;

    uint256 public totalCards;
    uint256 private _locked;

    event CardAdded(uint256 indexed cardId, address indexed owner, string physicalLocation);
    event CardLocationUpdated(uint256 indexed cardId, string newLocation);
    event SaleFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event CardListed(uint256 indexed cardId, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed cardId, address indexed seller);
    event CardPurchased(
        uint256 indexed cardId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 fee
    );
    event RedemptionInitiated(uint256 indexed cardId, address indexed owner, uint256 timestamp);
    event RedemptionCancelled(uint256 indexed cardId, address indexed owner);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier cardExists(uint256 cardId) {
        if (!_cards[cardId].exists) revert CardDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        admin = msg.sender;
        feeRecipient = _feeRecipient;
        saleFeeBps = DEFAULT_FEE_BPS;
        _locked = 1;
        emit AdminTransferred(address(0), msg.sender);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit SaleFeeUpdated(0, DEFAULT_FEE_BPS);
    }

    function addCard(
        address owner,
        string calldata physicalLocation
    ) external onlyAdmin returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        if (totalCards >= MAX_CARDS) revert MaxCardsReached();

        uint256 cardId = totalCards + 1;
        if (_cards[cardId].exists) revert CardAlreadyExists();

        _cards[cardId] = Card({
            owner: owner,
            physicalLocation: physicalLocation,
            exists: true
        });

        _addToOwned(owner, cardId);
        totalCards += 1;

        emit CardAdded(cardId, owner, physicalLocation);
        return cardId;
    }

    function updateCardLocation(
        uint256 cardId,
        string calldata newLocation
    ) external onlyAdmin cardExists(cardId) {
        _cards[cardId].physicalLocation = newLocation;
        emit CardLocationUpdated(cardId, newLocation);
    }

    function setSaleFee(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        uint256 old = saleFeeBps;
        saleFeeBps = newFeeBps;
        emit SaleFeeUpdated(old, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyAdmin {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address old = admin;
        admin = newAdmin;
        emit AdminTransferred(old, newAdmin);
    }

    function listCardForSale(uint256 cardId, uint256 price) external cardExists(cardId) {
        if (_cards[cardId].owner != msg.sender) revert NotCardOwner();
        if (_listings[cardId].active) revert CardAlreadyForSale();
        if (price == 0) revert InvalidPrice();

        _listings[cardId] = Listing({price: price, active: true});
        emit CardListed(cardId, msg.sender, price);
    }

    function cancelListing(uint256 cardId) external cardExists(cardId) {
        if (_cards[cardId].owner != msg.sender) revert NotCardOwner();
        if (!_listings[cardId].active) revert CardNotForSale();

        _listings[cardId].active = false;
        _listings[cardId].price = 0;
        emit ListingCancelled(cardId, msg.sender);
    }

    function purchaseCard(uint256 cardId) external payable nonReentrant cardExists(cardId) {
        Listing storage listing = _listings[cardId];
        if (!listing.active) revert CardNotForSale();

        address seller = _cards[cardId].owner;
        if (seller == msg.sender) revert SelfPurchase();
        if (seller == address(0)) revert ZeroAddress();

        uint256 price = listing.price;
        if (msg.value < price) revert InsufficientPayment();

        uint256 fee = (price * saleFeeBps) / BASIS_POINTS_DENOMINATOR;
        uint256 sellerProceeds = price - fee;

        listing.active = false;
        listing.price = 0;

        address buyer = msg.sender;
        _removeFromOwned(seller, cardId);
        _addToOwned(buyer, cardId);
        _cards[cardId].owner = buyer;

        (bool feeOk, ) = payable(feeRecipient).call{value: fee}("");
        if (!feeOk) revert FeeTransferFailed();

        (bool sellerOk, ) = payable(seller).call{value: sellerProceeds}("");
        if (!sellerOk) revert SellerTransferFailed();

        uint256 excess = msg.value - price;
        if (excess > 0) {
            (bool refundOk, ) = payable(buyer).call{value: excess}("");
            if (!refundOk) revert RefundFailed();
        }

        emit CardPurchased(cardId, buyer, seller, price, fee);
    }

    function initiateRedemption(uint256 cardId) external cardExists(cardId) {
        if (_cards[cardId].owner != msg.sender) revert NotCardOwner();
        if (_redemptionInitiated[cardId]) revert AlreadyRedeeming();

        _redemptionInitiated[cardId] = true;
        _redemptionTimestamp[cardId] = block.timestamp;
        emit RedemptionInitiated(cardId, msg.sender, block.timestamp);
    }

    function cancelRedemption(uint256 cardId) external cardExists(cardId) {
        if (_cards[cardId].owner != msg.sender) revert NotCardOwner();
        if (!_redemptionInitiated[cardId]) revert NotInRedemption();

        _redemptionInitiated[cardId] = false;
        _redemptionTimestamp[cardId] = 0;
        emit RedemptionCancelled(cardId, msg.sender);
    }

    function ownerOfCard(uint256 cardId) external view cardExists(cardId) returns (address) {
        return _cards[cardId].owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _ownedCards[owner].length;
    }

    function getOwnedCards(address owner) external view returns (uint256[] memory) {
        return _ownedCards[owner];
    }

    function getCard(
        uint256 cardId
    ) external view cardExists(cardId) returns (address owner, string memory physicalLocation) {
        Card storage c = _cards[cardId];
        return (c.owner, c.physicalLocation);
    }

    function getPhysicalLocation(uint256 cardId) external view cardExists(cardId) returns (string memory) {
        return _cards[cardId].physicalLocation;
    }

    function getListing(uint256 cardId) external view returns (uint256 price, bool active) {
        Listing storage l = _listings[cardId];
        return (l.price, l.active);
    }

    function isRedemptionInitiated(uint256 cardId) external view returns (bool) {
        return _redemptionInitiated[cardId];
    }

    function getRedemptionTimestamp(uint256 cardId) external view returns (uint256) {
        return _redemptionTimestamp[cardId];
    }

    function cardExistsCheck(uint256 cardId) external view returns (bool) {
        return _cards[cardId].exists;
    }

    function _addToOwned(address owner, uint256 cardId) internal {
        _ownedCardIndex[cardId] = _ownedCards[owner].length + 1;
        _ownedCards[owner].push(cardId);
    }

    function _removeFromOwned(address owner, uint256 cardId) internal {
        uint256 idx1 = _ownedCardIndex[cardId];
        if (idx1 == 0) return;

        uint256 idx = idx1 - 1;
        uint256 lastIndex = _ownedCards[owner].length - 1;

        if (idx != lastIndex) {
            uint256 lastCardId = _ownedCards[owner][lastIndex];
            _ownedCards[owner][idx] = lastCardId;
            _ownedCardIndex[lastCardId] = idx + 1;
        }

        _ownedCards[owner].pop();
        _ownedCardIndex[cardId] = 0;
    }

    receive() external payable {}
}
