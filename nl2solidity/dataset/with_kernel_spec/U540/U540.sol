// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TradingCards {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CardMinted(
        uint256 indexed tokenId,
        uint256 indexed cardTypeId,
        address indexed to,
        bytes32 artworkHash,
        uint256 timestamp
    );
    event CardTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event CardBurned(uint256 indexed tokenId, uint256 indexed cardTypeId, address indexed from);
    event MintingPaused(address indexed operator);
    event MintingUnpaused(address indexed operator);
    event CardTypeDefined(uint256 indexed cardTypeId, bytes32 artworkHash, uint256 maxSupply);
    event MaxSupplyUpdated(uint256 indexed cardTypeId, uint256 oldMaxSupply, uint256 newMaxSupply);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error Reentrancy();
    error CardTypeDoesNotExist(uint256 cardTypeId);
    error CardTypeAlreadyExists(uint256 cardTypeId);
    error MaxSupplyExceeded(uint256 cardTypeId, uint256 minted, uint256 maxSupply);
    error MaxSupplyCapExceeded(uint256 requested, uint256 cap);
    error MintingIsPaused();
    error MintingNotPaused();
    error IncorrectPayment(uint256 required, uint256 provided);
    error CardDoesNotExist(uint256 tokenId);
    error NotTokenOwner(address account, uint256 tokenId);
    error NotAuthorized();
    error ZeroAddressRecipient();
    error ZeroAddressOperator();
    error ZeroAddressTreasury();
    error CannotReduceBelowMinted(uint256 cardTypeId, uint256 minted, uint256 newMax);
    error SelfTransfer();
    error EtherTransferFailed();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_SUPPLY_PER_TYPE = 10_000;
    uint256 public constant MINT_FEE = 0.001 ether;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public operator;
    address public immutable treasury;
    bool public mintingPaused;
    uint256 private _locked = 1;

    uint256 public nextTokenId = 1;

    struct CardType {
        bytes32 artworkHash;
        uint256 maxSupply;
        uint256 mintedCount;
        bool exists;
    }

    mapping(uint256 => CardType) public cardTypes;
    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => uint256) internal _tokenCardType;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier whenNotPaused() {
        if (mintingPaused) revert MintingIsPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _operator, address _treasury) {
        if (_operator == address(0)) revert ZeroAddressOperator();
        if (_treasury == address(0)) revert ZeroAddressTreasury();
        operator = _operator;
        treasury = _treasury;
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function defineCardType(
        uint256 cardTypeId,
        bytes32 artworkHash,
        uint256 maxSupply
    ) external onlyOperator {
        if (cardTypes[cardTypeId].exists) revert CardTypeAlreadyExists(cardTypeId);
        if (maxSupply > MAX_SUPPLY_PER_TYPE) revert MaxSupplyCapExceeded(maxSupply, MAX_SUPPLY_PER_TYPE);
        cardTypes[cardTypeId] = CardType({
            artworkHash: artworkHash,
            maxSupply: maxSupply,
            mintedCount: 0,
            exists: true
        });
        emit CardTypeDefined(cardTypeId, artworkHash, maxSupply);
    }

    function setMaxSupply(uint256 cardTypeId, uint256 newMaxSupply) external onlyOperator {
        CardType storage ct = cardTypes[cardTypeId];
        if (!ct.exists) revert CardTypeDoesNotExist(cardTypeId);
        if (newMaxSupply > MAX_SUPPLY_PER_TYPE) revert MaxSupplyCapExceeded(newMaxSupply, MAX_SUPPLY_PER_TYPE);
        if (newMaxSupply < ct.mintedCount) revert CannotReduceBelowMinted(cardTypeId, ct.mintedCount, newMaxSupply);
        uint256 oldMaxSupply = ct.maxSupply;
        ct.maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(cardTypeId, oldMaxSupply, newMaxSupply);
    }

    function pauseMinting() external onlyOperator {
        if (mintingPaused) revert MintingIsPaused();
        mintingPaused = true;
        emit MintingPaused(msg.sender);
    }

    function unpauseMinting() external onlyOperator {
        if (!mintingPaused) revert MintingNotPaused();
        mintingPaused = false;
        emit MintingUnpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddressOperator();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                        MINTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(uint256 cardTypeId, address to) external payable whenNotPaused nonReentrant {
        if (msg.value != MINT_FEE) revert IncorrectPayment(MINT_FEE, msg.value);
        if (to == address(0)) revert ZeroAddressRecipient();

        CardType storage ct = cardTypes[cardTypeId];
        if (!ct.exists) revert CardTypeDoesNotExist(cardTypeId);
        if (ct.mintedCount >= ct.maxSupply) revert MaxSupplyExceeded(cardTypeId, ct.mintedCount, ct.maxSupply);

        uint256 tokenId = nextTokenId++;
        _tokenCardType[tokenId] = cardTypeId;
        _ownerOf[tokenId] = to;
        _balanceOf[to] += 1;
        ct.mintedCount += 1;

        bytes32 artworkHash = ct.artworkHash;

        (bool sent, ) = treasury.call{value: MINT_FEE}("");
        if (!sent) revert EtherTransferFailed();

        emit CardMinted(tokenId, cardTypeId, to, artworkHash, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert CardDoesNotExist(tokenId);
        if (msg.sender != owner) revert NotTokenOwner(msg.sender, tokenId);
        _transfer(msg.sender, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert CardDoesNotExist(tokenId);
        if (owner != from) revert NotTokenOwner(from, tokenId);

        bool authorized = (msg.sender == owner) ||
            (getApproved[tokenId] == msg.sender) ||
            (isApprovedForAll[owner][msg.sender]);
        if (!authorized) revert NotAuthorized();

        _transfer(from, to, tokenId);
    }

    function approve(address spender, uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert CardDoesNotExist(tokenId);
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        getApproved[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operator_, bool approved) external {
        isApprovedForAll[msg.sender][operator_] = approved;
        emit ApprovalForAll(msg.sender, operator_, approved);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddressRecipient();
        if (from == to) revert SelfTransfer();

        _balanceOf[from] -= 1;
        _balanceOf[to] += 1;
        _ownerOf[tokenId] = to;
        delete getApproved[tokenId];

        emit CardTransferred(tokenId, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                        BURN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert CardDoesNotExist(tokenId);

        bool authorized = (msg.sender == owner) ||
            (getApproved[tokenId] == msg.sender) ||
            (isApprovedForAll[owner][msg.sender]);
        if (!authorized) revert NotAuthorized();

        uint256 cardTypeId = _tokenCardType[tokenId];

        _balanceOf[owner] -= 1;
        delete _ownerOf[tokenId];
        delete getApproved[tokenId];
        delete _tokenCardType[tokenId];

        emit CardBurned(tokenId, cardTypeId, owner);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert CardDoesNotExist(tokenId);
        return owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddressRecipient();
        return _balanceOf[owner];
    }

    function cardTypeOf(uint256 tokenId) external view returns (uint256) {
        if (_ownerOf[tokenId] == address(0)) revert CardDoesNotExist(tokenId);
        return _tokenCardType[tokenId];
    }

    function artworkHashOf(uint256 tokenId) external view returns (bytes32) {
        if (_ownerOf[tokenId] == address(0)) revert CardDoesNotExist(tokenId);
        return cardTypes[_tokenCardType[tokenId]].artworkHash;
    }

    function getCardType(uint256 cardTypeId)
        external
        view
        returns (bytes32 artworkHash, uint256 maxSupply, uint256 mintedCount, bool exists)
    {
        CardType storage ct = cardTypes[cardTypeId];
        return (ct.artworkHash, ct.maxSupply, ct.mintedCount, ct.exists);
    }

    function totalMinted() external view returns (uint256) {
        return nextTokenId - 1;
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        revert("Direct Ether transfers not accepted");
    }
}
