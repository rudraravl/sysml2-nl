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

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(token.approve(spender, value), "SafeERC20: approve failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero address");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * @title OTCNFTExchange
 * @notice Peer-to-peer over-the-counter NFT trading contract with escrow.
 *         Sellers deposit an ERC721 token and create an offer specifying the
 *         requested ERC20 payment token, amount, and expiration. Any caller may
 *         accept an active offer by paying the requested amount; the contract
 *         transfers the NFT to the buyer and the net proceeds (minus a protocol
 *         fee) to the seller. Offers expire at most 7 days after creation.
 */
contract OTCNFTExchange is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_OFFER_DURATION = 7 days;
    uint256 public constant FEE_DENOMINATOR = 100_000;
    uint256 public constant DEFAULT_FEE_NUMERATOR = 500; // 0.5%
    uint256 public constant MAX_FEE_NUMERATOR = 5_000; // 5%

    struct Offer {
        address seller;
        address nft;
        uint256 tokenId;
        address paymentToken;
        uint256 paymentAmount;
        uint64 expiration;
        bool active;
    }

    mapping(uint256 => Offer) public offers;
    uint256 public offerCount;

    address public feeRecipient;
    address public operator;
    uint256 public feeNumerator;
    bool public paused;

    event OfferCreated(
        uint256 indexed offerId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        address paymentToken,
        uint256 paymentAmount,
        uint64 expiration
    );
    event OfferAccepted(
        uint256 indexed offerId,
        address indexed seller,
        address indexed buyer,
        address nft,
        uint256 tokenId,
        address paymentToken,
        uint256 paymentAmount,
        uint256 fee
    );
    event OfferCancelled(uint256 indexed offerId, address indexed seller, address nft, uint256 tokenId);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event FeeUpdated(address indexed operator, uint256 oldFeeNumerator, uint256 newFeeNumerator);
    event FeeRecipientUpdated(address indexed operator, address oldRecipient, address newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeWithdrawn(address indexed token, address indexed to, uint256 amount);
    event EthWithdrawn(address indexed to, uint256 amount);

    error ContractPaused();
    error ContractNotPaused();
    error ZeroAddress();
    error ZeroPaymentAmount();
    error InvalidExpiration();
    error OfferNotActive();
    error NotSeller();
    error OfferExpired();
    error InvalidFeeNumerator();
    error OnlyOperator();
    error SellerCannotAcceptOwnOffer();

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    constructor(address _operator, address _feeRecipient) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        feeNumerator = DEFAULT_FEE_NUMERATOR;
    }

    /**
     * @notice Sets a new operator who can pause/unpause and update fees.
     * @param newOperator The new operator address.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Creates a new offer to sell an NFT for a specified ERC20 payment.
     *         The NFT is transferred from the seller into this contract's escrow.
     * @param nft The ERC721 contract address of the token being offered.
     * @param tokenId The identifier of the NFT being offered.
     * @param paymentToken The ERC20 token requested as payment.
     * @param paymentAmount The amount of paymentToken requested.
     * @param duration Seconds from creation until expiration (max 7 days).
     * @return offerId The id of the newly created offer.
     */
    function createOffer(
        address nft,
        uint256 tokenId,
        address paymentToken,
        uint256 paymentAmount,
        uint64 duration
    ) external whenNotPaused nonReentrant returns (uint256 offerId) {
        if (nft == address(0) || paymentToken == address(0)) revert ZeroAddress();
        if (paymentAmount == 0) revert ZeroPaymentAmount();
        if (duration == 0 || duration > MAX_OFFER_DURATION) revert InvalidExpiration();

        uint64 expiration = uint64(block.timestamp) + duration;

        IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);

        offerId = ++offerCount;
        offers[offerId] = Offer({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            paymentToken: paymentToken,
            paymentAmount: paymentAmount,
            expiration: expiration,
            active: true
        });

        emit OfferCreated(offerId, msg.sender, nft, tokenId, paymentToken, paymentAmount, expiration);
    }

    /**
     * @notice Accepts an active offer by transferring the requested payment tokens
     *         to the seller (net of fee) and the NFT to the caller.
     * @param offerId The id of the offer to accept.
     */
    function acceptOffer(uint256 offerId) external whenNotPaused nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (block.timestamp > offer.expiration) revert OfferExpired();
        if (msg.sender == offer.seller) revert SellerCannotAcceptOwnOffer();

        address seller = offer.seller;
        address nft = offer.nft;
        uint256 tokenId = offer.tokenId;
        address paymentToken = offer.paymentToken;
        uint256 paymentAmount = offer.paymentAmount;

        offer.active = false;

        uint256 fee = (paymentAmount * feeNumerator) / FEE_DENOMINATOR;
        uint256 sellerProceeds = paymentAmount - fee;

        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), paymentAmount);

        if (fee > 0) {
            IERC20(paymentToken).safeTransfer(feeRecipient, fee);
        }
        if (sellerProceeds > 0) {
            IERC20(paymentToken).safeTransfer(seller, sellerProceeds);
        }

        IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);

        emit OfferAccepted(
            offerId,
            seller,
            msg.sender,
            nft,
            tokenId,
            paymentToken,
            paymentAmount,
            fee
        );
    }

    /**
     * @notice Cancels an active offer and returns the escrowed NFT to the seller.
     * @param offerId The id of the offer to cancel.
     */
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (msg.sender != offer.seller) revert NotSeller();

        address nft = offer.nft;
        uint256 tokenId = offer.tokenId;
        address seller = offer.seller;

        offer.active = false;

        IERC721(nft).safeTransferFrom(address(this), seller, tokenId);

        emit OfferCancelled(offerId, seller, nft, tokenId);
    }

    /**
     * @notice Pauses all trading activity. Only callable by the operator.
     */
    function pause() external onlyOperator {
        if (paused) revert ContractPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpauses trading activity. Only callable by the operator.
     */
    function unpause() external onlyOperator {
        if (!paused) revert ContractNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Updates the fee numerator applied to successful trades.
     * @param newFeeNumerator The new fee numerator (out of FEE_DENOMINATOR).
     */
    function setFee(uint256 newFeeNumerator) external onlyOperator {
        if (newFeeNumerator > MAX_FEE_NUMERATOR) revert InvalidFeeNumerator();
        uint256 old = feeNumerator;
        feeNumerator = newFeeNumerator;
        emit FeeUpdated(msg.sender, old, newFeeNumerator);
    }

    /**
     * @notice Updates the fee recipient address.
     * @param newRecipient The new fee recipient.
     */
    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(msg.sender, old, newRecipient);
    }

    /**
     * @notice Withdraws accumulated fees for a given token. Only callable by operator.
     * @param token The ERC20 token to withdraw.
     * @param to The recipient address.
     * @param amount The amount to withdraw.
     */
    function withdrawFees(address token, address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
        emit FeeWithdrawn(token, to, amount);
    }

    /**
     * @notice Withdraws any Ether held by the contract. Only callable by operator.
     * @param to The recipient address.
     * @param amount The amount to withdraw.
     */
    function withdrawEth(address payable to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
        emit EthWithdrawn(to, amount);
    }

    /**
     * @notice Returns the details of an offer.
     * @param offerId The id of the offer.
     */
    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    /**
     * @notice Computes the fee and seller proceeds for a given payment amount.
     * @param paymentAmount The gross payment amount.
     * @return fee The fee amount.
     * @return sellerProceeds The net amount paid to the seller.
     */
    function quoteFee(uint256 paymentAmount) external view returns (uint256 fee, uint256 sellerProceeds) {
        fee = (paymentAmount * feeNumerator) / FEE_DENOMINATOR;
        sellerProceeds = paymentAmount - fee;
    }

    /**
     * @dev Allows the contract to receive ERC721 tokens via safeTransferFrom.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
