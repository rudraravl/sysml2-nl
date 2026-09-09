// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract NFTMarketplace {
    // ──────────────────────────── Errors ────────────────────────────
    error NotOwner();
    error NotAuthorized();
    error NotSeller();
    error ListingNotFound();
    error AlreadyListed();
    error TokenNotApproved();
    error IncorrectPayment();
    error InsufficientBalance();
    error MarketplacePaused();
    error InvalidPrice();
    error ZeroAddress();
    error InvalidFeeBps();
    error ReentrantCall();
    error NFTContractNotAllowed();
    error SelfPurchase();
    error WithdrawalFailed();

    // ──────────────────────────── Events ────────────────────────────
    event Listed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event Purchased(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 fee
    );
    event Canceled(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorSet(address indexed operator, bool status);
    event PausedStateChanged(bool paused);
    event Withdrawal(address indexed account, uint256 amount);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event NFTContractAllowed(address indexed nftContract, bool allowed);

    // ─────────────────────────── Constants ─────────────────────────
    uint256 public constant MAX_FEE_BPS = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 250; // 2.5%

    // ──────────────────────────── Storage ──────────────────────────
    address public owner;
    uint256 public marketplaceFeeBps;
    bool public isPaused;
    uint256 public accumulatedFees;
    uint256 public listingCount;
    uint256 private _locked;

    struct Listing {
        address nftContract;
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(address => mapping(uint256 => uint256)) internal _tokenToListingId;
    mapping(address => uint256) public balances;
    mapping(address => bool) public operators;
    mapping(address => bool) public allowedNFTContracts;

    // ─────────────────────────── Modifiers ─────────────────────────
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != owner && !operators[msg.sender]) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (isPaused) revert MarketplacePaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    // ─────────────────────────── Constructor ────────────────────────
    constructor() {
        owner = msg.sender;
        marketplaceFeeBps = DEFAULT_FEE_BPS;
        operators[msg.sender] = true;
        emit OperatorSet(msg.sender, true);
        emit FeeUpdated(0, DEFAULT_FEE_BPS);
    }

    // ──────────────────────────── Admin ─────────────────────────────
    function setMarketplaceFee(uint256 feeBps) external onlyOwner {
        if (feeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        uint256 oldFee = marketplaceFeeBps;
        marketplaceFeeBps = feeBps;
        emit FeeUpdated(oldFee, feeBps);
    }

    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = status;
        emit OperatorSet(operator, status);
    }

    function setPaused(bool paused) external onlyOperator {
        isPaused = paused;
        emit PausedStateChanged(paused);
    }

    function setNFTContractAllowed(address nftContract, bool allowed) external onlyOwner {
        if (nftContract == address(0)) revert ZeroAddress();
        allowedNFTContracts[nftContract] = allowed;
        emit NFTContractAllowed(nftContract, allowed);
    }

    function withdrawFees(address payable recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert InsufficientBalance();
        accumulatedFees = 0;
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert WithdrawalFailed();
        emit FeesWithdrawn(recipient, amount);
    }

    // ────────────────────────── Marketplace ────────────────────────
    function list(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (!allowedNFTContracts[nftContract]) revert NFTContractNotAllowed();
        if (price == 0) revert InvalidPrice();
        if (_tokenToListingId[nftContract][tokenId] != 0) revert AlreadyListed();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotAuthorized();

        bool isApproved = nft.getApproved(tokenId) == address(this) ||
            nft.isApprovedForAll(msg.sender, address(this));
        if (!isApproved) revert TokenNotApproved();

        // Effects before interactions
        listingId = ++listingCount;
        listings[listingId] = Listing({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true
        });
        _tokenToListingId[nftContract][tokenId] = listingId;

        // Interaction: take custody of the token
        nft.transferFrom(msg.sender, address(this), tokenId);

        emit Listed(nftContract, tokenId, msg.sender, price);
    }

    function purchase(uint256 listingId) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotFound();
        if (msg.value != listing.price) revert IncorrectPayment();
        if (listing.seller == msg.sender) revert SelfPurchase();

        uint256 fee = (listing.price * marketplaceFeeBps) / MAX_FEE_BPS;
        uint256 sellerProceeds = listing.price - fee;

        address seller = listing.seller;
        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;
        uint256 price = listing.price;

        // Effects
        listing.active = false;
        _tokenToListingId[nftContract][tokenId] = 0;
        balances[seller] += sellerProceeds;
        accumulatedFees += fee;

        // Interactions
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit Purchased(nftContract, tokenId, msg.sender, seller, price, fee);
    }

    function cancelListing(uint256 listingId) external whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotFound();
        if (listing.seller != msg.sender) revert NotSeller();

        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;
        address seller = listing.seller;

        // Effects
        listing.active = false;
        _tokenToListingId[nftContract][tokenId] = 0;

        // Interactions — return NFT to seller
        IERC721(nftContract).transferFrom(address(this), seller, tokenId);

        emit Canceled(nftContract, tokenId, seller);
    }

    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert InsufficientBalance();

        // Effects
        balances[msg.sender] = 0;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit Withdrawal(msg.sender, amount);
    }

    // ───────────────────────────── Views ────────────────────────────
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getListingIdByToken(address nftContract, uint256 tokenId) external view returns (uint256) {
        return _tokenToListingId[nftContract][tokenId];
    }

    function isTokenListed(address nftContract, uint256 tokenId) external view returns (bool) {
        uint256 id = _tokenToListingId[nftContract][tokenId];
        return id != 0 && listings[id].active;
    }

    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
