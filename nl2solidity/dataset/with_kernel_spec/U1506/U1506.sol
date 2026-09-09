// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IOracle {
    /// @notice Returns the price of one unit of `asset` denominated in the collateral token, scaled by 1e18.
    function getPrice(address asset) external view returns (uint256);
}

contract SyntheticAssetVault {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotNominatedOwner();
    error WhenPaused();
    error AssetNotFound();
    error AssetAlreadyExists();
    error CollateralNotAccepted();
    error CollateralAlreadyAccepted();
    error InsufficientCollateral();
    error InsufficientBalance();
    error InvalidRatio();
    error ZeroAddress();
    error ZeroAmount();
    error ReentrantCall();
    error TransferFailed();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed collateral, uint256 amount);
    event SynthMinted(address indexed user, address indexed synthetic, uint256 amount, uint256 fee);
    event SynthRedeemed(address indexed user, address indexed synthetic, uint256 amount, uint256 collateralReturned);
    event SynthTransferred(address indexed from, address indexed to, address indexed synthetic, uint256 amount);
    event SyntheticAssetAdded(address indexed synthetic, address indexed collateral, address oracle, uint256 collateralizationRatio);
    event OracleUpdated(address indexed synthetic, address oldOracle, address newOracle);
    event CollateralizationRatioUpdated(address indexed synthetic, uint256 oldRatio, uint256 newRatio);
    event CollateralAccepted(address indexed collateral);
    event Paused();
    event Unpaused();
    event FeesCollected(address indexed collateral, uint256 amount);
    event OwnerNominated(address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 15000; // 150% in basis points
    uint256 public constant MINT_FEE_BPS = 10;                    // 0.1% in basis points
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------
    struct SyntheticAsset {
        bool exists;
        address collateralToken;
        uint256 collateralizationRatio; // basis points, e.g. 15000 = 150%
        address oracle;
    }

    // -----------------------------------------------------------------------
    // State Variables
    // -----------------------------------------------------------------------
    address public owner;
    address public nominatedOwner;
    bool public paused;
    bool private locked;

    mapping(address => SyntheticAsset) public syntheticAssets;
    address[] public syntheticAssetList;
    mapping(address => address[]) internal _collateralToSynthetics;

    mapping(address => bool) public acceptedCollaterals;
    address[] public acceptedCollateralList;

    mapping(address => uint256) public collateralPools;                              // collateral => total held
    mapping(address => mapping(address => uint256)) public userCollateral;         // user => collateral => amount
    mapping(address => mapping(address => uint256)) public syntheticBalances;      // user => synthetic => amount
    mapping(address => uint256) public accruedFees;                                 // collateral => accumulated fees

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // Ownership (two-step transfer)
    // -----------------------------------------------------------------------
    function nominateOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        nominatedOwner = newOwner;
        emit OwnerNominated(newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != nominatedOwner) revert NotNominatedOwner();
        address oldOwner = owner;
        owner = nominatedOwner;
        nominatedOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    // -----------------------------------------------------------------------
    // Pause
    // -----------------------------------------------------------------------
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    // -----------------------------------------------------------------------
    // Collateral Management
    // -----------------------------------------------------------------------
    function addCollateral(address collateral) external onlyOwner {
        if (collateral == address(0)) revert ZeroAddress();
        if (acceptedCollaterals[collateral]) revert CollateralAlreadyAccepted();
        acceptedCollaterals[collateral] = true;
        acceptedCollateralList.push(collateral);
        emit CollateralAccepted(collateral);
    }

    // -----------------------------------------------------------------------
    // Synthetic Asset Management
    // -----------------------------------------------------------------------
    function addSyntheticAsset(
        address synthetic,
        address collateral,
        address oracle,
        uint256 collateralizationRatio
    ) external onlyOwner {
        if (synthetic == address(0)) revert ZeroAddress();
        if (oracle == address(0)) revert ZeroAddress();
        if (syntheticAssets[synthetic].exists) revert AssetAlreadyExists();
        if (!acceptedCollaterals[collateral]) revert CollateralNotAccepted();
        if (collateralizationRatio < MIN_COLLATERALIZATION_RATIO) revert InvalidRatio();

        syntheticAssets[synthetic] = SyntheticAsset({
            exists: true,
            collateralToken: collateral,
            collateralizationRatio: collateralizationRatio,
            oracle: oracle
        });
        syntheticAssetList.push(synthetic);
        _collateralToSynthetics[collateral].push(synthetic);

        emit SyntheticAssetAdded(synthetic, collateral, oracle, collateralizationRatio);
    }

    function updateOracle(address synthetic, address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert ZeroAddress();
        SyntheticAsset storage asset = syntheticAssets[synthetic];
        if (!asset.exists) revert AssetNotFound();
        address oldOracle = asset.oracle;
        asset.oracle = newOracle;
        emit OracleUpdated(synthetic, oldOracle, newOracle);
    }

    function updateCollateralizationRatio(address synthetic, uint256 newRatio) external onlyOwner {
        if (newRatio < MIN_COLLATERALIZATION_RATIO) revert InvalidRatio();
        SyntheticAsset storage asset = syntheticAssets[synthetic];
        if (!asset.exists) revert AssetNotFound();
        uint256 oldRatio = asset.collateralizationRatio;
        asset.collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(synthetic, oldRatio, newRatio);
    }

    // -----------------------------------------------------------------------
    // Core Operations
    // -----------------------------------------------------------------------

    /// @notice Deposit collateral tokens into the vault.
    function deposit(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!acceptedCollaterals[collateral]) revert CollateralNotAccepted();

        // Interaction: pull collateral from user
        _safeTransferFrom(collateral, msg.sender, address(this), amount);

        // Effects
        userCollateral[msg.sender][collateral] += amount;
        collateralPools[collateral] += amount;

        emit CollateralDeposited(msg.sender, collateral, amount);
    }

    /// @notice Withdraw collateral, subject to maintaining sufficient collateralization.
    function withdraw(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userCollateral[msg.sender][collateral] < amount) revert InsufficientBalance();

        // Effects
        userCollateral[msg.sender][collateral] -= amount;

        // Check: remaining collateral must still back all outstanding synthetics
        uint256 required = _getRequiredCollateral(msg.sender, collateral);
        if (userCollateral[msg.sender][collateral] < required) revert InsufficientCollateral();

        collateralPools[collateral] -= amount;

        // Interaction
        _safeTransfer(collateral, msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, collateral, amount);
    }

    /// @notice Mint synthetic assets against deposited collateral. A 0.1% fee (in collateral) is charged.
    function mint(address synthetic, uint256 amount) external nonReentrant {
        if (paused) revert WhenPaused();
        if (amount == 0) revert ZeroAmount();

        SyntheticAsset memory asset = syntheticAssets[synthetic];
        if (!asset.exists) revert AssetNotFound();

        address collateral = asset.collateralToken;

        // Read oracle price (trusted external call)
        uint256 price = IOracle(asset.oracle).getPrice(synthetic);
        
        // Multiply before divide to avoid precision loss
        uint256 fee = (amount * price * MINT_FEE_BPS) / (PRICE_PRECISION * BPS_DENOMINATOR);

        // Checks: compute required collateral after minting
        uint256 currentRequired = _getRequiredCollateral(msg.sender, collateral);
        uint256 additionalRequired = (amount * price * asset.collateralizationRatio) / (PRICE_PRECISION * BPS_DENOMINATOR);
        uint256 totalRequired = currentRequired + additionalRequired;

        uint256 userColl = userCollateral[msg.sender][collateral];
        if (userColl < fee) revert InsufficientCollateral();
        uint256 availableAfterFee = userColl - fee;
        if (availableAfterFee < totalRequired) revert InsufficientCollateral();

        // Effects
        syntheticBalances[msg.sender][synthetic] += amount;
        userCollateral[msg.sender][collateral] -= fee;
        accruedFees[collateral] += fee;

        emit SynthMinted(msg.sender, synthetic, amount, fee);
    }

    /// @notice Redeem synthetic assets to reclaim collateral at the current oracle price.
    function redeem(address synthetic, uint256 amount) external nonReentrant {
        if (paused) revert WhenPaused();
        if (amount == 0) revert ZeroAmount();

        SyntheticAsset memory asset = syntheticAssets[synthetic];
        if (!asset.exists) revert AssetNotFound();
        if (syntheticBalances[msg.sender][synthetic] < amount) revert InsufficientBalance();

        address collateral = asset.collateralToken;

        // Read oracle price
        uint256 price = IOracle(asset.oracle).getPrice(synthetic);
        uint256 collateralToReturn = (amount * price) / PRICE_PRECISION;

        if (userCollateral[msg.sender][collateral] < collateralToReturn) revert InsufficientCollateral();

        // Effects
        syntheticBalances[msg.sender][synthetic] -= amount;
        userCollateral[msg.sender][collateral] -= collateralToReturn;
        collateralPools[collateral] -= collateralToReturn;

        // Interaction
        _safeTransfer(collateral, msg.sender, collateralToReturn);

        emit SynthRedeemed(msg.sender, synthetic, amount, collateralToReturn);
    }

    /// @notice Transfer synthetic assets to another user. The receiver must have sufficient collateral.
    function transfer(address to, address synthetic, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (syntheticBalances[msg.sender][synthetic] < amount) revert InsufficientBalance();

        SyntheticAsset memory asset = syntheticAssets[synthetic];
        if (!asset.exists) revert AssetNotFound();
        address collateral = asset.collateralToken;

        // Effects
        syntheticBalances[msg.sender][synthetic] -= amount;
        syntheticBalances[to][synthetic] += amount;

        // Check: receiver must be sufficiently collateralized for all their synthetics
        uint256 requiredReceiver = _getRequiredCollateral(to, collateral);
        if (userCollateral[to][collateral] < requiredReceiver) revert InsufficientCollateral();

        emit SynthTransferred(msg.sender, to, synthetic, amount);
    }

    // -----------------------------------------------------------------------
    // Fee Collection
    // -----------------------------------------------------------------------

    /// @notice Owner collects accumulated minting fees for a given collateral type.
    function collectFees(address collateral) external onlyOwner {
        uint256 amount = accruedFees[collateral];
        if (amount == 0) revert ZeroAmount();

        accruedFees[collateral] = 0;
        collateralPools[collateral] -= amount;

        _safeTransfer(collateral, owner, amount);

        emit FeesCollected(collateral, amount);
    }

    // -----------------------------------------------------------------------
    // Internal: Collateralization Calculation
    // -----------------------------------------------------------------------

    /// @dev Computes the total required collateral for a user across all synthetic assets
    ///      backed by the given collateral token, using current oracle prices and ratios.
    function _getRequiredCollateral(address user, address collateral) internal view returns (uint256 required) {
        address[] memory synths = _collateralToSynthetics[collateral];
        uint256 len = synths.length;
        for (uint256 i = 0; i < len; ) {
            address synth = synths[i];
            uint256 balance = syntheticBalances[user][synth];
            if (balance > 0) {
                SyntheticAsset memory asset = syntheticAssets[synth];
                uint256 price = IOracle(asset.oracle).getPrice(synth);
                // Multiply before divide to avoid precision loss
                required += (balance * price * asset.collateralizationRatio) / (PRICE_PRECISION * BPS_DENOMINATOR);
            }
            unchecked {
                ++i;
            }
        }
    }

    // -----------------------------------------------------------------------
    // Internal: Safe ERC20 Operations
    // -----------------------------------------------------------------------

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------

    function getRequiredCollateral(address user, address collateral) external view returns (uint256) {
        return _getRequiredCollateral(user, collateral);
    }

    function getSyntheticAsset(address synthetic)
        external
        view
        returns (
            bool exists,
            address collateralToken,
            uint256 collateralizationRatio,
            address oracle
        )
    {
        SyntheticAsset memory asset = syntheticAssets[synthetic];
        return (asset.exists, asset.collateralToken, asset.collateralizationRatio, asset.oracle);
    }

    function getSyntheticAssetCount() external view returns (uint256) {
        return syntheticAssetList.length;
    }

    function getAcceptedCollateralCount() external view returns (uint256) {
        return acceptedCollateralList.length;
    }

    function getSyntheticsByCollateral(address collateral) external view returns (address[] memory) {
        return _collateralToSynthetics[collateral];
    }

    function getCollateralValue(address synthetic, uint256 amount) external view returns (uint256) {
        SyntheticAsset memory asset = syntheticAssets[synthetic];
        if (!asset.exists) revert AssetNotFound();
        uint256 price = IOracle(asset.oracle).getPrice(synthetic);
        return (amount * price) / PRICE_PRECISION;
    }

    function getSyntheticBalance(address user, address synthetic) external view returns (uint256) {
        return syntheticBalances[user][synthetic];
    }

    function getUserCollateral(address user, address collateral) external view returns (uint256) {
        return userCollateral[user][collateral];
    }
}
