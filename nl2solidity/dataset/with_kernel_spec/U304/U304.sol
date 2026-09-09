// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract AssetMarketplace {
    // --------- Reentrancy Guard ---------

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // --------- State ---------

    address public operator;
    address public feeRecipient;

    uint256 public constant PLATFORM_FEE_BPS = 200; // 2%
    uint256 public constant AUCTION_DURATION = 7 days;

    bool public paused;

    struct Listing {
        address seller;
        bool isAuction;
        uint256 price; // direct sale price or auction reserve price
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool active;
        bool finalized;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public pendingRefunds;

    // --------- Events ---------

    event AssetListed(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        bool isAuction,
        uint256 price,
        uint256 endTime
    );

    event BidPlaced(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );

    event SaleFinalized(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price,
        uint256 fee
    );

    event AssetWithdrawn(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller
    );

    event RefundWithdrawn(address indexed recipient, uint256 amount);
    event RefundCredited(address indexed recipient, uint256 amount);

    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // --------- Errors ---------

    error NotOperator();
    error WhenPaused();
    error ZeroAddress();
    error InvalidPrice();
    error ListingAlreadyExists();
    error NotTokenOwner();
    error NotActiveListing();
    error NotAuction();
    error IsAuction();
    error AuctionEnded();
    error AuctionNotEnded();
    error BidTooLow();
    error IncorrectPayment();
    error NoValidBid();
    error WithdrawNotAllowed();
    error TransferFailed();
    error NoPendingRefund();
    error ReentrantCall();

    // --------- Modifiers ---------

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    // --------- Constructor ---------

    constructor() {
        _status = _NOT_ENTERED;
        operator = msg.sender;
        feeRecipient = msg.sender;
        emit OperatorUpdated(address(0), msg.sender);
        emit FeeRecipientUpdated(address(0), msg.sender);
    }

    // --------- Operator functions ---------

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address prev = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(prev, newRecipient);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorUpdated(prev, newOperator);
    }

    // --------- Listing functions ---------

    function listDirectSale(address nft, uint256 tokenId, uint256 price) external whenNotPaused nonReentrant {
        if (price == 0) revert InvalidPrice();
        if (listings[nft][tokenId].active) revert ListingAlreadyExists();
        if (IERC721(nft).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();

        // Effects: set listing state before external call
        listings[nft][tokenId] = Listing({
            seller: msg.sender,
            isAuction: false,
            price: price,
            highestBid: 0,
            highestBidder: address(0),
            endTime: 0,
            active: true,
            finalized: false
        });

        // Interactions: transfer asset into escrow
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);

        emit AssetListed(nft, tokenId, msg.sender, false, price, 0);
    }

    function listAuction(address nft, uint256 tokenId, uint256 reservePrice) external whenNotPaused nonReentrant {
        if (reservePrice == 0) revert InvalidPrice();
        if (listings[nft][tokenId].active) revert ListingAlreadyExists();
        if (IERC721(nft).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();

        uint256 endTime = block.timestamp + AUCTION_DURATION;

        // Effects: set listing state before external call
        listings[nft][tokenId] = Listing({
            seller: msg.sender,
            isAuction: true,
            price: reservePrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: endTime,
            active: true,
            finalized: false
        });

        // Interactions: transfer asset into escrow
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);

        emit AssetListed(nft, tokenId, msg.sender, true, reservePrice, endTime);
    }

    // --------- Bidding ---------

    function placeBid(address nft, uint256 tokenId) external payable whenNotPaused nonReentrant {
        Listing storage l = listings[nft][tokenId];
        if (!l.active) revert NotActiveListing();
        if (!l.isAuction) revert NotAuction();
        if (block.timestamp >= l.endTime) revert AuctionEnded();
        if (msg.value <= l.highestBid) revert BidTooLow();

        // Effects: credit refund to previous highest bidder via pull payment
        // This avoids reentrancy from external ETH transfer during state update
        if (l.highestBidder != address(0)) {
            pendingRefunds[l.highestBidder] += l.highestBid;
            emit RefundCredited(l.highestBidder, l.highestBid);
        }

        l.highestBid = msg.value;
        l.highestBidder = msg.sender;

        emit BidPlaced(nft, tokenId, msg.sender, msg.value);
    }

    // --------- Refund withdrawal (pull payment) ---------

    function withdrawRefund() external nonReentrant {
        uint256 amount = pendingRefunds[msg.sender];
        if (amount == 0) revert NoPendingRefund();

        // Effects
        pendingRefunds[msg.sender] = 0;

        // Interactions
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit RefundWithdrawn(msg.sender, amount);
    }

    // --------- Direct sale acceptance ---------

    function acceptDirectSale(address nft, uint256 tokenId) external payable whenNotPaused nonReentrant {
        Listing storage l = listings[nft][tokenId];
        if (!l.active) revert NotActiveListing();
        if (l.isAuction) revert IsAuction();
        if (msg.value != l.price) revert IncorrectPayment();

        address seller = l.seller;
        uint256 salePrice = l.price;
        uint256 fee = (salePrice * PLATFORM_FEE_BPS) / 10000;
        uint256 sellerProceeds = salePrice - fee;

        // Effects: mark as finalized before any external calls
        l.active = false;
        l.finalized = true;

        // Interactions
        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        (bool successFee, ) = feeRecipient.call{value: fee}("");
        if (!successFee) revert TransferFailed();

        (bool successSeller, ) = seller.call{value: sellerProceeds}("");
        if (!successSeller) revert TransferFailed();

        emit SaleFinalized(nft, tokenId, seller, msg.sender, salePrice, fee);
    }

    // --------- Auction finalization ---------

    function finalizeAuction(address nft, uint256 tokenId) external whenNotPaused nonReentrant {
        Listing storage l = listings[nft][tokenId];
        if (!l.active) revert NotActiveListing();
        if (!l.isAuction) revert NotAuction();
        if (block.timestamp < l.endTime) revert AuctionNotEnded();

        address seller = l.seller;
        address winner = l.highestBidder;
        uint256 winningBid = l.highestBid;
        uint256 reserve = l.price;

        // Effects: mark as finalized before any external calls
        l.active = false;
        l.finalized = true;

        if (winner != address(0) && winningBid >= reserve) {
            uint256 fee = (winningBid * PLATFORM_FEE_BPS) / 10000;
            uint256 sellerProceeds = winningBid - fee;

            // Interactions
            IERC721(nft).safeTransferFrom(address(this), winner, tokenId);

            (bool successFee, ) = feeRecipient.call{value: fee}("");
            if (!successFee) revert TransferFailed();

            (bool successSeller, ) = seller.call{value: sellerProceeds}("");
            if (!successSeller) revert TransferFailed();

            emit SaleFinalized(nft, tokenId, seller, winner, winningBid, fee);
        } else {
            // Auction unsuccessful: credit refund to bidder via pull payment
            if (winner != address(0)) {
                pendingRefunds[winner] += winningBid;
                emit RefundCredited(winner, winningBid);
            }
            // Asset remains in escrow for seller to withdraw
        }
    }

    // --------- Withdrawal ---------

    function withdrawAsset(address nft, uint256 tokenId) external nonReentrant {
        Listing storage l = listings[nft][tokenId];
        if (l.seller == address(0)) revert NotActiveListing();
        if (msg.sender != l.seller) revert NotTokenOwner();

        bool canWithdraw;
        if (l.isAuction) {
            // Can withdraw if auction ended and no valid winning bid
            canWithdraw = (block.timestamp >= l.endTime && (l.highestBidder == address(0) || l.highestBid < l.price));
        } else {
            // Direct sale: can withdraw if not yet finalized (sold)
            canWithdraw = !l.finalized;
        }

        if (!canWithdraw) revert WithdrawNotAllowed();

        // Effects: clear seller to prevent re-withdrawal, mark as finalized
        address seller = l.seller;
        l.active = false;
        l.finalized = true;
        l.seller = address(0);

        // Interactions
        IERC721(nft).safeTransferFrom(address(this), seller, tokenId);

        emit AssetWithdrawn(nft, tokenId, seller);
    }

    // --------- View ---------

    function getListing(address nft, uint256 tokenId) external view returns (Listing memory) {
        return listings[nft][tokenId];
    }

    receive() external payable {}
}
