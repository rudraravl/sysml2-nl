// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IOptionToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract OptionsTradingPlatform {
    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------

    error ZeroAddress();
    error Unauthorized();
    error ReentrantCall();
    error OptionTypeNotFound();
    error OptionTypeIsPaused();
    error InvalidAmount();
    error InvalidStrikePrice();
    error MarginRatioTooHigh();
    error MarginRatioTooLow();
    error InsufficientAvailableCollateral();
    error InsufficientLockedCollateral();
    error InsufficientOptionBalance();
    error InsufficientEthBalance();
    error TransferFailed();
    error NativeTokenNotAccepted();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant MAX_MARGIN_RATIO_BPS = 15000;
    uint256 public constant MIN_MARGIN_RATIO_BPS = 10000;
    uint256 public constant EXERCISE_FEE_BPS = 10;
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------------

    IERC20 public immutable collateralToken;
    IOptionToken public immutable optionToken;

    address public owner;
    address public operator;
    address public feeRecipient;

    uint256 public totalCollateral;
    uint256 public totalLockedCollateral;
    uint256 public nextOptionTypeId;

    struct OptionType {
        uint256 strikePrice;
        uint256 marginRatioBps;
        bool paused;
        bool exists;
    }

    mapping(uint256 => OptionType) public optionTypes;
    mapping(uint256 => uint256) public lockedCollateralByType;
    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userLockedCollateral;
    mapping(address => mapping(uint256 => uint256)) public userLockedCollateralByType;

    uint256 private _reentrancyStatus = 1;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier nonReentrant() {
        if (_reentrancyStatus != 1) revert ReentrantCall();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier onlyExistingOptionType(uint256 optionTypeId) {
        if (!optionTypes[optionTypeId].exists) revert OptionTypeNotFound();
        _;
    }

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event OptionsMinted(
        address indexed user,
        uint256 indexed optionType,
        uint256 optionAmount,
        uint256 collateralLocked
    );
    event OptionsExercised(
        address indexed user,
        uint256 indexed optionType,
        uint256 optionAmount,
        uint256 payout,
        uint256 fee
    );
    event OptionsBurned(
        address indexed user,
        uint256 indexed optionType,
        uint256 optionAmount,
        uint256 collateralReleased
    );
    event OptionTypeCreated(uint256 indexed optionType, uint256 strikePrice, uint256 marginRatioBps);
    event MarginRatioUpdated(uint256 indexed optionType, uint256 marginRatioBps);
    event OptionTypePaused(uint256 indexed optionType, bool paused);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EthWithdrawn(address indexed to, uint256 amount);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(
        address _collateralToken,
        address _optionToken,
        address _operator,
        address _feeRecipient
    ) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_optionToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        collateralToken = IERC20(_collateralToken);
        optionToken = IOptionToken(_optionToken);
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    // -----------------------------------------------------------------------
    // Receive
    // -----------------------------------------------------------------------

    receive() external payable {
        revert NativeTokenNotAccepted();
    }

    // -----------------------------------------------------------------------
    // User Functions
    // -----------------------------------------------------------------------

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        userCollateral[msg.sender] += amount;
        totalCollateral += amount;

        bool success = collateralToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        uint256 locked = userLockedCollateral[msg.sender];
        uint256 collateral = userCollateral[msg.sender];
        uint256 available = locked > collateral ? 0 : collateral - locked;
        if (available < amount) revert InsufficientAvailableCollateral();

        userCollateral[msg.sender] = collateral - amount;
        totalCollateral -= amount;

        bool success = collateralToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function mint(uint256 optionTypeId, uint256 optionAmount)
        external
        nonReentrant
        onlyExistingOptionType(optionTypeId)
    {
        OptionType storage opt = optionTypes[optionTypeId];
        if (opt.paused) revert OptionTypeIsPaused();
        if (optionAmount == 0) revert InvalidAmount();

        uint256 requiredCollateral =
            (optionAmount * opt.strikePrice * opt.marginRatioBps) / (BPS_DENOM * PRECISION);

        uint256 locked = userLockedCollateral[msg.sender];
        uint256 collateral = userCollateral[msg.sender];
        uint256 available = locked > collateral ? 0 : collateral - locked;
        if (available < requiredCollateral) revert InsufficientAvailableCollateral();

        userLockedCollateral[msg.sender] = locked + requiredCollateral;
        userLockedCollateralByType[msg.sender][optionTypeId] += requiredCollateral;
        lockedCollateralByType[optionTypeId] += requiredCollateral;
        totalLockedCollateral += requiredCollateral;

        optionToken.mint(msg.sender, optionAmount);

        emit OptionsMinted(msg.sender, optionTypeId, optionAmount, requiredCollateral);
    }

    function exercise(uint256 optionTypeId, uint256 optionAmount)
        external
        nonReentrant
        onlyExistingOptionType(optionTypeId)
    {
        if (optionAmount == 0) revert InvalidAmount();

        OptionType storage opt = optionTypes[optionTypeId];

        // Compute fee directly from the unscaled product to avoid divide-before-multiply.
        uint256 grossScaled = optionAmount * opt.strikePrice;
        uint256 fee = (grossScaled * EXERCISE_FEE_BPS) / (PRECISION * BPS_DENOM);
        uint256 payout = grossScaled / PRECISION;
        uint256 netPayout = payout - fee;

        uint256 lockedForOptions =
            (optionAmount * opt.strikePrice * opt.marginRatioBps) / (BPS_DENOM * PRECISION);

        if (optionToken.balanceOf(msg.sender) < optionAmount) revert InsufficientOptionBalance();
        if (userLockedCollateralByType[msg.sender][optionTypeId] < lockedForOptions)
            revert InsufficientLockedCollateral();
        if (lockedCollateralByType[optionTypeId] < lockedForOptions)
            revert InsufficientLockedCollateral();
        if (userCollateral[msg.sender] < payout) revert InsufficientAvailableCollateral();

        // Effects
        userLockedCollateral[msg.sender] -= lockedForOptions;
        userLockedCollateralByType[msg.sender][optionTypeId] -= lockedForOptions;
        lockedCollateralByType[optionTypeId] -= lockedForOptions;
        totalLockedCollateral -= lockedForOptions;

        userCollateral[msg.sender] -= payout;
        totalCollateral -= payout;

        // Interactions
        optionToken.burn(msg.sender, optionAmount);

        if (netPayout > 0) {
            bool success = collateralToken.transfer(msg.sender, netPayout);
            if (!success) revert TransferFailed();
        }
        if (fee > 0) {
            bool success = collateralToken.transfer(feeRecipient, fee);
            if (!success) revert TransferFailed();
        }

        emit OptionsExercised(msg.sender, optionTypeId, optionAmount, netPayout, fee);
    }

    function burnAndRelease(uint256 optionTypeId, uint256 optionAmount)
        external
        nonReentrant
        onlyExistingOptionType(optionTypeId)
    {
        if (optionAmount == 0) revert InvalidAmount();

        OptionType storage opt = optionTypes[optionTypeId];
        uint256 collateralToRelease =
            (optionAmount * opt.strikePrice * opt.marginRatioBps) / (BPS_DENOM * PRECISION);

        if (userLockedCollateralByType[msg.sender][optionTypeId] < collateralToRelease)
            revert InsufficientLockedCollateral();
        if (optionToken.balanceOf(msg.sender) < optionAmount) revert InsufficientOptionBalance();

        userLockedCollateral[msg.sender] -= collateralToRelease;
        userLockedCollateralByType[msg.sender][optionTypeId] -= collateralToRelease;
        lockedCollateralByType[optionTypeId] -= collateralToRelease;
        totalLockedCollateral -= collateralToRelease;

        optionToken.burn(msg.sender, optionAmount);

        emit OptionsBurned(msg.sender, optionTypeId, optionAmount, collateralToRelease);
    }

    // -----------------------------------------------------------------------
    // Operator Functions
    // -----------------------------------------------------------------------

    function createOptionType(uint256 strikePrice, uint256 marginRatioBps)
        external
        onlyOperator
        returns (uint256 optionTypeId)
    {
        if (strikePrice == 0) revert InvalidStrikePrice();
        if (marginRatioBps < MIN_MARGIN_RATIO_BPS) revert MarginRatioTooLow();
        if (marginRatioBps > MAX_MARGIN_RATIO_BPS) revert MarginRatioTooHigh();

        optionTypeId = nextOptionTypeId++;
        optionTypes[optionTypeId] = OptionType({
            strikePrice: strikePrice,
            marginRatioBps: marginRatioBps,
            paused: false,
            exists: true
        });

        emit OptionTypeCreated(optionTypeId, strikePrice, marginRatioBps);
    }

    function updateMarginRequirement(uint256 optionTypeId, uint256 marginRatioBps)
        external
        onlyOperator
        onlyExistingOptionType(optionTypeId)
    {
        if (marginRatioBps < MIN_MARGIN_RATIO_BPS) revert MarginRatioTooLow();
        if (marginRatioBps > MAX_MARGIN_RATIO_BPS) revert MarginRatioTooHigh();

        optionTypes[optionTypeId].marginRatioBps = marginRatioBps;

        emit MarginRatioUpdated(optionTypeId, marginRatioBps);
    }

    function setOptionTypePaused(uint256 optionTypeId, bool paused)
        external
        onlyOperator
        onlyExistingOptionType(optionTypeId)
    {
        optionTypes[optionTypeId].paused = paused;
        emit OptionTypePaused(optionTypeId, paused);
    }

    // -----------------------------------------------------------------------
    // Owner Functions
    // -----------------------------------------------------------------------

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdrawETH(address payable to, uint256 amount) external nonReentrant onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (address(this).balance < amount) revert InsufficientEthBalance();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit EthWithdrawn(to, amount);
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------

    function getAvailableCollateral(address user) external view returns (uint256) {
        uint256 locked = userLockedCollateral[user];
        uint256 collateral = userCollateral[user];
        return locked > collateral ? 0 : collateral - locked;
    }

    function getAvailableCollateralPool() external view returns (uint256) {
        return totalLockedCollateral > totalCollateral ? 0 : totalCollateral - totalLockedCollateral;
    }

    function getOptionType(uint256 optionTypeId) external view returns (OptionType memory) {
        return optionTypes[optionTypeId];
    }

    function getRequiredCollateral(uint256 optionTypeId, uint256 optionAmount)
        external
        view
        onlyExistingOptionType(optionTypeId)
        returns (uint256)
    {
        OptionType storage opt = optionTypes[optionTypeId];
        return (optionAmount * opt.strikePrice * opt.marginRatioBps) / (BPS_DENOM * PRECISION);
    }

    function getExerciseQuote(uint256 optionTypeId, uint256 optionAmount)
        external
        view
        onlyExistingOptionType(optionTypeId)
        returns (uint256 payout, uint256 fee, uint256 netPayout)
    {
        OptionType storage opt = optionTypes[optionTypeId];
        uint256 grossScaled = optionAmount * opt.strikePrice;
        fee = (grossScaled * EXERCISE_FEE_BPS) / (PRECISION * BPS_DENOM);
        payout = grossScaled / PRECISION;
        netPayout = payout - fee;
    }
}
