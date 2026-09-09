// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
}

/**
 * @title NFTMarketplace
 * @notice Multi-chain NFT marketplace and aggregator that facilitates the
 *         atomic exchange of non-fungible tokens for ETH. The contract never
 *         custodies NFT inventory; it coordinates transfers directly between
 *         sellers and buyers using the ERC-721 approval mechanism. Offer ETH
 *         is escrowed only for the lifetime of an active offer.
 */
contract NFTMarketplace {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error NotAuthorized();
    error ReentrantCall();
    error MarketplacePaused();
    error PriceTooLow();
    error FeeTooHigh();
    error InsufficientPayment();
    error NotTokenOwner();
    error NotApproved();
    error ListingNotActive();
    error OfferNotActive();
    error NotOfferTarget();
    error CannotBuyOwnListing();
    error CannotOfferOnOwnNFT();
    error NothingToWithdraw();
    error ETHTransferFailed();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 chainId
    );

    event NFTSold(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 fee,
        uint256 chainId
    );

    event ListingCancelled(
        uint256 indexed listingId,
        address indexed seller,
        address nftContract,
        uint256 tokenId
    );

    event OfferMade(
        uint256 indexed offerId,
        address indexed buyer,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 chainId
    );

    event OfferAccepted(
        uint256 indexed offerId,
        address indexed seller,
        address indexed buyer,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 fee,
        uint256 chainId
    );

    event OfferCancelled(uint256 indexed offerId, address indexed buyer, uint256 refund);

    event FeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event OperatorUpdated(address indexed newOperator);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event FeesWithdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_PRICE = 0.001 ether;
    uint256 public constant MAX_FEE_BPS = 500; // 5% cap
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5%

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public operator;
    address public feeRecipient;
    bool public paused;

    uint256 public feeBps;
    uint256 public accumulatedFees;

    uint256 private _nextListingId = 1;
    uint256 private _nextOfferId = 1;

    // Reentrancy guard state.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 chainId;
        bool active;
    }

    struct Offer {
        address buyer;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 chainId;
        bool active;
    }

    struct UserStats {
        uint256 totalListings;
        uint256 totalSales;
        uint256 totalPurchases;
        uint256 totalVolume;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer) public offers;
    mapping(address => UserStats) public userStats;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert MarketplacePaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        feeBps = DEFAULT_FEE_BPS;
        emit FeeUpdated(DEFAULT_FEE_BPS);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    function setFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function withdrawFees() external onlyOperator {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        _safeTransferETH(feeRecipient, amount);
        emit FeesWithdrawn(feeRecipient, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            LISTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price < MIN_PRICE) revert PriceTooLow();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (!_isApproved(nft, msg.sender, tokenId)) revert NotApproved();

        listingId = _nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            chainId: block.chainid,
            active: true
        });

        userStats[msg.sender].totalListings += 1;

        emit NFTListed(listingId, msg.sender, nftContract, tokenId, price, block.chainid);
    }

    function buyNFT(uint256 listingId) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();

        address seller = listing.seller;
        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;
        uint256 price = listing.price;
        uint256 chainId = listing.chainId;

        if (msg.sender == seller) revert CannotBuyOwnListing();
        if (msg.value != price) revert InsufficientPayment();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != seller) revert NotTokenOwner();
        if (!_isApproved(nft, seller, tokenId)) revert NotApproved();

        uint256 fee = (price * feeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = price - fee;

        // Effects
        listing.active = false;
        userStats[seller].totalSales += 1;
        userStats[seller].totalVolume += price;
        userStats[msg.sender].totalPurchases += 1;
        userStats[msg.sender].totalVolume += price;
        accumulatedFees += fee;

        // Interactions
        nft.transferFrom(seller, msg.sender, tokenId);
        _safeTransferETH(seller, sellerProceeds);

        emit NFTSold(listingId, seller, msg.sender, nftContract, tokenId, price, fee, chainId);
    }

    function cancelListing(uint256 listingId) external whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotAuthorized();

        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;

        listing.active = false;

        emit ListingCancelled(listingId, msg.sender, nftContract, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                             OFFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function makeOffer(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external payable whenNotPaused nonReentrant returns (uint256 offerId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price < MIN_PRICE) revert PriceTooLow();
        if (msg.value != price) revert InsufficientPayment();

        IERC721 nft = IERC721(nftContract);
        address currentOwner = nft.ownerOf(tokenId);
        if (currentOwner == msg.sender) revert CannotOfferOnOwnNFT();

        offerId = _nextOfferId++;
        offers[offerId] = Offer({
            buyer: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            chainId: block.chainid,
            active: true
        });

        emit OfferMade(offerId, msg.sender, nftContract, tokenId, price, block.chainid);
    }

    function acceptOffer(uint256 offerId) external whenNotPaused nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();

        address buyer = offer.buyer;
        address nftContract = offer.nftContract;
        uint256 tokenId = offer.tokenId;
        uint256 price = offer.price;
        uint256 chainId = offer.chainId;

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOfferTarget();
        if (!_isApproved(nft, msg.sender, tokenId)) revert NotApproved();

        uint256 fee = (price * feeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = price - fee;

        // Effects
        offer.active = false;
        userStats[msg.sender].totalSales += 1;
        userStats[msg.sender].totalVolume += price;
        userStats[buyer].totalPurchases += 1;
        userStats[buyer].totalVolume += price;
        accumulatedFees += fee;

        // Interactions
        nft.transferFrom(msg.sender, buyer, tokenId);
        _safeTransferETH(msg.sender, sellerProceeds);

        emit OfferAccepted(offerId, msg.sender, buyer, nftContract, tokenId, price, fee, chainId);
    }

    function cancelOffer(uint256 offerId) external whenNotPaused nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (offer.buyer != msg.sender) revert NotAuthorized();

        uint256 refund = offer.price;
        offer.active = false;

        _safeTransferETH(msg.sender, refund);

        emit OfferCancelled(offerId, msg.sender, refund);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    function getUserStats(address user) external view returns (UserStats memory) {
        return userStats[user];
    }

    function nextListingId() external view returns (uint256) {
        return _nextListingId;
    }

    function nextOfferId() external view returns (uint256) {
        return _nextOfferId;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _isApproved(
        IERC721 nft,
        address owner,
        uint256 tokenId
    ) internal view returns (bool) {
        return
            nft.isApprovedForAll(owner, address(this)) ||
            nft.getApproved(tokenId) == address(this);
    }

    function _safeTransferETH(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert ETHTransferFailed();
    }
}
