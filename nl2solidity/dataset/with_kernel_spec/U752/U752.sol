// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @dev Minimal ERC20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 */
library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        bool success = token.approve(spender, amount);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }
}

/**
 * @title Context
 * @dev Provides information about the current execution context.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @title Ownable
 * @dev Contract module which provides a basic access control mechanism.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (_msgSender() != _owner) revert OwnableUnauthorizedAccount(_msgSender());
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

/**
 * @title ReentrancyGuard
 * @dev Contract module that helps prevent reentrant calls.
 */
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

/**
 * @title ERC20
 * @dev Implementation of the ERC20 standard.
 */
contract ERC20 is Context {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view virtual returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(address(0));
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert ERC20InsufficientBalance(from, fromBalance, amount);

        _balances[from] = fromBalance - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC20InvalidReceiver(address(0));

        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC20InvalidSender(address(0));

        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert ERC20InsufficientBalance(account, accountBalance, amount);

        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual {
        if (owner_ == address(0)) revert ERC20InvalidApprover(address(0));
        if (spender == address(0)) revert ERC20InvalidSpender(address(0));

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = _allowances[owner_][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            _approve(owner_, spender, currentAllowance - amount);
        }
    }
}

/**
 * @title LiquidStaking
 * @notice Users deposit a base ERC-20 token and receive a yield-bearing receipt
 *         token representing their share of the staked pool. The receipt token
 *         accrues value relative to the base token as rewards are reported into
 *         the pool by the staking strategy.
 */
contract LiquidStaking is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error ZeroAddress();
    error NotStrategy();
    error DepositsPaused();
    error AmountZero();
    error InsufficientShares();
    error FeeTooHigh();
    error SameStrategy();
    error InsufficientPoolBalance();
    error TransferFromFailed();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposited(address indexed user, uint256 baseAmount, uint256 sharesMinted);
    event Redeemed(address indexed user, uint256 sharesBurned, uint256 baseAmount, uint256 fee);
    event WithdrawalFeeUpdated(uint256 oldFee, uint256 newFee);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event DepositsPausedChanged(bool paused);
    event RewardsReported(uint256 baseReward, uint256 newTotalBase);

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @notice Basis points denominator (10000 = 100%).
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Default withdrawal fee: 0.1% = 10 bps.
    uint256 public constant DEFAULT_WITHDRAWAL_FEE_BPS = 10;

    /// @notice Maximum allowed withdrawal fee (5%).
    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 500;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    /// @notice The base token accepted for staking.
    IERC20 public immutable baseToken;

    /// @notice Total amount of base tokens currently held by the pool.
    uint256 public totalBaseAssets;

    /// @notice Current withdrawal fee in basis points.
    uint256 public withdrawalFeeBps;

    /// @notice Whether deposits are paused.
    bool public depositsPaused;

    /// @notice Address of the staking strategy that reports rewards.
    address public strategy;

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(
        address _baseToken,
        address _strategy,
        string memory _receiptName,
        string memory _receiptSymbol
    ) ERC20(_receiptName, _receiptSymbol) Ownable(msg.sender) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_strategy == address(0)) revert ZeroAddress();

        baseToken = IERC20(_baseToken);
        strategy = _strategy;
        withdrawalFeeBps = DEFAULT_WITHDRAWAL_FEE_BPS;

        emit StrategyUpdated(address(0), _strategy);
        emit WithdrawalFeeUpdated(0, withdrawalFeeBps);
    }

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyStrategy() {
        if (msg.sender != strategy) revert NotStrategy();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    /**
     * @dev Pull base tokens from the caller into the contract. The `from`
     *      parameter is always `msg.sender`, preventing arbitrary transfers
     *      from third-party accounts. The return value is checked to support
     *      non-standard ERC20 implementations.
     */
    function _pullFromCaller(uint256 baseAmount) internal {
        bool success = baseToken.transferFrom(msg.sender, address(this), baseAmount);
        if (!success) revert TransferFromFailed();
    }

    // ---------------------------------------------------------------------
    // External / Public functions
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit base tokens and mint receipt tokens to the caller.
     * @param baseAmount Amount of base tokens to deposit.
     * @return sharesMinted Amount of receipt tokens minted.
     */
    function deposit(uint256 baseAmount)
        external
        nonReentrant
        whenDepositsNotPaused
        returns (uint256 sharesMinted)
    {
        if (baseAmount == 0) revert AmountZero();

        sharesMinted = _convertBaseToShares(baseAmount);
        if (sharesMinted == 0) revert AmountZero();

        // Effects
        totalBaseAssets += baseAmount;
        _mint(msg.sender, sharesMinted);

        // Interactions — `from` is always msg.sender, no arbitrary sender.
        _pullFromCaller(baseAmount);

        emit Deposited(msg.sender, baseAmount, sharesMinted);
    }

    /**
     * @notice Redeem receipt tokens to withdraw base tokens to the caller.
     * @param shares Amount of receipt tokens to burn.
     * @return baseAmount Amount of base tokens transferred (gross).
     * @return fee Amount of base tokens taken as withdrawal fee.
     */
    function redeem(uint256 shares)
        external
        nonReentrant
        returns (uint256 baseAmount, uint256 fee)
    {
        if (shares == 0) revert AmountZero();
        if (balanceOf(msg.sender) < shares) revert InsufficientShares();

        baseAmount = _convertSharesToBase(shares);
        if (baseAmount == 0) revert AmountZero();

        fee = (baseAmount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 netOut = baseAmount - fee;

        if (totalBaseAssets < baseAmount) revert InsufficientPoolBalance();

        // Effects
        totalBaseAssets -= baseAmount;
        _burn(msg.sender, shares);

        // Interactions
        if (netOut > 0) {
            baseToken.safeTransfer(msg.sender, netOut);
        }
        if (fee > 0) {
            baseToken.safeTransfer(owner(), fee);
        }

        emit Redeemed(msg.sender, shares, baseAmount, fee);
    }

    /**
     * @notice Preview the number of receipt tokens that would be minted for a
     *         given base token deposit.
     */
    function previewDeposit(uint256 baseAmount) external view returns (uint256) {
        return _convertBaseToShares(baseAmount);
    }

    /**
     * @notice Preview the number of base tokens (gross, before fee) that would
     *         be returned for a given receipt token redemption.
     */
    function previewRedeem(uint256 shares) external view returns (uint256) {
        return _convertSharesToBase(shares);
    }

    /**
     * @notice Current conversion rate: base tokens per receipt token, scaled by 1e18.
     */
    function conversionRate() external view returns (uint256) {
        if (totalSupply() == 0 || totalBaseAssets == 0) {
            return 1e18;
        }
        return (totalBaseAssets * 1e18) / totalSupply();
    }

    // ---------------------------------------------------------------------
    // Strategy interface
    // ---------------------------------------------------------------------

    /**
     * @notice Called by the strategy to report rewards accrued to the pool.
     *         The difference between the reported new total and the current
     *         `totalBaseAssets` is treated as reward yield.
     * @param newTotalBase The new total base assets held by the pool.
     */
    function reportRewards(uint256 newTotalBase) external onlyStrategy {
        if (newTotalBase < totalBaseAssets) {
            // Loss scenario: reduce pool assets accordingly.
            totalBaseAssets = newTotalBase;
            emit RewardsReported(0, newTotalBase);
            return;
        }

        uint256 reward = newTotalBase - totalBaseAssets;
        totalBaseAssets = newTotalBase;
        emit RewardsReported(reward, newTotalBase);
    }

    // ---------------------------------------------------------------------
    // Owner functions
    // ---------------------------------------------------------------------

    /**
     * @notice Update the staking strategy address.
     * @param newStrategy Address of the new strategy.
     */
    function setStrategy(address newStrategy) external onlyOwner {
        if (newStrategy == address(0)) revert ZeroAddress();
        if (newStrategy == strategy) revert SameStrategy();
        address old = strategy;
        strategy = newStrategy;
        emit StrategyUpdated(old, newStrategy);
    }

    /**
     * @notice Set the withdrawal fee in basis points. Capped at MAX_WITHDRAWAL_FEE_BPS.
     * @param newFeeBps New fee in basis points.
     */
    function setWithdrawalFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_WITHDRAWAL_FEE_BPS) revert FeeTooHigh();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Pause or unpause deposits.
     * @param paused True to pause deposits, false to resume.
     */
    function setDepositsPaused(bool paused) external onlyOwner {
        if (depositsPaused == paused) return;
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    /**
     * @notice Recover ERC20 tokens accidentally sent to the contract, excluding
     *         the base token which is protected.
     * @param token Address of the token to recover.
     * @param to Recipient address.
     * @param amount Amount to recover.
     */
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (token == address(baseToken)) revert AmountZero();
        IERC20(token).safeTransfer(to, amount);
    }

    // ---------------------------------------------------------------------
    // Internal conversion helpers
    // ---------------------------------------------------------------------

    /**
     * @dev Convert a base token amount into receipt token shares using the
     *      current pool ratio. First deposit is 1:1.
     */
    function _convertBaseToShares(uint256 baseAmount) internal view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0 || totalBaseAssets == 0) {
            return baseAmount;
        }
        return (baseAmount * supply) / totalBaseAssets;
    }

    /**
     * @dev Convert receipt token shares into a base token amount using the
     *      current pool ratio.
     */
    function _convertSharesToBase(uint256 shares) internal view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return 0;
        }
        return (shares * totalBaseAssets) / supply;
    }
}
