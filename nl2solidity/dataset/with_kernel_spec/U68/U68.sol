// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GamingAssetMarketplace {
    // ---------------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------------
    error NotAuthorized();
    error Paused();
    error NotPaused();
    error InvalidAmount();
    error InvalidPrice();
    error InvalidQuantity();
    error InsufficientQuantity();
    error InvalidFee();
    error InvalidDuration();
    error ZeroAddress();
    error ItemNotFound();
    error ItemAlreadyExists();
    error ListingNotFound();
    error ListingExpired();
    error ListingInactive();
    error InsufficientBalance();
    error InsufficientItemBalance();
    error InsufficientPayment();
    error TransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------
    event ItemListed(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed itemId,
        uint256 quantity,
        uint256 pricePerItem,
        uint256 expiry
    );
    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event ItemPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 itemId,
        uint256 quantity,
        uint256 totalPrice,
        uint256 fee
    );
    event Withdrawal(address indexed player, uint256 amount);
    event Deposit(address indexed player, uint256 amount);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event PausedStateChanged(bool paused);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ItemCreated(uint256 indexed itemId, string name);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 quantity);
    event ItemTransferred(address indexed from, address indexed to, uint256 indexed itemId, uint256 quantity);

    // ---------------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------------
    uint256 public constant MAX_FEE = 500; // 5% in basis points
    uint256 public constant MAX_LISTING_DURATION = 30 days;
    uint256 public constant FEE_DENOMINATOR = 10000;

    // ---------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------
    address public owner;
    address public operator;
    bool public paused;
    uint256 public transactionFee; // in basis points (0..500)

    // Native platform currency balances (in wei), includes earnings and deposits.
    mapping(address => uint256) public nativeBalances;

    // Item balances: player => itemId => quantity held directly (not escrowed).
    mapping(address => mapping(uint256 => uint256)) public itemBalances;

    // Total supply per item id.
    mapping(uint256 => uint256) public itemTotalSupply;

    struct Listing {
        address seller;
        uint256 itemId;
        uint256 pricePerItem;
        uint256 quantityRemaining;
        uint256 expiry;
        bool active;
    }

    uint256 public nextListingId;
    mapping(uint256 => Listing) public listings;

    struct ItemInfo {
        bool exists;
        string name;
    }
    mapping(uint256 => ItemInfo) public itemInfo;
    uint256[] public allItems;

    // Reentrancy guard
    uint256 private _locked = 1;

    // ---------------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------
    constructor(uint256 _transactionFee, address _operator) {
        if (_transactionFee > MAX_FEE) revert InvalidFee();
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        transactionFee = _transactionFee;
        emit FeeUpdated(0, _transactionFee);
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
    }

    // ---------------------------------------------------------------------------
    // Native currency deposit / withdrawal
    // ---------------------------------------------------------------------------
    function deposit() external payable whenNotPaused {
        if (msg.value == 0) revert InvalidAmount();
        nativeBalances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        uint256 bal = nativeBalances[msg.sender];
        if (bal < amount) revert InsufficientBalance();
        // effects
        nativeBalances[msg.sender] = bal - amount;
        // interactions
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawal(msg.sender, amount);
    }

    // ---------------------------------------------------------------------------
    // Item management (operator)
    // ---------------------------------------------------------------------------
    function createItem(uint256 itemId, string calldata name) external onlyOperator {
        if (itemInfo[itemId].exists) revert ItemAlreadyExists();
        itemInfo[itemId] = ItemInfo({exists: true, name: name});
        allItems.push(itemId);
        emit ItemCreated(itemId, name);
    }

    function mintItem(address to, uint256 itemId, uint256 quantity) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (quantity == 0) revert InvalidQuantity();
        if (!itemInfo[itemId].exists) revert ItemNotFound();
        itemBalances[to][itemId] += quantity;
        itemTotalSupply[itemId] += quantity;
        emit ItemMinted(to, itemId, quantity);
    }

    // ---------------------------------------------------------------------------
    // Peer-to-peer item transfer
    // ---------------------------------------------------------------------------
    function transferItem(address to, uint256 itemId, uint256 quantity) external whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (quantity == 0) revert InvalidQuantity();
        if (!itemInfo[itemId].exists) revert ItemNotFound();
        uint256 bal = itemBalances[msg.sender][itemId];
        if (bal < quantity) revert InsufficientItemBalance();
        // effects
        itemBalances[msg.sender][itemId] = bal - quantity;
        itemBalances[to][itemId] += quantity;
        emit ItemTransferred(msg.sender, to, itemId, quantity);
    }

    // ---------------------------------------------------------------------------
    // Listings
    // ---------------------------------------------------------------------------
    function listItem(
        uint256 itemId,
        uint256 quantity,
        uint256 pricePerItem,
        uint256 duration
    ) external whenNotPaused returns (uint256 listingId) {
        if (quantity == 0) revert InvalidQuantity();
        if (pricePerItem == 0) revert InvalidPrice();
        if (duration == 0 || duration > MAX_LISTING_DURATION) revert InvalidDuration();
        if (!itemInfo[itemId].exists) revert ItemNotFound();
        uint256 bal = itemBalances[msg.sender][itemId];
        if (bal < quantity) revert InsufficientItemBalance();

        // Escrow items into the contract for safe settlement.
        itemBalances[msg.sender][itemId] = bal - quantity;

        listingId = nextListingId++;
        uint256 expiry = block.timestamp + duration;
        listings[listingId] = Listing({
            seller: msg.sender,
            itemId: itemId,
            pricePerItem: pricePerItem,
            quantityRemaining: quantity,
            expiry: expiry,
            active: true
        });

        emit ItemListed(listingId, msg.sender, itemId, quantity, pricePerItem, expiry);
    }

    function cancelListing(uint256 listingId) external {
        Listing storage l = listings[listingId];
        if (l.seller == address(0)) revert ListingNotFound();
        if (!l.active) revert ListingInactive();
        if (l.seller != msg.sender) revert NotAuthorized();
        // effects
        l.active = false;
        uint256 remaining = l.quantityRemaining;
        l.quantityRemaining = 0;
        itemBalances[msg.sender][l.itemId] += remaining;
        emit ListingCancelled(listingId, msg.sender);
    }

    function purchaseItem(uint256 listingId, uint256 quantity)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        Listing storage l = listings[listingId];
        if (l.seller == address(0)) revert ListingNotFound();
        if (!l.active) revert ListingInactive();
        if (block.timestamp > l.expiry) revert ListingExpired();
        if (quantity == 0) revert InvalidQuantity();
        if (l.quantityRemaining < quantity) revert InsufficientQuantity();

        uint256 totalPrice = l.pricePerItem * quantity;
        if (msg.value < totalPrice) revert InsufficientPayment();

        uint256 fee = (totalPrice * transactionFee) / FEE_DENOMINATOR;
        uint256 sellerProceeds = totalPrice - fee;

        // effects
        l.quantityRemaining -= quantity;
        if (l.quantityRemaining == 0) {
            l.active = false;
        }
        // credit buyer with the items (already escrowed by the contract)
        itemBalances[msg.sender][l.itemId] += quantity;
        // credit seller net proceeds and operator fee (in native currency)
        nativeBalances[l.seller] += sellerProceeds;
        if (fee > 0) {
            nativeBalances[operator] += fee;
        }

        // interactions: refund any excess ETH sent.
        if (msg.value > totalPrice) {
            uint256 refund = msg.value - totalPrice;
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }

        emit ItemPurchased(listingId, msg.sender, l.seller, l.itemId, quantity, totalPrice, fee);
    }

    // ---------------------------------------------------------------------------
    // Operator controls
    // ---------------------------------------------------------------------------
    function setFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint256 old = transactionFee;
        transactionFee = newFee;
        emit FeeUpdated(old, newFee);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    // ---------------------------------------------------------------------------
    // Owner controls
    // ---------------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ---------------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------------
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function isListingActive(uint256 listingId) external view returns (bool) {
        Listing storage l = listings[listingId];
        return l.active && block.timestamp <= l.expiry && l.quantityRemaining > 0;
    }

    function getActiveListings() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            Listing storage l = listings[i];
            if (l.active && block.timestamp <= l.expiry && l.quantityRemaining > 0) {
                count++;
            }
        }
        uint256[] memory active = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            Listing storage l = listings[i];
            if (l.active && block.timestamp <= l.expiry && l.quantityRemaining > 0) {
                active[idx++] = i;
            }
        }
        return active;
    }

    function getItems() external view returns (uint256[] memory) {
        return allItems;
    }

    function balanceOf(address player, uint256 itemId) external view returns (uint256) {
        return itemBalances[player][itemId];
    }

    function nativeBalanceOf(address player) external view returns (uint256) {
        return nativeBalances[player];
    }

    function totalItemSupply(uint256 itemId) external view returns (uint256) {
        return itemTotalSupply[itemId];
    }

    function itemExists(uint256 itemId) external view returns (bool) {
        return itemInfo[itemId].exists;
    }

    function itemName(uint256 itemId) external view returns (string memory) {
        return itemInfo[itemId].name;
    }
}
