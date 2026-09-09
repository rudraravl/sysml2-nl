Looking at the error, the constructor reverts during setUp. The most likely cause is the `decimals()` call on mock tokens that may not implement it. I'll use try-catch to safely handle this.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

contract PredictionMarketLending {
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error AboveMaxLTV();
    error PositionSafe();
    error NoDebt();
    error InvalidPrice();
    error InvalidParameter();
    error InvalidDecimals();
    error LendingPaused();
    error BorrowingPaused();
    error SeizeExceedsCollateral();
    error Reentrancy();
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    uint256 public constant MAX_LTV = 8000;
    uint256 public constant LIQUIDATION_FEE = 50;
    uint256 public constant BPS = 10000;
    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    IERC20 public immutable usdc;
    IERC20 public immutable collateralToken;
    uint256 public immutable usdcScale;
    uint256 public immutable collateralScale;

    address public operator;
    IOracle public oracle;
    bool public lendingPaused;
    bool public borrowingPaused;
    uint256 public borrowRate;
    uint256 public liquidationThreshold;

    uint256 public totalShares;
    mapping(address => uint256) public lenderShares;

    struct Position {
        uint256 collateral;
        uint256 borrowed;
        uint256 interestAccrued;
        uint256 lastUpdate;
    }
    mapping(address => Position) public positions;
    uint256 public totalDebt;

    uint256 private _locked = 1;

    event Supply(address indexed lender, uint256 amount, uint256 shares);
    event Withdraw(address indexed lender, uint256 amount, uint256 shares);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, uint256 amount);
    event Borrow(address indexed borrower, uint256 amount, uint256 newTotalDebt);
    event Repay(address indexed borrower, uint256 amount, uint256 interestPaid);
    event Liquidate(
        address indexed borrower,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 feeAmount
    );
    event ParameterChanged(bytes32 indexed parameter, uint256 data);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event PauseStateChanged(bool lendingPaused, bool borrowingPaused);

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier notLendingPaused() {
        if (lendingPaused) revert LendingPaused();
        _;
    }

    modifier notBorrowingPaused() {
        if (borrowingPaused) revert BorrowingPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address _usdc,
        address _collateralToken,
        address _oracle,
        address _operator,
        uint256 _borrowRate,
        uint256 _liquidationThreshold
    ) {
        if (_usdc == address(0) || _collateralToken == address(0) ||
            _oracle == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_borrowRate > BPS) revert InvalidParameter();
        if (_liquidationThreshold == 0 || _liquidationThreshold > BPS) revert InvalidParameter();

        uint8 usdcDecimals = _safeDecimals(_usdc);
        uint8 collateralDecimals = _safeDecimals(_collateralToken);
        if (usdcDecimals > 18 || collateralDecimals > 18) revert InvalidDecimals();

        usdc = IERC20(_usdc);
        collateralToken = IERC20(_collateralToken);
        oracle = IOracle(_oracle);
        operator = _operator;
        borrowRate = _borrowRate;
        liquidationThreshold = _liquidationThreshold;

        usdcScale = 10 ** (18 - usdcDecimals);
        collateralScale = 10 ** (18 - collateralDecimals);

        emit ParameterChanged("BORROW_RATE", _borrowRate);
        emit ParameterChanged("LIQUIDATION_THRESHOLD", _liquidationThreshold);
    }

    function _safeDecimals(address token) internal view returns (uint8) {
        try IERC20(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function supply(uint256 amount) external nonReentrant notLendingPaused {
        if (amount == 0) revert ZeroAmount();

        uint256 assets = _totalAssets();
        uint256 shares;
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / assets;
        }
        if (shares == 0) revert ZeroShares();

        totalShares += shares;
        lenderShares[msg.sender] += shares;

        _safeTransferFrom(usdc, msg.sender, address(this), amount);
        emit Supply(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external nonReentrant notLendingPaused {
        if (shares == 0) revert ZeroShares();
        if (lenderShares[msg.sender] < shares) revert InsufficientShares();

        uint256 amount = (shares * _totalAssets()) / totalShares;
        if (amount == 0) revert ZeroAmount();
        if (usdc.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        lenderShares[msg.sender] -= shares;
        totalShares -= shares;

        _safeTransfer(usdc, msg.sender, amount);
        emit Withdraw(msg.sender, amount, shares);
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        positions[msg.sender].collateral += amount;
        _safeTransferFrom(collateralToken, msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        Position storage p = positions[msg.sender];
        if (p.collateral < amount) revert InsufficientCollateral();
        p.collateral -= amount;
        if (_getLTV(msg.sender, 0) > MAX_LTV) revert AboveMaxLTV();
        _safeTransfer(collateralToken, msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant notBorrowingPaused {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        if (_getLTV(msg.sender, amount) > MAX_LTV) revert AboveMaxLTV();
        if (usdc.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        Position storage p = positions[msg.sender];
        p.borrowed += amount;
        totalDebt += amount;

        _safeTransfer(usdc, msg.sender, amount);
        emit Borrow(msg.sender, amount, p.borrowed + p.interestAccrued);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _accrue(msg.sender);
        Position storage p = positions[msg.sender];
        uint256 debt = p.borrowed + p.interestAccrued;
        if (debt == 0) revert NoDebt();

        uint256 repayAmount = amount > debt ? debt : amount;
        uint256 interestToRepay = repayAmount > p.interestAccrued ? p.interestAccrued : repayAmount;
        uint256 principalToRepay = repayAmount - interestToRepay;

        p.interestAccrued -= interestToRepay;
        p.borrowed -= principalToRepay;
        totalDebt -= repayAmount;

        _safeTransferFrom(usdc, msg.sender, address(this), repayAmount);
        emit Repay(msg.sender, repayAmount, interestToRepay);
    }

    function liquidate(address borrower, uint256 repayAmount) external nonReentrant {
        if (repayAmount == 0) revert ZeroAmount();
        _accrue(borrower);
        Position storage p = positions[borrower];
        uint256 debt = p.borrowed + p.interestAccrued;
        if (debt == 0) revert NoDebt();
        if (_getLTV(borrower, 0) <= liquidationThreshold) revert PositionSafe();

        uint256 repay = repayAmount > debt ? debt : repayAmount;
        uint256 price = oracle.getPrice(address(collateralToken));
        if (price == 0) revert InvalidPrice();

        uint256 repayWad = repay * usdcScale;
        uint256 seizeValueWad = (repayWad * (BPS + LIQUIDATION_FEE)) / BPS;
        uint256 collateralToSeizeWad = (seizeValueWad * WAD) / price;
        uint256 collateralToSeize = collateralToSeizeWad / collateralScale;
        if (collateralToSeize > p.collateral) revert SeizeExceedsCollateral();

        uint256 interestToRepay = repay > p.interestAccrued ? p.interestAccrued : repay;
        uint256 principalToRepay = repay - interestToRepay;
        uint256 feeAmount = (repayWad * LIQUIDATION_FEE) / BPS / usdcScale;

        p.interestAccrued -= interestToRepay;
        p.borrowed -= principalToRepay;
        p.collateral -= collateralToSeize;
        totalDebt -= repay;

        _safeTransferFrom(usdc, msg.sender, address(this), repay);
        _safeTransfer(collateralToken, msg.sender, collateralToSeize);

        emit Liquidate(borrower, msg.sender, repay, collateralToSeize, feeAmount);
    }

    function setBorrowRate(uint256 newRate) external onlyOperator {
        if (newRate > BPS) revert InvalidParameter();
        borrowRate = newRate;
        emit ParameterChanged("BORROW_RATE", newRate);
    }

    function setLiquidationThreshold(uint256 newThreshold) external onlyOperator {
        if (newThreshold == 0 || newThreshold > BPS) revert InvalidParameter();
        liquidationThreshold = newThreshold;
        emit ParameterChanged("LIQUIDATION_THRESHOLD", newThreshold);
    }

    function setOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(oracle);
        oracle = IOracle(newOracle);
        emit OracleUpdated(old, newOracle);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setLendingPaused(bool paused) external onlyOperator {
        lendingPaused = paused;
        emit PauseStateChanged(lendingPaused, borrowingPaused);
    }

    function setBorrowingPaused(bool paused) external onlyOperator {
        borrowingPaused = paused;
        emit PauseStateChanged(lendingPaused, borrowingPaused);
    }

    function availableLiquidity() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    function getDebt(address borrower) external view returns (uint256 borrowed, uint256 interestAccrued) {
        Position memory p = positions[borrower];
        return (p.borrowed, p.interestAccrued);
    }

    function getLTV(address borrower) external view returns (uint256) {
        return _getLTV(borrower, 0);
    }

    function getCollateralValue(address borrower) external view returns (uint256) {
        Position memory p = positions[borrower];
        uint256 price = oracle.getPrice(address(collateralToken));
        if (price == 0) revert InvalidPrice();
        return ((p.collateral * collateralScale) * price) / WAD;
    }

    function getLenderBalance(address lender) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (lenderShares[lender] * _totalAssets()) / totalShares;
    }

    function _totalAssets() internal view returns (uint256) {
        return usdc.balanceOf(address(this)) + totalDebt;
    }

    function _accrue(address borrower) internal {
        Position storage p = positions[borrower];
        if (p.borrowed == 0) {
            p.lastUpdate = block.timestamp;
            return;
        }
        if (p.lastUpdate == 0) {
            p.lastUpdate = block.timestamp;
            return;
        }
        uint256 timeDelta = block.timestamp - p.lastUpdate;
        if (timeDelta == 0) return;

        uint256 interest = (p.borrowed * borrowRate * timeDelta) / (SECONDS_PER_YEAR * BPS);
        p.interestAccrued += interest;
        totalDebt += interest;
        p.lastUpdate = block.timestamp;
    }

    function _getLTV(address borrower, uint256 extraBorrow) internal view returns (uint256 ltvBps) {
        Position memory p = positions[borrower];
        uint256 debt = p.borrowed + p.interestAccrued + extraBorrow;
        if (debt == 0) return 0;

        uint256 price = oracle.getPrice(address(collateralToken));
        if (price == 0) revert InvalidPrice();

        uint256 collateralValueWad = ((p.collateral * collateralScale) * price) / WAD;
        if (collateralValueWad == 0) return type(uint256).max;

        uint256 debtWad = debt * usdcScale;
        return (debtWad * BPS) / collateralValueWad;
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert SafeTransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert SafeTransferFromFailed();
    }
}
