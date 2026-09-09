// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DigitalArtMarketplace
 * @notice Manages a collection of unique digital art tokens and facilitates their
 *         exchange. Tokens are held in escrow by the contract while listed for sale.
 */
contract DigitalArtMarketplace {
    // --------------------------------------------------------------------------------------------
    // Custom errors
    // --------------------------------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error TokenDoesNotExist(uint256 tokenId);
    error NotTokenOwner(uint256 tokenId, address caller);
    error TokenAlreadyListed(uint256 tokenId);
    error TokenNotListed(uint256 tokenId);
    error InvalidPrice();
    error InvalidFeePercentage(uint256 max, uint256 provided);
    error InsufficientMintingFee(uint256 required, uint256 provided);
    error InsufficientPayment(uint256 required, uint256 provided);
    error SalesPaused();
    error NoProceeds();
    error NoFees();
    error WithdrawalFailed();
    error IndexOutOfBounds(uint256 index);
    error ReentrantCall();

    // --------------------------------------------------------------------------------------------
    // Events
    // --------------------------------------------------------------------------------------------
    event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);
    event MintingFeeUpdated(uint256 oldFee, uint256 newFee);
    event SalesFeeUpdated(uint256 oldBps, uint256 newBps);
    event SalesPausedChanged(bool paused);
    event TokenMinted(uint256 indexed tokenId, address indexed owner, string metadataURI, uint256 timestamp);
    event TokenListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event TokenDelisted(uint256 indexed tokenId, address indexed seller);
    event TokenSold(
        uint256 indexed saleId,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price,
        uint256 fee,
        uint256 timestamp
    );
    event ProceedsWithdrawn(address indexed seller, uint256 amount);
    event FeesWithdrawn(address indexed admin, uint256 amount);

    // --------------------------------------------------------------------------------------------
    // Data structures
    // --------------------------------------------------------------------------------------------
    struct ArtToken {
        address owner;
        address seller;
        string metadataURI;
        uint256 mintedAt;
        uint256 price;
        bool listed;
    }

    struct SaleRecord {
        uint256 saleId;
        uint256 tokenId;
        address seller;
        address buyer;
        uint256 price;
        uint256 fee;
        uint256 timestamp;
    }

    // --------------------------------------------------------------------------------------------
    // State
    // --------------------------------------------------------------------------------------------
    address public admin;
    uint256 public mintingFee;          // wei per mint
    uint256 public salesFeeBps;         // fee in basis points (250 = 2.5%)
    bool public salesPaused;

    uint256 private _nextTokenId = 1;
    uint256 private _nextSaleId = 1;
    uint256 private _totalSupply;

    mapping(uint256 => ArtToken) private _tokens;
    mapping(uint256 => bool) private _tokenExists;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) public pendingWithdrawals;
    uint256 public accumulatedFees;

    mapping(address => uint256[]) internal _tokensByOwner;
    mapping(uint256 => uint256) internal _ownerTokenIndex;

    SaleRecord[] internal _salesHistory;

    // Reentrancy guard
    uint256 private _reentrancyStatus;

    // --------------------------------------------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------------------------------------------
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (salesPaused) revert SalesPaused();
        _;
    }

    modifier onlyExistingToken(uint256 tokenId) {
        if (!_tokenExists[tokenId]) revert TokenDoesNotExist(tokenId);
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == 1) revert ReentrantCall();
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 0;
    }

    // --------------------------------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------------------------------
    constructor() {
        admin = msg.sender;
        mintingFee = 0.01 ether;
        salesFeeBps = 250; // 2.5%
        salesPaused = false;
        _reentrancyStatus = 0;
    }

    // --------------------------------------------------------------------------------------------
    // Admin configuration
    // --------------------------------------------------------------------------------------------
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminUpdated(admin, newAdmin);
        admin = newAdmin;
    }

    function setMintingFee(uint256 newFee) external onlyAdmin {
        emit MintingFeeUpdated(mintingFee, newFee);
        mintingFee = newFee;
    }

    function setSalesFeeBps(uint256 newBps) external onlyAdmin {
        if (newBps > 10000) revert InvalidFeePercentage(10000, newBps);
        emit SalesFeeUpdated(salesFeeBps, newBps);
        salesFeeBps = newBps;
    }

    function setSalesPaused(bool paused) external onlyAdmin {
        salesPaused = paused;
        emit SalesPausedChanged(paused);
    }

    function withdrawFees() external onlyAdmin nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFees();
        accumulatedFees = 0;
        (bool ok, ) = payable(admin).call{value: amount}("");
        if (!ok) revert WithdrawalFailed();
        emit FeesWithdrawn(admin, amount);
    }

    // --------------------------------------------------------------------------------------------
    // Minting
    // --------------------------------------------------------------------------------------------
    /**
     * @notice Mint a new art token. Caller must send at least `mintingFee` ether.
     * @param metadataURI Off-chain metadata URI describing the token.
     * @return tokenId The id of the newly minted token.
     */
    function mint(string calldata metadataURI) external payable returns (uint256 tokenId) {
        if (msg.value < mintingFee) revert InsufficientMintingFee(mintingFee, msg.value);

        tokenId = _nextTokenId++;
        _totalSupply++;

        _tokens[tokenId] = ArtToken({
            owner: msg.sender,
            seller: address(0),
            metadataURI: metadataURI,
            mintedAt: block.timestamp,
            price: 0,
            listed: false
        });
        _tokenExists[tokenId] = true;
        _balances[msg.sender]++;
        _addTokenToOwner(msg.sender, tokenId);

        // The minting fee is revenue for the administrator.
        accumulatedFees += msg.value;

        emit TokenMinted(tokenId, msg.sender, metadataURI, block.timestamp);
    }

    // --------------------------------------------------------------------------------------------
    // Listing / delisting (escrow)
    // --------------------------------------------------------------------------------------------
    /**
     * @notice List an owned token for sale at `price`. The token is held in escrow
     *         by the contract until sold or delisted.
     */
    function listToken(uint256 tokenId, uint256 price)
        external
        onlyExistingToken(tokenId)
        whenNotPaused
    {
        ArtToken storage token = _tokens[tokenId];
        if (token.owner != msg.sender) revert NotTokenOwner(tokenId, msg.sender);
        if (token.listed) revert TokenAlreadyListed(tokenId);
        if (price == 0) revert InvalidPrice();

        _balances[msg.sender]--;
        _removeTokenFromOwner(msg.sender, tokenId);

        token.seller = msg.sender;
        token.owner = address(this);
        token.listed = true;
        token.price = price;

        _balances[address(this)]++;
        _addTokenToOwner(address(this), tokenId);

        emit TokenListed(tokenId, msg.sender, price);
    }

    /**
     * @notice Remove a token from sale, returning it from escrow to the original seller.
     */
    function delistToken(uint256 tokenId) external onlyExistingToken(tokenId) {
        ArtToken storage token = _tokens[tokenId];
        if (!token.listed) revert TokenNotListed(tokenId);
        if (token.seller != msg.sender) revert Unauthorized();

        address seller = token.seller;

        _balances[address(this)]--;
        _removeTokenFromOwner(address(this), tokenId);

        token.owner = seller;
        token.seller = address(0);
        token.listed = false;
        token.price = 0;

        _balances[seller]++;
        _addTokenToOwner(seller, tokenId);

        emit TokenDelisted(tokenId, seller);
    }

    // --------------------------------------------------------------------------------------------
    // Purchase
    // --------------------------------------------------------------------------------------------
    /**
     * @notice Buy a listed token. Caller must send at least the listing price;
     *         any excess is refunded after all state changes are committed.
     */
    function buyToken(uint256 tokenId)
        external
        payable
        onlyExistingToken(tokenId)
        whenNotPaused
        nonReentrant
    {
        ArtToken storage token = _tokens[tokenId];
        if (!token.listed) revert TokenNotListed(tokenId);
        if (msg.value < token.price) revert InsufficientPayment(token.price, msg.value);

        address seller = token.seller;
        address buyer = msg.sender;
        uint256 price = token.price;
        uint256 fee = (price * salesFeeBps) / 10000;
        uint256 proceeds = price - fee;
        uint256 refund = msg.value - price;

        // Effects: transfer token from escrow to buyer BEFORE any external call.
        _balances[address(this)]--;
        _removeTokenFromOwner(address(this), tokenId);
        token.owner = buyer;
        token.seller = address(0);
        token.listed = false;
        token.price = 0;
        _balances[buyer]++;
        _addTokenToOwner(buyer, tokenId);

        // Credit seller proceeds and administrator fee.
        pendingWithdrawals[seller] += proceeds;
        accumulatedFees += fee;

        // Record the sale.
        uint256 saleId = _nextSaleId++;
        _salesHistory.push(SaleRecord({
            saleId: saleId,
            tokenId: tokenId,
            seller: seller,
            buyer: buyer,
            price: price,
            fee: fee,
            timestamp: block.timestamp
        }));

        emit TokenSold(saleId, tokenId, seller, buyer, price, fee, block.timestamp);

        // Interactions: refund any excess payment last (checks-effects-interactions).
        if (refund > 0) {
            (bool refundOk, ) = payable(buyer).call{value: refund}("");
            if (!refundOk) revert WithdrawalFailed();
        }
    }

    // --------------------------------------------------------------------------------------------
    // Withdrawals
    // --------------------------------------------------------------------------------------------
    /**
     * @notice Withdraw accumulated sale proceeds credited to the caller.
     */
    function withdrawProceeds() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NoProceeds();

        pendingWithdrawals[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert WithdrawalFailed();

        emit ProceedsWithdrawn(msg.sender, amount);
    }

    // --------------------------------------------------------------------------------------------
    // Views
    // --------------------------------------------------------------------------------------------
    function ownerOf(uint256 tokenId) external view onlyExistingToken(tokenId) returns (address) {
        return _tokens[tokenId].owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function tokenURI(uint256 tokenId) external view onlyExistingToken(tokenId) returns (string memory) {
        return _tokens[tokenId].metadataURI;
    }

    function isListed(uint256 tokenId) external view onlyExistingToken(tokenId) returns (bool) {
        return _tokens[tokenId].listed;
    }

    function getPrice(uint256 tokenId) external view onlyExistingToken(tokenId) returns (uint256) {
        return _tokens[tokenId].price;
    }

    function getToken(uint256 tokenId) external view onlyExistingToken(tokenId) returns (ArtToken memory) {
        return _tokens[tokenId];
    }

    function tokensByOwner(address owner) external view returns (uint256[] memory) {
        return _tokensByOwner[owner];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function salesCount() external view returns (uint256) {
        return _salesHistory.length;
    }

    function getSale(uint256 index) external view returns (SaleRecord memory) {
        if (index >= _salesHistory.length) revert IndexOutOfBounds(index);
        return _salesHistory[index];
    }

    function getSalesRange(uint256 offset, uint256 limit) external view returns (SaleRecord[] memory page) {
        uint256 total = _salesHistory.length;
        if (offset >= total) {
            return new SaleRecord[](0);
        }
        uint256 end = offset + limit;
        if (end > total) end = total;
        page = new SaleRecord[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = _salesHistory[i];
        }
    }

    // --------------------------------------------------------------------------------------------
    // Internal helpers
    // --------------------------------------------------------------------------------------------
    function _addTokenToOwner(address owner, uint256 tokenId) internal {
        _ownerTokenIndex[tokenId] = _tokensByOwner[owner].length;
        _tokensByOwner[owner].push(tokenId);
    }

    function _removeTokenFromOwner(address owner, uint256 tokenId) internal {
        uint256[] storage ownerTokens = _tokensByOwner[owner];
        uint256 index = _ownerTokenIndex[tokenId];
        uint256 lastIndex = ownerTokens.length - 1;
        if (index != lastIndex) {
            uint256 lastTokenId = ownerTokens[lastIndex];
            ownerTokens[index] = lastTokenId;
            _ownerTokenIndex[lastTokenId] = index;
        }
        ownerTokens.pop();
        delete _ownerTokenIndex[tokenId];
    }

    receive() external payable {}
}
