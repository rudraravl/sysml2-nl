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
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert("SafeERC20: transfer failed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert("SafeERC20: transferFrom failed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error ErrNotOwner();

    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert ErrNotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert("Zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IPriceOracle {
    function getPrice(bytes32 pairId) external view returns (uint256);
}

contract PerpetualFuturesExchange is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ErrZeroAddress();
    error ErrZeroAmount();
    error ErrInsufficientBalance();
    error ErrInsufficientMargin();
    error ErrExceedsMaxLeverage();
    error ErrPositionNotFound();
    error ErrPositionAlreadyOpen();
    error ErrPairNotFound();
    error ErrPairInactive();
    error ErrPairAlreadyExists();
    error ErrPositionSafe();
    error ErrNotOperator();
    error ErrInvalidPrice();
    error ErrInvalidParameter();

    uint256 public constant MAX_LEVERAGE = 10e18;
    uint256 public constant TRADING_FEE_BPS = 10;
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant WAD = 1e18;

    struct TradingPair {
        address oracle;
        uint256 maxLeverage;
        uint256 maintenanceMarginBps;
        uint256 liquidationPenaltyBps;
        int256 fundingRatePerSecond;
        int256 cumulativeFundingRate;
        uint256 lastFundingTime;
        bool active;
        bool exists;
    }

    struct Position {
        bool isLong;
        uint256 size;
        uint256 collateral;
        uint256 entryPrice;
        int256 entryFundingRate;
        bool isOpen;
    }

    IERC20 public immutable collateralToken;
    address public operator;

    mapping(bytes32 => TradingPair) public pairs;
    bytes32[] public pairIds;

    mapping(address => uint256) public balances;
    mapping(address => mapping(bytes32 => Position)) public positions;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event MarginAdded(address indexed user, bytes32 indexed pairId, uint256 amount);
    event PositionOpened(
        address indexed user,
        bytes32 indexed pairId,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 entryPrice,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed pairId,
        bool isLong,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        int256 fundingPayment,
        uint256 fee
    );
    event PositionLiquidated(
        address indexed user,
        bytes32 indexed pairId,
        address indexed liquidator,
        uint256 size,
        uint256 liquidationPrice,
        uint256 penalty,
        int256 pnl
    );
    event FundingRateUpdated(
        bytes32 indexed pairId,
        int256 fundingRatePerSecond,
        int256 cumulativeFundingRate,
        uint256 timestamp
    );
    event PairAdded(bytes32 indexed pairId, address indexed oracle);
    event PairConfigured(
        bytes32 indexed pairId,
        uint256 maxLeverage,
        uint256 maintenanceMarginBps,
        uint256 liquidationPenaltyBps
    );
    event PairStatusChanged(bytes32 indexed pairId, bool active);
    event OperatorChanged(address indexed operator);

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier onlyExistingPair(bytes32 pairId) {
        if (!pairs[pairId].exists) revert ErrPairNotFound();
        _;
    }

    modifier onlyActivePair(bytes32 pairId) {
        if (!pairs[pairId].exists) revert ErrPairNotFound();
        if (!pairs[pairId].active) revert ErrPairInactive();
        _;
    }

    constructor(address _collateralToken, address _operator) Ownable(msg.sender) {
        if (_collateralToken == address(0)) revert ErrZeroAddress();
        if (_operator == address(0)) revert ErrZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        emit OperatorChanged(_operator);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ErrZeroAddress();
        operator = _operator;
        emit OperatorChanged(_operator);
    }

    function addPair(
        bytes32 pairId,
        address oracle,
        uint256 maxLeverage,
        uint256 maintenanceMarginBps,
        uint256 liquidationPenaltyBps
    ) external onlyOwner {
        if (pairs[pairId].exists) revert ErrPairAlreadyExists();
        if (oracle == address(0)) revert ErrZeroAddress();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert ErrInvalidParameter();
        if (maintenanceMarginBps == 0 || maintenanceMarginBps > BPS_DENOM) revert ErrInvalidParameter();
        if (liquidationPenaltyBps > BPS_DENOM) revert ErrInvalidParameter();

        pairs[pairId] = TradingPair({
            oracle: oracle,
            maxLeverage: maxLeverage,
            maintenanceMarginBps: maintenanceMarginBps,
            liquidationPenaltyBps: liquidationPenaltyBps,
            fundingRatePerSecond: 0,
            cumulativeFundingRate: 0,
            lastFundingTime: block.timestamp,
            active: true,
            exists: true
        });
        pairIds.push(pairId);

        emit PairAdded(pairId, oracle);
        emit PairConfigured(pairId, maxLeverage, maintenanceMarginBps, liquidationPenaltyBps);
    }

    function configurePair(
        bytes32 pairId,
        uint256 maxLeverage,
        uint256 maintenanceMarginBps,
        uint256 liquidationPenaltyBps
    ) external onlyOperator onlyExistingPair(pairId) {
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert ErrInvalidParameter();
        if (maintenanceMarginBps == 0 || maintenanceMarginBps > BPS_DENOM) revert ErrInvalidParameter();
        if (liquidationPenaltyBps > BPS_DENOM) revert ErrInvalidParameter();

        TradingPair storage p = pairs[pairId];
        p.maxLeverage = maxLeverage;
        p.maintenanceMarginBps = maintenanceMarginBps;
        p.liquidationPenaltyBps = liquidationPenaltyBps;

        emit PairConfigured(pairId, maxLeverage, maintenanceMarginBps, liquidationPenaltyBps);
    }

    function setPairStatus(bytes32 pairId, bool active) external onlyOperator onlyExistingPair(pairId) {
        pairs[pairId].active = active;
        emit PairStatusChanged(pairId, active);
    }

    function updateFundingRate(bytes32 pairId, int256 newRatePerSecond)
        external
        onlyOperator
        onlyExistingPair(pairId)
    {
        _accrueFunding(pairId);
        pairs[pairId].fundingRatePerSecond = newRatePerSecond;
        emit FundingRateUpdated(
            pairId,
            newRatePerSecond,
            pairs[pairId].cumulativeFundingRate,
            block.timestamp
        );
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrZeroAmount();
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrZeroAmount();
        if (balances[msg.sender] < amount) revert ErrInsufficientBalance();
        balances[msg.sender] -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function addMargin(bytes32 pairId, uint256 amount)
        external
        nonReentrant
        onlyActivePair(pairId)
    {
        if (amount == 0) revert ErrZeroAmount();
        Position storage pos = positions[msg.sender][pairId];
        if (!pos.isOpen) revert ErrPositionNotFound();
        if (balances[msg.sender] < amount) revert ErrInsufficientBalance();

        _accrueFunding(pairId);
        _settlePositionFunding(pos, pairs[pairId]);

        balances[msg.sender] -= amount;
        pos.collateral += amount;

        emit MarginAdded(msg.sender, pairId, amount);
    }

    function openPosition(
        bytes32 pairId,
        bool isLong,
        uint256 size,
        uint256 collateralAmount
    ) external nonReentrant onlyActivePair(pairId) {
        if (size == 0) revert ErrZeroAmount();
        if (collateralAmount == 0) revert ErrZeroAmount();

        Position storage existing = positions[msg.sender][pairId];
        if (existing.isOpen) revert ErrPositionAlreadyOpen();

        TradingPair storage p = pairs[pairId];
        _accrueFunding(pairId);

        uint256 price = IPriceOracle(p.oracle).getPrice(pairId);
        if (price == 0) revert ErrInvalidPrice();

        uint256 maxAllowedSize = (collateralAmount * p.maxLeverage) / WAD;
        if (size > maxAllowedSize) revert ErrExceedsMaxLeverage();

        uint256 fee = (size * TRADING_FEE_BPS) / BPS_DENOM;
        uint256 totalCost = collateralAmount + fee;
        if (balances[msg.sender] < totalCost) revert ErrInsufficientMargin();

        balances[msg.sender] -= totalCost;

        positions[msg.sender][pairId] = Position({
            isLong: isLong,
            size: size,
            collateral: collateralAmount,
            entryPrice: price,
            entryFundingRate: p.cumulativeFundingRate,
            isOpen: true
        });

        emit PositionOpened(msg.sender, pairId, isLong, size, collateralAmount, price, fee);
    }

    function closePosition(bytes32 pairId) external nonReentrant onlyExistingPair(pairId) {
        Position storage pos = positions[msg.sender][pairId];
        if (!pos.isOpen) revert ErrPositionNotFound();

        TradingPair storage p = pairs[pairId];
        _accrueFunding(pairId);

        uint256 price = IPriceOracle(p.oracle).getPrice(pairId);
        if (price == 0) revert ErrInvalidPrice();

        int256 pnl = _computePnl(pos, price);
        int256 fundingPayment = _computeFundingPayment(pos, p.cumulativeFundingRate);
        uint256 fee = (pos.size * TRADING_FEE_BPS) / BPS_DENOM;

        int256 net = int256(pos.collateral) + pnl - fundingPayment - int256(fee);
        uint256 returnAmount = net > 0 ? uint256(net) : 0;

        emit PositionClosed(msg.sender, pairId, pos.isLong, pos.size, price, pnl, fundingPayment, fee);

        _clearPosition(pos);

        if (returnAmount > 0) {
            balances[msg.sender] += returnAmount;
        }
    }

    function liquidate(address user, bytes32 pairId)
        external
        nonReentrant
        onlyOperator
        onlyExistingPair(pairId)
    {
        Position storage pos = positions[user][pairId];
        if (!pos.isOpen) revert ErrPositionNotFound();

        TradingPair storage p = pairs[pairId];
        _accrueFunding(pairId);

        uint256 price = IPriceOracle(p.oracle).getPrice(pairId);
        if (price == 0) revert ErrInvalidPrice();

        int256 pnl = _computePnl(pos, price);
        int256 fundingPayment = _computeFundingPayment(pos, p.cumulativeFundingRate);
        int256 equity = int256(pos.collateral) + pnl - fundingPayment;

        uint256 requiredMargin = (pos.size * p.maintenanceMarginBps) / BPS_DENOM;
        if (equity >= int256(requiredMargin)) revert ErrPositionSafe();

        uint256 penalty = (pos.collateral * p.liquidationPenaltyBps) / BPS_DENOM;
        uint256 returnToUser = pos.collateral > penalty ? pos.collateral - penalty : 0;

        emit PositionLiquidated(user, pairId, msg.sender, pos.size, price, penalty, pnl);

        _clearPosition(pos);

        if (penalty > 0) {
            balances[msg.sender] += penalty;
        }
        if (returnToUser > 0) {
            balances[user] += returnToUser;
        }
    }

    function getPairCount() external view returns (uint256) {
        return pairIds.length;
    }

    function getPair(bytes32 pairId) external view returns (TradingPair memory) {
        return pairs[pairId];
    }

    function getPosition(address user, bytes32 pairId) external view returns (Position memory) {
        return positions[user][pairId];
    }

    function getAvailableBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function computePnl(address user, bytes32 pairId) external view returns (int256) {
        Position storage pos = positions[user][pairId];
        if (!pos.isOpen) return 0;
        TradingPair storage p = pairs[pairId];
        uint256 price = IPriceOracle(p.oracle).getPrice(pairId);
        if (price == 0) return 0;
        return _computePnl(pos, price);
    }

    function isPositionSafe(address user, bytes32 pairId) external view returns (bool) {
        Position storage pos = positions[user][pairId];
        if (!pos.isOpen) return true;
        TradingPair storage p = pairs[pairId];
        uint256 price = IPriceOracle(p.oracle).getPrice(pairId);
        if (price == 0) return false;

        int256 pnl = _computePnl(pos, price);
        int256 currentCumFunding = _computeCumulativeFundingView(pairId);
        int256 fundingPayment = _computeFundingPayment(pos, currentCumFunding);
        int256 equity = int256(pos.collateral) + pnl - fundingPayment;

        uint256 requiredMargin = (pos.size * p.maintenanceMarginBps) / BPS_DENOM;
        return equity >= int256(requiredMargin);
    }

    function _accrueFunding(bytes32 pairId) internal {
        TradingPair storage p = pairs[pairId];
        if (block.timestamp <= p.lastFundingTime) return;
        uint256 elapsed = block.timestamp - p.lastFundingTime;
        p.cumulativeFundingRate += p.fundingRatePerSecond * int256(elapsed);
        p.lastFundingTime = block.timestamp;
    }

    function _computeCumulativeFundingView(bytes32 pairId) internal view returns (int256) {
        TradingPair storage p = pairs[pairId];
        if (block.timestamp <= p.lastFundingTime) return p.cumulativeFundingRate;
        uint256 elapsed = block.timestamp - p.lastFundingTime;
        return p.cumulativeFundingRate + (p.fundingRatePerSecond * int256(elapsed));
    }

    function _computePnl(Position storage pos, uint256 currentPrice) internal view returns (int256) {
        if (pos.entryPrice == 0) return 0;
        int256 priceDiff;
        if (pos.isLong) {
            priceDiff = int256(currentPrice) - int256(pos.entryPrice);
        } else {
            priceDiff = int256(pos.entryPrice) - int256(currentPrice);
        }
        return (int256(pos.size) * priceDiff) / int256(pos.entryPrice);
    }

    function _computeFundingPayment(Position storage pos, int256 currentCumFunding)
        internal
        view
        returns (int256)
    {
        int256 fundingDiff = currentCumFunding - pos.entryFundingRate;
        int256 payment = (int256(pos.size) * fundingDiff) / int256(WAD);
        if (pos.isLong) {
            return payment;
        } else {
            return -payment;
        }
    }

    function _settlePositionFunding(Position storage pos, TradingPair storage p) internal {
        int256 fundingPayment = _computeFundingPayment(pos, p.cumulativeFundingRate);
        if (fundingPayment > 0) {
            uint256 payment = uint256(fundingPayment);
            if (pos.collateral <= payment) {
                pos.collateral = 0;
            } else {
                pos.collateral -= payment;
            }
        } else if (fundingPayment < 0) {
            pos.collateral += uint256(-fundingPayment);
        }
        pos.entryFundingRate = p.cumulativeFundingRate;
    }

    function _clearPosition(Position storage pos) internal {
        pos.isOpen = false;
        pos.isLong = false;
        pos.size = 0;
        pos.collateral = 0;
        pos.entryPrice = 0;
        pos.entryFundingRate = 0;
    }
}
