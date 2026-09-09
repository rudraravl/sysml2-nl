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

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

abstract contract ReentrancyGuard {
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

contract NFTMarketplace is ReentrancyGuard {
    error ZeroAddress();
    error NotOperator();
    error Paused();
    error InvalidFee();
    error InvalidPrice();
    error InvalidAmount();
    error InsufficientBalance();
    error NotNFTOwner();
    error NftAlreadyDeposited();
    error NftNotDeposited();
    error NotListed();
    error ListingNotActive();
    error NotOffered();
    error OfferNotPending();
    error OfferExpired();
    error NotSeller();
    error NotBuyer();
    error NotAuthorized();
    error CannotOfferOnOwnListing();
    error NftCurrentlyListed();
    error TransferFailed();

    event TokensDeposited(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);
    event NftDeposited(address indexed user, address indexed nftContract, uint256 indexed tokenId);
    event NftWithdrawn(address indexed user, address indexed nftContract, uint256 indexed tokenId);
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );
    event ListingCancelled(uint256 indexed listingId);
    event OfferCreated(
        uint256 indexed offerId,
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price,
        uint256 deadline
    );
    event OfferAccepted(
        uint256 indexed offerId,
        uint256 indexed listingId,
        address buyer,
        address seller,
        uint256 price,
        uint256 fee
    );
    event OfferCancelled(uint256 indexed offerId);
    event FeeUpdated(uint256 newFeeBps);
    event OperatorUpdated(address newOperator);
    event PausedStateChanged(bool paused);

    uint256 public constant MAX_FEE_BPS = 250;
    uint256 public constant OFFER_DURATION = 24 hours;

    IERC20 public immutable marketToken;
    address public operator;
    uint256 public feeBps;
    bool public paused;

    uint256 public nextListingId = 1;
    uint256 public nextOfferId = 1;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    enum OfferStatus {
        Pending,
        Accepted,
        Cancelled
    }

    struct Offer {
        uint256 listingId;
        address buyer;
        uint256 price;
        uint256 deadline;
        OfferStatus status;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer) public offers;
    mapping(address => uint256) public tokenBalances;
    mapping(address => mapping(uint256 => address)) public nftDepositors;
    mapping(address => mapping(uint256 => uint256)) internal _activeListingForNft;
    mapping(uint256 => uint256[]) internal _listingOffers;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(address _marketToken, address _operator, uint256 _feeBps) {
        if (_marketToken == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert InvalidFee();
        marketToken = IERC20(_marketToken);
        operator = _operator;
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert InvalidFee();
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        operator = _newOperator;
        emit OperatorUpdated(_newOperator);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function depositTokens(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        uint256 before = marketToken.balanceOf(address(this));
        bool ok = marketToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        uint256 received = marketToken.balanceOf(address(this)) - before;
        tokenBalances[msg.sender] += received;
        emit TokensDeposited(msg.sender, received);
    }

    function withdrawTokens(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (tokenBalances[msg.sender] < amount) revert InsufficientBalance();
        tokenBalances[msg.sender] -= amount;
        bool ok = marketToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit TokensWithdrawn(msg.sender, amount);
    }

    function depositNft(address nftContract, uint256 tokenId) external whenNotPaused nonReentrant {
        if (nftContract == address(0)) revert ZeroAddress();
        if (nftDepositors[nftContract][tokenId] != address(0)) revert NftAlreadyDeposited();
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        nftDepositors[nftContract][tokenId] = msg.sender;
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        emit NftDeposited(msg.sender, nftContract, tokenId);
    }

    function withdrawNft(address nftContract, uint256 tokenId) external nonReentrant {
        if (nftDepositors[nftContract][tokenId] != msg.sender) revert NotNFTOwner();
        if (_activeListingForNft[nftContract][tokenId] != 0) revert NftCurrentlyListed();

        nftDepositors[nftContract][tokenId] = address(0);
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        emit NftWithdrawn(msg.sender, nftContract, tokenId);
    }

    function createListing(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        if (nftDepositors[nftContract][tokenId] != msg.sender) revert NotNFTOwner();
        if (price == 0) revert InvalidPrice();
        if (_activeListingForNft[nftContract][tokenId] != 0) revert NftCurrentlyListed();

        listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });
        _activeListingForNft[nftContract][tokenId] = listingId;

        emit ListingCreated(listingId, msg.sender, nftContract, tokenId, price);
    }

    function cancelListing(uint256 listingId) external whenNotPaused nonReentrant {
        Listing storage l = listings[listingId];
        if (l.seller == address(0)) revert NotListed();
        if (l.seller != msg.sender) revert NotSeller();
        if (!l.active) revert ListingNotActive();

        l.active = false;
        _activeListingForNft[l.nftContract][l.tokenId] = 0;

        uint256[] storage offerIds = _listingOffers[listingId];
        for (uint256 i = 0; i < offerIds.length; i++) {
            Offer storage o = offers[offerIds[i]];
            if (o.status == OfferStatus.Pending) {
                o.status = OfferStatus.Cancelled;
                tokenBalances[o.buyer] += o.price;
                emit OfferCancelled(offerIds[i]);
            }
        }

        emit ListingCancelled(listingId);
    }

    function makeOffer(
        uint256 listingId,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256 offerId) {
        Listing storage l = listings[listingId];
        if (l.seller == address(0)) revert NotListed();
        if (!l.active) revert ListingNotActive();
        if (price == 0) revert InvalidPrice();
        if (msg.sender == l.seller) revert CannotOfferOnOwnListing();
        if (tokenBalances[msg.sender] < price) revert InsufficientBalance();

        tokenBalances[msg.sender] -= price;

        offerId = nextOfferId++;
        uint256 deadline = block.timestamp + OFFER_DURATION;
        offers[offerId] = Offer({
            listingId: listingId,
            buyer: msg.sender,
            price: price,
            deadline: deadline,
            status: OfferStatus.Pending
        });
        _listingOffers[listingId].push(offerId);

        emit OfferCreated(offerId, listingId, msg.sender, price, deadline);
    }

    function acceptOffer(uint256 offerId) external whenNotPaused nonReentrant {
        Offer storage o = offers[offerId];
        if (o.buyer == address(0)) revert NotOffered();
        if (o.status != OfferStatus.Pending) revert OfferNotPending();
        if (block.timestamp > o.deadline) revert OfferExpired();

        Listing storage l = listings[o.listingId];
        if (l.seller != msg.sender) revert NotSeller();
        if (!l.active) revert ListingNotActive();

        o.status = OfferStatus.Accepted;
        l.active = false;
        _activeListingForNft[l.nftContract][l.tokenId] = 0;

        uint256 fee = (o.price * feeBps) / 10000;
        uint256 sellerProceeds = o.price - fee;

        tokenBalances[l.seller] += sellerProceeds;
        tokenBalances[operator] += fee;

        nftDepositors[l.nftContract][l.tokenId] = o.buyer;

        uint256[] storage offerIds = _listingOffers[o.listingId];
        for (uint256 i = 0; i < offerIds.length; i++) {
            uint256 otherId = offerIds[i];
            if (otherId != offerId) {
                Offer storage other = offers[otherId];
                if (other.status == OfferStatus.Pending) {
                    other.status = OfferStatus.Cancelled;
                    tokenBalances[other.buyer] += other.price;
                    emit OfferCancelled(otherId);
                }
            }
        }

        IERC721(l.nftContract).safeTransferFrom(address(this), o.buyer, l.tokenId);

        emit OfferAccepted(offerId, o.listingId, o.buyer, l.seller, o.price, fee);
    }

    function cancelOffer(uint256 offerId) external whenNotPaused nonReentrant {
        Offer storage o = offers[offerId];
        if (o.buyer == address(0)) revert NotOffered();
        if (o.status != OfferStatus.Pending) revert OfferNotPending();

        bool isBuyer = msg.sender == o.buyer;
        bool isSeller = msg.sender == listings[o.listingId].seller;
        if (!isBuyer && !(isSeller && block.timestamp > o.deadline)) {
            revert NotAuthorized();
        }

        o.status = OfferStatus.Cancelled;
        tokenBalances[o.buyer] += o.price;

        emit OfferCancelled(offerId);
    }

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    function getListingOffers(uint256 listingId) external view returns (uint256[] memory) {
        return _listingOffers[listingId];
    }

    function isNftDeposited(address nftContract, uint256 tokenId) external view returns (bool) {
        return nftDepositors[nftContract][tokenId] != address(0);
    }

    function getActiveListingForNft(address nftContract, uint256 tokenId) external view returns (uint256) {
        return _activeListingForNft[nftContract][tokenId];
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
