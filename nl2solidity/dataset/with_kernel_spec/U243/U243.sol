// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DigitalAssetMarketplace
 * @notice A marketplace for unique digital assets.
 *
 * The contract maintains a registry of minted assets, tracks ownership, and
 * acts as the escrow agent during active sales. When an asset is listed for
 * sale it is effectively escrowed by the marketplace (it cannot be transferred
 * until it is sold or delisted). When an asset is purchased, the buyer's
 * payment is split between a configurable platform fee (capped at 2% of the
 * sale price) which is credited to the contract owner, and seller proceeds
 * which are credited to the seller's internal balance until they withdraw them.
 *
 * Only addresses designated by the contract owner as approved minters may mint
 * new assets, and no minter may mint more than `MAX_MINT_PER_USER` assets.
 */
contract DigitalAssetMarketplace {
    // -----------------------------------------------------------------------
    //                              Custom Errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotApprovedMinter();
    error AssetNotFound();
    error NotAssetOwner();
    error AssetAlreadyListed();
    error AssetNotListed();
    error InsufficientPayment();
    error MintLimitExceeded();
    error NothingToWithdraw();
    error WithdrawFailed();
    error RefundFailed();
    error CannotTransferListedAsset();
    error InvalidRecipient();
    error FeeExceedsCap();
    error ZeroPrice();

    // -----------------------------------------------------------------------
    //                                Events
    // -----------------------------------------------------------------------
    event AssetListed(uint256 indexed assetId, address indexed seller, uint256 price);
    event AssetDelisted(uint256 indexed assetId, address indexed seller);
    event AssetSold(
        uint256 indexed assetId,
        address indexed seller,
        address indexed buyer,
        uint256 price,
        uint256 fee
    );
    event AssetMinted(
        uint256 indexed assetId,
        address indexed minter,
        address indexed owner,
        string metadataURI
    );
    event FundsWithdrawn(address indexed user, uint256 amount);
    event MinterApproved(address indexed minter);
    event MinterRevoked(address indexed minter);
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OwnershipTransferred(uint256 indexed assetId, address indexed from, address indexed to);

    // -----------------------------------------------------------------------
    //                              Constants
    // -----------------------------------------------------------------------
    /// @notice Maximum number of assets a single minter may mint.
    uint256 public constant MAX_MINT_PER_USER = 100;
    /// @notice Hard cap on the platform fee in basis points (2% = 200 bps).
    uint256 public constant FEE_CAP_BPS = 200;
    /// @notice Internal basis-points denominator.
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // -----------------------------------------------------------------------
    //                                Storage
    // -----------------------------------------------------------------------
    /// @notice Current contract owner / fee recipient.
    address public owner;
    /// @notice Platform fee expressed in basis points (200 == 2%).
    uint256 public platformFeeBps;

    struct Asset {
        address owner;
        uint256 price;
        bool listed;
        string metadataURI;
    }

    /// @dev Canonical asset registry indexed by asset id.
    mapping(uint256 => Asset) private _assets;
    /// @dev Withdrawable ETH balances credited from sales.
    mapping(address => uint256) private _balances;
    /// @dev Number of assets minted by each address.
    mapping(address => uint256) private _mintCount;
    /// @dev Allowlist of addresses permitted to mint new assets.
    mapping(address => bool) private _approvedMinters;
    /// @dev Next asset id to assign; starts at 1 so id 0 is reserved as "none".
    uint256 private _nextAssetId;

    // -----------------------------------------------------------------------
    //                               Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyApprovedMinter() {
        if (!_approvedMinters[msg.sender]) revert NotApprovedMinter();
        _;
    }

    // -----------------------------------------------------------------------
    //                              Constructor
    // -----------------------------------------------------------------------
    /**
     * @param initialFeeBps Initial platform fee in basis points (e.g. 200 = 2%).
     *                      Must be less than or equal to `FEE_CAP_BPS`.
     */
    constructor(uint256 initialFeeBps) {
        if (initialFeeBps > FEE_CAP_BPS) revert FeeExceedsCap();
        owner = msg.sender;
        platformFeeBps = initialFeeBps;
        _nextAssetId = 1;
    }

    // -----------------------------------------------------------------------
    //                       Owner Administration Functions
    // -----------------------------------------------------------------------
    /**
     * @notice Updates the platform fee charged on each sale.
     * @param newFeeBps New fee in basis points; cannot exceed `FEE_CAP_BPS`.
     */
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > FEE_CAP_BPS) revert FeeExceedsCap();
        emit PlatformFeeUpdated(platformFeeBps, newFeeBps);
        platformFeeBps = newFeeBps;
    }

    /**
     * @notice Grants minting privileges to `minter`.
     */
    function approveMinter(address minter) external onlyOwner {
        if (minter == address(0)) revert InvalidRecipient();
        _approvedMinters[minter] = true;
        emit MinterApproved(minter);
    }

    /**
     * @notice Revokes minting privileges from `minter`.
     */
    function revokeMinter(address minter) external onlyOwner {
        _approvedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    /**
     * @notice Transfers contract ownership to a new address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidRecipient();
        owner = newOwner;
    }

    // -----------------------------------------------------------------------
    //                             Minting Function
    // -----------------------------------------------------------------------
    /**
     * @notice Mints a new unique digital asset owned by `to`.
     * @param to          Recipient of the newly minted asset.
     * @param metadataURI Off-chain metadata URI describing the asset.
     * @return assetId    The id of the newly minted asset.
     */
    function mint(address to, string calldata metadataURI)
        external
        onlyApprovedMinter
        returns (uint256 assetId)
    {
        if (to == address(0)) revert InvalidRecipient();
        if (_mintCount[msg.sender] >= MAX_MINT_PER_USER) revert MintLimitExceeded();

        assetId = _nextAssetId++;
        _assets[assetId] = Asset({
            owner: to,
            price: 0,
            listed: false,
            metadataURI: metadataURI
        });

        // Increment is bounded by MAX_MINT_PER_USER (100), so no overflow risk.
        unchecked {
            _mintCount[msg.sender] += 1;
        }

        emit AssetMinted(assetId, msg.sender, to, metadataURI);
    }

    // -----------------------------------------------------------------------
    //                          Listing / Sale Functions
    // -----------------------------------------------------------------------
    /**
     * @notice Lists an asset owned by the caller for sale at `price`.
     *         While listed, the asset is escrowed and cannot be transferred
     *         directly; ownership changes only through `purchase`.
     * @param assetId Id of the asset to list.
     * @param price   Sale price in wei; must be greater than 0.
     */
    function listAsset(uint256 assetId, uint256 price) external {
        Asset storage asset = _assets[assetId];
        if (asset.owner == address(0)) revert AssetNotFound();
        if (asset.owner != msg.sender) revert NotAssetOwner();
        if (asset.listed) revert AssetAlreadyListed();
        if (price == 0) revert ZeroPrice();

        asset.price = price;
        asset.listed = true;

        emit AssetListed(assetId, msg.sender, price);
    }

    /**
     * @notice Removes a listing created by the caller, releasing the asset
     *         from escrow without changing ownership.
     */
    function delistAsset(uint256 assetId) external {
        Asset storage asset = _assets[assetId];
        if (asset.owner == address(0)) revert AssetNotFound();
        if (asset.owner != msg.sender) revert NotAssetOwner();
        if (!asset.listed) revert AssetNotListed();

        asset.listed = false;
        asset.price = 0;

        emit AssetDelisted(assetId, msg.sender);
    }

    /**
     * @notice Purchases a listed asset, sending the sale price (minus the
     *         platform fee) to the seller's withdrawable balance and the fee
     *         to the owner's withdrawable balance. Any excess ETH sent is
     *         refunded to the caller.
     * @param assetId Id of the asset to purchase.
     */
    function purchase(uint256 assetId) external payable {
        Asset storage asset = _assets[assetId];
        if (!asset.listed) revert AssetNotListed();
        if (msg.value < asset.price) revert InsufficientPayment();

        address seller = asset.owner;
        uint256 salePrice = asset.price;
        uint256 fee = (salePrice * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = salePrice - fee;

        // ----- Effects -----
        asset.listed = false;
        asset.owner = msg.sender;
        asset.price = 0;

        _balances[seller] += sellerProceeds;
        _balances[owner] += fee;

        // ----- Interactions: refund any overpayment -----
        uint256 refund = msg.value - salePrice;
        if (refund > 0) {
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            if (!ok) revert RefundFailed();
        }

        emit AssetSold(assetId, seller, msg.sender, salePrice, fee);
    }

    // -----------------------------------------------------------------------
    //                           Withdrawal Function
    // -----------------------------------------------------------------------
    /**
     * @notice Withdraws the caller's accumulated sale proceeds and fees.
     */
    function withdraw() external {
        uint256 amount = _balances[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Checks-effects-interactions: clear before the external call.
        _balances[msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert WithdrawFailed();

        emit FundsWithdrawn(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    //                          Asset Transfer Function
    // -----------------------------------------------------------------------
    /**
     * @notice Transfers an unlisted asset to a new owner. Listed assets cannot
     *         be transferred directly; they must be sold or delisted first.
     */
    function transferAsset(uint256 assetId, address to) external {
        Asset storage asset = _assets[assetId];
        if (asset.owner == address(0)) revert AssetNotFound();
        if (asset.owner != msg.sender) revert NotAssetOwner();
        if (asset.listed) revert CannotTransferListedAsset();
        if (to == address(0)) revert InvalidRecipient();

        address from = msg.sender;
        asset.owner = to;

        emit OwnershipTransferred(assetId, from, to);
    }

    // -----------------------------------------------------------------------
    //                              View Functions
    // -----------------------------------------------------------------------
    /**
     * @notice Returns the full record for an asset.
     */
    function getAsset(uint256 assetId)
        external
        view
        returns (
            address assetOwner,
            uint256 price,
            bool listed,
            string memory metadataURI
        )
    {
        Asset storage asset = _assets[assetId];
        if (asset.owner == address(0)) revert AssetNotFound();
        return (asset.owner, asset.price, asset.listed, asset.metadataURI);
    }

    /**
     * @notice Returns the current owner of an asset.
     */
    function ownerOf(uint256 assetId) external view returns (address) {
        address assetOwner = _assets[assetId].owner;
        if (assetOwner == address(0)) revert AssetNotFound();
        return assetOwner;
    }

    /**
     * @notice Returns the withdrawable balance of `user`.
     */
    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    /**
     * @notice Returns how many assets `user` has minted so far.
     */
    function mintCountOf(address user) external view returns (uint256) {
        return _mintCount[user];
    }

    /**
     * @notice Returns whether `minter` is permitted to mint new assets.
     */
    function isApprovedMinter(address minter) external view returns (bool) {
        return _approvedMinters[minter];
    }

    /**
     * @notice Returns the total number of assets ever minted by this contract.
     */
    function totalAssets() external view returns (uint256) {
        // _nextAssetId starts at 1 and only ever increments, so this is safe.
        return _nextAssetId - 1;
    }

    /**
     * @notice Returns the next asset id that will be assigned on mint.
     */
    function nextAssetId() external view returns (uint256) {
        return _nextAssetId;
    }
}
