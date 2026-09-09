// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract InvestmentPoolManager {
    error NotOperator();
    error ZeroAddress();
    error PoolNotFound();
    error AssetNotAllowed();
    error InsufficientShares();
    error InsufficientPoolBalance();
    error TradeNotFound();
    error TradeAlreadyProcessed();
    error TradeNotApproved();
    error InvalidFee();
    error ZeroAmount();
    error SameToken();
    error SlippageExceeded();
    error TransferFailed();
    error NoAssetsProvided();
    error ReentrantCall();

    uint256 public constant MAX_MANAGEMENT_FEE_BPS = 500;
    uint256 public constant PERFORMANCE_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;

    event PoolCreated(uint256 indexed poolId, address indexed manager, string strategy, uint256 managementFeeBps);
    event Deposit(uint256 indexed poolId, address indexed user, address token, uint256 amount, uint256 shares);
    event Withdrawal(uint256 indexed poolId, address indexed user, address token, uint256 shares, uint256 amount);
    event TradeProposed(uint256 indexed tradeId, uint256 indexed poolId, address proposer, address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut);
    event TradeApproved(uint256 indexed tradeId, uint256 indexed poolId, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 performanceFee);
    event TradeRejected(uint256 indexed tradeId);
    event ManagementFeeSet(uint256 indexed poolId, uint256 feeBps);
    event AllowedAssetAdded(uint256 indexed poolId, address asset);
    event AllowedAssetRemoved(uint256 indexed poolId, address asset);
    event OperatorSet(address indexed newOperator);

    struct Pool {
        address manager;
        string strategy;
        uint256 managementFeeBps;
        uint256 totalShares;
        bool exists;
    }

    struct Trade {
        uint256 poolId;
        address proposer;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        bool approved;
        bool rejected;
        bool executed;
    }

    address public operator;
    uint256 public nextPoolId;
    uint256 public nextTradeId;

    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(address => bool)) public allowedAssets;
    mapping(uint256 => mapping(address => uint256)) public poolBalances;
    mapping(uint256 => mapping(address => uint256)) public userShares;
    mapping(uint256 => Trade) public trades;

    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier poolExists(uint256 poolId) {
        if (!pools[poolId].exists) revert PoolNotFound();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function createPool(
        string calldata _strategy,
        address[] calldata _assets,
        uint256 _managementFeeBps
    ) external returns (uint256 poolId) {
        if (_assets.length == 0) revert NoAssetsProvided();
        if (_managementFeeBps > MAX_MANAGEMENT_FEE_BPS) revert InvalidFee();

        poolId = nextPoolId++;
        Pool storage pool = pools[poolId];
        pool.manager = msg.sender;
        pool.strategy = _strategy;
        pool.managementFeeBps = _managementFeeBps;
        pool.exists = true;

        for (uint256 i = 0; i < _assets.length; i++) {
            address asset = _assets[i];
            if (asset == address(0)) revert ZeroAddress();
            allowedAssets[poolId][asset] = true;
            emit AllowedAssetAdded(poolId, asset);
        }

        emit PoolCreated(poolId, msg.sender, _strategy, _managementFeeBps);
    }

    function setManagementFee(uint256 poolId, uint256 _feeBps) external onlyOperator poolExists(poolId) {
        if (_feeBps > MAX_MANAGEMENT_FEE_BPS) revert InvalidFee();
        pools[poolId].managementFeeBps = _feeBps;
        emit ManagementFeeSet(poolId, _feeBps);
    }

    function addAllowedAsset(uint256 poolId, address asset) external onlyOperator poolExists(poolId) {
        if (asset == address(0)) revert ZeroAddress();
        allowedAssets[poolId][asset] = true;
        emit AllowedAssetAdded(poolId, asset);
    }

    function removeAllowedAsset(uint256 poolId, address asset) external onlyOperator poolExists(poolId) {
        allowedAssets[poolId][asset] = false;
        emit AllowedAssetRemoved(poolId, asset);
    }

    function deposit(uint256 poolId, address token, uint256 amount) external nonReentrant poolExists(poolId) returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();
        if (!allowedAssets[poolId][token]) revert AssetNotAllowed();

        uint256 totalShares = pools[poolId].totalShares;
        uint256 tokenBalance = poolBalances[poolId][token];
        if (totalShares == 0 || tokenBalance == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / tokenBalance;
        }
        if (shares == 0) revert ZeroAmount();

        userShares[poolId][msg.sender] += shares;
        pools[poolId].totalShares += shares;
        poolBalances[poolId][token] += amount;

        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposit(poolId, msg.sender, token, amount, shares);
    }

    function withdraw(uint256 poolId, address token, uint256 shares) external nonReentrant poolExists(poolId) returns (uint256 amount) {
        if (shares == 0) revert ZeroAmount();
        if (!allowedAssets[poolId][token]) revert AssetNotAllowed();
        if (userShares[poolId][msg.sender] < shares) revert InsufficientShares();

        uint256 totalShares = pools[poolId].totalShares;
        uint256 tokenBalance = poolBalances[poolId][token];
        if (totalShares == 0 || tokenBalance == 0) revert InsufficientPoolBalance();

        amount = (shares * tokenBalance) / totalShares;
        if (amount == 0) revert InsufficientPoolBalance();

        userShares[poolId][msg.sender] -= shares;
        pools[poolId].totalShares -= shares;
        poolBalances[poolId][token] -= amount;

        if (!IERC20(token).transfer(msg.sender, amount)) revert TransferFailed();

        emit Withdrawal(poolId, msg.sender, token, shares, amount);
    }

    function proposeTrade(
        uint256 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external poolExists(poolId) returns (uint256 tradeId) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert SameToken();
        if (!allowedAssets[poolId][tokenIn] || !allowedAssets[poolId][tokenOut]) revert AssetNotAllowed();
        if (poolBalances[poolId][tokenIn] < amountIn) revert InsufficientPoolBalance();

        tradeId = nextTradeId++;
        trades[tradeId] = Trade({
            poolId: poolId,
            proposer: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            approved: false,
            rejected: false,
            executed: false
        });

        emit TradeProposed(tradeId, poolId, msg.sender, tokenIn, tokenOut, amountIn, minAmountOut);
    }

    function approveTrade(uint256 tradeId, uint256 amountOut) external nonReentrant onlyOperator {
        Trade storage trade = trades[tradeId];
        if (trade.tokenIn == address(0)) revert TradeNotFound();
        if (trade.executed || trade.approved || trade.rejected) revert TradeAlreadyProcessed();
        if (amountOut < trade.minAmountOut) revert SlippageExceeded();

        uint256 poolId = trade.poolId;
        if (poolBalances[poolId][trade.tokenIn] < trade.amountIn) revert InsufficientPoolBalance();

        uint256 performanceFee = 0;
        if (amountOut > trade.amountIn) {
            uint256 profit = amountOut - trade.amountIn;
            performanceFee = (profit * PERFORMANCE_FEE_BPS) / BPS_DENOMINATOR;
        }
        uint256 amountToPool = amountOut - performanceFee;

        poolBalances[poolId][trade.tokenIn] -= trade.amountIn;
        poolBalances[poolId][trade.tokenOut] += amountToPool;

        trade.approved = true;
        trade.executed = true;

        if (!IERC20(trade.tokenIn).transfer(msg.sender, trade.amountIn)) revert TransferFailed();

        if (!IERC20(trade.tokenOut).transferFrom(msg.sender, address(this), amountOut)) revert TransferFailed();

        if (performanceFee > 0) {
            if (!IERC20(trade.tokenOut).transfer(msg.sender, performanceFee)) revert TransferFailed();
        }

        emit TradeApproved(tradeId, poolId, trade.tokenIn, trade.tokenOut, trade.amountIn, amountOut, performanceFee);
    }

    function rejectTrade(uint256 tradeId) external onlyOperator {
        Trade storage trade = trades[tradeId];
        if (trade.tokenIn == address(0)) revert TradeNotFound();
        if (trade.executed || trade.approved || trade.rejected) revert TradeAlreadyProcessed();

        trade.rejected = true;
        trade.executed = true;
        emit TradeRejected(tradeId);
    }

    function getPool(uint256 poolId) external view returns (
        address manager,
        string memory strategy,
        uint256 managementFeeBps,
        uint256 totalShares,
        bool exists
    ) {
        Pool storage p = pools[poolId];
        return (p.manager, p.strategy, p.managementFeeBps, p.totalShares, p.exists);
    }

    function getTrade(uint256 tradeId) external view returns (Trade memory) {
        return trades[tradeId];
    }

    function isAllowedAsset(uint256 poolId, address asset) external view returns (bool) {
        return allowedAssets[poolId][asset];
    }
}
