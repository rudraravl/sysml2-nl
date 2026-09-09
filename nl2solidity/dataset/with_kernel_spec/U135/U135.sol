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
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IRoomNFT is IERC721 {
    function mint(address to) external returns (uint256);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract RoomMarketplace is IERC721Receiver {
    error ZeroAddress();
    error NotOperator();
    error NotRoomOwner();
    error RoomNotForSale();
    error CannotBuyOwnRoom();
    error InvalidPrice();
    error FeeExceedsMaximum();
    error PaymentTransferFailed();
    error PayoutTransferFailed();
    error ReentrantCall();

    event RoomCreated(uint256 indexed roomId, address indexed creator, uint256 price);
    event RoomBought(uint256 indexed roomId, address indexed buyer, address indexed seller, uint256 price, uint256 fee);
    event PriceUpdated(uint256 indexed roomId, address indexed owner, uint256 oldPrice, uint256 newPrice);
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event MarketplaceFeeUpdated(uint256 oldPercentage, uint256 newPercentage);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MAX_FEE_PERCENTAGE = 100;
    uint256 public constant DEFAULT_CREATION_FEE = 100;
    uint256 public constant DEFAULT_MARKETPLACE_FEE_PERCENTAGE = 5;

    IERC20 public immutable paymentToken;
    IRoomNFT public immutable roomToken;

    address public feeRecipient;
    address public operator;

    uint256 public creationFee;
    uint256 public marketplaceFeePercentage;

    mapping(uint256 => uint256) public roomPrice;
    mapping(uint256 => address) public roomOwner;

    bool private _locked;

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(
        address paymentToken_,
        address roomToken_,
        address feeRecipient_,
        address operator_
    ) {
        if (paymentToken_ == address(0)) revert ZeroAddress();
        if (roomToken_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();

        paymentToken = IERC20(paymentToken_);
        roomToken = IRoomNFT(roomToken_);
        feeRecipient = feeRecipient_;
        operator = operator_;
        creationFee = DEFAULT_CREATION_FEE;
        marketplaceFeePercentage = DEFAULT_MARKETPLACE_FEE_PERCENTAGE;
    }

    function createRoom(uint256 price) external nonReentrant returns (uint256 roomId) {
        if (price == 0) revert InvalidPrice();

        if (creationFee > 0) {
            if (!paymentToken.transferFrom(msg.sender, feeRecipient, creationFee)) {
                revert PaymentTransferFailed();
            }
        }

        roomId = roomToken.mint(address(this));
        roomOwner[roomId] = msg.sender;
        roomPrice[roomId] = price;

        emit RoomCreated(roomId, msg.sender, price);
    }

    function buyRoom(uint256 roomId) external nonReentrant {
        uint256 price = roomPrice[roomId];
        if (price == 0) revert RoomNotForSale();

        address seller = roomOwner[roomId];
        if (seller == msg.sender) revert CannotBuyOwnRoom();

        uint256 fee = (price * marketplaceFeePercentage) / 100;
        uint256 sellerProceeds = price - fee;

        roomOwner[roomId] = msg.sender;
        roomPrice[roomId] = 0;

        if (!paymentToken.transferFrom(msg.sender, address(this), price)) {
            revert PaymentTransferFailed();
        }

        if (fee > 0) {
            if (!paymentToken.transfer(feeRecipient, fee)) {
                revert PayoutTransferFailed();
            }
        }

        if (sellerProceeds > 0) {
            if (!paymentToken.transfer(seller, sellerProceeds)) {
                revert PayoutTransferFailed();
            }
        }

        roomToken.transferFrom(address(this), msg.sender, roomId);

        emit RoomBought(roomId, msg.sender, seller, price, fee);
    }

    function setPrice(uint256 roomId, uint256 newPrice) external {
        if (roomOwner[roomId] != msg.sender) revert NotRoomOwner();

        uint256 oldPrice = roomPrice[roomId];
        roomPrice[roomId] = newPrice;

        emit PriceUpdated(roomId, msg.sender, oldPrice, newPrice);
    }

    function setCreationFee(uint256 newFee) external onlyOperator {
        uint256 oldFee = creationFee;
        creationFee = newFee;
        emit CreationFeeUpdated(oldFee, newFee);
    }

    function setMarketplaceFeePercentage(uint256 newPercentage) external onlyOperator {
        if (newPercentage > MAX_FEE_PERCENTAGE) revert FeeExceedsMaximum();
        uint256 oldPercentage = marketplaceFeePercentage;
        marketplaceFeePercentage = newPercentage;
        emit MarketplaceFeeUpdated(oldPercentage, newPercentage);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function getRoomPrice(uint256 roomId) external view returns (uint256) {
        return roomPrice[roomId];
    }

    function getRoomOwner(uint256 roomId) external view returns (address) {
        return roomOwner[roomId];
    }

    function isRoomForSale(uint256 roomId) external view returns (bool) {
        return roomPrice[roomId] > 0;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
