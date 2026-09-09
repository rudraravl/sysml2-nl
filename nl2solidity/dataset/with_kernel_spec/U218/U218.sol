// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CrossChainTokenBridge
 * @notice Locks fungible tokens on the source chain as collateral for cross-chain
 *         transfers to a destination chain. A designated relayer finalizes transfers
 *         by releasing locked collateral (minus a 0.1% fee) to the recipient.
 */
contract CrossChainTokenBridge {
    /* ------------------------------------------------------------------ */
    /*                              Errors                                */
    /* ------------------------------------------------------------------ */

    error Unauthorized();
    error InsufficientLockedBalance();
    error TransferFailed();
    error DepositBelowMinimum();
    error ZeroAddress();
    error ZeroAmount();
    error ReentrantCall();
    error NoFeesAvailable();

    /* ------------------------------------------------------------------ */
    /*                              Events                                */
    /* ------------------------------------------------------------------ */

    event Deposit(address indexed sender, address indexed recipient, uint256 amount);
    event TransferFinalized(address indexed sender, address indexed recipient, uint256 amount, uint256 fee);
    event Withdrawal(address indexed sender, uint256 amount);
    event FeesWithdrawn(address indexed feeRecipient, uint256 amount);
    event RelayerUpdated(address indexed previousRelayer, address indexed newRelayer);
    event FeeRecipientUpdated(address indexed previous, address indexed next);
    event OwnershipTransferred(address indexed previous, address indexed next);

    /* ------------------------------------------------------------------ */
    /*                            Constants                               */
    /* ------------------------------------------------------------------ */

    /// @notice Minimum deposit amount in token's smallest unit.
    uint256 public constant MIN_DEPOSIT = 100;

    /// @notice Fee numerator: 0.1% = 1 / 1000.
    uint256 public constant FEE_NUMERATOR = 1;

    /// @notice Fee denominator.
    uint256 public constant FEE_DENOMINATOR = 1000;

    /* ------------------------------------------------------------------ */
    /*                             Storage                                */
    /* ------------------------------------------------------------------ */

    IERC20 public immutable token;

    address public owner;
    address public relayer;
    address public feeRecipient;

    /// @dev Per-user locked collateral.
    mapping(address => uint256) internal _lockedBalances;

    /// @dev Total tokens locked in the contract as collateral.
    uint256 public totalLocked;

    /// @dev Accumulated fees awaiting withdrawal by the fee recipient.
    uint256 public accumulatedFees;

    /// @dev Reentrancy guard state (1 = unlocked, 2 = locked).
    uint256 private _locked = 1;

    /* ------------------------------------------------------------------ */
    /*                            Modifiers                               */
    /* ------------------------------------------------------------------ */

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    /* ------------------------------------------------------------------ */
    /*                            Constructor                             */
    /* ------------------------------------------------------------------ */

    constructor(address token_, address relayer_, address feeRecipient_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (relayer_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();

        token = IERC20(token_);
        relayer = relayer_;
        feeRecipient = feeRecipient_;
        owner = msg.sender;

        emit RelayerUpdated(address(0), relayer_);
        emit FeeRecipientUpdated(address(0), feeRecipient_);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /* ------------------------------------------------------------------ */
    /*                       External / Public API                        */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Returns the locked collateral balance of a user.
     * @param user The address whose locked balance to query.
     */
    function lockedBalanceOf(address user) external view returns (uint256) {
        return _lockedBalances[user];
    }

    /**
     * @notice Deposits tokens into the bridge, locking them as collateral and
     *         initiating a cross-chain transfer to `recipient` on the destination chain.
     * @param recipient The address that will receive the released tokens on finalization.
     * @param amount The amount of tokens to deposit (must be >= MIN_DEPOSIT).
     */
    function deposit(address recipient, uint256 amount) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum();

        // Effects: record collateral before external interaction.
        _lockedBalances[msg.sender] += amount;
        totalLocked += amount;

        // Interaction: pull tokens from the depositor.
        // If this fails, the revert undoes all state changes above.
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposit(msg.sender, recipient, amount);
    }

    /**
     * @notice Finalizes a cross-chain transfer by releasing locked collateral
     *         (minus the 0.1% fee) to the recipient. Only the designated relayer
     *         may call this, after verifying that the corresponding tokens have
     *         been burned on the destination chain.
     * @param sender The original depositor whose collateral is being released.
     * @param recipient The address receiving the released tokens.
     * @param amount The original deposit amount being finalized.
     */
    function finalizeTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external onlyRelayer nonReentrant {
        if (sender == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 locked = _lockedBalances[sender];
        if (locked < amount) revert InsufficientLockedBalance();

        uint256 fee = (amount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 releaseAmount = amount - fee;

        // Effects: update all state before any external calls.
        _lockedBalances[sender] = locked - amount;
        totalLocked -= amount;
        accumulatedFees += fee;

        // Interactions: release to recipient. If this fails, revert undoes all effects.
        bool ok = token.transfer(recipient, releaseAmount);
        if (!ok) revert TransferFailed();

        // Interactions: transfer fee to fee recipient. If this fails, revert undoes
        // both the state effects and the recipient transfer above.
        if (fee > 0) {
            bool feeOk = token.transfer(feeRecipient, fee);
            if (!feeOk) revert TransferFailed();
        }

        emit TransferFinalized(sender, recipient, amount, fee);
    }

    /**
     * @notice Allows a depositor to withdraw their locked collateral. This is
     *         intended for transfers that were cancelled or failed on the
     *         destination chain.
     * @param amount The amount of locked tokens to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 locked = _lockedBalances[msg.sender];
        if (locked < amount) revert InsufficientLockedBalance();

        // Effects: reduce collateral before external interaction.
        _lockedBalances[msg.sender] = locked - amount;
        totalLocked -= amount;

        // Interaction: return collateral to the depositor.
        bool ok = token.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Allows the owner to withdraw accumulated fees to the fee recipient.
     */
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 fees = accumulatedFees;
        if (fees == 0) revert NoFeesAvailable();

        // Effects: clear fee accounting before external interaction.
        accumulatedFees = 0;

        // Interaction: send fees to the fee recipient.
        bool ok = token.transfer(feeRecipient, fees);
        if (!ok) revert TransferFailed();

        emit FeesWithdrawn(feeRecipient, fees);
    }

    /* ------------------------------------------------------------------ */
    /*                          Admin Functions                           */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Updates the designated relayer.
     * @param newRelayer The address of the new relayer.
     */
    function setRelayer(address newRelayer) external onlyOwner {
        if (newRelayer == address(0)) revert ZeroAddress();
        address previous = relayer;
        relayer = newRelayer;
        emit RelayerUpdated(previous, newRelayer);
    }

    /**
     * @notice Updates the fee recipient address.
     * @param newFeeRecipient The address that will receive accrued fees.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address previous = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(previous, newFeeRecipient);
    }

    /**
     * @notice Transfers ownership of the contract.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }
}
