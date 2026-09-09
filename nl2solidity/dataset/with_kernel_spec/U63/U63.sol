// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenizedEquityShares
 * @notice Issues and manages tokenized representations of real-world equity shares.
 *         The contract holds no underlying assets; an off-chain custodian manages the
 *         actual shares. A designated operator is responsible for minting (upon proof
 *         of acquisition) and burning (upon redemption) tokenized shares.
 */
contract TokenizedEquityShares {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error AmountExceedsMax();
    error InsufficientBalance();
    error InsufficientAllowance();
    error FeeExceedsMaximum();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(
        address indexed caller,
        address indexed recipient,
        uint256 amount,
        uint256 feeAmount,
        bytes32 indexed proofHash
    );

    event Burn(
        address indexed caller,
        address indexed from,
        uint256 amount,
        bytes32 indexed proofHash
    );

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    event MintingFeeChanged(uint256 oldFeeBps, uint256 newFeeBps);

    event FeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            TOKEN METADATA
    //////////////////////////////////////////////////////////////*/

    string public constant name = "Tokenized Equity Shares";
    string public constant symbol = "TES";
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of shares that can be minted in a single transaction.
    uint256 public constant MAX_MINT_AMOUNT = 1_000_000 * 10 ** 18;

    /// @notice Upper bound on the minting fee to prevent misconfiguration.
    uint256 public constant MAX_FEE_BPS = 1000; // 10%

    /// @notice Basis points divisor (1 basis point = 0.01%).
    uint256 private constant BPS_DIVISOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The owner of the contract, who can set the operator and adjust fees.
    address public owner;

    /// @notice The designated operator responsible for minting and burning.
    address public operator;

    /// @notice The address that receives minting fees.
    address public feeRecipient;

    /// @notice The minting fee in basis points (default 10 = 0.1%).
    uint256 public mintingFeeBps;

    /// @notice Total supply of tokenized shares.
    uint256 private _totalSupply;

    /// @notice Balance of each account.
    mapping(address => uint256) public balanceOf;

    /// @notice Allowance granted by an owner to a spender.
    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param initialOperator The address designated as the initial operator.
     * @param initialFeeRecipient The address that will receive minting fees.
     */
    constructor(address initialOperator, address initialFeeRecipient) {
        if (initialOperator == address(0) || initialFeeRecipient == address(0)) {
            revert ZeroAddress();
        }

        owner = msg.sender;
        operator = initialOperator;
        feeRecipient = initialFeeRecipient;
        mintingFeeBps = 10; // 0.1%

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), initialOperator);
        emit FeeRecipientChanged(address(0), initialFeeRecipient);
        emit MintingFeeChanged(0, 10);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total supply of tokenized shares.
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Computes the fee that would be charged for a given mint amount.
     * @param amount The amount of shares to be minted.
     * @return The fee amount in the same units as the shares.
     */
    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * mintingFeeBps) / BPS_DIVISOR;
    }

    /*//////////////////////////////////////////////////////////////
                         OWNERSHIP / CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers contract ownership to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Sets a new operator. Only callable by the owner.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Adjusts the minting fee. Only callable by the owner.
     * @param newFeeBps The new fee in basis points (e.g., 10 = 0.1%).
     */
    function setMintingFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();
        emit MintingFeeChanged(mintingFeeBps, newFeeBps);
        mintingFeeBps = newFeeBps;
    }

    /**
     * @notice Sets a new fee recipient. Only callable by the owner.
     * @param newFeeRecipient The address that will receive minting fees.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20-LIKE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves a spender to transfer up to a given amount on behalf of the caller.
     * @param spender The address authorized to spend.
     * @param amount The maximum amount the spender may transfer.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfers shares from the caller to a recipient.
     * @param to The recipient address.
     * @param amount The amount of shares to transfer.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Transfers shares on behalf of an owner to a recipient, consuming allowance.
     * @param from The owner whose shares are being transferred.
     * @param to The recipient address.
     * @param amount The amount of shares to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                         MINT / BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new tokenized shares to a recipient. Only callable by the operator.
     * @dev A minting fee of `mintingFeeBps` basis points is applied and minted to the
     *      fee recipient. The `proofHash` references off-chain evidence of the
     *      underlying share acquisition verified by the custodian.
     * @param recipient The address that will receive the minted shares.
     * @param amount The amount of shares to mint (before fee).
     * @param proofHash A hash referencing the off-chain proof of share acquisition.
     */
    function mint(address recipient, uint256 amount, bytes32 proofHash) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_MINT_AMOUNT) revert AmountExceedsMax();

        uint256 feeAmount = (amount * mintingFeeBps) / BPS_DIVISOR;
        uint256 totalMinted = amount + feeAmount;

        // Effects: update supply and balances before external interactions.
        _totalSupply += totalMinted;

        unchecked {
            balanceOf[recipient] += amount;
            if (feeAmount > 0) {
                balanceOf[feeRecipient] += feeAmount;
            }
        }

        emit Mint(msg.sender, recipient, amount, feeAmount, proofHash);
        emit Transfer(address(0), recipient, amount);
        if (feeAmount > 0) {
            emit Transfer(address(0), feeRecipient, feeAmount);
        }
    }

    /**
     * @notice Burns tokenized shares from an account upon redemption of the
     *         underlying equity. Only callable by the operator.
     * @param from The address whose shares are being burned.
     * @param amount The amount of shares to burn.
     * @param proofHash A hash referencing the off-chain proof of share redemption.
     */
    function burn(address from, uint256 amount, bytes32 proofHash) external onlyOperator {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        // Effects: update balance and supply.
        balanceOf[from] -= amount;
        _totalSupply -= amount;

        emit Burn(msg.sender, from, amount, proofHash);
        emit Transfer(from, address(0), amount);
    }
}
