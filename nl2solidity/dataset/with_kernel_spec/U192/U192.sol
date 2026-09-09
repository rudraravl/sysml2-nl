// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract MysteryBox is IERC721Receiver {
    enum RewardType { Token, NFT, Physical }

    struct Item {
        uint256 probability;
        RewardType rewardType;
        address tokenAddress;
        uint256 amount;
        address nftContract;
        uint256 nftTokenId;
        string physicalAssetId;
    }

    struct BoxType {
        string name;
        bool active;
        uint256 totalProbability;
        uint256 itemCount;
    }

    struct PhysicalOpening {
        uint256 id;
        string physicalAssetId;
        bool claimed;
    }

    event BoxTypeCreated(uint256 indexed boxTypeId, string name);
    event BoxTypeActivated(uint256 indexed boxTypeId);
    event BoxTypeDeactivated(uint256 indexed boxTypeId);
    event ItemAdded(uint256 indexed boxTypeId, uint256 itemIndex);
    event BoxPurchased(address indexed buyer, uint256 indexed boxTypeId, uint256 quantity, uint256 cost);
    event BoxOpened(
        address indexed opener,
        uint256 indexed boxTypeId,
        uint256 itemIndex,
        RewardType rewardType,
        address tokenAddress,
        uint256 amount,
        address nftContract,
        uint256 nftTokenId,
        string physicalAssetId,
        uint256 physicalOpeningId
    );
    event PhysicalAssetClaimed(address indexed claimer, uint256 indexed boxTypeId, uint256 openingId, string physicalAssetId);
    event TokenDeposited(address indexed token, uint256 amount);
    event NFTDeposited(address indexed nftContract, uint256 tokenId);
    event TokenWithdrawn(address indexed token, uint256 amount);
    event NFTWithdrawn(address indexed nftContract, uint256 tokenId);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event OpenCommitted(address indexed user, bytes32 commitment);
    event OpenRevealed(address indexed user, uint256 reveal);
    event CommitmentCancelled(address indexed user);

    error Unauthorized();
    error ZeroAddress();
    error BoxTypeNotFound();
    error BoxNotActive();
    error BoxAlreadyActive();
    error InvalidQuantity();
    error InvalidProbability();
    error ProbabilityOverflow();
    error ProbabilitySumMismatch();
    error InsufficientBoxBalance();
    error InsufficientUnallocatedTokens();
    error InsufficientUnallocatedNFT();
    error InsufficientAllocatedTokens();
    error InsufficientAllocatedNFT();
    error PhysicalAlreadyClaimed();
    error InvalidOpening();
    error TransferFailed();
    error NoCommitment();
    error InvalidReveal();
    error CommitmentAlreadyPending();
    error IndexOutOfBounds();

    uint256 public constant TOTAL_BASIS_POINTS = 10000;
    uint256 public constant BOX_COST = 100;

    address public operator;
    IERC20 public immutable acceptedToken;
    uint256 public boxPrice;

    uint256 public nextBoxTypeId = 1;

    mapping(uint256 => BoxType) public boxTypes;
    mapping(uint256 => Item[]) internal _boxItems;

    mapping(address => mapping(uint256 => uint256)) public boxBalanceOf;

    mapping(address => uint256) public unallocatedTokens;
    mapping(address => mapping(uint256 => bool)) public unallocatedNFTs;

    mapping(uint256 => mapping(address => uint256)) public allocatedTokens;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public allocatedNFTs;

    mapping(address => mapping(uint256 => PhysicalOpening[])) internal _physicalOpenings;
    uint256 private _nextPhysicalOpeningId = 1;

    mapping(address => bytes32) public openCommitments;

    uint256 private _nonce;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier boxExists(uint256 boxTypeId) {
        if (boxTypeId == 0 || boxTypeId >= nextBoxTypeId) revert BoxTypeNotFound();
        _;
    }

    constructor(address _acceptedToken) {
        if (_acceptedToken == address(0)) revert ZeroAddress();
        operator = msg.sender;
        acceptedToken = IERC20(_acceptedToken);
        boxPrice = BOX_COST;
        emit OperatorUpdated(address(0), operator);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setBoxPrice(uint256 _boxPrice) external onlyOperator {
        boxPrice = _boxPrice;
    }

    function createBoxType(string calldata name) external onlyOperator returns (uint256 boxTypeId) {
        boxTypeId = nextBoxTypeId++;
        boxTypes[boxTypeId] = BoxType({
            name: name,
            active: false,
            totalProbability: 0,
            itemCount: 0
        });
        emit BoxTypeCreated(boxTypeId, name);
    }

    function addItem(uint256 boxTypeId, Item calldata item) external onlyOperator boxExists(boxTypeId) {
        if (boxTypes[boxTypeId].active) revert BoxAlreadyActive();
        if (item.probability == 0) revert InvalidProbability();

        if (item.rewardType == RewardType.Token) {
            if (item.tokenAddress == address(0)) revert ZeroAddress();
            if (item.amount == 0) revert InvalidQuantity();
        } else if (item.rewardType == RewardType.NFT) {
            if (item.nftContract == address(0)) revert ZeroAddress();
        }

        uint256 newTotal = boxTypes[boxTypeId].totalProbability + item.probability;
        if (newTotal > TOTAL_BASIS_POINTS) revert ProbabilityOverflow();

        if (item.rewardType == RewardType.Token) {
            uint256 unalloc = unallocatedTokens[item.tokenAddress];
            if (unalloc < item.amount) revert InsufficientUnallocatedTokens();
            unallocatedTokens[item.tokenAddress] = unalloc - item.amount;
            allocatedTokens[boxTypeId][item.tokenAddress] += item.amount;
        } else if (item.rewardType == RewardType.NFT) {
            if (!unallocatedNFTs[item.nftContract][item.nftTokenId]) revert InsufficientUnallocatedNFT();
            unallocatedNFTs[item.nftContract][item.nftTokenId] = false;
            allocatedNFTs[boxTypeId][item.nftContract][item.nftTokenId] = true;
        }

        _boxItems[boxTypeId].push(item);
        boxTypes[boxTypeId].totalProbability = newTotal;
        boxTypes[boxTypeId].itemCount++;
        emit ItemAdded(boxTypeId, boxTypes[boxTypeId].itemCount - 1);
    }

    function activateBox(uint256 boxTypeId) external onlyOperator boxExists(boxTypeId) {
        if (boxTypes[boxTypeId].active) revert BoxAlreadyActive();
        if (boxTypes[boxTypeId].totalProbability != TOTAL_BASIS_POINTS) revert ProbabilitySumMismatch();
        boxTypes[boxTypeId].active = true;
        emit BoxTypeActivated(boxTypeId);
    }

    function deactivateBox(uint256 boxTypeId) external onlyOperator boxExists(boxTypeId) {
        if (!boxTypes[boxTypeId].active) revert BoxNotActive();
        boxTypes[boxTypeId].active = false;
        emit BoxTypeDeactivated(boxTypeId);
    }

    function depositTokens(address token, uint256 amount) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidQuantity();
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        unallocatedTokens[token] += amount;
        emit TokenDeposited(token, amount);
    }

    function depositNFT(address nftContract, uint256 tokenId) external onlyOperator {
        if (nftContract == address(0)) revert ZeroAddress();
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        unallocatedNFTs[nftContract][tokenId] = true;
        emit NFTDeposited(nftContract, tokenId);
    }

    function withdrawTokens(address token, uint256 amount) external onlyOperator {
        if (amount == 0) revert InvalidQuantity();
        if (unallocatedTokens[token] < amount) revert InsufficientUnallocatedTokens();
        unallocatedTokens[token] -= amount;
        bool ok = IERC20(token).transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit TokenWithdrawn(token, amount);
    }

    function withdrawNFT(address nftContract, uint256 tokenId) external onlyOperator {
        if (!unallocatedNFTs[nftContract][tokenId]) revert InsufficientUnallocatedNFT();
        unallocatedNFTs[nftContract][tokenId] = false;
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        emit NFTWithdrawn(nftContract, tokenId);
    }

    function purchaseBox(uint256 boxTypeId, uint256 quantity) external boxExists(boxTypeId) {
        if (!boxTypes[boxTypeId].active) revert BoxNotActive();
        if (quantity == 0) revert InvalidQuantity();
        uint256 cost = boxPrice * quantity;
        bool ok = acceptedToken.transferFrom(msg.sender, address(this), cost);
        if (!ok) revert TransferFailed();
        boxBalanceOf[msg.sender][boxTypeId] += quantity;
        emit BoxPurchased(msg.sender, boxTypeId, quantity, cost);
    }

    function generateCommitment(uint256 reveal) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(reveal));
    }

    function commitOpenBox(bytes32 commitment) external {
        if (openCommitments[msg.sender] != bytes32(0)) revert CommitmentAlreadyPending();
        openCommitments[msg.sender] = commitment;
        emit OpenCommitted(msg.sender, commitment);
    }

    function cancelOpenCommitment() external {
        if (openCommitments[msg.sender] == bytes32(0)) revert NoCommitment();
        openCommitments[msg.sender] = bytes32(0);
        emit CommitmentCancelled(msg.sender);
    }

    function openBox(uint256 boxTypeId, uint256 reveal) external boxExists(boxTypeId) {
        if (!boxTypes[boxTypeId].active) revert BoxNotActive();
        if (boxBalanceOf[msg.sender][boxTypeId] == 0) revert InsufficientBoxBalance();

        bytes32 commitment = openCommitments[msg.sender];
        if (commitment == bytes32(0)) revert NoCommitment();
        if (keccak256(abi.encodePacked(reveal)) != commitment) revert InvalidReveal();
        openCommitments[msg.sender] = bytes32(0);

        boxBalanceOf[msg.sender][boxTypeId]--;

        uint256 roll = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    _nonce++,
                    reveal
                )
            )
        ) % TOTAL_BASIS_POINTS;

        uint256 cumulative = 0;
        uint256 selectedIndex = 0;
        uint256 itemCount = boxTypes[boxTypeId].itemCount;
        for (uint256 i = 0; i < itemCount; i++) {
            cumulative += _boxItems[boxTypeId][i].probability;
            if (roll < cumulative) {
                selectedIndex = i;
                break;
            }
        }

        Item memory reward = _boxItems[boxTypeId][selectedIndex];
        uint256 physicalOpeningId = 0;

        if (reward.rewardType == RewardType.Token) {
            uint256 allocated = allocatedTokens[boxTypeId][reward.tokenAddress];
            if (allocated < reward.amount) revert InsufficientAllocatedTokens();
            allocatedTokens[boxTypeId][reward.tokenAddress] = allocated - reward.amount;
            bool ok = IERC20(reward.tokenAddress).transfer(msg.sender, reward.amount);
            if (!ok) revert TransferFailed();
        } else if (reward.rewardType == RewardType.NFT) {
            if (!allocatedNFTs[boxTypeId][reward.nftContract][reward.nftTokenId]) revert InsufficientAllocatedNFT();
            allocatedNFTs[boxTypeId][reward.nftContract][reward.nftTokenId] = false;
            IERC721(reward.nftContract).safeTransferFrom(address(this), msg.sender, reward.nftTokenId);
        } else {
            physicalOpeningId = _nextPhysicalOpeningId++;
            _physicalOpenings[msg.sender][boxTypeId].push(PhysicalOpening({
                id: physicalOpeningId,
                physicalAssetId: reward.physicalAssetId,
                claimed: false
            }));
        }

        emit OpenRevealed(msg.sender, reveal);
        emit BoxOpened(
            msg.sender,
            boxTypeId,
            selectedIndex,
            reward.rewardType,
            reward.tokenAddress,
            reward.amount,
            reward.nftContract,
            reward.nftTokenId,
            reward.physicalAssetId,
            physicalOpeningId
        );
    }

    function claimPhysicalAsset(uint256 boxTypeId, uint256 openingId) external boxExists(boxTypeId) {
        PhysicalOpening[] storage openings = _physicalOpenings[msg.sender][boxTypeId];
        uint256 len = openings.length;
        for (uint256 i = 0; i < len; i++) {
            if (openings[i].id == openingId) {
                if (openings[i].claimed) revert PhysicalAlreadyClaimed();
                openings[i].claimed = true;
                emit PhysicalAssetClaimed(msg.sender, boxTypeId, openingId, openings[i].physicalAssetId);
                return;
            }
        }
        revert InvalidOpening();
    }

    function getBoxType(uint256 boxTypeId)
        external
        view
        boxExists(boxTypeId)
        returns (string memory name, bool active, uint256 totalProbability, uint256 itemCount)
    {
        BoxType storage bt = boxTypes[boxTypeId];
        return (bt.name, bt.active, bt.totalProbability, bt.itemCount);
    }

    function getBoxItem(uint256 boxTypeId, uint256 index)
        external
        view
        boxExists(boxTypeId)
        returns (Item memory)
    {
        if (index >= _boxItems[boxTypeId].length) revert IndexOutOfBounds();
        return _boxItems[boxTypeId][index];
    }

    function getBoxItemCount(uint256 boxTypeId) external view boxExists(boxTypeId) returns (uint256) {
        return _boxItems[boxTypeId].length;
    }

    function getPhysicalOpeningCount(address user, uint256 boxTypeId) external view returns (uint256) {
        return _physicalOpenings[user][boxTypeId].length;
    }

    function getPhysicalOpening(address user, uint256 boxTypeId, uint256 index)
        external
        view
        returns (PhysicalOpening memory)
    {
        if (index >= _physicalOpenings[user][boxTypeId].length) revert IndexOutOfBounds();
        return _physicalOpenings[user][boxTypeId][index];
    }

    function getAllocatedTokenBalance(uint256 boxTypeId, address token) external view returns (uint256) {
        return allocatedTokens[boxTypeId][token];
    }

    function isNFTAllocated(uint256 boxTypeId, address nftContract, uint256 tokenId) external view returns (bool) {
        return allocatedNFTs[boxTypeId][nftContract][tokenId];
    }

    function getUnallocatedTokenBalance(address token) external view returns (uint256) {
        return unallocatedTokens[token];
    }

    function isNFTUnallocated(address nftContract, uint256 tokenId) external view returns (bool) {
        return unallocatedNFTs[nftContract][tokenId];
    }

    function hasPendingCommitment(address user) external view returns (bool) {
        return openCommitments[user] != bytes32(0);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
