// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    /// @notice Returns the price of the base asset in USD with 18 decimals
    function getPrice() external view returns (uint256);
}

contract SquaredPerpetual {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized();
    error InsufficientCollateral();
    error Undercollateralized();
    error PositionNotFound();
    error InvalidOracle();
    error NothingToClaim();
    error TransferFailed();
    error Reentrancy();

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 15000; // 150% in bps
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant WITHDRAWAL_FEE_BPS = 10; // 0.1%
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant FUNDING_PRECISION = 1e18;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    address public immutable baseAsset;
    address public collateralToken;
    IPriceOracle public oracle;
    address public operator;
    address public feeRecipient;

    uint256 public fundingRate; // per-second funding rate, scaled by 1e18
    uint256 public lastFundingTimestamp;
    uint256 public cumulativeFundingIndex; // accumulated funding index, scaled by 1e18

    struct Position {
        uint256 size; // squared exposure units
        uint256 collateral; // collateral backing the position
        uint256 lastFundingIndex; // funding index at last settlement
    }

    mapping(address => Position) public positions;
    mapping(address => uint256) public freeCollateral; // unallocated collateral
    mapping(address => uint256) public fundingAccrued; // pending funding to claim

    uint256 public totalOpenSize;
    uint256 private _locked = 1;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 grossAmount, uint256 fee);
    event PositionOpened(address indexed user, uint256 size, uint256 price);
    event PositionClosed(address indexed user, uint256 size, uint256 price);
    event FundingUpdated(uint256 cumulativeFundingIndex, uint256 fundingRate);
    event FundingRateChanged(uint256 newRate);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event FundingClaimed(address indexed user, uint256 amount);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(
        address _baseAsset,
        address _collateralToken,
        address _oracle,
        address _feeRecipient,
        uint256 _initialFundingRate
    ) {
        if (_baseAsset == address(0)) revert ZeroAddress();
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        baseAsset = _baseAsset;
        collateralToken = _collateralToken;
        oracle = IPriceOracle(_oracle);
        operator = msg.sender;
        feeRecipient = _feeRecipient;
        fundingRate = _initialFundingRate;
        lastFundingTimestamp = block.timestamp;
        cumulativeFundingIndex = FUNDING_PRECISION;

        emit FundingRateChanged(_initialFundingRate);
    }

    // -------------------------------------------------------------------------
    // Internal: Token transfers (low-level to support non-bool-returning tokens)
    // -------------------------------------------------------------------------
    function _transferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _transfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        if (!ok) revert TransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    // -------------------------------------------------------------------------
    // Internal: Funding
    // -------------------------------------------------------------------------

    /// @notice Advance the global cumulative funding index by the accrued rate
    function _updateGlobalFunding() internal {
        if (block.timestamp <= lastFundingTimestamp) return;
        uint256 elapsed = block.timestamp - lastFundingTimestamp;
        cumulativeFundingIndex += (fundingRate * elapsed) / FUNDING_PRECISION;
        lastFundingTimestamp = block.timestamp;
        emit FundingUpdated(cumulativeFundingIndex, fundingRate);
    }

    /// @notice Settle funding for a user's open position, adjusting collateral
    function _settleFunding(address user) internal {
        Position storage pos = positions[user];
        if (pos.size == 0) {
            pos.lastFundingIndex = cumulativeFundingIndex;
            return;
        }
        if (cumulativeFundingIndex <= pos.lastFundingIndex) {
            pos.lastFundingIndex = cumulativeFundingIndex;
            return;
        }
        uint256 delta = cumulativeFundingIndex - pos.lastFundingIndex;
        // Longs pay funding: funding = size * delta / precision
        uint256 fundingAmount = (pos.size * delta) / FUNDING_PRECISION;
        if (fundingAmount > pos.collateral) {
            fundingAmount = pos.collateral;
        }
        pos.collateral -= fundingAmount;
        fundingAccrued[user] += fundingAmount;
        pos.lastFundingIndex = cumulativeFundingIndex;
    }

    // -------------------------------------------------------------------------
    // Internal: Valuation
    // -------------------------------------------------------------------------

    function _getPrice() internal view returns (uint256) {
        return oracle.getPrice();
    }

    /// @notice Notional value of squared exposure = size * price^2 / PRECISION^2
    function _notionalValue(uint256 size, uint256 price) internal pure returns (uint256) {
        return (size * price * price) / (PRICE_PRECISION * PRICE_PRECISION);
    }

    /// @notice Minimum collateral required for a position size at current price
    function _minCollateralRequired(uint256 size) internal view returns (uint256) {
        uint256 price = _getPrice();
        uint256 notional = _notionalValue(size, price);
        return (notional * MIN_COLLATERALIZATION_RATIO) / BPS_DENOMINATOR;
    }

    /// @notice Enforce that an open position remains above the min CR
    function _enforceCollateralization(address user) internal view {
        Position storage pos = positions[user];
        if (pos.size == 0) return;
        uint256 required = _minCollateralRequired(pos.size);
        if (pos.collateral < required) revert Undercollateralized();
    }

    // -------------------------------------------------------------------------
    // External: User Actions
    // -------------------------------------------------------------------------

    /// @notice Deposit collateral into free balance
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateGlobalFunding();
        _settleFunding(msg.sender);
        freeCollateral[msg.sender] += amount;
        _transferFrom(collateralToken, msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    /// @notice Open or increase a squared exposure position
    /// @param size Additional squared exposure units to open
    /// @param collateralAmount Collateral to allocate from free balance to back the position
    function openPosition(uint256 size, uint256 collateralAmount) external nonReentrant {
        if (size == 0) revert ZeroAmount();
        _updateGlobalFunding();
        _settleFunding(msg.sender);

        if (collateralAmount > freeCollateral[msg.sender]) revert InsufficientCollateral();

        uint256 price = _getPrice();
        Position storage pos = positions[msg.sender];

        pos.size += size;
        pos.collateral += collateralAmount;
        freeCollateral[msg.sender] -= collateralAmount;

        totalOpenSize += size;

        // Check collateralization on the full position
        uint256 required = _minCollateralRequired(pos.size);
        if (pos.collateral < required) revert Undercollateralized();

        emit PositionOpened(msg.sender, size, price);
    }

    /// @notice Close (reduce) a squared exposure position
    /// @param size Amount of squared exposure units to close
    function closePosition(uint256 size) external nonReentrant {
        if (size == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender];
        if (pos.size == 0) revert PositionNotFound();
        if (size > pos.size) revert ZeroAmount();

        _updateGlobalFunding();
        _settleFunding(msg.sender);

        uint256 price = _getPrice();

        // Pro-rata collateral released back to free balance
        uint256 collateralReleased = (pos.collateral * size) / pos.size;
        pos.size -= size;
        pos.collateral -= collateralReleased;
        totalOpenSize -= size;

        freeCollateral[msg.sender] += collateralReleased;

        // If position fully closed, reset funding index
        if (pos.size == 0) {
            pos.lastFundingIndex = cumulativeFundingIndex;
        } else {
            _enforceCollateralization(msg.sender);
        }

        emit PositionClosed(msg.sender, size, price);
    }

    /// @notice Withdraw free collateral (and excess position collateral if needed)
    /// @dev 0.1% fee is sent to the fee recipient
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateGlobalFunding();
        _settleFunding(msg.sender);

        Position storage pos = positions[msg.sender];
        uint256 available = freeCollateral[msg.sender];

        if (pos.size > 0) {
            // Determine how much can be pulled from position collateral
            // while maintaining the minimum CR.
            uint256 required = _minCollateralRequired(pos.size);
            uint256 excessFromPosition = pos.collateral > required
                ? pos.collateral - required
                : 0;
            uint256 totalWithdrawable = available + excessFromPosition;
            if (amount > totalWithdrawable) revert InsufficientCollateral();

            if (amount > available) {
                uint256 fromPosition = amount - available;
                pos.collateral -= fromPosition;
                freeCollateral[msg.sender] = 0;
            } else {
                freeCollateral[msg.sender] -= amount;
            }
        } else {
            if (amount > available) revert InsufficientCollateral();
            freeCollateral[msg.sender] -= amount;
        }

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 net = amount - fee;

        _transfer(collateralToken, msg.sender, net);

        if (fee > 0) {
            _transfer(collateralToken, feeRecipient, fee);
        }

        emit Withdrawal(msg.sender, amount, fee);
    }

    /// @notice Claim accrued funding payments
    function claimFunding() external nonReentrant {
        _updateGlobalFunding();
        _settleFunding(msg.sender);

        uint256 amount = fundingAccrued[msg.sender];
        if (!(amount > 0)) revert NothingToClaim();
        fundingAccrued[msg.sender] = 0;

        _transfer(collateralToken, msg.sender, amount);

        emit FundingClaimed(msg.sender, amount);
    }

    // -------------------------------------------------------------------------
    // External: Operator Actions
    // -------------------------------------------------------------------------

    /// @notice Update the oracle address
    function updateOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert InvalidOracle();
        address old = address(oracle);
        oracle = IPriceOracle(newOracle);
        emit OracleUpdated(old, newOracle);
    }

    /// @notice Adjust the per-second funding rate
    function setFundingRate(uint256 newRate) external onlyOperator {
        _updateGlobalFunding();
        fundingRate = newRate;
        emit FundingRateChanged(newRate);
    }

    /// @notice Update the fee recipient
    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(old, newRecipient);
    }

    // -------------------------------------------------------------------------
    // External: Views
    // -------------------------------------------------------------------------

    /// @notice Current price of the base asset from the oracle
    function getPrice() external view returns (uint256) {
        return _getPrice();
    }

    /// @notice Minimum collateral required for a given position size
    function minCollateralRequired(uint256 size) external view returns (uint256) {
        return _minCollateralRequired(size);
    }

    /// @notice Get a user's full position details
    function getPosition(address user)
        external
        view
        returns (uint256 size, uint256 collateral, uint256 lastFundingIndex)
    {
        Position storage pos = positions[user];
        return (pos.size, pos.collateral, pos.lastFundingIndex);
    }

    /// @notice Get the collateral ratio (in bps) for a user's position
    function getCollateralRatio(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        if (pos.size == 0) return type(uint256).max;
        uint256 price = _getPrice();
        uint256 notional = _notionalValue(pos.size, price);
        if (notional == 0) return type(uint256).max;
        return (pos.collateral * BPS_DENOMINATOR) / notional;
    }

    /// @notice Total withdrawable collateral for a user (free + excess from position)
    function getWithdrawable(address user) external view returns (uint256) {
        uint256 available = freeCollateral[user];
        Position storage pos = positions[user];
        if (pos.size == 0) return available;
        uint256 required = _minCollateralRequired(pos.size);
        uint256 excess = pos.collateral > required ? pos.collateral - required : 0;
        return available + excess;
    }
}
