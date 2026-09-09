// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error Unauthorized();
error PropertyAlreadyOnboarded();
error PropertyNotFound();
error OnboardingFeeNotPaid();
error OnboardingFeeAlreadyPaid();
error IncorrectOnboardingFee();
error CapExceeded();
error InsufficientBalance();
error ZeroAddress();
error InvalidAmount();
error InvalidPrice();
error NoRentalIncomeAvailable();
error InsufficientPayment();
error TransferFailed();
error NothingToWithdraw();

contract RealEstateToken {
    address public owner;
    address public operator;

    uint256 public constant CAP_PER_PROPERTY = 1_000_000;
    uint256 public constant ONBOARDING_FEE_BPS = 50; // 0.5% = 50 basis points

    struct Property {
        bytes32 legalDocHash;
        uint256 tokenPrice;            // price per token in wei
        uint256 totalSupply;           // current total supply of tokens
        uint256 initialIssuanceValue;  // tokenPrice * initialTokenAmount
        uint256 onboardingFee;         // 0.5% of initialIssuanceValue
        bool onboarded;
        bool onboardingFeePaid;
        uint256 rentalPool;            // accumulated rental income for the property
    }

    mapping(bytes32 => Property) public properties;
    mapping(bytes32 => mapping(address => uint256)) public balanceOf;

    uint256 public totalFeesCollected; // tracks onboarding fees separately from rental income

    event PropertyOnboarded(
        bytes32 indexed propertyId,
        bytes32 legalDocHash,
        uint256 tokenPrice,
        uint256 initialTokenAmount,
        uint256 initialIssuanceValue,
        uint256 onboardingFee
    );
    event OnboardingFeePaid(bytes32 indexed propertyId, address indexed payer, uint256 amount);
    event Transfer(bytes32 indexed propertyId, address indexed from, address indexed to, uint256 amount);
    event TokensMinted(bytes32 indexed propertyId, address indexed to, uint256 amount);
    event TokensBurned(bytes32 indexed propertyId, address indexed from, uint256 amount);
    event TokensPurchased(bytes32 indexed propertyId, address indexed buyer, uint256 amount, uint256 cost);
    event RentalIncomeDeposited(bytes32 indexed propertyId, address indexed depositor, uint256 amount);
    event RentalIncomeRedeemed(bytes32 indexed propertyId, address indexed holder, uint256 tokensRedeemed, uint256 payout);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function onboardProperty(
        bytes32 propertyId,
        bytes32 legalDocHash,
        uint256 tokenPrice,
        uint256 initialTokenAmount
    ) external onlyOwner {
        Property storage p = properties[propertyId];
        if (p.onboarded) revert PropertyAlreadyOnboarded();
        if (tokenPrice == 0) revert InvalidPrice();
        if (initialTokenAmount == 0) revert InvalidAmount();
        if (initialTokenAmount > CAP_PER_PROPERTY) revert CapExceeded();

        uint256 issuanceValue = tokenPrice * initialTokenAmount;
        uint256 fee = (issuanceValue * ONBOARDING_FEE_BPS) / 10_000;

        p.legalDocHash = legalDocHash;
        p.tokenPrice = tokenPrice;
        p.initialIssuanceValue = issuanceValue;
        p.onboardingFee = fee;
        p.onboarded = true;
        p.onboardingFeePaid = false;
        p.rentalPool = 0;

        emit PropertyOnboarded(propertyId, legalDocHash, tokenPrice, initialTokenAmount, issuanceValue, fee);
    }

    function payOnboardingFee(bytes32 propertyId) external payable {
        Property storage p = properties[propertyId];
        if (!p.onboarded) revert PropertyNotFound();
        if (p.onboardingFeePaid) revert OnboardingFeeAlreadyPaid();
        if (msg.value != p.onboardingFee) revert IncorrectOnboardingFee();
        p.onboardingFeePaid = true;
        totalFeesCollected += msg.value;
        emit OnboardingFeePaid(propertyId, msg.sender, msg.value);
    }

    function mint(bytes32 propertyId, address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        Property storage p = properties[propertyId];
        if (!p.onboarded) revert PropertyNotFound();
        if (!p.onboardingFeePaid) revert OnboardingFeeNotPaid();
        if (p.totalSupply + amount > CAP_PER_PROPERTY) revert CapExceeded();

        p.totalSupply += amount;
        balanceOf[propertyId][to] += amount;

        emit TokensMinted(propertyId, to, amount);
        emit Transfer(propertyId, address(0), to, amount);
    }

    function burn(bytes32 propertyId, address from, uint256 amount) external onlyOperator {
        if (amount == 0) revert InvalidAmount();
        Property storage p = properties[propertyId];
        if (!p.onboarded) revert PropertyNotFound();
        if (balanceOf[propertyId][from] < amount) revert InsufficientBalance();

        balanceOf[propertyId][from] -= amount;
        p.totalSupply -= amount;

        emit TokensBurned(propertyId, from, amount);
        emit Transfer(propertyId, from, address(0), amount);
    }

    function purchaseTokens(bytes32 propertyId, uint256 amount) external payable {
        if (amount == 0) revert InvalidAmount();
        Property storage p = properties[propertyId];
        if (!p.onboarded) revert PropertyNotFound();
        if (!p.onboardingFeePaid) revert OnboardingFeeNotPaid();
        if (p.totalSupply + amount > CAP_PER_PROPERTY) revert CapExceeded();

        uint256 cost = p.tokenPrice * amount;
        if (msg.value < cost) revert InsufficientPayment();

        p.totalSupply += amount;
        balanceOf[propertyId][msg.sender] += amount;

        if (msg.value > cost) {
            uint256 refund = msg.value - cost;
            (bool success, ) = msg.sender.call{value: refund}("");
            if (!success) revert TransferFailed();
        }

        emit TokensMinted(propertyId, msg.sender, amount);
        emit Transfer(propertyId, address(0), msg.sender, amount);
        emit TokensPurchased(propertyId, msg.sender, amount, cost);
    }

    function transfer(bytes32 propertyId, address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        Property storage p = properties[propertyId];
        if (!p.onboarded) revert PropertyNotFound();
        if (balanceOf[propertyId][msg.sender] < amount) revert InsufficientBalance();

        balanceOf[propertyId][msg.sender] -= amount;
        balanceOf[propertyId][to] += amount;

        emit Transfer(propertyId, msg.sender, to, amount);
    }

    function depositRentalIncome(bytes32 propertyId) external payable onlyOperator {
        if (msg.value == 0) revert InvalidAmount();
        Property storage p = properties[propertyId];
        if (!p.onboarded) revert PropertyNotFound();
        p.rentalPool += msg.value;
        emit RentalIncomeDeposited(propertyId, msg.sender, msg.value);
    }

    function redeemRentalIncome(bytes32 propertyId, uint256 tokensToRedeem) external {
        if (tokensToRedeem == 0) revert InvalidAmount();
        Property storage p = properties[propertyId];
        if (!p.onboarded) revert PropertyNotFound();
        if (balanceOf[propertyId][msg.sender] < tokensToRedeem) revert InsufficientBalance();
        if (p.totalSupply == 0) revert NoRentalIncomeAvailable();
        if (p.rentalPool == 0) revert NoRentalIncomeAvailable();

        uint256 payout = (p.rentalPool * tokensToRedeem) / p.totalSupply;
        if (payout == 0) revert NoRentalIncomeAvailable();

        // Effects
        balanceOf[propertyId][msg.sender] -= tokensToRedeem;
        p.totalSupply -= tokensToRedeem;
        p.rentalPool -= payout;

        emit TokensBurned(propertyId, msg.sender, tokensToRedeem);
        emit Transfer(propertyId, msg.sender, address(0), tokensToRedeem);
        emit RentalIncomeRedeemed(propertyId, msg.sender, tokensToRedeem, payout);

        // Interaction
        (bool success, ) = msg.sender.call{value: payout}("");
        if (!success) revert TransferFailed();
    }

    function getLegalDocHash(bytes32 propertyId) external view returns (bytes32) {
        return properties[propertyId].legalDocHash;
    }

    function propertyTotalSupply(bytes32 propertyId) external view returns (uint256) {
        return properties[propertyId].totalSupply;
    }

    function propertyRentalPool(bytes32 propertyId) external view returns (uint256) {
        return properties[propertyId].rentalPool;
    }

    function isOnboarded(bytes32 propertyId) external view returns (bool) {
        return properties[propertyId].onboarded;
    }

    function isOnboardingFeePaid(bytes32 propertyId) external view returns (bool) {
        return properties[propertyId].onboardingFeePaid;
    }

    function onboardingFeeOf(bytes32 propertyId) external view returns (uint256) {
        return properties[propertyId].onboardingFee;
    }

    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = totalFeesCollected;
        if (amount == 0) revert NothingToWithdraw();
        totalFeesCollected = 0;
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit FeesWithdrawn(to, amount);
    }
}
