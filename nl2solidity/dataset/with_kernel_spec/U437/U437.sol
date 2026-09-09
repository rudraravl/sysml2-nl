// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
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

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title NFTMarketplace
 * @notice A peer-to-peer marketplace for trading NFTs from operator-approved
 *         ERC721 collections. Listed NFTs are held in escrow by the contract
 *         for the lifetime of the listing. Each listing tracks a single
 *         highest bid that may be accepted by the seller, outbid, or
 *         withdrawn by the bidder. A flat 0.02 ether fee is taken from the
 *         sale proceeds on every successful acceptance.
 */
contract NFTMarketplace is ReentrancyGuard, IERC721Receiver {
    // --------- Custom errors ---------
    error NotOperator();
    error NotSeller();
    error NotBidder();
    error SellerCannotBid();
    error CollectionNotApproved();
    error CollectionAlreadyApproved();
    error CollectionNotApprovedForRemoval();
    error AlreadyListed();
    error NotListed();
    error ListingExpired();
    error ListingStillActive();
    error PriceTooLow();
    error BidTooLow();
    error NoActiveBid();
    error MaxListingsReached();
    error ZeroAddress();
    error TransferFailed();
    error NotNFTOwner();
    error InvalidAmount();

    // --------- Events ---------
    event CollectionApproved(address indexed collection, bool approved);
    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed collection,
        uint256 tokenId,
        uint256 price,
        uint256 expiresAt
    );
    event OfferMade(
        uint256 indexed listingId,
        address indexed bidder,
        address indexed collection,
        uint256 tokenId,
        uint256 amount
    );
    event OfferAccepted(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer,
        address collection,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );
    event ListingCanceled(
        uint256 indexed listingId,
        address indexed seller,
        address indexed collection,
        uint256 tokenId
    );
    event NFTWithdrawn(
        uint256 indexed listingId,
        address indexed seller,
        address indexed collection,
        uint256 tokenId
    );
    event OfferWithdrawn(
        uint256 indexed listingId,
        address indexed bidder,
        uint256 amount
    );
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeWithdrawn(address indexed to, uint256 amount);

    // --------- Constants ---------
    uint256 public constant LISTING_FEE = 0.02 ether;
    uint256 public constant MAX_LISTINGS_PER_SELLER = 100;

    // --------- Structs ---------
    struct Listing {
        address seller;
        address collection;
        uint256 tokenId;
        uint256 price;
        uint256 expiresAt;
        bool active;
    }

    struct Bid {
        address bidder;
        uint256 amount;
    }

    // --------- State ---------
    address public operator;
    mapping(address => bool) public approvedCollections;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Bid) public bids;
    mapping(address => uint256) public activeListingsCount;
    mapping(address => mapping(uint256 => uint256)) public listingIdOf;
    uint256 public nextListingId;
    uint256 public accumulatedFees;

    // --------- Modifiers ---------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // --------- Constructor ---------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(address(0), _operator);
    }

    // --------- Operator functions ---------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function approveCollection(address collection) external onlyOperator {
        if (collection == address(0)) revert ZeroAddress();
        if (approvedCollections[collection]) revert CollectionAlreadyApproved();
        approvedCollections[collection] = true;
        emit CollectionApproved(collection, true);
    }

    function removeCollection(address collection) external onlyOperator {
        if (!approvedCollections[collection]) revert CollectionNotApprovedForRemoval();
        approvedCollections[collection] = false;
        emit CollectionApproved(collection, false);
    }

    // --------- Listing functions ---------
    function listNFT(
        address collection,
        uint256 tokenId,
        uint256 price,
        uint256 expiresAt
    ) external nonReentrant returns (uint256 listingId) {
        if (collection == address(0)) revert ZeroAddress();
        if (!approvedCollections[collection]) revert CollectionNotApproved();
        if (price <= LISTING_FEE) revert PriceTooLow();
        if (expiresAt <= block.timestamp) revert ListingExpired();
        if (listingIdOf[collection][tokenId] != 0) revert AlreadyListed();
        if (activeListingsCount[msg.sender] >= MAX_LISTINGS_PER_SELLER) revert MaxListingsReached();

        IERC721 nft = IERC721(collection);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        // Effects
        listingId = ++nextListingId;
        listings[listingId] = Listing({
            seller: msg.sender,
            collection: collection,
            tokenId: tokenId,
            price: price,
            expiresAt: expiresAt,
            active: true
        });
        listingIdOf[collection][tokenId] = listingId;
        activeListingsCount[msg.sender] += 1;

        // Interaction: pull NFT into escrow
        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit NFTListed(listingId, msg.sender, collection, tokenId, price, expiresAt);
    }

    function makeOffer(uint256 listingId) external payable nonReentrant returns (uint256) {
        if (msg.value == 0) revert InvalidAmount();
        Listing storage listing = listings[listingId];
        if (!listing.active) revert NotListed();
        if (block.timestamp > listing.expiresAt) revert ListingExpired();
        if (msg.sender == listing.seller) revert SellerCannotBid();

        Bid storage current = bids[listingId];
        uint256 minOffer = current.amount > listing.price ? current.amount : listing.price;
        if (msg.value <= minOffer) revert BidTooLow();

        address prevBidder = current.bidder;
        uint256 prevAmount = current.amount;

        // Effects: replace highest bid
        bids[listingId] = Bid({bidder: msg.sender, amount: msg.value});

        // Interaction: refund previous highest bidder
        if (prevBidder != address(0) && prevAmount > 0) {
            (bool ok, ) = payable(prevBidder).call{value: prevAmount}("");
            if (!ok) revert TransferFailed();
        }

        emit OfferMade(listingId, msg.sender, listing.collection, listing.tokenId, msg.value);
        return msg.value;
    }

    function withdrawOffer(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert NotListed();

        Bid storage bid = bids[listingId];
        if (bid.bidder != msg.sender) revert NotBidder();

        address bidder = bid.bidder;
        uint256 amount = bid.amount;

        // Effects
        bids[listingId] = Bid({bidder: address(0), amount: 0});

        // Interaction
        (bool ok, ) = payable(bidder).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit OfferWithdrawn(listingId, bidder, amount);
    }

    function acceptOffer(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert NotListed();
        if (listing.seller != msg.sender) revert NotSeller();
        if (block.timestamp > listing.expiresAt) revert ListingExpired();

        Bid storage bid = bids[listingId];
        if (bid.bidder == address(0) || bid.amount == 0) revert NoActiveBid();

        address seller = listing.seller;
        address buyer = bid.bidder;
        address collection = listing.collection;
        uint256 tokenId = listing.tokenId;
        uint256 salePrice = bid.amount;
        uint256 fee = LISTING_FEE;
        if (salePrice <= fee) revert PriceTooLow();
        uint256 sellerProceeds = salePrice - fee;

        // Effects
        listing.active = false;
        listingIdOf[collection][tokenId] = 0;
        activeListingsCount[seller] -= 1;
        bids[listingId] = Bid({bidder: address(0), amount: 0});
        accumulatedFees += fee;

        // Interactions
        IERC721(collection).safeTransferFrom(address(this), buyer, tokenId);
        (bool okSeller, ) = payable(seller).call{value: sellerProceeds}("");
        if (!okSeller) revert TransferFailed();

        emit OfferAccepted(listingId, seller, buyer, collection, tokenId, salePrice, fee);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert NotListed();
        if (listing.seller != msg.sender) revert NotSeller();

        address seller = listing.seller;
        address collection = listing.collection;
        uint256 tokenId = listing.tokenId;

        _closeListing(listingId, seller, collection, tokenId);
        emit ListingCanceled(listingId, seller, collection, tokenId);
    }

    function withdrawNFT(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert NotListed();
        if (listing.seller != msg.sender) revert NotSeller();
        if (block.timestamp <= listing.expiresAt) revert ListingStillActive();

        address seller = listing.seller;
        address collection = listing.collection;
        uint256 tokenId = listing.tokenId;

        _closeListing(listingId, seller, collection, tokenId);
        emit NFTWithdrawn(listingId, seller, collection, tokenId);
    }

    function _closeListing(
        uint256 listingId,
        address seller,
        address collection,
        uint256 tokenId
    ) internal {
        Bid storage bid = bids[listingId];
        address bidder = bid.bidder;
        uint256 refund = bid.amount;

        // Effects
        listings[listingId].active = false;
        listingIdOf[collection][tokenId] = 0;
        activeListingsCount[seller] -= 1;
        bids[listingId] = Bid({bidder: address(0), amount: 0});

        // Interactions: refund any outstanding bid
        if (bidder != address(0) && refund > 0) {
            (bool ok, ) = payable(bidder).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }

        // Return NFT to seller
        IERC721(collection).safeTransferFrom(address(this), seller, tokenId);
    }

    // --------- Fee withdrawal ---------
    function withdrawFees(address payable to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert InvalidAmount();

        // Effects
        accumulatedFees = 0;

        // Interaction
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit FeeWithdrawn(to, amount);
    }

    // --------- View functions ---------
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getBid(uint256 listingId) external view returns (Bid memory) {
        return bids[listingId];
    }

    function isCollectionApproved(address collection) external view returns (bool) {
        return approvedCollections[collection];
    }

    function getActiveListingCount(address seller) external view returns (uint256) {
        return activeListingsCount[seller];
    }

    // --------- ERC721 Receiver ---------
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
