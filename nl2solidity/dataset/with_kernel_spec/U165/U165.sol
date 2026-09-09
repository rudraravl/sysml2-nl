// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title GradedCollectibleMarketplace
 * @notice A peer-to-peer marketplace for unique, graded digital collectibles
 *         (ERC-721 tokens). Sellers list collectibles at a fixed price; the
 *         marketplace holds the token in escrow until the listing is purchased
 *         or canceled. A configurable platform fee, capped at 5%, is withheld
 *         from the sale proceeds and accrues to the fee recipient.
 */
contract GradedCollectibleMarketplace is IERC721Receiver, ReentrancyGuard {
    // ───────────────────────── Constants ─────────────────────────

    /// @dev Maximum platform fee in basis points (5% = 500 bps).
    uint16 public constant MAX_PLATFORM_FEE_BPS = 500;

    /// @dev Basis points denominator.
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ───────────────────────── Immutables ────────────────────────

    /// @notice The ERC-721 contract backing the graded collectibles.
    IERC721 public immutable collectibleContract;

    /// @notice The address entitled to withdraw accumulated platform fees.
    address public immutable feeRecipient;

    // ───────────────────────── State ─────────────────────────────

    /// @notice Current platform fee in basis points (e.g., 250 = 2.5%).
    uint16 public platformFeeBps;

    /// @notice Address authorized to adjust the platform fee.
    address public operator;

    /// @notice Total accumulated, unwithdrawn platform fees (in wei).
    uint256 public accumulatedFees;

    /// @notice Number of currently active listings.
    uint256 public activeListingCount;

    /// @notice Total number of completed sales.
    uint256 public totalSales;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    /// @notice Registry of all listings keyed by token ID.
    mapping(uint256 tokenId => Listing listing) internal _listings;

    // ───────────────────────── Events ────────────────────────────

    event CollectibleListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event CollectibleSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price,
        uint256 fee
    );
    event ListingCanceled(uint256 indexed tokenId, address indexed seller);
    event PlatformFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event OperatorUpdated(address oldOperator, address newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ───────────────────────── Errors ────────────────────────────

    error ZeroAddress();
    error FeeExceedsMax();
    error PriceZero();
    error NotTokenOwner();
    error TokenNotApproved();
    error AlreadyListed();
    error ListingNotActive();
    error NotSeller();
    error SelfPurchase();
    error IncorrectPayment();
    error TransferFailed();
    error NoFeesToWithdraw();
    error OnlyOperator();

    // ───────────────────────── Modifiers ────────────────────────

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // ───────────────────────── Constructor ──────────────────────

    /**
     * @param _collectibleContract Address of the ERC-721 collectible contract.
     * @param _feeRecipient        Address that receives withdrawn platform fees.
     * @param _operator            Address authorized to adjust the platform fee.
     * @param _initialFeeBps       Initial platform fee in basis points (<= 500).
     */
    constructor(
        address _collectibleContract,
        address _feeRecipient,
        address _operator,
        uint16 _initialFeeBps
    ) {
        if (_collectibleContract == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialFeeBps > MAX_PLATFORM_FEE_BPS) revert FeeExceedsMax();

        collectibleContract = IERC721(_collectibleContract);
        feeRecipient = _feeRecipient;
        operator = _operator;
        platformFeeBps = _initialFeeBps;

        emit OperatorUpdated(address(0), _operator);
        emit PlatformFeeUpdated(0, _initialFeeBps);
    }

    // ───────────────────────── Listing ──────────────────────────

    /**
     * @notice List a graded collectible for sale. The caller must own the token
     *         and have approved this contract to transfer it. The token is moved
     *         into escrow until the listing is purchased or canceled.
     * @param tokenId The ID of the collectible to list.
     * @param price   The asking price in wei (must be greater than zero).
     */
    function listCollectible(uint256 tokenId, uint256 price) external nonReentrant {
        if (price == 0) revert PriceZero();
        if (collectibleContract.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (
            collectibleContract.getApproved(tokenId) != address(this) &&
            !collectibleContract.isApprovedForAll(msg.sender, address(this))
        ) {
            revert TokenNotApproved();
        }
        if (_listings[tokenId].active) revert AlreadyListed();

        // Effects: register listing before taking custody.
        _listings[tokenId] = Listing({seller: msg.sender, price: price, active: true});
        unchecked {
            ++activeListingCount;
        }

        // Interactions: pull the collectible into escrow.
        collectibleContract.safeTransferFrom(msg.sender, address(this), tokenId);

        emit CollectibleListed(tokenId, msg.sender, price);
    }

    /**
     * @notice Purchase a listed collectible. The caller must send exactly the
     *         listing price. The platform fee is withheld and accrues to the
     *         fee recipient; the remainder is sent to the seller.
     * @param tokenId The ID of the collectible to purchase.
     */
    function purchaseCollectible(uint256 tokenId) external payable nonReentrant {
        Listing storage listing = _listings[tokenId];
        if (!listing.active) revert ListingNotActive();

        address seller = listing.seller;
        uint256 price = listing.price;

        if (msg.sender == seller) revert SelfPurchase();
        if (msg.value != price) revert IncorrectPayment();

        // Effects: deactivate listing and settle accounting before transfers.
        listing.active = false;
        unchecked {
            --activeListingCount;
            ++totalSales;
        }

        uint256 fee = (price * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = price - fee;
        accumulatedFees += fee;

        // Interactions: deliver the collectible to the buyer.
        collectibleContract.safeTransferFrom(address(this), msg.sender, tokenId);

        // Interactions: pay the seller.
        if (sellerProceeds > 0) {
            (bool ok, ) = payable(seller).call{value: sellerProceeds}("");
            if (!ok) revert TransferFailed();
        }

        emit CollectibleSold(tokenId, seller, msg.sender, price, fee);
    }

    /**
     * @notice Cancel an active listing and return the collectible to the seller.
     *         Only the original seller may cancel.
     * @param tokenId The ID of the listed collectible.
     */
    function cancelListing(uint256 tokenId) external nonReentrant {
        Listing storage listing = _listings[tokenId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotSeller();

        // Effects: deactivate listing before returning the token.
        listing.active = false;
        unchecked {
            --activeListingCount;
        }

        // Interactions: return the collectible to the seller.
        collectibleContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit ListingCanceled(tokenId, msg.sender);
    }

    // ───────────────────────── Operator ─────────────────────────

    /**
     * @notice Update the platform fee. Only callable by the operator.
     * @param newFeeBps New fee in basis points (must be <= MAX_PLATFORM_FEE_BPS).
     */
    function setPlatformFee(uint16 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_PLATFORM_FEE_BPS) revert FeeExceedsMax();
        uint16 oldFeeBps = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Transfer the operator role to a new address. Only callable by the
     *         current operator.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    /**
     * @notice Withdraw accumulated platform fees to the fee recipient.
     *         Only callable by the operator.
     */
    function withdrawFees() external onlyOperator {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();

        // Effects: zero out balance before transfer.
        accumulatedFees = 0;

        // Interactions: send fees to the immutable fee recipient.
        (bool ok, ) = payable(feeRecipient).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit FeesWithdrawn(feeRecipient, amount);
    }

    // ───────────────────────── Views ────────────────────────────

    /**
     * @notice Get the listing details for a token.
     * @param tokenId The token ID to query.
     * @return seller  The address of the seller.
     * @return price   The asking price in wei.
     * @return active  Whether the listing is currently active.
     */
    function getListing(uint256 tokenId)
        external
        view
        returns (address seller, uint256 price, bool active)
    {
        Listing storage listing = _listings[tokenId];
        return (listing.seller, listing.price, listing.active);
    }

    /**
     * @notice Check whether a token is currently listed for sale.
     * @param tokenId The token ID to query.
     * @return True if the token has an active listing.
     */
    function isListed(uint256 tokenId) external view returns (bool) {
        return _listings[tokenId].active;
    }

    // ───────────────────────── ERC-721 Receiver ──────────────────

    /**
     * @notice Allows the marketplace to safely receive ERC-721 tokens into escrow.
     */
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
