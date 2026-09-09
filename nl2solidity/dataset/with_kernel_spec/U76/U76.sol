// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract GaslessTokenSwap {
    IERC20 public immutable stablecoin;
    address public operator;

    uint256 public totalStableReserve;
    uint256 public nativeReserve;
    uint256 public exchangeRate; // native tokens per 1 stablecoin unit

    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    mapping(address => uint256) public stableBalances;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    event Deposited(address indexed user, uint256 amount);
    event Swapped(address indexed user, uint256 stableAmount, uint256 nativeAmount, uint256 fee);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event NativeReserveReplenished(uint256 amount);
    event StablecoinsWithdrawn(address indexed to, uint256 amount);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    error OnlyOperator();
    error InsufficientBalance();
    error InsufficientNativeReserve();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error NoExcessStablecoins();
    error InvalidRate();
    error Reentrancy();

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrancy();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _stablecoin, address _operator) payable {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        exchangeRate = 100; // 100 native tokens per 1 stablecoin
        _status = _NOT_ENTERED;
        if (msg.value > 0) {
            nativeReserve += msg.value;
        }
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        stableBalances[msg.sender] += amount;
        totalStableReserve += amount;

        emit Deposited(msg.sender, amount);
    }

    function swap(uint256 stableAmount) external nonReentrant {
        if (stableAmount == 0) revert ZeroAmount();
        if (stableBalances[msg.sender] < stableAmount) revert InsufficientBalance();

        uint256 fee = (stableAmount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 netStable = stableAmount - fee;
        uint256 nativeAmount = netStable * exchangeRate;

        if (nativeReserve < nativeAmount) revert InsufficientNativeReserve();

        stableBalances[msg.sender] -= stableAmount;
        totalStableReserve -= stableAmount;
        nativeReserve -= nativeAmount;

        (bool sent, ) = payable(msg.sender).call{value: nativeAmount}("");
        if (!sent) revert TransferFailed();

        emit Swapped(msg.sender, stableAmount, nativeAmount, fee);
    }

    function withdrawStable(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stableBalances[msg.sender] < amount) revert InsufficientBalance();

        stableBalances[msg.sender] -= amount;
        totalStableReserve -= amount;

        bool success = stablecoin.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit StablecoinsWithdrawn(msg.sender, amount);
    }

    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    function replenishNativeReserve() external payable onlyOperator {
        if (msg.value == 0) revert ZeroAmount();
        nativeReserve += msg.value;
        emit NativeReserveReplenished(msg.value);
    }

    function withdrawExcessStable(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (contractBalance < totalStableReserve) revert NoExcessStablecoins();
        uint256 excess = contractBalance - totalStableReserve;
        if (amount > excess) revert NoExcessStablecoins();

        bool success = stablecoin.transfer(operator, amount);
        if (!success) revert TransferFailed();

        emit StablecoinsWithdrawn(operator, amount);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function getStableBalance(address user) external view returns (uint256) {
        return stableBalances[user];
    }

    function getExcessStable() external view returns (uint256) {
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (contractBalance < totalStableReserve) return 0;
        return contractBalance - totalStableReserve;
    }

    receive() external payable {
        nativeReserve += msg.value;
    }
}
