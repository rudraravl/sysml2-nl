// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title L1L2TokenBridge
 * @dev Facilitates transfer of an arbitrary ERC-20 token between Layer 1 and Layer 2.
 * Deposited tokens are held in escrow on Layer 1. Withdrawals from Layer 2 are recorded
 * by a designated Layer 2 messaging contract and later claimed by recipients on Layer 1.
 */
contract L1L2TokenBridge {
    /* ------------------------------------------------------------------ */
    /* Constants                                                          */
    /* ------------------------------------------------------------------ */

    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant WITHDRAWAL_FEE = 0.01 ether;

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */

    error L1L2TokenBridge__Paused();
    error L1L2TokenBridge__NotPaused();
    error L1L2TokenBridge__Unauthorized();
    error L1L2TokenBridge__ZeroAddress();
    error L1L2TokenBridge__DepositTooLow(uint256 amount, uint256 minimum);
    error L1L2TokenBridge__InsufficientAllowance(uint256 available, uint256 required);
    error L1L2TokenBridge__TransferFailed();
    error L1L2TokenBridge__WithdrawalAlreadyExists(bytes32 l2TxHash);
    error L1L2TokenBridge__WithdrawalDoesNotExist(bytes32 l2TxHash);
    error L1L2TokenBridge__WithdrawalAlreadyClaimed(bytes32 l2TxHash);
    error L1L2TokenBridge__NotWithdrawalRecipient(address caller, address recipient);
    error L1L2TokenBridge__IncorrectFee(uint256 sent, uint256 required);
    error L1L2TokenBridge__ZeroAmount();

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */

    event TokensDeposited(address indexed depositor, uint256 amount);
    event WithdrawalInitiated(bytes32 indexed l2TxHash, address indexed recipient, uint256 amount);
    event WithdrawalClaimed(bytes32 indexed l2TxHash, address indexed recipient, uint256 amount);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event L2MessagingContractUpdated(address indexed previous, address indexed current);
    event OperatorUpdated(address indexed previous, address indexed current);
    event FeesWithdrawn(address indexed operator, uint256 amount);

    /* ------------------------------------------------------------------ */
    /* Structs                                                            */
    /* ------------------------------------------------------------------ */

    struct Withdrawal {
        address recipient;
        uint256 amount;
        bool claimed;
    }

    /* ------------------------------------------------------------------ */
    /* State Variables                                                    */
    /* ------------------------------------------------------------------ */

    IERC20 public immutable token;

    address public operator;
    address public l2MessagingContract;

    bool public paused;

    /// @notice Each user's deposited L1 token balance awaiting transfer to L2.
    mapping(address => uint256) public depositBalances;

    /// @notice L2 transaction hash => withdrawal record.
    mapping(bytes32 => Withdrawal) public withdrawals;

    /// @notice Accumulated ETH fees collected from withdrawal processing.
    uint256 public accumulatedFees;

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */

    modifier onlyOperator() {
        if (msg.sender != operator) revert L1L2TokenBridge__Unauthorized();
        _;
    }

    modifier onlyL2Messaging() {
        if (msg.sender != l2MessagingContract) revert L1L2TokenBridge__Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert L1L2TokenBridge__Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert L1L2TokenBridge__NotPaused();
        _;
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */

    /**
     * @param token_        The ERC-20 token to bridge.
     * @param l2Messaging_  The address of the Layer 2 messaging contract.
     */
    constructor(address token_, address l2Messaging_) {
        if (token_ == address(0)) revert L1L2TokenBridge__ZeroAddress();
        if (l2Messaging_ == address(0)) revert L1L2TokenBridge__ZeroAddress();

        token = IERC20(token_);
        l2MessagingContract = l2Messaging_;
        operator = msg.sender;

        emit L2MessagingContractUpdated(address(0), l2Messaging_);
        emit OperatorUpdated(address(0), msg.sender);
    }

    /* ------------------------------------------------------------------ */
    /* External / Public Functions                                        */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Deposit ERC-20 tokens for transfer to Layer 2.
     * @dev    The caller must have approved this contract to spend `amount` tokens.
     *         The deposit amount must be at least {MIN_DEPOSIT}.
     * @param amount  The amount of tokens to deposit (in base units).
     */
    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert L1L2TokenBridge__ZeroAmount();
        if (amount < MIN_DEPOSIT) {
            revert L1L2TokenBridge__DepositTooLow(amount, MIN_DEPOSIT);
        }

        uint256 allowance = token.allowance(msg.sender, address(this));
        if (allowance < amount) {
            revert L1L2TokenBridge__InsufficientAllowance(allowance, amount);
        }

        // Effects
        depositBalances[msg.sender] += amount;

        // Interactions
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert L1L2TokenBridge__TransferFailed();

        emit TokensDeposited(msg.sender, amount);
    }

    /**
     * @notice Initiate a withdrawal from Layer 2 to Layer 1.
     * @dev    Only callable by the Layer 2 messaging contract. The caller must
     *         send exactly {WITHDRAWAL_FEE} ETH as a processing fee.
     * @param l2TxHash   The Layer 2 transaction hash that triggered the withdrawal.
     * @param recipient  The Layer 1 address that will claim the tokens.
     * @param amount     The amount of tokens to withdraw.
     */
    function initiateWithdrawal(
        bytes32 l2TxHash,
        address recipient,
        uint256 amount
    ) external payable onlyL2Messaging whenNotPaused {
        if (msg.value != WITHDRAWAL_FEE) {
            revert L1L2TokenBridge__IncorrectFee(msg.value, WITHDRAWAL_FEE);
        }
        if (recipient == address(0)) revert L1L2TokenBridge__ZeroAddress();
        if (amount == 0) revert L1L2TokenBridge__ZeroAmount();
        if (withdrawals[l2TxHash].recipient != address(0)) {
            revert L1L2TokenBridge__WithdrawalAlreadyExists(l2TxHash);
        }

        // Effects
        withdrawals[l2TxHash] = Withdrawal({
            recipient: recipient,
            amount: amount,
            claimed: false
        });
        accumulatedFees += msg.value;

        emit WithdrawalInitiated(l2TxHash, recipient, amount);
    }

    /**
     * @notice Claim withdrawn tokens on Layer 1.
     * @dev    Only the designated recipient of the withdrawal may claim.
     *         Tokens are transferred from this contract's escrow balance.
     * @param l2TxHash  The Layer 2 transaction hash identifying the withdrawal.
     */
    function claimWithdrawal(bytes32 l2TxHash) external whenNotPaused {
        Withdrawal storage w = withdrawals[l2TxHash];

        if (w.recipient == address(0)) {
            revert L1L2TokenBridge__WithdrawalDoesNotExist(l2TxHash);
        }
        if (w.claimed) {
            revert L1L2TokenBridge__WithdrawalAlreadyClaimed(l2TxHash);
        }
        if (msg.sender != w.recipient) {
            revert L1L2TokenBridge__NotWithdrawalRecipient(msg.sender, w.recipient);
        }

        uint256 amount = w.amount;

        // Effects
        w.claimed = true;

        // Interactions
        bool success = token.transfer(w.recipient, amount);
        if (!success) revert L1L2TokenBridge__TransferFailed();

        emit WithdrawalClaimed(l2TxHash, w.recipient, amount);
    }

    /* ------------------------------------------------------------------ */
    /* Operator Functions                                                 */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Pause the contract. Only callable by the operator.
     */
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause the contract. Only callable by the operator.
     */
    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Update the Layer 2 messaging contract address.
     * @param newL2Messaging  The new address of the Layer 2 messaging contract.
     */
    function setL2MessagingContract(address newL2Messaging) external onlyOperator {
        if (newL2Messaging == address(0)) revert L1L2TokenBridge__ZeroAddress();
        address previous = l2MessagingContract;
        l2MessagingContract = newL2Messaging;
        emit L2MessagingContractUpdated(previous, newL2Messaging);
    }

    /**
     * @notice Transfer the operator role to a new address.
     * @param newOperator  The new operator address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert L1L2TokenBridge__ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    /**
     * @notice Withdraw accumulated ETH fees to the operator.
     */
    function withdrawFees() external onlyOperator {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert L1L2TokenBridge__ZeroAmount();

        // Effects
        accumulatedFees = 0;

        // Interactions
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert L1L2TokenBridge__TransferFailed();

        emit FeesWithdrawn(msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /* View Functions                                                     */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Get the deposited L1 token balance for a user awaiting transfer to L2.
     * @param user  The depositor address.
     * @return      The pending deposit balance.
     */
    function getDepositBalance(address user) external view returns (uint256) {
        return depositBalances[user];
    }

    /**
     * @notice Get the withdrawal record for a given Layer 2 transaction hash.
     * @param l2TxHash  The Layer 2 transaction hash.
     * @return recipient  The Layer 1 recipient address.
     * @return amount     The withdrawal amount.
     * @return claimed    Whether the withdrawal has been claimed.
     */
    function getWithdrawalStatus(
        bytes32 l2TxHash
    ) external view returns (address recipient, uint256 amount, bool claimed) {
        Withdrawal storage w = withdrawals[l2TxHash];
        return (w.recipient, w.amount, w.claimed);
    }

    /**
     * @notice Get the total ERC-20 token balance held in escrow by this contract.
     * @return The contract's token balance.
     */
    function escrowBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /* ------------------------------------------------------------------ */
    /* Receive                                                            */
    /* ------------------------------------------------------------------ */

    receive() external payable {}
}
