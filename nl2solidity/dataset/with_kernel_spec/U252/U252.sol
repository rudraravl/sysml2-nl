// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CollectibleManager
/// @notice Manages the creation and distribution of unique in-game collectible NFTs.
/// @dev Holds no custodied value; collectibles represent in-game assets only.
contract CollectibleManager {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error TokenDoesNotExist();
    error NotTokenOwner();
    error ZeroAddressRecipient();
    error MintingPaused();
    error MaxSupplyReached();
    error InsufficientFee();
    error InvalidAttributes();
    error MaxRarityExceeded();
    error TransferFailed();
    error AlreadyPaused();
    error NotPaused();
    error InvalidBaseURI();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollectibleMinted(uint256 indexed tokenId, address indexed owner, uint256 rarity, string category);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Burned(address indexed owner, address indexed tokenId);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event PausedStateChanged(bool paused);
    event BaseURISet(string baseURI);
    event FeesWithdrawn(address indexed operator, address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_SUPPLY = 100_000;
    uint256 public constant MINT_FEE = 0.01 ether;
    uint256 public constant MAX_RARITY = 100;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address private _operator;
    bool private _paused;
    string private _baseURI;
    uint256 private _totalMinted;

    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;

    struct Attributes {
        uint256 rarity;
        string category;
    }
    mapping(uint256 => Attributes) private _attributes;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != _operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert MintingPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address initialOperator, string memory initialBaseURI) {
        if (initialOperator == address(0)) revert ZeroAddressRecipient();
        _operator = initialOperator;
        _baseURI = initialBaseURI;
        _paused = false;
        _totalMinted = 0;
        emit OperatorChanged(address(0), initialOperator);
        emit BaseURISet(initialBaseURI);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddressRecipient();
        address previous = _operator;
        _operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOperator {
        if (bytes(newBaseURI).length == 0) revert InvalidBaseURI();
        _baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    function pause() external onlyOperator {
        if (_paused) revert AlreadyPaused();
        _paused = true;
        emit PausedStateChanged(true);
    }

    function unpause() external onlyOperator {
        if (!_paused) revert NotPaused();
        _paused = false;
        emit PausedStateChanged(false);
    }

    function withdrawFees(address payable recipient) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddressRecipient();
        uint256 balance = address(this).balance;
        (bool sent, ) = recipient.call{value: balance}("");
        if (!sent) revert TransferFailed();
        emit FeesWithdrawn(msg.sender, recipient, balance);
    }

    /*//////////////////////////////////////////////////////////////
                              MINT LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(uint256 rarity, string calldata category) external payable whenNotPaused returns (uint256) {
        if (msg.value != MINT_FEE) revert InsufficientFee();
        if (rarity > MAX_RARITY) revert MaxRarityExceeded();
        if (bytes(category).length == 0) revert InvalidAttributes();
        if (_totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();

        uint256 tokenId = _totalMinted + 1;
        _totalMinted = tokenId;

        address owner = msg.sender;
        _ownerOf[tokenId] = owner;
        unchecked {
            _balanceOf[owner] += 1;
        }
        _attributes[tokenId] = Attributes({rarity: rarity, category: category});

        emit CollectibleMinted(tokenId, owner, rarity, category);
        emit Transfer(address(0), owner, tokenId);
        return tokenId;
    }

    /*//////////////////////////////////////////////////////////////
                            BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    function burn(uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        if (owner != msg.sender) revert NotTokenOwner();

        unchecked {
            _balanceOf[owner] -= 1;
        }
        delete _ownerOf[tokenId];
        delete _attributes[tokenId];

        emit Burned(owner, tokenId);
        emit Transfer(owner, address(0), tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/
    function transfer(address to, uint256 tokenId) external {
        if (to == address(0)) revert ZeroAddressRecipient();
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        if (owner != msg.sender) revert NotTokenOwner();
        if (owner == to) return;

        unchecked {
            _balanceOf[owner] -= 1;
            _balanceOf[to] += 1;
        }
        _ownerOf[tokenId] = to;

        emit Transfer(owner, to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function operator() external view returns (address) {
        return _operator;
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function baseURI() external view returns (string memory) {
        return _baseURI;
    }

    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        return owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddressRecipient();
        return _balanceOf[owner];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        if (bytes(_baseURI).length == 0) return _uintToString(tokenId);
        return string(abi.encodePacked(_baseURI, _uintToString(tokenId)));
    }

    function getAttributes(uint256 tokenId) external view returns (uint256 rarity, string memory category) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        Attributes memory attr = _attributes[tokenId];
        return (attr.rarity, attr.category);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _uintToString(uint256 value) internal pure returns (string memory) {
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
