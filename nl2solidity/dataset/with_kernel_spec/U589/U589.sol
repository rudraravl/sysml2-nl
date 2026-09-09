// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CrossChainAssetBridge
 * @notice Facilitates cross-chain asset transfers by locking wrapped tokens on the source chain
 *         and releasing native tokens on the destination chain. Users deposit supported wrapped
 *         tokens, initiate withdrawal requests for native tokens on a linked chain, and claim
 *         their native tokens once an operator fulfills the request. A flat 0.1% fee is charged
 *         on all deposits, and a single withdrawal request cannot exceed 10,000 units.
 */
contract CrossChainAssetBridge {
    // ============ Custom Errors ============
    error Unauthorized();
    error UnsupportedToken();
    error InsufficientAvailableBalance();
    error ExceedsMaxWithdrawal();
    error RequestNotFound();
    error AlreadyFulfilled();
    error AlreadyClaimed();
    error NotRequester();
    error NotFulfilled();
    error ZeroAmount();
    error InvalidAddress();
    error InsufficientNativeLiquidity();
    error TransferFailed();

    // ============ Constants ============
    uint256 public constant FEE_BASIS_POINTS = 10; // 0.1%
    uint256 public constant FEE_DIVISOR = 10_000;
    uint256 public constant MAX_WITHDRAWAL_AMOUNT = 10_000;

    // ============ Structs ============
    struct TokenConfig {
        bool isSupported;
        address nativeToken; // token paid out on the destination chain
    }

    struct WithdrawalRequest {
        address requester;
        address wrappedToken;
        address nativeToken;
        uint256 amount;
        bytes destinationAddress;
        uint256 createdAt;
        bool fulfilled;
        bool claimed;
    }

    // ============ State Variables ============
    address public owner;
    address public feeCollector;

    mapping(address => bool) public operators;
    mapping(address => TokenConfig) public supportedTokens;

    // user => wrappedToken => net credited deposit (after fee)
    mapping(address => mapping(address => uint256)) public deposits;

    // user => wrappedToken => amount locked in pending withdrawal requests
    mapping(address => mapping(address => uint256)) public lockedBalance;

    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    uint256 public nextRequestId;

    // ============ Events ============
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed operator, bool enabled);
    event FeeCollectorUpdated(address indexed previousCollector, address indexed newCollector);
    event AssetSupported(address indexed wrappedToken, address indexed nativeToken, bool enabled);
    event Deposit(address indexed user, address indexed wrappedToken, uint256 amount, uint256 fee);
    event WithdrawalRequested(
        uint256 indexed requestId,
        address indexed requester,
        address indexed wrappedToken,
        address nativeToken,
        uint256 amount,
        bytes destinationAddress
    );
    event WithdrawalFulfilled(uint256 indexed requestId, address indexed operator);
    event WithdrawalClaimed(uint256 indexed requestId, address indexed requester, uint256 amount);

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert Unauthorized();
        _;
    }

    // ============ Constructor ============
    constructor(address feeCollector_) {
        if (feeCollector_ == address(0)) revert InvalidAddress();
        owner = msg.sender;
        feeCollector = feeCollector_;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeCollectorUpdated(address(0), feeCollector_);
    }

    // ============ Internal Helpers ============
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    // ============ Owner Functions ============

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setFeeCollector(address newCollector) external onlyOwner {
        if (newCollector == address(0)) revert InvalidAddress();
        address previous = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(previous, newCollector);
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        if (operator == address(0)) revert InvalidAddress();
        operators[operator] = enabled;
        emit OperatorUpdated(operator, enabled);
    }

    function setSupportedAsset(address wrappedToken, address nativeToken, bool enabled) external onlyOwner {
        if (wrappedToken == address(0) || nativeToken == address(0)) revert InvalidAddress();
        supportedTokens[wrappedToken] = TokenConfig({isSupported: enabled, nativeToken: nativeToken});
        emit AssetSupported(wrappedToken, nativeToken, enabled);
    }

    // ============ Operator Functions ============

    /**
     * @notice Allows an operator to deposit native (destination-chain) tokens into the contract
     *         to fund future claims.
     * @param nativeToken Address of the native token to deposit.
     * @param amount Amount to deposit.
     */
    function addNativeLiquidity(address nativeToken, uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        _safeTransferFrom(nativeToken, msg.sender, address(this), amount);
    }

    /**
     * @notice Fulfills a withdrawal request, marking it as ready for the requester to claim.
     * @param requestId ID of the withdrawal request to fulfill.
     */
    function fulfillWithdrawal(uint256 requestId) external onlyOperator {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requester == address(0)) revert RequestNotFound();
        if (req.fulfilled) revert AlreadyFulfilled();

        req.fulfilled = true;

        emit WithdrawalFulfilled(requestId, msg.sender);
    }

    // ============ Public Functions ============

    /**
     * @notice Deposits wrapped tokens into the bridge. A flat 0.1% fee is deducted and sent
     *         to the fee collector. The net amount is credited to the depositor.
     * @param wrappedToken Address of the supported wrapped token.
     * @param amount Amount of wrapped tokens to deposit.
     */
    function deposit(address wrappedToken, uint256 amount) external {
        if (!supportedTokens[wrappedToken].isSupported) revert UnsupportedToken();
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * FEE_BASIS_POINTS) / FEE_DIVISOR;
        uint256 netAmount = amount - fee;

        // Transfer full amount from user to the bridge
        _safeTransferFrom(wrappedToken, msg.sender, address(this), amount);

        // Transfer fee to the fee collector
        if (fee > 0) {
            _safeTransfer(wrappedToken, feeCollector, fee);
        }

        // Credit net deposit to user
        deposits[msg.sender][wrappedToken] += netAmount;

        emit Deposit(msg.sender, wrappedToken, netAmount, fee);
    }

    /**
     * @notice Initiates a withdrawal request for native tokens on the destination chain.
     *         The requested amount is locked from the user's available deposit balance.
     * @param wrappedToken Address of the wrapped token to withdraw against.
     * @param amount Amount of native tokens to request (must be <= 10,000).
     * @param destinationAddress Recipient address on the destination chain (encoded as bytes).
     * @return requestId The ID of the created withdrawal request.
     */
    function initiateWithdrawal(
        address wrappedToken,
        uint256 amount,
        bytes calldata destinationAddress
    ) external returns (uint256 requestId) {
        TokenConfig storage config = supportedTokens[wrappedToken];
        if (!config.isSupported) revert UnsupportedToken();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_WITHDRAWAL_AMOUNT) revert ExceedsMaxWithdrawal();

        uint256 available = deposits[msg.sender][wrappedToken] - lockedBalance[msg.sender][wrappedToken];
        if (amount > available) revert InsufficientAvailableBalance();

        // Lock the requested amount
        lockedBalance[msg.sender][wrappedToken] += amount;

        requestId = nextRequestId++;
        withdrawalRequests[requestId] = WithdrawalRequest({
            requester: msg.sender,
            wrappedToken: wrappedToken,
            nativeToken: config.nativeToken,
            amount: amount,
            destinationAddress: destinationAddress,
            createdAt: block.timestamp,
            fulfilled: false,
            claimed: false
        });

        emit WithdrawalRequested(requestId, msg.sender, wrappedToken, config.nativeToken, amount, destinationAddress);
    }

    /**
     * @notice Allows a requester to claim native tokens after their withdrawal request
     *         has been fulfilled by an operator.
     * @param requestId ID of the fulfilled withdrawal request.
     */
    function claimWithdrawal(uint256 requestId) external {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requester == address(0)) revert RequestNotFound();
        if (msg.sender != req.requester) revert NotRequester();
        if (!req.fulfilled) revert NotFulfilled();
        if (req.claimed) revert AlreadyClaimed();

        uint256 amount = req.amount;
        address nativeToken = req.nativeToken;

        // Verify sufficient native token liquidity
        if (IERC20(nativeToken).balanceOf(address(this)) < amount) revert InsufficientNativeLiquidity();

        // Effects: mark claimed and release locked balance
        req.claimed = true;
        lockedBalance[req.requester][req.wrappedToken] -= amount;
        deposits[req.requester][req.wrappedToken] -= amount;

        // Interactions: transfer native tokens to the requester
        _safeTransfer(nativeToken, msg.sender, amount);

        emit WithdrawalClaimed(requestId, msg.sender, amount);
    }

    // ============ View Functions ============

    /**
     * @notice Returns the total deposited balance (net of fees) for a user and wrapped token.
     */
    function getDepositBalance(address user, address wrappedToken) external view returns (uint256) {
        return deposits[user][wrappedToken];
    }

    /**
     * @notice Returns the available (unlocked) balance for a user and wrapped token.
     */
    function getAvailableBalance(address user, address wrappedToken) external view returns (uint256) {
        return deposits[user][wrappedToken] - lockedBalance[user][wrappedToken];
    }

    /**
     * @notice Returns the locked balance for a user and wrapped token.
     */
    function getLockedBalance(address user, address wrappedToken) external view returns (uint256) {
        return lockedBalance[user][wrappedToken];
    }

    /**
     * @notice Returns the full withdrawal request details.
     */
    function getWithdrawalRequest(uint256 requestId)
        external
        view
        returns (
            address requester,
            address wrappedToken,
            address nativeToken,
            uint256 amount,
            bytes memory destinationAddress,
            uint256 createdAt,
            bool fulfilled,
            bool claimed
        )
    {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        return (
            req.requester,
            req.wrappedToken,
            req.nativeToken,
            req.amount,
            req.destinationAddress,
            req.createdAt,
            req.fulfilled,
            req.claimed
        );
    }

    /**
     * @notice Returns the token configuration for a wrapped token.
     */
    function getTokenConfig(address wrappedToken) external view returns (TokenConfig memory) {
        return supportedTokens[wrappedToken];
    }

    /**
     * @notice Returns the native token balance held by the bridge for a given native token.
     */
    function getNativeLiquidity(address nativeToken) external view returns (uint256) {
        return IERC20(nativeToken).balanceOf(address(this));
    }
}
