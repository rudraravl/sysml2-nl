// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IDEXAdapter {
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata data
    ) external returns (uint256 amountOut);
}

contract AlgorithmicTradingManager {
    error NotOperator();
    error StrategyNotFound();
    error StrategyIsPaused();
    error StrategyNotPaused();
    error ZeroAddress();
    error ZeroAmount();
    error ExceedsMaxSlippage();
    error InsufficientShares();
    error InsufficientStrategyCapital();
    error InvalidSlippage();
    error SameTokens();
    error UnauthorizedTrade();

    uint256 public constant MAX_SLIPPAGE_BPS = 50;
    uint256 public constant WITHDRAWAL_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PRECISION = 1e18;

    event StrategyCreated(
        uint256 indexed strategyId,
        address indexed tokenIn,
        address indexed tokenOut,
        address dexAdapter,
        uint256 maxSlippageBps,
        string metadata
    );

    event StrategyUpdated(
        uint256 indexed strategyId,
        address dexAdapter,
        uint256 maxSlippageBps,
        bool paused,
        string metadata
    );

    event StrategyPaused(uint256 indexed strategyId, bool paused);

    event TradeExecuted(
        uint256 indexed strategyId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 minAmountOut,
        uint256 timestamp
    );

    event Deposited(
        uint256 indexed strategyId,
        address indexed depositor,
        uint256 amount,
        uint256 sharesMinted
    );

    event Withdrawn(
        uint256 indexed strategyId,
        address indexed withdrawer,
        uint256 sharesBurned,
        uint256 amountReturned,
        uint256 feeTaken
    );

    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    struct Strategy {
        address tokenIn;
        address tokenOut;
        address dexAdapter;
        uint256 maxSlippageBps;
        bool paused;
        uint256 totalCapital;
        uint256 totalShares;
        uint256 totalTrades;
        uint256 totalVolumeIn;
        uint256 totalVolumeOut;
        uint256 realizedPnl;
        string metadata;
    }

    struct UserPosition {
        uint256 shares;
        uint256 depositedAmount;
    }

    struct StrategyView {
        address tokenIn;
        address tokenOut;
        address dexAdapter;
        uint256 maxSlippageBps;
        bool paused;
        uint256 totalCapital;
        uint256 totalShares;
        uint256 totalTrades;
        uint256 totalVolumeIn;
        uint256 totalVolumeOut;
        uint256 realizedPnl;
        string metadata;
    }

    address public operator;
    address public feeRecipient;
    address public collateralToken;

    uint256 public nextStrategyId;
    mapping(uint256 => Strategy) public strategies;
    mapping(uint256 => mapping(address => UserPosition)) public userPositions;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier strategyExists(uint256 strategyId) {
        if (strategies[strategyId].tokenIn == address(0)) revert StrategyNotFound();
        _;
    }

    modifier notPaused(uint256 strategyId) {
        if (strategies[strategyId].paused) revert StrategyIsPaused();
        _;
    }

    constructor(address _collateralToken, address _operator, address _feeRecipient) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        collateralToken = _collateralToken;
        operator = _operator;
        feeRecipient = _feeRecipient;
        nextStrategyId = 1;

        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

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

    function createStrategy(
        address tokenIn,
        address tokenOut,
        address dexAdapter,
        uint256 maxSlippageBps,
        string calldata metadata
    ) external onlyOperator returns (uint256 strategyId) {
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();
        if (dexAdapter == address(0)) revert ZeroAddress();
        if (tokenIn == tokenOut) revert SameTokens();
        if (maxSlippageBps > MAX_SLIPPAGE_BPS) revert ExceedsMaxSlippage();

        strategyId = nextStrategyId++;
        Strategy storage s = strategies[strategyId];
        s.tokenIn = tokenIn;
        s.tokenOut = tokenOut;
        s.dexAdapter = dexAdapter;
        s.maxSlippageBps = maxSlippageBps;
        s.paused = false;
        s.metadata = metadata;

        emit StrategyCreated(strategyId, tokenIn, tokenOut, dexAdapter, maxSlippageBps, metadata);
    }

    function updateStrategy(
        uint256 strategyId,
        address dexAdapter,
        uint256 maxSlippageBps,
        string calldata metadata
    ) external onlyOperator strategyExists(strategyId) {
        if (dexAdapter == address(0)) revert ZeroAddress();
        if (maxSlippageBps > MAX_SLIPPAGE_BPS) revert ExceedsMaxSlippage();

        Strategy storage s = strategies[strategyId];
        s.dexAdapter = dexAdapter;
        s.maxSlippageBps = maxSlippageBps;
        s.metadata = metadata;

        emit StrategyUpdated(strategyId, dexAdapter, maxSlippageBps, s.paused, metadata);
    }

    function setStrategyPaused(uint256 strategyId, bool paused) external onlyOperator strategyExists(strategyId) {
        Strategy storage s = strategies[strategyId];
        if (paused && s.paused) revert StrategyIsPaused();
        if (!paused && !s.paused) revert StrategyNotPaused();
        s.paused = paused;
        emit StrategyPaused(strategyId, paused);
        emit StrategyUpdated(strategyId, s.dexAdapter, s.maxSlippageBps, s.paused, s.metadata);
    }

    function deposit(uint256 strategyId, uint256 amount)
        external
        strategyExists(strategyId)
        notPaused(strategyId)
        returns (uint256 sharesMinted)
    {
        if (amount == 0) revert ZeroAmount();

        Strategy storage s = strategies[strategyId];
        UserPosition storage pos = userPositions[strategyId][msg.sender];

        bool ok = IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        require(ok, "TransferFrom failed");

        if (s.totalShares == 0 || s.totalCapital == 0) {
            sharesMinted = amount * PRECISION;
        } else {
            sharesMinted = (amount * s.totalShares) / s.totalCapital;
        }
        if (sharesMinted == 0) revert ZeroAmount();

        s.totalCapital += amount;
        s.totalShares += sharesMinted;
        pos.shares += sharesMinted;
        pos.depositedAmount += amount;

        emit Deposited(strategyId, msg.sender, amount, sharesMinted);
    }

    function withdraw(uint256 strategyId, uint256 sharesToBurn)
        external
        strategyExists(strategyId)
        returns (uint256 amountReturned, uint256 feeTaken)
    {
        if (sharesToBurn == 0) revert ZeroAmount();

        Strategy storage s = strategies[strategyId];
        UserPosition storage pos = userPositions[strategyId][msg.sender];

        if (pos.shares < sharesToBurn) revert InsufficientShares();

        uint256 grossAmount = (sharesToBurn * s.totalCapital) / s.totalShares;
        if (grossAmount == 0) revert ZeroAmount();
        if (grossAmount > s.totalCapital) revert InsufficientStrategyCapital();

        feeTaken = (grossAmount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        amountReturned = grossAmount - feeTaken;

        s.totalCapital -= grossAmount;
        s.totalShares -= sharesToBurn;
        pos.shares -= sharesToBurn;
        pos.depositedAmount = pos.depositedAmount > grossAmount ? pos.depositedAmount - grossAmount : 0;

        if (amountReturned > 0) {
            bool ok = IERC20(collateralToken).transfer(msg.sender, amountReturned);
            require(ok, "Transfer failed");
        }
        if (feeTaken > 0) {
            bool okFee = IERC20(collateralToken).transfer(feeRecipient, feeTaken);
            require(okFee, "Fee transfer failed");
        }

        emit Withdrawn(strategyId, msg.sender, sharesToBurn, amountReturned, feeTaken);
    }

    function executeTrade(
        uint256 strategyId,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata tradeData
    ) external onlyOperator strategyExists(strategyId) notPaused(strategyId) returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();

        Strategy storage s = strategies[strategyId];
        if (amountIn > s.totalCapital) revert InsufficientStrategyCapital();

        uint256 spotPrice = amountIn;
        uint256 maxSlippage = s.maxSlippageBps;
        if (maxSlippage > MAX_SLIPPAGE_BPS) maxSlippage = MAX_SLIPPAGE_BPS;

        uint256 minAllowedOut = (spotPrice * (BPS_DENOMINATOR - maxSlippage)) / BPS_DENOMINATOR;
        if (minAmountOut < minAllowedOut) revert ExceedsMaxSlippage();

        bool okIn = IERC20(s.tokenIn).approve(s.dexAdapter, amountIn);
        require(okIn, "Approve failed");

        uint256 balanceBefore = IERC20(s.tokenOut).balanceOf(address(this));
        amountOut = IDEXAdapter(s.dexAdapter).swap(s.tokenIn, s.tokenOut, amountIn, minAmountOut, tradeData);
        uint256 balanceAfter = IERC20(s.tokenOut).balanceOf(address(this));

        if (balanceAfter <= balanceBefore) revert UnauthorizedTrade();
        uint256 received = balanceAfter - balanceBefore;
        if (received != amountOut) revert UnauthorizedTrade();
        if (amountOut < minAmountOut) revert ExceedsMaxSlippage();

        s.totalTrades += 1;
        s.totalVolumeIn += amountIn;
        s.totalVolumeOut += amountOut;

        if (s.tokenIn == collateralToken) {
            s.totalCapital = s.totalCapital - amountIn + amountOut;
        } else if (s.tokenOut == collateralToken) {
            s.totalCapital += amountOut - amountIn;
        }

        if (amountOut >= spotPrice) {
            s.realizedPnl += (amountOut - spotPrice);
        } else {
            uint256 loss = spotPrice - amountOut;
            s.realizedPnl = s.realizedPnl > loss ? s.realizedPnl - loss : 0;
        }

        emit TradeExecuted(strategyId, s.tokenIn, s.tokenOut, amountIn, amountOut, minAmountOut, block.timestamp);
    }

    function getStrategy(uint256 strategyId)
        external
        view
        strategyExists(strategyId)
        returns (StrategyView memory)
    {
        Strategy storage s = strategies[strategyId];
        return StrategyView({
            tokenIn: s.tokenIn,
            tokenOut: s.tokenOut,
            dexAdapter: s.dexAdapter,
            maxSlippageBps: s.maxSlippageBps,
            paused: s.paused,
            totalCapital: s.totalCapital,
            totalShares: s.totalShares,
            totalTrades: s.totalTrades,
            totalVolumeIn: s.totalVolumeIn,
            totalVolumeOut: s.totalVolumeOut,
            realizedPnl: s.realizedPnl,
            metadata: s.metadata
        });
    }

    function getUserPosition(uint256 strategyId, address user)
        external
        view
        strategyExists(strategyId)
        returns (uint256 shares, uint256 depositedAmount, uint256 shareValue)
    {
        UserPosition storage pos = userPositions[strategyId][user];
        Strategy storage s = strategies[strategyId];
        shares = pos.shares;
        depositedAmount = pos.depositedAmount;
        shareValue = (s.totalShares == 0) ? 0 : (pos.shares * s.totalCapital) / s.totalShares;
    }

    function getSharesValue(uint256 strategyId, uint256 shares)
        external
        view
        strategyExists(strategyId)
        returns (uint256)
    {
        Strategy storage s = strategies[strategyId];
        if (s.totalShares == 0) return 0;
        return (shares * s.totalCapital) / s.totalShares;
    }

    function strategyCount() external view returns (uint256) {
        return nextStrategyId - 1;
    }
}
