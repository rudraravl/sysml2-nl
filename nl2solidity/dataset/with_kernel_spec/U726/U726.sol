// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) {
            require(token.transferFrom(from, to, amount), "SafeERC20: transferFrom failed");
        }
    }
}

/**
 * @title StablePay
 * @notice Facilitates direct stablecoin payments between users and merchants.
 *         The contract holds no funds; payments are routed directly from payer
 *         to the merchant's designated recipient, with a platform fee sent to
 *         a configurable fee recipient.
 */
contract StablePay {
    using SafeERC20 for IERC20;

    // --- Constants ---
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_PLATFORM_FEE_BPS = 20; // 0.2%
    uint256 public constant MAX_PLATFORM_FEE_BPS = 1_000; // 10%

    // --- State Variables ---
    address public owner;
    address public feeRecipient;
    uint256 public platformFeeBps;

    mapping(address stablecoin => bool approved) public approvedStablecoins;

    struct PaymentLink {
        address creator;
        address recipient;
        address stablecoin;
        uint256 amount;
        bool active;
    }

    mapping(uint256 linkId => PaymentLink) public paymentLinks;
    uint256 private _nextLinkId;

    // --- Events ---
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event PlatformFeeUpdated(uint256 previousFeeBps, uint256 newFeeBps);
    event StablecoinApprovalUpdated(address indexed stablecoin, bool approved);
    event PaymentLinkCreated(
        uint256 indexed linkId,
        address indexed creator,
        address indexed recipient,
        address stablecoin,
        uint256 amount
    );
    event PaymentLinkUpdated(
        uint256 indexed linkId,
        address indexed recipient,
        address stablecoin,
        uint256 amount,
        bool active
    );
    event PaymentProcessed(
        uint256 indexed linkId,
        address indexed payer,
        address indexed recipient,
        address stablecoin,
        uint256 amount,
        uint256 fee
    );

    // --- Errors ---
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error FeeTooHigh(uint256 feeBps);
    error StablecoinNotApproved(address stablecoin);
    error LinkNotFound(uint256 linkId);
    error LinkInactive(uint256 linkId);
    error NotLinkCreator(uint256 linkId, address caller);

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // --- Constructor ---
    constructor(address initialOwner, address initialFeeRecipient) {
        if (initialOwner == address(0)) revert ZeroAddress();
        if (initialFeeRecipient == address(0)) revert ZeroAddress();
        owner = initialOwner;
        feeRecipient = initialFeeRecipient;
        platformFeeBps = DEFAULT_PLATFORM_FEE_BPS;
        emit OwnershipTransferred(address(0), initialOwner);
        emit FeeRecipientUpdated(address(0), initialFeeRecipient);
        emit PlatformFeeUpdated(0, DEFAULT_PLATFORM_FEE_BPS);
    }

    // --- Owner Functions ---

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address previous = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(previous, newRecipient);
    }

    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_PLATFORM_FEE_BPS) revert FeeTooHigh(newFeeBps);
        uint256 previous = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(previous, newFeeBps);
    }

    function setStablecoinApproval(address stablecoin, bool approved) external onlyOwner {
        if (stablecoin == address(0)) revert ZeroAddress();
        approvedStablecoins[stablecoin] = approved;
        emit StablecoinApprovalUpdated(stablecoin, approved);
    }

    // --- Merchant Functions ---

    function createPaymentLink(
        address recipient,
        address stablecoin,
        uint256 amount
    ) external returns (uint256 linkId) {
        if (recipient == address(0)) revert ZeroAddress();
        if (!approvedStablecoins[stablecoin]) revert StablecoinNotApproved(stablecoin);
        if (amount == 0) revert ZeroAmount();

        linkId = _nextLinkId++;
        paymentLinks[linkId] = PaymentLink({
            creator: msg.sender,
            recipient: recipient,
            stablecoin: stablecoin,
            amount: amount,
            active: true
        });

        emit PaymentLinkCreated(linkId, msg.sender, recipient, stablecoin, amount);
    }

    function updatePaymentLink(
        uint256 linkId,
        address recipient,
        address stablecoin,
        uint256 amount,
        bool active
    ) external {
        PaymentLink storage link = paymentLinks[linkId];
        if (link.creator == address(0)) revert LinkNotFound(linkId);
        if (link.creator != msg.sender) revert NotLinkCreator(linkId, msg.sender);
        if (recipient == address(0)) revert ZeroAddress();
        if (!approvedStablecoins[stablecoin]) revert StablecoinNotApproved(stablecoin);
        if (amount == 0) revert ZeroAmount();

        link.recipient = recipient;
        link.stablecoin = stablecoin;
        link.amount = amount;
        link.active = active;

        emit PaymentLinkUpdated(linkId, recipient, stablecoin, amount, active);
    }

    // --- Payer Functions ---

    function pay(uint256 linkId) external {
        PaymentLink storage link = paymentLinks[linkId];
        if (link.creator == address(0)) revert LinkNotFound(linkId);
        if (!link.active) revert LinkInactive(linkId);

        address payer = msg.sender;
        address stablecoin = link.stablecoin;
        address recipient = link.recipient;
        uint256 amount = link.amount;

        uint256 fee = (amount * platformFeeBps) / BPS_DENOMINATOR;
        uint256 merchantAmount = amount - fee;

        // Direct transfer from payer to recipient; contract holds no funds.
        IERC20(stablecoin).safeTransferFrom(payer, recipient, merchantAmount);
        if (fee > 0) {
            IERC20(stablecoin).safeTransferFrom(payer, feeRecipient, fee);
        }

        emit PaymentProcessed(linkId, payer, recipient, stablecoin, amount, fee);
    }

    // --- View Functions ---

    function getLinkCount() external view returns (uint256) {
        return _nextLinkId;
    }

    function calculateFee(uint256 amount) external view returns (uint256 fee) {
        fee = (amount * platformFeeBps) / BPS_DENOMINATOR;
    }

    function getPaymentLink(uint256 linkId)
        external
        view
        returns (
            address creator,
            address recipient,
            address stablecoin,
            uint256 amount,
            bool active
        )
    {
        PaymentLink storage link = paymentLinks[linkId];
        return (link.creator, link.recipient, link.stablecoin, link.amount, link.active);
    }
}
