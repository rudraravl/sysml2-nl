// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

library SafeERC20 {
    error SafeERC20FailedTransfer();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20FailedTransfer();
    }

    /// @dev Transfers tokens from the caller (msg.sender) to `to`.
    ///      The `from` is fixed to msg.sender to prevent arbitrary-send-erc20.
    function safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        if (!ok) revert SafeERC20FailedTransfer();
    }
}

contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    error ReentrantCall();
}

/**
 * @title NFTBiddingEscrow
 * @dev A decentralized NFT bidding system that holds fungible tokens as collateral for bids.
 *      Users deposit fungible tokens, place bids on NFT collections, and sellers can fulfill
 *      those bids by transferring the corresponding NFTs. A configurable fee is applied on
 *      fulfillment and sent to a designated fee receiver.
 */
contract NFTBiddingEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientAvailableBalance();
    error BidNotFound();
    error InvalidMinBidAmount();
    error InvalidFeeBasisPoints();
    error InvalidQuantity();
    error PriceBelowMinimum();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event BidPlaced(address indexed bidder, address indexed collection, uint256 price, uint256 quantity);
    event BidCanceled(address indexed bidder, address indexed collection);
    event BidFulfilled(
        address indexed bidder,
        address indexed seller,
        address indexed collection,
        uint256 quantity,
        uint256 totalCost,
        uint256 fee
    );
    event FeeBasisPointsUpdated(uint256 newFeeBps);
    event MinBidAmountUpdated(address indexed collection, uint256 newMinBid);
    event OperatorUpdated(address indexed newOperator);
    event FeeReceiverUpdated(address indexed newFeeReceiver);

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------
    struct Bid {
        uint128 price;
        uint128 quantity;
    }

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------
    /// @notice The fungible token used as collateral for bids.
    IERC20 public immutable token;

    /// @notice Address authorized to update fees and minimum bid amounts.
    address public operator;

    /// @notice Address that receives fees on bid fulfillment.
    address public feeReceiver;

    /// @notice Fee in basis points (50 = 0.5%).
    uint256 public feeBps;

    /// @notice Absolute minimum bid price: 0.001 tokens (assuming 18 decimals).
    uint256 public constant MIN_BID_AMOUNT = 1e15;

    /// @notice Maximum fee in basis points (1000 = 10%).
    uint256 public constant MAX_FEE_BPS = 1_000;

    /// @notice Basis points divisor (10000 = 100%).
    uint256 public constant BPS_DIVISOR = 10_000;

    /// @notice User's available (unlocked) token balance.
    mapping(address => uint256) public availableBalances;

    /// @notice Total tokens locked in active bids per user.
    mapping(address => uint256) public lockedBalances;

    /// @notice Active bids: collection => bidder => Bid.
    mapping(address => mapping(address => Bid)) public bids;

    /// @notice Minimum bid price per collection (0 means use MIN_BID_AMOUNT).
    mapping(address => uint256) public minBidAmount;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address _token, address _operator, address _feeReceiver) {
        if (_token == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeReceiver == address(0)) revert ZeroAddress();

        token = IERC20(_token);
        operator = _operator;
        feeReceiver = _feeReceiver;
        feeBps = 50; // 0.5%
    }

    // -----------------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposits fungible tokens into the contract to be used as collateral for bids.
     * @param amount The amount of tokens to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        availableBalances[msg.sender] += amount;
        token.safeTransferFrom(address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraws available fungible token balance from the contract.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (availableBalances[msg.sender] < amount) revert InsufficientAvailableBalance();

        availableBalances[msg.sender] -= amount;
        token.safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Places or updates a bid on a specific NFT collection.
     * @param collection The address of the NFT collection.
     * @param price The price per NFT.
     * @param quantity The number of NFTs to bid on.
     */
    function placeBid(address collection, uint256 price, uint256 quantity) external nonReentrant {
        if (collection == address(0)) revert ZeroAddress();
        if (price == 0 || quantity == 0) revert ZeroAmount();

        uint256 currentMin = minBidAmount[collection] == 0 ? MIN_BID_AMOUNT : minBidAmount[collection];
        if (price < currentMin) revert PriceBelowMinimum();

        uint256 totalBid = price * quantity;
        Bid memory existing = bids[collection][msg.sender];
        uint256 existingLocked = uint256(existing.price) * uint256(existing.quantity);

        if (totalBid > existingLocked) {
            uint256 diff = totalBid - existingLocked;
            if (diff > availableBalances[msg.sender]) revert InsufficientAvailableBalance();
            availableBalances[msg.sender] -= diff;
            lockedBalances[msg.sender] += diff;
        } else if (totalBid < existingLocked) {
            uint256 diff = existingLocked - totalBid;
            availableBalances[msg.sender] += diff;
            lockedBalances[msg.sender] -= diff;
        }

        bids[collection][msg.sender] = Bid(uint128(price), uint128(quantity));
        emit BidPlaced(msg.sender, collection, price, quantity);
    }

    /**
     * @notice Cancels an active bid and unlocks the collateral.
     * @param collection The address of the NFT collection.
     */
    function cancelBid(address collection) external nonReentrant {
        Bid memory bid = bids[collection][msg.sender];
        if (bid.quantity == 0) revert BidNotFound();

        uint256 lockedAmount = uint256(bid.price) * uint256(bid.quantity);
        lockedBalances[msg.sender] -= lockedAmount;
        availableBalances[msg.sender] += lockedAmount;

        delete bids[collection][msg.sender];
        emit BidCanceled(msg.sender, collection);
    }

    /**
     * @notice Fulfills a bid by transferring NFTs from the seller to the bidder and
     *         fungible tokens to the seller (minus fee).
     * @param bidder The address of the bidder.
     * @param collection The address of the NFT collection.
     * @param tokenIds The IDs of the NFTs to transfer.
     */
    function fulfillBid(address bidder, address collection, uint256[] calldata tokenIds) external nonReentrant {
        if (bidder == address(0)) revert ZeroAddress();
        if (collection == address(0)) revert ZeroAddress();

        uint256 quantity = tokenIds.length;
        if (quantity == 0) revert InvalidQuantity();

        Bid storage bid = bids[collection][bidder];
        if (bid.quantity < quantity) revert InvalidQuantity();

        uint256 totalCost = uint256(bid.price) * quantity;
        uint256 fee = (totalCost * feeBps) / BPS_DIVISOR;
        uint256 payout = totalCost - fee;

        // Effects
        lockedBalances[bidder] -= totalCost;
        bid.quantity -= uint128(quantity);
        if (bid.quantity == 0) {
            delete bids[collection][bidder];
        }

        // Interactions
        for (uint256 i = 0; i < quantity; i++) {
            IERC721(collection).safeTransferFrom(msg.sender, bidder, tokenIds[i]);
        }
        token.safeTransfer(msg.sender, payout);
        if (fee > 0) {
            token.safeTransfer(feeReceiver, fee);
        }

        emit BidFulfilled(bidder, msg.sender, collection, quantity, totalCost, fee);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------

    /**
     * @notice Updates the fee percentage. Only callable by the operator.
     * @param _feeBps The new fee in basis points (1..1000).
     */
    function updateFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps == 0 || _feeBps > MAX_FEE_BPS) revert InvalidFeeBasisPoints();
        feeBps = _feeBps;
        emit FeeBasisPointsUpdated(_feeBps);
    }

    /**
     * @notice Updates the minimum bid amount for a specific collection. Only callable by the operator.
     * @param collection The address of the NFT collection.
     * @param amount The new minimum bid amount (must be >= MIN_BID_AMOUNT).
     */
    function updateMinBid(address collection, uint256 amount) external onlyOperator {
        if (collection == address(0)) revert ZeroAddress();
        if (amount < MIN_BID_AMOUNT) revert InvalidMinBidAmount();
        minBidAmount[collection] = amount;
        emit MinBidAmountUpdated(collection, amount);
    }

    /**
     * @notice Updates the operator address. Only callable by the current operator.
     * @param _operator The new operator address.
     */
    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    /**
     * @notice Updates the fee receiver address. Only callable by the operator.
     * @param _feeReceiver The new fee receiver address.
     */
    function setFeeReceiver(address _feeReceiver) external onlyOperator {
        if (_feeReceiver == address(0)) revert ZeroAddress();
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }
}
