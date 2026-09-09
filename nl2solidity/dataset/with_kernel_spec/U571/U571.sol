// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalValue() external view returns (uint256);
}

contract YieldVault {
    IERC20 public immutable stablecoin;
    IStrategy public strategy;
    address public operator;
    address public feeRecipient;

    uint256 public totalAssets;
    uint256 public totalShares;
    uint256 public sharePrice;

    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userDeposits;

    uint256 public constant MIN_DEPOSIT = 100 * 10**18;
    uint256 public constant WITHDRAW_FEE_BPS = 50;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant BPS_DENOM = 10000;

    uint256 private _status = 1;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event YieldClaim(address indexed user, uint256 amount);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event Rebalance(address indexed caller, uint256 newTotalAssets);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    error ZeroAddress();
    error ZeroAmount();
    error BelowMinimumDeposit();
    error InsufficientBalance();
    error NoShares();
    error NoYield();
    error NoSharesMinted();
    error NotOperator();
    error TransferFailed();
    error Reentrancy();
    error InvalidStrategy();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert Reentrancy();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address _stablecoin, address _strategy, address _feeRecipient) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_strategy == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        strategy = IStrategy(_strategy);
        feeRecipient = _feeRecipient;
        operator = msg.sender;
        sharePrice = PRECISION;
    }

    function _syncTotalAssets() internal {
        uint256 idle = stablecoin.balanceOf(address(this));
        uint256 invested = IStrategy(strategy).totalValue();
        totalAssets = idle + invested;
        sharePrice = totalShares > 0 ? (totalAssets * PRECISION) / totalShares : PRECISION;
    }

    function _ensureApproval(address spender, uint256 amount) internal {
        (bool ok, ) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!ok) revert TransferFailed();
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT) revert BelowMinimumDeposit();

        _syncTotalAssets();

        uint256 sharesToMint = (amount * PRECISION) / sharePrice;
        if (sharesToMint < 1) revert NoSharesMinted();

        userShares[msg.sender] += sharesToMint;
        userDeposits[msg.sender] += amount;
        totalShares += sharesToMint;
        totalAssets += amount;
        sharePrice = (totalAssets * PRECISION) / totalShares;

        _safeTransferFrom(address(stablecoin), msg.sender, address(this), amount);
        _ensureApproval(address(strategy), amount);
        IStrategy(strategy).deposit(amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > userDeposits[msg.sender]) revert InsufficientBalance();

        _syncTotalAssets();

        uint256 sharesToBurn = (amount * PRECISION) / sharePrice;
        if (sharesToBurn < 1) revert NoSharesMinted();
        if (sharesToBurn > userShares[msg.sender]) revert InsufficientBalance();

        uint256 fee = (amount * WITHDRAW_FEE_BPS) / BPS_DENOM;
        uint256 payout = amount - fee;

        userShares[msg.sender] -= sharesToBurn;
        userDeposits[msg.sender] -= amount;
        totalShares -= sharesToBurn;
        totalAssets -= amount;
        sharePrice = totalShares > 0 ? (totalAssets * PRECISION) / totalShares : PRECISION;

        uint256 idle = stablecoin.balanceOf(address(this));
        if (idle < amount) {
            IStrategy(strategy).withdraw(amount - idle);
        }
        _safeTransfer(address(stablecoin), msg.sender, payout);
        if (fee > 0) {
            _safeTransfer(address(stablecoin), feeRecipient, fee);
        }

        emit Withdrawal(msg.sender, amount);
    }

    function claimYield() external nonReentrant {
        uint256 shares = userShares[msg.sender];
        if (shares < 1) revert NoShares();

        _syncTotalAssets();

        uint256 currentValue = (shares * sharePrice) / PRECISION;
        uint256 principal = userDeposits[msg.sender];
        if (currentValue <= principal) revert NoYield();

        uint256 yieldAmount = currentValue - principal;
        uint256 sharesToBurn = (yieldAmount * PRECISION) / sharePrice;
        if (sharesToBurn > shares) sharesToBurn = shares;
        if (sharesToBurn < 1) revert NoYield();

        userShares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        totalAssets -= yieldAmount;
        sharePrice = totalShares > 0 ? (totalAssets * PRECISION) / totalShares : PRECISION;

        uint256 idle = stablecoin.balanceOf(address(this));
        if (idle < yieldAmount) {
            IStrategy(strategy).withdraw(yieldAmount - idle);
        }
        _safeTransfer(address(stablecoin), msg.sender, yieldAmount);

        emit YieldClaim(msg.sender, yieldAmount);
    }

    function rebalance() external onlyOperator {
        _syncTotalAssets();
        emit Rebalance(msg.sender, totalAssets);
    }

    function updateStrategy(address newStrategy) external onlyOperator nonReentrant {
        if (newStrategy == address(0)) revert ZeroAddress();
        if (newStrategy == address(strategy)) revert InvalidStrategy();

        address oldStrategy = address(strategy);

        // Update state before external calls (checks-effects-interactions)
        strategy = IStrategy(newStrategy);

        _ensureApproval(oldStrategy, 0);

        uint256 oldTotalValue = IStrategy(oldStrategy).totalValue();
        if (oldTotalValue > 0) {
            IStrategy(oldStrategy).withdraw(oldTotalValue);
        }

        uint256 idle = stablecoin.balanceOf(address(this));
        if (idle > 0) {
            _ensureApproval(newStrategy, idle);
            IStrategy(newStrategy).deposit(idle);
        }

        _syncTotalAssets();
        emit StrategyUpdated(oldStrategy, newStrategy);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function totalValueOfUser(address user) external view returns (uint256) {
        if (totalShares < 1) return 0;
        return (userShares[user] * sharePrice) / PRECISION;
    }

    function pendingYield(address user) external view returns (uint256) {
        if (totalShares < 1) return 0;
        uint256 currentValue = (userShares[user] * totalAssets) / totalShares;
        if (currentValue <= userDeposits[user]) return 0;
        return currentValue - userDeposits[user];
    }

    function currentTotalAssets() external view returns (uint256) {
        return stablecoin.balanceOf(address(this)) + IStrategy(strategy).totalValue();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
