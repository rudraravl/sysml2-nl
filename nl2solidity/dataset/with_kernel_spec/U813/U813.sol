// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title CryptoCardEscrow
 * @notice Manages user deposits of various cryptocurrencies to facilitate payments
 *         through a linked card service, holding deposited funds in escrow.
 */
contract CryptoCardEscrow {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @notice Sentinel address used to represent the chain's native asset.
    address public constant NATIVE_ASSET = address(0);

    /// @notice Maximum allowed transaction fee in basis points (5%).
    uint16 public constant MAX_FEE_BPS = 500;

    /// @notice Delay before a requested withdrawal may be executed.
    uint256 public constant WITHDRAWAL_DELAY = 24 hours;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error Unauthorized();
    error OnlyOperator();
    error OnlyOwner();
    error ZeroAmount();
    error UnsupportedAsset(address asset);
    error AssetAlreadySupported(address asset);
    error InsufficientBalance(address user, address asset, uint256 available, uint256 required);
    error FeeExceedsMaximum(uint16 feeBps, uint16 maxFeeBps);
    error CardAlreadyLinked(address user);
    error CardNotLinked(address user);
    error InvalidCardHash();
    error NoPendingWithdrawal(address user);
    error WithdrawalNotYetExecutable(uint256 executableAt, uint256 currentTime);
    error NativeValueMismatch(uint256 expected, uint256 received);
    error TransferFailed();
    error ReentrantCall();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposited(address indexed user, address indexed asset, uint256 amount);
    event WithdrawalRequested(address indexed user, address indexed asset, uint256 amount, uint256 executableAt);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount);
    event CardLinked(address indexed user, bytes32 indexed cardHash);
    event CardUnlinked(address indexed user);
    event AssetSupported(address indexed asset, bool supported);
    event FeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PaymentProcessed(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        address indexed merchant
    );

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    /// @notice Contract owner.
    address public owner;

    /// @notice Operator authorized to manage assets, fees, and process payments.
    address public operator;

    /// @notice Current transaction fee in basis points (e.g., 100 = 1%).
    uint16 public feeBps;

    /// @notice Whether an asset is supported for deposit/withdrawal.
    mapping(address asset => bool supported) public supportedAssets;

    /// @notice User balances per asset: user => asset => balance.
    mapping(address user => mapping(address asset => uint256 balance)) public balances;

    struct WithdrawalRequest {
        address asset;
        uint256 amount;
        uint256 executableAt;
        bool active;
    }

    /// @notice Pending withdrawal request per user.
    mapping(address user => WithdrawalRequest) public pendingWithdrawals;

    /// @notice Hash of the card identifier linked to a user.
    mapping(address user => bytes32 cardHash) public linkedCardHash;

    /// @notice Whether a user has a card linked.
    mapping(address user => bool linked) public hasCardLinked;

    /// @notice Reentrancy guard flag.
    uint256 private _locked;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!supportedAssets[asset]) revert UnsupportedAsset(asset);
        _;
    }

    modifier nonReentrant() {
        if (_locked == 1) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    /**
     * @param _operator        Initial operator address.
     * @param _feeBps          Initial transaction fee in basis points (<= MAX_FEE_BPS).
     * @param _initialAssets   Array of asset addresses to support initially.
     */
    constructor(
        address _operator,
        uint16 _feeBps,
        address[] memory _initialAssets
    ) {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum(_feeBps, MAX_FEE_BPS);
        if (_operator == address(0)) revert Unauthorized();

        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        operator = _operator;
        feeBps = _feeBps;

        for (uint256 i = 0; i < _initialAssets.length; i++) {
            address asset = _initialAssets[i];
            if (supportedAssets[asset]) revert AssetAlreadySupported(asset);
            supportedAssets[asset] = true;
            emit AssetSupported(asset, true);
        }

        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, _feeBps);

        _locked = 0;
    }

    // ---------------------------------------------------------------------
    // Receive (native asset direct deposit)
    // ---------------------------------------------------------------------

    receive() external payable {
        _deposit(msg.sender, NATIVE_ASSET, msg.value);
    }

    // ---------------------------------------------------------------------
    // Admin / Operator configuration
    // ---------------------------------------------------------------------

    /**
     * @notice Transfer ownership to a new address.
     * @param newOwner New owner address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Unauthorized();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Update the operator address.
     * @param _operator New operator address.
     */
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert Unauthorized();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    /**
     * @notice Update the transaction fee in basis points.
     * @param _feeBps New fee in basis points (max 500 = 5%).
     */
    function setFee(uint16 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeExceedsMaximum(_feeBps, MAX_FEE_BPS);
        emit FeeUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    /**
     * @notice Add a supported asset.
     * @param asset Asset address (NATIVE_ASSET for native token).
     */
    function addSupportedAsset(address asset) external onlyOperator {
        if (supportedAssets[asset]) revert AssetAlreadySupported(asset);
        supportedAssets[asset] = true;
        emit AssetSupported(asset, true);
    }

    /**
     * @notice Remove a supported asset. Existing balances remain withdrawable.
     * @param asset Asset address to remove.
     */
    function removeSupportedAsset(address asset) external onlyOperator {
        if (!supportedAssets[asset]) revert UnsupportedAsset(asset);
        supportedAssets[asset] = false;
        emit AssetSupported(asset, false);
    }

    // ---------------------------------------------------------------------
    // User: deposits
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit a supported cryptocurrency into the escrow.
     * @param asset  Asset address (NATIVE_ASSET for native token).
     * @param amount Amount to deposit (must equal msg.value for native).
     */
    function deposit(address asset, uint256 amount)
        external
        payable
        nonReentrant
        onlySupportedAsset(asset)
    {
        if (asset == NATIVE_ASSET) {
            if (amount == 0) revert ZeroAmount();
            if (msg.value != amount) revert NativeValueMismatch(amount, msg.value);
            _deposit(msg.sender, NATIVE_ASSET, amount);
        } else {
            if (amount == 0) revert ZeroAmount();
            _safeTransferFrom(IERC20(asset), msg.sender, address(this), amount);
            _deposit(msg.sender, asset, amount);
        }
    }

    function _deposit(address user, address asset, uint256 amount) internal {
        balances[user][asset] += amount;
        emit Deposited(user, asset, amount);
    }

    // ---------------------------------------------------------------------
    // User: withdrawals (24h delay)
    // ---------------------------------------------------------------------

    /**
     * @notice Request a withdrawal of a specified amount of a supported asset.
     *         Funds are reserved immediately and become claimable after WITHDRAWAL_DELAY.
     * @param asset  Asset address.
     * @param amount Amount to withdraw.
     */
    function requestWithdrawal(address asset, uint256 amount)
        external
        nonReentrant
        onlySupportedAsset(asset)
    {
        if (amount == 0) revert ZeroAmount();

        uint256 available = balances[msg.sender][asset];
        if (available < amount) revert InsufficientBalance(msg.sender, asset, available, amount);

        WithdrawalRequest storage req = pendingWithdrawals[msg.sender];
        if (req.active) revert NoPendingWithdrawal(msg.sender);

        // Reserve funds immediately (checks-effects)
        balances[msg.sender][asset] = available - amount;
        req.asset = asset;
        req.amount = amount;
        req.executableAt = block.timestamp + WITHDRAWAL_DELAY;
        req.active = true;

        emit WithdrawalRequested(msg.sender, asset, amount, req.executableAt);
    }

    /**
     * @notice Cancel a pending withdrawal request, returning reserved funds to balance.
     */
    function cancelWithdrawal() external nonReentrant {
        WithdrawalRequest storage req = pendingWithdrawals[msg.sender];
        if (!req.active) revert NoPendingWithdrawal(msg.sender);

        balances[msg.sender][req.asset] += req.amount;
        delete pendingWithdrawals[msg.sender];
    }

    /**
     * @notice Execute a previously requested withdrawal after the delay has elapsed.
     */
    function executeWithdrawal() external nonReentrant {
        WithdrawalRequest storage req = pendingWithdrawals[msg.sender];
        if (!req.active) revert NoPendingWithdrawal(msg.sender);
        if (block.timestamp < req.executableAt) {
            revert WithdrawalNotYetExecutable(req.executableAt, block.timestamp);
        }

        address asset = req.asset;
        uint256 amount = req.amount;
        delete pendingWithdrawals[msg.sender];

        _transferOut(msg.sender, asset, amount);
        emit Withdrawn(msg.sender, asset, amount);
    }

    // ---------------------------------------------------------------------
    // User: card linkage
    // ---------------------------------------------------------------------

    /**
     * @notice Link a payment card to the caller's account.
     * @param _cardHash Hashed representation of the card identifier.
     */
    function linkCard(bytes32 _cardHash) external {
        if (_cardHash == bytes32(0)) revert InvalidCardHash();
        if (hasCardLinked[msg.sender]) revert CardAlreadyLinked(msg.sender);
        hasCardLinked[msg.sender] = true;
        linkedCardHash[msg.sender] = _cardHash;
        emit CardLinked(msg.sender, _cardHash);
    }

    /**
     * @notice Unlink the payment card from the caller's account.
     */
    function unlinkCard() external {
        if (!hasCardLinked[msg.sender]) revert CardNotLinked(msg.sender);
        delete hasCardLinked[msg.sender];
        delete linkedCardHash[msg.sender];
        emit CardUnlinked(msg.sender);
    }

    // ---------------------------------------------------------------------
    // Operator: payment processing
    // ---------------------------------------------------------------------

    /**
     * @notice Process a payment from a user's balance to a merchant, applying the fee.
     *         The fee remains in the contract as accumulated revenue.
     * @param user     The user whose balance will be debited.
     * @param asset    The asset to use for payment.
     * @param amount   The total amount (including fee) to deduct from the user.
     * @param merchant The recipient of the net payment.
     */
    function processPayment(
        address user,
        address asset,
        uint256 amount,
        address merchant
    ) external onlyOperator nonReentrant onlySupportedAsset(asset) {
        if (amount == 0) revert ZeroAmount();
        if (!hasCardLinked[user]) revert CardNotLinked(user);

        uint256 available = balances[user][asset];
        if (available < amount) revert InsufficientBalance(user, asset, available, amount);

        uint256 fee = (amount * feeBps) / 10000;
        uint256 netAmount = amount - fee;

        // Effects
        balances[user][asset] = available - amount;

        // Interactions: transfer net to merchant; fee retained in contract
        if (asset == NATIVE_ASSET) {
            (bool success, ) = payable(merchant).call{value: netAmount}("");
            if (!success) revert TransferFailed();
        } else {
            _safeTransfer(IERC20(asset), merchant, netAmount);
        }

        emit PaymentProcessed(user, asset, amount, fee, merchant);
    }

    // ---------------------------------------------------------------------
    // Owner: fee withdrawal
    // ---------------------------------------------------------------------

    /**
     * @notice Withdraw accumulated fee revenue for a given asset.
     *         Only excess funds beyond tracked user balances may be withdrawn.
     * @param asset  Asset address.
     * @param amount Amount to withdraw.
     */
    function withdrawFees(address asset, uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 contractBalance = asset == NATIVE_ASSET
            ? address(this).balance
            : IERC20(asset).balanceOf(address(this));

        if (contractBalance < amount) revert InsufficientBalance(address(this), asset, contractBalance, amount);

        _transferOut(msg.sender, asset, amount);
    }

    // ---------------------------------------------------------------------
    // Internal: transfer helpers
    // ---------------------------------------------------------------------

    function _transferOut(address to, address asset, uint256 amount) internal {
        if (asset == NATIVE_ASSET) {
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            _safeTransfer(IERC20(asset), to, amount);
        }
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /**
     * @notice Returns the pending withdrawal request details for a user.
     */
    function getPendingWithdrawal(address user)
        external
        view
        returns (address asset, uint256 amount, uint256 executableAt, bool active)
    {
        WithdrawalRequest memory req = pendingWithdrawals[user];
        return (req.asset, req.amount, req.executableAt, req.active);
    }
}
