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

contract PerpetualFuturesExchange {
    uint256 public constant PRICE_BASE = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant TRADING_FEE_BPS = 5;
    uint256 public constant MIN_INITIAL_MARGIN_BPS = 1000;
    uint256 public constant MAX_LEVERAGE = 100e18;

    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error InvalidPairId();
    error PairNotConfigured();
    error PairAlreadyExists();
    error PairPausedError();
    error InvalidLeverage();
    error InvalidPrice();
    error InvalidAmount();
    error InvalidMarginBps();
    error PositionAlreadyOpen();
    error NoPositionExists();
    error InsufficientAvailableCollateral();
    error TransferFailed();
    error Reentrancy();

    struct PairConfig {
        bool exists;
        bool tradingPaused;
        uint256 markPrice;
        uint256 fundingRatePerSecond;
        uint256 maxLeverage;
        uint256 minInitialMarginBps;
        uint256 maintenanceMarginBps;
        uint256 lastFundingTime;
        uint256 cumulativeFunding;
    }

    struct Position {
        bool isLong;
        uint256 size;
        uint256 leverage;
        uint256 openPrice;
        uint256 margin;
        uint256 entryFunding;
    }

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event PositionOpened(
        address indexed user,
        bytes32 indexed pairId,
        bool isLong,
        uint256 size,
        uint256 leverage,
        uint256 openPrice,
        uint256 margin,
        uint256 fee
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed pairId,
        bool isLong,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 fee,
        uint256 marginReturned
    );
    event LeverageModified(
        address indexed user,
        bytes32 indexed pairId,
        uint256 oldLeverage,
        uint256 newLeverage,
        int256 marginAdjustment
    );
    event PairAdded(bytes32 indexed pairId, string name);
    event PairConfigUpdated(
        bytes32 indexed pairId,
        uint256 markPrice,
        uint256 fundingRatePerSecond,
        uint256 maxLeverage,
        uint256 minInitialMarginBps,
        uint256 maintenanceMarginBps,
        bool tradingPaused
    );
    event PairPausedStatus(bytes32 indexed pairId, bool paused);
    event PriceUpdated(bytes32 indexed pairId, uint256 price);
    event EmergencySettled(
        address indexed user,
        bytes32 indexed pairId,
        uint256 settlementPrice,
        uint256 marginReturned
    );
    event FeesCollected(address indexed collector, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    address public owner;
    address public operator;
    address public feeRecipient;
    IERC20 public immutable collateralToken;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public totalLocked;
    mapping(bytes32 => PairConfig) public pairConfigs;
    mapping(address => mapping(bytes32 => Position)) public positions;

    uint256 public feesCollected;
    uint256 private _status;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier pairMustExist(bytes32 pairId) {
        if (!pairConfigs[pairId].exists) revert PairNotConfigured();
        _;
    }

    modifier nonReentrant() {
        if (_status != 1) revert Reentrancy();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address collateralToken_, address operator_, address feeRecipient_) {
        if (collateralToken_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = operator_;
        feeRecipient = feeRecipient_;
        collateralToken = IERC20(collateralToken_);
        _status = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), operator_);
        emit FeeRecipientUpdated(address(0), feeRecipient_);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        _safeTransferFrom(address(collateralToken), msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, address(collateralToken), amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        uint256 available = _availableCollateral(msg.sender);
        if (amount > available) revert InsufficientAvailableCollateral();
        balances[msg.sender] -= amount;
        _safeTransfer(address(collateralToken), msg.sender, amount);
        emit Withdraw(msg.sender, address(collateralToken), amount);
    }

    function openPosition(
        bytes32 pairId,
        bool isLong,
        uint256 size,
        uint256 leverage
    ) external pairMustExist(pairId) {
        PairConfig storage pair = pairConfigs[pairId];
        if (pair.tradingPaused) revert PairPausedError();
        if (size == 0) revert InvalidAmount();
        if (leverage == 0 || leverage > pair.maxLeverage || leverage > MAX_LEVERAGE) {
            revert InvalidLeverage();
        }
        if (positions[msg.sender][pairId].size != 0) revert PositionAlreadyOpen();

        uint256 price = pair.markPrice;
        if (price == 0) revert InvalidPrice();

        _applyFunding(pairId);

        uint256 requiredMargin;
        uint256 fee;
        {
            if ((size * price) / PRICE_BASE == 0) revert InvalidAmount();
            requiredMargin = (size * price) / (PRICE_BASE * leverage);
            uint256 minInitial = (size * price * pair.minInitialMarginBps) / (PRICE_BASE * BPS_DENOMINATOR);
            uint256 globalMin = (size * price * MIN_INITIAL_MARGIN_BPS) / (PRICE_BASE * BPS_DENOMINATOR);
            if (minInitial < globalMin) minInitial = globalMin;
            if (requiredMargin < minInitial) requiredMargin = minInitial;
            fee = (size * price * TRADING_FEE_BPS) / (PRICE_BASE * BPS_DENOMINATOR);
        }

        uint256 available = _availableCollateral(msg.sender);
        if (available < requiredMargin + fee) revert InsufficientAvailableCollateral();

        balances[msg.sender] -= fee;
        totalLocked[msg.sender] += requiredMargin;
        feesCollected += fee;

        positions[msg.sender][pairId] = Position({
            isLong: isLong,
            size: size,
            leverage: leverage,
            openPrice: price,
            margin: requiredMargin,
            entryFunding: pair.cumulativeFunding
        });

        emit PositionOpened(
            msg.sender,
            pairId,
            isLong,
            size,
            leverage,
            price,
            requiredMargin,
            fee
        );
    }

    function closePosition(bytes32 pairId) external pairMustExist(pairId) {
        PairConfig storage pair = pairConfigs[pairId];
        uint256 exitPrice = pair.markPrice;
        if (exitPrice == 0) revert InvalidPrice();
        _applyFunding(pairId);
        _closePosition(msg.sender, pairId, exitPrice, true);
    }

    function modifyLeverage(bytes32 pairId, uint256 newLeverage)
        external
        pairMustExist(pairId)
    {
        PairConfig storage pair = pairConfigs[pairId];
        if (pair.tradingPaused) revert PairPausedError();
        if (newLeverage == 0 || newLeverage > pair.maxLeverage || newLeverage > MAX_LEVERAGE) {
            revert InvalidLeverage();
        }
        Position storage pos = positions[msg.sender][pairId];
        if (pos.size == 0) revert NoPositionExists();

        uint256 price = pair.markPrice;
        if (price == 0) revert InvalidPrice();

        uint256 newMargin;
        {
            uint256 minInitial = (pos.size * price * pair.minInitialMarginBps) / (PRICE_BASE * BPS_DENOMINATOR);
            uint256 globalMin = (pos.size * price * MIN_INITIAL_MARGIN_BPS) / (PRICE_BASE * BPS_DENOMINATOR);
            if (minInitial < globalMin) minInitial = globalMin;
            newMargin = (pos.size * price) / (PRICE_BASE * newLeverage);
            if (newMargin < minInitial) newMargin = minInitial;
        }

        uint256 oldLeverage = pos.leverage;
        int256 marginAdjustment = 0;

        if (newMargin > pos.margin) {
            uint256 extra = newMargin - pos.margin;
            if (_availableCollateral(msg.sender) < extra) {
                revert InsufficientAvailableCollateral();
            }
            totalLocked[msg.sender] += extra;
            pos.margin = newMargin;
            marginAdjustment = int256(extra);
        } else if (newMargin < pos.margin) {
            uint256 released = pos.margin - newMargin;
            totalLocked[msg.sender] -= released;
            pos.margin = newMargin;
            marginAdjustment = -int256(released);
        }

        pos.leverage = newLeverage;
        emit LeverageModified(msg.sender, pairId, oldLeverage, newLeverage, marginAdjustment);
    }

    function addPair(
        bytes32 pairId,
        string calldata name,
        uint256 initialPrice,
        uint256 fundingRatePerSecond,
        uint256 maxLeverage,
        uint256 minInitialMarginBps,
        uint256 maintenanceMarginBps
    ) external onlyOperator {
        if (pairId == bytes32(0)) revert InvalidPairId();
        if (pairConfigs[pairId].exists) revert PairAlreadyExists();
        if (initialPrice == 0) revert InvalidPrice();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (minInitialMarginBps < MIN_INITIAL_MARGIN_BPS || minInitialMarginBps > BPS_DENOMINATOR) {
            revert InvalidMarginBps();
        }
        if (maintenanceMarginBps > minInitialMarginBps) revert InvalidMarginBps();

        pairConfigs[pairId] = PairConfig({
            exists: true,
            tradingPaused: false,
            markPrice: initialPrice,
            fundingRatePerSecond: fundingRatePerSecond,
            maxLeverage: maxLeverage,
            minInitialMarginBps: minInitialMarginBps,
            maintenanceMarginBps: maintenanceMarginBps,
            lastFundingTime: block.timestamp,
            cumulativeFunding: 0
        });

        emit PairAdded(pairId, name);
        emit PairConfigUpdated(
            pairId,
            initialPrice,
            fundingRatePerSecond,
            maxLeverage,
            minInitialMarginBps,
            maintenanceMarginBps,
            false
        );
        emit PriceUpdated(pairId, initialPrice);
    }

    function setPairConfig(
        bytes32 pairId,
        uint256 markPrice,
        uint256 fundingRatePerSecond,
        uint256 maxLeverage,
        uint256 minInitialMarginBps,
        uint256 maintenanceMarginBps,
        bool tradingPaused
    ) external onlyOperator pairMustExist(pairId) {
        if (markPrice == 0) revert InvalidPrice();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (minInitialMarginBps < MIN_INITIAL_MARGIN_BPS || minInitialMarginBps > BPS_DENOMINATOR) {
            revert InvalidMarginBps();
        }
        if (maintenanceMarginBps > minInitialMarginBps) revert InvalidMarginBps();

        _applyFunding(pairId);

        PairConfig storage pair = pairConfigs[pairId];
        pair.markPrice = markPrice;
        pair.fundingRatePerSecond = fundingRatePerSecond;
        pair.maxLeverage = maxLeverage;
        pair.minInitialMarginBps = minInitialMarginBps;
        pair.maintenanceMarginBps = maintenanceMarginBps;
        pair.tradingPaused = tradingPaused;

        emit PairConfigUpdated(
            pairId,
            markPrice,
            fundingRatePerSecond,
            maxLeverage,
            minInitialMarginBps,
            maintenanceMarginBps,
            tradingPaused
        );
        emit PriceUpdated(pairId, markPrice);
    }

    function setPrice(bytes32 pairId, uint256 price)
        external
        onlyOperator
        pairMustExist(pairId)
    {
        if (price == 0) revert InvalidPrice();
        _applyFunding(pairId);
        pairConfigs[pairId].markPrice = price;
        emit PriceUpdated(pairId, price);
    }

    function pausePair(bytes32 pairId, bool paused)
        external
        onlyOperator
        pairMustExist(pairId)
    {
        pairConfigs[pairId].tradingPaused = paused;
        emit PairPausedStatus(pairId, paused);
    }

    function emergencySettle(
        address user,
        bytes32 pairId,
        uint256 settlementPrice
    ) external onlyOperator pairMustExist(pairId) {
        if (settlementPrice == 0) revert InvalidPrice();
        _applyFunding(pairId);
        uint256 returned = _closePosition(user, pairId, settlementPrice, false);
        emit EmergencySettled(user, pairId, settlementPrice, returned);
    }

    function collectFees() external onlyOperator nonReentrant {
        uint256 amount = feesCollected;
        if (amount == 0) revert InvalidAmount();
        feesCollected = 0;
        _safeTransfer(address(collateralToken), feeRecipient, amount);
        emit FeesCollected(feeRecipient, amount);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function availableCollateral(address user) external view returns (uint256) {
        return _availableCollateral(user);
    }

    function getPair(bytes32 pairId) external view returns (PairConfig memory) {
        return pairConfigs[pairId];
    }

    function getPosition(address user, bytes32 pairId)
        external
        view
        returns (Position memory)
    {
        return positions[user][pairId];
    }

    function computePnl(address user, bytes32 pairId)
        external
        view
        returns (int256 pricePnl, int256 fundingPnl, int256 totalPnl, uint256 fee)
    {
        Position memory pos = positions[user][pairId];
        if (pos.size == 0) return (0, 0, 0, 0);
        uint256 exitPrice = pairConfigs[pairId].markPrice;

        uint256 openNotional = (pos.size * pos.openPrice) / PRICE_BASE;
        uint256 closeNotional = (pos.size * exitPrice) / PRICE_BASE;
        if (pos.isLong) {
            pricePnl = int256(closeNotional) - int256(openNotional);
        } else {
            pricePnl = int256(openNotional) - int256(closeNotional);
        }
        fundingPnl = _computeFundingPnl(pos.size, pos.entryFunding, pos.isLong, pairId);
        totalPnl = pricePnl + fundingPnl;
        fee = (pos.size * exitPrice * TRADING_FEE_BPS) / (PRICE_BASE * BPS_DENOMINATOR);
    }

    function currentCumulativeFunding(bytes32 pairId)
        public
        view
        pairMustExist(pairId)
        returns (uint256)
    {
        PairConfig storage pair = pairConfigs[pairId];
        if (block.timestamp <= pair.lastFundingTime) return pair.cumulativeFunding;
        uint256 elapsed = block.timestamp - pair.lastFundingTime;
        return pair.cumulativeFunding + elapsed * pair.fundingRatePerSecond;
    }

    function _availableCollateral(address user) internal view returns (uint256) {
        uint256 balance = balances[user];
        uint256 locked = totalLocked[user];
        return balance > locked ? balance - locked : 0;
    }

    function _applyFunding(bytes32 pairId) internal {
        PairConfig storage pair = pairConfigs[pairId];
        if (block.timestamp > pair.lastFundingTime) {
            uint256 elapsed = block.timestamp - pair.lastFundingTime;
            pair.cumulativeFunding += elapsed * pair.fundingRatePerSecond;
            pair.lastFundingTime = block.timestamp;
        }
    }

    function _computeFundingPnl(
        uint256 size,
        uint256 entryFunding,
        bool isLong,
        bytes32 pairId
    ) internal view returns (int256) {
        uint256 current = currentCumulativeFunding(pairId);
        if (current <= entryFunding) return 0;
        uint256 diff = current - entryFunding;
        int256 funding = (int256(size) * int256(diff)) / int256(PRICE_BASE);
        return isLong ? -funding : funding;
    }

    function _closePosition(
        address user,
        bytes32 pairId,
        uint256 exitPrice,
        bool chargeFee
    ) internal returns (uint256 marginReturned) {
        Position storage pos = positions[user][pairId];
        if (pos.size == 0) revert NoPositionExists();
        if (exitPrice == 0) revert InvalidPrice();

        int256 pnl;
        uint256 closeNotional;
        {
            uint256 openNotional = (pos.size * pos.openPrice) / PRICE_BASE;
            closeNotional = (pos.size * exitPrice) / PRICE_BASE;
            if (pos.isLong) {
                pnl = int256(closeNotional) - int256(openNotional);
            } else {
                pnl = int256(openNotional) - int256(closeNotional);
            }
            pnl += _computeFundingPnl(pos.size, pos.entryFunding, pos.isLong, pairId);
        }

        uint256 fee = 0;
        if (chargeFee) {
            fee = (pos.size * exitPrice * TRADING_FEE_BPS) / (PRICE_BASE * BPS_DENOMINATOR);
            feesCollected += fee;
        }

        {
            uint256 margin = pos.margin;
            totalLocked[user] -= margin;
            int256 newBalance = int256(balances[user]) + pnl - int256(fee);
            balances[user] = newBalance > 0 ? uint256(newBalance) : 0;
            int256 returned = int256(margin) + pnl - int256(fee);
            marginReturned = returned > 0 ? uint256(returned) : 0;
        }

        bool isLong = pos.isLong;
        uint256 size = pos.size;
        delete positions[user][pairId];

        emit PositionClosed(user, pairId, isLong, size, exitPrice, pnl, fee, marginReturned);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
