// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract YieldVault {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error Unauthorized();
    error ReentrantCall();
    error BelowMinimumDeposit(uint256 amount, uint256 minimum);
    error InsufficientDeposit(address user, uint256 requested, uint256 available);
    error ZeroAmount();
    error NoYieldToClaim();
    error FeeExceedsMax(uint256 fee, uint256 maxFee);
    error NoDeposits();

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount, uint256 fee);
    event YieldClaimed(address indexed user, uint256 amount);
    event YieldAdded(uint256 amount);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MIN_DEPOSIT = 100 * 1e18;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;

    IERC20 public immutable stablecoin;
    address public operator;
    address public yieldStrategy;
    uint256 public withdrawalFeeBps;

    uint256 public totalDeposits;
    uint256 public accYieldPerShare;
    uint256 public totalYieldDistributed;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public yieldDebt;
    mapping(address => uint256) public pendingYield;

    bool private _locked;

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        withdrawalFeeBps = 10;
        emit OperatorUpdated(address(0), _operator);
        emit WithdrawalFeeUpdated(0, 10);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit(amount, MIN_DEPOSIT);

        _updateUserYield(msg.sender);

        deposits[msg.sender] += amount;
        totalDeposits += amount;
        yieldDebt[msg.sender] = (deposits[msg.sender] * accYieldPerShare) / PRECISION;

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (deposits[msg.sender] < amount)
            revert InsufficientDeposit(msg.sender, amount, deposits[msg.sender]);

        _updateUserYield(msg.sender);

        uint256 fee = (amount * withdrawalFeeBps) / FEE_DENOMINATOR;
        uint256 userAmount = amount - fee;

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        yieldDebt[msg.sender] = (deposits[msg.sender] * accYieldPerShare) / PRECISION;

        stablecoin.safeTransfer(msg.sender, userAmount);
        if (fee > 0) {
            stablecoin.safeTransfer(operator, fee);
        }

        emit Withdrawal(msg.sender, amount, fee);
    }

    function claimYield() external nonReentrant {
        _updateUserYield(msg.sender);
        uint256 yield_ = pendingYield[msg.sender];
        if (yield_ == 0) revert NoYieldToClaim();

        pendingYield[msg.sender] = 0;
        stablecoin.safeTransfer(msg.sender, yield_);

        emit YieldClaimed(msg.sender, yield_);
    }

    function addYield(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (totalDeposits == 0) revert NoDeposits();

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        accYieldPerShare += (amount * PRECISION) / totalDeposits;
        totalYieldDistributed += amount;

        emit YieldAdded(amount);
    }

    function setStrategy(address newStrategy) external onlyOperator {
        address old = yieldStrategy;
        yieldStrategy = newStrategy;
        emit StrategyUpdated(old, newStrategy);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMax(newFeeBps, MAX_FEE_BPS);
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(old, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function pendingYieldOf(address user) external view returns (uint256) {
        uint256 userDeposit = deposits[user];
        if (userDeposit == 0) {
            return pendingYield[user];
        }
        uint256 accumulated = (userDeposit * accYieldPerShare) / PRECISION;
        if (accumulated > yieldDebt[user]) {
            return (accumulated - yieldDebt[user]) + pendingYield[user];
        }
        return pendingYield[user];
    }

    function totalAssets() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    function _updateUserYield(address user) internal {
        uint256 userDeposit = deposits[user];
        if (userDeposit > 0) {
            uint256 accumulated = (userDeposit * accYieldPerShare) / PRECISION;
            if (accumulated > yieldDebt[user]) {
                pendingYield[user] += accumulated - yieldDebt[user];
            }
        }
        yieldDebt[user] = (userDeposit * accYieldPerShare) / PRECISION;
    }
}
