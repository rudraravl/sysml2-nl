// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PortableCreditToken
 * @notice Manages issuance and redemption of portable tokens backed by isolated
 *         credit positions. The contract holds no custodied assets itself; it
 *         only tracks per-user credit limits, outstanding balances, portable
 *         token balances, and aggregate totals. A 0.1% fee is applied to each
 *         minting operation and accrues into the issuer's outstanding balance.
 */
contract PortableCreditToken {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @notice Maximum credit limit grantable to any single user (1,000,000 units).
    uint256 public constant MAX_CREDIT_LIMIT = 1_000_000;

    /// @notice Mint fee rate expressed in basis points (0.1% = 10 bps).
    uint256 public constant MINT_FEE_RATE = 10;

    /// @notice Denominator for basis-point fee calculations.
    uint256 public constant FEE_DENOMINATOR = 10_000;

    // -----------------------------------------------------------------------
    // Storage
    // -----------------------------------------------------------------------

    address public owner;
    address public operator;
    bool public paused;

    string public name;
    string public symbol;

    uint256 public totalSupply;
    uint256 public totalOutstanding;
    uint256 public totalFeesCollected;

    mapping(address => uint256) public creditLimit;
    mapping(address => uint256) public outstandingBalance;
    mapping(address => uint256) public portableBalance;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Mint(address indexed user, uint256 amount, uint256 fee);
    event Repay(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event CreditLimitUpdated(address indexed user, uint256 oldLimit, uint256 newLimit);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error SystemPaused();
    error AlreadyPaused();
    error SystemNotPaused();
    error CreditLimitExceeded();
    error InsufficientOutstanding();
    error InsufficientPortableBalance();
    error LimitAboveMaximum();
    error ZeroAddress();
    error ZeroAmount();

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

    modifier notPaused() {
        if (paused) revert SystemPaused();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param _name     Name of the portable credit token.
     * @param _symbol   Symbol of the portable credit token.
     * @param _operator Address granted rights to adjust credit limits and pause.
     */
    constructor(string memory _name, string memory _symbol, address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        name = _name;
        symbol = _symbol;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    // -----------------------------------------------------------------------
    // Administration – Ownership
    // -----------------------------------------------------------------------

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    // -----------------------------------------------------------------------
    // Administration – Operator
    // -----------------------------------------------------------------------

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorChanged(old, _operator);
    }

    // -----------------------------------------------------------------------
    // Administration – Credit Limits
    // -----------------------------------------------------------------------

    /**
     * @notice Sets the credit limit for a user. The limit may be reduced below
     *         the user's current outstanding balance, which simply prevents
     *         further minting until the outstanding balance is repaid.
     * @param user  The account whose credit limit is being adjusted.
     * @param limit The new credit limit, expressed in underlying credit units.
     */
    function setCreditLimit(address user, uint256 limit) external onlyOperator {
        if (limit > MAX_CREDIT_LIMIT) revert LimitAboveMaximum();
        uint256 oldLimit = creditLimit[user];
        creditLimit[user] = limit;
        emit CreditLimitUpdated(user, oldLimit, limit);
    }

    // -----------------------------------------------------------------------
    // Administration – Pause
    // -----------------------------------------------------------------------

    function pause() external onlyOperator {
        if (paused) revert AlreadyPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert SystemNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    // -----------------------------------------------------------------------
    // Core Operations
    // -----------------------------------------------------------------------

    /**
     * @notice Mints portable tokens to the caller by drawing against their
     *         available credit. A 0.1% fee is charged on the minted amount and
     *         added to the caller's outstanding balance.
     * @param amount The face amount of portable tokens to mint.
     */
    function mint(uint256 amount) external notPaused {
        if (amount == 0) revert ZeroAmount();

        address user = msg.sender;
        uint256 userLimit = creditLimit[user];
        uint256 userOutstanding = outstandingBalance[user];
        uint256 available = userLimit > userOutstanding ? userLimit - userOutstanding : 0;

        uint256 fee = (amount * MINT_FEE_RATE) / FEE_DENOMINATOR;
        uint256 totalCost = amount + fee;

        if (totalCost > available) revert CreditLimitExceeded();

        // Effects
        outstandingBalance[user] = userOutstanding + totalCost;
        portableBalance[user] += amount;
        totalSupply += amount;
        totalOutstanding += totalCost;
        totalFeesCollected += fee;

        emit Mint(user, amount, fee);
    }

    /**
     * @notice Repays outstanding debt, reducing the caller's outstanding
     *         balance without burning portable tokens. This represents an
     *         external repayment of the isolated credit position.
     * @param amount The amount of debt to repay.
     */
    function repay(uint256 amount) external notPaused {
        if (amount == 0) revert ZeroAmount();

        address user = msg.sender;
        uint256 userOutstanding = outstandingBalance[user];
        if (amount > userOutstanding) revert InsufficientOutstanding();

        outstandingBalance[user] = userOutstanding - amount;
        totalOutstanding -= amount;

        emit Repay(user, amount);
    }

    /**
     * @notice Redeems portable tokens to reduce the caller's outstanding
     *         balance. The redeemed tokens are burned and removed from
     *         total supply.
     * @param amount The amount of portable tokens to redeem.
     */
    function redeem(uint256 amount) external notPaused {
        if (amount == 0) revert ZeroAmount();

        address user = msg.sender;
        uint256 userOutstanding = outstandingBalance[user];
        uint256 userBalance = portableBalance[user];

        if (amount > userOutstanding) revert InsufficientOutstanding();
        if (amount > userBalance) revert InsufficientPortableBalance();

        outstandingBalance[user] = userOutstanding - amount;
        portableBalance[user] = userBalance - amount;
        totalSupply -= amount;
        totalOutstanding -= amount;

        emit Redeem(user, amount);
    }

    /**
     * @notice Transfers portable tokens between accounts. Transfers do not
     *         affect outstanding balances — credit positions are personal and
     *         remain with the original issuer.
     * @param to     The recipient address.
     * @param amount The amount of portable tokens to transfer.
     */
    function transfer(address to, uint256 amount) external notPaused returns (bool) {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        address from = msg.sender;
        uint256 fromBalance = portableBalance[from];
        if (amount > fromBalance) revert InsufficientPortableBalance();

        portableBalance[from] = fromBalance - amount;
        portableBalance[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------

    function balanceOf(address user) external view returns (uint256) {
        return portableBalance[user];
    }

    function outstandingOf(address user) external view returns (uint256) {
        return outstandingBalance[user];
    }

    function getCreditLimit(address user) external view returns (uint256) {
        return creditLimit[user];
    }

    function availableCredit(address user) external view returns (uint256) {
        uint256 userLimit = creditLimit[user];
        uint256 userOutstanding = outstandingBalance[user];
        return userLimit > userOutstanding ? userLimit - userOutstanding : 0;
    }

    /**
     * @notice Computes the 0.1% mint fee for a given mint amount.
     * @param amount The face mint amount.
     * @return The fee that would be charged.
     */
    function calculateMintFee(uint256 amount) public pure returns (uint256) {
        return (amount * MINT_FEE_RATE) / FEE_DENOMINATOR;
    }
}
