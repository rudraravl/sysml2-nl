// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract TokenizedShortDurationGovernmentSecuritiesFund {
    string public constant name = "Short-Duration Government Securities Fund";
    string public constant symbol = "SDGSF";
    uint8 public constant decimals = 18;
    uint256 internal constant UNIT = 1e18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable stablecoin;
    uint8 public immutable stablecoinDecimals;

    address public operator;
    uint256 public navPerUnit;
    uint256 public lastNavUpdateDay;
    bool public subscriptionsPaused;
    bool public redemptionsPaused;

    uint256 public constant REDEMPTION_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant SECONDS_PER_DAY = 86_400;
    uint256 public constant SETTLEMENT_HOUR_UTC = 17;
    uint256 public constant SETTLEMENT_SECONDS_UTC = SETTLEMENT_HOUR_UTC * 3_600;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Subscribed(address indexed subscriber, uint256 stablecoinAmount, uint256 unitsMinted, uint256 navPerUnit);
    event Redeemed(address indexed redeemer, uint256 unitsBurned, uint256 stablecoinOut, uint256 feeCharged, uint256 navPerUnit);
    event NAVUpdated(uint256 newNavPerUnit, uint256 dayIndex, uint256 timestamp);
    event SubscriptionsPaused(address indexed operator);
    event SubscriptionsUnpaused(address indexed operator);
    event RedemptionsPaused(address indexed operator);
    event RedemptionsUnpaused(address indexed operator);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidNAV();
    error InvalidDecimals();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InsufficientContractBalance();
    error SubscriptionsArePaused();
    error RedemptionsArePaused();
    error NAVNotUpdated();
    error OutsideProcessingWindow();
    error NAVAlreadyUpdatedToday();
    error TransferFailed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stablecoin, address _operator, uint256 _initialNavPerUnit, uint8 _stablecoinDecimals) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialNavPerUnit == 0) revert InvalidNAV();
        if (_stablecoinDecimals > 30) revert InvalidDecimals();

        stablecoin = IERC20(_stablecoin);
        stablecoinDecimals = _stablecoinDecimals;
        operator = _operator;
        navPerUnit = _initialNavPerUnit;
        lastNavUpdateDay = block.timestamp / SECONDS_PER_DAY;

        emit OperatorChanged(address(0), _operator);
        emit NAVUpdated(_initialNavPerUnit, lastNavUpdateDay, block.timestamp);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
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
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        uint256 newAllowance = currentAllowance - subtractedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function subscribe(uint256 stablecoinAmount) external returns (uint256 unitsMinted) {
        if (subscriptionsPaused) revert SubscriptionsArePaused();
        if (stablecoinAmount == 0) revert ZeroAmount();
        _requireProcessingWindow();

        uint256 currentNav = navPerUnit;
        uint256 normalizedAmount = _to18Decimals(stablecoinAmount);
        unitsMinted = (normalizedAmount * UNIT) / currentNav;
        if (unitsMinted == 0) revert ZeroAmount();

        _safeTransferFrom(msg.sender, address(this), stablecoinAmount);
        _mint(msg.sender, unitsMinted);

        emit Subscribed(msg.sender, stablecoinAmount, unitsMinted, currentNav);
    }

    function redeem(uint256 units) external returns (uint256 stablecoinOut) {
        if (redemptionsPaused) revert RedemptionsArePaused();
        if (units == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < units) revert InsufficientBalance();
        _requireProcessingWindow();

        uint256 currentNav = navPerUnit;
        uint256 grossValue18 = (units * currentNav) / UNIT;
        uint256 grossStablecoin = _from18Decimals(grossValue18);
        uint256 fee = (grossStablecoin * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        stablecoinOut = grossStablecoin - fee;

        if (stablecoinOut == 0) revert ZeroAmount();
        if (stablecoin.balanceOf(address(this)) < stablecoinOut) revert InsufficientContractBalance();

        _burn(msg.sender, units);
        _safeTransfer(msg.sender, stablecoinOut);

        emit Redeemed(msg.sender, units, stablecoinOut, fee, currentNav);
    }

    function updateNAV(uint256 _newNavPerUnit) external onlyOperator {
        if (_newNavPerUnit == 0) revert InvalidNAV();
        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        if (currentDay <= lastNavUpdateDay) revert NAVAlreadyUpdatedToday();
        navPerUnit = _newNavPerUnit;
        lastNavUpdateDay = currentDay;
        emit NAVUpdated(_newNavPerUnit, currentDay, block.timestamp);
    }

    function pauseSubscriptions() external onlyOperator {
        subscriptionsPaused = true;
        emit SubscriptionsPaused(msg.sender);
    }

    function unpauseSubscriptions() external onlyOperator {
        subscriptionsPaused = false;
        emit SubscriptionsUnpaused(msg.sender);
    }

    function pauseRedemptions() external onlyOperator {
        redemptionsPaused = true;
        emit RedemptionsPaused(msg.sender);
    }

    function unpauseRedemptions() external onlyOperator {
        redemptionsPaused = false;
        emit RedemptionsUnpaused(msg.sender);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _newOperator);
        operator = _newOperator;
    }

    function currentDay() external view returns (uint256) {
        return block.timestamp / SECONDS_PER_DAY;
    }

    function getStablecoinBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    function previewSubscribe(uint256 stablecoinAmount) external view returns (uint256) {
        if (stablecoinAmount == 0) return 0;
        uint256 normalized = _to18Decimals(stablecoinAmount);
        return (normalized * UNIT) / navPerUnit;
    }

    function previewRedeem(uint256 units) external view returns (uint256 netOut, uint256 fee) {
        if (units == 0) return (0, 0);
        uint256 gross18 = (units * navPerUnit) / UNIT;
        uint256 gross = _from18Decimals(gross18);
        fee = (gross * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        netOut = gross - fee;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (value == 0) revert ZeroAmount();
        if (balanceOf[from] < value) revert InsufficientBalance();
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _requireProcessingWindow() internal view {
        uint256 dayIndex = block.timestamp / SECONDS_PER_DAY;
        uint256 dayStart = dayIndex * SECONDS_PER_DAY;
        uint256 secondsIntoDay = block.timestamp - dayStart;
        if (secondsIntoDay < SETTLEMENT_SECONDS_UTC) revert OutsideProcessingWindow();
        if (lastNavUpdateDay < dayIndex) revert NAVNotUpdated();
    }

    function _to18Decimals(uint256 amount) internal view returns (uint256) {
        if (stablecoinDecimals == 18) return amount;
        if (stablecoinDecimals < 18) return amount * (10 ** (18 - stablecoinDecimals));
        return amount / (10 ** (stablecoinDecimals - 18));
    }

    function _from18Decimals(uint256 amount) internal view returns (uint256) {
        if (stablecoinDecimals == 18) return amount;
        if (stablecoinDecimals < 18) return amount / (10 ** (18 - stablecoinDecimals));
        return amount * (10 ** (stablecoinDecimals - 18));
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0) {
            if (!abi.decode(data, (bool))) revert TransferFailed();
        }
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert TransferFailed();
        if (data.length > 0) {
            if (!abi.decode(data, (bool))) revert TransferFailed();
        }
    }
}
