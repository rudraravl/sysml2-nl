// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

/**
 * @title DataFeedSubscriptions
 * @notice Manages subscriptions for premium data feeds. The contract does not
 *         custody any payment tokens; subscription payments are forwarded
 *         directly to a designated treasury address.
 */
contract DataFeedSubscriptions {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOwner();
    error ZeroAddress();
    error FeedDoesNotExist();
    error FeedPaused();
    error ZeroMonths();
    error ExceedsMaxMonths();
    error InvalidFee();
    error TransferFailed();
    error NoActiveSubscription();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event DataFeedAdded(uint256 indexed feedId, string name, uint256 monthlyFee);
    event DataFeedFeeUpdated(uint256 indexed feedId, uint256 newMonthlyFee);
    event DataFeedPausedChanged(uint256 indexed feedId, bool paused);
    event Subscribed(
        address indexed subscriber,
        uint256 indexed feedId,
        uint256 months,
        uint256 newEndDate,
        uint256 amountPaid
    );
    event SubscriptionRenewed(
        address indexed subscriber,
        uint256 indexed feedId,
        uint256 months,
        uint256 newEndDate,
        uint256 amountPaid
    );
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event OwnershipTransferred(address oldOwner, address newOwner);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant DEFAULT_MONTHLY_FEE = 100 * 1e18;
    uint256 public constant MAX_MONTHS = 12;
    uint256 public constant SECONDS_PER_MONTH = 30 days;

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------
    struct DataFeed {
        string name;
        uint256 monthlyFee;
        bool paused;
        bool exists;
    }

    struct Subscription {
        uint256 endDate;
        bool active;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public owner;
    address public treasury;
    IERC20 public immutable paymentToken;

    uint256 public nextFeedId;
    mapping(uint256 => DataFeed) public feeds;
    mapping(address => mapping(uint256 => Subscription)) public subscriptions;

    uint256 private _locked = 1;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier feedExists(uint256 feedId) {
        if (!feeds[feedId].exists) revert FeedDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _paymentToken, address _treasury) {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        treasury = _treasury;
        paymentToken = IERC20(_paymentToken);
        emit OwnershipTransferred(address(0), msg.sender);
        emit TreasuryUpdated(address(0), _treasury);
    }

    // ---------------------------------------------------------------------
    // Owner: feed management
    // ---------------------------------------------------------------------
    function addDataFeed(string calldata name) external onlyOwner returns (uint256 feedId) {
        feedId = nextFeedId++;
        feeds[feedId] = DataFeed({
            name: name,
            monthlyFee: DEFAULT_MONTHLY_FEE,
            paused: false,
            exists: true
        });
        emit DataFeedAdded(feedId, name, DEFAULT_MONTHLY_FEE);
    }

    function updateMonthlyFee(uint256 feedId, uint256 newMonthlyFee)
        external
        onlyOwner
        feedExists(feedId)
    {
        if (newMonthlyFee == 0) revert InvalidFee();
        feeds[feedId].monthlyFee = newMonthlyFee;
        emit DataFeedFeeUpdated(feedId, newMonthlyFee);
    }

    function setFeedPaused(uint256 feedId, bool paused)
        external
        onlyOwner
        feedExists(feedId)
    {
        feeds[feedId].paused = paused;
        emit DataFeedPausedChanged(feedId, paused);
    }

    // ---------------------------------------------------------------------
    // Owner: configuration
    // ---------------------------------------------------------------------
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    // ---------------------------------------------------------------------
    // Subscription logic
    // ---------------------------------------------------------------------
    function subscribe(uint256 feedId, uint256 months)
        external
        feedExists(feedId)
        nonReentrant
    {
        DataFeed storage feed = feeds[feedId];
        if (feed.paused) revert FeedPaused();
        if (months == 0) revert ZeroMonths();
        if (months > MAX_MONTHS) revert ExceedsMaxMonths();

        uint256 amount = feed.monthlyFee * months;

        // Effects: update state before external transfer (checks-effects-interactions)
        Subscription storage sub = subscriptions[msg.sender][feedId];
        uint256 newEndDate;
        bool isRenewal = sub.active && sub.endDate > block.timestamp;
        if (isRenewal) {
            newEndDate = sub.endDate + (months * SECONDS_PER_MONTH);
        } else {
            newEndDate = block.timestamp + (months * SECONDS_PER_MONTH);
        }
        sub.endDate = newEndDate;
        sub.active = true;

        // Interactions
        _collectPayment(msg.sender, amount);

        if (isRenewal) {
            emit SubscriptionRenewed(msg.sender, feedId, months, newEndDate, amount);
        } else {
            emit Subscribed(msg.sender, feedId, months, newEndDate, amount);
        }
    }

    function renew(uint256 feedId, uint256 months)
        external
        feedExists(feedId)
        nonReentrant
    {
        DataFeed storage feed = feeds[feedId];
        if (feed.paused) revert FeedPaused();
        if (months == 0) revert ZeroMonths();
        if (months > MAX_MONTHS) revert ExceedsMaxMonths();

        Subscription storage sub = subscriptions[msg.sender][feedId];
        if (!sub.active) revert NoActiveSubscription();

        uint256 amount = feed.monthlyFee * months;

        // Effects: update state before external transfer (checks-effects-interactions)
        uint256 base = sub.endDate > block.timestamp ? sub.endDate : block.timestamp;
        uint256 newEndDate = base + (months * SECONDS_PER_MONTH);
        sub.endDate = newEndDate;
        sub.active = true;

        // Interactions
        _collectPayment(msg.sender, amount);

        emit SubscriptionRenewed(msg.sender, feedId, months, newEndDate, amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function isSubscribed(address subscriber, uint256 feedId)
        external
        view
        feedExists(feedId)
        returns (bool)
    {
        Subscription storage sub = subscriptions[subscriber][feedId];
        return sub.active && sub.endDate > block.timestamp;
    }

    function getSubscription(address subscriber, uint256 feedId)
        external
        view
        feedExists(feedId)
        returns (bool active, uint256 endDate)
    {
        Subscription storage sub = subscriptions[subscriber][feedId];
        active = sub.active && sub.endDate > block.timestamp;
        endDate = sub.endDate;
    }

    function getFeed(uint256 feedId)
        external
        view
        feedExists(feedId)
        returns (string memory name, uint256 monthlyFee, bool paused)
    {
        DataFeed storage feed = feeds[feedId];
        return (feed.name, feed.monthlyFee, feed.paused);
    }

    function getAllFeedIds() external view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](nextFeedId);
        for (uint256 i = 0; i < nextFeedId; i++) {
            ids[i] = i;
        }
        return ids;
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------
    function _collectPayment(address from, uint256 amount) internal {
        bool ok = paymentToken.transferFrom(from, treasury, amount);
        if (!ok) revert TransferFailed();
    }
}
