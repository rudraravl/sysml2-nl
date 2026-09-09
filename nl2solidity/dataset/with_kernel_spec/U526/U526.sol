Looking at the error, the `deposit` function mints the fee to the owner, which inflates `totalSupply` and potentially the depositor's balance if they are the owner. The test expects only net currency to be minted after the 1% fee deduction. The fix is to not mint the fee portion — the fee remains as external tokens held by the contract (recoverable via `rescueTokens`).

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract GameCurrency is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error WithdrawalCapExceeded(uint256 requested, uint256 available);
    error UnauthorizedOperator();
    error InvalidConfig();
    error TransferToSelf();

    event Deposit(address indexed player, uint256 tokenAmount, uint256 currencyMinted, uint256 fee);
    event Withdraw(address indexed player, uint256 currencyAmount, uint256 tokenReturned);
    event CurrencyTransfer(address indexed from, address indexed to, uint256 amount);
    event CurrencyMint(address indexed operator, address indexed to, uint256 amount);
    event CurrencyBurn(address indexed operator, address indexed from, uint256 amount);
    event ConfigUpdated(
        address indexed operator,
        uint256 depositFeeBps,
        uint256 dailyWithdrawCap,
        uint256 exchangeRate,
        bool depositsEnabled,
        bool withdrawalsEnabled,
        bool transfersEnabled
    );
    event OperatorSet(address indexed account, bool authorized);

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant SECONDS_PER_DAY = 1 days;
    uint256 public constant MAX_FEE_BPS = 1_000;

    IERC20 public immutable paymentToken;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    struct GameConfig {
        uint256 depositFeeBps;
        uint256 dailyWithdrawCap;
        uint256 exchangeRate;
        bool depositsEnabled;
        bool withdrawalsEnabled;
        bool transfersEnabled;
    }

    GameConfig public config;

    struct WithdrawWindow {
        uint64 windowStart;
        uint192 withdrawnThisWindow;
    }

    mapping(address => WithdrawWindow) internal _withdrawWindows;

    mapping(address => bool) public isOperator;

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert UnauthorizedOperator();
        _;
    }

    constructor(address paymentToken_, address initialOperator) Ownable(msg.sender) {
        if (paymentToken_ == address(0)) revert ZeroAddress();
        if (initialOperator == address(0)) revert ZeroAddress();

        paymentToken = IERC20(paymentToken_);

        config = GameConfig({
            depositFeeBps: 100,
            dailyWithdrawCap: 10_000 * 1e18,
            exchangeRate: 1e18,
            depositsEnabled: true,
            withdrawalsEnabled: true,
            transfersEnabled: true
        });

        isOperator[initialOperator] = true;
        emit OperatorSet(initialOperator, true);
    }

    function deposit(uint256 tokenAmount) external nonReentrant {
        if (tokenAmount == 0) revert ZeroAmount();
        if (!config.depositsEnabled) revert InvalidConfig();

        GameConfig memory cfg = config;

        paymentToken.safeTransferFrom(msg.sender, address(this), tokenAmount);

        uint256 grossCurrency = (tokenAmount * cfg.exchangeRate) / 1e18;
        uint256 fee = (grossCurrency * cfg.depositFeeBps) / BPS_DENOMINATOR;
        if (fee > grossCurrency) fee = grossCurrency;
        uint256 netCurrency = grossCurrency - fee;

        _mint(msg.sender, netCurrency);

        emit Deposit(msg.sender, tokenAmount, netCurrency, fee);
    }

    function withdraw(uint256 currencyAmount) external nonReentrant {
        if (currencyAmount == 0) revert ZeroAmount();
        if (!config.withdrawalsEnabled) revert InvalidConfig();
        if (balanceOf[msg.sender] < currencyAmount) revert InsufficientBalance();

        GameConfig memory cfg = config;

        uint256 available = _availableWithdrawAllowance(msg.sender, cfg.dailyWithdrawCap);
        if (currencyAmount > available) {
            revert WithdrawalCapExceeded(currencyAmount, available);
        }

        _consumeWithdrawAllowance(msg.sender, currencyAmount);

        _burn(msg.sender, currencyAmount);

        uint256 tokenReturn = (currencyAmount * 1e18) / cfg.exchangeRate;
        if (tokenReturn > 0) {
            paymentToken.safeTransfer(msg.sender, tokenReturn);
        }

        emit Withdraw(msg.sender, currencyAmount, tokenReturn);
    }

    function transfer(address to, uint256 amount) external nonReentrant {
        if (!config.transfersEnabled) revert InvalidConfig();
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert TransferToSelf();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        _transfer(msg.sender, to, amount);

        emit CurrencyTransfer(msg.sender, to, amount);
    }

    function mintTo(address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _mint(to, amount);
        emit CurrencyMint(msg.sender, to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyOperator {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        _burn(from, amount);
        emit CurrencyBurn(msg.sender, from, amount);
    }

    function updateConfig(
        uint256 depositFeeBps_,
        uint256 dailyWithdrawCap_,
        uint256 exchangeRate_,
        bool depositsEnabled_,
        bool withdrawalsEnabled_,
        bool transfersEnabled_
    ) external onlyOperator {
        if (depositFeeBps_ > MAX_FEE_BPS) revert InvalidConfig();
        if (dailyWithdrawCap_ == 0 || dailyWithdrawCap_ > type(uint192).max) revert InvalidConfig();
        if (exchangeRate_ == 0) revert InvalidConfig();

        config = GameConfig({
            depositFeeBps: depositFeeBps_,
            dailyWithdrawCap: dailyWithdrawCap_,
            exchangeRate: exchangeRate_,
            depositsEnabled: depositsEnabled_,
            withdrawalsEnabled: withdrawalsEnabled_,
            transfersEnabled: transfersEnabled_
        });

        emit ConfigUpdated(
            msg.sender,
            depositFeeBps_,
            dailyWithdrawCap_,
            exchangeRate_,
            depositsEnabled_,
            withdrawalsEnabled_,
            transfersEnabled_
        );
    }

    function setOperator(address account, bool authorized) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        isOperator[account] = authorized;
        emit OperatorSet(account, authorized);
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(owner(), amount);
    }

    function availableWithdrawAllowance(address player) external view returns (uint256) {
        return _availableWithdrawAllowance(player, config.dailyWithdrawCap);
    }

    function getWithdrawWindow(address player)
        external
        view
        returns (uint256 windowStart, uint256 withdrawn)
    {
        WithdrawWindow memory w = _withdrawWindows[player];
        uint256 currentStart = _currentWindowStart(w.windowStart);
        if (currentStart != w.windowStart) {
            return (currentStart, 0);
        }
        return (w.windowStart, w.withdrawnThisWindow);
    }

    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }

    function _currentWindowStart(uint256 storedStart) internal view returns (uint256) {
        if (storedStart == 0) {
            return (block.timestamp / SECONDS_PER_DAY) * SECONDS_PER_DAY;
        }
        if (block.timestamp < storedStart + SECONDS_PER_DAY) {
            return storedStart;
        }
        return (block.timestamp / SECONDS_PER_DAY) * SECONDS_PER_DAY;
    }

    function _availableWithdrawAllowance(address player, uint256 dailyCap)
        internal
        view
        returns (uint256)
    {
        WithdrawWindow memory w = _withdrawWindows[player];
        uint256 currentStart = _currentWindowStart(w.windowStart);
        if (currentStart != w.windowStart) {
            return dailyCap;
        }
        if (w.withdrawnThisWindow >= dailyCap) {
            return 0;
        }
        return dailyCap - w.withdrawnThisWindow;
    }

    function _consumeWithdrawAllowance(address player, uint256 amount) internal {
        WithdrawWindow storage w = _withdrawWindows[player];
        uint256 currentStart = _currentWindowStart(w.windowStart);
        if (currentStart != w.windowStart) {
            w.windowStart = uint64(currentStart);
            w.withdrawnThisWindow = 0;
        }
        w.withdrawnThisWindow += uint192(amount);
    }
}
