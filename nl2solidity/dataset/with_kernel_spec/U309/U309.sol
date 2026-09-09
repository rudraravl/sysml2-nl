// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract GoldVault {
    IERC20 public immutable goldToken;

    address public operator;
    uint256 public totalSupply;
    uint256 public withdrawalFeeBps; // basis points, 50 = 0.5%

    bool public depositsPaused;
    bool public withdrawalsPaused;

    uint256 public constant MAX_DAILY_WITHDRAWAL = 100 * 10 ** 18;
    uint256 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 public constant SECONDS_PER_DAY = 1 days;
    uint256 public constant FEE_DENOMINATOR = 10000;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public dailyWithdrawn;
    mapping(address => uint256) public lastWithdrawDay;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amountRequested, uint256 amountReceived, uint256 fee);
    event VaultTransfer(address indexed from, address indexed to, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event DepositsPausedChanged(bool paused);
    event WithdrawalsPausedChanged(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error DepositsArePaused();
    error WithdrawalsArePaused();
    error InsufficientBalance();
    error ExceedsDailyLimit();
    error ZeroAmount();
    error InvalidFee();
    error TransferFailed();
    error InvalidAddress();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _goldToken, address _operator) {
        if (_goldToken == address(0) || _operator == address(0)) revert InvalidAddress();
        goldToken = IERC20(_goldToken);
        operator = _operator;
        withdrawalFeeBps = 50; // 0.5%
        emit FeeUpdated(0, 50);
        emit OperatorChanged(address(0), _operator);
    }

    function deposit(uint256 amount) external {
        if (depositsPaused) revert DepositsArePaused();
        if (amount == 0) revert ZeroAmount();

        balances[msg.sender] += amount;
        totalSupply += amount;

        bool ok = goldToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        if (lastWithdrawDay[msg.sender] < currentDay) {
            dailyWithdrawn[msg.sender] = 0;
            lastWithdrawDay[msg.sender] = currentDay;
        }
        if (dailyWithdrawn[msg.sender] + amount > MAX_DAILY_WITHDRAWAL) revert ExceedsDailyLimit();

        uint256 fee = (amount * withdrawalFeeBps) / FEE_DENOMINATOR;
        uint256 receiveAmount = amount - fee;

        balances[msg.sender] -= amount;
        totalSupply -= amount;
        dailyWithdrawn[msg.sender] += amount;

        bool ok = goldToken.transfer(msg.sender, receiveAmount);
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, amount, receiveAmount, fee);
    }

    function transferVaultBalance(address to, uint256 amount) external {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit VaultTransfer(msg.sender, to, amount);
    }

    function setDepositsPaused(bool paused) external onlyOperator {
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    function setWithdrawalsPaused(bool paused) external onlyOperator {
        withdrawalsPaused = paused;
        emit WithdrawalsPausedChanged(paused);
    }

    function setWithdrawalFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function getDailyWithdrawn(address user) external view returns (uint256 withdrawn, uint256 day) {
        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        if (lastWithdrawDay[user] >= currentDay) {
            return (dailyWithdrawn[user], currentDay);
        }
        return (0, currentDay);
    }

    function remainingDailyWithdrawal(address user) external view returns (uint256) {
        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        if (lastWithdrawDay[user] < currentDay) {
            return MAX_DAILY_WITHDRAWAL;
        }
        if (dailyWithdrawn[user] >= MAX_DAILY_WITHDRAWAL) {
            return 0;
        }
        return MAX_DAILY_WITHDRAWAL - dailyWithdrawn[user];
    }
}
