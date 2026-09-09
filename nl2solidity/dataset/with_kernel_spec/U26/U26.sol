// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

contract TreasuryDistributor {
    using SafeERC20 for IERC20;

    uint256 private constant ACC_PRECISION = 1e18;
    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_RATE_BPS = 500; // 5%
    uint256 public constant MIN_INTERVAL = 24 hours;
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    error NotOperator();
    error NotSupportedToken();
    error AlreadySupported();
    error RateTooHigh();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientStake();
    error DistributionTooSoon();
    error NothingToDistribute();
    error NoStakers();
    error InvalidStakingToken();
    error ReentrancyDetected();

    event TokenSupported(address indexed token);
    event DistributionRateUpdated(uint256 oldRate, uint256 newRate);
    event Deposited(address indexed token, address indexed from, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event DistributionExecuted(uint256 totalDistributedValue, uint256 timestamp);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    address public operator;
    address public immutable stakingToken;

    uint256 public distributionRateBps;
    uint256 public lastDistributionTime;
    uint256 private _reentrancyStatus = NOT_ENTERED;

    address[] public supportedTokens;
    mapping(address => bool) public isSupported;

    mapping(address => uint256) public tokenBalances;

    uint256 public totalStaked;
    mapping(address => uint256) public userStake;

    mapping(address => uint256) public accTokenPerShare;
    mapping(address => mapping(address => uint256)) public userRewardDebt;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus != NOT_ENTERED) revert ReentrancyDetected();
        _reentrancyStatus = ENTERED;
        _;
        _reentrancyStatus = NOT_ENTERED;
    }

    constructor(address _stakingToken, address _operator, uint256 _initialRateBps) {
        if (_stakingToken == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_initialRateBps > MAX_RATE_BPS) revert RateTooHigh();
        stakingToken = _stakingToken;
        operator = _operator;
        distributionRateBps = _initialRateBps;
        lastDistributionTime = block.timestamp;
        emit OperatorUpdated(address(0), _operator);
    }

    function supportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function pendingReward(address user, address token) public view returns (uint256) {
        if (!isSupported[token]) return 0;
        uint256 stake = userStake[user];
        if (stake < 1) return 0;
        uint256 accrued = (stake * accTokenPerShare[token]) / ACC_PRECISION;
        uint256 debt = userRewardDebt[token][user];
        if (accrued <= debt) return 0;
        return accrued - debt;
    }

    function _updateUserDebt(address user) internal {
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; ++i) {
            address token = supportedTokens[i];
            userRewardDebt[token][user] = (userStake[user] * accTokenPerShare[token]) / ACC_PRECISION;
        }
    }

    function addSupportedToken(address token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (token == stakingToken) revert InvalidStakingToken();
        if (isSupported[token]) revert AlreadySupported();
        isSupported[token] = true;
        supportedTokens.push(token);
        emit TokenSupported(token);
    }

    function setDistributionRate(uint256 newRateBps) external onlyOperator {
        if (newRateBps > MAX_RATE_BPS) revert RateTooHigh();
        uint256 old = distributionRateBps;
        distributionRateBps = newRateBps;
        emit DistributionRateUpdated(old, newRateBps);
    }

    function depositToken(address token, uint256 amount) external nonReentrant {
        if (!isSupported[token]) revert NotSupportedToken();
        if (amount < 1) revert ZeroAmount();

        // Effects: update accounting optimistically
        tokenBalances[token] += amount;

        // Interaction
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(token, msg.sender, amount);
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();

        // Effects: settle pending rewards before changing stake
        _updateUserDebt(msg.sender);

        // Update stake accounting before transfer (checks-effects-interactions)
        userStake[msg.sender] += amount;
        totalStaked += amount;

        // Recompute debt with new stake
        _updateUserDebt(msg.sender);

        // Interaction
        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) public nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (userStake[msg.sender] < amount) revert InsufficientStake();

        // Effects: settle pending rewards before changing stake
        _updateUserDebt(msg.sender);

        userStake[msg.sender] -= amount;
        totalStaked -= amount;

        // Recompute debt with new stake
        _updateUserDebt(msg.sender);

        // Interaction
        IERC20(stakingToken).safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function withdrawRewards() public nonReentrant {
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; ++i) {
            address token = supportedTokens[i];
            uint256 pending = pendingReward(msg.sender, token);
            if (pending < 1) continue;

            // Effects: update debt and balance before transfer
            userRewardDebt[token][msg.sender] += pending;
            tokenBalances[token] -= pending;

            // Interaction
            IERC20(token).safeTransfer(msg.sender, pending);

            emit Withdrawn(msg.sender, token, pending);
        }
    }

    function exit() external nonReentrant {
        uint256 amount = userStake[msg.sender];
        if (amount > 0) {
            // Effects
            _updateUserDebt(msg.sender);
            userStake[msg.sender] = 0;
            totalStaked -= amount;
            _updateUserDebt(msg.sender);

            // Interaction
            IERC20(stakingToken).safeTransfer(msg.sender, amount);
            emit Unstaked(msg.sender, amount);
        }

        // Withdraw all pending rewards
        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; ++i) {
            address token = supportedTokens[i];
            uint256 pending = pendingReward(msg.sender, token);
            if (pending < 1) continue;

            userRewardDebt[token][msg.sender] += pending;
            tokenBalances[token] -= pending;
            IERC20(token).safeTransfer(msg.sender, pending);
            emit Withdrawn(msg.sender, token, pending);
        }
    }

    function distribute() external onlyOperator nonReentrant {
        if (block.timestamp < lastDistributionTime + MIN_INTERVAL) revert DistributionTooSoon();
        if (totalStaked < 1) revert NoStakers();

        uint256 rate = distributionRateBps;
        uint256 len = supportedTokens.length;
        uint256 totalDistributedValue = 0;

        for (uint256 i = 0; i < len; ++i) {
            address token = supportedTokens[i];
            uint256 balance = tokenBalances[token];
            if (balance < 1) continue;

            // Combine multiply before divide to avoid divide-before-multiply precision loss
            // accTokenPerShare increment = (balance * rate * ACC_PRECISION) / (BPS_DENOMINATOR * totalStaked)
            uint256 increment = (balance * rate * ACC_PRECISION) / (BPS_DENOMINATOR * totalStaked);
            if (increment < 1) continue;

            uint256 toDistribute = (increment * totalStaked) / ACC_PRECISION;

            // Effects
            tokenBalances[token] -= toDistribute;
            accTokenPerShare[token] += increment;
            totalDistributedValue += toDistribute;
        }

        if (totalDistributedValue < 1) revert NothingToDistribute();

        lastDistributionTime = block.timestamp;
        emit DistributionExecuted(totalDistributedValue, block.timestamp);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previousOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(previousOperator, newOperator);
    }
}
