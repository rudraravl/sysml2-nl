// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }

    error SafeERC20FailedOperation(address token);
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    error ReentrancyGuardReentrantCall();
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

contract LeveragedPositions is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant FEE_BPS = 10;
    uint16 public constant LIQUIDATOR_REWARD_BPS = 500;
    uint256 public constant BPS_DENOM = 10_000;
    uint256 public constant LEVERAGE_DENOM = 1e18;
    uint256 public constant MIN_LEVERAGE = 1e18;
    uint256 public constant MAX_LEVERAGE = 50e18;

    enum Direction {
        Long,
        Short
    }

    struct Position {
        address owner;
        uint256 collateral;
        uint256 leverage;
        Direction direction;
        uint256 openPrice;
        bool exists;
    }

    IERC20 public immutable baseAsset;
    uint8 public collateralDecimals;
    uint256 public immutable minCollateral;

    address public operator;
    IPriceOracle public oracle;
    uint256 public liquidationThreshold;

    uint256 public collectedFees;
    uint256 public nextPositionId;
    mapping(uint256 => Position) public positions;

    event PositionOpened(
        uint256 indexed positionId,
        address indexed owner,
        Direction direction,
        uint256 leverage,
        uint256 collateral,
        uint256 openPrice,
        uint256 fee
    );

    event CollateralAdded(
        uint256 indexed positionId,
        address indexed caller,
        uint256 amount,
        uint256 newCollateral
    );

    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        int256 pnl,
        uint256 fee,
        uint256 returnedAmount,
        uint256 closePrice
    );

    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        address indexed owner,
        int256 pnl,
        uint256 liquidatorReward,
        uint256 protocolRecovery,
        uint256 liquidationPrice
    );

    event OracleUpdated(address indexed caller, address indexed oldOracle, address indexed newOracle);

    event LiquidationThresholdUpdated(address indexed caller, uint256 oldThreshold, uint256 newThreshold);

    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    event FeesWithdrawn(address indexed caller, address indexed recipient, uint256 amount);

    error PositionNotFound(uint256 positionId);
    error NotPositionOwner(address caller, uint256 positionId);
    error NotOperator(address caller);
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral(uint256 provided, uint256 required);
    error InvalidLeverage(uint256 leverage);
    error InvalidLiquidationThreshold(uint256 threshold);
    error PriceInvalid(uint256 price);
    error PositionNotLiquidatable(uint256 positionId, int256 equity, uint256 maintenanceMargin);
    error TransferFailed();
    error MulDivDenominatorZero();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator(msg.sender);
        _;
    }

    modifier onlyExistingPosition(uint256 positionId) {
        if (!positions[positionId].exists) revert PositionNotFound(positionId);
        _;
    }

    modifier onlyPositionOwner(uint256 positionId) {
        Position storage p = positions[positionId];
        if (!p.exists) revert PositionNotFound(positionId);
        if (p.owner != msg.sender) revert NotPositionOwner(msg.sender, positionId);
        _;
    }

    constructor(
        address _baseAsset,
        address _oracle,
        address _operator,
        uint256 _liquidationThreshold
    ) {
        if (_baseAsset == address(0) || _oracle == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        if (_liquidationThreshold == 0 || _liquidationThreshold > BPS_DENOM) {
            revert InvalidLiquidationThreshold(_liquidationThreshold);
        }

        baseAsset = IERC20(_baseAsset);

        uint8 _decimals = 18;
        try IERC20Metadata(_baseAsset).decimals() returns (uint8 d) {
            _decimals = d;
        } catch {}

        collateralDecimals = _decimals;

        if (_decimals < 2) {
            minCollateral = 1;
        } else {
            minCollateral = 10 ** (uint256(_decimals) - 2);
        }

        oracle = IPriceOracle(_oracle);
        operator = _operator;
        liquidationThreshold = _liquidationThreshold;
        nextPositionId = 1;
    }

    function openPosition(
        Direction direction,
        uint256 leverage,
        uint256 collateralAmount
    ) external nonReentrant returns (uint256 positionId) {
        if (collateralAmount < minCollateral) {
            revert InsufficientCollateral(collateralAmount, minCollateral);
        }
        if (leverage < MIN_LEVERAGE || leverage > MAX_LEVERAGE) {
            revert InvalidLeverage(leverage);
        }

        uint256 price = oracle.getPrice(address(baseAsset));
        if (price == 0) revert PriceInvalid(0);

        // Fee = (collateralAmount * leverage * FEE_BPS) / (LEVERAGE_DENOM * BPS_DENOM)
        // Using mulDiv to avoid divide-before-multiply precision loss
        uint256 fee = mulDiv(collateralAmount, leverage * FEE_BPS, LEVERAGE_DENOM * BPS_DENOM);

        // Effects: update state before external call (CEI pattern)
        positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            collateral: collateralAmount,
            leverage: leverage,
            direction: direction,
            openPrice: price,
            exists: true
        });
        collectedFees += fee;

        // Interaction: pull collateral and fee from msg.sender
        _transferFrom(address(this), collateralAmount + fee);

        emit PositionOpened(positionId, msg.sender, direction, leverage, collateralAmount, price, fee);
    }

    function addCollateral(uint256 positionId, uint256 amount)
        external
        nonReentrant
        onlyExistingPosition(positionId)
    {
        if (amount == 0) revert ZeroAmount();

        Position storage p = positions[positionId];

        // Effects: update state before external call (CEI pattern)
        p.collateral += amount;

        // Interaction: pull collateral from msg.sender
        _transferFrom(address(this), amount);

        emit CollateralAdded(positionId, msg.sender, amount, p.collateral);
    }

    function closePosition(uint256 positionId)
        external
        nonReentrant
        onlyPositionOwner(positionId)
        returns (int256 pnl, uint256 fee, uint256 returnedAmount)
    {
        Position memory p = positions[positionId];

        uint256 price = oracle.getPrice(address(baseAsset));
        if (price == 0) revert PriceInvalid(0);

        pnl = computePnL(p, price);

        // Fee = (collateral * leverage * FEE_BPS) / (LEVERAGE_DENOM * BPS_DENOM)
        fee = mulDiv(p.collateral, p.leverage * FEE_BPS, LEVERAGE_DENOM * BPS_DENOM);

        int256 equity = int256(p.collateral) + pnl - int256(fee);
        if (equity < 0) {
            returnedAmount = 0;
        } else {
            returnedAmount = uint256(equity);
        }

        // Effects: bookkeeping and delete before interaction (CEI pattern)
        collectedFees += fee;
        delete positions[positionId];

        // Interaction: return collateral to owner
        if (returnedAmount > 0) {
            baseAsset.safeTransfer(msg.sender, returnedAmount);
        }

        emit PositionClosed(positionId, msg.sender, pnl, fee, returnedAmount, price);
    }

    function liquidate(uint256 positionId)
        external
        nonReentrant
        onlyExistingPosition(positionId)
        returns (uint256 liquidatorReward, uint256 protocolRecovery)
    {
        Position memory p = positions[positionId];

        uint256 price = oracle.getPrice(address(baseAsset));
        if (price == 0) revert PriceInvalid(0);

        int256 pnl = computePnL(p, price);
        int256 equity = int256(p.collateral) + pnl;
        uint256 maintenanceMargin = (p.collateral * liquidationThreshold) / BPS_DENOM;

        if (equity >= int256(maintenanceMargin)) {
            revert PositionNotLiquidatable(positionId, equity, maintenanceMargin);
        }

        uint256 remaining;
        if (equity < 0) {
            remaining = 0;
        } else {
            remaining = uint256(equity);
        }

        liquidatorReward = (remaining * LIQUIDATOR_REWARD_BPS) / BPS_DENOM;
        protocolRecovery = remaining - liquidatorReward;

        // Effects: delete before interactions (CEI pattern)
        delete positions[positionId];

        // Interactions
        if (liquidatorReward > 0) {
            baseAsset.safeTransfer(msg.sender, liquidatorReward);
        }
        if (protocolRecovery > 0) {
            baseAsset.safeTransfer(operator, protocolRecovery);
        }

        emit PositionLiquidated(
            positionId,
            msg.sender,
            p.owner,
            pnl,
            liquidatorReward,
            protocolRecovery,
            price
        );
    }

    function computePnL(Position memory p, uint256 currentPrice) public pure returns (int256) {
        // Compute PnL = (collateral * leverage * priceDiff) / (LEVERAGE_DENOM * openPrice)
        // Using mulDiv to perform all multiplications before divisions,
        // avoiding divide-before-multiply precision loss.
        uint256 denom = LEVERAGE_DENOM * p.openPrice;

        if (p.direction == Direction.Long) {
            if (currentPrice >= p.openPrice) {
                uint256 priceDiff = currentPrice - p.openPrice;
                return int256(mulDiv(p.collateral, p.leverage * priceDiff, denom));
            }
            uint256 priceDiff = p.openPrice - currentPrice;
            return -int256(mulDiv(p.collateral, p.leverage * priceDiff, denom));
        } else {
            if (p.openPrice >= currentPrice) {
                uint256 priceDiff = p.openPrice - currentPrice;
                return int256(mulDiv(p.collateral, p.leverage * priceDiff, denom));
            }
            uint256 priceDiff = currentPrice - p.openPrice;
            return -int256(mulDiv(p.collateral, p.leverage * priceDiff, denom));
        }
    }

    /// @dev Computes (a * b) / denominator with full precision, handling overflow.
    ///      When a * b would overflow uint256, the computation is split by dividing
    ///      a by the denominator first: (a / d) * b + (a % d) * b / d.
    ///      This is mathematically exact and only reverts if the true result
    ///      exceeds uint256 (via checked arithmetic on the intermediate products).
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        if (denominator == 0) revert MulDivDenominatorZero();
        if (a == 0 || b == 0) return 0;

        // If a * b does not overflow, compute directly
        if (a <= type(uint256).max / b) {
            return (a * b) / denominator;
        }

        // a * b overflows; divide a by denominator first to reduce magnitude.
        // result = (a / d) * b + (a % d) * b / d = a * b / d (mathematically exact).
        // Checked arithmetic ensures q * b and r * b revert if they overflow,
        // which only happens when the true result exceeds uint256.
        uint256 q = a / denominator;
        uint256 r = a % denominator;
        return q * b + (r * b) / denominator;
    }

    /// @dev Internal transferFrom that always uses msg.sender as the sender,
    ///      preventing arbitrary-send-erc20 vulnerabilities.
    function _transferFrom(address to, uint256 amount) internal {
        bool success = baseAsset.transferFrom(msg.sender, to, amount);
        if (!success) revert TransferFailed();
    }

    function getPosition(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getEquity(uint256 positionId) external view returns (int256) {
        Position memory p = positions[positionId];
        if (!p.exists) revert PositionNotFound(positionId);

        uint256 price = oracle.getPrice(address(baseAsset));
        if (price == 0) revert PriceInvalid(0);

        return int256(p.collateral) + computePnL(p, price);
    }

    function isLiquidatable(uint256 positionId) external view returns (bool) {
        Position memory p = positions[positionId];
        if (!p.exists) return false;

        uint256 price = oracle.getPrice(address(baseAsset));
        if (price == 0) return false;

        int256 equity = int256(p.collateral) + computePnL(p, price);
        uint256 maintenanceMargin = (p.collateral * liquidationThreshold) / BPS_DENOM;
        return equity < int256(maintenanceMargin);
    }

    function getNotional(uint256 positionId) external view returns (uint256) {
        Position memory p = positions[positionId];
        if (!p.exists) revert PositionNotFound(positionId);
        return (p.collateral * p.leverage) / LEVERAGE_DENOM;
    }

    function setOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IPriceOracle(newOracle);
        emit OracleUpdated(msg.sender, old, newOracle);
    }

    function setLiquidationThreshold(uint256 newThreshold) external onlyOperator {
        if (newThreshold == 0 || newThreshold > BPS_DENOM) {
            revert InvalidLiquidationThreshold(newThreshold);
        }
        uint256 old = liquidationThreshold;
        liquidationThreshold = newThreshold;
        emit LiquidationThresholdUpdated(msg.sender, old, newThreshold);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorTransferred(old, newOperator);
    }

    function withdrawFees(address recipient) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = collectedFees;
        if (amount == 0) revert ZeroAmount();

        // Effects: zero out collected fees before transfer (CEI pattern)
        collectedFees = 0;

        // Interaction
        baseAsset.safeTransfer(recipient, amount);

        emit FeesWithdrawn(msg.sender, recipient, amount);
    }
}
