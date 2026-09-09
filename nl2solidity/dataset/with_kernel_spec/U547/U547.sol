// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract NFTFractionalPool {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error ZeroAddress();
    error PoolDoesNotExist();
    error PoolAlreadyExists();
    error InvalidPrice();
    error InvalidFee();
    error InvalidAmount();
    error NFTAlreadyDeposited();
    error NFTNotInPool();
    error NotNFTOwner();
    error InsufficientBalance();
    error InsufficientPayment();
    error InsufficientLiquidity();
    error InsufficientBacking();
    error InsufficientFees();
    error TransferFailed();
    error ReentrantCall();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    event PoolCreated(address indexed collection, uint256 pricePerNft, uint256 feeBps);
    event FeeUpdated(address indexed collection, uint256 feeBps);
    event PriceUpdated(address indexed collection, uint256 pricePerNft);
    event NFTDeposited(address indexed collection, uint256 indexed tokenId, address indexed depositor);
    event NFTWithdrawn(address indexed collection, uint256 indexed tokenId, address indexed withdrawer);
    event NFTRedeemed(address indexed collection, uint256 indexed tokenId, address indexed redeemer);
    event TokensBought(address indexed collection, address indexed buyer, uint256 amount, uint256 totalCost, uint256 fee);
    event TokensSold(address indexed collection, address indexed seller, uint256 amount, uint256 payout, uint256 fee);
    event OperatorSet(address indexed operator, bool status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant TOKENS_PER_NFT = 1 ether;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_FEE_BPS = 500; // 5%

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Pool {
        bool exists;
        uint256 tokenPrice; // price per whole NFT in wei
        uint256 feeBps;
        uint256 totalSupply;
        uint256 nftCount;
        uint256 liquidity; // ETH available for sells in this pool
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public owner;
    uint256 public protocolFees;
    uint256 private _reentrancyStatus;

    mapping(address => Pool) internal _pools;
    mapping(address => mapping(address => uint256)) internal _balances; // collection => user => balance
    mapping(address => mapping(uint256 => bool)) internal _nftDeposited;
    mapping(address => uint256[]) internal _nftList;
    mapping(address => mapping(uint256 => uint256)) internal _nftIndex;

    mapping(address => bool) public operators;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner && !operators[msg.sender]) revert NotAuthorized();
        _;
    }

    modifier poolExists(address collection) {
        if (!_pools[collection].exists) revert PoolDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == 2) revert ReentrantCall();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        owner = msg.sender;
        _reentrancyStatus = 1;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = status;
        emit OperatorSet(operator, status);
    }

    function createPool(address collection, uint256 pricePerNft) external onlyOwnerOrOperator {
        if (collection == address(0)) revert ZeroAddress();
        if (pricePerNft == 0) revert InvalidPrice();
        if (_pools[collection].exists) revert PoolAlreadyExists();

        Pool storage pool = _pools[collection];
        pool.exists = true;
        pool.tokenPrice = pricePerNft;
        pool.feeBps = DEFAULT_FEE_BPS;

        emit PoolCreated(collection, pricePerNft, DEFAULT_FEE_BPS);
    }

    function setFee(address collection, uint256 feeBps) external onlyOwnerOrOperator poolExists(collection) {
        if (feeBps > MAX_FEE_BPS) revert InvalidFee();
        _pools[collection].feeBps = feeBps;
        emit FeeUpdated(collection, feeBps);
    }

    function setPrice(address collection, uint256 pricePerNft) external onlyOwnerOrOperator poolExists(collection) {
        if (pricePerNft == 0) revert InvalidPrice();
        _pools[collection].tokenPrice = pricePerNft;
        emit PriceUpdated(collection, pricePerNft);
    }

    function withdrawFees(address payable to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount > protocolFees) revert InsufficientFees();

        protocolFees -= amount;

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          NFT DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function depositNFT(address collection, uint256 tokenId) external nonReentrant poolExists(collection) {
        if (_nftDeposited[collection][tokenId]) revert NFTAlreadyDeposited();
        if (IERC721(collection).ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        // Effects: update state before external call (checks-effects-interactions)
        _nftDeposited[collection][tokenId] = true;
        _nftIndex[collection][tokenId] = _nftList[collection].length;
        _nftList[collection].push(tokenId);

        Pool storage pool = _pools[collection];
        pool.totalSupply += TOKENS_PER_NFT;
        pool.nftCount += 1;
        _balances[collection][msg.sender] += TOKENS_PER_NFT;

        // Interactions: transfer NFT from sender to this contract
        IERC721(collection).transferFrom(msg.sender, address(this), tokenId);

        emit NFTDeposited(collection, tokenId, msg.sender);
    }

    function withdrawNFT(address collection, uint256 tokenId) external nonReentrant poolExists(collection) {
        _exitNFT(collection, tokenId);
        emit NFTWithdrawn(collection, tokenId, msg.sender);
    }

    function redeemNFT(address collection, uint256 tokenId) external nonReentrant poolExists(collection) {
        _exitNFT(collection, tokenId);
        emit NFTRedeemed(collection, tokenId, msg.sender);
        emit NFTWithdrawn(collection, tokenId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                       BUY / SELL FUNGIBLE TOKENS
    //////////////////////////////////////////////////////////////*/
    function buyTokens(address collection, uint256 amount) external payable nonReentrant poolExists(collection) {
        if (amount == 0) revert InvalidAmount();

        Pool storage pool = _pools[collection];

        // Compute fee directly from raw values to avoid divide-before-multiply
        uint256 fee = (amount * pool.tokenPrice * pool.feeBps) / (TOKENS_PER_NFT * FEE_DENOMINATOR);
        uint256 grossCost = (amount * pool.tokenPrice) / TOKENS_PER_NFT;
        if (grossCost == 0) revert InvalidAmount();

        uint256 totalCost = grossCost + fee;

        if (msg.value < totalCost) revert InsufficientPayment();

        // Effects
        pool.totalSupply += amount;
        _balances[collection][msg.sender] += amount;
        pool.liquidity += grossCost;
        protocolFees += fee;

        // Interactions: refund excess payment
        uint256 refund = msg.value - totalCost;
        if (refund > 0) {
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert TransferFailed();
        }

        emit TokensBought(collection, msg.sender, amount, totalCost, fee);
    }

    function sellTokens(address collection, uint256 amount) external nonReentrant poolExists(collection) {
        if (amount == 0) revert InvalidAmount();

        Pool storage pool = _pools[collection];

        if (_balances[collection][msg.sender] < amount) revert InsufficientBalance();

        // Compute fee directly from raw values to avoid divide-before-multiply
        uint256 fee = (amount * pool.tokenPrice * pool.feeBps) / (TOKENS_PER_NFT * FEE_DENOMINATOR);
        uint256 grossValue = (amount * pool.tokenPrice) / TOKENS_PER_NFT;
        if (grossValue == 0) revert InvalidAmount();

        uint256 payout = grossValue - fee;

        if (pool.liquidity < grossValue) revert InsufficientLiquidity();
        if (pool.totalSupply - amount < pool.nftCount * TOKENS_PER_NFT) revert InsufficientBacking();

        // Effects
        _balances[collection][msg.sender] -= amount;
        pool.totalSupply -= amount;
        pool.liquidity -= grossValue;
        protocolFees += fee;

        // Interactions: send payout to seller
        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) revert TransferFailed();

        emit TokensSold(collection, msg.sender, amount, payout, fee);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getPool(address collection)
        external
        view
        returns (
            bool exists,
            uint256 tokenPrice,
            uint256 feeBps,
            uint256 totalSupply,
            uint256 nftCount,
            uint256 liquidity
        )
    {
        Pool storage pool = _pools[collection];
        return (pool.exists, pool.tokenPrice, pool.feeBps, pool.totalSupply, pool.nftCount, pool.liquidity);
    }

    function balanceOf(address collection, address account) external view returns (uint256) {
        return _balances[collection][account];
    }

    function totalSupply(address collection) external view returns (uint256) {
        return _pools[collection].totalSupply;
    }

    function poolLiquidity(address collection) external view returns (uint256) {
        return _pools[collection].liquidity;
    }

    function isNFTDeposited(address collection, uint256 tokenId) external view returns (bool) {
        return _nftDeposited[collection][tokenId];
    }

    function getDepositedNFTs(address collection) external view poolExists(collection) returns (uint256[] memory) {
        return _nftList[collection];
    }

    function getBuyPrice(address collection, uint256 amount)
        external
        view
        poolExists(collection)
        returns (uint256 totalCost, uint256 fee)
    {
        Pool storage pool = _pools[collection];
        uint256 grossCost = (amount * pool.tokenPrice) / TOKENS_PER_NFT;
        // Compute fee directly from raw values to avoid divide-before-multiply
        fee = (amount * pool.tokenPrice * pool.feeBps) / (TOKENS_PER_NFT * FEE_DENOMINATOR);
        totalCost = grossCost + fee;
    }

    function getSellPrice(address collection, uint256 amount)
        external
        view
        poolExists(collection)
        returns (uint256 payout, uint256 fee)
    {
        Pool storage pool = _pools[collection];
        uint256 grossValue = (amount * pool.tokenPrice) / TOKENS_PER_NFT;
        // Compute fee directly from raw values to avoid divide-before-multiply
        fee = (amount * pool.tokenPrice * pool.feeBps) / (TOKENS_PER_NFT * FEE_DENOMINATOR);
        payout = grossValue - fee;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _exitNFT(address collection, uint256 tokenId) internal {
        if (!_nftDeposited[collection][tokenId]) revert NFTNotInPool();
        if (_balances[collection][msg.sender] < TOKENS_PER_NFT) revert InsufficientBalance();

        Pool storage pool = _pools[collection];

        // Effects: update state before external call (checks-effects-interactions)
        _balances[collection][msg.sender] -= TOKENS_PER_NFT;
        pool.totalSupply -= TOKENS_PER_NFT;
        pool.nftCount -= 1;

        _nftDeposited[collection][tokenId] = false;
        _removeNft(collection, tokenId);

        // Interactions: transfer NFT back to user
        IERC721(collection).transferFrom(address(this), msg.sender, tokenId);
    }

    function _removeNft(address collection, uint256 tokenId) internal {
        uint256[] storage list = _nftList[collection];
        uint256 index = _nftIndex[collection][tokenId];
        uint256 lastIndex = list.length - 1;

        if (index != lastIndex) {
            uint256 lastTokenId = list[lastIndex];
            list[index] = lastTokenId;
            _nftIndex[collection][lastTokenId] = index;
        }

        list.pop();
        delete _nftIndex[collection][tokenId];
    }

    receive() external payable {}
}
