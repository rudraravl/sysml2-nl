// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract YieldBearingStablecoin {
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_YIELD_RATE_BPS = 1000; // 10%
    uint256 public constant REDEMPTION_FEE_BPS = 10;   // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant YIELD_DURATION = 7 days;
    uint256 private constant PRECISION = 1e18;

    IERC20 public immutable baseToken;

    address public owner;
    address public operator;
    bool public paused;

    uint256 public totalBaseSupply;
    uint256 public totalDerivativeSupply;

    mapping(address => uint256) public userBaseBalance;
    mapping(address => uint256) public userDerivativeBalance;

    uint256 public yieldRateBps;
    uint256 public yieldRate;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public yieldPerTokenStored;
    uint256 public yieldReserve;

    mapping(address => uint256) public userYieldPerTokenPaid;
    mapping(address => uint256) public accruedYield;

    event Deposit(address indexed user, uint256 baseAmount, uint256 derivativeAmount);
    event Redeem(address indexed user, uint256 derivativeAmount, uint256 baseAmount, uint256 fee);
    event YieldClaimed(address indexed user, uint256 amount);
    event YieldRateBpsUpdated(uint256 oldRate, uint256 newRate);
    event YieldNotified(uint256 amount, uint256 rate, uint256 periodFinish);
    event Paused();
    event Unpaused();
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    error ErrZeroAddress();
    error ErrZeroAmount();
    error ErrPaused();
    error ErrNotOwner();
    error ErrNotOperator();
    error ErrRateTooHigh();
    error ErrInsufficientBalance();
    error ErrNoYieldToClaim();
    error ErrCannotRecoverBaseToken();
    error ErrTransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrNotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    constructor(address _baseToken, address _operator) {
        if (_baseToken == address(0)) revert ErrZeroAddress();
        if (_operator == address(0)) revert ErrZeroAddress();
        baseToken = IERC20(_baseToken);
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    function _updateYield() internal {
        uint256 _totalDerivativeSupply = totalDerivativeSupply;
        if (_totalDerivativeSupply == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 endTime = block.timestamp > periodFinish ? periodFinish : block.timestamp;
        if (endTime <= lastUpdateTime) return;

        uint256 timeElapsed = endTime - lastUpdateTime;

        uint256 yieldAccrued = yieldRate * timeElapsed;
        if (yieldAccrued > yieldReserve) yieldAccrued = yieldReserve;

        yieldPerTokenStored += (yieldAccrued * PRECISION) / _totalDerivativeSupply;
        yieldReserve -= yieldAccrued;
        lastUpdateTime = endTime;

        if (block.timestamp >= periodFinish) {
            yieldRate = 0;
        }
    }

    function _updateUserYield(address user) internal {
        _updateYield();
        uint256 derivativeBalance = userDerivativeBalance[user];
        if (derivativeBalance > 0) {
            uint256 pending = (derivativeBalance * yieldPerTokenStored) / PRECISION;
            pending = pending - userYieldPerTokenPaid[user];
            if (pending > 0) {
                accruedYield[user] += pending;
            }
        }
        userYieldPerTokenPaid[user] = yieldPerTokenStored;
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ErrZeroAmount();
        _updateUserYield(msg.sender);

        userBaseBalance[msg.sender] += amount;
        userDerivativeBalance[msg.sender] += amount;
        totalBaseSupply += amount;
        totalDerivativeSupply += amount;

        if (!baseToken.transferFrom(msg.sender, address(this), amount)) revert ErrTransferFailed();

        emit Deposit(msg.sender, amount, amount);
    }

    function redeem(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ErrZeroAmount();
        _updateUserYield(msg.sender);

        if (userDerivativeBalance[msg.sender] < amount) revert ErrInsufficientBalance();

        uint256 fee = (amount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 transferable = amount - fee;

        userDerivativeBalance[msg.sender] -= amount;
        userBaseBalance[msg.sender] -= amount;
        totalDerivativeSupply -= amount;
        totalBaseSupply -= amount;
        yieldReserve += fee;

        if (!baseToken.transfer(msg.sender, transferable)) revert ErrTransferFailed();

        emit Redeem(msg.sender, amount, transferable, fee);
    }

    function claimYield() external {
        _updateUserYield(msg.sender);
        uint256 amount = accruedYield[msg.sender];
        if (amount <= 0) revert ErrNoYieldToClaim();

        accruedYield[msg.sender] = 0;

        if (!baseToken.transfer(msg.sender, amount)) revert ErrTransferFailed();

        emit YieldClaimed(msg.sender, amount);
    }

    function setYieldRateBps(uint256 newRate) external onlyOperator {
        if (newRate > MAX_YIELD_RATE_BPS) revert ErrRateTooHigh();
        uint256 oldRate = yieldRateBps;
        yieldRateBps = newRate;
        emit YieldRateBpsUpdated(oldRate, newRate);
    }

    function notifyYield(uint256 amount) external onlyOperator {
        if (amount == 0) revert ErrZeroAmount();
        _updateYield();

        yieldReserve += amount;

        uint256 _totalDerivativeSupply = totalDerivativeSupply;
        if (_totalDerivativeSupply > 0 && yieldRateBps > 0) {
            yieldRate = (_totalDerivativeSupply * yieldRateBps) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp + YIELD_DURATION;
        }

        if (!baseToken.transferFrom(msg.sender, address(this), amount)) revert ErrTransferFailed();

        emit YieldNotified(amount, yieldRate, periodFinish);
    }

    function pause() external onlyOperator {
        if (paused) revert ErrPaused();
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOperator {
        if (!paused) revert ErrPaused();
        paused = false;
        emit Unpaused();
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ErrZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function recoverToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ErrZeroAddress();
        if (token == address(baseToken)) revert ErrCannotRecoverBaseToken();
        if (!IERC20(token).transfer(to, amount)) revert ErrTransferFailed();
        emit Recovered(token, to, amount);
    }

    function earned(address user) external view returns (uint256) {
        uint256 currentYieldPerToken = yieldPerTokenStored;
        uint256 _totalDerivativeSupply = totalDerivativeSupply;
        if (_totalDerivativeSupply > 0 && block.timestamp > lastUpdateTime && block.timestamp < periodFinish) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            uint256 yieldAccrued = yieldRate * timeElapsed;
            if (yieldAccrued > yieldReserve) yieldAccrued = yieldReserve;
            currentYieldPerToken += (yieldAccrued * PRECISION) / _totalDerivativeSupply;
        }
        uint256 derivativeBalance = userDerivativeBalance[user];
        uint256 pending = (derivativeBalance * currentYieldPerToken) / PRECISION;
        pending = pending - userYieldPerTokenPaid[user];
        return accruedYield[user] + pending;
    }

    function getYieldPerToken() external view returns (uint256) {
        uint256 currentYieldPerToken = yieldPerTokenStored;
        uint256 _totalDerivativeSupply = totalDerivativeSupply;
        if (_totalDerivativeSupply > 0 && block.timestamp > lastUpdateTime && block.timestamp < periodFinish) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            uint256 yieldAccrued = yieldRate * timeElapsed;
            if (yieldAccrued > yieldReserve) yieldAccrued = yieldReserve;
            currentYieldPerToken += (yieldAccrued * PRECISION) / _totalDerivativeSupply;
        }
        return currentYieldPerToken;
    }

    function balanceOfBase(address user) external view returns (uint256) {
        return userBaseBalance[user];
    }

    function balanceOfDerivative(address user) external view returns (uint256) {
        return userDerivativeBalance[user];
    }
}
