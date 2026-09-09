// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/**
 * @title NFTMarketplace
 * @notice A non-custodial marketplace that facilitates direct peer-to-peer ERC721 sales
 *         with a configurable platform fee taken on each successful purchase.
 */
contract NFTMarketplace {
    struct Listing {
        address nftContract;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool active;
    }

    /// @notice Address with administrative privileges (fee updates, fee recipient changes).
    address public operator;

    /// @notice Address that receives platform fees from successful sales.
    address public feeRecipient;

    /// @notice Platform fee expressed in basis points (e.g. 250 = 2.5%).
    uint256 public feeBps;

    /// @dev Counter used to assign unique listing IDs.
    uint256 private _nextListingId;

    /// @notice Mapping from listing ID to listing details.
    mapping(uint256 => Listing) private _listings;

    /// @notice Accumulated fees available for withdrawal by the fee recipient.
    mapping(address => uint256) public pendingFees;

    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );

    event ListingCanceled(uint256 indexed listingId, address indexed seller);

    event Purchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );

    event FeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event FeesAccrued(address indexed recipient, uint256 amount);

    error Unauthorized();
    error ZeroAddress();
    error InvalidPrice();
    error InvalidFeeBps(uint256 feeBps);
    error ListingNotActive();
    error NotListingSeller();
    error NotTokenOwner();
    error NotApprovedMarketplace();
    error IncorrectPayment(uint256 expected, uint256 received);
    error TransferFailed();
    error NothingToWithdraw();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    /**
     * @param _feeRecipient Address that will receive collected platform fees.
     * @param _feeBps Initial platform fee in basis points (250 = 2.5%).
     */
    constructor(address _feeRecipient, uint256 _feeBps) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > 10000) revert InvalidFeeBps(_feeBps);

        operator = msg.sender;
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;
        _nextListingId = 1;

        emit OperatorUpdated(address(0), msg.sender);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit FeeBpsUpdated(0, _feeBps);
    }

    /**
     * @notice Returns the next listing ID that will be assigned.
     */
    function nextListingId() external view returns (uint256) {
        return _nextListingId;
    }

    /**
     * @notice Returns the details of a listing.
     * @param listingId The ID of the listing to query.
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return _listings[listingId];
    }

    /**
     * @notice List an ERC721 token for sale. The caller must own the token and have
     *         approved this marketplace to transfer it.
     * @param nftContract The address of the ERC721 contract.
     * @param tokenId The ID of the token to list.
     * @param price The sale price in wei (must be greater than zero).
     * @return listingId The ID of the newly created listing.
     */
    function listToken(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external returns (uint256 listingId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (
            nft.getApproved(tokenId) != address(this) &&
            !nft.isApprovedForAll(msg.sender, address(this))
        ) revert NotApprovedMarketplace();

        listingId = _nextListingId++;
        _listings[listingId] = Listing({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: payable(msg.sender),
            price: price,
            active: true
        });

        emit Listed(listingId, msg.sender, nftContract, tokenId, price);
    }

    /**
     * @notice Cancel an active listing. Only the original seller may cancel.
     * @param listingId The ID of the listing to cancel.
     */
    function cancelListing(uint256 listingId) external {
        Listing storage l = _listings[listingId];
        if (!l.active) revert ListingNotActive();
        if (l.seller != msg.sender) revert NotListingSeller();

        l.active = false;
        emit ListingCanceled(listingId, msg.sender);
    }

    /**
     * @notice Purchase a listed token by sending exactly the listing price.
     *         The token is transferred directly from the seller to the buyer;
     *         the marketplace never takes custody. The platform fee is accrued
     *         to the fee recipient's withdrawable balance (pull payment), and the
     *         remainder is sent to the seller.
     * @param listingId The ID of the listing to purchase.
     */
    function buyToken(uint256 listingId) external payable {
        Listing storage l = _listings[listingId];
        if (!l.active) revert ListingNotActive();
        if (msg.value != l.price) revert IncorrectPayment(l.price, msg.value);

        // Re-validate ownership/approval at purchase time to avoid stale listings.
        IERC721 nft = IERC721(l.nftContract);
        if (nft.ownerOf(l.tokenId) != l.seller) revert NotTokenOwner();
        if (
            nft.getApproved(l.tokenId) != address(this) &&
            !nft.isApprovedForAll(l.seller, address(this))
        ) revert NotApprovedMarketplace();

        // Effects: deactivate listing and accrue fee before external interactions.
        address payable seller = l.seller;
        address nftContract = l.nftContract;
        uint256 tokenId = l.tokenId;
        uint256 price = l.price;
        l.active = false;

        uint256 fee = (price * feeBps) / 10000;
        uint256 sellerProceeds = price - fee;

        if (fee > 0) {
            pendingFees[feeRecipient] += fee;
            emit FeesAccrued(feeRecipient, fee);
        }

        // Interactions: transfer NFT directly from seller to buyer.
        nft.safeTransferFrom(seller, msg.sender, tokenId);

        // Distribute payment remainder to seller.
        if (sellerProceeds > 0) {
            (bool sellerOk, ) = seller.call{value: sellerProceeds}("");
            if (!sellerOk) revert TransferFailed();
        }

        emit Purchased(listingId, msg.sender, seller, nftContract, tokenId, price, fee);
    }

    /**
     * @notice Allows the fee recipient to withdraw accrued platform fees.
     */
    function withdrawFees() external {
        uint256 amount = pendingFees[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        pendingFees[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit FeesWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Update the platform fee in basis points. Only callable by the operator.
     * @param newFeeBps The new fee in basis points (must be <= 10000).
     */
    function updateFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > 10000) revert InvalidFeeBps(newFeeBps);
        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        emit FeeBpsUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Update the address that receives platform fees. Only callable by the operator.
     * @param newRecipient The new fee recipient address.
     */
    function updateFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @notice Transfer operator privileges to a new address. Only callable by the current operator.
     * @param newOperator The address of the new operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }
}
