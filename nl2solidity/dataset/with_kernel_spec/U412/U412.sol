// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IOracle {
    function getPrice(address asset) external view returns (uint256);
}

contract PerpetualFutures {
    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_LEVERAGE_CAP = 100e18;

    address public operator;
    address public treasury;
    IOracle public oracle;
    address public indexAsset;

    uint256 public maxLeverage;
    uint256 public tradingFeeBps;
    uint256 public liquidationPenaltyBps;
    uint256 public maintenanceMarginBps;
    uint256 public minNotionalUsd;
    bool public paused;

    mapping(address => bool) public acceptedTokens;
    mapping(address => uint8) public tokenDecimals;
    mapping(address => mapping(address => uint256)) public accountBalance;
    mapping(address => uint256) public protocolFees;

    struct Position {
        uint256 size;
        uint256 entryPrice;
        uint256 liquidationPrice;
        uint256 collateral;
        bool isLong;
        bool isActive;
    }
    mapping(address => mapping(address => mapping(bool => Position))) public positions;

    event PositionOpened(
        address indexed account,
        address indexed token,
        bool isLong,
        uint256 size,
        uint256 entryPrice,
        uint256 liquidationPrice,
        uint256 collateral
    );
    event PositionIncreased(
        address indexed account,
        address indexed token,
        bool isLong,
        uint256 sizeDelta,
        uint256 newEntryPrice,
        uint256 newLiquidationPrice,
        uint256 collateralDelta
    );
    event PositionDecreased(
        address indexed account,
        address indexed token,
        bool isLong,
        uint256 sizeDelta,
        uint256 newSize,
        uint256 collateralReleased,
        uint256 feeAmount
    );
    event PositionClosed(
        address indexed account,
        address indexed token,
        bool isLong,
        uint256 size,
        uint256 exitPrice,
        uint256 collateralReturned,
        int256 pnlUsd,
        uint256 feeAmount
    );
    event PositionLiquidated(
        address indexed account,
        address indexed token,
        bool isLong,
        uint256 size,
        address indexed liquidator,
        uint256 collateralSeized
    );
    event CollateralDeposited(address indexed account, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed account, address indexed token, uint256 amount);
    event ConfigUpdated(string param, uint256 value);
    event OracleUpdated(address indexed oracle);
    event OperatorUpdated(address indexed operator);
    event TreasuryUpdated(address indexed treasury);
    event TokenAccepted(address indexed token, bool accepted);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    error NotOperator();
    error EnforcedPause();
    error NotAcceptedToken(address token);
    error ZeroAddress();
    error LeverageTooHigh(uint256 leverage, uint256 max);
    error LeverageTooLow(uint256 leverage);
    error InsufficientBalance(uint256 available, uint256 required);
    error NoPosition(address account, address token, bool isLong);
    error PositionExists(address account, address token, bool isLong);
    error InvalidAmount();
    error InvalidPrice();
    error NotLiquidatable(address account, address token, bool isLong);
    error NotionalTooSmall(uint256 notional, uint256 min);
    error FeeTooHigh(uint256 bps);
    error TransferFailed();

    uint256 private _status = 1;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        require(_status == _NOT_ENTERED, "REENTRANT");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    constructor(address _oracle, address _indexAsset, address _treasury) {
        if (_oracle == address(0) || _indexAsset == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        oracle = IOracle(_oracle);
        indexAsset = _indexAsset;
        treasury = _treasury;
        operator = msg.sender;
        maxLeverage = 100e18;
        tradingFeeBps = 8;
        liquidationPenaltyBps = 50;
        maintenanceMarginBps = 50;
        minNotionalUsd = 100e18;
    }

    function _price(address asset) internal view returns (uint256) {
        uint256 p = oracle.getPrice(asset);
        if (p == 0) revert InvalidPrice();
        return p;
    }

    function _valueUsd(address token, uint256 amount) internal view returns (uint256) {
        uint256 p = _price(token);
        uint256 d = uint256(tokenDecimals[token]);
        return (amount * p) / (10 ** d);
    }

    function _amountFromUsd(address token, uint256 usd) internal view returns (uint256) {
        uint256 p = _price(token);
        uint256 d = uint256(tokenDecimals[token]);
        return (usd * (10 ** d)) / p;
    }

    function _leverage(uint256 notionalUsd, uint256 collateralUsd) internal pure returns (uint256) {
        if (collateralUsd == 0) return type(uint256).max;
        return (notionalUsd * WAD) / collateralUsd;
    }

    function _liquidationPrice(uint256 entry, uint256 leverage, bool isLong)
        internal
        view
        returns (uint256)
    {
        if (leverage <= WAD) {
            return isLong ? 0 : type(uint256).max;
        }
        uint256 marginRatio = (maintenanceMarginBps * WAD) / 10000;
        uint256 adj = ((WAD - marginRatio) * WAD) / leverage;
        if (isLong) {
            return (entry * (WAD - adj)) / WAD;
        } else {
            return (entry * (WAD + adj)) / WAD;
        }
    }

    function _pnlUsd(uint256 size, uint256 entry, uint256 current, bool isLong)
        internal
        pure
        returns (int256)
    {
        if (isLong) {
            return (int256(size) * (int256(current) - int256(entry))) / int256(WAD);
        } else {
            return (int256(size) * (int256(entry) - int256(current))) / int256(WAD);
        }
    }

    function _chargeFee(address token, uint256 amount) internal {
        protocolFees[token] += amount;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        if (amount == 0) revert InvalidAmount();
        accountBalance[msg.sender][token] += amount;
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        if (amount == 0) revert InvalidAmount();
        uint256 bal = accountBalance[msg.sender][token];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        accountBalance[msg.sender][token] = bal - amount;
        _safeTransfer(token, msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    function getAvailableCollateral(address user, address token) public view returns (uint256) {
        uint256 bal = accountBalance[user][token];
        uint256 locked;
        Position storage longPos = positions[user][token][true];
        Position storage shortPos = positions[user][token][false];
        if (longPos.isActive) locked += longPos.collateral;
        if (shortPos.isActive) locked += shortPos.collateral;
        return bal >= locked ? bal - locked : 0;
    }

    function openPosition(
        address token,
        uint256 collateralAmount,
        uint256 size,
        bool isLong
    ) external whenNotPaused nonReentrant {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        if (collateralAmount == 0 || size == 0) revert InvalidAmount();
        if (positions[msg.sender][token][isLong].isActive) revert PositionExists(msg.sender, token, isLong);

        uint256 indexPrice = _price(indexAsset);
        uint256 lev;
        uint256 feeToken;
        {
            uint256 notional = (size * indexPrice) / WAD;
            if (notional < minNotionalUsd) revert NotionalTooSmall(notional, minNotionalUsd);
            uint256 colUsd = _valueUsd(token, collateralAmount);
            if (colUsd == 0) revert InvalidPrice();
            lev = (notional * WAD) / colUsd;
            if (lev < WAD) revert LeverageTooLow(lev);
            if (lev > maxLeverage) revert LeverageTooHigh(lev, maxLeverage);
            feeToken = _amountFromUsd(token, (notional * tradingFeeBps) / 10000);
        }
        uint256 needed = collateralAmount + feeToken;
        uint256 bal = accountBalance[msg.sender][token];
        if (bal < needed) revert InsufficientBalance(bal, needed);
        accountBalance[msg.sender][token] = bal - needed;
        _chargeFee(token, feeToken);

        Position storage p = positions[msg.sender][token][isLong];
        p.size = size;
        p.entryPrice = indexPrice;
        p.liquidationPrice = _liquidationPrice(indexPrice, lev, isLong);
        p.collateral = collateralAmount;
        p.isLong = isLong;
        p.isActive = true;

        emit PositionOpened(msg.sender, token, isLong, size, indexPrice, p.liquidationPrice, collateralAmount);
    }

    function increasePosition(
        address token,
        uint256 addCollateral,
        uint256 addSize,
        bool isLong
    ) external whenNotPaused nonReentrant {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        if (addCollateral == 0 || addSize == 0) revert InvalidAmount();
        Position storage p = positions[msg.sender][token][isLong];
        if (!p.isActive) revert NoPosition(msg.sender, token, isLong);

        uint256 indexPrice = _price(indexAsset);
        uint256 feeToken;
        {
            uint256 addedNotional = (addSize * indexPrice) / WAD;
            feeToken = _amountFromUsd(token, (addedNotional * tradingFeeBps) / 10000);
        }
        uint256 needed = addCollateral + feeToken;
        uint256 bal = accountBalance[msg.sender][token];
        if (bal < needed) revert InsufficientBalance(bal, needed);

        uint256 newEntry;
        uint256 newLiq;
        {
            uint256 newColUsd = _valueUsd(token, p.collateral + addCollateral);
            uint256 newSize = p.size + addSize;
            uint256 newNotional = (newSize * indexPrice) / WAD;
            uint256 lev = (newNotional * WAD) / newColUsd;
            if (lev > maxLeverage) revert LeverageTooHigh(lev, maxLeverage);
            newEntry = ((p.size * p.entryPrice) + (addSize * indexPrice)) / newSize;
            newLiq = _liquidationPrice(newEntry, lev, isLong);
            p.size = newSize;
            p.collateral = p.collateral + addCollateral;
        }
        accountBalance[msg.sender][token] = bal - needed;
        _chargeFee(token, feeToken);
        p.entryPrice = newEntry;
        p.liquidationPrice = newLiq;

        emit PositionIncreased(msg.sender, token, isLong, addSize, newEntry, newLiq, addCollateral);
    }

    function decreasePosition(address token, uint256 reduceSize, bool isLong)
        external
        whenNotPaused
        nonReentrant
    {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        if (reduceSize == 0) revert InvalidAmount();
        Position storage p = positions[msg.sender][token][isLong];
        if (!p.isActive) revert NoPosition(msg.sender, token, isLong);
        if (reduceSize > p.size) revert InvalidAmount();

        uint256 indexPrice = _price(indexAsset);
        uint256 toReturn;
        uint256 feeToken;
        {
            uint256 colPrice = _price(token);
            uint256 dec = uint256(tokenDecimals[token]);
            int256 pnlPortionUsd = _pnlUsd(reduceSize, p.entryPrice, indexPrice, p.isLong);
            int256 pnlPortionToken = (pnlPortionUsd * int256(10 ** dec)) / int256(colPrice);
            uint256 baseReleased = (p.collateral * reduceSize) / p.size;
            int256 totalRelease = int256(baseReleased) + pnlPortionToken;
            if (totalRelease < 0) totalRelease = 0;
            uint256 release = uint256(totalRelease);
            uint256 reducedNotional = (reduceSize * indexPrice) / WAD;
            feeToken = _amountFromUsd(token, (reducedNotional * tradingFeeBps) / 10000);
            if (feeToken > release) feeToken = release;
            toReturn = release - feeToken;
            p.size = p.size - reduceSize;
            p.collateral = p.collateral - baseReleased;
        }
        accountBalance[msg.sender][token] += toReturn;
        _chargeFee(token, feeToken);

        if (p.size == 0) {
            p.isActive = false;
            p.entryPrice = 0;
            p.liquidationPrice = 0;
        }

        emit PositionDecreased(msg.sender, token, isLong, reduceSize, p.size, toReturn, feeToken);
    }

    function closePosition(address token, bool isLong) external nonReentrant {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        Position storage p = positions[msg.sender][token][isLong];
        if (!p.isActive) revert NoPosition(msg.sender, token, isLong);

        uint256 closedSize = p.size;
        uint256 indexPrice = _price(indexAsset);
        int256 pnl;
        uint256 feeToken;
        {
            uint256 notional = (closedSize * indexPrice) / WAD;
            pnl = _pnlUsd(closedSize, p.entryPrice, indexPrice, p.isLong);
            feeToken = _amountFromUsd(token, (notional * tradingFeeBps) / 10000);
        }
        uint256 toReturn;
        {
            uint256 colPrice = _price(token);
            int256 pnlToken = (pnl * int256(10 ** uint256(tokenDecimals[token]))) / int256(colPrice);
            int256 retSigned = int256(p.collateral) + pnlToken;
            if (retSigned < 0) retSigned = 0;
            uint256 retToken = uint256(retSigned);
            if (feeToken > retToken) feeToken = retToken;
            toReturn = retToken - feeToken;
        }
        p.isActive = false;
        p.size = 0;
        p.entryPrice = 0;
        p.liquidationPrice = 0;
        p.collateral = 0;

        accountBalance[msg.sender][token] += toReturn;
        _chargeFee(token, feeToken);

        emit PositionClosed(msg.sender, token, isLong, closedSize, indexPrice, toReturn, pnl, feeToken);
    }

    function liquidatePosition(address account, address token, bool isLong)
        external
        nonReentrant
    {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        Position storage p = positions[account][token][isLong];
        if (!p.isActive) revert NoPosition(account, token, isLong);

        uint256 indexPrice = _price(indexAsset);
        bool liq;
        if (p.isLong) {
            liq = indexPrice <= p.liquidationPrice;
        } else {
            liq = indexPrice >= p.liquidationPrice;
        }
        if (!liq) revert NotLiquidatable(account, token, isLong);

        uint256 closedSize = p.size;
        uint256 seized;
        uint256 ownerReturn;
        {
            uint256 colPrice = _price(token);
            int256 pnl = _pnlUsd(closedSize, p.entryPrice, indexPrice, p.isLong);
            int256 pnlToken = (pnl * int256(10 ** uint256(tokenDecimals[token]))) / int256(colPrice);
            int256 remaining = int256(p.collateral) + pnlToken;
            if (remaining < 0) remaining = 0;
            uint256 remainingU = uint256(remaining);
            seized = (remainingU * liquidationPenaltyBps) / 10000;
            if (seized > remainingU) seized = remainingU;
            ownerReturn = remainingU - seized;
        }
        p.isActive = false;
        p.size = 0;
        p.entryPrice = 0;
        p.liquidationPrice = 0;
        p.collateral = 0;

        accountBalance[account][token] += ownerReturn;
        _safeTransfer(token, msg.sender, seized);

        emit PositionLiquidated(account, token, isLong, closedSize, msg.sender, seized);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        operator = newOperator;
        emit OperatorUpdated(newOperator);
    }

    function setOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        oracle = IOracle(newOracle);
        emit OracleUpdated(newOracle);
    }

    function setTreasury(address newTreasury) external onlyOperator {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function setMaxLeverage(uint256 newMax) external onlyOperator {
        if (newMax > MAX_LEVERAGE_CAP) revert LeverageTooHigh(newMax, MAX_LEVERAGE_CAP);
        if (newMax < WAD) revert LeverageTooLow(newMax);
        maxLeverage = newMax;
        emit ConfigUpdated("maxLeverage", newMax);
    }

    function setTradingFeeBps(uint256 newBps) external onlyOperator {
        if (newBps > 10000) revert FeeTooHigh(newBps);
        tradingFeeBps = newBps;
        emit ConfigUpdated("tradingFeeBps", newBps);
    }

    function setLiquidationPenaltyBps(uint256 newBps) external onlyOperator {
        if (newBps > 10000) revert FeeTooHigh(newBps);
        liquidationPenaltyBps = newBps;
        emit ConfigUpdated("liquidationPenaltyBps", newBps);
    }

    function setMaintenanceMarginBps(uint256 newBps) external onlyOperator {
        if (newBps > 10000) revert FeeTooHigh(newBps);
        maintenanceMarginBps = newBps;
        emit ConfigUpdated("maintenanceMarginBps", newBps);
    }

    function setMinNotionalUsd(uint256 newMin) external onlyOperator {
        minNotionalUsd = newMin;
        emit ConfigUpdated("minNotionalUsd", newMin);
    }

    function setTokenAccepted(address token, bool accepted) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        acceptedTokens[token] = accepted;
        if (accepted) {
            tokenDecimals[token] = IERC20(token).decimals();
        }
        emit TokenAccepted(token, accepted);
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function withdrawFees(address token, uint256 amount) external onlyOperator nonReentrant {
        if (!acceptedTokens[token]) revert NotAcceptedToken(token);
        if (amount == 0) revert InvalidAmount();
        uint256 avail = protocolFees[token];
        if (amount > avail) revert InsufficientBalance(avail, amount);
        protocolFees[token] = avail - amount;
        _safeTransfer(token, treasury, amount);
        emit FeesWithdrawn(token, treasury, amount);
    }

    function getPosition(address user, address token, bool isLong)
        external
        view
        returns (Position memory)
    {
        return positions[user][token][isLong];
    }

    function getCurrentNotionalUsd(address user, address token, bool isLong)
        external
        view
        returns (uint256)
    {
        Position storage p = positions[user][token][isLong];
        if (!p.isActive) return 0;
        return (p.size * _price(indexAsset)) / WAD;
    }

    function getCurrentLeverage(address user, address token, bool isLong)
        external
        view
        returns (uint256)
    {
        Position storage p = positions[user][token][isLong];
        if (!p.isActive) return 0;
        uint256 notional = (p.size * _price(indexAsset)) / WAD;
        uint256 colUsd = _valueUsd(token, p.collateral);
        if (colUsd == 0) revert InvalidPrice();
        return _leverage(notional, colUsd);
    }

    function isLiquidatable(address user, address token, bool isLong)
        external
        view
        returns (bool)
    {
        Position storage p = positions[user][token][isLong];
        if (!p.isActive) return false;
        uint256 indexPrice = _price(indexAsset);
        if (p.isLong) {
            return indexPrice <= p.liquidationPrice;
        } else {
            return indexPrice >= p.liquidationPrice;
        }
    }
}
