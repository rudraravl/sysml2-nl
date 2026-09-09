// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTMarketplace {
    uint256 public constant PLATFORM_FEE_BPS = 200; // 2%
    uint256 public constant MAX_ROYALTY_LIMIT_BPS = 1000; // 10%

    address public admin;
    uint256 public listingFee;
    uint256 public maxRoyaltyBps = 1000;

    uint256 private _nextTokenId = 1;
    uint256 public totalSupply;

    struct Listing {
        address owner;
        uint256 price;
        bool isListed;
    }

    mapping(uint256 => address) private _ownerOf;
    mapping(uint256 => address) private _creatorOf;
    mapping(uint256 => uint256) private _royaltyBps;
    mapping(uint256 => string) private _tokenURI;
    mapping(uint256 => bool) private _tokenExists;
    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => Listing) private _listings;

    event NFTMinted(uint256 indexed tokenId, address indexed creator, uint256 royaltyBps, string tokenURI);
    event NFTListed(uint256 indexed tokenId, address indexed owner, uint256 price, uint256 feePaid);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price, uint256 platformFee, uint256 royalty);
    event NFTDelisted(uint256 indexed tokenId, address indexed owner);
    event OwnershipTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event ListingFeeUpdated(uint256 oldFee, uint256 newFee);
    event MaxRoyaltyUpdated(uint256 oldMaxBps, uint256 newMaxBps);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    error NotAdmin();
    error ZeroAddress();
    error TokenDoesNotExist();
    error NotTokenOwner();
    error AlreadyListed();
    error NotListed();
    error PriceMustBePositive();
    error InsufficientListingFee();
    error InsufficientPayment();
    error RoyaltyExceedsMax();
    error InvalidMaxRoyalty();
    error TransferFailed();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyExistingToken(uint256 tokenId) {
        if (!_tokenExists[tokenId]) revert TokenDoesNotExist();
        _;
    }

    constructor(address _admin, uint256 _listingFee) {
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        listingFee = _listingFee;
        emit AdminChanged(address(0), _admin);
        emit ListingFeeUpdated(0, _listingFee);
    }

    function setListingFee(uint256 newFee) external onlyAdmin {
        emit ListingFeeUpdated(listingFee, newFee);
        listingFee = newFee;
    }

    function setMaxRoyaltyBps(uint256 newMaxBps) external onlyAdmin {
        if (newMaxBps > MAX_ROYALTY_LIMIT_BPS) revert InvalidMaxRoyalty();
        emit MaxRoyaltyUpdated(maxRoyaltyBps, newMaxBps);
        maxRoyaltyBps = newMaxBps;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function mintNFT(string calldata uri, uint256 royaltyBps) external returns (uint256 tokenId) {
        if (royaltyBps > maxRoyaltyBps) revert RoyaltyExceedsMax();

        tokenId = _nextTokenId++;
        _ownerOf[tokenId] = msg.sender;
        _creatorOf[tokenId] = msg.sender;
        _royaltyBps[tokenId] = royaltyBps;
        _tokenURI[tokenId] = uri;
        _tokenExists[tokenId] = true;
        _balanceOf[msg.sender] += 1;
        totalSupply += 1;

        emit NFTMinted(tokenId, msg.sender, royaltyBps, uri);
    }

    function listNFT(uint256 tokenId, uint256 price) external payable onlyExistingToken(tokenId) {
        if (_ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (_listings[tokenId].isListed) revert AlreadyListed();
        if (price == 0) revert PriceMustBePositive();
        if (msg.value < listingFee) revert InsufficientListingFee();

        _listings[tokenId] = Listing({
            owner: msg.sender,
            price: price,
            isListed: true
        });

        if (listingFee > 0) {
            (bool ok, ) = payable(admin).call{value: listingFee}("");
            if (!ok) revert TransferFailed();
        }

        uint256 refund = msg.value - listingFee;
        if (refund > 0) {
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }

        emit NFTListed(tokenId, msg.sender, price, listingFee);
    }

    function buyNFT(uint256 tokenId) external payable onlyExistingToken(tokenId) {
        Listing memory listing = _listings[tokenId];
        if (!listing.isListed) revert NotListed();
        if (msg.value < listing.price) revert InsufficientPayment();

        address seller = listing.owner;
        address buyer = msg.sender;
        uint256 salePrice = listing.price;
        address creator = _creatorOf[tokenId];
        uint256 royaltyBps = _royaltyBps[tokenId];

        uint256 platformFee = (salePrice * PLATFORM_FEE_BPS) / 10000;
        uint256 royalty = (salePrice * royaltyBps) / 10000;
        uint256 sellerProceeds = salePrice - platformFee - royalty;

        delete _listings[tokenId];

        _balanceOf[seller] -= 1;
        _ownerOf[tokenId] = buyer;
        _balanceOf[buyer] += 1;

        emit NFTSold(tokenId, seller, buyer, salePrice, platformFee, royalty);
        emit OwnershipTransferred(tokenId, seller, buyer);

        if (platformFee > 0) {
            (bool ok, ) = payable(admin).call{value: platformFee}("");
            if (!ok) revert TransferFailed();
        }
        if (royalty > 0 && creator != seller) {
            (bool ok, ) = payable(creator).call{value: royalty}("");
            if (!ok) revert TransferFailed();
        }
        if (sellerProceeds > 0) {
            (bool ok, ) = payable(seller).call{value: sellerProceeds}("");
            if (!ok) revert TransferFailed();
        }

        uint256 refund = msg.value - salePrice;
        if (refund > 0) {
            (bool ok, ) = payable(buyer).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }
    }

    function delistNFT(uint256 tokenId) external onlyExistingToken(tokenId) {
        if (_ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (!_listings[tokenId].isListed) revert NotListed();

        delete _listings[tokenId];
        emit NFTDelisted(tokenId, msg.sender);
    }

    function transferOwnership(uint256 tokenId, address to) external onlyExistingToken(tokenId) {
        if (_ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (to == address(0)) revert ZeroAddress();
        if (_listings[tokenId].isListed) revert AlreadyListed();

        address from = msg.sender;
        _balanceOf[from] -= 1;
        _ownerOf[tokenId] = to;
        _balanceOf[to] += 1;

        emit OwnershipTransferred(tokenId, from, to);
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        if (!_tokenExists[tokenId]) revert TokenDoesNotExist();
        return _ownerOf[tokenId];
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balanceOf[owner];
    }

    function creatorOf(uint256 tokenId) external view onlyExistingToken(tokenId) returns (address) {
        return _creatorOf[tokenId];
    }

    function royaltyOf(uint256 tokenId) external view onlyExistingToken(tokenId) returns (uint256) {
        return _royaltyBps[tokenId];
    }

    function tokenURI(uint256 tokenId) external view onlyExistingToken(tokenId) returns (string memory) {
        return _tokenURI[tokenId];
    }

    function getListing(uint256 tokenId)
        external
        view
        onlyExistingToken(tokenId)
        returns (address owner, uint256 price, bool isListed)
    {
        Listing memory listing = _listings[tokenId];
        return (listing.owner, listing.price, listing.isListed);
    }

    function calculateFees(uint256 salePrice)
        external
        pure
        returns (uint256 platformFee, uint256 maxPossibleRoyalty)
    {
        platformFee = (salePrice * PLATFORM_FEE_BPS) / 10000;
        maxPossibleRoyalty = (salePrice * MAX_ROYALTY_LIMIT_BPS) / 10000;
    }
}
