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

contract NFTCollection {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event CollectionRoyaltyUpdated(uint256 indexed oldRoyalty, uint256 indexed newRoyalty);
    event CollectionOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotAuthorized();
    error InvalidRecipient();
    error NotMinted();
    error MaxSupplyExceeded();
    error ZeroAddress();
    error UnsafeRecipient();
    error RoyaltyOutOfBounds();

    string public name;
    string public symbol;
    uint256 public royaltyPercentage;
    uint256 public immutable maxSupply;
    uint256 public totalSupply;
    address public creator;
    address public immutable manager;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    modifier onlyManager() {
        if (msg.sender != manager) revert NotAuthorized();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _royaltyPercentage,
        uint256 _maxSupply,
        address _creator
    ) {
        if (_royaltyPercentage > 10) revert RoyaltyOutOfBounds();
        if (_maxSupply == 0 || _maxSupply > 10_000) revert MaxSupplyExceeded();
        if (_creator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        royaltyPercentage = _royaltyPercentage;
        maxSupply = _maxSupply;
        creator = _creator;
        manager = msg.sender;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165
            interfaceId == 0x80ac58cd || // ERC-721
            interfaceId == 0x5b5e139f || // ERC-721 Metadata
            interfaceId == 0x2a55205a;   // ERC-2981
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balanceOf[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert NotMinted();
        return owner;
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) revert NotAuthorized();
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (_ownerOf[tokenId] == address(0)) revert NotMinted();
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (from != _ownerOf[tokenId]) revert NotAuthorized();
        if (to == address(0)) revert InvalidRecipient();
        if (
            msg.sender != from &&
            msg.sender != _tokenApprovals[tokenId] &&
            !_operatorApprovals[from][msg.sender]
        ) revert NotAuthorized();

        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        _ownerOf[tokenId] = to;
        delete _tokenApprovals[tokenId];
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
            } catch {
                revert UnsafeRecipient();
            }
        }
    }

    function mint(address to) external onlyManager returns (uint256 tokenId) {
        if (to == address(0)) revert InvalidRecipient();
        if (totalSupply >= maxSupply) revert MaxSupplyExceeded();
        unchecked {
            tokenId = totalSupply + 1;
            totalSupply++;
            _balanceOf[to]++;
        }
        _ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function setRoyaltyPercentage(uint256 _royaltyPercentage) external onlyManager {
        if (_royaltyPercentage > 10) revert RoyaltyOutOfBounds();
        uint256 old = royaltyPercentage;
        royaltyPercentage = _royaltyPercentage;
        emit CollectionRoyaltyUpdated(old, _royaltyPercentage);
    }

    function transferOwnership(address newCreator) external onlyManager {
        if (newCreator == address(0)) revert ZeroAddress();
        address previous = creator;
        creator = newCreator;
        emit CollectionOwnershipTransferred(previous, newCreator);
    }

    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        receiver = creator;
        royaltyAmount = (salePrice * royaltyPercentage) / 100;
    }
}

contract CollectionManager {
    struct CollectionInfo {
        address creator;
        uint256 royaltyPercentage;
        uint256 maxSupply;
        bool exists;
    }

    event CollectionDeployed(
        address indexed collection,
        address indexed creator,
        uint256 royaltyPercentage,
        uint256 maxSupply
    );
    event TokenMinted(address indexed collection, address indexed to, uint256 indexed tokenId);
    event RoyaltyUpdated(address indexed collection, uint256 oldRoyalty, uint256 newRoyalty);
    event CollectionOwnershipTransferred(
        address indexed collection,
        address indexed previousCreator,
        address indexed newCreator
    );
    event MintingPausedChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error CollectionNotFound();
    error NotCreator();
    error NotOperator();
    error MintingIsPaused();
    error RoyaltyOutOfBounds();
    error MaxSupplyInvalid();
    error ZeroAddress();

    address public operator;
    bool public mintingPaused;
    uint256 public collectionCount;

    mapping(address => CollectionInfo) public collections;
    address[] public allCollections;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    function deployCollection(
        string memory name,
        string memory symbol,
        uint256 royaltyPercentage,
        uint256 maxSupply
    ) external returns (address collection) {
        if (royaltyPercentage > 10) revert RoyaltyOutOfBounds();
        if (maxSupply == 0 || maxSupply > 10_000) revert MaxSupplyInvalid();

        NFTCollection newCollection = new NFTCollection(
            name,
            symbol,
            royaltyPercentage,
            maxSupply,
            msg.sender
        );
        collection = address(newCollection);

        collections[collection] = CollectionInfo({
            creator: msg.sender,
            royaltyPercentage: royaltyPercentage,
            maxSupply: maxSupply,
            exists: true
        });
        allCollections.push(collection);
        unchecked {
            collectionCount++;
        }

        emit CollectionDeployed(collection, msg.sender, royaltyPercentage, maxSupply);
    }

    function mint(address collection, address to) external returns (uint256 tokenId) {
        CollectionInfo storage info = collections[collection];
        if (!info.exists) revert CollectionNotFound();
        if (info.creator != msg.sender) revert NotCreator();
        if (mintingPaused) revert MintingIsPaused();

        tokenId = NFTCollection(collection).mint(to);
        emit TokenMinted(collection, to, tokenId);
    }

    function transferCollectionOwnership(address collection, address newCreator) external {
        CollectionInfo storage info = collections[collection];
        if (!info.exists) revert CollectionNotFound();
        if (info.creator != msg.sender) revert NotCreator();
        if (newCreator == address(0)) revert ZeroAddress();

        address previousCreator = info.creator;
        info.creator = newCreator;
        NFTCollection(collection).transferOwnership(newCreator);
        emit CollectionOwnershipTransferred(collection, previousCreator, newCreator);
    }

    function setMintingPaused(bool paused) external onlyOperator {
        mintingPaused = paused;
        emit MintingPausedChanged(paused);
    }

    function updateRoyalty(address collection, uint256 newRoyalty) external onlyOperator {
        CollectionInfo storage info = collections[collection];
        if (!info.exists) revert CollectionNotFound();
        if (newRoyalty > 10) revert RoyaltyOutOfBounds();

        uint256 oldRoyalty = info.royaltyPercentage;
        info.royaltyPercentage = newRoyalty;
        NFTCollection(collection).setRoyaltyPercentage(newRoyalty);
        emit RoyaltyUpdated(collection, oldRoyalty, newRoyalty);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function getCollection(address collection) external view returns (CollectionInfo memory) {
        return collections[collection];
    }

    function getAllCollections() external view returns (address[] memory) {
        return allCollections;
    }

    function isCollectionCreator(address collection, address account) external view returns (bool) {
        return collections[collection].exists && collections[collection].creator == account;
    }
}
