// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidStaking {
    // ============ Custom Errors ============
    error NotOwner();
    error NotOperator();
    error WhenPaused();
    error InsufficientDeposit();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InvalidYieldRate();
    error InvalidAddress();
    error InsufficientLiquidity();
    error ReentrantCall();
    error EthTransferFailed();

    // ============ Events ============
    event Deposit(address indexed depositor, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        uint256 shares,
        uint256 assets,
        uint256 fee
    );
    event StakingYieldRateUpdated(uint256 oldRate, uint256 newRate);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event FeesCollected(address indexed collector, address indexed to, uint256 amount);
    event YieldRealized(address indexed from, uint256 amount);

    // ============ Constants ============
    uint256 public constant MIN_DEPOSIT = 0.1 ether;
    uint16 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_YIELD_RATE = 1e18; // 100% APR cap
    uint256 internal constant RATE_PRECISION = 1e18;

    // ============ Token Metadata ============
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ============ Access Control ============
    address public owner;
    address public operator;
    bool public paused;

    // ============ ERC20 State ============
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ============ Staking State ============
    uint256 public totalAssets; // cumulative deposits + yield realizations - gross redemptions
    uint256 public yieldRate; // annual percentage rate in 1e18 precision (e.g. 0.05e18 = 5%)
    uint256 public accumulatedRate; // share-to-asset exchange rate, starts at 1e18
    uint256 public lastAccrualTime;
    uint256 public collectedFees;

    // ============ Reentrancy Guard ============
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert WhenPaused();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ============ Constructor ============
    constructor(string memory _name, string memory _symbol, uint256 _initialYieldRate) {
        if (_initialYieldRate > MAX_YIELD_RATE) revert InvalidYieldRate();
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        operator = msg.sender;
        yieldRate = _initialYieldRate;
        accumulatedRate = RATE_PRECISION;
        lastAccrualTime = block.timestamp;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), msg.sender);
    }

    // ============ Yield Accrual ============
    function accrue() public {
        uint256 elapsed = block.timestamp - lastAccrualTime;
        if (elapsed < 1) return;
        uint256 rateDelta = (yieldRate * elapsed) / SECONDS_PER_YEAR;
        if (rateDelta > 0) {
            accumulatedRate += rateDelta;
        }
        lastAccrualTime = block.timestamp;
    }

    function currentExchangeRate() public view returns (uint256) {
        uint256 elapsed = block.timestamp - lastAccrualTime;
        return accumulatedRate + (yieldRate * elapsed) / SECONDS_PER_YEAR;
    }

    function convertAssetsToShares(uint256 assets) public view returns (uint256) {
        return (assets * RATE_PRECISION) / currentExchangeRate();
    }

    function convertSharesToAssets(uint256 shares) public view returns (uint256) {
        return (shares * currentExchangeRate()) / RATE_PRECISION;
    }

    // ============ Deposit ============
    function deposit() external payable whenNotPaused nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert InsufficientDeposit();
        accrue();
        uint256 shares = convertAssetsToShares(msg.value);
        if (shares < 1) revert ZeroAmount();
        totalAssets += msg.value;
        totalSupply += shares;
        balanceOf[msg.sender] += shares;
        emit Transfer(address(0), msg.sender, shares);
        emit Deposit(msg.sender, msg.value, shares);
    }

    // ============ Redeem ============
    function redeem(uint256 shares, address receiver) external whenNotPaused nonReentrant {
        if (shares < 1) revert ZeroAmount();
        if (receiver == address(0)) revert InvalidAddress();
        if (balanceOf[msg.sender] < shares) revert InsufficientBalance();

        accrue();
        uint256 assets = convertSharesToAssets(shares);
        if (assets > totalAssets) revert InsufficientLiquidity();

        uint256 fee = (assets * FEE_BASIS_POINTS) / BPS_DENOMINATOR;
        uint256 assetsToReturn = assets - fee;

        // Effects
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        totalAssets -= assets;
        collectedFees += fee;

        // Interactions
        (bool success, ) = payable(receiver).call{value: assetsToReturn}("");
        if (!success) revert EthTransferFailed();

        emit Transfer(msg.sender, address(0), shares);
        emit Withdraw(msg.sender, receiver, shares, assetsToReturn, fee);
    }

    // ============ Yield Realization ============
    // Accepts base network assets (e.g. staking rewards) to back the appreciated exchange rate.
    receive() external payable {
        if (msg.value > 0) {
            totalAssets += msg.value;
            emit YieldRealized(msg.sender, msg.value);
        }
    }

    // ============ ERC20 Transfer / Approval ============
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // ============ Operator Functions ============
    function setYieldRate(uint256 newRate) external onlyOperator {
        if (newRate > MAX_YIELD_RATE) revert InvalidYieldRate();
        accrue();
        uint256 oldRate = yieldRate;
        yieldRate = newRate;
        emit StakingYieldRateUpdated(oldRate, newRate);
    }

    // ============ Owner Functions ============
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function collectFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        uint256 amount = collectedFees;
        if (amount < 1) revert ZeroAmount();
        collectedFees = 0;
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert EthTransferFailed();
        emit FeesCollected(msg.sender, to, amount);
    }

    // ============ Views ============
    function exchangeRate() external view returns (uint256) {
        return currentExchangeRate();
    }

    function getStats()
        external
        view
        returns (
            uint256 _totalSupply,
            uint256 _totalAssets,
            uint256 _rate,
            uint256 _fees,
            bool _paused
        )
    {
        return (totalSupply, totalAssets, currentExchangeRate(), collectedFees, paused);
    }
}
