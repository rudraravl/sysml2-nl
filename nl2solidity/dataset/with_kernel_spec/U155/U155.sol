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
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract CrossChainSwapEscrow is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error AssetNotSupported(address asset);
    error AssetAlreadySupported(address asset);
    error AmountZero();
    error AmountOutOfBounds(uint256 min, uint256 max, uint256 amount);
    error FeeExceedsMaximum(uint256 fee, uint256 maxFee);
    error SwapNotFound(uint256 swapId);
    error NotSwapInitiator(address caller, address initiator);
    error NotOperator();
    error SwapNotPending(uint256 swapId, SwapStatus status);
    error SwapNotCompleted(uint256 swapId, SwapStatus status);
    error SwapAlreadyClaimed(uint256 swapId);
    error SwapNotExpired(uint256 swapId);
    error InvalidConfig();
    error InsufficientEscrowBalance(address asset, uint256 available, uint256 required);
    error NoFeesToWithdraw();

    enum SwapStatus {
        Pending,
        Completed,
        Cancelled,
        Expired
    }

    struct SwapConfig {
        uint64 swapFeeBps;
        uint32 expirySeconds;
        uint128 minSwapAmount;
        uint128 maxSwapAmount;
    }

    struct SwapRequest {
        address initiator;
        address sourceAsset;
        address destinationAsset;
        uint256 sourceChainId;
        uint256 destinationChainId;
        uint256 sourceAmount;
        uint256 feeAmount;
        uint256 initiatedAt;
        uint256 finalizedAt;
        SwapStatus status;
        bool claimed;
    }

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 50;
    uint256 public constant DEFAULT_EXPIRY = 24 hours;

    SwapConfig public config;
    address public operator;
    uint256 public nextSwapId;

    mapping(address => bool) public supportedAssets;
    mapping(address => uint256) public assetBalances;
    mapping(address => uint256) public feeBalances;
    mapping(uint256 => SwapRequest) public swaps;

    event AssetRegistered(address indexed asset);
    event AssetRemoved(address indexed asset);
    event SwapConfigUpdated(uint64 swapFeeBps, uint32 expirySeconds, uint128 minSwapAmount, uint128 maxSwapAmount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event SwapInitiated(
        uint256 indexed swapId,
        address indexed initiator,
        address sourceAsset,
        address destinationAsset,
        uint256 sourceChainId,
        uint256 destinationChainId,
        uint256 sourceAmount,
        uint256 feeAmount
    );
    event SwapCompleted(
        uint256 indexed swapId,
        address indexed initiator,
        address destinationAsset,
        uint256 destinationChainId
    );
    event SwapClaimed(
        uint256 indexed swapId,
        address indexed claimant,
        address asset,
        uint256 netAmount,
        uint256 feeAmount
    );
    event SwapCancelled(
        uint256 indexed swapId,
        address indexed initiator,
        address sourceAsset,
        uint256 refundAmount
    );
    event SwapExpired(
        uint256 indexed swapId,
        address indexed initiator,
        address sourceAsset,
        uint256 refundAmount
    );
    event FeesWithdrawn(address indexed token, address indexed recipient, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert NotOperator();
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!supportedAssets[asset]) revert AssetNotSupported(asset);
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        config = SwapConfig({
            swapFeeBps: 30,
            expirySeconds: uint32(DEFAULT_EXPIRY),
            minSwapAmount: 1e6,
            maxSwapAmount: 1_000_000e18
        });
        nextSwapId = 1;
        emit OperatorUpdated(address(0), _operator);
        emit SwapConfigUpdated(config.swapFeeBps, config.expirySeconds, config.minSwapAmount, config.maxSwapAmount);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function registerAsset(address asset) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (supportedAssets[asset]) revert AssetAlreadySupported(asset);
        supportedAssets[asset] = true;
        emit AssetRegistered(asset);
    }

    function removeAsset(address asset) external onlyOperator {
        if (!supportedAssets[asset]) revert AssetNotSupported(asset);
        if (assetBalances[asset] > 0) revert InsufficientEscrowBalance(asset, 0, assetBalances[asset]);
        supportedAssets[asset] = false;
        emit AssetRemoved(asset);
    }

    function updateSwapConfig(
        uint64 _swapFeeBps,
        uint32 _expirySeconds,
        uint128 _minSwapAmount,
        uint128 _maxSwapAmount
    ) external onlyOperator {
        if (_swapFeeBps > MAX_FEE_BPS) revert FeeExceedsMaximum(_swapFeeBps, MAX_FEE_BPS);
        if (_minSwapAmount >= _maxSwapAmount) revert InvalidConfig();
        if (_expirySeconds == 0) revert InvalidConfig();
        config.swapFeeBps = _swapFeeBps;
        config.expirySeconds = _expirySeconds;
        config.minSwapAmount = _minSwapAmount;
        config.maxSwapAmount = _maxSwapAmount;
        emit SwapConfigUpdated(_swapFeeBps, _expirySeconds, _minSwapAmount, _maxSwapAmount);
    }

    function initiateSwap(
        address sourceAsset,
        address destinationAsset,
        uint256 destinationChainId,
        uint256 sourceAmount
    ) external nonReentrant onlySupportedAsset(sourceAsset) returns (uint256 swapId) {
        if (sourceAmount == 0) revert AmountZero();
        if (sourceAmount < config.minSwapAmount || sourceAmount > config.maxSwapAmount) {
            revert AmountOutOfBounds(config.minSwapAmount, config.maxSwapAmount, sourceAmount);
        }

        uint256 feeAmount = (sourceAmount * config.swapFeeBps) / BPS_DENOMINATOR;

        swapId = nextSwapId++;
        swaps[swapId] = SwapRequest({
            initiator: msg.sender,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            sourceChainId: block.chainid,
            destinationChainId: destinationChainId,
            sourceAmount: sourceAmount,
            feeAmount: feeAmount,
            initiatedAt: block.timestamp,
            finalizedAt: 0,
            status: SwapStatus.Pending,
            claimed: false
        });

        assetBalances[sourceAsset] += sourceAmount;
        IERC20(sourceAsset).safeTransferFrom(msg.sender, address(this), sourceAmount);

        emit SwapInitiated(
            swapId,
            msg.sender,
            sourceAsset,
            destinationAsset,
            block.chainid,
            destinationChainId,
            sourceAmount,
            feeAmount
        );
    }

    function finalizeSwap(uint256 swapId) external onlyOperator nonReentrant {
        SwapRequest storage req = swaps[swapId];
        if (req.initiator == address(0)) revert SwapNotFound(swapId);
        if (req.status != SwapStatus.Pending) revert SwapNotPending(swapId, req.status);
        if (block.timestamp > req.initiatedAt + config.expirySeconds) {
            _expireSwap(swapId);
            return;
        }

        req.status = SwapStatus.Completed;
        req.finalizedAt = block.timestamp;

        emit SwapCompleted(swapId, req.initiator, req.destinationAsset, req.destinationChainId);
    }

    function claimSwap(uint256 swapId) external nonReentrant {
        SwapRequest storage req = swaps[swapId];
        if (req.initiator == address(0)) revert SwapNotFound(swapId);
        if (req.status != SwapStatus.Completed) revert SwapNotCompleted(swapId, req.status);
        if (req.claimed) revert SwapAlreadyClaimed(swapId);

        req.claimed = true;

        address sourceAsset = req.sourceAsset;
        uint256 feeAmount = req.feeAmount;
        uint256 netAmount = req.sourceAmount - feeAmount;

        assetBalances[sourceAsset] -= req.sourceAmount;
        feeBalances[sourceAsset] += feeAmount;

        IERC20(sourceAsset).safeTransfer(req.initiator, netAmount);

        emit SwapClaimed(swapId, req.initiator, sourceAsset, netAmount, feeAmount);
    }

    function cancelSwap(uint256 swapId) external nonReentrant {
        SwapRequest storage req = swaps[swapId];
        if (req.initiator == address(0)) revert SwapNotFound(swapId);
        if (req.status != SwapStatus.Pending) revert SwapNotPending(swapId, req.status);
        if (msg.sender != req.initiator) revert NotSwapInitiator(msg.sender, req.initiator);

        req.status = SwapStatus.Cancelled;
        address sourceAsset = req.sourceAsset;
        uint256 refundAmount = req.sourceAmount;

        assetBalances[sourceAsset] -= refundAmount;
        IERC20(sourceAsset).safeTransfer(req.initiator, refundAmount);

        emit SwapCancelled(swapId, req.initiator, sourceAsset, refundAmount);
    }

    function expireSwap(uint256 swapId) external nonReentrant {
        SwapRequest storage req = swaps[swapId];
        if (req.initiator == address(0)) revert SwapNotFound(swapId);
        if (req.status != SwapStatus.Pending) revert SwapNotPending(swapId, req.status);
        if (block.timestamp <= req.initiatedAt + config.expirySeconds) {
            revert SwapNotExpired(swapId);
        }
        _expireSwap(swapId);
    }

    function _expireSwap(uint256 swapId) internal {
        SwapRequest storage req = swaps[swapId];
        req.status = SwapStatus.Expired;

        address sourceAsset = req.sourceAsset;
        uint256 refundAmount = req.sourceAmount;

        assetBalances[sourceAsset] -= refundAmount;
        IERC20(sourceAsset).safeTransfer(req.initiator, refundAmount);

        emit SwapExpired(swapId, req.initiator, sourceAsset, refundAmount);
    }

    function withdrawFees(address token, address recipient) external onlyOperator nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = feeBalances[token];
        if (amount == 0) revert NoFeesToWithdraw();

        feeBalances[token] = 0;
        IERC20(token).safeTransfer(recipient, amount);
        emit FeesWithdrawn(token, recipient, amount);
    }

    function getSwap(uint256 swapId) external view returns (SwapRequest memory) {
        return swaps[swapId];
    }

    function isSwapExpired(uint256 swapId) external view returns (bool) {
        SwapRequest storage req = swaps[swapId];
        return req.status == SwapStatus.Pending && block.timestamp > req.initiatedAt + config.expirySeconds;
    }

    function isAssetSupported(address asset) external view returns (bool) {
        return supportedAssets[asset];
    }

    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * config.swapFeeBps) / BPS_DENOMINATOR;
    }
}
