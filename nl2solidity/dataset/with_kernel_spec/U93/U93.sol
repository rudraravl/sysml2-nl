// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DigitalAssetAuction {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error AssetDoesNotExist();
    error NotAssetOwner();
    error AuctionNotActive();
    error AuctionStillActive();
    error AuctionEnded();
    error BidTooLow();
    error NoBidToAccept();
    error AuctionDurationTooShort();
    error ZeroAddress();
    error NotBidder();
    error NothingToWithdraw();
    error TransferFailed();
    error InvalidFeePercentage();
    error BidExists();
    error AssetAlreadyAuctioned();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event AssetMinted(uint256 indexed assetId, address indexed minter, address indexed owner, string uri);
    event AuctionListed(uint256 indexed assetId, address indexed seller, uint256 reservePrice, uint256 endTime);
    event BidPlaced(uint256 indexed assetId, address indexed bidder, uint256 amount);
    event AuctionConcluded(uint256 indexed assetId, address indexed seller, address indexed winner, uint256 salePrice, uint256 fee);
    event AuctionCancelled(uint256 indexed assetId, address indexed seller);
    event AssetWithdrawn(uint256 indexed assetId, address indexed owner);
    event FundsWithdrawn(address indexed account, uint256 amount);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event FeePercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    event MinterApproved(address indexed minter, bool approved);
    event AssetTransferred(uint256 indexed assetId, address indexed from, address indexed to);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                              STATE STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct DigitalAsset {
        string uri;
        address currentOwner;
        bool exists;
    }

    struct Auction {
        bool active;
        address seller;
        uint256 reservePrice;
        uint256 endTime;
        uint256 highestBid;
        address highestBidder;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_AUCTION_DURATION = 24 hours;
    uint256 public constant MAX_FEE_PERCENTAGE = 100;

    address public owner;
    uint256 public platformFeePercentage;
    uint256 public nextAssetId;

    mapping(uint256 => DigitalAsset) public assets;
    mapping(uint256 => Auction) public auctions;
    mapping(address => bool) public approvedMinters;
    mapping(address => uint256) public pendingReturns;
    uint256 public accumulatedFees;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyMinter() {
        if (msg.sender != owner && !approvedMinters[msg.sender]) revert NotAuthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        owner = msg.sender;
        platformFeePercentage = 10;
        nextAssetId = 1;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          MINTING & TRANSFER
    //////////////////////////////////////////////////////////////*/
    function mint(address initialOwner, string calldata uri) external onlyMinter returns (uint256 assetId) {
        if (initialOwner == address(0)) revert ZeroAddress();
        assetId = nextAssetId++;
        assets[assetId] = DigitalAsset({uri: uri, currentOwner: initialOwner, exists: true});
        emit AssetMinted(assetId, msg.sender, initialOwner, uri);
    }

    function transferAsset(uint256 assetId, address to) external {
        if (to == address(0)) revert ZeroAddress();
        DigitalAsset storage asset = assets[assetId];
        if (!asset.exists) revert AssetDoesNotExist();
        if (asset.currentOwner != msg.sender) revert NotAssetOwner();
        if (auctions[assetId].active) revert AuctionStillActive();
        address from = asset.currentOwner;
        asset.currentOwner = to;
        emit AssetTransferred(assetId, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function listAuction(uint256 assetId, uint256 reservePrice, uint256 duration) external {
        DigitalAsset storage asset = assets[assetId];
        if (!asset.exists) revert AssetDoesNotExist();
        if (asset.currentOwner != msg.sender) revert NotAssetOwner();
        if (auctions[assetId].active) revert AssetAlreadyAuctioned();
        if (duration < MIN_AUCTION_DURATION) revert AuctionDurationTooShort();

        uint256 endTime = block.timestamp + duration;
        auctions[assetId] = Auction({
            active: true,
            seller: msg.sender,
            reservePrice: reservePrice,
            endTime: endTime,
            highestBid: 0,
            highestBidder: address(0)
        });

        emit AuctionListed(assetId, msg.sender, reservePrice, endTime);
    }

    function placeBid(uint256 assetId) external payable {
        Auction storage auction = auctions[assetId];
        if (!auction.active) revert AuctionNotActive();
        if (block.timestamp >= auction.endTime) revert AuctionEnded();
        if (msg.value < auction.reservePrice) revert BidTooLow();
        if (msg.value <= auction.highestBid) revert BidTooLow();

        if (auction.highestBidder != address(0) && auction.highestBid > 0) {
            pendingReturns[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(assetId, msg.sender, msg.value);
    }

    function acceptBid(uint256 assetId) external {
        Auction storage auction = auctions[assetId];
        if (!auction.active) revert AuctionNotActive();
        if (auction.seller != msg.sender) revert NotAssetOwner();
        if (auction.highestBidder == address(0)) revert NoBidToAccept();
        if (block.timestamp < auction.endTime) revert AuctionStillActive();

        address winner = auction.highestBidder;
        uint256 salePrice = auction.highestBid;
        uint256 fee = (salePrice * platformFeePercentage) / 100;
        uint256 sellerProceeds = salePrice - fee;

        assets[assetId].currentOwner = winner;
        pendingReturns[auction.seller] += sellerProceeds;
        accumulatedFees += fee;

        auction.active = false;
        auction.highestBid = 0;
        auction.highestBidder = address(0);

        emit AuctionConcluded(assetId, auction.seller, winner, salePrice, fee);
    }

    function cancelAuction(uint256 assetId) external {
        Auction storage auction = auctions[assetId];
        if (!auction.active) revert AuctionNotActive();
        if (auction.seller != msg.sender) revert NotAssetOwner();
        if (auction.highestBidder != address(0)) revert BidExists();

        auction.active = false;
        emit AuctionCancelled(assetId, msg.sender);
    }

    function reclaimBid(uint256 assetId) external {
        Auction storage auction = auctions[assetId];
        if (!auction.active) revert AuctionNotActive();
        if (block.timestamp < auction.endTime) revert AuctionStillActive();
        if (auction.highestBidder != msg.sender) revert NotBidder();

        uint256 amount = auction.highestBid;
        auction.highestBid = 0;
        auction.highestBidder = address(0);
        auction.active = false;

        pendingReturns[msg.sender] += amount;
        emit AuctionCancelled(assetId, auction.seller);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function withdrawAsset(uint256 assetId) external {
        DigitalAsset storage asset = assets[assetId];
        if (!asset.exists) revert AssetDoesNotExist();
        if (asset.currentOwner != msg.sender) revert NotAssetOwner();
        if (auctions[assetId].active) revert AuctionStillActive();
        emit AssetWithdrawn(assetId, msg.sender);
    }

    function withdrawFunds() external {
        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        pendingReturns[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FundsWithdrawn(msg.sender, amount);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FeesWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setFeePercentage(uint256 newPercentage) external onlyOwner {
        if (newPercentage > MAX_FEE_PERCENTAGE) revert InvalidFeePercentage();
        uint256 old = platformFeePercentage;
        platformFeePercentage = newPercentage;
        emit FeePercentageUpdated(old, newPercentage);
    }

    function setMinterApproval(address minter, bool approved) external onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        approvedMinters[minter] = approved;
        emit MinterApproved(minter, approved);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAsset(uint256 assetId)
        external
        view
        returns (string memory uri, address currentOwner, bool exists)
    {
        DigitalAsset storage asset = assets[assetId];
        return (asset.uri, asset.currentOwner, asset.exists);
    }

    function getAuction(uint256 assetId)
        external
        view
        returns (
            bool active,
            address seller,
            uint256 reservePrice,
            uint256 endTime,
            uint256 highestBid,
            address highestBidder
        )
    {
        Auction storage auction = auctions[assetId];
        return (
            auction.active,
            auction.seller,
            auction.reservePrice,
            auction.endTime,
            auction.highestBid,
            auction.highestBidder
        );
    }
}
