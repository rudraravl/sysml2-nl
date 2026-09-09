// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CrossChainTokenBridge
 * @notice Custodies deposited ERC20 tokens and facilitates operator-approved
 *         cross-chain transfers with a 0.1% fee routed to a treasury. Transfer
 *         requests must be approved within 24 hours or the locked tokens become
 *         reclaimable by the original sender.
 */
contract CrossChainTokenBridge {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant APPROVAL_WINDOW = 24 hours;

    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    enum Status {
        None,
        Pending,
        Approved,
        Completed,
        Reclaimed
    }

    struct TransferRequest {
        address sender;
        address token;
        uint256 amount;
        uint256 sourceChain;
        uint256 destinationChain;
        bytes recipient;
        uint256 initiatedAt;
        uint256 approvedAt;
        uint256 completedAt;
        Status status;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    address public operator;
    address public treasury;
    uint256 public immutable thisChainId;

    uint256 public nextTransferId;

    /// @dev user => token => custodied balance available for transfer / claim
    mapping(address => mapping(address => uint256)) public deposits;

    /// @dev chainId => tokenOnThatChain => supported
    mapping(uint256 => mapping(address => bool)) public supportedTokens;

    /// @dev transferId => TransferRequest (source-chain record)
    mapping(uint256 => TransferRequest) public transfers;

    /// @dev sourceTransferId => completed (destination-chain guard)
    mapping(uint256 => bool) public completedTransfers;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposit(address indexed user, address indexed token, uint256 amount, address indexed sender);
    event TransferRequested(
        uint256 indexed transferId,
        address indexed sender,
        address token,
        uint256 amount,
        uint256 destinationChain,
        bytes recipient
    );
    event TransferApproved(uint256 indexed transferId, address indexed operator, uint256 fee);
    event TransferCompleted(
        uint256 indexed transferId,
        address indexed recipient,
        address token,
        uint256 netAmount,
        uint256 fee
    );
    event TransferReclaimed(uint256 indexed transferId, address indexed sender, uint256 amount);
    event SupportedTokenUpdated(uint256 indexed chainId, address indexed token, bool supported);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event LiquidityProvided(address indexed token, uint256 amount, address indexed provider);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error OnlyOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidChain();
    error TokenNotSupported();
    error InsufficientDeposit();
    error InvalidStatus();
    error ApprovalWindowExpired();
    error NotExpired();
    error NotSender();
    error TransferNotApproved();
    error AlreadyCompleted();
    error InsufficientContractBalance();
    error ERC20TransferFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address operator_, address treasury_, uint256 chainId_) {
        if (operator_ == address(0) || treasury_ == address(0)) revert ZeroAddress();
        operator = operator_;
        treasury = treasury_;
        thisChainId = chainId_;
        nextTransferId = 1;
    }

    // ---------------------------------------------------------------------
    // Deposit (source / liquidity)
    // ---------------------------------------------------------------------

    /// @notice Deposit ERC20 tokens into custody for the caller.
    function deposit(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (!supportedTokens[thisChainId][token]) revert TokenNotSupported();
        _safeTransferFrom(token, msg.sender, address(this), amount);
        deposits[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount, msg.sender);
    }

    /// @notice Operator-funded liquidity used to fulfil claims on the destination chain.
    function provideLiquidity(address token, uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit LiquidityProvided(token, amount, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Transfer request (source chain)
    // ---------------------------------------------------------------------

    /// @notice Lock `amount` of `token` and register a cross-chain transfer request.
    function requestTransfer(
        address token,
        uint256 amount,
        uint256 destinationChain,
        bytes calldata recipient
    ) external returns (uint256 transferId) {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (destinationChain == thisChainId) revert InvalidChain();
        if (recipient.length == 0) revert ZeroAddress();
        if (!supportedTokens[thisChainId][token]) revert TokenNotSupported();
        if (deposits[msg.sender][token] < amount) revert InsufficientDeposit();

        // Effects before interactions
        deposits[msg.sender][token] -= amount;

        transferId = nextTransferId++;
        transfers[transferId] = TransferRequest({
            sender: msg.sender,
            token: token,
            amount: amount,
            sourceChain: thisChainId,
            destinationChain: destinationChain,
            recipient: recipient,
            initiatedAt: block.timestamp,
            approvedAt: 0,
            completedAt: 0,
            status: Status.Pending
        });

        emit TransferRequested(transferId, msg.sender, token, amount, destinationChain, recipient);
    }

    // ---------------------------------------------------------------------
    // Operator approval (source chain)
    // ---------------------------------------------------------------------

    /// @notice Approve a pending transfer within the 24h window and route the fee to treasury.
    function approveTransfer(uint256 transferId) external onlyOperator {
        TransferRequest storage req = transfers[transferId];
        if (req.status != Status.Pending) revert InvalidStatus();
        if (block.timestamp > req.initiatedAt + APPROVAL_WINDOW) revert ApprovalWindowExpired();

        // Effects before interactions
        req.status = Status.Approved;
        req.approvedAt = block.timestamp;

        uint256 fee = (req.amount * FEE_BPS) / BPS_DENOM;
        if (fee > 0) {
            _safeTransfer(req.token, treasury, fee);
        }

        emit TransferApproved(transferId, msg.sender, fee);
    }

    // ---------------------------------------------------------------------
    // Reclaim expired (source chain)
    // ---------------------------------------------------------------------

    /// @notice Reclaim locked tokens if the operator failed to approve within 24 hours.
    function reclaimTransfer(uint256 transferId) external {
        TransferRequest storage req = transfers[transferId];
        if (req.status != Status.Pending) revert InvalidStatus();
        if (block.timestamp <= req.initiatedAt + APPROVAL_WINDOW) revert NotExpired();
        if (req.sender != msg.sender) revert NotSender();

        // Effects before interactions
        req.status = Status.Reclaimed;
        deposits[msg.sender][req.token] += req.amount;

        emit TransferReclaimed(transferId, msg.sender, req.amount);
    }

    // ---------------------------------------------------------------------
    // Complete transfer (destination chain)
    // ---------------------------------------------------------------------

    /// @notice Finalise an approved cross-chain transfer by crediting the recipient
    ///         with the net amount (gross minus 0.1% fee, already taken on source).
    function completeTransfer(
        uint256 sourceTransferId,
        address recipient,
        address token,
        uint256 grossAmount
    ) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (grossAmount == 0) revert ZeroAmount();
        if (!supportedTokens[thisChainId][token]) revert TokenNotSupported();
        if (completedTransfers[sourceTransferId]) revert AlreadyCompleted();

        uint256 fee = (grossAmount * FEE_BPS) / BPS_DENOM;
        uint256 net = grossAmount - fee;

        if (_contractBalance(token) < net) revert InsufficientContractBalance();

        // Effects before interactions
        completedTransfers[sourceTransferId] = true;
        deposits[recipient][token] += net;

        emit TransferCompleted(sourceTransferId, recipient, token, net, fee);
    }

    // ---------------------------------------------------------------------
    // Claim (destination chain)
    // ---------------------------------------------------------------------

    /// @notice Withdraw credited ERC20 tokens from custody to the caller's own balance.
    function claim(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (deposits[msg.sender][token] < amount) revert InsufficientDeposit();

        // Effects before interactions
        deposits[msg.sender][token] -= amount;
        _safeTransfer(token, msg.sender, amount);

        emit Deposit(msg.sender, token, amount, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------

    function setSupportedToken(uint256 chainId, address token, bool supported) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        supportedTokens[chainId][token] = supported;
        emit SupportedTokenUpdated(chainId, token, supported);
    }

    function updateOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function updateTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function isExpired(uint256 transferId) public view returns (bool) {
        TransferRequest storage req = transfers[transferId];
        return req.status == Status.Pending && block.timestamp > req.initiatedAt + APPROVAL_WINDOW;
    }

    function contractTokenBalance(address token) external view returns (uint256) {
        return _contractBalance(token);
    }

    function _contractBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // ---------------------------------------------------------------------
    // Internal transfer helpers
    // ---------------------------------------------------------------------

    /// @dev Safe ERC20 transfer that validates the call succeeded and, when return
    ///      data is present, that it decoded to `true`. Only ERC20 tokens are moved,
    ///      eliminating arbitrary native-ETH sends.
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20TransferFailed();
    }

    /// @dev Safe ERC20 transferFrom that validates the call succeeded and, when
    ///      return data is present, that it decoded to `true`.
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20TransferFailed();
    }
}
