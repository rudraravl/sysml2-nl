// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) {
            if (address(token).code.length == 0) {
                revert SafeERC20FailedOperation(address(token));
            }
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/**
 * @title CrossChainSwapEscrow
 * @notice Facilitates cross-chain token swaps by holding deposited input tokens in escrow
 *         until a swap is either completed (processed by an operator) or cancelled by the
 *         original depositor. A 0.1% fee is applied to the output amount of every successful
 *         swap and accrues to the contract for later withdrawal by the owner.
 */
contract CrossChainSwapEscrow is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error ChainNotSupported(uint256 chainId);
    error TokenNotSupported(address token);
    error AmountBelowMinimum(uint256 amount, uint256 minimum);
    error SwapNotPending(bytes32 swapId);
    error SwapAlreadyProcessed(bytes32 swapId);
    error SwapNotProcessed(bytes32 swapId);
    error NotSwapInitiator(bytes32 swapId, address caller);
    error NotSwapRecipient(bytes32 swapId, address caller);
    error OutputAmountZero(bytes32 swapId);
    error ZeroAddress();
    error NothingToWithdraw(address token);
    error ArrayLengthMismatch();
    error InsufficientOutputLiquidity(address token, uint256 available, uint256 required);
    error NotOperatorOrOwner(address caller);
    error TransferFromFailed(address token, address from, address to, uint256 amount);

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event SwapInitiated(
        bytes32 indexed swapId,
        address indexed initiator,
        uint256 indexed sourceChain,
        uint256 destinationChain,
        address inputToken,
        address outputToken,
        uint256 amount,
        address recipient
    );

    event SwapProcessed(
        bytes32 indexed swapId,
        uint256 outputAmount,
        uint256 feeAmount
    );

    event SwapCancelled(bytes32 indexed swapId, address indexed initiator, uint256 refundedAmount);

    event SwapClaimed(bytes32 indexed swapId, address indexed recipient, uint256 claimedAmount);

    event ConfigurationUpdated(
        address indexed caller,
        uint256[] supportedChains,
        uint256 feeBps
    );

    event OperatorUpdated(address indexed operator, bool status);

    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant FEE_BPS = 1; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_AMOUNT_DIVISOR = 100; // minimum = 100 units * 10^decimals

    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    enum SwapStatus {
        NonExistent,
        Pending,
        Processed,
        Cancelled,
        Claimed
    }

    struct Swap {
        address initiator;
        uint256 sourceChain;
        uint256 destinationChain;
        address inputToken;
        address outputToken;
        uint256 amount;
        address recipient;
        uint256 outputAmount;
        uint256 feeAmount;
        SwapStatus status;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    address public operator;
    mapping(address => bool) public supportedTokens;
    mapping(uint256 => bool) public supportedChains;
    mapping(bytes32 => Swap) public swaps;
    mapping(address => uint256) public accruedFees;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperatorOrOwner() {
        if (msg.sender != operator && msg.sender != owner()) {
            revert NotOperatorOrOwner(msg.sender);
        }
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(
        address operator_,
        uint256[] memory supportedChains_,
        address[] memory supportedTokens_
    ) Ownable(msg.sender) {
        if (operator_ == address(0)) revert ZeroAddress();

        operator = operator_;
        emit OperatorUpdated(operator_, true);

        for (uint256 i = 0; i < supportedChains_.length; i++) {
            supportedChains[supportedChains_[i]] = true;
        }

        for (uint256 i = 0; i < supportedTokens_.length; i++) {
            if (supportedTokens_[i] == address(0)) revert ZeroAddress();
            supportedTokens[supportedTokens_[i]] = true;
        }

        emit ConfigurationUpdated(msg.sender, supportedChains_, FEE_BPS);
    }

    // ---------------------------------------------------------------------
    // External / Public functions
    // ---------------------------------------------------------------------

    /**
     * @notice Initiates a cross-chain swap by depositing `amount` of `inputToken` into escrow.
     * @param destinationChain The chain where the recipient will claim output tokens.
     * @param inputToken The token deposited on this chain.
     * @param outputToken The token expected on the destination chain (recorded for routing).
     * @param amount The amount of input token to deposit.
     * @param recipient The address that will claim the output tokens once processed.
     * @return swapId The unique identifier of the created swap.
     */
    function initiateSwap(
        uint256 destinationChain,
        address inputToken,
        address outputToken,
        uint256 amount,
        address recipient
    ) external nonReentrant returns (bytes32 swapId) {
        if (!supportedChains[destinationChain]) revert ChainNotSupported(destinationChain);
        if (!supportedTokens[inputToken]) revert TokenNotSupported(inputToken);
        if (!supportedTokens[outputToken]) revert TokenNotSupported(outputToken);
        if (recipient == address(0)) revert ZeroAddress();

        uint256 minimum = _minimumAmount(inputToken);
        if (amount < minimum) revert AmountBelowMinimum(amount, minimum);

        swapId = keccak256(
            abi.encodePacked(
                msg.sender,
                block.chainid,
                destinationChain,
                inputToken,
                outputToken,
                amount,
                recipient,
                block.timestamp
            )
        );

        Swap storage s = swaps[swapId];
        if (s.status != SwapStatus.NonExistent) revert SwapAlreadyProcessed(swapId);

        s.initiator = msg.sender;
        s.sourceChain = block.chainid;
        s.destinationChain = destinationChain;
        s.inputToken = inputToken;
        s.outputToken = outputToken;
        s.amount = amount;
        s.recipient = recipient;
        s.status = SwapStatus.Pending;

        _pullTokenFromCaller(inputToken, amount);

        emit SwapInitiated(
            swapId,
            msg.sender,
            block.chainid,
            destinationChain,
            inputToken,
            outputToken,
            amount,
            recipient
        );
    }

    /**
     * @notice Cancels a pending swap and refunds the deposited input tokens to the initiator.
     * @param swapId The identifier of the swap to cancel.
     */
    function cancelSwap(bytes32 swapId) external nonReentrant {
        Swap storage s = swaps[swapId];
        if (s.status != SwapStatus.Pending) revert SwapNotPending(swapId);
        if (s.initiator != msg.sender) revert NotSwapInitiator(swapId, msg.sender);

        s.status = SwapStatus.Cancelled;

        address inputToken = s.inputToken;
        uint256 refundAmount = s.amount;

        IERC20(inputToken).safeTransfer(s.initiator, refundAmount);

        emit SwapCancelled(swapId, msg.sender, refundAmount);
    }

    /**
     * @notice Marks a pending swap as processed and records the output amount to be claimed.
     *         The 0.1% fee is deducted from the output amount and accrues to the contract.
     * @dev Only callable by the operator or owner. The output token must be supported and
     *      must already be held by this contract in sufficient quantity.
     * @param swapId The identifier of the swap to process.
     * @param outputAmount The gross output amount produced by the cross-chain swap.
     */
    function processSwap(bytes32 swapId, uint256 outputAmount) external onlyOperatorOrOwner nonReentrant {
        Swap storage s = swaps[swapId];
        if (s.status != SwapStatus.Pending) revert SwapNotPending(swapId);
        if (outputAmount == 0) revert OutputAmountZero(swapId);

        address outputToken = s.outputToken;
        if (!supportedTokens[outputToken]) revert TokenNotSupported(outputToken);

        uint256 feeAmount = (outputAmount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 netOutput = outputAmount - feeAmount;

        s.outputAmount = netOutput;
        s.feeAmount = feeAmount;
        s.status = SwapStatus.Processed;

        accruedFees[outputToken] += feeAmount;

        // The operator is responsible for ensuring the contract holds enough output tokens
        // (e.g. by pre-funding or bridging them in) before marking the swap as processed.
        uint256 balance = IERC20(outputToken).balanceOf(address(this));
        uint256 required = netOutput + accruedFees[outputToken];
        if (balance < required) {
            revert InsufficientOutputLiquidity(outputToken, balance, required);
        }

        emit SwapProcessed(swapId, netOutput, feeAmount);
    }

    /**
     * @notice Allows the recipient of a processed swap to claim their net output tokens.
     * @param swapId The identifier of the swap to claim.
     */
    function claimSwap(bytes32 swapId) external nonReentrant {
        Swap storage s = swaps[swapId];
        if (s.status != SwapStatus.Processed) revert SwapNotProcessed(swapId);
        if (s.recipient != msg.sender) revert NotSwapRecipient(swapId, msg.sender);

        s.status = SwapStatus.Claimed;

        address outputToken = s.outputToken;
        uint256 claimAmount = s.outputAmount;

        IERC20(outputToken).safeTransfer(s.recipient, claimAmount);

        emit SwapClaimed(swapId, msg.sender, claimAmount);
    }

    /**
     * @notice Updates the set of supported chains and tokens.
     * @param chains Array of chain ids to set support flags for.
     * @param chainFlags Parallel array of booleans indicating support status.
     * @param tokens Array of token addresses to set support flags for.
     * @param tokenFlags Parallel array of booleans indicating support status.
     */
    function updateConfiguration(
        uint256[] calldata chains,
        bool[] calldata chainFlags,
        address[] calldata tokens,
        bool[] calldata tokenFlags
    ) external onlyOperatorOrOwner {
        if (chains.length != chainFlags.length) revert ArrayLengthMismatch();
        if (tokens.length != tokenFlags.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < chains.length; i++) {
            supportedChains[chains[i]] = chainFlags[i];
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            supportedTokens[tokens[i]] = tokenFlags[i];
        }

        emit ConfigurationUpdated(msg.sender, chains, FEE_BPS);
    }

    /**
     * @notice Sets or unsets the operator role.
     * @param operator_ The new operator address (use address(0) to revoke).
     */
    function setOperator(address operator_) external onlyOwner {
        operator = operator_;
        emit OperatorUpdated(operator_, operator_ != address(0));
    }

    /**
     * @notice Withdraws accumulated fees for a given token to a recipient.
     * @param token The token whose fees should be withdrawn.
     * @param to The recipient of the withdrawn fees.
     */
    function withdrawFees(address token, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees[token];
        if (amount == 0) revert NothingToWithdraw(token);

        accruedFees[token] = 0;
        IERC20(token).safeTransfer(to, amount);

        emit FeesWithdrawn(token, to, amount);
    }

    /**
     * @notice Allows the owner to rescue tokens that are not accrued fees (e.g. mistakenly
     *         sent tokens), excluding tokens locked in pending swaps.
     * @param token The token to rescue.
     * @param to The recipient.
     * @param amount The amount to rescue.
     */
    function rescue(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 lockedFees = accruedFees[token];
        if (balance - lockedFees < amount) revert NothingToWithdraw(token);

        IERC20(token).safeTransfer(to, amount);
        emit TokensRescued(token, to, amount);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the full swap record for a given swap id.
     */
    function getSwap(bytes32 swapId) external view returns (Swap memory) {
        return swaps[swapId];
    }

    /**
     * @notice Returns the status of a swap.
     */
    function swapStatus(bytes32 swapId) external view returns (SwapStatus) {
        return swaps[swapId].status;
    }

    /**
     * @notice Computes the minimum swap amount for a token: 100 units (i.e. 100 * 10^decimals).
     */
    function minimumAmount(address token) external view returns (uint256) {
        return _minimumAmount(token);
    }

    /**
     * @notice Returns the fee that would be applied to a given gross output amount.
     */
    function computeFee(uint256 outputAmount) external pure returns (uint256) {
        return (outputAmount * FEE_BPS) / BPS_DENOMINATOR;
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    /**
     * @dev Pulls `amount` of `token` from the caller (msg.sender) into this contract.
     *      The `from` address is hard-coded to msg.sender to avoid arbitrary token pulls.
     */
    function _pullTokenFromCaller(address token, uint256 amount) internal {
        IERC20 t = IERC20(token);
        address from = msg.sender;
        address to = address(this);

        bool success = t.transferFrom(from, to, amount);
        if (!success) {
            if (address(t).code.length == 0) {
                revert TransferFromFailed(token, from, to, amount);
            }
            revert TransferFromFailed(token, from, to, amount);
        }
    }

    function _minimumAmount(address token) internal view returns (uint256) {
        uint8 decimals = 18;
        try IERC20Extended(token).decimals() returns (uint8 d) {
            decimals = d;
        } catch {
            decimals = 18;
        }
        return MIN_AMOUNT_DIVISOR * (10 ** uint256(decimals));
    }
}
