// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title CrossChainBridge
 * @dev Facilitates cross-chain asset transfers by holding wrapped tokens on the source chain
 *      and releasing native tokens on the destination chain, or vice-versa. Charges a 0.1% fee
 *      on all transfers and enforces a minimum transfer amount of 100 units.
 */
contract CrossChainBridge {
    uint256 public constant FEE_BASIS_POINTS = 10; // 0.1% = 10 / 10000
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 public constant MINIMUM_TRANSFER = 100;

    address public operator;
    address public feeRecipient;

    struct TokenConfig {
        uint256 destinationChainId;
        address bridgeAgent;
        bool paused;
        bool supported;
    }

    struct TransferRecord {
        address user;
        address token;
        uint256 amount;
        uint256 fee;
        uint256 destinationChainId;
        address recipient;
        bool redeemed;
        bool failed;
        bool refunded;
    }

    /// @dev Deposited net amount (after fee) per user.
    mapping(address => uint256) public deposits;

    /// @dev Total supply of wrapped tokens held by this contract.
    uint256 public totalSupply;

    /// @dev Configuration for each supported token.
    mapping(address => TokenConfig) public tokenConfigs;

    /// @dev Record of each cross-chain transfer keyed by a unique transfer ID.
    mapping(bytes32 => TransferRecord) public transfers;

    /// @dev List of all supported token addresses.
    address[] public supportedTokens;

    uint256 private _locked = 1;

    // ── Events ──

    event Deposited(
        bytes32 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 destinationChainId,
        address recipient
    );

    event Redeemed(
        bytes32 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount,
        address recipient
    );

    event Refunded(
        bytes32 indexed transferId,
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event TokenAdded(address indexed token, uint256 destinationChainId, address bridgeAgent);
    event TokenPaused(address indexed token);
    event TokenUnpaused(address indexed token);
    event BridgeAgentUpdated(address indexed token, address indexed newAgent);
    event TransferFailed(bytes32 indexed transferId);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event OperatorUpdated(address indexed newOperator);

    // ── Custom Errors ──

    error NotOperator();
    error NotBridgeAgent();
    error Unauthorized();
    error TokenNotSupported(address token);
    error TokenIsPaused(address token);
    error BelowMinimumTransfer(uint256 amount, uint256 minimum);
    error TransferNotFound(bytes32 transferId);
    error TransferAlreadyRedeemed(bytes32 transferId);
    error TransferNotFailed(bytes32 transferId);
    error TransferAlreadyFailed(bytes32 transferId);
    error TransferAlreadyRefunded(bytes32 transferId);
    error InvalidParameters();
    error ZeroAddress();
    error ExternalTransferFailed();
    error ReentrancyDetected();

    // ── Modifiers ──

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!tokenConfigs[token].supported) revert TokenNotSupported(token);
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ── Constructor ──

    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        emit OperatorUpdated(_operator);
        emit FeeRecipientUpdated(_feeRecipient);
    }

    // ── Admin Functions ──

    /**
     * @dev Adds a new token to the list of supported tokens.
     * @param token The address of the token to support.
     * @param destinationChainId The destination chain identifier for this token.
     * @param bridgeAgent The address authorized to redeem or mark transfers as failed.
     */
    function addToken(address token, uint256 destinationChainId, address bridgeAgent)
        external
        onlyOperator
    {
        if (token == address(0) || bridgeAgent == address(0)) revert ZeroAddress();
        if (tokenConfigs[token].supported) revert InvalidParameters();

        tokenConfigs[token] = TokenConfig({
            destinationChainId: destinationChainId,
            bridgeAgent: bridgeAgent,
            paused: false,
            supported: true
        });

        supportedTokens.push(token);
        emit TokenAdded(token, destinationChainId, bridgeAgent);
    }

    /**
     * @dev Pauses transfers for a specific token.
     */
    function pauseToken(address token)
        external
        onlyOperator
        onlySupportedToken(token)
    {
        if (tokenConfigs[token].paused) revert InvalidParameters();
        tokenConfigs[token].paused = true;
        emit TokenPaused(token);
    }

    /**
     * @dev Unpauses transfers for a specific token.
     */
    function unpauseToken(address token)
        external
        onlyOperator
        onlySupportedToken(token)
    {
        if (!tokenConfigs[token].paused) revert InvalidParameters();
        tokenConfigs[token].paused = false;
        emit TokenUnpaused(token);
    }

    /**
     * @dev Updates the bridge agent for a given token.
     * @param token The token whose bridge agent should be updated.
     * @param newAgent The new bridge agent address.
     */
    function updateBridgeAgent(address token, address newAgent)
        external
        onlyOperator
        onlySupportedToken(token)
    {
        if (newAgent == address(0)) revert ZeroAddress();
        tokenConfigs[token].bridgeAgent = newAgent;
        emit BridgeAgentUpdated(token, newAgent);
    }

    /**
     * @dev Updates the fee recipient address.
     */
    function updateFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    /**
     * @dev Updates the operator address.
     */
    function updateOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    // ── Core Transfer Functions ──

    /**
     * @dev Initiates a cross-chain transfer by depositing tokens into this contract.
     *      A 0.1% fee is deducted and sent to the fee recipient. The net amount is
     *      recorded and held until redemption or refund.
     * @param token The token to transfer.
     * @param amount The gross amount of tokens to deposit (must be >= 100).
     * @param recipient The recipient address on the destination chain.
     * @return transferId A unique identifier for this transfer.
     */
    function deposit(address token, uint256 amount, address recipient)
        external
        onlySupportedToken(token)
        nonReentrant
        returns (bytes32 transferId)
    {
        if (tokenConfigs[token].paused) revert TokenIsPaused(token);
        if (amount < MINIMUM_TRANSFER) revert BelowMinimumTransfer(amount, MINIMUM_TRANSFER);
        if (recipient == address(0)) revert ZeroAddress();

        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Pull tokens from the depositor
        bool pullSuccess = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!pullSuccess) revert ExternalTransferFailed();

        // Send fee to fee recipient
        if (fee > 0) {
            bool feeSuccess = IERC20(token).transfer(feeRecipient, fee);
            if (!feeSuccess) revert ExternalTransferFailed();
        }

        // Effects: update state before external interactions
        deposits[msg.sender] += netAmount;
        totalSupply += netAmount;

        transferId = keccak256(
            abi.encodePacked(
                msg.sender,
                token,
                amount,
                block.chainid,
                block.timestamp,
                recipient,
                totalSupply
            )
        );

        transfers[transferId] = TransferRecord({
            user: msg.sender,
            token: token,
            amount: netAmount,
            fee: fee,
            destinationChainId: tokenConfigs[token].destinationChainId,
            recipient: recipient,
            redeemed: false,
            failed: false,
            refunded: false
        });

        emit Deposited(
            transferId,
            msg.sender,
            token,
            netAmount,
            fee,
            tokenConfigs[token].destinationChainId,
            recipient
        );
    }

    /**
     * @dev Redeems tokens on the destination chain after a successful cross-chain transfer.
     *      Only the configured bridge agent for the transfer's token may call this.
     * @param transferId The unique identifier of the transfer to redeem.
     */
    function redeem(bytes32 transferId) external nonReentrant {
        TransferRecord storage record = transfers[transferId];
        if (record.user == address(0)) revert TransferNotFound(transferId);
        if (msg.sender != tokenConfigs[record.token].bridgeAgent) revert NotBridgeAgent();
        if (record.redeemed) revert TransferAlreadyRedeemed(transferId);
        if (record.failed) revert TransferAlreadyFailed(transferId);

        // Effects
        record.redeemed = true;
        totalSupply -= record.amount;

        // Interactions
        bool success = IERC20(record.token).transfer(record.recipient, record.amount);
        if (!success) revert ExternalTransferFailed();

        emit Redeemed(transferId, record.user, record.token, record.amount, record.recipient);
    }

    /**
     * @dev Marks a transfer as failed, enabling the depositor to claim a refund.
     *      Only the configured bridge agent for the transfer's token may call this.
     * @param transferId The unique identifier of the failed transfer.
     */
    function markTransferFailed(bytes32 transferId) external nonReentrant {
        TransferRecord storage record = transfers[transferId];
        if (record.user == address(0)) revert TransferNotFound(transferId);
        if (msg.sender != tokenConfigs[record.token].bridgeAgent) revert NotBridgeAgent();
        if (record.redeemed) revert TransferAlreadyRedeemed(transferId);
        if (record.failed) revert TransferAlreadyFailed(transferId);

        record.failed = true;
        emit TransferFailed(transferId);
    }

    /**
     * @dev Allows the original depositor to claim a refund for a failed transfer.
     *      The net deposited amount (excluding the already-distributed fee) is returned.
     * @param transferId The unique identifier of the failed transfer.
     */
    function claimRefund(bytes32 transferId) external nonReentrant {
        TransferRecord storage record = transfers[transferId];
        if (record.user == address(0)) revert TransferNotFound(transferId);
        if (msg.sender != record.user) revert Unauthorized();
        if (!record.failed) revert TransferNotFailed(transferId);
        if (record.refunded) revert TransferAlreadyRefunded(transferId);

        // Effects
        record.refunded = true;
        deposits[msg.sender] -= record.amount;
        totalSupply -= record.amount;

        // Interactions
        bool success = IERC20(record.token).transfer(record.user, record.amount);
        if (!success) revert ExternalTransferFailed();

        emit Refunded(transferId, record.user, record.token, record.amount);
    }

    // ── View Functions ──

    function isTokenSupported(address token) external view returns (bool) {
        return tokenConfigs[token].supported;
    }

    function isTokenPaused(address token) external view returns (bool) {
        return tokenConfigs[token].paused;
    }

    function getTokenConfig(address token) external view returns (TokenConfig memory) {
        return tokenConfigs[token];
    }

    function getTransfer(bytes32 transferId) external view returns (TransferRecord memory) {
        return transfers[transferId];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function calculateFee(uint256 amount) external pure returns (uint256) {
        return (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
    }

    function depositsOf(address user) external view returns (uint256) {
        return deposits[user];
    }
}
