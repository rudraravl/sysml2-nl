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
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returnData) = address(token).call(data);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let data_size := mload(returnData)
                    revert(add(returnData, 32), data_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

contract YieldStableVault {
    using SafeERC20 for IERC20;

    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error DepositTooSmall(uint256 amount, uint256 minimum);
    error InsufficientBalance();
    error InsufficientAllowance();
    error LockupNotElapsed(uint256 availableAt);
    error SameUnderlying();
    error ReentrancyGuard();
    error StrategyNotApproved();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed user, uint256 underlyingAmount, uint256 yieldTokenAmount);
    event Withdraw(address indexed user, uint256 underlyingAmount, uint256 yieldTokenAmount, uint256 fee);
    event Redeem(address indexed user, uint256 underlyingAmount, uint256 yieldTokenAmount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event UnderlyingUpdated(address indexed previousUnderlying, address indexed newUnderlying);
    event LockupPeriodUpdated(uint256 previousPeriod, uint256 newPeriod);
    event StrategyTransfer(address indexed strategy, bool indexed toStrategy, uint256 amount);
    event StrategyApproved(address indexed strategy, bool approved);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant WITHDRAW_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // -----------------------------------------------------------------------
    // State variables
    // -----------------------------------------------------------------------
    IERC20 public underlying;
    address public owner;
    address public operator;

    uint256 public totalSupply;
    uint256 public totalUnderlying;
    uint256 public vaultBalance;
    uint256 public totalDeployed;

    uint256 public lockupPeriod;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public lastDepositTime;
    mapping(address => bool) public approvedStrategies;

    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 private _locked = 1;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(
        address _underlying,
        address _operator,
        uint256 _lockupPeriod,
        string memory _name,
        string memory _symbol
    ) {
        if (_underlying == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        underlying = IERC20(_underlying);
        owner = msg.sender;
        operator = _operator;
        lockupPeriod = _lockupPeriod;
        name = _name;
        symbol = _symbol;
        decimals = 18;
    }

    // -----------------------------------------------------------------------
    // Owner functions
    // -----------------------------------------------------------------------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setLockupPeriod(uint256 _lockupPeriod) external onlyOwner {
        emit LockupPeriodUpdated(lockupPeriod, _lockupPeriod);
        lockupPeriod = _lockupPeriod;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        owner = _newOwner;
    }

    function approveStrategy(address strategy, bool approved) external onlyOwner {
        if (strategy == address(0)) revert ZeroAddress();
        approvedStrategies[strategy] = approved;
        emit StrategyApproved(strategy, approved);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------
    function updateUnderlying(address _newUnderlying) external onlyOperator {
        if (_newUnderlying == address(0)) revert ZeroAddress();
        if (_newUnderlying == address(underlying)) revert SameUnderlying();
        emit UnderlyingUpdated(address(underlying), _newUnderlying);
        underlying = IERC20(_newUnderlying);
    }

    function transferToStrategy(address strategy, uint256 amount) external onlyOperator nonReentrant {
        if (strategy == address(0)) revert ZeroAddress();
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (amount == 0) revert ZeroAmount();
        if (amount > vaultBalance) revert InsufficientBalance();

        // Effects before interactions
        vaultBalance -= amount;
        totalDeployed += amount;

        // Interactions
        underlying.safeTransfer(strategy, amount);

        emit StrategyTransfer(strategy, true, amount);
    }

    function transferFromStrategy(address strategy, uint256 amount, uint256 principal) external onlyOperator nonReentrant {
        if (strategy == address(0)) revert ZeroAddress();
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (amount == 0) revert ZeroAmount();
        if (principal > amount) revert InsufficientBalance();
        if (principal > totalDeployed) revert InsufficientBalance();

        // Effects before interactions (checks-effects-interactions pattern)
        totalDeployed -= principal;
        vaultBalance += amount;
        totalUnderlying += (amount - principal);

        // Interactions
        underlying.safeTransferFrom(strategy, address(this), amount);

        emit StrategyTransfer(strategy, false, amount);
    }

    function reportProfit(uint256 profitAmount) external onlyOperator {
        if (profitAmount == 0) revert ZeroAmount();
        totalUnderlying += profitAmount;
        emit StrategyTransfer(address(0), false, profitAmount);
    }

    // -----------------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------------
    function deposit(uint256 underlyingAmount) external nonReentrant returns (uint256 yieldTokens) {
        if (underlyingAmount == 0) revert ZeroAmount();
        if (underlyingAmount < MIN_DEPOSIT) revert DepositTooSmall(underlyingAmount, MIN_DEPOSIT);

        yieldTokens = _underlyingToShares(underlyingAmount);

        // Effects
        balanceOf[msg.sender] += yieldTokens;
        totalSupply += yieldTokens;
        totalUnderlying += underlyingAmount;
        vaultBalance += underlyingAmount;
        lastDepositTime[msg.sender] = block.timestamp;

        // Interactions
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        emit Deposit(msg.sender, underlyingAmount, yieldTokens);
    }

    function withdraw(uint256 yieldTokens) external nonReentrant returns (uint256 underlyingOut) {
        if (yieldTokens == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < yieldTokens) revert InsufficientBalance();

        uint256 underlyingAmount = _sharesToUnderlying(yieldTokens);
        uint256 fee = (underlyingAmount * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        underlyingOut = underlyingAmount - fee;

        // Effects
        balanceOf[msg.sender] -= yieldTokens;
        totalSupply -= yieldTokens;
        totalUnderlying -= underlyingAmount;
        if (underlyingAmount > vaultBalance) revert InsufficientBalance();
        vaultBalance -= underlyingAmount;

        // Interactions
        if (fee > 0) {
            underlying.safeTransfer(owner, fee);
        }
        underlying.safeTransfer(msg.sender, underlyingOut);

        emit Withdraw(msg.sender, underlyingAmount, yieldTokens, fee);
    }

    function redeem(uint256 yieldTokens) external nonReentrant returns (uint256 underlyingOut) {
        if (yieldTokens == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < yieldTokens) revert InsufficientBalance();

        uint256 availableAt = lastDepositTime[msg.sender] + lockupPeriod;
        if (block.timestamp < availableAt) revert LockupNotElapsed(availableAt);

        uint256 underlyingAmount = _sharesToUnderlying(yieldTokens);

        // Effects
        balanceOf[msg.sender] -= yieldTokens;
        totalSupply -= yieldTokens;
        totalUnderlying -= underlyingAmount;
        if (underlyingAmount > vaultBalance) revert InsufficientBalance();
        vaultBalance -= underlyingAmount;

        // Interactions
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Redeem(msg.sender, underlyingAmount, yieldTokens);
        return underlyingAmount;
    }

    // -----------------------------------------------------------------------
    // ERC20 functions for yield-accruing token
    // -----------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------
    function previewDeposit(uint256 underlyingAmount) external view returns (uint256) {
        return _underlyingToShares(underlyingAmount);
    }

    function previewWithdraw(uint256 shares) external view returns (uint256) {
        return _sharesToUnderlying(shares);
    }

    function underlyingBalanceOf(address user) external view returns (uint256) {
        return _sharesToUnderlying(balanceOf[user]);
    }

    function redeemableAt(address user) external view returns (uint256) {
        if (block.timestamp < lastDepositTime[user] + lockupPeriod) {
            return 0;
        }
        return _sharesToUnderlying(balanceOf[user]);
    }

    function getExchangeRate() external view returns (uint256) {
        if (totalSupply < 1) return 1e18;
        return (totalUnderlying * 1e18) / totalSupply;
    }

    // -----------------------------------------------------------------------
    // Internal functions
    // -----------------------------------------------------------------------
    function _underlyingToShares(uint256 underlyingAmount) internal view returns (uint256) {
        if (totalSupply < 1 || totalUnderlying < 1) {
            return underlyingAmount;
        }
        return (underlyingAmount * totalSupply) / totalUnderlying;
    }

    function _sharesToUnderlying(uint256 shares) internal view returns (uint256) {
        if (totalSupply < 1) {
            return 0;
        }
        return (shares * totalUnderlying) / totalSupply;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
}
