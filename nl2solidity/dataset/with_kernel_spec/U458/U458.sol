// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721Minimal {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
}

contract NFTMarket {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Maximum number of NFTs per single order (buy or sell).
    uint256 public constant MAX_ORDER_SIZE = 100;

    /// @dev Denominator for basis-point fee calculations.
    uint256 public constant FEE_DENOMINATOR = 10000;

    /// @dev Upper bound on the operator-settable trading fee (10 %).
    uint256 public constant MAX_FEE_BPS = 1000;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error NotOrderCreator();
    error CollectionNotSupported();
    error CollectionAlreadySupported();
    error ZeroAddress();
    error InvalidPrice();
    error InvalidQuantity();
    error OrderNotActive();
    error QuantityExceedsRemaining();
    error InsufficientBalance();
    error NotTokenOwner();
    error NotApprovedForTransfer();
    error InvalidFeeBps();
    error EmptyTokenIds();
    error TransferFailed();
    error ReentrancyDetected();
    error NoFeesToClaim();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event BuyOrderCreated(
        uint256 indexed orderId,
        address indexed creator,
        address indexed collection,
        uint256 pricePerNFT,
        uint256 quantity
    );
    event SellOrderCreated(
        uint256 indexed orderId,
        address indexed creator,
        address indexed collection,
        uint256 pricePerNFT,
        uint256 tokenCount
    );
    event BuyOrderCancelled(uint256 indexed orderId, uint256 refundAmount);
    event SellOrderCancelled(uint256 indexed orderId, uint256 returnedCount);

    /// @dev Emitted when a sell order is filled — i.e. a successful NFT purchase.
    event NFTPurchased(
        uint256 indexed orderId,
        address indexed buyer,
        address indexed seller,
        address collection,
        uint256[] tokenIds,
        uint256 totalPrice,
        uint256 fee
    );

    /// @dev Emitted when a buy order is filled — i.e. a successful NFT sale.
    event NFTSold(
        uint256 indexed orderId,
        address indexed seller,
        address indexed buyer,
        address collection,
        uint256[] tokenIds,
        uint256 totalPrice,
        uint256 fee
    );

    /// @dev Emitted whenever the operator changes the trading fee.
    event TradingFeeUpdated(uint256 indexed oldFeeBps, uint256 indexed newFeeBps);

    event CollectionAdded(address indexed collection);
    event FeesClaimed(address indexed operator, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public operator;
    address public immutable paymentToken;

    /// @dev Individual fungible-token balances credited to each user.
    mapping(address => uint256) public balances;

    /// @dev Total fungible tokens custodied by the contract.
    uint256 public globalReserve;

    /// @dev Portion of the global reserve currently locked in pending buy orders.
    uint256 public lockedAmount;

    /// @dev Trading fees accumulated and claimable by the operator.
    uint256 public accumulatedFees;

    /// @dev Current trading fee in basis points (50 = 0.5 %).
    uint256 public tradingFeeBps;

    mapping(address => bool) public supportedCollections;
    address[] public allCollections;

    struct BuyOrder {
        address creator;
        address collection;
        uint256 pricePerNFT;
        uint256 quantityRemaining;
        bool active;
    }

    struct SellOrder {
        address creator;
        address collection;
        uint256 pricePerNFT;
        uint256[] tokenIds;
        bool active;
    }

    mapping(uint256 => BuyOrder) public buyOrders;
    mapping(uint256 => SellOrder) public sellOrders;
    uint256 public nextBuyOrderId;
    uint256 public nextSellOrderId;

    bool private _locked;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrancyDetected();
        _locked = true;
        _;
        _locked = false;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _paymentToken, address _operator) {
        if (_paymentToken == address(0) || _operator == address(0)) revert ZeroAddress();
        paymentToken = _paymentToken;
        operator = _operator;
        tradingFeeBps = 50; // 0.5 %
        nextBuyOrderId = 1;
        nextSellOrderId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                      FUNGIBLE TOKEN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit fungible tokens into the caller's custodial balance.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidQuantity();

        // Effects
        balances[msg.sender] += amount;
        globalReserve += amount;

        // Interactions
        if (!IERC20(paymentToken).transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        emit Deposit(msg.sender, amount);
    }

    /// @notice Withdraw fungible tokens from the caller's custodial balance.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidQuantity();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        // Effects
        balances[msg.sender] -= amount;
        globalReserve -= amount;

        // Interactions
        if (!IERC20(paymentToken).transfer(msg.sender, amount)) {
            revert TransferFailed();
        }

        emit Withdrawal(msg.sender, amount);
    }

    /// @notice Operator claims accumulated trading fees.
    function claimFees() external onlyOperator nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToClaim();

        // Effects
        accumulatedFees = 0;
        globalReserve -= amount;

        // Interactions
        if (!IERC20(paymentToken).transfer(operator, amount)) {
            revert TransferFailed();
        }

        emit FeesClaimed(operator, amount);
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Whitelist a new NFT collection for trading.
    function addCollection(address collection) external onlyOperator {
        if (collection == address(0)) revert ZeroAddress();
        if (supportedCollections[collection]) revert CollectionAlreadySupported();
        supportedCollections[collection] = true;
        allCollections.push(collection);
        emit CollectionAdded(collection);
    }

    /// @notice Adjust the trading fee (in basis points). Capped at MAX_FEE_BPS.
    function setTradingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        uint256 oldFee = tradingFeeBps;
        tradingFeeBps = newFeeBps;
        emit TradingFeeUpdated(oldFee, newFeeBps);
    }

    /// @notice Transfer the operator role to a new address.
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
    }

    /*//////////////////////////////////////////////////////////////
                         BUY ORDER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a buy order that locks fungible tokens to purchase NFTs
    ///         from a supported collection at a fixed price per NFT.
    function createBuyOrder(
        address collection,
        uint256 pricePerNFT,
        uint256 quantity
    ) external nonReentrant {
        if (!supportedCollections[collection]) revert CollectionNotSupported();
        if (pricePerNFT == 0) revert InvalidPrice();
        if (quantity == 0 || quantity > MAX_ORDER_SIZE) revert InvalidQuantity();

        uint256 totalCost = pricePerNFT * quantity;
        if (balances[msg.sender] < totalCost) revert InsufficientBalance();

        // Effects
        balances[msg.sender] -= totalCost;
        lockedAmount += totalCost;

        uint256 orderId = nextBuyOrderId++;
        buyOrders[orderId] = BuyOrder({
            creator: msg.sender,
            collection: collection,
            pricePerNFT: pricePerNFT,
            quantityRemaining: quantity,
            active: true
        });

        emit BuyOrderCreated(orderId, msg.sender, collection, pricePerNFT, quantity);
    }

    /// @notice Cancel a pending buy order and refund the remaining locked tokens.
    function cancelBuyOrder(uint256 orderId) external nonReentrant {
        BuyOrder storage order = buyOrders[orderId];
        if (!order.active) revert OrderNotActive();
        if (order.creator != msg.sender) revert NotOrderCreator();

        // Effects
        uint256 refund = order.pricePerNFT * order.quantityRemaining;
        order.quantityRemaining = 0;
        order.active = false;
        lockedAmount -= refund;
        balances[msg.sender] += refund;

        emit BuyOrderCancelled(orderId, refund);
    }

    /// @notice Fill a buy order by selling the specified NFTs to the order creator.
    ///         The seller receives the proceeds (minus fee) credited to their balance.
    function fillBuyOrder(uint256 orderId, uint256[] calldata tokenIds) external nonReentrant {
        BuyOrder storage order = buyOrders[orderId];
        if (!order.active) revert OrderNotActive();
        if (tokenIds.length == 0) revert EmptyTokenIds();
        if (tokenIds.length > order.quantityRemaining) revert QuantityExceedsRemaining();

        address collection = order.collection;

        // Checks — verify seller owns and has approved each NFT.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (IERC721Minimal(collection).ownerOf(tokenIds[i]) != msg.sender) {
                revert NotTokenOwner();
            }
            if (
                !IERC721Minimal(collection).isApprovedForAll(msg.sender, address(this)) &&
                IERC721Minimal(collection).getApproved(tokenIds[i]) != address(this)
            ) {
                revert NotApprovedForTransfer();
            }
        }

        uint256 totalPrice = order.pricePerNFT * tokenIds.length;
        uint256 fee = (totalPrice * tradingFeeBps) / FEE_DENOMINATOR;
        uint256 sellerProceeds = totalPrice - fee;

        // Effects
        order.quantityRemaining -= tokenIds.length;
        if (order.quantityRemaining == 0) {
            order.active = false;
        }
        lockedAmount -= totalPrice;
        balances[msg.sender] += sellerProceeds;
        accumulatedFees += fee;

        address buyer = order.creator;

        // Interactions — transfer NFTs from seller directly to buyer.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721Minimal(collection).transferFrom(msg.sender, buyer, tokenIds[i]);
        }

        emit NFTSold(orderId, msg.sender, buyer, collection, tokenIds, totalPrice, fee);
    }

    /*//////////////////////////////////////////////////////////////
                         SELL ORDER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a sell order by custodying NFTs for sale at a fixed price.
    function createSellOrder(
        address collection,
        uint256[] calldata tokenIds,
        uint256 pricePerNFT
    ) external nonReentrant {
        if (!supportedCollections[collection]) revert CollectionNotSupported();
        if (pricePerNFT == 0) revert InvalidPrice();
        if (tokenIds.length == 0 || tokenIds.length > MAX_ORDER_SIZE) revert InvalidQuantity();

        // Checks — verify ownership and approval before custodying.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (IERC721Minimal(collection).ownerOf(tokenIds[i]) != msg.sender) {
                revert NotTokenOwner();
            }
            if (
                !IERC721Minimal(collection).isApprovedForAll(msg.sender, address(this)) &&
                IERC721Minimal(collection).getApproved(tokenIds[i]) != address(this)
            ) {
                revert NotApprovedForTransfer();
            }
        }

        // Effects — record the sell order in storage.
        uint256 orderId = nextSellOrderId++;
        SellOrder storage order = sellOrders[orderId];
        order.creator = msg.sender;
        order.collection = collection;
        order.pricePerNFT = pricePerNFT;
        order.active = true;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            order.tokenIds.push(tokenIds[i]);
        }

        // Interactions — custody the NFTs.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721Minimal(collection).transferFrom(msg.sender, address(this), tokenIds[i]);
        }

        emit SellOrderCreated(orderId, msg.sender, collection, pricePerNFT, tokenIds.length);
    }

    /// @notice Cancel a pending sell order and return the remaining NFTs.
    function cancelSellOrder(uint256 orderId) external nonReentrant {
        SellOrder storage order = sellOrders[orderId];
        if (!order.active) revert OrderNotActive();
        if (order.creator != msg.sender) revert NotOrderCreator();

        address collection = order.collection;
        uint256 count = order.tokenIds.length;

        // Copy token IDs to memory before clearing storage.
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = order.tokenIds[i];
        }

        // Effects
        order.active = false;
        delete order.tokenIds;

        // Interactions — return NFTs to the creator.
        for (uint256 i = 0; i < count; i++) {
            IERC721Minimal(collection).transferFrom(address(this), msg.sender, ids[i]);
        }

        emit SellOrderCancelled(orderId, count);
    }

    /// @notice Fill a sell order by purchasing `quantity` NFTs with fungible tokens.
    ///         The buyer pays the full price; the seller receives proceeds minus the fee.
    function fillSellOrder(uint256 orderId, uint256 quantity) external nonReentrant {
        SellOrder storage order = sellOrders[orderId];
        if (!order.active) revert OrderNotActive();
        if (quantity == 0) revert InvalidQuantity();
        if (quantity > order.tokenIds.length) revert QuantityExceedsRemaining();

        uint256 totalPrice = order.pricePerNFT * quantity;
        uint256 fee = (totalPrice * tradingFeeBps) / FEE_DENOMINATOR;
        uint256 sellerProceeds = totalPrice - fee;

        if (balances[msg.sender] < totalPrice) revert InsufficientBalance();

        address collection = order.collection;
        address seller = order.creator;

        // Effects
        balances[msg.sender] -= totalPrice;
        balances[seller] += sellerProceeds;
        accumulatedFees += fee;

        // Pop `quantity` NFTs from the tail of the order's token list.
        uint256[] memory boughtIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            boughtIds[i] = order.tokenIds[order.tokenIds.length - 1];
            order.tokenIds.pop();
        }

        if (order.tokenIds.length == 0) {
            order.active = false;
        }

        // Interactions — transfer NFTs from the contract to the buyer.
        for (uint256 i = 0; i < quantity; i++) {
            IERC721Minimal(collection).transferFrom(address(this), msg.sender, boughtIds[i]);
        }

        emit NFTPurchased(orderId, msg.sender, seller, collection, boughtIds, totalPrice, fee);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isCollectionSupported(address collection) external view returns (bool) {
        return supportedCollections[collection];
    }

    function getCollectionCount() external view returns (uint256) {
        return allCollections.length;
    }

    function getAllCollections() external view returns (address[] memory) {
        return allCollections;
    }

    function getBuyOrder(uint256 orderId) external view returns (BuyOrder memory) {
        return buyOrders[orderId];
    }

    function getSellOrder(uint256 orderId) external view returns (SellOrder memory) {
        return sellOrders[orderId];
    }

    function getSellOrderTokenIds(uint256 orderId) external view returns (uint256[] memory) {
        return sellOrders[orderId].tokenIds;
    }
}
