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

contract GameCharacterNFT {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NotAuthorized();
    error SpeciesNotApproved();
    error SpeciesCapExceeded(uint256 speciesId, uint256 current, uint256 cap);
    error InsufficientMintFee(uint256 required, uint256 sent);
    error NotOwnerNorApproved();
    error ZeroAddress();
    error InvalidTokenId();
    error TransferToNonERC721Receiver();
    error SelfApproval();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CharacterMinted(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 indexed speciesId,
        uint256 classId
    );
    event CharacterTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );
    event CharacterBurned(uint256 indexed tokenId, address indexed burner);
    event SpeciesApproved(uint256 indexed speciesId, bool approved);
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_PER_SPECIES = 10_000;
    uint256 public constant INITIAL_MINT_FEE = 0.05 ether;

    address public operator;
    uint256 public mintFee;

    uint256 private _nextTokenId = 1;
    uint256 public totalSupply;

    struct Character {
        uint256 speciesId;
        uint256 classId;
    }

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => Character) private _characters;
    mapping(uint256 => uint256) public speciesMintCount;
    mapping(uint256 => bool) public speciesApproved;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        operator = msg.sender;
        mintFee = INITIAL_MINT_FEE;
        emit OperatorUpdated(address(0), msg.sender);
        emit MintFeeUpdated(0, INITIAL_MINT_FEE);
    }

    /*//////////////////////////////////////////////////////////////
                           OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setMintFee(uint256 newFee) external onlyOperator {
        uint256 old = mintFee;
        mintFee = newFee;
        emit MintFeeUpdated(old, newFee);
    }

    function approveSpecies(uint256 speciesId, bool approved) external onlyOperator {
        speciesApproved[speciesId] = approved;
        emit SpeciesApproved(speciesId, approved);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                              MINT LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(uint256 speciesId, uint256 classId) external payable returns (uint256 tokenId) {
        if (!speciesApproved[speciesId]) revert SpeciesNotApproved();
        if (msg.value < mintFee) revert InsufficientMintFee(mintFee, msg.value);

        uint256 speciesCount = speciesMintCount[speciesId];
        if (speciesCount >= MAX_PER_SPECIES) {
            revert SpeciesCapExceeded(speciesId, speciesCount, MAX_PER_SPECIES);
        }

        tokenId = _nextTokenId++;
        _owners[tokenId] = msg.sender;
        _balances[msg.sender] += 1;
        _characters[tokenId] = Character({speciesId: speciesId, classId: classId});
        speciesMintCount[speciesId] = speciesCount + 1;
        totalSupply += 1;

        emit CharacterMinted(tokenId, msg.sender, speciesId, classId);
        emit CharacterTransferred(tokenId, address(0), msg.sender);
        emit Transfer(address(0), msg.sender, tokenId);

        if (msg.value > mintFee) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - mintFee}("");
            require(refunded, "Refund failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/
    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != from) revert InvalidTokenId();
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerNorApproved();

        address approved = _tokenApprovals[tokenId];
        if (approved != address(0)) {
            _tokenApprovals[tokenId] = address(0);
            emit Approval(from, address(0), tokenId);
        }

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit CharacterTransferred(tokenId, from, to);
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        _safeTransferFrom(from, to, tokenId, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        transferFrom(from, to, tokenId);
        if (to.code.length > 0) {
            (bool success, bytes memory ret) = to.call(
                abi.encodeWithSelector(
                    IERC721Receiver.onERC721Received.selector,
                    msg.sender,
                    from,
                    tokenId,
                    data
                )
            );
            if (
                !success ||
                ret.length < 4 ||
                bytes4(ret) != IERC721Receiver.onERC721Received.selector
            ) {
                revert TransferToNonERC721Receiver();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    function burn(uint256 tokenId) external {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert InvalidTokenId();
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerNorApproved();

        address approved = _tokenApprovals[tokenId];
        if (approved != address(0)) {
            _tokenApprovals[tokenId] = address(0);
            emit Approval(owner, address(0), tokenId);
        }

        _balances[owner] -= 1;
        delete _owners[tokenId];
        delete _characters[tokenId];
        totalSupply -= 1;

        emit CharacterBurned(tokenId, owner);
        emit CharacterTransferred(tokenId, owner, address(0));
        emit Transfer(owner, address(0), tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            APPROVAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function approve(address to, uint256 tokenId) external {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert InvalidTokenId();
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) {
            revert NotAuthorized();
        }
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operatorAddr, bool approved) external {
        if (operatorAddr == msg.sender) revert SelfApproval();
        _operatorApprovals[msg.sender][operatorAddr] = approved;
        emit ApprovalForAll(msg.sender, operatorAddr, approved);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert InvalidTokenId();
        return owner;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balances[account];
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (_owners[tokenId] == address(0)) revert InvalidTokenId();
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address account, address operatorAddr) public view returns (bool) {
        return _operatorApprovals[account][operatorAddr];
    }

    function getCharacter(uint256 tokenId) external view returns (uint256 speciesId, uint256 classId) {
        if (_owners[tokenId] == address(0)) revert InvalidTokenId();
        Character memory c = _characters[tokenId];
        return (c.speciesId, c.classId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = _owners[tokenId];
        return (
            owner == spender ||
            _tokenApprovals[tokenId] == spender ||
            _operatorApprovals[owner][spender]
        );
    }

    /*//////////////////////////////////////////////////////////////
                          FEE WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function withdrawFees(address payable recipient) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = address(this).balance;
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Withdraw failed");
    }
}
