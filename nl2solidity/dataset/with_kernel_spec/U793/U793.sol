// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title DigitalAssetMarketplace
 * @notice A non-custodial marketplace for unique digital assets (ERC721 tokens).
 * @dev The contract holds only the assets currently offered for sale and the
 *      proceeds from successful sales (credited to sellers and the admin for
 *      withdrawal). The marketplace fee is configurable by the admin and defaults
 *      to 2.5%. A listing's price cannot be updated while active; the seller
 *      must cancel and relist to change the price.
 */
contract DigitalAssetMarketplace is IERC721Receiver {
    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    /// @notice Marketplace administrator who can adjust the fee.
    address public admin;

    /// @notice Marketplace fee in basis points (e.g., 250 = 2.5%).
    uint256 public feeBps;

    /// @notice Details of a listed digital asset.
    struct Listing {
        address seller;
        uint256 price;
        bool active;
        bool sold;
    }

    /// @dev Listings keyed by NFT contract address and token ID.
    mapping(address => mapping(uint256 => Listing)) internal _listings;

    /// @notice Withdrawable native-token balances credited from sale proceeds.
    mapping(address => uint256) public pendingWithdrawals;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event AssetListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event AssetPurchased(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 fee
    );

    event ListingCancelled(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller
    );

    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    event Withdrawn(address indexed account, uint256 amount);

    // ---------------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------------

    error NotAdmin();
    error ZeroAddress();
    error ZeroPrice();
    error NotTokenOwner();
    error AlreadyListed();
    error ListingNotActive();
    error AlreadySold();
    error IncorrectPayment();
    error SelfPurchase();
    error NotSeller();
    error FeeTooHigh();
    error NothingToWithdraw();
    error WithdrawalFailed();
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor() {
        admin = msg.sender;
        feeBps = 250; // 2.5%
        emit FeeUpdated(0, feeBps);
        emit AdminUpdated(address(0), msg.sender);
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    /// @notice Updates the marketplace fee in basis points. Only callable by admin.
    /// @param newFeeBps The new fee; must not exceed 10,000 (100%).
    function setFee(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > 10_000) revert FeeTooHigh();
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    /// @notice Transfers the administrator role to a new address.
    /// @param newAdmin The address of the new administrator.
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address old = admin;
        admin = newAdmin;
        emit AdminUpdated(old, newAdmin);
    }

    // ---------------------------------------------------------------------
    // Marketplace functions
    // ---------------------------------------------------------------------

    /**
     * @notice Lists a digital asset for sale at a fixed price.
     * @dev The caller must own the token and have approved this contract to
     *      transfer it. The token is moved into the contract's custody. The
     *      price cannot be changed while the listing is active; cancel and
     *      relist to adjust it.
     * @param nftContract The address of the ERC721 contract.
     * @param tokenId The token identifier to list.
     * @param price The asking price in wei.
     */
    function listAsset(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price == 0) revert ZeroPrice();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();

        Listing storage existing = _listings[nftContract][tokenId];
        if (existing.active && !existing.sold) revert AlreadyListed();

        // Effects: record the listing before the external transfer.
        _listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true,
            sold: false
        });

        // Interaction: take custody of the asset.
        nft.transferFrom(msg.sender, address(this), tokenId);

        emit AssetListed(nftContract, tokenId, msg.sender, price);
    }

    /**
     * @notice Purchases a listed digital asset by sending the exact asking price.
     * @dev The sale proceeds (minus the fee) are credited to the seller's
     *      withdrawable balance, and the fee is credited to the admin. The
     *      asset is transferred to the buyer.
     * @param nftContract The address of the ERC721 contract.
     * @param tokenId The token identifier to purchase.
     */
    function buyAsset(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = _listings[nftContract][tokenId];
        if (!listing.active) revert ListingNotActive();
        if (listing.sold) revert AlreadySold();
        if (msg.sender == listing.seller) revert SelfPurchase();
        if (msg.value != listing.price) revert IncorrectPayment();

        address seller = listing.seller;
        uint256 price = listing.price;
        uint256 fee = (price * feeBps) / 10_000;
        uint256 sellerProceeds = price - fee;

        // Effects: mark sold and credit proceeds before external calls.
        listing.active = false;
        listing.sold = true;
        pendingWithdrawals[seller] += sellerProceeds;
        pendingWithdrawals[admin] += fee;

        // Interaction: deliver the asset to the buyer.
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit AssetPurchased(nftContract, tokenId, msg.sender, seller, price, fee);
    }

    /**
     * @notice Cancels an active listing and returns the asset to the seller.
     * @param nftContract The address of the ERC721 contract.
     * @param tokenId The token identifier whose listing should be cancelled.
     */
    function cancelListing(address nftContract, uint256 tokenId) external {
        Listing storage listing = _listings[nftContract][tokenId];
        if (!listing.active) revert ListingNotActive();
        if (listing.sold) revert AlreadySold();
        if (msg.sender != listing.seller) revert NotSeller();

        // Effects: deactivate the listing before returning the asset.
        listing.active = false;

        // Interaction: return the asset to the seller.
        IERC721(nftContract).transferFrom(address(this), listing.seller, tokenId);

        emit ListingCancelled(nftContract, tokenId, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Withdrawal
    // ---------------------------------------------------------------------

    /// @notice Withdraws the caller's credited sale proceeds or fee share.
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Effects: zero the balance before the external call.
        pendingWithdrawals[msg.sender] = 0;

        // Interaction: send the funds.
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit Withdrawn(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Returns the details of a listing.
    /// @param nftContract The address of the ERC721 contract.
    /// @param tokenId The token identifier.
    /// @return seller The current seller.
    /// @return price The asking price in wei.
    /// @return active Whether the listing is active.
    /// @return sold Whether the asset has been sold.
    function getListing(
        address nftContract,
        uint256 tokenId
    ) external view returns (address seller, uint256 price, bool active, bool sold) {
        Listing storage listing = _listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.active, listing.sold);
    }

    /// @notice Returns the withdrawable balance credited to an account.
    /// @param account The address to query.
    /// @return The amount of native tokens available for withdrawal.
    function getPendingWithdrawal(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    // ---------------------------------------------------------------------
    // IERC721Receiver
    // ---------------------------------------------------------------------

    /// @dev Allows the contract to safely receive ERC721 tokens.
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Accepts native-token payments (e.g., refunds or direct sends).
    receive() external payable {}
}
