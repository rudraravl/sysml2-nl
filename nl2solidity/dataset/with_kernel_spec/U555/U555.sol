// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title NativeAssetBridge
 * @dev Non-custodial bridge that wraps an external blockchain's native asset
 *      (represented as an ERC-20 on this chain) into a locally minted wrapped
 *      token. The external asset is held in escrow by this contract and can
 *      be reclaimed by burning the corresponding wrapped tokens.
 */
contract NativeAssetBridge {
    // ---------------------------------------------------------------------
    // ERC-20 metadata & storage
    // ---------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------
    // Bridge storage
    // ---------------------------------------------------------------------
    /// @notice The external asset held in escrow (ERC-20 representation of the
    ///         foreign chain's native token).
    IERC20 public immutable externalAsset;

    /// @notice Privileged role that can pause / unpause and adjust fees.
    address public operator;

    /// @notice Bridge fee expressed in basis points (1 bp = 0.01 %).
    uint256 public bridgeFeeBps;

    /// @dev Whether bridging operations are currently halted.
    bool public paused;

    /// @dev Monotonically increasing counter used to generate unique tx ids.
    uint256 public nextTxId;

    /// @notice Net amount of the external asset each user has deposited into
    ///         escrow (deposits minus redemptions, floored at zero).
    mapping(address => uint256) public depositedAmount;

    /// @dev Reentrancy guard status (0 = idle, 1 = entered).
    uint256 private _reentrancyStatus;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    /// @dev Maximum allowed bridge fee: 0.5 % = 50 basis points.
    uint256 public constant MAX_FEE_BPS = 50;

    /// @dev Minimum deposit: 0.0001 units of the external asset (18 decimals).
    uint256 public constant MIN_DEPOSIT = 10 ** 14;

    /// @dev Basis points denominator.
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount, uint256 fee, uint256 minted, uint256 indexed txId);
    event Withdrawal(address indexed user, uint256 amount, uint256 fee, uint256 received, uint256 indexed txId);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event BridgeFeeUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // ---------------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------------
    error NotOperator();
    error EnforcedPause();
    error ExpectedPause();
    error FeeExceedsMaximum(uint256 feeBps, uint256 maxBps);
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error ZeroAddress();
    error TransferFailed();
    error AmountIsZero();
    error ReentrancyGuard();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus != 0) revert ReentrancyGuard();
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 0;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        address _externalAsset,
        string memory _name,
        string memory _symbol,
        uint256 _bridgeFeeBps
    ) {
        if (_externalAsset == address(0)) revert ZeroAddress();
        if (_bridgeFeeBps > MAX_FEE_BPS) revert FeeExceedsMaximum(_bridgeFeeBps, MAX_FEE_BPS);

        externalAsset = IERC20(_externalAsset);
        name = _name;
        symbol = _symbol;
        operator = msg.sender;
        bridgeFeeBps = _bridgeFeeBps;
        nextTxId = 1;
        _reentrancyStatus = 0;

        // Inherit decimals from the external asset when possible.
        try IERC20(_externalAsset).decimals() returns (uint8 _decimals) {
            decimals = _decimals;
        } catch {
            decimals = 18;
        }
    }

    // ---------------------------------------------------------------------
    // ERC-20 core
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance(currentAllowance, subtractedValue);
        unchecked {
            allowance[msg.sender][spender] = currentAllowance - subtractedValue;
        }
        emit Approval(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance(fromBalance, amount);
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance(fromBalance, amount);
        unchecked {
            balanceOf[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    // ---------------------------------------------------------------------
    // Bridge operations
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit the external asset into escrow and mint wrapped tokens.
     * @dev    The caller must have approved this contract to spend `amount`
     *         of the external asset. A bridge fee (capped at 0.5 %) is
     *         deducted from the minted wrapped tokens and credited to the
     *         operator as compensation for bridge operation costs.
     * @param  amount  Quantity of the external asset to deposit.
     * @return txId    Unique identifier for this deposit transaction.
     */
    function deposit(uint256 amount) external whenNotPaused nonReentrant returns (uint256 txId) {
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum(amount, MIN_DEPOSIT);

        // --- Effects ---
        depositedAmount[msg.sender] += amount;

        uint256 fee = (amount * bridgeFeeBps) / BPS_DENOMINATOR;
        uint256 mintAmount = amount - fee;

        txId = nextTxId++;

        // --- Interactions (pull external asset) ---
        bool ok = externalAsset.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        // --- Effects (mint wrapped tokens) ---
        _mint(msg.sender, mintAmount);
        if (fee > 0) {
            _mint(operator, fee);
        }

        emit Deposit(msg.sender, amount, fee, mintAmount, txId);
    }

    /**
     * @notice Redeem wrapped tokens and withdraw the corresponding external
     *         asset from escrow.
     * @dev    The redemption is one-to-one with the burned wrapped tokens;
     *         no fee is charged on the way out because the fee was already
     *         collected at deposit time.
     * @param  amount  Quantity of wrapped tokens to burn.
     * @return txId    Unique identifier for this withdrawal transaction.
     */
    function redeem(uint256 amount) external whenNotPaused nonReentrant returns (uint256 txId) {
        if (amount == 0) revert AmountIsZero();

        uint256 userBalance = balanceOf[msg.sender];
        if (userBalance < amount) revert InsufficientBalance(userBalance, amount);

        // --- Effects ---
        _burn(msg.sender, amount);

        // Decrease the user's recorded deposit (floored at zero).
        uint256 deposited = depositedAmount[msg.sender];
        if (deposited >= amount) {
            depositedAmount[msg.sender] = deposited - amount;
        } else {
            depositedAmount[msg.sender] = 0;
        }

        txId = nextTxId++;

        // --- Interactions (push external asset) ---
        bool ok = externalAsset.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, amount, 0, amount, txId);
    }

    // ---------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------

    /**
     * @notice Halt all deposit and redemption operations.
     */
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Resume deposit and redemption operations.
     */
    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Update the bridge fee.
     * @param  newFeeBps  New fee in basis points (must not exceed 50 / 0.5 %).
     */
    function setBridgeFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsMaximum(newFeeBps, MAX_FEE_BPS);
        uint256 oldFee = bridgeFeeBps;
        bridgeFeeBps = newFeeBps;
        emit BridgeFeeUpdated(msg.sender, oldFee, newFeeBps);
    }

    /**
     * @notice Transfer the operator role to a new address.
     * @param  newOperator  Address of the new operator.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    // ---------------------------------------------------------------------
    // View helpers
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the fee that would be charged for a given deposit
     *         amount.
     */
    function previewDepositFee(uint256 amount) external view returns (uint256) {
        return (amount * bridgeFeeBps) / BPS_DENOMINATOR;
    }

    /**
     * @notice Returns the amount of wrapped tokens a depositor would receive
     *         for a given deposit amount (net of fee).
     */
    function previewDepositMint(uint256 amount) external view returns (uint256) {
        return amount - (amount * bridgeFeeBps) / BPS_DENOMINATOR;
    }

    /**
     * @notice Returns the total external asset balance held by this contract
     *         in escrow.
     */
    function totalEscrowed() external view returns (uint256) {
        return externalAsset.balanceOf(address(this));
    }

    /**
     * @notice Returns the deposited amount of the external asset recorded for
     *         a given user (deposits minus redemptions, floored at zero).
     */
    function getDepositedAmount(address user) external view returns (uint256) {
        return depositedAmount[user];
    }
}
