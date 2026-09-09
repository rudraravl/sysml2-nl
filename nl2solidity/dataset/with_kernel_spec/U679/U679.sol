// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract Pausable {
    bool public paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    function _pause() internal {
        if (paused) revert EnforcedPause();
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        if (!paused) revert ExpectedPause();
        paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title DigitalAssetMarketplace
 * @notice Decentralized marketplace for ERC721 digital assets with escrowed
 *         payments and a configurable platform fee.
 */
contract DigitalAssetMarketplace is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //---------------------------------------------------------------------------
    // Constants
    //---------------------------------------------------------------------------

    /// @notice Minimum listing price (0.01 payment tokens, assuming 18 decimals).
    uint256 public constant MIN_PRICE = 1e16;

    /// @notice Maximum platform fee in basis points (10%).
    uint256 public constant MAX_FEE_BPS = 1000;

    /// @notice Default platform fee in basis points (2.5%).
    uint256 public constant DEFAULT_FEE_BPS = 250;

    /// @notice Basis points denominator.
    uint256 private constant BPS_DENOMINATOR = 10000;

    //---------------------------------------------------------------------------
    // State
    //---------------------------------------------------------------------------

    IERC20 public immutable paymentToken;

    address public operator;

    /// @notice Platform fee in basis points. Settable by operator.
    uint256 public platformFeeBps;

    /// @notice Total fees accrued and available for withdrawal.
    uint256 public totalFeesCollected;

    uint256 public nextListingId = 1;
    uint256 public nextOfferId = 1;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    struct Offer {
        uint256 listingId;
        address buyer;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer) public offers;
    mapping(uint256 => uint256[]) public listingOfferIds;

    /// @notice Accumulated, withdrawable proceeds for each seller (net of fees).
    mapping(address => uint256) public sellerProceeds;

    //---------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------

    event AssetListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );
    event OfferMade(
        uint256 indexed offerId,
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price
    );
    event OfferAccepted(
        uint256 indexed offerId,
        uint256 indexed listingId,
        address indexed seller,
        address buyer,
        uint256 price,
        uint256 fee
    );
    event SaleCompleted(
        uint256 indexed listingId,
        address indexed seller,
        address buyer,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );
    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event OfferCancelled(uint256 indexed offerId, address indexed buyer);
    event ProceedsWithdrawn(address indexed seller, uint256 amount);
    event FeesWithdrawn(address indexed operator, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    //---------------------------------------------------------------------------
    // Errors
    //---------------------------------------------------------------------------

    error PriceBelowMinimum();
    error InvalidPrice();
    error NotSeller();
    error NotBuyer();
    error NotOperator();
    error ListingNotActive();
    error OfferNotActive();
    error InsufficientProceeds();
    error FeeTooHigh();
    error NothingToWithdraw();
    error NotAssetOwner();
    error NotApproved();
    error AssetNotHeld();

    //---------------------------------------------------------------------------
    // Modifiers
    //---------------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    //---------------------------------------------------------------------------
    // Constructor
    //---------------------------------------------------------------------------

    constructor(address _paymentToken, address _operator) Ownable(msg.sender) {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        paymentToken = IERC20(_paymentToken);
        operator = _operator;
        platformFeeBps = DEFAULT_FEE_BPS;

        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, DEFAULT_FEE_BPS);
    }

    //---------------------------------------------------------------------------
    // Admin / Operator
    //---------------------------------------------------------------------------

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setPlatformFeeBps(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeUpdated(platformFeeBps, _feeBps);
        platformFeeBps = _feeBps;
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    /// @notice Withdraw accrued platform fees to the operator.
    function withdrawFees() external onlyOperator nonReentrant {
        uint256 amount = totalFeesCollected;
        if (amount == 0) revert NothingToWithdraw();
        totalFeesCollected = 0;
        paymentToken.safeTransfer(operator, amount);
        emit FeesWithdrawn(operator, amount);
    }

    //---------------------------------------------------------------------------
    // Listing
    //---------------------------------------------------------------------------

    /**
     * @notice List an ERC721 asset for sale. The NFT is transferred into escrow.
     * @param nftContract  The ERC721 contract address.
     * @param tokenId      The token id to list.
     * @param price        The asking price in payment tokens (>= MIN_PRICE).
     * @return listingId   The id of the newly created listing.
     */
    function listAsset(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price < MIN_PRICE) revert PriceBelowMinimum();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotAssetOwner();
        if (
            !nft.isApprovedForAll(msg.sender, address(this)) &&
            nft.getApproved(tokenId) != address(this)
        ) revert NotApproved();

        listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        nft.transferFrom(msg.sender, address(this), tokenId);

        emit AssetListed(listingId, msg.sender, nftContract, tokenId, price);
    }

    /**
     * @notice Cancel an active listing and return the NFT to the seller.
     * @param listingId  The id of the listing to cancel.
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotSeller();

        listing.active = false;

        IERC721(listing.nftContract).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        emit ListingCancelled(listingId, msg.sender);
    }

    //---------------------------------------------------------------------------
    // Offers
    //---------------------------------------------------------------------------

    /**
     * @notice Make an offer on a listing by escrowing the offer amount.
     * @param listingId  The target listing id.
     * @param price      The offer price in payment tokens (must be > 0).
     * @return offerId   The id of the newly created offer.
     */
    function makeOffer(
        uint256 listingId,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256 offerId) {
        if (price == 0) revert InvalidPrice();

        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (msg.sender == listing.seller) revert NotBuyer();

        offerId = nextOfferId++;
        offers[offerId] = Offer({
            listingId: listingId,
            buyer: msg.sender,
            price: price,
            active: true
        });
        listingOfferIds[listingId].push(offerId);

        paymentToken.safeTransferFrom(msg.sender, address(this), price);

        emit OfferMade(offerId, listingId, msg.sender, price);
    }

    /**
     * @notice Accept an offer. The seller receives the offer amount net of the
     *         platform fee; the buyer receives the NFT. The listing and the
     *         accepted offer are marked inactive.
     * @param offerId  The id of the offer to accept.
     */
    function acceptOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();

        uint256 listingId = offer.listingId;
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotSeller();

        address buyer = offer.buyer;
        uint256 salePrice = offer.price;
        uint256 fee = (salePrice * platformFeeBps) / BPS_DENOMINATOR;
        uint256 proceeds = salePrice - fee;

        // Effects
        offer.active = false;
        listing.active = false;
        sellerProceeds[listing.seller] += proceeds;
        totalFeesCollected += fee;

        // Interactions
        IERC721(listing.nftContract).transferFrom(
            address(this),
            buyer,
            listing.tokenId
        );

        emit OfferAccepted(
            offerId,
            listingId,
            listing.seller,
            buyer,
            salePrice,
            fee
        );
        emit SaleCompleted(
            listingId,
            listing.seller,
            buyer,
            listing.nftContract,
            listing.tokenId,
            salePrice,
            fee
        );
    }

    /**
     * @notice Cancel an active offer and refund the escrowed payment to the buyer.
     * @param offerId  The id of the offer to cancel.
     */
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (offer.buyer != msg.sender) revert NotBuyer();

        offer.active = false;

        paymentToken.safeTransfer(msg.sender, offer.price);

        emit OfferCancelled(offerId, msg.sender);
    }

    //---------------------------------------------------------------------------
    // Withdrawals
    //---------------------------------------------------------------------------

    /**
     * @notice Withdraw accumulated sale proceeds (net of fees) by the seller.
     */
    function withdrawProceeds() external nonReentrant {
        uint256 amount = sellerProceeds[msg.sender];
        if (amount == 0) revert InsufficientProceeds();

        sellerProceeds[msg.sender] = 0;
        paymentToken.safeTransfer(msg.sender, amount);

        emit ProceedsWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Withdraw an ERC721 asset currently held by the marketplace that is
     *         not part of an active listing. Only the contract owner may reclaim
     *         stranded assets as a recovery mechanism.
     * @param nftContract  The ERC721 contract address.
     * @param tokenId      The token id to withdraw.
     */
    function withdrawAsset(address nftContract, uint256 tokenId) external nonReentrant {
        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != address(this)) revert AssetNotHeld();
        if (msg.sender != owner()) revert NotAssetOwner();

        nft.transferFrom(address(this), msg.sender, tokenId);
    }

    //---------------------------------------------------------------------------
    // Views
    //---------------------------------------------------------------------------

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    function getListingOfferIds(uint256 listingId) external view returns (uint256[] memory) {
        return listingOfferIds[listingId];
    }

    function getListingOfferCount(uint256 listingId) external view returns (uint256) {
        return listingOfferIds[listingId].length;
    }

    /**
     * @notice Compute the fee that would be charged for a given sale price.
     */
    function computeFee(uint256 salePrice) external view returns (uint256) {
        return (salePrice * platformFeeBps) / BPS_DENOMINATOR;
    }
}
