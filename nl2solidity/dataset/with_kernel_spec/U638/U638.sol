// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert("Ownable: zero address");
        }
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert("Ownable: new owner is the zero address");
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

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

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

contract SyntheticAsset is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /* ========== Constants ========== */

    uint256 public constant RATE_PRECISION = 1e18;
    uint256 public constant WITHDRAW_FEE_BPS = 50;       // 0.5%
    uint256 public constant MAX_FLUCTUATION_BPS = 500;   // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_DAY = 1 days;

    /* ========== State Variables ========== */

    IERC20 public immutable stablecoin;

    address public operator;

    /// @notice Exchange rate: stablecoin units per 1 synthetic token (scaled by RATE_PRECISION).
    uint256 public exchangeRate;

    /// @notice The reference rate at the start of the current 24-hour window.
    uint256 public dailyBaseRate;

    /// @notice Day index (block.timestamp / 1 days) of the last exchange rate update.
    uint256 public lastRateUpdateDay;

    /// @notice Total stablecoin staked in the contract.
    uint256 public totalStaked;

    bool public stakingPaused;
    bool public redemptionPaused;

    /// @notice Amount of stablecoin each user has staked (available to mint against or withdraw).
    mapping(address => uint256) public stakedBalance;

    /// @notice Amount of synthetic asset each user has minted.
    mapping(address => uint256) public mintedBalance;

    /* ========== Events ========== */

    event Staked(address indexed user, uint256 stablecoinAmount);
    event Minted(address indexed user, uint256 stablecoinAmount, uint256 syntheticAmount);
    event Redeemed(address indexed user, uint256 syntheticAmount, uint256 stablecoinAmount);
    event Withdrawn(address indexed user, uint256 amountRequested, uint256 fee, uint256 amountReceived);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 dailyBaseRate);
    event StakingPausedChanged(bool paused);
    event RedemptionPausedChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    /* ========== Errors ========== */

    error ZeroAddress();
    error StakingPaused();
    error RedemptionPaused();
    error InsufficientStakedBalance();
    error InsufficientSyntheticBalance();
    error InsufficientContractLiquidity();
    error RateFluctuationExceeded(uint256 proposed, uint256 minAllowed, uint256 maxAllowed);
    error NotOperator();
    error ZeroAmount();
    error InvalidRate();

    /* ========== Modifiers ========== */

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenStakingNotPaused() {
        if (stakingPaused) revert StakingPaused();
        _;
    }

    modifier whenRedemptionNotPaused() {
        if (redemptionPaused) revert RedemptionPaused();
        _;
    }

    /* ========== Constructor ========== */

    constructor(
        address _stablecoin,
        address _operator,
        uint256 _initialExchangeRate,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_initialExchangeRate == 0) revert InvalidRate();

        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        exchangeRate = _initialExchangeRate;
        dailyBaseRate = _initialExchangeRate;
        lastRateUpdateDay = block.timestamp / SECONDS_PER_DAY;
    }

    /* ========== External Functions ========== */

    /// @notice Stake stablecoin into the contract to back future synthetic minting.
    /// @param amount The amount of stablecoin to stake.
    function stake(uint256 amount) external whenStakingNotPaused {
        if (amount == 0) revert ZeroAmount();

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /// @notice Mint synthetic assets by consuming staked stablecoin at the current exchange rate.
    /// @param stablecoinAmount The amount of staked stablecoin to convert into synthetic assets.
    function mint(uint256 stablecoinAmount) external whenStakingNotPaused {
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < stablecoinAmount) revert InsufficientStakedBalance();

        uint256 syntheticAmount = (stablecoinAmount * RATE_PRECISION) / exchangeRate;
        if (syntheticAmount == 0) revert ZeroAmount();

        stakedBalance[msg.sender] -= stablecoinAmount;
        mintedBalance[msg.sender] += syntheticAmount;

        _mint(msg.sender, syntheticAmount);

        emit Minted(msg.sender, stablecoinAmount, syntheticAmount);
    }

    /// @notice Redeem synthetic assets to recover staked stablecoin at the current exchange rate.
    /// @param syntheticAmount The amount of synthetic assets to redeem.
    function redeem(uint256 syntheticAmount) external whenRedemptionNotPaused {
        if (syntheticAmount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < syntheticAmount) revert InsufficientSyntheticBalance();
        if (mintedBalance[msg.sender] < syntheticAmount) revert InsufficientSyntheticBalance();

        uint256 stablecoinAmount = (syntheticAmount * exchangeRate) / RATE_PRECISION;
        if (stablecoinAmount == 0) revert ZeroAmount();
        if (stablecoin.balanceOf(address(this)) < stablecoinAmount) revert InsufficientContractLiquidity();

        mintedBalance[msg.sender] -= syntheticAmount;
        stakedBalance[msg.sender] += stablecoinAmount;

        _burn(msg.sender, syntheticAmount);

        emit Redeemed(msg.sender, syntheticAmount, stablecoinAmount);
    }

    /// @notice Withdraw staked stablecoin. A 0.5% fee is deducted and retained by the contract.
    /// @param amount The amount of stablecoin to withdraw (before fee).
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStakedBalance();
        if (stablecoin.balanceOf(address(this)) < amount) revert InsufficientContractLiquidity();

        uint256 fee = (amount * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountReceived = amount - fee;

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        stablecoin.safeTransfer(msg.sender, amountReceived);

        emit Withdrawn(msg.sender, amount, fee, amountReceived);
    }

    /* ========== Operator Functions ========== */

    /// @notice Update the exchange rate. The new rate must not deviate more than 5%
    ///         from the daily base rate. If a new 24-hour window has begun, the
    ///         daily base rate is reset to the current rate before applying the change.
    /// @param newRate The proposed new exchange rate.
    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidRate();

        uint256 currentDay = block.timestamp / SECONDS_PER_DAY;
        if (currentDay != lastRateUpdateDay) {
            dailyBaseRate = exchangeRate;
            lastRateUpdateDay = currentDay;
        }

        uint256 minAllowed = dailyBaseRate - (dailyBaseRate * MAX_FLUCTUATION_BPS) / BPS_DENOMINATOR;
        uint256 maxAllowed = dailyBaseRate + (dailyBaseRate * MAX_FLUCTUATION_BPS) / BPS_DENOMINATOR;

        if (newRate < minAllowed || newRate > maxAllowed) {
            revert RateFluctuationExceeded(newRate, minAllowed, maxAllowed);
        }

        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;

        emit ExchangeRateUpdated(oldRate, newRate, dailyBaseRate);
    }

    /// @notice Pause or unpause staking and minting operations.
    /// @param paused Whether staking should be paused.
    function setStakingPaused(bool paused) external onlyOperator {
        stakingPaused = paused;
        emit StakingPausedChanged(paused);
    }

    /// @notice Pause or unpause redemption operations.
    /// @param paused Whether redemption should be paused.
    function setRedemptionPaused(bool paused) external onlyOperator {
        redemptionPaused = paused;
        emit RedemptionPausedChanged(paused);
    }

    /// @notice Set a new operator address.
    /// @param newOperator The address of the new operator.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    /* ========== View Functions ========== */

    /// @notice Returns the maximum amount of synthetic assets a user can mint
    ///         given their current staked stablecoin balance and the exchange rate.
    function maxMintable(address user) external view returns (uint256) {
        return (stakedBalance[user] * RATE_PRECISION) / exchangeRate;
    }

    /// @notice Returns the amount of stablecoin a user would receive for redeeming
    ///         a given amount of synthetic assets at the current exchange rate.
    function stablecoinForSynthetic(uint256 syntheticAmount) external view returns (uint256) {
        return (syntheticAmount * exchangeRate) / RATE_PRECISION;
    }

    /// @notice Returns the amount of synthetic assets that would be minted for
    ///         a given amount of stablecoin at the current exchange rate.
    function syntheticForStablecoin(uint256 stablecoinAmount) external view returns (uint256) {
        return (stablecoinAmount * RATE_PRECISION) / exchangeRate;
    }

    /// @notice Returns the withdrawable stablecoin for a user after the 0.5% fee.
    function withdrawableAfterFee(address user) external view returns (uint256) {
        uint256 bal = stakedBalance[user];
        uint256 fee = (bal * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        return bal - fee;
    }

    /// @notice Returns the allowed exchange rate bounds for the current day.
    function currentRateBounds() external view returns (uint256 minAllowed, uint256 maxAllowed) {
        minAllowed = dailyBaseRate - (dailyBaseRate * MAX_FLUCTUATION_BPS) / BPS_DENOMINATOR;
        maxAllowed = dailyBaseRate + (dailyBaseRate * MAX_FLUCTUATION_BPS) / BPS_DENOMINATOR;
    }
}
