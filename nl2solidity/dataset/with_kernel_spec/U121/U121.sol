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

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

/**
 * @title StablecoinSpendingManager
 * @notice Manages stablecoin deposits and a wrapped "spending account" token used to
 *         fund real-world purchases. Users deposit a supported stablecoin (capped at
 *         10,000 per user), may withdraw their stablecoin at any time, or convert their
 *         deposited stablecoin into spending account tokens at a fixed 0.5% conversion
 *         fee. A designated operator may mint/burn spending account tokens and adjust a
 *         global fee percentage used for protocol accounting.
 */
contract StablecoinSpendingManager {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------------------------

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error TransferToZeroAddress();
    error ExceedsDepositCap(address user, uint256 current, uint256 attempted, uint256 cap);
    error InsufficientDeposit(address user, uint256 available, uint256 requested);
    error InsufficientSpendingBalance(address user, uint256 available, uint256 requested);
    error InsufficientAllowance(address owner, address spender, uint256 available, uint256 requested);
    error InvalidFeePercentage(uint256 provided);
    error Reentrancy();

    // ---------------------------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Conversion(address indexed user, uint256 stablecoinAmount, uint256 fee, uint256 tokensMinted);
    event FeePercentageUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event SpendingTokenTransfer(address indexed from, address indexed to, uint256 amount);
    event SpendingTokenApproval(address indexed owner, address indexed spender, uint256 amount);
    event SpendingTokenMint(address indexed operator, address indexed to, uint256 amount);
    event SpendingTokenBurn(address indexed operator, address indexed from, uint256 amount);

    // ---------------------------------------------------------------------------------------------
    // Constants & Immutables
    // ---------------------------------------------------------------------------------------------

    uint256 public constant CONVERSION_FEE_BPS = 50; // 0.5%
    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 private constant MAX_DEPOSIT_PER_USER_RAW = 10000; // 10,000 stablecoins (scaled by decimals)
    uint8 private constant DEFAULT_DECIMALS = 18;

    IERC20 public immutable stablecoin;
    uint256 public immutable maxDepositPerUser;

    // ---------------------------------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------------------------------

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------------------------------
    // Operator
    // ---------------------------------------------------------------------------------------------

    address public operator;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------------------------------------------------------------------------------------------
    // Stablecoin deposit state
    // ---------------------------------------------------------------------------------------------

    mapping(address => uint256) public depositedBalances;
    uint256 public totalDeposits;

    // ---------------------------------------------------------------------------------------------
    // Spending account token state
    // ---------------------------------------------------------------------------------------------

    string public spendingTokenName;
    string public spendingTokenSymbol;
    uint256 public totalSpendingTokenSupply;
    mapping(address => uint256) public spendingTokenBalances;
    mapping(address => mapping(address => uint256)) public spendingTokenAllowances;

    /**
     * @notice Operator-updatable global fee percentage (in basis points). Does not alter the
     *         fixed 0.5% conversion fee, but is tracked for protocol-level accounting.
     */
    uint256 public globalFeePercentage;

    // ---------------------------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------------------------

    constructor(
        address stablecoin_,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        if (stablecoin_ == address(0)) revert ZeroAddress();
        stablecoin = IERC20(stablecoin_);
        uint8 dec = DEFAULT_DECIMALS;
        try IERC20Metadata(stablecoin_).decimals() returns (uint8 d) {
            if (d <= 18) {
                dec = d;
            }
        } catch {}
        maxDepositPerUser = MAX_DEPOSIT_PER_USER_RAW * (10 ** uint256(dec));
        operator = msg.sender;
        spendingTokenName = tokenName;
        spendingTokenSymbol = tokenSymbol;
        globalFeePercentage = CONVERSION_FEE_BPS;
        emit OperatorChanged(address(0), msg.sender);
        emit FeePercentageUpdated(0, globalFeePercentage);
    }

    // ---------------------------------------------------------------------------------------------
    // Deposit / Withdraw / Convert
    // ---------------------------------------------------------------------------------------------

    /**
     * @notice Deposit stablecoin into the caller's spending account. Capped at
     *         `maxDepositPerUser` per user.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 current = depositedBalances[msg.sender];
        uint256 newBalance = current + amount;
        if (newBalance > maxDepositPerUser) {
            revert ExceedsDepositCap(msg.sender, current, amount, maxDepositPerUser);
        }
        // Effects: update state before external call (checks-effects-interactions).
        depositedBalances[msg.sender] = newBalance;
        totalDeposits += amount;
        // Interactions: pull stablecoin from the caller.
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw previously deposited stablecoin back to the caller.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 available = depositedBalances[msg.sender];
        if (amount > available) revert InsufficientDeposit(msg.sender, available, amount);
        // Effects: update state before external call (checks-effects-interactions).
        depositedBalances[msg.sender] = available - amount;
        totalDeposits -= amount;
        // Interactions: send stablecoin back to the caller.
        stablecoin.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Convert a portion of the caller's deposited stablecoin into spending account
     *         tokens at a fixed 0.5% conversion fee. The fee portion of the stablecoin is
     *         retained by the protocol as revenue (it is no longer tracked as a deposit).
     */
    function convertToSpendingToken(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 available = depositedBalances[msg.sender];
        if (amount > available) revert InsufficientDeposit(msg.sender, available, amount);

        uint256 fee = (amount * CONVERSION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 minted = amount - fee;

        // Effects: deduct deposit and mint spending tokens.
        depositedBalances[msg.sender] = available - amount;
        totalDeposits -= amount;
        _mintSpendingToken(msg.sender, minted);

        emit Conversion(msg.sender, amount, fee, minted);
    }

    // ---------------------------------------------------------------------------------------------
    // Spending account token internals
    // ---------------------------------------------------------------------------------------------

    function _mintSpendingToken(address to, uint256 amount) internal {
        if (to == address(0)) revert TransferToZeroAddress();
        spendingTokenBalances[to] += amount;
        totalSpendingTokenSupply += amount;
        emit SpendingTokenMint(operator, to, amount);
    }

    function _burnSpendingToken(address from, uint256 amount) internal {
        uint256 bal = spendingTokenBalances[from];
        if (amount > bal) revert InsufficientSpendingBalance(from, bal, amount);
        spendingTokenBalances[from] = bal - amount;
        totalSpendingTokenSupply -= amount;
        emit SpendingTokenBurn(operator, from, amount);
    }

    // ---------------------------------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------------------------------

    /**
     * @notice Mint spending account tokens to a user. Only callable by the operator.
     */
    function mintSpendingToken(address to, uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert TransferToZeroAddress();
        _mintSpendingToken(to, amount);
    }

    /**
     * @notice Burn spending account tokens from a user. Only callable by the operator.
     */
    function burnSpendingToken(address from, uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (from == address(0)) revert TransferToZeroAddress();
        _burnSpendingToken(from, amount);
    }

    /**
     * @notice Update the global fee percentage (in basis points). Must be <= 10000 (100%).
     */
    function setFeePercentage(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > BPS_DENOMINATOR) revert InvalidFeePercentage(newFeeBps);
        uint256 old = globalFeePercentage;
        globalFeePercentage = newFeeBps;
        emit FeePercentageUpdated(old, newFeeBps);
    }

    /**
     * @notice Transfer operator privileges to a new address.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    // ---------------------------------------------------------------------------------------------
    // Spending account token transfers (user-facing ERC20-like)
    // ---------------------------------------------------------------------------------------------

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert TransferToZeroAddress();
        uint256 bal = spendingTokenBalances[msg.sender];
        if (amount > bal) revert InsufficientSpendingBalance(msg.sender, bal, amount);
        spendingTokenBalances[msg.sender] = bal - amount;
        spendingTokenBalances[to] += amount;
        emit SpendingTokenTransfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        spendingTokenAllowances[msg.sender][spender] = amount;
        emit SpendingTokenApproval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert TransferToZeroAddress();
        uint256 allowed = spendingTokenAllowances[from][msg.sender];
        if (amount > allowed) revert InsufficientAllowance(from, msg.sender, allowed, amount);
        uint256 bal = spendingTokenBalances[from];
        if (amount > bal) revert InsufficientSpendingBalance(from, bal, amount);
        spendingTokenAllowances[from][msg.sender] = allowed - amount;
        spendingTokenBalances[from] = bal - amount;
        spendingTokenBalances[to] += amount;
        emit SpendingTokenTransfer(from, to, amount);
        return true;
    }

    // ---------------------------------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------------------------------

    function spendingTokenBalanceOf(address account) external view returns (uint256) {
        return spendingTokenBalances[account];
    }

    function spendingTokenAllowance(address owner_, address spender) external view returns (uint256) {
        return spendingTokenAllowances[owner_][spender];
    }

    function depositedBalanceOf(address account) external view returns (uint256) {
        return depositedBalances[account];
    }
}
