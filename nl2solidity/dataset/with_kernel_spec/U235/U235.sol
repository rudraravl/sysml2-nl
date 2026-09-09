// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
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

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title YieldVault
 * @notice A vault for trusted real-world asset strategies. Users deposit stablecoins,
 *         accrue yield distributed by the operator, and claim optional reward tokens.
 */
contract YieldVault is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    // ------------------------------------------------------------------
    // Custom errors
    // ------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance(uint256 requested, uint256 available);
    error BelowMinimumDeposit(uint256 amount, uint256 minimum);
    error NotOperator();
    error InvalidStrategyParams();
    error NoAssets();
    error VaultPaused();
    error InvalidTokenConfig();

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 principalWithdrawn, uint256 yieldWithdrawn);
    event YieldHarvested(address indexed operator, uint256 amount);
    event RewardsDistributed(address indexed operator, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event StrategyUpdated(address indexed operator, uint256 yieldRatePerSecond, uint256 rewardRatePerSecond, bool paused);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // ------------------------------------------------------------------
    // Immutable & constant state
    // ------------------------------------------------------------------
    uint256 public constant PRECISION = 1e18;

    IERC20Metadata public immutable stablecoin;
    IERC20 public immutable rewardToken;
    address public operator;
    uint256 public immutable MIN_DEPOSIT;

    // ------------------------------------------------------------------
    // Global accounting
    // ------------------------------------------------------------------
    uint256 public totalAssets;      // total stablecoin value held by the vault
    uint256 public totalPrincipal;   // sum of all user principal
    uint256 public yieldIndex;       // accumulated yield per unit of principal (scaled by PRECISION)
    uint256 public rewardIndex;      // accumulated rewards per unit of principal (scaled by PRECISION)

    struct UserData {
        uint256 principal;
        uint256 accruedYield;
        uint256 claimableRewards;
        uint256 lastYieldIndex;
        uint256 lastRewardIndex;
    }
    mapping(address => UserData) public deposits;

    struct StrategyParams {
        uint256 yieldRatePerSecond;   // off-chain / informational yield expectation
        uint256 rewardRatePerSecond;  // off-chain / informational reward expectation
        bool paused;
    }
    StrategyParams public strategy;

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------
    constructor(address _stablecoin, address _rewardToken, address _operator) {
        if (_stablecoin == address(0) || _rewardToken == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        if (_rewardToken == _stablecoin) {
            revert InvalidTokenConfig();
        }

        stablecoin = IERC20Metadata(_stablecoin);
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
        MIN_DEPOSIT = 100 * (10 ** stablecoin.decimals());
    }

    // ------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (strategy.paused) revert VaultPaused();
        _;
    }

    // ------------------------------------------------------------------
    // User actions
    // ------------------------------------------------------------------

    /**
     * @notice Deposit stablecoins into the vault. Enforces a minimum deposit of 100 stablecoins.
     * @param amount Amount of stablecoins to deposit, in the token's smallest unit.
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit(amount, MIN_DEPOSIT);

        _accrueYield(msg.sender);
        _accrueRewards(msg.sender);

        // Effects: update state before external interaction
        deposits[msg.sender].principal += amount;
        totalPrincipal += amount;
        totalAssets += amount;

        // Interaction: pull stablecoins from depositor
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw a portion of principal together with all currently accrued yield.
     * @param principalAmount Amount of principal to withdraw. Pass 0 to claim accrued yield only.
     */
    function withdraw(uint256 principalAmount) external nonReentrant {
        UserData storage ud = deposits[msg.sender];
        if (principalAmount > ud.principal) {
            revert InsufficientBalance(principalAmount, ud.principal);
        }

        _accrueYield(msg.sender);
        _accrueRewards(msg.sender);

        uint256 yieldAmount = ud.accruedYield;
        if (principalAmount == 0 && yieldAmount == 0) revert ZeroAmount();

        // Effects: update state before external interaction
        ud.principal -= principalAmount;
        ud.accruedYield = 0;
        totalPrincipal -= principalAmount;
        totalAssets -= (principalAmount + yieldAmount);

        // Interaction: send stablecoins to user
        stablecoin.safeTransfer(msg.sender, principalAmount + yieldAmount);

        emit Withdrawal(msg.sender, principalAmount, yieldAmount);
    }

    /**
     * @notice Claim all pending reward tokens credited to the caller.
     */
    function claimRewards() external nonReentrant {
        UserData storage ud = deposits[msg.sender];
        _accrueRewards(msg.sender);

        uint256 amount = ud.claimableRewards;
        if (amount == 0) revert ZeroAmount();

        // Effects: update state before external interaction
        ud.claimableRewards = 0;

        // Interaction: send reward tokens to user
        rewardToken.safeTransfer(msg.sender, amount);

        emit RewardsClaimed(msg.sender, amount);
    }

    // ------------------------------------------------------------------
    // Operator actions
    // ------------------------------------------------------------------

    /**
     * @notice Harvest yield from the trusted strategy and distribute it proportionally to depositors.
     *         The operator must transfer the harvested stablecoins into the vault.
     * @param amount Gross amount of stablecoins harvested.
     */
    function harvestYield(uint256 amount) external onlyOperator nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (totalPrincipal == 0) revert NoAssets();

        // Effects: update indices and totals before external interaction
        yieldIndex += (amount * PRECISION) / totalPrincipal;
        totalAssets += amount;

        // Interaction: pull harvested stablecoins from operator
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit YieldHarvested(msg.sender, amount);
    }

    /**
     * @notice Distribute reward tokens to depositors proportionally to their principal.
     * @param amount Amount of reward tokens to distribute.
     */
    function distributeRewards(uint256 amount) external onlyOperator nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (totalPrincipal == 0) revert NoAssets();

        // Effects: update reward index before external interaction
        rewardIndex += (amount * PRECISION) / totalPrincipal;

        // Interaction: pull reward tokens from operator
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsDistributed(msg.sender, amount);
    }

    /**
     * @notice Update the vault's strategy parameters. Rates are informational and do not
     *         affect on-chain accrual, which is driven by explicit harvest/distribute calls.
     * @param yieldRatePerSecond Expected yield rate per second per unit of principal.
     * @param rewardRatePerSecond Expected reward rate per second per unit of principal.
     * @param paused Whether deposits and harvesting are paused.
     */
    function updateStrategyParams(
        uint256 yieldRatePerSecond,
        uint256 rewardRatePerSecond,
        bool paused
    ) external onlyOperator {
        if (!paused && yieldRatePerSecond == 0 && rewardRatePerSecond == 0) {
            revert InvalidStrategyParams();
        }

        strategy.yieldRatePerSecond = yieldRatePerSecond;
        strategy.rewardRatePerSecond = rewardRatePerSecond;
        strategy.paused = paused;

        emit StrategyUpdated(msg.sender, yieldRatePerSecond, rewardRatePerSecond, paused);
    }

    /**
     * @notice Transfer the operator role to a new address.
     * @param newOperator Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    // ------------------------------------------------------------------
    // View functions
    // ------------------------------------------------------------------

    /**
     * @notice Get the full deposit record for a user.
     */
    function getDeposit(address user)
        external
        view
        returns (
            uint256 principal,
            uint256 accruedYield,
            uint256 claimableRewards,
            uint256 lastYieldIndex,
            uint256 lastRewardIndex
        )
    {
        UserData storage ud = deposits[user];
        return (
            ud.principal,
            ud.accruedYield,
            ud.claimableRewards,
            ud.lastYieldIndex,
            ud.lastRewardIndex
        );
    }

    /**
     * @notice Preview the total yield currently available to a user, including un-accrued pending yield.
     */
    function pendingYield(address user) external view returns (uint256) {
        UserData storage ud = deposits[user];
        uint256 pending = 0;
        if (ud.principal > 0 && yieldIndex > ud.lastYieldIndex) {
            pending = (ud.principal * (yieldIndex - ud.lastYieldIndex)) / PRECISION;
        }
        return ud.accruedYield + pending;
    }

    /**
     * @notice Preview the total rewards currently available to a user, including un-accrued pending rewards.
     */
    function pendingRewards(address user) external view returns (uint256) {
        UserData storage ud = deposits[user];
        uint256 pending = 0;
        if (ud.principal > 0 && rewardIndex > ud.lastRewardIndex) {
            pending = (ud.principal * (rewardIndex - ud.lastRewardIndex)) / PRECISION;
        }
        return ud.claimableRewards + pending;
    }

    // ------------------------------------------------------------------
    // Internal accounting
    // ------------------------------------------------------------------

    /**
     * @dev Accrue pending yield for a user based on the current yield index.
     */
    function _accrueYield(address user) internal {
        UserData storage ud = deposits[user];
        if (ud.principal == 0) {
            ud.lastYieldIndex = yieldIndex;
            return;
        }
        ud.accruedYield += (ud.principal * (yieldIndex - ud.lastYieldIndex)) / PRECISION;
        ud.lastYieldIndex = yieldIndex;
    }

    /**
     * @dev Accrue pending rewards for a user based on the current reward index.
     */
    function _accrueRewards(address user) internal {
        UserData storage ud = deposits[user];
        if (ud.principal == 0) {
            ud.lastRewardIndex = rewardIndex;
            return;
        }
        ud.claimableRewards += (ud.principal * (rewardIndex - ud.lastRewardIndex)) / PRECISION;
        ud.lastRewardIndex = rewardIndex;
    }
}
