// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CharacterAssets
 * @notice Manages unique digital character assets and their associated in-game items.
 *         The contract holds no custodied value; it only tracks ownership, experience,
 *         and equipment state.
 */
contract CharacterAssets {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum experience points a character can accumulate.
    uint256 public constant MAX_EXPERIENCE = 10_000;
    /// @notice Minimum experience points required to equip an item.
    uint256 public constant MIN_EXPERIENCE_TO_EQUIP = 500;

    uint8 public constant SLOT_NONE = 0;
    uint8 public constant SLOT_WEAPON = 1;
    uint8 public constant SLOT_ARMOR = 2;
    uint8 public constant SLOT_ACCESSORY = 3;
    uint8 public constant MAX_SLOT = 3;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotCharacterOwner();
    error NotOperator();
    error CharacterNotFound();
    error ItemNotFound();
    error ItemTypeNotFound();
    error ExperienceCapExceeded(uint256 currentXP, uint256 attemptedAdd);
    error InsufficientExperience(uint256 currentXP, uint256 required);
    error ItemNotOwnedByCaller();
    error SlotOccupied(uint8 slot);
    error SlotEmpty(uint8 slot);
    error ItemAlreadyEquipped();
    error InvalidSlot();
    error TransferToZeroAddress();
    error EmptyName();
    error ZeroQuantity();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event CharacterCreated(uint256 indexed characterId, address indexed owner, string name, uint256 classId);
    event ExperienceAssigned(uint256 indexed characterId, address indexed by, uint256 amount, uint256 newXP);
    event ItemEquipped(uint256 indexed characterId, uint256 indexed itemId, uint8 slot);
    event ItemUnequipped(uint256 indexed characterId, uint256 indexed itemId, uint8 slot);
    event CharacterTransferred(uint256 indexed characterId, address indexed from, address indexed to);
    event ItemTypeDefined(uint256 indexed typeId, string name, uint8 slot, uint8 rarity, uint16 statBonus);
    event ItemMinted(uint256 indexed itemId, uint256 indexed typeId, address indexed to);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Character {
        address owner;
        uint256 xp;
        string name;
        uint256 classId;
        bool exists;
    }

    struct ItemType {
        string name;
        uint8 slot;
        uint8 rarity;
        uint16 statBonus;
        bool exists;
    }

    struct ItemInstance {
        uint256 typeId;
        address owner;
        uint256 equippedCharacterId; // 0 means not equipped
        bool exists;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public operator;

    uint256 public nextCharacterId = 1;
    uint256 public nextItemTypeId = 1;
    uint256 public nextItemId = 1;

    mapping(uint256 => Character) public characters;
    mapping(uint256 => ItemType) public itemTypes;
    mapping(uint256 => ItemInstance) public items;

    /// @dev characterId => slot => itemId (0 = empty)
    mapping(uint256 => mapping(uint8 => uint256)) public equippedItems;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyCharacterOwner(uint256 characterId) {
        Character storage c = characters[characterId];
        if (!c.exists) revert CharacterNotFound();
        if (c.owner != msg.sender) revert NotCharacterOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator) {
        if (_operator == address(0)) revert TransferToZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                         CHARACTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new character asset owned by the caller.
     * @param name    A human-readable name for the character.
     * @param classId The class identifier (e.g., warrior, mage, rogue).
     * @return characterId The unique identifier assigned to the new character.
     */
    function createCharacter(string calldata name, uint256 classId) external returns (uint256 characterId) {
        if (bytes(name).length == 0) revert EmptyName();
        characterId = nextCharacterId++;
        characters[characterId] = Character({
            owner: msg.sender,
            xp: 0,
            name: name,
            classId: classId,
            exists: true
        });
        emit CharacterCreated(characterId, msg.sender, name, classId);
    }

    /**
     * @notice Assigns experience points to a character owned by the caller.
     *         Total XP is capped at {MAX_EXPERIENCE}.
     * @param characterId The character receiving experience.
     * @param amount      The amount of XP to add.
     */
    function assignExperience(uint256 characterId, uint256 amount) external onlyCharacterOwner(characterId) {
        Character storage c = characters[characterId];
        uint256 newXP = c.xp + amount;
        if (newXP > MAX_EXPERIENCE) revert ExperienceCapExceeded(c.xp, amount);
        c.xp = newXP;
        emit ExperienceAssigned(characterId, msg.sender, amount, newXP);
    }

    /**
     * @notice Equips an item from the caller's inventory onto a character.
     *         The character must have at least {MIN_EXPERIENCE_TO_EQUIP} XP.
     * @param characterId The character that will equip the item.
     * @param itemId      The item instance to equip.
     */
    function equipItem(uint256 characterId, uint256 itemId) external onlyCharacterOwner(characterId) {
        Character storage c = characters[characterId];
        ItemInstance storage item = items[itemId];
        if (!item.exists) revert ItemNotFound();
        if (item.owner != msg.sender) revert ItemNotOwnedByCaller();
        if (item.equippedCharacterId != 0) revert ItemAlreadyEquipped();
        if (c.xp < MIN_EXPERIENCE_TO_EQUIP) revert InsufficientExperience(c.xp, MIN_EXPERIENCE_TO_EQUIP);

        ItemType storage itemType = itemTypes[item.typeId];
        uint8 slot = itemType.slot;
        if (slot == SLOT_NONE || slot > MAX_SLOT) revert InvalidSlot();
        if (equippedItems[characterId][slot] != 0) revert SlotOccupied(slot);

        // Effects
        equippedItems[characterId][slot] = itemId;
        item.equippedCharacterId = characterId;

        emit ItemEquipped(characterId, itemId, slot);
    }

    /**
     * @notice Unequips the item currently in the specified slot of a character.
     * @param characterId The character from which to unequip.
     * @param slot        The equipment slot to clear.
     */
    function unequipItem(uint256 characterId, uint8 slot) external onlyCharacterOwner(characterId) {
        if (slot == SLOT_NONE || slot > MAX_SLOT) revert InvalidSlot();
        uint256 itemId = equippedItems[characterId][slot];
        if (itemId == 0) revert SlotEmpty(slot);

        // Effects
        equippedItems[characterId][slot] = 0;
        items[itemId].equippedCharacterId = 0;

        emit ItemUnequipped(characterId, itemId, slot);
    }

    /**
     * @notice Transfers ownership of a character (and any equipped items) to a new address.
     * @param characterId The character to transfer.
     * @param to          The new owner.
     */
    function transferCharacter(uint256 characterId, address to) external onlyCharacterOwner(characterId) {
        if (to == address(0)) revert TransferToZeroAddress();

        address from = msg.sender;
        characters[characterId].owner = to;

        // Transfer ownership of all equipped items to the new owner.
        for (uint8 slot = 1; slot <= MAX_SLOT; slot++) {
            uint256 itemId = equippedItems[characterId][slot];
            if (itemId != 0) {
                items[itemId].owner = to;
            }
        }

        emit CharacterTransferred(characterId, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Defines a new item type in the global registry.
     * @param name      Human-readable name for the item type.
     * @param slot      Equipment slot this item type occupies.
     * @param rarity    Rarity tier (arbitrary application-defined scale).
     * @param statBonus Bonus stat granted by this item type.
     * @return typeId The unique identifier assigned to the new item type.
     */
    function defineItemType(
        string calldata name,
        uint8 slot,
        uint8 rarity,
        uint16 statBonus
    ) external onlyOperator returns (uint256 typeId) {
        if (bytes(name).length == 0) revert EmptyName();
        if (slot == SLOT_NONE || slot > MAX_SLOT) revert InvalidSlot();

        typeId = nextItemTypeId++;
        itemTypes[typeId] = ItemType({
            name: name,
            slot: slot,
            rarity: rarity,
            statBonus: statBonus,
            exists: true
        });

        emit ItemTypeDefined(typeId, name, slot, rarity, statBonus);
    }

    /**
     * @notice Mints a single item instance of the given type to a recipient.
     * @param typeId The item type to mint.
     * @param to     The recipient of the minted item.
     * @return itemId The unique identifier of the minted item instance.
     */
    function mintItem(uint256 typeId, address to) external onlyOperator returns (uint256 itemId) {
        if (to == address(0)) revert TransferToZeroAddress();
        if (!itemTypes[typeId].exists) revert ItemTypeNotFound();

        itemId = nextItemId++;
        items[itemId] = ItemInstance({
            typeId: typeId,
            owner: to,
            equippedCharacterId: 0,
            exists: true
        });

        emit ItemMinted(itemId, typeId, to);
    }

    /**
     * @notice Mints multiple item instances of the given type to a recipient.
     * @param typeId   The item type to mint.
     * @param to       The recipient of the minted items.
     * @param quantity The number of item instances to mint.
     * @return itemIds An array of the minted item instance identifiers.
     */
    function mintItems(
        uint256 typeId,
        address to,
        uint256 quantity
    ) external onlyOperator returns (uint256[] memory itemIds) {
        if (to == address(0)) revert TransferToZeroAddress();
        if (!itemTypes[typeId].exists) revert ItemTypeNotFound();
        if (quantity == 0) revert ZeroQuantity();

        itemIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            uint256 itemId = nextItemId++;
            items[itemId] = ItemInstance({
                typeId: typeId,
                owner: to,
                equippedCharacterId: 0,
                exists: true
            });
            itemIds[i] = itemId;
            emit ItemMinted(itemId, typeId, to);
        }
    }

    /**
     * @notice Transfers operator role to a new address.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert TransferToZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the core attributes of a character.
     */
    function getCharacter(uint256 characterId)
        external
        view
        returns (address owner, uint256 xp, string memory name, uint256 classId)
    {
        Character storage c = characters[characterId];
        if (!c.exists) revert CharacterNotFound();
        return (c.owner, c.xp, c.name, c.classId);
    }

    /**
     * @notice Returns the properties of an item type.
     */
    function getItemType(uint256 typeId)
        external
        view
        returns (string memory name, uint8 slot, uint8 rarity, uint16 statBonus)
    {
        ItemType storage it = itemTypes[typeId];
        if (!it.exists) revert ItemTypeNotFound();
        return (it.name, it.slot, it.rarity, it.statBonus);
    }

    /**
     * @notice Returns the state of an item instance.
     */
    function getItem(uint256 itemId)
        external
        view
        returns (uint256 typeId, address owner, uint256 equippedCharacterId)
    {
        ItemInstance storage item = items[itemId];
        if (!item.exists) revert ItemNotFound();
        return (item.typeId, item.owner, item.equippedCharacterId);
    }

    /**
     * @notice Returns the item instance ID equipped in a given slot for a character.
     *         Returns 0 if the slot is empty.
     */
    function getEquippedItem(uint256 characterId, uint8 slot) external view returns (uint256 itemId) {
        return equippedItems[characterId][slot];
    }

    /**
     * @notice Returns all equipped item IDs for a character across the three slots.
     */
    function getCharacterEquipment(uint256 characterId)
        external
        view
        returns (uint256 weaponId, uint256 armorId, uint256 accessoryId)
    {
        return (
            equippedItems[characterId][SLOT_WEAPON],
            equippedItems[characterId][SLOT_ARMOR],
            equippedItems[characterId][SLOT_ACCESSORY]
        );
    }

    /**
     * @notice Returns the total number of item types defined.
     */
    function totalItemTypes() external view returns (uint256) {
        return nextItemTypeId - 1;
    }

    /**
     * @notice Returns the total number of item instances minted.
     */
    function totalItems() external view returns (uint256) {
        return nextItemId - 1;
    }

    /**
     * @notice Returns the total number of characters created.
     */
    function totalCharacters() external view returns (uint256) {
        return nextCharacterId - 1;
    }
}
