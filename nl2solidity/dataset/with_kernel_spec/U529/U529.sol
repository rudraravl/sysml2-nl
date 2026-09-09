// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract GachaPack {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error ZeroAddress();
    error PackTypeAlreadyExists();
    error PackTypeDoesNotExist();
    error PackTypeNotActive();
    error CollectibleTypeAlreadyExists();
    error CollectibleTypeDoesNotExist();
    error InsufficientSupply();
    error InsufficientUnopenedPacks();
    error NoPendingCollectibles();
    error NotPendingClaimant();
    error InvalidAmount();
    error InvalidProbabilityTable();
    error ArrayLengthsMismatch();
    error TokenDoesNotExist();
    error NotTokenOwner();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event PackTypeCreated(uint256 indexed packTypeId, uint256 price, uint256 supply);
    event PackSupplyReplenished(uint256 indexed packTypeId, uint256 amountAdded, uint256 newRemaining);
    event PackPriceUpdated(uint256 indexed packTypeId, uint256 oldPrice, uint256 newPrice);
    event PackActiveChanged(uint256 indexed packTypeId, bool active);
    event ProbabilityTableUpdated(uint256 indexed packTypeId, uint256 entryCount);
    event CollectibleTypeCreated(uint256 indexed collectibleId, string name, uint256 maxSupply);
    event CollectibleMaxSupplyUpdated(uint256 indexed collectibleId, uint256 newMaxSupply);
    event PackPurchased(address indexed user, uint256 indexed packTypeId, uint256 amount, uint256 totalPaid, uint256 fee);
    event PackOpened(address indexed user, uint256 indexed packTypeId, uint256 packsOpened, uint256[] revealedTokenIds);
    event CollectibleClaimed(address indexed user, uint256 indexed tokenId, uint256 collectibleId);
    event RevenueWithdrawn(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant COLLECTIBLES_PER_PACK = 5;

    string public constant name = "Gacha Collectible";
    string public constant symbol = "GACHA";

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address public operator;
    address public treasury;
    IERC20 public immutable paymentToken;

    uint256 private _randomNonce;
    uint256 private _nextTokenId = 1;

    struct PackType {
        bool exists;
        uint256 price;
        uint256 supply;
        uint256 remaining;
        bool active;
    }

    struct CollectibleType {
        bool exists;
        string name;
        uint256 maxSupply;
        uint256 minted;
    }

    struct ProbabilityEntry {
        uint256 collectibleId;
        uint256 weight;
    }

    mapping(uint256 => PackType) public packTypes;
    mapping(uint256 => ProbabilityEntry[]) internal _probabilityTable;
    mapping(uint256 => CollectibleType) public collectibleTypes;

    // User => packTypeId => count of unopened packs
    mapping(address => mapping(uint256 => uint256)) public unopenedPacks;

    // Pending collectible tracking for O(1) claim operations
    mapping(uint256 => address) public pendingClaimant; // tokenId => user entitled to claim
    mapping(address => uint256[]) internal _pendingList; // user => pending tokenIds
    mapping(uint256 => uint256) internal _pendingIndex; // tokenId => index in user's _pendingList

    // ERC-721 token state
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => uint256) public tokenCollectibleId; // tokenId => collectibleTypeId
    string private _baseURI;

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _paymentToken, address _treasury, string memory baseURI_) {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
        operator = msg.sender;
        _baseURI = baseURI_;
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR: CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    function setBaseURI(string memory baseURI_) external onlyOperator {
        _baseURI = baseURI_;
    }

    function createCollectibleType(
        uint256 collectibleId,
        string calldata collectibleName,
        uint256 maxSupply
    ) external onlyOperator {
        if (collectibleTypes[collectibleId].exists) revert CollectibleTypeAlreadyExists();
        collectibleTypes[collectibleId] = CollectibleType({
            exists: true,
            name: collectibleName,
            maxSupply: maxSupply,
            minted: 0
        });
        emit CollectibleTypeCreated(collectibleId, collectibleName, maxSupply);
    }

    function updateCollectibleMaxSupply(uint256 collectibleId, uint256 newMaxSupply) external onlyOperator {
        if (!collectibleTypes[collectibleId].exists) revert CollectibleTypeDoesNotExist();
        collectibleTypes[collectibleId].maxSupply = newMaxSupply;
        emit CollectibleMaxSupplyUpdated(collectibleId, newMaxSupply);
    }

    function createPackType(
        uint256 packTypeId,
        uint256 price,
        uint256 supply
    ) external onlyOperator {
        if (packTypes[packTypeId].exists) revert PackTypeAlreadyExists();
        if (supply == 0) revert InvalidAmount();
        packTypes[packTypeId] = PackType({
            exists: true,
            price: price,
            supply: supply,
            remaining: supply,
            active: true
        });
        emit PackTypeCreated(packTypeId, price, supply);
    }

    function replenishPackSupply(uint256 packTypeId, uint256 amount) external onlyOperator {
        PackType storage pt = packTypes[packTypeId];
        if (!pt.exists) revert PackTypeDoesNotExist();
        if (amount == 0) revert InvalidAmount();
        pt.supply += amount;
        pt.remaining += amount;
        emit PackSupplyReplenished(packTypeId, amount, pt.remaining);
    }

    function updatePackPrice(uint256 packTypeId, uint256 price) external onlyOperator {
        PackType storage pt = packTypes[packTypeId];
        if (!pt.exists) revert PackTypeDoesNotExist();
        uint256 oldPrice = pt.price;
        pt.price = price;
        emit PackPriceUpdated(packTypeId, oldPrice, price);
    }

    function setPackActive(uint256 packTypeId, bool active) external onlyOperator {
        PackType storage pt = packTypes[packTypeId];
        if (!pt.exists) revert PackTypeDoesNotExist();
        pt.active = active;
        emit PackActiveChanged(packTypeId, active);
    }

    function setProbabilityTable(
        uint256 packTypeId,
        uint256[] calldata collectibleIds,
        uint256[] calldata weights
    ) external onlyOperator {
        if (!packTypes[packTypeId].exists) revert PackTypeDoesNotExist();
        if (collectibleIds.length != weights.length) revert ArrayLengthsMismatch();
        if (collectibleIds.length == 0) revert InvalidProbabilityTable();

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < collectibleIds.length; i++) {
            if (!collectibleTypes[collectibleIds[i]].exists) revert CollectibleTypeDoesNotExist();
            if (weights[i] == 0) revert InvalidProbabilityTable();
            totalWeight += weights[i];
        }
        if (totalWeight == 0) revert InvalidProbabilityTable();

        // Clear existing table
        delete _probabilityTable[packTypeId];

        // Populate new table
        for (uint256 i = 0; i < collectibleIds.length; i++) {
            _probabilityTable[packTypeId].push(ProbabilityEntry({
                collectibleId: collectibleIds[i],
                weight: weights[i]
            }));
        }

        emit ProbabilityTableUpdated(packTypeId, collectibleIds.length);
    }

    function withdrawRevenue(uint256 amount) external onlyOperator {
        uint256 balance = paymentToken.balanceOf(address(this));
        if (amount > balance) revert InvalidAmount();
        if (!paymentToken.transfer(treasury, amount)) revert TransferFailed();
        emit RevenueWithdrawn(treasury, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        USER: PURCHASE PACKS
    //////////////////////////////////////////////////////////////*/

    function purchasePacks(uint256 packTypeId, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        PackType storage pt = packTypes[packTypeId];
        if (!pt.exists) revert PackTypeDoesNotExist();
        if (!pt.active) revert PackTypeNotActive();
        if (pt.remaining < amount) revert InsufficientSupply();

        uint256 totalPrice = pt.price * amount;
        uint256 fee = (totalPrice * FEE_BPS) / BPS_DENOMINATOR;
        uint256 toContract = totalPrice - fee;

        // Effects before interactions
        pt.remaining -= amount;
        unopenedPacks[msg.sender][packTypeId] += amount;

        // Interactions
        if (totalPrice > 0) {
            if (fee > 0) {
                if (!paymentToken.transferFrom(msg.sender, treasury, fee)) revert TransferFailed();
            }
            if (toContract > 0) {
                if (!paymentToken.transferFrom(msg.sender, address(this), toContract)) revert TransferFailed();
            }
        }

        emit PackPurchased(msg.sender, packTypeId, amount, totalPrice, fee);
    }

    /*//////////////////////////////////////////////////////////////
                         USER: OPEN PACKS
    //////////////////////////////////////////////////////////////*/

    function openPacks(uint256 packTypeId, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (unopenedPacks[msg.sender][packTypeId] < amount) revert InsufficientUnopenedPacks();

        ProbabilityEntry[] storage table = _probabilityTable[packTypeId];
        if (table.length == 0) revert InvalidProbabilityTable();

        // Effect: deduct unopened packs
        unopenedPacks[msg.sender][packTypeId] -= amount;

        uint256 totalToReveal = amount * COLLECTIBLES_PER_PACK;
        uint256[] memory revealedTokens = new uint256[](totalToReveal);

        for (uint256 p = 0; p < amount; p++) {
            for (uint256 c = 0; c < COLLECTIBLES_PER_PACK; c++) {
                uint256 collectibleId = _drawCollectible(packTypeId);
                uint256 tokenId = _mintCollectible(collectibleId);
                _addToPending(msg.sender, tokenId);
                revealedTokens[p * COLLECTIBLES_PER_PACK + c] = tokenId;
            }
        }

        emit PackOpened(msg.sender, packTypeId, amount, revealedTokens);
    }

    /*//////////////////////////////////////////////////////////////
                        USER: CLAIM COLLECTIBLES
    //////////////////////////////////////////////////////////////*/

    function claimCollectibles(uint256[] calldata tokenIds) external {
        if (tokenIds.length == 0) revert NoPendingCollectibles();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _claimSingle(tokenIds[i]);
        }
    }

    function claimAllPending() external {
        uint256[] storage pending = _pendingList[msg.sender];
        while (pending.length > 0) {
            uint256 tokenId = pending[pending.length - 1];
            _claimSingle(tokenId);
        }
    }

    function _claimSingle(uint256 tokenId) internal {
        if (pendingClaimant[tokenId] != msg.sender) revert NotPendingClaimant();
        uint256 collectibleId = tokenCollectibleId[tokenId];
        _removeFromPending(msg.sender, tokenId);
        _transfer(address(this), msg.sender, tokenId);
        emit CollectibleClaimed(msg.sender, tokenId, collectibleId);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL: RANDOMNESS
    //////////////////////////////////////////////////////////////*/

    function _drawCollectible(uint256 packTypeId) internal returns (uint256) {
        ProbabilityEntry[] storage table = _probabilityTable[packTypeId];
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < table.length; i++) {
            totalWeight += table[i].weight;
        }

        uint256 random = _randomValue(totalWeight);
        uint256 cumulative = 0;
        for (uint256 i = 0; i < table.length; i++) {
            cumulative += table[i].weight;
            if (random < cumulative) {
                return table[i].collectibleId;
            }
        }
        return table[table.length - 1].collectibleId;
    }

    function _randomValue(uint256 max) internal returns (uint256) {
        _randomNonce++;
        uint256 r = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, _randomNonce))
        );
        if (max == 0) return 0;
        return r % max;
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL: MINT COLLECTIBLE
    //////////////////////////////////////////////////////////////*/

    function _mintCollectible(uint256 collectibleId) internal returns (uint256) {
        CollectibleType storage ct = collectibleTypes[collectibleId];
        ct.minted++;

        uint256 tokenId = _nextTokenId++;
        ownerOf[tokenId] = address(this);
        balanceOf[address(this)]++;
        tokenCollectibleId[tokenId] = collectibleId;

        emit Transfer(address(0), address(this), tokenId);
        return tokenId;
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL: PENDING TRACKING
    //////////////////////////////////////////////////////////////*/

    function _addToPending(address user, uint256 tokenId) internal {
        _pendingList[user].push(tokenId);
        _pendingIndex[tokenId] = _pendingList[user].length - 1;
        pendingClaimant[tokenId] = user;
    }

    function _removeFromPending(address user, uint256 tokenId) internal {
        uint256 index = _pendingIndex[tokenId];
        uint256 lastIndex = _pendingList[user].length - 1;

        if (index != lastIndex) {
            uint256 lastTokenId = _pendingList[user][lastIndex];
            _pendingList[user][index] = lastTokenId;
            _pendingIndex[lastTokenId] = index;
        }

        _pendingList[user].pop();
        delete _pendingIndex[tokenId];
        delete pendingClaimant[tokenId];
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL: ERC-721 TRANSFER
    //////////////////////////////////////////////////////////////*/

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (ownerOf[tokenId] != from) revert NotTokenOwner();
        if (to == address(0)) revert ZeroAddress();

        delete getApproved[tokenId];
        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf[tokenId];
        if (tokenOwner == address(0)) return false;
        return tokenOwner == spender || getApproved[tokenId] == spender || isApprovedForAll[tokenOwner][spender];
    }

    /*//////////////////////////////////////////////////////////////
                          ERC-721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf[tokenId];
        if (tokenOwner == address(0)) revert TokenDoesNotExist();
        if (msg.sender != tokenOwner && !isApprovedForAll[tokenOwner][msg.sender]) revert Unauthorized();
        getApproved[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator_, bool approved) external {
        isApprovedForAll[msg.sender][operator_] = approved;
        emit ApprovalForAll(msg.sender, operator_, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert Unauthorized();
        _transfer(from, to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

    function pendingCollectiblesOf(address user) external view returns (uint256[] memory) {
        return _pendingList[user];
    }

    function pendingCount(address user) external view returns (uint256) {
        return _pendingList[user].length;
    }

    function getProbabilityTable(uint256 packTypeId)
        external
        view
        returns (uint256[] memory collectibleIds, uint256[] memory weights)
    {
        ProbabilityEntry[] storage table = _probabilityTable[packTypeId];
        uint256 len = table.length;
        collectibleIds = new uint256[](len);
        weights = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            collectibleIds[i] = table[i].collectibleId;
            weights[i] = table[i].weight;
        }
    }

    function totalWeightOf(uint256 packTypeId) public view returns (uint256) {
        ProbabilityEntry[] storage table = _probabilityTable[packTypeId];
        uint256 total = 0;
        for (uint256 i = 0; i < table.length; i++) {
            total += table[i].weight;
        }
        return total;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        if (ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked(_baseURI, _toString(tokenId)));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x80ac58cd || // ERC-721
               interfaceId == 0x01ffc9a7;   // ERC-165
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
