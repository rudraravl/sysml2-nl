// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CbEthStaking
 * @notice A staking pool for Coinbase Wrapped Staked ETH (cbETH).
 *
 * @dev Core Mechanism:
 *   Users stake cbETH and receive shares 1:1 against the principal balance.
 *   A designated reward distributor periodically adds cbETH rewards. Rewards
 *   are distributed linearly over a configurable reward duration (default 7 days)
 *   based on each user's share of the total staked principal. Users can withdraw
 *   their principal at any time and claim accumulated rewards separately. The
 *   contract enforces checks-effects-interactions, uses a reentrancy guard, and
 *   implements role-based access control for administrative functions.
 */
contract CbEthStaking {
    IERC20 public immutable cbETH;

    address public owner;
    address public rewardDistributor;
    bool public paused;

    uint256 public totalShares;
    uint256 public totalPrincipal;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public rewardDuration;

    uint256 private constant REWARD_PRECISION = 1e18;
    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 30 days;

    uint256 private _reentrancyGuard = 1;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientShares();
    error NotOwner();
    error NotRewardDistributor();
    error AlreadyPaused();
    error NotPaused();
    error ContractPaused();
    error Reentrant();
    error TransferFailed();
    error InvalidDuration();
    error RewardPeriodActive();
    error TokenNotRecoverable();

    event Staked(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardNotified(uint256 amount, uint256 rewardRate, uint256 periodFinish);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RewardDistributorUpdated(address indexed previous, address indexed updated);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event RewardDurationUpdated(uint256 previous, uint256 updated);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRewardDistributor() {
        if (msg.sender != rewardDistributor) revert NotRewardDistributor();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyGuard != 1) revert Reentrant();
        _reentrancyGuard = 2;
        _;
        _reentrancyGuard = 1;
    }

    modifier updateReward(address _account) {
        _updateReward(_account);
        _;
    }

    constructor(address _cbETH, address _rewardDistributor) {
        if (_cbETH == address(0) || _rewardDistributor == address(0)) revert ZeroAddress();

        cbETH = IERC20(_cbETH);
        owner = msg.sender;
        rewardDistributor = _rewardDistributor;
        rewardDuration = 7 days;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit RewardDistributorUpdated(address(0), _rewardDistributor);
    }

    /**
     * @notice Stakes cbETH into the pool and receives shares 1:1.
     * @param amount The amount of cbETH to stake.
     */
    function stake(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        if (amount == 0) revert ZeroAmount();

        totalPrincipal += amount;
        shares[msg.sender] += amount;
        totalShares += amount;

        _safeTransferFrom(cbETH, msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, amount);
    }

    /**
     * @notice Withdraws staked principal by burning shares.
     * @param shareAmount The number of shares to redeem for cbETH.
     */
    function withdraw(uint256 shareAmount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        if (shareAmount == 0) revert ZeroAmount();
        if (shares[msg.sender] < shareAmount) revert InsufficientShares();

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalPrincipal -= shareAmount;

        _safeTransfer(cbETH, msg.sender, shareAmount);

        emit Withdrawn(msg.sender, shareAmount, shareAmount);
    }

    /**
     * @notice Claims all accumulated cbETH rewards for the caller.
     */
    function claim() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) return;

        rewards[msg.sender] = 0;
        _safeTransfer(cbETH, msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    /**
     * @notice Withdraws all staked principal and claims all rewards for the caller.
     */
    function exit() external nonReentrant updateReward(msg.sender) {
        uint256 userShares = shares[msg.sender];
        uint256 reward = rewards[msg.sender];

        // Effects: update all state before any external interaction.
        if (userShares > 0) {
            shares[msg.sender] = 0;
            totalShares -= userShares;
            totalPrincipal -= userShares;
            emit Withdrawn(msg.sender, userShares, userShares);
        }

        if (reward > 0) {
            rewards[msg.sender] = 0;
            emit RewardPaid(msg.sender, reward);
        }

        // Interactions: perform external transfers after state is fully updated.
        if (userShares > 0) {
            _safeTransfer(cbETH, msg.sender, userShares);
        }

        if (reward > 0) {
            _safeTransfer(cbETH, msg.sender, reward);
        }
    }

    /**
     * @notice Called by the reward distributor to add cbETH rewards for the pool.
     * @param amount The reward amount in cbETH to distribute over the reward duration.
     */
    function notifyRewardAmount(uint256 amount)
        external
        nonReentrant
        onlyRewardDistributor
    {
        if (amount == 0) revert ZeroAmount();

        _safeTransferFrom(cbETH, msg.sender, address(this), amount);

        _updateReward(address(0));

        uint256 newRewardRate;
        if (block.timestamp >= periodFinish) {
            newRewardRate = amount / rewardDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            newRewardRate = (amount + leftover) / rewardDuration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardDuration;
        rewardRate = newRewardRate;

        emit RewardNotified(amount, newRewardRate, periodFinish);
    }

    /**
     * @notice Transfers ownership of the staking contract.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @notice Updates the reward distributor address.
     * @param _rewardDistributor The new reward distributor address.
     */
    function setRewardDistributor(address _rewardDistributor) external onlyOwner {
        if (_rewardDistributor == address(0)) revert ZeroAddress();

        address previous = rewardDistributor;
        rewardDistributor = _rewardDistributor;

        emit RewardDistributorUpdated(previous, _rewardDistributor);
    }

    /**
     * @notice Updates the reward duration. Can only be changed between reward periods.
     * @param _duration New reward duration in seconds.
     */
    function setRewardDuration(uint256 _duration) external onlyOwner {
        if (block.timestamp <= periodFinish) revert RewardPeriodActive();
        if (_duration < MIN_DURATION || _duration > MAX_DURATION) revert InvalidDuration();

        uint256 previous = rewardDuration;
        rewardDuration = _duration;

        emit RewardDurationUpdated(previous, _duration);
    }

    /**
     * @notice Pauses new deposits.
     */
    function pause() external onlyOwner {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpauses deposits.
     */
    function unpause() external onlyOwner {
        if (!paused) revert NotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Recovers ERC20 tokens sent to the contract by mistake, excluding cbETH.
     * @param token The ERC20 token address.
     * @param to The recipient of the recovered tokens.
     * @param amount The amount to recover.
     */
    function recoverToken(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(cbETH)) revert TokenNotRecoverable();
        if (to == address(0)) revert ZeroAddress();

        _safeTransfer(IERC20(token), to, amount);
        emit Recovered(token, to, amount);
    }

    /**
     * @notice Returns the total amount of cbETH held by this contract.
     */
    function totalUnderlying() external view returns (uint256) {
        return cbETH.balanceOf(address(this));
    }

    /**
     * @notice Returns the total number of shares outstanding.
     */
    function totalSupply() external view returns (uint256) {
        return totalShares;
    }

    /**
     * @notice Returns the share balance of an account.
     */
    function balanceOf(address account) external view returns (uint256) {
        return shares[account];
    }

    /**
     * @notice Returns the last timestamp in the current reward period applicable for accrual.
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Returns the current reward amount per staked share.
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalShares == 0) return rewardPerTokenStored;

        uint256 effectiveLastTime = lastTimeRewardApplicable();
        uint256 timeElapsed = effectiveLastTime - lastUpdateTime;

        return rewardPerTokenStored + ((timeElapsed * rewardRate * REWARD_PRECISION) / totalShares);
    }

    /**
     * @notice Returns the currently earned reward for an account.
     * @param account The user address.
     */
    function earned(address account) public view returns (uint256) {
        return _earned(account, rewardPerToken());
    }

    /**
     * @notice Returns the total reward amount distributed over the current reward duration.
     */
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardDuration;
    }

    function _updateReward(address account) internal {
        uint256 currentRewardPerToken = rewardPerToken();

        rewardPerTokenStored = currentRewardPerToken;
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = _earned(account, currentRewardPerToken);
            userRewardPerTokenPaid[account] = currentRewardPerToken;
        }
    }

    function _earned(address account, uint256 currentRewardPerToken) internal view returns (uint256) {
        uint256 accumulated = (shares[account] * (currentRewardPerToken - userRewardPerTokenPaid[account])) / REWARD_PRECISION;
        return rewards[account] + accumulated;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );

        if (!success || (returndata.length != 0 && !abi.decode(returndata, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );

        if (!success || (returndata.length != 0 && !abi.decode(returndata, (bool)))) {
            revert TransferFailed();
        }
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
