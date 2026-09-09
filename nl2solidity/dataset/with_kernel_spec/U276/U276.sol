// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DigitalContentMarketplace
 * @notice Manages creation, ownership, listing, and purchase of digital content items.
 *         Applies a configurable fee (up to 10%) on each purchase, directed to a designated recipient.
 */
contract DigitalContentMarketplace {
    // ============ Custom Errors ============
    error Unauthorized();
    error ZeroAddressNotAllowed();
    error ContentDoesNotExist();
    error NotContentOwner();
    error PriceTooLow();
    error FeeTooHigh();
    error ContentAlreadyListed();
    error ContentNotListed();
    error InsufficientPayment();
    error CannotTransferToSelf();
    error ReentrancyDetected();
    error TransferFailed();

    // ============ Events ============
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeePercentageUpdated(uint256 oldFeePercentage, uint256 newFeePercentage);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event ContentCreated(uint256 indexed contentId, address indexed owner);
    event ContentListed(uint256 indexed contentId, address indexed owner, uint256 price);
    event ContentPurchased(uint256 indexed contentId, address indexed buyer, address indexed seller, uint256 price, uint256 fee);
    event ContentDelisted(uint256 indexed contentId, address indexed owner);
    event ContentTransferred(uint256 indexed contentId, address indexed from, address indexed to);

    // ============ Constants ============
    uint256 public constant MIN_PRICE = 0.001 ether;
    uint256 public constant MAX_FEE_PERCENTAGE = 10; // 10%

    // ============ State Variables ============
    address public contractOwner;
    uint256 public feePercentage; // in percentage points (e.g., 5 = 5%)
    address public feeRecipient;

    uint256 public nextContentId;
    uint256 public totalContent;

    struct Content {
        address owner;
        uint256 price;
        bool isListed;
    }

    mapping(uint256 => Content) private contents;

    uint256 private _locked = 1;

    // ============ Modifiers ============
    modifier onlyContractOwner() {
        if (msg.sender != contractOwner) revert Unauthorized();
        _;
    }

    modifier onlyContentOwner(uint256 contentId) {
        if (contents[contentId].owner == address(0)) revert ContentDoesNotExist();
        if (contents[contentId].owner != msg.sender) revert NotContentOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Constructor ============
    constructor(address _feeRecipient, uint256 _feePercentage) {
        if (_feeRecipient == address(0)) revert ZeroAddressNotAllowed();
        if (_feePercentage > MAX_FEE_PERCENTAGE) revert FeeTooHigh();
        contractOwner = msg.sender;
        feeRecipient = _feeRecipient;
        feePercentage = _feePercentage;
        nextContentId = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit FeePercentageUpdated(0, _feePercentage);
    }

    // ============ Ownership Management ============
    function transferContractOwnership(address newOwner) external onlyContractOwner {
        if (newOwner == address(0)) revert ZeroAddressNotAllowed();
        emit OwnershipTransferred(contractOwner, newOwner);
        contractOwner = newOwner;
    }

    // ============ Fee Configuration ============
    function setFeePercentage(uint256 newFeePercentage) external onlyContractOwner {
        if (newFeePercentage > MAX_FEE_PERCENTAGE) revert FeeTooHigh();
        uint256 oldFee = feePercentage;
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(oldFee, newFeePercentage);
    }

    function setFeeRecipient(address newRecipient) external onlyContractOwner {
        if (newRecipient == address(0)) revert ZeroAddressNotAllowed();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    // ============ Content Management ============
    function createContent() external returns (uint256 contentId) {
        contentId = nextContentId++;
        contents[contentId] = Content({
            owner: msg.sender,
            price: 0,
            isListed: false
        });
        totalContent++;
        emit ContentCreated(contentId, msg.sender);
    }

    function transferContent(uint256 contentId, address newOwner) external onlyContentOwner(contentId) {
        if (newOwner == address(0)) revert ZeroAddressNotAllowed();
        if (newOwner == msg.sender) revert CannotTransferToSelf();
        Content storage c = contents[contentId];
        if (c.isListed) {
            c.isListed = false;
            c.price = 0;
            emit ContentDelisted(contentId, msg.sender);
        }
        c.owner = newOwner;
        emit ContentTransferred(contentId, msg.sender, newOwner);
    }

    function listContent(uint256 contentId, uint256 price) external onlyContentOwner(contentId) {
        if (price < MIN_PRICE) revert PriceTooLow();
        Content storage c = contents[contentId];
        if (c.isListed) revert ContentAlreadyListed();
        c.price = price;
        c.isListed = true;
        emit ContentListed(contentId, msg.sender, price);
    }

    function delistContent(uint256 contentId) external onlyContentOwner(contentId) {
        Content storage c = contents[contentId];
        if (!c.isListed) revert ContentNotListed();
        c.isListed = false;
        c.price = 0;
        emit ContentDelisted(contentId, msg.sender);
    }

    function purchaseContent(uint256 contentId) external payable nonReentrant {
        Content storage c = contents[contentId];
        if (c.owner == address(0)) revert ContentDoesNotExist();
        if (!c.isListed) revert ContentNotListed();
        if (msg.sender == c.owner) revert CannotTransferToSelf();
        if (msg.value < c.price) revert InsufficientPayment();

        address seller = c.owner;
        uint256 salePrice = c.price;
        uint256 fee = (salePrice * feePercentage) / 100;
        uint256 sellerProceeds = salePrice - fee;

        // Effects: update state before external calls
        c.isListed = false;
        c.price = 0;
        c.owner = msg.sender;

        // Interactions: transfer funds
        if (fee > 0) {
            (bool feeSent, ) = feeRecipient.call{value: fee}("");
            if (!feeSent) revert TransferFailed();
        }
        if (sellerProceeds > 0) {
            (bool sellerPaid, ) = seller.call{value: sellerProceeds}("");
            if (!sellerPaid) revert TransferFailed();
        }

        // Refund any excess payment
        uint256 excess = msg.value - salePrice;
        if (excess > 0) {
            (bool refunded, ) = msg.sender.call{value: excess}("");
            if (!refunded) revert TransferFailed();
        }

        emit ContentPurchased(contentId, msg.sender, seller, salePrice, fee);
    }

    // ============ View Functions ============
    function getContent(uint256 contentId) external view returns (address owner_, uint256 price, bool isListed_) {
        Content storage c = contents[contentId];
        if (c.owner == address(0)) revert ContentDoesNotExist();
        return (c.owner, c.price, c.isListed);
    }

    function contentOwner(uint256 contentId) external view returns (address) {
        return contents[contentId].owner;
    }

    function isListed(uint256 contentId) external view returns (bool) {
        return contents[contentId].isListed;
    }

    function contentPrice(uint256 contentId) external view returns (uint256) {
        return contents[contentId].price;
    }
}
