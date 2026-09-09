// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

error Unauthorized();
error ZeroAddress();
error AssetAlreadySupported();
error AssetNotSupported();
error AssetPaused();
error FeeExceedsMaximum();
error AmountBelowMinimum();
error InsufficientWrappedBalance();
error InvalidAmount();
error EmptyTargetRecipient();
error TransferFailed();

contract CrossChainBridgeVault {
    uint16 public constant MAX_FEE_BPS = 50;
    uint256 private constant BPS_DENOMINATOR = 10000;

    address public operator;

    struct AssetConfig {
        bool isSupported;
        bool paused;
        uint16 feeBps;
        uint8 decimals;
        uint256 totalWrapped;
    }

    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => mapping(address => uint256)) public wrappedBalances;
    address[] public supportedAssets;

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event AssetAdded(address indexed asset, uint8 decimals, uint16 feeBps);
    event AssetPaused(address indexed asset, bool paused);
    event FeeUpdated(address indexed asset, uint16 oldFeeBps, uint16 newFeeBps);
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Redemption(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        uint256 netAmount,
        bytes targetChainRecipient
    );

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function addAsset(address asset, uint8 decimals_, uint16 feeBps) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        if (assetConfigs[asset].isSupported) revert AssetAlreadySupported();
        if (feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();

        assetConfigs[asset] = AssetConfig({
            isSupported: true,
            paused: false,
            feeBps: feeBps,
            decimals: decimals_,
            totalWrapped: 0
        });
        supportedAssets.push(asset);

        emit AssetAdded(asset, decimals_, feeBps);
    }

    function setBridgingFee(address asset, uint16 newFeeBps) external onlyOperator {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isSupported) revert AssetNotSupported();
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMaximum();

        uint16 oldFeeBps = cfg.feeBps;
        cfg.feeBps = newFeeBps;
        emit FeeUpdated(asset, oldFeeBps, newFeeBps);
    }

    function setPaused(address asset, bool paused_) external onlyOperator {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isSupported) revert AssetNotSupported();
        cfg.paused = paused_;
        emit AssetPaused(asset, paused_);
    }

    function deposit(address asset, uint256 amount) external {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isSupported) revert AssetNotSupported();
        if (cfg.paused) revert AssetPaused();
        if (amount == 0) revert InvalidAmount();

        wrappedBalances[msg.sender][asset] += amount;
        cfg.totalWrapped += amount;

        _safeTransferFrom(IERC20(asset), msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount);
    }

    function redeem(address asset, uint256 amount, bytes calldata targetChainRecipient) external {
        AssetConfig storage cfg = assetConfigs[asset];
        if (!cfg.isSupported) revert AssetNotSupported();
        if (cfg.paused) revert AssetPaused();
        if (targetChainRecipient.length == 0) revert EmptyTargetRecipient();

        uint256 minAmount = (10 ** uint256(cfg.decimals)) / 1000;
        if (minAmount == 0) {
            minAmount = 1;
        }
        if (amount < minAmount) revert AmountBelowMinimum();

        uint256 available = wrappedBalances[msg.sender][asset];
        if (available < amount) revert InsufficientWrappedBalance();

        uint256 fee = (amount * uint256(cfg.feeBps)) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        wrappedBalances[msg.sender][asset] = available - amount;
        cfg.totalWrapped -= amount;

        emit Redemption(msg.sender, asset, amount, fee, netAmount, targetChainRecipient);
    }

    function balanceOf(address user, address asset) external view returns (uint256) {
        return wrappedBalances[user][asset];
    }

    function supportedAssetsCount() external view returns (uint256) {
        return supportedAssets.length;
    }

    function isAssetSupported(address asset) external view returns (bool) {
        return assetConfigs[asset].isSupported;
    }

    function getAssetConfig(address asset)
        external
        view
        returns (
            bool isSupported,
            bool paused,
            uint16 feeBps,
            uint8 decimals,
            uint256 totalWrapped
        )
    {
        AssetConfig storage cfg = assetConfigs[asset];
        return (cfg.isSupported, cfg.paused, cfg.feeBps, cfg.decimals, cfg.totalWrapped);
    }

    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }
}
