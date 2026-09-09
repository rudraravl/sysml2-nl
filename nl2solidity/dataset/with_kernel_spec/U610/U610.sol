// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RealEstateTokenization {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_TOKENS_PER_PROPERTY = 10_000;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                              ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;

    /*//////////////////////////////////////////////////////////////
                              PROPERTY STORAGE
    //////////////////////////////////////////////////////////////*/
    struct Property {
        bytes32 legalDocHash;
        uint256 tokenPrice;
        uint256 totalSupply;
        bool exists;
        bool saleActive;
        uint256 salePricePerToken;
        uint256 totalSaleValue;
        uint256 redeemedTokens;
    }

    mapping(uint256 => Property) private properties;
    mapping(uint256 => mapping(address => uint256)) private balances;

    mapping(uint256 => uint256) public purchaseProceeds;
    mapping(uint256 => uint256) public salePool;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PropertyRegistered(
        uint256 indexed propertyId,
        bytes32 indexed legalDocHash,
        uint256 tokenPrice
    );
    event TokensMinted(uint256 indexed propertyId, address indexed to, uint256 amount);
    event TokensPurchased(
        uint256 indexed propertyId,
        address indexed buyer,
        uint256 amount,
        uint256 pricePaid
    );
    event TokensTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 fee
    );
    event SaleInitiated(
        uint256 indexed propertyId,
        uint256 salePricePerToken,
        uint256 totalSaleValue
    );
    event TokensRedeemed(
        uint256 indexed propertyId,
        address indexed redeemer,
        uint256 amount,
        uint256 payout
    );
    event PurchaseProceedsWithdrawn(uint256 indexed propertyId, address indexed owner, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    modifier propertyExists(uint256 propertyId) {
        require(properties[propertyId].exists, "PROPERTY_NOT_REGISTERED");
        _;
    }

    modifier saleNotActive(uint256 propertyId) {
        require(!properties[propertyId].saleActive, "SALE_ACTIVE");
        _;
    }

    modifier saleIsActive(uint256 propertyId) {
        require(properties[propertyId].saleActive, "SALE_NOT_ACTIVE");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _operator) {
        require(_operator != address(0), "OPERATOR_ZERO_ADDRESS");
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "NEW_OWNER_ZERO_ADDRESS");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "OPERATOR_ZERO_ADDRESS");
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                       PROPERTY MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function registerProperty(
        uint256 propertyId,
        bytes32 legalDocHash,
        uint256 tokenPrice
    ) external onlyOperator {
        Property storage prop = properties[propertyId];
        require(!prop.exists, "PROPERTY_ALREADY_REGISTERED");
        require(legalDocHash != bytes32(0), "INVALID_LEGAL_DOC_HASH");

        prop.exists = true;
        prop.legalDocHash = legalDocHash;
        prop.tokenPrice = tokenPrice;

        emit PropertyRegistered(propertyId, legalDocHash, tokenPrice);
    }

    function mintTokens(
        uint256 propertyId,
        address to,
        uint256 amount
    ) external onlyOperator propertyExists(propertyId) saleNotActive(propertyId) {
        require(to != address(0), "MINT_TO_ZERO_ADDRESS");
        require(amount > 0, "MINT_AMOUNT_ZERO");

        Property storage prop = properties[propertyId];
        require(
            prop.totalSupply + amount <= MAX_TOKENS_PER_PROPERTY,
            "EXCEEDS_MAX_TOKEN_SUPPLY"
        );

        prop.totalSupply += amount;
        balances[propertyId][to] += amount;

        emit TokensMinted(propertyId, to, amount);
    }

    function initiateSale(
        uint256 propertyId,
        uint256 salePricePerToken
    ) external payable onlyOperator propertyExists(propertyId) saleNotActive(propertyId) {
        Property storage prop = properties[propertyId];
        require(prop.totalSupply > 0, "NO_TOKENS_MINTED");
        require(salePricePerToken > 0, "SALE_PRICE_ZERO");

        require(
            prop.totalSupply <= type(uint256).max / salePricePerToken,
            "SALE_VALUE_OVERFLOW"
        );
        uint256 totalSaleValue = salePricePerToken * prop.totalSupply;
        require(msg.value == totalSaleValue, "INCORRECT_SALE_DEPOSIT");

        prop.saleActive = true;
        prop.salePricePerToken = salePricePerToken;
        prop.totalSaleValue = totalSaleValue;
        salePool[propertyId] = totalSaleValue;

        emit SaleInitiated(propertyId, salePricePerToken, totalSaleValue);
    }

    /*//////////////////////////////////////////////////////////////
                          TOKEN PURCHASE
    //////////////////////////////////////////////////////////////*/
    function purchaseTokens(
        uint256 propertyId,
        uint256 amount
    ) external payable propertyExists(propertyId) saleNotActive(propertyId) {
        require(amount > 0, "PURCHASE_AMOUNT_ZERO");

        Property storage prop = properties[propertyId];
        require(
            prop.totalSupply + amount <= MAX_TOKENS_PER_PROPERTY,
            "EXCEEDS_MAX_TOKEN_SUPPLY"
        );

        uint256 priceToPay;
        if (prop.tokenPrice > 0) {
            require(
                amount <= type(uint256).max / prop.tokenPrice,
                "PRICE_OVERFLOW"
            );
            priceToPay = prop.tokenPrice * amount;
        } else {
            priceToPay = 0;
        }
        require(msg.value == priceToPay, "INCORRECT_PAYMENT");

        prop.totalSupply += amount;
        balances[propertyId][msg.sender] += amount;
        purchaseProceeds[propertyId] += priceToPay;

        emit TokensPurchased(propertyId, msg.sender, amount, priceToPay);
    }

    /*//////////////////////////////////////////////////////////////
                          TOKEN TRANSFER
    //////////////////////////////////////////////////////////////*/
    function transferTokens(
        uint256 propertyId,
        address to,
        uint256 amount
    ) external propertyExists(propertyId) {
        require(to != address(0), "TRANSFER_TO_ZERO_ADDRESS");
        require(to != msg.sender, "TRANSFER_TO_SELF");
        require(amount > 0, "TRANSFER_AMOUNT_ZERO");

        uint256 senderBalance = balances[propertyId][msg.sender];
        require(senderBalance >= amount, "INSUFFICIENT_BALANCE");

        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        uint256 recipientAmount = amount - fee;

        balances[propertyId][msg.sender] = senderBalance - amount;
        balances[propertyId][to] += recipientAmount;
        if (fee > 0) {
            balances[propertyId][owner] += fee;
        }

        emit TokensTransferred(propertyId, msg.sender, to, recipientAmount, fee);
    }

    /*//////////////////////////////////////////////////////////////
                          TOKEN REDEMPTION
    //////////////////////////////////////////////////////////////*/
    function redeemTokens(
        uint256 propertyId,
        uint256 amount
    ) external propertyExists(propertyId) saleIsActive(propertyId) {
        require(amount > 0, "REDEEM_AMOUNT_ZERO");

        uint256 senderBalance = balances[propertyId][msg.sender];
        require(senderBalance >= amount, "INSUFFICIENT_BALANCE");

        Property storage prop = properties[propertyId];
        require(
            amount <= type(uint256).max / prop.salePricePerToken,
            "PAYOUT_OVERFLOW"
        );
        uint256 payout = prop.salePricePerToken * amount;
        require(salePool[propertyId] >= payout, "INSUFFICIENT_SALE_POOL");

        // Effects
        balances[propertyId][msg.sender] = senderBalance - amount;
        prop.totalSupply -= amount;
        prop.redeemedTokens += amount;
        salePool[propertyId] -= payout;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: payout}("");
        require(success, "PAYOUT_FAILED");

        emit TokensRedeemed(propertyId, msg.sender, amount, payout);
    }

    /*//////////////////////////////////////////////////////////////
                       PROCEEDS WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function withdrawPurchaseProceeds(uint256 propertyId) external onlyOwner propertyExists(propertyId) {
        uint256 amount = purchaseProceeds[propertyId];
        require(amount > 0, "NO_PROCEEDS_TO_WITHDRAW");

        purchaseProceeds[propertyId] = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "WITHDRAWAL_FAILED");

        emit PurchaseProceedsWithdrawn(propertyId, owner, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getProperty(uint256 propertyId)
        external
        view
        returns (
            bytes32 legalDocHash,
            uint256 tokenPrice,
            uint256 totalSupply,
            bool exists,
            bool saleActive,
            uint256 salePricePerToken,
            uint256 totalSaleValue,
            uint256 redeemedTokens
        )
    {
        Property storage prop = properties[propertyId];
        return (
            prop.legalDocHash,
            prop.tokenPrice,
            prop.totalSupply,
            prop.exists,
            prop.saleActive,
            prop.salePricePerToken,
            prop.totalSaleValue,
            prop.redeemedTokens
        );
    }

    function totalSupply(uint256 propertyId) external view returns (uint256) {
        return properties[propertyId].totalSupply;
    }

    function balanceOf(uint256 propertyId, address account)
        external
        view
        propertyExists(propertyId)
        returns (uint256)
    {
        return balances[propertyId][account];
    }

    function getSalePool(uint256 propertyId) external view returns (uint256) {
        return salePool[propertyId];
    }

    function getPurchaseProceeds(uint256 propertyId) external view returns (uint256) {
        return purchaseProceeds[propertyId];
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/
    receive() external payable {
        revert("DIRECT_ETHER_NOT_ACCEPTED");
    }
}
