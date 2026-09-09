// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title WeaponSkinManager
/// @notice Manages the creation, distribution, transfer, and burning of unique
///         in-game weapon skins. Each skin belongs to a skin type whose supply
///         is capped at 10,000 units. A 2% fee (computed from the skin type's
///         base price) is collected on every successful transfer and accrues
///         to the contract owner.
contract WeaponSkinManager {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error NotAuthorized();
    error SkinDoesNotExist();
    error SkinTypeDoesNotExist();
    error MaxSupplyExceeded();
    error InvalidMaxSupply();
    error TransfersPaused();
    error InsufficientFee();
    error RefundFailed();
    error SelfTransfer();
    error NothingToWithdraw();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Maximum number of units that may ever be minted for a single skin type.
    uint256 public constant MAX_SUPPLY_PER_TYPE = 10_000;
    /// @notice Transfer fee in basis points (200 = 2%).
    uint256 public constant FEE_BPS = 200;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct SkinType {
        uint256 rarity;       // rarity tier of the skin type
        uint256 visualEffect; // identifier for the visual effect
        uint256 basePrice;    // base price (wei) used to compute transfer fees
        uint256 maxSupply;    // maximum mintable units for this type (<= 10,000)
        uint256 minted;       // number of units minted so far (never decreases)
        bool exists;          // whether the skin type has been created
    }

    struct WeaponSkin {
        uint256 typeId;   // id of the skin type this skin belongs to
        uint40 mintedAt;   // timestamp the skin was minted
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    address public operator;
    bool public paused;

    uint256 internal _nextTypeId = 1;
    uint256 internal _nextId = 1;
    uint256 public totalSupply;

    mapping(uint256 => SkinType) public skinTypes;
    mapping(uint256 => WeaponSkin) internal _skins;
    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    uint256 public accumulatedFees;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SkinTypeCreated(
        uint256 indexed typeId,
        uint256 rarity,
        uint256 visualEffect,
        uint256 basePrice,
        uint256 maxSupply
    );
    event SkinTypeSupplyUpdated(uint256 indexed typeId, uint256 oldMax, uint256 newMax);
    event SkinMinted(uint256 indexed id, uint256 indexed typeId, address indexed to);
    event SkinTransferred(uint256 indexed id, address indexed from, address indexed to, uint256 fee);
    event SkinBurned(uint256 indexed id, address indexed from);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PausedStateChanged(bool paused);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TransfersPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _owner, address _operator) {
        if (_owner == address(0) || _operator == address(0)) revert ZeroAddress();
        owner = _owner;
        operator = _operator;
        emit OwnershipTransferred(address(0), _owner);
        emit OperatorChanged(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN / OPERATOR LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Transfers contract ownership to a new address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Sets a new privileged operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Pauses or unpauses all transfer operations.
    function setPaused(bool state) external onlyOperator {
        paused = state;
        emit PausedStateChanged(state);
    }

    /// @notice Withdraws accumulated transfer fees to the owner or a designated recipient.
    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();
        accumulatedFees = 0;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert RefundFailed();
        emit FeesWithdrawn(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            SKIN TYPE LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates a new skin type with immutable rarity and visual effect.
    /// @return typeId The id assigned to the newly created skin type.
    function createSkinType(
        uint256 rarity,
        uint256 visualEffect,
        uint256 basePrice,
        uint256 maxSupply
    ) external onlyOperator returns (uint256 typeId) {
        if (maxSupply == 0 || maxSupply > MAX_SUPPLY_PER_TYPE) revert InvalidMaxSupply();
        typeId = _nextTypeId++;
        SkinType storage t = skinTypes[typeId];
        t.rarity = rarity;
        t.visualEffect = visualEffect;
        t.basePrice = basePrice;
        t.maxSupply = maxSupply;
        t.exists = true;
        emit SkinTypeCreated(typeId, rarity, visualEffect, basePrice, maxSupply);
    }

    /// @notice Updates the maximum supply for an existing skin type. The new cap
    ///         cannot be lower than the number of units already minted.
    function setMaxSupply(uint256 typeId, uint256 newMax) external onlyOperator {
        SkinType storage t = skinTypes[typeId];
        if (!t.exists) revert SkinTypeDoesNotExist();
        if (newMax == 0 || newMax > MAX_SUPPLY_PER_TYPE) revert InvalidMaxSupply();
        if (newMax < t.minted) revert MaxSupplyExceeded();
        uint256 old = t.maxSupply;
        t.maxSupply = newMax;
        emit SkinTypeSupplyUpdated(typeId, old, newMax);
    }

    /*//////////////////////////////////////////////////////////////
                             MINT / BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Mints a new unique weapon skin of the given type to `to`.
    function mint(address to, uint256 typeId) external onlyOperator returns (uint256 id) {
        if (to == address(0)) revert ZeroAddress();
        SkinType storage t = skinTypes[typeId];
        if (!t.exists) revert SkinTypeDoesNotExist();
        if (t.minted >= t.maxSupply) revert MaxSupplyExceeded();

        id = _nextId++;
        t.minted++;
        _skins[id] = WeaponSkin({typeId: typeId, mintedAt: uint40(block.timestamp)});
        _ownerOf[id] = to;
        unchecked {
            _balanceOf[to]++;
            totalSupply++;
        }

        emit SkinMinted(id, typeId, to);
    }

    /// @notice Burns an existing skin. Only the owner or an approved party may burn.
    function burn(uint256 id) external {
        address from = _ownerOf[id];
        if (from == address(0)) revert SkinDoesNotExist();
        if (
            msg.sender != from &&
            !isApprovedForAll[from][msg.sender] &&
            getApproved[id] != msg.sender
        ) revert NotAuthorized();

        unchecked {
            _balanceOf[from]--;
            totalSupply--;
        }
        delete _ownerOf[id];
        delete getApproved[id];
        delete _skins[id];

        emit SkinBurned(id, from);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Transfers ownership of skin `id` from its current owner to `to`.
    ///         A 2% fee, computed from the skin type's base price, must accompany
    ///         the transfer and is credited to the contract owner. Any excess
    ///         ETH sent beyond the fee is refunded to the caller.
    function transferSkin(address to, uint256 id) external payable whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        address from = _ownerOf[id];
        if (from == address(0)) revert SkinDoesNotExist();
        if (from == to) revert SelfTransfer();
        if (
            msg.sender != from &&
            !isApprovedForAll[from][msg.sender] &&
            getApproved[id] != msg.sender
        ) revert NotAuthorized();

        SkinType storage t = skinTypes[_skins[id].typeId];
        uint256 fee = (t.basePrice * FEE_BPS) / 10_000;
        if (msg.value < fee) revert InsufficientFee();

        // effects
        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        _ownerOf[id] = to;
        delete getApproved[id];
        if (fee > 0) {
            accumulatedFees += fee;
        }
        uint256 refund = msg.value - fee;

        emit SkinTransferred(id, from, to, fee);

        // interactions
        if (refund > 0) {
            (bool ok, ) = payable(msg.sender).call{value: refund}("");
            if (!ok) revert RefundFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                              APPROVAL LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Approves `spender` to transfer the skin `id` on the owner's behalf.
    function approve(address spender, uint256 id) external {
        address tokenOwner = _ownerOf[id];
        if (tokenOwner == address(0)) revert SkinDoesNotExist();
        if (msg.sender != tokenOwner && !isApprovedForAll[tokenOwner][msg.sender]) {
            revert NotAuthorized();
        }
        getApproved[id] = spender;
        emit Approval(tokenOwner, spender, id);
    }

    /// @notice Grants or revokes operator status to manage all of the caller's skins.
    function setApprovalForAll(address op, bool approved) external {
        if (op == address(0)) revert ZeroAddress();
        isApprovedForAll[msg.sender][op] = approved;
        emit ApprovalForAll(msg.sender, op, approved);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the owner of skin `id`.
    function ownerOf(uint256 id) external view returns (address) {
        address o = _ownerOf[id];
        if (o == address(0)) revert SkinDoesNotExist();
        return o;
    }

    /// @notice Returns the number of skins owned by `account`.
    function balanceOf(address account) external view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balanceOf[account];
    }

    /// @notice Returns detailed information about a specific skin.
    function getSkin(uint256 id)
        external
        view
        returns (uint256 typeId, uint40 mintedAt, address currentOwner)
    {
        if (_ownerOf[id] == address(0)) revert SkinDoesNotExist();
        WeaponSkin storage s = _skins[id];
        return (s.typeId, s.mintedAt, _ownerOf[id]);
    }

    /// @notice Returns the full configuration of a skin type.
    function getSkinType(uint256 typeId) external view returns (SkinType memory) {
        if (!skinTypes[typeId].exists) revert SkinTypeDoesNotExist();
        return skinTypes[typeId];
    }

    /// @notice Returns the number of skin types created so far.
    function skinTypeCount() external view returns (uint256) {
        return _nextTypeId - 1;
    }

    /// @notice Returns the number of skins minted so far.
    function skinIdCount() external view returns (uint256) {
        return _nextId - 1;
    }

    /// @notice Computes the required transfer fee for a given skin.
    function computeTransferFee(uint256 id) external view returns (uint256) {
        if (_ownerOf[id] == address(0)) revert SkinDoesNotExist();
        return (skinTypes[_skins[id].typeId].basePrice * FEE_BPS) / 10_000;
    }
}
