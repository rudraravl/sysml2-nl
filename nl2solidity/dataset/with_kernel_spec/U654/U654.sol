// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PerpetualExchange is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Position {
        uint256 margin;       // Collateral in asset amount
        uint256 size;         // Position size in USD (1e18)
        bool isLong;
        uint256 entryPrice;   // Entry price in USD (1e18)
    }

    struct Pool {
        uint256 liquidity;    // LP liquidity in asset amount
        uint256 longSize;     // Total long size in USD
        uint256 shortSize;    // Total short size in USD
    }

    uint256 public constant MAX_LEVERAGE = 50;
    uint256 public constant FEE_RATE = 0.001e18;          // 0.1%
    uint256 public constant MAINTENANCE_MARGIN = 0.05e18;  // 5%
    uint256 public constant PRICE_PRECISION = 1e18;

    mapping(address => mapping(address => Position)) public positions; // trader => asset => Position
    mapping(address => Pool) public pools;                              // asset => Pool
    mapping(address => uint256) public assetPrices;                     // asset => price (1e18)
    mapping(address => int256) public fundingRates;                     // asset => funding rate
    mapping(address => mapping(address => uint256)) public lpBalances;  // provider => asset => amount

    address public operator;

    event PositionOpened(
        address indexed trader,
        address indexed asset,
        bool isLong,
        uint256 marginAdded,
        uint256 size,
        uint256 entryPrice
    );
    event PositionIncreased(
        address indexed trader,
        address indexed asset,
        uint256 marginAdded,
        uint256 sizeDelta,
        uint256 newSize
    );
    event PositionClosed(
        address indexed trader,
        address indexed asset,
        uint256 marginReturned,
        uint256 sizeClosed,
        uint256 exitPrice,
        int256 pnl
    );
    event PositionLiquidated(
        address indexed trader,
        address indexed asset,
        uint256 margin,
        uint256 size,
        uint256 price
    );
    event CollateralDeposited(address indexed trader, address indexed asset, uint256 amount);
    event CollateralWithdrawn(address indexed trader, address indexed asset, uint256 amount);
    event LiquidityAdded(address indexed provider, address indexed asset, uint256 amount);
    event LiquidityRemoved(address indexed provider, address indexed asset, uint256 amount);
    event PriceUpdated(address indexed asset, uint256 price);
    event FundingRateUpdated(address indexed asset, int256 rate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    error UnauthorizedOperator();
    error InvalidPrice();
    error InsufficientMargin();
    error ExceedsMaxLeverage();
    error PositionNotFound();
    error PositionAlreadyExists();
    error NotLiquidatable();
    error InsufficientLiquidity();
    error ZeroAmount();
    error ZeroAddress();

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert UnauthorizedOperator();
        _;
    }

    modifier nonZero(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    constructor() Ownable(msg.sender) {
        operator = msg.sender;
        emit OperatorUpdated(address(0), operator);
    }

    function setOperator(address _operator) external onlyOwner nonZero(_operator) {
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setPrice(address asset, uint256 price) external onlyOperator nonZero(asset) {
        if (price == 0) revert InvalidPrice();
        assetPrices[asset] = price;
        emit PriceUpdated(asset, price);
    }

    function setFundingRate(address asset, int256 rate) external onlyOperator nonZero(asset) {
        fundingRates[asset] = rate;
        emit FundingRateUpdated(asset, rate);
    }

    function depositCollateral(address asset, uint256 amount) external nonReentrant nonZero(asset) {
        if (amount == 0) revert ZeroAmount();
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        positions[msg.sender][asset].margin += amount;
        emit CollateralDeposited(msg.sender, asset, amount);
    }

    function withdrawCollateral(address asset, uint256 amount) external nonReentrant nonZero(asset) {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender][asset];
        if (pos.margin < amount) revert InsufficientMargin();

        if (pos.size > 0) {
            uint256 price = assetPrices[asset];
            if (price == 0) revert InvalidPrice();
            int256 pnl = _getPnl(pos, price);
            uint256 remainingMargin = pos.margin - amount;
            if (!_isSafeMargin(remainingMargin, pos.size, pnl, price)) revert InsufficientMargin();
        }

        pos.margin -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, asset, amount);
    }

    function openPosition(
        address asset,
        bool isLong,
        uint256 margin,
        uint256 leverage
    ) external nonReentrant nonZero(asset) {
        if (margin == 0 || leverage == 0) revert ZeroAmount();
        if (leverage > MAX_LEVERAGE) revert ExceedsMaxLeverage();
        uint256 price = assetPrices[asset];
        if (price == 0) revert InvalidPrice();

        Position storage pos = positions[msg.sender][asset];
        if (pos.size > 0) revert PositionAlreadyExists();
        if (pos.margin < margin) revert InsufficientMargin();

        pos.margin -= margin;

        uint256 marginUSD = (margin * price) / PRICE_PRECISION;
        uint256 size = (marginUSD * leverage) / PRICE_PRECISION;
        uint256 feeUSD = (size * FEE_RATE) / PRICE_PRECISION;
        uint256 feeInAsset = (feeUSD * PRICE_PRECISION) / price;

        if (margin <= feeInAsset) revert InsufficientMargin();
        uint256 effectiveMargin = margin - feeInAsset;

        pos.margin += effectiveMargin;
        pos.size = size;
        pos.isLong = isLong;
        pos.entryPrice = price;

        pools[asset].liquidity += feeInAsset;
        if (isLong) {
            pools[asset].longSize += size;
        } else {
            pools[asset].shortSize += size;
        }

        emit PositionOpened(msg.sender, asset, isLong, margin, size, price);
    }

    function increasePosition(address asset, uint256 marginToAdd) external nonReentrant nonZero(asset) {
        if (marginToAdd == 0) revert ZeroAmount();
        uint256 price = assetPrices[asset];
        if (price == 0) revert InvalidPrice();

        Position storage pos = positions[msg.sender][asset];
        if (pos.size == 0) revert PositionNotFound();
        if (pos.margin < marginToAdd) revert InsufficientMargin();

        pos.margin -= marginToAdd;

        uint256 currentLeverage = (pos.size * PRICE_PRECISION) / ((pos.margin * price) / PRICE_PRECISION);
        if (currentLeverage > MAX_LEVERAGE) revert ExceedsMaxLeverage();

        uint256 additionalSize = (marginToAdd * price * currentLeverage) / (PRICE_PRECISION * PRICE_PRECISION);
        uint256 feeUSD = (additionalSize * FEE_RATE) / PRICE_PRECISION;
        uint256 feeInAsset = (feeUSD * PRICE_PRECISION) / price;

        if (marginToAdd <= feeInAsset) revert InsufficientMargin();
        uint256 effectiveMargin = marginToAdd - feeInAsset;

        pos.margin += effectiveMargin;

        uint256 oldSize = pos.size;
        pos.size += additionalSize;
        pos.entryPrice = (pos.entryPrice * oldSize + price * additionalSize) / pos.size;

        pools[asset].liquidity += feeInAsset;
        if (pos.isLong) {
            pools[asset].longSize += additionalSize;
        } else {
            pools[asset].shortSize += additionalSize;
        }

        emit PositionIncreased(msg.sender, asset, marginToAdd, additionalSize, pos.size);
    }

    function decreasePosition(address asset, uint256 marginToReduce) external nonReentrant nonZero(asset) {
        if (marginToReduce == 0) revert ZeroAmount();
        uint256 price = assetPrices[asset];
        if (price == 0) revert InvalidPrice();

        Position storage pos = positions[msg.sender][asset];
        if (pos.size == 0) revert PositionNotFound();
        if (pos.margin < marginToReduce) revert InsufficientMargin();

        uint256 sizeToReduce = (pos.size * marginToReduce) / pos.margin;
        uint256 feeUSD = (sizeToReduce * FEE_RATE) / PRICE_PRECISION;
        uint256 feeInAsset = (feeUSD * PRICE_PRECISION) / price;

        int256 pnl = _getPnl(pos, price);
        int256 pnlOnReduced = (pnl * int256(sizeToReduce)) / int256(pos.size);
        int256 returnAmount = int256(marginToReduce) + pnlOnReduced - int256(feeInAsset);

        if (returnAmount <= 0) revert InsufficientMargin();

        pos.margin -= marginToReduce;
        pos.size -= sizeToReduce;

        pools[asset].liquidity += feeInAsset;
        if (pnlOnReduced > 0) {
            pools[asset].liquidity -= uint256(pnlOnReduced);
        } else {
            pools[asset].liquidity += uint256(-pnlOnReduced);
        }

        if (pos.isLong) {
            pools[asset].longSize -= sizeToReduce;
        } else {
            pools[asset].shortSize -= sizeToReduce;
        }

        IERC20(asset).safeTransfer(msg.sender, uint256(returnAmount));
        emit PositionClosed(msg.sender, asset, uint256(returnAmount), sizeToReduce, price, pnlOnReduced);
    }

    function closePosition(address asset) external nonReentrant nonZero(asset) {
        uint256 price = assetPrices[asset];
        if (price == 0) revert InvalidPrice();

        Position storage pos = positions[msg.sender][asset];
        if (pos.size == 0) revert PositionNotFound();

        int256 pnl = _getPnl(pos, price);
        uint256 feeUSD = (pos.size * FEE_RATE) / PRICE_PRECISION;
        uint256 feeInAsset = (feeUSD * PRICE_PRECISION) / price;
        int256 returnAmount = int256(pos.margin) + pnl - int256(feeInAsset);

        if (returnAmount <= 0) revert InsufficientMargin();

        uint256 marginReturned = uint256(returnAmount);
        pools[asset].liquidity += feeInAsset;
        if (pnl > 0) {
            pools[asset].liquidity -= uint256(pnl);
        } else {
            pools[asset].liquidity += uint256(-pnl);
        }

        if (pos.isLong) {
            pools[asset].longSize -= pos.size;
        } else {
            pools[asset].shortSize -= pos.size;
        }

        emit PositionClosed(msg.sender, asset, marginReturned, pos.size, price, pnl);

        pos.margin = 0;
        pos.size = 0;
        pos.entryPrice = 0;

        IERC20(asset).safeTransfer(msg.sender, marginReturned);
    }

    function liquidate(address trader, address asset) external onlyOperator nonReentrant nonZero(asset) {
        uint256 price = assetPrices[asset];
        if (price == 0) revert InvalidPrice();

        Position storage pos = positions[trader][asset];
        if (pos.size == 0) revert PositionNotFound();

        int256 pnl = _getPnl(pos, price);
        if (!_isLiquidatable(pos, pnl, price)) revert NotLiquidatable();

        pools[asset].liquidity += pos.margin;
        if (pos.isLong) {
            pools[asset].longSize -= pos.size;
        } else {
            pools[asset].shortSize -= pos.size;
        }

        emit PositionLiquidated(trader, asset, pos.margin, pos.size, price);

        pos.margin = 0;
        pos.size = 0;
        pos.entryPrice = 0;
    }

    function addLiquidity(address asset, uint256 amount) external nonReentrant nonZero(asset) {
        if (amount == 0) revert ZeroAmount();
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        pools[asset].liquidity += amount;
        lpBalances[msg.sender][asset] += amount;
        emit LiquidityAdded(msg.sender, asset, amount);
    }

    function removeLiquidity(address asset, uint256 amount) external nonReentrant nonZero(asset) {
        if (amount == 0) revert ZeroAmount();
        Pool storage pool = pools[asset];
        if (lpBalances[msg.sender][asset] < amount) revert InsufficientLiquidity();
        if (pool.liquidity < amount) revert InsufficientLiquidity();
        lpBalances[msg.sender][asset] -= amount;
        pool.liquidity -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
        emit LiquidityRemoved(msg.sender, asset, amount);
    }

    function getPosition(address trader, address asset)
        external
        view
        returns (uint256 margin, uint256 size, bool isLong, uint256 entryPrice)
    {
        Position memory pos = positions[trader][asset];
        return (pos.margin, pos.size, pos.isLong, pos.entryPrice);
    }

    function getPool(address asset)
        external
        view
        returns (uint256 liquidity, uint256 longSize, uint256 shortSize)
    {
        Pool memory pool = pools[asset];
        return (pool.liquidity, pool.longSize, pool.shortSize);
    }

    function getUnrealizedPnl(address trader, address asset) external view returns (int256) {
        Position memory pos = positions[trader][asset];
        if (pos.size == 0) return 0;
        uint256 price = assetPrices[asset];
        if (price == 0) revert InvalidPrice();
        return _getPnl(pos, price);
    }

    function getLpBalance(address provider, address asset) external view returns (uint256) {
        return lpBalances[provider][asset];
    }

    function _getPnl(Position memory pos, uint256 price) internal pure returns (int256) {
        if (pos.size == 0) return 0;
        int256 priceDiff;
        if (pos.isLong) {
            priceDiff = int256(price) - int256(pos.entryPrice);
        } else {
            priceDiff = int256(pos.entryPrice) - int256(price);
        }
        int256 pnlUSD = (int256(pos.size) * priceDiff) / int256(pos.entryPrice);
        int256 pnlAsset = (pnlUSD * int256(PRICE_PRECISION)) / int256(price);
        return pnlAsset;
    }

    function _isSafeMargin(uint256 margin, uint256 size, int256 pnl, uint256 price) internal pure returns (bool) {
        int256 equity = int256(margin) + pnl;
        if (equity <= 0) return false;
        int256 equityUSD = (equity * int256(price)) / int256(PRICE_PRECISION);
        int256 maintenance = (int256(size) * int256(MAINTENANCE_MARGIN)) / int256(PRICE_PRECISION);
        return equityUSD >= maintenance;
    }

    function _isLiquidatable(Position memory pos, int256 pnl, uint256 price) internal pure returns (bool) {
        return !_isSafeMargin(pos.margin, pos.size, pnl, price);
    }
}
