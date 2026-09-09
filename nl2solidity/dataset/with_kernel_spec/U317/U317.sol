// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SocialContentPlatform {
    // ---------- Custom Errors ----------
    error NotOperator();
    error InvalidAddress();
    error CreatorAlreadyRegistered();
    error CreatorNotRegistered();
    error TierNotAvailable();
    error IncorrectPayment();
    error NoActiveSubscription();
    error NoEarningsToWithdraw();
    error NoFeesToWithdraw();
    error PriceBelowMinimum();
    error TransferFailed();

    // ---------- Constants ----------
    uint256 public constant MIN_PRICE = 0.001 ether;
    uint256 public constant PLATFORM_FEE_PERCENT = 5; // 5%
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;
    uint256 private constant HUNDRED = 100;

    // ---------- Storage ----------
    address public operator;

    struct Subscription {
        uint256 tierId;
        uint256 expiresAt;
        bool counted;
    }

    mapping(uint256 => uint256) public tierPrice; // tierId => monthly price (wei)
    mapping(address => bool) public isRegisteredCreator;
    mapping(address => uint256) public creatorEarnings; // withdrawable balance
    mapping(address => uint256) public totalValueAccumulated; // lifetime creator share
    mapping(address => mapping(address => Subscription)) internal _subscriptions; // subscriber => creator
    mapping(address => uint256) public creatorActiveFollowers;
    uint256 public platformFees;

    // ---------- Events ----------
    event Subscribed(address indexed subscriber, address indexed creator, uint256 indexed tierId, uint256 amount);
    event Unsubscribed(address indexed subscriber, address indexed creator, uint256 tierId);
    event Withdrawn(address indexed creator, uint256 amount);
    event TierPriceSet(uint256 indexed tierId, uint256 price);
    event CreatorRegistered(address indexed creator);
    event PlatformFeesWithdrawn(address indexed operator, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------- Constructor ----------
    constructor() {
        address initialOperator = msg.sender;
        if (initialOperator == address(0)) revert InvalidAddress();
        operator = initialOperator;
        emit OperatorChanged(address(0), initialOperator);
    }

    // ---------- Admin ----------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorChanged(prev, newOperator);
    }

    function registerCreator(address creator) external onlyOperator {
        if (creator == address(0)) revert InvalidAddress();
        if (isRegisteredCreator[creator]) revert CreatorAlreadyRegistered();
        isRegisteredCreator[creator] = true;
        emit CreatorRegistered(creator);
    }

    function setTierPrice(uint256 tierId, uint256 price) external onlyOperator {
        if (price < MIN_PRICE) revert PriceBelowMinimum();
        tierPrice[tierId] = price;
        emit TierPriceSet(tierId, price);
    }

    // ---------- Subscription ----------
    function subscribe(address creator, uint256 tierId) external payable {
        if (!isRegisteredCreator[creator]) revert CreatorNotRegistered();
        uint256 price = tierPrice[tierId];
        if (price == 0) revert TierNotAvailable();
        if (msg.value != price) revert IncorrectPayment();

        Subscription storage sub = _subscriptions[msg.sender][creator];
        bool wasActive = sub.expiresAt > block.timestamp;

        // Count as a new active follower only when transitioning from inactive to active.
        if (!wasActive && !sub.counted) {
            creatorActiveFollowers[creator] += 1;
            sub.counted = true;
        }

        // 5% platform fee, remainder to creator earnings.
        uint256 fee = (msg.value * PLATFORM_FEE_PERCENT) / HUNDRED;
        uint256 earnings = msg.value - fee;
        platformFees += fee;
        creatorEarnings[creator] += earnings;
        totalValueAccumulated[creator] += earnings;

        // Extend from current expiry if still active, otherwise from now.
        uint256 base = block.timestamp > sub.expiresAt ? block.timestamp : sub.expiresAt;
        sub.tierId = tierId;
        sub.expiresAt = base + SUBSCRIPTION_DURATION;

        emit Subscribed(msg.sender, creator, tierId, msg.value);
    }

    function unsubscribe(address creator) external {
        Subscription storage sub = _subscriptions[msg.sender][creator];
        if (sub.expiresAt <= block.timestamp) revert NoActiveSubscription();

        uint256 tierId = sub.tierId;
        sub.expiresAt = block.timestamp;
        sub.tierId = 0;

        if (sub.counted) {
            sub.counted = false;
            unchecked {
                creatorActiveFollowers[creator] -= 1;
            }
        }

        emit Unsubscribed(msg.sender, creator, tierId);
    }

    // ---------- Withdrawals ----------
    function withdrawEarnings() external {
        if (!isRegisteredCreator[msg.sender]) revert CreatorNotRegistered();
        uint256 amount = creatorEarnings[msg.sender];
        if (amount == 0) revert NoEarningsToWithdraw();

        // Checks-effects-interactions
        creatorEarnings[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function withdrawPlatformFees() external onlyOperator {
        uint256 amount = platformFees;
        if (amount == 0) revert NoFeesToWithdraw();

        platformFees = 0;
        (bool success, ) = payable(operator).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit PlatformFeesWithdrawn(operator, amount);
    }

    // ---------- Views ----------
    function isSubscribed(address subscriber, address creator) external view returns (bool) {
        return _subscriptions[subscriber][creator].expiresAt > block.timestamp;
    }

    function getSubscription(address subscriber, address creator)
        external
        view
        returns (uint256 tierId, uint256 expiresAt)
    {
        Subscription storage sub = _subscriptions[subscriber][creator];
        return (sub.tierId, sub.expiresAt);
    }

    function getCreatorStats(address creator)
        external
        view
        returns (uint256 activeFollowers, uint256 earnings, uint256 totalAccumulated)
    {
        return (
            creatorActiveFollowers[creator],
            creatorEarnings[creator],
            totalValueAccumulated[creator]
        );
    }
}
