// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// @title StakedEtherNFT
/// @notice Each NFT represents a share of staked Ether that is custodied by the contract.
///         Holders may transfer their NFTs or burn them to redeem the underlying Ether.
contract StakedEtherNFT {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Staked(address indexed owner, uint256 indexed id, uint256 amount);
    event Redeemed(address indexed owner, uint256 indexed id, uint256 amount);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error NotMinted();
    error NotAuthorized();
    error InvalidRecipient();
    error InsufficientStake(uint256 provided, uint256 minimum);
    error EnforcedPause();
    error ExpectedPause();
    error UnsafeRecipient();
    error NotOperator();
    error EthTransferFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Minimum amount of staked Ether required to mint a new NFT.
    uint256 public constant MINIMUM_STAKE = 0.1 ether;

    /*//////////////////////////////////////////////////////////////
                              METADATA
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;

    /*//////////////////////////////////////////////////////////////
                          ERC721 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    uint256 internal _nextTokenId;

    /*//////////////////////////////////////////////////////////////
                          STAKING STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @dev Amount of staked Ether represented by each NFT.
    mapping(uint256 => uint256) internal _stakedAmount;
    /// @dev Total amount of staked Ether custodied by the contract.
    uint256 public totalStakedEther;
    /// @dev Whether minting and redemption are globally paused.
    bool public paused;
    /// @dev Designated operator capable of pausing and unpausing operations.
    address public operator;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(string memory _name, string memory _symbol, address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        name = _name;
        symbol = _symbol;
        operator = _operator;
        emit OperatorUpdated(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/
    function ownerOf(uint256 id) public view returns (address owner) {
        owner = _ownerOf[id];
        if (owner == address(0)) revert NotMinted();
    }

    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balanceOf[owner];
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }

    function getStakedAmount(uint256 id) public view returns (uint256) {
        if (_ownerOf[id] == address(0)) revert NotMinted();
        return _stakedAmount[id];
    }

    function approve(address spender, uint256 id) public {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert NotMinted();
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        getApproved[id] = spender;
        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator_, bool approved) public {
        isApprovedForAll[msg.sender][operator_] = approved;
        emit ApprovalForAll(msg.sender, operator_, approved);
    }

    function transferFrom(address from, address to, uint256 id) public {
        _transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) public {
        _safeTransfer(from, to, id, "");
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public {
        _safeTransfer(from, to, id, data);
    }

    function _safeTransfer(address from, address to, uint256 id, bytes memory data) internal {
        _transfer(from, to, id);
        if (to.code.length != 0) {
            if (
                IERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data)
                    != IERC721TokenReceiver.onERC721Received.selector
            ) {
                revert UnsafeRecipient();
            }
        }
    }

    function _transfer(address from, address to, uint256 id) internal {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert NotMinted();
        if (owner != from) revert NotMinted();
        if (to == address(0)) revert InvalidRecipient();
        if (!_isApprovedOrOwner(msg.sender, id)) revert NotAuthorized();

        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        _ownerOf[id] = to;
        delete getApproved[id];
        emit Transfer(from, to, id);
    }

    function _isApprovedOrOwner(address spender, uint256 id) internal view returns (bool) {
        address owner = _ownerOf[id];
        return spender == owner || isApprovedForAll[owner][spender] || getApproved[id] == spender;
    }

    /*//////////////////////////////////////////////////////////////
                            MINTING / BURNING
    //////////////////////////////////////////////////////////////*/
    /// @notice Mints a new NFT representing the staked Ether sent with the call.
    /// @param to Recipient of the newly minted NFT.
    /// @return id The identifier of the minted NFT.
    function mint(address to) public payable whenNotPaused returns (uint256 id) {
        if (to == address(0)) revert ZeroAddress();
        if (msg.value < MINIMUM_STAKE) revert InsufficientStake(msg.value, MINIMUM_STAKE);

        id = _nextTokenId++;
        _ownerOf[id] = to;
        unchecked {
            _balanceOf[to]++;
        }
        _stakedAmount[id] = msg.value;
        totalStakedEther += msg.value;

        emit Transfer(address(0), to, id);
        emit Staked(to, id, msg.value);
    }

    /// @notice Burns an NFT and returns the staked Ether it represents to its owner.
    /// @param id The identifier of the NFT to redeem.
    function burn(uint256 id) public whenNotPaused {
        address owner = _ownerOf[id];
        if (owner == address(0)) revert NotMinted();
        if (!_isApprovedOrOwner(msg.sender, id)) revert NotAuthorized();

        uint256 amount = _stakedAmount[id];

        unchecked {
            _balanceOf[owner]--;
        }
        delete _ownerOf[id];
        delete _stakedAmount[id];
        delete getApproved[id];
        totalStakedEther -= amount;

        emit Transfer(owner, address(0), id);
        emit Redeemed(owner, id, amount);

        (bool success, ) = payable(owner).call{value: amount}("");
        if (!success) revert EthTransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Pauses minting and redemption operations. Only callable by the operator.
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpauses minting and redemption operations. Only callable by the operator.
    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Transfers operator rights to a new address.
    /// @param newOperator The address to designate as the new operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f;   // ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/
    receive() external payable {
        // Direct Ether transfers are not treated as mints; reject them.
        revert();
    }
}
