// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract GamePieceManager {
    // ==================== Constants ====================
    uint256 public constant MAX_PIECE_TYPES = 10_000;
    uint256 public constant MIN_MATCH_PIECES = 2;
    uint256 public constant MAX_UPGRADE_LEVEL = 10;
    uint256 public constant MAX_ATTRIBUTE = 1_000_000;
    uint256 private constant UPGRADE_FACTOR = 10;

    // ==================== Custom Errors ====================
    error NotOperator();
    error ZeroAddress();
    error MaxPieceTypesReached();
    error PieceTypeDoesNotExist();
    error InvalidPieceAttributes();
    error InvalidPieceId();
    error NotTokenOwner();
    error NotAuthorized();
    error InsufficientMatchPieces();
    error DuplicatePieceInMatch();
    error MaxUpgradeLevelReached();
    error MatchDoesNotExist();
    error TransferToZeroAddress();
    error TransferFromIncorrectOwner();
    error InvalidRecipient();

    // ==================== Structs ====================
    struct PieceType {
        uint256 id;
        string name;
        uint256 baseHealth;
        uint256 baseAttack;
        uint256 baseDefense;
        bool exists;
    }

    struct PieceState {
        uint256 typeId;
        uint256 health;
        uint256 attack;
        uint256 defense;
        uint256 upgradeLevel;
    }

    struct MatchResult {
        uint256 id;
        address initiator;
        uint256[] pieceIds;
        uint256 timestamp;
    }

    // ==================== ERC721 State ====================
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // ==================== ERC721Enumerable State ====================
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;
    mapping(uint256 => uint256) private _allTokens;
    mapping(uint256 => uint256) private _allTokensIndex;
    uint256 private _totalTokens;

    // ==================== Game State ====================
    string public name;
    string public symbol;
    address public operator;
    uint256 public pieceTypeCount;
    uint256 public matchCount;
    uint256 private _nextTokenId;

    mapping(uint256 => PieceType) public pieceTypes;
    mapping(uint256 => PieceState) public pieceStates;
    mapping(uint256 => MatchResult) private _matches;

    // ==================== Events ====================
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event PieceTypeRegistered(uint256 indexed typeId, string name, uint256 baseHealth, uint256 baseAttack, uint256 baseDefense);
    event PieceTypeAttributesUpdated(uint256 indexed typeId, uint256 baseHealth, uint256 baseAttack, uint256 baseDefense);
    event PieceMinted(uint256 indexed tokenId, uint256 indexed typeId, address indexed owner);
    event PieceUpgraded(uint256 indexed tokenId, uint256 upgradeLevel, uint256 health, uint256 attack, uint256 defense);
    event PieceBurned(uint256 indexed tokenId, address indexed owner, uint256 indexed typeId);
    event MatchInitiated(uint256 indexed matchId, address indexed initiator, uint256[] pieceIds);

    // ==================== Modifiers ====================
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyExistingPieceType(uint256 typeId) {
        if (!pieceTypes[typeId].exists) revert PieceTypeDoesNotExist();
        _;
    }

    // ==================== Constructor ====================
    constructor(string memory _name, string memory _symbol, address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    // ==================== Operator Functions ====================

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function registerPieceType(
        string calldata _name,
        uint256 baseHealth,
        uint256 baseAttack,
        uint256 baseDefense
    ) external onlyOperator returns (uint256 typeId) {
        if (pieceTypeCount >= MAX_PIECE_TYPES) revert MaxPieceTypesReached();
        if (
            bytes(_name).length == 0 ||
            baseHealth == 0 || baseHealth > MAX_ATTRIBUTE ||
            baseAttack == 0 || baseAttack > MAX_ATTRIBUTE ||
            baseDefense == 0 || baseDefense > MAX_ATTRIBUTE
        ) revert InvalidPieceAttributes();

        typeId = pieceTypeCount++;
        pieceTypes[typeId] = PieceType({
            id: typeId,
            name: _name,
            baseHealth: baseHealth,
            baseAttack: baseAttack,
            baseDefense: baseDefense,
            exists: true
        });

        emit PieceTypeRegistered(typeId, _name, baseHealth, baseAttack, baseDefense);
    }

    function setPieceTypeAttributes(
        uint256 typeId,
        uint256 baseHealth,
        uint256 baseAttack,
        uint256 baseDefense
    ) external onlyOperator onlyExistingPieceType(typeId) {
        if (
            baseHealth == 0 || baseHealth > MAX_ATTRIBUTE ||
            baseAttack == 0 || baseAttack > MAX_ATTRIBUTE ||
            baseDefense == 0 || baseDefense > MAX_ATTRIBUTE
        ) revert InvalidPieceAttributes();

        PieceType storage pt = pieceTypes[typeId];
        pt.baseHealth = baseHealth;
        pt.baseAttack = baseAttack;
        pt.baseDefense = baseDefense;

        emit PieceTypeAttributesUpdated(typeId, baseHealth, baseAttack, baseDefense);
    }

    // ==================== Player Functions ====================

    function registerGamePiece(uint256 typeId) external onlyExistingPieceType(typeId) returns (uint256 tokenId) {
        PieceType storage pt = pieceTypes[typeId];

        tokenId = _nextTokenId++;
        pieceStates[tokenId] = PieceState({
            typeId: typeId,
            health: pt.baseHealth,
            attack: pt.baseAttack,
            defense: pt.baseDefense,
            upgradeLevel: 0
        });

        _mint(msg.sender, tokenId);
        emit PieceMinted(tokenId, typeId, msg.sender);
    }

    function upgradeGamePiece(uint256 tokenId) external {
        if (!_exists(tokenId)) revert InvalidPieceId();
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();

        PieceState storage state = pieceStates[tokenId];
        if (state.upgradeLevel >= MAX_UPGRADE_LEVEL) revert MaxUpgradeLevelReached();

        PieceType storage pt = pieceTypes[state.typeId];
        state.upgradeLevel += 1;
        state.health += (pt.baseHealth * UPGRADE_FACTOR) / 100;
        state.attack += (pt.baseAttack * UPGRADE_FACTOR) / 100;
        state.defense += (pt.baseDefense * UPGRADE_FACTOR) / 100;

        emit PieceUpgraded(tokenId, state.upgradeLevel, state.health, state.attack, state.defense);
    }

    function initiateMatch(uint256[] calldata tokenIds) external returns (uint256 matchId) {
        uint256 length = tokenIds.length;
        if (length < MIN_MATCH_PIECES) revert InsufficientMatchPieces();

        for (uint256 i = 0; i < length; i++) {
            if (!_exists(tokenIds[i])) revert InvalidPieceId();
            if (ownerOf(tokenIds[i]) != msg.sender) revert NotTokenOwner();
            for (uint256 j = i + 1; j < length; j++) {
                if (tokenIds[i] == tokenIds[j]) revert DuplicatePieceInMatch();
            }
        }

        uint256[] memory pieceIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            address owner = ownerOf(tokenId);
            uint256 typeId = pieceStates[tokenId].typeId;

            _burn(tokenId);
            delete pieceStates[tokenId];

            pieceIds[i] = tokenId;
            emit PieceBurned(tokenId, owner, typeId);
        }

        matchId = matchCount++;
        _matches[matchId] = MatchResult({
            id: matchId,
            initiator: msg.sender,
            pieceIds: pieceIds,
            timestamp: block.timestamp
        });

        emit MatchInitiated(matchId, msg.sender, pieceIds);
    }

    // ==================== View Functions ====================

    function getPlayerPieces(address player) external view returns (uint256[] memory) {
        uint256 count = balanceOf(player);
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(player, i);
        }
        return ids;
    }

    function getPieceState(uint256 tokenId)
        external
        view
        returns (uint256 typeId, uint256 health, uint256 attack, uint256 defense, uint256 upgradeLevel)
    {
        if (!_exists(tokenId)) revert InvalidPieceId();
        PieceState storage state = pieceStates[tokenId];
        return (state.typeId, state.health, state.attack, state.defense, state.upgradeLevel);
    }

    function getPieceType(uint256 typeId)
        external
        view
        onlyExistingPieceType(typeId)
        returns (string memory _name, uint256 baseHealth, uint256 baseAttack, uint256 baseDefense)
    {
        PieceType storage pt = pieceTypes[typeId];
        return (pt.name, pt.baseHealth, pt.baseAttack, pt.baseDefense);
    }

    function getMatch(uint256 matchId) external view returns (MatchResult memory) {
        if (matchId >= matchCount) revert MatchDoesNotExist();
        return _matches[matchId];
    }

    function totalPieceTypes() external view returns (uint256) {
        return pieceTypeCount;
    }

    function totalPieces() external view returns (uint256) {
        return _totalTokens;
    }

    function totalMatches() external view returns (uint256) {
        return matchCount;
    }

    // ==================== ERC721 Public Functions ====================

    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert InvalidPieceId();
        return owner;
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotAuthorized();
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (!_exists(tokenId)) revert InvalidPieceId();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operatorAddr, bool approved) external {
        _operatorApprovals[msg.sender][operatorAddr] = approved;
        emit ApprovalForAll(msg.sender, operatorAddr, approved);
    }

    function isApprovedForAll(address owner, address operatorAddr) public view returns (bool) {
        return _operatorApprovals[owner][operatorAddr];
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        _transfer(from, to, tokenId);
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) revert InvalidRecipient();
            } catch {
                revert InvalidRecipient();
            }
        }
    }

    // ==================== ERC721Enumerable Public Functions ====================

    function totalSupply() public view returns (uint256) {
        return _totalTokens;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        if (index >= _balances[owner]) revert InvalidPieceId();
        return _ownedTokens[owner][index];
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        if (index >= _totalTokens) revert InvalidPieceId();
        return _allTokens[index];
    }

    // ==================== Internal ERC721 Helpers ====================

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert TransferToZeroAddress();
        if (_exists(tokenId)) revert InvalidPieceId();

        _addTokenToOwnerEnumeration(to, tokenId);
        _addTokenToAllTokensEnumeration(tokenId);

        _owners[tokenId] = to;
        _balances[to] += 1;
        _totalTokens += 1;

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert InvalidPieceId();

        delete _tokenApprovals[tokenId];

        _removeTokenFromOwnerEnumeration(owner, tokenId);
        _removeTokenFromAllTokensEnumeration(tokenId);

        _balances[owner] -= 1;
        _totalTokens -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert TransferToZeroAddress();

        address owner = _owners[tokenId];
        if (owner != from) revert TransferFromIncorrectOwner();

        bool isAuthorized = (msg.sender == owner) ||
            isApprovedForAll(owner, msg.sender) ||
            _tokenApprovals[tokenId] == msg.sender;
        if (!isAuthorized) revert NotAuthorized();

        delete _tokenApprovals[tokenId];

        if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
            _addTokenToOwnerEnumeration(to, tokenId);
            _balances[from] -= 1;
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    // ==================== Enumeration Helpers ====================

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = _balances[to];
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastIndex = _balances[from] - 1;
        uint256 currentIndex = _ownedTokensIndex[tokenId];

        if (currentIndex != lastIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastIndex];
            _ownedTokens[from][currentIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = currentIndex;
        }

        delete _ownedTokens[from][lastIndex];
        delete _ownedTokensIndex[tokenId];
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _totalTokens;
        _allTokens[_totalTokens] = tokenId;
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        uint256 lastIndex = _totalTokens - 1;
        uint256 currentIndex = _allTokensIndex[tokenId];

        if (currentIndex != lastIndex) {
            uint256 lastTokenId = _allTokens[lastIndex];
            _allTokens[currentIndex] = lastTokenId;
            _allTokensIndex[lastTokenId] = currentIndex;
        }

        delete _allTokens[lastIndex];
        delete _allTokensIndex[tokenId];
    }
}
