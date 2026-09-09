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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract ERC20OneWayBridge {
    using SafeERC20 for IERC20;

    enum BridgeStatus { Pending, Processed, Claimed }

    struct BridgeTransfer {
        address source;
        address destination;
        uint256 grossAmount;
        uint256 netAmount;
        uint256 fee;
        BridgeStatus status;
        uint256 timestamp;
    }

    IERC20 public immutable token;
    address public operator;
    uint256 public feeBasisPoints;

    uint256 public constant MAX_BRIDGE_AMOUNT = 10_000 * 10**18;
    uint256 public constant MAX_FEE_BASIS_POINTS = 1000;

    uint256 private _nonce;
    mapping(bytes32 => BridgeTransfer) public bridgeTransfers;
    mapping(address => uint256) public entitlements;
    uint256 public totalEntitlements;

    event BridgeInitiated(
        bytes32 indexed transferId,
        address indexed source,
        address indexed destination,
        uint256 grossAmount,
        uint256 fee,
        uint256 netAmount
    );
    event BridgeProcessed(bytes32 indexed transferId);
    event BridgeClaimed(bytes32 indexed transferId, address indexed claimant, uint256 amount);
    event FeeUpdated(uint256 oldFeeBasisPoints, uint256 newFeeBasisPoints);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error ExceedsMaxBridgeAmount(uint256 amount, uint256 max);
    error InvalidFeeBasisPoints(uint256 fee, uint256 max);
    error Unauthorized(address caller);
    error TransferNotFound(bytes32 transferId);
    error TransferNotProcessed(bytes32 transferId);
    error TransferAlreadyClaimed(bytes32 transferId);
    error NotEntitled(address caller);
    error InsufficientWithdrawable(uint256 available);

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized(msg.sender);
        _;
    }

    constructor(address token_, address operator_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        operator = operator_;
        feeBasisPoints = 50;
        emit OperatorUpdated(address(0), operator_);
    }

    function bridge(address destination, uint256 amount) external returns (bytes32 transferId) {
        if (destination == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_BRIDGE_AMOUNT) revert ExceedsMaxBridgeAmount(amount, MAX_BRIDGE_AMOUNT);

        uint256 fee = (amount * feeBasisPoints) / 10000;
        uint256 netAmount = amount - fee;

        transferId = keccak256(
            abi.encodePacked(msg.sender, destination, amount, block.timestamp, _nonce)
        );
        _nonce++;

        bridgeTransfers[transferId] = BridgeTransfer({
            source: msg.sender,
            destination: destination,
            grossAmount: amount,
            netAmount: netAmount,
            fee: fee,
            status: BridgeStatus.Pending,
            timestamp: block.timestamp
        });

        entitlements[destination] += netAmount;
        totalEntitlements += netAmount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit BridgeInitiated(transferId, msg.sender, destination, amount, fee, netAmount);
    }

    function processTransfer(bytes32 transferId) external onlyOperator {
        BridgeTransfer storage transfer = bridgeTransfers[transferId];
        if (transfer.source == address(0)) revert TransferNotFound(transferId);
        if (transfer.status != BridgeStatus.Pending) revert TransferNotProcessed(transferId);

        transfer.status = BridgeStatus.Processed;
        emit BridgeProcessed(transferId);
    }

    function claim(bytes32 transferId) external {
        BridgeTransfer storage transfer = bridgeTransfers[transferId];
        if (transfer.source == address(0)) revert TransferNotFound(transferId);
        if (transfer.status == BridgeStatus.Claimed) revert TransferAlreadyClaimed(transferId);
        if (transfer.status != BridgeStatus.Processed) revert TransferNotProcessed(transferId);
        if (msg.sender != transfer.destination) revert NotEntitled(msg.sender);

        transfer.status = BridgeStatus.Claimed;
        uint256 amount = transfer.netAmount;
        entitlements[msg.sender] -= amount;
        totalEntitlements -= amount;

        token.safeTransfer(msg.sender, amount);

        emit BridgeClaimed(transferId, msg.sender, amount);
    }

    function setFee(uint256 newFeeBasisPoints) external onlyOperator {
        if (newFeeBasisPoints > MAX_FEE_BASIS_POINTS) {
            revert InvalidFeeBasisPoints(newFeeBasisPoints, MAX_FEE_BASIS_POINTS);
        }
        uint256 oldFee = feeBasisPoints;
        feeBasisPoints = newFeeBasisPoints;
        emit FeeUpdated(oldFee, newFeeBasisPoints);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function withdrawFees(address to) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = token.balanceOf(address(this));
        if (balance <= totalEntitlements) {
            revert InsufficientWithdrawable(0);
        }
        uint256 withdrawable = balance - totalEntitlements;
        token.safeTransfer(to, withdrawable);
        emit FeesWithdrawn(to, withdrawable);
    }

    function getBridgeTransfer(bytes32 transferId) external view returns (BridgeTransfer memory) {
        return bridgeTransfers[transferId];
    }

    function getEntitlement(address destination) external view returns (uint256) {
        return entitlements[destination];
    }

    function getReserveBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getWithdrawableFees() external view returns (uint256) {
        uint256 balance = token.balanceOf(address(this));
        if (balance <= totalEntitlements) {
            return 0;
        }
        return balance - totalEntitlements;
    }
}
