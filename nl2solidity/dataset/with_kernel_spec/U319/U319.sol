// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CustodiedGold
 * @notice ERC-20 compatible token representing fractional ownership of
 *         physical gold that is held and verified off-chain by a designated
 *         custodian. The contract itself custody no physical assets; it only
 *         maintains on-chain balances that mirror the off-chain holdings.
 *
 *         Transfers are subject to a configurable fee (default 0.1%) that is
 *         burned from the total supply on each transfer, reducing circulating
 *         supply over time. Total supply is hard-capped at 1,000,000,000
 *         tokens. A designated operator may mint, pause, and unpause.
 */
contract CustodiedGold {
    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeRateUpdated(uint256 oldBps, uint256 newBps);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error ContractPaused();
    error ContractNotPaused();
    error Unauthorized();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ExceedsSupplyCap();
    error FeeRateTooHigh();

    // ---------------------------------------------------------------------
    // Metadata
    // ---------------------------------------------------------------------
    string public constant name = "Custodied Gold";
    string public constant symbol = "CGOLD";
    uint8 public constant decimals = 18;

    /// @notice Absolute upper bound on the number of tokens that may ever exist.
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**uint256(decimals);

    /// @notice Upper bound on the configurable fee rate, expressed in basis
    ///         points. 1,000 bps == 10%.
    uint256 public constant MAX_FEE_BPS = 1000;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public operator;
    /// @notice Transfer fee in basis points. 10 bps == 0.1%.
    uint256 public feeBps;
    bool public paused;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractNotPaused();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        feeBps = 10; // 0.1% by default
    }

    // ---------------------------------------------------------------------
    // ERC-20 surface
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        _approve(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    // ---------------------------------------------------------------------
    // Burn
    // ---------------------------------------------------------------------
    function burn(uint256 amount) external whenNotPaused {
        uint256 accountBalance = balanceOf[msg.sender];
        if (accountBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] = accountBalance - amount;
            totalSupply -= amount;
        }
        emit Burned(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    // ---------------------------------------------------------------------
    // Operator-gated functions
    // ---------------------------------------------------------------------
    function mint(address to, uint256 amount)
        external
        onlyOperator
        whenNotPaused
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount > MAX_SUPPLY - totalSupply) revert ExceedsSupplyCap();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Minted(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function setFeeBps(uint256 newBps) external onlyOperator {
        if (newBps > MAX_FEE_BPS) revert FeeRateTooHigh();
        uint256 previous = feeBps;
        feeBps = newBps;
        emit FeeRateUpdated(previous, newBps);
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();

        uint256 fee = (amount * feeBps) / 10_000;
        uint256 net = amount - fee;

        // Deduct the full amount from the sender.
        unchecked {
            balanceOf[from] = fromBalance - amount;
        }

        // Credit the net amount to the recipient.
        unchecked {
            balanceOf[to] += net;
        }

        // The fee portion is burned: removed from total supply and announced
        // via a Transfer event to the zero address.
        if (fee > 0) {
            totalSupply -= fee;
            emit Transfer(from, address(0), fee);
        }

        emit Transfer(from, to, net);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
}
