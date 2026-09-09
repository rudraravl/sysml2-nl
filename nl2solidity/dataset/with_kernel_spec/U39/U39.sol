// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @dev Minimal ERC-20 interface needed by the bridge escrow.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title Ownable
 * @dev Minimal ownable implementation.
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnerCannotBeZero();

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnerCannotBeZero();
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnerCannotBeZero();
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

/**
 * @title ReentrancyGuard
 * @dev Minimal reentrancy guard.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title TokenBridgeEscrow
 * @notice Facilitates cross-chain transfers of arbitrary ERC-20 tokens by holding
 *         deposited tokens in escrow on the origin chain. A designated relayer can
 *         finalize withdrawal requests after a minimum delay of 7 days, with a 0.1%
 *         fee deducted from the withdrawn amount. The owner manages canonical token
 *         mappings between chains.
 */
contract TokenBridgeEscrow is Ownable, ReentrancyGuard {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error ZeroAmount();
    error ZeroAddress();
    error NotRelayer();
    error WithdrawalTooEarly();
    error RequestAlreadyFinalized();
    error InvalidRequestId();
    error InsufficientDeposit();
    error TokenNotMapped();
    error SafeTransferFailed();
    error InvalidDestChainId();

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @dev Minimum time between a withdrawal request and its finalization.
    uint256 public constant MIN_WITHDRAWAL_DELAY = 7 days;

    /// @dev Fee charged on finalized withdrawals, in basis points (10 = 0.1%).
    uint256 public constant FEE_BIPS = 10;

    /// @dev Precision denominator for basis-point calculations.
    uint256 public constant BIPS_PRECISION = 10_000;

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------

    struct WithdrawalRequest {
        address sender;
        address recipient;
        address token;
        uint256 amount;
        uint256 destChainId;
        uint64 requestedAt;
        bool finalized;
    }

    // ---------------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------------

    /// @dev Address of the authorized relayer who can finalize withdrawals.
    address public relayer;

    /// @dev Next withdrawal request identifier (starts at 1).
    uint256 public nextRequestId;

    /// @dev user => token => available deposited amount
    mapping(address => mapping(address => uint256)) public userDeposits;

    /// @dev destChainId => originToken => destinationToken
    mapping(uint256 => mapping(address => address)) public canonicalToken;

    /// @dev requestId => WithdrawalRequest
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;

    /// @dev token => accumulated fees awaiting claim by the owner
    mapping(address => uint256) public feeAccrued;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event TokensDeposited(
        address indexed sender,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    event WithdrawalRequested(
        address indexed sender,
        address recipient,
        address indexed token,
        uint256 amount,
        uint256 indexed requestId
    );

    event WithdrawalFinalized(
        address indexed sender,
        address recipient,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 indexed requestId
    );

    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);

    event CanonicalTokenUpdated(
        uint256 indexed destChainId,
        address indexed originToken,
        address indexed destToken
    );

    event FeeClaimed(address indexed token, address indexed recipient, uint256 amount);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert NotRelayer();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address relayer_) Ownable(msg.sender) {
        if (relayer_ == address(0)) revert ZeroAddress();
        relayer = relayer_;
        nextRequestId = 1;
        emit RelayerUpdated(address(0), relayer_);
    }

    // ---------------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------------

    /**
     * @notice Updates the authorized relayer address.
     * @param newRelayer The new relayer address.
     */
    function setRelayer(address newRelayer) external onlyOwner {
        if (newRelayer == address(0)) revert ZeroAddress();
        emit RelayerUpdated(relayer, newRelayer);
        relayer = newRelayer;
    }

    /**
     * @notice Sets or updates the canonical token mapping between the origin
     *         chain and a destination chain.
     * @param destChainId The destination chain identifier.
     * @param originToken The token address on this (origin) chain.
     * @param destToken   The canonical token address on the destination chain.
     */
    function setCanonicalToken(
        uint256 destChainId,
        address originToken,
        address destToken
    ) external onlyOwner {
        if (originToken == address(0) || destToken == address(0)) revert ZeroAddress();
        if (destChainId == 0) revert InvalidDestChainId();
        canonicalToken[destChainId][originToken] = destToken;
        emit CanonicalTokenUpdated(destChainId, originToken, destToken);
    }

    // ---------------------------------------------------------------------
    // Core Bridge Functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposits ERC-20 tokens into escrow on behalf of a recipient.
     * @param token     The ERC-20 token address to deposit.
     * @param amount    The amount of tokens to deposit.
     * @param recipient The address to credit the deposit to.
     */
    function deposit(address token, uint256 amount, address recipient) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();

        // Effects: record deposit before interaction.
        userDeposits[recipient][token] += amount;

        // Interaction: pull tokens from the caller.
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit TokensDeposited(msg.sender, recipient, token, amount);
    }

    /**
     * @notice Initiates a cross-chain withdrawal request. The caller's deposited
     *         balance is immediately reduced and the tokens are locked pending
     *         finalization by the relayer after the minimum delay.
     * @param token       The token to withdraw.
     * @param amount      The amount to withdraw.
     * @param recipient   The recipient address on the destination chain.
     * @param destChainId The destination chain identifier.
     * @return requestId The unique identifier for this withdrawal request.
     */
    function requestWithdrawal(
        address token,
        uint256 amount,
        address recipient,
        uint256 destChainId
    ) external nonReentrant returns (uint256 requestId) {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (destChainId == 0) revert InvalidDestChainId();
        if (canonicalToken[destChainId][token] == address(0)) revert TokenNotMapped();

        uint256 available = userDeposits[msg.sender][token];
        if (available < amount) revert InsufficientDeposit();

        // Effects: lock the tokens by reducing available balance.
        userDeposits[msg.sender][token] = available - amount;

        requestId = nextRequestId++;
        withdrawalRequests[requestId] = WithdrawalRequest({
            sender: msg.sender,
            recipient: recipient,
            token: token,
            amount: amount,
            destChainId: destChainId,
            requestedAt: uint64(block.timestamp),
            finalized: false
        });

        emit WithdrawalRequested(msg.sender, recipient, token, amount, requestId);
    }

    /**
     * @notice Finalizes a pending withdrawal request, transferring the canonical
     *         destination token (minus the 0.1% fee) to the recipient. Only
     *         callable by the relayer after the minimum withdrawal delay has
     *         elapsed.
     * @param requestId The identifier of the withdrawal request to finalize.
     */
    function finalizeWithdrawal(uint256 requestId) external nonReentrant onlyRelayer {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requestedAt == 0) revert InvalidRequestId();
        if (req.finalized) revert RequestAlreadyFinalized();
        if (block.timestamp < req.requestedAt + MIN_WITHDRAWAL_DELAY)
            revert WithdrawalTooEarly();

        address destToken = canonicalToken[req.destChainId][req.token];
        if (destToken == address(0)) revert TokenNotMapped();

        // Effects: mark as finalized and accrue fee.
        req.finalized = true;

        uint256 fee = (req.amount * FEE_BIPS) / BIPS_PRECISION;
        uint256 payout = req.amount - fee;
        feeAccrued[destToken] += fee;

        // Interaction: transfer payout to recipient.
        _safeTransfer(destToken, req.recipient, payout);

        emit WithdrawalFinalized(req.sender, req.recipient, req.token, payout, fee, requestId);
    }

    /**
     * @notice Allows the owner to claim accumulated fees for a given token.
     * @param token The token address whose fees should be claimed.
     */
    function claimFees(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        uint256 amount = feeAccrued[token];
        if (amount == 0) revert ZeroAmount();
        feeAccrued[token] = 0;
        address recipient = owner();
        _safeTransfer(token, recipient, amount);
        emit FeeClaimed(token, recipient, amount);
    }

    // ---------------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the available deposited balance for a user and token.
     */
    function getDeposit(address user, address token) external view returns (uint256) {
        return userDeposits[user][token];
    }

    /**
     * @notice Returns the full withdrawal request struct for a given request ID.
     */
    function getWithdrawalRequest(uint256 requestId) external view returns (WithdrawalRequest memory) {
        return withdrawalRequests[requestId];
    }

    /**
     * @notice Returns the canonical destination token address for an origin
     *         token on a given destination chain.
     */
    function getCanonicalToken(uint256 destChainId, address originToken) external view returns (address) {
        return canonicalToken[destChainId][originToken];
    }

    /**
     * @notice Returns the timestamp after which a withdrawal request can be
     *         finalized, or 0 if the request does not exist.
     */
    function getFinalizableAt(uint256 requestId) external view returns (uint256) {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requestedAt == 0) return 0;
        return req.requestedAt + MIN_WITHDRAWAL_DELAY;
    }

    // ---------------------------------------------------------------------
    // Internal Helpers
    // ---------------------------------------------------------------------

    /**
     * @dev Performs an ERC-20 `transfer` and reverts on failure, supporting both
     *      tokens that return a boolean and tokens that return nothing.
     */
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    /**
     * @dev Performs an ERC-20 `transferFrom` and reverts on failure, supporting
     *      both tokens that return a boolean and tokens that return nothing.
     */
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }
}
