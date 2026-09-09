// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();

    constructor(address _owner) {
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert NotOwner();
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

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

contract PowerPerpMarket is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant POWER = 2;
    uint256 public constant INITIAL_MARGIN_BPS = 1000; // 10%
    uint256 public constant MAINTENANCE_MARGIN_BPS = 500; // 5%
    uint256 public constant TRADING_FEE_BPS = 5; // 0.05%
    uint256 public constant LIQUIDATION_PENALTY_BPS = 500; // 5%

    error ZeroAddress();
    error ZeroAmount();
    error SameSize();
    error PositionExists();
    error NoPosition();
    error InsufficientBalance();
    error InsufficientMargin();
    error NotUndercollateralized();
    error UnauthorizedOperator();
    error PriceStale();

    event Deposit(address indexed account, address indexed asset, uint256 amount);
    event Withdraw(address indexed account, address indexed asset, uint256 amount);
    event PositionOpened(
        address indexed account,
        address indexed asset,
        bool isLong,
        uint256 size,
        uint256 entryPrice,
        uint256 fee
    );
    event PositionClosed(
        address indexed account,
        address indexed asset,
        bool isLong,
        uint256 size,
        uint256 exitPrice,
        uint256 fee,
        int256 pnl
    );
    event PositionAdjusted(
        address indexed account,
        address indexed asset,
        uint256 oldSize,
        uint256 newSize,
        uint256 newEntryPrice
    );
    event FundingClaimed(address indexed account, int256 amount);
    event Liquidated(
        address indexed account,
        address indexed liquidator,
        address indexed asset,
        uint256 size,
        uint256 price,
        uint256 collateralSeized
    );
    event FundingRateUpdated(int256 newRate);
    event FeesClaimed(address indexed operator, uint256 amount);
    event OperatorChanged(address indexed newOperator);

    struct Position {
        bool isLong;
        bool exists;
        uint256 size;
        uint256 entryPrice;
        int256 entryFundingIndex;
    }

    IERC20 public immutable baseToken;
    IPriceOracle public immutable oracle;

    address public operator;
    int256 public fundingRate;
    uint256 public lastFundingTime;
    int256 public globalFundingIndex;

    uint256 public accumulatedFees;

    mapping(address => uint256) public balances;
    mapping(address => Position) public positions;

    modifier onlyOperator() {
        if (msg.sender != operator) revert UnauthorizedOperator();
        _;
    }

    constructor(
        address _baseToken,
        address _oracle,
        address _operator
    ) Ownable(msg.sender) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        baseToken = IERC20(_baseToken);
        oracle = IPriceOracle(_oracle);
        operator = _operator;
        lastFundingTime = block.timestamp;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorChanged(_operator);
    }

    function setFundingRate(int256 _rate) external onlyOperator {
        _updateFunding();
        fundingRate = _rate;
        emit FundingRateUpdated(_rate);
    }

    function updateFunding() external {
        _updateFunding();
    }

    function _updateFunding() internal {
        uint256 elapsed = block.timestamp - lastFundingTime;
        if (elapsed > 0) {
            globalFundingIndex += fundingRate * int256(elapsed);
            lastFundingTime = block.timestamp;
        }
    }

    function _getIndexPrice() internal view returns (uint256) {
        uint256 price = oracle.getPrice();
        if (price == 0) revert PriceStale();
        return price;
    }

    function _notionalPerUnit(uint256 price) internal pure returns (uint256) {
        // POWER == 2: notional per unit is price^2 normalized to PRECISION.
        // A single multiply followed by a single divide avoids the
        // divide-before-multiply precision loss present in iterative
        // exponentiation-by-squaring with intermediate normalization.
        return (price * price) / PRECISION;
    }

    function _notional(uint256 size, uint256 price) internal pure returns (uint256) {
        return (size * _notionalPerUnit(price)) / PRECISION;
    }

    function _pnlAndFunding(Position storage pos)
        internal
        view
        returns (int256 pnl, int256 funding)
    {
        uint256 price = _getIndexPrice();
        int256 delta = globalFundingIndex - pos.entryFundingIndex;
        if (pos.isLong) {
            pnl =
                (int256(pos.size) * (int256(price) - int256(pos.entryPrice))) /
                int256(PRECISION);
            funding = -(int256(pos.size) * delta) / int256(PRECISION);
        } else {
            pnl =
                (int256(pos.size) * (int256(pos.entryPrice) - int256(price))) /
                int256(PRECISION);
            funding = (int256(pos.size) * delta) / int256(PRECISION);
        }
    }

    function _settle(address account, int256 settlement) internal {
        if (settlement >= 0) {
            balances[account] += uint256(settlement);
        } else {
            uint256 loss = uint256(-settlement);
            if (loss >= balances[account]) {
                balances[account] = 0;
            } else {
                balances[account] -= loss;
            }
        }
    }

    function _maintenanceMargin(uint256 size, uint256 price) internal pure returns (uint256) {
        return (_notional(size, price) * MAINTENANCE_MARGIN_BPS) / BPS_DENOM;
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateFunding();
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, address(baseToken), amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateFunding();
        if (amount > balances[msg.sender]) revert InsufficientBalance();

        Position storage pos = positions[msg.sender];
        if (pos.exists) {
            (int256 pnl, int256 funding) = _pnlAndFunding(pos);
            int256 margin = int256(balances[msg.sender]) + pnl + funding;
            uint256 price = _getIndexPrice();
            uint256 required = _maintenanceMargin(pos.size, price);
            if (margin < int256(required)) revert InsufficientMargin();
        }

        balances[msg.sender] -= amount;
        baseToken.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, address(baseToken), amount);
    }

    function openPosition(uint256 size, bool isLong) external nonReentrant {
        if (size == 0) revert ZeroAmount();
        _updateFunding();

        Position storage pos = positions[msg.sender];
        if (pos.exists) revert PositionExists();

        uint256 price = _getIndexPrice();
        uint256 notional = _notional(size, price);
        uint256 fee = (notional * TRADING_FEE_BPS) / BPS_DENOM;
        uint256 requiredMargin =
            (notional * INITIAL_MARGIN_BPS) / BPS_DENOM + fee;

        if (balances[msg.sender] < requiredMargin) revert InsufficientMargin();

        pos.isLong = isLong;
        pos.exists = true;
        pos.size = size;
        pos.entryPrice = price;
        pos.entryFundingIndex = globalFundingIndex;

        balances[msg.sender] -= fee;
        accumulatedFees += fee;

        emit PositionOpened(msg.sender, address(baseToken), isLong, size, price, fee);
    }

    function closePosition() external nonReentrant {
        _updateFunding();
        Position storage pos = positions[msg.sender];
        if (!pos.exists) revert NoPosition();

        uint256 price = _getIndexPrice();
        (int256 pnl, int256 funding) = _pnlAndFunding(pos);
        uint256 notional = _notional(pos.size, price);
        uint256 fee = (notional * TRADING_FEE_BPS) / BPS_DENOM;

        int256 settlement = pnl + funding - int256(fee);
        _settle(msg.sender, settlement);
        accumulatedFees += fee;

        emit PositionClosed(
            msg.sender,
            address(baseToken),
            pos.isLong,
            pos.size,
            price,
            fee,
            pnl + funding
        );

        delete positions[msg.sender];
    }

    function adjustSize(uint256 newSize) external nonReentrant {
        _updateFunding();
        Position storage pos = positions[msg.sender];
        if (!pos.exists) revert NoPosition();
        if (newSize == 0) revert ZeroAmount();
        if (newSize == pos.size) revert SameSize();

        uint256 price = _getIndexPrice();
        uint256 oldSize = pos.size;

        if (newSize < pos.size) {
            uint256 delta = pos.size - newSize;
            uint256 notionalDelta = _notional(delta, price);
            uint256 fee = (notionalDelta * TRADING_FEE_BPS) / BPS_DENOM;

            (int256 pnl, int256 funding) = _pnlAndFunding(pos);
            int256 realizedPnl = (pnl * int256(delta)) / int256(pos.size);
            int256 realizedFunding =
                (funding * int256(delta)) / int256(pos.size);
            int256 settlement = realizedPnl + realizedFunding - int256(fee);

            _settle(msg.sender, settlement);
            accumulatedFees += fee;
            pos.size = newSize;
        } else {
            uint256 delta = newSize - pos.size;
            uint256 notionalDelta = _notional(delta, price);
            uint256 fee = (notionalDelta * TRADING_FEE_BPS) / BPS_DENOM;
            uint256 requiredMargin =
                (notionalDelta * INITIAL_MARGIN_BPS) / BPS_DENOM + fee;

            if (balances[msg.sender] < requiredMargin) revert InsufficientMargin();

            (, int256 funding) = _pnlAndFunding(pos);
            _settle(msg.sender, funding);
            pos.entryFundingIndex = globalFundingIndex;

            pos.entryPrice =
                (pos.size * pos.entryPrice + delta * price) /
                newSize;

            balances[msg.sender] -= fee;
            accumulatedFees += fee;
            pos.size = newSize;
        }

        emit PositionAdjusted(
            msg.sender,
            address(baseToken),
            oldSize,
            newSize,
            pos.entryPrice
        );
    }

    function claimFunding() external nonReentrant {
        _updateFunding();
        Position storage pos = positions[msg.sender];
        if (!pos.exists) revert NoPosition();

        (, int256 funding) = _pnlAndFunding(pos);
        _settle(msg.sender, funding);
        pos.entryFundingIndex = globalFundingIndex;

        emit FundingClaimed(msg.sender, funding);
    }

    function liquidate(address account) external onlyOperator nonReentrant {
        _updateFunding();
        Position storage pos = positions[account];
        if (!pos.exists) revert NoPosition();

        uint256 price = _getIndexPrice();
        (int256 pnl, int256 funding) = _pnlAndFunding(pos);
        int256 margin = int256(balances[account]) + pnl + funding;
        uint256 required = _maintenanceMargin(pos.size, price);

        if (margin >= int256(required)) revert NotUndercollateralized();

        // Effects: settle PnL/funding and compute penalty first.
        int256 settlement = pnl + funding;
        _settle(account, settlement);

        uint256 notional = _notional(pos.size, price);
        uint256 penalty = (notional * LIQUIDATION_PENALTY_BPS) / BPS_DENOM;
        uint256 penaltyAmount = penalty > balances[account]
            ? balances[account]
            : penalty;
        balances[account] -= penaltyAmount;

        // Capture position fields before clearing state (checks-effects-interactions).
        uint256 size = pos.size;

        // Effects: clear position state before any external interaction.
        delete positions[account];

        emit Liquidated(
            account,
            msg.sender,
            address(baseToken),
            size,
            price,
            penaltyAmount
        );

        // Interaction: transfer penalty to liquidator last.
        baseToken.safeTransfer(msg.sender, penaltyAmount);
    }

    function claimFees() external onlyOperator nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        baseToken.safeTransfer(msg.sender, amount);
        emit FeesClaimed(msg.sender, amount);
    }

    function getAccountState(address account)
        external
        view
        returns (
            uint256 balance,
            bool hasPosition,
            bool isLong,
            uint256 size,
            uint256 entryPrice,
            int256 entryFundingIndex,
            int256 pnl,
            int256 funding,
            int256 margin,
            uint256 notional,
            uint256 maintenanceRequired
        )
    {
        balance = balances[account];
        Position storage pos = positions[account];
        hasPosition = pos.exists;
        if (hasPosition) {
            isLong = pos.isLong;
            size = pos.size;
            entryPrice = pos.entryPrice;
            entryFundingIndex = pos.entryFundingIndex;
            (pnl, funding) = _pnlAndFunding(pos);
            uint256 price = _getIndexPrice();
            notional = _notional(pos.size, price);
            maintenanceRequired = _maintenanceMargin(pos.size, price);
            margin = int256(balance) + pnl + funding;
        }
    }

    function getNotionalValue(uint256 size) external view returns (uint256) {
        return _notional(size, _getIndexPrice());
    }

    function getMaintenanceMargin(uint256 size) external view returns (uint256) {
        return _maintenanceMargin(size, _getIndexPrice());
    }
}
