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

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(bytes32 => bytes32) private _roleAdmin;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        bytes32 admin = _roleAdmin[role];
        return admin == bytes32(0) ? DEFAULT_ADMIN_ROLE : admin;
    }

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "AccessControl: can only renounce for self");
        _revokeRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roleAdmin[role] = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
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

contract PerpetualExchange is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant MIN_MARGIN_RATIO_DEFAULT = 1e17;      // 10%
    uint256 public constant TRADING_FEE_DEFAULT = 5e14;           // 0.05%
    uint256 public constant MAX_LEVERAGE_DEFAULT = 10e18;         // 10x
    uint256 public constant LIQUIDATION_THRESHOLD_DEFAULT = 5e16; // 5%
    uint256 public constant LIQUIDATION_PENALTY_DEFAULT = 5e16;   // 5% of position size

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable collateralToken;
    address public immutable priceOracle;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Position {
        uint256 size;             // notional size in WAD
        uint256 entryPrice;       // entry price in WAD
        uint256 margin;           // collateral locked for this position
        int256 entryFundingIndex; // funding index at position open
        bool isLong;
        bool isOpen;
    }

    struct Account {
        uint256 freeCollateral;   // collateral not locked in a position
    }

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => Position) public positions;
    mapping(address => Account) public accounts;

    uint256 public maxLeverage;
    uint256 public minMarginRatio;
    uint256 public tradingFeeBps;       // fee in WAD (e.g. 5e14 = 0.05%)
    uint256 public liquidationThreshold; // equity / size below this => liquidatable
    uint256 public liquidationPenalty;    // portion of position size awarded to liquidator

    int256 public fundingRate;          // per-second rate in WAD; positive => longs pay shorts
    int256 public fundingIndex;         // cumulative funding index
    uint256 public lastFundingUpdate;   // timestamp of last funding application

    bool public paused;
    uint256 public protocolFees;        // accumulated trading fees
    uint256 public totalCollateral;     // total collateral held (informational)

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        bool isLong,
        uint256 size,
        uint256 entryPrice,
        uint256 margin,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        bool isLong,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        int256 fundingPayment,
        uint256 fee
    );
    event PositionLiquidated(
        address indexed user,
        address indexed liquidator,
        bool isLong,
        uint256 size,
        uint256 price,
        uint256 liquidatorReward
    );
    event FundingUpdated(int256 fundingIndex, int256 fundingRate, uint256 lastUpdate);
    event ConfigUpdated(bytes32 indexed parameter, uint256 value);
    event TradingPaused();
    event TradingResumed();
    event FeesWithdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error TradingIsPaused();
    error InsufficientFreeCollateral();
    error PositionNotOpen();
    error PositionAlreadyOpen();
    error ExceedsMaxLeverage();
    error BelowMinMargin();
    error NotLiquidatable();
    error InvalidPrice();
    error InvalidParameter();
    error InsufficientMarginForFee();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _collateralToken, address _priceOracle) {
        require(_collateralToken != address(0), InvalidParameter());
        require(_priceOracle != address(0), InvalidParameter());

        collateralToken = IERC20(_collateralToken);
        priceOracle = _priceOracle;

        maxLeverage = MAX_LEVERAGE_DEFAULT;
        minMarginRatio = MIN_MARGIN_RATIO_DEFAULT;
        tradingFeeBps = TRADING_FEE_DEFAULT;
        liquidationThreshold = LIQUIDATION_THRESHOLD_DEFAULT;
        liquidationPenalty = LIQUIDATION_PENALTY_DEFAULT;

        lastFundingUpdate = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        require(!paused, TradingIsPaused());
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           FUNDING LOGIC
    //////////////////////////////////////////////////////////////*/

    function _applyFunding() internal {
        // Avoid strict equality on elapsed time; guard against non-positive deltas.
        if (block.timestamp <= lastFundingUpdate) return;

        uint256 elapsed = block.timestamp - lastFundingUpdate;
        fundingIndex += fundingRate * int256(elapsed);
        lastFundingUpdate = block.timestamp;

        emit FundingUpdated(fundingIndex, fundingRate, lastFundingUpdate);
    }

    function applyFunding() external {
        _applyFunding();
    }

    /*//////////////////////////////////////////////////////////////
                           PNL / EQUITY
    //////////////////////////////////////////////////////////////*/

    function _getPnL(Position memory pos, uint256 price) internal pure returns (int256) {
        if (pos.isLong) {
            return
                int256(pos.size) *
                (int256(price) - int256(pos.entryPrice)) /
                int256(pos.entryPrice);
        } else {
            return
                int256(pos.size) *
                (int256(pos.entryPrice) - int256(price)) /
                int256(pos.entryPrice);
        }
    }

    function _getFundingPayment(Position memory pos) internal view returns (int256) {
        int256 fundingDiff = fundingIndex - pos.entryFundingIndex;
        int256 payment = (int256(pos.size) * fundingDiff) / int256(WAD);
        return pos.isLong ? payment : -payment;
    }

    function _getEquity(Position memory pos, uint256 price) internal view returns (int256) {
        int256 pnl = _getPnL(pos, price);
        int256 fundingPayment = _getFundingPayment(pos);
        return int256(pos.margin) + pnl - fundingPayment;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, ZeroAmount());

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        accounts[msg.sender].freeCollateral += amount;
        totalCollateral += amount;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, ZeroAmount());
        require(accounts[msg.sender].freeCollateral >= amount, InsufficientFreeCollateral());

        accounts[msg.sender].freeCollateral -= amount;
        totalCollateral -= amount;
        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           TRADING
    //////////////////////////////////////////////////////////////*/

    function openPosition(bool isLong, uint256 size, uint256 margin)
        external
        nonReentrant
        whenNotPaused
    {
        require(size > 0, ZeroAmount());
        require(margin > 0, ZeroAmount());

        Position storage pos = positions[msg.sender];
        require(!pos.isOpen, PositionAlreadyOpen());

        require(margin >= (size * minMarginRatio) / WAD, BelowMinMargin());
        require(size <= (margin * maxLeverage) / WAD, ExceedsMaxLeverage());

        uint256 fee = (size * tradingFeeBps) / WAD;
        require(accounts[msg.sender].freeCollateral >= margin + fee, InsufficientFreeCollateral());

        _applyFunding();

        uint256 price = IPriceOracle(priceOracle).getPrice();
        require(price > 0, InvalidPrice());

        accounts[msg.sender].freeCollateral -= (margin + fee);
        protocolFees += fee;

        pos.size = size;
        pos.entryPrice = price;
        pos.margin = margin;
        pos.entryFundingIndex = fundingIndex;
        pos.isLong = isLong;
        pos.isOpen = true;

        emit PositionOpened(msg.sender, isLong, size, price, margin, fee);
    }

    function closePosition() external nonReentrant whenNotPaused {
        Position storage pos = positions[msg.sender];
        require(pos.isOpen, PositionNotOpen());

        _applyFunding();

        uint256 price = IPriceOracle(priceOracle).getPrice();
        require(price > 0, InvalidPrice());

        Position memory posMem = pos;

        int256 pnl = _getPnL(posMem, price);
        int256 fundingPayment = _getFundingPayment(posMem);
        int256 netPnl = pnl - fundingPayment;

        uint256 fee = (posMem.size * tradingFeeBps) / WAD;

        int256 equity = int256(posMem.margin) + netPnl;
        uint256 returnAmount = equity > 0 ? uint256(equity) : 0;

        require(returnAmount >= fee, InsufficientMarginForFee());
        returnAmount -= fee;
        protocolFees += fee;

        _clearPosition(pos);
        accounts[msg.sender].freeCollateral += returnAmount;

        emit PositionClosed(
            msg.sender,
            posMem.isLong,
            posMem.size,
            price,
            netPnl,
            fundingPayment,
            fee
        );
    }

    function liquidate(address user) external nonReentrant whenNotPaused {
        Position storage pos = positions[user];
        require(pos.isOpen, PositionNotOpen());

        _applyFunding();

        uint256 price = IPriceOracle(priceOracle).getPrice();
        require(price > 0, InvalidPrice());

        Position memory posMem = pos;

        int256 equity = _getEquity(posMem, price);
        uint256 equityUint = equity > 0 ? uint256(equity) : 0;

        require(equityUint < (posMem.size * liquidationThreshold) / WAD, NotLiquidatable());

        uint256 penalty = (posMem.size * liquidationPenalty) / WAD;
        uint256 liquidatorReward = equityUint + penalty;

        if (liquidatorReward > posMem.margin) {
            liquidatorReward = posMem.margin;
        }

        uint256 remaining = posMem.margin - liquidatorReward;

        _clearPosition(pos);

        if (remaining > 0) {
            accounts[user].freeCollateral += remaining;
        }

        if (liquidatorReward > 0) {
            collateralToken.safeTransfer(msg.sender, liquidatorReward);
            totalCollateral -= liquidatorReward;
        }

        emit PositionLiquidated(
            user,
            msg.sender,
            posMem.isLong,
            posMem.size,
            price,
            liquidatorReward
        );
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _clearPosition(Position storage pos) internal {
        pos.isOpen = false;
        pos.size = 0;
        pos.entryPrice = 0;
        pos.margin = 0;
        pos.entryFundingIndex = 0;
        pos.isLong = false;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPosition(address user)
        external
        view
        returns (
            uint256 size,
            uint256 entryPrice,
            uint256 margin,
            int256 entryFundingIndex,
            bool isLong,
            bool isOpen
        )
    {
        Position memory pos = positions[user];
        return (pos.size, pos.entryPrice, pos.margin, pos.entryFundingIndex, pos.isLong, pos.isOpen);
    }

    function getFreeCollateral(address user) external view returns (uint256) {
        return accounts[user].freeCollateral;
    }

    function getEquity(address user) external view returns (int256) {
        Position memory pos = positions[user];
        int256 free = int256(accounts[user].freeCollateral);
        if (!pos.isOpen) return free;

        uint256 price = IPriceOracle(priceOracle).getPrice();
        return free + _getEquity(pos, price);
    }

    function getPnL(address user) external view returns (int256) {
        Position memory pos = positions[user];
        if (!pos.isOpen) return 0;

        uint256 price = IPriceOracle(priceOracle).getPrice();
        return _getPnL(pos, price);
    }

    function getFundingPayment(address user) external view returns (int256) {
        Position memory pos = positions[user];
        if (!pos.isOpen) return 0;
        return _getFundingPayment(pos);
    }

    function isLiquidatable(address user) external view returns (bool) {
        Position memory pos = positions[user];
        if (!pos.isOpen) return false;

        uint256 price = IPriceOracle(priceOracle).getPrice();
        int256 equity = _getEquity(pos, price);
        uint256 equityUint = equity > 0 ? uint256(equity) : 0;
        return equityUint < (pos.size * liquidationThreshold) / WAD;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        Position memory pos = positions[user];
        // Open positions always have a strictly positive size by construction,
        // so checking the open flag alone is sufficient and avoids a strict
        // equality comparison on the size field.
        if (!pos.isOpen) return type(uint256).max;

        uint256 price = IPriceOracle(priceOracle).getPrice();
        int256 equity = _getEquity(pos, price);
        uint256 equityUint = equity > 0 ? uint256(equity) : 0;
        return (equityUint * WAD) / pos.size;
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFundingRate(int256 _rate) external onlyRole(OPERATOR_ROLE) {
        require(_rate <= 1e16 && _rate >= -1e16, InvalidParameter());
        fundingRate = _rate;
        emit ConfigUpdated("fundingRate", uint256(int256(_rate)));
    }

    function setMaxLeverage(uint256 _maxLeverage) external onlyRole(OPERATOR_ROLE) {
        require(_maxLeverage > 0 && _maxLeverage <= 100e18, InvalidParameter());
        maxLeverage = _maxLeverage;
        emit ConfigUpdated("maxLeverage", _maxLeverage);
    }

    function setMinMarginRatio(uint256 _ratio) external onlyRole(OPERATOR_ROLE) {
        require(_ratio >= 1e16 && _ratio <= WAD, InvalidParameter());
        minMarginRatio = _ratio;
        emit ConfigUpdated("minMarginRatio", _ratio);
    }

    function setTradingFee(uint256 _fee) external onlyRole(OPERATOR_ROLE) {
        require(_fee <= 1e16, InvalidParameter());
        tradingFeeBps = _fee;
        emit ConfigUpdated("tradingFee", _fee);
    }

    function setLiquidationThreshold(uint256 _threshold) external onlyRole(OPERATOR_ROLE) {
        require(_threshold > 0 && _threshold < minMarginRatio, InvalidParameter());
        liquidationThreshold = _threshold;
        emit ConfigUpdated("liquidationThreshold", _threshold);
    }

    function setLiquidationPenalty(uint256 _penalty) external onlyRole(OPERATOR_ROLE) {
        require(_penalty <= 1e17, InvalidParameter());
        liquidationPenalty = _penalty;
        emit ConfigUpdated("liquidationPenalty", _penalty);
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        paused = true;
        emit TradingPaused();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        paused = false;
        emit TradingResumed();
    }

    function withdrawFees(address to) external onlyRole(OPERATOR_ROLE) {
        require(to != address(0), InvalidParameter());
        uint256 amount = protocolFees;
        protocolFees = 0;
        totalCollateral -= amount;
        collateralToken.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }
}
