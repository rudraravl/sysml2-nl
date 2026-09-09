// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract VaultInfrastructure {
    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------
    error NotOperator();
    error VaultDoesNotExist();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientShares();
    error ReserveViolation();
    error MaxSharesExceeded();
    error TransferFailed();
    error SelfTransfer();
    error ReentrancyDetected();

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint256 public constant MIN_RESERVE = 100;
    uint256 public constant MAX_SHARES = 1_000_000;

    // -------------------------------------------------------------------------
    // Vault Structure
    // -------------------------------------------------------------------------
    struct Vault {
        address underlyingAsset;
        uint256 totalTokens;
        uint256 totalShares;
        bool exists;
    }

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------
    address public operator;

    /// @dev Reentrancy guard status: 1 = not entered, 2 = entered.
    uint256 private _reentrancyStatus = 1;

    mapping(uint256 => Vault) public vaults;
    mapping(uint256 => mapping(address => uint256)) public userDeposits;
    mapping(uint256 => mapping(address => uint256)) public userShares;

    uint256 public nextVaultId;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event VaultCreated(uint256 indexed vaultId, address indexed underlyingAsset, address indexed creator);
    event VaultAssetUpdated(uint256 indexed vaultId, address indexed oldAsset, address indexed newAsset);
    event Deposited(uint256 indexed vaultId, address indexed depositor, uint256 amount, uint256 sharesMinted);
    event Withdrawn(uint256 indexed vaultId, address indexed withdrawer, uint256 sharesBurned, uint256 amount);
    event SharesTransferred(uint256 indexed vaultId, address indexed from, address indexed to, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier vaultExists(uint256 vaultId) {
        if (!vaults[vaultId].exists) revert VaultDoesNotExist();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus != 1) revert ReentrancyDetected();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor() {
        operator = msg.sender;
        nextVaultId = 1;
        emit OperatorUpdated(address(0), msg.sender);
    }

    // -------------------------------------------------------------------------
    // Operator Functions
    // -------------------------------------------------------------------------

    /// @notice Creates a new vault with the specified underlying ERC20 asset.
    /// @param underlyingAsset The ERC20 token address the vault will accept.
    /// @return vaultId The ID of the newly created vault.
    function createVault(address underlyingAsset) external onlyOperator returns (uint256 vaultId) {
        if (underlyingAsset == address(0)) revert ZeroAddress();

        vaultId = nextVaultId++;
        vaults[vaultId] = Vault({
            underlyingAsset: underlyingAsset,
            totalTokens: 0,
            totalShares: 0,
            exists: true
        });

        emit VaultCreated(vaultId, underlyingAsset, msg.sender);
    }

    /// @notice Updates the underlying asset address for an existing vault.
    /// @param vaultId The ID of the vault to update.
    /// @param newAsset The new underlying ERC20 token address.
    function updateVaultAsset(uint256 vaultId, address newAsset) external onlyOperator vaultExists(vaultId) {
        if (newAsset == address(0)) revert ZeroAddress();

        address oldAsset = vaults[vaultId].underlyingAsset;
        vaults[vaultId].underlyingAsset = newAsset;

        emit VaultAssetUpdated(vaultId, oldAsset, newAsset);
    }

    /// @notice Transfers operator privileges to a new address.
    /// @param newOperator The address of the new operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    // -------------------------------------------------------------------------
    // User Functions
    // -------------------------------------------------------------------------

    /// @notice Deposits underlying tokens into a vault and receives vault shares 1:1.
    /// @param vaultId The ID of the target vault.
    /// @param amount The amount of underlying tokens to deposit.
    function deposit(uint256 vaultId, uint256 amount) external nonReentrant vaultExists(vaultId) {
        if (amount == 0) revert ZeroAmount();

        Vault storage vault = vaults[vaultId];

        // Enforce maximum shares cap.
        if (vault.totalShares + amount > MAX_SHARES) revert MaxSharesExceeded();

        // Enforce minimum reserve: vault must hold at least MIN_RESERVE tokens after deposit.
        if (vault.totalTokens + amount < MIN_RESERVE) revert ReserveViolation();

        // Transfer tokens from depositor to this contract.
        IERC20 asset = IERC20(vault.underlyingAsset);
        if (!asset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        // Effects: update vault and user balances (1:1 share-to-token ratio).
        vault.totalTokens += amount;
        vault.totalShares += amount;
        userDeposits[vaultId][msg.sender] += amount;
        userShares[vaultId][msg.sender] += amount;

        emit Deposited(vaultId, msg.sender, amount, amount);
    }

    /// @notice Withdraws underlying tokens by redeeming vault shares.
    /// @param vaultId The ID of the vault to withdraw from.
    /// @param shareAmount The number of vault shares to redeem.
    function withdraw(uint256 vaultId, uint256 shareAmount) external nonReentrant vaultExists(vaultId) {
        if (shareAmount == 0) revert ZeroAmount();

        Vault storage vault = vaults[vaultId];

        if (userShares[vaultId][msg.sender] < shareAmount) revert InsufficientShares();

        // Enforce minimum reserve: vault must retain at least MIN_RESERVE tokens.
        if (vault.totalTokens < shareAmount) revert InsufficientShares();
        if (vault.totalTokens - shareAmount < MIN_RESERVE) revert ReserveViolation();

        // 1:1 redemption: each share equals one underlying token.
        uint256 tokenAmount = shareAmount;

        // Effects: burn shares and reduce balances before external call.
        userShares[vaultId][msg.sender] -= shareAmount;
        userDeposits[vaultId][msg.sender] -= shareAmount;
        vault.totalShares -= shareAmount;
        vault.totalTokens -= shareAmount;

        // Interactions: transfer underlying tokens to the withdrawer.
        IERC20 asset = IERC20(vault.underlyingAsset);
        if (!asset.transfer(msg.sender, tokenAmount)) revert TransferFailed();

        emit Withdrawn(vaultId, msg.sender, shareAmount, tokenAmount);
    }

    /// @notice Transfers vault shares (and corresponding deposit claims) to another address.
    /// @param vaultId The ID of the vault.
    /// @param to The recipient address.
    /// @param amount The number of shares to transfer.
    function transferShares(uint256 vaultId, address to, uint256 amount) external nonReentrant vaultExists(vaultId) {
        if (to == address(0)) revert ZeroAddress();
        if (to == msg.sender) revert SelfTransfer();
        if (amount == 0) revert ZeroAmount();
        if (userShares[vaultId][msg.sender] < amount) revert InsufficientShares();

        // Effects: move shares and deposit balances.
        userShares[vaultId][msg.sender] -= amount;
        userShares[vaultId][to] += amount;
        userDeposits[vaultId][msg.sender] -= amount;
        userDeposits[vaultId][to] += amount;

        emit SharesTransferred(vaultId, msg.sender, to, amount);
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------

    /// @notice Returns vault information.
    /// @param vaultId The vault ID.
    /// @return underlyingAsset The ERC20 token address.
    /// @return totalTokens Total tokens held by the vault.
    /// @return totalShares Total shares issued by the vault.
    function getVaultInfo(uint256 vaultId)
        external
        view
        vaultExists(vaultId)
        returns (address underlyingAsset, uint256 totalTokens, uint256 totalShares)
    {
        Vault storage vault = vaults[vaultId];
        return (vault.underlyingAsset, vault.totalTokens, vault.totalShares);
    }

    /// @notice Returns a user's deposit and share balance for a given vault.
    /// @param vaultId The vault ID.
    /// @param user The user address.
    /// @return depositBalance The user's recorded token deposit.
    /// @return shareBalance The user's vault share balance.
    function getUserInfo(uint256 vaultId, address user)
        external
        view
        vaultExists(vaultId)
        returns (uint256 depositBalance, uint256 shareBalance)
    {
        return (userDeposits[vaultId][user], userShares[vaultId][user]);
    }

    /// @notice Returns the total number of vaults created.
    /// @return count The count of vaults.
    function vaultCount() external view returns (uint256) {
        return nextVaultId - 1;
    }
}
