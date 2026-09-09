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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(address(token).code.length > 0, "SafeERC20: call to non-contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(address(token).code.length > 0, "SafeERC20: call to non-contract");
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

error ZeroAddress();
error ZeroAmount();
error AmountBelowMinimum();
error NotOwner();
error Unauthorized();
error FeeExceedsCap();
error AssetNotApproved();
error AssetPaused();
error InvestmentsPaused();
error RedemptionsPaused();
error InsufficientBalance(uint256 available, uint256 required);
error PortfolioCapExceeded(uint256 remaining, uint256 requested);
error PortfolioAlreadyApproved();
error SharesTooSmall();
error InvalidShareRatio();
error ReentrantCall();

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title StablecoinAssetPool
 * @notice A pool that accepts stablecoin deposits and routes them into
 *         operator-approved tokenized real-world asset portfolios. Users
 *         deposit a stablecoin, hold an internal redeemable balance, and may
 *         convert that balance into proportional shares of an approved
 *         portfolio. A separate operator role is responsible for approving
 *         portfolios, pausing activity, and adjusting the deposit fee (capped
 *         at 0.5%).
 */
contract StablecoinAssetPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @dev 0.5% expressed in basis points.
    uint16 public constant MAX_DEPOSIT_FEE_BPS = 50;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant SHARE_PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    IERC20 public immutable stablecoin;

    /// @notice Address empowered to approve portfolios, toggle pauses, and set fees.
    address public operator;

    /// @notice Current deposit fee in basis points (0 .. MAX_DEPOSIT_FEE_BPS).
    uint16 public depositFeeBps;

    /// @notice Stablecoin fees accrued by the protocol, withdrawable by the operator.
    uint256 public accruedFees;

    /// @notice Credited stablecoin balance per user (net of deposit fees).
    mapping(address => uint256) public userBalances;

    /// @notice Total stablecoin currently credited across all users.
    uint256 public totalDeposited;

    struct AssetPortfolio {
        bool approved;
        bool active;
        string name;
        uint256 cap;
        uint256 totalStableCommitted;
        uint256 totalSharesIssued;
    }

    /// @notice Portfolio parameters keyed by portfolio address.
    mapping(address => AssetPortfolio) public portfolios;
    address[] public portfolioList;

    /// @notice Shares owned by each user within each portfolio.
    mapping(address => mapping(address => uint256)) public portfolioShares;

    /// @notice Total shares held by a user across all portfolios.
    mapping(address => uint256) public totalUserShares;

    struct GlobalConfig {
        bool investmentsPaused;
        bool redemptionsPaused;
        uint256 minDepositAmount;
        uint256 minRedeemAmount;
        uint256 minInvestAmount;
    }

    GlobalConfig public globalConfig;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amountDeposited, uint256 amountCredited, uint256 fee);
    event Redemption(address indexed user, uint256 amount);
    event Investment(address indexed user, address indexed portfolio, uint256 stableAmount, uint256 sharesIssued);
    event InvestmentExit(address indexed user, address indexed portfolio, uint256 shares, uint256 stableAmount);
    event PortfolioApproved(address indexed portfolio, string name, uint256 cap);
    event PortfolioStatusChanged(address indexed portfolio, bool active);
    event PortfolioCapUpdated(address indexed portfolio, uint256 oldCap, uint256 newCap);
    event DepositFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event GlobalConfigUpdated(
        bool investmentsPaused,
        bool redemptionsPaused,
        uint256 minDeposit,
        uint256 minRedeem,
        uint256 minInvest
    );
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(
        address stablecoin_,
        address operator_,
        uint16 depositFeeBps_
    ) {
        if (stablecoin_ == address(0) || operator_ == address(0)) revert ZeroAddress();
        if (depositFeeBps_ > MAX_DEPOSIT_FEE_BPS) revert FeeExceedsCap();

        stablecoin = IERC20(stablecoin_);
        operator = operator_;
        depositFeeBps = depositFeeBps_;

        globalConfig = GlobalConfig({
            investmentsPaused: false,
            redemptionsPaused: false,
            minDepositAmount: 1e6,
            minRedeemAmount: 1e6,
            minInvestAmount: 1e6
        });

        emit OperatorUpdated(address(0), operator_);
        emit DepositFeeUpdated(0, depositFeeBps_);
    }

    // ---------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------

    /**
     * @notice Transfers the operator role to a new address. Only the owner may do this.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Approves a new asset portfolio for investment.
     * @param portfolio On-chain identifier (address) of the portfolio.
     * @param name Human-readable name of the portfolio.
     * @param cap Maximum stablecoin that may be committed to this portfolio.
     */
    function approvePortfolio(
        address portfolio,
        string calldata name,
        uint256 cap
    ) external onlyOperator {
        if (portfolio == address(0)) revert ZeroAddress();
        AssetPortfolio storage p = portfolios[portfolio];
        if (p.approved) revert PortfolioAlreadyApproved();

        p.approved = true;
        p.active = true;
        p.name = name;
        p.cap = cap;

        portfolioList.push(portfolio);
        emit PortfolioApproved(portfolio, name, cap);
    }

    /**
     * @notice Pauses or unpauses investment activity for an approved portfolio.
     */
    function setPortfolioActive(address portfolio, bool active) external onlyOperator {
        if (!portfolios[portfolio].approved) revert AssetNotApproved();
        portfolios[portfolio].active = active;
        emit PortfolioStatusChanged(portfolio, active);
    }

    /**
     * @notice Updates the maximum stablecoin commitment for an approved portfolio.
     */
    function setPortfolioCap(address portfolio, uint256 newCap) external onlyOperator {
        AssetPortfolio storage p = portfolios[portfolio];
        if (!p.approved) revert AssetNotApproved();
        if (newCap < p.totalStableCommitted) revert PortfolioCapExceeded(newCap, p.totalStableCommitted);
        uint256 oldCap = p.cap;
        p.cap = newCap;
        emit PortfolioCapUpdated(portfolio, oldCap, newCap);
    }

    /**
     * @notice Adjusts the deposit fee, hard-capped at 0.5% (50 bps).
     */
    function setDepositFee(uint16 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_DEPOSIT_FEE_BPS) revert FeeExceedsCap();
        uint16 old = depositFeeBps;
        depositFeeBps = newFeeBps;
        emit DepositFeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Updates the global investment strategy configuration.
     */
    function setGlobalConfig(
        bool investmentsPaused,
        bool redemptionsPaused,
        uint256 minDepositAmount,
        uint256 minRedeemAmount,
        uint256 minInvestAmount
    ) external onlyOperator {
        globalConfig = GlobalConfig({
            investmentsPaused: investmentsPaused,
            redemptionsPaused: redemptionsPaused,
            minDepositAmount: minDepositAmount,
            minRedeemAmount: minRedeemAmount,
            minInvestAmount: minInvestAmount
        });
        emit GlobalConfigUpdated(
            investmentsPaused,
            redemptionsPaused,
            minDepositAmount,
            minRedeemAmount,
            minInvestAmount
        );
    }

    /**
     * @notice Withdraws accrued protocol fees to a recipient.
     */
    function withdrawFees(address to, uint256 amount) external onlyOperator nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accruedFees) revert InsufficientBalance(accruedFees, amount);

        accruedFees -= amount;
        stablecoin.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    // ---------------------------------------------------------------------
    // User operations
    // ---------------------------------------------------------------------

    /**
     * @notice Deposits stablecoins into the pool. A fee (capped at 0.5%) may
     *         be deducted and retained by the protocol; the remainder is
     *         credited to the caller's internal balance.
     */
    function deposit(uint256 amount) external nonReentrant {
        GlobalConfig memory cfg = globalConfig;
        if (amount == 0) revert ZeroAmount();
        if (amount < cfg.minDepositAmount) revert AmountBelowMinimum();

        uint256 fee = (amount * uint256(depositFeeBps)) / BPS_DENOMINATOR;
        uint256 credited = amount - fee;

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        userBalances[msg.sender] += credited;
        totalDeposited += credited;
        accruedFees += fee;

        emit Deposit(msg.sender, amount, credited, fee);
    }

    /**
     * @notice Redeems part or all of the caller's credited stablecoin balance.
     */
    function redeem(uint256 amount) external nonReentrant {
        GlobalConfig memory cfg = globalConfig;
        if (cfg.redemptionsPaused) revert RedemptionsPaused();
        if (amount == 0) revert ZeroAmount();
        if (amount < cfg.minRedeemAmount) revert AmountBelowMinimum();

        uint256 available = userBalances[msg.sender];
        if (amount > available) revert InsufficientBalance(available, amount);

        // Effects
        userBalances[msg.sender] = available - amount;
        totalDeposited -= amount;

        // Interaction
        stablecoin.safeTransfer(msg.sender, amount);

        emit Redemption(msg.sender, amount);
    }

    /**
     * @notice Converts a portion of the caller's stablecoin balance into
     *         proportional shares of an approved, active asset portfolio.
     */
    function invest(address portfolio, uint256 stableAmount) external nonReentrant {
        GlobalConfig memory cfg = globalConfig;
        if (cfg.investmentsPaused) revert InvestmentsPaused();
        if (portfolio == address(0)) revert ZeroAddress();
        if (stableAmount == 0) revert ZeroAmount();
        if (stableAmount < cfg.minInvestAmount) revert AmountBelowMinimum();

        AssetPortfolio storage p = portfolios[portfolio];
        if (!p.approved) revert AssetNotApproved();
        if (!p.active) revert AssetPaused();

        uint256 available = userBalances[msg.sender];
        if (stableAmount > available) revert InsufficientBalance(available, stableAmount);

        uint256 remainingCap = p.cap - p.totalStableCommitted;
        if (stableAmount > remainingCap) revert PortfolioCapExceeded(remainingCap, stableAmount);

        // Compute shares proportionally. On the very first commitment shares
        // are minted 1:1 (scaled by SHARE_PRECISION) with the stable amount.
        uint256 shares;
        if (p.totalSharesIssued == 0 || p.totalStableCommitted == 0) {
            shares = stableAmount * SHARE_PRECISION;
        } else {
            shares = (stableAmount * p.totalSharesIssued) / p.totalStableCommitted;
        }
        if (shares == 0) revert SharesTooSmall();

        // Effects
        userBalances[msg.sender] = available - stableAmount;
        totalDeposited -= stableAmount;

        p.totalStableCommitted += stableAmount;
        p.totalSharesIssued += shares;

        portfolioShares[msg.sender][portfolio] += shares;
        totalUserShares[msg.sender] += shares;

        emit Investment(msg.sender, portfolio, stableAmount, shares);
    }

    /**
     * @notice Exits a portfolio by burning shares and crediting the
     *         corresponding stablecoin amount back to the caller's balance.
     *         This is the inverse of `invest` and does not move any tokens out
     *         of the pool until the user separately calls `redeem`.
     */
    function exitInvestment(address portfolio, uint256 shares) external nonReentrant {
        if (portfolio == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();

        AssetPortfolio storage p = portfolios[portfolio];
        if (!p.approved || p.totalSharesIssued == 0) revert AssetNotApproved();

        uint256 userHolding = portfolioShares[msg.sender][portfolio];
        if (shares > userHolding) revert InsufficientBalance(userHolding, shares);

        uint256 stableAmount = (shares * p.totalStableCommitted) / p.totalSharesIssued;
        if (stableAmount == 0) revert InvalidShareRatio();

        // Effects
        portfolioShares[msg.sender][portfolio] = userHolding - shares;
        totalUserShares[msg.sender] -= shares;

        p.totalSharesIssued -= shares;
        p.totalStableCommitted -= stableAmount;

        userBalances[msg.sender] += stableAmount;
        totalDeposited += stableAmount;

        emit InvestmentExit(msg.sender, portfolio, shares, stableAmount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function portfolioCount() external view returns (uint256) {
        return portfolioList.length;
    }

    function getPortfolio(address portfolio)
        external
        view
        returns (
            bool approved,
            bool active,
            string memory name,
            uint256 cap,
            uint256 totalStableCommitted,
            uint256 totalSharesIssued
        )
    {
        AssetPortfolio storage p = portfolios[portfolio];
        return (p.approved, p.active, p.name, p.cap, p.totalStableCommitted, p.totalSharesIssued);
    }

    function getUserPortfolioShares(address user, address portfolio) external view returns (uint256) {
        return portfolioShares[user][portfolio];
    }

    function getUserBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }

    function getGlobalConfig()
        external
        view
        returns (
            bool investmentsPaused,
            bool redemptionsPaused,
            uint256 minDepositAmount,
            uint256 minRedeemAmount,
            uint256 minInvestAmount
        )
    {
        GlobalConfig memory cfg = globalConfig;
        return (
            cfg.investmentsPaused,
            cfg.redemptionsPaused,
            cfg.minDepositAmount,
            cfg.minRedeemAmount,
            cfg.minInvestAmount
        );
    }
}
