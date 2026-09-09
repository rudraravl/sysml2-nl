// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title FractionalRealEstate
/// @notice Manages fractionalized ownership shares of real estate assets.
/// @dev The contract holds no direct assets itself; it only tracks share balances
///      and property valuations that represent claims on off-chain property.
contract FractionalRealEstate {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Minimum purchase amount: 0.01 units (18-decimal precision).
    uint256 public constant MIN_PURCHASE = 1e16;
    /// @dev Sale fee in basis points: 0.5% = 50 bps.
    uint256 public constant SALE_FEE_BPS = 50;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAuthorized();
    error PropertyAlreadyExists();
    error PropertyDoesNotExist();
    error TradingPaused();
    error ZeroAddress();
    error ZeroAmount();
    error BelowMinimumPurchase();
    error InsufficientShares();
    error ValuationZero();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event PropertyAdded(uint256 indexed propertyId, uint256 initialValuation);
    event ValuationUpdated(uint256 indexed propertyId, uint256 oldValuation, uint256 newValuation);
    event PropertyPaused(uint256 indexed propertyId, bool paused);
    event SharesPurchased(address indexed buyer, uint256 indexed propertyId, uint256 amount);
    event SharesSold(address indexed seller, uint256 indexed propertyId, uint256 amount, uint256 fee);
    event SharesTransferred(
        address indexed from,
        address indexed to,
        uint256 indexed propertyId,
        uint256 amount
    );
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event FeeCollectorUpdated(address indexed previousCollector, address indexed newCollector);

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Property {
        bool exists;
        uint256 valuation;
        bool paused;
        uint256 totalShares;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public admin;
    address public feeCollector;

    uint256[] public propertyIds;
    mapping(uint256 => bool) public propertyExists;
    mapping(uint256 => Property) internal properties;
    mapping(uint256 => mapping(address => uint256)) internal shares; // propertyId => user => balance
    mapping(address => uint256) internal userTotalShares;           // user => total shares across all properties

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAuthorized();
        _;
    }

    modifier propertyMustExist(uint256 propertyId) {
        if (!properties[propertyId].exists) revert PropertyDoesNotExist();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _admin, address _feeCollector) {
        if (_admin == address(0)) revert ZeroAddress();
        if (_feeCollector == address(0)) revert ZeroAddress();

        admin = _admin;
        feeCollector = _feeCollector;

        emit AdminChanged(address(0), _admin);
        emit FeeCollectorUpdated(address(0), _feeCollector);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a new property to the registry.
    /// @param propertyId Unique identifier for the property.
    /// @param initialValuation Starting valuation of the property (18-decimal units).
    function addProperty(uint256 propertyId, uint256 initialValuation) external onlyAdmin {
        if (properties[propertyId].exists) revert PropertyAlreadyExists();
        if (initialValuation == 0) revert ValuationZero();

        properties[propertyId] = Property({
            exists: true,
            valuation: initialValuation,
            paused: false,
            totalShares: 0
        });

        propertyExists[propertyId] = true;
        propertyIds.push(propertyId);

        emit PropertyAdded(propertyId, initialValuation);
    }

    /// @notice Updates the valuation of an existing property.
    /// @param propertyId Property to update.
    /// @param newValuation New valuation value.
    function updateValuation(uint256 propertyId, uint256 newValuation)
        external
        onlyAdmin
        propertyMustExist(propertyId)
    {
        if (newValuation == 0) revert ValuationZero();

        uint256 oldValuation = properties[propertyId].valuation;
        properties[propertyId].valuation = newValuation;

        emit ValuationUpdated(propertyId, oldValuation, newValuation);
    }

    /// @notice Pauses or unpauses share trading for a specific property.
    /// @param propertyId Property to pause/unpause.
    /// @param paused True to pause, false to unpause.
    function setPropertyPaused(uint256 propertyId, bool paused)
        external
        onlyAdmin
        propertyMustExist(propertyId)
    {
        properties[propertyId].paused = paused;
        emit PropertyPaused(propertyId, paused);
    }

    /// @notice Sets a new fee collector address.
    /// @param newCollector Address that will receive sale fees.
    function setFeeCollector(address newCollector) external onlyAdmin {
        if (newCollector == address(0)) revert ZeroAddress();
        address previous = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(previous, newCollector);
    }

    /// @notice Transfers admin rights to a new address.
    /// @param newAdmin Address of the new administrator.
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminChanged(previous, newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                        USER TRADING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Purchases fractional shares of a property.
    /// @dev Shares are minted to the caller; the contract does not handle payments.
    /// @param propertyId Property to purchase shares of.
    /// @param amount Number of shares to purchase (18-decimal units).
    function purchaseShares(uint256 propertyId, uint256 amount)
        external
        propertyMustExist(propertyId)
    {
        if (amount < MIN_PURCHASE) revert BelowMinimumPurchase();

        Property storage prop = properties[propertyId];
        if (prop.paused) revert TradingPaused();

        // Effects
        shares[propertyId][msg.sender] += amount;
        prop.totalShares += amount;
        userTotalShares[msg.sender] += amount;

        emit SharesPurchased(msg.sender, propertyId, amount);
    }

    /// @notice Sells fractional shares back to the contract.
    /// @dev A 0.5% fee is deducted from the sold shares and credited to the fee collector.
    /// @param propertyId Property to sell shares of.
    /// @param amount Number of shares to sell (18-decimal units).
    function sellShares(uint256 propertyId, uint256 amount)
        external
        propertyMustExist(propertyId)
    {
        if (amount == 0) revert ZeroAmount();

        Property storage prop = properties[propertyId];
        if (prop.paused) revert TradingPaused();

        if (shares[propertyId][msg.sender] < amount) revert InsufficientShares();

        uint256 fee = (amount * SALE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountAfterFee = amount - fee;

        // Effects
        shares[propertyId][msg.sender] -= amount;
        userTotalShares[msg.sender] -= amount;
        prop.totalShares -= amountAfterFee;

        if (fee > 0) {
            shares[propertyId][feeCollector] += fee;
        }

        emit SharesSold(msg.sender, propertyId, amount, fee);
    }

    /// @notice Transfers fractional shares to another user.
    /// @param propertyId Property whose shares are transferred.
    /// @param to Recipient address.
    /// @param amount Number of shares to transfer (18-decimal units).
    function transferShares(uint256 propertyId, address to, uint256 amount)
        external
        propertyMustExist(propertyId)
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        Property storage prop = properties[propertyId];
        if (prop.paused) revert TradingPaused();

        if (shares[propertyId][msg.sender] < amount) revert InsufficientShares();

        // Effects
        shares[propertyId][msg.sender] -= amount;
        shares[propertyId][to] += amount;
        userTotalShares[msg.sender] -= amount;
        userTotalShares[to] += amount;

        emit SharesTransferred(msg.sender, to, propertyId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the details of a property.
    /// @param propertyId Property identifier.
    function getProperty(uint256 propertyId)
        external
        view
        returns (uint256 valuation, bool paused, uint256 totalShares, bool exists)
    {
        Property storage prop = properties[propertyId];
        return (prop.valuation, prop.paused, prop.totalShares, prop.exists);
    }

    /// @notice Returns the share balance of a user for a specific property.
    /// @param user Address of the user.
    /// @param propertyId Property identifier.
    function getUserShares(address user, uint256 propertyId) external view returns (uint256) {
        return shares[propertyId][user];
    }

    /// @notice Returns the total shares held by a user across all properties.
    /// @param user Address of the user.
    function getUserTotalShares(address user) external view returns (uint256) {
        return userTotalShares[user];
    }

    /// @notice Returns the list of all registered property IDs.
    function getPropertyIds() external view returns (uint256[] memory) {
        return propertyIds;
    }

    /// @notice Returns whether a property is currently paused.
    /// @param propertyId Property identifier.
    function isPropertyPaused(uint256 propertyId) external view returns (bool) {
        return properties[propertyId].paused;
    }

    /// @notice Returns the current valuation of a property.
    /// @param propertyId Property identifier.
    function getPropertyValuation(uint256 propertyId) external view returns (uint256) {
        return properties[propertyId].valuation;
    }
}
