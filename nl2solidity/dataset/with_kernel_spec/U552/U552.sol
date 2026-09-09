// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title OneWayTokenBridge
 * @dev Facilitates one-way transfers of a fungible token from a source chain to a
 * destination chain. Tokens are held in escrow on the source chain. Users deposit
 * tokens, then initiate bridge operations that lock their tokens and signal the
 * destination chain to mint corresponding tokens. A designated operator finalizes
 * each bridge operation. A 0.1% fee is deducted from every bridged amount.
 */
contract OneWayTokenBridge {
    // ============ Immutable / Constant ============
    IERC20 public immutable token;
    uint256 public constant MIN_DEPOSIT = 100 * 10**18;
    uint256 public constant FEE_DENOMINATOR = 1000; // 0.1% fee

    // ============ Access Control ============
    address public owner;
    address public operator;
    address public feeCollector;

    // ============ Accounting ============
    uint256 public totalEscrowed;   // tokens currently held as user deposits (not yet bridged)
    uint256 public totalBridged;    // cumulative net tokens bridged to destination chain
    mapping(address => uint256) public depositedAmount; // per-user deposited balance

    // ============ Bridge Requests ============
    struct BridgeRequest {
        address sender;
        uint256 grossAmount;
        uint256 netAmount;
        uint256 fee;
        bool finalized;
    }
    mapping(uint256 => BridgeRequest) public bridgeRequests;
    uint256 public nextTxId;

    // ============ Events ============
    event Deposited(address indexed sender, uint256 amount);
    event Bridged(address indexed sender, uint256 amount, uint256 netAmount, uint256 fee, uint256 indexed txId);
    event BridgeFinalized(uint256 indexed txId, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event FeeCollectorChanged(address indexed previousCollector, address indexed newCollector);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Custom Errors ============
    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized(address caller);
    error InsufficientDeposit(uint256 amount, uint256 minDeposit);
    error InsufficientBalance(address user, uint256 required, uint256 available);
    error InvalidTxId(uint256 txId);
    error AlreadyFinalized(uint256 txId);
    error TransferFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized(msg.sender);
        _;
    }

    // ============ Constructor ============
    constructor(address _token, address _operator, address _feeCollector) {
        if (_token == address(0) || _operator == address(0) || _feeCollector == address(0)) {
            revert ZeroAddress();
        }
        token = IERC20(_token);
        owner = msg.sender;
        operator = _operator;
        feeCollector = _feeCollector;
        nextTxId = 1;
    }

    // ============ User Functions ============

    /**
     * @notice Deposit tokens into the bridge escrow.
     * @param amount The number of tokens to deposit (must be > 0).
     */
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        // Effects
        depositedAmount[msg.sender] += amount;
        totalEscrowed += amount;

        // Interactions
        _safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Initiate a bridge operation, locking deposited tokens and signaling
     *         the destination chain to mint corresponding tokens.
     * @param amount The gross amount to bridge (must be >= MIN_DEPOSIT).
     * @return txId Unique identifier for this bridge operation.
     */
    function bridge(uint256 amount) external returns (uint256 txId) {
        if (amount < MIN_DEPOSIT) revert InsufficientDeposit(amount, MIN_DEPOSIT);
        if (depositedAmount[msg.sender] < amount) {
            revert InsufficientBalance(msg.sender, amount, depositedAmount[msg.sender]);
        }

        // Calculate 0.1% fee
        uint256 fee = amount / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Effects: lock tokens by reducing user deposit and escrow totals
        depositedAmount[msg.sender] -= amount;
        totalEscrowed -= amount;

        // Record the bridge request for operator finalization
        txId = nextTxId++;
        bridgeRequests[txId] = BridgeRequest({
            sender: msg.sender,
            grossAmount: amount,
            netAmount: netAmount,
            fee: fee,
            finalized: false
        });

        emit Bridged(msg.sender, amount, netAmount, fee, txId);
    }

    // ============ Operator Functions ============

    /**
     * @notice Finalize a bridge operation, confirming the destination chain has
     *         minted the corresponding tokens. Deducts the bridged amount from the
     *         contract's total balance and sends the fee to the fee collector.
     * @param txId The unique identifier of the bridge operation to finalize.
     */
    function finalizeBridge(uint256 txId) external onlyOperator {
        BridgeRequest storage req = bridgeRequests[txId];
        if (req.sender == address(0)) revert InvalidTxId(txId);
        if (req.finalized) revert AlreadyFinalized(txId);

        // Effects
        req.finalized = true;
        totalBridged += req.netAmount;

        // Interactions: send fee to collector
        if (req.fee > 0) {
            _safeTransfer(feeCollector, req.fee);
        }

        emit BridgeFinalized(txId, req.netAmount);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the operator address.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Update the fee collector address.
     * @param newFeeCollector The address of the new fee collector.
     */
    function setFeeCollector(address newFeeCollector) external onlyOwner {
        if (newFeeCollector == address(0)) revert ZeroAddress();
        emit FeeCollectorChanged(feeCollector, newFeeCollector);
        feeCollector = newFeeCollector;
    }

    /**
     * @notice Transfer contract ownership to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ============ View Functions ============

    /**
     * @notice Returns the actual token balance held by this contract.
     */
    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Returns details of a specific bridge request.
     */
    function getBridgeRequest(uint256 txId) external view returns (BridgeRequest memory) {
        return bridgeRequests[txId];
    }

    // ============ Internal Helpers ============

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
