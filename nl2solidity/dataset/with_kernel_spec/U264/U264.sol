// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/// @title SocialTokenEscrow
/// @notice Manages a social token for a decentralized social network. Users deposit a base
///         ERC20 token into escrow and receive a corresponding amount of social tokens based
///         on the current conversion rate. Social tokens can be transferred peer-to-peer
///         (subject to a per-transaction cap) and burned to redeem a proportional share of
///         the escrowed base tokens. A designated operator may adjust the conversion rate.
contract SocialTokenEscrow {
    // ---------------------------------------------------------------------
    // Metadata
    // ---------------------------------------------------------------------

    string public constant name = "SocialToken";
    string public constant symbol = "SOC";
    uint8 public constant decimals = 18;

    /// @dev Maximum social tokens allowed in a single peer-to-peer transfer.
    uint256 public constant MAX_TRANSFER = 1_000_000 * 10 ** 18;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    /// @notice Base ERC20 token held in escrow.
    IERC20 public immutable baseToken;

    /// @notice Designated operator authorised to adjust the conversion rate and transfer operator role.
    address public operator;

    /// @notice Conversion rate expressed as social-token units per base-token unit.
    /// @dev Initially 100, i.e. 1 base token mints 100 social tokens.
    uint256 public conversionRate;

    /// @notice Total supply of social tokens.
    uint256 public totalSupply;

    /// @notice Per-user social token balances.
    mapping(address => uint256) public balanceOf;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Mint(address indexed account, uint256 baseAmount, uint256 socialAmount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Burn(address indexed account, uint256 socialAmount, uint256 baseAmount);
    event ConversionRateUpdated(address indexed operator, uint256 oldRate, uint256 newRate);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------------

    error Unauthorized();
    error InsufficientBalance();
    error ExceedsMaxTransfer();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error InvalidRate();
    error InvalidBaseToken();
    error InsufficientSupply();
    error ReentrantCall();

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

    /// @param _baseToken Address of the ERC20 base token to hold in escrow.
    constructor(address _baseToken) {
        if (_baseToken == address(0)) revert InvalidBaseToken();
        baseToken = IERC20(_baseToken);
        operator = msg.sender;
        conversionRate = 100; // 1 base token <=> 100 social tokens
    }

    // ---------------------------------------------------------------------
    // External / Public Functions
    // ---------------------------------------------------------------------

    /// @notice Deposit base tokens to mint social tokens at the current conversion rate.
    /// @dev    Caller must have approved this contract to spend `baseAmount` of the base token.
    /// @param baseAmount Amount of base tokens to deposit (in base-token units).
    function deposit(uint256 baseAmount) external nonReentrant {
        if (baseAmount == 0) revert ZeroAmount();

        uint256 socialAmount = baseAmount * conversionRate;

        // --- Effects ---
        balanceOf[msg.sender] += socialAmount;
        totalSupply += socialAmount;

        // --- Interactions ---
        bool success = baseToken.transferFrom(msg.sender, address(this), baseAmount);
        if (!success) revert TransferFailed();

        emit Mint(msg.sender, baseAmount, socialAmount);
        emit Transfer(address(0), msg.sender, socialAmount);
    }

    /// @notice Transfer social tokens to another address. Capped at MAX_TRANSFER per call.
    /// @dev    Conforms to the ERC20 `transfer` interface by returning a boolean.
    /// @param to     Recipient address.
    /// @param amount Amount of social tokens to transfer.
    /// @return True if the transfer succeeded.
    function transfer(address to, uint256 amount) external nonReentrant returns (bool) {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (amount > MAX_TRANSFER) revert ExceedsMaxTransfer();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        // --- Effects ---
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Burn social tokens and redeem a proportional share of the escrowed base tokens.
    /// @dev    The redeemed base amount is `socialAmount * baseBalance / totalSupply`, ensuring
    ///         that each social token always corresponds to the same fraction of the escrow.
    /// @param socialAmount Amount of social tokens to burn.
    function burn(uint256 socialAmount) external nonReentrant {
        if (socialAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < socialAmount) revert InsufficientBalance();
        if (totalSupply == 0) revert InsufficientSupply();

        uint256 baseBalance = baseToken.balanceOf(address(this));
        uint256 baseAmount = (socialAmount * baseBalance) / totalSupply;

        // --- Effects ---
        balanceOf[msg.sender] -= socialAmount;
        totalSupply -= socialAmount;

        // --- Interactions ---
        if (baseAmount > 0) {
            bool success = baseToken.transfer(msg.sender, baseAmount);
            if (!success) revert TransferFailed();
        }

        emit Burn(msg.sender, socialAmount, baseAmount);
        emit Transfer(msg.sender, address(0), socialAmount);
    }

    // ---------------------------------------------------------------------
    // Operator Functions
    // ---------------------------------------------------------------------

    /// @notice Update the conversion rate (social tokens minted per base token).
    /// @param newRate The new conversion rate; must be greater than zero.
    function setConversionRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidRate();
        uint256 oldRate = conversionRate;
        conversionRate = newRate;
        emit ConversionRateUpdated(msg.sender, oldRate, newRate);
    }

    /// @notice Transfer the operator role to a new address.
    /// @param newOperator The address of the new operator.
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    // ---------------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------------

    /// @notice Returns the total base token balance held by this contract in escrow.
    function baseTokenBalance() external view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }
}
