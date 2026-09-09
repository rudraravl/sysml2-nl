// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddressOwner();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddressOwner();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddressOwner();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}

contract SyntheticAssetPlatform is Ownable, ReentrancyGuard {
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotSupported();
    error AssetPaused();
    error InsufficientCollateral();
    error InsufficientBalance();
    error InvalidCollateralizationRatio();
    error InvalidTradingFee();
    error SameAsset();
    error NotOperator();
    error TransferFailed();

    uint256 public constant MIN_COLLATERALIZATION_RATIO = 15000;
    uint256 public constant MAX_TRADING_FEE_BPS = 1000;
    uint256 public constant DEFAULT_TRADING_FEE_BPS = 20;
    uint256 public constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable collateralToken;
    address public operator;

    struct AssetConfig {
        bool supported;
        bool paused;
        uint256 collateralizationRatio;
        uint256 tradingFeeBps;
        uint256 totalSyntheticSupply;
    }

    struct Position {
        uint256 collateral;
        uint256 minted;
    }

    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => mapping(address => Position)) public positions;

    event CollateralDeposited(address indexed user, address indexed asset, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed asset, uint256 amount);
    event SyntheticMinted(address indexed user, address indexed asset, uint256 amount);
    event SyntheticBurned(address indexed user, address indexed asset, uint256 amount, uint256 collateralReleased);
    event SyntheticTraded(
        address indexed user,
        address indexed fromAsset,
        address indexed toAsset,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event AssetConfigured(address indexed asset, uint256 collateralizationRatio, uint256 tradingFeeBps);
    event AssetCollateralizationRatioUpdated(address indexed asset, uint256 newRatio);
    event AssetTradingFeeUpdated(address indexed asset, uint256 newFeeBps);
    event AssetPausedChanged(address indexed asset, bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier assetSupported(address asset) {
        if (!assetConfigs[asset].supported) revert AssetNotSupported();
        _;
    }

    modifier assetNotPaused(address asset) {
        if (assetConfigs[asset].paused) revert AssetPaused();
        _;
    }

    constructor(address _collateralToken, address _operator) Ownable(msg.sender) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = _newOperator;
        emit OperatorChanged(prev, _newOperator);
    }

    function configureAsset(address _asset, uint256 _collateralizationRatio) external onlyOperator {
        if (_asset == address(0)) revert ZeroAddress();
        if (_collateralizationRatio < MIN_COLLATERALIZATION_RATIO) revert InvalidCollateralizationRatio();
        assetConfigs[_asset] = AssetConfig({
            supported: true,
            paused: false,
            collateralizationRatio: _collateralizationRatio,
            tradingFeeBps: DEFAULT_TRADING_FEE_BPS,
            totalSyntheticSupply: 0
        });
        emit AssetConfigured(_asset, _collateralizationRatio, DEFAULT_TRADING_FEE_BPS);
    }

    function setCollateralizationRatio(address _asset, uint256 _newRatio)
        external
        onlyOperator
        assetSupported(_asset)
    {
        if (_newRatio < MIN_COLLATERALIZATION_RATIO) revert InvalidCollateralizationRatio();
        assetConfigs[_asset].collateralizationRatio = _newRatio;
        emit AssetCollateralizationRatioUpdated(_asset, _newRatio);
    }

    function setTradingFee(address _asset, uint256 _newFeeBps)
        external
        onlyOperator
        assetSupported(_asset)
    {
        if (_newFeeBps > MAX_TRADING_FEE_BPS) revert InvalidTradingFee();
        assetConfigs[_asset].tradingFeeBps = _newFeeBps;
        emit AssetTradingFeeUpdated(_asset, _newFeeBps);
    }

    function setAssetPaused(address _asset, bool _paused)
        external
        onlyOperator
        assetSupported(_asset)
    {
        assetConfigs[_asset].paused = _paused;
        emit AssetPausedChanged(_asset, _paused);
    }

    function depositCollateral(address _asset, uint256 _amount)
        external
        nonReentrant
        assetSupported(_asset)
        assetNotPaused(_asset)
    {
        if (_amount == 0) revert ZeroAmount();
        positions[msg.sender][_asset].collateral += _amount;
        bool success = collateralToken.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert TransferFailed();
        emit CollateralDeposited(msg.sender, _asset, _amount);
    }

    function withdrawCollateral(address _asset, uint256 _amount)
        external
        nonReentrant
        assetSupported(_asset)
    {
        if (_amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender][_asset];
        if (pos.collateral < _amount) revert InsufficientBalance();
        pos.collateral -= _amount;
        if (pos.minted > 0) {
            _checkCollateralization(_asset, pos);
        }
        bool success = collateralToken.transfer(msg.sender, _amount);
        if (!success) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, _asset, _amount);
    }

    function mintSynthetic(address _asset, uint256 _amount)
        external
        nonReentrant
        assetSupported(_asset)
        assetNotPaused(_asset)
    {
        if (_amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender][_asset];
        pos.minted += _amount;
        assetConfigs[_asset].totalSyntheticSupply += _amount;
        _checkCollateralization(_asset, pos);
        emit SyntheticMinted(msg.sender, _asset, _amount);
    }

    function burnSynthetic(address _asset, uint256 _amount)
        external
        nonReentrant
        assetSupported(_asset)
    {
        if (_amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender][_asset];
        if (pos.minted < _amount) revert InsufficientBalance();

        pos.minted -= _amount;
        assetConfigs[_asset].totalSyntheticSupply -= _amount;

        uint256 collateralReleased = (_amount * assetConfigs[_asset].collateralizationRatio) / BPS_DENOMINATOR;
        if (collateralReleased > pos.collateral) {
            collateralReleased = pos.collateral;
        }
        pos.collateral -= collateralReleased;

        bool success = collateralToken.transfer(msg.sender, collateralReleased);
        if (!success) revert TransferFailed();

        emit SyntheticBurned(msg.sender, _asset, _amount, collateralReleased);
    }

    function tradeSynthetic(
        address _fromAsset,
        address _toAsset,
        uint256 _amountIn
    )
        external
        nonReentrant
        assetSupported(_fromAsset)
        assetSupported(_toAsset)
        assetNotPaused(_fromAsset)
        assetNotPaused(_toAsset)
    {
        if (_amountIn == 0) revert ZeroAmount();
        if (_fromAsset == _toAsset) revert SameAsset();

        Position storage fromPos = positions[msg.sender][_fromAsset];
        Position storage toPos = positions[msg.sender][_toAsset];
        if (fromPos.minted < _amountIn) revert InsufficientBalance();

        AssetConfig storage fromConfig = assetConfigs[_fromAsset];
        AssetConfig storage toConfig = assetConfigs[_toAsset];

        uint256 fee = (_amountIn * toConfig.tradingFeeBps) / BPS_DENOMINATOR;
        uint256 amountOut = _amountIn - fee;
        if (amountOut == 0) revert ZeroAmount();

        uint256 collateralToMove = (_amountIn * fromConfig.collateralizationRatio) / BPS_DENOMINATOR;
        if (collateralToMove > fromPos.collateral) {
            collateralToMove = fromPos.collateral;
        }

        fromPos.minted -= _amountIn;
        fromPos.collateral -= collateralToMove;
        fromConfig.totalSyntheticSupply -= _amountIn;

        toPos.minted += amountOut;
        toPos.collateral += collateralToMove;
        toConfig.totalSyntheticSupply += amountOut;

        _checkCollateralization(_toAsset, toPos);

        emit SyntheticTraded(msg.sender, _fromAsset, _toAsset, _amountIn, amountOut, fee);
    }

    function _checkCollateralization(address _asset, Position storage _pos) internal view {
        if (_pos.minted == 0) return;
        AssetConfig storage cfg = assetConfigs[_asset];
        uint256 requiredCollateral = (_pos.minted * cfg.collateralizationRatio) / BPS_DENOMINATOR;
        if (_pos.collateral < requiredCollateral) revert InsufficientCollateral();
    }

    function getPosition(address _user, address _asset)
        external
        view
        returns (uint256 collateral, uint256 minted)
    {
        Position storage pos = positions[_user][_asset];
        return (pos.collateral, pos.minted);
    }

    function getAssetConfig(address _asset)
        external
        view
        returns (
            bool supported,
            bool paused,
            uint256 collateralizationRatio,
            uint256 tradingFeeBps,
            uint256 totalSyntheticSupply
        )
    {
        AssetConfig storage cfg = assetConfigs[_asset];
        return (
            cfg.supported,
            cfg.paused,
            cfg.collateralizationRatio,
            cfg.tradingFeeBps,
            cfg.totalSyntheticSupply
        );
    }

    function requiredCollateralForMint(address _asset, uint256 _amount)
        external
        view
        assetSupported(_asset)
        returns (uint256)
    {
        return (_amount * assetConfigs[_asset].collateralizationRatio) / BPS_DENOMINATOR;
    }

    function isPositionCollateralized(address _user, address _asset) external view returns (bool) {
        Position storage pos = positions[_user][_asset];
        if (pos.minted == 0) return true;
        uint256 required = (pos.minted * assetConfigs[_asset].collateralizationRatio) / BPS_DENOMINATOR;
        return pos.collateral >= required;
    }
}
