// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ArtworkMarketplace {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error NotPlatformOperator();
    error ArtworkDoesNotExist();
    error NotOwner();
    error NotForSale();
    error AlreadyForSale();
    error ZeroAddress();
    error InsufficientPayment();
    error NoBid();
    error BidTooLow();
    error FeeExceedsCap();
    error NothingToWithdraw();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ArtworkCreated(uint256 indexed tokenId, address indexed creator, string metadataURI);
    event OwnershipTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event ArtworkListed(uint256 indexed tokenId, uint256 price);
    event ArtworkDelisted(uint256 indexed tokenId);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event BidWithdrawn(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event ArtworkSold(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price, uint256 fee);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             ARTWORK STORAGE
    //////////////////////////////////////////////////////////////*/
    struct Artwork {
        address creator;
        address owner;
        string metadataURI;
        bool forSale;
        uint256 price;
        bool exists;
    }

    uint256 public nextTokenId;
    uint256 public totalSupply;
    uint256 public platformFeePercentage; // in basis points, e.g. 500 = 5%
    uint256 public constant FEE_CAP = 1500; // 15%
    uint256 public constant DEFAULT_FEE = 500; // 5%

    address public platformOperator;
    uint256 public accumulatedFees;

    mapping(uint256 => Artwork) internal _artworks;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => mapping(address => uint256)) internal _bids;

    bool internal _locked;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyPlatformOperator() {
        if (msg.sender != platformOperator) revert NotPlatformOperator();
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "REENTRANT");
        _locked = true;
        _;
        _locked = false;
    }

    modifier existingArtwork(uint256 tokenId) {
        if (!_artworks[tokenId].exists) revert ArtworkDoesNotExist();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _platformOperator) {
        if (_platformOperator == address(0)) revert ZeroAddress();
        platformOperator = _platformOperator;
        platformFeePercentage = DEFAULT_FEE;
        nextTokenId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setPlatformFee(uint256 newFeePercentage) external onlyPlatformOperator {
        if (newFeePercentage > FEE_CAP) revert FeeExceedsCap();
        emit PlatformFeeUpdated(platformFeePercentage, newFeePercentage);
        platformFeePercentage = newFeePercentage;
    }

    function mintArtwork(address creator, string calldata metadataURI) external onlyPlatformOperator returns (uint256) {
        if (creator == address(0)) revert ZeroAddress();
        uint256 tokenId = nextTokenId++;
        _artworks[tokenId] = Artwork({
            creator: creator,
            owner: creator,
            metadataURI: metadataURI,
            forSale: false,
            price: 0,
            exists: true
        });
        _balances[creator]++;
        totalSupply++;
        emit ArtworkCreated(tokenId, creator, metadataURI);
        emit OwnershipTransferred(tokenId, address(0), creator);
        return tokenId;
    }

    function withdrawFees(address payable to) external onlyPlatformOperator nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          ARTWORK QUERIES
    //////////////////////////////////////////////////////////////*/
    function getArtwork(uint256 tokenId) external view existingArtwork(tokenId) returns (
        address creator,
        address owner,
        string memory metadataURI,
        bool forSale,
        uint256 price
    ) {
        Artwork storage a = _artworks[tokenId];
        return (a.creator, a.owner, a.metadataURI, a.forSale, a.price);
    }

    function ownerOf(uint256 tokenId) external view existingArtwork(tokenId) returns (address) {
        return _artworks[tokenId].owner;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function getBid(uint256 tokenId, address bidder) external view existingArtwork(tokenId) returns (uint256) {
        return _bids[tokenId][bidder];
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(uint256 tokenId, address to) external existingArtwork(tokenId) nonReentrant {
        Artwork storage a = _artworks[tokenId];
        if (msg.sender != a.owner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        if (a.forSale) {
            a.forSale = false;
            a.price = 0;
            emit ArtworkDelisted(tokenId);
        }
        _transfer(tokenId, a.owner, to);
    }

    function _transfer(uint256 tokenId, address from, address to) internal {
        _balances[from]--;
        _balances[to]++;
        _artworks[tokenId].owner = to;
        emit OwnershipTransferred(tokenId, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                            SALE LOGIC
    //////////////////////////////////////////////////////////////*/
    function listForSale(uint256 tokenId, uint256 price) external existingArtwork(tokenId) {
        Artwork storage a = _artworks[tokenId];
        if (msg.sender != a.owner) revert NotOwner();
        if (price == 0) revert InsufficientPayment();
        a.forSale = true;
        a.price = price;
        emit ArtworkListed(tokenId, price);
    }

    function delist(uint256 tokenId) external existingArtwork(tokenId) {
        Artwork storage a = _artworks[tokenId];
        if (msg.sender != a.owner) revert NotOwner();
        if (!a.forSale) revert NotForSale();
        a.forSale = false;
        a.price = 0;
        emit ArtworkDelisted(tokenId);
    }

    function buyArtwork(uint256 tokenId) external payable existingArtwork(tokenId) nonReentrant {
        Artwork storage a = _artworks[tokenId];
        if (!a.forSale) revert NotForSale();
        if (msg.value < a.price) revert InsufficientPayment();

        address seller = a.owner;
        uint256 price = a.price;
        uint256 fee = (price * platformFeePercentage) / 10000;
        uint256 sellerProceeds = price - fee;

        // Effects
        a.forSale = false;
        a.price = 0;
        accumulatedFees += fee;
        _transfer(tokenId, seller, msg.sender);

        // Interactions
        if (sellerProceeds > 0) {
            (bool ok, ) = payable(seller).call{value: sellerProceeds}("");
            if (!ok) revert TransferFailed();
        }

        // Refund excess payment
        if (msg.value > price) {
            (bool refundOk, ) = payable(msg.sender).call{value: msg.value - price}("");
            if (!refundOk) revert TransferFailed();
        }

        emit ArtworkSold(tokenId, seller, msg.sender, price, fee);
    }

    /*//////////////////////////////////////////////////////////////
                             BIDDING LOGIC
    //////////////////////////////////////////////////////////////*/
    function bid(uint256 tokenId) external payable existingArtwork(tokenId) nonReentrant {
        Artwork storage a = _artworks[tokenId];
        if (msg.sender == a.owner) revert NotAuthorized();
        if (msg.value == 0) revert InsufficientPayment();

        uint256 existing = _bids[tokenId][msg.sender];
        _bids[tokenId][msg.sender] = existing + msg.value;
        emit BidPlaced(tokenId, msg.sender, existing + msg.value);
    }

    function withdrawBid(uint256 tokenId) external existingArtwork(tokenId) nonReentrant {
        uint256 amount = _bids[tokenId][msg.sender];
        if (amount == 0) revert NoBid();

        _bids[tokenId][msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit BidWithdrawn(tokenId, msg.sender, amount);
    }

    function acceptBid(uint256 tokenId, address bidder) external existingArtwork(tokenId) nonReentrant {
        Artwork storage a = _artworks[tokenId];
        if (msg.sender != a.owner) revert NotOwner();
        uint256 bidAmount = _bids[tokenId][bidder];
        if (bidAmount == 0) revert NoBid();

        address seller = a.owner;
        uint256 fee = (bidAmount * platformFeePercentage) / 10000;
        uint256 sellerProceeds = bidAmount - fee;

        // Effects
        _bids[tokenId][bidder] = 0;
        a.forSale = false;
        a.price = 0;
        accumulatedFees += fee;
        _transfer(tokenId, seller, bidder);

        // Interactions
        if (sellerProceeds > 0) {
            (bool ok, ) = payable(seller).call{value: sellerProceeds}("");
            if (!ok) revert TransferFailed();
        }

        emit ArtworkSold(tokenId, seller, bidder, bidAmount, fee);
    }

    receive() external payable {}
}
