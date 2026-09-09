// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract TieredNFTStaking {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error NotStaker();
    error ZeroAddress();
    error NoTokensToStake();
    error NoTokensToUnstake();
    error NotTokenOwner(uint256 tokenId);
    error InvalidTier(uint256 tier);
    error InvalidThreshold();
    error RewardTransferFailed();
    error NothingToClaim();
    error ReentrancyDetected();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Staked(address indexed user, uint256[] tokenIds, uint256 newTier);
    event Unstaked(address indexed user, uint256[] tokenIds, uint256 feeBps, uint256 feeAmount, uint256 newTier);
    event RewardsClaimed(address indexed user, uint256 amount);
    event TierRateUpdated(uint256 indexed tier, uint256 oldRate, uint256 newRate);
    event TierThresholdUpdated(uint256 indexed tier, uint256 oldThreshold, uint256 newThreshold);
    event NftCollectionUpdated(address indexed oldCollection, address indexed newCollection);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_STAKE_DURATION = 365 days;
    uint256 public constant EARLY_UNSTAKE_PERIOD = 30 days;
    uint256 public constant EARLY_UNSTAKE_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_TIERS = 3;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public operator;
    address public treasury;
    IERC20 public immutable rewardToken;
    address public nftCollection;

    struct StakedNFT {
        address staker;
        uint96 stakedAt;
        uint96 lastUpdate;
        uint128 accumulatedRewards;
    }

    struct Staker {
        uint256[] stakedTokenIds;
        uint256 currentTier;
        mapping(uint256 => uint256) indexOfToken; // tokenId => index in stakedTokenIds
    }

    mapping(address => Staker) private stakers;
    mapping(uint256 => StakedNFT) private stakedNFTs; // tokenId => info

    uint256[MAX_TIERS] public tierRates; // rewards per second per NFT for each tier
    uint256[MAX_TIERS] public tierThresholds; // min NFT count to qualify for tier

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyDetected();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonZero(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        address _rewardToken,
        address _nftCollection,
        address _operator,
        address _treasury
    )
        nonZero(_rewardToken)
        nonZero(_nftCollection)
        nonZero(_operator)
        nonZero(_treasury)
    {
        rewardToken = IERC20(_rewardToken);
        nftCollection = _nftCollection;
        operator = _operator;
        treasury = _treasury;

        // Default tier thresholds
        tierThresholds[0] = 1;
        tierThresholds[1] = 3;
        tierThresholds[2] = 6;

        // Default rates (per second per NFT)
        tierRates[0] = 1e15;   // 0.001 tokens/sec
        tierRates[1] = 3e15;   // 0.003 tokens/sec
        tierRates[2] = 7e15;   // 0.007 tokens/sec
    }

    // ---------------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------------

    /// @notice Stake an array of NFTs from the caller.
    /// @param tokenIds Array of token IDs to stake.
    function stake(uint256[] calldata tokenIds) external nonReentrant {
        uint256 len = tokenIds.length;
        if (len == 0) revert NoTokensToStake();

        Staker storage staker = stakers[msg.sender];
        IERC721 collection = IERC721(nftCollection);

        // Accrue rewards on existing stakes before changing tier.
        _updateRewards(msg.sender);

        uint96 now96 = uint96(block.timestamp);

        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = tokenIds[i];
            if (collection.ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

            // Effects before interactions: record stake state prior to transfer.
            stakedNFTs[tokenId] = StakedNFT({
                staker: msg.sender,
                stakedAt: now96,
                lastUpdate: now96,
                accumulatedRewards: 0
            });

            staker.indexOfToken[tokenId] = staker.stakedTokenIds.length;
            staker.stakedTokenIds.push(tokenId);

            // Interaction: pull NFT in after state is committed.
            collection.transferFrom(msg.sender, address(this), tokenId);
        }

        uint256 newTier = _computeTier(staker.stakedTokenIds.length);
        staker.currentTier = newTier;

        emit Staked(msg.sender, tokenIds, newTier);
    }

    /// @notice Unstake an array of NFTs. Applies a 5% fee on rewards for tokens
    ///         staked fewer than 30 days.
    /// @param tokenIds Array of token IDs to unstake.
    function unstake(uint256[] calldata tokenIds) external nonReentrant {
        uint256 len = tokenIds.length;
        if (len == 0) revert NoTokensToUnstake();

        Staker storage staker = stakers[msg.sender];
        if (staker.stakedTokenIds.length == 0) revert NotStaker();

        // Accrue rewards before removing tokens.
        _updateRewards(msg.sender);

        IERC721 collection = IERC721(nftCollection);
        uint256 totalFee = 0;
        uint256 totalPaid = 0;
        address[] memory tokenIdsMem = new address[](0);
        // accumulate token ids to transfer out after state updates

        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = tokenIds[i];
            StakedNFT storage nft = stakedNFTs[tokenId];
            if (nft.staker != msg.sender) revert NotTokenOwner(tokenId);

            uint128 rewards = nft.accumulatedRewards;
            uint256 feeAmount = 0;
            uint256 paidAmount = 0;

            if (block.timestamp - uint256(nft.stakedAt) < EARLY_UNSTAKE_PERIOD) {
                feeAmount = (uint256(rewards) * EARLY_UNSTAKE_FEE_BPS) / BPS_DENOMINATOR;
                paidAmount = uint256(rewards) - feeAmount;
                totalFee += feeAmount;
            } else {
                paidAmount = uint256(rewards);
            }
            totalPaid += paidAmount;

            // Effects: remove from staker's array (swap-and-pop) before transfer.
            uint256 idx = staker.indexOfToken[tokenId];
            uint256 lastIdx = staker.stakedTokenIds.length - 1;
            if (idx != lastIdx) {
                uint256 lastTokenId = staker.stakedTokenIds[lastIdx];
                staker.stakedTokenIds[idx] = lastTokenId;
                staker.indexOfToken[lastTokenId] = idx;
            }
            staker.stakedTokenIds.pop();
            delete staker.indexOfToken[tokenId];
            delete stakedNFTs[tokenId];

            // Interaction: transfer NFT back to staker after state is cleared.
            collection.transferFrom(address(this), msg.sender, tokenId);
        }

        // Recompute tier after removal
        uint256 newTier = _computeTier(staker.stakedTokenIds.length);
        staker.currentTier = newTier;

        // Pay rewards to staker
        if (totalPaid > 0) {
            _safeRewardTransfer(msg.sender, totalPaid);
        }
        // Pay fee to treasury
        if (totalFee > 0) {
            _safeRewardTransfer(treasury, totalFee);
        }

        emit Unstaked(msg.sender, tokenIds, totalFee > 0 ? EARLY_UNSTAKE_FEE_BPS : 0, totalFee, newTier);
    }

    /// @notice Claim all accumulated rewards without unstaking.
    function claim() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        if (staker.stakedTokenIds.length == 0) revert NotStaker();

        _updateRewards(msg.sender);

        uint256 total = _collectAndResetRewards(msg.sender);
        if (total == 0) revert NothingToClaim();

        _safeRewardTransfer(msg.sender, total);

        emit RewardsClaimed(msg.sender, total);
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------

    /// @notice Set the reward rate (per second per NFT) for a tier.
    function setTierRate(uint256 tier, uint256 rate) external onlyOperator {
        if (tier >= MAX_TIERS) revert InvalidTier(tier);
        uint256 old = tierRates[tier];
        tierRates[tier] = rate;
        emit TierRateUpdated(tier, old, rate);
    }

    /// @notice Set the minimum NFT count required to qualify for a tier.
    function setTierThreshold(uint256 tier, uint256 threshold) external onlyOperator {
        if (tier >= MAX_TIERS) revert InvalidTier(tier);
        if (threshold == 0) revert InvalidThreshold();
        // Enforce ascending order of thresholds
        if (tier > 0 && threshold <= tierThresholds[tier - 1]) revert InvalidThreshold();
        if (tier < MAX_TIERS - 1 && tierThresholds[tier + 1] != 0 && threshold >= tierThresholds[tier + 1]) {
            revert InvalidThreshold();
        }
        uint256 old = tierThresholds[tier];
        tierThresholds[tier] = threshold;
        emit TierThresholdUpdated(tier, old, threshold);
    }

    /// @notice Set the NFT collection that can be staked.
    function setNftCollection(address newCollection) external onlyOperator nonZero(newCollection) {
        address old = nftCollection;
        nftCollection = newCollection;
        emit NftCollectionUpdated(old, newCollection);
    }

    /// @notice Set the treasury address that receives unstaking fees.
    function setTreasury(address newTreasury) external onlyOperator nonZero(newTreasury) {
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    /// @notice Transfer operator role to a new address.
    function setOperator(address newOperator) external onlyOperator nonZero(newOperator) {
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------

    /// @notice Returns the list of token IDs staked by a user and their tier.
    function getStaker(address user) external view returns (uint256[] memory tokenIds, uint256 currentTier) {
        Staker storage s = stakers[user];
        return (s.stakedTokenIds, s.currentTier);
    }

    /// @notice Returns the staking info for a specific NFT.
    function getStakedNFT(uint256 tokenId) external view returns (StakedNFT memory) {
        return stakedNFTs[tokenId];
    }

    /// @notice Returns the total pending rewards for a user, including accrued.
    function pendingRewards(address user) external view returns (uint256) {
        Staker storage s = stakers[user];
        uint256 count = s.stakedTokenIds.length;
        if (count == 0) return 0;

        uint256 rate = tierRates[s.currentTier];
        uint256 total = 0;

        for (uint256 i = 0; i < count; ++i) {
            StakedNFT storage nft = stakedNFTs[s.stakedTokenIds[i]];
            uint256 cap = uint256(nft.stakedAt) + MAX_STAKE_DURATION;
            uint256 end = block.timestamp < cap ? block.timestamp : cap;
            uint256 elapsed = end > uint256(nft.lastUpdate) ? end - uint256(nft.lastUpdate) : 0;
            total += uint256(nft.accumulatedRewards) + elapsed * rate;
        }
        return total;
    }

    /// @notice Returns the tier a user would be in for a given staked count.
    function computeTier(uint256 count) external view returns (uint256) {
        return _computeTier(count);
    }

    // ---------------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------------

    function _computeTier(uint256 count) internal view returns (uint256) {
        uint256 tier = 0;
        for (uint256 i = 0; i < MAX_TIERS; ++i) {
            if (count >= tierThresholds[i]) {
                tier = i;
            }
        }
        return tier;
    }

    /// @dev Accrue rewards for all NFTs staked by the user based on current tier rate.
    function _updateRewards(address user) internal {
        Staker storage s = stakers[user];
        uint256 count = s.stakedTokenIds.length;
        if (count == 0) return;

        uint256 rate = tierRates[s.currentTier];

        for (uint256 i = 0; i < count; ++i) {
            StakedNFT storage nft = stakedNFTs[s.stakedTokenIds[i]];
            uint256 cap = uint256(nft.stakedAt) + MAX_STAKE_DURATION;
            uint256 end = block.timestamp < cap ? block.timestamp : cap;
            uint256 elapsed = end > uint256(nft.lastUpdate) ? end - uint256(nft.lastUpdate) : 0;
            if (elapsed > 0) {
                nft.accumulatedRewards += uint128(elapsed * rate);
                nft.lastUpdate = uint96(end);
            }
        }
    }

    /// @dev Sums and resets accumulated rewards across all of a user's staked NFTs.
    function _collectAndResetRewards(address user) internal returns (uint256 total) {
        Staker storage s = stakers[user];
        uint256 count = s.stakedTokenIds.length;
        total = 0;
        for (uint256 i = 0; i < count; ++i) {
            StakedNFT storage nft = stakedNFTs[s.stakedTokenIds[i]];
            total += uint256(nft.accumulatedRewards);
            nft.accumulatedRewards = 0;
        }
    }

    /// @dev Safe transfer of reward tokens, reverts on failure.
    function _safeRewardTransfer(address to, uint256 amount) internal {
        if (!rewardToken.transfer(to, amount)) revert RewardTransferFailed();
    }
}
