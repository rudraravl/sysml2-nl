// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Backing {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract GoldBackedStablecoin {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    string public constant name = "Gold Claim Stablecoin";
    string public constant symbol = "GCS";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    address public operator;
    address public custodian;

    IERC20Backing public immutable backingToken;

    /// @notice Fees expressed in basis points (1 bp = 0.01%)
    uint256 public mintFeeBps;   // 10 = 0.1%
    uint256 public redeemFeeBps; // 20 = 0.2%

    bool public mintPaused;
    bool public redeemPaused;

    uint256 private constant BPS_DENOMINATOR = 10_000;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Minted(address indexed sender, address indexed recipient, uint256 goldAmount, uint256 backingAmount, uint256 fee);
    event Redeemed(address indexed sender, address indexed recipient, uint256 goldAmount, uint256 backingAmount, uint256 fee);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event MintFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event RedeemFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MintPauseStateChanged(bool paused);
    event RedeemPauseStateChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error MintPaused();
    error RedeemPaused();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountZero();
    error FeeExceedsMax();
    error TransferFailed();

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _backingToken, address _custodian, address _operator)
        notZeroAddress(_backingToken)
        notZeroAddress(_custodian)
        notZeroAddress(_operator)
    {
        backingToken = IERC20Backing(_backingToken);
        custodian = _custodian;
        operator = _operator;
        owner = msg.sender;

        mintFeeBps = 10;    // 0.1%
        redeemFeeBps = 20;  // 0.2%

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit MintFeeUpdated(0, mintFeeBps);
        emit RedeemFeeUpdated(0, redeemFeeBps);
    }

    // -------------------------------------------------------------------------
    // ERC20 Core Functions
    // -------------------------------------------------------------------------

    function transfer(address recipient, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        if (balanceOf[sender] < amount) revert InsufficientBalance();
        if (allowance[sender][msg.sender] < amount) revert InsufficientAllowance();

        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    // -------------------------------------------------------------------------
    // Minting
    // -------------------------------------------------------------------------

    /// @notice Mint gold stablecoins by providing an equivalent value in the backing stablecoin.
    /// @dev The caller must first approve this contract to spend the backing stablecoin.
    /// The minting fee (0.1%) is added on top of the requested amount.
    /// @param amount The amount of gold stablecoins to mint.
    function mint(uint256 amount) external {
        if (mintPaused) revert MintPaused();
        if (amount == 0) revert AmountZero();

        uint256 fee = (amount * mintFeeBps) / BPS_DENOMINATOR;
        uint256 backingNeeded = amount + fee;

        // Transfer backing tokens from the caller to this contract
        if (!backingToken.transferFrom(msg.sender, address(this), backingNeeded)) revert TransferFailed();

        // Mint gold stablecoins to the caller
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        emit Minted(msg.sender, msg.sender, amount, backingNeeded, fee);
        emit Transfer(address(0), msg.sender, amount);
    }

    // -------------------------------------------------------------------------
    // Redemption
    // -------------------------------------------------------------------------

    /// @notice Redeem gold stablecoins for the equivalent value in the backing stablecoin.
    /// @dev The redemption fee (0.2%) is deducted from the backing tokens returned.
    /// @param amount The amount of gold stablecoins to redeem.
    function redeem(uint256 amount) external {
        if (redeemPaused) revert RedeemPaused();
        if (amount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * redeemFeeBps) / BPS_DENOMINATOR;
        uint256 backingAmount = amount - fee;

        // Burn gold stablecoins from the caller (checks-effects-interactions)
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        // Transfer backing tokens to the caller
        if (!backingToken.transfer(msg.sender, backingAmount)) revert TransferFailed();

        emit Redeemed(msg.sender, msg.sender, amount, backingAmount, fee);
        emit Transfer(msg.sender, address(0), amount);
    }

    // -------------------------------------------------------------------------
    // Operator Functions (Pause / Unpause)
    // -------------------------------------------------------------------------

    function setMintPaused(bool paused) external onlyOperator {
        mintPaused = paused;
        emit MintPauseStateChanged(paused);
    }

    function setRedeemPaused(bool paused) external onlyOperator {
        redeemPaused = paused;
        emit RedeemPauseStateChanged(paused);
    }

    // -------------------------------------------------------------------------
    // Owner Functions
    // -------------------------------------------------------------------------

    function setOperator(address newOperator)
        external
        onlyOwner
        notZeroAddress(newOperator)
    {
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function setMintFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > BPS_DENOMINATOR) revert FeeExceedsMax();
        uint256 oldFeeBps = mintFeeBps;
        mintFeeBps = newFeeBps;
        emit MintFeeUpdated(oldFeeBps, newFeeBps);
    }

    function setRedeemFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > BPS_DENOMINATOR) revert FeeExceedsMax();
        uint256 oldFeeBps = redeemFeeBps;
        redeemFeeBps = newFeeBps;
        emit RedeemFeeUpdated(oldFeeBps, newFeeBps);
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
        notZeroAddress(newOwner)
    {
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address previous = owner;
        owner = address(0);
        emit OwnershipTransferred(previous, address(0));
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------

    function getMintOutput(uint256 goldAmount) external view returns (uint256 backingNeeded, uint256 fee) {
        fee = (goldAmount * mintFeeBps) / BPS_DENOMINATOR;
        backingNeeded = goldAmount + fee;
    }

    function getRedeemOutput(uint256 goldAmount) external view returns (uint256 backingAmount, uint256 fee) {
        fee = (goldAmount * redeemFeeBps) / BPS_DENOMINATOR;
        backingAmount = goldAmount - fee;
    }
}
