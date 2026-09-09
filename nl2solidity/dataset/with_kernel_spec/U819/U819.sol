// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function invest(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external returns (uint256);
    function harvest(address token) external returns (uint256);
    function balanceOf(address token) external view returns (uint256);
}

contract YieldAggregator {
    error NotOwner();
    error ZeroAmount();
    error InsufficientBalance();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error MaxStrategiesReached();
    error InsufficientIdleBalance();
    error InvalidFeePercentage();
    error TransferFailed();
    error Reentrancy();
    error NoRewardsToClaim();
    error ApproveFailed();

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);
    event RewardClaimed(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event StrategyApproved(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event FeePercentageUpdated(uint256 newFee);
    event EmergencyWithdrawal(address indexed token, uint256 amount);
    event Invested(address indexed strategy, address indexed token, uint256 amount);
    event WithdrawnFromStrategy(address indexed strategy, address indexed token, uint256 amount);
    event Harvested(address indexed strategy, address indexed token, uint256 amount);

    address public owner;
    uint256 public feePercentage;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant MAX_STRATEGIES = 10;
    uint256 public constant REWARDS_DURATION = 7 days;

    mapping(address => bool) public approvedStrategies;
    address[] public strategyList;

    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => uint256) public totalBalances;
    mapping(address => uint256) public totalInvested;
    mapping(address => mapping(address => uint256)) public strategyInvested;

    mapping(address => uint256) public rewardPool;
    mapping(address => uint256) public rewardRate;
    mapping(address => uint256) public periodFinish;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewardPerTokenStored;
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    modifier updateReward(address token, address user) {
        rewardPerTokenStored[token] = rewardPerToken(token);
        lastUpdateTime[token] = lastTimeRewardApplicable(token);
        if (user != address(0)) {
            rewards[token][user] = earned(token, user);
            userRewardPerTokenPaid[token][user] = rewardPerTokenStored[token];
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        feePercentage = 50; // 0.5%
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        if (_feePercentage > FEE_PRECISION) revert InvalidFeePercentage();
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(_feePercentage);
    }

    function approveStrategy(address strategy) external onlyOwner {
        if (strategy == address(0)) revert StrategyNotApproved();
        if (approvedStrategies[strategy]) revert StrategyAlreadyApproved();
        if (strategyList.length >= MAX_STRATEGIES) revert MaxStrategiesReached();
        approvedStrategies[strategy] = true;
        strategyList.push(strategy);
        emit StrategyApproved(strategy);
    }

    function removeStrategy(address strategy) external onlyOwner {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        approvedStrategies[strategy] = false;
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[strategyList.length - 1];
                strategyList.pop();
                break;
            }
        }
        emit StrategyRemoved(strategy);
    }

    function deposit(address token, uint256 amount) external nonReentrant updateReward(token, msg.sender) {
        if (amount == 0) revert ZeroAmount();

        // Effects: update state before external call
        userBalances[msg.sender][token] += amount;
        totalBalances[token] += amount;

        // Interactions
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;

        // Correct state if token has transfer fees
        if (received != amount) {
            userBalances[msg.sender][token] -= amount;
            totalBalances[token] -= amount;
            userBalances[msg.sender][token] += received;
            totalBalances[token] += received;
        }

        emit Deposit(msg.sender, token, received);
    }

    function withdraw(address token, uint256 amount) external nonReentrant updateReward(token, msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (userBalances[msg.sender][token] < amount) revert InsufficientBalance();

        // Effects: update state before external calls
        userBalances[msg.sender][token] -= amount;
        totalBalances[token] -= amount;

        // Interactions
        _ensureIdleBalance(token, amount);
        _safeTransfer(token, msg.sender, amount);

        emit Withdrawal(msg.sender, token, amount);
    }

    function claimRewards(address token) external nonReentrant updateReward(token, msg.sender) {
        uint256 reward = rewards[token][msg.sender];
        if (reward == 0) revert NoRewardsToClaim();

        // Effects
        rewards[token][msg.sender] = 0;
        rewardPool[token] -= reward;

        uint256 fee = (reward * feePercentage) / FEE_PRECISION;
        uint256 netReward = reward - fee;

        // Interactions
        if (fee > 0) {
            _safeTransfer(token, owner, fee);
        }
        _safeTransfer(token, msg.sender, netReward);

        emit RewardClaimed(msg.sender, token, netReward, fee);
    }

    function invest(address token, address strategy, uint256 amount) external onlyOwner nonReentrant {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (amount == 0) revert ZeroAmount();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < rewardPool[token]) revert InsufficientBalance();
        uint256 available = balance - rewardPool[token];
        if (amount > available) revert InsufficientIdleBalance();

        // Effects: update state before external calls
        strategyInvested[strategy][token] += amount;
        totalInvested[token] += amount;

        // Interactions
        _safeApprove(token, strategy, amount);
        IStrategy(strategy).invest(token, amount);

        emit Invested(strategy, token, amount);
    }

    function withdrawFromStrategy(address token, address strategy, uint256 amount) external onlyOwner nonReentrant {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (amount == 0) revert ZeroAmount();
        if (amount > strategyInvested[strategy][token]) revert InsufficientBalance();

        // Effects: update state before external call
        strategyInvested[strategy][token] -= amount;
        totalInvested[token] -= amount;

        // Interactions
        uint256 withdrawn = IStrategy(strategy).withdraw(token, amount);

        // Correct state if actual withdrawn differs
        if (withdrawn < amount) {
            uint256 diff = amount - withdrawn;
            strategyInvested[strategy][token] += diff;
            totalInvested[token] += diff;
        } else if (withdrawn > amount) {
            uint256 diff = withdrawn - amount;
            if (diff > strategyInvested[strategy][token]) {
                strategyInvested[strategy][token] = 0;
                if (diff > totalInvested[token]) {
                    totalInvested[token] = 0;
                } else {
                    totalInvested[token] -= diff;
                }
            } else {
                strategyInvested[strategy][token] -= diff;
                totalInvested[token] -= diff;
            }
        }

        emit WithdrawnFromStrategy(strategy, token, withdrawn);
    }

    function harvest(address token, address strategy) external onlyOwner nonReentrant {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        uint256 reportedReward = IStrategy(strategy).harvest(token);
        uint256 actualReward = IERC20(token).balanceOf(address(this)) - balanceBefore;

        if (actualReward > 0) {
            // Effects
            rewardPool[token] += actualReward;
            _updateRewardRate(token, actualReward);
            emit Harvested(strategy, token, actualReward);
        }

        // Use reportedReward to avoid unused-return warning; actualReward is authoritative
        if (reportedReward > 0 && actualReward == 0) {
            // Strategy reported rewards but none materialized; no state change needed
        }
    }

    function emergencyWithdraw(address token) external onlyOwner nonReentrant {
        // Effects: update state before external calls
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strategy = strategyList[i];
            uint256 invested = strategyInvested[strategy][token];
            if (invested > 0) {
                strategyInvested[strategy][token] = 0;
                if (invested <= totalInvested[token]) {
                    totalInvested[token] -= invested;
                } else {
                    totalInvested[token] = 0;
                }

                // Interactions
                uint256 withdrawn = IStrategy(strategy).withdraw(token, invested);

                // Correct state if actual withdrawn differs
                if (withdrawn < invested) {
                    uint256 diff = invested - withdrawn;
                    strategyInvested[strategy][token] += diff;
                    totalInvested[token] += diff;
                }
            }
        }

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            _safeTransfer(token, owner, balance);
            emit EmergencyWithdrawal(token, balance);
        }
    }

    function lastTimeRewardApplicable(address token) public view returns (uint256) {
        return block.timestamp < periodFinish[token] ? block.timestamp : periodFinish[token];
    }

    function rewardPerToken(address token) public view returns (uint256) {
        uint256 totalSupply = totalBalances[token];
        if (totalSupply == 0) {
            return rewardPerTokenStored[token];
        }
        uint256 timeDelta = lastTimeRewardApplicable(token) > lastUpdateTime[token]
            ? lastTimeRewardApplicable(token) - lastUpdateTime[token]
            : 0;
        return rewardPerTokenStored[token] + (timeDelta * rewardRate[token] * 1e18) / totalSupply;
    }

    function earned(address token, address user) public view returns (uint256) {
        uint256 perTokenPaid = userRewardPerTokenPaid[token][user];
        uint256 currentPerToken = rewardPerToken(token);
        uint256 delta = currentPerToken >= perTokenPaid ? currentPerToken - perTokenPaid : 0;
        return (userBalances[user][token] * delta) / 1e18 + rewards[token][user];
    }

    function getStrategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function _ensureIdleBalance(address token, uint256 amount) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 reserved = rewardPool[token];
        if (balance < reserved) revert InsufficientBalance();
        uint256 available = balance - reserved;
        if (available < amount) {
            _withdrawFromStrategies(token, amount - available);
        }
    }

    function _withdrawFromStrategies(address token, uint256 amount) internal {
        uint256 remaining = amount;
        for (uint256 i = 0; i < strategyList.length && remaining > 0; i++) {
            address strategy = strategyList[i];
            uint256 invested = strategyInvested[strategy][token];
            if (invested == 0) continue;
            uint256 toWithdraw = invested < remaining ? invested : remaining;

            // Effects: update state before external call
            strategyInvested[strategy][token] -= toWithdraw;
            if (toWithdraw <= totalInvested[token]) {
                totalInvested[token] -= toWithdraw;
            } else {
                totalInvested[token] = 0;
            }

            // Interactions
            uint256 withdrawn = IStrategy(strategy).withdraw(token, toWithdraw);

            // Correct state if actual withdrawn differs
            if (withdrawn < toWithdraw) {
                uint256 diff = toWithdraw - withdrawn;
                strategyInvested[strategy][token] += diff;
                totalInvested[token] += diff;
            } else if (withdrawn > toWithdraw) {
                uint256 diff = withdrawn - toWithdraw;
                if (diff <= strategyInvested[strategy][token]) {
                    strategyInvested[strategy][token] -= diff;
                } else {
                    strategyInvested[strategy][token] = 0;
                }
                if (diff <= totalInvested[token]) {
                    totalInvested[token] -= diff;
                } else {
                    totalInvested[token] = 0;
                }
            }

            remaining -= withdrawn;
        }
        if (remaining > 0) revert InsufficientIdleBalance();
    }

    function _updateRewardRate(address token, uint256 reward) internal {
        if (block.timestamp >= periodFinish[token]) {
            rewardRate[token] = reward / REWARDS_DURATION;
        } else {
            uint256 remaining = periodFinish[token] - block.timestamp;
            uint256 leftover = remaining * rewardRate[token];
            rewardRate[token] = (reward + leftover) / REWARDS_DURATION;
        }
        lastUpdateTime[token] = block.timestamp;
        periodFinish[token] = block.timestamp + REWARDS_DURATION;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert ApproveFailed();
    }
}
