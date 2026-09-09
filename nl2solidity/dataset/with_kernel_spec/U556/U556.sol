// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract NFTAutomatedTrader {
    // ============ Custom Errors ============
    error NotOwner();
    error NotOperator();
    error PoolNotFound();
    error PoolNotActive();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidFee();
    error InvalidPrice();
    error PoolMinimumNotMet();
    error InsufficientDeposit();
    error InsufficientPoolBalance();
    error NFTNotOwnedByCaller();
    error NFTNotInPool();
    error SlippageExceeded();
    error EmptyNFTList();
    error ReentrancyGuard();
    error TransferFailed();

    // ============ Structs ============
    struct Pool {
        address token;
        address nft;
        uint256 spotPrice;
        uint256 delta;
        bool active;
        uint256 tokenReserve;
        uint256[] nftIds;
    }

    // ============ Events ============
    event PoolCreated(
        uint256 indexed poolId,
        address indexed token,
        address indexed nft,
        address creator,
        uint256 spotPrice,
        uint256 delta
    );
    event NFTsDeposited(uint256 indexed poolId, address indexed user, uint256[] tokenIds);
    event TokensDeposited(uint256 indexed poolId, address indexed user, uint256 amount);
    event NFTsWithdrawn(uint256 indexed poolId, address indexed user, uint256[] tokenIds);
    event TokensWithdrawn(uint256 indexed poolId, address indexed user, uint256 amount);
    event SwapTokenForNFT(
        uint256 indexed poolId,
        address indexed user,
        uint256 amountIn,
        uint256 tokenId,
        uint256 feePaid
    );
    event SwapNFTForToken(
        uint256 indexed poolId,
        address indexed user,
        uint256 tokenId,
        uint256 amountOut,
        uint256 feePaid
    );
    event SpotPriceUpdated(uint256 indexed poolId, uint256 oldPrice, uint256 newPrice);
    event DeltaUpdated(uint256 indexed poolId, uint256 oldDelta, uint256 newDelta);
    event PoolStatusChanged(uint256 indexed poolId, bool active);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ============ Constants ============
    uint256 public constant MIN_NFTS_PER_POOL = 1;
    uint256 public constant MIN_TOKENS_PER_POOL = 100;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_PROTOCOL_FEE = 1_000; // 10%

    // ============ State Variables ============
    address public owner;
    address public operator;
    uint256 public protocolFee;
    address public feeRecipient;
    uint256 public nextPoolId;

    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(address => uint256)) public userTokenDeposits;
    mapping(uint256 => mapping(address => uint256)) public userNftCounts;
    mapping(uint256 => mapping(uint256 => uint256)) internal _poolNftIndex; // poolId => tokenId => index+1

    uint256 private _locked = 1;

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier poolExists(uint256 poolId) {
        if (pools[poolId].token == address(0)) revert PoolNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Constructor ============
    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        protocolFee = 50; // 0.5% default
        nextPoolId = 1;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit ProtocolFeeUpdated(0, 50);
    }

    // ============ View Functions ============
    function getPoolNftIds(uint256 poolId) external view poolExists(poolId) returns (uint256[] memory) {
        return pools[poolId].nftIds;
    }

    function getPoolNftCount(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return pools[poolId].nftIds.length;
    }

    function getPoolInfo(uint256 poolId) external view poolExists(poolId) returns (Pool memory) {
        return pools[poolId];
    }

    function getUserTokenDeposit(uint256 poolId, address user) external view poolExists(poolId) returns (uint256) {
        return userTokenDeposits[poolId][user];
    }

    function getUserNftCount(uint256 poolId, address user) external view poolExists(poolId) returns (uint256) {
        return userNftCounts[poolId][user];
    }

    // ============ Internal Helpers ============
    function _addNftToPool(uint256 poolId, uint256 tokenId) internal {
        uint256[] storage arr = pools[poolId].nftIds;
        _poolNftIndex[poolId][tokenId] = arr.length + 1;
        arr.push(tokenId);
    }

    function _removeNftFromPool(uint256 poolId, uint256 tokenId) internal {
        uint256[] storage arr = pools[poolId].nftIds;
        uint256 idxPlusOne = _poolNftIndex[poolId][tokenId];
        if (idxPlusOne == 0) revert NFTNotInPool();
        uint256 idx = idxPlusOne - 1;
        uint256 lastIdx = arr.length - 1;
        if (idx != lastIdx) {
            uint256 lastToken = arr[lastIdx];
            arr[idx] = lastToken;
            _poolNftIndex[poolId][lastToken] = idx + 1;
        }
        arr.pop();
        delete _poolNftIndex[poolId][tokenId];
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _checkNoDuplicates(uint256[] calldata nftIds) internal pure {
        uint256 len = nftIds.length;
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (nftIds[i] == nftIds[j]) revert InvalidAmount();
            }
        }
    }

    // ============ Pool Creation ============
    function createPool(
        address token,
        address nft,
        uint256 spotPrice,
        uint256 delta,
        uint256[] calldata nftIds,
        uint256 tokenAmount
    ) external nonReentrant returns (uint256 poolId) {
        if (token == address(0) || nft == address(0)) revert ZeroAddress();
        if (spotPrice == 0) revert InvalidPrice();
        if (nftIds.length < MIN_NFTS_PER_POOL) revert PoolMinimumNotMet();
        if (tokenAmount < MIN_TOKENS_PER_POOL) revert PoolMinimumNotMet();
        _checkNoDuplicates(nftIds);

        for (uint256 i = 0; i < nftIds.length; i++) {
            if (IERC721(nft).ownerOf(nftIds[i]) != msg.sender) revert NFTNotOwnedByCaller();
        }

        poolId = nextPoolId++;
        Pool storage pool = pools[poolId];
        pool.token = token;
        pool.nft = nft;
        pool.spotPrice = spotPrice;
        pool.delta = delta;
        pool.active = true;
        pool.tokenReserve = tokenAmount;

        userTokenDeposits[poolId][msg.sender] += tokenAmount;
        userNftCounts[poolId][msg.sender] += nftIds.length;
        for (uint256 i = 0; i < nftIds.length; i++) {
            _addNftToPool(poolId, nftIds[i]);
        }

        _safeTransferFrom(token, msg.sender, address(this), tokenAmount);
        for (uint256 i = 0; i < nftIds.length; i++) {
            IERC721(nft).transferFrom(msg.sender, address(this), nftIds[i]);
        }

        emit PoolCreated(poolId, token, nft, msg.sender, spotPrice, delta);
        emit TokensDeposited(poolId, msg.sender, tokenAmount);
        emit NFTsDeposited(poolId, msg.sender, nftIds);
    }

    // ============ Deposits ============
    function depositTokens(uint256 poolId, uint256 amount)
        external
        nonReentrant
        poolExists(poolId)
        returns (uint256)
    {
        if (amount == 0) revert InvalidAmount();
        Pool storage pool = pools[poolId];
        pool.tokenReserve += amount;
        userTokenDeposits[poolId][msg.sender] += amount;
        _safeTransferFrom(pool.token, msg.sender, address(this), amount);
        emit TokensDeposited(poolId, msg.sender, amount);
        return amount;
    }

    function depositNFTs(uint256 poolId, uint256[] calldata nftIds)
        external
        nonReentrant
        poolExists(poolId)
        returns (uint256)
    {
        if (nftIds.length == 0) revert InvalidAmount();
        _checkNoDuplicates(nftIds);
        Pool storage pool = pools[poolId];
        for (uint256 i = 0; i < nftIds.length; i++) {
            if (IERC721(pool.nft).ownerOf(nftIds[i]) != msg.sender) revert NFTNotOwnedByCaller();
        }
        userNftCounts[poolId][msg.sender] += nftIds.length;
        for (uint256 i = 0; i < nftIds.length; i++) {
            _addNftToPool(poolId, nftIds[i]);
            IERC721(pool.nft).transferFrom(msg.sender, address(this), nftIds[i]);
        }
        emit NFTsDeposited(poolId, msg.sender, nftIds);
        return nftIds.length;
    }

    // ============ Withdrawals ============
    function withdrawTokens(uint256 poolId, uint256 amount)
        external
        nonReentrant
        poolExists(poolId)
        returns (uint256)
    {
        if (amount == 0) revert InvalidAmount();
        Pool storage pool = pools[poolId];
        if (amount > userTokenDeposits[poolId][msg.sender]) revert InsufficientDeposit();
        if (amount > pool.tokenReserve) revert InsufficientPoolBalance();
        if (pool.tokenReserve - amount < MIN_TOKENS_PER_POOL) revert PoolMinimumNotMet();

        userTokenDeposits[poolId][msg.sender] -= amount;
        pool.tokenReserve -= amount;

        _safeTransfer(pool.token, msg.sender, amount);

        emit TokensWithdrawn(poolId, msg.sender, amount);
        return amount;
    }

    function withdrawNFTs(uint256 poolId, uint256[] calldata nftIds)
        external
        nonReentrant
        poolExists(poolId)
        returns (uint256)
    {
        if (nftIds.length == 0) revert InvalidAmount();
        _checkNoDuplicates(nftIds);
        Pool storage pool = pools[poolId];
        if (nftIds.length > userNftCounts[poolId][msg.sender]) revert InsufficientDeposit();
        if (pool.nftIds.length - nftIds.length < MIN_NFTS_PER_POOL) revert PoolMinimumNotMet();

        for (uint256 i = 0; i < nftIds.length; i++) {
            if (_poolNftIndex[poolId][nftIds[i]] == 0) revert NFTNotInPool();
        }

        userNftCounts[poolId][msg.sender] -= nftIds.length;
        for (uint256 i = 0; i < nftIds.length; i++) {
            _removeNftFromPool(poolId, nftIds[i]);
            IERC721(pool.nft).transferFrom(address(this), msg.sender, nftIds[i]);
        }

        emit NFTsWithdrawn(poolId, msg.sender, nftIds);
        return nftIds.length;
    }

    // ============ Swaps ============
    function swapTokenForNFT(uint256 poolId, uint256 maxAmountIn)
        external
        nonReentrant
        poolExists(poolId)
        returns (uint256 tokenId, uint256 amountIn)
    {
        Pool storage pool = pools[poolId];
        if (!pool.active) revert PoolNotActive();
        if (maxAmountIn == 0) revert InvalidAmount();
        if (pool.nftIds.length <= MIN_NFTS_PER_POOL) revert EmptyNFTList();

        uint256 spotPrice = pool.spotPrice;
        if (spotPrice == 0) revert InvalidPrice();
        uint256 feeAmount = (spotPrice * protocolFee) / FEE_DENOMINATOR;
        amountIn = spotPrice + feeAmount;
        if (amountIn > maxAmountIn) revert SlippageExceeded();

        tokenId = pool.nftIds[pool.nftIds.length - 1];

        pool.tokenReserve += spotPrice;
        pool.spotPrice += pool.delta;
        _removeNftFromPool(poolId, tokenId);

        _safeTransferFrom(pool.token, msg.sender, address(this), amountIn);
        if (feeAmount > 0) {
            _safeTransfer(pool.token, feeRecipient, feeAmount);
        }
        IERC721(pool.nft).transferFrom(address(this), msg.sender, tokenId);

        emit SwapTokenForNFT(poolId, msg.sender, amountIn, tokenId, feeAmount);
    }

    function swapNFTForToken(uint256 poolId, uint256 tokenId, uint256 minAmountOut)
        external
        nonReentrant
        poolExists(poolId)
        returns (uint256 amountOut)
    {
        Pool storage pool = pools[poolId];
        if (!pool.active) revert PoolNotActive();
        if (IERC721(pool.nft).ownerOf(tokenId) != msg.sender) revert NFTNotOwnedByCaller();

        uint256 spotPrice = pool.spotPrice;
        if (spotPrice == 0) revert InvalidPrice();
        uint256 feeAmount = (spotPrice * protocolFee) / FEE_DENOMINATOR;
        amountOut = spotPrice - feeAmount;
        if (spotPrice > pool.tokenReserve) revert InsufficientPoolBalance();
        if (pool.tokenReserve - spotPrice < MIN_TOKENS_PER_POOL) revert PoolMinimumNotMet();
        if (minAmountOut > amountOut) revert SlippageExceeded();

        pool.tokenReserve -= spotPrice;
        if (pool.spotPrice > pool.delta) {
            pool.spotPrice -= pool.delta;
        } else {
            pool.spotPrice = 0;
        }
        _addNftToPool(poolId, tokenId);

        IERC721(pool.nft).transferFrom(msg.sender, address(this), tokenId);
        _safeTransfer(pool.token, msg.sender, amountOut);
        if (feeAmount > 0) {
            _safeTransfer(pool.token, feeRecipient, feeAmount);
        }

        emit SwapNFTForToken(poolId, msg.sender, tokenId, amountOut, feeAmount);
    }

    // ============ Operator Functions ============
    function setPoolSpotPrice(uint256 poolId, uint256 newSpotPrice)
        external
        onlyOperator
        poolExists(poolId)
    {
        if (newSpotPrice == 0) revert InvalidPrice();
        uint256 oldPrice = pools[poolId].spotPrice;
        pools[poolId].spotPrice = newSpotPrice;
        emit SpotPriceUpdated(poolId, oldPrice, newSpotPrice);
    }

    function setPoolDelta(uint256 poolId, uint256 newDelta) external onlyOperator poolExists(poolId) {
        uint256 oldDelta = pools[poolId].delta;
        pools[poolId].delta = newDelta;
        emit DeltaUpdated(poolId, oldDelta, newDelta);
    }

    function setPoolActive(uint256 poolId, bool active) external onlyOperator poolExists(poolId) {
        pools[poolId].active = active;
        emit PoolStatusChanged(poolId, active);
    }

    // ============ Owner Functions ============
    function setProtocolFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_PROTOCOL_FEE) revert InvalidFee();
        uint256 oldFee = protocolFee;
        protocolFee = newFee;
        emit ProtocolFeeUpdated(oldFee, newFee);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
