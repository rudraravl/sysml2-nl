// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract GameTreasury {
    error NotAuthorized();
    error NotItemOwner();
    error ItemNotInTreasury();
    error ItemAlreadyInTreasury();
    error ItemDoesNotExist();
    error MaxItemsReached();
    error ClaimCooldownActive();
    error NoTokensToClaim();
    error ZeroAddress();
    error TransferFailed();
    error InsufficientTreasuryBalance();

    event GovernanceTokensClaimed(address indexed participant, uint256 amount);
    event GamingItemDeposited(address indexed depositor, uint256 indexed itemId);
    event GamingItemWithdrawn(address indexed withdrawer, uint256 indexed itemId);
    event GamingItemTransferred(address indexed from, address indexed to, uint256 indexed itemId);
    event GamingItemMinted(address indexed to, uint256 indexed itemId);
    event TokensAllocated(address indexed participant, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TreasuryFunded(address indexed funder, uint256 amount);

    uint256 public constant MAX_ITEMS = 10_000;
    uint256 public constant CLAIM_COOLDOWN = 30 days;

    address public owner;
    address public operator;
    address public immutable governanceToken;

    uint256 public totalItemsMinted;
    mapping(uint256 => address) public itemOwner;
    mapping(uint256 => bool) public itemInTreasury;
    mapping(address => uint256[]) public ownedItemIds;
    mapping(uint256 => uint256) internal _itemIndex;

    mapping(address => uint256) public allocatedTokens;
    mapping(address => uint256) public claimedTokens;
    mapping(address => uint256) public lastClaimAt;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    constructor(address _governanceToken, address _operator) {
        if (_governanceToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        governanceToken = _governanceToken;
        operator = _operator;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function fundTreasury(uint256 amount) external {
        bool success = IERC20(governanceToken).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert TransferFailed();
        emit TreasuryFunded(msg.sender, amount);
    }

    function allocateTokens(address participant, uint256 amount) external onlyOperator {
        if (participant == address(0)) revert ZeroAddress();
        allocatedTokens[participant] += amount;
        emit TokensAllocated(participant, amount);
    }

    function claimGovernanceTokens() external {
        uint256 allocated = allocatedTokens[msg.sender];
        uint256 claimed = claimedTokens[msg.sender];
        if (allocated <= claimed) revert NoTokensToClaim();

        if (
            lastClaimAt[msg.sender] > 0 &&
            block.timestamp < lastClaimAt[msg.sender] + CLAIM_COOLDOWN
        ) {
            revert ClaimCooldownActive();
        }

        uint256 allocatable = allocated - claimed;
        uint256 contractBalance = IERC20(governanceToken).balanceOf(address(this));
        if (contractBalance < allocatable) revert InsufficientTreasuryBalance();

        claimedTokens[msg.sender] = allocated;
        lastClaimAt[msg.sender] = block.timestamp;

        bool success = IERC20(governanceToken).transfer(msg.sender, allocatable);
        if (!success) revert TransferFailed();

        emit GovernanceTokensClaimed(msg.sender, allocatable);
    }

    function mintGamingItem(address to) external onlyOperator returns (uint256 itemId) {
        if (totalItemsMinted >= MAX_ITEMS) revert MaxItemsReached();
        if (to == address(0)) revert ZeroAddress();

        totalItemsMinted++;
        itemId = totalItemsMinted;

        itemOwner[itemId] = to;
        _itemIndex[itemId] = ownedItemIds[to].length;
        ownedItemIds[to].push(itemId);

        emit GamingItemMinted(to, itemId);
    }

    function depositGamingItem(uint256 itemId) external {
        if (itemOwner[itemId] != msg.sender) revert NotItemOwner();
        if (itemInTreasury[itemId]) revert ItemAlreadyInTreasury();

        itemInTreasury[itemId] = true;
        emit GamingItemDeposited(msg.sender, itemId);
    }

    function withdrawGamingItem(uint256 itemId) external {
        if (itemOwner[itemId] != msg.sender) revert NotItemOwner();
        if (!itemInTreasury[itemId]) revert ItemNotInTreasury();

        itemInTreasury[itemId] = false;
        emit GamingItemWithdrawn(msg.sender, itemId);
    }

    function transferGamingItem(address to, uint256 itemId) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (itemOwner[itemId] == address(0)) revert ItemDoesNotExist();
        if (!itemInTreasury[itemId]) revert ItemNotInTreasury();

        address from = itemOwner[itemId];

        _removeItemFromOwner(from, itemId);
        _addItemToOwner(to, itemId);
        itemOwner[itemId] = to;
        itemInTreasury[itemId] = false;

        emit GamingItemTransferred(from, to, itemId);
    }

    function _removeItemFromOwner(address from, uint256 itemId) internal {
        uint256 len = ownedItemIds[from].length;
        if (len == 0) return;

        uint256 index = _itemIndex[itemId];
        uint256 lastIndex = len - 1;

        if (index != lastIndex) {
            uint256 lastItemId = ownedItemIds[from][lastIndex];
            ownedItemIds[from][index] = lastItemId;
            _itemIndex[lastItemId] = index;
        }

        ownedItemIds[from].pop();
        delete _itemIndex[itemId];
    }

    function _addItemToOwner(address to, uint256 itemId) internal {
        _itemIndex[itemId] = ownedItemIds[to].length;
        ownedItemIds[to].push(itemId);
    }

    function ownedItemsCount(address account) external view returns (uint256) {
        return ownedItemIds[account].length;
    }

    function claimableAmount(address participant) external view returns (uint256) {
        uint256 allocated = allocatedTokens[participant];
        uint256 claimed = claimedTokens[participant];
        if (allocated <= claimed) return 0;
        return allocated - claimed;
    }

    function canClaim(address participant) external view returns (bool) {
        if (allocatedTokens[participant] <= claimedTokens[participant]) {
            return false;
        }
        if (lastClaimAt[participant] < 1) {
            return true;
        }
        return block.timestamp >= lastClaimAt[participant] + CLAIM_COOLDOWN;
    }

    function treasuryTokenBalance() external view returns (uint256) {
        return IERC20(governanceToken).balanceOf(address(this));
    }

    function nextClaimTimestamp(address participant) external view returns (uint256) {
        if (lastClaimAt[participant] < 1) {
            return 0;
        }
        return lastClaimAt[participant] + CLAIM_COOLDOWN;
    }
}
