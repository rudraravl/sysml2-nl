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

interface IYieldStrategy {
    function deploy(address asset, uint256 amount) external returns (uint256 shares);
    function withdraw(address asset, uint256 shares) external returns (uint256 amountReturned);
    function estimatedValue(address asset, uint256 shares) external view returns (uint256);
}

contract YieldAggregator {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error AssetNotSupported();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error MaxStrategiesReached();
    error InsufficientBalance();
    error InvalidPosition();
    error PositionNotActive();
    error FeeTooHigh();
    error WhenPaused();
    error WhenNotPaused();
    error TransferFailed();
    error Reentrancy();

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_STRATEGIES = 10;
    uint256 public constant FEE_PRECISION = 10_000; // basis points
    uint256 public constant MAX_FEE_BPS = 5_000; // 50% cap
    uint256 public constant DEFAULT_FEE_BPS = 10; // 0.1%

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public operator;
    address public feeRecipient;
    uint256 public feeBps;
    bool public paused;

    mapping(address => bool) public supportedAssets;
    mapping(address => bool) public approvedStrategies;
    address[] public strategyList;

    mapping(address => mapping(address => uint256)) public userBalances;

    struct Position {
        address user;
        address asset;
        address strategy;
        uint256 principal;
        uint256 shares;
        bool active;
    }

    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId;

    mapping(address => uint256) public totalFeesCollected;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event PositionOpened(
        address indexed user,
        uint256 indexed positionId,
        address indexed strategy,
        address asset,
        uint256 amount,
        uint256 shares
    );
    event PositionClosed(
        address indexed user,
        uint256 indexed positionId,
        address indexed strategy,
        address asset,
        uint256 principal,
        uint256 returned,
        uint256 profit,
        uint256 fee
    );
    event StrategyApproved(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event AssetSupported(address indexed asset, bool supported);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesCollected(address indexed asset, uint256 amount);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier notPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!supportedAssets[asset]) revert AssetNotSupported();
        _;
    }

    modifier onlyApprovedStrategy(address strategy) {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        feeBps = DEFAULT_FEE_BPS;
        _status = _NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Internal transfer helpers
    // ---------------------------------------------------------------------
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------
    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setFeeBps(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function setAssetSupport(address asset, bool supported) external onlyOperator {
        if (asset == address(0)) revert ZeroAddress();
        supportedAssets[asset] = supported;
        emit AssetSupported(asset, supported);
    }

    function approveStrategy(address strategy) external onlyOperator {
        if (strategy == address(0)) revert ZeroAddress();
        if (approvedStrategies[strategy]) revert StrategyAlreadyApproved();
        if (strategyList.length >= MAX_STRATEGIES) revert MaxStrategiesReached();
        approvedStrategies[strategy] = true;
        strategyList.push(strategy);
        emit StrategyApproved(strategy);
    }

    function removeStrategy(address strategy) external onlyOperator {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        approvedStrategies[strategy] = false;
        uint256 len = strategyList.length;
        for (uint256 i = 0; i < len; i++) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[len - 1];
                strategyList.pop();
                break;
            }
        }
        emit StrategyRemoved(strategy);
    }

    function pause() external onlyOperator {
        if (paused) revert WhenPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        if (!paused) revert WhenNotPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ---------------------------------------------------------------------
    // User functions
    // ---------------------------------------------------------------------
    function deposit(address asset, uint256 amount)
        external
        notPaused
        onlySupportedAsset(asset)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        _safeTransferFrom(asset, msg.sender, address(this), amount);
        userBalances[msg.sender][asset] += amount;
        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount)
        external
        notPaused
        onlySupportedAsset(asset)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = userBalances[msg.sender][asset];
        if (bal < amount) revert InsufficientBalance();
        userBalances[msg.sender][asset] = bal - amount;
        _safeTransfer(asset, msg.sender, amount);
        emit Withdraw(msg.sender, asset, amount);
    }

    function openPosition(address strategy, address asset, uint256 amount)
        external
        notPaused
        onlySupportedAsset(asset)
        onlyApprovedStrategy(strategy)
        nonReentrant
        returns (uint256 positionId)
    {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = userBalances[msg.sender][asset];
        if (bal < amount) revert InsufficientBalance();

        userBalances[msg.sender][asset] = bal - amount;

        _safeApprove(asset, strategy, amount);
        uint256 shares = IYieldStrategy(strategy).deploy(asset, amount);
        if (shares == 0) revert ZeroAmount();

        positionId = nextPositionId++;
        positions[positionId] = Position({
            user: msg.sender,
            asset: asset,
            strategy: strategy,
            principal: amount,
            shares: shares,
            active: true
        });

        emit PositionOpened(msg.sender, positionId, strategy, asset, amount, shares);
    }

    function closePosition(uint256 positionId)
        external
        notPaused
        nonReentrant
        returns (uint256 returned)
    {
        Position storage p = positions[positionId];
        if (p.user == address(0)) revert InvalidPosition();
        if (!p.active) revert PositionNotActive();
        if (p.user != msg.sender) revert InvalidPosition();

        address asset = p.asset;
        address strategy = p.strategy;
        uint256 principal = p.principal;
        uint256 shares = p.shares;

        // Effects: mark position inactive before external interaction
        p.active = false;

        // Interaction: withdraw from strategy
        returned = IYieldStrategy(strategy).withdraw(asset, shares);

        uint256 profit = 0;
        uint256 fee = 0;
        if (returned > principal) {
            profit = returned - principal;
            fee = (profit * feeBps) / FEE_PRECISION;
        }

        uint256 netToUser = returned - fee;

        if (fee > 0) {
            totalFeesCollected[asset] += fee;
            _safeTransfer(asset, feeRecipient, fee);
            emit FeesCollected(asset, fee);
        }

        userBalances[msg.sender][asset] += netToUser;

        emit PositionClosed(
            msg.sender,
            positionId,
            strategy,
            asset,
            principal,
            returned,
            profit,
            fee
        );
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------
    function getStrategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    function getStrategies() external view returns (address[] memory) {
        return strategyList;
    }

    function getPosition(uint256 positionId)
        external
        view
        returns (
            address user,
            address asset,
            address strategy,
            uint256 principal,
            uint256 shares,
            bool active
        )
    {
        Position storage p = positions[positionId];
        return (p.user, p.asset, p.strategy, p.principal, p.shares, p.active);
    }

    function getPositionValue(uint256 positionId)
        external
        view
        returns (uint256)
    {
        Position storage p = positions[positionId];
        if (!p.active) return 0;
        return IYieldStrategy(p.strategy).estimatedValue(p.asset, p.shares);
    }

    function totalValueOf(address user, address asset) external view returns (uint256) {
        uint256 total = userBalances[user][asset];
        for (uint256 i = 0; i < nextPositionId; i++) {
            Position storage p = positions[i];
            if (p.active && p.user == user && p.asset == asset) {
                total += IYieldStrategy(p.strategy).estimatedValue(asset, p.shares);
            }
        }
        return total;
    }
}
