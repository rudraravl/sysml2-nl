// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidStakingPool {
    // ========== ERC20 Metadata ==========
    string public constant name = "Liquid Staked Native";
    string public constant symbol = "lsNATIVE";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ========== Roles ==========
    address public owner;
    address public operator;
    address public treasury;

    // ========== Staking State ==========
    /// @notice Exchange rate denominated in native per 1 LST, scaled by 1e18.
    uint256 public exchangeRate;
    /// @notice Cumulative amount of native tokens deposited by users.
    uint256 public totalNativeDeposited;
    /// @notice Total native tokens currently held by the pool.
    uint256 public totalNativeInPool;

    // ========== Reward Distribution (dividend style) ==========
    /// @notice Accumulated reward per LST share, scaled by 1e18.
    uint256 public accRewardPerShare;
    /// @dev Snapshot of each user's balance * accRewardPerShare at last update.
    mapping(address => uint256) public rewardDebt;
    /// @dev User's currently unclaimed reward amount.
    mapping(address => uint256) public pendingReward;

    // ========== Validator Rebalancing ==========
    address[] public validators;
    mapping(address => uint256) public validatorAllocation;

    // ========== Constants ==========
    uint256 public constant FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DEPOSIT = 1e17; // 0.1 native
    uint256 public constant PRECISION = 1e18;

    // ========== Reentrancy ==========
    uint256 private _locked = 1;

    // ========== Events ==========
    event Deposit(address indexed user, uint256 nativeAmount, uint256 lstAmount);
    event Withdraw(address indexed user, uint256 lstAmount, uint256 nativeReturned, uint256 fee);
    event RewardDistributed(uint256 amount, uint256 newAccRewardPerShare);
    event RewardClaimed(address indexed user, uint256 amount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event ValidatorsRebalanced(uint256 validatorCount, uint256 totalAllocated);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ========== Errors ==========
    error NotOwner();
    error NotOperator();
    error NotAuthorized();
    error ReentrantCall();
    error DepositTooSmall();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InvalidExchangeRate();
    error InvalidValidators();
    error InvalidAddress();
    error TransferFailed();
    error NoPendingRewards();
    error ArraysLengthMismatch();

    // ========== Modifiers ==========
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ========== Constructor ==========
    constructor(address _operator, address _treasury) {
        if (_operator == address(0) || _treasury == address(0)) revert InvalidAddress();
        owner = msg.sender;
        operator = _operator;
        treasury = _treasury;
        exchangeRate = PRECISION; // 1:1 initially
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit TreasuryChanged(address(0), _treasury);
        emit ExchangeRateUpdated(0, PRECISION);
    }

    // ========== Receive ==========
    /// @notice Allows operator or owner to top up the pool with native to back exchange rate appreciation.
    receive() external payable {
        if (msg.sender != operator && msg.sender != owner) revert NotAuthorized();
        totalNativeInPool += msg.value;
    }

    // ========== ERC20 Functions ==========
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert InvalidAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert InvalidAddress();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        _updateReward(from);
        _updateReward(to);
        balanceOf[from] = fromBal - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidAddress();
        _updateReward(to);
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        _updateReward(from);
        balanceOf[from] = fromBal - amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ========== Reward Accounting ==========
    function _updateReward(address user) internal {
        uint256 bal = balanceOf[user];
        if (bal > 0) {
            uint256 entitled = (bal * accRewardPerShare) / PRECISION;
            if (entitled > rewardDebt[user]) {
                pendingReward[user] += entitled - rewardDebt[user];
            }
        }
        rewardDebt[user] = (bal * accRewardPerShare) / PRECISION;
    }

    function getPendingReward(address user) external view returns (uint256) {
        uint256 bal = balanceOf[user];
        uint256 entitled = (bal * accRewardPerShare) / PRECISION;
        uint256 unclaimed = entitled > rewardDebt[user] ? entitled - rewardDebt[user] : 0;
        return pendingReward[user] + unclaimed;
    }

    // ========== Staking Functions ==========
    /// @notice Deposit native tokens to mint liquid staking tokens.
    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall();
        if (exchangeRate == 0) revert InvalidExchangeRate();
        uint256 shares = (msg.value * PRECISION) / exchangeRate;
        if (shares == 0) revert ZeroAmount();
        totalNativeDeposited += msg.value;
        totalNativeInPool += msg.value;
        _mint(msg.sender, shares);
        emit Deposit(msg.sender, msg.value, shares);
    }

    /// @notice Burn liquid staking tokens to withdraw native tokens. A 0.5% fee is deducted.
    function withdraw(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();

        // Compute fee from the full-precision product to avoid divide-before-multiply rounding.
        uint256 nativeValueExact = lstAmount * exchangeRate;
        uint256 fee = (nativeValueExact * FEE_BPS) / (PRECISION * BPS_DENOMINATOR);
        uint256 nativeValue = nativeValueExact / PRECISION;
        if (nativeValue == 0) revert ZeroAmount();
        uint256 toReturn = nativeValue - fee;

        if (totalNativeInPool < nativeValue) revert InsufficientLiquidity();

        // Effects: burn LST and update pool state before external calls.
        _burn(msg.sender, lstAmount);
        totalNativeInPool -= nativeValue;

        // Interactions: transfer native tokens.
        if (fee > 0) {
            (bool okFee, ) = treasury.call{value: fee}("");
            if (!okFee) revert TransferFailed();
        }
        (bool ok, ) = msg.sender.call{value: toReturn}("");
        if (!ok) revert TransferFailed();

        emit Withdraw(msg.sender, lstAmount, toReturn, fee);
    }

    /// @notice Claim accumulated staking rewards from the dividend pool.
    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 pending = pendingReward[msg.sender];
        if (pending == 0) revert NoPendingRewards();
        pendingReward[msg.sender] = 0;
        if (address(this).balance < pending) revert InsufficientLiquidity();
        (bool ok, ) = msg.sender.call{value: pending}("");
        if (!ok) revert TransferFailed();
        emit RewardClaimed(msg.sender, pending);
    }

    // ========== Operator Functions ==========
    /// @notice Update the global exchange rate based on validator performance. Rate must be backed by pool balance.
    function updateExchangeRate(uint256 newRate) external onlyOperator {
        if (newRate == 0) revert InvalidExchangeRate();
        uint256 requiredNative = (totalSupply * newRate) / PRECISION;
        if (address(this).balance < requiredNative) revert InsufficientLiquidity();
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }

    /// @notice Distribute native tokens as dividends to all LST holders proportionally.
    function distributeRewards() external payable onlyOperator {
        if (msg.value == 0) revert ZeroAmount();
        if (totalSupply == 0) revert ZeroAmount();
        uint256 rewardPerShare = (msg.value * PRECISION) / totalSupply;
        accRewardPerShare += rewardPerShare;
        totalNativeInPool += msg.value;
        emit RewardDistributed(msg.value, accRewardPerShare);
    }

    /// @notice Rebalance the staked assets among validators. Bookkeeping only; the pool retains custody of native.
    function rebalanceValidators(address[] calldata _validators, uint256[] calldata amounts)
        external
        onlyOperator
    {
        if (_validators.length != amounts.length) revert ArraysLengthMismatch();
        if (_validators.length == 0) revert InvalidValidators();

        for (uint256 i = 0; i < validators.length; i++) {
            validatorAllocation[validators[i]] = 0;
        }
        delete validators;

        uint256 totalAlloc = 0;
        for (uint256 i = 0; i < _validators.length; i++) {
            if (_validators[i] == address(0)) revert InvalidAddress();
            validators.push(_validators[i]);
            validatorAllocation[_validators[i]] = amounts[i];
            totalAlloc += amounts[i];
        }

        if (totalAlloc > address(this).balance) revert InsufficientLiquidity();

        emit ValidatorsRebalanced(_validators.length, totalAlloc);
    }

    // ========== Admin Functions ==========
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ========== View Functions ==========
    function totalStakedValue() external view returns (uint256) {
        return (totalSupply * exchangeRate) / PRECISION;
    }

    function validatorCount() external view returns (uint256) {
        return validators.length;
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }
}
