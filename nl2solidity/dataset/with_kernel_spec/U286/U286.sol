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
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            } else {
                revert("SafeERC20: transfer failed");
            }
        }
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transfer failed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            } else {
                revert("SafeERC20: transferFrom failed");
            }
        }
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transferFrom failed");
        }
    }
}

abstract contract AccessControl {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: missing role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        bytes32 admin = _roles[role].adminRole;
        return admin != bytes32(0) ? admin : DEFAULT_ADMIN_ROLE;
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            if (_roles[role].adminRole == bytes32(0)) {
                _roles[role].adminRole = DEFAULT_ADMIN_ROLE;
            }
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
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
}

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    function _pause() internal {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

contract PerpetualFutures is AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant WAD = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_LEVERAGE = 50;
    uint256 public constant OPEN_FEE_BPS = 10; // 0.1%

    bytes32 private constant PARAM_MAX_POSITION_SIZE = keccak256("maxPositionSize");
    bytes32 private constant PARAM_MAINTENANCE_MARGIN = keccak256("maintenanceMarginBps");
    bytes32 private constant PARAM_LIQUIDATION_FEE = keccak256("liquidationFeeBps");

    IERC20 public immutable collateral;

    struct Position {
        bool isLong;
        uint256 size;        // notional exposure at entry, in WAD
        uint256 entryPrice;  // mark price at open, in WAD
        uint256 margin;      // collateral locked for this position, in WAD
        uint256 openTime;    // timestamp position was opened
    }

    mapping(address => uint256) public collateralBalances;
    mapping(address => Position) public positions;
    uint256 public insurancePool; // collateral reserved for the insurance fund, in WAD
    uint256 public markPrice;     // current mark price, in WAD

    struct SystemParams {
        uint256 fundingRate;          // per-second funding rate, in WAD
        uint256 maxPositionSize;      // maximum notional per position, in WAD
        uint256 maintenanceMarginBps; // maintenance margin ratio, in bps
        uint256 liquidationFeeBps;    // liquidator reward, in bps of notional
    }
    SystemParams public params;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event MarginAdded(address indexed trader, uint256 amount);
    event PositionOpened(
        address indexed trader,
        bool isLong,
        uint256 size,
        uint256 margin,
        uint256 entryPrice,
        uint256 fee
    );
    event PositionClosed(
        address indexed trader,
        bool isLong,
        uint256 size,
        uint256 entryPrice,
        uint256 markPrice,
        int256 pnl
    );
    event Liquidated(
        address indexed trader,
        address indexed liquidator,
        uint256 reward
    );
    event FundingRateUpdated(uint256 rate);
    event MarkPriceUpdated(uint256 price);
    event ParameterUpdated(bytes32 indexed name, uint256 value);

    error ZeroAmount();
    error ZeroAddress();
    error ZeroPrice();
    error PositionAlreadyOpen();
    error NoOpenPosition();
    error InsufficientCollateral();
    error LeverageTooHigh();
    error SizeExceedsMax();
    error PositionSafe();
    error InvalidParameter();

    constructor(address collateral_, address admin_) {
        if (collateral_ == address(0) || admin_ == address(0)) revert ZeroAddress();

        collateral = IERC20(collateral_);
        markPrice = WAD;

        params = SystemParams({
            fundingRate: 0,
            maxPositionSize: 10_000_000 * WAD,
            maintenanceMarginBps: 100, // 1%
            liquidationFeeBps: 50      // 0.5%
        });

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalances[msg.sender] < amount) revert InsufficientCollateral();
        collateralBalances[msg.sender] -= amount;
        collateral.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function openPosition(
        bool isLong,
        uint256 size,
        uint256 marginAmount
    ) external whenNotPaused {
        if (size == 0 || marginAmount == 0) revert ZeroAmount();

        if (positions[msg.sender].size != 0) revert PositionAlreadyOpen();
        if (size > params.maxPositionSize) revert SizeExceedsMax();
        if (size > marginAmount * MAX_LEVERAGE) revert LeverageTooHigh();

        uint256 fee = (size * OPEN_FEE_BPS) / BPS_DENOMINATOR;
        uint256 totalNeeded = marginAmount + fee;
        if (collateralBalances[msg.sender] < totalNeeded) revert InsufficientCollateral();

        collateralBalances[msg.sender] -= totalNeeded;
        insurancePool += fee;

        uint256 entryPrice = markPrice;
        positions[msg.sender] = Position({
            isLong: isLong,
            size: size,
            entryPrice: entryPrice,
            margin: marginAmount,
            openTime: block.timestamp
        });

        emit PositionOpened(msg.sender, isLong, size, marginAmount, entryPrice, fee);
    }

    function addMargin(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (positions[msg.sender].size == 0) revert NoOpenPosition();
        if (collateralBalances[msg.sender] < amount) revert InsufficientCollateral();

        collateralBalances[msg.sender] -= amount;
        positions[msg.sender].margin += amount;

        emit MarginAdded(msg.sender, amount);
    }

    function closePosition() external whenNotPaused {
        _settle(msg.sender, markPrice, false, address(0));
    }

    function liquidate(address trader) external whenNotPaused {
        if (positions[trader].size == 0) revert NoOpenPosition();
        if (!_isUnsafe(trader, markPrice)) revert PositionSafe();
        _settle(trader, markPrice, true, msg.sender);
    }

    function setFundingRate(uint256 rate) external onlyRole(OPERATOR_ROLE) {
        params.fundingRate = rate;
        emit FundingRateUpdated(rate);
    }

    function setMarkPrice(uint256 price) external onlyRole(OPERATOR_ROLE) {
        if (price == 0) revert ZeroPrice();
        markPrice = price;
        emit MarkPriceUpdated(price);
    }

    function setMaxPositionSize(uint256 max) external onlyRole(OPERATOR_ROLE) {
        params.maxPositionSize = max;
        emit ParameterUpdated(PARAM_MAX_POSITION_SIZE, max);
    }

    function setMaintenanceMarginBps(uint256 bps) external onlyRole(OPERATOR_ROLE) {
        if (bps == 0 || bps >= BPS_DENOMINATOR) revert InvalidParameter();
        params.maintenanceMarginBps = bps;
        emit ParameterUpdated(PARAM_MAINTENANCE_MARGIN, bps);
    }

    function setLiquidationFeeBps(uint256 bps) external onlyRole(OPERATOR_ROLE) {
        if (bps >= BPS_DENOMINATOR) revert InvalidParameter();
        params.liquidationFeeBps = bps;
        emit ParameterUpdated(PARAM_LIQUIDATION_FEE, bps);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function pnl(address trader) external view returns (int256) {
        Position storage p = positions[trader];
        if (p.size == 0) return 0;
        return _pnl(p, markPrice);
    }

    function marginRatio(address trader) external view returns (uint256) {
        if (positions[trader].size == 0) return 0;
        return _marginRatio(trader, markPrice);
    }

    function fundingFee(address trader) external view returns (uint256) {
        Position storage p = positions[trader];
        if (p.size == 0) return 0;
        return _fundingFee(p);
    }

    function isUnsafe(address trader) external view returns (bool) {
        if (positions[trader].size == 0) return false;
        return _isUnsafe(trader, markPrice);
    }

    function freeCollateral(address trader) external view returns (uint256) {
        return collateralBalances[trader];
    }

    function getPosition(address trader)
        external
        view
        returns (
            bool isLong,
            uint256 size,
            uint256 entryPrice,
            uint256 margin,
            uint256 openTime
        )
    {
        Position storage p = positions[trader];
        return (p.isLong, p.size, p.entryPrice, p.margin, p.openTime);
    }

    function _settle(
        address trader,
        uint256 mark,
        bool isLiquidation,
        address liquidator
    ) internal {
        Position storage p = positions[trader];
        if (p.size == 0) revert NoOpenPosition();

        int256 positionPnl = _pnl(p, mark);
        uint256 funding = _fundingFee(p);

        int256 net = int256(p.margin) + positionPnl;
        if (p.isLong) {
            net -= int256(funding);
        } else {
            net += int256(funding);
        }

        uint256 payout = net > 0 ? uint256(net) : 0;

        if (payout >= p.margin) {
            uint256 excess = payout - p.margin;
            if (excess > insurancePool) excess = insurancePool;
            insurancePool -= excess;
        } else {
            insurancePool += (p.margin - payout);
        }

        if (isLiquidation) {
            uint256 reward = (p.size * params.liquidationFeeBps) / BPS_DENOMINATOR;
            if (reward > payout) reward = payout;
            payout -= reward;
            collateralBalances[trader] += payout;
            if (reward > 0) {
                collateral.safeTransfer(liquidator, reward);
            }
            emit Liquidated(trader, liquidator, reward);
        } else {
            collateralBalances[trader] += payout;
        }

        emit PositionClosed(
            trader,
            p.isLong,
            p.size,
            p.entryPrice,
            mark,
            positionPnl
        );

        delete positions[trader];
    }

    function _pnl(Position storage p, uint256 mark) internal view returns (int256) {
        if (p.isLong) {
            return
                (int256(p.size) * (int256(mark) - int256(p.entryPrice))) /
                int256(p.entryPrice);
        } else {
            return
                (int256(p.size) * (int256(p.entryPrice) - int256(mark))) /
                int256(p.entryPrice);
        }
    }

    function _fundingFee(Position storage p) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - p.openTime;
        return (p.size * params.fundingRate * elapsed) / WAD;
    }

    function _marginRatio(address trader, uint256 mark) internal view returns (uint256) {
        Position storage p = positions[trader];
        if (p.size == 0) return 0;
        int256 positionPnl = _pnl(p, mark);
        int256 equity = int256(p.margin) + positionPnl;
        if (equity <= 0) return 0;
        uint256 currentNotional = (p.size * mark) / p.entryPrice;
        if (currentNotional == 0) return 0;
        return (uint256(equity) * WAD) / currentNotional;
    }

    function _isUnsafe(address trader, uint256 mark) internal view returns (bool) {
        uint256 ratio = _marginRatio(trader, mark);
        return ratio < (params.maintenanceMarginBps * WAD) / BPS_DENOMINATOR;
    }
}
