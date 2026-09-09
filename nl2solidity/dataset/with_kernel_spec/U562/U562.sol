// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IYieldStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external;
    function balanceOf(address account) external view returns (uint256);
}

interface ILeverageManager {
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function outstandingDebt(address borrower) external view returns (uint256);
}

contract LeveragedYieldPosition {
    ////////////////////////////////////////////////////////////////////////
    //                              ERRORS                                //
    ////////////////////////////////////////////////////////////////////////
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error LeverageRatioTooHigh();
    error LeverageRatioTooLow();
    error NoOutstandingDebt();
    error NotOperator();
    error NotOwner();
    error NothingToClaim();
    error NothingToReinvest();
    error ReentrancyDetected();
    error ApproveFailed();

    ////////////////////////////////////////////////////////////////////////
    //                              EVENTS                                //
    ////////////////////////////////////////////////////////////////////////
    event Deposit(address indexed user, uint256 baseAmount, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 baseAmount, uint256 yieldAmount, uint256 sharesBurned);
    event RewardClaimed(address indexed user, uint256 rewardAmount, uint256 feeAmount);
    event LeverageRepaid(address indexed user, uint256 repaidAmount);
    event LeverageRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event YieldHarvested(uint256 harvestedAmount);
    event YieldReinvested(uint256 reinvestedAmount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    ////////////////////////////////////////////////////////////////////////
    //                            CONSTANTS                               //
    ////////////////////////////////////////////////////////////////////////
    uint256 public constant MAX_LEVERAGE_RATIO = 2e18; // 2.0x
    uint256 public constant MIN_LEVERAGE_RATIO = 1e18; // 1.0x
    uint256 public constant FEE_BASIS_POINTS = 50;     // 0.5%
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 private constant WAD = 1e18;

    ////////////////////////////////////////////////////////////////////////
    //                             STORAGE                                //
    ////////////////////////////////////////////////////////////////////////
    IERC20 public immutable baseToken;
    IERC20 public immutable yieldToken;
    IYieldStrategy public immutable yieldStrategy;
    ILeverageManager public immutable leverageManager;

    address public owner;
    address public operator;
    address public feeRecipient;

    uint256 public leverageRatio;        // in WAD (1e18 = 1.0x)
    uint256 public totalShares;
    uint256 public totalBaseDeposited;
    uint256 public accumulatedRewardPerShare;
    uint256 public lastHarvestTimestamp;
    uint256 public pendingReinvest;

    struct UserInfo {
        uint256 shares;            // shares representing principal
        uint256 baseDeposited;     // base tokens deposited by user
        uint256 rewardDebt;        // reward debt for accounting
        uint256 accruedYield;      // yield accrued but not yet claimed
    }

    mapping(address => UserInfo) public users;

    bool private locked;

    ////////////////////////////////////////////////////////////////////////
    //                            MODIFIERS                               //
    ////////////////////////////////////////////////////////////////////////
    modifier nonReentrant() {
        if (locked) revert ReentrancyDetected();
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    ////////////////////////////////////////////////////////////////////////
    //                           CONSTRUCTOR                              //
    ////////////////////////////////////////////////////////////////////////
    constructor(
        address _baseToken,
        address _yieldToken,
        address _yieldStrategy,
        address _leverageManager,
        address _operator,
        address _feeRecipient,
        uint256 _initialLeverageRatio
    ) {
        if (
            _baseToken == address(0) ||
            _yieldToken == address(0) ||
            _yieldStrategy == address(0) ||
            _leverageManager == address(0) ||
            _operator == address(0) ||
            _feeRecipient == address(0)
        ) revert ZeroAddress();

        if (_initialLeverageRatio < MIN_LEVERAGE_RATIO || _initialLeverageRatio > MAX_LEVERAGE_RATIO)
            revert LeverageRatioTooLow();

        baseToken = IERC20(_baseToken);
        yieldToken = IERC20(_yieldToken);
        yieldStrategy = IYieldStrategy(_yieldStrategy);
        leverageManager = ILeverageManager(_leverageManager);
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        leverageRatio = _initialLeverageRatio;
        lastHarvestTimestamp = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit FeeRecipientChanged(address(0), _feeRecipient);
        emit LeverageRatioUpdated(0, _initialLeverageRatio);
    }

    ////////////////////////////////////////////////////////////////////////
    //                       USER-FACING FUNCTIONS                        //
    ////////////////////////////////////////////////////////////////////////

    /**
     * @notice Deposit base tokens into the leveraged yield position.
     * @param amount The amount of base tokens to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _updateGlobalRewards();

        UserInfo storage user = users[msg.sender];

        // Calculate pending rewards before share change
        uint256 pending = _pendingRewards(user);
        uint256 fee = 0;
        uint256 netReward = 0;
        if (pending > 0) {
            fee = (pending * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
            netReward = pending - fee;
        }

        // Transfer base tokens from user (pull interaction first)
        uint256 before = baseToken.balanceOf(address(this));
        if (!baseToken.transferFrom(msg.sender, address(this), amount)) revert InsufficientAllowance();
        uint256 received = baseToken.balanceOf(address(this)) - before;

        // Calculate shares to mint
        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = received;
        } else {
            sharesToMint = (received * totalShares) / totalBaseDeposited;
        }

        // EFFECTS: update all state before further external calls
        user.shares += sharesToMint;
        user.baseDeposited += received;
        user.accruedYield += netReward;
        totalShares += sharesToMint;
        totalBaseDeposited += received;
        user.rewardDebt = (user.shares * accumulatedRewardPerShare) / WAD;

        // INTERACTIONS: deposit into strategy with leverage
        _leveragedDeposit(received);

        // Transfer fee to feeRecipient
        if (fee > 0) {
            if (!yieldToken.transfer(feeRecipient, fee)) revert InsufficientBalance();
        }

        if (pending > 0) {
            emit RewardClaimed(msg.sender, netReward, fee);
        }
        emit Deposit(msg.sender, received, sharesToMint);
    }

    /**
     * @notice Withdraw principal and accrued yield.
     * @param shareAmount The number of shares to withdraw.
     */
    function withdraw(uint256 shareAmount) external nonReentrant {
        UserInfo storage user = users[msg.sender];
        if (shareAmount == 0) revert ZeroAmount();
        if (shareAmount > user.shares) revert InsufficientBalance();

        _updateGlobalRewards();

        // Calculate pending rewards
        uint256 pending = _pendingRewards(user);
        uint256 fee = 0;
        uint256 netReward = 0;
        if (pending > 0) {
            fee = (pending * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
            netReward = pending - fee;
        }

        // Calculate base amount proportional to shares
        uint256 baseAmount = (shareAmount * totalBaseDeposited) / totalShares;
        uint256 yieldAmount = user.accruedYield + netReward;

        // EFFECTS: burn shares and update deposits before external calls
        uint256 userSharesBefore = user.shares;
        user.shares -= shareAmount;
        user.baseDeposited -= (shareAmount * user.baseDeposited) / userSharesBefore;
        totalShares -= shareAmount;
        totalBaseDeposited -= baseAmount;
        user.accruedYield = 0;
        user.rewardDebt = (user.shares * accumulatedRewardPerShare) / WAD;

        // INTERACTIONS: withdraw from yield strategy
        yieldStrategy.withdraw(baseAmount);

        // Repay leverage proportionally
        uint256 debt = leverageManager.outstandingDebt(address(this));
        if (debt > 0) {
            uint256 repayFraction = (debt * shareAmount) / (totalShares + shareAmount);
            if (repayFraction > 0) {
                _repayLeverage(repayFraction);
            }
        }

        // Transfer base tokens and yield tokens to user
        if (!baseToken.transfer(msg.sender, baseAmount)) revert InsufficientBalance();
        if (yieldAmount > 0) {
            if (!yieldToken.transfer(msg.sender, yieldAmount)) revert InsufficientBalance();
        }
        if (fee > 0) {
            if (!yieldToken.transfer(feeRecipient, fee)) revert InsufficientBalance();
        }

        if (pending > 0) {
            emit RewardClaimed(msg.sender, netReward, fee);
        }
        emit Withdraw(msg.sender, baseAmount, yieldAmount, shareAmount);
    }

    /**
     * @notice Claim accumulated rewards from the leveraged position.
     */
    function claimRewards() external nonReentrant {
        UserInfo storage user = users[msg.sender];
        _updateGlobalRewards();

        uint256 pending = _pendingRewards(user);
        if (pending == 0) revert NothingToClaim();

        uint256 fee = (pending * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        uint256 netReward = pending - fee;

        // EFFECTS: update accrued yield and reward debt before external transfer
        user.accruedYield += netReward;
        user.rewardDebt = (user.shares * accumulatedRewardPerShare) / WAD;

        // INTERACTIONS: transfer fee to feeRecipient
        if (fee > 0) {
            if (!yieldToken.transfer(feeRecipient, fee)) revert InsufficientBalance();
        }

        emit RewardClaimed(msg.sender, netReward, fee);
    }

    /**
     * @notice Repay outstanding leverage debt using base tokens.
     * @param amount The amount of base tokens to use for repayment.
     */
    function repayLeverage(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _repayLeverage(amount);
        emit LeverageRepaid(msg.sender, amount);
    }

    ////////////////////////////////////////////////////////////////////////
    //                      OPERATOR-FACING FUNCTIONS                     //
    ////////////////////////////////////////////////////////////////////////

    /**
     * @notice Adjust the leverage ratio. Only callable by the operator.
     * @param newRatio The new leverage ratio in WAD (1e18 = 1.0x).
     */
    function setLeverageRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < MIN_LEVERAGE_RATIO) revert LeverageRatioTooLow();
        if (newRatio > MAX_LEVERAGE_RATIO) revert LeverageRatioTooHigh();

        uint256 oldRatio = leverageRatio;
        leverageRatio = newRatio;

        emit LeverageRatioUpdated(oldRatio, newRatio);
    }

    /**
     * @notice Harvest yield from the strategy and prepare for reinvestment.
     */
    function harvestYield() external onlyOperator nonReentrant {
        uint256 before = yieldToken.balanceOf(address(this));
        yieldStrategy.harvest();
        uint256 afterBalance = yieldToken.balanceOf(address(this));

        uint256 harvested = afterBalance > before ? afterBalance - before : 0;

        if (harvested > 0) {
            pendingReinvest += harvested;
            lastHarvestTimestamp = block.timestamp;
            emit YieldHarvested(harvested);
        }
    }

    /**
     * @notice Reinvest pending harvested yield back into the leveraged position.
     */
    function reinvestYield() external onlyOperator nonReentrant {
        if (pendingReinvest == 0) revert NothingToReinvest();

        uint256 amount = pendingReinvest;
        pendingReinvest = 0;

        // Approve and deposit yield tokens back into strategy with leverage
        if (!yieldToken.approve(address(yieldStrategy), amount)) revert ApproveFailed();
        _leveragedDeposit(amount);

        emit YieldReinvested(amount);
    }

    ////////////////////////////////////////////////////////////////////////
    //                       ADMIN-FACING FUNCTIONS                       //
    ////////////////////////////////////////////////////////////////////////

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    ////////////////////////////////////////////////////////////////////////
    //                          VIEW FUNCTIONS                            //
    ////////////////////////////////////////////////////////////////////////

    function pendingRewards(address userAddr) external view returns (uint256) {
        UserInfo storage u = users[userAddr];
        return _pendingRewards(u);
    }

    function getUserInfo(address userAddr) external view returns (
        uint256 shares,
        uint256 baseDeposited,
        uint256 rewardDebt,
        uint256 accruedYield
    ) {
        UserInfo storage u = users[userAddr];
        return (u.shares, u.baseDeposited, u.rewardDebt, u.accruedYield);
    }

    function outstandingDebt() external view returns (uint256) {
        return leverageManager.outstandingDebt(address(this));
    }

    ////////////////////////////////////////////////////////////////////////
    //                         INTERNAL FUNCTIONS                         //
    ////////////////////////////////////////////////////////////////////////

    function _pendingRewards(UserInfo storage user) internal view returns (uint256) {
        if (user.shares == 0) return 0;
        uint256 currentPerShare = accumulatedRewardPerShare;
        uint256 userPending = (user.shares * currentPerShare) / WAD;
        if (userPending <= user.rewardDebt) return 0;
        return userPending - user.rewardDebt;
    }

    function _updateGlobalRewards() internal {
        uint256 strategyBalance = yieldStrategy.balanceOf(address(this));
        if (strategyBalance > totalBaseDeposited) {
            uint256 yieldGenerated = strategyBalance - totalBaseDeposited;
            if (totalShares > 0) {
                accumulatedRewardPerShare += (yieldGenerated * WAD) / totalShares;
            }
        }
    }

    function _leveragedDeposit(uint256 baseAmount) internal {
        // Calculate borrowed amount based on leverage ratio
        // leverageRatio is in WAD; borrowed = baseAmount * (ratio - 1)
        if (leverageRatio > WAD) {
            uint256 borrowAmount = (baseAmount * (leverageRatio - WAD)) / WAD;
            if (borrowAmount > 0) {
                leverageManager.borrow(borrowAmount);
                baseAmount += borrowAmount;
            }
        }

        // Approve strategy and deposit
        if (!baseToken.approve(address(yieldStrategy), baseAmount)) revert ApproveFailed();
        yieldStrategy.deposit(baseAmount);
    }

    function _repayLeverage(uint256 amount) internal {
        uint256 debt = leverageManager.outstandingDebt(address(this));
        if (debt == 0) revert NoOutstandingDebt();

        uint256 repayAmount = amount > debt ? debt : amount;

        // Approve leverage manager and repay
        if (!baseToken.approve(address(leverageManager), repayAmount)) revert ApproveFailed();
        leverageManager.repay(repayAmount);
    }
}
