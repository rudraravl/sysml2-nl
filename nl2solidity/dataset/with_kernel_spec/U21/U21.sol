// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TreasuryBillFractionalToken
 * @notice ERC20-like token representing fractional ownership of a portfolio of
 *         short-term US Treasury bills and reverse repurchase agreements. The
 *         contract holds no on-chain assets directly; token supply reflects an
 *         off-chain portfolio managed by a designated operator. Holders may
 *         mint tokens by depositing US Dollars, redeem tokens for US Dollars
 *         (subject to a 0.1% redemption fee), and transfer tokens freely when
 *         the contract is not paused. The operator may update the global daily
 *         interest rate (capped at 0.1%) and pause/unpause transfers.
 */
contract TreasuryBillFractionalToken {
    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error TransferPaused();
    error DailyRateExceedsMaximum(uint256 provided, uint256 maximum);
    error AmountZero();
    error UnauthorizedOperator();
    error UnauthorizedOwner();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Mint(address indexed account, uint256 usdAmount, uint256 tokenAmount);
    event Redeem(address indexed account, uint256 tokenAmount, uint256 usdAmount, uint256 feeAmount);
    event DailyInterestRateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant name = "Treasury Bill Fractional Token";
    string public constant symbol = "TBFT";
    uint8 public constant decimals = 18;

    /// @dev Precision used for the daily interest rate (1e18 = 100%).
    uint256 public constant RATE_PRECISION = 1e18;

    /// @dev Maximum daily interest rate: 0.001 (0.1%) expressed with RATE_PRECISION.
    uint256 public constant MAX_DAILY_RATE = 1e15; // 0.001 * 1e18

    /// @dev Redemption fee: 0.1% = 10 basis points.
    uint256 public constant REDEMPTION_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address private _owner;
    address private _operator;

    uint256 private _totalSupply;
    uint256 public dailyInterestRate;

    bool public paused;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != _owner) revert UnauthorizedOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != _operator) revert UnauthorizedOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TransferPaused();
        _;
    }

    modifier nonZeroAddress(address account) {
        if (account == address(0)) revert ZeroAddress();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address operator_) nonZeroAddress(operator_) {
        _owner = msg.sender;
        _operator = operator_;
        dailyInterestRate = 0;
        paused = false;
        emit OwnershipTransferred(address(0), _owner);
        emit OperatorChanged(address(0), _operator);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function operator() external view returns (address) {
        return _operator;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount)
        external
        whenNotPaused
        nonZeroAddress(to)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        whenNotPaused
        nonZeroAddress(to)
        nonZeroAddress(from)
        returns (bool)
    {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        // Effects: reduce allowance before external interactions (CEI).
        _allowances[from][msg.sender] = currentAllowance - amount;
        emit Approval(from, msg.sender, currentAllowance - amount);

        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        external
        nonZeroAddress(spender)
        returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                       MINT & REDEEM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint tokens by depositing US Dollars. Tokens are minted 1:1 with
     *         the USD amount provided. The contract does not custody USD; the
     *         deposit is handled off-chain and this function records the
     *         corresponding token balance.
     * @param to        Recipient of the minted tokens.
     * @param usdAmount Amount of US Dollars deposited (in 1e18 precision).
     */
    function mint(address to, uint256 usdAmount)
        external
        whenNotPaused
        nonZeroAddress(to)
        returns (uint256 tokenAmount)
    {
        if (usdAmount == 0) revert AmountZero();

        tokenAmount = usdAmount; // 1:1 mint ratio

        // Effects.
        _totalSupply += tokenAmount;
        _balances[to] += tokenAmount;

        emit Mint(to, usdAmount, tokenAmount);
        emit Transfer(address(0), to, tokenAmount);
    }

    /**
     * @notice Redeem tokens for US Dollars. A 0.1% fee is deducted from the
     *         redeemed token amount; the fee remains in the contract (accruing
     *         to the off-chain portfolio) and the net USD equivalent is recorded
     *         for off-chain settlement.
     * @param tokenAmount Amount of tokens to redeem.
     */
    function redeem(uint256 tokenAmount)
        external
        whenNotPaused
        returns (uint256 usdAmount, uint256 feeAmount)
    {
        if (tokenAmount == 0) revert AmountZero();
        if (_balances[msg.sender] < tokenAmount) revert InsufficientBalance();

        feeAmount = (tokenAmount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netTokenAmount = tokenAmount - feeAmount;
        usdAmount = netTokenAmount; // 1:1 redemption ratio for net amount

        // Effects.
        _balances[msg.sender] -= tokenAmount;
        _totalSupply -= netTokenAmount;

        // Fee tokens are burned from supply but not credited to any account;
        // they represent the redemption fee retained by the portfolio.

        emit Redeem(msg.sender, tokenAmount, usdAmount, feeAmount);
        emit Transfer(msg.sender, address(0), netTokenAmount);
    }

    /*//////////////////////////////////////////////////////////////
                     OPERATOR: INTEREST RATE & PAUSE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update the global daily interest rate. The rate cannot exceed
     *         0.001 (0.1%).
     * @param newRate New daily interest rate in 1e18 precision (e.g. 5e14 = 0.05%).
     */
    function updateDailyInterestRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_DAILY_RATE) {
            revert DailyRateExceedsMaximum(newRate, MAX_DAILY_RATE);
        }
        uint256 oldRate = dailyInterestRate;
        dailyInterestRate = newRate;
        emit DailyInterestRateUpdated(oldRate, newRate);
    }

    /**
     * @notice Pause all token transfers, mints, and redemptions.
     */
    function pause() external onlyOperator {
        if (paused) return;
        paused = true;
        emit Paused(_operator);
    }

    /**
     * @notice Unpause token transfers, mints, and redemptions.
     */
    function unpause() external onlyOperator {
        if (!paused) return;
        paused = false;
        emit Unpaused(_operator);
    }

    /*//////////////////////////////////////////////////////////////
                       OWNERSHIP & OPERATOR ADMIN
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) external onlyOwner nonZeroAddress(newOwner) {
        address previous = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner nonZeroAddress(newOperator) {
        address previous = _operator;
        _operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _transfer(address from, address to, uint256 amount) internal {
        if (amount == 0) revert AmountZero();
        if (_balances[from] < amount) revert InsufficientBalance();

        // Effects.
        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }
}
