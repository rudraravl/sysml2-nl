// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VaultCollectibleMarket
/// @notice Marketplace for trading unique digital collectibles that represent vaulted physical assets.
///         The contract holds no fungible tokens; it tracks ownership of non-fungible collectibles
///         and facilitates their listing, sale, and transfer. A platform fee (default 2.5%, capped
///         at 10%) is deducted from each successful purchase and can be withdrawn only by the
///         designated operator.
contract VaultCollectibleMarket {
    /* ------------------------------------------------------------------ */
    /*                              Errors                                */
    /* ------------------------------------------------------------------ */
    error NotOperator();
    error NotOwner();
    error TokenDoesNotExist();
    error AlreadyListed();
    error NotListed();
    error ZeroAddress();
    error PriceMustBeGreaterThanZero();
    error InsufficientPayment();
    error FeeTooHigh();
    error NoFeesToWithdraw();
    error SelfTransfer();
    error PaymentFailed();
    error ReentrantCall();

    /* ------------------------------------------------------------------ */
    /*                             Constants                              */
    /* ------------------------------------------------------------------ */
    /// @dev Maximum allowed platform fee in basis points (10%).
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10000;
    /// @dev Initial platform fee representing 2.5%.
    uint256 public constant DEFAULT_FEE_BPS = 250;

    /* ------------------------------------------------------------------ */
    /*                              Storage                               */
    /* ------------------------------------------------------------------ */
    address public operator;
    uint256 public platformFeeBps;
    uint256 public accumulatedFees;
    uint256 public nextTokenId;

    struct Collectible {
        address owner;
        bool isListed;
        uint256 salePrice;
        string metadataURI;
    }

    mapping(uint256 => Collectible) private _collectibles;

    uint256 private _locked; // reentrancy guard

    /* ------------------------------------------------------------------ */
    /*                              Events                                 */
    /* ------------------------------------------------------------------ */
    event Minted(uint256 indexed tokenId, address indexed to, string metadataURI);
    event Listed(uint256 indexed tokenId, address indexed owner, uint256 salePrice);
    event Delisted(uint256 indexed tokenId, address indexed owner);
    event Purchased(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 salePrice,
        uint256 fee
    );
    event Transferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event PlatformFeeUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed operator, address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    /* ------------------------------------------------------------------ */
    /*                            Modifiers                               */
    /* ------------------------------------------------------------------ */
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    /* ------------------------------------------------------------------ */
    /*                            Constructor                              */
    /* ------------------------------------------------------------------ */
    constructor() {
        operator = msg.sender;
        platformFeeBps = DEFAULT_FEE_BPS; // 2.5%
        nextTokenId = 1;
        emit PlatformFeeUpdated(address(0), 0, DEFAULT_FEE_BPS);
        emit OperatorChanged(address(0), msg.sender);
    }

    /* ------------------------------------------------------------------ */
    /*                      Operator-only functions                        */
    /* ------------------------------------------------------------------ */

    /// @notice Sets a new platform fee percentage, expressed in basis points (250 = 2.5%).
    function setPlatformFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(msg.sender, old, newFeeBps);
    }

    /// @notice Withdraws all accumulated platform fees to `recipient`.
    function withdrawFees(address payable recipient) external onlyOperator nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();
        // Effects
        accumulatedFees = 0;
        // Interactions
        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert PaymentFailed();
        emit FeesWithdrawn(msg.sender, recipient, amount);
    }

    /// @notice Mints a new collectible representing a vaulted physical asset to `to`.
    function mint(address to, string calldata metadataURI)
        external
        onlyOperator
        returns (uint256 tokenId)
    {
        if (to == address(0)) revert ZeroAddress();
        tokenId = nextTokenId++;
        _collectibles[tokenId] = Collectible({
            owner: to,
            isListed: false,
            salePrice: 0,
            metadataURI: metadataURI
        });
        emit Minted(tokenId, to, metadataURI);
        emit Transferred(tokenId, address(0), to);
    }

    /// @notice Transfers operator role to a new address.
    function changeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    /* ------------------------------------------------------------------ */
    /*                        Market functions                            */
    /* ------------------------------------------------------------------ */

    /// @notice Lists a collectible for sale at `salePrice`. Reverts if already listed.
    function list(uint256 tokenId, uint256 salePrice) external {
        Collectible storage c = _collectibles[tokenId];
        if (c.owner == address(0)) revert TokenDoesNotExist();
        if (c.owner != msg.sender) revert NotOwner();
        if (c.isListed) revert AlreadyListed();
        if (salePrice == 0) revert PriceMustBeGreaterThanZero();
        c.isListed = true;
        c.salePrice = salePrice;
        emit Listed(tokenId, msg.sender, salePrice);
    }

    /// @notice Removes a collectible from the active sale listing.
    function delist(uint256 tokenId) external {
        Collectible storage c = _collectibles[tokenId];
        if (c.owner == address(0)) revert TokenDoesNotExist();
        if (c.owner != msg.sender) revert NotOwner();
        if (!c.isListed) revert NotListed();
        c.isListed = false;
        c.salePrice = 0;
        emit Delisted(tokenId, msg.sender);
    }

    /// @notice Purchases a listed collectible. Payment must be at least the sale price;
    ///         excess is refunded. The platform fee is retained; the remainder pays the seller.
    function purchase(uint256 tokenId) external payable nonReentrant {
        Collectible storage c = _collectibles[tokenId];
        if (c.owner == address(0)) revert TokenDoesNotExist();
        if (!c.isListed) revert NotListed();
        if (c.owner == msg.sender) revert SelfTransfer();

        uint256 salePrice = c.salePrice;
        if (msg.value < salePrice) revert InsufficientPayment();

        address seller = c.owner;
        uint256 fee = (salePrice * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = salePrice - fee;

        // Effects
        c.owner = msg.sender;
        c.isListed = false;
        c.salePrice = 0;
        accumulatedFees += fee;

        // Interactions
        if (sellerProceeds > 0) {
            (bool ok, ) = payable(seller).call{value: sellerProceeds}("");
            if (!ok) revert PaymentFailed();
        }

        uint256 excess = msg.value - salePrice;
        if (excess > 0) {
            (bool ok2, ) = payable(msg.sender).call{value: excess}("");
            if (!ok2) revert PaymentFailed();
        }

        emit Purchased(tokenId, seller, msg.sender, salePrice, fee);
        emit Transferred(tokenId, seller, msg.sender);
    }

    /// @notice Transfers ownership of a collectible to another account. Auto-delists if listed.
    function transfer(address to, uint256 tokenId) external {
        if (to == address(0)) revert ZeroAddress();
        Collectible storage c = _collectibles[tokenId];
        if (c.owner == address(0)) revert TokenDoesNotExist();
        if (c.owner != msg.sender) revert NotOwner();
        if (to == msg.sender) revert SelfTransfer();

        address from = c.owner;
        if (c.isListed) {
            c.isListed = false;
            c.salePrice = 0;
            emit Delisted(tokenId, from);
        }
        c.owner = to;
        emit Transferred(tokenId, from, to);
    }

    /* ------------------------------------------------------------------ */
    /*                            View functions                          */
    /* ------------------------------------------------------------------ */

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _collectibles[tokenId].owner;
    }

    function isListed(uint256 tokenId) external view returns (bool) {
        return _collectibles[tokenId].isListed;
    }

    function salePriceOf(uint256 tokenId) external view returns (uint256) {
        return _collectibles[tokenId].salePrice;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return _collectibles[tokenId].metadataURI;
    }

    function getCollectible(uint256 tokenId)
        external
        view
        returns (address owner, bool listed, uint256 salePrice, string memory uri)
    {
        Collectible storage c = _collectibles[tokenId];
        return (c.owner, c.isListed, c.salePrice, c.metadataURI);
    }
}
