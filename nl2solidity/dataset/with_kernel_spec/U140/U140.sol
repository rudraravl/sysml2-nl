// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error ZeroAddress();
error NotOwner();
error NotAuthorized();
error DepositsPaused();
error InsufficientBalance();
error InsufficientAllowance();
error WithdrawalNotReady();
error FeeExceedsMax();
error DelayBelowMinimum();
error NoPendingWithdrawal();
error EthTransferFailed();
error AmountZero();
error InsufficientEthLiquidity();
error WithdrawalAlreadyPending();

contract LiquidStakingVault {
    // -----------------------------------------------------------------------
    // Token Metadata
    // -----------------------------------------------------------------------
    string public constant PRINCIPAL_NAME = "Liquid Staked Principal";
    string public constant PRINCIPAL_SYMBOL = "lsPRINC";
    string public constant YIELD_NAME = "Liquid Staked Yield";
    string public constant YIELD_SYMBOL = "lsYIELD";
    uint8 public constant TOKEN_DECIMALS = 18;

    // -----------------------------------------------------------------------
    // Principal Token State (ERC-20)
    // -----------------------------------------------------------------------
    uint256 public principalTotalSupply;
    mapping(address => uint256) public principalBalanceOf;
    mapping(address => mapping(address => uint256)) public principalAllowance;

    // -----------------------------------------------------------------------
    // Yield Token State (ERC-20)
    // -----------------------------------------------------------------------
    uint256 public yieldTotalSupply;
    mapping(address => uint256) public yieldBalanceOf;
    mapping(address => mapping(address => uint256)) public yieldAllowance;

    // -----------------------------------------------------------------------
    // Per-Account Records
    // -----------------------------------------------------------------------
    struct Account {
        uint256 depositedPrincipal;
        uint256 earnedYield;
        uint256 pendingWithdrawal;
        uint256 withdrawalRequestTime;
    }
    mapping(address => Account) public accounts;

    // -----------------------------------------------------------------------
    // Global Configuration
    // -----------------------------------------------------------------------
    uint256 public depositFeeBps;
    uint256 public withdrawalDelay;
    uint256 public accumulatedFees;

    uint256 public constant MAX_DEPOSIT_FEE_BPS = 50; // 0.5%
    uint256 public constant MIN_WITHDRAWAL_DELAY = 24 hours;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // -----------------------------------------------------------------------
    // Access Control
    // -----------------------------------------------------------------------
    address public owner;
    mapping(address => bool) public isOperator;
    bool public depositsPaused;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed depositor, uint256 etherAmount, uint256 fee, uint256 principalMinted);
    event PrincipalRedeemed(address indexed redeemer, uint256 principalBurned, uint256 etherReturned);
    event YieldWithdrawalRequested(address indexed user, uint256 yieldAmount, uint256 availableAt);
    event YieldWithdrawalCompleted(address indexed user, uint256 etherAmount);
    event YieldWithdrawalCancelled(address indexed user, uint256 yieldAmount);
    event EtherTransferred(address indexed to, uint256 amount);
    event YieldDistributed(address indexed user, uint256 etherAmount);
    event DepositFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event WithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event OperatorSet(address indexed operator, bool status);
    event DepositsPausedChanged(bool paused);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event PrincipalTransfer(address indexed from, address indexed to, uint256 amount);
    event PrincipalApproval(address indexed ownerAddr, address indexed spender, uint256 amount);
    event YieldTransfer(address indexed from, address indexed to, uint256 amount);
    event YieldApproval(address indexed ownerAddr, address indexed spender, uint256 amount);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner && !isOperator[msg.sender]) revert NotAuthorized();
        _;
    }

    modifier notPaused() {
        if (depositsPaused) revert DepositsPaused();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor() {
        owner = msg.sender;
        withdrawalDelay = MIN_WITHDRAWAL_DELAY;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // Core: Deposit Ether
    // -----------------------------------------------------------------------
    function deposit() external payable notPaused {
        if (msg.value == 0) revert AmountZero();

        uint256 fee = (msg.value * depositFeeBps) / BPS_DENOMINATOR;
        uint256 principalAmount = msg.value - fee;

        accumulatedFees += fee;
        accounts[msg.sender].depositedPrincipal += principalAmount;

        _mintPrincipal(msg.sender, principalAmount);

        emit Deposit(msg.sender, msg.value, fee, principalAmount);
    }

    // -----------------------------------------------------------------------
    // Core: Redeem Principal Tokens for Ether
    // -----------------------------------------------------------------------
    function redeem(uint256 principalAmount) external {
        if (principalAmount == 0) revert AmountZero();
        if (principalBalanceOf[msg.sender] < principalAmount) revert InsufficientBalance();
        if (address(this).balance < principalAmount) revert InsufficientEthLiquidity();

        uint256 deposited = accounts[msg.sender].depositedPrincipal;
        accounts[msg.sender].depositedPrincipal = deposited > principalAmount
            ? deposited - principalAmount
            : 0;

        _burnPrincipal(msg.sender, principalAmount);

        (bool success, ) = payable(msg.sender).call{value: principalAmount}("");
        if (!success) revert EthTransferFailed();

        emit PrincipalRedeemed(msg.sender, principalAmount, principalAmount);
        emit EtherTransferred(msg.sender, principalAmount);
    }

    // -----------------------------------------------------------------------
    // Core: Initiate Yield Withdrawal (locks yield tokens, starts delay)
    // -----------------------------------------------------------------------
    function requestYieldWithdrawal(uint256 yieldAmount) external {
        if (yieldAmount == 0) revert AmountZero();
        if (yieldBalanceOf[msg.sender] < yieldAmount) revert InsufficientBalance();
        if (accounts[msg.sender].pendingWithdrawal != 0) revert WithdrawalAlreadyPending();

        accounts[msg.sender].pendingWithdrawal = yieldAmount;
        accounts[msg.sender].withdrawalRequestTime = block.timestamp;
        _burnYield(msg.sender, yieldAmount);

        emit YieldWithdrawalRequested(msg.sender, yieldAmount, block.timestamp + withdrawalDelay);
    }

    // -----------------------------------------------------------------------
    // Core: Cancel Pending Yield Withdrawal (re-mints yield tokens)
    // -----------------------------------------------------------------------
    function cancelYieldWithdrawal() external {
        Account storage acct = accounts[msg.sender];
        if (acct.pendingWithdrawal == 0) revert NoPendingWithdrawal();

        uint256 amount = acct.pendingWithdrawal;
        acct.pendingWithdrawal = 0;
        acct.withdrawalRequestTime = 0;

        _mintYield(msg.sender, amount);

        emit YieldWithdrawalCancelled(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // Core: Complete Yield Withdrawal (sends Ether after delay)
    // -----------------------------------------------------------------------
    function completeYieldWithdrawal() external {
        Account storage acct = accounts[msg.sender];
        if (acct.pendingWithdrawal == 0) revert NoPendingWithdrawal();
        if (block.timestamp < acct.withdrawalRequestTime + withdrawalDelay) revert WithdrawalNotReady();
        if (address(this).balance < acct.pendingWithdrawal) revert InsufficientEthLiquidity();

        uint256 amount = acct.pendingWithdrawal;
        acct.pendingWithdrawal = 0;
        acct.withdrawalRequestTime = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert EthTransferFailed();

        emit YieldWithdrawalCompleted(msg.sender, amount);
        emit EtherTransferred(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // Operator: Distribute Yield (payable, mints yield tokens to user)
    // -----------------------------------------------------------------------
    function distributeYield(address user) external payable onlyOwnerOrOperator {
        if (user == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert AmountZero();

        accounts[user].earnedYield += msg.value;
        _mintYield(user, msg.value);

        emit YieldDistributed(user, msg.value);
    }

    // -----------------------------------------------------------------------
    // Owner: Set Deposit Fee (max 0.5%)
    // -----------------------------------------------------------------------
    function setDepositFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_DEPOSIT_FEE_BPS) revert FeeExceedsMax();
        emit DepositFeeUpdated(depositFeeBps, newFeeBps);
        depositFeeBps = newFeeBps;
    }

    // -----------------------------------------------------------------------
    // Owner: Set Withdrawal Delay (min 24 hours)
    // -----------------------------------------------------------------------
    function setWithdrawalDelay(uint256 newDelay) external onlyOwner {
        if (newDelay < MIN_WITHDRAWAL_DELAY) revert DelayBelowMinimum();
        emit WithdrawalDelayUpdated(withdrawalDelay, newDelay);
        withdrawalDelay = newDelay;
    }

    // -----------------------------------------------------------------------
    // Owner: Designate Operator
    // -----------------------------------------------------------------------
    function setOperator(address operator, bool status) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        isOperator[operator] = status;
        emit OperatorSet(operator, status);
    }

    // -----------------------------------------------------------------------
    // Owner / Operator: Pause or Unpause Deposits
    // -----------------------------------------------------------------------
    function setDepositsPaused(bool paused) external onlyOwnerOrOperator {
        depositsPaused = paused;
        emit DepositsPausedChanged(paused);
    }

    // -----------------------------------------------------------------------
    // Owner: Withdraw Accumulated Fees
    // -----------------------------------------------------------------------
    function withdrawFees(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert AmountZero();

        accumulatedFees = 0;

        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert EthTransferFailed();

        emit FeesWithdrawn(to, amount);
        emit EtherTransferred(to, amount);
    }

    // -----------------------------------------------------------------------
    // Owner: Transfer Ownership
    // -----------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // -----------------------------------------------------------------------
    // Principal Token: ERC-20 Interface
    // -----------------------------------------------------------------------
    function transferPrincipal(address to, uint256 amount) external returns (bool) {
        _transferPrincipal(msg.sender, to, amount);
        return true;
    }

    function approvePrincipal(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        principalAllowance[msg.sender][spender] = amount;
        emit PrincipalApproval(msg.sender, spender, amount);
        return true;
    }

    function transferFromPrincipal(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = principalAllowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            principalAllowance[from][msg.sender] = allowed - amount;
        }
        _transferPrincipal(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Yield Token: ERC-20 Interface
    // -----------------------------------------------------------------------
    function transferYield(address to, uint256 amount) external returns (bool) {
        _transferYield(msg.sender, to, amount);
        return true;
    }

    function approveYield(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        yieldAllowance[msg.sender][spender] = amount;
        emit YieldApproval(msg.sender, spender, amount);
        return true;
    }

    function transferFromYield(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = yieldAllowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            yieldAllowance[from][msg.sender] = allowed - amount;
        }
        _transferYield(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Internal: Principal Token
    // -----------------------------------------------------------------------
    function _mintPrincipal(address to, uint256 amount) internal {
        principalTotalSupply += amount;
        principalBalanceOf[to] += amount;
        emit PrincipalTransfer(address(0), to, amount);
    }

    function _burnPrincipal(address from, uint256 amount) internal {
        if (principalBalanceOf[from] < amount) revert InsufficientBalance();
        principalBalanceOf[from] -= amount;
        principalTotalSupply -= amount;
        emit PrincipalTransfer(from, address(0), amount);
    }

    function _transferPrincipal(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = principalBalanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            principalBalanceOf[from] = fromBalance - amount;
        }
        principalBalanceOf[to] += amount;
        emit PrincipalTransfer(from, to, amount);
    }

    // -----------------------------------------------------------------------
    // Internal: Yield Token
    // -----------------------------------------------------------------------
    function _mintYield(address to, uint256 amount) internal {
        yieldTotalSupply += amount;
        yieldBalanceOf[to] += amount;
        emit YieldTransfer(address(0), to, amount);
    }

    function _burnYield(address from, uint256 amount) internal {
        if (yieldBalanceOf[from] < amount) revert InsufficientBalance();
        yieldBalanceOf[from] -= amount;
        yieldTotalSupply -= amount;
        emit YieldTransfer(from, address(0), amount);
    }

    function _transferYield(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = yieldBalanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            yieldBalanceOf[from] = fromBalance - amount;
        }
        yieldBalanceOf[to] += amount;
        emit YieldTransfer(from, to, amount);
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------
    function getAccount(address user)
        external
        view
        returns (uint256 depositedPrincipal, uint256 earnedYield, uint256 pendingWithdrawal, uint256 withdrawalRequestTime)
    {
        Account memory acct = accounts[user];
        return (acct.depositedPrincipal, acct.earnedYield, acct.pendingWithdrawal, acct.withdrawalRequestTime);
    }

    function pendingWithdrawalAvailableAt(address user) external view returns (uint256) {
        if (accounts[user].pendingWithdrawal == 0) return 0;
        return accounts[user].withdrawalRequestTime + withdrawalDelay;
    }

    function totalEthCustodied() external view returns (uint256) {
        return address(this).balance;
    }

    function principalName() external pure returns (string memory) {
        return PRINCIPAL_NAME;
    }

    function principalSymbol() external pure returns (string memory) {
        return PRINCIPAL_SYMBOL;
    }

    function yieldName() external pure returns (string memory) {
        return YIELD_NAME;
    }

    function yieldSymbol() external pure returns (string memory) {
        return YIELD_SYMBOL;
    }

    function tokenDecimals() external pure returns (uint8) {
        return TOKEN_DECIMALS;
    }

    receive() external payable {}
}
