// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrossChainAssetBridge
 * @notice Custodies wrapped tokens representing assets on other chains. A privileged
 *         operator registers wrapped token types, sets cross-chain fees, and may pause
 *         individual token types. Users transfer wrapped tokens between each other and
 *         burn them to withdraw the underlying asset on a connected chain.
 */
contract CrossChainAssetBridge {
    // --------------------------------------------------------------
    // EVENTS
    // --------------------------------------------------------------
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TokenRegistered(bytes32 indexed assetId, address indexed wrappedToken, uint256 decimals);
    event FeeUpdated(uint256 feeBps);
    event TokenPausedSet(address indexed wrappedToken, bool paused);
    event Minted(address indexed to, address indexed wrappedToken, uint256 amount, uint256 fee);
    event Burned(address indexed from, address indexed wrappedToken, uint256 amount, uint256 fee);
    event CrossChainTransferCompleted(
        address indexed wrappedToken,
        address indexed user,
        uint256 netAmount,
        uint256 fee,
        bool isDeposit
    );
    event Transfer(address indexed wrappedToken, address indexed from, address indexed to, uint256 amount);

    // --------------------------------------------------------------
    // ERRORS
    // --------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error TokenNotRegistered();
    error TokenAlreadyRegistered();
    error AssetAlreadyMapped();
    error TokenPaused();
    error InvalidAmount();
    error InvalidDecimals();
    error InsufficientBalance();
    error FeeExceedsAmount();
    error FeeTooHigh();

    // --------------------------------------------------------------
    // CONSTANTS
    // --------------------------------------------------------------
    /// @dev Maximum percentage fee is 0.5% (50 basis points).
    uint16 public constant MAX_FEE_BPS = 50;

    // --------------------------------------------------------------
    // STATE
    // --------------------------------------------------------------
    address public operator;
    /// @dev Percentage fee in basis points applied to every cross-chain transfer.
    uint16 public feeBps;

    mapping(bytes32 => address) public assetToWrapped;
    mapping(address => bytes32) public wrappedToAsset;
    mapping(address => bool) public isRegistered;
    mapping(address => bool) public paused;
    mapping(address => uint256) public decimalsOf;
    mapping(address => uint256) public totalSupplyOf;
    mapping(address => mapping(address => uint256)) public balanceOf;

    // --------------------------------------------------------------
    // MODIFIERS
    // --------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier tokenActive(address wrappedToken) {
        if (!isRegistered[wrappedToken]) revert TokenNotRegistered();
        if (paused[wrappedToken]) revert TokenPaused();
        _;
    }

    // --------------------------------------------------------------
    // CONSTRUCTOR
    // --------------------------------------------------------------
    constructor(address _operator, uint16 _feeBps) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        operator = _operator;
        feeBps = _feeBps;
        emit OperatorChanged(address(0), _operator);
        emit FeeUpdated(_feeBps);
    }

    // --------------------------------------------------------------
    // ADMINISTRATION (OPERATOR ONLY)
    // --------------------------------------------------------------

    /**
     * @notice Transfers the operator role to a new address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Sets the percentage fee (in basis points) for cross-chain transfers.
     * @param _feeBps Fee in basis points; must not exceed MAX_FEE_BPS (50 = 0.5%).
     */
    function setFee(uint16 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    /**
     * @notice Registers a new wrapped token type corresponding to an asset on another chain.
     * @param assetId Unique identifier of the original chain asset.
     * @param wrappedToken Address representing the wrapped token on this chain.
     * @param decimals Decimal precision of the wrapped token.
     */
    function registerToken(
        bytes32 assetId,
        address wrappedToken,
        uint256 decimals
    ) external onlyOperator {
        if (wrappedToken == address(0)) revert ZeroAddress();
        if (isRegistered[wrappedToken]) revert TokenAlreadyRegistered();
        if (assetToWrapped[assetId] != address(0)) revert AssetAlreadyMapped();
        if (decimals < 2) revert InvalidDecimals();

        isRegistered[wrappedToken] = true;
        assetToWrapped[assetId] = wrappedToken;
        wrappedToAsset[wrappedToken] = assetId;
        decimalsOf[wrappedToken] = decimals;

        emit TokenRegistered(assetId, wrappedToken, decimals);
    }

    /**
     * @notice Pauses or unpauses cross-chain operations for a specific wrapped token.
     */
    function setPaused(address wrappedToken, bool _paused) external onlyOperator {
        if (!isRegistered[wrappedToken]) revert TokenNotRegistered();
        paused[wrappedToken] = _paused;
        emit TokenPausedSet(wrappedToken, _paused);
    }

    // --------------------------------------------------------------
    // CROSS-CHAIN OPERATIONS
    // --------------------------------------------------------------

    /**
     * @notice Mints wrapped tokens to a user after a verified deposit of the native
     *         asset on the connected source chain. A fee is deducted from the deposited
     *         amount and credited to the operator.
     * @param to Recipient of the minted wrapped tokens.
     * @param wrappedToken Wrapped token address to mint.
     * @param amount Total amount deposited on the source chain (before fees).
     */
    function mint(address to, address wrappedToken, uint256 amount) external onlyOperator tokenActive(wrappedToken) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 fee = _calculateFee(wrappedToken, amount);
        if (fee >= amount) revert FeeExceedsAmount();
        uint256 mintAmount = amount - fee;

        balanceOf[to][wrappedToken] += mintAmount;
        totalSupplyOf[wrappedToken] += mintAmount;

        if (fee != 0) {
            balanceOf[operator][wrappedToken] += fee;
            totalSupplyOf[wrappedToken] += fee;
            emit Transfer(wrappedToken, address(0), operator, fee);
        }

        emit Minted(to, wrappedToken, mintAmount, fee);
        emit Transfer(wrappedToken, address(0), to, mintAmount);
        emit CrossChainTransferCompleted(wrappedToken, to, mintAmount, fee, true);
    }

    /**
     * @notice Burns wrapped tokens from the caller to withdraw the underlying native
     *         asset on the connected chain. A fee is deducted and retained by the operator.
     * @param wrappedToken Wrapped token address to burn.
     * @param amount Total amount of wrapped tokens to burn (before fees).
     */
    function burn(address wrappedToken, uint256 amount) external tokenActive(wrappedToken) {
        if (amount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender][wrappedToken] < amount) revert InsufficientBalance();

        uint256 fee = _calculateFee(wrappedToken, amount);
        if (fee >= amount) revert FeeExceedsAmount();
        uint256 netAmount = amount - fee;

        // Deduct the full burn amount from the caller.
        balanceOf[msg.sender][wrappedToken] -= amount;
        totalSupplyOf[wrappedToken] -= amount;

        // Retain the fee inside the system, credited to the operator.
        if (fee != 0) {
            balanceOf[operator][wrappedToken] += fee;
            totalSupplyOf[wrappedToken] += fee;
            emit Transfer(wrappedToken, msg.sender, operator, fee);
        }

        // The net amount is effectively burned.
        emit Transfer(wrappedToken, msg.sender, address(0), netAmount);
        emit Burned(msg.sender, wrappedToken, netAmount, fee);
        emit CrossChainTransferCompleted(wrappedToken, msg.sender, netAmount, fee, false);
    }

    // --------------------------------------------------------------
    // WRAPPED TOKEN TRANSFERS
    // --------------------------------------------------------------

    /**
     * @notice Transfers wrapped tokens from the caller to another user.
     */
    function transfer(address to, address wrappedToken, uint256 amount) external tokenActive(wrappedToken) returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (balanceOf[msg.sender][wrappedToken] < amount) revert InsufficientBalance();

        balanceOf[msg.sender][wrappedToken] -= amount;
        balanceOf[to][wrappedToken] += amount;

        emit Transfer(wrappedToken, msg.sender, to, amount);
        return true;
    }

    // --------------------------------------------------------------
    // VIEWS
    // --------------------------------------------------------------

    /**
     * @notice Returns the total supply of a given wrapped token.
     */
    function totalSupply(address wrappedToken) external view returns (uint256) {
        return totalSupplyOf[wrappedToken];
    }

    // --------------------------------------------------------------
    // INTERNAL HELPERS
    // --------------------------------------------------------------

    /**
     * @dev Computes the cross-chain fee for a given wrapped token and amount.
     *      The fee is the sum of a percentage fee (feeBps basis points) and a
     *      flat fee of 0.01 units of the wrapped token (10^(decimals - 2)).
     */
    function _calculateFee(address wrappedToken, uint256 amount) internal view returns (uint256) {
        uint256 percentageFee = (amount * uint256(feeBps)) / 10000;
        uint256 decimals = decimalsOf[wrappedToken];
        // Flat fee of 0.01 units = 10^(decimals - 2). decimals >= 2 enforced at registration.
        uint256 flatFee = 10 ** (decimals - 2);
        return percentageFee + flatFee;
    }
}
