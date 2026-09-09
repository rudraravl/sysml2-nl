Looking at the errors, all four basic operations (deposit, withdraw, commit, claim) are reverting. The common cause is likely the `SafeERC20` library not properly handling tokens that don't return a `bool` value from `transfer`/`transferFrom` (a common issue with mock tokens in test harnesses). The simple `bool ok = token.transfer(...)` approach decodes empty return data as `false`, causing spurious reverts. I'll rewrite `SafeERC20` to use low-level calls with proper return data handling.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert SafeTransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert SafeTransferFailed();
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert SafeTransferFromFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert SafeTransferFromFailed();
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    constructor() {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert ExpectedPause();
        _;
    }

    function _pause() internal {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract IncentivizedActionMarket is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Action {
        uint256 id;
        string name;
        uint256 multiplier;
        bool active;
    }

    struct AccountState {
        uint256 collateralBalance;
        uint256 uncommittedCollateral;
        uint256 claimedRewards;
    }

    uint256 public constant MIN_COMMIT_COLLATERAL = 100;
    uint256 public constant FEE_BPS = 500;
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant ACC_REWARD_PRECISION = 1e18;

    IERC20 public immutable collateralToken;
    IERC20 public immutable rewardToken;
    address public treasury;

    uint256 public rewardRate;
    uint256 public nextActionId;

    mapping(uint256 => Action) public actions;
    mapping(uint256 => uint256) public totalCommittedPerAction;
    mapping(uint256 => uint256) public accRewardPerShare;
    mapping(uint256 => uint256) public lastUpdateTimestamp;

    mapping(address => AccountState) public accounts;
    mapping(address => mapping(uint256 => uint256)) public userCommitted;
    mapping(address => mapping(uint256 => uint256)) public userRewardDebt;

    event Deposit(address indexed account, uint256 amount, uint256 newBalance);
    event Withdraw(address indexed account, uint256 amount, uint256 newBalance);
    event ActionCommitted(address indexed account, uint256 indexed actionId, uint256 amount);
    event ActionUncommitted(address indexed account, uint256 indexed actionId, uint256 amount);
    event RewardClaimed(address indexed account, uint256 grossReward, uint256 fee, uint256 netReward);
    event ActionCreated(uint256 indexed actionId, string name, uint256 multiplier);
    event ActionUpdated(uint256 indexed actionId, uint256 multiplier, bool active);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientUncommitted();
    error ActionNotFound();
    error ActionNotActive();
    error BelowMinCommit();
    error NothingToClaim();
    error InvalidMultiplier();
    error InvalidName();

    constructor(
        address _collateralToken,
        address _rewardToken,
        address _treasury,
        uint256 _rewardRate
    ) {
        if (_collateralToken == address(0) || _rewardToken == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        collateralToken = IERC20(_collateralToken);
        rewardToken = IERC20(_rewardToken);
        treasury = _treasury;
        rewardRate = _rewardRate;
        emit TreasuryUpdated(address(0), _treasury);
        emit RewardRateUpdated(0, _rewardRate);
    }

    function createAction(string calldata name, uint256 multiplier)
        external
        onlyOwner
        returns (uint256 actionId)
    {
        if (multiplier == 0) revert InvalidMultiplier();
        if (bytes(name).length == 0) revert InvalidName();
        actionId = nextActionId++;
        actions[actionId] = Action({
            id: actionId,
            name: name,
            multiplier: multiplier,
            active: true
        });
        lastUpdateTimestamp[actionId] = block.timestamp;
        emit ActionCreated(actionId, name, multiplier);
    }

    function updateAction(uint256 actionId, uint256 multiplier, bool active) external onlyOwner {
        if (actionId >= nextActionId) revert ActionNotFound();
        if (multiplier == 0) revert InvalidMultiplier();
        _updateActionIndex(actionId);
        actions[actionId].multiplier = multiplier;
        actions[actionId].active = active;
        emit ActionUpdated(actionId, multiplier, active);
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        for (uint256 i = 0; i < nextActionId; i++) {
            if (actions[i].active) {
                _updateActionIndex(i);
            }
        }
        emit RewardRateUpdated(rewardRate, newRate);
        rewardRate = newRate;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _updateAllActionIndicesFor(msg.sender);

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        accounts[msg.sender].collateralBalance += amount;
        accounts[msg.sender].uncommittedCollateral += amount;

        emit Deposit(msg.sender, amount, accounts[msg.sender].collateralBalance);
    }

    function commitAction(uint256 actionId, uint256 amount) external nonReentrant whenNotPaused {
        if (actionId >= nextActionId) revert ActionNotFound();
        if (!actions[actionId].active) revert ActionNotActive();
        if (amount < MIN_COMMIT_COLLATERAL) revert BelowMinCommit();
        if (accounts[msg.sender].uncommittedCollateral < amount) revert InsufficientUncommitted();

        _updateActionIndex(actionId);

        accounts[msg.sender].uncommittedCollateral -= amount;
        userCommitted[msg.sender][actionId] += amount;
        totalCommittedPerAction[actionId] += amount;

        userRewardDebt[msg.sender][actionId] =
            (userCommitted[msg.sender][actionId] * accRewardPerShare[actionId]) / ACC_REWARD_PRECISION;

        emit ActionCommitted(msg.sender, actionId, amount);
    }

    function uncommitAction(uint256 actionId, uint256 amount) external nonReentrant whenNotPaused {
        if (actionId >= nextActionId) revert ActionNotFound();
        if (amount == 0) revert ZeroAmount();
        if (userCommitted[msg.sender][actionId] < amount) revert InsufficientBalance();

        _updateActionIndex(actionId);

        _claimActionRewards(msg.sender, actionId);

        userCommitted[msg.sender][actionId] -= amount;
        totalCommittedPerAction[actionId] -= amount;
        accounts[msg.sender].uncommittedCollateral += amount;

        userRewardDebt[msg.sender][actionId] =
            (userCommitted[msg.sender][actionId] * accRewardPerShare[actionId]) / ACC_REWARD_PRECISION;

        emit ActionUncommitted(msg.sender, actionId, amount);
    }

    function claimRewards() external nonReentrant whenNotPaused returns (uint256 netReward) {
        _updateAllActionIndicesFor(msg.sender);

        uint256 totalEarned;
        for (uint256 i = 0; i < nextActionId; i++) {
            if (userCommitted[msg.sender][i] > 0) {
                totalEarned += _pendingActionRewards(msg.sender, i);
                userRewardDebt[msg.sender][i] =
                    (userCommitted[msg.sender][i] * accRewardPerShare[i]) / ACC_REWARD_PRECISION;
            }
        }

        if (totalEarned == 0) revert NothingToClaim();

        uint256 fee = (totalEarned * FEE_BPS) / BPS_DENOM;
        netReward = totalEarned - fee;

        accounts[msg.sender].claimedRewards += totalEarned;

        rewardToken.safeTransfer(treasury, fee);
        rewardToken.safeTransfer(msg.sender, netReward);

        emit RewardClaimed(msg.sender, totalEarned, fee, netReward);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (accounts[msg.sender].uncommittedCollateral < amount) revert InsufficientUncommitted();

        _updateAllActionIndicesFor(msg.sender);

        accounts[msg.sender].uncommittedCollateral -= amount;
        accounts[msg.sender].collateralBalance -= amount;

        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, accounts[msg.sender].collateralBalance);
    }

    function pendingRewards(address account) external view returns (uint256 total) {
        for (uint256 i = 0; i < nextActionId; i++) {
            if (userCommitted[account][i] > 0) {
                total += _pendingActionRewardsView(account, i);
            }
        }
    }

    function pendingActionRewards(address account, uint256 actionId)
        external
        view
        returns (uint256)
    {
        return _pendingActionRewardsView(account, actionId);
    }

    function getAction(uint256 actionId) external view returns (Action memory) {
        return actions[actionId];
    }

    function getUserCommitted(address account, uint256 actionId) external view returns (uint256) {
        return userCommitted[account][actionId];
    }

    function getUncommittedCollateral(address account) external view returns (uint256) {
        return accounts[account].uncommittedCollateral;
    }

    function _updateActionIndex(uint256 actionId) internal {
        uint256 lastTs = lastUpdateTimestamp[actionId];
        if (block.timestamp <= lastTs) return;

        uint256 totalCommitted = totalCommittedPerAction[actionId];
        if (totalCommitted == 0) {
            lastUpdateTimestamp[actionId] = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastTs;
        uint256 rewards = (rewardRate * actions[actionId].multiplier * elapsed) / BPS_DENOM;
        accRewardPerShare[actionId] += (rewards * ACC_REWARD_PRECISION) / totalCommitted;
        lastUpdateTimestamp[actionId] = block.timestamp;
    }

    function _updateAllActionIndicesFor(address account) internal {
        for (uint256 i = 0; i < nextActionId; i++) {
            _updateActionIndex(i);
            if (userCommitted[account][i] > 0) {
                userRewardDebt[account][i] =
                    (userCommitted[account][i] * accRewardPerShare[i]) / ACC_REWARD_PRECISION;
            }
        }
    }

    function _pendingActionRewards(address account, uint256 actionId)
        internal
        view
        returns (uint256)
    {
        uint256 committed = userCommitted[account][actionId];
        if (committed == 0) return 0;
        uint256 accumulated = (committed * accRewardPerShare[actionId]) / ACC_REWARD_PRECISION;
        return accumulated > userRewardDebt[account][actionId]
            ? accumulated - userRewardDebt[account][actionId]
            : 0;
    }

    function _pendingActionRewardsView(address account, uint256 actionId)
        internal
        view
        returns (uint256)
    {
        uint256 committed = userCommitted[account][actionId];
        if (committed == 0) return 0;

        uint256 currentAcc = accRewardPerShare[actionId];
        uint256 lastTs = lastUpdateTimestamp[actionId];
        uint256 totalCommitted = totalCommittedPerAction[actionId];

        if (block.timestamp > lastTs && totalCommitted > 0) {
            uint256 elapsed = block.timestamp - lastTs;
            uint256 rewards = (rewardRate * actions[actionId].multiplier * elapsed) / BPS_DENOM;
            currentAcc += (rewards * ACC_REWARD_PRECISION) / totalCommitted;
        }

        uint256 accumulated = (committed * currentAcc) / ACC_REWARD_PRECISION;
        return accumulated > userRewardDebt[account][actionId]
            ? accumulated - userRewardDebt[account][actionId]
            : 0;
    }

    function _claimActionRewards(address account, uint256 actionId) internal {
        uint256 earned = _pendingActionRewards(account, actionId);
        if (earned == 0) return;

        uint256 fee = (earned * FEE_BPS) / BPS_DENOM;
        uint256 net = earned - fee;

        accounts[account].claimedRewards += earned;
        rewardToken.safeTransfer(treasury, fee);
        rewardToken.safeTransfer(account, net);

        emit RewardClaimed(account, earned, fee, net);
    }
}
