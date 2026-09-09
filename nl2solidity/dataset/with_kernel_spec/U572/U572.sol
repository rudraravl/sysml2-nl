// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface ISyntheticAsset is IERC20 {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }
}

contract SyntheticAssetManager {
    using SafeERC20 for IERC20;

    /* ===================================================
                            CONSTANTS
    =================================================== */

    uint256 public constant WAD = 1e18;
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 1.5e18; // 150%
    uint256 public constant MINT_FEE_RATE = 1e15; // 0.1%

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PARAMETER_ROLE = keccak256("PARAMETER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /* ===================================================
                            DATA TYPES
    =================================================== */

    struct CollateralConfig {
        bool supported;
        uint256 price; // USD per whole token, scaled by 1e18
        uint8 decimals;
    }

    struct SyntheticConfig {
        bool supported;
        uint256 collateralizationRatio; // scaled by 1e18, >= MIN_COLLATERALIZATION_RATIO
        uint256 price; // USD per whole token, scaled by 1e18
        uint8 decimals;
    }

    struct UserPosition {
        mapping(address => uint256) collateralBalances; // collateralToken => raw amount
        mapping(address => uint256) syntheticDebt; // syntheticAsset => raw debt amount
    }

    /* ===================================================
                          CUSTOM ERRORS
    =================================================== */

    error ZeroAddress();
    error AmountZero();
    error CollateralNotSupported();
    error SyntheticNotSupported();
    error InsufficientCollateral();
    error InsufficientBalance();
    error NoOutstandingDebt();
    error AlreadySupported();
    error CollateralizationRatioTooLow();
    error InvalidPrice();
    error EnforcedPause();
    error ReentrantCall();
    error Unauthorized();

    /* ===================================================
                            STATE
    =================================================== */

    mapping(bytes32 => mapping(address => bool)) internal _roles;
    bool internal _paused;
    uint256 internal _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    mapping(address => CollateralConfig) public collateralConfig;
    mapping(address => SyntheticConfig) public syntheticConfig;
    mapping(address => UserPosition) private positions;

    address[] public collateralList;
    address[] public syntheticList;

    mapping(address => uint256) public totalCollateralDeposited;
    mapping(address => uint256) public totalSyntheticDebt;

    address public feeRecipient;

    /* ===================================================
                            EVENTS
    =================================================== */

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event SyntheticMinted(address indexed user, address indexed synthetic, uint256 amount, uint256 fee);
    event SyntheticBurned(address indexed user, address indexed synthetic, uint256 amount);

    event CollateralTokenAdded(address indexed token, uint256 price, uint8 decimals);
    event SyntheticAssetAdded(
        address indexed synthetic,
        uint256 collateralizationRatio,
        uint256 price,
        uint8 decimals
    );
    event SyntheticAssetRemoved(address indexed synthetic);
    event CollateralizationRatioUpdated(address indexed synthetic, uint256 oldRatio, uint256 newRatio);
    event CollateralPriceUpdated(address indexed token, uint256 oldPrice, uint256 newPrice);
    event SyntheticPriceUpdated(address indexed synthetic, uint256 oldPrice, uint256 newPrice);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event Paused(address indexed caller);
    event Unpaused(address indexed caller);

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /* ===================================================
                          MODIFIERS
    =================================================== */

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    modifier onlyRole(bytes32 role) {
        if (!_roles[role][msg.sender]) revert Unauthorized();
        _;
    }

    /* ===================================================
                          CONSTRUCTOR
    =================================================== */

    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PARAMETER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        feeRecipient = _feeRecipient;
        _status = _NOT_ENTERED;
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    /* ===================================================
                        USER FUNCTIONS
    =================================================== */

    /// @notice Deposits a supported collateral token.
    function depositCollateral(address token, uint256 amount) external nonReentrant whenNotPaused {
        if (!collateralConfig[token].supported) revert CollateralNotSupported();
        if (amount == 0) revert AmountZero();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        positions[msg.sender].collateralBalances[token] += amount;
        totalCollateralDeposited[token] += amount;

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /// @notice Withdraws collateral as long as the position remains sufficiently collateralized.
    function withdrawCollateral(address token, uint256 amount) external nonReentrant whenNotPaused {
        if (!collateralConfig[token].supported) revert CollateralNotSupported();
        if (amount == 0) revert AmountZero();

        UserPosition storage pos = positions[msg.sender];
        if (pos.collateralBalances[token] < amount) revert InsufficientBalance();

        pos.collateralBalances[token] -= amount;
        totalCollateralDeposited[token] -= amount;

        if (_totalCollateralValue(msg.sender) < _requiredCollateralValue(msg.sender)) {
            revert InsufficientCollateral();
        }

        IERC20(token).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /// @notice Mints synthetic assets against the caller's collateral. A 0.1% fee is minted to the fee recipient.
    function mintSynthetic(address synthetic, uint256 amount) external nonReentrant whenNotPaused {
        SyntheticConfig storage sc = syntheticConfig[synthetic];
        if (!sc.supported) revert SyntheticNotSupported();
        if (amount == 0) revert AmountZero();

        uint256 fee = (amount * MINT_FEE_RATE) / WAD;

        // Effects: record debt before external calls
        positions[msg.sender].syntheticDebt[synthetic] += amount;
        totalSyntheticDebt[synthetic] += amount;

        // Validation: ensure position is safe after debt increase
        if (_totalCollateralValue(msg.sender) < _requiredCollateralValue(msg.sender)) {
            revert InsufficientCollateral();
        }

        // Interactions: mint tokens to user and fee recipient
        ISyntheticAsset(synthetic).mint(msg.sender, amount);
        if (fee > 0) {
            ISyntheticAsset(synthetic).mint(feeRecipient, fee);
        }

        emit SyntheticMinted(msg.sender, synthetic, amount, fee);
    }

    /// @notice Burns synthetic assets to reduce outstanding debt.
    function burnSynthetic(address synthetic, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert AmountZero();

        UserPosition storage pos = positions[msg.sender];
        uint256 debt = pos.syntheticDebt[synthetic];
        if (debt == 0) revert NoOutstandingDebt();

        uint256 burnAmount = amount > debt ? debt : amount;

        pos.syntheticDebt[synthetic] -= burnAmount;
        totalSyntheticDebt[synthetic] -= burnAmount;

        ISyntheticAsset(synthetic).burnFrom(msg.sender, burnAmount);

        emit SyntheticBurned(msg.sender, synthetic, burnAmount);
    }

    /* ===================================================
                        VIEW FUNCTIONS
    =================================================== */

    function getCollateralBalance(address user, address token) external view returns (uint256) {
        return positions[user].collateralBalances[token];
    }

    function getSyntheticDebt(address user, address synthetic) external view returns (uint256) {
        return positions[user].syntheticDebt[synthetic];
    }

    function totalCollateralValue(address user) external view returns (uint256) {
        return _totalCollateralValue(user);
    }

    function requiredCollateralValue(address user) external view returns (uint256) {
        return _requiredCollateralValue(user);
    }

    function isPositionSafe(address user) external view returns (bool) {
        return _totalCollateralValue(user) >= _requiredCollateralValue(user);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        uint256 required = _requiredCollateralValue(user);
        if (required == 0) return type(uint256).max;
        return (_totalCollateralValue(user) * WAD) / required;
    }

    function collateralListLength() external view returns (uint256) {
        return collateralList.length;
    }

    function syntheticListLength() external view returns (uint256) {
        return syntheticList.length;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    /* ===================================================
                    INTERNAL VALUE LOGIC
    =================================================== */

    function _tokenValue(
        uint256 amount,
        uint256 price,
        uint8 decimals
    ) internal pure returns (uint256) {
        return (amount * price) / (10 ** uint256(decimals));
    }

    function _totalCollateralValue(address user) internal view returns (uint256 total) {
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; i++) {
            address token = collateralList[i];
            uint256 bal = positions[user].collateralBalances[token];
            if (bal == 0) continue;
            CollateralConfig storage c = collateralConfig[token];
            total += _tokenValue(bal, c.price, c.decimals);
        }
    }

    function _requiredCollateralValue(address user) internal view returns (uint256 required) {
        uint256 len = syntheticList.length;
        for (uint256 i = 0; i < len; i++) {
            address syn = syntheticList[i];
            uint256 debt = positions[user].syntheticDebt[syn];
            if (debt == 0) continue;
            SyntheticConfig storage sc = syntheticConfig[syn];
            uint256 debtValue = _tokenValue(debt, sc.price, sc.decimals);
            required += (debtValue * sc.collateralizationRatio) / WAD;
        }
    }

    /* ===================================================
                  ACCESS CONTROL INTERNALS
    =================================================== */

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    /* ===================================================
                      ADMIN: CONFIGURATION
    =================================================== */

    function addCollateralToken(address token, uint256 price) external onlyRole(PARAMETER_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (collateralConfig[token].supported) revert AlreadySupported();
        if (price == 0) revert InvalidPrice();

        uint8 decimals = IERC20(token).decimals();
        collateralConfig[token] = CollateralConfig({
            supported: true,
            price: price,
            decimals: decimals
        });
        collateralList.push(token);

        emit CollateralTokenAdded(token, price, decimals);
    }

    function addSyntheticAsset(
        address synthetic,
        uint256 collateralizationRatio,
        uint256 price
    ) external onlyRole(PARAMETER_ROLE) {
        if (synthetic == address(0)) revert ZeroAddress();
        if (syntheticConfig[synthetic].supported) revert AlreadySupported();
        if (price == 0) revert InvalidPrice();
        if (collateralizationRatio < MIN_COLLATERALIZATION_RATIO) revert CollateralizationRatioTooLow();

        uint8 decimals = ISyntheticAsset(synthetic).decimals();
        syntheticConfig[synthetic] = SyntheticConfig({
            supported: true,
            collateralizationRatio: collateralizationRatio,
            price: price,
            decimals: decimals
        });
        syntheticList.push(synthetic);

        emit SyntheticAssetAdded(synthetic, collateralizationRatio, price, decimals);
    }

    function removeSyntheticAsset(address synthetic) external onlyRole(PARAMETER_ROLE) {
        if (!syntheticConfig[synthetic].supported) revert SyntheticNotSupported();
        syntheticConfig[synthetic].supported = false;
        emit SyntheticAssetRemoved(synthetic);
    }

    function setCollateralizationRatio(
        address synthetic,
        uint256 newRatio
    ) external onlyRole(PARAMETER_ROLE) {
        if (!syntheticConfig[synthetic].supported) revert SyntheticNotSupported();
        if (newRatio < MIN_COLLATERALIZATION_RATIO) revert CollateralizationRatioTooLow();

        uint256 old = syntheticConfig[synthetic].collateralizationRatio;
        syntheticConfig[synthetic].collateralizationRatio = newRatio;

        emit CollateralizationRatioUpdated(synthetic, old, newRatio);
    }

    function setCollateralPrice(address token, uint256 newPrice) external onlyRole(PARAMETER_ROLE) {
        if (!collateralConfig[token].supported) revert CollateralNotSupported();
        if (newPrice == 0) revert InvalidPrice();

        uint256 old = collateralConfig[token].price;
        collateralConfig[token].price = newPrice;

        emit CollateralPriceUpdated(token, old, newPrice);
    }

    function setSyntheticPrice(address synthetic, uint256 newPrice) external onlyRole(PARAMETER_ROLE) {
        if (!syntheticConfig[synthetic].supported) revert SyntheticNotSupported();
        if (newPrice == 0) revert InvalidPrice();

        uint256 old = syntheticConfig[synthetic].price;
        syntheticConfig[synthetic].price = newPrice;

        emit SyntheticPriceUpdated(synthetic, old, newPrice);
    }

    function setFeeRecipient(address newRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    /* ===================================================
                  ADMIN: ROLE MANAGEMENT
    =================================================== */

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(role, account);
    }

    /* ===================================================
                        ADMIN: PAUSE
    =================================================== */

    function pause() external onlyRole(PAUSER_ROLE) {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /* ===================================================
                        ADMIN: RESCUE
    =================================================== */

    /// @notice Allows the admin to recover tokens sent to this contract by accident.
    ///         Supported collateral tokens cannot be rescued to protect user deposits.
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (collateralConfig[token].supported) revert CollateralNotSupported();
        IERC20(token).safeTransfer(to, amount);
    }
}
