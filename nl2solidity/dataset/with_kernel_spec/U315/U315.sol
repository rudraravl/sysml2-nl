// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function harvest() external returns (uint256);
    function balanceOf() external view returns (uint256);
}

contract YieldVault {
    error NotOwner();
    error NotOperator();
    error InsufficientDeposit();
    error InsufficientShares();
    error InsufficientLiquidity();
    error InsufficientInvested();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error StrategyNotFound();
    error StrategyInUse();
    error SameStrategy();
    error InvalidFee();
    error ZeroAddress();
    error TransferFailed();
    error NoRewards();
    error NoFees();
    error AmountZero();
    error NoYield();
    error Reentrancy();

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event RewardClaimed(address indexed user, uint256 amount);
    event StrategyApproved(address indexed strategy);
    event StrategyRevoked(address indexed strategy);
    event ManagementFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event RebalanceInitiated(address indexed fromStrategy, address indexed toStrategy, uint256 amount);
    event YieldHarvested(address indexed strategy, uint256 grossYield, uint256 fee, uint256 netYield);
    event FeesClaimed(address indexed owner, uint256 amount);
    event FundsInvested(address indexed strategy, uint256 amount);
    event FundsDivested(address indexed strategy, uint256 amount);

    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant MAX_FEE = 10000;
    uint256 public constant DEFAULT_MANAGEMENT_FEE = 50;
    uint256 private constant MIN_SHARES = 1;
    uint256 private constant MIN_RETURN = 1;

    IERC20 public immutable token;
    address public owner;
    address public operator;

    uint256 public totalShares;
    uint256 public totalDeposited;
    uint256 public managementFeeBps;
    uint256 public accruedFees;

    mapping(address => uint256) public userShares;
    mapping(address => bool) public approvedStrategies;
    mapping(address => uint256) public strategyInvested;
    address[] public approvedStrategyList;

    uint256 public rewardIndex;
    mapping(address => uint256) public userRewardIndex;
    mapping(address => uint256) public userAccruedRewards;

    uint256 private _status;

    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        owner = msg.sender;
        operator = operator_;
        managementFeeBps = DEFAULT_MANAGEMENT_FEE;
        _status = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status != 1) revert Reentrancy();
        _status = 2;
        _;
        _status = 1;
    }

    function _safeTransfer(IERC20 token_, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token_, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _updateReward(address user) internal {
        uint256 shares = userShares[user];
        if (shares > 0) {
            uint256 idxDelta = rewardIndex - userRewardIndex[user];
            if (idxDelta > 0) {
                userAccruedRewards[user] += (shares * idxDelta) / REWARD_PRECISION;
            }
        }
        userRewardIndex[user] = rewardIndex;
    }

    function totalAssets() public view returns (uint256) {
        uint256 invested = 0;
        uint256 len = approvedStrategyList.length;
        for (uint256 i = 0; i < len; i++) {
            invested += strategyInvested[approvedStrategyList[i]];
        }
        return token.balanceOf(address(this)) + invested;
    }

    function vaultBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function approvedStrategyCount() external view returns (uint256) {
        return approvedStrategyList.length;
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit();
        _updateReward(msg.sender);

        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / totalAssets();
        }
        if (sharesToMint < MIN_SHARES) revert InsufficientShares();

        userShares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalDeposited += amount;

        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 shareAmount) external nonReentrant {
        if (shareAmount < MIN_SHARES) revert InsufficientShares();
        if (userShares[msg.sender] < shareAmount) revert InsufficientShares();

        uint256 currentAssets = totalAssets();
        uint256 assetsToReturn = (shareAmount * currentAssets) / totalShares;
        if (assetsToReturn < MIN_RETURN) revert InsufficientLiquidity();
        if (token.balanceOf(address(this)) < assetsToReturn) revert InsufficientLiquidity();

        _updateReward(msg.sender);

        uint256 depositPortion = (shareAmount * totalDeposited) / totalShares;
        userShares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        if (totalDeposited >= depositPortion) {
            totalDeposited -= depositPortion;
        } else {
            totalDeposited = 0;
        }

        _safeTransfer(token, msg.sender, assetsToReturn);

        emit Withdraw(msg.sender, assetsToReturn, shareAmount);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 rewards = userAccruedRewards[msg.sender];
        if (rewards < MIN_RETURN) revert NoRewards();
        userAccruedRewards[msg.sender] = 0;
        _safeTransfer(token, msg.sender, rewards);
        emit RewardClaimed(msg.sender, rewards);
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 shares = userShares[user];
        uint256 idxDelta = rewardIndex - userRewardIndex[user];
        return userAccruedRewards[user] + (shares * idxDelta) / REWARD_PRECISION;
    }

    function approveStrategy(address strategy) external onlyOwner {
        if (strategy == address(0)) revert ZeroAddress();
        if (approvedStrategies[strategy]) revert StrategyAlreadyApproved();
        approvedStrategies[strategy] = true;
        approvedStrategyList.push(strategy);
        emit StrategyApproved(strategy);
    }

    function revokeStrategy(address strategy) external onlyOwner {
        if (!approvedStrategies[strategy]) revert StrategyNotFound();
        if (strategyInvested[strategy] > 0) revert StrategyInUse();
        approvedStrategies[strategy] = false;
        uint256 len = approvedStrategyList.length;
        for (uint256 i = 0; i < len; i++) {
            if (approvedStrategyList[i] == strategy) {
                approvedStrategyList[i] = approvedStrategyList[len - 1];
                approvedStrategyList.pop();
                break;
            }
        }
        emit StrategyRevoked(strategy);
    }

    function setManagementFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE) revert InvalidFee();
        uint256 old = managementFeeBps;
        managementFeeBps = newFeeBps;
        emit ManagementFeeUpdated(old, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function claimFees() external onlyOwner nonReentrant {
        uint256 fees = accruedFees;
        if (fees == 0) revert NoFees();
        accruedFees = 0;
        _safeTransfer(token, owner, fees);
        emit FeesClaimed(owner, fees);
    }

    function invest(address strategy, uint256 amount) external onlyOperator nonReentrant {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (amount == 0) revert AmountZero();
        if (token.balanceOf(address(this)) < amount) revert InsufficientLiquidity();
        _safeTransfer(token, strategy, amount);
        IStrategy(strategy).deposit(amount);
        strategyInvested[strategy] += amount;
        emit FundsInvested(strategy, amount);
    }

    function divest(address strategy, uint256 amount) external onlyOperator nonReentrant {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (amount == 0) revert AmountZero();
        if (strategyInvested[strategy] < amount) revert InsufficientInvested();
        strategyInvested[strategy] -= amount;
        uint256 returned = IStrategy(strategy).withdraw(amount);
        emit FundsDivested(strategy, returned);
    }

    function rebalance(address fromStrategy, address toStrategy, uint256 amount) external onlyOperator nonReentrant {
        if (!approvedStrategies[fromStrategy]) revert StrategyNotApproved();
        if (!approvedStrategies[toStrategy]) revert StrategyNotApproved();
        if (fromStrategy == toStrategy) revert SameStrategy();
        if (amount == 0) revert AmountZero();
        if (strategyInvested[fromStrategy] < amount) revert InsufficientInvested();

        strategyInvested[fromStrategy] -= amount;
        uint256 returned = IStrategy(fromStrategy).withdraw(amount);

        if (returned > 0) {
            _safeTransfer(token, toStrategy, returned);
            IStrategy(toStrategy).deposit(returned);
            strategyInvested[toStrategy] += returned;
        }
        emit RebalanceInitiated(fromStrategy, toStrategy, amount);
    }

    function harvest(address strategy) external nonReentrant {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        uint256 grossYield = IStrategy(strategy).harvest();
        if (grossYield == 0) revert NoYield();
        uint256 fee = (grossYield * managementFeeBps) / FEE_DENOMINATOR;
        uint256 netYield = grossYield - fee;
        accruedFees += fee;
        if (totalShares > 0) {
            rewardIndex += (netYield * REWARD_PRECISION) / totalShares;
        } else {
            accruedFees += netYield;
        }
        emit YieldHarvested(strategy, grossYield, fee, netYield);
    }
}
