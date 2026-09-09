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
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!token.transfer(to, value)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        if (!token.approve(spender, newAllowance)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < requestedDecrease) {
            revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        uint256 newAllowance = currentAllowance - requestedDecrease;
        if (!token.approve(spender, newAllowance)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title StructuredOptionsVault
 * @notice A collateral vault for structured option products. Users deposit a single
 *         base collateral token, open option positions by paying a premium from their
 *         deposited balance, and may exercise in-the-money positions after settlement.
 *         Withdrawals are charged a 0.1% fee sent to the fee recipient.
 */
contract StructuredOptionsVault is Ownable {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ErrZeroAddress();
    error ErrInvalidAmount();
    error ErrInvalidParameter();
    error ErrNotOperator();
    error ErrSeriesNotFound();
    error ErrSeriesNotActive();
    error ErrSeriesExpired();
    error ErrSeriesNotExpired();
    error ErrSeriesAlreadySettled();
    error ErrSettlementNotSet();
    error ErrMaxOpenInterestExceeded();
    error ErrInsufficientBalance();
    error ErrInsufficientPosition();
    error ErrTotalCollateralTooLow();
    error ErrTransferFromFailed();

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    enum OptionType {
        Call,
        Put
    }

    struct OptionSeries {
        bool active;
        bool settled;
        OptionType optionType;
        uint256 expiration;
        uint256 strikePrice;
        uint256 settlementPrice;
        uint256 premiumPerUnit;
        uint256 maxOpenInterest;
        uint256 openInterest;
    }

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant WITHDRAWAL_FEE_BPS = 10; // 0.1%
    uint256 public constant FEE_PRECISION = 10_000;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    IERC20 public immutable collateral;
    uint256 public immutable baseUnit;

    address public operator;
    address public feeRecipient;

    uint256 public minTotalCollateral;
    uint256 public totalUserBalances;
    uint256 public totalFeesCollected;

    uint256 public nextSeriesId;

    mapping(uint256 => OptionSeries) public optionSeries;
    mapping(address => uint256) public userBalances;
    mapping(address => mapping(uint256 => uint256)) public positions;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(
        address indexed user,
        uint256 grossAmount,
        uint256 fee,
        uint256 netAmount,
        uint256 newBalance
    );
    event PositionOpened(
        address indexed user,
        uint256 indexed seriesId,
        uint256 amount,
        uint256 premiumPaid
    );
    event PositionExercised(
        address indexed user,
        uint256 indexed seriesId,
        uint256 amount,
        uint256 payout
    );
    event SeriesCreated(
        uint256 indexed seriesId,
        OptionType optionType,
        uint256 expiration,
        uint256 strikePrice,
        uint256 premiumPerUnit,
        uint256 maxOpenInterest
    );
    event SeriesUpdated(
        uint256 indexed seriesId,
        uint256 premiumPerUnit,
        uint256 maxOpenInterest,
        bool active
    );
    event SeriesSettled(uint256 indexed seriesId, uint256 settlementPrice);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    event MinTotalCollateralChanged(uint256 newMinTotalCollateral);
    event FeesSwept(address indexed to, uint256 amount);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator && msg.sender != owner()) revert ErrNotOperator();
        _;
    }

    modifier seriesExists(uint256 seriesId) {
        if (optionSeries[seriesId].expiration == 0) revert ErrSeriesNotFound();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        IERC20 collateral_,
        address operator_,
        address feeRecipient_
    ) Ownable(msg.sender) {
        if (address(collateral_) == address(0)) revert ErrZeroAddress();
        if (operator_ == address(0)) revert ErrZeroAddress();
        if (feeRecipient_ == address(0)) revert ErrZeroAddress();

        collateral = collateral_;
        operator = operator_;
        feeRecipient = feeRecipient_;

        uint8 decimals = IERC20Metadata(address(collateral_)).decimals();
        baseUnit = 10 ** decimals;
        minTotalCollateral = 100_000 * baseUnit;
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /// @notice Transfers collateral from the caller (msg.sender) into the vault.
    /// @dev The `from` is hardcoded to msg.sender to prevent arbitrary pulls.
    function _pullFromCaller(uint256 amount) internal {
        if (!collateral.transferFrom(msg.sender, address(this), amount)) {
            revert ErrTransferFromFailed();
        }
    }

    // -------------------------------------------------------------------------
    // View helpers
    // -------------------------------------------------------------------------

    /// @notice Returns the actual collateral balance held by the vault.
    function totalCollateralInVault() public view returns (uint256) {
        return collateral.balanceOf(address(this));
    }

    /// @notice Returns the details of an option series.
    function getSeries(uint256 seriesId) external view seriesExists(seriesId) returns (OptionSeries memory) {
        return optionSeries[seriesId];
    }

    /// @notice Returns the open position size of a user for a given series.
    function getPosition(address user, uint256 seriesId) external view returns (uint256) {
        return positions[user][seriesId];
    }

    // -------------------------------------------------------------------------
    // User actions
    // -------------------------------------------------------------------------

    /// @notice Deposits base collateral into the vault.
    /// @param amount The amount of collateral to deposit.
    function deposit(uint256 amount) external {
        if (amount == 0) revert ErrInvalidAmount();

        _pullFromCaller(amount);

        userBalances[msg.sender] += amount;
        totalUserBalances += amount;

        emit Deposited(msg.sender, amount, userBalances[msg.sender]);
    }

    /// @notice Withdraws available collateral, charging a 0.1% fee on the gross amount.
    /// @param amount The gross amount of collateral to withdraw.
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ErrInvalidAmount();

        uint256 balance = userBalances[msg.sender];
        if (amount > balance) revert ErrInsufficientBalance();

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / FEE_PRECISION;
        uint256 netAmount = amount - fee;

        userBalances[msg.sender] = balance - amount;
        totalUserBalances -= amount;
        totalFeesCollected += fee;

        if (netAmount > 0) {
            collateral.safeTransfer(msg.sender, netAmount);
        }
        if (fee > 0) {
            collateral.safeTransfer(feeRecipient, fee);
        }

        emit Withdrawn(msg.sender, amount, fee, netAmount, userBalances[msg.sender]);
    }

    /// @notice Opens a new option position by paying the required premium from available balance.
    /// @param seriesId The id of the option series to open a position in.
    /// @param amount The number of option units to open.
    function openPosition(uint256 seriesId, uint256 amount) external seriesExists(seriesId) {
        if (amount == 0) revert ErrInvalidAmount();

        OptionSeries storage series = optionSeries[seriesId];
        if (!series.active) revert ErrSeriesNotActive();
        if (series.settled) revert ErrSeriesAlreadySettled();
        if (block.timestamp >= series.expiration) revert ErrSeriesExpired();
        if (series.openInterest + amount > series.maxOpenInterest) revert ErrMaxOpenInterestExceeded();
        if (totalCollateralInVault() <= minTotalCollateral) revert ErrTotalCollateralTooLow();

        uint256 premiumPaid = amount * series.premiumPerUnit;
        uint256 balance = userBalances[msg.sender];
        if (premiumPaid > balance) revert ErrInsufficientBalance();

        // Effects
        userBalances[msg.sender] = balance - premiumPaid;
        totalUserBalances -= premiumPaid;

        positions[msg.sender][seriesId] += amount;
        series.openInterest += amount;

        emit PositionOpened(msg.sender, seriesId, amount, premiumPaid);
    }

    /// @notice Exercises an expiring option position after the series has been settled.
    /// @param seriesId The id of the option series to exercise.
    /// @param amount The number of option units to exercise.
    function exercise(uint256 seriesId, uint256 amount) external seriesExists(seriesId) {
        if (amount == 0) revert ErrInvalidAmount();

        OptionSeries storage series = optionSeries[seriesId];
        if (!series.settled) revert ErrSettlementNotSet();
        if (block.timestamp < series.expiration) revert ErrSeriesNotExpired();

        uint256 positionAmount = positions[msg.sender][seriesId];
        if (amount > positionAmount) revert ErrInsufficientPosition();

        // Compute payout based on option type and settlement vs strike.
        uint256 payout = 0;
        if (series.optionType == OptionType.Call) {
            if (series.settlementPrice > series.strikePrice) {
                payout = amount * (series.settlementPrice - series.strikePrice);
            }
        } else {
            if (series.strikePrice > series.settlementPrice) {
                payout = amount * (series.strikePrice - series.settlementPrice);
            }
        }

        // Effects
        positions[msg.sender][seriesId] = positionAmount - amount;
        series.openInterest -= amount;

        if (payout > 0) {
            userBalances[msg.sender] += payout;
            totalUserBalances += payout;
        }

        emit PositionExercised(msg.sender, seriesId, amount, payout);
    }

    // -------------------------------------------------------------------------
    // Operator actions
    // -------------------------------------------------------------------------

    /// @notice Creates a new option series.
    function createOptionSeries(
        OptionType optionType,
        uint256 expiration,
        uint256 strikePrice,
        uint256 premiumPerUnit,
        uint256 maxOpenInterest
    ) external onlyOperator returns (uint256 seriesId) {
        if (expiration <= block.timestamp) revert ErrInvalidParameter();
        if (strikePrice == 0) revert ErrInvalidParameter();
        if (premiumPerUnit == 0) revert ErrInvalidParameter();
        if (maxOpenInterest == 0) revert ErrInvalidParameter();

        seriesId = nextSeriesId++;
        OptionSeries storage series = optionSeries[seriesId];
        series.active = true;
        series.optionType = optionType;
        series.expiration = expiration;
        series.strikePrice = strikePrice;
        series.premiumPerUnit = premiumPerUnit;
        series.maxOpenInterest = maxOpenInterest;

        emit SeriesCreated(
            seriesId,
            optionType,
            expiration,
            strikePrice,
            premiumPerUnit,
            maxOpenInterest
        );
    }

    /// @notice Adjusts risk parameters for an existing series.
    function updateSeries(
        uint256 seriesId,
        uint256 premiumPerUnit,
        uint256 maxOpenInterest,
        bool active
    ) external onlyOperator seriesExists(seriesId) {
        if (premiumPerUnit == 0) revert ErrInvalidParameter();
        if (maxOpenInterest == 0) revert ErrInvalidParameter();

        OptionSeries storage series = optionSeries[seriesId];
        if (maxOpenInterest < series.openInterest) revert ErrInvalidParameter();

        series.premiumPerUnit = premiumPerUnit;
        series.maxOpenInterest = maxOpenInterest;
        series.active = active;

        emit SeriesUpdated(seriesId, premiumPerUnit, maxOpenInterest, active);
    }

    /// @notice Settles an expiring series by setting its final settlement price.
    function settleSeries(uint256 seriesId, uint256 settlementPrice) external onlyOperator seriesExists(seriesId) {
        OptionSeries storage series = optionSeries[seriesId];
        if (block.timestamp < series.expiration) revert ErrSeriesNotExpired();
        if (series.settled) revert ErrSeriesAlreadySettled();

        series.settlementPrice = settlementPrice;
        series.settled = true;

        emit SeriesSettled(seriesId, settlementPrice);
    }

    // -------------------------------------------------------------------------
    // Admin actions
    // -------------------------------------------------------------------------

    /// @notice Updates the designated operator address.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Updates the fee recipient for withdrawal fees.
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ErrZeroAddress();
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /// @notice Updates the minimum total collateral required to open positions.
    function setMinTotalCollateral(uint256 newMinTotalCollateral) external onlyOwner {
        if (newMinTotalCollateral == 0) revert ErrInvalidParameter();
        minTotalCollateral = newMinTotalCollateral;
        emit MinTotalCollateralChanged(newMinTotalCollateral);
    }

    /// @notice Sweeps accumulated withdrawal fees to a recipient.
    function sweepFees(address to) external onlyOwner {
        if (to == address(0)) revert ErrZeroAddress();
        uint256 amount = totalFeesCollected;
        if (amount == 0) revert ErrInvalidAmount();

        totalFeesCollected = 0;
        collateral.safeTransfer(to, amount);

        emit FeesSwept(to, amount);
    }
}
