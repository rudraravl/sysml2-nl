// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract PetStakingVault {
    // --- Custom Errors ---
    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error ZeroAddress();
    error MaxPetsExceeded();
    error RateTooHigh();
    error NotTokenOwner();
    error NotStakedByUser();
    error NotApproved();
    error TransferFailed();
    error NothingToClaim();
    error TokenAlreadyStaked();

    // --- Events ---
    event PetStaked(address indexed user, uint256 indexed tokenId);
    event PetWithdrawn(address indexed user, uint256 indexed tokenId);
    event RewardsClaimed(address indexed user, uint256 amount);
    event DailyRateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- Constants ---
    uint256 public constant MAX_PETS_PER_USER = 5;
    uint256 public constant MAX_DAILY_RATE = 1e16; // 0.01 reward tokens (assuming 18 decimals)
    uint256 public constant SECONDS_PER_DAY = 1 days;

    // --- State ---
    address public owner;
    address public operator;
    bool public paused;

    IERC20 public immutable rewardToken;
    IERC721 public immutable petToken;

    uint256 public dailyRewardRate; // reward tokens per pet per day
    uint256 public accRewardPerPet; // accumulated reward per pet
    uint256 public lastUpdateTime;
    uint256 public totalStaked;

    struct UserInfo {
        uint256[] tokenIds;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    mapping(address => UserInfo) private _users;
    mapping(uint256 => address) public stakerOf; // tokenId => staker
    mapping(address => mapping(uint256 => uint256)) private _petIndex; // user => tokenId => array index

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    // --- Constructor ---
    constructor(
        address rewardToken_,
        address petToken_,
        address operator_,
        uint256 initialDailyRate
    ) {
        if (rewardToken_ == address(0) || petToken_ == address(0) || operator_ == address(0)) revert ZeroAddress();
        if (initialDailyRate >= MAX_DAILY_RATE) revert RateTooHigh();

        rewardToken = IERC20(rewardToken_);
        petToken = IERC721(petToken_);
        operator = operator_;
        dailyRewardRate = initialDailyRate;
        lastUpdateTime = block.timestamp;

        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), operator_);
        emit DailyRateUpdated(0, initialDailyRate);
    }

    // --- Admin ---
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
        if (state) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function setDailyRewardRate(uint256 newRate) external onlyOperator {
        if (newRate >= MAX_DAILY_RATE) revert RateTooHigh();
        _updateReward();
        emit DailyRateUpdated(dailyRewardRate, newRate);
        dailyRewardRate = newRate;
    }

    // --- Reward Accounting ---
    function _updateReward() internal {
        if (block.timestamp <= lastUpdateTime) return;
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastUpdateTime;
        accRewardPerPet += (elapsed * dailyRewardRate) / SECONDS_PER_DAY;
        lastUpdateTime = block.timestamp;
    }

    function _updateUserPending(address user) internal {
        UserInfo storage info = _users[user];
        uint256 count = info.tokenIds.length;
        uint256 earned = count * accRewardPerPet - info.rewardDebt;
        info.pendingRewards += earned;
        info.rewardDebt = count * accRewardPerPet;
    }

    // --- Staking ---
    function _stake(address user, uint256 tokenId) internal {
        if (petToken.ownerOf(tokenId) != user) revert NotTokenOwner();
        if (stakerOf[tokenId] != address(0)) revert TokenAlreadyStaked();
        if (
            petToken.getApproved(tokenId) != address(this) &&
            !petToken.isApprovedForAll(user, address(this))
        ) revert NotApproved();

        UserInfo storage info = _users[user];
        if (info.tokenIds.length >= MAX_PETS_PER_USER) revert MaxPetsExceeded();

        _updateReward();
        _updateUserPending(user);

        info.tokenIds.push(tokenId);
        _petIndex[user][tokenId] = info.tokenIds.length - 1;
        stakerOf[tokenId] = user;
        totalStaked += 1;
        info.rewardDebt += accRewardPerPet;

        petToken.transferFrom(user, address(this), tokenId);

        emit PetStaked(user, tokenId);
    }

    function stake(uint256 tokenId) external whenNotPaused {
        _stake(msg.sender, tokenId);
    }

    function stakeBatch(uint256[] calldata tokenIds) external whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _stake(msg.sender, tokenIds[i]);
        }
    }

    // --- Withdrawal ---
    function _withdraw(address user, uint256 tokenId) internal {
        if (stakerOf[tokenId] != user) revert NotStakedByUser();

        _updateReward();
        _updateUserPending(user);

        UserInfo storage info = _users[user];
        uint256 index = _petIndex[user][tokenId];
        uint256 lastIndex = info.tokenIds.length - 1;

        if (index != lastIndex) {
            uint256 lastTokenId = info.tokenIds[lastIndex];
            info.tokenIds[index] = lastTokenId;
            _petIndex[user][lastTokenId] = index;
        }
        info.tokenIds.pop();
        delete _petIndex[user][tokenId];
        delete stakerOf[tokenId];
        totalStaked -= 1;
        info.rewardDebt -= accRewardPerPet;

        petToken.safeTransferFrom(address(this), user, tokenId);

        emit PetWithdrawn(user, tokenId);
    }

    function withdraw(uint256 tokenId) external whenNotPaused {
        _withdraw(msg.sender, tokenId);
    }

    function withdrawAll() external whenNotPaused {
        UserInfo storage info = _users[msg.sender];
        uint256 len = info.tokenIds.length;
        uint256[] memory tokenIds = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            tokenIds[i] = info.tokenIds[i];
        }
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _withdraw(msg.sender, tokenIds[i]);
        }
    }

    // --- Claim ---
    function claimRewards() external whenNotPaused {
        _updateReward();
        _updateUserPending(msg.sender);

        UserInfo storage info = _users[msg.sender];
        uint256 amount = info.pendingRewards;
        if (amount == 0) revert NothingToClaim();
        info.pendingRewards = 0;

        bool success = rewardToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit RewardsClaimed(msg.sender, amount);
    }

    // --- Views ---
    function pendingRewards(address user) external view returns (uint256) {
        UserInfo storage info = _users[user];
        uint256 count = info.tokenIds.length;
        uint256 currentAcc = accRewardPerPet;
        if (totalStaked > 0 && block.timestamp > lastUpdateTime) {
            uint256 elapsed = block.timestamp - lastUpdateTime;
            currentAcc += (elapsed * dailyRewardRate) / SECONDS_PER_DAY;
        }
        uint256 earned = count * currentAcc - info.rewardDebt;
        return info.pendingRewards + earned;
    }

    function stakedCount(address user) external view returns (uint256) {
        return _users[user].tokenIds.length;
    }

    function getStakedPets(address user) external view returns (uint256[] memory) {
        return _users[user].tokenIds;
    }

    function userInfo(address user)
        external
        view
        returns (uint256[] memory tokenIds, uint256 rewardDebt, uint256 pending)
    {
        UserInfo storage info = _users[user];
        return (info.tokenIds, info.rewardDebt, info.pendingRewards);
    }
}
