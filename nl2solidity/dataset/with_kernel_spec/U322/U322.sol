// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IStakingManager {
    function delegate(address validator, uint256 amount) external;
    function undelegate(address validator, uint256 amount) external returns (uint256);
    function claimRewards(address validator) external returns (uint256);
}

contract LiquidStakingVault {
    /* ------------------------------------------------------------
                            LSD token storage
    ------------------------------------------------------------ */
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /* ------------------------------------------------------------
                            Vault configuration
    ------------------------------------------------------------ */
    IERC20 public immutable underlying;
    IStakingManager public immutable stakingManager;
    address public operator;
    address public treasury;
    uint256 public feePercentage; // basis points, 1000 = 10%
    uint256 public immutable minDeposit; // 0.01 units of the underlying

    /* ------------------------------------------------------------
                            Staking accounting
    ------------------------------------------------------------ */
    uint256 public totalUnderlying; // total underlying backing LSD holders
    uint256 public totalStaked;     // underlying currently delegated to validators
    mapping(address => uint256) public delegatedTo; // per-validator delegated amount

    uint256 public constant MAX_FEE = 5000; // 50% cap
    uint256 public constant FEE_DENOMINATOR = 10000;

    /* ------------------------------------------------------------
                            Reentrancy guard
    ------------------------------------------------------------ */
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    /* ------------------------------------------------------------
                                  Events
    ------------------------------------------------------------ */
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Redeem(address indexed user, uint256 assets, uint256 shares);
    event Staked(address indexed validator, uint256 amount);
    event Unstaked(address indexed validator, uint256 amount);
    event RewardsClaimed(address indexed validator, uint256 gross, uint256 fee, uint256 net);
    event FeePercentageChanged(uint256 oldFee, uint256 newFee);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event LSDTransfer(address indexed from, address indexed to, uint256 value);
    event LSDApproval(address indexed owner, address indexed spender, uint256 value);

    /* ------------------------------------------------------------
                                  Errors
    ------------------------------------------------------------ */
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error BelowMinimumDeposit();
    error ZeroShares();
    error ZeroAssets();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientLiquidity();
    error InsufficientUnstaked();
    error FeeTooHigh();
    error NoRewards();
    error ReentrantCall();
    error TransferFailed();
    error DecimalsTooLow();

    /* ------------------------------------------------------------
                                 Modifiers
    ------------------------------------------------------------ */
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /* ------------------------------------------------------------
                                Constructor
    ------------------------------------------------------------ */
    constructor(
        address _underlying,
        address _stakingManager,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) {
        if (_underlying == address(0) || _stakingManager == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        underlying = IERC20(_underlying);
        stakingManager = IStakingManager(_stakingManager);
        treasury = _treasury;
        operator = msg.sender;
        name = _name;
        symbol = _symbol;

        uint8 ud = underlying.decimals();
        if (ud < 2) revert DecimalsTooLow();
        decimals = ud;
        minDeposit = 10 ** (uint256(ud) - 2);

        feePercentage = 1000; // 10%

        emit OperatorChanged(address(0), msg.sender);
        emit TreasuryChanged(address(0), _treasury);
        emit FeePercentageChanged(0, 1000);
    }

    /* ------------------------------------------------------------
                            Exchange rate views
    ------------------------------------------------------------ */
    function totalAssets() public view returns (uint256) {
        return totalUnderlying;
    }

    function exchangeRate() public view returns (uint256) {
        if (totalSupply > 0) {
            return (totalUnderlying * (10 ** uint256(decimals))) / totalSupply;
        }
        return 10 ** uint256(decimals);
    }

    function sharesForUnderlying(uint256 amount) public view returns (uint256) {
        if (totalUnderlying > 0) {
            return (amount * totalSupply) / totalUnderlying;
        }
        return amount;
    }

    function underlyingForShares(uint256 shares) public view returns (uint256) {
        if (totalSupply > 0) {
            return (shares * totalUnderlying) / totalSupply;
        }
        return 0;
    }

    function availableUnderlying() public view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    /* ------------------------------------------------------------
                              User: deposit
    ------------------------------------------------------------ */
    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        if (amount < minDeposit) revert BelowMinimumDeposit();

        shares = sharesForUnderlying(amount);
        if (shares < 1) revert ZeroShares();

        totalUnderlying += amount;
        totalSupply += shares;
        balanceOf[msg.sender] += shares;

        bool ok = underlying.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit LSDTransfer(address(0), msg.sender, shares);
        emit Deposit(msg.sender, amount, shares);
    }

    /* ------------------------------------------------------------
                              User: redeem
    ------------------------------------------------------------ */
    function redeem(uint256 shares) external nonReentrant returns (uint256 assets) {
        if (shares < 1) revert ZeroAmount();
        if (balanceOf[msg.sender] < shares) revert InsufficientBalance();

        assets = underlyingForShares(shares);
        if (assets < 1) revert ZeroAssets();
        if (underlying.balanceOf(address(this)) < assets) revert InsufficientLiquidity();

        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        totalUnderlying -= assets;

        bool ok = underlying.transfer(msg.sender, assets);
        if (!ok) revert TransferFailed();

        emit LSDTransfer(msg.sender, address(0), shares);
        emit Redeem(msg.sender, assets, shares);
    }

    /* ------------------------------------------------------------
                       Operator: stake with validators
    ------------------------------------------------------------ */
    function stake(address validator, uint256 amount) external onlyOperator nonReentrant {
        if (validator == address(0)) revert ZeroAddress();
        if (amount < 1) revert ZeroAmount();
        if (underlying.balanceOf(address(this)) < amount) revert InsufficientUnstaked();

        // Effects before interactions
        totalStaked += amount;
        delegatedTo[validator] += amount;

        // Interactions
        bool ok = underlying.transfer(address(stakingManager), amount);
        if (!ok) revert TransferFailed();

        stakingManager.delegate(validator, amount);

        emit Staked(validator, amount);
    }

    /* ------------------------------------------------------------
                       Operator: unstake from validators
    ------------------------------------------------------------ */
    function unstake(address validator, uint256 amount) external onlyOperator nonReentrant {
        if (validator == address(0)) revert ZeroAddress();
        if (amount < 1) revert ZeroAmount();
        if (delegatedTo[validator] < amount) revert InsufficientUnstaked();

        // Effects before interactions
        delegatedTo[validator] -= amount;
        totalStaked -= amount;

        // Interactions
        uint256 returned = stakingManager.undelegate(validator, amount);
        if (returned < amount) revert InsufficientLiquidity();

        emit Unstaked(validator, amount);
    }

    /* ------------------------------------------------------------
                       Operator: claim staking rewards
    ------------------------------------------------------------ */
    function claimRewards(address validator)
        external
        onlyOperator
        nonReentrant
        returns (uint256 gross, uint256 fee, uint256 net)
    {
        if (validator == address(0)) revert ZeroAddress();

        // Use the return value from the staking manager rather than relying on
        // a balance snapshot taken before the external call, which avoids
        // stale-balance reentrancy concerns. The staking manager is trusted and
        // immutable, and the nonReentrant guard prevents cross-function
        // reentrancy.
        gross = stakingManager.claimRewards(validator);
        if (gross < 1) revert NoRewards();

        fee = (gross * feePercentage) / FEE_DENOMINATOR;
        net = gross - fee;

        totalUnderlying += net;

        if (fee > 0) {
            bool ok = underlying.transfer(treasury, fee);
            if (!ok) revert TransferFailed();
        }

        emit RewardsClaimed(validator, gross, fee, net);
    }

    /* ------------------------------------------------------------
                       Operator: set fee percentage
    ------------------------------------------------------------ */
    function setFeePercentage(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE) revert FeeTooHigh();
        emit FeePercentageChanged(feePercentage, newFee);
        feePercentage = newFee;
    }

    /* ------------------------------------------------------------
                       Operator: admin controls
    ------------------------------------------------------------ */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    /* ------------------------------------------------------------
                       LSD token: ERC20 transfers
    ------------------------------------------------------------ */
    function transfer(address to, uint256 value) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < value) revert InsufficientBalance();

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit LSDTransfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = value;
        emit LSDApproval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed < type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - value;
        }

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit LSDTransfer(from, to, value);
        return true;
    }
}
