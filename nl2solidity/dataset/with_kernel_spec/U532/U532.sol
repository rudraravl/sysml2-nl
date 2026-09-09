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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
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
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/// @title PerpetualFutures
/// @notice Manages collateral deposits and perpetual futures positions with up to 50x leverage.
///         A designated operator pushes oracle prices, sets funding rates, and liquidates
///         undercollateralized positions. All position opening and closing trades are
///         charged a flat 0.05% fee on the notional value.
contract PerpetualFutures is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ------------------------------------------------------------------ */
    /*                             Constants                               */
    /* ------------------------------------------------------------------ */

    /// @dev Fixed-point base unit.
    uint256 public constant WAD = 1e18;

    /// @dev Maximum allowed leverage (50x).
    uint256 public constant MAX_LEVERAGE = 50;

    /// @dev Minimum allowed leverage (1x).
    uint256 public constant MIN_LEVERAGE = 1;

    /// @dev Trade fee applied on open and close (0.05%).
    uint256 public constant FEE_RATE = 5e14; // 0.0005 * 1e18

    /// @dev Fraction of remaining equity awarded to the liquidator (operator).
    uint256 public constant LIQUIDATION_BOUNTY = 5e16; // 0.05 * 1e18

    /* ------------------------------------------------------------------ */
    /*                              Storage                                */
    /* ------------------------------------------------------------------ */

    /// @notice Collateral token held in escrow.
    IERC20 public immutable collateralToken;

    /// @notice Address authorized to push prices, set funding rates, and liquidate.
    address public operator;

    /// @notice Last oracle price in collateral-per-asset terms (WAD).
    uint256 public oraclePrice;

    /// @notice Per-second funding rate (WAD). Positive means longs pay shorts.
    uint256 public fundingRate;

    /// @notice Maintenance margin ratio (WAD). Position is liquidatable when
    ///         equity falls below notional * maintenanceMarginRatio.
    uint256 public maintenanceMarginRatio;

    struct Position {
        uint256 size;            // notional size in asset units (WAD)
        uint256 entryPrice;      // price at open (WAD)
        uint256 leverage;        // leverage used (integer multiplier), e.g. 10 = 10x
        uint256 margin;          // collateral locked for this position (WAD)
        bool isShort;            // true => short, false => long
        uint256 lastFundingTime; // last time funding was applied to this position
    }

    /// @notice Free (unlocked) collateral balances per account.
    mapping(address => uint256) public balances;

    /// @notice Open positions per account. One position per account.
    mapping(address => Position) public positions;

    /* ------------------------------------------------------------------ */
    /*                               Events                                */
    /* ------------------------------------------------------------------ */

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        bool isShort,
        uint256 size,
        uint256 entryPrice,
        uint256 leverage,
        uint256 margin,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        bool isShort,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 fee,
        uint256 returned
    );
    event LeverageModified(address indexed user, uint256 oldLeverage, uint256 newLeverage);
    event PositionLiquidated(
        address indexed user,
        address indexed liquidator,
        bool isShort,
        uint256 size,
        uint256 price,
        uint256 bounty
    );
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event FundingRateUpdated(uint256 oldRate, uint256 newRate);
    event FundingApplied(address indexed user, int256 fundingPayment);
    event MaintenanceMarginUpdated(uint256 oldRatio, uint256 newRatio);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /* ------------------------------------------------------------------ */
    /*                              Errors                                 */
    /* ------------------------------------------------------------------ */

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error PositionAlreadyOpen();
    error NoOpenPosition();
    error LeverageInvalid();
    error InsufficientMargin();
    error NotOperator();
    error PriceNotSet();
    error PositionSafe();
    error InvalidParameter();

    /* ------------------------------------------------------------------ */
    /*                             Modifiers                               */
    /* ------------------------------------------------------------------ */

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /* ------------------------------------------------------------------ */
    /*                            Constructor                              */
    /* ------------------------------------------------------------------ */

    constructor(
        address _collateralToken,
        address _operator,
        uint256 _maintenanceMarginRatio
    ) Ownable(msg.sender) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_maintenanceMarginRatio == 0 || _maintenanceMarginRatio > WAD) {
            revert InvalidParameter();
        }
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        maintenanceMarginRatio = _maintenanceMarginRatio;
    }

    /* ------------------------------------------------------------------ */
    /*                       Operator configuration                        */
    /* ------------------------------------------------------------------ */

    /// @notice Transfers operator privileges to a new address. Only owner.
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    /// @notice Pushes a new oracle price. Only callable by the operator.
    function updatePrice(uint256 _price) external onlyOperator {
        if (_price == 0) revert InvalidParameter();
        uint256 old = oraclePrice;
        oraclePrice = _price;
        emit PriceUpdated(old, _price);
    }

    /// @notice Sets the per-second funding rate. Only callable by the operator.
    function setFundingRate(uint256 _rate) external onlyOperator {
        uint256 old = fundingRate;
        fundingRate = _rate;
        emit FundingRateUpdated(old, _rate);
    }

    /// @notice Sets the maintenance margin ratio. Only callable by the operator.
    function setMaintenanceMarginRatio(uint256 _ratio) external onlyOperator {
        if (_ratio == 0 || _ratio > WAD) revert InvalidParameter();
        uint256 old = maintenanceMarginRatio;
        maintenanceMarginRatio = _ratio;
        emit MaintenanceMarginUpdated(old, _ratio);
    }

    /* ------------------------------------------------------------------ */
    /*                          Deposit / Withdraw                         */
    /* ------------------------------------------------------------------ */

    /// @notice Deposits collateral into the caller's free balance.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        balances[msg.sender] += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    /// @notice Withdraws free collateral from the caller's balance.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /*                            Position actions                         */
    /* ------------------------------------------------------------------ */

    /// @notice Opens a new position. Reverts if a position is already open.
    /// @param size     Notional size in asset units (WAD).
    /// @param leverage Desired leverage (integer multiplier). Must be in [1, 50].
    /// @param isShort  Direction: true => short, false => long.
    function openPosition(
        uint256 size,
        uint256 leverage,
        bool isShort
    ) external nonReentrant {
        if (size == 0) revert ZeroAmount();
        if (positions[msg.sender].size != 0) revert PositionAlreadyOpen();
        if (leverage < MIN_LEVERAGE || leverage > MAX_LEVERAGE) revert LeverageInvalid();
        if (oraclePrice == 0) revert PriceNotSet();

        _applyFunding(msg.sender);

        uint256 notional = (size * oraclePrice) / WAD;
        uint256 margin = notional / leverage;
        uint256 fee = (notional * FEE_RATE) / WAD;
        uint256 total = margin + fee;

        if (balances[msg.sender] < total) revert InsufficientBalance();

        balances[msg.sender] -= total;

        positions[msg.sender] = Position({
            size: size,
            entryPrice: oraclePrice,
            leverage: leverage,
            margin: margin,
            isShort: isShort,
            lastFundingTime: block.timestamp
        });

        emit PositionOpened(msg.sender, isShort, size, oraclePrice, leverage, margin, fee);
    }

    /// @notice Closes the caller's open position at the current oracle price.
    function closePosition() external nonReentrant {
        Position storage p = positions[msg.sender];
        if (p.size == 0) revert NoOpenPosition();
        if (oraclePrice == 0) revert PriceNotSet();

        _applyFunding(msg.sender);

        uint256 currentPrice = oraclePrice;
        int256 pnl = _pnlCollateral(p, currentPrice);
        uint256 notional = (p.size * currentPrice) / WAD;
        uint256 fee = (notional * FEE_RATE) / WAD;

        int256 returned = int256(p.margin) + pnl - int256(fee);
        if (returned < 0) returned = 0;
        uint256 returnedUint = uint256(returned);

        balances[msg.sender] += returnedUint;

        emit PositionClosed(
            msg.sender,
            p.isShort,
            p.size,
            currentPrice,
            pnl,
            fee,
            returnedUint
        );

        delete positions[msg.sender];
    }

    /// @notice Adjusts the leverage on the caller's open position. The position
    ///         must remain sufficiently margined at the new leverage.
    function modifyLeverage(uint256 newLeverage) external nonReentrant {
        Position storage p = positions[msg.sender];
        if (p.size == 0) revert NoOpenPosition();
        if (newLeverage < MIN_LEVERAGE || newLeverage > MAX_LEVERAGE) {
            revert LeverageInvalid();
        }
        if (oraclePrice == 0) revert PriceNotSet();

        _applyFunding(msg.sender);

        uint256 notional = (p.size * oraclePrice) / WAD;
        uint256 requiredMargin = notional / newLeverage;
        if (p.margin < requiredMargin) revert InsufficientMargin();

        uint256 oldLeverage = p.leverage;
        p.leverage = newLeverage;

        emit LeverageModified(msg.sender, oldLeverage, newLeverage);
    }

    /* ------------------------------------------------------------------ */
    /*                              Liquidation                            */
    /* ------------------------------------------------------------------ */

    /// @notice Liquidates an unsafe position. Callable only by the operator.
    /// @dev   A position is unsafe when equity < notional * maintenance ratio.
    function liquidate(address user) external onlyOperator nonReentrant {
        Position storage p = positions[user];
        if (p.size == 0) revert NoOpenPosition();
        if (oraclePrice == 0) revert PriceNotSet();

        _applyFunding(user);

        uint256 currentPrice = oraclePrice;
        int256 pnl = _pnlCollateral(p, currentPrice);
        int256 equity = int256(p.margin) + pnl;
        uint256 notional = (p.size * currentPrice) / WAD;
        uint256 maintenance = (notional * maintenanceMarginRatio) / WAD;

        if (equity >= int256(maintenance)) revert PositionSafe();

        uint256 equityUint = equity > 0 ? uint256(equity) : 0;
        uint256 bounty = (equityUint * LIQUIDATION_BOUNTY) / WAD;

        // Award the bounty to the operator (liquidator).
        balances[operator] += bounty;
        // Return any residual equity to the user being liquidated.
        if (equityUint > bounty) {
            balances[user] += (equityUint - bounty);
        }

        emit PositionLiquidated(
            user,
            operator,
            p.isShort,
            p.size,
            currentPrice,
            bounty
        );

        delete positions[user];
    }

    /* ------------------------------------------------------------------ */
    /*                             Funding logic                           */
    /* ------------------------------------------------------------------ */

    /// @dev Accrues funding on a user's open position based on elapsed time.
    ///      Positive fundingRate: longs pay, shorts receive. Negative reverses.
    function _applyFunding(address user) internal {
        Position storage p = positions[user];
        if (p.size == 0) return;

        uint256 elapsed = block.timestamp - p.lastFundingTime;
        if (elapsed == 0) return;

        int256 fundingPayment = int256((p.size * fundingRate * elapsed) / WAD);
        if (fundingPayment == 0) {
            p.lastFundingTime = block.timestamp;
            return;
        }

        if (p.isShort) {
            // Shorts receive positive funding.
            p.margin += uint256(fundingPayment);
        } else {
            // Longs pay positive funding.
            if (fundingPayment < int256(p.margin)) {
                p.margin -= uint256(fundingPayment);
            } else {
                p.margin = 0;
            }
        }

        p.lastFundingTime = block.timestamp;
        emit FundingApplied(
            user,
            p.isShort ? fundingPayment : -fundingPayment
        );
    }

    /* ------------------------------------------------------------------ */
    /*                          View / accounting                         */
    /* ------------------------------------------------------------------ */

    /// @dev Computes unrealized PnL in collateral terms for a position
    ///      valued at `price`.
    function _pnlCollateral(
        Position storage p,
        uint256 price
    ) internal view returns (int256) {
        int256 diff;
        if (p.isShort) {
            diff = int256(p.entryPrice) - int256(price);
        } else {
            diff = int256(price) - int256(p.entryPrice);
        }
        return (diff * int256(p.size)) / int256(WAD);
    }

    /// @notice Returns the unrealized PnL for an account's open position.
    function unrealizedPnL(address user) external view returns (int256) {
        Position storage p = positions[user];
        if (p.size == 0) return 0;
        return _pnlCollateral(p, oraclePrice);
    }

    /// @notice Returns the equity of an account's open position
    ///         (margin + unrealized PnL).
    function positionEquity(address user) external view returns (int256) {
        Position storage p = positions[user];
        if (p.size == 0) return 0;
        return int256(p.margin) + _pnlCollateral(p, oraclePrice);
    }

    /// @notice Returns the notional value of an account's open position
    ///         denominated in collateral, valued at the current oracle price.
    function positionNotional(address user) external view returns (uint256) {
        Position storage p = positions[user];
        if (p.size == 0) return 0;
        return (p.size * oraclePrice) / WAD;
    }

    /// @notice Returns the total account value: free balance plus position equity.
    function totalAccountValue(address user) external view returns (int256) {
        Position storage p = positions[user];
        int256 equity = int256(balances[user]);
        if (p.size != 0) {
            equity += int256(p.margin) + _pnlCollateral(p, oraclePrice);
        }
        return equity;
    }

    /// @notice Returns the open position for an account.
    function getPosition(
        address user
    )
        external
        view
        returns (
            uint256 size,
            uint256 entryPrice,
            uint256 leverage,
            uint256 margin,
            bool isShort,
            uint256 lastFundingTime
        )
    {
        Position storage p = positions[user];
        return (
            p.size,
            p.entryPrice,
            p.leverage,
            p.margin,
            p.isShort,
            p.lastFundingTime
        );
    }
}
