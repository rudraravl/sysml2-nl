// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GameItemAssets {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error NotOwnerNorApproved();
    error NotMinter();
    error NotContractOwner();
    error AssetDoesNotExist();
    error ZeroAddress();
    error MintLimitReached();
    error AssetAlreadyExists();
    error TransferToZeroAddress();
    error WrongFromOwner();
    error UnsafeRecipient();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event MinterAssigned(address indexed account);
    event MinterRevoked(address indexed account);
    event ContractOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_SUPPLY = 10_000;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    address public contractOwner;
    uint256 public totalAssetsMinted;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => string) internal _tokenURIs;
    mapping(address => bool) public isMinter;

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyContractOwner() {
        if (msg.sender != contractOwner) revert NotContractOwner();
        _;
    }

    modifier onlyMinter() {
        if (!isMinter[msg.sender]) revert NotMinter();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        contractOwner = initialOwner;
        emit ContractOwnershipTransferred(address(0), initialOwner);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL LOGIC
    //////////////////////////////////////////////////////////////*/
    function transferContractOwnership(address newOwner) external onlyContractOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = contractOwner;
        contractOwner = newOwner;
        emit ContractOwnershipTransferred(previous, newOwner);
    }

    function assignMinter(address account) external onlyContractOwner {
        if (account == address(0)) revert ZeroAddress();
        isMinter[account] = true;
        emit MinterAssigned(account);
    }

    function revokeMinter(address account) external onlyContractOwner {
        if (!isMinter[account]) revert NotMinter();
        isMinter[account] = false;
        emit MinterRevoked(account);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC721-LIKE LOGIC
    //////////////////////////////////////////////////////////////*/
    function ownerOf(uint256 id) public view returns (address) {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert AssetDoesNotExist();
        return owner;
    }

    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balanceOf[owner];
    }

    function tokenURI(uint256 id) public view returns (string memory) {
        if (_ownerOf[id] == address(0)) revert AssetDoesNotExist();
        return _tokenURIs[id];
    }

    function approve(address spender, uint256 id) public {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert AssetDoesNotExist();
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotOwnerNorApproved();
        getApproved[id] = spender;
        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public {
        if (operator == address(0)) revert ZeroAddress();
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 id) public {
        if (_ownerOf[id] != from) revert WrongFromOwner();
        if (to == address(0)) revert TransferToZeroAddress();
        if (
            msg.sender != from &&
            msg.sender != getApproved[id] &&
            !isApprovedForAll[from][msg.sender]
        ) revert NotAuthorized();

        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;
        delete getApproved[id];
        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) external {
        transferFrom(from, to, id);
        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") !=
                ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) external {
        transferFrom(from, to, id);
        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) !=
                ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    /*//////////////////////////////////////////////////////////////
                              MINT LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(address to, string calldata uri_) external onlyMinter returns (uint256 id) {
        if (to == address(0)) revert ZeroAddress();
        if (totalAssetsMinted >= MAX_SUPPLY) revert MintLimitReached();

        id = totalAssetsMinted + 1;
        if (_ownerOf[id] != address(0)) revert AssetAlreadyExists();

        totalAssetsMinted = id;
        _ownerOf[id] = to;
        _tokenURIs[id] = uri_;

        unchecked {
            _balanceOf[to]++;
        }

        emit Transfer(address(0), to, id);
    }

    /*//////////////////////////////////////////////////////////////
                              BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    function burn(uint256 id) external {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert AssetDoesNotExist();
        if (
            msg.sender != owner &&
            msg.sender != getApproved[id] &&
            !isApprovedForAll[owner][msg.sender]
        ) revert NotAuthorized();

        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];
        delete getApproved[id];
        delete _tokenURIs[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC165 INTROSPECTION
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f;   // ERC721Metadata
    }
}

/*//////////////////////////////////////////////////////////////
                    ERC721 RECEIVER INTERFACE
//////////////////////////////////////////////////////////////*/
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4);
}
