// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract PortfolioManagementVault {
    error NotOwner();
    error ZeroAddress();
    error TokenNotSupported();
    error TokenAlreadySupported();
    error InsufficientDeposit();
    error InsufficientShares();
    error ZeroShares();
    error InvalidAllocation();
    error InvalidFee();
    error StrategyAlreadyExists();
    error StrategyNotFound();
    error InsufficientRewardBalance();
    error NothingToClaim();
    error TransferFailed();
    error SameOwner();
    error ReentrantCall();

    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 sharesBurned, address[] tokens, uint256[] amounts);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardDistributed(address indexed from, uint256 amount);
    event ManagementFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event ManagementFeeAccrued(uint256 sharesMinted);
    event TokenSupported(address indexed token);
    event TokenRemoved(address indexed token);
    event StrategyAdded(address indexed strategy, uint256 allocationBps);
    event StrategyRemoved(address indexed strategy);
    event StrategyAllocationUpdated(address indexed strategy, uint256 oldAllocationBps, uint256 newAllocationBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant REWARD_SHARE_MULTIPLIER = 1e18;

    address public owner;
    IERC20 public immutable rewardToken;
    uint256 public managementFeeBps;
    uint256 public lastFeeAccrual;
    uint256 public totalAccruedFeeShares;

    mapping(address => bool) public isSupportedToken;
    address[] public supportedTokens;

    uint256 public totalShares;
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userDeposits;

    struct Strategy {
        address id;
        uint256 allocationBps;
        bool active;
    }
    Strategy[] public strategies;
    uint256 public totalActiveAllocationBps;

    uint256 public rewardPerShareStored;
    mapping(address => uint256) public userRewardPaid;
    mapping(address => uint256) public userRewardPending;

    uint256 private _locked = 1;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _rewardToken) {
        if (_rewardToken == address(0)) revert ZeroAddress();
        owner = msg.sender;
        rewardToken = IERC20(_rewardToken);
        managementFeeBps = 50; // 0.5% annually
        lastFeeAccrual = block.timestamp;
        emit ManagementFeeUpdated(0, 50);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function _updateReward(address user) internal {
        uint256 shares = userShares[user];
        if (shares > 0) {
            uint256 pending = (shares * rewardPerShareStored) / REWARD_SHARE_MULTIPLIER;
            userRewardPending[user] += pending - userRewardPaid[user];
            userRewardPaid[user] = pending;
        } else {
            userRewardPaid[user] = 0;
        }
    }

    function _mintShares(address to, uint256 amount) internal {
        _updateReward(to);
        totalShares += amount;
        userShares[to] += amount;
        userRewardPaid[to] = (userShares[to] * rewardPerShareStored) / REWARD_SHARE_MULTIPLIER;
    }

    function _burnShares(address from, uint256 amount) internal {
        _updateReward(from);
        userShares[from] -= amount;
        totalShares -= amount;
        userRewardPaid[from] = (userShares[from] * rewardPerShareStored) / REWARD_SHARE_MULTIPLIER;
    }

    function _accrueManagementFee() internal {
        if (totalShares <= 0) {
            lastFeeAccrual = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastFeeAccrual;
        if (elapsed <= 0) return;
        uint256 feeShares = (totalShares * managementFeeBps * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        if (feeShares <= 0) return;
        _mintShares(owner, feeShares);
        totalAccruedFeeShares += feeShares;
        lastFeeAccrual = block.timestamp;
        emit ManagementFeeAccrued(feeShares);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (!isSupportedToken[token]) revert TokenNotSupported();
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();

        _accrueManagementFee();

        uint256 balBefore = IERC20(token).balanceOf(address(this));
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        uint256 balAfter = IERC20(token).balanceOf(address(this));
        uint256 received = balAfter - balBefore;

        userDeposits[msg.sender] += received;
        _mintShares(msg.sender, received);

        emit Deposit(msg.sender, token, received, received);
    }

    function withdraw(uint256 sharesToBurn) external nonReentrant {
        if (sharesToBurn == 0) revert ZeroShares();
        if (userShares[msg.sender] < sharesToBurn) revert InsufficientShares();

        _accrueManagementFee();
        uint256 denominator = totalShares;
        _burnShares(msg.sender, sharesToBurn);

        address[] memory tokens = supportedTokens;
        uint256[] memory amounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 bal = IERC20(tokens[i]).balanceOf(address(this));
            uint256 amountOut = (bal * sharesToBurn) / denominator;
            amounts[i] = amountOut;
            if (amountOut > 0) {
                if (!IERC20(tokens[i]).transfer(msg.sender, amountOut)) revert TransferFailed();
            }
        }
        emit Withdraw(msg.sender, sharesToBurn, tokens, amounts);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 pending = userRewardPending[msg.sender];
        if (pending <= 0) revert NothingToClaim();
        userRewardPending[msg.sender] = 0;
        uint256 bal = rewardToken.balanceOf(address(this));
        if (bal < pending) revert InsufficientRewardBalance();
        if (!rewardToken.transfer(msg.sender, pending)) revert TransferFailed();
        emit RewardClaimed(msg.sender, pending);
    }

    function distributeRewards(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert InsufficientDeposit();
        if (totalShares == 0) revert ZeroShares();
        uint256 balBefore = rewardToken.balanceOf(address(this));
        if (!rewardToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        uint256 balAfter = rewardToken.balanceOf(address(this));
        uint256 received = balAfter - balBefore;
        rewardPerShareStored += (received * REWARD_SHARE_MULTIPLIER) / totalShares;
        emit RewardDistributed(msg.sender, received);
    }

    function addSupportedToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (isSupportedToken[token]) revert TokenAlreadySupported();
        isSupportedToken[token] = true;
        supportedTokens.push(token);
        emit TokenSupported(token);
    }

    function removeSupportedToken(address token) external onlyOwner {
        if (!isSupportedToken[token]) revert TokenNotSupported();
        isSupportedToken[token] = false;
        emit TokenRemoved(token);
    }

    function setManagementFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > BPS_DENOMINATOR) revert InvalidFee();
        _accrueManagementFee();
        uint256 old = managementFeeBps;
        managementFeeBps = newFeeBps;
        emit ManagementFeeUpdated(old, newFeeBps);
    }

    function addStrategy(address strategyId, uint256 allocationBps) external onlyOwner {
        if (strategyId == address(0)) revert ZeroAddress();
        if (allocationBps == 0 || allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].id == strategyId) revert StrategyAlreadyExists();
        }
        if (totalActiveAllocationBps + allocationBps > BPS_DENOMINATOR) revert InvalidAllocation();
        strategies.push(Strategy(strategyId, allocationBps, true));
        totalActiveAllocationBps += allocationBps;
        emit StrategyAdded(strategyId, allocationBps);
    }

    function removeStrategy(address strategyId) external onlyOwner {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].id == strategyId && strategies[i].active) {
                totalActiveAllocationBps -= strategies[i].allocationBps;
                strategies[i].active = false;
                emit StrategyRemoved(strategyId);
                return;
            }
        }
        revert StrategyNotFound();
    }

    function updateStrategyAllocation(address strategyId, uint256 newAllocationBps) external onlyOwner {
        if (newAllocationBps > BPS_DENOMINATOR) revert InvalidAllocation();
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].id == strategyId && strategies[i].active) {
                uint256 old = strategies[i].allocationBps;
                uint256 newTotal = totalActiveAllocationBps - old + newAllocationBps;
                if (newTotal > BPS_DENOMINATOR) revert InvalidAllocation();
                totalActiveAllocationBps = newTotal;
                strategies[i].allocationBps = newAllocationBps;
                emit StrategyAllocationUpdated(strategyId, old, newAllocationBps);
                return;
            }
        }
        revert StrategyNotFound();
    }

    function transferOwnership(address newOwner) external onlyOwner nonReentrant {
        if (newOwner == address(0)) revert ZeroAddress();
        if (newOwner == owner) revert SameOwner();
        _accrueManagementFee();
        _updateReward(owner);
        _updateReward(newOwner);

        uint256 ownerShareBal = userShares[owner];
        uint256 ownerPending = userRewardPending[owner];

        if (ownerShareBal > 0) {
            userShares[owner] = 0;
            userShares[newOwner] += ownerShareBal;
        }
        if (ownerPending > 0) {
            userRewardPending[owner] = 0;
            userRewardPending[newOwner] += ownerPending;
        }
        userRewardPaid[newOwner] = (userShares[newOwner] * rewardPerShareStored) / REWARD_SHARE_MULTIPLIER;
        userRewardPaid[owner] = 0;

        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function supportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }

    function strategiesLength() external view returns (uint256) {
        return strategies.length;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getStrategies() external view returns (Strategy[] memory) {
        return strategies;
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 shares = userShares[user];
        uint256 accrued = (shares * rewardPerShareStored) / REWARD_SHARE_MULTIPLIER;
        uint256 delta = accrued > userRewardPaid[user] ? accrued - userRewardPaid[user] : 0;
        return userRewardPending[user] + delta;
    }

    function vaultBalanceOf(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function userSharePercentage(address user) external view returns (uint256) {
        if (totalShares <= 0) return 0;
        return (userShares[user] * BPS_DENOMINATOR) / totalShares;
    }
}
