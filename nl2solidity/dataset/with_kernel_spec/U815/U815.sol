// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GoldToken
/// @notice ERC20-like token representing physical gold (1 token = 1 gram). The contract
///         custodies no physical assets; it only tracks supply, balances, and allowances.
///         A designated operator may mint, burn, and pause/unpause transfers. A 0.1%
///         transfer fee is deducted from every transfer and routed to a fee collector.
contract GoldToken {
    /*//////////////////////////////////////////////////////////////
                              METADATA
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public totalSupply;
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18; // 1,000,000 grams
    uint256 public constant FEE_DIVISOR = 1000; // 0.1% fee

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public operator;
    address public feeCollector;
    bool public paused;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeCollectorUpdated(address indexed previousCollector, address indexed newCollector);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error ExceedsMaxSupply();
    error InsufficientBalance();
    error InsufficientAllowance();
    error EnforcedPause();
    error ExpectedPause();
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @param _name Token name.
    /// @param _symbol Token symbol.
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        operator = msg.sender;
        feeCollector = msg.sender;
        emit OperatorChanged(address(0), msg.sender);
        emit FeeCollectorUpdated(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20 EXTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Transfers `amount` tokens to `to`. A 0.1% fee is deducted and sent to the fee collector.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to send (before fee).
    /// @return true on success.
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Approves `spender` to spend up to `amount` tokens on behalf of the caller.
    /// @param spender Address to be authorized.
    /// @param amount Approved allowance.
    /// @return true on success.
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers `amount` tokens from `from` to `to` using an allowance. The 0.1% fee applies.
    /// @param from Source address.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to send (before fee).
    /// @return true on success.
    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mints `amount` tokens to `to`. Only callable by the operator. Total supply cannot exceed `MAX_SUPPLY`.
    /// @param to Recipient of the newly minted tokens.
    /// @param amount Number of tokens to mint.
    function mint(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (totalSupply + amount > MAX_SUPPLY) revert ExceedsMaxSupply();

        balanceOf[to] += amount;
        totalSupply += amount;

        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    /// @notice Burns `amount` tokens from `from`. Only callable by the operator. Reduces total supply.
    /// @param from Address whose tokens will be burned.
    /// @param amount Number of tokens to burn.
    function burn(address from, uint256 amount) external onlyOperator {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Burn(from, amount);
        emit Transfer(from, address(0), amount);
    }

    /// @notice Pauses all token transfers. Only callable by the operator.
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpauses token transfers. Only callable by the operator.
    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Sets a new fee collector address. Only callable by the operator.
    /// @param newCollector Address that will receive all transfer fees.
    function setFeeCollector(address newCollector) external onlyOperator {
        if (newCollector == address(0)) revert ZeroAddress();
        address previous = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(previous, newCollector);
    }

    /// @notice Transfers operator role to a new address. Only callable by the current operator.
    /// @param newOperator Address of the new operator.
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    /// @notice Renounces the operator role. Only callable by the current operator.
    function renounceOperator() external onlyOperator {
        address previous = operator;
        operator = address(0);
        emit OperatorChanged(previous, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @dev Internal transfer logic applying the 0.1% fee to the fee collector.
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 fee = amount / FEE_DIVISOR;
        uint256 netAmount = amount - fee;

        balanceOf[from] -= amount;
        balanceOf[to] += netAmount;
        if (fee > 0) {
            balanceOf[feeCollector] += fee;
            emit Transfer(from, feeCollector, fee);
        }

        emit Transfer(from, to, netAmount);
    }

    /// @dev Internal approval logic.
    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        if (tokenOwner == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }
}
