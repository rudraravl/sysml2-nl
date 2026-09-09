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
        bool success = token.transfer(to, amount);
        if (!success) {
            // Revert with the return data if available, otherwise generic error
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool success = token.approve(spender, amount);
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NewOwnerIsZeroAddress();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert NewOwnerIsZeroAddress();
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert NewOwnerIsZeroAddress();
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;

    error ReentrantCall();

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IYieldStrategy {
    function deploy(uint256 amount) external returns (uint256 shares);
    function redeem(uint256 shares) external returns (uint256 amount);
    function balanceOf(address account) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

contract GoldVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error NotOperator();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error ExceedsMaxLTV();
    error NoYieldToClaim();
    error InsufficientAvailableFunds();
    error InsufficientStrategyShares();
    error ArrayLengthMismatch();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event YieldDistributed(uint256 grossYield, uint256 fee, uint256 netYield);
    event YieldClaimed(address indexed user, uint256 amount);
    event Borrowed(address indexed operator, uint256 amount);
    event Repaid(address indexed operator, uint256 amount);
    event Deployed(address indexed strategy, uint256 amount, uint256 sharesReceived);
    event Redeemed(address indexed strategy, uint256 shares, uint256 amountReturned);
    event StrategyApproved(address indexed strategy);
    event StrategyRevoked(address indexed strategy);
    event OperatorSet(address indexed operator);
    event FeeRecipientSet(address indexed feeRecipient);
    event MaxLTVSet(uint256 maxLTV);
    event YieldFeeSet(uint256 yieldFee);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable goldToken;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    address public operator;
    address public feeRecipient;

    /// @notice Maximum loan-to-value ratio in basis points (7000 = 70%).
    uint256 public maxLTV;

    /// @notice Fee applied to yield distributions in basis points (50 = 0.5%).
    uint256 public yieldFee;

    /// @notice Total gold collateral deposited in the vault.
    uint256 public totalGoldDeposits;

    /// @notice Total borrowed amount outstanding against the collateral.
    uint256 public totalBorrowed;

    /// @notice Total capital deployed into strategies.
    uint256 public totalDeployed;

    /// @notice Per-user deposited gold balance.
    mapping(address => uint256) public userDeposits;

    /// @notice Cumulative yield per deposited token, scaled by PRECISION.
    uint256 public cumulativeYieldPerToken;

    /// @notice Last cumulative yield per token recorded for each user.
    mapping(address => uint256) public userYieldDebt;

    /// @notice Approved yield-generating strategies.
    mapping(address => bool) public approvedStrategies;

    /// @notice Shares held by the vault in each strategy.
    mapping(address => uint256) public strategyShares;

    /// @notice Principal deployed into each strategy.
    mapping(address => uint256) public strategyPrincipal;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyApprovedStrategy(address strategy) {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _goldToken,
        address _operator,
        address _feeRecipient,
        uint256 _maxLTV,
        uint256 _yieldFee
    ) Ownable(msg.sender) {
        if (_goldToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_maxLTV > BASIS_POINTS) revert ExceedsMaxLTV();
        if (_yieldFee > BASIS_POINTS) revert ZeroAmount();

        goldToken = IERC20(_goldToken);
        operator = _operator;
        feeRecipient = _feeRecipient;
        maxLTV = _maxLTV;
        yieldFee = _yieldFee;

        emit OperatorSet(_operator);
        emit FeeRecipientSet(_feeRecipient);
        emit MaxLTVSet(_maxLTV);
        emit YieldFeeSet(_yieldFee);
    }

    /*//////////////////////////////////////////////////////////////
                          USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits gold tokens into the vault.
    /// @param amount The amount of gold tokens to deposit.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _claimYieldInternal(msg.sender);

        userDeposits[msg.sender] += amount;
        totalGoldDeposits += amount;

        userYieldDebt[msg.sender] =
            (userDeposits[msg.sender] * cumulativeYieldPerToken) /
            PRECISION;

        goldToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    /// @notice Withdraws deposited gold tokens from the vault.
    /// @param amount The amount of gold tokens to withdraw.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 balance = userDeposits[msg.sender];
        if (balance < amount) revert InsufficientBalance();

        _claimYieldInternal(msg.sender);

        uint256 newTotalCollateral = totalGoldDeposits - amount;

        // Enforce max LTV after withdrawal
        if (totalBorrowed > (newTotalCollateral * maxLTV) / BASIS_POINTS) {
            revert ExceedsMaxLTV();
        }

        userDeposits[msg.sender] = balance - amount;
        totalGoldDeposits = newTotalCollateral;

        userYieldDebt[msg.sender] =
            (userDeposits[msg.sender] * cumulativeYieldPerToken) /
            PRECISION;

        goldToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Claims accrued yield for the caller.
    function claimYield() external nonReentrant {
        uint256 balance = userDeposits[msg.sender];
        uint256 accumulated = (balance * cumulativeYieldPerToken) / PRECISION;

        if (accumulated <= userYieldDebt[msg.sender]) revert NoYieldToClaim();

        uint256 pending = accumulated - userYieldDebt[msg.sender];
        userYieldDebt[msg.sender] = accumulated;

        goldToken.safeTransfer(msg.sender, pending);

        emit YieldClaimed(msg.sender, pending);
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrows gold tokens against the total collateral, enforcing max LTV.
    /// @param amount The amount to borrow and transfer to the operator.
    function borrow(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 newTotalBorrowed = totalBorrowed + amount;
        uint256 maxBorrowable = (totalGoldDeposits * maxLTV) / BASIS_POINTS;

        if (newTotalBorrowed > maxBorrowable) revert ExceedsMaxLTV();

        totalBorrowed = newTotalBorrowed;

        goldToken.safeTransfer(operator, amount);

        emit Borrowed(msg.sender, amount);
    }

    /// @notice Repays borrowed gold, reducing total outstanding debt.
    /// @param amount The amount to repay.
    function repayBorrow(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (totalBorrowed < amount) revert InsufficientBalance();

        totalBorrowed -= amount;

        goldToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Repaid(msg.sender, amount);
    }

    /// @notice Deploys borrowed capital into an approved yield-generating strategy.
    /// @param strategy The address of the approved strategy.
    /// @param amount The amount of gold tokens to deploy.
    function deployToStrategy(address strategy, uint256 amount)
        external
        onlyOperator
        onlyApprovedStrategy(strategy)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        uint256 available = totalBorrowed - totalDeployed;
        if (amount > available) revert InsufficientAvailableFunds();

        uint256 sharesBefore = IYieldStrategy(strategy).balanceOf(address(this));

        goldToken.safeTransfer(strategy, amount);
        uint256 sharesReceived = IYieldStrategy(strategy).deploy(amount);

        if (sharesReceived == 0) revert ZeroAmount();

        uint256 sharesAfter = IYieldStrategy(strategy).balanceOf(address(this));
        if (sharesAfter != sharesBefore + sharesReceived) revert InsufficientBalance();

        strategyShares[strategy] += sharesReceived;
        strategyPrincipal[strategy] += amount;
        totalDeployed += amount;

        emit Deployed(strategy, amount, sharesReceived);
    }

    /// @notice Redeems positions from a strategy, returning capital and yield to the vault.
    /// @param strategy The address of the approved strategy.
    /// @param shares The number of strategy shares to redeem.
    function redeemFromStrategy(address strategy, uint256 shares)
        external
        onlyOperator
        onlyApprovedStrategy(strategy)
        nonReentrant
    {
        if (shares == 0) revert ZeroAmount();
        if (strategyShares[strategy] < shares) revert InsufficientStrategyShares();

        uint256 principalBefore = strategyPrincipal[strategy];
        uint256 totalSharesBefore = strategyShares[strategy];

        strategyShares[strategy] -= shares;

        uint256 amountReturned = IYieldStrategy(strategy).redeem(shares);
        if (amountReturned == 0) revert ZeroAmount();

        // Determine principal portion vs yield using proportion of shares redeemed
        uint256 principalPortion = (principalBefore * shares) / totalSharesBefore;

        strategyPrincipal[strategy] -= principalPortion;
        totalDeployed -= principalPortion;

        uint256 yieldPortion = amountReturned > principalPortion
            ? amountReturned - principalPortion
            : 0;

        if (yieldPortion > 0) {
            _distributeYield(yieldPortion);
        }

        emit Redeemed(strategy, shares, amountReturned);
    }

    /// @notice Distributes yield to depositors proportionally, applying the yield fee.
    /// @dev Yield tokens are pulled from the operator and distributed via a cumulative index.
    /// @param yieldAmount The total gross yield to distribute.
    function distributeYield(uint256 yieldAmount) external onlyOperator nonReentrant {
        if (yieldAmount == 0) revert ZeroAmount();

        goldToken.safeTransferFrom(msg.sender, address(this), yieldAmount);

        _distributeYield(yieldAmount);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Approves a yield-generating strategy.
    function approveStrategy(address strategy) external onlyOwner {
        if (strategy == address(0)) revert ZeroAddress();
        if (approvedStrategies[strategy]) revert StrategyAlreadyApproved();
        approvedStrategies[strategy] = true;
        emit StrategyApproved(strategy);
    }

    /// @notice Revokes a previously approved strategy.
    function revokeStrategy(address strategy) external onlyOwner {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        approvedStrategies[strategy] = false;
        emit StrategyRevoked(strategy);
    }

    /// @notice Sets the operator address.
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    /// @notice Sets the fee recipient address.
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientSet(_feeRecipient);
    }

    /// @notice Sets the maximum loan-to-value ratio.
    /// @param _maxLTV The new max LTV in basis points (e.g., 7000 = 70%).
    function setMaxLTV(uint256 _maxLTV) external onlyOwner {
        if (_maxLTV > BASIS_POINTS) revert ExceedsMaxLTV();
        maxLTV = _maxLTV;
        emit MaxLTVSet(_maxLTV);
    }

    /// @notice Sets the yield fee.
    /// @param _yieldFee The new yield fee in basis points (e.g., 50 = 0.5%).
    function setYieldFee(uint256 _yieldFee) external onlyOwner {
        if (_yieldFee > BASIS_POINTS) revert ZeroAmount();
        yieldFee = _yieldFee;
        emit YieldFeeSet(_yieldFee);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the maximum borrowable amount given current collateral.
    function maxBorrowable() external view returns (uint256) {
        return (totalGoldDeposits * maxLTV) / BASIS_POINTS;
    }

    /// @notice Returns the current LTV ratio in basis points.
    function currentLTV() external view returns (uint256) {
        if (totalGoldDeposits == 0) return 0;
        return (totalBorrowed * BASIS_POINTS) / totalGoldDeposits;
    }

    /// @notice Returns a user's pending claimable yield.
    function pendingYield(address user) external view returns (uint256) {
        uint256 accumulated = (userDeposits[user] * cumulativeYieldPerToken) /
            PRECISION;
        if (accumulated <= userYieldDebt[user]) return 0;
        return accumulated - userYieldDebt[user];
    }

    /// @notice Returns the available (undeployed) borrowed funds.
    function availableFunds() external view returns (uint256) {
        return totalBorrowed - totalDeployed;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Claims pending yield for a user and resets their reward debt.
    function _claimYieldInternal(address user) internal {
        uint256 balance = userDeposits[user];
        uint256 accumulated = (balance * cumulativeYieldPerToken) / PRECISION;

        if (accumulated <= userYieldDebt[user]) return;

        uint256 pending = accumulated - userYieldDebt[user];
        userYieldDebt[user] = accumulated;

        goldToken.safeTransfer(user, pending);

        emit YieldClaimed(user, pending);
    }

    /// @dev Distributes yield proportionally using a cumulative per-token index.
    function _distributeYield(uint256 grossYield) internal {
        uint256 fee = (grossYield * yieldFee) / BASIS_POINTS;
        uint256 netYield = grossYield - fee;

        if (fee > 0) {
            goldToken.safeTransfer(feeRecipient, fee);
        }

        if (totalGoldDeposits > 0) {
            cumulativeYieldPerToken +=
                (netYield * PRECISION) /
                totalGoldDeposits;
        }

        emit YieldDistributed(grossYield, fee, netYield);
    }
}
