// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract GameRewardSystem {
    error NotOwner();
    error Paused();
    error NotApprovedOrOwner();
    error InvalidPayment();
    error InsufficientPool();
    error InsufficientBalance();
    error MaxCollectiblesReached();
    error AlreadyStaked();
    error NotStaked();
    error TokenDoesNotExist();
    error ZeroAddress();
    error ZeroAmount();
    error TransferFailed();

    event TokensEarned(address indexed player, uint256 amount);
    event CollectibleMinted(address indexed player, uint256 tokenId);
    event CollectibleStaked(address indexed player, uint256 tokenId);
    event CollectibleUnstaked(address indexed player, uint256 tokenId);
    event YieldClaimed(address indexed player, uint256 tokenId, uint256 amount);
    event PoolFunded(address indexed funder, uint256 amount);
    event PausedState(bool isPaused);
    event RewardsWithdrawn(address indexed player, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    address public owner;
    IERC20 public immutable rewardToken;
    uint256 public globalPool;
    uint256 public gameRewardRate;
    uint256 public stakingYieldPercentage;
    uint256 public collectibleMintCost;

    uint256 public constant PLAY_COST = 0.01 ether;
    uint256 public constant MAX_COLLECTIBLES_PER_PLAYER = 10;

    bool public paused;

    mapping(address => uint256) public playerBalances;

    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;
    uint256 private _nextTokenId = 1;

    mapping(uint256 => uint256) public stakingStartTime;
    mapping(uint256 => bool) public isStaked;

    mapping(address => uint256) public collectiblesMinted;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(
        address _rewardToken,
        uint256 _gameRewardRate,
        uint256 _stakingYieldPercentage,
        uint256 _collectibleMintCost
    ) {
        if (_rewardToken == address(0)) revert ZeroAddress();
        owner = msg.sender;
        rewardToken = IERC20(_rewardToken);
        gameRewardRate = _gameRewardRate;
        stakingYieldPercentage = _stakingYieldPercentage;
        collectibleMintCost = _collectibleMintCost;
    }

    function playGame() external payable whenNotPaused {
        if (msg.value != PLAY_COST) revert InvalidPayment();
        if (globalPool < gameRewardRate) revert InsufficientPool();

        globalPool -= gameRewardRate;
        playerBalances[msg.sender] += gameRewardRate;

        emit TokensEarned(msg.sender, gameRewardRate);
    }

    function mintCollectible() external whenNotPaused {
        if (collectiblesMinted[msg.sender] >= MAX_COLLECTIBLES_PER_PLAYER) revert MaxCollectiblesReached();
        if (playerBalances[msg.sender] < collectibleMintCost) revert InsufficientBalance();

        playerBalances[msg.sender] -= collectibleMintCost;
        globalPool += collectibleMintCost;

        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        collectiblesMinted[msg.sender]++;

        emit CollectibleMinted(msg.sender, tokenId);
    }

    function stakeCollectible(uint256 tokenId) external whenNotPaused {
        if (_owners[tokenId] != msg.sender) revert NotApprovedOrOwner();
        if (isStaked[tokenId]) revert AlreadyStaked();

        isStaked[tokenId] = true;
        stakingStartTime[tokenId] = block.timestamp;

        emit CollectibleStaked(msg.sender, tokenId);
    }

    function unstakeCollectible(uint256 tokenId) external whenNotPaused {
        if (_owners[tokenId] != msg.sender) revert NotApprovedOrOwner();
        if (!isStaked[tokenId]) revert NotStaked();

        _claimYield(tokenId);
        isStaked[tokenId] = false;

        emit CollectibleUnstaked(msg.sender, tokenId);
    }

    function claimStakingYield(uint256 tokenId) external whenNotPaused {
        if (_owners[tokenId] != msg.sender) revert NotApprovedOrOwner();
        if (!isStaked[tokenId]) revert NotStaked();

        _claimYield(tokenId);
    }

    function _claimYield(uint256 tokenId) internal {
        uint256 startTime = stakingStartTime[tokenId];
        if (block.timestamp <= startTime) return;

        uint256 timeStaked = block.timestamp - startTime;
        uint256 yield = (timeStaked * gameRewardRate * stakingYieldPercentage) / (100 * 1 days);

        if (yield > 0) {
            if (globalPool < yield) {
                yield = globalPool;
            }
            globalPool -= yield;
            playerBalances[msg.sender] += yield;
            stakingStartTime[tokenId] = block.timestamp;
            emit YieldClaimed(msg.sender, tokenId, yield);
        }
    }

    function withdrawRewards(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (playerBalances[msg.sender] < amount) revert InsufficientBalance();

        playerBalances[msg.sender] -= amount;
        if (!rewardToken.transfer(msg.sender, amount)) revert TransferFailed();

        emit RewardsWithdrawn(msg.sender, amount);
    }

    function setGameRewardRate(uint256 _rate) external onlyOwner {
        gameRewardRate = _rate;
    }

    function setStakingYieldPercentage(uint256 _percentage) external onlyOwner {
        stakingYieldPercentage = _percentage;
    }

    function setCollectibleMintCost(uint256 _cost) external onlyOwner {
        collectibleMintCost = _cost;
    }

    function fundPool(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        if (!rewardToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        globalPool += amount;
        emit PoolFunded(msg.sender, amount);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedState(_paused);
    }

    function withdrawNative() external onlyOwner {
        (bool success, ) = owner.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        if (tokenOwner == address(0)) revert TokenDoesNotExist();
        return tokenOwner;
    }

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = _owners[tokenId];
        if (tokenOwner == address(0)) revert TokenDoesNotExist();
        if (msg.sender != tokenOwner && !_operatorApprovals[tokenOwner][msg.sender]) revert NotApprovedOrOwner();
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist();
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public whenNotPaused {
        if (_owners[tokenId] != from) revert NotApprovedOrOwner();
        if (to == address(0)) revert ZeroAddress();
        if (isStaked[tokenId]) revert AlreadyStaked();
        if (msg.sender != from && _tokenApprovals[tokenId] != msg.sender && !_operatorApprovals[from][msg.sender]) revert NotApprovedOrOwner();

        _tokenApprovals[tokenId] = address(0);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public whenNotPaused {
        transferFrom(from, to, tokenId);
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) revert TransferFailed();
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert TransferFailed();
            }
        }
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != address(0)) revert TokenDoesNotExist();

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }
}
