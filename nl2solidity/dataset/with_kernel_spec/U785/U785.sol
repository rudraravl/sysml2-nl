// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IStrategy {
    function invest(uint256 amount) external;
    function divest(uint256 amount) external;
    function harvest() external returns (uint256);
    function totalAssets() external view returns (uint256);
    function rewardToken() external view returns (address);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, currentAllowance + value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (owner() != _msgSender()) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        if (paused()) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused()) revert ExpectedPause();
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract YieldAggregationVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error FeeExceedsCap(uint256 feeBps, uint256 capBps);
    error StrategyCooldownNotElapsed(uint256 remaining);
    error NoPendingRewards();
    error NothingToWithdraw();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @dev Maximum withdrawal fee in basis points: 0.5% = 50 bps.
    uint256 public constant MAX_FEE_BPS = 50;
    /// @dev Minimum delay between strategy updates.
    uint256 public constant STRATEGY_COOLDOWN = 24 hours;
    /// @dev Basis points denominator.
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    IERC20 public immutable asset;

    /// @dev Strategy contract that generates yield.
    address public strategy;
    /// @dev Timestamp after which the strategy may be updated again.
    uint256 public nextStrategyUpdate;
    /// @dev Withdrawal fee in basis points.
    uint256 public withdrawalFeeBps;
    /// @dev Accumulated fees held by the vault, claimable by the owner.
    uint256 public accruedFees;

    /// @dev Total amount of `asset` deposited by users (excludes yield).
    uint256 public totalDeposited;

    /// @dev Per-user principal deposit balance.
    mapping(address => uint256) public userDeposits;
    /// @dev Per-user claimed rewards tracking.
    mapping(address => uint256) public rewardsClaimed;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount, uint256 totalDeposited);
    event Withdraw(address indexed user, uint256 amount, uint256 fee, uint256 netAmount);
    event RewardsClaimed(address indexed user, address rewardToken, uint256 amount);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesCollected(address indexed collector, uint256 amount);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address _asset, address _strategy, uint256 _withdrawalFeeBps) Ownable(msg.sender) {
        if (_asset == address(0)) revert ZeroAddress();
        if (_strategy == address(0)) revert ZeroAddress();
        if (_withdrawalFeeBps > MAX_FEE_BPS) revert FeeExceedsCap(_withdrawalFeeBps, MAX_FEE_BPS);

        asset = IERC20(_asset);
        strategy = _strategy;
        withdrawalFeeBps = _withdrawalFeeBps;
        nextStrategyUpdate = block.timestamp + STRATEGY_COOLDOWN;

        emit StrategyUpdated(address(0), _strategy);
        emit WithdrawalFeeUpdated(0, _withdrawalFeeBps);
    }

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    // -----------------------------------------------------------------------
    // Pausable controls
    // -----------------------------------------------------------------------

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // -----------------------------------------------------------------------
    // Owner configuration
    // -----------------------------------------------------------------------

    /**
     * @notice Update the yield-generating strategy. Can only be called once
     *         every 24 hours. Any assets invested in the old strategy are
     *         divested and forwarded to the new strategy.
     * @param newStrategy Address of the new strategy contract.
     */
    function setStrategy(address newStrategy) external onlyOwner nonReentrant {
        if (newStrategy == address(0)) revert ZeroAddress();
        if (block.timestamp < nextStrategyUpdate) {
            revert StrategyCooldownNotElapsed(nextStrategyUpdate - block.timestamp);
        }

        address oldStrategy = strategy;

        // Effects: update state before interactions to prevent reentrancy.
        strategy = newStrategy;
        nextStrategyUpdate = block.timestamp + STRATEGY_COOLDOWN;

        // Interactions: divest from the old strategy.
        if (oldStrategy != address(0)) {
            uint256 invested = IStrategy(oldStrategy).totalAssets();
            if (invested > 0) {
                IStrategy(oldStrategy).divest(invested);
            }
        }

        // Invest the current idle balance into the new strategy.
        uint256 idle = asset.balanceOf(address(this)) - accruedFees;
        if (idle > 0) {
            asset.safeIncreaseAllowance(newStrategy, idle);
            IStrategy(newStrategy).invest(idle);
        }

        emit StrategyUpdated(oldStrategy, newStrategy);
    }

    /**
     * @notice Set the withdrawal fee in basis points. Capped at 0.5% (50 bps).
     */
    function setWithdrawalFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsCap(newFeeBps, MAX_FEE_BPS);
        uint256 oldFeeBps = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Collect accrued withdrawal fees to the owner.
     */
    function collectFees() external onlyOwner {
        uint256 amount = accruedFees;
        if (amount == 0) revert ZeroAmount();
        accruedFees = 0;
        asset.safeTransfer(owner(), amount);
        emit FeesCollected(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // User operations
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit `amount` of the underlying asset into the vault.
     * @param amount Amount to deposit.
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused validAmount(amount) {
        asset.safeTransferFrom(msg.sender, address(this), amount);

        userDeposits[msg.sender] += amount;
        totalDeposited += amount;

        // Invest the newly deposited funds into the strategy.
        address strat = strategy;
        asset.safeIncreaseAllowance(strat, amount);
        IStrategy(strat).invest(amount);

        emit Deposit(msg.sender, amount, totalDeposited);
    }

    /**
     * @notice Withdraw `amount` of the underlying asset. A withdrawal fee,
     *         capped at 0.5%, is deducted and retained by the vault.
     * @param amount Amount of principal to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused validAmount(amount) {
        uint256 balance = userDeposits[msg.sender];
        if (balance < amount) revert InsufficientBalance();

        // Effects: update state before interactions.
        userDeposits[msg.sender] = balance - amount;
        totalDeposited -= amount;

        // Calculate fee.
        uint256 fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;
        accruedFees += fee;

        // Divest from strategy to cover the withdrawal if idle balance is insufficient.
        address strat = strategy;
        uint256 idle = asset.balanceOf(address(this)) - accruedFees;
        if (idle < netAmount) {
            IStrategy(strat).divest(netAmount - idle);
        }

        asset.safeTransfer(msg.sender, netAmount);

        emit Withdraw(msg.sender, amount, fee, netAmount);
    }

    /**
     * @notice Claim any available reward tokens accrued by the strategy.
     */
    function claimRewards() external nonReentrant {
        address strat = strategy;
        address rewardToken = IStrategy(strat).rewardToken();
        if (rewardToken == address(0)) revert NoPendingRewards();

        // Harvest rewards from the strategy into this vault.
        uint256 harvested = IStrategy(strat).harvest();
        if (harvested == 0) revert NoPendingRewards();

        // Distribute proportionally to the caller's share of total deposits.
        uint256 userBalance = userDeposits[msg.sender];
        if (userBalance == 0) revert NothingToWithdraw();
        if (totalDeposited == 0) revert NoPendingRewards();

        uint256 userShare = (harvested * userBalance) / totalDeposited;
        if (userShare == 0) revert NoPendingRewards();

        rewardsClaimed[msg.sender] += userShare;

        IERC20(rewardToken).safeTransfer(msg.sender, userShare);

        emit RewardsClaimed(msg.sender, rewardToken, userShare);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    /**
     * @notice Returns the total value managed by the vault: idle balance plus
     *         assets invested in the strategy, minus accrued fees.
     */
    function totalAssets() public view returns (uint256) {
        uint256 idle = asset.balanceOf(address(this)) - accruedFees;
        uint256 invested = IStrategy(strategy).totalAssets();
        return idle + invested;
    }

    /**
     * @notice Returns the user's deposit balance.
     */
    function balanceOf(address user) external view returns (uint256) {
        return userDeposits[user];
    }
}
