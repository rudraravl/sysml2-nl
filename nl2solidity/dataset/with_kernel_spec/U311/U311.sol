// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PerpetualExchange {
    // ---------------------------------------------------------------------
    //                              Errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error Unauthorized();
    error ZeroAmount();
    error ZeroSize();
    error PairAlreadyExists();
    error PairNotActive();
    error InsufficientBalance();
    error InsufficientMargin();
    error AboveMaxLeverage();
    error BelowMaintenanceMargin();
    error CannotFlipPosition();
    error PositionNotLiquidatable();
    error InvalidPrice();
    error InvalidLeverage();
    error TransferFailed();

    // ---------------------------------------------------------------------
    //                            Constants
    // ---------------------------------------------------------------------
    uint256 public constant WAD = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant TRADING_FEE_BPS = 5;            // 0.05%
    uint256 public constant MAX_LEVERAGE_CAP = 50e18;       // 50x hard cap
    uint256 public constant LIQUIDATION_PENALTY_BPS = 500;  // 5% of notional

    // ---------------------------------------------------------------------
    //                              Events
    // ---------------------------------------------------------------------
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, address indexed to, uint256 amount);
    event PairAdded(uint256 indexed pairId, string name);
    event PairUpdated(uint256 indexed pairId, uint64 maxLeverage, uint64 fundingRate, uint64 marginRatio);
    event PriceUpdated(uint256 indexed pairId, uint256 price);
    event PositionOpened(address indexed user, uint256 indexed pairId, int256 size, uint256 margin, uint256 entryPrice);
    event PositionClosed(address indexed user, uint256 indexed pairId, int256 size, uint256 exitPrice, uint256 returnedMargin);
    event PositionModified(address indexed user, uint256 indexed pairId, int256 sizeDelta, int256 marginDelta);
    event PositionLiquidated(address indexed user, address indexed liquidator, uint256 indexed pairId, int256 size, uint256 penalty);
    event FundingApplied(address indexed user, uint256 indexed pairId, int256 funding);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------------------------------------------------------------------
    //                              Structs
    // ---------------------------------------------------------------------
    struct TradingPair {
        string name;
        bool active;
        uint64 maxLeverage;             // WAD (e.g. 50e18)
        uint64 fundingRate;             // per-second, WAD
        uint64 maintenanceMarginRatio;  // WAD (e.g. 0.05e18 = 5%)
        uint256 price;                  // WAD
    }

    struct Position {
        int256 size;             // signed base asset size (WAD)
        uint256 margin;          // collateral locked for this position (raw units)
        uint256 entryPrice;      // WAD
        uint256 lastFundingTime; // timestamp
    }

    // ---------------------------------------------------------------------
    //                              State
    // ---------------------------------------------------------------------
    IERC20 public immutable collateralToken;
    address public owner;
    address public operator;

    uint256 public collectedFees;

    mapping(uint256 => TradingPair) public pairs;
    uint256[] public pairList;

    mapping(address => uint256) public balances; // free collateral
    mapping(address => mapping(uint256 => Position)) public positions;

    // ---------------------------------------------------------------------
    //                            Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier pairActive(uint256 pairId) {
        if (!pairs[pairId].active) revert PairNotActive();
        _;
    }

    // ---------------------------------------------------------------------
    //                           Constructor
    // ---------------------------------------------------------------------
    constructor(address _collateralToken, address _operator) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    // ---------------------------------------------------------------------
    //                       Admin / Operator
    // ---------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function addPair(
        uint256 pairId,
        string calldata name,
        uint64 maxLeverage,
        uint64 fundingRate,
        uint64 maintenanceMarginRatio,
        uint256 initialPrice
    ) external onlyOperator {
        if (pairs[pairId].active) revert PairAlreadyExists();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE_CAP) revert InvalidLeverage();
        if (initialPrice == 0) revert InvalidPrice();
        if (maintenanceMarginRatio == 0) revert InvalidPrice();
        pairs[pairId] = TradingPair({
            name: name,
            active: true,
            maxLeverage: maxLeverage,
            fundingRate: fundingRate,
            maintenanceMarginRatio: maintenanceMarginRatio,
            price: initialPrice
        });
        pairList.push(pairId);
        emit PairAdded(pairId, name);
    }

    function updatePairParams(
        uint256 pairId,
        uint64 maxLeverage,
        uint64 fundingRate,
        uint64 maintenanceMarginRatio
    ) external onlyOperator pairActive(pairId) {
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE_CAP) revert InvalidLeverage();
        if (maintenanceMarginRatio == 0) revert InvalidPrice();
        TradingPair storage p = pairs[pairId];
        p.maxLeverage = maxLeverage;
        p.fundingRate = fundingRate;
        p.maintenanceMarginRatio = maintenanceMarginRatio;
        emit PairUpdated(pairId, maxLeverage, fundingRate, maintenanceMarginRatio);
    }

    function updatePrice(uint256 pairId, uint256 newPrice) external onlyOperator pairActive(pairId) {
        if (newPrice == 0) revert InvalidPrice();
        pairs[pairId].price = newPrice;
        emit PriceUpdated(pairId, newPrice);
    }

    function withdrawFees(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > collectedFees) revert InsufficientBalance();
        collectedFees -= amount;
        emit FeesWithdrawn(to, amount);
        if (!collateralToken.transfer(to, amount)) revert TransferFailed();
    }

    function getPairCount() external view returns (uint256) {
        return pairList.length;
    }

    // ---------------------------------------------------------------------
    //                      Deposit / Withdraw collateral
    // ---------------------------------------------------------------------
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        balances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount, address to) external {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        uint256 avail = availableMargin(msg.sender);
        if (amount > avail) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        emit Withdrawn(msg.sender, to, amount);
        if (!collateralToken.transfer(to, amount)) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    //                         View helpers
    // ---------------------------------------------------------------------
    function availableMargin(address user) public view returns (uint256) {
        uint256 bal = balances[user];
        uint256 locked = 0;
        for (uint256 i = 0; i < pairList.length; i++) {
            locked += positions[user][pairList[i]].margin;
        }
        if (locked >= bal) return 0;
        return bal - locked;
    }

    function unrealizedPnL(address user, uint256 pairId) public view returns (int256) {
        Position storage pos = positions[user][pairId];
        if (pos.size <= 0 && pos.size >= 0) return 0;
        int256 priceDiff = int256(pairs[pairId].price) - int256(pos.entryPrice);
        return (pos.size * priceDiff) / int256(WAD);
    }

    function positionValue(address user, uint256 pairId) public view returns (int256) {
        Position storage pos = positions[user][pairId];
        if (pos.size <= 0 && pos.size >= 0) return 0;
        return int256(pos.margin) + unrealizedPnL(user, pairId);
    }

    function notionalValue(address user, uint256 pairId) public view returns (uint256) {
        Position storage pos = positions[user][pairId];
        if (pos.size <= 0 && pos.size >= 0) return 0;
        uint256 absSize = pos.size > 0 ? uint256(pos.size) : uint256(-pos.size);
        return (absSize * pairs[pairId].price) / WAD;
    }

    function maintenanceMargin(address user, uint256 pairId) public view returns (uint256) {
        uint256 notional = notionalValue(user, pairId);
        return (notional * pairs[pairId].maintenanceMarginRatio) / WAD;
    }

    function isLiquidatable(address user, uint256 pairId) public view returns (bool) {
        Position storage pos = positions[user][pairId];
        if (pos.size <= 0 && pos.size >= 0) return false;
        int256 pv = positionValue(user, pairId);
        if (pv <= 0) return true;
        return uint256(pv) < maintenanceMargin(user, pairId);
    }

    function currentLeverage(address user, uint256 pairId) public view returns (uint256) {
        Position storage pos = positions[user][pairId];
        if ((pos.size <= 0 && pos.size >= 0) || pos.margin == 0) return 0;
        uint256 notional = notionalValue(user, pairId);
        return (notional * WAD) / pos.margin;
    }

    // ---------------------------------------------------------------------
    //                            Funding
    // ---------------------------------------------------------------------
    function _applyFunding(address user, uint256 pairId) internal {
        Position storage pos = positions[user][pairId];
        if (pos.size <= 0 && pos.size >= 0) return;
        TradingPair storage p = pairs[pairId];
        if (block.timestamp <= pos.lastFundingTime) return;
        uint256 elapsed = block.timestamp - pos.lastFundingTime;
        // funding = size * price * fundingRate * elapsed / WAD^2  (collateral units)
        // longs (size > 0) pay when fundingRate > 0; shorts receive
        int256 funding = (pos.size
            * int256(p.price)
            * int256(uint256(p.fundingRate))
            * int256(elapsed)) / int256(WAD * WAD);
        int256 newMargin = int256(pos.margin) + funding;
        if (newMargin < 0) {
            pos.margin = 0;
        } else {
            pos.margin = uint256(newMargin);
        }
        pos.lastFundingTime = block.timestamp;
        emit FundingApplied(user, pairId, funding);
    }

    function applyFunding(address user, uint256 pairId) external pairActive(pairId) {
        Position storage pos = positions[user][pairId];
        if (pos.size <= 0 && pos.size >= 0) return;
        _applyFunding(user, pairId);
    }

    // ---------------------------------------------------------------------
    //                       Position modifications
    // ---------------------------------------------------------------------
    function modifyPosition(
        uint256 pairId,
        int256 sizeDelta,
        int256 marginDelta
    ) public pairActive(pairId) {
        // Reject no-op calls without using strict equality on signed inputs.
        if (sizeDelta <= 0 && sizeDelta >= 0 && marginDelta <= 0 && marginDelta >= 0) {
            revert ZeroAmount();
        }

        Position storage pos = positions[msg.sender][pairId];
        TradingPair storage p = pairs[pairId];

        int256 oldSize = pos.size;
        int256 newSize = oldSize + sizeDelta;

        // Disallow position flips within a single call.
        if (oldSize > 0 && sizeDelta < 0 && newSize < 0) revert CannotFlipPosition();
        if (oldSize < 0 && sizeDelta > 0 && newSize > 0) revert CannotFlipPosition();

        // Settle any pending funding before mutating the position.
        if (oldSize > 0 || oldSize < 0) {
            _applyFunding(msg.sender, pairId);
        }

        // Trading fee on the notional being traded (open or close).
        // Compute fee with a single division to avoid divide-before-multiply.
        uint256 absDelta = sizeDelta >= 0 ? uint256(sizeDelta) : uint256(-sizeDelta);
        uint256 notionalDelta = (absDelta * p.price) / WAD;
        uint256 fee = (absDelta * p.price * TRADING_FEE_BPS) / (WAD * BPS_DENOMINATOR);
        collectedFees += fee;

        // Pull extra margin from free balance if requested.
        if (marginDelta > 0) {
            uint256 add = uint256(marginDelta);
            if (add > availableMargin(msg.sender)) revert InsufficientBalance();
            balances[msg.sender] -= add;
            pos.margin += add;
        }

        // Charge the fee from position margin, falling back to free balance.
        if (fee > 0) {
            if (pos.margin >= fee) {
                pos.margin -= fee;
            } else {
                uint256 extra = fee - pos.margin;
                if (extra > availableMargin(msg.sender)) revert InsufficientMargin();
                balances[msg.sender] -= extra;
                pos.margin = 0;
            }
        }

        // ----- Full close -------------------------------------------------
        // Flips are prevented above, so for a long newSize cannot go negative
        // and for a short newSize cannot go positive. Using inequalities here
        // is equivalent to an exact zero check but avoids strict equality.
        if ((oldSize > 0 && newSize <= 0) || (oldSize < 0 && newSize >= 0)) {
            int256 pnl = unrealizedPnL(msg.sender, pairId);
            int256 settled = int256(pos.margin) + pnl;
            uint256 returnAmount = settled > 0 ? uint256(settled) : 0;
            balances[msg.sender] += returnAmount;
            emit PositionClosed(msg.sender, pairId, oldSize, p.price, returnAmount);
            emit PositionModified(msg.sender, pairId, sizeDelta, marginDelta);
            pos.size = 0;
            pos.margin = 0;
            pos.entryPrice = 0;
            pos.lastFundingTime = 0;
            return;
        }

        // ----- New position ----------------------------------------------
        if (oldSize <= 0 && oldSize >= 0) {
            pos.entryPrice = p.price;
            pos.lastFundingTime = block.timestamp;
            pos.size = newSize;
            emit PositionOpened(msg.sender, pairId, newSize, pos.margin, pos.entryPrice);
        }
        // ----- Same-direction increase: weighted-average entry -----------
        else if ((oldSize > 0 && sizeDelta > 0) || (oldSize < 0 && sizeDelta < 0)) {
            uint256 oldAbs = oldSize > 0 ? uint256(oldSize) : uint256(-oldSize);
            uint256 oldNotional = (oldAbs * pos.entryPrice) / WAD;
            uint256 newAbs = newSize > 0 ? uint256(newSize) : uint256(-newSize);
            pos.entryPrice = ((oldNotional + notionalDelta) * WAD) / newAbs;
            pos.size = newSize;
        }
        // ----- Partial reduction (opposite direction, no flip) ----------
        else {
            int256 sign = oldSize > 0 ? int256(1) : int256(-1);
            int256 priceDiff = int256(p.price) - int256(pos.entryPrice);
            int256 closedPnl = (sign * int256(absDelta) * priceDiff) / int256(WAD);
            int256 newMargin = int256(pos.margin) + closedPnl;
            if (newMargin < 0) newMargin = 0;
            pos.margin = uint256(newMargin);
            pos.size = newSize;
            // entry price stays the same for the remaining portion
        }

        // ----- Optional margin release -----------------------------------
        if (marginDelta < 0) {
            uint256 remove = uint256(-marginDelta);
            if (remove > pos.margin) revert InsufficientMargin();
            pos.margin -= remove;
            balances[msg.sender] += remove;
        }

        // ----- Post-trade safety checks ----------------------------------
        _checkLeverage(msg.sender, pairId);
        if (isLiquidatable(msg.sender, pairId)) revert BelowMaintenanceMargin();

        if (oldSize > 0 || oldSize < 0) {
            emit PositionModified(msg.sender, pairId, sizeDelta, marginDelta);
        } else {
            // PositionOpened already emitted above; emit a modification event too
            // so downstream indexers always see a uniform trail of changes.
            emit PositionModified(msg.sender, pairId, sizeDelta, marginDelta);
        }
    }

    function closePosition(uint256 pairId) external {
        int256 size = positions[msg.sender][pairId].size;
        // Require a non-zero position without using strict equality.
        if (!(size > 0 || size < 0)) revert ZeroSize();
        // Pass in the negation of the current size to fully close the position.
        modifyPosition(pairId, -size, 0);
    }

    function _checkLeverage(address user, uint256 pairId) internal view {
        Position storage pos = positions[user][pairId];
        if (pos.size <= 0 && pos.size >= 0) return;
        if (pos.margin == 0) revert AboveMaxLeverage();
        TradingPair storage p = pairs[pairId];
        uint256 absSize = pos.size > 0 ? uint256(pos.size) : uint256(-pos.size);
        uint256 notional = (absSize * p.price) / WAD;
        uint256 maxNotional = (pos.margin * uint256(p.maxLeverage)) / WAD;
        if (notional > maxNotional) revert AboveMaxLeverage();
    }

    // ---------------------------------------------------------------------
    //                           Liquidation
    // ---------------------------------------------------------------------
    function liquidate(address user, uint256 pairId) external onlyOperator pairActive(pairId) {
        Position storage pos = positions[user][pairId];
        if (!(pos.size > 0 || pos.size < 0)) revert ZeroSize();
        if (!isLiquidatable(user, pairId)) revert PositionNotLiquidatable();

        // Settle funding to reflect the most up-to-date margin.
        _applyFunding(user, pairId);

        TradingPair storage p = pairs[pairId];
        int256 pv = positionValue(user, pairId);
        uint256 notional = notionalValue(user, pairId);
        uint256 penalty = (notional * LIQUIDATION_PENALTY_BPS) / BPS_DENOMINATOR;

        int256 oldSize = pos.size;
        uint256 liquidatorReward;

        if (pv <= 0) {
            // Insolvent: liquidator takes whatever margin is left, protocol eats the rest.
            liquidatorReward = pos.margin;
            pos.margin = 0;
        } else {
            uint256 remaining = uint256(pv);
            if (penalty > remaining) penalty = remaining;
            liquidatorReward = penalty;
            // Return the surviving margin to the user's free balance.
            balances[user] += (remaining - penalty);
            pos.margin = 0;
        }

        // Reset the position.
        pos.size = 0;
        pos.entryPrice = 0;
        pos.lastFundingTime = 0;

        if (liquidatorReward > 0) {
            if (!collateralToken.transfer(msg.sender, liquidatorReward)) revert TransferFailed();
        }

        emit PositionLiquidated(user, msg.sender, pairId, oldSize, liquidatorReward);
    }
}
