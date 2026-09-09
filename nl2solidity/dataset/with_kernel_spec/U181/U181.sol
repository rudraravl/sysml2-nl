// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CollectiblePacks
/// @notice Custodies unique digital collectibles and distributes them through sealed packs.
contract CollectiblePacks {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotOperator();
    error InvalidPack();
    error PackInactive();
    error IncorrectFee();
    error MaxSupplyReached();
    error NotMinted();
    error NotOwner();
    error NotAuthorized();
    error InvalidRecipient();
    error TransferFailed();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PackCreated(uint256 indexed packId, uint256 size, address indexed creator);
    event PackOpened(uint256 indexed packId, address indexed opener);
    event PackCancelled(uint256 indexed packId);
    event CollectibleTransferred(uint256 indexed collectibleId, address indexed from, address indexed to);
    event RarityWeightsUpdated(uint256 indexed packId, address indexed operator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed operator, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant PACK_FEE = 0.01 ether;
    uint256 public constant NUM_RARITIES = 4;

    /*//////////////////////////////////////////////////////////////
                              TYPES
    //////////////////////////////////////////////////////////////*/
    enum PackStatus {
        NonExistent,
        Created,
        Opened,
        Cancelled
    }

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address public operator;
    uint256 public totalMinted;
    uint256 public reservedSupply;
    uint256 public nextPackId;
    uint256 private _mintNonce;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => uint8) public collectibleRarity;

    mapping(uint256 => uint256[]) internal _packContents;
    mapping(uint256 => uint256[]) internal _packRarityWeights;
    mapping(uint256 => PackStatus) public packStatus;
    mapping(uint256 => uint256) public packSize;

    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

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
        emit OperatorChanged(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR LOGIC
    //////////////////////////////////////////////////////////////*/
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /*//////////////////////////////////////////////////////////////
                          PACK MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function createPack(uint256 size, uint256[] calldata weights)
        external
        onlyOperator
        returns (uint256 packId)
    {
        if (size == 0) revert InvalidPack();
        if (weights.length == 0 || weights.length > NUM_RARITIES) revert InvalidPack();

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        if (totalWeight == 0) revert InvalidPack();

        if (totalMinted + reservedSupply + size > MAX_SUPPLY) revert MaxSupplyReached();

        packId = nextPackId++;
        packSize[packId] = size;
        packStatus[packId] = PackStatus.Created;
        for (uint256 i = 0; i < weights.length; i++) {
            _packRarityWeights[packId].push(weights[i]);
        }
        reservedSupply += size;

        emit PackCreated(packId, size, msg.sender);
    }

    function setRarityWeights(uint256 packId, uint256[] calldata weights) external onlyOperator {
        if (packId >= nextPackId) revert InvalidPack();
        if (packStatus[packId] != PackStatus.Created) revert PackInactive();
        if (weights.length == 0 || weights.length > NUM_RARITIES) revert InvalidPack();

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        if (totalWeight == 0) revert InvalidPack();

        delete _packRarityWeights[packId];
        for (uint256 i = 0; i < weights.length; i++) {
            _packRarityWeights[packId].push(weights[i]);
        }

        emit RarityWeightsUpdated(packId, msg.sender);
    }

    function cancelPack(uint256 packId) external onlyOperator {
        if (packId >= nextPackId) revert InvalidPack();
        if (packStatus[packId] != PackStatus.Created) revert PackInactive();

        uint256 size = packSize[packId];
        packStatus[packId] = PackStatus.Cancelled;
        reservedSupply -= size;

        emit PackCancelled(packId);
    }

    /*//////////////////////////////////////////////////////////////
                            PACK OPENING
    //////////////////////////////////////////////////////////////*/
    function openPack(uint256 packId) external payable returns (uint256[] memory mintedIds) {
        if (msg.value != PACK_FEE) revert IncorrectFee();
        if (packId >= nextPackId) revert InvalidPack();
        if (packStatus[packId] != PackStatus.Created) revert PackInactive();

        uint256 size = packSize[packId];
        if (totalMinted + size > MAX_SUPPLY) revert MaxSupplyReached();

        // Effects: mark the pack opened and release its reservation before minting.
        packStatus[packId] = PackStatus.Opened;
        reservedSupply -= size;

        mintedIds = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            uint256 id = ++totalMinted;
            uint8 rarity = _pickRarity(packId, i);
            collectibleRarity[id] = rarity;
            ownerOf[id] = msg.sender;
            balanceOf[msg.sender]++;
            _packContents[packId].push(id);
            mintedIds[i] = id;
            emit CollectibleTransferred(id, address(0), msg.sender);
        }

        emit PackOpened(packId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                         COLLECTIBLE TRANSFERS
    //////////////////////////////////////////////////////////////*/
    function transferCollectible(address to, uint256 id) external {
        address owner = ownerOf[id];
        if (owner == address(0)) revert NotMinted();
        if (owner != msg.sender) revert NotOwner();
        _transfer(msg.sender, to, id);
    }

    function transferFrom(address from, address to, uint256 id) external {
        address owner = ownerOf[id];
        if (owner == address(0)) revert NotMinted();
        if (owner != from) revert NotOwner();
        if (msg.sender != from && getApproved[id] != msg.sender && !isApprovedForAll[from][msg.sender]) {
            revert NotAuthorized();
        }
        _transfer(from, to, id);
    }

    function _transfer(address from, address to, uint256 id) internal {
        if (to == address(0)) revert InvalidRecipient();
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        ownerOf[id] = to;
        delete getApproved[id];
        emit CollectibleTransferred(id, from, to);
    }

    function approve(address spender, uint256 id) external {
        address owner = ownerOf[id];
        if (owner == address(0)) revert NotMinted();
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        getApproved[id] = spender;
        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator_, bool approved) external {
        if (operator_ == address(0)) revert ZeroAddress();
        isApprovedForAll[msg.sender][operator_] = approved;
        emit ApprovalForAll(msg.sender, operator_, approved);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/
    function getPackContents(uint256 packId) external view returns (uint256[] memory) {
        return _packContents[packId];
    }

    function getPackRarityWeights(uint256 packId) external view returns (uint256[] memory) {
        return _packRarityWeights[packId];
    }

    function rarityName(uint8 r) public pure returns (string memory) {
        if (r == 0) return "Common";
        if (r == 1) return "Rare";
        if (r == 2) return "Epic";
        if (r == 3) return "Legendary";
        return "Unknown";
    }

    /*//////////////////////////////////////////////////////////////
                          FEE WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function withdrawFees() external onlyOperator {
        uint256 amount = address(this).balance;
        if (amount > 0) {
            (bool ok, ) = payable(operator).call{value: amount}("");
            if (!ok) revert TransferFailed();
            emit FeesWithdrawn(operator, amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _pickRarity(uint256 packId, uint256 index) internal returns (uint8) {
        uint256[] storage weights = _packRarityWeights[packId];
        uint256 len = weights.length;
        uint256 total = 0;
        for (uint256 i = 0; i < len; i++) {
            total += weights[i];
        }
        if (total == 0) return 0;

        // Pseudo-random selection across the configured rarity weights.
        // NOTE: Pure on-chain randomness is inherently limited; for high-value
        // minting, integrate a decentralized randomness beacon (e.g. Chainlink VRF).
        // Block-derived values are intentionally avoided here; entropy is mixed
        // from the caller, pack id, per-mint index, a monotonic nonce, and gas.
        uint256 roll = uint256(
            keccak256(abi.encodePacked(msg.sender, packId, index, _mintNonce, gasleft()))
        ) % total;
        _mintNonce++;

        uint256 cum = 0;
        for (uint256 i = 0; i < len; i++) {
            cum += weights[i];
            if (roll < cum) return uint8(i);
        }
        return uint8(len - 1);
    }
}
