// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract BackedNFT {
    error NotOwnerNorApproved();
    error AssetDoesNotExist();
    error MaxSupplyReached();
    error InsufficientBackingAmount();
    error ZeroAddress();
    error NotOperator();
    error UnsafeRecipient();
    error TransferFailed();
    error BackingNotConfigured();

    event AssetMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed backingToken,
        uint256 backingAmount,
        uint8 category,
        uint8 rarity,
        bytes32 metadata
    );
    event AssetTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event AssetBurned(uint256 indexed tokenId, address indexed owner, address indexed backingToken, uint256 backingAmount);
    event BackingRequirementUpdated(address indexed backingToken, uint256 backingAmount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MIN_MINT_AMOUNT = 100;

    address public operator;
    address public requiredBackingToken;
    uint256 public requiredBackingAmount;

    uint256 public totalSupply;
    uint256 public mintedCount;
    uint256 private _nextTokenId;

    struct Characteristics {
        uint8 category;
        uint8 rarity;
        bytes32 metadata;
    }

    struct Asset {
        address backingToken;
        uint256 backingAmount;
        Characteristics characteristics;
    }

    mapping(uint256 => Asset) internal _assets;
    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address initialOperator) {
        if (initialOperator == address(0)) revert ZeroAddress();
        operator = initialOperator;
        _nextTokenId = 1;
        emit OperatorUpdated(address(0), initialOperator);
    }

    function setBackingRequirement(address token, uint256 amount) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (amount < MIN_MINT_AMOUNT) revert InsufficientBackingAmount();
        requiredBackingToken = token;
        requiredBackingAmount = amount;
        emit BackingRequirementUpdated(token, amount);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert AssetDoesNotExist();
        return owner;
    }

    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (_owners[tokenId] == address(0)) revert AssetDoesNotExist();
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operatorAddr) public view returns (bool) {
        return _operatorApprovals[owner][operatorAddr];
    }

    function getAsset(uint256 tokenId)
        external
        view
        returns (
            address owner,
            address backingToken,
            uint256 backingAmount,
            uint8 category,
            uint8 rarity,
            bytes32 metadata
        )
    {
        if (_owners[tokenId] == address(0)) revert AssetDoesNotExist();
        Asset storage asset = _assets[tokenId];
        return (
            _owners[tokenId],
            asset.backingToken,
            asset.backingAmount,
            asset.characteristics.category,
            asset.characteristics.rarity,
            asset.characteristics.metadata
        );
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function approve(address spender, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) revert NotOwnerNorApproved();
        _tokenApprovals[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operatorAddr, bool approved) public {
        if (operatorAddr == address(0)) revert ZeroAddress();
        _operatorApprovals[msg.sender][operatorAddr] = approved;
        emit ApprovalForAll(msg.sender, operatorAddr, approved);
    }

    function transfer(address to, uint256 tokenId) external {
        _transfer(msg.sender, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) public {
        _safeTransferFrom(from, to, tokenId, data);
    }

    function mint(Characteristics calldata characteristics) external returns (uint256) {
        if (mintedCount >= MAX_SUPPLY) revert MaxSupplyReached();
        if (requiredBackingToken == address(0) || requiredBackingAmount < MIN_MINT_AMOUNT) revert BackingNotConfigured();

        address token = requiredBackingToken;
        uint256 amount = requiredBackingAmount;

        // Effects: update all state before the external call (checks-effects-interactions)
        uint256 tokenId = _nextTokenId++;
        mintedCount += 1;
        totalSupply += 1;

        _assets[tokenId] = Asset({
            backingToken: token,
            backingAmount: amount,
            characteristics: characteristics
        });

        _owners[tokenId] = msg.sender;
        _balances[msg.sender] += 1;

        // Interactions: pull backing tokens from minter
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount)
        );
        if (!success || data.length < 32 || !abi.decode(data, (bool))) revert TransferFailed();

        emit AssetMinted(
            tokenId,
            msg.sender,
            token,
            amount,
            characteristics.category,
            characteristics.rarity,
            characteristics.metadata
        );
        emit AssetTransferred(tokenId, address(0), msg.sender);

        return tokenId;
    }

    function burn(uint256 tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerNorApproved();

        address owner = _owners[tokenId];
        Asset memory asset = _assets[tokenId];

        // Effects: clear state before external call
        delete _assets[tokenId];
        delete _owners[tokenId];
        delete _tokenApprovals[tokenId];
        _balances[owner] -= 1;
        totalSupply -= 1;

        emit AssetBurned(tokenId, owner, asset.backingToken, asset.backingAmount);

        // Interactions: return backing tokens to owner
        (bool success, bytes memory data) = asset.backingToken.call(
            abi.encodeWithSelector(IERC20.transfer.selector, owner, asset.backingAmount)
        );
        if (!success || data.length < 32 || !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();

        address owner = _owners[tokenId];
        if (owner == address(0)) revert AssetDoesNotExist();
        if (owner != from) revert NotOwnerNorApproved();
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerNorApproved();

        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit AssetTransferred(tokenId, from, to);
    }

    function _safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId);
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 ret) {
                if (ret != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
            } catch {
                revert UnsafeRecipient();
            }
        }
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert AssetDoesNotExist();
        address approved = _tokenApprovals[tokenId];
        return (spender == owner || (approved != address(0) && approved == spender) || _operatorApprovals[owner][spender]);
    }
}
