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
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        _approve(token, spender, currentAllowance + value);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < value) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, value);
            }
            _approve(token, spender, currentAllowance - value);
        }
    }

    function _approve(IERC20 token, address spender, uint256 value) private {
        bool success = token.approve(spender, value);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        if (paused()) {
            revert EnforcedPause();
        }
        _;
    }

    modifier whenPaused() {
        if (!paused()) {
            revert ExpectedPause();
        }
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

contract PerpetualFutures is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_LEVERAGE = 100e18;
    uint256 public constant TRADING_FEE = 1e15;
    uint256 public constant MAINTENANCE_MARGIN_RATIO = 5e15;
    uint256 public constant LIQUIDATION_PENALTY = 2e16;
    uint256 public constant FUNDING_PRECISION = 1e18;
    int256 public constant MAX_ABS_FUNDING_RATE = 1e14;

    error ErrZeroAddress();
    error ErrZeroAmount();
    error ErrZeroPrice();
    error ErrPairNotFound();
    error ErrPairAlreadyExists();
    error ErrPairNotActive();
    error ErrPositionNotFound();
    error ErrOppositeDirection();
    error ErrExcessiveLeverage();
    error ErrExcessiveSize();
    error ErrInsufficientMargin();
    error ErrInsufficientBalance();
    error ErrInsufficientFees();
    error ErrNotLiquidatable();
    error ErrNotOperator();
    error ErrFundingRateTooHigh();

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        bytes32 indexed pairId,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 entryPrice
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed pairId,
        uint256 sizeClosed,
        uint256 exitPrice,
        int256 realizedPnL,
        uint256 fee
    );
    event MarginAdded(address indexed user, bytes32 indexed pairId, uint256 amount);
    event MarginRemoved(address indexed user, bytes32 indexed pairId, uint256 amount);
    event PositionLiquidated(
        address indexed user,
        bytes32 indexed pairId,
        address indexed liquidator,
        uint256 size,
        int256 pnl,
        uint256 bounty
    );
    event PriceUpdated(bytes32 indexed pairId, uint256 oldPrice, uint256 newPrice);
    event FundingRateUpdated(bytes32 indexed pairId, int256 oldRate, int256 newRate);
    event PairAdded(bytes32 indexed pairId, uint256 initialPrice);
    event PairActiveChanged(bytes32 indexed pairId, bool active);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesClaimed(address indexed to, uint256 amount);

    struct Pair {
        bool active;
        uint256 price;
        int256 fundingRate;
        int256 fundingIndex;
        uint256 longOI;
        uint256 shortOI;
        uint40 lastFundingUpdate;
    }

    struct Position {
        bool isLong;
        uint256 size;
        uint256 margin;
        uint256 entryPrice;
        int256 entryFundingIndex;
    }

    IERC20 public immutable baseAsset;
    address public operator;
    uint256 public totalLiquidity;
    uint256 public accumulatedFees;

    mapping(bytes32 => Pair) public pairs;
    mapping(address => uint256) public freeBalance;
    mapping(address => mapping(bytes32 => Position)) public positions;

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert ErrNotOperator();
        _;
    }

    constructor(address baseAsset_) Ownable(msg.sender) {
        if (baseAsset_ == address(0)) revert ErrZeroAddress();
        baseAsset = IERC20(baseAsset_);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function addPair(bytes32 pairId, uint256 initialPrice) external onlyOwner {
        if (pairs[pairId].lastFundingUpdate != 0) revert ErrPairAlreadyExists();
        if (initialPrice == 0) revert ErrZeroPrice();

        Pair storage pair = pairs[pairId];
        pair.active = true;
        pair.price = initialPrice;
        pair.fundingIndex = int256(FUNDING_PRECISION);
        pair.lastFundingUpdate = uint40(block.timestamp);

        emit PairAdded(pairId, initialPrice);
    }

    function setPairActive(bytes32 pairId, bool active) external onlyOwner {
        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (active && pair.price == 0) revert ErrZeroPrice();
        pair.active = active;
        emit PairActiveChanged(pairId, active);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function claimFees(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ErrZeroAddress();
        if (amount == 0) revert ErrZeroAmount();
        if (amount > accumulatedFees) revert ErrInsufficientFees();

        accumulatedFees -= amount;
        totalLiquidity -= amount;
        baseAsset.safeTransfer(to, amount);

        emit FeesClaimed(to, amount);
    }

    function updatePrice(bytes32 pairId, uint256 newPrice) external onlyOperator {
        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();
        if (newPrice == 0) revert ErrZeroPrice();

        _applyFunding(pairId);

        uint256 oldPrice = pair.price;
        pair.price = newPrice;

        emit PriceUpdated(pairId, oldPrice, newPrice);
    }

    function updateFundingRate(bytes32 pairId, int256 newRate) external onlyOperator {
        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();
        if (newRate > MAX_ABS_FUNDING_RATE || newRate < -MAX_ABS_FUNDING_RATE) revert ErrFundingRateTooHigh();

        _applyFunding(pairId);

        int256 oldRate = pair.fundingRate;
        pair.fundingRate = newRate;

        emit FundingRateUpdated(pairId, oldRate, newRate);
    }

    function liquidate(address user, bytes32 pairId)
        external
        onlyOperator
        nonReentrant
        whenNotPaused
    {
        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();

        Position storage pos = positions[user][pairId];
        if (pos.size == 0) revert ErrPositionNotFound();

        _applyFunding(pairId);
        int256 pnl = _unrealizedPnL(user, pairId);
        _settle(user, pairId);

        uint256 notional = pos.size * pair.price / PRECISION;
        uint256 maintenanceMargin = notional * MAINTENANCE_MARGIN_RATIO / PRECISION;
        if (pos.margin >= maintenanceMargin) revert ErrNotLiquidatable();

        uint256 bounty = notional * LIQUIDATION_PENALTY / PRECISION;
        if (bounty > pos.margin) bounty = pos.margin;
        uint256 remaining = pos.margin - bounty;

        bool wasLong = pos.isLong;
        uint256 closedSize = pos.size;

        pos.size = 0;
        pos.margin = 0;

        if (wasLong) {
            pair.longOI -= closedSize;
        } else {
            pair.shortOI -= closedSize;
        }

        if (bounty > 0) freeBalance[msg.sender] += bounty;
        if (remaining > 0) freeBalance[user] += remaining;

        delete positions[user][pairId];

        emit PositionLiquidated(user, pairId, msg.sender, closedSize, pnl, bounty);
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ErrZeroAmount();

        freeBalance[msg.sender] += amount;
        totalLiquidity += amount;

        baseAsset.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ErrZeroAmount();
        if (freeBalance[msg.sender] < amount) revert ErrInsufficientBalance();

        freeBalance[msg.sender] -= amount;
        totalLiquidity -= amount;

        baseAsset.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    function openPosition(
        bytes32 pairId,
        bool isLong,
        uint256 size,
        uint256 marginAmount
    ) external nonReentrant whenNotPaused {
        if (size == 0 || marginAmount == 0) revert ErrZeroAmount();

        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();
        if (pair.price == 0) revert ErrZeroPrice();

        _applyFunding(pairId);

        Position storage pos = positions[msg.sender][pairId];
        if (pos.size > 0) {
            if (pos.isLong != isLong) revert ErrOppositeDirection();
            _settle(msg.sender, pairId);
        }

        uint256 notional = size * pair.price / PRECISION;
        uint256 fee = notional * TRADING_FEE / PRECISION;

        if (freeBalance[msg.sender] < marginAmount + fee) revert ErrInsufficientBalance();

        freeBalance[msg.sender] -= marginAmount + fee;
        accumulatedFees += fee;

        pos.isLong = isLong;
        pos.size += size;
        pos.margin += marginAmount;
        pos.entryPrice = pair.price;
        pos.entryFundingIndex = _currentFundingIndex(pairId);

        uint256 totalNotional = pos.size * pair.price / PRECISION;
        uint256 requiredMargin = totalNotional * PRECISION / MAX_LEVERAGE;
        if (pos.margin < requiredMargin) revert ErrExcessiveLeverage();

        if (isLong) {
            pair.longOI += size;
        } else {
            pair.shortOI += size;
        }

        emit PositionOpened(msg.sender, pairId, isLong, size, marginAmount, pair.price);
    }

    function closePosition(bytes32 pairId, uint256 sizeToClose)
        external
        nonReentrant
        whenNotPaused
    {
        if (sizeToClose == 0) revert ErrZeroAmount();

        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();

        Position storage pos = positions[msg.sender][pairId];
        if (pos.size == 0) revert ErrPositionNotFound();
        if (sizeToClose > pos.size) revert ErrExcessiveSize();

        _applyFunding(pairId);

        int256 pnl = _unrealizedPnL(msg.sender, pairId);
        uint256 originalSize = pos.size;

        _settle(msg.sender, pairId);

        uint256 closeNotional = sizeToClose * pair.price / PRECISION;
        uint256 fee = closeNotional * TRADING_FEE / PRECISION;
        uint256 marginPortion = pos.margin * sizeToClose / originalSize;

        if (fee > marginPortion) revert ErrInsufficientMargin();

        uint256 returnAmount = marginPortion - fee;

        pos.size -= sizeToClose;
        pos.margin -= marginPortion;

        if (pos.isLong) {
            pair.longOI -= sizeToClose;
        } else {
            pair.shortOI -= sizeToClose;
        }

        freeBalance[msg.sender] += returnAmount;
        accumulatedFees += fee;

        int256 realizedPnL = (pnl * int256(sizeToClose)) / int256(originalSize);

        if (pos.size == 0) {
            delete positions[msg.sender][pairId];
        }

        emit PositionClosed(msg.sender, pairId, sizeToClose, pair.price, realizedPnL, fee);
    }

    function addMargin(bytes32 pairId, uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        if (amount == 0) revert ErrZeroAmount();

        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();

        Position storage pos = positions[msg.sender][pairId];
        if (pos.size == 0) revert ErrPositionNotFound();
        if (freeBalance[msg.sender] < amount) revert ErrInsufficientBalance();

        _applyFunding(pairId);
        _settle(msg.sender, pairId);

        freeBalance[msg.sender] -= amount;
        pos.margin += amount;

        emit MarginAdded(msg.sender, pairId, amount);
    }

    function removeMargin(bytes32 pairId, uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        if (amount == 0) revert ErrZeroAmount();

        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) revert ErrPairNotFound();
        if (!pair.active) revert ErrPairNotActive();

        Position storage pos = positions[msg.sender][pairId];
        if (pos.size == 0) revert ErrPositionNotFound();

        _applyFunding(pairId);
        _settle(msg.sender, pairId);

        if (amount > pos.margin) revert ErrInsufficientMargin();

        uint256 newMargin = pos.margin - amount;
        uint256 notional = pos.size * pair.price / PRECISION;
        uint256 requiredMargin = notional * PRECISION / MAX_LEVERAGE;
        uint256 maintenanceMargin = notional * MAINTENANCE_MARGIN_RATIO / PRECISION;

        if (newMargin < requiredMargin) revert ErrExcessiveLeverage();
        if (newMargin < maintenanceMargin) revert ErrInsufficientMargin();

        pos.margin = newMargin;
        freeBalance[msg.sender] += amount;

        emit MarginRemoved(msg.sender, pairId, amount);
    }

    function pairExists(bytes32 pairId) external view returns (bool) {
        return pairs[pairId].lastFundingUpdate != 0;
    }

    function getPosition(address user, bytes32 pairId)
        external
        view
        returns (
            bool isLong,
            uint256 size,
            uint256 margin,
            uint256 entryPrice,
            int256 entryFundingIndex
        )
    {
        Position storage pos = positions[user][pairId];
        return (pos.isLong, pos.size, pos.margin, pos.entryPrice, pos.entryFundingIndex);
    }

    function getPair(bytes32 pairId)
        external
        view
        returns (
            bool active,
            uint256 price,
            int256 fundingRate,
            int256 fundingIndex,
            uint256 longOI,
            uint256 shortOI,
            uint40 lastFundingUpdate
        )
    {
        Pair storage pair = pairs[pairId];
        return (
            pair.active,
            pair.price,
            pair.fundingRate,
            pair.fundingIndex,
            pair.longOI,
            pair.shortOI,
            pair.lastFundingUpdate
        );
    }

    function getUnrealizedPnL(address user, bytes32 pairId)
        external
        view
        returns (int256)
    {
        return _unrealizedPnL(user, pairId);
    }

    function getEquity(address user, bytes32 pairId)
        external
        view
        returns (int256)
    {
        return int256(positions[user][pairId].margin) + _unrealizedPnL(user, pairId);
    }

    function getLeverage(address user, bytes32 pairId)
        external
        view
        returns (uint256)
    {
        Position storage pos = positions[user][pairId];
        if (pos.size == 0 || pos.margin == 0) return 0;

        uint256 notional = pos.size * pairs[pairId].price / PRECISION;
        return notional * PRECISION / pos.margin;
    }

    function getHealthFactor(address user, bytes32 pairId)
        external
        view
        returns (uint256)
    {
        Position storage pos = positions[user][pairId];
        if (pos.size == 0) return type(uint256).max;

        Pair storage pair = pairs[pairId];
        uint256 notional = pos.size * pair.price / PRECISION;
        uint256 maintenanceMargin = notional * MAINTENANCE_MARGIN_RATIO / PRECISION;
        if (maintenanceMargin == 0) return type(uint256).max;

        int256 equity = int256(pos.margin) + _unrealizedPnL(user, pairId);
        if (equity <= 0) return 0;

        return uint256(equity) * PRECISION / maintenanceMargin;
    }

    function isLiquidatable(address user, bytes32 pairId)
        external
        view
        returns (bool)
    {
        Pair storage pair = pairs[pairId];
        Position storage pos = positions[user][pairId];
        if (pos.size == 0 || pair.price == 0) return false;

        uint256 notional = pos.size * pair.price / PRECISION;
        uint256 maintenanceMargin = notional * MAINTENANCE_MARGIN_RATIO / PRECISION;
        int256 equity = int256(pos.margin) + _unrealizedPnL(user, pairId);

        return equity < int256(maintenanceMargin);
    }

    function totalOpenInterest(bytes32 pairId) external view returns (uint256) {
        Pair storage pair = pairs[pairId];
        return pair.longOI + pair.shortOI;
    }

    function _currentFundingIndex(bytes32 pairId) internal view returns (int256) {
        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) return int256(FUNDING_PRECISION);
        if (block.timestamp == pair.lastFundingUpdate) return pair.fundingIndex;

        uint256 elapsed = block.timestamp - pair.lastFundingUpdate;
        return pair.fundingIndex + (int256(elapsed) * pair.fundingRate) / int256(FUNDING_PRECISION);
    }

    function _applyFunding(bytes32 pairId) internal {
        Pair storage pair = pairs[pairId];
        if (pair.lastFundingUpdate == 0) {
            pair.lastFundingUpdate = uint40(block.timestamp);
            return;
        }
        if (block.timestamp == pair.lastFundingUpdate) return;

        uint256 elapsed = block.timestamp - pair.lastFundingUpdate;
        pair.fundingIndex += (int256(elapsed) * pair.fundingRate) / int256(FUNDING_PRECISION);
        pair.lastFundingUpdate = uint40(block.timestamp);
    }

    function _unrealizedPnL(address user, bytes32 pairId)
        internal
        view
        returns (int256)
    {
        Pair storage pair = pairs[pairId];
        Position storage pos = positions[user][pairId];
        if (pos.size == 0 || pos.entryPrice == 0) return 0;

        int256 pricePnL;
        if (pos.isLong) {
            pricePnL =
                (int256(pos.size) * (int256(pair.price) - int256(pos.entryPrice))) /
                int256(pos.entryPrice);
        } else {
            pricePnL =
                (int256(pos.size) * (int256(pos.entryPrice) - int256(pair.price))) /
                int256(pos.entryPrice);
        }

        int256 fundingDelta = _currentFundingIndex(pairId) - pos.entryFundingIndex;
        int256 fundingPnL = (int256(pos.size) * fundingDelta) / int256(FUNDING_PRECISION);

        if (pos.isLong) {
            fundingPnL = -fundingPnL;
        }

        return pricePnL + fundingPnL;
    }

    function _settle(address user, bytes32 pairId) internal returns (int256 pnl) {
        Pair storage pair = pairs[pairId];
        Position storage pos = positions[user][pairId];

        pnl = _unrealizedPnL(user, pairId);

        if (pnl >= 0) {
            pos.margin += uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            pos.margin = pos.margin > loss ? pos.margin - loss : 0;
        }

        pos.entryPrice = pair.price;
        pos.entryFundingIndex = _currentFundingIndex(pairId);
    }
}
