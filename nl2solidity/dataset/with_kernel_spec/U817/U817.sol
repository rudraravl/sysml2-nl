// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Minimal ERC20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Collection of functions related to the address type.
 */
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), errorMessage);
        (bool success, bytes memory returndata) = target.call(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

/**
 * @dev Wrappers around ERC20 operations that revert on failure.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title GamingRewards
 * @notice Manages an ERC20 reward token for a gaming platform. Users register,
 *         earn engagement rewards (credited by the admin), claim up to a daily
 *         cap, and stake tokens to accrue bonus rewards over time.
 */
contract GamingRewards is ReentrancyGuard {
    using SafeERC20 for IERC20;

    //-----------------------------------------------------------------------
    // Errors
    //-----------------------------------------------------------------------
    error CallerNotAdmin();
    error ZeroAddress();
    error ZeroAmount();
    error AlreadyRegistered();
    error NotRegistered();
    error InsufficientEarned();
    error InsufficientStakedBalance();
    error InsufficientRewardPool();
    error DailyClaimLimitExceeded(uint256 requested, uint256 available);

    //-----------------------------------------------------------------------
    // Constants
    //-----------------------------------------------------------------------
    uint256 public constant MAX_DAILY_CLAIM = 100e18;
    uint256 public constant BASE_REWARD_RATE = 5e18;
    uint256 private constant SECONDS_PER_DAY = 1 days;
    uint256 private constant BONUS_PRECISION = 1e18;

    //-----------------------------------------------------------------------
    // State
    //-----------------------------------------------------------------------
    IERC20 public immutable rewardToken;
    address public admin;

    /// @notice Tokens granted per eligible engagement action.
    uint256 public rewardRate;

    /// @notice Bonus tokens accrued per staked token per second (scaled by 1e18).
    uint256 public stakingBonusRatePerSecond;

    /// @notice Total tokens held by the contract earmarked for reward distribution.
    uint256 public rewardPoolBalance;

    /// @notice Total tokens currently staked by all users.
    uint256 public totalStaked;

    struct UserInfo {
        bool isRegistered;
        uint256 earnedBalance;
        uint256 stakedBalance;
        uint256 stakingBonus;
        uint256 lastBonusTimestamp;
        uint256 lastClaimDay;
        uint256 claimedToday;
    }

    mapping(address => UserInfo) private users;

    //-----------------------------------------------------------------------
    // Events
    //-----------------------------------------------------------------------
    event UserRegistered(address indexed user);
    event EngagementRewarded(address indexed user, uint256 actions, uint256 reward);
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount);
    event BonusClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event StakingBonusRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardPoolFunded(address indexed funder, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    //-----------------------------------------------------------------------
    // Modifiers
    //-----------------------------------------------------------------------
    modifier onlyAdmin() {
        if (msg.sender != admin) revert CallerNotAdmin();
        _;
    }

    modifier onlyRegistered() {
        if (!users[msg.sender].isRegistered) revert NotRegistered();
        _;
    }

    //-----------------------------------------------------------------------
    // Constructor
    //-----------------------------------------------------------------------
    constructor(address _rewardToken, address _admin) {
        if (_rewardToken == address(0) || _admin == address(0)) revert ZeroAddress();
        rewardToken = IERC20(_rewardToken);
        admin = _admin;
        rewardRate = BASE_REWARD_RATE;
        stakingBonusRatePerSecond = 1e14;
    }

    //-----------------------------------------------------------------------
    // Admin functions
    //-----------------------------------------------------------------------

    function setRewardRate(uint256 newRate) external onlyAdmin {
        if (newRate == 0) revert ZeroAmount();
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    function setStakingBonusRate(uint256 newRate) external onlyAdmin {
        uint256 oldRate = stakingBonusRatePerSecond;
        stakingBonusRatePerSecond = newRate;
        emit StakingBonusRateUpdated(oldRate, newRate);
    }

    function fundRewardPool(uint256 amount) external onlyAdmin {
        if (amount == 0) revert ZeroAmount();
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        rewardPoolBalance += amount;
        emit RewardPoolFunded(msg.sender, amount);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }

    function accrueReward(address user, uint256 actionCount) external onlyAdmin {
        if (!users[user].isRegistered) revert NotRegistered();
        if (actionCount == 0) revert ZeroAmount();

        uint256 reward = actionCount * rewardRate;
        users[user].earnedBalance += reward;

        emit EngagementRewarded(user, actionCount, reward);
    }

    //-----------------------------------------------------------------------
    // User functions
    //-----------------------------------------------------------------------

    function register() external {
        if (users[msg.sender].isRegistered) revert AlreadyRegistered();
        users[msg.sender].isRegistered = true;
        users[msg.sender].lastBonusTimestamp = block.timestamp;
        emit UserRegistered(msg.sender);
    }

    function claim(uint256 amount) external nonReentrant onlyRegistered {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage u = users[msg.sender];

        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        if (u.lastClaimDay != currentDay) {
            u.lastClaimDay = currentDay;
            u.claimedToday = 0;
        }

        uint256 remainingDaily = MAX_DAILY_CLAIM - u.claimedToday;
        if (amount > remainingDaily) revert DailyClaimLimitExceeded(amount, remainingDaily);
        if (amount > u.earnedBalance) revert InsufficientEarned();
        if (amount > rewardPoolBalance) revert InsufficientRewardPool();

        u.earnedBalance -= amount;
        u.claimedToday += amount;
        rewardPoolBalance -= amount;

        rewardToken.safeTransfer(msg.sender, amount);
        emit TokensClaimed(msg.sender, amount);
    }

    function stake(uint256 amount) external nonReentrant onlyRegistered {
        if (amount == 0) revert ZeroAmount();

        _accrueBonus(msg.sender);

        UserInfo storage u = users[msg.sender];
        u.stakedBalance += amount;
        totalStaked += amount;

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit TokensStaked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant onlyRegistered {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage u = users[msg.sender];
        if (amount > u.stakedBalance) revert InsufficientStakedBalance();

        _accrueBonus(msg.sender);

        u.stakedBalance -= amount;
        totalStaked -= amount;

        rewardToken.safeTransfer(msg.sender, amount);
        emit TokensUnstaked(msg.sender, amount);
    }

    function claimBonus() external nonReentrant onlyRegistered {
        _accrueBonus(msg.sender);

        UserInfo storage u = users[msg.sender];
        uint256 bonus = u.stakingBonus;
        if (bonus == 0) revert ZeroAmount();
        if (bonus > rewardPoolBalance) revert InsufficientRewardPool();

        u.stakingBonus = 0;
        rewardPoolBalance -= bonus;

        rewardToken.safeTransfer(msg.sender, bonus);
        emit BonusClaimed(msg.sender, bonus);
    }

    //-----------------------------------------------------------------------
    // Internal helpers
    //-----------------------------------------------------------------------

    function _accrueBonus(address userAddr) internal {
        UserInfo storage u = users[userAddr];
        if (u.stakedBalance == 0) {
            u.lastBonusTimestamp = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - u.lastBonusTimestamp;
        // Accrue bonus only when a positive amount of time has elapsed,
        // avoiding strict equality checks against zero.
        if (elapsed > 0) {
            uint256 bonus = (u.stakedBalance * stakingBonusRatePerSecond * elapsed) / BONUS_PRECISION;
            u.stakingBonus += bonus;
            u.lastBonusTimestamp = block.timestamp;
        }
    }

    //-----------------------------------------------------------------------
    // View functions
    //-----------------------------------------------------------------------

    function getPendingBonus(address userAddr) external view returns (uint256) {
        UserInfo storage u = users[userAddr];
        if (u.stakedBalance == 0) return u.stakingBonus;
        uint256 elapsed = block.timestamp - u.lastBonusTimestamp;
        uint256 pending = (u.stakedBalance * stakingBonusRatePerSecond * elapsed) / BONUS_PRECISION;
        return u.stakingBonus + pending;
    }

    function getRemainingDailyClaim(address userAddr) external view returns (uint256 remaining) {
        UserInfo storage u = users[userAddr];
        if (!u.isRegistered) return 0;

        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        uint256 claimed = (u.lastClaimDay != currentDay) ? 0 : u.claimedToday;

        if (claimed >= MAX_DAILY_CLAIM) return 0;
        remaining = MAX_DAILY_CLAIM - claimed;
    }

    function getUserInfo(address userAddr)
        external
        view
        returns (
            bool isRegistered,
            uint256 earnedBalance,
            uint256 stakedBalance,
            uint256 stakingBonus,
            uint256 claimedToday
        )
    {
        UserInfo storage u = users[userAddr];
        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        uint256 claimed = (u.lastClaimDay != currentDay) ? 0 : u.claimedToday;

        return (
            u.isRegistered,
            u.earnedBalance,
            u.stakedBalance,
            u.stakingBonus,
            claimed
        );
    }
}
