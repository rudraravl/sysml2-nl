// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract FractionalNFTMarket is IERC721Receiver {
    // ============ State Variables ============
    address public owner;
    uint256 public protocolFeeBps;
    uint256 public collectedFees;
    uint256 public nextTokenId;

    mapping(address => bool) public allowedCollections;
    mapping(address => mapping(uint256 => bool)) private _escrowedNfts;

    struct FractionalToken {
        address nftCollection;
        uint256 nftTokenId;
        uint256 totalSupply;
        uint256 reserve;
        uint256 slope;
        uint256 ethPool;
        bool exists;
    }

    mapping(uint256 => FractionalToken) public fractionalTokens;
    mapping(uint256 => mapping(address => uint256)) private _balances;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ============ Constants ============
    uint256 public constant MIN_TOTAL_SUPPLY = 100;
    uint256 public constant FIXED_PROTOCOL_FEE_BPS = 50;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ============ Events ============
    event FractionalTokenCreated(
        uint256 indexed tokenId,
        address indexed creator,
        address indexed collection,
        uint256 nftTokenId,
        uint256 totalSupply,
        uint256 slope
    );
    event Bought(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 amount,
        uint256 cost,
        uint256 fee
    );
    event Sold(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 amount,
        uint256 proceeds,
        uint256 fee
    );
    event NFTWithdrawn(
        uint256 indexed tokenId,
        address indexed withdrawer,
        address indexed collection,
        uint256 nftTokenId,
        uint256 ethReturned
    );
    event ProtocolFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event CollectionAllowedUpdated(address indexed collection, bool allowed);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Custom Errors ============
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroSlope();
    error FeeTooHigh(uint256 feeBps);
    error CollectionNotAllowed(address collection);
    error TokenDoesNotExist(uint256 tokenId);
    error BelowMinSupply(uint256 provided, uint256 minimum);
    error InsufficientReserve(uint256 available, uint256 requested);
    error InsufficientBalance(uint256 available, uint256 requested);
    error InsufficientEthPool(uint256 available, uint256 required);
    error InsufficientPayment(uint256 provided, uint256 required);
    error NotAllTokensHeld(uint256 held, uint256 totalSupply);
    error NFTAlreadyEscrowed(address collection, uint256 tokenId);
    error NotNFTOwner(address collection, uint256 tokenId);
    error TransferFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        require(_status == _NOT_ENTERED, "Reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ============ Constructor ============
    constructor() {
        owner = msg.sender;
        protocolFeeBps = FIXED_PROTOCOL_FEE_BPS;
        nextTokenId = 1;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============ Admin Functions ============
    function setProtocolFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > BPS_DENOMINATOR) revert FeeTooHigh(_feeBps);
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = _feeBps;
        emit ProtocolFeeUpdated(oldFee, _feeBps);
    }

    function setAllowedCollection(address _collection, bool _allowed) external onlyOwner {
        if (_collection == address(0)) revert ZeroAddress();
        allowedCollections[_collection] = _allowed;
        emit CollectionAllowedUpdated(_collection, _allowed);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = collectedFees;
        collectedFees = 0;
        if (amount > 0) {
            (bool success, ) = payable(owner).call{value: amount}("");
            if (!success) revert TransferFailed();
        }
        emit FeesWithdrawn(owner, amount);
    }

    // ============ Core Functions ============
    function createFractionalToken(
        address _nftCollection,
        uint256 _nftTokenId,
        uint256 _totalSupply,
        uint256 _slope
    ) external nonReentrant returns (uint256 tokenId) {
        if (!allowedCollections[_nftCollection]) revert CollectionNotAllowed(_nftCollection);
        if (_totalSupply < MIN_TOTAL_SUPPLY) revert BelowMinSupply(_totalSupply, MIN_TOTAL_SUPPLY);
        if (_slope == 0) revert ZeroSlope();
        if (_escrowedNfts[_nftCollection][_nftTokenId]) revert NFTAlreadyEscrowed(_nftCollection, _nftTokenId);

        address nftOwner = IERC721(_nftCollection).ownerOf(_nftTokenId);
        if (nftOwner != msg.sender) revert NotNFTOwner(_nftCollection, _nftTokenId);

        // Effects: update all state before external interactions
        tokenId = nextTokenId++;
        _escrowedNfts[_nftCollection][_nftTokenId] = true;
        fractionalTokens[tokenId] = FractionalToken({
            nftCollection: _nftCollection,
            nftTokenId: _nftTokenId,
            totalSupply: _totalSupply,
            reserve: _totalSupply,
            slope: _slope,
            ethPool: 0,
            exists: true
        });

        // Interactions: transfer NFT into escrow last
        IERC721(_nftCollection).transferFrom(msg.sender, address(this), _nftTokenId);

        emit FractionalTokenCreated(tokenId, msg.sender, _nftCollection, _nftTokenId, _totalSupply, _slope);
    }

    function buy(uint256 _tokenId, uint256 _amount) external payable nonReentrant {
        FractionalToken storage ft = fractionalTokens[_tokenId];
        if (!ft.exists) revert TokenDoesNotExist(_tokenId);
        if (_amount == 0) revert ZeroAmount();
        if (ft.reserve < _amount) revert InsufficientReserve(ft.reserve, _amount);

        uint256 outstanding = ft.totalSupply - ft.reserve;
        uint256 cost = _buyPrice(ft.slope, outstanding, _amount);
        uint256 fee = (cost * protocolFeeBps) / BPS_DENOMINATOR;
        uint256 totalRequired = cost + fee;

        if (msg.value < totalRequired) revert InsufficientPayment(msg.value, totalRequired);

        ft.reserve -= _amount;
        ft.ethPool += cost;
        collectedFees += fee;
        _balances[_tokenId][msg.sender] += _amount;

        if (msg.value > totalRequired) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalRequired}("");
            if (!success) revert TransferFailed();
        }

        emit Bought(_tokenId, msg.sender, _amount, cost, fee);
    }

    function sell(uint256 _tokenId, uint256 _amount) external nonReentrant {
        FractionalToken storage ft = fractionalTokens[_tokenId];
        if (!ft.exists) revert TokenDoesNotExist(_tokenId);
        if (_amount == 0) revert ZeroAmount();

        uint256 sellerBalance = _balances[_tokenId][msg.sender];
        if (sellerBalance < _amount) revert InsufficientBalance(sellerBalance, _amount);

        uint256 outstanding = ft.totalSupply - ft.reserve;
        uint256 proceeds = _sellPrice(ft.slope, outstanding, _amount);
        uint256 fee = (proceeds * protocolFeeBps) / BPS_DENOMINATOR;
        uint256 sellerGets = proceeds - fee;

        if (ft.ethPool < proceeds) revert InsufficientEthPool(ft.ethPool, proceeds);

        ft.reserve += _amount;
        ft.ethPool -= proceeds;
        collectedFees += fee;
        _balances[_tokenId][msg.sender] = sellerBalance - _amount;

        (bool success, ) = payable(msg.sender).call{value: sellerGets}("");
        if (!success) revert TransferFailed();

        emit Sold(_tokenId, msg.sender, _amount, proceeds, fee);
    }

    function withdrawNFT(uint256 _tokenId) external nonReentrant {
        FractionalToken storage ft = fractionalTokens[_tokenId];
        if (!ft.exists) revert TokenDoesNotExist(_tokenId);

        uint256 userBalance = _balances[_tokenId][msg.sender];
        if (userBalance < ft.totalSupply) revert NotAllTokensHeld(userBalance, ft.totalSupply);

        address collection = ft.nftCollection;
        uint256 nftTokenId = ft.nftTokenId;
        uint256 ethToReturn = ft.ethPool;

        _balances[_tokenId][msg.sender] = 0;
        ft.reserve = 0;
        ft.ethPool = 0;
        ft.exists = false;
        _escrowedNfts[collection][nftTokenId] = false;

        IERC721(collection).safeTransferFrom(address(this), msg.sender, nftTokenId);

        if (ethToReturn > 0) {
            (bool success, ) = payable(msg.sender).call{value: ethToReturn}("");
            if (!success) revert TransferFailed();
        }

        emit NFTWithdrawn(_tokenId, msg.sender, collection, nftTokenId, ethToReturn);
    }

    // ============ View Functions ============
    function balanceOf(uint256 _tokenId, address _account) external view returns (uint256) {
        return _balances[_tokenId][_account];
    }

    function getFractionalToken(uint256 _tokenId)
        external
        view
        returns (
            address nftCollection,
            uint256 nftTokenId,
            uint256 totalSupply,
            uint256 reserve,
            uint256 slope,
            uint256 ethPool,
            bool exists
        )
    {
        FractionalToken storage ft = fractionalTokens[_tokenId];
        return (
            ft.nftCollection,
            ft.nftTokenId,
            ft.totalSupply,
            ft.reserve,
            ft.slope,
            ft.ethPool,
            ft.exists
        );
    }

    function outstandingSupply(uint256 _tokenId) external view returns (uint256) {
        FractionalToken storage ft = fractionalTokens[_tokenId];
        return ft.totalSupply - ft.reserve;
    }

    function buyPrice(uint256 _tokenId, uint256 _amount)
        external
        view
        returns (uint256 cost, uint256 fee, uint256 total)
    {
        FractionalToken storage ft = fractionalTokens[_tokenId];
        if (!ft.exists) revert TokenDoesNotExist(_tokenId);
        uint256 outstanding = ft.totalSupply - ft.reserve;
        cost = _buyPrice(ft.slope, outstanding, _amount);
        fee = (cost * protocolFeeBps) / BPS_DENOMINATOR;
        total = cost + fee;
    }

    function sellPrice(uint256 _tokenId, uint256 _amount)
        external
        view
        returns (uint256 proceeds, uint256 fee, uint256 sellerGets)
    {
        FractionalToken storage ft = fractionalTokens[_tokenId];
        if (!ft.exists) revert TokenDoesNotExist(_tokenId);
        uint256 outstanding = ft.totalSupply - ft.reserve;
        proceeds = _sellPrice(ft.slope, outstanding, _amount);
        fee = (proceeds * protocolFeeBps) / BPS_DENOMINATOR;
        sellerGets = proceeds - fee;
    }

    function isNFTEscrowed(address _collection, uint256 _tokenId) external view returns (bool) {
        return _escrowedNfts[_collection][_tokenId];
    }

    // ============ Internal Bonding Curve Math ============
    function _buyPrice(uint256 slope, uint256 outstanding, uint256 amount) internal pure returns (uint256) {
        uint256 newOutstanding = outstanding + amount;
        return (slope * (newOutstanding * newOutstanding - outstanding * outstanding)) / 2;
    }

    function _sellPrice(uint256 slope, uint256 outstanding, uint256 amount) internal pure returns (uint256) {
        uint256 newOutstanding = outstanding - amount;
        return (slope * (outstanding * outstanding - newOutstanding * newOutstanding)) / 2;
    }

    // ============ IERC721Receiver ============
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
