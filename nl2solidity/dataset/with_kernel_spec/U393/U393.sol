// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title SmartWallet
/// @notice Non-custodial smart wallet letting users deposit whitelisted ERC-20 tokens,
///         transfer them to any address for a flat fee, and manage per-token allowances.
contract SmartWallet {
    // -----------------------------------------------------------------------
    // Custom errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotPendingOwner();
    error ZeroAddress();
    error TokenNotSupported(address token);
    error TokenAlreadySupported(address token);
    error DepositExceedsLimit(uint256 attempted, uint256 limit);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error AmountTooLow();
    error NoFeesToClaim();
    error TransferFailed();
    error Reentrancy();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    /// @dev Maximum cumulative deposit a single user may hold for any one token.
    uint256 public constant MAX_DEPOSIT = 100 ether;
    /// @dev Flat fee charged on every outbound transfer and deducted from the transferred amount.
    uint256 public constant TRANSFER_FEE = 0.001 ether;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    address public owner;
    address public pendingOwner;
    uint256 private _locked = 1;

    mapping(address => bool) public isTokenSupported;
    mapping(address => mapping(address => uint256)) public userBalances;                     // user => token => balance
    mapping(address => mapping(address => mapping(address => uint256))) public userAllowances; // owner => token => spender => amount
    mapping(address => uint256) public accumulatedFees;                                      // token => accrued fees

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event TokenWhitelisted(address indexed token);
    event TokenRemoved(address indexed token);
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Transferred(address indexed from, address indexed to, address indexed token, uint256 amount, uint256 fee);
    event ApprovalSet(address indexed owner, address indexed token, address indexed spender, uint256 amount);
    event ApprovalRevoked(address indexed owner, address indexed token, address indexed spender);
    event FeesClaimed(address indexed token, address indexed to, uint256 amount);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier supportedToken(address token) {
        if (!isTokenSupported[token]) revert TokenNotSupported(token);
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // Owner administration
    // -----------------------------------------------------------------------
    /// @notice Whitelists a new ERC-20 token so users may deposit it.
    function addSupportedToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (isTokenSupported[token]) revert TokenAlreadySupported(token);
        isTokenSupported[token] = true;
        emit TokenWhitelisted(token);
    }

    /// @notice Removes a token from the whitelist. Existing balances may still be transferred out.
    function removeSupportedToken(address token) external onlyOwner {
        if (!isTokenSupported[token]) revert TokenNotSupported(token);
        isTokenSupported[token] = false;
        emit TokenRemoved(token);
    }

    /// @notice Begins a two-step ownership transfer.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice Completes a two-step ownership transfer.
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        address oldOwner = owner;
        owner = msg.sender;
        delete pendingOwner;
        emit OwnershipTransferred(oldOwner, msg.sender);
    }

    /// @notice Lets the owner sweep fees accrued for a given token.
    function claimFees(address token, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees[token];
        if (amount == 0) revert NoFeesToClaim();
        accumulatedFees[token] = 0;
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        emit FeesClaimed(token, to, amount);
    }

    // -----------------------------------------------------------------------
    // User operations
    // -----------------------------------------------------------------------
    /// @notice Deposits a supported token into the caller's wallet balance.
    function deposit(address token, uint256 amount) external supportedToken(token) nonReentrant {
        if (amount == 0) revert AmountTooLow();
        uint256 newBalance = userBalances[msg.sender][token] + amount;
        if (newBalance > MAX_DEPOSIT) revert DepositExceedsLimit(newBalance, MAX_DEPOSIT);
        userBalances[msg.sender][token] = newBalance;
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Deposited(msg.sender, token, amount);
    }

    /// @notice Sends tokens from the caller's wallet balance to an arbitrary address.
    ///         A flat fee is deducted from the amount and accrued for the owner.
    function transfer(address token, address to, uint256 amount) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount <= TRANSFER_FEE) revert AmountTooLow();
        uint256 balance = userBalances[msg.sender][token];
        if (balance < amount) revert InsufficientBalance(balance, amount);

        uint256 fee = TRANSFER_FEE;
        uint256 sendAmount = amount - fee;

        userBalances[msg.sender][token] = balance - amount;
        accumulatedFees[token] += fee;

        if (!IERC20(token).transfer(to, sendAmount)) revert TransferFailed();
        emit Transferred(msg.sender, to, token, sendAmount, fee);
    }

    /// @notice Sets an allowance permitting a spender to transfer tokens on the caller's behalf.
    function approve(address token, address spender, uint256 amount) external {
        if (spender == address(0)) revert ZeroAddress();
        userAllowances[msg.sender][token][spender] = amount;
        emit ApprovalSet(msg.sender, token, spender, amount);
    }

    /// @notice Revokes a previously granted allowance.
    function revokeApproval(address token, address spender) external {
        if (spender == address(0)) revert ZeroAddress();
        userAllowances[msg.sender][token][spender] = 0;
        emit ApprovalRevoked(msg.sender, token, spender);
    }

    /// @notice Transfers tokens from another user's balance using a prior allowance.
    function transferFrom(address token, address from, address to, uint256 amount) external nonReentrant {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (amount <= TRANSFER_FEE) revert AmountTooLow();

        uint256 allowed = userAllowances[from][token][msg.sender];
        if (allowed < amount) revert InsufficientAllowance(allowed, amount);

        uint256 balance = userBalances[from][token];
        if (balance < amount) revert InsufficientBalance(balance, amount);

        uint256 fee = TRANSFER_FEE;
        uint256 sendAmount = amount - fee;

        userBalances[from][token] = balance - amount;
        if (allowed != type(uint256).max) {
            userAllowances[from][token][msg.sender] = allowed - amount;
        }
        accumulatedFees[token] += fee;

        if (!IERC20(token).transfer(to, sendAmount)) revert TransferFailed();
        emit Transferred(from, to, token, sendAmount, fee);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------
    function getBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }

    function getAllowance(address user, address token, address spender) external view returns (uint256) {
        return userAllowances[user][token][spender];
    }
}
