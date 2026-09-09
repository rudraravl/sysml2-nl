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
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
    }
}

contract ReentrancyGuard {
    uint256 private _status;

    constructor() {
        _status = 1;
    }

    modifier nonReentrant() {
        require(_status == 1, "ReentrancyGuard: reentrant call");
        _status = 2;
        _;
        _status = 1;
    }
}

contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: unauthorized");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
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
}

contract PerpetualFutures is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_LEVERAGE = 10e18; // 10x
    uint256 public constant FEE_RATE = 1e15; // 0.1% = 0.001e18
    uint256 public constant PRECISION = 1e18;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidPair();
    error PairAlreadyExists();
    error PositionAlreadyExists();
    error PositionNotFound();
    error InsufficientFreeCollateral();
    error MaxLeverageExceeded();
    error NotUndercollateralized();
    error ZeroAddress();
    error ZeroSize();
    error InvalidLiquidationThreshold();
    error InvalidPrice();
    error OnlyOperator();
    error InvalidParameter();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event PairAdded(bytes32 indexed pairId, uint256 liquidationThreshold, int256 fundingRatePerSec);
    event PairParamsUpdated(bytes32 indexed pairId, uint256 liquidationThreshold, int256 fundingRatePerSec);
    event PriceUpdated(bytes32 indexed pairId, uint256 price);
    event FundingRateUpdated(bytes32 indexed pairId, int256 fundingRatePerSec);

    event CollateralDeposited(address indexed user, uint256 amount);
    event FreeCollateralWithdrawn(address indexed user, uint256 amount);
    event PositionCollateralAdded(bytes32 indexed pairId, address indexed user, bool isLong, uint256 amount);
    event PositionCollateralWithdrawn(bytes32 indexed pairId, address indexed user, bool isLong, uint256 amount);

    event PositionOpened(
        bytes32 indexed pairId,
        address indexed user,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 entryPrice,
        int256 entryFundingIndex
    );
    event PositionClosed(
        bytes32 indexed pairId,
        address indexed user,
        bool isLong,
        uint256 size,
        int256 pnl,
        int256 fundingPayment,
        uint256 fee
    );
    event FundingClaimed(
        bytes32 indexed pairId,
        address indexed user,
        bool isLong,
        int256 fundingPayment
    );
    event Liquidated(
        bytes32 indexed pairId,
        address indexed user,
        bool isLong,
        uint256 size,
        uint256 collateralSeized,
        address indexed liquidator
    );

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Pair {
        bool exists;
        uint256 price;
        uint256 liquidationThreshold; // 1e18, e.g. 0.8e18
        int256 fundingRatePerSec; // 1e18
        int256 fundingIndex; // 1e18
        uint256 lastFundingUpdate;
        uint256 totalLongSize;
        uint256 totalShortSize;
    }

    struct Position {
        uint256 size; // base units, 1e18
        uint256 entryPrice; // 1e18
        uint256 collateral; // 1e18 stablecoin
        int256 entryFundingIndex; // 1e18
    }

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable collateralToken;
    address public feeRecipient;

    mapping(bytes32 => Pair) public pairs;
    mapping(address => uint256) public freeCollateral; // 1e18
    mapping(bytes32 => mapping(address => mapping(bool => Position))) public positions;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _collateralToken, address _admin, address _feeRecipient) {
        if (_collateralToken == address(0) || _admin == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }
        collateralToken = IERC20(_collateralToken);
        feeRecipient = _feeRecipient;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) revert OnlyOperator();
        _;
    }

    modifier pairExists(bytes32 pairId) {
        if (!pairs[pairId].exists) revert InvalidPair();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addPair(
        bytes32 pairId,
        uint256 liquidationThreshold,
        int256 fundingRatePerSec
    ) external onlyOperator {
        if (pairs[pairId].exists) revert PairAlreadyExists();
        if (liquidationThreshold == 0 || liquidationThreshold > PRECISION) revert InvalidLiquidationThreshold();
        pairs[pairId] = Pair({
            exists: true,
            price: 0,
            liquidationThreshold: liquidationThreshold,
            fundingRatePerSec: fundingRatePerSec,
            fundingIndex: 0,
            lastFundingUpdate: block.timestamp,
            totalLongSize: 0,
            totalShortSize: 0
        });
        emit PairAdded(pairId, liquidationThreshold, fundingRatePerSec);
    }

    function updatePairParams(
        bytes32 pairId,
        uint256 liquidationThreshold,
        int256 fundingRatePerSec
    ) external onlyOperator pairExists(pairId) {
        if (liquidationThreshold == 0 || liquidationThreshold > PRECISION) revert InvalidLiquidationThreshold();
        _updateFundingIndex(pairId);
        Pair storage p = pairs[pairId];
        p.liquidationThreshold = liquidationThreshold;
        p.fundingRatePerSec = fundingRatePerSec;
        emit PairParamsUpdated(pairId, liquidationThreshold, fundingRatePerSec);
    }

    function updateFundingRate(bytes32 pairId, int256 fundingRatePerSec) external onlyOperator pairExists(pairId) {
        _updateFundingIndex(pairId);
        pairs[pairId].fundingRatePerSec = fundingRatePerSec;
        emit FundingRateUpdated(pairId, fundingRatePerSec);
    }

    function updatePrice(bytes32 pairId, uint256 price) external onlyOperator pairExists(pairId) {
        if (price == 0) revert InvalidPrice();
        pairs[pairId].price = price;
        emit PriceUpdated(pairId, price);
    }

    function liquidate(
        bytes32 pairId,
        address user,
        bool isLong
    ) external onlyOperator pairExists(pairId) nonReentrant {
        Position storage pos = positions[pairId][user][isLong];
        if (pos.size == 0) revert PositionNotFound();
        _updateFundingIndex(pairId);
        Pair storage p = pairs[pairId];
        uint256 price = p.price;
        if (price == 0) revert InvalidPrice();
        uint256 maintenanceMargin = (pos.size * price * p.liquidationThreshold) / (PRECISION * PRECISION);
        if (pos.collateral >= maintenanceMargin) revert NotUndercollateralized();

        uint256 seized = pos.collateral;
        if (isLong) {
            p.totalLongSize -= pos.size;
        } else {
            p.totalShortSize -= pos.size;
        }
        delete positions[pairId][user][isLong];

        collateralToken.safeTransfer(msg.sender, seized);
        emit Liquidated(pairId, user, isLong, pos.size, seized, msg.sender);
    }

    function setFeeRecipient(address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert ZeroAddress();
        feeRecipient = recipient;
    }

    /*//////////////////////////////////////////////////////////////
                        USER COLLATERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidParameter();
        freeCollateral[msg.sender] += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawFreeCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidParameter();
        if (freeCollateral[msg.sender] < amount) revert InsufficientFreeCollateral();
        freeCollateral[msg.sender] -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit FreeCollateralWithdrawn(msg.sender, amount);
    }

    function addPositionCollateral(bytes32 pairId, bool isLong, uint256 amount) external pairExists(pairId) nonReentrant {
        Position storage pos = positions[pairId][msg.sender][isLong];
        if (pos.size == 0) revert PositionNotFound();
        if (amount == 0) revert InvalidParameter();
        if (freeCollateral[msg.sender] < amount) revert InsufficientFreeCollateral();

        freeCollateral[msg.sender] -= amount;
        pos.collateral += amount;
        emit PositionCollateralAdded(pairId, msg.sender, isLong, amount);
    }

    function withdrawPositionCollateral(bytes32 pairId, bool isLong, uint256 amount) external pairExists(pairId) nonReentrant {
        Position storage pos = positions[pairId][msg.sender][isLong];
        if (pos.size == 0) revert PositionNotFound();
        if (amount == 0) revert InvalidParameter();

        _updateFundingIndex(pairId);
        Pair storage p = pairs[pairId];
        uint256 price = p.price;
        if (price == 0) revert InvalidPrice();

        if (pos.collateral < amount) revert InsufficientFreeCollateral();
        uint256 remainingCollateral = pos.collateral - amount;
        uint256 maintenanceMargin = (pos.size * price * p.liquidationThreshold) / (PRECISION * PRECISION);
        if (remainingCollateral < maintenanceMargin) revert InsufficientFreeCollateral();

        pos.collateral = remainingCollateral;
        freeCollateral[msg.sender] += amount;
        emit PositionCollateralWithdrawn(pairId, msg.sender, isLong, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        POSITION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function openPosition(
        bytes32 pairId,
        bool isLong,
        uint256 size,
        uint256 collateralAmount
    ) external pairExists(pairId) nonReentrant {
        if (size == 0 || collateralAmount == 0) revert ZeroSize();
        Position storage pos = positions[pairId][msg.sender][isLong];
        if (pos.size != 0) revert PositionAlreadyExists();

        _updateFundingIndex(pairId);
        Pair storage p = pairs[pairId];
        uint256 price = p.price;
        if (price == 0) revert InvalidPrice();

        uint256 notional = (size * price) / PRECISION;
        if (notional > collateralAmount * MAX_LEVERAGE) revert MaxLeverageExceeded();

        uint256 fee = (notional * FEE_RATE) / PRECISION;
        if (freeCollateral[msg.sender] < collateralAmount + fee) revert InsufficientFreeCollateral();

        freeCollateral[msg.sender] -= collateralAmount + fee;
        if (fee > 0) {
            collateralToken.safeTransfer(feeRecipient, fee);
        }

        pos.size = size;
        pos.entryPrice = price;
        pos.collateral = collateralAmount;
        pos.entryFundingIndex = p.fundingIndex;

        if (isLong) {
            p.totalLongSize += size;
        } else {
            p.totalShortSize += size;
        }

        emit PositionOpened(pairId, msg.sender, isLong, size, collateralAmount, price, p.fundingIndex);
    }

    function closePosition(bytes32 pairId, bool isLong) external pairExists(pairId) nonReentrant {
        Position storage pos = positions[pairId][msg.sender][isLong];
        if (pos.size == 0) revert PositionNotFound();

        _updateFundingIndex(pairId);
        Pair storage p = pairs[pairId];
        uint256 price = p.price;
        if (price == 0) revert InvalidPrice();

        int256 pnl = _pnl(pos, isLong, price);
        int256 fundingPayment = _fundingPayment(pos, isLong, p.fundingIndex);
        int256 netCollateral = int256(pos.collateral) + pnl + fundingPayment;

        uint256 notional = (pos.size * price) / PRECISION;
        uint256 fee = (notional * FEE_RATE) / PRECISION;

        if (netCollateral > int256(fee)) {
            netCollateral -= int256(fee);
            if (fee > 0) {
                collateralToken.safeTransfer(feeRecipient, fee);
            }
        } else {
            int256 availableFeeInt = netCollateral < 0 ? int256(0) : netCollateral;
            uint256 availableFee = availableFeeInt < 0 ? 0 : uint256(availableFeeInt);
            if (availableFee > 0) {
                collateralToken.safeTransfer(feeRecipient, availableFee);
            }
            netCollateral = 0;
        }

        if (netCollateral > 0) {
            freeCollateral[msg.sender] += uint256(netCollateral);
        }

        if (isLong) {
            p.totalLongSize -= pos.size;
        } else {
            p.totalShortSize -= pos.size;
        }

        emit PositionClosed(pairId, msg.sender, isLong, pos.size, pnl, fundingPayment, fee);

        delete positions[pairId][msg.sender][isLong];
    }

    function claimFunding(bytes32 pairId, bool isLong) external pairExists(pairId) nonReentrant {
        Position storage pos = positions[pairId][msg.sender][isLong];
        if (pos.size == 0) revert PositionNotFound();

        _updateFundingIndex(pairId);
        Pair storage p = pairs[pairId];
        int256 fundingPayment = _fundingPayment(pos, isLong, p.fundingIndex);

        int256 newCollateral = int256(pos.collateral) + fundingPayment;
        if (newCollateral < 0) {
            pos.collateral = 0;
        } else {
            pos.collateral = uint256(newCollateral);
        }
        pos.entryFundingIndex = p.fundingIndex;

        emit FundingClaimed(pairId, msg.sender, isLong, fundingPayment);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _updateFundingIndex(bytes32 pairId) internal {
        Pair storage p = pairs[pairId];
        uint256 elapsed = block.timestamp - p.lastFundingUpdate;
        if (elapsed > 0) {
            p.fundingIndex += (p.fundingRatePerSec * int256(elapsed)) / int256(PRECISION);
            p.lastFundingUpdate = block.timestamp;
        }
    }

    function _pnl(
        Position storage pos,
        bool isLong,
        uint256 currentPrice
    ) internal view returns (int256) {
        int256 priceDiff = isLong
            ? int256(currentPrice) - int256(pos.entryPrice)
            : int256(pos.entryPrice) - int256(currentPrice);
        return (int256(pos.size) * priceDiff) / int256(PRECISION);
    }

    function _fundingPayment(
        Position storage pos,
        bool isLong,
        int256 currentFundingIndex
    ) internal view returns (int256) {
        int256 delta = currentFundingIndex - pos.entryFundingIndex;
        int256 raw = (int256(pos.size) * delta) / int256(PRECISION);
        // Positive funding rate means longs pay shorts.
        return isLong ? -raw : raw;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPair(bytes32 pairId)
        external
        view
        returns (
            bool exists,
            uint256 price,
            uint256 liquidationThreshold,
            int256 fundingRatePerSec,
            int256 fundingIndex,
            uint256 lastFundingUpdate,
            uint256 totalLongSize,
            uint256 totalShortSize
        )
    {
        Pair storage p = pairs[pairId];
        return (
            p.exists,
            p.price,
            p.liquidationThreshold,
            p.fundingRatePerSec,
            p.fundingIndex,
            p.lastFundingUpdate,
            p.totalLongSize,
            p.totalShortSize
        );
    }

    function getPosition(
        bytes32 pairId,
        address user,
        bool isLong
    ) external view returns (uint256 size, uint256 entryPrice, uint256 collateral, int256 entryFundingIndex) {
        Position storage pos = positions[pairId][user][isLong];
        return (pos.size, pos.entryPrice, pos.collateral, pos.entryFundingIndex);
    }

    function getFreeCollateral(address user) external view returns (uint256) {
        return freeCollateral[user];
    }

    function isUndercollateralized(
        bytes32 pairId,
        address user,
        bool isLong
    ) external view returns (bool) {
        Position storage pos = positions[pairId][user][isLong];
        if (pos.size == 0) return false;
        Pair storage p = pairs[pairId];
        uint256 maintenanceMargin = (pos.size * p.price * p.liquidationThreshold) / (PRECISION * PRECISION);
        return pos.collateral < maintenanceMargin;
    }
}
