// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

/**
 * @title NFTMarketplace
 * @notice A marketplace for unique digital assets where users deposit NFTs,
 *         list them for sale priced in a marketplace-specific ERC20 token,
 *         and trade with a configurable fee deducted from seller proceeds.
 */
contract NFTMarketplace {
    ////////////////////////////////////////////////////////////////
    //                          CUSTOM ERRORS                       //
    ////////////////////////////////////////////////////////////////
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InvalidPrice();
    error InvalidAmount();
    error InvalidFeePercentage();
    error WhenPaused();
    error NotAssetOwner();
    error AssetAlreadyListed();
    error AssetIsListed();
    error AssetNotDeposited();
    error ListingNotActive();
    error NotListingSeller();
    error InsufficientBalance();
    error MaxListingsReached();
    error ReentrantCall();
    error TransferFailed();

    ////////////////////////////////////////////////////////////////
    //                            EVENTS                            //
    ////////////////////////////////////////////////////////////////
    event AssetDeposited(address indexed depositor, uint256 indexed tokenId);
    event AssetWithdrawn(address indexed withdrawer, uint256 indexed tokenId);
    event AssetListed(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );
    event AssetPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );
    event ListingCancelled(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId);
    event TokensDeposited(address indexed depositor, uint256 amount);
    event TokensWithdrawn(address indexed withdrawer, uint256 amount);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);

    ////////////////////////////////////////////////////////////////
    //                            STRUCTS                           //
    ////////////////////////////////////////////////////////////////
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    ////////////////////////////////////////////////////////////////
    //                       STATE VARIABLES                        //
    ////////////////////////////////////////////////////////////////
    address public owner;
    address public operator;
    address public feeRecipient;

    IERC20 public immutable marketplaceToken;
    IERC721 public immutable nftContract;

    /// @dev Fee in basis points. 250 = 2.5%.
    uint256 public feePercentage;
    uint256 public constant MAX_FEE_PERCENTAGE = 10000;
    uint256 public constant MAX_LISTINGS_PER_USER = 50;

    uint256 private _nextListingId;
    bool public paused;

    /// @dev listingId => Listing
    mapping(uint256 => Listing) public listings;

    /// @dev user => marketplace token credit balance
    mapping(address => uint256) public tokenBalances;

    /// @dev user => number of currently active listings
    mapping(address => uint256) public activeListingCount;

    /// @dev tokenId => address that deposited the asset (address(0) if not deposited)
    mapping(uint256 => address) public assetOwners;

    /// @dev tokenId => active listingId (0 if not listed)
    mapping(uint256 => uint256) public assetListing;

    /// @dev Reentrancy guard
    uint256 private _locked = 1;

    ////////////////////////////////////////////////////////////////
    //                           MODIFIERS                         //
    ////////////////////////////////////////////////////////////////
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    ////////////////////////////////////////////////////////////////
    //                          CONSTRUCTOR                        //
    ////////////////////////////////////////////////////////////////
    constructor(
        address _marketplaceToken,
        address _nftContract,
        address _operator,
        address _feeRecipient
    ) {
        if (_marketplaceToken == address(0)) revert ZeroAddress();
        if (_nftContract == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        marketplaceToken = IERC20(_marketplaceToken);
        nftContract = IERC721(_nftContract);
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        feePercentage = 250; // 2.5%
        _nextListingId = 1;
    }

    ////////////////////////////////////////////////////////////////
    //                    ASSET DEPOSIT / WITHDRAW                 //
    ////////////////////////////////////////////////////////////////

    /// @notice Deposit an NFT into the marketplace custody.
    /// @dev Caller must have approved this contract to transfer the NFT.
    /// @param tokenId The token id of the NFT to deposit.
    function depositAsset(uint256 tokenId) external nonReentrant {
        nftContract.transferFrom(msg.sender, address(this), tokenId);
        assetOwners[tokenId] = msg.sender;
        emit AssetDeposited(msg.sender, tokenId);
    }

    /// @notice Withdraw a deposited NFT that is not currently listed.
    /// @param tokenId The token id of the NFT to withdraw.
    function withdrawAsset(uint256 tokenId) external nonReentrant {
        if (assetOwners[tokenId] != msg.sender) revert NotAssetOwner();
        if (assetListing[tokenId] != 0) revert AssetIsListed();

        delete assetOwners[tokenId];
        nftContract.transferFrom(address(this), msg.sender, tokenId);
        emit AssetWithdrawn(msg.sender, tokenId);
    }

    ////////////////////////////////////////////////////////////////
    //                       LISTING OPERATIONS                     //
    ////////////////////////////////////////////////////////////////

    /// @notice List a previously deposited asset for sale.
    /// @param tokenId The token id to list.
    /// @param price   The sale price in marketplace tokens (must be > 0).
    function listAsset(uint256 tokenId, uint256 price)
        external
        whenNotPaused
        nonReentrant
    {
        if (assetOwners[tokenId] != msg.sender) revert NotAssetOwner();
        if (assetListing[tokenId] != 0) revert AssetAlreadyListed();
        if (price == 0) revert InvalidPrice();
        if (activeListingCount[msg.sender] >= MAX_LISTINGS_PER_USER)
            revert MaxListingsReached();

        uint256 listingId = _nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            price: price,
            active: true
        });
        assetListing[tokenId] = listingId;
        activeListingCount[msg.sender]++;

        emit AssetListed(listingId, msg.sender, tokenId, price);
    }

    /// @notice Purchase an asset from an active listing.
    /// @dev Caller must have sufficient marketplace token credit balance.
    /// @param listingId The id of the listing to purchase.
    function buyAsset(uint256 listingId)
        external
        whenNotPaused
        nonReentrant
    {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();

        address seller = listing.seller;
        uint256 price = listing.price;
        uint256 tokenId = listing.tokenId;

        if (tokenBalances[msg.sender] < price) revert InsufficientBalance();

        // Calculate fee and seller proceeds
        uint256 fee = (price * feePercentage) / MAX_FEE_PERCENTAGE;
        uint256 sellerProceeds = price - fee;

        // ----- Effects -----
        tokenBalances[msg.sender] -= price;
        tokenBalances[seller] += sellerProceeds;
        tokenBalances[feeRecipient] += fee;

        listing.active = false;
        assetListing[tokenId] = 0;
        delete assetOwners[tokenId];
        activeListingCount[seller]--;

        // ----- Interactions -----
        nftContract.transferFrom(address(this), msg.sender, tokenId);

        emit AssetPurchased(listingId, msg.sender, seller, tokenId, price, fee);
    }

    /// @notice Cancel an active listing. The NFT remains in marketplace custody
    ///         and can be withdrawn or re-listed by the seller.
    /// @param listingId The id of the listing to cancel.
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotListingSeller();

        uint256 tokenId = listing.tokenId;

        listing.active = false;
        assetListing[tokenId] = 0;
        activeListingCount[msg.sender]--;

        emit ListingCancelled(listingId, msg.sender, tokenId);
    }

    ////////////////////////////////////////////////////////////////
    //                  MARKETPLACE TOKEN OPERATIONS               //
    ////////////////////////////////////////////////////////////////

    /// @notice Deposit marketplace tokens to obtain credit for purchases.
    /// @dev Caller must have approved this contract to spend the tokens.
    /// @param amount The amount of marketplace tokens to deposit.
    function depositTokens(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        // Effects
        tokenBalances[msg.sender] += amount;

        // Interactions
        bool success = marketplaceToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit TokensDeposited(msg.sender, amount);
    }

    /// @notice Withdraw marketplace token credit to the caller's wallet.
    /// @param amount The amount of marketplace tokens to withdraw.
    function withdrawTokens(uint256 amount) external nonReentrant {
        if (tokenBalances[msg.sender] < amount) revert InsufficientBalance();

        // Effects
        tokenBalances[msg.sender] -= amount;

        // Interactions
        bool success = marketplaceToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit TokensWithdrawn(msg.sender, amount);
    }

    ////////////////////////////////////////////////////////////////
    //                     OPERATOR FUNCTIONS                       //
    ////////////////////////////////////////////////////////////////

    /// @notice Set the marketplace fee percentage (in basis points).
    /// @dev Only callable by the operator. Max value is 10000 (100%).
    /// @param _feePercentage The new fee in basis points.
    function setFeePercentage(uint256 _feePercentage) external onlyOperator {
        if (_feePercentage > MAX_FEE_PERCENTAGE) revert InvalidFeePercentage();
        uint256 oldFee = feePercentage;
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(oldFee, _feePercentage);
    }

    /// @notice Pause or unpause all trading activity (listing and buying).
    /// @dev Only callable by the operator. Withdrawals remain available.
    /// @param _paused True to pause, false to unpause.
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    ////////////////////////////////////////////////////////////////
    //                       OWNER FUNCTIONS                        //
    ////////////////////////////////////////////////////////////////

    /// @notice Transfer the operator role to a new address.
    /// @param _operator The new operator address.
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    /// @notice Set the fee recipient address.
    /// @param _feeRecipient The new fee recipient address.
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(old, _feeRecipient);
    }

    ////////////////////////////////////////////////////////////////
    //                        VIEW FUNCTIONS                        //
    ////////////////////////////////////////////////////////////////

    /// @notice Retrieve full listing details.
    /// @param listingId The listing id to query.
    /// @return The Listing struct.
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /// @notice Get the active listing id for a given asset, if any.
    /// @param tokenId The token id to query.
    /// @return The listing id, or 0 if not listed.
    function getListingIdForAsset(uint256 tokenId) external view returns (uint256) {
        return assetListing[tokenId];
    }

    /// @notice Check whether an asset is currently listed.
    /// @param tokenId The token id to query.
    /// @return True if the asset has an active listing.
    function isAssetListed(uint256 tokenId) external view returns (bool) {
        return assetListing[tokenId] != 0;
    }

    /// @notice Get the number of active listings for a user.
    /// @param user The address to query.
    /// @return The count of active listings.
    function getActiveListingCount(address user) external view returns (uint256) {
        return activeListingCount[user];
    }

    /// @notice Get the marketplace token credit balance for a user.
    /// @param user The address to query.
    /// @return The credit balance.
    function getTokenBalance(address user) external view returns (uint256) {
        return tokenBalances[user];
    }

    /// @notice Get the depositor of a given asset, if deposited.
    /// @param tokenId The token id to query.
    /// @return The depositor address, or address(0) if not deposited.
    function getAssetOwner(uint256 tokenId) external view returns (address) {
        return assetOwners[tokenId];
    }

    /// @notice Get the next listing id that will be assigned.
    /// @return The next listing id.
    function getNextListingId() external view returns (uint256) {
        return _nextListingId;
    }
}
