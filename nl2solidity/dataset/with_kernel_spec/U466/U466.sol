// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract NFTMarketplace {
    error NotAuthorized();
    error ListingNotActive();
    error ListingExpired();
    error PriceNotMet();
    error InsufficientBalance();
    error TransferFailed();
    error ZeroAddress();
    error InvalidPrice();
    error InvalidAmount();
    error FeeTooHigh();
    error NotSeller();
    error ContractPaused();

    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 expiresAt
    );

    event Purchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );

    event ListingCanceled(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId
    );

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint64 listedAt;
        uint64 expiresAt;
        bool active;
    }

    address public operator;
    address public feeRecipient;

    IERC20 public immutable paymentToken;

    uint256 public feeBps;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant LISTING_DURATION = 30 days;

    bool public paused;

    uint256 public nextListingId;

    mapping(uint256 => Listing) public listings;

    mapping(address => uint256) public balances;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(address _paymentToken, address _operator, address _feeRecipient) {
        if (_paymentToken == address(0) || _operator == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }

        paymentToken = IERC20(_paymentToken);
        operator = _operator;
        feeRecipient = _feeRecipient;
        feeBps = 250;
        nextListingId = 1;

        emit FeeUpdated(0, feeBps);
    }

    function listNFT(address nftContract, uint256 tokenId, uint256 price)
        external
        whenNotPaused
        returns (uint256 listingId)
    {
        if (price == 0) revert InvalidPrice();
        if (nftContract == address(0)) revert ZeroAddress();

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        listingId = nextListingId++;
        uint64 now_ = uint64(block.timestamp);

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            listedAt: now_,
            expiresAt: now_ + uint64(LISTING_DURATION),
            active: true
        });

        emit Listed(listingId, msg.sender, nftContract, tokenId, price, now_ + uint64(LISTING_DURATION));
    }

    function buyNFT(uint256 listingId) external whenNotPaused {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (block.timestamp > listing.expiresAt) revert ListingExpired();

        address seller = listing.seller;
        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;
        uint256 price = listing.price;

        listing.active = false;

        uint256 fee = (price * feeBps) / 10000;
        uint256 proceeds = price - fee;

        balances[seller] += proceeds;
        if (fee > 0) {
            balances[feeRecipient] += fee;
        }

        bool ok = paymentToken.transferFrom(msg.sender, address(this), price);
        if (!ok) revert TransferFailed();

        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Purchased(listingId, msg.sender, seller, nftContract, tokenId, price, fee);
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotSeller();

        address nftContract = listing.nftContract;
        uint256 tokenId = listing.tokenId;

        listing.active = false;

        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        emit ListingCanceled(listingId, msg.sender, nftContract, tokenId);
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert InvalidAmount();

        bool ok = paymentToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        balances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;

        bool ok = paymentToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function isListingActive(uint256 listingId) external view returns (bool) {
        Listing storage l = listings[listingId];
        return l.active && block.timestamp <= l.expiresAt;
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
}
