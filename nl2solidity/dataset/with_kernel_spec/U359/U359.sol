// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DigitalLifeForms
/// @notice Manages creation, evolution, and ownership of unique digital life forms.
///         The contract holds no custodied assets; creation fees are forwarded directly
///         to the designated operator.
contract DigitalLifeForms {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event EntityCreated(uint256 indexed id, address indexed owner, string name, uint256 stage);
    event EntityEvolved(uint256 indexed id, address indexed owner, uint256 oldStage, uint256 newStage);
    event Transferred(uint256 indexed id, address indexed from, address indexed to);
    event ConfigUpdated(uint256 newCreationCost, uint256 newEvolutionResourceCost);
    event ResourcesGranted(address indexed to, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOperator();
    error NotOwner();
    error EntityNotFound();
    error InvalidAddress();
    error InsufficientFee();
    error InsufficientResources();
    error MaxEvolutionReached();
    error FeeTransferFailed();
    error EmptyName();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_EVOLUTIONS = 5;
    uint256 public constant INITIAL_CREATION_COST = 0.01 ether;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    address public operator;

    /// @notice Cost in wei required to create a new digital entity.
    uint256 public creationCost;

    /// @notice Amount of resources required to evolve an entity one stage.
    uint256 public evolutionResourceCost;

    /// @notice Next entity id to be minted.
    uint256 public nextId;

    struct DigitalEntity {
        uint256 id;
        string name;
        uint256 stage;
        uint256 power;
        uint256 vitality;
        uint256 agility;
        uint256 createdAt;
    }

    mapping(uint256 => DigitalEntity) private _entities;
    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(address => uint256) private _resourceBalance;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        operator = msg.sender;
        creationCost = INITIAL_CREATION_COST;
        evolutionResourceCost = 100;
        emit OperatorUpdated(address(0), msg.sender);
        emit ConfigUpdated(creationCost, evolutionResourceCost);
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new digital entity. Requires exactly the creation cost in ether.
    /// @param name A human-readable label for the entity.
    /// @return id The newly assigned entity id.
    function createEntity(string calldata name) external payable returns (uint256 id) {
        if (bytes(name).length == 0) revert EmptyName();
        if (msg.value < creationCost) revert InsufficientFee();

        id = nextId++;

        _entities[id] = DigitalEntity({
            id: id,
            name: name,
            stage: 1,
            power: 10,
            vitality: 10,
            agility: 10,
            createdAt: block.timestamp
        });

        _ownerOf[id] = msg.sender;
        unchecked {
            _balanceOf[msg.sender]++;
        }

        // Forward the fee directly to the operator; the contract holds no custodied assets.
        (bool sent, ) = operator.call{value: msg.value}("");
        if (!sent) revert FeeTransferFailed();

        emit EntityCreated(id, msg.sender, name, 1);
    }

    /// @notice Evolves an entity owned by the caller, consuming resources.
    /// @param id The entity to evolve.
    function evolve(uint256 id) external {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert EntityNotFound();
        if (owner != msg.sender) revert NotOwner();

        DigitalEntity storage entity = _entities[id];
        if (entity.stage >= MAX_EVOLUTIONS) revert MaxEvolutionReached();
        if (_resourceBalance[msg.sender] < evolutionResourceCost) revert InsufficientResources();

        // Effects
        _resourceBalance[msg.sender] -= evolutionResourceCost;
        uint256 oldStage = entity.stage;
        entity.stage = oldStage + 1;
        entity.power += 5 * entity.stage;
        entity.vitality += 4 * entity.stage;
        entity.agility += 3 * entity.stage;

        emit EntityEvolved(id, msg.sender, oldStage, entity.stage);
    }

    /// @notice Transfers ownership of an entity to a new address.
    /// @param id The entity id.
    /// @param to The recipient address.
    function transfer(uint256 id, address to) external {
        address from = _ownerOf[id];
        if (from == address(0)) revert EntityNotFound();
        if (from != msg.sender) revert NotOwner();
        if (to == address(0)) revert InvalidAddress();
        if (to == from) revert InvalidAddress();

        // Effects
        _ownerOf[id] = to;
        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }

        emit Transferred(id, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates global configuration parameters.
    /// @param newCreationCost New creation fee in wei.
    /// @param newEvolutionResourceCost New resource cost per evolution.
    function setConfig(uint256 newCreationCost, uint256 newEvolutionResourceCost) external onlyOperator {
        creationCost = newCreationCost;
        evolutionResourceCost = newEvolutionResourceCost;
        emit ConfigUpdated(newCreationCost, newEvolutionResourceCost);
    }

    /// @notice Grants resources to an address, enabling evolution.
    /// @param to Recipient of the resources.
    /// @param amount Quantity of resources to grant.
    function grantResources(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert InvalidAddress();
        _resourceBalance[to] += amount;
        emit ResourcesGranted(to, amount);
    }

    /// @notice Transfers operator privileges to a new address.
    /// @param newOperator The address of the new operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the owner of a given entity.
    function ownerOf(uint256 id) external view returns (address) {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert EntityNotFound();
        return owner;
    }

    /// @notice Returns the number of entities owned by an address.
    function balanceOf(address account) external view returns (uint256) {
        return _balanceOf[account];
    }

    /// @notice Returns the resource balance of an address.
    function resourceBalanceOf(address account) external view returns (uint256) {
        return _resourceBalance[account];
    }

    /// @notice Returns the full attribute set of an entity.
    function getEntity(uint256 id) external view returns (DigitalEntity memory) {
        if (_ownerOf[id] == address(0)) revert EntityNotFound();
        return _entities[id];
    }

    /// @notice Returns the current evolutionary stage of an entity.
    function stageOf(uint256 id) external view returns (uint256) {
        if (_ownerOf[id] == address(0)) revert EntityNotFound();
        return _entities[id].stage;
    }
}
