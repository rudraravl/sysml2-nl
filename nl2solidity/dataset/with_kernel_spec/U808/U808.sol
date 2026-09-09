// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC2981 is IERC165 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
}

contract NFTOrderbook {
    ////////////////////////////////////////////////////////////////
    //                          ERRORS
    ////////////////////////////////////////////////////////////////
    error NotOperator();
    error TradingPaused();
    error ZeroAddress();
    error InvalidPrice();
    error NotTokenOwner();
    error NotApproved();
    error MaxListingsReached();
    error NotListingOwner();
    error NotBidder();
    error ListingInactive();
    error BidInactive();
    error PriceMismatch();
    error IndexOutOfRange();
    error SelfTrade();
    error InvalidRoyaltyBps();
    error TransferFailed();

    ////////////////////////////////////////////////////////////////
    //                          EVENTS
    ////////////////////////////////////////////////////////////////
    event ListingCreated(address indexed collection, uint256 indexed tokenId, address indexed seller, uint256 price, uint256 listingIndex);
    event ListingCancelled(address indexed collection, uint256 indexed tokenId, address indexed seller, uint256 listingIndex);
    event BidPlaced(address indexed collection, uint256 indexed tokenId, address indexed bidder, uint256 price, uint256 bidIndex);
    event BidCancelled(address indexed collection, uint256 indexed tokenId, address indexed bidder, uint256 bidIndex);
    event TradeExecuted(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price,
        uint256 protocolFee,
        uint256 royaltyAmount
    );
    event TradingPausedChanged(bool paused);
    event RoyaltyEnforcementChanged(bool enforced);
    event RoyaltyOverrideSet(address indexed collection, address receiver, uint96 bps);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);

    ////////////////////////////////////////////////////////////////
    //                          TYPES
    ////////////////////////////////////////////////////////////////
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    struct Bid {
        address bidder;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    struct RoyaltyOverride {
        address receiver;
        uint96 bps; // basis points out of 10000
        bool set;
    }

    ////////////////////////////////////////////////////////////////
    //                       STATE VARIABLES
    ////////////////////////////////////////////////////////////////
    address public operator;
    address public treasury;

    bool public tradingPaused;
    bool public royaltyEnforced;

    uint256 public constant MAX_LISTINGS_PER_COLLECTION = 100;
    uint256 public constant PROTOCOL_FEE_BPS = 50; // 0.5%
    uint256 private constant BPS_DENOMINATOR = 10000;

    // collection => tokenId => listings
    mapping(address => mapping(uint256 => Listing[])) internal _listings;
    // collection => tokenId => bids
    mapping(address => mapping(uint256 => Bid[])) internal _bids;
    // collection => active listing count
    mapping(address => uint256) internal _activeListingCount;

    // collection => royalty override
    mapping(address => RoyaltyOverride) internal _royaltyOverrides;

    // Reentrancy guard
    uint256 private _locked = 1;

    ////////////////////////////////////////////////////////////////
    //                        MODIFIERS
    ////////////////////////////////////////////////////////////////
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (tradingPaused) revert TradingPaused();
        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "REENTRANT");
        _locked = 2;
        _;
        _locked = 1;
    }

    ////////////////////////////////////////////////////////////////
    //                        CONSTRUCTOR
    ////////////////////////////////////////////////////////////////
    constructor(address _operator, address _treasury) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        operator = _operator;
        treasury = _treasury;
        tradingPaused = false;
        royaltyEnforced = true;
    }

    ////////////////////////////////////////////////////////////////
    //                    ADMIN / OPERATOR
    ////////////////////////////////////////////////////////////////
    function setTradingPaused(bool paused) external onlyOperator {
        tradingPaused = paused;
        emit TradingPausedChanged(paused);
    }

    function setRoyaltyEnforcement(bool enforced) external onlyOperator {
        royaltyEnforced = enforced;
        emit RoyaltyEnforcementChanged(enforced);
    }

    function setRoyaltyOverride(address collection, address receiver, uint96 bps) external onlyOperator {
        if (collection == address(0)) revert ZeroAddress();
        if (bps > 5000) revert InvalidRoyaltyBps(); // cap at 50%
        _royaltyOverrides[collection] = RoyaltyOverride({receiver: receiver, bps: bps, set: true});
        emit RoyaltyOverrideSet(collection, receiver, bps);
    }

    function changeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function changeTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    ////////////////////////////////////////////////////////////////
    //                       LISTING LOGIC
    ////////////////////////////////////////////////////////////////
    function createListing(address collection, uint256 tokenId, uint256 price) external whenNotPaused {
        if (collection == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        if (IERC721(collection).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (_activeListingCount[collection] >= MAX_LISTINGS_PER_COLLECTION) revert MaxListingsReached();

        uint256 listingIndex = _listings[collection][tokenId].length;
        _listings[collection][tokenId].push(
            Listing({seller: msg.sender, tokenId: tokenId, price: price, active: true})
        );
        _activeListingCount[collection] += 1;

        emit ListingCreated(collection, tokenId, msg.sender, price, listingIndex);
    }

    function cancelListing(address collection, uint256 tokenId, uint256 listingIndex) external {
        if (listingIndex >= _listings[collection][tokenId].length) revert IndexOutOfRange();
        Listing storage listing = _listings[collection][tokenId][listingIndex];
        if (!listing.active) revert ListingInactive();
        if (listing.seller != msg.sender) revert NotListingOwner();

        listing.active = false;
        _activeListingCount[collection] -= 1;

        emit ListingCancelled(collection, tokenId, msg.sender, listingIndex);
    }

    ////////////////////////////////////////////////////////////////
    //                         BID LOGIC
    ////////////////////////////////////////////////////////////////
    function placeBid(address collection, uint256 tokenId) external payable whenNotPaused {
        if (collection == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert InvalidPrice();

        uint256 bidIndex = _bids[collection][tokenId].length;
        _bids[collection][tokenId].push(
            Bid({bidder: msg.sender, tokenId: tokenId, price: msg.value, active: true})
        );

        emit BidPlaced(collection, tokenId, msg.sender, msg.value, bidIndex);
    }

    function cancelBid(address collection, uint256 tokenId, uint256 bidIndex) external nonReentrant {
        if (bidIndex >= _bids[collection][tokenId].length) revert IndexOutOfRange();
        Bid storage bid = _bids[collection][tokenId][bidIndex];
        if (!bid.active) revert BidInactive();
        if (bid.bidder != msg.sender) revert NotBidder();

        uint256 refund = bid.price;
        bid.active = false;
        bid.price = 0;

        (bool success, ) = payable(msg.sender).call{value: refund}("");
        if (!success) revert TransferFailed();

        emit BidCancelled(collection, tokenId, msg.sender, bidIndex);
    }

    ////////////////////////////////////////////////////////////////
    //                       TRADE EXECUTION
    ////////////////////////////////////////////////////////////////
    function executeTrade(
        address collection,
        uint256 tokenId,
        uint256 listingIndex,
        uint256 bidIndex
    ) external whenNotPaused nonReentrant {
        if (listingIndex >= _listings[collection][tokenId].length) revert IndexOutOfRange();
        if (bidIndex >= _bids[collection][tokenId].length) revert IndexOutOfRange();

        Listing storage listing = _listings[collection][tokenId][listingIndex];
        Bid storage bid = _bids[collection][tokenId][bidIndex];

        if (!listing.active) revert ListingInactive();
        if (!bid.active) revert BidInactive();
        if (listing.price != bid.price) revert PriceMismatch();
        if (listing.seller == bid.bidder) revert SelfTrade();

        // Verify seller still owns and has approved the marketplace
        if (IERC721(collection).ownerOf(tokenId) != listing.seller) revert NotTokenOwner();
        if (
            !IERC721(collection).isApprovedForAll(listing.seller, address(this)) &&
            IERC721(collection).getApproved(tokenId) != address(this)
        ) revert NotApproved();

        uint256 price = listing.price;
        address seller = listing.seller;
        address buyer = bid.bidder;

        // Effects: deactivate listing and bid before external interactions
        listing.active = false;
        _activeListingCount[collection] -= 1;

        bid.active = false;
        bid.price = 0;

        // Compute protocol fee (0.5%)
        uint256 protocolFee = (price * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;

        // Compute royalty if enforcement is enabled
        uint256 royaltyAmount = 0;
        address royaltyReceiver = address(0);
        if (royaltyEnforced) {
            (royaltyReceiver, royaltyAmount) = _resolveRoyalty(collection, tokenId, price);
        }

        // Seller proceeds: price minus protocol fee and royalty
        uint256 sellerProceeds = price - protocolFee - royaltyAmount;

        // Interactions: transfer NFT from seller to buyer
        IERC721(collection).transferFrom(seller, buyer, tokenId);

        // Pay protocol fee to treasury
        if (protocolFee > 0) {
            (bool feeOk, ) = payable(treasury).call{value: protocolFee}("");
            if (!feeOk) revert TransferFailed();
        }

        // Pay royalty
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            (bool royaltyOk, ) = payable(royaltyReceiver).call{value: royaltyAmount}("");
            if (!royaltyOk) revert TransferFailed();
        }

        // Pay seller
        (bool sellerOk, ) = payable(seller).call{value: sellerProceeds}("");
        if (!sellerOk) revert TransferFailed();

        emit TradeExecuted(collection, tokenId, seller, buyer, price, protocolFee, royaltyAmount);
    }

    ////////////////////////////////////////////////////////////////
    //                       VIEW FUNCTIONS
    ////////////////////////////////////////////////////////////////
    function getListing(address collection, uint256 tokenId, uint256 listingIndex)
        external
        view
        returns (Listing memory)
    {
        if (listingIndex >= _listings[collection][tokenId].length) revert IndexOutOfRange();
        return _listings[collection][tokenId][listingIndex];
    }

    function getBid(address collection, uint256 tokenId, uint256 bidIndex)
        external
        view
        returns (Bid memory)
    {
        if (bidIndex >= _bids[collection][tokenId].length) revert IndexOutOfRange();
        return _bids[collection][tokenId][bidIndex];
    }

    function listingCount(address collection, uint256 tokenId) external view returns (uint256) {
        return _listings[collection][tokenId].length;
    }

    function bidCount(address collection, uint256 tokenId) external view returns (uint256) {
        return _bids[collection][tokenId].length;
    }

    function activeListingCount(address collection) external view returns (uint256) {
        return _activeListingCount[collection];
    }

    function royaltyOverride(address collection)
        external
        view
        returns (address receiver, uint96 bps, bool set)
    {
        RoyaltyOverride memory ro = _royaltyOverrides[collection];
        return (ro.receiver, ro.bps, ro.set);
    }

    ////////////////////////////////////////////////////////////////
    //                      INTERNAL HELPERS
    ////////////////////////////////////////////////////////////////
    function _resolveRoyalty(address collection, uint256 tokenId, uint256 salePrice)
        internal
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyOverride memory ro = _royaltyOverrides[collection];
        if (ro.set) {
            if (ro.receiver != address(0)) {
                royaltyAmount = (salePrice * ro.bps) / BPS_DENOMINATOR;
                return (ro.receiver, royaltyAmount);
            }
            return (address(0), 0);
        }

        // Fall back to EIP-2981 if the collection supports it
        try IERC2981(collection).supportsInterface(0x2a55205a) returns (bool supported) {
            if (supported) {
                try IERC2981(collection).royaltyInfo(tokenId, salePrice) returns (address r, uint256 amount) {
                    if (amount > salePrice) amount = salePrice;
                    return (r, amount);
                } catch {}
            }
        } catch {}

        return (address(0), 0);
    }

    ////////////////////////////////////////////////////////////////
    //                      RECEIVE / FALLBACK
    ////////////////////////////////////////////////////////////////
    receive() external payable {}

    fallback() external payable {}
}
