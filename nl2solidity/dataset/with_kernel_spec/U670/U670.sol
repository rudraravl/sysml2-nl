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
    event MetadataUpdated(string newBaseURI);
    event MintingStatusChanged(bool mintable);
    event CollectionApproved(bool approved);
    event Minted(address indexed to, uint256 indexed tokenId, uint256 platformFeePaid);
    event FundsWithdrawn(address indexed to, uint256 amount);

    error NotMintable();
    error NotApproved();
    error MintExhausted();
    error InsufficientPayment();
    error FeeTransferFailed();
    error NotFactory();
    error NotCreator();
    error ZeroAddress();
    error NonexistentToken();
    error WrongFrom();
    error NotAuthorized();
    error UnsafeRecipient();
    error WithdrawFailed();

    string public name;
    string public symbol;
    string public baseTokenURI;
    uint256 public immutable maxSupply;
    uint256 public mintPrice;
    uint256 public totalSupply;
    bool public mintable;
    bool public approved;
    address public immutable factory;
    address public immutable creator;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    constructor(
        address factory_,
        address creator_,
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        uint256 mintPrice_
    ) {
        if (factory_ == address(0) || creator_ == address(0)) revert ZeroAddress();
        factory = factory_;
        creator = creator_;
        name = name_;
        symbol = symbol_;
        baseTokenURI = baseURI_;
        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
        mintable = false;
        approved = false;
    }

    function ownerOf(uint256 tokenId) external view returns (address owner) {
        owner = _ownerOf[tokenId];
        if (owner == address(0)) revert NonexistentToken();
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balanceOf[owner];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert NonexistentToken();
        return string(abi.encodePacked(baseTokenURI, _toString(tokenId)));
    }

    function approve(address spender, uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert NonexistentToken();
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        getApproved[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved_) external {
        isApprovedForAll[msg.sender][operator] = approved_;
        emit ApprovalForAll(msg.sender, operator, approved_);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (_ownerOf[tokenId] != from) revert WrongFrom();
        if (to == address(0)) revert ZeroAddress();
        if (msg.sender != from && !isApprovedForAll[from][msg.sender] && msg.sender != getApproved[tokenId]) {
            revert NotAuthorized();
        }
        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        delete getApproved[tokenId];
        _ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0) {
            if (
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "") !=
                IERC721Receiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0) {
            if (
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) !=
                IERC721Receiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    function mint() external payable {
        if (!approved) revert NotApproved();
        if (!mintable) revert NotMintable();
        if (totalSupply >= maxSupply) revert MintExhausted();
        if (msg.value < mintPrice) revert InsufficientPayment();

        NFTCollectionFactory f = NFTCollectionFactory(factory);
        uint256 fee = (msg.value * f.platformFeeBps()) / 10_000;
        if (fee > 0) {
            address treasury = f.feeRecipient();
            (bool ok, ) = treasury.call{value: fee}("");
            if (!ok) revert FeeTransferFailed();
        }

        uint256 tokenId = ++totalSupply;
        _balanceOf[msg.sender]++;
        _ownerOf[tokenId] = msg.sender;
        emit Transfer(address(0), msg.sender, tokenId);
        emit Minted(msg.sender, tokenId, fee);
    }

    function withdrawFunds() external {
        if (msg.sender != creator) revert NotCreator();
        uint256 amount = address(this).balance;
        if (amount > 0) {
            (bool ok, ) = creator.call{value: amount}("");
            if (!ok) revert WithdrawFailed();
        }
        emit FundsWithdrawn(creator, amount);
    }

    function setBaseURI(string calldata newBaseURI) external onlyFactory {
        baseTokenURI = newBaseURI;
        emit MetadataUpdated(newBaseURI);
    }

    function setMintingStatus(bool status) external onlyFactory {
        mintable = status;
        emit MintingStatusChanged(status);
    }

    function setApproved(bool status) external onlyFactory {
        approved = status;
        emit CollectionApproved(status);
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
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

contract NFTCollectionFactory {
    uint256 public constant MAX_PLATFORM_FEE_BPS = 1_000; // 10%
    uint256 public constant MAX_MONTHLY_DEPLOYMENTS = 5;
    uint256 public constant MONTH_SECONDS = 30 days;

    enum ApprovalStatus { Pending, Approved, Rejected }

    struct CollectionInfo {
        address collection;
        address creator;
        uint64 deployedAt;
        uint256 maxSupply;
        uint256 mintPrice;
        bool mintable;
        ApprovalStatus approvalStatus;
    }

    event CollectionDeployed(
        address indexed collection,
        address indexed creator,
        string name,
        string symbol,
        uint256 maxSupply,
        uint256 mintPrice
    );
    event CollectionApprovalChanged(address indexed collection, ApprovalStatus status);
    event MintingStatusChanged(address indexed collection, address indexed creator, bool mintable);
    event CollectionMetadataUpdated(address indexed collection, address indexed creator, string newBaseURI);
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error ZeroAddress();
    error FeeTooHigh(uint256 requested, uint256 maximum);
    error MonthlyDeploymentLimitReached(address creator, uint256 month, uint256 limit);
    error InvalidMaxSupply();
    error NotCollection();
    error NotCollectionCreator(address caller, address expectedCreator);
    error OperatorAlreadySet();
    error CollectionNotPending(address collection, ApprovalStatus currentStatus);

    address public operator;
    address public feeRecipient;
    uint256 public platformFeeBps;

    address[] private _allCollections;
    mapping(address => CollectionInfo) public collectionInfo;
    mapping(address => bool) public isCollection;
    mapping(address => mapping(uint256 => uint256)) public monthlyDeployments;
    mapping(address => address[]) private _creatorCollections;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address feeRecipient_) {
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        operator = msg.sender;
        feeRecipient = feeRecipient_;
        platformFeeBps = 0;
    }

    function setPlatformFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_PLATFORM_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_PLATFORM_FEE_BPS);
        uint256 oldFeeBps = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(oldFeeBps, newFeeBps);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(oldRecipient, newFeeRecipient);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        if (newOperator == operator) revert OperatorAlreadySet();
        emit OperatorTransferred(operator, newOperator);
        operator = newOperator;
    }

    function deployCollection(
        string calldata name,
        string calldata symbol,
        string calldata baseURI,
        uint256 maxSupply,
        uint256 mintPrice
    ) external returns (address collection) {
        if (maxSupply == 0) revert InvalidMaxSupply();

        uint256 month = currentMonth();
        if (monthlyDeployments[msg.sender][month] >= MAX_MONTHLY_DEPLOYMENTS) {
            revert MonthlyDeploymentLimitReached(msg.sender, month, MAX_MONTHLY_DEPLOYMENTS);
        }

        NFTCollection newCollection = new NFTCollection(
            address(this),
            msg.sender,
            name,
            symbol,
            baseURI,
            maxSupply,
            mintPrice
        );
        collection = address(newCollection);

        monthlyDeployments[msg.sender][month]++;
        _allCollections.push(collection);
        _creatorCollections[msg.sender].push(collection);
        isCollection[collection] = true;
        collectionInfo[collection] = CollectionInfo({
            collection: collection,
            creator: msg.sender,
            deployedAt: uint64(block.timestamp),
            maxSupply: maxSupply,
            mintPrice: mintPrice,
            mintable: false,
            approvalStatus: ApprovalStatus.Pending
        });

        emit CollectionDeployed(collection, msg.sender, name, symbol, maxSupply, mintPrice);
    }

    function approveCollection(address collection) external onlyOperator {
        CollectionInfo storage info = _getValidCollection(collection);
        if (info.approvalStatus != ApprovalStatus.Pending) {
            revert CollectionNotPending(collection, info.approvalStatus);
        }
        info.approvalStatus = ApprovalStatus.Approved;
        NFTCollection(collection).setApproved(true);
        emit CollectionApprovalChanged(collection, ApprovalStatus.Approved);
    }

    function rejectCollection(address collection) external onlyOperator {
        CollectionInfo storage info = _getValidCollection(collection);
        if (info.approvalStatus != ApprovalStatus.Pending) {
            revert CollectionNotPending(collection, info.approvalStatus);
        }
        info.approvalStatus = ApprovalStatus.Rejected;
        NFTCollection(collection).setApproved(false);
        emit CollectionApprovalChanged(collection, ApprovalStatus.Rejected);
    }

    function updateCollectionMetadata(address collection, string calldata newBaseURI) external {
        CollectionInfo storage info = _getValidCollection(collection);
        if (info.creator != msg.sender) revert NotCollectionCreator(msg.sender, info.creator);
        NFTCollection(collection).setBaseURI(newBaseURI);
        emit CollectionMetadataUpdated(collection, msg.sender, newBaseURI);
    }

    function setCollectionMintingStatus(address collection, bool status) external {
        CollectionInfo storage info = _getValidCollection(collection);
        if (info.creator != msg.sender) revert NotCollectionCreator(msg.sender, info.creator);
        NFTCollection(collection).setMintingStatus(status);
        info.mintable = status;
        emit MintingStatusChanged(collection, msg.sender, status);
    }

    function totalCollections() external view returns (uint256) {
        return _allCollections.length;
    }

    function getAllCollections() external view returns (address[] memory) {
        return _allCollections;
    }

    function getCollectionsByCreator(address creator) external view returns (address[] memory) {
        return _creatorCollections[creator];
    }

    function getMonthlyDeploymentCount(address creator, uint256 month) external view returns (uint256) {
        return monthlyDeployments[creator][month];
    }

    function currentMonth() public view returns (uint256) {
        return block.timestamp / MONTH_SECONDS;
    }

    function _getValidCollection(address collection) internal view returns (CollectionInfo storage info) {
        if (!isCollection[collection]) revert NotCollection();
        info = collectionInfo[collection];
    }
}
