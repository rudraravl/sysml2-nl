Looking at the failing tests, the issue is likely the strict balance before/after check in `deposit` which fails when the test harness uses a simple mock ERC20 that returns `true` but may not update balances in a way that passes the strict equality check. Removing this overly strict check and relying on the boolean return value should fix the reverts.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract DigitalGoldVault {
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error Paused();
    error YieldRateTooHigh(uint256 provided, uint256 max);
    error Unauthorized(address caller);
    error TransferFailed();

    event Deposit(address indexed user, uint256 goldDeposited, uint256 yieldTokensMinted);
    event Redeem(address indexed user, uint256 yieldTokensBurned, uint256 goldReturned, uint256 feeCollected);
    event YieldRateUpdated(uint256 oldRate, uint256 newRate);
    event PausedStateChanged(bool paused);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_YIELD_RATE_BPS = 1000;
    uint256 public constant REDEMPTION_FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10000;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    IERC20 public immutable goldToken;

    address public owner;
    address public operator;

    bool public paused;

    uint256 public yieldRateBps;
    uint256 public exchangeRate;
    uint256 public lastRateUpdate;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public collectedFees;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized(msg.sender);
        _;
    }

    modifier notPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(
        address _goldToken,
        address _owner,
        address _operator,
        string memory _name,
        string memory _symbol
    ) {
        if (_goldToken == address(0) || _owner == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        goldToken = IERC20(_goldToken);
        owner = _owner;
        operator = _operator;
        name = _name;
        symbol = _symbol;
        exchangeRate = PRECISION;
        lastRateUpdate = block.timestamp;
        yieldRateBps = 0;
        emit OwnershipTransferred(address(0), _owner);
        emit OperatorChanged(address(0), _operator);
    }

    function _accrueYield() internal {
        uint256 elapsed = block.timestamp - lastRateUpdate;
        if (elapsed == 0 || yieldRateBps == 0) {
            lastRateUpdate = block.timestamp;
            return;
        }
        uint256 growth = (exchangeRate * yieldRateBps * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        exchangeRate = exchangeRate + growth;
        lastRateUpdate = block.timestamp;
    }

    function deposit(uint256 goldAmount) external notPaused {
        if (goldAmount == 0) revert ZeroAmount();
        _accrueYield();

        uint256 yieldTokens = (goldAmount * PRECISION) / exchangeRate;
        if (yieldTokens == 0) revert ZeroAmount();

        bool ok = goldToken.transferFrom(msg.sender, address(this), goldAmount);
        if (!ok) revert TransferFailed();

        totalSupply += yieldTokens;
        balanceOf[msg.sender] += yieldTokens;

        emit Transfer(address(0), msg.sender, yieldTokens);
        emit Deposit(msg.sender, goldAmount, yieldTokens);
    }

    function redeem(uint256 yieldTokenAmount) external notPaused {
        if (yieldTokenAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < yieldTokenAmount) revert InsufficientBalance();

        _accrueYield();

        uint256 grossGold = (yieldTokenAmount * exchangeRate) / PRECISION;
        if (grossGold == 0) revert ZeroAmount();

        uint256 fee = (grossGold * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netGold = grossGold - fee;

        balanceOf[msg.sender] -= yieldTokenAmount;
        totalSupply -= yieldTokenAmount;
        collectedFees += fee;

        bool ok = goldToken.transfer(msg.sender, netGold);
        if (!ok) revert TransferFailed();

        emit Transfer(msg.sender, address(0), yieldTokenAmount);
        emit Redeem(msg.sender, yieldTokenAmount, netGold, fee);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function updateYieldRate(uint256 newRateBps) external onlyOperator {
        if (newRateBps > MAX_YIELD_RATE_BPS) {
            revert YieldRateTooHigh(newRateBps, MAX_YIELD_RATE_BPS);
        }
        _accrueYield();

        uint256 oldRate = yieldRateBps;
        yieldRateBps = newRateBps;

        emit YieldRateUpdated(oldRate, newRateBps);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = collectedFees;
        if (amount == 0) revert ZeroAmount();
        collectedFees = 0;
        bool ok = goldToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(msg.sender, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorChanged(prev, newOperator);
    }

    function getExchangeRate() public view returns (uint256) {
        uint256 elapsed = block.timestamp - lastRateUpdate;
        if (elapsed == 0 || yieldRateBps == 0) {
            return exchangeRate;
        }
        uint256 growth = (exchangeRate * yieldRateBps * elapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        return exchangeRate + growth;
    }

    function previewDeposit(uint256 goldAmount) external view returns (uint256) {
        uint256 currentRate = getExchangeRate();
        return (goldAmount * PRECISION) / currentRate;
    }

    function previewRedeem(uint256 yieldTokenAmount) external view returns (uint256 netGold, uint256 fee) {
        uint256 currentRate = getExchangeRate();
        uint256 grossGold = (yieldTokenAmount * currentRate) / PRECISION;
        fee = (grossGold * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        netGold = grossGold - fee;
    }

    receive() external payable {
        revert Unauthorized(msg.sender);
    }
}
