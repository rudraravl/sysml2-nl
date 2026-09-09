// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract CollectibleEscrow {
    ////////////////////////////////////////////////////////////////
    //                           ERRORS                            //
    ////////////////////////////////////////////////////////////////
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error CollectionNotRegistered();
    error CollectionAlreadyRegistered();
    error AlreadyDeposited();
    error NotDeposited();
    error NotDepositor();
    error InsufficientFee();
    error NoActiveWithdrawal();
    error TimelockNotPassed();
    error TransferPending();
    error InvalidRecipient();
    error TransferFailed();

    ////////////////////////////////////////////////////////////////
    //                           EVENTS                            //
    ////////////////////////////////////////////////////////////////
    event Deposited(address indexed collection, uint256 indexed tokenId, address indexed depositor);
    event Withdrawn(address indexed collection, uint256 indexed tokenId, address indexed withdrawer);
    event Transferred(address indexed collection, uint256 indexed tokenId, address from, address indexed to);
    event CollectionRegistered(address indexed collection, string name, string metadataURI);
    event CollectionMetadataUpdated(address indexed collection, string name, string metadataURI);
    event DepositFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorStatusChanged(address indexed operator, bool status);
    event WithdrawalRequested(address indexed collection, uint256 indexed tokenId, address indexed requester, uint256 unlockTime);
    event WithdrawalCancelled(address indexed collection, uint256 indexed tokenId, address indexed canceller);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    ////////////////////////////////////////////////////////////////
    //                          STRUCTS                            //
    ////////////////////////////////////////////////////////////////
    struct Collection {
        bool registered;
        string name;
        string metadataURI;
    }

    struct PendingWithdrawal {
        bool active;
        uint256 unlockTime;
    }

    ////////////////////////////////////////////////////////////////
    //                         STATE VARIABLES                     //
    ////////////////////////////////////////////////////////////////
    address public owner;
    uint256 public depositFee;
    uint256 public collectedFees;
    uint256 public constant WITHDRAWAL_TIMELOCK = 24 hours;

    mapping(address => bool) public operators;
    mapping(address => Collection) public collections;
    mapping(address => mapping(uint256 => address)) public depositOwner;
    mapping(address => mapping(uint256 => bool)) public isDeposited;
    mapping(address => mapping(uint256 => PendingWithdrawal)) public pendingWithdrawals;
    mapping(address => uint256) public userDepositCount;

    ////////////////////////////////////////////////////////////////
    //                         MODIFIERS                           //
    ////////////////////////////////////////////////////////////////
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                        CONSTRUCTOR                          //
    ////////////////////////////////////////////////////////////////
    constructor() {
        owner = msg.sender;
        depositFee = 0.01 ether;
        emit OwnershipTransferred(address(0), msg.sender);
        emit DepositFeeUpdated(0, 0.01 ether);
    }

    ////////////////////////////////////////////////////////////////
    //                    ADMIN / OWNERSHIP                        //
    ////////////////////////////////////////////////////////////////
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setDepositFee(uint256 fee) external onlyOwner {
        emit DepositFeeUpdated(depositFee, fee);
        depositFee = fee;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = status;
        emit OperatorStatusChanged(operator, status);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = collectedFees;
        collectedFees = 0;
        (bool ok, ) = payable(owner).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(owner, amount);
    }

    ////////////////////////////////////////////////////////////////
    //                  COLLECTION MANAGEMENT                     //
    ////////////////////////////////////////////////////////////////
    function registerCollection(address collection, string calldata name, string calldata metadataURI) external onlyOperator {
        if (collection == address(0)) revert ZeroAddress();
        if (collections[collection].registered) revert CollectionAlreadyRegistered();
        collections[collection] = Collection(true, name, metadataURI);
        emit CollectionRegistered(collection, name, metadataURI);
    }

    function updateCollectionMetadata(address collection, string calldata name, string calldata metadataURI) external onlyOperator {
        if (!collections[collection].registered) revert CollectionNotRegistered();
        Collection storage c = collections[collection];
        c.name = name;
        c.metadataURI = metadataURI;
        emit CollectionMetadataUpdated(collection, name, metadataURI);
    }

    ////////////////////////////////////////////////////////////////
    //                      DEPOSIT LOGIC                          //
    ////////////////////////////////////////////////////////////////
    function deposit(address collection, uint256 tokenId) external payable {
        if (!collections[collection].registered) revert CollectionNotRegistered();
        if (isDeposited[collection][tokenId]) revert AlreadyDeposited();
        if (msg.value < depositFee) revert InsufficientFee();

        address currentOwner = IERC721(collection).ownerOf(tokenId);
        if (currentOwner != msg.sender) revert NotDepositor();

        // Effects
        isDeposited[collection][tokenId] = true;
        depositOwner[collection][tokenId] = msg.sender;
        userDepositCount[msg.sender] += 1;
        collectedFees += depositFee;

        // Interactions
        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);

        // Refund excess payment
        uint256 excess = msg.value - depositFee;
        if (excess > 0) {
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert TransferFailed();
        }

        emit Deposited(collection, tokenId, msg.sender);
    }

    ////////////////////////////////////////////////////////////////
    //                    WITHDRAWAL LOGIC                         //
    ////////////////////////////////////////////////////////////////
    function requestWithdrawal(address collection, uint256 tokenId) external {
        if (!isDeposited[collection][tokenId]) revert NotDeposited();
        if (depositOwner[collection][tokenId] != msg.sender) revert NotDepositor();
        if (pendingWithdrawals[collection][tokenId].active) revert TransferPending();

        uint256 unlockTime = block.timestamp + WITHDRAWAL_TIMELOCK;
        pendingWithdrawals[collection][tokenId] = PendingWithdrawal(true, unlockTime);

        emit WithdrawalRequested(collection, tokenId, msg.sender, unlockTime);
    }

    function cancelWithdrawal(address collection, uint256 tokenId) external {
        if (!isDeposited[collection][tokenId]) revert NotDeposited();
        if (depositOwner[collection][tokenId] != msg.sender) revert NotDepositor();
        if (!pendingWithdrawals[collection][tokenId].active) revert NoActiveWithdrawal();

        delete pendingWithdrawals[collection][tokenId];
        emit WithdrawalCancelled(collection, tokenId, msg.sender);
    }

    function completeWithdrawal(address collection, uint256 tokenId) external {
        if (!isDeposited[collection][tokenId]) revert NotDeposited();
        if (depositOwner[collection][tokenId] != msg.sender) revert NotDepositor();

        PendingWithdrawal memory pwd = pendingWithdrawals[collection][tokenId];
        if (!pwd.active) revert NoActiveWithdrawal();
        if (block.timestamp < pwd.unlockTime) revert TimelockNotPassed();

        // Effects
        delete pendingWithdrawals[collection][tokenId];
        delete isDeposited[collection][tokenId];
        delete depositOwner[collection][tokenId];
        userDepositCount[msg.sender] -= 1;

        // Interactions
        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Withdrawn(collection, tokenId, msg.sender);
    }

    ////////////////////////////////////////////////////////////////
    //               INTRA-SYSTEM TRANSFER LOGIC                   //
    ////////////////////////////////////////////////////////////////
    function transfer(address collection, uint256 tokenId, address to) external {
        if (!isDeposited[collection][tokenId]) revert NotDeposited();
        if (depositOwner[collection][tokenId] != msg.sender) revert NotDepositor();
        if (pendingWithdrawals[collection][tokenId].active) revert TransferPending();
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert InvalidRecipient();

        depositOwner[collection][tokenId] = to;
        userDepositCount[msg.sender] -= 1;
        userDepositCount[to] += 1;

        emit Transferred(collection, tokenId, msg.sender, to);
    }

    ////////////////////////////////////////////////////////////////
    //                       VIEW FUNCTIONS                        //
    ////////////////////////////////////////////////////////////////
    function getCollection(address collection) external view returns (bool registered, string memory name, string memory metadataURI) {
        Collection memory c = collections[collection];
        return (c.registered, c.name, c.metadataURI);
    }

    function getPendingWithdrawal(address collection, uint256 tokenId) external view returns (bool active, uint256 unlockTime) {
        PendingWithdrawal memory pwd = pendingWithdrawals[collection][tokenId];
        return (pwd.active, pwd.unlockTime);
    }

    function isOperator(address account) external view returns (bool) {
        return operators[account];
    }

    function isRegisteredCollection(address collection) external view returns (bool) {
        return collections[collection].registered;
    }

    function getDepositOwner(address collection, uint256 tokenId) external view returns (address) {
        return depositOwner[collection][tokenId];
    }

    ////////////////////////////////////////////////////////////////
    //                  ERC721 RECEIVER SUPPORT                   //
    ////////////////////////////////////////////////////////////////
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    ////////////////////////////////////////////////////////////////
    //                       RECEIVE ETHER                         //
    ////////////////////////////////////////////////////////////////
    receive() external payable {}
}
