// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LiquidRestakingVault
/// @notice Accepts native SOL deposits, issues a yield-bearing liquid restaking token (LRT),
///         and routes redemptions through a 7-day unbonding queue.
contract LiquidRestakingVault {
    // ---------------------------------------------------------------------------
    // Token & metadata
    // ---------------------------------------------------------------------------
    string public constant name = "Liquid Restaking Token";
    string public constant symbol = "LRT";
    uint8 public constant decimals = 18;

    // ---------------------------------------------------------------------------
    // LRT (ERC20-like) state
    // ---------------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------------
    // Restaking accounting
    // ---------------------------------------------------------------------------
    /// @dev Exchange rate with 1e18 precision: lrtMinted = solAmount * 1e18 / exchangeRate
    uint256 public exchangeRate;
    /// @dev Cumulative SOL deposited per user (informational).
    mapping(address => uint256) public solDeposited;

    // ---------------------------------------------------------------------------
    // Operator, fees and unbonding
    // ---------------------------------------------------------------------------
    address public operator;
    uint256 public withdrawalFeeBps; // capped at MAX_WITHDRAWAL_FEE_BPS
    uint256 public constant MAX_WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant UNBONDING_PERIOD = 7 days;

    struct UnbondingEntry {
        uint256 solAmount;
        uint256 unlockTime;
    }
    mapping(address => UnbondingEntry[]) public unbondingQueue;

    // ---------------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------------
    uint256 private _locked = 1;

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------
    event Deposit(address indexed sender, address indexed recipient, uint256 solAmount, uint256 lrtAmount);
    event Withdrawal(address indexed sender, address indexed recipient, uint256 lrtAmount, uint256 solAmount, uint256 unlockTime);
    event Transfer(address indexed sender, address indexed recipient, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Claim(address indexed user, uint256 solAmount, uint256 fee);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event WithdrawalFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    error ZeroAmount();
    error ZeroAddress();
    error Unauthorized();
    error InsufficientBalance();
    error InsufficientAllowance();
    error FeeExceedsCap();
    error RateMustNotDecrease();
    error UnbondingNotElapsed();
    error NothingToClaim();
    error IndexOutOfRange();
    error TransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------
    constructor(address _operator, uint256 _initialExchangeRate) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialExchangeRate == 0) revert ZeroAmount();
        operator = _operator;
        exchangeRate = _initialExchangeRate;
        emit OperatorUpdated(address(0), _operator);
        emit ExchangeRateUpdated(0, _initialExchangeRate);
    }

    // ---------------------------------------------------------------------------
    // LRT ERC20-like interface
    // ---------------------------------------------------------------------------
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            _approve(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    // ---------------------------------------------------------------------------
    // Vault operations
    // ---------------------------------------------------------------------------

    /// @notice Deposit native SOL and receive LRT minted at the current exchange rate.
    function deposit() external payable nonReentrant returns (uint256 lrtMinted) {
        if (msg.value == 0) revert ZeroAmount();
        uint256 rate = exchangeRate;
        lrtMinted = (msg.value * 1e18) / rate;
        if (lrtMinted == 0) revert ZeroAmount();

        totalSupply += lrtMinted;
        balanceOf[msg.sender] += lrtMinted;
        solDeposited[msg.sender] += msg.value;

        emit Deposit(msg.sender, msg.sender, msg.value, lrtMinted);
        emit Transfer(address(0), msg.sender, lrtMinted);
    }

    /// @notice Redeem LRT for SOL. The SOL is queued for a 7-day unbonding period.
    function redeem(uint256 lrtAmount) external nonReentrant returns (uint256 solOut) {
        if (lrtAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lrtAmount) revert InsufficientBalance();

        solOut = (lrtAmount * exchangeRate) / 1e18;
        if (solOut == 0) revert ZeroAmount();

        // Burn LRT (checks-effects)
        balanceOf[msg.sender] -= lrtAmount;
        totalSupply -= lrtAmount;

        uint256 unlockTime = block.timestamp + UNBONDING_PERIOD;
        unbondingQueue[msg.sender].push(
            UnbondingEntry({solAmount: solOut, unlockTime: unlockTime})
        );

        emit Withdrawal(msg.sender, msg.sender, lrtAmount, solOut, unlockTime);
        emit Transfer(msg.sender, address(0), lrtAmount);
    }

    /// @notice Claim an unbonded redemption, paying out SOL minus the withdrawal fee.
    function claim(uint256 index) external nonReentrant returns (uint256 payout) {
        UnbondingEntry[] storage queue = unbondingQueue[msg.sender];
        if (index >= queue.length) revert IndexOutOfRange();
        UnbondingEntry storage entry = queue[index];
        if (entry.solAmount == 0) revert NothingToClaim();
        if (block.timestamp < entry.unlockTime) revert UnbondingNotElapsed();

        uint256 solAmount = entry.solAmount;
        uint256 fee = (solAmount * withdrawalFeeBps) / 10000;
        payout = solAmount - fee;

        // Remove the entry (swap-and-pop) before external calls.
        uint256 lastIdx = queue.length - 1;
        if (index != lastIdx) {
            queue[index] = queue[lastIdx];
        }
        queue.pop();

        (bool ok, ) = msg.sender.call{value: payout}("");
        if (!ok) revert TransferFailed();
        if (fee > 0) {
            (bool ok2, ) = operator.call{value: fee}("");
            if (!ok2) revert TransferFailed();
        }

        emit Claim(msg.sender, payout, fee);
    }

    // ---------------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------------
    function unbondingLength(address user) external view returns (uint256) {
        return unbondingQueue[user].length;
    }

    function unbondingEntry(address user, uint256 index)
        external
        view
        returns (uint256 solAmount, uint256 unlockTime)
    {
        if (index >= unbondingQueue[user].length) revert IndexOutOfRange();
        UnbondingEntry storage e = unbondingQueue[user][index];
        return (e.solAmount, e.unlockTime);
    }

    function claimableUnbonding(address user) external view returns (uint256 total) {
        UnbondingEntry[] storage queue = unbondingQueue[user];
        uint256 len = queue.length;
        for (uint256 i = 0; i < len; ) {
            if (block.timestamp >= queue[i].unlockTime) {
                total += queue[i].solAmount;
            }
            unchecked {
                ++i;
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------------

    /// @notice Update the restaking yield / exchange rate. Rate may only increase.
    function setExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert ZeroAmount();
        if (newRate < exchangeRate) revert RateMustNotDecrease();
        uint256 old = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(old, newRate);
    }

    /// @notice Set the withdrawal fee in basis points. Capped at 0.5% (50 bps).
    function setWithdrawalFee(uint256 feeBps) external onlyOperator {
        if (feeBps > MAX_WITHDRAWAL_FEE_BPS) revert FeeExceedsCap();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = feeBps;
        emit WithdrawalFeeUpdated(old, feeBps);
    }

    /// @notice Transfer the operator role to a new address.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /// @notice Accept native SOL transfers (e.g. yield from operator).
    receive() external payable {}
}
