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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract DecentralizedStablecoin {
    using SafeERC20 for IERC20;

    // ============ Custom Errors ============
    error ZeroAddress();
    error NotOperator();
    error MintPaused();
    error BurnPaused();
    error InvalidAmount();
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error InvalidRateBounds();
    error RateOutOfBounds(uint256 rate, uint256 min, uint256 max);
    error RateChangeTooLarge(uint256 requested, uint256 minAllowed, uint256 maxAllowed);
    error InsufficientReserve(uint256 available, uint256 required);

    // ============ Constants ============
    uint256 public constant RATE_PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_RATE_CHANGE_BPS = 50; // 0.5%
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant ADJUSTMENT_WINDOW = 24 hours;
    uint256 private constant RATE_FEE_PRODUCT = RATE_PRECISION * BPS_DENOMINATOR;

    // ============ ERC20 Metadata ============
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ============ ERC20 State ============
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ============ Stablecoin State ============
    IERC20 public immutable collateral;
    uint256 public immutable minRate;
    uint256 public immutable maxRate;
    address public operator;
    address public feeRecipient;

    uint256 public collateralReserve;
    uint256 public redemptionRate;
    uint256 public windowStartTime;
    uint256 public windowStartRate;

    bool public mintPaused;
    bool public burnPaused;

    // ============ Events ============
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Minted(address indexed minter, address indexed to, uint256 stablecoinAmount, uint256 collateralDeposited);
    event Burned(address indexed burner, address indexed from, uint256 stablecoinAmount, uint256 collateralReturned, uint256 fee);
    event RedemptionRateUpdated(uint256 oldRate, uint256 newRate);
    event MintPausedSet(bool paused);
    event BurnPausedSet(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenMintNotPaused() {
        if (mintPaused) revert MintPaused();
        _;
    }

    modifier whenBurnNotPaused() {
        if (burnPaused) revert BurnPaused();
        _;
    }

    // ============ Constructor ============
    constructor(
        address _collateral,
        string memory _name,
        string memory _symbol,
        uint256 _initialRate,
        uint256 _minRate,
        uint256 _maxRate,
        address _operator,
        address _feeRecipient
    ) {
        if (_collateral == address(0) || _operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        if (_minRate == 0 || _maxRate < _minRate) revert InvalidRateBounds();
        if (_initialRate < _minRate || _initialRate > _maxRate) revert RateOutOfBounds(_initialRate, _minRate, _maxRate);

        collateral = IERC20(_collateral);
        name = _name;
        symbol = _symbol;
        minRate = _minRate;
        maxRate = _maxRate;
        operator = _operator;
        feeRecipient = _feeRecipient;
        redemptionRate = _initialRate;
        windowStartTime = block.timestamp;
        windowStartRate = _initialRate;
    }

    // ============ ERC20 Core ============
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 available = balanceOf[from];
        if (available < amount) revert InsufficientBalance(available, amount);

        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(allowed, amount);

        unchecked {
            balanceOf[from] = available - amount;
            balanceOf[to] += amount;
            if (allowed != type(uint256).max) {
                allowance[from][msg.sender] = allowed - amount;
            }
        }

        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance(currentAllowance, subtractedValue);
        unchecked {
            uint256 newAllowance = currentAllowance - subtractedValue;
            allowance[msg.sender][spender] = newAllowance;
            emit Approval(msg.sender, spender, newAllowance);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 available = balanceOf[from];
        if (available < amount) revert InsufficientBalance(available, amount);

        unchecked {
            balanceOf[from] = available - amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 available = balanceOf[from];
        if (available < amount) revert InsufficientBalance(available, amount);
        unchecked {
            balanceOf[from] = available - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    // ============ Mint / Burn ============
    function mint(address to, uint256 stablecoinAmount) external whenMintNotPaused returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (stablecoinAmount == 0) revert InvalidAmount();

        uint256 collateralRequired = (stablecoinAmount * redemptionRate) / RATE_PRECISION;
        if (collateralRequired == 0) revert InvalidAmount();

        collateral.safeTransferFrom(msg.sender, address(this), collateralRequired);

        collateralReserve += collateralRequired;
        _mint(to, stablecoinAmount);

        emit Minted(msg.sender, to, stablecoinAmount, collateralRequired);
        return true;
    }

    function burn(uint256 stablecoinAmount) external whenBurnNotPaused returns (bool) {
        if (stablecoinAmount == 0) revert InvalidAmount();
        uint256 available = balanceOf[msg.sender];
        if (available < stablecoinAmount) revert InsufficientBalance(available, stablecoinAmount);

        // Compute gross and fee without divide-before-multiply: derive the fee
        // directly from the unrounded product, then subtract it from the gross.
        uint256 fullCollateral = stablecoinAmount * redemptionRate;
        uint256 grossCollateral = fullCollateral / RATE_PRECISION;
        if (grossCollateral == 0) revert InvalidAmount();
        if (collateralReserve < grossCollateral) revert InsufficientReserve(collateralReserve, grossCollateral);

        uint256 fee = fullCollateral * REDEMPTION_FEE_BPS / RATE_FEE_PRODUCT;
        uint256 netCollateral = grossCollateral - fee;

        _burn(msg.sender, stablecoinAmount);
        collateralReserve -= grossCollateral;

        if (netCollateral > 0) {
            collateral.safeTransfer(msg.sender, netCollateral);
        }
        if (fee > 0) {
            collateral.safeTransfer(feeRecipient, fee);
        }

        emit Burned(msg.sender, msg.sender, stablecoinAmount, netCollateral, fee);
        return true;
    }

    // ============ Operator Functions ============
    function setRedemptionRate(uint256 newRate) external onlyOperator {
        if (newRate < minRate || newRate > maxRate) revert RateOutOfBounds(newRate, minRate, maxRate);

        uint256 currentTime = block.timestamp;
        uint256 referenceRate = windowStartRate;

        if (currentTime - windowStartTime >= ADJUSTMENT_WINDOW) {
            windowStartTime = currentTime;
            windowStartRate = redemptionRate;
            referenceRate = redemptionRate;
        }

        uint256 maxDelta = (referenceRate * MAX_RATE_CHANGE_BPS) / BPS_DENOMINATOR;
        if (maxDelta == 0) maxDelta = 1;
        uint256 maxAllowed = referenceRate + maxDelta;
        uint256 minAllowed = referenceRate > maxDelta ? referenceRate - maxDelta : 0;

        if (newRate > maxAllowed || newRate < minAllowed) {
            revert RateChangeTooLarge(newRate, minAllowed, maxAllowed);
        }

        uint256 oldRate = redemptionRate;
        redemptionRate = newRate;
        emit RedemptionRateUpdated(oldRate, newRate);
    }

    function setMintPaused(bool _paused) external onlyOperator {
        mintPaused = _paused;
        emit MintPausedSet(_paused);
    }

    function setBurnPaused(bool _paused) external onlyOperator {
        burnPaused = _paused;
        emit BurnPausedSet(_paused);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(old, newRecipient);
    }

    // ============ View Functions ============
    function collateralRequiredForMint(uint256 stablecoinAmount) external view returns (uint256) {
        return (stablecoinAmount * redemptionRate) / RATE_PRECISION;
    }

    function collateralReturnedForBurn(uint256 stablecoinAmount) external view returns (uint256 net, uint256 fee) {
        // Avoid divide-before-multiply: compute the fee from the unrounded
        // product, then subtract from the gross (rounded) amount.
        uint256 fullCollateral = stablecoinAmount * redemptionRate;
        uint256 gross = fullCollateral / RATE_PRECISION;
        fee = fullCollateral * REDEMPTION_FEE_BPS / RATE_FEE_PRODUCT;
        net = gross - fee;
    }

    function currentRateAdjustmentBounds() external view returns (uint256 minAllowed, uint256 maxAllowed) {
        uint256 referenceRate = (block.timestamp - windowStartTime >= ADJUSTMENT_WINDOW) ? redemptionRate : windowStartRate;
        uint256 maxDelta = (referenceRate * MAX_RATE_CHANGE_BPS) / BPS_DENOMINATOR;
        if (maxDelta == 0) maxDelta = 1;
        maxAllowed = referenceRate + maxDelta;
        minAllowed = referenceRate > maxDelta ? referenceRate - maxDelta : 0;
        if (minAllowed < minRate) minAllowed = minRate;
        if (maxAllowed > maxRate) maxAllowed = maxRate;
    }
}
