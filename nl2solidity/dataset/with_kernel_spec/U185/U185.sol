// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title NFTExchange
 * @notice Peer-to-peer escrow exchange for NFTs and fungible tokens.
 *         Makers create offers depositing NFTs into escrow; takers fulfill
 *         offers by providing the requested NFTs and/or ERC20 tokens.
 *         A configurable fee (default 2%) is deducted from the fungible
 *         token portion of successful trades.
 */
contract NFTExchange {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_OFFER_DURATION = 30 days;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 1000; // 10%

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Offer {
        address maker;
        address offeredNftContract;
        uint256[] offeredTokenIds;
        address requestedNftContract;
        uint256[] requestedTokenIds;
        address requestedFtContract;
        uint256 requestedFtAmount;
        uint256 expiration;
        bool active;
    }

    /*//////////////////////////////////////////////////////////////
                          STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => Offer) private _offers;
    uint256 public nextOfferId;
    uint256 public feeBps;
    address public operator;
    mapping(address => uint256) public accumulatedFees;

    uint256 private _locked = 1;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    event OfferCreated(
        uint256 indexed offerId,
        address indexed maker,
        address offeredNftContract,
        uint256[] offeredTokenIds,
        address requestedNftContract,
        uint256[] requestedTokenIds,
        address requestedFtContract,
        uint256 requestedFtAmount,
        uint256 expiration
    );

    event OfferAccepted(
        uint256 indexed offerId,
        address indexed maker,
        address indexed taker,
        uint256 feePaid
    );

    event OfferCancelled(uint256 indexed offerId, address indexed maker);

    event FeePercentageUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error InvalidDuration();
    error InvalidOfferedNftContract();
    error NoOfferedTokens();
    error NoRequestedItems();
    error InvalidRequestedNftContract();
    error InvalidRequestedFtContract();
    error NotOwnerOfOfferedToken();
    error OfferNotActive();
    error OfferExpired();
    error NotMaker();
    error NotOperator();
    error FeeTooHigh();
    error NoFeesToWithdraw();
    error ReentrantCall();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        feeBps = 200; // 2%
        emit FeePercentageUpdated(0, 200);
        emit OperatorUpdated(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                           OFFER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new exchange offer, depositing offered NFTs into escrow.
    /// @dev The maker must have approved this contract to transfer the offered NFTs.
    /// @param offeredNftContract The ERC721 contract of NFTs being offered.
    /// @param offeredTokenIds Token IDs of the offered NFTs.
    /// @param requestedNftContract The ERC721 contract of NFTs being requested (address(0) if none).
    /// @param requestedTokenIds Token IDs of the requested NFTs.
    /// @param requestedFtContract The ERC20 contract of fungible tokens requested (address(0) if none).
    /// @param requestedFtAmount Amount of fungible tokens requested.
    /// @param duration Offer duration in seconds (must be > 0 and <= 30 days).
    /// @return offerId The ID of the newly created offer.
    function createOffer(
        address offeredNftContract,
        uint256[] calldata offeredTokenIds,
        address requestedNftContract,
        uint256[] calldata requestedTokenIds,
        address requestedFtContract,
        uint256 requestedFtAmount,
        uint256 duration
    ) external nonReentrant returns (uint256 offerId) {
        if (offeredNftContract == address(0)) revert InvalidOfferedNftContract();
        if (offeredTokenIds.length == 0) revert NoOfferedTokens();
        if (duration == 0 || duration > MAX_OFFER_DURATION) revert InvalidDuration();
        if (requestedTokenIds.length == 0 && requestedFtAmount == 0) revert NoRequestedItems();
        if (requestedTokenIds.length > 0 && requestedNftContract == address(0)) revert InvalidRequestedNftContract();
        if (requestedFtAmount > 0 && requestedFtContract == address(0)) revert InvalidRequestedFtContract();

        offerId = nextOfferId++;

        // Effects: store offer state before external interactions
        _offers[offerId] = Offer({
            maker: msg.sender,
            offeredNftContract: offeredNftContract,
            offeredTokenIds: offeredTokenIds,
            requestedNftContract: requestedNftContract,
            requestedTokenIds: requestedTokenIds,
            requestedFtContract: requestedFtContract,
            requestedFtAmount: requestedFtAmount,
            expiration: block.timestamp + duration,
            active: true
        });

        // Interactions: transfer offered NFTs into escrow
        for (uint256 i = 0; i < offeredTokenIds.length; i++) {
            if (IERC721(offeredNftContract).ownerOf(offeredTokenIds[i]) != msg.sender) {
                revert NotOwnerOfOfferedToken();
            }
            IERC721(offeredNftContract).transferFrom(msg.sender, address(this), offeredTokenIds[i]);
        }

        emit OfferCreated(
            offerId,
            msg.sender,
            offeredNftContract,
            offeredTokenIds,
            requestedNftContract,
            requestedTokenIds,
            requestedFtContract,
            requestedFtAmount,
            block.timestamp + duration
        );
    }

    /// @notice Accepts an active offer by providing the requested items.
    /// @dev The taker must have approved this contract for the requested NFTs and ERC20s.
    ///      A fee is deducted from the fungible token portion and accumulated for the operator.
    /// @param offerId The ID of the offer to accept.
    function acceptOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = _offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (block.timestamp > offer.expiration) revert OfferExpired();

        // Effects: deactivate before external interactions
        offer.active = false;
        address maker = offer.maker;
        address taker = msg.sender;
        uint256 feePaid = 0;

        // Interactions: transfer requested NFTs from taker to maker
        uint256 reqNftLen = offer.requestedTokenIds.length;
        for (uint256 i = 0; i < reqNftLen; i++) {
            IERC721(offer.requestedNftContract).transferFrom(
                taker,
                maker,
                offer.requestedTokenIds[i]
            );
        }

        // Interactions: transfer requested FT from taker to maker minus fee
        if (offer.requestedFtAmount > 0) {
            uint256 fee = (offer.requestedFtAmount * feeBps) / FEE_DENOMINATOR;
            uint256 makerAmount = offer.requestedFtAmount - fee;

            if (makerAmount > 0) {
                if (!IERC20(offer.requestedFtContract).transferFrom(taker, maker, makerAmount)) {
                    revert TransferFailed();
                }
            }
            if (fee > 0) {
                if (!IERC20(offer.requestedFtContract).transferFrom(taker, address(this), fee)) {
                    revert TransferFailed();
                }
                accumulatedFees[offer.requestedFtContract] += fee;
                feePaid = fee;
            }
        }

        // Interactions: transfer escrowed NFTs to taker
        uint256 offNftLen = offer.offeredTokenIds.length;
        for (uint256 i = 0; i < offNftLen; i++) {
            IERC721(offer.offeredNftContract).transferFrom(
                address(this),
                taker,
                offer.offeredTokenIds[i]
            );
        }

        emit OfferAccepted(offerId, maker, taker, feePaid);
    }

    /// @notice Cancels an active offer, returning escrowed NFTs to the maker.
    /// @param offerId The ID of the offer to cancel.
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = _offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (offer.maker != msg.sender) revert NotMaker();

        // Effects: deactivate before external interactions
        offer.active = false;

        // Interactions: return escrowed NFTs to maker
        uint256 offNftLen = offer.offeredTokenIds.length;
        for (uint256 i = 0; i < offNftLen; i++) {
            IERC721(offer.offeredNftContract).transferFrom(
                address(this),
                msg.sender,
                offer.offeredTokenIds[i]
            );
        }

        emit OfferCancelled(offerId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the global fee percentage (in basis points).
    /// @param newFeeBps The new fee in basis points (max 1000 = 10%).
    function setFeePercentage(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        emit FeePercentageUpdated(oldFeeBps, newFeeBps);
    }

    /// @notice Withdraws accumulated fees for a given ERC20 token to the operator.
    /// @param token The ERC20 token address from which to withdraw fees.
    function withdrawFees(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees[token];
        if (amount == 0) revert NoFeesToWithdraw();

        accumulatedFees[token] = 0;
        if (!IERC20(token).transfer(operator, amount)) revert TransferFailed();

        emit FeesWithdrawn(token, operator, amount);
    }

    /// @notice Transfers operator role to a new address.
    /// @param newOperator The address of the new operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the full details of an offer.
    /// @param offerId The ID of the offer to query.
    /// @return The Offer struct containing all offer details.
    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return _offers[offerId];
    }

    /// @notice Checks whether an offer is currently active and not expired.
    /// @param offerId The ID of the offer to check.
    /// @return True if the offer is active and not expired.
    function isOfferActive(uint256 offerId) external view returns (bool) {
        Offer storage offer = _offers[offerId];
        return offer.active && block.timestamp <= offer.expiration;
    }

    /// @notice Returns the accumulated fee balance for a given ERC20 token.
    /// @param token The ERC20 token address.
    /// @return The accumulated fee amount.
    function getAccumulatedFees(address token) external view returns (uint256) {
        return accumulatedFees[token];
    }
}
