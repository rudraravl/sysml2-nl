// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LandRegistry
 * @notice A secure registry and escrow for in-game virtual land parcels. Each parcel is a
 *         non-fungible digital asset identified by a unique ID. Players may develop parcels
 *         by spending in-game currency and may transfer parcels to other players. A
 *         designated game administrator may mint new parcels, set per-type development costs,
 *         credit players with currency, and pause player-initiated transfers in emergencies.
 */
contract LandRegistry {
    // -----------------------------------------------------------------
    // Enums
    // -----------------------------------------------------------------

    enum ParcelStatus {
        Undeveloped,
        Developed,
        Rented
    }

    // -----------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------

    struct Parcel {
        uint256 id;
        uint256 parcelType;
        uint256 developmentLevel;
        ParcelStatus status;
        bool exists;
    }

    // -----------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------

    uint256 public constant MAX_DEVELOPMENT_LEVEL = 5;
    uint256 public constant STANDARD_PARCEL_TYPE = 0;
    uint256 public constant STANDARD_DEVELOPMENT_COST_PER_LEVEL = 1000;

    // -----------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------

    address public admin;
    bool public paused;
    uint256 public nextParcelId;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => Parcel) internal _parcels;

    mapping(address => uint256) public inGameCurrency;
    mapping(uint256 => uint256) public devCostPerLevel;

    mapping(address => uint256[]) internal _ownedParcels;
    mapping(uint256 => uint256) internal _ownedParcelsIndex;

    // -----------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------

    event ParcelMinted(uint256 indexed parcelId, address indexed owner, uint256 parcelType);
    event DevelopmentLevelChanged(uint256 indexed parcelId, address indexed owner, uint256 newLevel);
    event Transfer(address indexed from, address indexed to, uint256 indexed parcelId);
    event Paused(bool isPaused);
    event DevelopmentCostSet(uint256 indexed parcelType, uint256 costPerLevel);
    event CurrencyCredited(address indexed player, uint256 amount);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    // -----------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------

    error NotAdmin();
    error ZeroAddress();
    error ParcelAlreadyExists();
    error ParcelDoesNotExist();
    error NotParcelOwner();
    error MaxDevelopmentLevelReached();
    error InsufficientCurrency();
    error TransfersArePaused();

    // -----------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TransfersArePaused();
        _;
    }

    modifier existingParcel(uint256 parcelId) {
        if (!_parcels[parcelId].exists) revert ParcelDoesNotExist();
        _;
    }

    // -----------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------

    constructor() {
        admin = msg.sender;
        nextParcelId = 1;
        devCostPerLevel[STANDARD_PARCEL_TYPE] = STANDARD_DEVELOPMENT_COST_PER_LEVEL;
        emit AdminChanged(address(0), msg.sender);
    }

    // -----------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------

    /**
     * @notice Transfers the administrator role to a new address.
     * @param newAdmin The address of the new administrator.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    /**
     * @notice Sets the development cost per level for a parcel type.
     * @param parcelType The parcel type whose cost is being configured.
     * @param costPerLevel The new development cost per level for that type.
     */
    function setDevelopmentCost(uint256 parcelType, uint256 costPerLevel) external onlyAdmin {
        devCostPerLevel[parcelType] = costPerLevel;
        emit DevelopmentCostSet(parcelType, costPerLevel);
    }

    /**
     * @notice Credits in-game currency to a player's balance.
     * @param player The player whose balance should be increased.
     * @param amount The amount of currency to credit.
     */
    function creditCurrency(address player, uint256 amount) external onlyAdmin {
        if (player == address(0)) revert ZeroAddress();
        inGameCurrency[player] += amount;
        emit CurrencyCredited(player, amount);
    }

    /**
     * @notice Pauses all player-initiated transfers in an emergency.
     */
    function pause() external onlyAdmin {
        paused = true;
        emit Paused(true);
    }

    /**
     * @notice Resumes player-initiated transfers after an emergency.
     */
    function unpause() external onlyAdmin {
        paused = false;
        emit Paused(false);
    }

    /**
     * @notice Mints a new land parcel to a specified owner.
     * @param to The address that will own the newly minted parcel.
     * @param parcelType The parcel type, used to determine development cost.
     */
    function mintParcel(address to, uint256 parcelType) external onlyAdmin {
        if (to == address(0)) revert ZeroAddress();
        if (devCostPerLevel[parcelType] == 0) {
            // Ensure a cost is configured for the type; default to the standard cost
            // if the admin has not yet set one explicitly.
            devCostPerLevel[parcelType] = STANDARD_DEVELOPMENT_COST_PER_LEVEL;
        }

        uint256 parcelId = nextParcelId++;
        _parcels[parcelId] = Parcel({
            id: parcelId,
            parcelType: parcelType,
            developmentLevel: 0,
            status: ParcelStatus.Undeveloped,
            exists: true
        });

        _addParcelToOwner(to, parcelId);
        ownerOf[parcelId] = to;
        balanceOf[to] += 1;

        emit ParcelMinted(parcelId, to, parcelType);
        emit Transfer(address(0), to, parcelId);
    }

    /**
     * @notice Sets the status of an existing parcel (e.g., to mark it as rented).
     * @param parcelId The parcel whose status should change.
     * @param newStatus The new status to assign.
     */
    function setParcelStatus(uint256 parcelId, ParcelStatus newStatus)
        external
        onlyAdmin
        existingParcel(parcelId)
    {
        _parcels[parcelId].status = newStatus;
    }

    // -----------------------------------------------------------------
    // Player Functions
    // -----------------------------------------------------------------

    /**
     * @notice Develops a parcel by spending in-game currency. Each call increments
     *         the parcel's development level by one up to a maximum of 5.
     * @param parcelId The parcel to develop.
     */
    function developParcel(uint256 parcelId) external whenNotPaused existingParcel(parcelId) {
        address parcelOwner = ownerOf[parcelId];
        if (parcelOwner != msg.sender) revert NotParcelOwner();

        Parcel storage parcel = _parcels[parcelId];
        if (parcel.developmentLevel >= MAX_DEVELOPMENT_LEVEL) {
            revert MaxDevelopmentLevelReached();
        }

        uint256 cost = devCostPerLevel[parcel.parcelType];
        if (inGameCurrency[msg.sender] < cost) revert InsufficientCurrency();

        // Effects before interactions with external state.
        inGameCurrency[msg.sender] -= cost;
        parcel.developmentLevel += 1;

        if (parcel.status == ParcelStatus.Undeveloped) {
            parcel.status = ParcelStatus.Developed;
        }

        emit DevelopmentLevelChanged(parcelId, msg.sender, parcel.developmentLevel);
    }

    /**
     * @notice Transfers ownership of a parcel to another player. Blocked while paused.
     * @param to The recipient of the parcel.
     * @param parcelId The parcel to transfer.
     */
    function transferParcel(address to, uint256 parcelId)
        external
        whenNotPaused
        existingParcel(parcelId)
    {
        address from = ownerOf[parcelId];
        if (from != msg.sender) revert NotParcelOwner();
        if (to == address(0)) revert ZeroAddress();
        if (to == from) return;

        _removeParcelFromOwner(from, parcelId);
        _addParcelToOwner(to, parcelId);

        ownerOf[parcelId] = to;
        balanceOf[from] -= 1;
        balanceOf[to] += 1;

        emit Transfer(from, to, parcelId);
    }

    // -----------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------

    /**
     * @notice Returns the list of parcel IDs owned by a given address.
     * @param owner The address to query.
     */
    function getOwnedParcels(address owner) external view returns (uint256[] memory) {
        if (owner == address(0)) revert ZeroAddress();
        return _ownedParcels[owner];
    }

    /**
     * @notice Returns the full data for a given parcel.
     */
    function getParcel(uint256 parcelId)
        external
        view
        existingParcel(parcelId)
        returns (
            address owner,
            uint256 parcelType,
            uint256 developmentLevel,
            ParcelStatus status
        )
    {
        Parcel storage parcel = _parcels[parcelId];
        return (ownerOf[parcelId], parcel.parcelType, parcel.developmentLevel, parcel.status);
    }

    /**
     * @notice Returns the development cost per level for a given parcel type.
     */
    function developmentCostOf(uint256 parcelType) external view returns (uint256) {
        uint256 cost = devCostPerLevel[parcelType];
        return cost == 0 ? STANDARD_DEVELOPMENT_COST_PER_LEVEL : cost;
    }

    // -----------------------------------------------------------------
    // Internal Helpers
    // -----------------------------------------------------------------

    function _addParcelToOwner(address to, uint256 parcelId) internal {
        _ownedParcelsIndex[parcelId] = _ownedParcels[to].length;
        _ownedParcels[to].push(parcelId);
    }

    function _removeParcelFromOwner(address from, uint256 parcelId) internal {
        uint256 lastIndex = _ownedParcels[from].length - 1;
        uint256 parcelIndex = _ownedParcelsIndex[parcelId];

        if (parcelIndex != lastIndex) {
            uint256 lastParcelId = _ownedParcels[from][lastIndex];
            _ownedParcels[from][parcelIndex] = lastParcelId;
            _ownedParcelsIndex[lastParcelId] = parcelIndex;
        }

        _ownedParcels[from].pop();
        delete _ownedParcelsIndex[parcelId];
    }
}
