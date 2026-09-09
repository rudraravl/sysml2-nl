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
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
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
    uint256 private _status = NOT_ENTERED;

    error ReentrantCall();

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface ISyntheticToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract SyntheticAssetManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 31_536_000;
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 1.5e18; // 150%
    uint256 public constant DEFAULT_STABILITY_FEE_RATE = 0.005e18; // 0.5% per year
    uint256 public constant MAX_LIQUIDATION_PENALTY = 0.2e18; // 20%

    // ============ State ============
    IERC20 public immutable collateralToken;
    IPriceOracle public oracle;
    address public operator;

    struct SynthConfig {
        bool exists;
        bool active;
        bool mintPaused;
        bool redeemPaused;
        uint256 liquidationThreshold; // WAD, e.g. 1.3e18 = 130%
        uint256 liquidationPenalty;   // WAD, e.g. 0.1e18 = 10%
        uint256 stabilityFeeRate;     // WAD per year, e.g. 0.005e18 = 0.5%
        uint256 totalDebt;            // total outstanding synth debt
    }

    mapping(address => SynthConfig) public synthConfigs;
    address[] public allSynths;

    mapping(address => uint256) public userCollateral;
    mapping(address => mapping(address => uint256)) public userDebt;
    mapping(address => mapping(address => uint256)) public userLastAccrual;

    // ============ Events ============
    event OracleSet(address indexed oracle);
    event OperatorSet(address indexed operator);
    event SynthAdded(
        address indexed synth,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 stabilityFeeRate
    );
    event SynthActiveToggled(address indexed synth, bool active);
    event MintPauseToggled(address indexed synth, bool paused);
    event RedeemPauseToggled(address indexed synth, bool paused);
    event LiquidationThresholdSet(address indexed synth, uint256 threshold);
    event LiquidationPenaltySet(address indexed synth, uint256 penalty);
    event StabilityFeeRateSet(address indexed synth, uint256 rate);
    event FeesAccrued(address indexed user, address indexed synth, uint256 fee);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event SyntheticMinted(address indexed user, address indexed synth, uint256 amount);
    event SyntheticRepaid(address indexed user, address indexed synth, uint256 amount);
    event PositionLiquidated(
        address indexed liquidator,
        address indexed user,
        address indexed synth,
        uint256 debtCovered,
        uint256 collateralSeized
    );

    // ============ Errors ============
    error ZeroAmount();
    error ZeroAddress();
    error SynthNotFound(address synth);
    error SynthNotActive(address synth);
    error SynthAlreadyExists(address synth);
    error MintPaused(address synth);
    error RedeemPaused(address synth);
    error InsufficientCollateral();
    error BelowCollateralizationRatio();
    error NotUndercollateralized();
    error InsufficientDebt();
    error InvalidPrice();
    error InvalidConfig();
    error LiquidationPenaltyTooHigh();
    error NotOperator();

    // ============ Modifiers ============
    modifier existingSynth(address synth) {
        if (!synthConfigs[synth].exists) revert SynthNotFound(synth);
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner) revert NotOperator();
        _;
    }

    // ============ Constructor ============
    constructor(address _collateralToken, address _oracle) Ownable(msg.sender) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        oracle = IPriceOracle(_oracle);
        operator = msg.sender;
        emit OracleSet(_oracle);
        emit OperatorSet(msg.sender);
    }

    // ============ Admin — Owner ============
    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(_oracle);
        emit OracleSet(_oracle);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorSet(_operator);
    }

    function addSynth(
        address synth,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 stabilityFeeRate
    ) external onlyOwner {
        if (synth == address(0)) revert ZeroAddress();
        if (synthConfigs[synth].exists) revert SynthAlreadyExists(synth);
        if (liquidationThreshold < WAD) revert InvalidConfig();
        if (liquidationPenalty > MAX_LIQUIDATION_PENALTY) revert LiquidationPenaltyTooHigh();

        uint256 feeRate = stabilityFeeRate == 0 ? DEFAULT_STABILITY_FEE_RATE : stabilityFeeRate;

        synthConfigs[synth] = SynthConfig({
            exists: true,
            active: true,
            mintPaused: false,
            redeemPaused: false,
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            stabilityFeeRate: feeRate,
            totalDebt: 0
        });
        allSynths.push(synth);

        emit SynthAdded(synth, liquidationThreshold, liquidationPenalty, feeRate);
    }

    // ============ Admin — Operator ============
    function setSynthActive(address synth, bool active) external onlyOperator existingSynth(synth) {
        synthConfigs[synth].active = active;
        emit SynthActiveToggled(synth, active);
    }

    function setMintPaused(address synth, bool paused) external onlyOperator existingSynth(synth) {
        synthConfigs[synth].mintPaused = paused;
        emit MintPauseToggled(synth, paused);
    }

    function setRedeemPaused(address synth, bool paused) external onlyOperator existingSynth(synth) {
        synthConfigs[synth].redeemPaused = paused;
        emit RedeemPauseToggled(synth, paused);
    }

    function setLiquidationThreshold(address synth, uint256 threshold)
        external
        onlyOperator
        existingSynth(synth)
    {
        if (threshold < WAD) revert InvalidConfig();
        synthConfigs[synth].liquidationThreshold = threshold;
        emit LiquidationThresholdSet(synth, threshold);
    }

    function setLiquidationPenalty(address synth, uint256 penalty)
        external
        onlyOperator
        existingSynth(synth)
    {
        if (penalty > MAX_LIQUIDATION_PENALTY) revert LiquidationPenaltyTooHigh();
        synthConfigs[synth].liquidationPenalty = penalty;
        emit LiquidationPenaltySet(synth, penalty);
    }

    function setStabilityFeeRate(address synth, uint256 rate)
        external
        onlyOperator
        existingSynth(synth)
    {
        synthConfigs[synth].stabilityFeeRate = rate;
        emit StabilityFeeRateSet(synth, rate);
    }

    // ============ User Functions ============
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        userCollateral[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function mint(address synth, uint256 amount) external nonReentrant existingSynth(synth) {
        if (amount == 0) revert ZeroAmount();
        SynthConfig storage cfg = synthConfigs[synth];
        if (!cfg.active) revert SynthNotActive(synth);
        if (cfg.mintPaused) revert MintPaused(synth);

        _accrueAll(msg.sender);

        if (userDebt[msg.sender][synth] == 0) {
            userLastAccrual[msg.sender][synth] = block.timestamp;
        }
        userDebt[msg.sender][synth] += amount;
        cfg.totalDebt += amount;

        if (!_isCollateralized(msg.sender)) revert BelowCollateralizationRatio();

        ISyntheticToken(synth).mint(msg.sender, amount);
        emit SyntheticMinted(msg.sender, synth, amount);
    }

    function repay(address synth, uint256 amount) external nonReentrant existingSynth(synth) {
        if (amount == 0) revert ZeroAmount();
        SynthConfig storage cfg = synthConfigs[synth];
        if (cfg.redeemPaused) revert RedeemPaused(synth);

        _accrue(msg.sender, synth);

        uint256 debt = userDebt[msg.sender][synth];
        if (debt == 0) revert InsufficientDebt();
        uint256 repayAmount = amount > debt ? debt : amount;

        userDebt[msg.sender][synth] -= repayAmount;
        cfg.totalDebt -= repayAmount;

        ISyntheticToken(synth).burn(msg.sender, repayAmount);
        emit SyntheticRepaid(msg.sender, synth, repayAmount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userCollateral[msg.sender] < amount) revert InsufficientCollateral();

        _accrueAll(msg.sender);

        userCollateral[msg.sender] -= amount;

        if (!_isCollateralized(msg.sender)) {
            userCollateral[msg.sender] += amount;
            revert BelowCollateralizationRatio();
        }

        collateralToken.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function liquidate(address user, address synth, uint256 debtToCover)
        external
        nonReentrant
        existingSynth(synth)
    {
        if (debtToCover == 0) revert ZeroAmount();
        SynthConfig storage cfg = synthConfigs[synth];

        _accrueAll(user);

        uint256 debt = userDebt[user][synth];
        if (debt == 0) revert InsufficientDebt();
        if (debtToCover > debt) debtToCover = debt;

        if (!_isUndercollateralized(user, synth)) revert NotUndercollateralized();

        uint256 synthPrice = oracle.getPrice(synth);
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        if (synthPrice == 0 || collateralPrice == 0) revert InvalidPrice();

        // Perform all multiplications before any division to avoid divide-before-multiply
        // precision loss. The equivalent chained computation:
        //   debtValueUSD   = (debtToCover * synthPrice) / WAD
        //   seizeValueUSD  = (debtValueUSD * (WAD + liquidationPenalty)) / WAD
        //   collateralToSeize = (seizeValueUSD * WAD) / collateralPrice
        // simplifies (algebraically, with WAD cancelling) to the single expression below,
        // which keeps full precision by dividing only once.
        uint256 numerator = debtToCover * synthPrice * (WAD + cfg.liquidationPenalty);
        uint256 denominator = WAD * collateralPrice;
        uint256 collateralToSeize = numerator / denominator;

        if (collateralToSeize > userCollateral[user]) {
            collateralToSeize = userCollateral[user];
        }

        // Effects
        userDebt[user][synth] -= debtToCover;
        cfg.totalDebt -= debtToCover;
        userCollateral[user] -= collateralToSeize;

        // Interactions
        ISyntheticToken(synth).burn(msg.sender, debtToCover);
        collateralToken.safeTransfer(msg.sender, collateralToSeize);

        emit PositionLiquidated(msg.sender, user, synth, debtToCover, collateralToSeize);
    }

    // ============ View Functions ============
    function getSynthCount() external view returns (uint256) {
        return allSynths.length;
    }

    function getSynthAt(uint256 index) external view returns (address) {
        return allSynths[index];
    }

    function getUserDebt(address user, address synth) external view returns (uint256) {
        return userDebt[user][synth];
    }

    function getPendingFees(address user, address synth) external view returns (uint256) {
        uint256 debt = userDebt[user][synth];
        if (debt == 0) return 0;
        uint256 lastUpdate = userLastAccrual[user][synth];
        if (lastUpdate == 0 || block.timestamp <= lastUpdate) return 0;
        uint256 elapsed = block.timestamp - lastUpdate;
        uint256 rate = synthConfigs[synth].stabilityFeeRate;
        return (debt * rate * elapsed) / (WAD * SECONDS_PER_YEAR);
    }

    function getTotalDebtValue(address user) external view returns (uint256) {
        return _getTotalDebtValue(user);
    }

    function getCollateralizationRatio(address user) external view returns (uint256) {
        uint256 totalDebtValue = _getTotalDebtValue(user);
        if (totalDebtValue == 0) return type(uint256).max;
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        if (collateralPrice == 0) revert InvalidPrice();
        // Perform multiplication before division to avoid divide-before-multiply
        // precision loss. The previous chained form:
        //   collateralValue = (userCollateral[user] * collateralPrice) / WAD
        //   ratio           = (collateralValue * WAD) / totalDebtValue
        // simplifies (WAD cancels) to the single expression below.
        return (userCollateral[user] * collateralPrice) / totalDebtValue;
    }

    function isPositionSafe(address user) external view returns (bool) {
        return _isCollateralized(user);
    }

    function isPositionLiquidatable(address user, address synth) external view returns (bool) {
        if (!synthConfigs[synth].exists) return false;
        return _isUndercollateralized(user, synth);
    }

    // ============ Internal ============
    function _accrue(address user, address synth) internal {
        uint256 lastUpdate = userLastAccrual[user][synth];
        if (lastUpdate == 0) {
            userLastAccrual[user][synth] = block.timestamp;
            return;
        }
        if (block.timestamp <= lastUpdate) return;
        uint256 debt = userDebt[user][synth];
        if (debt == 0) return;
        uint256 elapsed = block.timestamp - lastUpdate;
        uint256 rate = synthConfigs[synth].stabilityFeeRate;
        uint256 fee = (debt * rate * elapsed) / (WAD * SECONDS_PER_YEAR);
        if (fee > 0) {
            userDebt[user][synth] += fee;
            synthConfigs[synth].totalDebt += fee;
            emit FeesAccrued(user, synth, fee);
        }
        userLastAccrual[user][synth] = block.timestamp;
    }

    function _accrueAll(address user) internal {
        for (uint256 i = 0; i < allSynths.length; i++) {
            address synth = allSynths[i];
            if (userDebt[user][synth] > 0) {
                _accrue(user, synth);
            }
        }
    }

    function _getTotalDebtValue(address user) internal view returns (uint256 total) {
        for (uint256 i = 0; i < allSynths.length; i++) {
            address synth = allSynths[i];
            uint256 debt = userDebt[user][synth];
            if (debt == 0) continue;
            uint256 synthPrice = oracle.getPrice(synth);
            if (synthPrice == 0) revert InvalidPrice();
            total += (debt * synthPrice) / WAD;
        }
    }

    function _isCollateralized(address user) internal view returns (bool) {
        uint256 collateral = userCollateral[user];
        uint256 totalDebtValue = _getTotalDebtValue(user);
        if (totalDebtValue == 0) return true;
        if (collateral == 0) return false;
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        if (collateralPrice == 0) revert InvalidPrice();
        uint256 collateralValue = (collateral * collateralPrice) / WAD;
        return collateralValue >= (totalDebtValue * MIN_COLLATERALIZATION_RATIO) / WAD;
    }

    function _isUndercollateralized(address user, address synth) internal view returns (bool) {
        uint256 collateral = userCollateral[user];
        uint256 totalDebtValue = _getTotalDebtValue(user);
        if (totalDebtValue == 0) return false;
        if (collateral == 0) return true;
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        if (collateralPrice == 0) revert InvalidPrice();
        uint256 collateralValue = (collateral * collateralPrice) / WAD;
        uint256 threshold = synthConfigs[synth].liquidationThreshold;
        return collateralValue < (totalDebtValue * threshold) / WAD;
    }
}
