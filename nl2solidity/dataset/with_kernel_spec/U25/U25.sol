// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LiquidStaking
/// @notice Non-rebasing liquid staking receipt token. Each receipt token represents
/// a share of the contract's Ether holdings (deposits + accrued staking rewards).
/// The conversion rate between receipt tokens and Ether only increases over time
/// as the operator adds staking rewards and as redemption fees accrue to remaining
/// holders. Redemptions are subject to a 0.1% fee and require the operator to have
/// refreshed the stored conversion rate within the last 24 hours.
contract LiquidStaking {
    // ---------------------------------------------------------------------
    //                            Errors
    // ---------------------------------------------------------------------
    error LiquidStaking__NotOperator();
    error LiquidStaking__Paused();
    error LiquidStaking__ZeroAmount();
    error LiquidStaking__ZeroAddress();
    error LiquidStaking__InsufficientBalance();
    error LiquidStaking__InsufficientAllowance();
    error LiquidStaking__RateStale();
    error LiquidStaking__TransferFailed();

    // ---------------------------------------------------------------------
    //                            Events
    // ---------------------------------------------------------------------
    event EtherDeposited(address indexed user, uint256 etherAmount, uint256 receiptAmount);
    event ReceiptTokensRedeemed(
        address indexed user,
        uint256 receiptAmount,
        uint256 etherSent,
        uint256 fee
    );
    event StakingRewardsAdded(address indexed operator, uint256 amount, uint256 newConversionRate);
    event ConversionRateUpdated(uint256 newRate, uint256 timestamp);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ---------------------------------------------------------------------
    //                            Constants
    // ---------------------------------------------------------------------
    uint256 public constant PRECISION = 1e18;
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_RATE_UPDATE_INTERVAL = 24 hours;
    uint8 private constant _DECIMALS = 18;

    // ---------------------------------------------------------------------
    //                            Storage
    // ---------------------------------------------------------------------
    string private _name;
    string private _symbol;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalEtherHeld; // total Ether backing all receipt tokens
    uint256 public conversionRate; // Ether per receipt token, scaled by PRECISION
    uint256 public lastRateUpdate; // timestamp of last conversion rate refresh

    address public operator;
    bool public paused;

    // ---------------------------------------------------------------------
    //                            Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert LiquidStaking__NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert LiquidStaking__Paused();
        _;
    }

    // ---------------------------------------------------------------------
    //                            Constructor
    // ---------------------------------------------------------------------
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        operator = msg.sender;
        conversionRate = PRECISION; // 1:1 initially
        lastRateUpdate = block.timestamp;
    }

    // ---------------------------------------------------------------------
    //                      User: Deposit / Redeem
    // ---------------------------------------------------------------------

    /// @notice Deposit Ether and receive receipt tokens at the current conversion rate.
    /// @dev Mints receipt tokens such that the per-token Ether ratio is preserved.
    function deposit() external payable whenNotPaused {
        if (msg.value == 0) revert LiquidStaking__ZeroAmount();

        uint256 supply = _totalSupply;
        uint256 receiptAmount;
        if (supply == 0) {
            // First depositor: 1 receipt token per wei.
            receiptAmount = msg.value;
        } else {
            // Subsequent depositors: keep the existing Ether-per-token ratio.
            receiptAmount = (msg.value * supply) / _totalEtherHeld;
        }

        _totalEtherHeld += msg.value;
        _mint(msg.sender, receiptAmount);

        emit EtherDeposited(msg.sender, msg.value, receiptAmount);
    }

    /// @notice Redeem receipt tokens for Ether. A 0.1% fee is retained in the
    /// contract, increasing the conversion rate for remaining holders.
    /// @param receiptAmount Amount of receipt tokens to redeem.
    function redeem(uint256 receiptAmount) external whenNotPaused {
        if (receiptAmount == 0) revert LiquidStaking__ZeroAmount();
        if (_balances[msg.sender] < receiptAmount) revert LiquidStaking__InsufficientBalance();
        if (block.timestamp - lastRateUpdate > MAX_RATE_UPDATE_INTERVAL) {
            revert LiquidStaking__RateStale();
        }

        // Compute the gross Ether value of the redeemed tokens.
        uint256 etherValue = (receiptAmount * conversionRate) / PRECISION;
        // Compute the fee directly from the full-precision product to avoid
        // multiplying the truncated result of a division (divide-before-multiply).
        uint256 fee = (receiptAmount * conversionRate * REDEMPTION_FEE_BPS) /
            (PRECISION * BPS_DENOMINATOR);
        uint256 etherToSend = etherValue - fee;

        // Effects: burn tokens, reduce Ether backing by what is sent out.
        // The fee remains in the contract, raising the rate for remaining holders.
        _burn(msg.sender, receiptAmount);
        _totalEtherHeld -= etherToSend;

        // Interactions: send Ether to the redeemer.
        (bool success, ) = payable(msg.sender).call{value: etherToSend}("");
        if (!success) revert LiquidStaking__TransferFailed();

        emit ReceiptTokensRedeemed(msg.sender, receiptAmount, etherToSend, fee);
    }

    // ---------------------------------------------------------------------
    //                      Operator: Rewards / Rate
    // ---------------------------------------------------------------------

    /// @notice Operator deposits accrued staking rewards, raising the conversion
    /// rate for all existing holders. The stored conversion rate is refreshed.
    function addStakingRewards() external payable onlyOperator {
        if (msg.value == 0) revert LiquidStaking__ZeroAmount();
        _totalEtherHeld += msg.value;
        _refreshConversionRate();
        emit StakingRewardsAdded(msg.sender, msg.value, conversionRate);
    }

    /// @notice Operator refreshes the stored conversion rate. Must be called at
    /// least once every 24 hours for redemptions to remain available.
    function updateConversionRate() external onlyOperator {
        _refreshConversionRate();
    }

    function _refreshConversionRate() internal {
        if (_totalSupply > 0) {
            conversionRate = (_totalEtherHeld * PRECISION) / _totalSupply;
        }
        lastRateUpdate = block.timestamp;
        emit ConversionRateUpdated(conversionRate, lastRateUpdate);
    }

    // ---------------------------------------------------------------------
    //                      Operator: Pause / Unpause
    // ---------------------------------------------------------------------

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert LiquidStaking__ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    // ---------------------------------------------------------------------
    //                            ERC20 Views
    // ---------------------------------------------------------------------

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalEtherHeld() external view returns (uint256) {
        return _totalEtherHeld;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    /// @notice Live conversion rate based on current Ether holdings and supply.
    function currentConversionRate() external view returns (uint256) {
        if (_totalSupply == 0) return PRECISION;
        return (_totalEtherHeld * PRECISION) / _totalSupply;
    }

    // ---------------------------------------------------------------------
    //                          ERC20 Operations
    // ---------------------------------------------------------------------

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 current = _allowances[from][msg.sender];
        if (current < amount) revert LiquidStaking__InsufficientAllowance();
        if (current != type(uint256).max) {
            _approve(from, msg.sender, current - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    // ---------------------------------------------------------------------
    //                            Internals
    // ---------------------------------------------------------------------

    function _mint(address to, uint256 amount) internal {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        _balances[from] -= amount;
        _totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert LiquidStaking__ZeroAddress();
        if (_balances[from] < amount) revert LiquidStaking__InsufficientBalance();
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert LiquidStaking__ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    // ---------------------------------------------------------------------
    //                            Receive
    // ---------------------------------------------------------------------

    /// @dev Reject direct Ether transfers; use deposit() or addStakingRewards().
    receive() external payable {
        revert("LiquidStaking: use deposit() or addStakingRewards()");
    }
}
