// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/// @title RiskHedgingVault
/// @notice Custodies a designated collateral asset and issues principal and swap tokens
///         representing the right to redeem collateral at expiry or swap the reference
///         asset for the collateral asset before expiry.
contract RiskHedgingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error ZeroAddress();
    error ZeroAmount();
    error OnlyOperator();
    error SameAsset();
    error PairNotConfigured();
    error PairAlreadyConfigured();
    error ExpiryInPast();
    error PairHasDeposits();
    error BeforeExpiry();
    error AfterExpiry();
    error MintRatioOutOfBounds(uint256 ratio, uint256 min, uint256 max);
    error InsufficientPrincipalTokens();
    error InsufficientSwapTokens();
    error InsufficientCollateral();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event OperatorSet(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientSet(address indexed previousRecipient, address indexed newRecipient);
    event PairConfigured(address indexed collateralAsset, address indexed referenceAsset, uint256 expiry);
    event MintingRatioUpdated(
        address indexed collateralAsset,
        address indexed referenceAsset,
        uint256 oldRatio,
        uint256 newRatio
    );
    event ExpiryUpdated(
        address indexed collateralAsset,
        address indexed referenceAsset,
        uint256 oldExpiry,
        uint256 newExpiry
    );
    event Minted(
        address indexed user,
        address indexed collateralAsset,
        address indexed referenceAsset,
        uint256 collateralDeposited,
        uint256 principalMinted,
        uint256 swapMinted
    );
    event PrincipalRedeemed(
        address indexed user,
        address indexed collateralAsset,
        address indexed referenceAsset,
        uint256 principalBurned,
        uint256 collateralReturned
    );
    event Swapped(
        address indexed user,
        address indexed collateralAsset,
        address indexed referenceAsset,
        uint256 swapTokensBurned,
        uint256 referenceAssetPaid,
        uint256 collateralReceived,
        uint256 fee
    );

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant RATIO_SCALE = 1e18;
    uint256 public constant MIN_MINT_RATIO = 0.5e18;
    uint256 public constant MAX_MINT_RATIO = 2e18;
    uint256 public constant INITIAL_MINT_RATIO = 1e18;
    uint256 public constant SWAP_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------
    struct PairConfig {
        uint256 mintingRatio;
        uint256 expiryTime;
        uint256 totalCollateralCustodied;
        uint256 totalPrincipalOutstanding;
        uint256 totalSwapOutstanding;
        bool configured;
    }

    struct UserRecord {
        uint256 collateralDeposited;
        uint256 principalTokens;
        uint256 swapTokens;
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    address public operator;
    address public feeRecipient;

    mapping(address => mapping(address => PairConfig)) public pairConfigs;
    mapping(address => mapping(address => mapping(address => UserRecord))) public userRecords;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier configuredPair(address collateralAsset, address referenceAsset) {
        if (!pairConfigs[collateralAsset][referenceAsset].configured) revert PairNotConfigured();
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(address _operator, address _feeRecipient) Ownable(msg.sender) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
    }

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorSet(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientSet(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    // ---------------------------------------------------------------------
    // Operator functions
    // ---------------------------------------------------------------------

    /// @notice Configures a new asset pair with initial 1:1 minting ratio and an expiry time.
    function configurePair(
        address collateralAsset,
        address referenceAsset,
        uint256 expiryTime
    ) external onlyOperator {
        if (collateralAsset == address(0) || referenceAsset == address(0)) revert ZeroAddress();
        if (collateralAsset == referenceAsset) revert SameAsset();
        if (expiryTime <= block.timestamp) revert ExpiryInPast();

        PairConfig storage config = pairConfigs[collateralAsset][referenceAsset];
        if (config.configured) revert PairAlreadyConfigured();

        config.mintingRatio = INITIAL_MINT_RATIO;
        config.expiryTime = expiryTime;
        config.configured = true;

        emit PairConfigured(collateralAsset, referenceAsset, expiryTime);
    }

    /// @notice Updates the minting ratio for an existing pair within allowed bounds.
    function updateMintingRatio(
        address collateralAsset,
        address referenceAsset,
        uint256 newRatio
    ) external onlyOperator configuredPair(collateralAsset, referenceAsset) {
        if (newRatio < MIN_MINT_RATIO || newRatio > MAX_MINT_RATIO) {
            revert MintRatioOutOfBounds(newRatio, MIN_MINT_RATIO, MAX_MINT_RATIO);
        }

        uint256 oldRatio = pairConfigs[collateralAsset][referenceAsset].mintingRatio;
        pairConfigs[collateralAsset][referenceAsset].mintingRatio = newRatio;

        emit MintingRatioUpdated(collateralAsset, referenceAsset, oldRatio, newRatio);
    }

    /// @notice Sets a new expiry for a pair that has no deposits yet.
    function setExpiry(
        address collateralAsset,
        address referenceAsset,
        uint256 newExpiry
    ) external onlyOperator configuredPair(collateralAsset, referenceAsset) {
        if (pairConfigs[collateralAsset][referenceAsset].totalCollateralCustodied > 0) revert PairHasDeposits();
        if (newExpiry <= block.timestamp) revert ExpiryInPast();

        uint256 oldExpiry = pairConfigs[collateralAsset][referenceAsset].expiryTime;
        pairConfigs[collateralAsset][referenceAsset].expiryTime = newExpiry;

        emit ExpiryUpdated(collateralAsset, referenceAsset, oldExpiry, newExpiry);
    }

    // ---------------------------------------------------------------------
    // User functions
    // ---------------------------------------------------------------------

    /// @notice Deposits collateral and mints principal and swap tokens scaled by the
    ///         current minting ratio for the pair.
    function deposit(
        address collateralAsset,
        address referenceAsset,
        uint256 amount
    ) external nonReentrant configuredPair(collateralAsset, referenceAsset) {
        if (amount == 0) revert ZeroAmount();

        PairConfig storage config = pairConfigs[collateralAsset][referenceAsset];
        if (block.timestamp >= config.expiryTime) revert AfterExpiry();

        uint256 mintAmount = (amount * config.mintingRatio) / RATIO_SCALE;

        config.totalCollateralCustodied += amount;
        config.totalPrincipalOutstanding += mintAmount;
        config.totalSwapOutstanding += mintAmount;

        UserRecord storage record = userRecords[collateralAsset][referenceAsset][msg.sender];
        record.collateralDeposited += amount;
        record.principalTokens += mintAmount;
        record.swapTokens += mintAmount;

        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), amount);

        emit Minted(msg.sender, collateralAsset, referenceAsset, amount, mintAmount, mintAmount);
    }

    /// @notice Redeems principal tokens for the collateral asset at expiry.
    function redeem(
        address collateralAsset,
        address referenceAsset,
        uint256 principalAmount
    ) external nonReentrant configuredPair(collateralAsset, referenceAsset) {
        if (principalAmount == 0) revert ZeroAmount();

        PairConfig storage config = pairConfigs[collateralAsset][referenceAsset];
        if (block.timestamp < config.expiryTime) revert BeforeExpiry();

        UserRecord storage record = userRecords[collateralAsset][referenceAsset][msg.sender];
        if (record.principalTokens < principalAmount) revert InsufficientPrincipalTokens();

        uint256 collateralToReturn = (principalAmount * RATIO_SCALE) / config.mintingRatio;
        if (collateralToReturn > record.collateralDeposited) revert InsufficientCollateral();

        record.principalTokens -= principalAmount;
        record.collateralDeposited -= collateralToReturn;
        config.totalPrincipalOutstanding -= principalAmount;
        config.totalCollateralCustodied -= collateralToReturn;

        IERC20(collateralAsset).safeTransfer(msg.sender, collateralToReturn);

        emit PrincipalRedeemed(msg.sender, collateralAsset, referenceAsset, principalAmount, collateralToReturn);
    }

    /// @notice Swaps the reference asset for the collateral asset using swap tokens before
    ///         expiry. A 0.1% fee of the swapped amount is routed to the fee recipient and
    ///         the remainder is custodied by the vault.
    function swap(
        address collateralAsset,
        address referenceAsset,
        uint256 swapTokenAmount
    ) external nonReentrant configuredPair(collateralAsset, referenceAsset) {
        if (swapTokenAmount == 0) revert ZeroAmount();

        PairConfig storage config = pairConfigs[collateralAsset][referenceAsset];
        if (block.timestamp >= config.expiryTime) revert AfterExpiry();

        UserRecord storage record = userRecords[collateralAsset][referenceAsset][msg.sender];
        if (record.swapTokens < swapTokenAmount) revert InsufficientSwapTokens();

        uint256 collateralToReturn = (swapTokenAmount * RATIO_SCALE) / config.mintingRatio;
        if (collateralToReturn > record.collateralDeposited) revert InsufficientCollateral();

        uint256 fee = (swapTokenAmount * SWAP_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netReference = swapTokenAmount - fee;

        record.swapTokens -= swapTokenAmount;
        record.collateralDeposited -= collateralToReturn;
        config.totalSwapOutstanding -= swapTokenAmount;
        config.totalCollateralCustodied -= collateralToReturn;

        if (fee > 0) {
            IERC20(referenceAsset).safeTransferFrom(msg.sender, feeRecipient, fee);
        }
        if (netReference > 0) {
            IERC20(referenceAsset).safeTransferFrom(msg.sender, address(this), netReference);
        }
        IERC20(collateralAsset).safeTransfer(msg.sender, collateralToReturn);

        emit Swapped(
            msg.sender,
            collateralAsset,
            referenceAsset,
            swapTokenAmount,
            swapTokenAmount,
            collateralToReturn,
            fee
        );
    }

    // ---------------------------------------------------------------------
    // View functions
    // ---------------------------------------------------------------------
    function getPairConfig(
        address collateralAsset,
        address referenceAsset
    )
        external
        view
        returns (
            uint256 mintingRatio,
            uint256 expiryTime,
            uint256 totalCollateralCustodied,
            uint256 totalPrincipalOutstanding,
            uint256 totalSwapOutstanding,
            bool configured
        )
    {
        PairConfig storage config = pairConfigs[collateralAsset][referenceAsset];
        return (
            config.mintingRatio,
            config.expiryTime,
            config.totalCollateralCustodied,
            config.totalPrincipalOutstanding,
            config.totalSwapOutstanding,
            config.configured
        );
    }

    function getUserRecord(
        address collateralAsset,
        address referenceAsset,
        address user
    ) external view returns (uint256 collateralDeposited, uint256 principalTokens, uint256 swapTokens) {
        UserRecord storage record = userRecords[collateralAsset][referenceAsset][user];
        return (record.collateralDeposited, record.principalTokens, record.swapTokens);
    }
}
