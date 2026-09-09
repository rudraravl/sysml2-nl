// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ArtMarketplace
/// @notice Digital art registry and marketplace for ERC721-style artwork tokens
///         with creator royalties (0–15%), a capped platform fee (≤5%), and
///         fixed-price listings.
contract ArtMarketplace {
    /* =============================================================
                            EVENTS
    ============================================================= */
    event Minted(
        uint256 indexed tokenId,
        address indexed creator,
        address indexed to,
        uint256 royaltyBps,
        string uri
    );
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Delisted(uint256 indexed tokenId, address indexed seller);
    event Purchased(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price,
        uint256 platformFee,
        uint256 royalty
    );
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MinterStatusUpdated(address indexed minter, bool status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PlatformFeeWithdrawn(address indexed to, uint256 amount);
    event RoyaltiesClaimed(address indexed creator, uint256 amount);

    /* =============================================================
                            ERRORS
    ============================================================= */
    error ZeroAddress();
    error NotAuthorized();
    error NotApprovedMinter();
    error TokenNotMinted();
    error InvalidRoyalty();
    error InvalidFee();
    error InvalidPrice();
    error NotForSale();
    error InsufficientPayment();
    error NotListedByCaller();
    error SelfPurchase();
    error UnsafeRecipient();
    error PaymentFailed();
    error NothingToWithdraw();

    /* =============================================================
                            CONSTANTS
    ============================================================= */
    uint256 public constant MAX_PLATFORM_FEE_BPS = 500; // 5%
    uint256 public constant MAX_ROYALTY_BPS = 1500; // 15%
    uint256 private constant BPS = 10000;

    /* =============================================================
                            STORAGE
    ============================================================= */
    address public owner;
    uint256 public platformFeeBps;
    uint256 public nextTokenId;

    string public name;
    string public symbol;

    mapping(address => bool) public approvedMinters;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    struct Artwork {
        address creator;
        uint256 royaltyBps;
        string uri;
    }
    mapping(uint256 => Artwork) internal _artworks;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }
    mapping(uint256 => Listing) internal _listings;

    uint256 public pendingPlatformFees;
    mapping(address => uint256) public pendingRoyalties;

    /* =============================================================
                            MODIFIERS
    ============================================================= */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyApprovedMinter() {
        if (!approvedMinters[msg.sender]) revert NotApprovedMinter();
        _;
    }

    /* =============================================================
                            CONSTRUCTOR
    ============================================================= */
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        uint256 _initialFeeBps
    ) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_initialFeeBps > MAX_PLATFORM_FEE_BPS) revert InvalidFee();
        name = _name;
        symbol = _symbol;
        owner = _owner;
        platformFeeBps = _initialFeeBps;
        nextTokenId = 1;
        emit OwnershipTransferred(address(0), _owner);
        emit PlatformFeeUpdated(0, _initialFeeBps);
    }

    /* =============================================================
                       ERC165 / INTROSPECTION
    ============================================================= */
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    /* =============================================================
                    ADMIN: OWNERSHIP & CONFIGURATION
    ============================================================= */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_PLATFORM_FEE_BPS) revert InvalidFee();
        uint256 old = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(old, newFeeBps);
    }

    function setMinter(address minter, bool status) external onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        approvedMinters[minter] = status;
        emit MinterStatusUpdated(minter, status);
    }

    function withdrawPlatformFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = pendingPlatformFees;
        if (amount == 0) revert NothingToWithdraw();
        pendingPlatformFees = 0;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert PaymentFailed();
        emit PlatformFeeWithdrawn(to, amount);
    }

    function claimRoyalties() external {
        uint256 amount = pendingRoyalties[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        pendingRoyalties[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert PaymentFailed();
        emit RoyaltiesClaimed(msg.sender, amount);
    }

    /* =============================================================
                       ERC721 VIEWS
    ============================================================= */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address o = _ownerOf[tokenId];
        if (o == address(0)) revert TokenNotMinted();
        return o;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balanceOf[account];
    }

    function totalSupply() public view returns (uint256) {
        return nextTokenId - 1;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenNotMinted();
        return _artworks[tokenId].uri;
    }

    function getCreator(uint256 tokenId) public view returns (address) {
        if (_ownerOf[tokenId] == address(0)) revert TokenNotMinted();
        return _artworks[tokenId].creator;
    }

    function getRoyaltyBps(uint256 tokenId) public view returns (uint256) {
        if (_ownerOf[tokenId] == address(0)) revert TokenNotMinted();
        return _artworks[tokenId].royaltyBps;
    }

    function getListing(uint256 tokenId)
        external
        view
        returns (address seller, uint256 price, bool active)
    {
        Listing memory l = _listings[tokenId];
        return (l.seller, l.price, l.active);
    }

    function getArtwork(uint256 tokenId)
        external
        view
        returns (address creator, uint256 royaltyBps, string memory uri)
    {
        if (_ownerOf[tokenId] == address(0)) revert TokenNotMinted();
        Artwork memory a = _artworks[tokenId];
        return (a.creator, a.royaltyBps, a.uri);
    }

    /* =============================================================
                       ERC721 APPROVALS
    ============================================================= */
    function approve(address approved, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        if (msg.sender != tokenOwner && !isApprovedForAll[tokenOwner][msg.sender]) {
            revert NotAuthorized();
        }
        getApproved[tokenId] = approved;
        emit Approval(tokenOwner, approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public {
        if (operator == address(0)) revert ZeroAddress();
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /* =============================================================
                       INTERNAL HELPERS
    ============================================================= */
    function _isAuthorized(
        address spender,
        address tokenOwner,
        uint256 tokenId
    ) internal view returns (bool) {
        return spender == tokenOwner ||
            isApprovedForAll[tokenOwner][spender] ||
            getApproved[tokenId] == spender;
    }

    function _clearListingIfActive(uint256 tokenId) internal {
        if (_listings[tokenId].active) {
            address seller = _listings[tokenId].seller;
            delete _listings[tokenId];
            emit Delisted(tokenId, seller);
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        address tokenOwner = ownerOf(tokenId);
        if (from != tokenOwner) revert NotAuthorized();
        if (!_isAuthorized(msg.sender, tokenOwner, tokenId)) revert NotAuthorized();

        delete getApproved[tokenId];
        _clearListingIfActive(tokenId);

        unchecked {
            _balanceOf[from] -= 1;
            _balanceOf[to] += 1;
        }
        _ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            (bool ok, bytes memory ret) = to.call(
                abi.encodeWithSignature(
                    "onERC721Received(address,address,uint256,bytes)",
                    msg.sender,
                    from,
                    tokenId,
                    data
                )
            );
            if (!ok) revert UnsafeRecipient();
            if (bytes4(ret) != 0x150b7a02) revert UnsafeRecipient();
        }
    }

    /* =============================================================
                       ERC721 TRANSFERS
    ============================================================= */
    function transferFrom(address from, address to, uint256 tokenId) public {
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) public {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /* =============================================================
                            MINTING
    ============================================================= */
    /// @notice Mint a new artwork token. Only callable by approved minters.
    /// @param to Recipient and initial owner of the new token.
    /// @param royaltyBps Creator royalty in basis points (0–1500).
    /// @param uri Metadata URI for the artwork.
    function mint(
        address to,
        uint256 royaltyBps,
        string calldata uri
    ) external onlyApprovedMinter returns (uint256) {
        if (to == address(0)) revert ZeroAddress();
        if (royaltyBps > MAX_ROYALTY_BPS) revert InvalidRoyalty();

        uint256 tokenId = nextTokenId++;
        _ownerOf[tokenId] = to;
        unchecked {
            _balanceOf[to] += 1;
        }
        _artworks[tokenId] = Artwork({
            creator: msg.sender,
            royaltyBps: royaltyBps,
            uri: uri
        });

        emit Minted(tokenId, msg.sender, to, royaltyBps, uri);
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }

    /* =============================================================
                       MARKETPLACE: LISTING
    ============================================================= */
    function listToken(uint256 tokenId, uint256 price) external {
        if (price == 0) revert InvalidPrice();
        address tokenOwner = ownerOf(tokenId);
        if (msg.sender != tokenOwner) revert NotAuthorized();
        if (_listings[tokenId].active) revert NotForSale();
        _listings[tokenId] = Listing({
            seller: tokenOwner,
            price: price,
            active: true
        });
        emit Listed(tokenId, tokenOwner, price);
    }

    function delistToken(uint256 tokenId) external {
        Listing storage l = _listings[tokenId];
        if (!l.active) revert NotForSale();
        if (msg.sender != l.seller) revert NotListedByCaller();
        delete _listings[tokenId];
        emit Delisted(tokenId, msg.sender);
    }

    /* =============================================================
                       MARKETPLACE: PURCHASE
    ============================================================= */
    /// @notice Buy a listed token. Sends platform fee and creator royalty
    ///         to withdrawable balances and the remainder to the seller.
    function buyToken(uint256 tokenId) external payable {
        Listing memory l = _listings[tokenId];
        if (!l.active) revert NotForSale();
        if (msg.value < l.price) revert InsufficientPayment();
        if (msg.sender == l.seller) revert SelfPurchase();

        address seller = l.seller;
        address buyer = msg.sender;
        uint256 price = l.price;
        Artwork memory art = _artworks[tokenId];

        /* ----- Effects ----- */
        delete _listings[tokenId];
        delete getApproved[tokenId];

        unchecked {
            _balanceOf[seller] -= 1;
            _balanceOf[buyer] += 1;
        }
        _ownerOf[tokenId] = buyer;

        uint256 fee = (price * platformFeeBps) / BPS;
        uint256 royalty = (price * art.royaltyBps) / BPS;
        uint256 sellerProceeds = price - fee - royalty;

        if (fee > 0) {
            pendingPlatformFees += fee;
        }
        if (royalty > 0 && art.creator != address(0)) {
            pendingRoyalties[art.creator] += royalty;
        }

        emit Delisted(tokenId, seller);
        emit Transfer(seller, buyer, tokenId);
        emit Purchased(tokenId, seller, buyer, price, fee, royalty);

        /* ----- Interactions ----- */
        // Refund excess payment to buyer first.
        if (msg.value > price) {
            (bool rOk, ) = payable(buyer).call{value: msg.value - price}("");
            if (!rOk) revert PaymentFailed();
        }
        // Push seller proceeds (seller is the active party who chose to list).
        if (sellerProceeds > 0) {
            (bool sOk, ) = payable(seller).call{value: sellerProceeds}("");
            if (!sOk) revert PaymentFailed();
        }
    }

    /* =============================================================
                       ROYALTY INFO (ERC2981-compatible view)
    ============================================================= */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        if (_ownerOf[tokenId] == address(0)) revert TokenNotMinted();
        Artwork memory art = _artworks[tokenId];
        receiver = art.creator;
        royaltyAmount = (salePrice * art.royaltyBps) / BPS;
    }

    receive() external payable {}
}
