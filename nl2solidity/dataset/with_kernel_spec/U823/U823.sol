// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

library EnumerableSet {
    struct UintSet {
        uint256[] _values;
        mapping(uint256 => uint256) _indexes;
    }

    function add(UintSet storage set, uint256 value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        }
        return false;
    }

    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex == 0) {
            return false;
        }
        uint256 lastIndex = set._values.length;
        if (valueIndex != lastIndex) {
            uint256 lastValue = set._values[lastIndex - 1];
            set._values[valueIndex - 1] = lastValue;
            set._indexes[lastValue] = valueIndex;
        }
        set._values.pop();
        delete set._indexes[value];
        return true;
    }

    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function length(UintSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return set._values[index];
    }

    function values(UintSet storage set) internal view returns (uint256[] memory) {
        return set._values;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableUnauthorizedAccount(address(0));
        }
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableUnauthorizedAccount(address(0));
        }
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract NFTLiquidityPool is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;

    error PoolDoesNotExist();
    error ZeroAddress();
    error EmptyTokenIds();
    error InsufficientFungibleAmount();
    error InsufficientNFTInventory();
    error InvalidCurveParameter();
    error FeeExceedsMaximum();
    error NotPoolOperator();
    error NoAssetsProvided();
    error InvalidTradeAmount();
    error PriceOutOfBounds();
    error SlippageExceeded();
    error NFTAlreadyInPool();
    error NFTNotInPool();
    error TransferFailed();

    event PoolCreated(
        uint256 indexed poolId,
        address indexed nftCollection,
        address indexed fungibleToken,
        uint256 spotPrice,
        uint256 delta,
        uint256 feeBps,
        address royaltyRecipient,
        uint256 royaltyBps
    );
    event LiquidityAdded(
        uint256 indexed poolId,
        address indexed provider,
        uint256 fungibleAmount,
        uint256[] nftIds
    );
    event LiquidityRemoved(
        uint256 indexed poolId,
        address indexed provider,
        uint256 fungibleAmount,
        uint256[] nftIds
    );
    event NFTBought(
        uint256 indexed poolId,
        address indexed buyer,
        uint256[] nftIds,
        uint256 totalPaid,
        uint256 platformFee,
        uint256 royalty
    );
    event NFTSold(
        uint256 indexed poolId,
        address indexed seller,
        uint256[] nftIds,
        uint256 totalReceived,
        uint256 platformFee,
        uint256 royalty
    );
    event CurveUpdated(uint256 indexed poolId, uint256 spotPrice, uint256 delta);
    event RoyaltyRecipientUpdated(uint256 indexed poolId, address indexed recipient, uint256 royaltyBps);
    event PlatformFeeUpdated(uint256 feeBps);
    event OperatorUpdated(address indexed operator);

    struct Pool {
        address nftCollection;
        address fungibleToken;
        address royaltyRecipient;
        uint256 fungibleBalance;
        uint256 nftInventory;
        uint256 spotPrice;
        uint256 delta;
        uint256 feeBps;
        uint256 royaltyBps;
        bool exists;
    }

    uint256 public constant MAX_FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DELTA = 1e15;
    uint256 public constant MAX_DELTA = 1e24;
    uint256 public constant MAX_ROYALTY_BPS = 1000; // 10%

    mapping(uint256 => Pool) public pools;
    mapping(uint256 => EnumerableSet.UintSet) internal poolNFTs;
    uint256 public nextPoolId;

    address public operator;
    uint256 public platformFeeBps = 50; // 0.5%

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotPoolOperator();
        _;
    }

    modifier poolExists(uint256 poolId) {
        if (!pools[poolId].exists) revert PoolDoesNotExist();
        _;
    }

    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
        emit PlatformFeeUpdated(platformFeeBps);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setPlatformFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        platformFeeBps = _feeBps;
        emit PlatformFeeUpdated(_feeBps);
    }

    function createPool(
        address _nftCollection,
        address _fungibleToken,
        address _royaltyRecipient,
        uint256 _spotPrice,
        uint256 _delta,
        uint256 _feeBps,
        uint256 _royaltyBps
    ) external returns (uint256 poolId) {
        if (_nftCollection == address(0)) revert ZeroAddress();
        if (_fungibleToken == address(0)) revert ZeroAddress();
        if (_royaltyRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        if (_royaltyBps > MAX_ROYALTY_BPS) revert FeeExceedsMaximum();
        if (_delta < MIN_DELTA || _delta > MAX_DELTA) revert InvalidCurveParameter();
        if (_spotPrice == 0) revert InvalidCurveParameter();

        poolId = nextPoolId++;
        pools[poolId] = Pool({
            nftCollection: _nftCollection,
            fungibleToken: _fungibleToken,
            royaltyRecipient: _royaltyRecipient,
            fungibleBalance: 0,
            nftInventory: 0,
            spotPrice: _spotPrice,
            delta: _delta,
            feeBps: _feeBps,
            royaltyBps: _royaltyBps,
            exists: true
        });

        emit PoolCreated(poolId, _nftCollection, _fungibleToken, _spotPrice, _delta, _feeBps, _royaltyRecipient, _royaltyBps);
    }

    function addLiquidity(
        uint256 poolId,
        uint256 fungibleAmount,
        uint256[] calldata nftIds
    ) external nonReentrant poolExists(poolId) {
        if (fungibleAmount == 0 && nftIds.length == 0) revert NoAssetsProvided();

        Pool storage pool = pools[poolId];

        // Effects: update state before interactions
        if (fungibleAmount > 0) {
            pool.fungibleBalance += fungibleAmount;
        }

        if (nftIds.length > 0) {
            pool.nftInventory += nftIds.length;
            for (uint256 i = 0; i < nftIds.length; ) {
                if (!poolNFTs[poolId].add(nftIds[i])) revert NFTAlreadyInPool();
                unchecked {
                    ++i;
                }
            }
        }

        // Interactions
        if (fungibleAmount > 0) {
            _safeTransferFrom(pool.fungibleToken, address(this), fungibleAmount);
        }

        if (nftIds.length > 0) {
            IERC721 nft = IERC721(pool.nftCollection);
            for (uint256 i = 0; i < nftIds.length; ) {
                nft.transferFrom(msg.sender, address(this), nftIds[i]);
                unchecked {
                    ++i;
                }
            }
        }

        emit LiquidityAdded(poolId, msg.sender, fungibleAmount, nftIds);
    }

    function removeLiquidity(
        uint256 poolId,
        uint256 fungibleAmount,
        uint256[] calldata nftIds
    ) external nonReentrant poolExists(poolId) {
        if (fungibleAmount == 0 && nftIds.length == 0) revert NoAssetsProvided();

        Pool storage pool = pools[poolId];

        // Effects: update state before interactions
        if (fungibleAmount > 0) {
            if (fungibleAmount > pool.fungibleBalance) revert InsufficientFungibleAmount();
            pool.fungibleBalance -= fungibleAmount;
        }

        if (nftIds.length > 0) {
            if (nftIds.length > pool.nftInventory) revert InsufficientNFTInventory();
            pool.nftInventory -= nftIds.length;
            for (uint256 i = 0; i < nftIds.length; ) {
                if (!poolNFTs[poolId].remove(nftIds[i])) revert NFTNotInPool();
                unchecked {
                    ++i;
                }
            }
        }

        // Interactions
        if (fungibleAmount > 0) {
            _safeTransfer(pool.fungibleToken, msg.sender, fungibleAmount);
        }

        if (nftIds.length > 0) {
            IERC721 nft = IERC721(pool.nftCollection);
            for (uint256 i = 0; i < nftIds.length; ) {
                nft.transferFrom(address(this), msg.sender, nftIds[i]);
                unchecked {
                    ++i;
                }
            }
        }

        emit LiquidityRemoved(poolId, msg.sender, fungibleAmount, nftIds);
    }

    function buyNFTs(
        uint256 poolId,
        uint256[] calldata nftIds,
        uint256 maxTokenAmount
    ) external nonReentrant poolExists(poolId) {
        if (nftIds.length == 0) revert EmptyTokenIds();

        Pool storage pool = pools[poolId];
        if (nftIds.length > pool.nftInventory) revert InsufficientNFTInventory();

        (uint256 totalPrice, uint256 platformFee, uint256 royalty) = _computeBuyPrice(poolId, nftIds.length);
        uint256 totalCost = totalPrice + platformFee + royalty;

        if (totalCost > maxTokenAmount) revert SlippageExceeded();

        // Effects: update state before interactions
        pool.fungibleBalance += totalPrice;
        pool.nftInventory -= nftIds.length;
        for (uint256 i = 0; i < nftIds.length; ) {
            if (!poolNFTs[poolId].remove(nftIds[i])) revert NFTNotInPool();
            unchecked {
                ++i;
            }
        }

        // Interactions
        _safeTransferFrom(pool.fungibleToken, address(this), totalCost);

        IERC721 nft = IERC721(pool.nftCollection);
        for (uint256 i = 0; i < nftIds.length; ) {
            nft.transferFrom(address(this), msg.sender, nftIds[i]);
            unchecked {
                ++i;
            }
        }

        if (platformFee > 0) {
            _safeTransfer(pool.fungibleToken, operator, platformFee);
        }
        if (royalty > 0) {
            _safeTransfer(pool.fungibleToken, pool.royaltyRecipient, royalty);
        }

        emit NFTBought(poolId, msg.sender, nftIds, totalCost, platformFee, royalty);
    }

    function sellNFTs(
        uint256 poolId,
        uint256[] calldata nftIds,
        uint256 minTokenAmount
    ) external nonReentrant poolExists(poolId) {
        if (nftIds.length == 0) revert EmptyTokenIds();

        Pool storage pool = pools[poolId];

        (uint256 totalPayout, uint256 platformFee, uint256 royalty) = _computeSellPrice(poolId, nftIds.length);
        uint256 totalCost = totalPayout + platformFee + royalty;

        if (totalCost > pool.fungibleBalance) revert InsufficientFungibleAmount();
        if (totalPayout < minTokenAmount) revert SlippageExceeded();

        // Effects: update state before interactions
        pool.nftInventory += nftIds.length;
        pool.fungibleBalance -= totalCost;
        for (uint256 i = 0; i < nftIds.length; ) {
            if (!poolNFTs[poolId].add(nftIds[i])) revert NFTAlreadyInPool();
            unchecked {
                ++i;
            }
        }

        // Interactions
        IERC721 nft = IERC721(pool.nftCollection);
        for (uint256 i = 0; i < nftIds.length; ) {
            nft.transferFrom(msg.sender, address(this), nftIds[i]);
            unchecked {
                ++i;
            }
        }

        _safeTransfer(pool.fungibleToken, msg.sender, totalPayout);

        if (platformFee > 0) {
            _safeTransfer(pool.fungibleToken, operator, platformFee);
        }
        if (royalty > 0) {
            _safeTransfer(pool.fungibleToken, pool.royaltyRecipient, royalty);
        }

        emit NFTSold(poolId, msg.sender, nftIds, totalPayout, platformFee, royalty);
    }

    function updateCurve(
        uint256 poolId,
        uint256 _spotPrice,
        uint256 _delta
    ) external onlyOperator poolExists(poolId) {
        if (_delta < MIN_DELTA || _delta > MAX_DELTA) revert InvalidCurveParameter();
        if (_spotPrice == 0) revert InvalidCurveParameter();
        Pool storage pool = pools[poolId];
        pool.spotPrice = _spotPrice;
        pool.delta = _delta;
        emit CurveUpdated(poolId, _spotPrice, _delta);
    }

    function updateRoyaltyRecipient(
        uint256 poolId,
        address _recipient,
        uint256 _royaltyBps
    ) external onlyOperator poolExists(poolId) {
        if (_recipient == address(0)) revert ZeroAddress();
        if (_royaltyBps > MAX_ROYALTY_BPS) revert FeeExceedsMaximum();
        pools[poolId].royaltyRecipient = _recipient;
        pools[poolId].royaltyBps = _royaltyBps;
        emit RoyaltyRecipientUpdated(poolId, _recipient, _royaltyBps);
    }

    function getPoolNFTs(uint256 poolId) external view poolExists(poolId) returns (uint256[] memory) {
        return poolNFTs[poolId].values();
    }

    function getPoolNFTCount(uint256 poolId) external view poolExists(poolId) returns (uint256) {
        return poolNFTs[poolId].length();
    }

    function getBuyPrice(uint256 poolId, uint256 quantity) external view poolExists(poolId) returns (uint256 totalCost) {
        if (quantity == 0) revert InvalidTradeAmount();
        (uint256 total, uint256 platformFee, uint256 royalty) = _computeBuyPrice(poolId, quantity);
        return total + platformFee + royalty;
    }

    function getSellPrice(uint256 poolId, uint256 quantity) external view poolExists(poolId) returns (uint256 totalPayout) {
        if (quantity == 0) revert InvalidTradeAmount();
        (uint256 total, , ) = _computeSellPrice(poolId, quantity);
        return total;
    }

    function _computeBuyPrice(
        uint256 poolId,
        uint256 quantity
    ) internal view returns (uint256 total, uint256 platformFee, uint256 royalty) {
        Pool storage pool = pools[poolId];
        uint256 price = pool.spotPrice;
        for (uint256 i = 0; i < quantity; ) {
            total += price;
            price += pool.delta;
            unchecked {
                ++i;
            }
        }
        uint256 feeBps = pool.feeBps + platformFeeBps;
        platformFee = (total * feeBps) / BPS_DENOMINATOR;
        royalty = (total * pool.royaltyBps) / BPS_DENOMINATOR;
    }

    function _computeSellPrice(
        uint256 poolId,
        uint256 quantity
    ) internal view returns (uint256 totalPayout, uint256 platformFee, uint256 royalty) {
        Pool storage pool = pools[poolId];
        uint256 price = pool.spotPrice;
        uint256 gross = 0;
        for (uint256 i = 0; i < quantity; ) {
            if (price <= pool.delta) revert PriceOutOfBounds();
            gross += price;
            price -= pool.delta;
            unchecked {
                ++i;
            }
        }
        uint256 feeBps = pool.feeBps + platformFeeBps;
        platformFee = (gross * feeBps) / BPS_DENOMINATOR;
        royalty = (gross * pool.royaltyBps) / BPS_DENOMINATOR;
        totalPayout = gross - platformFee - royalty;
    }

    function _safeTransferFrom(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
