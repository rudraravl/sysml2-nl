// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MessagingNetworkRegistry
 * @notice Manages user registrations, public keys, and subscription fees for a
 *         decentralized messaging network. Users register with a public key,
 *         renew subscriptions by paying a fee in native currency, and receive
 *         30 days of access per renewal. A designated operator may adjust the
 *         fee and withdraw accumulated fees.
 */
contract MessagingNetworkRegistry {
    // ============ Constants ============
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;
    uint256 public constant INITIAL_FEE = 0.01 ether;

    // ============ State ============
    address public operator;
    uint256 public subscriptionFee;
    uint256 public totalCollectedFees;
    uint256 private nextUserId;

    struct User {
        uint256 id;
        bytes publicKey;
        uint256 subscriptionExpiry;
        bool isRegistered;
    }

    mapping(address => User) internal _users;

    // ============ Events ============
    event UserRegistered(address indexed user, uint256 indexed id, bytes publicKey);
    event PublicKeyUpdated(address indexed user, bytes newPublicKey);
    event SubscriptionRenewed(address indexed user, uint256 newExpiry);
    event UserDeregistered(address indexed user);
    event SubscriptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    // ============ Errors ============
    error NotOperator();
    error AlreadyRegistered();
    error NotRegistered();
    error InsufficientFee();
    error ZeroAddress();
    error EmptyPublicKey();
    error InvalidFee();
    error RefundFailed();
    error WithdrawalFailed();
    error NothingToWithdraw();

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyRegistered() {
        if (!_users[msg.sender].isRegistered) revert NotRegistered();
        _;
    }

    // ============ Constructor ============
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        subscriptionFee = INITIAL_FEE;
    }

    // ============ User Functions ============

    /**
     * @notice Register a new user with an associated public key.
     * @param publicKey Public key bytes (e.g. compressed secp256k1 key).
     */
    function registerUser(bytes calldata publicKey) external {
        if (_users[msg.sender].isRegistered) revert AlreadyRegistered();
        if (publicKey.length == 0) revert EmptyPublicKey();

        uint256 id = nextUserId++;
        _users[msg.sender] = User({
            id: id,
            publicKey: publicKey,
            subscriptionExpiry: 0,
            isRegistered: true
        });

        emit UserRegistered(msg.sender, id, publicKey);
    }

    /**
     * @notice Update the caller's public key.
     * @param newPublicKey The new public key bytes.
     */
    function updatePublicKey(bytes calldata newPublicKey) external onlyRegistered {
        if (newPublicKey.length == 0) revert EmptyPublicKey();
        _users[msg.sender].publicKey = newPublicKey;
        emit PublicKeyUpdated(msg.sender, newPublicKey);
    }

    /**
     * @notice Renew the caller's subscription by paying at least the current fee.
     *         Any excess payment is refunded to the caller. If the current
     *         subscription is still active, the new expiry extends from the
     *         existing expiry; otherwise it extends from the block timestamp.
     */
    function renewSubscription() external payable onlyRegistered {
        if (msg.value < subscriptionFee) revert InsufficientFee();

        User storage user = _users[msg.sender];
        uint256 base = block.timestamp > user.subscriptionExpiry
            ? block.timestamp
            : user.subscriptionExpiry;
        user.subscriptionExpiry = base + SUBSCRIPTION_DURATION;

        totalCollectedFees += subscriptionFee;

        uint256 refund = msg.value - subscriptionFee;
        if (refund > 0) {
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            if (!ok) revert RefundFailed();
        }

        emit SubscriptionRenewed(msg.sender, user.subscriptionExpiry);
    }

    /**
     * @notice Deregister the caller, deleting their record and any remaining
     *         subscription time.
     */
    function deregister() external onlyRegistered {
        delete _users[msg.sender];
        emit UserDeregistered(msg.sender);
    }

    // ============ Operator Functions ============

    /**
     * @notice Set a new subscription fee.
     * @param newFee New fee amount in wei (must be greater than zero).
     */
    function setSubscriptionFee(uint256 newFee) external onlyOperator {
        if (newFee == 0) revert InvalidFee();
        uint256 oldFee = subscriptionFee;
        subscriptionFee = newFee;
        emit SubscriptionFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Withdraw accumulated fees to a recipient address.
     * @param to Recipient address. Must be non-zero.
     */
    function withdrawFees(address payable to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = totalCollectedFees;
        if (amount == 0) revert NothingToWithdraw();

        totalCollectedFees = 0;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert WithdrawalFailed();

        emit FeesWithdrawn(to, amount);
    }

    /**
     * @notice Transfer operator role to a new address.
     * @param newOperator Address of the new operator (must be non-zero).
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    // ============ View Functions ============

    /**
     * @notice Returns whether a user is registered.
     */
    function isRegistered(address user) external view returns (bool) {
        return _users[user].isRegistered;
    }

    /**
     * @notice Returns whether a user's subscription is currently active.
     */
    function isSubscriptionActive(address user) external view returns (bool) {
        return _users[user].isRegistered && _users[user].subscriptionExpiry > block.timestamp;
    }

    /**
     * @notice Retrieve full user information.
     */
    function getUser(address user)
        external
        view
        returns (uint256 id, bytes memory publicKey, uint256 subscriptionExpiry, bool isReg)
    {
        User storage u = _users[user];
        return (u.id, u.publicKey, u.subscriptionExpiry, u.isRegistered);
    }

    /**
     * @notice Retrieve a user's public key.
     */
    function getPublicKey(address user) external view returns (bytes memory) {
        return _users[user].publicKey;
    }

    /**
     * @notice Retrieve a user's subscription expiry timestamp.
     */
    function getSubscriptionExpiry(address user) external view returns (uint256) {
        return _users[user].subscriptionExpiry;
    }

    /**
     * @notice Returns the total number of user ids ever issued.
     */
    function totalUsers() external view returns (uint256) {
        return nextUserId;
    }
}
