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

contract YieldBearingStablecoin {
    // --- Token metadata ---
    string private constant _name = "Yield Bearing Stablecoin";
    string private constant _symbol = "YBS";
    uint8 private constant _decimals = 18;

    // --- Underlying & constants ---
    IERC20 public immutable underlying;
    uint256 public constant MIN_DEPOSIT = 10 * 10**18;
    uint256 public constant REDEMPTION_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant RATE_PRECISION = 10**18;
    uint256 public constant FEE_SCALE_FACTOR = RATE_PRECISION * BPS_DENOMINATOR;

    // --- State ---
    address public operator;
    bool public paused;
    uint256 public exchangeRate;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // --- Events ---
    event Deposit(address indexed sender, address indexed recipient, uint256 underlyingAmount, uint256 ybsMinted);
    event Redemption(address indexed sender, address indexed recipient, uint256 ybsBurned, uint256 underlyingReturned, uint256 fee);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // --- Errors ---
    error ZeroAddress();
    error NotOperator();
    error WhenPaused();
    error WhenNotPaused();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidExchangeRate();
    error ZeroAmount();
    error InvalidFee();
    error TransferFailed();
    error NoSurplus();

    // --- Modifiers ---
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    // --- Constructor ---
    constructor(address _underlying, address _operator) {
        if (_underlying == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        underlying = IERC20(_underlying);
        operator = _operator;
        exchangeRate = RATE_PRECISION;
        emit OperatorChanged(address(0), _operator);
    }

    // --- ERC20 metadata views ---
    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    // --- Core: Deposit ---
    function deposit(address recipient, uint256 underlyingAmount) external whenNotPaused returns (uint256 ybsMinted) {
        if (recipient == address(0)) revert ZeroAddress();
        if (underlyingAmount < MIN_DEPOSIT) revert DepositTooSmall();

        ybsMinted = (underlyingAmount * RATE_PRECISION) / exchangeRate;
        if (ybsMinted == 0) revert ZeroAmount();

        // Effects
        _balances[recipient] += ybsMinted;
        _totalSupply += ybsMinted;

        // Interactions
        bool ok = underlying.transferFrom(msg.sender, address(this), underlyingAmount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, recipient, underlyingAmount, ybsMinted);
        emit Transfer(address(0), recipient, ybsMinted);
    }

    // --- Core: Redeem ---
    function redeem(address recipient, uint256 ybsAmount) external whenNotPaused returns (uint256 underlyingReturned, uint256 fee) {
        if (recipient == address(0)) revert ZeroAddress();
        if (ybsAmount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < ybsAmount) revert InsufficientBalance();

        // Compute the raw product once to preserve full precision and avoid
        // divide-before-multiply rounding loss when calculating the fee.
        uint256 rawProduct = ybsAmount * exchangeRate;

        // Gross underlying the shares are worth (rounded down).
        uint256 grossUnderlying = rawProduct / RATE_PRECISION;

        // Fee computed from the unrounded raw product to prevent precision loss.
        // Equivalent to (grossUnderlying * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR
        // but without the intermediate rounding from the first division.
        fee = (rawProduct * REDEMPTION_FEE_BPS) / FEE_SCALE_FACTOR;

        if (fee >= grossUnderlying) revert InvalidFee();
        underlyingReturned = grossUnderlying - fee;

        // Effects
        _balances[msg.sender] -= ybsAmount;
        _totalSupply -= ybsAmount;

        // Interactions
        bool ok = underlying.transfer(recipient, underlyingReturned);
        if (!ok) revert TransferFailed();

        emit Redemption(msg.sender, recipient, ybsAmount, underlyingReturned, fee);
        emit Transfer(msg.sender, address(0), ybsAmount);
    }

    // --- ERC20 transfer ---
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // --- Operator: exchange rate ---
    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    // --- Operator: pause / unpause ---
    function pause() external onlyOperator {
        if (paused) revert WhenPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert WhenNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setPaused(bool _paused) external onlyOperator {
        if (_paused) {
            if (paused) revert WhenPaused();
            paused = true;
            emit Paused(msg.sender);
        } else {
            if (!paused) revert WhenNotPaused();
            paused = false;
            emit Unpaused(msg.sender);
        }
    }

    // --- Operator: rotate operator ---
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // --- Operator: withdraw accumulated fees / surplus ---
    function withdrawFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 backing = (_totalSupply * exchangeRate) / RATE_PRECISION;
        uint256 held = underlying.balanceOf(address(this));
        if (held <= backing) revert NoSurplus();
        uint256 surplus = held - backing;
        bool ok = underlying.transfer(to, surplus);
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(to, surplus);
    }

    // --- Views ---
    function underlyingBalanceOfContract() external view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    function getUnderlyingValue(uint256 ybsAmount) external view returns (uint256) {
        return (ybsAmount * exchangeRate) / RATE_PRECISION;
    }

    function getYbsValue(uint256 underlyingAmount) external view returns (uint256) {
        return (underlyingAmount * RATE_PRECISION) / exchangeRate;
    }
}
