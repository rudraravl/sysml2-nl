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

/// @title GenerativeArtCollectible
/// @notice Manages unique digital collectibles representing generative AI art pieces.
///         Only a designated operator may mint, up to a fixed maximum supply of 10,000.
///         Each mint requires a 0.01 ether fee that is forwarded to the contract owner.
contract GenerativeArtCollectible {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error TokenDoesNotExist();
    error MaxSupplyReached();
    error InsufficientMintFee();
    error NotApprovedOrOwner();
    error TransferToZeroAddress();
    error SelfApproval();
    error FeeTransferFailed();
    error NonReceiverContract();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Minted(address indexed to, uint256 indexed tokenId, string metadataURI);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BaseURIUpdated(string newBaseURI);

    /*//////////////////////////////////////////////////////////////
                             STORAGE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MINT_FEE = 0.01 ether;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;
    string private _baseURI;

    address public owner;
    address public operator;
    uint256 public totalSupply;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _tokenURIs;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address initialOperator
    ) {
        if (initialOperator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = initialOperator;
        name = name_;
        symbol = symbol_;
        _baseURI = baseURI_;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), initialOperator);
        emit BaseURIUpdated(baseURI_);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /*//////////////////////////////////////////////////////////////
                              MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints a new collectible to `to` with off-chain `metadataURI`.
    /// @dev    Caller must be the designated operator and must send exactly MINT_FEE.
    function mint(address to, string calldata metadataURI) external payable onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (totalSupply >= MAX_SUPPLY) revert MaxSupplyReached();
        if (msg.value != MINT_FEE) revert InsufficientMintFee();

        uint256 tokenId = totalSupply + 1;
        totalSupply = tokenId;

        _balances[to] += 1;
        _owners[tokenId] = to;
        _tokenURIs[tokenId] = metadataURI;

        emit Transfer(address(0), to, tokenId);
        emit Minted(to, tokenId, metadataURI);

        (bool ok, ) = owner.call{value: MINT_FEE}("");
        if (!ok) revert FeeTransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId, msg.sender);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _safeTransfer(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        _safeTransfer(from, to, tokenId, data);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId, msg.sender);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _transfer(address from, address to, uint256 tokenId, address spender) internal {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        address tokenOwner = _owners[tokenId];
        if (from != tokenOwner) revert NotOwner();
        if (to == address(0)) revert TransferToZeroAddress();
        if (!_isAuthorized(spender, tokenOwner, tokenId)) revert NotApprovedOrOwner();

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        if (_tokenApprovals[tokenId] != address(0)) {
            _tokenApprovals[tokenId] = address(0);
            emit Approval(tokenOwner, address(0), tokenId);
        }

        emit Transfer(from, to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            APPROVAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address to, uint256 tokenId) external {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        address tokenOwner = _owners[tokenId];
        if (to == tokenOwner) revert SelfApproval();
        if (msg.sender != tokenOwner && !_operatorApprovals[tokenOwner][msg.sender]) {
            revert Unauthorized();
        }
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address to, bool approved) external {
        if (to == msg.sender) revert SelfApproval();
        _operatorApprovals[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        if (tokenOwner == address(0)) revert TokenDoesNotExist();
        return tokenOwner;
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address account, address spender) public view returns (bool) {
        return _operatorApprovals[account][spender];
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        string memory uri = _tokenURIs[tokenId];
        if (bytes(uri).length > 0) return uri;
        if (bytes(_baseURI).length > 0) {
            return string(abi.encodePacked(_baseURI, _toString(tokenId)));
        }
        return "";
    }

    function currentSupply() public view returns (uint256) {
        return totalSupply;
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= totalSupply;
    }

    function _isAuthorized(address spender, address tokenOwner, uint256 tokenId) internal view returns (bool) {
        return (spender == tokenOwner
            || _tokenApprovals[tokenId] == spender
            || _operatorApprovals[tokenOwner][spender]);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) revert NonReceiverContract();
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert NonReceiverContract();
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
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

    /*//////////////////////////////////////////////////////////////
                              RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        revert Unauthorized();
    }
}
