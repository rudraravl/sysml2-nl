// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IERC20
 * @notice Minimal ERC20 interface for the bridge.
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
 * @title SafeERC20
 * @notice Minimal safe transfer library that wraps ERC20 calls with revert checks.
 * @dev safeTransferFrom does not accept an arbitrary `from` parameter; it always
 *      operates on msg.sender to prevent arbitrary token movement.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert SafeERC20__TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transferFrom(msg.sender, to, amount);
        if (!success) revert SafeERC20__TransferFromFailed();
    }

    error SafeERC20__TransferFailed();
    error SafeERC20__TransferFromFailed();
}

/**
 * @title ReentrancyGuard
 * @notice Minimal reentrancy guard implementation.
 */
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuard__ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    error ReentrancyGuard__ReentrantCall();
}

/**
 * @title CrossChainAssetBridge
 * @notice A cross-chain bridge for a yield-bearing stablecoin. Users deposit the native
 *         stablecoin on this chain to mint wrapped representations on a supported destination
 *         chain. Users can initiate withdrawals from a destination chain and later claim
 *         their native stablecoin once the withdrawal is confirmed by the operator.
 */
contract CrossChainAssetBridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error Bridge__Paused();
    error Bridge__NotPaused();
    error Bridge__NotOperator();
    error Bridge__ChainNotSupported(uint256 chainId);
    error Bridge__InsufficientDeposit(uint256 amount, uint256 minimum);
    error Bridge__FeeExceedsMaximum(uint256 feeBps, uint256 maxFeeBps);
    error Bridge__InvalidAmount();
    error Bridge__InvalidChainId();
    error Bridge__RequestNotFound(uint256 requestId);
    error Bridge__RequestNotConfirmed(uint256 requestId);
    error Bridge__RequestAlreadyClaimed(uint256 requestId);
    error Bridge__RequestAlreadyConfirmed(uint256 requestId);
    error Bridge__RequestNotOwner(uint256 requestId, address caller);
    error Bridge__InsufficientContractBalance(uint256 required, uint256 available);
    error Bridge__ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed user,
        uint256 indexed destChainId,
        uint256 amount,
        uint256 timestamp
    );

    event WithdrawalInitiated(
        uint256 indexed requestId,
        address indexed user,
        uint256 indexed srcChainId,
        uint256 amount,
        uint256 timestamp
    );

    event WithdrawalConfirmed(
        uint256 indexed requestId,
        address indexed operator,
        uint256 timestamp
    );

    event Claimed(
        uint256 indexed requestId,
        address indexed user,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    event ChainApproved(uint256 indexed chainId, bool approved);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum withdrawal fee in basis points (0.5% = 50 bps).
    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 50;

    /// @notice Minimum deposit amount: 100 stablecoin tokens (assuming 18 decimals).
    uint256 public constant MIN_DEPOSIT = 100 * 10 ** 18;

    /// @notice Basis points precision denominator.
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The native yield-bearing stablecoin token held in escrow by this contract.
    IERC20 public immutable stablecoin;

    /// @notice The designated operator responsible for pausing, fee updates, chain approval, and confirming withdrawals.
    address public operator;

    /// @notice Whether the bridge is currently paused.
    bool public paused;

    /// @notice Withdrawal fee in basis points applied to claimed amounts.
    uint256 public withdrawalFeeBps;

    /// @notice Total wrapped tokens minted per destination chain.
    mapping(uint256 chainId => uint256 wrappedSupply) public wrappedSupply;

    /// @notice Per-user total deposited amount (native stablecoin).
    mapping(address user => uint256 totalDeposited) public totalDeposited;

    /// @notice Per-user total withdrawn/claimed amount (native stablecoin).
    mapping(address user => uint256 totalWithdrawn) public totalWithdrawn;

    /// @notice Supported destination/source chains for bridging.
    mapping(uint256 chainId => bool supported) public supportedChains;

    /// @notice Counter for withdrawal request IDs.
    uint256 public nextRequestId;

    /// @notice Withdrawal request structure.
    struct WithdrawalRequest {
        address user;
        uint256 srcChainId;
        uint256 amount;
        bool confirmed;
        bool claimed;
    }

    /// @notice Mapping of withdrawal request ID to request data.
    mapping(uint256 requestId => WithdrawalRequest) public withdrawalRequests;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert Bridge__NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Bridge__Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert Bridge__NotPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param stablecoin_   The address of the native yield-bearing stablecoin.
     * @param operator_     The address of the initial operator.
     * @param initialFeeBps The initial withdrawal fee in basis points (max 50).
     */
    constructor(address stablecoin_, address operator_, uint256 initialFeeBps) {
        if (stablecoin_ == address(0)) revert Bridge__ZeroAddress();
        if (operator_ == address(0)) revert Bridge__ZeroAddress();
        if (initialFeeBps > MAX_WITHDRAWAL_FEE_BPS) {
            revert Bridge__FeeExceedsMaximum(initialFeeBps, MAX_WITHDRAWAL_FEE_BPS);
        }

        stablecoin = IERC20(stablecoin_);
        operator = operator_;
        withdrawalFeeBps = initialFeeBps;

        emit OperatorUpdated(address(0), operator_);
        emit WithdrawalFeeUpdated(0, initialFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits native stablecoin to mint wrapped representations on a destination chain.
     * @param destChainId The destination chain where wrapped tokens will be minted.
     * @param amount      The amount of stablecoin to deposit (must be >= MIN_DEPOSIT).
     */
    function deposit(uint256 destChainId, uint256 amount) external nonReentrant whenNotPaused {
        if (destChainId == 0) revert Bridge__InvalidChainId();
        if (!supportedChains[destChainId]) revert Bridge__ChainNotSupported(destChainId);
        if (amount < MIN_DEPOSIT) revert Bridge__InsufficientDeposit(amount, MIN_DEPOSIT);

        // Effects: update state before external interactions
        totalDeposited[msg.sender] += amount;
        wrappedSupply[destChainId] += amount;

        // Interactions: pull stablecoin from depositor (from is always msg.sender)
        stablecoin.safeTransferFrom(address(this), amount);

        emit Deposit(msg.sender, destChainId, amount, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a withdrawal of wrapped tokens from a source destination chain.
     *         The wrapped supply on that chain is reduced, and a claim request is created.
     *         The request must be confirmed by the operator before the user can claim.
     * @param srcChainId The source chain from which wrapped tokens are being withdrawn.
     * @param amount     The amount of wrapped tokens to withdraw.
     * @return requestId The ID of the created withdrawal request.
     */
    function initiateWithdrawal(uint256 srcChainId, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        if (srcChainId == 0) revert Bridge__InvalidChainId();
        if (!supportedChains[srcChainId]) revert Bridge__ChainNotSupported(srcChainId);
        if (amount == 0) revert Bridge__InvalidAmount();
        if (wrappedSupply[srcChainId] < amount) {
            revert Bridge__InsufficientContractBalance(amount, wrappedSupply[srcChainId]);
        }

        // Effects: reduce wrapped supply and create request
        wrappedSupply[srcChainId] -= amount;

        requestId = nextRequestId++;
        withdrawalRequests[requestId] = WithdrawalRequest({
            user: msg.sender,
            srcChainId: srcChainId,
            amount: amount,
            confirmed: false,
            claimed: false
        });

        emit WithdrawalInitiated(requestId, msg.sender, srcChainId, amount, block.timestamp);
    }

    /**
     * @notice Confirms a withdrawal request, allowing the user to claim their stablecoin.
     * @dev    Only callable by the operator. Can be called even when paused to process
     *         pending withdrawals during a pause.
     * @param requestId The ID of the withdrawal request to confirm.
     */
    function confirmWithdrawal(uint256 requestId) external onlyOperator {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        if (request.user == address(0)) revert Bridge__RequestNotFound(requestId);
        if (request.confirmed) revert Bridge__RequestAlreadyConfirmed(requestId);

        request.confirmed = true;

        emit WithdrawalConfirmed(requestId, msg.sender, block.timestamp);
    }

    /**
     * @notice Claims native stablecoin for a confirmed withdrawal request. A withdrawal fee
     *         is deducted from the claimed amount and retained by the contract.
     * @param requestId The ID of the withdrawal request to claim.
     */
    function claim(uint256 requestId) external nonReentrant {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        if (request.user == address(0)) revert Bridge__RequestNotFound(requestId);
        if (msg.sender != request.user) {
            revert Bridge__RequestNotOwner(requestId, msg.sender);
        }
        if (!request.confirmed) revert Bridge__RequestNotConfirmed(requestId);
        if (request.claimed) revert Bridge__RequestAlreadyClaimed(requestId);

        uint256 amount = request.amount;
        uint256 fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        // Effects: mark as claimed and update user totals
        request.claimed = true;
        totalWithdrawn[msg.sender] += amount;

        // Interactions: transfer stablecoin to the user
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (contractBalance < payout) {
            revert Bridge__InsufficientContractBalance(payout, contractBalance);
        }
        stablecoin.safeTransfer(msg.sender, payout);

        emit Claimed(requestId, msg.sender, payout, fee, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                         OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses all deposits and withdrawal initiations.
     */
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpauses the bridge, allowing deposits and withdrawal initiations.
     */
    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Updates the withdrawal fee percentage in basis points.
     * @param newFeeBps The new fee in basis points (must not exceed MAX_WITHDRAWAL_FEE_BPS).
     */
    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_WITHDRAWAL_FEE_BPS) {
            revert Bridge__FeeExceedsMaximum(newFeeBps, MAX_WITHDRAWAL_FEE_BPS);
        }
        uint256 oldFeeBps = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Approves or revokes a destination chain for bridging.
     * @param chainId  The chain ID to approve or revoke.
     * @param approved Whether the chain is supported.
     */
    function approveChain(uint256 chainId, bool approved) external onlyOperator {
        if (chainId == 0) revert Bridge__InvalidChainId();
        supportedChains[chainId] = approved;
        emit ChainApproved(chainId, approved);
    }

    /**
     * @notice Transfers the operator role to a new address.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert Bridge__ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the details of a withdrawal request.
     * @param requestId The ID of the withdrawal request.
     */
    function getWithdrawalRequest(uint256 requestId)
        external
        view
        returns (address user, uint256 srcChainId, uint256 amount, bool confirmed, bool claimed)
    {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        return (request.user, request.srcChainId, request.amount, request.confirmed, request.claimed);
    }

    /**
     * @notice Computes the fee and payout for a given withdrawal amount.
     * @param amount The gross withdrawal amount.
     * @return fee    The fee deducted.
     * @return payout The net amount the user would receive.
     */
    function quoteWithdrawal(uint256 amount) external view returns (uint256 fee, uint256 payout) {
        fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        payout = amount - fee;
    }

    /**
     * @notice Returns the total stablecoin balance held by this contract.
     */
    function contractBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }
}
