// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract NFTMarketplace {
    error NotOwner();
    error NotSeller();
    error TokenNotListed();
    error TokenAlreadyListed();
    error InsufficientPayment();
    error ZeroPrice();
    error FeeTooHigh();
    error NothingToWithdraw();
    error TransferFailed();
    error ReentrancyDetected();

    event TokenListed(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );
    event TokenSold(
        address indexed buyer,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );
    event ListingCancelled(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event ProceedsWithdrawn(address indexed seller, uint256 amount);
    event FeesWithdrawn(address indexed owner, uint256 amount);

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    address public owner;
    uint256 public feeBps; // basis points, e.g. 250 = 2.5%
    uint256 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 public constant DEFAULT_FEE_BPS = 250; // 2.5%
    uint256 public collectedFees;

    // nftContract => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;
    // seller => proceeds balance (in wei)
    mapping(address => uint256) public proceeds;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyDetected();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor() {
        owner = msg.sender;
        feeBps = DEFAULT_FEE_BPS;
        _status = _NOT_ENTERED;
        emit FeeUpdated(0, DEFAULT_FEE_BPS);
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 oldFee = feeBps;
        feeBps = _feeBps;
        emit FeeUpdated(oldFee, _feeBps);
    }

    function listItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant {
        if (price == 0) revert ZeroPrice();
        if (listings[nftContract][tokenId].active) revert TokenAlreadyListed();
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) revert NotSeller();

        // Effects: record listing before transferring the token
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        // Interactions
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit TokenListed(msg.sender, nftContract, tokenId, price);
    }

    function buyItem(address nftContract, uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        if (!listing.active) revert TokenNotListed();
        if (msg.value < listing.price) revert InsufficientPayment();

        // Effects
        listings[nftContract][tokenId].active = false;
        uint256 fee = (listing.price * feeBps) / 10000;
        uint256 sellerProceeds = listing.price - fee;
        proceeds[listing.seller] += sellerProceeds;
        collectedFees += fee;

        // Interactions
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // Refund excess payment
        uint256 excess = msg.value - listing.price;
        if (excess > 0) {
            (bool sent, ) = payable(msg.sender).call{value: excess}("");
            if (!sent) revert TransferFailed();
        }

        emit TokenSold(
            msg.sender,
            listing.seller,
            nftContract,
            tokenId,
            listing.price,
            fee
        );
    }

    function cancelListing(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        if (!listing.active) revert TokenNotListed();
        if (listing.seller != msg.sender) revert NotSeller();

        // Effects
        listings[nftContract][tokenId].active = false;

        // Interactions
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit ListingCancelled(msg.sender, nftContract, tokenId);
    }

    function withdrawProceeds() external nonReentrant {
        uint256 amount = proceeds[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Effects
        proceeds[msg.sender] = 0;

        // Interactions
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        if (!sent) revert TransferFailed();

        emit ProceedsWithdrawn(msg.sender, amount);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = collectedFees;
        if (amount == 0) revert NothingToWithdraw();

        // Effects
        collectedFees = 0;

        // Interactions
        (bool sent, ) = payable(owner).call{value: amount}("");
        if (!sent) revert TransferFailed();

        emit FeesWithdrawn(owner, amount);
    }

    function getListing(address nftContract, uint256 tokenId)
        external
        view
        returns (address seller, uint256 price, bool active)
    {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.active);
    }
}
