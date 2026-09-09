// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IOptionToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

contract OptionsMarket {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error SeriesNotFound();
    error SeriesNotActive();
    error SeriesExpired();
    error SeriesNotExpired();
    error SeriesAlreadySettled();
    error SeriesNotSettled();
    error SeriesAlreadyExists();
    error LeverageTooHigh();
    error InsufficientCollateral();
    error InsufficientShares();
    error InsufficientOptionBalance();
    error NotSolvent();
    error InvalidExpiry();
    error InvalidStrike();
    error InvalidLeverage();
    error FeeTooHigh();
    error AlreadyInitialized();
    error InvalidOptionToken();
    error TransferFailed();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event Deposit(address indexed user, bytes32 indexed seriesId, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, bytes32 indexed seriesId, uint256 amount, uint256 shares);
    event OptionMint(
        address indexed user,
        bytes32 indexed seriesId,
        uint256 amount,
        uint256 premium,
        uint256 fee
    );
    event OptionExercise(address indexed user, bytes32 indexed seriesId, uint256 amount, uint256 payout);
    event OptionRedeem(address indexed user, bytes32 indexed seriesId, uint256 amount, uint256 payout);
    event SeriesAdded(
        bytes32 indexed seriesId,
        address indexed optionToken,
        address indexed underlying,
        uint256 strike,
        uint256 expiry,
        uint8 optionType,
        uint256 premiumRate,
        uint256 maxLeverage
    );
    event SeriesDeactivated(bytes32 indexed seriesId);
    event SeriesSettled(bytes32 indexed seriesId, uint256 settlementPrice);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    event Upgraded(address indexed oldImplementation, address indexed newImplementation);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant MAX_LEVERAGE = 10e18; // 10x cap (1e18 precision)
    uint256 public constant BPS = 1e4;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MAX_PROTOCOL_FEE = 500; // 5% cap in bps
    uint256 public constant DEFAULT_PROTOCOL_FEE = 10; // 0.1% in bps

    enum OptionType {
        Call,
        Put
    }

    struct OptionSeries {
        address optionToken;
        address underlying;
        uint256 strike; // strike price with PRICE_PRECISION
        uint256 expiry; // timestamp after which options may be settled
        OptionType optionType;
        uint256 premiumRate; // fraction of notional charged as premium (1e18)
        uint256 maxLeverage; // 1e18, capped at MAX_LEVERAGE
        bool active;
        bool settled;
        uint256 settlementPrice;
    }

    struct Pool {
        uint256 totalCollateral; // collateral held for this series
        uint256 totalShares; // LP shares outstanding
        uint256 totalMinted; // option tokens minted and not yet burned
    }

    struct Position {
        uint256 shares; // LP shares owned by the user for this series
    }

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------
    address public owner;
    address public operator;
    address public collateralToken;
    address public feeRecipient;
    IPriceOracle public oracle;

    uint256 public protocolFee; // in bps

    mapping(bytes32 => OptionSeries) public series;
    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => Position)) public positions;
    bytes32[] public seriesIds;

    // EIP-1967 implementation slot for upgradeability
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    uint256 private _locked = 1;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Unauthorized();
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier activeSeries(bytes32 seriesId) {
        OptionSeries storage s = series[seriesId];
        if (s.optionToken == address(0)) revert SeriesNotFound();
        if (!s.active) revert SeriesNotActive();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor() {
        _setImplementation(address(this));
    }

    function initialize(
        address owner_,
        address operator_,
        address collateralToken_,
        address feeRecipient_,
        address oracle_,
        uint256 protocolFee_
    ) external {
        if (owner != address(0)) revert AlreadyInitialized();
        if (
            owner_ == address(0) || operator_ == address(0) || collateralToken_ == address(0)
                || feeRecipient_ == address(0) || oracle_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (protocolFee_ > MAX_PROTOCOL_FEE) revert FeeTooHigh();
        owner = owner_;
        operator = operator_;
        collateralToken = collateralToken_;
        feeRecipient = feeRecipient_;
        oracle = IPriceOracle(oracle_);
        protocolFee = protocolFee_ == 0 ? DEFAULT_PROTOCOL_FEE : protocolFee_;
        emit ProtocolFeeUpdated(0, protocolFee);
        emit OperatorUpdated(address(0), operator);
        emit FeeRecipientUpdated(address(0), feeRecipient);
        emit OwnerUpdated(address(0), owner);
    }

    // -------------------------------------------------------------------------
    // Upgrade logic (UUPS-style)
    // -------------------------------------------------------------------------
    function _getImplementation() internal view returns (address impl) {
        assembly {
            impl := sload(_IMPLEMENTATION_SLOT)
        }
    }

    function _setImplementation(address newImplementation) internal {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        address old = _getImplementation();
        _setImplementation(newImplementation);
        emit Upgraded(old, newImplementation);
    }

    // -------------------------------------------------------------------------
    // Admin (operator / owner)
    // -------------------------------------------------------------------------
    function setProtocolFee(uint256 newFee) external onlyOperator {
        if (newFee > MAX_PROTOCOL_FEE) revert FeeTooHigh();
        emit ProtocolFeeUpdated(protocolFee, newFee);
        protocolFee = newFee;
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }

    function addSeries(
        bytes32 seriesId,
        address optionToken,
        address underlying,
        uint256 strike,
        uint256 expiry,
        OptionType optionType,
        uint256 premiumRate,
        uint256 maxLeverage
    ) external onlyOperator {
        if (series[seriesId].optionToken != address(0)) revert SeriesAlreadyExists();
        if (optionToken == address(0) || underlying == address(0)) revert ZeroAddress();
        if (strike == 0) revert InvalidStrike();
        if (expiry <= block.timestamp) revert InvalidExpiry();
        if (maxLeverage == 0 || maxLeverage > MAX_LEVERAGE) revert InvalidLeverage();
        if (premiumRate == 0) revert ZeroAmount();

        series[seriesId] = OptionSeries({
            optionToken: optionToken,
            underlying: underlying,
            strike: strike,
            expiry: expiry,
            optionType: optionType,
            premiumRate: premiumRate,
            maxLeverage: maxLeverage,
            active: true,
            settled: false,
            settlementPrice: 0
        });

        seriesIds.push(seriesId);

        emit SeriesAdded(
            seriesId,
            optionToken,
            underlying,
            strike,
            expiry,
            uint8(optionType),
            premiumRate,
            maxLeverage
        );
    }

    function deactivateSeries(bytes32 seriesId) external onlyOperator activeSeries(seriesId) {
        series[seriesId].active = false;
        emit SeriesDeactivated(seriesId);
    }

    function settleSeries(bytes32 seriesId) external onlyOperator activeSeries(seriesId) {
        OptionSeries storage s = series[seriesId];
        if (block.timestamp <= s.expiry) revert SeriesNotExpired();
        if (s.settled) revert SeriesAlreadySettled();
        uint256 price = oracle.getPrice(s.underlying);
        s.settled = true;
        s.settlementPrice = price;
        emit SeriesSettled(seriesId, price);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------
    function seriesCount() external view returns (uint256) {
        return seriesIds.length;
    }

    function getPosition(bytes32 seriesId, address user) external view returns (uint256 shares) {
        return positions[seriesId][user].shares;
    }

    function getPool(bytes32 seriesId)
        external
        view
        returns (uint256 totalCollateral, uint256 totalShares, uint256 totalMinted)
    {
        Pool storage p = pools[seriesId];
        return (p.totalCollateral, p.totalShares, p.totalMinted);
    }

    function isSolvent(bytes32 seriesId) public view returns (bool) {
        OptionSeries storage s = series[seriesId];
        Pool storage p = pools[seriesId];
        if (s.optionToken == address(0)) revert SeriesNotFound();
        // required = (totalMinted * strike) / maxLeverage
        // (PRICE_PRECISION cancels: obligation = totalMinted*strike/PRICE_PRECISION,
        //  required = obligation * PRICE_PRECISION / maxLeverage)
        uint256 required = (p.totalMinted * s.strike) / s.maxLeverage;
        return p.totalCollateral >= required;
    }

    function pendingPayout(bytes32 seriesId, uint256 amount) public view returns (uint256) {
        OptionSeries storage s = series[seriesId];
        if (s.optionToken == address(0)) revert SeriesNotFound();
        uint256 price = s.settled ? s.settlementPrice : oracle.getPrice(s.underlying);
        return _computePayout(s, price, amount);
    }

    function _computePayout(OptionSeries storage s, uint256 price, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (s.optionType == OptionType.Call) {
            if (price <= s.strike) return 0;
            return (amount * (price - s.strike)) / PRICE_PRECISION;
        } else {
            if (price >= s.strike) return 0;
            return (amount * (s.strike - price)) / PRICE_PRECISION;
        }
    }

    // -------------------------------------------------------------------------
    // LP: deposit / withdraw
    // -------------------------------------------------------------------------
    function depositCollateral(bytes32 seriesId, uint256 amount)
        external
        nonReentrant
        activeSeries(seriesId)
    {
        if (amount == 0) revert ZeroAmount();
        Pool storage p = pools[seriesId];

        uint256 shares;
        if (p.totalShares == 0 || p.totalCollateral == 0) {
            shares = amount;
        } else {
            shares = (amount * p.totalShares) / p.totalCollateral;
        }
        if (shares == 0) revert InsufficientShares();

        // effects before interactions
        p.totalCollateral += amount;
        p.totalShares += shares;
        positions[seriesId][msg.sender].shares += shares;

        _safeTransferFrom(collateralToken, msg.sender, address(this), amount);

        emit Deposit(msg.sender, seriesId, amount, shares);
    }

    function withdrawCollateral(bytes32 seriesId, uint256 shares)
        external
        nonReentrant
        activeSeries(seriesId)
    {
        if (shares == 0) revert ZeroAmount();
        Pool storage p = pools[seriesId];
        Position storage pos = positions[seriesId][msg.sender];
        if (pos.shares < shares) revert InsufficientShares();

        uint256 amount = (shares * p.totalCollateral) / p.totalShares;
        if (amount == 0) revert InsufficientCollateral();

        // effects before interactions
        pos.shares -= shares;
        p.totalShares -= shares;
        p.totalCollateral -= amount;

        // solvency check after withdrawal
        if (!isSolvent(seriesId)) revert NotSolvent();

        _safeTransfer(collateralToken, msg.sender, amount);

        emit Withdraw(msg.sender, seriesId, amount, shares);
    }

    // -------------------------------------------------------------------------
    // Options: mint / exercise / redeem
    // -------------------------------------------------------------------------
    function mintOption(bytes32 seriesId, uint256 amount)
        external
        nonReentrant
        activeSeries(seriesId)
    {
        if (amount == 0) revert ZeroAmount();
        OptionSeries storage s = series[seriesId];
        Pool storage p = pools[seriesId];

        if (block.timestamp > s.expiry) revert SeriesExpired();

        // Compute premium and fee without divide-before-multiply loss:
        // premium = amount * strike * premiumRate / (PRICE_PRECISION^2)
        // fee     = amount * strike * premiumRate * protocolFee / (PRICE_PRECISION^2 * BPS)
        uint256 premium = (amount * s.strike * s.premiumRate) / (PRICE_PRECISION * PRICE_PRECISION);
        uint256 fee = (amount * s.strike * s.premiumRate * protocolFee) / (PRICE_PRECISION * PRICE_PRECISION * BPS);
        uint256 netPremium = premium - fee;

        // solvency after mint: (totalCollateral + netPremium) * maxLeverage >= (totalMinted + amount) * strike
        uint256 newObligation = ((p.totalMinted + amount) * s.strike) / PRICE_PRECISION;
        uint256 newCollateral = p.totalCollateral + netPremium;
        uint256 maxSupported = (newCollateral * s.maxLeverage) / PRICE_PRECISION;
        if (maxSupported < newObligation) revert LeverageTooHigh();

        // effects before interactions
        p.totalCollateral = newCollateral;
        p.totalMinted += amount;

        // collect premium from minter
        _safeTransferFrom(collateralToken, msg.sender, address(this), premium);
        if (fee > 0) {
            _safeTransfer(collateralToken, feeRecipient, fee);
        }

        // mint option tokens to minter
        IOptionToken(s.optionToken).mint(msg.sender, amount);

        emit OptionMint(msg.sender, seriesId, amount, premium, fee);
    }

    function exerciseOption(bytes32 seriesId, uint256 amount)
        external
        nonReentrant
        activeSeries(seriesId)
    {
        if (amount == 0) revert ZeroAmount();
        OptionSeries storage s = series[seriesId];
        Pool storage p = pools[seriesId];

        if (block.timestamp > s.expiry) revert SeriesExpired();
        if (s.settled) revert SeriesAlreadySettled();

        uint256 price = oracle.getPrice(s.underlying);
        uint256 payout = _computePayout(s, price, amount);
        if (payout == 0) revert InsufficientCollateral();
        if (p.totalCollateral < payout) revert InsufficientCollateral();

        // effects before interactions
        p.totalMinted -= amount;
        p.totalCollateral -= payout;

        // burn option tokens from exerciser
        IOptionToken(s.optionToken).burn(msg.sender, amount);

        _safeTransfer(collateralToken, msg.sender, payout);

        emit OptionExercise(msg.sender, seriesId, amount, payout);
    }

    function redeemExpired(bytes32 seriesId, uint256 amount)
        external
        nonReentrant
        activeSeries(seriesId)
    {
        if (amount == 0) revert ZeroAmount();
        OptionSeries storage s = series[seriesId];
        Pool storage p = pools[seriesId];

        if (block.timestamp <= s.expiry) revert SeriesNotExpired();
        if (!s.settled) revert SeriesNotSettled();

        uint256 payout = _computePayout(s, s.settlementPrice, amount);
        if (payout > p.totalCollateral) payout = p.totalCollateral;

        // effects before interactions
        p.totalMinted -= amount;
        if (payout > 0) {
            p.totalCollateral -= payout;
        }

        // burn option tokens from redeemer
        IOptionToken(s.optionToken).burn(msg.sender, amount);

        if (payout > 0) {
            _safeTransfer(collateralToken, msg.sender, payout);
        }

        emit OptionRedeem(msg.sender, seriesId, amount, payout);
    }

    // -------------------------------------------------------------------------
    // Safe ERC20 helpers
    // -------------------------------------------------------------------------
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
