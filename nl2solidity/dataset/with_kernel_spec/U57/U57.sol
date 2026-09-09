// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract RewardDistributionSystem {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error AlreadyRegistered();
    error NotRegistered();
    error RewardRateExceedsMaximum(uint256 provided, uint256 maximum);
    error InsufficientRewardAddition(uint256 provided, uint256 minimum);
    error InsufficientPoolBalance(uint256 required, uint256 available);
    error NothingToClaim();
    error ZeroAmount();
    error OnlyOperator();
    error OnlyAdmin();
    error ReentrantCall();
    error SystemPaused();

    event UserRegistered(address indexed user, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardTokensAdded(address indexed by, uint256 amount, uint256 newPoolBalance);
    event RewardsPaused();
    event RewardsUnpaused();
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MAX_REWARD_RATE = 100;
    uint256 public constant MIN_REWARD_ADDITION = 50;

    IERC20 public immutable rewardToken;
    address public admin;
    address public operator;

    uint256 public rewardRatePerSecond;
    uint256 public rewardPoolBalance;
    bool public paused;

    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public accumulatedRewards;
    mapping(address => uint256) public lastAccrual;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert SystemPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address admin_, address operator_, address rewardToken_) {
        if (admin_ == address(0) || operator_ == address(0) || rewardToken_ == address(0)) {
            revert ZeroAddress();
        }
        admin = admin_;
        operator = operator_;
        rewardToken = IERC20(rewardToken_);
        _status = _NOT_ENTERED;
    }

    function register() external whenNotPaused {
        address user = msg.sender;
        if (isRegistered[user]) revert AlreadyRegistered();
        isRegistered[user] = true;
        lastAccrual[user] = block.timestamp;
        emit UserRegistered(user, block.timestamp);
    }

    function claim() external nonReentrant whenNotPaused {
        address user = msg.sender;
        if (!isRegistered[user]) revert NotRegistered();

        _settle(user);

        uint256 amount = accumulatedRewards[user];

        if (amount > 0) {
            if (amount > rewardPoolBalance) {
                revert InsufficientPoolBalance(amount, rewardPoolBalance);
            }

            // Effects
            accumulatedRewards[user] = 0;
            rewardPoolBalance -= amount;

            // Interactions
            rewardToken.safeTransfer(user, amount);
            emit RewardsClaimed(user, amount);
        } else {
            revert NothingToClaim();
        }
    }

    function getRewardBalance(address user) external view returns (uint256) {
        if (!isRegistered[user]) return 0;
        uint256 elapsed = block.timestamp - lastAccrual[user];
        return accumulatedRewards[user] + (elapsed * rewardRatePerSecond);
    }

    function getPoolBalance() external view returns (uint256) {
        return rewardPoolBalance;
    }

    function updateRewardRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_REWARD_RATE) {
            revert RewardRateExceedsMaximum(newRate, MAX_REWARD_RATE);
        }
        uint256 oldRate = rewardRatePerSecond;
        rewardRatePerSecond = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    function addRewardTokens(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_REWARD_ADDITION) {
            revert InsufficientRewardAddition(amount, MIN_REWARD_ADDITION);
        }

        uint256 balanceBefore = rewardToken.balanceOf(address(this));
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = rewardToken.balanceOf(address(this)) - balanceBefore;

        rewardPoolBalance += received;
        emit RewardTokensAdded(msg.sender, received, rewardPoolBalance);
    }

    function pauseRewards() external onlyOperator {
        paused = true;
        emit RewardsPaused();
    }

    function unpauseRewards() external onlyOperator {
        paused = false;
        emit RewardsUnpaused();
    }

    function setOperator(address newOperator) external onlyAdmin {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function _settle(address user) internal {
        uint256 last = lastAccrual[user];
        if (block.timestamp > last) {
            uint256 elapsed = block.timestamp - last;
            accumulatedRewards[user] += elapsed * rewardRatePerSecond;
            lastAccrual[user] = block.timestamp;
        }
    }
}
