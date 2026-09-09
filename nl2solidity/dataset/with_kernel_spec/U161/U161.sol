// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
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
    address public owner;
    address public immutable nftContract;
    bool public paused;

    uint256 public constant LISTING_FEE = 0.01 ether;
    uint256 public constant MAX_LISTINGS_PER_ADDRESS = 10;

    uint256 public accumulatedFees;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) private _listings;
    mapping(address => uint256) private _activeListingCount;

    uint256 private _locked = 1;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 fee
    );
    event NFTListingCancelled(uint256 indexed tokenId, address indexed seller);
    event NFTPriceUpdated(uint256 indexed tokenId, address indexed seller, uint256 oldPrice, uint256 newPrice);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotSeller();
    error EnforcedPause();
    error ExpectedPause();
    error PriceTooLow();
    error InvalidPrice();
    error InsufficientPayment();
    error MaxListingsReached();
    error ZeroAddress();
    error TransferFailed();
    error NoFeesToWithdraw();
    error AlreadyListed();
    error NotListed();
    error ReentrantCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _nftContract) {
        if (_nftContract == address(0)) revert ZeroAddress();
        nftContract = _nftContract;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function listNFT(uint256 tokenId, uint256 price) external whenNotPaused nonReentrant {
        if (price < LISTING_FEE) revert PriceTooLow();
        if (_activeListingCount[msg.sender] >= MAX_LISTINGS_PER_ADDRESS) revert MaxListingsReached();
        if (_listings[tokenId].active) revert AlreadyListed();
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) revert NotSeller();

        // Effects before interactions to prevent cross-function reentrancy.
        _listings[tokenId] = Listing({seller: msg.sender, price: price, active: true});
        _activeListingCount[msg.sender]++;

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit NFTListed(tokenId, msg.sender, price);
    }

    function purchaseNFT(uint256 tokenId) external payable whenNotPaused nonReentrant {
        Listing storage listing = _listings[tokenId];
        if (!listing.active) revert NotListed();
        if (msg.value < listing.price) revert InsufficientPayment();

        address seller = listing.seller;
        uint256 price = listing.price;
        uint256 fee = LISTING_FEE;
        uint256 payout = price - fee;

        // Effects before interactions.
        listing.active = false;
        _activeListingCount[seller]--;
        accumulatedFees += fee;

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        (bool sent, ) = payable(seller).call{value: payout}("");
        if (!sent) revert TransferFailed();

        if (msg.value > price) {
            uint256 refund = msg.value - price;
            (bool refunded, ) = payable(msg.sender).call{value: refund}("");
            if (!refunded) revert TransferFailed();
        }

        emit NFTPurchased(tokenId, msg.sender, seller, price, fee);
    }

    function cancelListing(uint256 tokenId) external whenNotPaused nonReentrant {
        Listing storage listing = _listings[tokenId];
        if (!listing.active) revert NotListed();
        if (listing.seller != msg.sender) revert NotSeller();

        // Effects before interactions.
        listing.active = false;
        _activeListingCount[msg.sender]--;

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit NFTListingCancelled(tokenId, msg.sender);
    }

    function updatePrice(uint256 tokenId, uint256 newPrice) external whenNotPaused {
        Listing storage listing = _listings[tokenId];
        if (!listing.active) revert NotListed();
        if (listing.seller != msg.sender) revert NotSeller();
        if (newPrice < LISTING_FEE) revert PriceTooLow();
        if (newPrice == listing.price) revert InvalidPrice();

        uint256 oldPrice = listing.price;
        listing.price = newPrice;

        emit NFTPriceUpdated(tokenId, msg.sender, oldPrice, newPrice);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();
        accumulatedFees = 0;
        (bool sent, ) = payable(owner).call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit FeesWithdrawn(owner, amount);
    }

    function getListing(uint256 tokenId) external view returns (address seller, uint256 price, bool active) {
        Listing storage listing = _listings[tokenId];
        return (listing.seller, listing.price, listing.active);
    }

    function activeListingCount(address account) external view returns (uint256) {
        return _activeListingCount[account];
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
