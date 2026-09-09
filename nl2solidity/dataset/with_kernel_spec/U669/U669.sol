// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracle {
    function getPrice() external view returns (uint256);
}

contract PerpetualExchange {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotAdmin();
    error TradingPaused();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error PositionAlreadyOpen();
    error NoOpenPosition();
    error InvalidLeverage();
    error InsufficientMargin();
    error LeverageExceeded();
    error InvalidFee();
    error TransferFailed();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event MarginAdded(address indexed user, uint256 amount);
    event MarginRemoved(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        bool isLong,
        uint256 margin,
        uint256 size,
        uint256 entryPrice,
        uint256 leverage
    );
    event PositionClosed(
        address indexed user,
        bool isLong,
        uint256 size,
        uint256 exitPrice,
        int256 pnl,
        uint256 fee
    );
    event TradingFeeUpdated(uint256 oldFee, uint256 newFee);
    event OracleUpdated(address oldOracle, address newOracle);
    event TradingPausedStateChanged(bool paused);
    event FundingRateUpdated(uint256 newRate);
    event FeesClaimed(address indexed admin, uint256 amount);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MAX_LEVERAGE = 50;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 10; // 0.1%
    uint256 public constant PRICE_PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    IERC20 public immutable collateralToken;
    address public admin;
    address public oracle;
    bool public paused;
    uint256 public tradingFeeBps;
    uint256 public fundingRate;
    uint256 public accumulatedFees;

    struct Position {
        bool isOpen;
        bool isLong;
        uint256 margin;
        uint256 size; // notional size in collateral terms
        uint256 entryPrice;
        uint256 leverage;
    }

    mapping(address => uint256) public collateralBalance;
    mapping(address => Position) public positions;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TradingPaused();
        _;
    }

    constructor(address _collateralToken, address _oracle) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        oracle = _oracle;
        admin = msg.sender;
        tradingFeeBps = DEFAULT_FEE_BPS;
    }

    // -----------------------------------------------------------------------
    // Collateral management
    // -----------------------------------------------------------------------
    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        collateralBalance[msg.sender] += amount;
        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        uint256 available = getAvailableBalance(msg.sender);
        if (amount > available) revert InsufficientBalance();

        collateralBalance[msg.sender] -= amount;
        bool ok = collateralToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function getAvailableBalance(address user) public view returns (uint256) {
        Position storage pos = positions[user];
        uint256 locked = pos.isOpen ? pos.margin : 0;
        return collateralBalance[user] - locked;
    }

    // -----------------------------------------------------------------------
    // Position management
    // -----------------------------------------------------------------------
    function openPosition(
        bool isLong,
        uint256 margin,
        uint256 leverage
    ) external whenNotPaused {
        if (margin == 0) revert ZeroAmount();
        if (leverage == 0 || leverage > MAX_LEVERAGE) revert InvalidLeverage();

        Position storage pos = positions[msg.sender];
        if (pos.isOpen) revert PositionAlreadyOpen();

        if (collateralBalance[msg.sender] < margin) revert InsufficientBalance();

        uint256 price = IOracle(oracle).getPrice();
        if (price == 0) revert ZeroAmount();

        // size = margin * leverage (notional in collateral terms)
        uint256 size = margin * leverage;

        // charge trading fee on notional size
        uint256 fee = (size * tradingFeeBps) / BASIS_POINTS;
        uint256 totalNeeded = margin + fee;

        if (collateralBalance[msg.sender] < totalNeeded) revert InsufficientMargin();

        collateralBalance[msg.sender] -= totalNeeded;
        accumulatedFees += fee;

        pos.isOpen = true;
        pos.isLong = isLong;
        pos.margin = margin;
        pos.size = size;
        pos.entryPrice = price;
        pos.leverage = leverage;

        emit PositionOpened(msg.sender, isLong, margin, size, price, leverage);
    }

    function closePosition() external whenNotPaused {
        Position storage pos = positions[msg.sender];
        if (!pos.isOpen) revert NoOpenPosition();

        uint256 exitPrice = IOracle(oracle).getPrice();
        if (exitPrice == 0) revert ZeroAmount();

        // PnL calculation
        // For long: pnl = size * (exitPrice - entryPrice) / entryPrice
        // For short: pnl = size * (entryPrice - exitPrice) / entryPrice
        int256 pnl;
        if (pos.isLong) {
            if (exitPrice >= pos.entryPrice) {
                pnl = int256((pos.size * (exitPrice - pos.entryPrice)) / pos.entryPrice);
            } else {
                pnl = -int256((pos.size * (pos.entryPrice - exitPrice)) / pos.entryPrice);
            }
        } else {
            if (pos.entryPrice >= exitPrice) {
                pnl = int256((pos.size * (pos.entryPrice - exitPrice)) / pos.entryPrice);
            } else {
                pnl = -int256((pos.size * (exitPrice - pos.entryPrice)) / pos.entryPrice);
            }
        }

        // charge trading fee on notional size
        uint256 fee = (pos.size * tradingFeeBps) / BASIS_POINTS;
        accumulatedFees += fee;

        // settle margin + pnl - fee
        int256 settlement = int256(pos.margin) + pnl - int256(fee);

        if (settlement > 0) {
            collateralBalance[msg.sender] += uint256(settlement);
        }
        // If settlement <= 0, the position is underwater and the margin is lost.
        // In a production system, an insurance fund would cover the deficit.

        emit PositionClosed(msg.sender, pos.isLong, pos.size, exitPrice, pnl, fee);

        // reset position
        pos.isOpen = false;
        pos.isLong = false;
        pos.margin = 0;
        pos.size = 0;
        pos.entryPrice = 0;
        pos.leverage = 0;
    }

    function addMargin(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender];
        if (!pos.isOpen) revert NoOpenPosition();
        if (collateralBalance[msg.sender] < amount) revert InsufficientBalance();

        collateralBalance[msg.sender] -= amount;
        pos.margin += amount;

        emit MarginAdded(msg.sender, amount);
    }

    function removeMargin(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender];
        if (!pos.isOpen) revert NoOpenPosition();
        if (amount >= pos.margin) revert InsufficientMargin();

        pos.margin -= amount;
        collateralBalance[msg.sender] += amount;

        // Ensure leverage does not exceed max after margin removal
        // size = margin * leverage => leverage = size / margin
        uint256 newLeverage = pos.size / pos.margin;
        if (newLeverage > MAX_LEVERAGE) revert LeverageExceeded();

        emit MarginRemoved(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------
    function getPosition(address user)
        external
        view
        returns (
            bool isOpen,
            bool isLong,
            uint256 margin,
            uint256 size,
            uint256 entryPrice,
            uint256 leverage
        )
    {
        Position storage pos = positions[user];
        return (pos.isOpen, pos.isLong, pos.margin, pos.size, pos.entryPrice, pos.leverage);
    }

    function getUnrealizedPnl(address user) external view returns (int256 pnl) {
        Position storage pos = positions[user];
        if (!pos.isOpen) return 0;

        uint256 exitPrice = IOracle(oracle).getPrice();
        if (exitPrice == 0) return 0;

        if (pos.isLong) {
            if (exitPrice >= pos.entryPrice) {
                pnl = int256((pos.size * (exitPrice - pos.entryPrice)) / pos.entryPrice);
            } else {
                pnl = -int256((pos.size * (pos.entryPrice - exitPrice)) / pos.entryPrice);
            }
        } else {
            if (pos.entryPrice >= exitPrice) {
                pnl = int256((pos.size * (pos.entryPrice - exitPrice)) / pos.entryPrice);
            } else {
                pnl = -int256((pos.size * (exitPrice - pos.entryPrice)) / pos.entryPrice);
            }
        }
    }

    // -----------------------------------------------------------------------
    // Admin functions
    // -----------------------------------------------------------------------
    function setTradingFee(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > BASIS_POINTS) revert InvalidFee();
        uint256 oldFee = tradingFeeBps;
        tradingFeeBps = newFeeBps;
        emit TradingFeeUpdated(oldFee, newFeeBps);
    }

    function setOracle(address newOracle) external onlyAdmin {
        if (newOracle == address(0)) revert ZeroAddress();
        address oldOracle = oracle;
        oracle = newOracle;
        emit OracleUpdated(oldOracle, newOracle);
    }

    function setPaused(bool _paused) external onlyAdmin {
        paused = _paused;
        emit TradingPausedStateChanged(_paused);
    }

    function setFundingRate(uint256 newRate) external onlyAdmin {
        fundingRate = newRate;
        emit FundingRateUpdated(newRate);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    function claimFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        bool ok = collateralToken.transfer(admin, amount);
        if (!ok) revert TransferFailed();
        emit FeesClaimed(admin, amount);
    }
}
