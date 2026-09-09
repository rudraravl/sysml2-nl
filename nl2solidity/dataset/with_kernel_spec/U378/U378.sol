// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(from == msg.sender, "SafeERC20: transferFrom not authorized");
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
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

contract PerpetualFutures is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error MaxLeverageExceeded();
    error NotLiquidatable();
    error PairNotSupported();
    error TradingPaused();
    error Unauthorized();
    error PositionNotFound();
    error WrongDirection();
    error ExceedsPositionSize();
    error InvalidThreshold();

    uint256 public constant MAX_LEVERAGE = 50 * 1e18;
    uint256 public constant TRADING_FEE_BPS = 10;
    uint256 public constant BPS_DIVISOR = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_REWARD_BPS = 1000;

    struct PairConfig {
        bool isSupported;
        uint256 liquidationThreshold;
        uint256 fundingRate;
        uint256 basePrice;
    }

    struct Position {
        uint256 size;
        uint256 entryPrice;
        bool isLong;
        uint256 collateral;
    }

    IERC20 public immutable collateralToken;
    address public operator;
    address public feeReceiver;
    bool public paused;

    mapping(bytes32 => PairConfig) public pairs;
    mapping(address => mapping(bytes32 => Position)) public positions;
    mapping(address => uint256) public collateralBalances;
    uint256 public accumulatedFees;

    event PositionOpened(
        address indexed user,
        bytes32 indexed pairId,
        bool isLong,
        uint256 size,
        uint256 entryPrice,
        uint256 collateral,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed pairId,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 fee
    );
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        bytes32 indexed pairId,
        uint256 size,
        uint256 exitPrice,
        uint256 reward
    );
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event PairConfigUpdated(
        bytes32 indexed pairId,
        bool isSupported,
        uint256 liquidationThreshold,
        uint256 fundingRate,
        uint256 basePrice
    );
    event Paused(bool isPaused);
    event FeesClaimed(address indexed receiver, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeReceiverUpdated(address indexed previousReceiver, address indexed newReceiver);

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    modifier supportedPair(bytes32 pairId) {
        if (!pairs[pairId].isSupported) revert PairNotSupported();
        _;
    }

    constructor(address _collateralToken, address _operator, address _feeReceiver) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeReceiver == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        feeReceiver = _feeReceiver;
    }

    function depositCollateral(uint256 amount) external notPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        collateralBalances[msg.sender] += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external notPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalances[msg.sender] < amount) revert InsufficientCollateral();
        collateralBalances[msg.sender] -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function openPosition(
        bytes32 pairId,
        bool isLong,
        uint256 size,
        uint256 collateralAmount
    ) external notPaused nonReentrant supportedPair(pairId) {
        if (size == 0 || collateralAmount == 0) revert ZeroAmount();

        uint256 price = pairs[pairId].basePrice;
        Position storage pos = positions[msg.sender][pairId];

        if (pos.size > 0 && pos.isLong != isLong) revert WrongDirection();

        uint256 totalSize = pos.size + size;
        uint256 totalCollateral = pos.collateral + collateralAmount;
        // leverage = (totalSize * price) / totalCollateral (PRECISION cancels)
        uint256 leverage = (totalSize * price) / totalCollateral;
        if (leverage > MAX_LEVERAGE) revert MaxLeverageExceeded();

        // fee = (size * price * TRADING_FEE_BPS) / (PRECISION * BPS_DIVISOR)
        uint256 fee = (size * price * TRADING_FEE_BPS) / (PRECISION * BPS_DIVISOR);
        if (collateralBalances[msg.sender] < collateralAmount + fee) revert InsufficientCollateral();
        collateralBalances[msg.sender] -= (collateralAmount + fee);
        accumulatedFees += fee;

        if (pos.size > 0) {
            pos.entryPrice = ((pos.entryPrice * pos.size) + (price * size)) / totalSize;
            pos.size = totalSize;
            pos.collateral = totalCollateral;
        } else {
            pos.size = size;
            pos.entryPrice = price;
            pos.isLong = isLong;
            pos.collateral = collateralAmount;
        }

        emit PositionOpened(msg.sender, pairId, isLong, size, price, collateralAmount, fee);
    }

    function increasePosition(
        bytes32 pairId,
        uint256 sizeAdded,
        uint256 collateralAdded
    ) external notPaused nonReentrant supportedPair(pairId) {
        if (sizeAdded == 0) revert ZeroAmount();

        Position storage pos = positions[msg.sender][pairId];
        if (pos.size == 0) revert PositionNotFound();

        uint256 price = pairs[pairId].basePrice;
        uint256 totalSize = pos.size + sizeAdded;
        uint256 totalCollateral = pos.collateral + collateralAdded;
        if (totalCollateral == 0) revert InsufficientCollateral();
        // leverage = (totalSize * price) / totalCollateral (PRECISION cancels)
        uint256 leverage = (totalSize * price) / totalCollateral;
        if (leverage > MAX_LEVERAGE) revert MaxLeverageExceeded();

        // fee = (sizeAdded * price * TRADING_FEE_BPS) / (PRECISION * BPS_DIVISOR)
        uint256 fee = (sizeAdded * price * TRADING_FEE_BPS) / (PRECISION * BPS_DIVISOR);
        if (collateralBalances[msg.sender] < collateralAdded + fee) revert InsufficientCollateral();
        collateralBalances[msg.sender] -= (collateralAdded + fee);
        accumulatedFees += fee;

        pos.entryPrice = ((pos.entryPrice * pos.size) + (price * sizeAdded)) / totalSize;
        pos.size = totalSize;
        pos.collateral = totalCollateral;

        emit PositionOpened(msg.sender, pairId, pos.isLong, sizeAdded, price, collateralAdded, fee);
    }

    function decreasePosition(bytes32 pairId, uint256 sizeToDecrease)
        external
        notPaused
        nonReentrant
        supportedPair(pairId)
    {
        Position storage pos = positions[msg.sender][pairId];
        if (pos.size == 0) revert PositionNotFound();
        if (sizeToDecrease == 0) revert ZeroAmount();
        if (sizeToDecrease > pos.size) revert ExceedsPositionSize();
        _decreasePosition(msg.sender, pairId, sizeToDecrease);
    }

    function closePosition(bytes32 pairId) external notPaused nonReentrant supportedPair(pairId) {
        Position storage pos = positions[msg.sender][pairId];
        if (pos.size == 0) revert PositionNotFound();
        _decreasePosition(msg.sender, pairId, pos.size);
    }

    function liquidate(address user, bytes32 pairId) external notPaused nonReentrant supportedPair(pairId) {
        Position storage pos = positions[user][pairId];
        if (pos.size == 0) revert PositionNotFound();

        uint256 price = pairs[pairId].basePrice;
        int256 pnl = _getPnl(pos.isLong, pos.entryPrice, price, pos.size);

        uint256 equity = _computeEquity(pos.collateral, pnl);

        // equity * PRECISION * PRECISION > pos.size * price * liquidationThreshold
        if (equity * PRECISION * PRECISION > pos.size * price * pairs[pairId].liquidationThreshold) {
            revert NotLiquidatable();
        }

        // reward = (pos.size * price * LIQUIDATION_REWARD_BPS) / (PRECISION * BPS_DIVISOR)
        uint256 reward = (pos.size * price * LIQUIDATION_REWARD_BPS) / (PRECISION * BPS_DIVISOR);
        if (reward > equity) {
            reward = equity;
        }

        uint256 remainingEquity = equity - reward;
        if (remainingEquity > 0) {
            collateralBalances[feeReceiver] += remainingEquity;
        }
        collateralBalances[msg.sender] += reward;

        uint256 closedSize = pos.size;
        delete positions[user][pairId];

        emit Liquidated(user, msg.sender, pairId, closedSize, price, reward);
    }

    function setPairConfig(
        bytes32 pairId,
        bool isSupported,
        uint256 liquidationThreshold,
        uint256 fundingRate,
        uint256 basePrice
    ) external onlyOperator {
        if (liquidationThreshold > PRECISION) revert InvalidThreshold();
        pairs[pairId] = PairConfig({
            isSupported: isSupported,
            liquidationThreshold: liquidationThreshold,
            fundingRate: fundingRate,
            basePrice: basePrice
        });
        emit PairConfigUpdated(pairId, isSupported, liquidationThreshold, fundingRate, basePrice);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit Paused(_paused);
    }

    function setFeeReceiver(address _feeReceiver) external onlyOperator {
        if (_feeReceiver == address(0)) revert ZeroAddress();
        emit FeeReceiverUpdated(feeReceiver, _feeReceiver);
        feeReceiver = _feeReceiver;
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function claimFees() external nonReentrant {
        if (msg.sender != feeReceiver) revert Unauthorized();
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        if (amount > 0) {
            collateralToken.safeTransfer(feeReceiver, amount);
        }
        emit FeesClaimed(feeReceiver, amount);
    }

    function getPositionValue(address user, bytes32 pairId) external view returns (uint256) {
        Position storage pos = positions[user][pairId];
        if (pos.size == 0) return 0;
        return (pos.size * pairs[pairId].basePrice) / PRECISION;
    }

    function getEquity(address user, bytes32 pairId) external view returns (uint256) {
        Position storage pos = positions[user][pairId];
        if (pos.size == 0) return collateralBalances[user];
        int256 pnl = _getPnl(pos.isLong, pos.entryPrice, pairs[pairId].basePrice, pos.size);
        return _computeEquity(pos.collateral, pnl);
    }

    function isLiquidatable(address user, bytes32 pairId) external view returns (bool) {
        Position storage pos = positions[user][pairId];
        if (pos.size == 0) return false;
        uint256 price = pairs[pairId].basePrice;
        int256 pnl = _getPnl(pos.isLong, pos.entryPrice, price, pos.size);
        uint256 equity = _computeEquity(pos.collateral, pnl);
        // equity * PRECISION * PRECISION <= pos.size * price * liquidationThreshold
        return equity * PRECISION * PRECISION <= pos.size * price * pairs[pairId].liquidationThreshold;
    }

    function _decreasePosition(address user, bytes32 pairId, uint256 sizeToDecrease) internal {
        Position storage pos = positions[user][pairId];
        uint256 price = pairs[pairId].basePrice;

        int256 pnl = _getPnl(pos.isLong, pos.entryPrice, price, sizeToDecrease);
        // fee = (sizeToDecrease * price * TRADING_FEE_BPS) / (PRECISION * BPS_DIVISOR)
        uint256 fee = (sizeToDecrease * price * TRADING_FEE_BPS) / (PRECISION * BPS_DIVISOR);

        uint256 collateralReturned = (pos.collateral * sizeToDecrease) / pos.size;
        pos.size -= sizeToDecrease;
        pos.collateral -= collateralReturned;

        uint256 amountToReturn = collateralReturned;
        if (pnl > 0) {
            amountToReturn += uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            if (loss < amountToReturn) {
                amountToReturn -= loss;
            } else {
                amountToReturn = 0;
            }
        }

        uint256 actualFee;
        if (amountToReturn > fee) {
            amountToReturn -= fee;
            actualFee = fee;
        } else {
            actualFee = amountToReturn;
            amountToReturn = 0;
        }
        accumulatedFees += actualFee;
        collateralBalances[user] += amountToReturn;

        if (pos.size == 0) {
            delete positions[user][pairId];
        }

        emit PositionClosed(user, pairId, sizeToDecrease, price, pnl, actualFee);
    }

    function _getPnl(bool isLong, uint256 entryPrice, uint256 currentPrice, uint256 size)
        internal
        pure
        returns (int256)
    {
        if (isLong) {
            if (currentPrice >= entryPrice) {
                return int256((currentPrice - entryPrice) * size / PRECISION);
            } else {
                return -int256((entryPrice - currentPrice) * size / PRECISION);
            }
        } else {
            if (entryPrice >= currentPrice) {
                return int256((entryPrice - currentPrice) * size / PRECISION);
            } else {
                return -int256((currentPrice - entryPrice) * size / PRECISION);
            }
        }
    }

    function _computeEquity(uint256 collateral, int256 pnl) internal pure returns (uint256) {
        if (pnl >= 0) {
            return collateral + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            if (loss >= collateral) return 0;
            return collateral - loss;
        }
    }
}
