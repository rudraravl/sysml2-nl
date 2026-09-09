// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract NFTMarketplaceEscrow {
    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error ContractPaused();
    error ContractNotPaused();
    error ZeroAddress();
    error NotNftOwner();
    error NotApprovedToEscrow();
    error InvalidPrice();
    error InsufficientPayment();
    error InvalidFee();
    error ListingNotActive();
    error ListingExpired();
    error NotSeller();
    error NothingToWithdraw();
    error InsufficientBalance();
    error TransferFailed();
    error ReentrantCall();
    error InvalidRecipient();
    error DirectDepositNotAllowed();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 expiresAt
    );
    event ListingCanceled(uint256 indexed listingId, address indexed seller);
    event NFTPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesClaimed(address indexed operator, address indexed recipient, uint256 amount);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Constants & storage
    // ---------------------------------------------------------------------
    uint256 public constant MAX_FEE_BPS = 1000; // 10% hard cap
    uint256 public constant LISTING_DURATION = 30 days;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant INITIAL_FEE_BPS = 250; // 2.5%

    address public operator;
    bool public paused;
    uint256 public platformFeeBps;
    uint256 public accumulatedFees;
    uint256 public nextListingId;

    uint256 private _locked = 1;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 expiresAt;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(address => uint256) public balances;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractNotPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        platformFeeBps = INITIAL_FEE_BPS;
    }

    // ---------------------------------------------------------------------
    // Native currency escrow: deposit / withdraw
    // ---------------------------------------------------------------------
    function deposit() external payable whenNotPaused {
        if (msg.value == 0) revert InvalidPrice();
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert NothingToWithdraw();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Listing flow
    // ---------------------------------------------------------------------
    function list(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotNftOwner();
        if (
            nft.getApproved(tokenId) != address(this) &&
            !nft.isApprovedForAll(msg.sender, address(this))
        ) revert NotApprovedToEscrow();

        uint256 expiresAt = block.timestamp + LISTING_DURATION;
        listingId = nextListingId++;

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            expiresAt: expiresAt,
            active: true
        });

        nft.transferFrom(msg.sender, address(this), tokenId);

        emit NFTListed(listingId, msg.sender, nftContract, tokenId, price, expiresAt);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotSeller();

        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;
        listing.active = false;

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit ListingCanceled(listingId, msg.sender);
    }

    function purchase(uint256 listingId) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (block.timestamp > listing.expiresAt) revert ListingExpired();
        if (msg.value != listing.price) revert InsufficientPayment();

        address seller = listing.seller;
        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;
        uint256 price = listing.price;

        listing.active = false;

        uint256 fee = (price * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = price - fee;

        balances[seller] += sellerProceeds;
        accumulatedFees += fee;

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit NFTPurchased(listingId, msg.sender, seller, nftContract, tokenId, price, fee);
    }

    // ---------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setPlatformFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 old = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(old, newFeeBps);
    }

    function claimFees(address recipient) external onlyOperator nonReentrant {
        if (recipient == address(0)) revert InvalidRecipient();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool success, ) = payable(recipient).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FeesClaimed(msg.sender, recipient, amount);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorTransferred(previous, newOperator);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function isListingActive(uint256 listingId) external view returns (bool) {
        Listing storage listing = listings[listingId];
        return listing.active && block.timestamp <= listing.expiresAt;
    }

    function computeFee(uint256 price) external view returns (uint256) {
        return (price * platformFeeBps) / BPS_DENOMINATOR;
    }

    receive() external payable {
        revert DirectDepositNotAllowed();
    }
}
