// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success, "SafeERC20: transfer failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transfer returned false");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success, "SafeERC20: transferFrom failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transferFrom returned false");
        }
    }
}

contract ReentrancyGuard {
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

contract P2PLendingMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 10000;
    uint256 internal constant MAX_LTV_CAP_BPS = 8000; // 80%
    uint256 internal constant MAX_ORIGINATION_FEE_BPS = 1000; // 10%
    uint256 internal constant MAX_LIQUIDATION_BONUS_BPS = 5000; // 50%
    uint256 internal constant MAX_RATE_PER_SECOND = 1e12; // sanity bound
    uint256 internal constant DEFAULT_ORIGINATION_FEE_BPS = 10; // 0.1%

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error SameToken();
    error DecimalsTooHigh();
    error MarketExists();
    error MarketNotExists();
    error NotOperator();
    error PoolPaused();
    error ZeroAmount();
    error ZeroTransfer();
    error InsufficientLiquidity();
    error InsufficientBalance();
    error InsufficientCollateral();
    error BorrowExceedsMaxLtv();
    error WithdrawCollateralViolatesLtv();
    error NoDebt();
    error RepayTooSmall();
    error PositionHealthy();
    error SelfLiquidate();
    error ZeroRepayment();
    error ZeroCollateralSeized();
    error NoFees();
    error InvalidMaxLtv();
    error InvalidLiquidationThreshold();
    error InvalidInterestRate();
    error InvalidOriginationFee();
    error InvalidLiquidationBonus();
    error InvalidExchangeRate();

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Market {
        address collateralToken;
        address loanToken;
        uint8 collateralDecimals;
        uint8 loanDecimals;
        uint256 maxLtvBps;
        uint256 liquidationThresholdBps;
        uint256 interestRatePerSecond;
        uint256 originationFeeBps;
        uint256 liquidationBonusBps;
        uint256 collateralToLoanRate; // WAD: how many loan-wad per collateral-wad
        uint256 borrowIndex;
        uint256 lastAccrualTime;
        uint256 totalCollateral; // WAD
        uint256 totalLiquidity;  // WAD
        uint256 totalDebt;       // WAD
        uint256 accruedFees;     // WAD
        bool active;
    }

    struct Borrower {
        uint256 collateral;              // WAD
        uint256 debtAmount;              // WAD (debt snapshot at last change)
        uint256 borrowIndexAtLastChange; // global index captured at last change
    }

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public operator;
    bool public paused;

    mapping(bytes32 => Market) public markets;
    mapping(bytes32 => mapping(address => uint256)) public lenderDeposits; // WAD
    mapping(bytes32 => mapping(address => Borrower)) public borrowers;
    bytes32[] public marketIds;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarketCreated(
        bytes32 indexed marketId,
        address indexed collateralToken,
        address indexed loanToken,
        uint256 maxLtvBps,
        uint256 liquidationThresholdBps,
        uint256 interestRatePerSecond,
        uint256 originationFeeBps,
        uint256 liquidationBonusBps,
        uint256 collateralToLoanRate
    );
    event MarketParametersUpdated(
        bytes32 indexed marketId,
        uint256 maxLtvBps,
        uint256 liquidationThresholdBps,
        uint256 interestRatePerSecond,
        uint256 originationFeeBps,
        uint256 liquidationBonusBps,
        uint256 collateralToLoanRate
    );
    event LiquidityDeposited(address indexed user, bytes32 indexed marketId, uint256 amount);
    event LiquidityWithdrawn(address indexed user, bytes32 indexed marketId, uint256 amount);
    event CollateralDeposited(address indexed user, bytes32 indexed marketId, uint256 amount);
    event CollateralWithdrawn(address indexed user, bytes32 indexed marketId, uint256 amount);
    event Borrowed(address indexed borrower, bytes32 indexed marketId, uint256 amount, uint256 fee);
    event Repaid(address indexed borrower, bytes32 indexed marketId, uint256 amount, uint256 debtReduction);
    event Liquidated(
        address indexed liquidator,
        address indexed borrower,
        bytes32 indexed marketId,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event FeesWithdrawn(bytes32 indexed marketId, address indexed to, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Paused(bool paused);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PoolPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        operator = msg.sender;
        emit OperatorUpdated(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                      MARKET ADMINISTRATION
    //////////////////////////////////////////////////////////////*/

    function createMarket(
        address collateralToken,
        address loanToken,
        uint256 maxLtvBps,
        uint256 liquidationThresholdBps,
        uint256 interestRatePerSecond,
        uint256 liquidationBonusBps,
        uint256 collateralToLoanRate
    ) external onlyOperator returns (bytes32 marketId) {
        if (collateralToken == address(0) || loanToken == address(0)) revert ZeroAddress();
        if (collateralToken == loanToken) revert SameToken();

        if (maxLtvBps > MAX_LTV_CAP_BPS) revert InvalidMaxLtv();
        if (liquidationThresholdBps < maxLtvBps || liquidationThresholdBps > BPS) {
            revert InvalidLiquidationThreshold();
        }
        if (interestRatePerSecond > MAX_RATE_PER_SECOND) revert InvalidInterestRate();
        if (liquidationBonusBps > MAX_LIQUIDATION_BONUS_BPS) revert InvalidLiquidationBonus();
        if (collateralToLoanRate == 0) revert InvalidExchangeRate();

        marketId = keccak256(abi.encodePacked(collateralToken, loanToken));
        if (markets[marketId].collateralToken != address(0)) revert MarketExists();

        uint8 cDec = IERC20Metadata(collateralToken).decimals();
        uint8 lDec = IERC20Metadata(loanToken).decimals();
        if (cDec > 18 || lDec > 18) revert DecimalsTooHigh();

        Market storage m = markets[marketId];
        m.collateralToken = collateralToken;
        m.loanToken = loanToken;
        m.collateralDecimals = cDec;
        m.loanDecimals = lDec;
        m.maxLtvBps = maxLtvBps;
        m.liquidationThresholdBps = liquidationThresholdBps;
        m.interestRatePerSecond = interestRatePerSecond;
        m.originationFeeBps = DEFAULT_ORIGINATION_FEE_BPS;
        m.liquidationBonusBps = liquidationBonusBps;
        m.collateralToLoanRate = collateralToLoanRate;
        m.borrowIndex = WAD;
        m.lastAccrualTime = block.timestamp;
        m.active = true;

        marketIds.push(marketId);

        emit MarketCreated(
            marketId,
            collateralToken,
            loanToken,
            maxLtvBps,
            liquidationThresholdBps,
            interestRatePerSecond,
            DEFAULT_ORIGINATION_FEE_BPS,
            liquidationBonusBps,
            collateralToLoanRate
        );
    }

    function setMarketParameters(
        bytes32 marketId,
        uint256 maxLtvBps,
        uint256 liquidationThresholdBps,
        uint256 interestRatePerSecond,
        uint256 liquidationBonusBps,
        uint256 collateralToLoanRate
    ) external onlyOperator {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();

        if (maxLtvBps > MAX_LTV_CAP_BPS) revert InvalidMaxLtv();
        if (liquidationThresholdBps < maxLtvBps || liquidationThresholdBps > BPS) {
            revert InvalidLiquidationThreshold();
        }
        if (interestRatePerSecond > MAX_RATE_PER_SECOND) revert InvalidInterestRate();
        if (liquidationBonusBps > MAX_LIQUIDATION_BONUS_BPS) revert InvalidLiquidationBonus();
        if (collateralToLoanRate == 0) revert InvalidExchangeRate();

        _accrueInterest(marketId);

        market.maxLtvBps = maxLtvBps;
        market.liquidationThresholdBps = liquidationThresholdBps;
        market.interestRatePerSecond = interestRatePerSecond;
        market.liquidationBonusBps = liquidationBonusBps;
        market.collateralToLoanRate = collateralToLoanRate;

        emit MarketParametersUpdated(
            marketId,
            maxLtvBps,
            liquidationThresholdBps,
            interestRatePerSecond,
            market.originationFeeBps,
            liquidationBonusBps,
            collateralToLoanRate
        );
    }

    function setOriginationFee(bytes32 marketId, uint256 originationFeeBps) external onlyOperator {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (originationFeeBps > MAX_ORIGINATION_FEE_BPS) revert InvalidOriginationFee();

        _accrueInterest(marketId);

        market.originationFeeBps = originationFeeBps;

        emit MarketParametersUpdated(
            marketId,
            market.maxLtvBps,
            market.liquidationThresholdBps,
            market.interestRatePerSecond,
            originationFeeBps,
            market.liquidationBonusBps,
            market.collateralToLoanRate
        );
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit Paused(_paused);
    }

    function withdrawFees(bytes32 marketId, address to) external onlyOperator nonReentrant {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (to == address(0)) revert ZeroAddress();

        _accrueInterest(marketId);

        uint256 feeWad = market.accruedFees;
        if (feeWad == 0) revert NoFees();

        uint256 nativeFee = _fromWadDown(feeWad, market.loanDecimals);
        if (nativeFee == 0) revert NoFees();

        market.accruedFees = feeWad - _toWad(nativeFee, market.loanDecimals);

        IERC20(market.loanToken).safeTransfer(to, nativeFee);

        emit FeesWithdrawn(marketId, to, nativeFee);
    }

    /*//////////////////////////////////////////////////////////////
                      LENDER INTERFACE
    //////////////////////////////////////////////////////////////*/

    function depositLiquidity(bytes32 marketId, uint256 amount) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(marketId);

        uint256 wadAmount = _toWad(amount, market.loanDecimals);

        lenderDeposits[marketId][msg.sender] += wadAmount;
        market.totalLiquidity += wadAmount;

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityDeposited(msg.sender, marketId, amount);
    }

    function withdrawLiquidity(bytes32 marketId, uint256 amount) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(marketId);

        uint256 wadAmount = _toWad(amount, market.loanDecimals);
        uint256 userBalance = lenderDeposits[marketId][msg.sender];

        if (wadAmount > userBalance) revert InsufficientBalance();
        if (wadAmount > market.totalLiquidity) revert InsufficientLiquidity();

        lenderDeposits[marketId][msg.sender] = userBalance - wadAmount;
        market.totalLiquidity -= wadAmount;

        IERC20(market.loanToken).safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, marketId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                      BORROWER INTERFACE
    //////////////////////////////////////////////////////////////*/

    function depositCollateral(bytes32 marketId, uint256 amount) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(marketId);

        uint256 wadAmount = _toWad(amount, market.collateralDecimals);

        borrowers[marketId][msg.sender].collateral += wadAmount;
        market.totalCollateral += wadAmount;

        IERC20(market.collateralToken).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, marketId, amount);
    }

    function withdrawCollateral(bytes32 marketId, uint256 amount) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (amount == 0) revert ZeroAmount();

        uint256 wadAmount = _toWad(amount, market.collateralDecimals);
        Borrower storage borrower = borrowers[marketId][msg.sender];

        if (wadAmount > borrower.collateral) revert InsufficientCollateral();

        _accrueInterest(marketId);

        uint256 debt = _currentDebt(market, borrower);
        if (debt > 0) {
            uint256 remainingCollateral = borrower.collateral - wadAmount;
            if (!_isBorrowerSafe(market, remainingCollateral, debt)) {
                revert WithdrawCollateralViolatesLtv();
            }
        }

        borrower.collateral -= wadAmount;
        market.totalCollateral -= wadAmount;

        IERC20(market.collateralToken).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, marketId, amount);
    }

    function borrow(bytes32 marketId, uint256 amount) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(marketId);

        uint256 borrowWad = _toWad(amount, market.loanDecimals);
        uint256 feeNative = (amount * market.originationFeeBps) / BPS;
        uint256 disburseNative = amount - feeNative;
        if (disburseNative == 0) revert ZeroTransfer();

        if (borrowWad > market.totalLiquidity) revert InsufficientLiquidity();

        Borrower storage borrower = borrowers[marketId][msg.sender];
        uint256 newDebt = _currentDebt(market, borrower) + borrowWad;

        if (!_isBorrowerSafe(market, borrower.collateral, newDebt)) revert BorrowExceedsMaxLtv();

        borrower.debtAmount = newDebt;
        borrower.borrowIndexAtLastChange = market.borrowIndex;

        market.totalDebt += borrowWad;
        market.totalLiquidity -= borrowWad;
        market.accruedFees += _toWad(feeNative, market.loanDecimals);

        IERC20(market.loanToken).safeTransfer(msg.sender, disburseNative);

        emit Borrowed(msg.sender, marketId, amount, feeNative);
    }

    function repay(bytes32 marketId, uint256 amount) external nonReentrant returns (uint256 nativeRepaid) {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(marketId);

        Borrower storage borrower = borrowers[marketId][msg.sender];
        uint256 debt = _currentDebt(market, borrower);
        if (debt == 0) revert NoDebt();

        nativeRepaid = _computeNativeRepay(amount, debt, market.loanDecimals);
        if (nativeRepaid == 0 || nativeRepaid > amount) revert RepayTooSmall();

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), nativeRepaid);

        uint256 transferredWad = _applyRepay(market, borrower, debt, nativeRepaid, market.loanDecimals);

        emit Repaid(msg.sender, marketId, nativeRepaid, transferredWad);
    }

    function liquidate(
        bytes32 marketId,
        address borrowerAddr,
        uint256 repayAmount
    ) external nonReentrant returns (uint256 collateralSeized, uint256 debtRepaid) {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (borrowerAddr == msg.sender) revert SelfLiquidate();
        if (repayAmount == 0) revert ZeroAmount();

        _accrueInterest(marketId);

        Borrower storage borrower = borrowers[marketId][borrowerAddr];
        uint256 debt = _currentDebt(market, borrower);
        if (debt == 0) revert NoDebt();

        if (
            debt * BPS * WAD <=
            borrower.collateral * market.collateralToLoanRate * market.liquidationThresholdBps
        ) revert PositionHealthy();

        debtRepaid = _computeNativeRepay(repayAmount, debt, market.loanDecimals);
        if (debtRepaid == 0) revert ZeroRepayment();

        IERC20(market.loanToken).safeTransferFrom(msg.sender, address(this), debtRepaid);

        uint256 transferredWad = _applyRepay(market, borrower, debt, debtRepaid, market.loanDecimals);

        collateralSeized = _seizeCollateral(market, borrower, transferredWad);

        emit Liquidated(msg.sender, borrowerAddr, marketId, transferredWad, _toWad(collateralSeized, market.collateralDecimals));
    }

    /*//////////////////////////////////////////////////////////////
                      VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function getMarketCount() external view returns (uint256) {
        return marketIds.length;
    }

    function getMarketId(address collateralToken, address loanToken) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(collateralToken, loanToken));
    }

    function currentDebt(bytes32 marketId, address user) external view returns (uint256) {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        return _previewDebt(market, borrowers[marketId][user]);
    }

    function borrowerPosition(bytes32 marketId, address user)
        external
        view
        returns (uint256 collateral, uint256 debt)
    {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        Borrower storage borrower = borrowers[marketId][user];
        return (borrower.collateral, _previewDebt(market, borrower));
    }

    function isLiquidatable(bytes32 marketId, address user) external view returns (bool) {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();

        Borrower storage borrower = borrowers[marketId][user];
        uint256 debt = _previewDebt(market, borrower);
        if (debt == 0) return false;

        return debt * BPS * WAD >
            borrower.collateral * market.collateralToLoanRate * market.liquidationThresholdBps;
    }

    function lenderBalance(bytes32 marketId, address user) external view returns (uint256) {
        return lenderDeposits[marketId][user];
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _accrueInterest(bytes32 marketId) internal {
        Market storage market = markets[marketId];
        if (market.collateralToken == address(0)) revert MarketNotExists();
        if (!market.active) return;

        uint256 elapsed = block.timestamp - market.lastAccrualTime;
        if (elapsed == 0) return;

        uint256 interestFactor = WAD + (market.interestRatePerSecond * elapsed);
        market.borrowIndex = (market.borrowIndex * interestFactor) / WAD;
        market.totalDebt = (market.totalDebt * interestFactor) / WAD;
        market.lastAccrualTime = block.timestamp;
    }

    function _currentDebt(Market storage market, Borrower storage borrower)
        internal
        view
        returns (uint256)
    {
        if (borrower.debtAmount == 0) return 0;
        if (borrower.borrowIndexAtLastChange == 0) return borrower.debtAmount;
        return (borrower.debtAmount * market.borrowIndex) / borrower.borrowIndexAtLastChange;
    }

    function _previewDebt(Market storage market, Borrower storage borrower)
        internal
        view
        returns (uint256)
    {
        if (borrower.debtAmount == 0) return 0;

        uint256 previewIndex = market.borrowIndex;
        uint256 elapsed = block.timestamp - market.lastAccrualTime;
        if (elapsed > 0 && market.interestRatePerSecond > 0) {
            previewIndex = (previewIndex * (WAD + market.interestRatePerSecond * elapsed)) / WAD;
        }

        if (borrower.borrowIndexAtLastChange == 0) return borrower.debtAmount;
        return (borrower.debtAmount * previewIndex) / borrower.borrowIndexAtLastChange;
    }

    function _isBorrowerSafe(Market storage market, uint256 collateral, uint256 debt)
        internal
        view
        returns (bool)
    {
        if (debt == 0) return true;
        return debt * BPS * WAD <=
            collateral * market.collateralToLoanRate * market.maxLtvBps;
    }

    function _computeNativeRepay(uint256 amount, uint256 debt, uint8 decimals)
        internal
        pure
        returns (uint256 nativeRepay)
    {
        uint256 requestedWad = _toWad(amount, decimals);
        uint256 repayWad = requestedWad > debt ? debt : requestedWad;
        nativeRepay = _fromWadUp(repayWad, decimals);
    }

    function _applyRepay(
        Market storage market,
        Borrower storage borrower,
        uint256 debt,
        uint256 nativeRepay,
        uint8 decimals
    ) internal returns (uint256 transferredWad) {
        transferredWad = _toWad(nativeRepay, decimals);
        if (transferredWad > debt) {
            market.accruedFees += transferredWad - debt;
            transferredWad = debt;
        }

        borrower.debtAmount = debt - transferredWad;
        borrower.borrowIndexAtLastChange = market.borrowIndex;

        market.totalDebt -= transferredWad;
        market.totalLiquidity += transferredWad;
    }

    function _seizeCollateral(
        Market storage market,
        Borrower storage borrower,
        uint256 repayWad
    ) internal returns (uint256 nativeSeize) {
        uint256 bonusFactor = BPS + market.liquidationBonusBps;
        uint256 seizureValue = (repayWad * bonusFactor) / BPS;
        uint256 maxSeizeWad = (seizureValue * WAD) / market.collateralToLoanRate;
        if (maxSeizeWad > borrower.collateral) {
            maxSeizeWad = borrower.collateral;
        }

        nativeSeize = _fromWadDown(maxSeizeWad, market.collateralDecimals);
        if (nativeSeize == 0) revert ZeroCollateralSeized();

        uint256 actualSeizeWad = _toWad(nativeSeize, market.collateralDecimals);

        borrower.collateral -= actualSeizeWad;
        market.totalCollateral -= actualSeizeWad;

        IERC20(market.collateralToken).safeTransfer(msg.sender, nativeSeize);
    }

    function _toWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals > 18) revert DecimalsTooHigh();
        if (decimals == 18) return amount;
        uint256 scale = 10 ** (18 - decimals);
        return amount * scale;
    }

    function _fromWadDown(uint256 wad, uint8 decimals) internal pure returns (uint256) {
        if (decimals > 18) revert DecimalsTooHigh();
        if (decimals == 18) return wad;
        uint256 scale = 10 ** (18 - decimals);
        return wad / scale;
    }

    function _fromWadUp(uint256 wad, uint8 decimals) internal pure returns (uint256) {
        if (decimals > 18) revert DecimalsTooHigh();
        if (decimals == 18) return wad;
        uint256 scale = 10 ** (18 - decimals);
        return (wad + scale - 1) / scale;
    }
}
