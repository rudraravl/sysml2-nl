// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract VoteEscrowNFTMarketplace {
    uint256 public constant MAX_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_OFFER = 0.01 ether;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error NotListed();
    error AlreadyListed();
    error NotOwnerOfOffer();
    error OfferNotActive();
    error OfferBelowMinimum();
    error InvalidPrice();
    error NftTypeMismatch();
    error Paused();
    error FeeTooHigh();
    error TransferFailed();
    error ReentrancyDetected();

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    struct GlobalOffer {
        address buyer;
        address nftContract;
        uint256 price;
        bool active;
    }

    address public owner;
    uint256 public feeBps = MAX_FEE_BPS;
    bool public paused;

    mapping(address => bool) public operators;

    // nftContract => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    // offerId => GlobalOffer
    mapping(uint256 => GlobalOffer) public globalOffers;
    uint256 public nextOfferId = 1;

    uint256 private _reentrancyStatus;

    event OperatorUpdated(address indexed operator, bool status);
    event PausedStatus(bool paused);
    event FeeUpdated(uint256 newFeeBps);
    event NftListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NftUnlisted(address indexed nftContract, uint256 indexed tokenId, address indexed seller);
    event GlobalOfferMade(uint256 indexed offerId, address indexed buyer, address indexed nftContract, uint256 price);
    event OfferWithdrawn(uint256 indexed offerId, address indexed buyer, uint256 amount);
    event SaleCompleted(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price,
        uint256 fee
    );

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender] && msg.sender != owner) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus != 0) revert ReentrancyDetected();
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 0;
    }

    constructor() {
        owner = msg.sender;
        operators[msg.sender] = true;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = status;
        emit OperatorUpdated(operator, status);
    }

    function setPaused(bool status) external onlyOperator {
        paused = status;
        emit PausedStatus(status);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    function listNft(address nftContract, uint256 tokenId, uint256 price) external whenNotPaused nonReentrant {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        if (listings[nftContract][tokenId].active) revert AlreadyListed();

        // Effects: record listing before transferring the NFT
        listings[nftContract][tokenId] = Listing({seller: msg.sender, price: price, active: true});

        // Interactions
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit NftListed(nftContract, tokenId, msg.sender, price);
    }

    function withdrawNft(address nftContract, uint256 tokenId) external nonReentrant {
        Listing storage listing = listings[nftContract][tokenId];
        if (!listing.active) revert NotListed();
        if (listing.seller != msg.sender) revert NotOwner();

        // Effects
        listing.active = false;

        // Interactions
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit NftUnlisted(nftContract, tokenId, msg.sender);
    }

    function makeGlobalOffer(address nftContract) external payable whenNotPaused nonReentrant returns (uint256 offerId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (msg.value < MIN_OFFER) revert OfferBelowMinimum();

        offerId = nextOfferId++;
        globalOffers[offerId] = GlobalOffer({
            buyer: msg.sender,
            nftContract: nftContract,
            price: msg.value,
            active: true
        });

        emit GlobalOfferMade(offerId, msg.sender, nftContract, msg.value);
    }

    function withdrawOffer(uint256 offerId) external nonReentrant {
        GlobalOffer storage offer = globalOffers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (offer.buyer != msg.sender) revert NotOwnerOfOffer();

        // Effects
        uint256 amount = offer.price;
        offer.active = false;
        offer.price = 0;

        // Interactions
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit OfferWithdrawn(offerId, msg.sender, amount);
    }

    function acceptOffer(uint256 offerId, address nftContract, uint256 tokenId) external whenNotPaused nonReentrant {
        GlobalOffer storage offer = globalOffers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (offer.nftContract != nftContract) revert NftTypeMismatch();

        Listing storage listing = listings[nftContract][tokenId];
        if (!listing.active) revert NotListed();
        if (listing.seller != msg.sender) revert NotOwner();

        address seller = listing.seller;
        address buyer = offer.buyer;
        uint256 salePrice = offer.price;

        // Effects
        listing.active = false;
        offer.active = false;
        offer.price = 0;

        uint256 fee = (salePrice * feeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = salePrice - fee;

        // Interactions
        IERC721(nftContract).transferFrom(address(this), buyer, tokenId);

        if (fee > 0) {
            (bool feeOk, ) = payable(owner).call{value: fee}("");
            if (!feeOk) revert TransferFailed();
        }
        (bool payOk, ) = payable(seller).call{value: sellerProceeds}("");
        if (!payOk) revert TransferFailed();

        emit SaleCompleted(nftContract, tokenId, seller, buyer, salePrice, fee);
    }

    function getListing(address nftContract, uint256 tokenId) external view returns (Listing memory) {
        return listings[nftContract][tokenId];
    }

    function getGlobalOffer(uint256 offerId) external view returns (GlobalOffer memory) {
        return globalOffers[offerId];
    }
}
