// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract TimedAuction {
    error NotOwner();
    error WhenPaused();
    error WhenNotPaused();
    error AuctionNotFound();
    error AuctionEnded();
    error AuctionNotEnded();
    error NotSeller();
    error NotWinner();
    error BidTooLow();
    error NothingToWithdraw();
    error ZeroAddress();
    error InvalidDuration();
    error InvalidFee();
    error AlreadyClaimed();
    error TransferFailed();

    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 startTime,
        uint256 endTime,
        uint256 reservePrice
    );
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 endTime
    );
    event AuctionConcluded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid,
        uint256 fee,
        uint256 sellerProceeds
    );
    event AuctionCancelled(uint256 indexed auctionId);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed to, uint256 amount);

    struct Auction {
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable highestBidder;
        uint256 highestBid;
        uint256 endTime;
        bool active;
        bool finalized;
    }

    address public owner;
    bool public paused;
    uint256 public platformFeeBps;
    uint256 public accumulatedFees;
    uint256 public nextAuctionId;

    mapping(uint256 => Auction) public auctions;

    uint256 private constant MIN_INCREMENT_BPS = 100; // 1%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert WhenNotPaused();
        _;
    }

    constructor(uint256 _platformFeeBps) {
        if (_platformFeeBps > BPS_DENOMINATOR) revert InvalidFee();
        owner = msg.sender;
        platformFeeBps = _platformFeeBps;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setPlatformFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > BPS_DENOMINATOR) revert InvalidFee();
        uint256 old = platformFeeBps;
        platformFeeBps = _feeBps;
        emit PlatformFeeUpdated(old, _feeBps);
    }

    function startAuction(
        address nftContract,
        uint256 tokenId,
        uint256 reservePrice,
        uint256 duration
    ) external whenNotPaused returns (uint256 auctionId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (duration < 1 minutes) revert InvalidDuration();

        IERC721 asset = IERC721(nftContract);
        if (asset.ownerOf(tokenId) != msg.sender) revert NotSeller();

        auctionId = nextAuctionId++;
        uint256 endTime = block.timestamp + duration;

        auctions[auctionId] = Auction({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: payable(msg.sender),
            highestBidder: payable(address(0)),
            highestBid: reservePrice,
            endTime: endTime,
            active: true,
            finalized: false
        });

        asset.transferFrom(msg.sender, address(this), tokenId);

        emit AuctionStarted(
            auctionId,
            nftContract,
            tokenId,
            msg.sender,
            block.timestamp,
            endTime,
            reservePrice
        );
    }

    function placeBid(uint256 auctionId) external payable whenNotPaused {
        Auction storage a = auctions[auctionId];
        if (!a.active) revert AuctionNotFound();
        if (block.timestamp >= a.endTime) revert AuctionEnded();

        uint256 minIncrement = (a.highestBid * MIN_INCREMENT_BPS) / BPS_DENOMINATOR;
        uint256 minBid = a.highestBid + minIncrement;
        if (msg.value < minBid) revert BidTooLow();

        address payable previousBidder = a.highestBidder;
        uint256 previousBid = a.highestBid;

        a.highestBidder = payable(msg.sender);
        a.highestBid = msg.value;

        if (previousBidder != address(0) && previousBid != 0) {
            (bool sent, ) = previousBidder.call{value: previousBid}("");
            if (!sent) revert TransferFailed();
        }

        emit BidPlaced(auctionId, msg.sender, msg.value, a.endTime);
    }

    function claimAsset(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        if (!a.active) revert AuctionNotFound();
        if (block.timestamp < a.endTime) revert AuctionNotEnded();
        if (a.finalized) revert AlreadyClaimed();

        address winner = a.highestBidder;
        if (msg.sender != winner) revert NotWinner();

        a.finalized = true;
        a.active = false;

        uint256 salePrice = a.highestBid;
        uint256 fee = (salePrice * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = salePrice - fee;

        accumulatedFees += fee;

        IERC721(a.nftContract).transferFrom(address(this), winner, a.tokenId);

        (bool sent, ) = a.seller.call{value: sellerProceeds}("");
        if (!sent) revert TransferFailed();

        emit AuctionConcluded(auctionId, winner, salePrice, fee, sellerProceeds);
    }

    function cancelAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        if (!a.active) revert AuctionNotFound();
        if (msg.sender != a.seller && msg.sender != owner) revert NotSeller();
        if (a.highestBidder != address(0)) revert AuctionEnded();

        a.active = false;
        a.finalized = true;

        IERC721(a.nftContract).transferFrom(address(this), a.seller, a.tokenId);

        emit AuctionCancelled(auctionId);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit FeesWithdrawn(msg.sender, amount);
    }

    function getAuction(uint256 auctionId)
        external
        view
        returns (
            address nftContract,
            uint256 tokenId,
            address seller,
            address highestBidder,
            uint256 highestBid,
            uint256 endTime,
            bool active,
            bool finalized
        )
    {
        Auction storage a = auctions[auctionId];
        return (
            a.nftContract,
            a.tokenId,
            a.seller,
            a.highestBidder,
            a.highestBid,
            a.endTime,
            a.active,
            a.finalized
        );
    }

    function minNextBid(uint256 auctionId) external view returns (uint256) {
        Auction storage a = auctions[auctionId];
        if (!a.active) return 0;
        uint256 minIncrement = (a.highestBid * MIN_INCREMENT_BPS) / BPS_DENOMINATOR;
        return a.highestBid + minIncrement;
    }
}
