// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedStablecoinSystem {
    /* ------------------------------------------------------------------ */
    /*                              Constants                              */
    /* ------------------------------------------------------------------ */

    uint256 public constant BPS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 15000; // 150%
    uint256 public constant MINT_FEE_BPS = 50;                   // 0.5%
    uint256 public constant MAX_COLLATERAL_FACTOR = 10000;       // 100%

    /* ------------------------------------------------------------------ */
    /*                              Errors                                 */
    /* ------------------------------------------------------------------ */

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error CollateralNotApproved();
    error CollateralAlreadyApproved();
    error CollateralFactorTooHigh();
    error RatioTooLow();
    error InsufficientBalance();
    error InsufficientCollateral();
    error BelowCollateralization();
    error NoStakers();
    error TransferFailed();
    error ZeroDuration();
    error CollateralHasDeposits();

    /* ------------------------------------------------------------------ */
    /*                              Events                                 */
    /* ------------------------------------------------------------------ */

    event Mint(
        address indexed user,
        address indexed collateral,
        uint256 collateralAmount,
        uint256 stablecoinGross,
        uint256 fee,
        uint256 stablecoinNet
    );
    event Burn(
        address indexed user,
        address indexed collateral,
        uint256 stablecoinAmount,
        uint256 collateralReturned
    );
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed collateral, uint256 amount);
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ReserveDistributed(address indexed caller, uint256 amount, uint256 duration);
    event RewardsClaimed(address indexed user, uint256 amount);
    event CollateralAdded(address indexed collateral, uint256 factor);
    event CollateralRemoved(address indexed collateral);
    event CollateralFactorUpdated(address indexed collateral, uint256 oldFactor, uint256 newFactor);
    event TargetCollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event OperatorUpdated(address oldOperator, address newOperator);
    event StablecoinTransfer(address indexed from, address indexed to, uint256 amount);
    event ReserveTokenTransfer(address indexed from, address indexed to, uint256 amount);
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    /* ------------------------------------------------------------------ */
    /*                              State                                  */
    /* ------------------------------------------------------------------ */

    address public operator;

    uint256 public totalStablecoinSupply;
    uint256 public totalReserveSupply;
    uint256 public feePoolStable;

    uint256 public targetCollateralizationRatio = MIN_COLLATERALIZATION_RATIO;

    // User balances
    mapping(address => uint256) public stablecoinBalance;
    mapping(address => uint256) public reserveTokenBalance;
    mapping(address => mapping(address => uint256)) public collateralDeposits; // user => collateral => amount

    // Collateral configuration
    struct CollateralConfig {
        bool approved;
        uint256 factor; // basis points, e.g. 8000 = 80%
    }
    mapping(address => CollateralConfig) public collateralConfig;
    address[] public collateralList;
    mapping(address => uint256) public totalCollateralDeposited; // collateral => total deposited

    // Staking
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;

    // Time-based reward distribution
    uint256 public rewardRate;           // reserve tokens per second
    uint256 public periodFinish;         // timestamp when current distribution ends
    uint256 public lastUpdateTime;       // last time rewardPerTokenStored was updated
    uint256 public rewardPerTokenStored; // accumulated reward per token (in PRECISION)
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public accruedReserve;

    // Exact undistributed reserve carried across distribution periods, to avoid
    // recomputing leftover via a multiplication of a previously-divided rate.
    uint256 public leftoverReserve;

    // Reentrancy guard
    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    /* ------------------------------------------------------------------ */
    /*                            Constructor                              */
    /* ------------------------------------------------------------------ */

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
    }

    /* ------------------------------------------------------------------ */
    /*                    Collateral Management (Operator)                 */
    /* ------------------------------------------------------------------ */

    function addCollateral(address collateral, uint256 factor) external onlyOperator {
        if (collateral == address(0)) revert ZeroAddress();
        if (collateralConfig[collateral].approved) revert CollateralAlreadyApproved();
        if (factor > MAX_COLLATERAL_FACTOR) revert CollateralFactorTooHigh();

        collateralConfig[collateral] = CollateralConfig({approved: true, factor: factor});
        collateralList.push(collateral);

        emit CollateralAdded(collateral, factor);
    }

    function removeCollateral(address collateral) external onlyOperator {
        if (!collateralConfig[collateral].approved) revert CollateralNotApproved();
        if (totalCollateralDeposited[collateral] > 0) revert CollateralHasDeposits();

        collateralConfig[collateral].approved = false;

        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; ) {
            if (collateralList[i] == collateral) {
                collateralList[i] = collateralList[len - 1];
                collateralList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit CollateralRemoved(collateral);
    }

    function setCollateralFactor(address collateral, uint256 factor) external onlyOperator {
        if (!collateralConfig[collateral].approved) revert CollateralNotApproved();
        if (factor > MAX_COLLATERAL_FACTOR) revert CollateralFactorTooHigh();

        uint256 old = collateralConfig[collateral].factor;
        collateralConfig[collateral].factor = factor;

        emit CollateralFactorUpdated(collateral, old, factor);
    }

    function setTargetCollateralizationRatio(uint256 ratio) external onlyOperator {
        if (ratio < MIN_COLLATERALIZATION_RATIO) revert RatioTooLow();
        uint256 old = targetCollateralizationRatio;
        targetCollateralizationRatio = ratio;
        emit TargetCollateralizationRatioUpdated(old, ratio);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /* ------------------------------------------------------------------ */
    /*                    Collateral Deposit / Withdraw                    */
    /* ------------------------------------------------------------------ */

    function depositCollateral(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!collateralConfig[collateral].approved) revert CollateralNotApproved();

        collateralDeposits[msg.sender][collateral] += amount;
        totalCollateralDeposited[collateral] += amount;

        bool ok = IERC20(collateral).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit CollateralDeposited(msg.sender, collateral, amount);
    }

    function withdrawCollateral(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (collateralDeposits[msg.sender][collateral] < amount) revert InsufficientCollateral();

        // Check collateralization after withdrawal
        uint256 debt = getUserOutstandingStablecoin(msg.sender);
        if (debt > 0) {
            uint256 newCollateralValue = getUserCollateralValueAfterWithdraw(msg.sender, collateral, amount);
            if (newCollateralValue * BPS < debt * targetCollateralizationRatio) revert BelowCollateralization();
        }

        collateralDeposits[msg.sender][collateral] -= amount;
        totalCollateralDeposited[collateral] -= amount;

        bool ok = IERC20(collateral).transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, collateral, amount);
    }

    /* ------------------------------------------------------------------ */
    /*                       Mint & Burn Stablecoin                        */
    /* ------------------------------------------------------------------ */

    function mint(address collateral, uint256 collateralAmount, uint256 stablecoinAmount)
        external
        nonReentrant
    {
        if (collateralAmount == 0 || stablecoinAmount == 0) revert ZeroAmount();
        CollateralConfig storage cfg = collateralConfig[collateral];
        if (!cfg.approved) revert CollateralNotApproved();

        uint256 fee = (stablecoinAmount * MINT_FEE_BPS) / BPS;
        uint256 netStable = stablecoinAmount - fee;
        if (netStable == 0) revert ZeroAmount();

        // Check collateralization: new debt vs new collateral value
        uint256 newDebt = getUserOutstandingStablecoin(msg.sender) + netStable;
        uint256 newCollateralValue =
            getUserTotalCollateralValue(msg.sender) + (collateralAmount * cfg.factor) / BPS;

        if (newCollateralValue * BPS < newDebt * targetCollateralizationRatio) revert BelowCollateralization();

        // Effects
        collateralDeposits[msg.sender][collateral] += collateralAmount;
        totalCollateralDeposited[collateral] += collateralAmount;
        stablecoinBalance[msg.sender] += netStable;
        feePoolStable += fee;
        totalStablecoinSupply += stablecoinAmount;

        // Interactions
        bool ok = IERC20(collateral).transferFrom(msg.sender, address(this), collateralAmount);
        if (!ok) revert TransferFailed();

        emit Mint(msg.sender, collateral, collateralAmount, stablecoinAmount, fee, netStable);
    }

    function burn(address collateral, uint256 stablecoinAmount, uint256 collateralAmount)
        external
        nonReentrant
    {
        if (stablecoinAmount == 0 || collateralAmount == 0) revert ZeroAmount();
        if (stablecoinBalance[msg.sender] < stablecoinAmount) revert InsufficientBalance();
        if (collateralDeposits[msg.sender][collateral] < collateralAmount) revert InsufficientCollateral();

        // Check collateralization after burn + withdrawal
        uint256 outstandingAfter = getUserOutstandingStablecoin(msg.sender) - stablecoinAmount;
        if (outstandingAfter > 0) {
            uint256 newCollateralValue =
                getUserCollateralValueAfterWithdraw(msg.sender, collateral, collateralAmount);
            if (newCollateralValue * BPS < outstandingAfter * targetCollateralizationRatio)
                revert BelowCollateralization();
        }

        // Effects
        stablecoinBalance[msg.sender] -= stablecoinAmount;
        totalStablecoinSupply -= stablecoinAmount;
        collateralDeposits[msg.sender][collateral] -= collateralAmount;
        totalCollateralDeposited[collateral] -= collateralAmount;

        // Interactions
        bool ok = IERC20(collateral).transfer(msg.sender, collateralAmount);
        if (!ok) revert TransferFailed();

        emit Burn(msg.sender, collateral, stablecoinAmount, collateralAmount);
    }

    /* ------------------------------------------------------------------ */
    /*                         Staking & Rewards                           */
    /* ------------------------------------------------------------------ */

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (stablecoinBalance[msg.sender] < amount) revert InsufficientBalance();

        stablecoinBalance[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientBalance();

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        stablecoinBalance[msg.sender] += amount;

        emit Unstake(msg.sender, amount);
    }

    function distributeReserve(uint256 amount, uint256 duration) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (duration == 0) revert ZeroDuration();
        if (totalStaked == 0) revert NoStakers();

        // Accrue rewards up to now and settle the exact leftover reserve.
        _updateReward(address(0));

        // Carry forward the exact undistributed reserve instead of recomputing it
        // as `remaining * rewardRate`, which would multiply a previously divided
        // value and lose precision.
        uint256 totalToDistribute = amount + leftoverReserve;
        rewardRate = totalToDistribute / duration;
        leftoverReserve = totalToDistribute;

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        totalReserveSupply += amount;

        emit ReserveDistributed(msg.sender, amount, duration);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) {
        uint256 amount = accruedReserve[msg.sender];
        if (amount == 0) revert ZeroAmount();

        accruedReserve[msg.sender] = 0;
        reserveTokenBalance[msg.sender] += amount;

        emit RewardsClaimed(msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /*                         Token Transfers                             */
    /* ------------------------------------------------------------------ */

    function transferStablecoin(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (stablecoinBalance[msg.sender] < amount) revert InsufficientBalance();

        stablecoinBalance[msg.sender] -= amount;
        stablecoinBalance[to] += amount;

        emit StablecoinTransfer(msg.sender, to, amount);
        return true;
    }

    function transferReserveToken(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (reserveTokenBalance[msg.sender] < amount) revert InsufficientBalance();

        reserveTokenBalance[msg.sender] -= amount;
        reserveTokenBalance[to] += amount;

        emit ReserveTokenTransfer(msg.sender, to, amount);
        return true;
    }

    function withdrawFees(address recipient, uint256 amount) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (feePoolStable < amount) revert InsufficientBalance();

        feePoolStable -= amount;
        stablecoinBalance[recipient] += amount;

        emit FeesWithdrawn(recipient, amount);
    }

    /* ------------------------------------------------------------------ */
    /*                       Reward Math (Internal)                        */
    /* ------------------------------------------------------------------ */

    function _lastTimeRewardApplicable() internal view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function _rewardPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 lastTime = _lastTimeRewardApplicable();
        if (lastTime <= lastUpdateTime) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTime - lastUpdateTime) * rewardRate * PRECISION) /
            totalStaked;
    }

    function _updateReward(address account) internal {
        uint256 oldRewardPerToken = rewardPerTokenStored;
        rewardPerTokenStored = _rewardPerToken();
        lastUpdateTime = _lastTimeRewardApplicable();

        // Decrement the exact leftover reserve by the amount globally earned
        // since the last update, so it accurately reflects undistributed rewards.
        if (totalStaked > 0 && rewardPerTokenStored > oldRewardPerToken) {
            uint256 earned = ((rewardPerTokenStored - oldRewardPerToken) * totalStaked) / PRECISION;
            if (earned >= leftoverReserve) {
                leftoverReserve = 0;
            } else {
                leftoverReserve -= earned;
            }
        }

        if (account != address(0)) {
            uint256 staked = stakedBalance[account];
            uint256 perTokenDelta = rewardPerTokenStored - userRewardPerTokenPaid[account];
            accruedReserve[account] += (staked * perTokenDelta) / PRECISION;
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    /* ------------------------------------------------------------------ */
    /*                       Collateral Value Helpers                      */
    /* ------------------------------------------------------------------ */

    function getUserOutstandingStablecoin(address user) public view returns (uint256) {
        return stablecoinBalance[user] + stakedBalance[user];
    }

    function getUserTotalCollateralValue(address user) public view returns (uint256) {
        uint256 total = 0;
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; ) {
            address token = collateralList[i];
            CollateralConfig storage cfg = collateralConfig[token];
            uint256 deposited = collateralDeposits[user][token];
            if (cfg.approved && deposited > 0) {
                total += (deposited * cfg.factor) / BPS;
            }
            unchecked {
                ++i;
            }
        }
        return total;
    }

    function getUserCollateralValueAfterWithdraw(
        address user,
        address collateral,
        uint256 amount
    ) public view returns (uint256) {
        uint256 total = 0;
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; ) {
            address token = collateralList[i];
            CollateralConfig storage cfg = collateralConfig[token];
            uint256 deposited = collateralDeposits[user][token];
            if (token == collateral) {
                deposited = deposited > amount ? deposited - amount : 0;
            }
            if (cfg.approved && deposited > 0) {
                total += (deposited * cfg.factor) / BPS;
            }
            unchecked {
                ++i;
            }
        }
        return total;
    }

    /* ------------------------------------------------------------------ */
    /*                           View Functions                            */
    /* ------------------------------------------------------------------ */

    function getCollateralList() external view returns (address[] memory) {
        return collateralList;
    }

    function getCollateralConfig(address collateral)
        external
        view
        returns (bool approved, uint256 factor)
    {
        CollateralConfig storage cfg = collateralConfig[collateral];
        return (cfg.approved, cfg.factor);
    }

    function getSystemCollateralizationRatio() external view returns (uint256) {
        if (totalStablecoinSupply == 0) return type(uint256).max;
        uint256 totalCollateralValue = 0;
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; ) {
            address token = collateralList[i];
            CollateralConfig storage cfg = collateralConfig[token];
            uint256 deposited = totalCollateralDeposited[token];
            if (cfg.approved && deposited > 0) {
                totalCollateralValue += (deposited * cfg.factor) / BPS;
            }
            unchecked {
                ++i;
            }
        }
        return (totalCollateralValue * BPS) / totalStablecoinSupply;
    }

    function pendingRewards(address user) external view returns (uint256) {
        uint256 currentRewardPerToken = rewardPerTokenStored;
        if (totalStaked > 0) {
            uint256 lastTime = _lastTimeRewardApplicable();
            if (lastTime > lastUpdateTime) {
                currentRewardPerToken +=
                    ((lastTime - lastUpdateTime) * rewardRate * PRECISION) /
                    totalStaked;
            }
        }
        uint256 perTokenDelta = currentRewardPerToken - userRewardPerTokenPaid[user];
        return (stakedBalance[user] * perTokenDelta) / PRECISION + accruedReserve[user];
    }

    function getRewardRate() external view returns (uint256) {
        return rewardRate;
    }

    function getPeriodFinish() external view returns (uint256) {
        return periodFinish;
    }

    function getRewardPerTokenStored() external view returns (uint256) {
        return rewardPerTokenStored;
    }
}
