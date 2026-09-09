// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title CrossChainTokenBridge
 * @notice A custodial bridge for a specific ERC-20 token. Users lock tokens on this chain
 *         to mint wrapped equivalents on a destination chain, and burn wrapped tokens on the
 *         destination chain to unlock the original tokens here. A designated operator approves
 *         unlock operations and manages the bridge fee.
 */
contract CrossChainTokenBridge {
    // ========== Custom Errors ==========
    error ZeroAddress();
    error InvalidAmount();
    error ExceedsMaxTransfer(uint256 amount, uint256 max);
    error InsufficientLockedSupply(uint256 available, uint256 required);
    error TransferFailed();
    error Unauthorized();
    error BurnEventAlreadyProcessed(bytes32 burnEventId);
    error FeeUpdateTooSoon(uint256 nextAllowedAt);
    error InvalidFee(uint256 feeBps);
    error InsufficientAccumulatedFees(uint256 available, uint256 required);

    // ========== Events ==========
    event Locked(
        uint256 indexed operationId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event Unlocked(
        uint256 indexed operationId,
        address indexed recipient,
        uint256 grossAmount,
        uint256 fee,
        uint256 netAmount,
        bytes32 indexed burnEventId,
        uint256 timestamp
    );

    event BridgeFeeUpdated(
        uint256 oldFeeBps,
        uint256 newFeeBps,
        address indexed changedBy,
        uint256 timestamp
    );

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator,
        uint256 timestamp
    );

    event FeesWithdrawn(address indexed to, uint256 amount);

    // ========== Constants ==========
    uint256 public constant MAX_FEE_BPS = 100; // cap at 1%
    uint256 public constant FEE_UPDATE_COOLDOWN = 24 hours;

    // ========== State ==========
    IERC20 public immutable token;
    uint256 public immutable maxTransferAmount;

    address public operator;

    uint256 public totalLockedSupply;
    mapping(address => uint256) public lockedBalanceOf;

    uint256 public feeBps; // 10 = 0.1%
    uint256 public lastFeeUpdateTime;

    uint256 public accumulatedFees;

    // Replay protection: burnEventId => processed
    mapping(bytes32 => bool) public processedBurnEvents;

    // Operation counter and records
    uint256 private _nextOperationId;
    mapping(uint256 => BridgeOperation) public operations;

    struct BridgeOperation {
        uint256 id;
        OperationType opType;
        address user;
        uint256 amount;
        uint256 fee;
        uint256 timestamp;
        bytes32 burnEventId;
    }

    enum OperationType { Lock, Unlock }

    // ========== Modifiers ==========
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ========== Constructor ==========
    constructor(address token_, address operator_, uint8 tokenDecimals) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (tokenDecimals > 18) revert InvalidAmount();

        token = IERC20(token_);
        operator = operator_;

        maxTransferAmount = 1_000_000 * 10 ** uint256(tokenDecimals);

        feeBps = 10; // 0.1%
        lastFeeUpdateTime = block.timestamp;
        _nextOperationId = 1;

        emit OperatorTransferred(address(0), operator_, block.timestamp);
    }

    // ========== External Functions ==========

    /**
     * @notice Locks fungible tokens into bridge custody, initiating a cross-chain transfer.
     * @param amount The amount of tokens to lock.
     * @return operationId The unique identifier assigned to this lock operation.
     */
    function lock(uint256 amount) external returns (uint256 operationId) {
        if (amount == 0) revert InvalidAmount();
        if (amount > maxTransferAmount) revert ExceedsMaxTransfer(amount, maxTransferAmount);

        // Interactions: pull tokens from user
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        // Effects
        lockedBalanceOf[msg.sender] += amount;
        totalLockedSupply += amount;

        operationId = _nextOperationId++;
        operations[operationId] = BridgeOperation({
            id: operationId,
            opType: OperationType.Lock,
            user: msg.sender,
            amount: amount,
            fee: 0,
            timestamp: block.timestamp,
            burnEventId: bytes32(0)
        });

        emit Locked(operationId, msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Operator approves an unlock by providing proof of a burn event on the destination chain.
     *         Tokens are released from custody to the recipient, minus the bridge fee.
     * @param burnEventId Unique identifier of the burn event on the destination chain.
     * @param recipient Address to receive the unlocked tokens.
     * @param grossAmount The full amount of tokens to unlock (before fee deduction).
     * @return operationId The unique identifier assigned to this unlock operation.
     */
    function approveUnlock(
        bytes32 burnEventId,
        address recipient,
        uint256 grossAmount
    ) external onlyOperator returns (uint256 operationId) {
        if (recipient == address(0)) revert ZeroAddress();
        if (grossAmount == 0) revert InvalidAmount();
        if (grossAmount > maxTransferAmount) revert ExceedsMaxTransfer(grossAmount, maxTransferAmount);
        if (processedBurnEvents[burnEventId]) revert BurnEventAlreadyProcessed(burnEventId);

        uint256 fee = (grossAmount * feeBps) / 10_000;
        uint256 netAmount = grossAmount - fee;

        if (totalLockedSupply < grossAmount) revert InsufficientLockedSupply(totalLockedSupply, grossAmount);

        // Mark burn event as processed (replay protection)
        processedBurnEvents[burnEventId] = true;

        // Effects
        totalLockedSupply -= grossAmount;
        accumulatedFees += fee;

        operationId = _nextOperationId++;
        operations[operationId] = BridgeOperation({
            id: operationId,
            opType: OperationType.Unlock,
            user: recipient,
            amount: grossAmount,
            fee: fee,
            timestamp: block.timestamp,
            burnEventId: burnEventId
        });

        // Interactions: transfer net amount to recipient
        bool ok = token.transfer(recipient, netAmount);
        if (!ok) revert TransferFailed();

        emit Unlocked(operationId, recipient, grossAmount, fee, netAmount, burnEventId, block.timestamp);
    }

    /**
     * @notice Updates the bridge fee in basis points. Can only be called once every 24 hours.
     * @param newFeeBps The new fee in basis points (e.g., 10 = 0.1%).
     */
    function setBridgeFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee(newFeeBps);
        if (block.timestamp < lastFeeUpdateTime + FEE_UPDATE_COOLDOWN) {
            revert FeeUpdateTooSoon(lastFeeUpdateTime + FEE_UPDATE_COOLDOWN);
        }

        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        lastFeeUpdateTime = block.timestamp;

        emit BridgeFeeUpdated(oldFeeBps, newFeeBps, msg.sender, block.timestamp);
    }

    /**
     * @notice Transfers the operator role to a new address.
     * @param newOperator The address of the new operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorTransferred(previous, newOperator, block.timestamp);
    }

    /**
     * @notice Allows the operator to withdraw accumulated bridge fees.
     * @param to The recipient address.
     * @param amount The amount of fee tokens to withdraw.
     */
    function withdrawFees(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount > accumulatedFees) revert InsufficientAccumulatedFees(accumulatedFees, amount);

        accumulatedFees -= amount;

        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    // ========== View Functions ==========

    /**
     * @notice Returns the total number of bridge operations recorded.
     */
    function totalOperations() external view returns (uint256) {
        return _nextOperationId - 1;
    }

    /**
     * @notice Returns the timestamp when the bridge fee can next be updated.
     */
    function nextFeeUpdateAllowedAt() external view returns (uint256) {
        return lastFeeUpdateTime + FEE_UPDATE_COOLDOWN;
    }

    /**
     * @notice Computes the fee and net amount for a given gross transfer amount.
     */
    function calculateFee(uint256 grossAmount) external view returns (uint256 fee, uint256 netAmount) {
        fee = (grossAmount * feeBps) / 10_000;
        netAmount = grossAmount - fee;
    }

    /**
     * @notice Returns whether a burn event has already been processed.
     */
    function isBurnEventProcessed(bytes32 burnEventId) external view returns (bool) {
        return processedBurnEvents[burnEventId];
    }

    /**
     * @notice Returns details of a specific bridge operation.
     */
    function getOperation(uint256 operationId)
        external
        view
        returns (
            OperationType opType,
            address user,
            uint256 amount,
            uint256 fee,
            uint256 timestamp,
            bytes32 burnEventId
        )
    {
        BridgeOperation memory op = operations[operationId];
        return (op.opType, op.user, op.amount, op.fee, op.timestamp, op.burnEventId);
    }
}
