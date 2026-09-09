// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ReputationMarket
 * @notice A contract that manages reputation markets for entities. Users can express
 *         trust or distrust in an entity. Each entity maintains a trust pool and a
 *         distrust pool. When a user redeems their trust shares, they receive a
 *         proportional share of the entity's distrust pool (the counter-reputation),
 *         and vice versa. A configurable fee is taken from every expression and
 *         accrues to the contract owner.
 */
contract ReputationMarket {
    struct Entity {
        bool exists;
        uint256 trustPool;
        uint256 distrustPool;
    }

    struct UserPosition {
        uint256 trustShares;
        uint256 distrustShares;
    }

    uint256 public constant MIN_INITIAL_TRUST = 100;
    uint256 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    address public owner;
    uint256 public marketFeeBps; // initially 50 = 0.5%
    bool public paused;
    uint256 public accruedFees;

    uint256 public nextEntityId;
    mapping(uint256 => Entity) public entities;
    mapping(uint256 => mapping(address => UserPosition)) public positions;
    mapping(address => uint256) public claimableBalance;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PausedStateChanged(bool paused);
    event MarketFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event EntityCreated(uint256 indexed entityId, address indexed creator, uint256 initialTrust);
    event TrustExpressed(uint256 indexed entityId, address indexed user, uint256 amount, uint256 fee, uint256 shares);
    event DistrustExpressed(uint256 indexed entityId, address indexed user, uint256 amount, uint256 fee, uint256 shares);
    event TrustRedeemed(uint256 indexed entityId, address indexed user, uint256 shares, uint256 payout);
    event DistrustRedeemed(uint256 indexed entityId, address indexed user, uint256 shares, uint256 payout);
    event FeesClaimed(address indexed owner, uint256 amount);
    event BalanceWithdrawn(address indexed user, uint256 amount);

    error NotOwner();
    error EnforcedPause();
    error EnforcedUnpause();
    error ZeroAddress();
    error EntityDoesNotExist(uint256 entityId);
    error InsufficientInitialTrust(uint256 provided, uint256 required);
    error InsufficientShares(uint256 available, uint256 requested);
    error ZeroAmount();
    error FeeTooHigh(uint256 provided, uint256 max);
    error NoPayout();
    error CounterPoolEmpty();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert EnforcedUnpause();
        _;
    }

    constructor() {
        owner = msg.sender;
        marketFeeBps = 50; // 0.5%
        emit OwnershipTransferred(address(0), msg.sender);
        emit MarketFeeUpdated(0, marketFeeBps);
    }

    /**
     * @notice Transfers ownership to a new account.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /**
     * @notice Pauses all market operations.
     */
    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit PausedStateChanged(true);
    }

    /**
     * @notice Unpauses all market operations.
     */
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit PausedStateChanged(false);
    }

    /**
     * @notice Updates the market fee assessed on each trust/distrust expression.
     * @param newFeeBps The new fee in basis points (max 1000 = 10%).
     */
    function setMarketFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        uint256 old = marketFeeBps;
        marketFeeBps = newFeeBps;
        emit MarketFeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Allows the owner to claim accrued fees to their claimable balance.
     */
    function claimFees() external onlyOwner {
        uint256 amount = accruedFees;
        if (amount == 0) revert ZeroAmount();
        accruedFees = 0;
        claimableBalance[owner] += amount;
        emit FeesClaimed(owner, amount);
    }

    /**
     * @notice Allows a user to withdraw their claimable balance.
     */
    function withdrawClaimable() external {
        uint256 amount = claimableBalance[msg.sender];
        if (amount == 0) revert ZeroAmount();
        claimableBalance[msg.sender] = 0;
        emit BalanceWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Creates a new reputation market entity with an initial trust expression.
     * @param initialTrust The amount of trust to express (must be >= MIN_INITIAL_TRUST).
     * @return entityId The id of the newly created entity.
     */
    function createEntity(uint256 initialTrust) external whenNotPaused returns (uint256 entityId) {
        if (initialTrust < MIN_INITIAL_TRUST) {
            revert InsufficientInitialTrust(initialTrust, MIN_INITIAL_TRUST);
        }

        uint256 fee = (initialTrust * marketFeeBps) / BPS_DENOMINATOR;
        uint256 net = initialTrust - fee;

        entityId = nextEntityId++;
        entities[entityId] = Entity({exists: true, trustPool: net, distrustPool: 0});
        positions[entityId][msg.sender].trustShares = net;

        accruedFees += fee;

        emit EntityCreated(entityId, msg.sender, initialTrust);
        emit TrustExpressed(entityId, msg.sender, initialTrust, fee, net);
    }

    /**
     * @notice Expresses trust in an existing entity.
     * @param entityId The id of the entity to trust.
     * @param amount The amount of trust to express.
     */
    function expressTrust(uint256 entityId, uint256 amount) external whenNotPaused {
        Entity storage entity = entities[entityId];
        if (!entity.exists) revert EntityDoesNotExist(entityId);
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * marketFeeBps) / BPS_DENOMINATOR;
        uint256 net = amount - fee;

        entity.trustPool += net;
        positions[entityId][msg.sender].trustShares += net;
        accruedFees += fee;

        emit TrustExpressed(entityId, msg.sender, amount, fee, net);
    }

    /**
     * @notice Expresses distrust in an existing entity.
     * @param entityId The id of the entity to distrust.
     * @param amount The amount of distrust to express.
     */
    function expressDistrust(uint256 entityId, uint256 amount) external whenNotPaused {
        Entity storage entity = entities[entityId];
        if (!entity.exists) revert EntityDoesNotExist(entityId);
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * marketFeeBps) / BPS_DENOMINATOR;
        uint256 net = amount - fee;

        entity.distrustPool += net;
        positions[entityId][msg.sender].distrustShares += net;
        accruedFees += fee;

        emit DistrustExpressed(entityId, msg.sender, amount, fee, net);
    }

    /**
     * @notice Redeems trust shares for a proportional share of the entity's distrust pool.
     * @param entityId The id of the entity.
     * @param shares   The number of trust shares to redeem.
     */
    function redeemTrust(uint256 entityId, uint256 shares) external whenNotPaused {
        Entity storage entity = entities[entityId];
        if (!entity.exists) revert EntityDoesNotExist(entityId);
        if (shares == 0) revert ZeroAmount();

        UserPosition storage pos = positions[entityId][msg.sender];
        if (shares > pos.trustShares) revert InsufficientShares(pos.trustShares, shares);

        uint256 trustPool = entity.trustPool;
        uint256 distrustPool = entity.distrustPool;

        if (trustPool == 0) revert CounterPoolEmpty();
        if (distrustPool == 0) revert CounterPoolEmpty();

        // Payout is a proportional share of the counter-reputation (distrust pool).
        uint256 payout = (shares * distrustPool) / trustPool;
        if (payout == 0) revert NoPayout();

        // Effects
        pos.trustShares -= shares;
        entity.trustPool = trustPool - shares;
        entity.distrustPool = distrustPool - payout;
        claimableBalance[msg.sender] += payout;

        emit TrustRedeemed(entityId, msg.sender, shares, payout);
    }

    /**
     * @notice Redeems distrust shares for a proportional share of the entity's trust pool.
     * @param entityId The id of the entity.
     * @param shares   The number of distrust shares to redeem.
     */
    function redeemDistrust(uint256 entityId, uint256 shares) external whenNotPaused {
        Entity storage entity = entities[entityId];
        if (!entity.exists) revert EntityDoesNotExist(entityId);
        if (shares == 0) revert ZeroAmount();

        UserPosition storage pos = positions[entityId][msg.sender];
        if (shares > pos.distrustShares) revert InsufficientShares(pos.distrustShares, shares);

        uint256 trustPool = entity.trustPool;
        uint256 distrustPool = entity.distrustPool;

        if (distrustPool == 0) revert CounterPoolEmpty();
        if (trustPool == 0) revert CounterPoolEmpty();

        // Payout is a proportional share of the counter-reputation (trust pool).
        uint256 payout = (shares * trustPool) / distrustPool;
        if (payout == 0) revert NoPayout();

        // Effects
        pos.distrustShares -= shares;
        entity.distrustPool = distrustPool - shares;
        entity.trustPool = trustPool - payout;
        claimableBalance[msg.sender] += payout;

        emit DistrustRedeemed(entityId, msg.sender, shares, payout);
    }

    // ---------------------------------------------------------------------------
    // View helpers
    // ---------------------------------------------------------------------------

    function entityExists(uint256 entityId) external view returns (bool) {
        return entities[entityId].exists;
    }

    function getEntity(uint256 entityId) external view returns (bool exists, uint256 trustPool, uint256 distrustPool) {
        Entity storage e = entities[entityId];
        return (e.exists, e.trustPool, e.distrustPool);
    }

    function getUserPosition(uint256 entityId, address user)
        external
        view
        returns (uint256 trustShares, uint256 distrustShares)
    {
        UserPosition storage p = positions[entityId][user];
        return (p.trustShares, p.distrustShares);
    }

    /**
     * @notice Previews the payout for redeeming trust shares.
     */
    function previewTrustRedeem(uint256 entityId, uint256 shares)
        external
        view
        returns (uint256 payout)
    {
        Entity storage e = entities[entityId];
        if (!e.exists || e.trustPool == 0) return 0;
        return (shares * e.distrustPool) / e.trustPool;
    }

    /**
     * @notice Previews the payout for redeeming distrust shares.
     */
    function previewDistrustRedeem(uint256 entityId, uint256 shares)
        external
        view
        returns (uint256 payout)
    {
        Entity storage e = entities[entityId];
        if (!e.exists || e.distrustPool == 0) return 0;
        return (shares * e.trustPool) / e.distrustPool;
    }
}
