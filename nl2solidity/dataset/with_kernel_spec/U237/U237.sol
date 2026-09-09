// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    /// @dev Pulls `amount` of `token` from the caller (msg.sender) into this contract.
    ///      `from` is fixed to msg.sender to prevent arbitrary-send-erc20 vulnerabilities:
    ///      the contract can only move stablecoins that the caller has explicitly approved
    ///      and owns, never tokens belonging to an arbitrary third party.
    function safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFromFailed();
        }
    }
}

/**
 * @title MoneyMarketFund
 * @notice Tokenized money market fund representing shares in a pool of short-term,
 *         high-quality USD instruments. Users deposit stablecoins to mint fund shares,
 *         redeem shares to withdraw stablecoins (subject to a 0.1% fee), and transfer
 *         shares freely. An operator adjusts the exchange rate (NAV per share) and the
 *         owner may pause deposits and redemptions.
 */
contract MoneyMarketFund is IERC20 {
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------
    //                            Errors
    // ------------------------------------------------------------------
    error Unauthorized();
    error Paused();
    error ZeroAddress();
    error DepositBelowMinimum();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InvalidRate();
    error ZeroShares();
    error ZeroAssets();
    error Reentrancy();
    error InsufficientRescueBalance();

    // ------------------------------------------------------------------
    //                            Events
    // ------------------------------------------------------------------
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Redeem(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        uint256 fee
    );
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint40 timestamp);
    event PausedState(bool paused);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeeReceiverUpdated(address indexed previousReceiver, address indexed newReceiver);

    // ------------------------------------------------------------------
    //                       Constants & Storage
    // ------------------------------------------------------------------
    string private constant _NAME = "Money Market Fund USD";
    string private constant _SYMBOL = "MMF";
    uint8 private constant _DECIMALS = 18;

    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant RATE_DENOMINATOR = 1e18;

    IERC20 public immutable stablecoin;
    uint8 public immutable stablecoinDecimals;
    uint256 public immutable minDeposit; // 100 stablecoins in smallest unit

    address public owner;
    address public operator;
    address public feeReceiver;
    bool public paused;

    uint256 public exchangeRate; // stablecoin units (stablecoinDecimals) per 1 share (1e18)
    uint40 public lastRateUpdate;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    bool private _locked;

    // ------------------------------------------------------------------
    //                          Constructor
    // ------------------------------------------------------------------
    constructor(IERC20 stablecoin_, address operator_, address feeReceiver_, uint256 initialRate_) {
        if (address(stablecoin_) == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        if (initialRate_ == 0) revert InvalidRate();

        stablecoin = stablecoin_;
        stablecoinDecimals = stablecoin_.decimals();
        minDeposit = 100 * 10 ** stablecoinDecimals;

        operator = operator_;
        owner = msg.sender;
        feeReceiver = feeReceiver_;
        exchangeRate = initialRate_;
        lastRateUpdate = uint40(block.timestamp);

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), operator_);
        emit FeeReceiverUpdated(address(0), feeReceiver_);
        emit ExchangeRateUpdated(0, initialRate_, lastRateUpdate);
    }

    // ------------------------------------------------------------------
    //                       ERC20 Metadata
    // ------------------------------------------------------------------
    function name() external pure returns (string memory) {
        return _NAME;
    }

    function symbol() external pure returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external pure returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    // ------------------------------------------------------------------
    //                       Access Modifiers
    // ------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    // ------------------------------------------------------------------
    //                       Admin Functions
    // ------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setFeeReceiver(address newReceiver) external onlyOwner {
        emit FeeReceiverUpdated(feeReceiver, newReceiver);
        feeReceiver = newReceiver;
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
        emit PausedState(state);
    }

    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidRate();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        lastRateUpdate = uint40(block.timestamp);
        emit ExchangeRateUpdated(oldRate, newRate, lastRateUpdate);
    }

    // ------------------------------------------------------------------
    //                       Conversion Helpers
    // ------------------------------------------------------------------
    /// @notice Converts stablecoin units to share units (1e18).
    function convertToShares(uint256 assets) public view returns (uint256) {
        if (assets == 0) return 0;
        return (assets * RATE_DENOMINATOR) / exchangeRate;
    }

    /// @notice Converts share units (1e18) to stablecoin units (gross, before fee).
    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (shares == 0) return 0;
        return (shares * exchangeRate) / RATE_DENOMINATOR;
    }

    /// @notice Preview the net assets and fee for redeeming a given number of shares.
    function previewRedeem(uint256 shares) public view returns (uint256 assetsAfterFee, uint256 fee) {
        uint256 gross = convertToAssets(shares);
        fee = (gross * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        assetsAfterFee = gross - fee;
    }

    // ------------------------------------------------------------------
    //                       Deposit / Redeem
    // ------------------------------------------------------------------
    function deposit(uint256 assets, address receiver) external whenNotPaused nonReentrant returns (uint256 shares) {
        if (assets < minDeposit) revert DepositBelowMinimum();
        if (receiver == address(0)) revert ZeroAddress();

        shares = convertToShares(assets);
        if (shares == 0) revert ZeroShares();

        // effects
        _totalSupply += shares;
        _balances[receiver] += shares;

        // interactions: pull stablecoins only from the caller (msg.sender)
        stablecoin.safeTransferFrom(address(this), assets);

        emit Transfer(address(0), receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner_)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        if (shares == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        if (_balances[owner_] < shares) revert InsufficientBalance();

        address spender = msg.sender;
        if (owner_ != spender) {
            uint256 allowed = _allowances[owner_][spender];
            if (allowed != type(uint256).max) {
                if (allowed < shares) revert InsufficientAllowance();
                _allowances[owner_][spender] = allowed - shares;
            }
        }

        (uint256 assetsAfterFee, uint256 fee) = previewRedeem(shares);
        if (assetsAfterFee == 0) revert ZeroAssets();

        // effects
        _balances[owner_] -= shares;
        _totalSupply -= shares;

        // interactions
        stablecoin.safeTransfer(receiver, assetsAfterFee);
        if (fee > 0 && feeReceiver != address(0)) {
            stablecoin.safeTransfer(feeReceiver, fee);
        }

        emit Transfer(owner_, address(0), shares);
        emit Redeem(spender, receiver, owner_, assetsAfterFee, shares, fee);
    }

    // ------------------------------------------------------------------
    //                       ERC20 Transfers
    // ------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        address spender = msg.sender;
        uint256 allowed = _allowances[from][spender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            _allowances[from][spender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 current = _allowances[msg.sender][spender];
        if (current < subtractedValue) revert InsufficientAllowance();
        _approve(msg.sender, spender, current - subtractedValue);
        return true;
    }

    // ------------------------------------------------------------------
    //                       Internal Helpers
    // ------------------------------------------------------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (_balances[from] < amount) revert InsufficientBalance();

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    // ------------------------------------------------------------------
    //                       Rescue (owner only)
    // ------------------------------------------------------------------
    /// @notice Rescues tokens accidentally sent to the contract. The stablecoins
    ///         backing outstanding shares cannot be rescued.
    function rescue(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (token == address(stablecoin)) {
            uint256 backing = convertToAssets(_totalSupply);
            if (balance < backing || amount > balance - backing) revert InsufficientRescueBalance();
        } else {
            if (amount > balance) revert InsufficientRescueBalance();
        }
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }
}
