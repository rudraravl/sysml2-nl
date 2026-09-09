// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TreasuryReserveCurrency
/// @notice Manages a treasury-backed reserve currency. Users stake whitelisted
/// treasury assets (stablecoins / LP tokens) to mint reserve currency 1:1, then
/// can unstake by burning reserve currency to redeem any whitelisted asset
/// (subject to a 0.5% fee). A designated operator may periodically trigger
/// rebase events that compound every staker's reserve balance at 0.05% per
/// 4-hour period. Rebase rewards are credited lazily when users interact.
contract TreasuryReserveCurrency is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**************************************************************************
     * Constants
     *************************************************************************/
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant REBASE_PERIOD = 4 hours;
    uint256 public constant INITIAL_REBASE_RATE_BPS = 5; // 0.05% per period
    uint256 public constant UNSTAKE_FEE_BPS = 50; // 0.5%
    uint256 public constant INDEX_PRECISION = 1e18;
    uint256 public constant MAX_PERIODS_PER_REBASE = 365;

    /**************************************************************************
     * Errors
     *************************************************************************/
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotTreasury();
    error AssetAlreadyAdded();
    error InsufficientReserve();
    error InsufficientAssetBalance();
    error NoPeriodElapsed();
    error InvalidRate();
    error NotOperator();
    error CannotRecoverTreasuryAsset();

    /**************************************************************************
     * Events
     *************************************************************************/
    event Staked(
        address indexed user,
        address indexed asset,
        uint256 amountStaked,
        uint256 reserveMinted
    );
    event Unstaked(
        address indexed user,
        address indexed asset,
        uint256 reserveBurned,
        uint256 assetReturned,
        uint256 fee
    );
    event RebaseTriggered(
        uint256 indexed epoch,
        uint256 periods,
        uint256 mintAmount,
        uint256 oldIndex,
        uint256 newIndex
    );
    event RebaseRewardRateUpdated(uint256 oldRateBps, uint256 newRateBps);
    event TreasuryAssetAdded(address indexed asset);
    event TreasuryAssetRemoved(address indexed asset);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event RewardsClaimed(address indexed user, uint256 amount);
    event FeesSwept(address indexed asset, address indexed recipient, uint256 amount);

    /**************************************************************************
     * Storage – access control & rebase configuration
     *************************************************************************/
    address public operator;
    uint256 public rebaseRateBps;
    uint256 public lastRebaseTime;
    uint256 public epoch;

    /**************************************************************************
     * Storage – reserve currency accounting
     *************************************************************************/
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 public rebaseIndex = INDEX_PRECISION;
    mapping(address => uint256) public userIndex;
    uint256 public unclaimedRewards;

    /**************************************************************************
     * Storage – treasury assets
     *************************************************************************/
    address[] public treasuryAssets;
    mapping(address => bool) public isTreasuryAsset;
    mapping(address => uint256) public totalStakedByAsset;
    mapping(address => uint256) public accumulatedFees;

    /**************************************************************************
     * Modifiers
     *************************************************************************/
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /**************************************************************************
     * Constructor
     *************************************************************************/
    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        rebaseRateBps = INITIAL_REBASE_RATE_BPS;
        lastRebaseTime = block.timestamp;
        emit OperatorUpdated(address(0), _operator);
        emit RebaseRewardRateUpdated(0, INITIAL_REBASE_RATE_BPS);
    }

    /**************************************************************************
     * Owner administration
     *************************************************************************/

    function addTreasuryAsset(address asset) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (isTreasuryAsset[asset]) revert AssetAlreadyAdded();
        isTreasuryAsset[asset] = true;
        treasuryAssets.push(asset);
        emit TreasuryAssetAdded(asset);
    }

    function removeTreasuryAsset(address asset) external onlyOwner {
        if (!isTreasuryAsset[asset]) revert AssetNotTreasury();
        if (totalStakedByAsset[asset] != 0 || accumulatedFees[asset] != 0) {
            revert InsufficientAssetBalance();
        }
        isTreasuryAsset[asset] = false;
        uint256 len = treasuryAssets.length;
        for (uint256 i = 0; i < len; ) {
            if (treasuryAssets[i] == asset) {
                treasuryAssets[i] = treasuryAssets[len - 1];
                treasuryAssets.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit TreasuryAssetRemoved(asset);
    }

    function setRebaseRewardRate(uint256 newRateBps) external onlyOwner {
        if (newRateBps > BPS_DENOMINATOR) revert InvalidRate();
        uint256 old = rebaseRateBps;
        rebaseRateBps = newRateBps;
        emit RebaseRewardRateUpdated(old, newRateBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function sweepFees(address asset, address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees[asset];
        if (amount == 0) revert ZeroAmount();
        accumulatedFees[asset] = 0;
        IERC20(asset).safeTransfer(recipient, amount);
        emit FeesSwept(asset, recipient, amount);
    }

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (isTreasuryAsset[token]) revert CannotRecoverTreasuryAsset();
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**************************************************************************
     * Operator – rebase
     *************************************************************************/

    function rebase() external onlyOperator {
        uint256 elapsed = block.timestamp - lastRebaseTime;
        uint256 periods = elapsed / REBASE_PERIOD;
        if (periods == 0) revert NoPeriodElapsed();
        if (periods > MAX_PERIODS_PER_REBASE) periods = MAX_PERIODS_PER_REBASE;

        uint256 oldIndex = rebaseIndex;
        uint256 newIndex =
            (oldIndex * (BPS_DENOMINATOR + rebaseRateBps * periods)) / BPS_DENOMINATOR;
        rebaseIndex = newIndex;

        uint256 mintAmount;
        if (totalSupply > 0 && oldIndex > 0) {
            mintAmount = (totalSupply * (newIndex - oldIndex)) / oldIndex;
            totalSupply += mintAmount;
            unclaimedRewards += mintAmount;
        }

        lastRebaseTime += periods * REBASE_PERIOD;
        unchecked {
            epoch += 1;
        }

        emit RebaseTriggered(epoch, periods, mintAmount, oldIndex, newIndex);
    }

    /**************************************************************************
     * User – stake / unstake / claim
     *************************************************************************/

    function stake(address asset, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!isTreasuryAsset[asset]) revert AssetNotTreasury();

        _sync(msg.sender);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        totalStakedByAsset[asset] += amount;

        emit Staked(msg.sender, asset, amount, amount);
    }

    function unstake(address asset, uint256 reserveAmount) external nonReentrant {
        if (reserveAmount == 0) revert ZeroAmount();
        if (!isTreasuryAsset[asset]) revert AssetNotTreasury();

        _sync(msg.sender);

        uint256 bal = balanceOf[msg.sender];
        if (bal < reserveAmount) revert InsufficientReserve();

        // 0.5% fee on the redeemed amount
        uint256 fee = (reserveAmount * UNSTAKE_FEE_BPS) / BPS_DENOMINATOR;
        uint256 toReturn = reserveAmount - fee;

        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        uint256 reserved = accumulatedFees[asset];
        uint256 available = assetBalance > reserved ? assetBalance - reserved : 0;
        if (available < toReturn) revert InsufficientAssetBalance();

        // Effects
        balanceOf[msg.sender] = bal - reserveAmount;
        totalSupply -= reserveAmount;
        accumulatedFees[asset] = reserved + fee;
        uint256 stakedAsset = totalStakedByAsset[asset];
        totalStakedByAsset[asset] =
            stakedAsset >= reserveAmount ? stakedAsset - reserveAmount : 0;

        // Interactions
        IERC20(asset).safeTransfer(msg.sender, toReturn);

        emit Unstaked(msg.sender, asset, reserveAmount, toReturn, fee);
    }

    function claim() external nonReentrant returns (uint256 rewards) {
        rewards = _sync(msg.sender);
    }

    /**************************************************************************
     * Internal – lazy rebase synchronisation
     *************************************************************************/

    function _sync(address user) internal returns (uint256 rewards) {
        uint256 idx = userIndex[user];
        if (idx == 0) {
            userIndex[user] = rebaseIndex;
            return 0;
        }
        if (idx == rebaseIndex) return 0;

        uint256 bal = balanceOf[user];
        if (bal > 0) {
            uint256 newBalance = (bal * rebaseIndex) / idx;
            if (newBalance > bal) {
                rewards = newBalance - bal;
                balanceOf[user] = newBalance;
                if (unclaimedRewards >= rewards) {
                    unclaimedRewards -= rewards;
                } else {
                    unclaimedRewards = 0;
                }
                if (rewards > 0) emit RewardsClaimed(user, rewards);
            }
        }
        userIndex[user] = rebaseIndex;
    }

    /**************************************************************************
     * Views
     *************************************************************************/

    function pendingRewards(address user) external view returns (uint256) {
        uint256 idx = userIndex[user];
        if (idx == 0 || idx == rebaseIndex) return 0;
        uint256 bal = balanceOf[user];
        if (bal == 0) return 0;
        uint256 newBalance = (bal * rebaseIndex) / idx;
        return newBalance > bal ? newBalance - bal : 0;
    }

    function pendingRebasePeriods() external view returns (uint256) {
        return (block.timestamp - lastRebaseTime) / REBASE_PERIOD;
    }

    function getTreasuryAssets() external view returns (address[] memory) {
        return treasuryAssets;
    }

    function treasuryAssetCount() external view returns (uint256) {
        return treasuryAssets.length;
    }

    function availableToRedeem(address asset) external view returns (uint256) {
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        uint256 reserved = accumulatedFees[asset];
        return assetBalance > reserved ? assetBalance - reserved : 0;
    }
}
