// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract LiquidStaking {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error NotPaused();
    error BelowMinDeposit();
    error InsufficientLST();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidRate();
    error NoPendingRewards();
    error TransferFailed();
    error CannotRescueStakingTokens();
    error ReentrancyGuardReentrantCall();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event RewardClaim(address indexed claimant, uint256 amount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event PausedStateChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event RewardsNotified(uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 public constant RATE_DENOMINATOR = 1e18;
    uint256 public constant MIN_DEPOSIT = 10 * 1e18; // 10 units (assuming 18 decimals)

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    IERC20 public immutable baseToken;
    IERC20 public immutable rewardToken;

    address public owner;
    address public operator;

    bool public paused;

    /// @notice Exchange rate: how many LST tokens (scaled by 1e18) are minted per 1 base token.
    uint256 public exchangeRate;

    uint256 public totalBaseDeposited;
    uint256 public totalLSTIssued;
    mapping(address => uint256) public lstBalance;

    // Rewards distribution (index-based, per LST token)
    uint256 public rewardPerLSTStored;
    uint256 public pendingRewards; // rewards notified but not yet accrued into the index
    mapping(address => uint256) public userRewardPerLSTPaid;
    mapping(address => uint256) public rewards;

    // Reentrancy guard
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    modifier nonZeroAddress(address a) {
        if (a == address(0)) revert ZeroAddress();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(
        address baseToken_,
        address rewardToken_,
        address operator_,
        uint256 initialRate_
    )
        nonZeroAddress(baseToken_)
        nonZeroAddress(rewardToken_)
        nonZeroAddress(operator_)
    {
        if (initialRate_ == 0) revert InvalidRate();
        baseToken = IERC20(baseToken_);
        rewardToken = IERC20(rewardToken_);
        operator = operator_;
        exchangeRate = initialRate_;
        owner = msg.sender;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), operator_);
        emit ExchangeRateUpdated(0, initialRate_);
    }

    // -------------------------------------------------------------------------
    // Admin functions
    // -------------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner nonZeroAddress(newOwner) {
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner nonZeroAddress(newOperator) {
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    function setPaused(bool state) external onlyOperator {
        paused = state;
        emit PausedStateChanged(state);
    }

    function pause() external onlyOperator {
        if (paused) revert EnforcedPause();
        paused = true;
        emit PausedStateChanged(true);
    }

    function unpause() external onlyOperator {
        if (!paused) revert NotPaused();
        paused = false;
        emit PausedStateChanged(false);
    }

    // -------------------------------------------------------------------------
    // Rewards
    // -------------------------------------------------------------------------
    /// @notice Operator notifies the contract of newly available rewards.
    ///         The reward tokens must be transferred from the operator to this contract.
    function notifyRewards(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateGlobalReward();
        pendingRewards += amount;
        bool ok = rewardToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit RewardsNotified(amount);
    }

    function _updateGlobalReward() internal {
        if (pendingRewards > 0 && totalLSTIssued > 0) {
            rewardPerLSTStored += (pendingRewards * RATE_DENOMINATOR) / totalLSTIssued;
            pendingRewards = 0;
        }
    }

    function _updateAccountReward(address account) internal {
        _updateGlobalReward();
        uint256 paid = userRewardPerLSTPaid[account];
        if (rewardPerLSTStored > paid) {
            rewards[account] += (lstBalance[account] * (rewardPerLSTStored - paid)) / RATE_DENOMINATOR;
            userRewardPerLSTPaid[account] = rewardPerLSTStored;
        }
    }

    function pendingRewardsOf(address account) external view returns (uint256) {
        if (totalLSTIssued == 0) return rewards[account];
        uint256 pendingIndex = rewardPerLSTStored;
        if (pendingRewards > 0) {
            pendingIndex += (pendingRewards * RATE_DENOMINATOR) / totalLSTIssued;
        }
        uint256 paid = userRewardPerLSTPaid[account];
        return rewards[account] + (lstBalance[account] * (pendingIndex - paid)) / RATE_DENOMINATOR;
    }

    // -------------------------------------------------------------------------
    // Staking operations
    // -------------------------------------------------------------------------
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount < MIN_DEPOSIT) revert BelowMinDeposit();

        // Update rewards based on the current (pre-deposit) balance.
        _updateAccountReward(msg.sender);

        // Calculate LST to mint before any external interaction.
        uint256 lstToMint = (amount * exchangeRate) / RATE_DENOMINATOR;
        if (lstToMint == 0) revert ZeroAmount();

        // Effects: update state before the external token transfer.
        totalBaseDeposited += amount;
        totalLSTIssued += lstToMint;
        lstBalance[msg.sender] += lstToMint;

        // Interaction: pull base tokens from the depositor.
        bool ok = baseToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 lstAmount) external whenNotPaused nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (lstAmount > lstBalance[msg.sender]) revert InsufficientLST();

        // Update rewards before changing the user's balance.
        _updateAccountReward(msg.sender);

        uint256 baseToReturn = (lstAmount * RATE_DENOMINATOR) / exchangeRate;

        // Effects: update state before the external token transfer.
        totalLSTIssued -= lstAmount;
        lstBalance[msg.sender] -= lstAmount;
        totalBaseDeposited -= baseToReturn;

        // Interaction: return base tokens to the withdrawer.
        bool ok = baseToken.transfer(msg.sender, baseToReturn);
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, baseToReturn);
    }

    function claimRewards() external nonReentrant {
        _updateAccountReward(msg.sender);
        uint256 amount = rewards[msg.sender];
        if (amount == 0) revert NoPendingRewards();

        // Effects: zero out rewards before transferring.
        rewards[msg.sender] = 0;

        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        uint256 userAmount = amount - fee;

        // Interactions: transfer fee and net reward.
        if (fee > 0) {
            bool feeOk = rewardToken.transfer(owner, fee);
            if (!feeOk) revert TransferFailed();
        }
        bool ok = rewardToken.transfer(msg.sender, userAmount);
        if (!ok) revert TransferFailed();

        emit RewardClaim(msg.sender, amount);
    }

    // -------------------------------------------------------------------------
    // Rescue (owner only)
    // -------------------------------------------------------------------------
    /// @notice Allows the owner to recover tokens accidentally sent to the contract.
    ///         Cannot rescue baseToken or rewardToken to protect stakers/rewards.
    function rescueToken(address token, uint256 amount) external onlyOwner nonZeroAddress(token) nonReentrant {
        if (token == address(baseToken) || token == address(rewardToken)) revert CannotRescueStakingTokens();
        bool ok = IERC20(token).transfer(owner, amount);
        if (!ok) revert TransferFailed();
    }
}
