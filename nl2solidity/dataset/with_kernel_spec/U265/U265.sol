// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title DecentralizedStablecoin
 * @notice A collateral-backed stablecoin system. Users deposit an ERC20
 *         collateral asset, mint stable tokens against their deposited
 *         collateral at a configurable collateralization ratio, redeem
 *         stable tokens to recover collateral (minus a fee), and withdraw
 *         unencumbered (free) collateral. A designated operator can
 *         adjust the collateralization ratio and pause minting/redemption.
 */
contract DecentralizedStablecoin {
    // --------------------------------------------------------------
    //  Custom Errors
    // --------------------------------------------------------------
    error ZeroAmount();
    error ZeroAddress();
    error Unauthorized();
    error MintingPaused();
    error RedemptionPaused();
    error InsufficientCollateral();
    error InsufficientStableBalance();
    error InsufficientFreeCollateral();
    error CollateralTransferFailed();
    error InvalidCollateralizationRatio();

    // --------------------------------------------------------------
    //  Events
    // --------------------------------------------------------------
    event CollateralDeposited(address indexed account, uint256 amount);
    event CollateralWithdrawn(address indexed account, uint256 amount);
    event StableMinted(address indexed account, uint256 amount);
    event StableRedeemed(
        address indexed account,
        uint256 stableAmount,
        uint256 collateralReturned,
        uint256 fee
    );
    event CollateralizationRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event MintingPausedChanged(bool paused);
    event RedemptionPausedChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesCollected(address indexed collector, uint256 amount);

    // --------------------------------------------------------------
    //  Constants
    // --------------------------------------------------------------
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant REDEMPTION_FEE_BPS = 50; // 0.5%

    string public constant name = "Decentralized Stablecoin";
    string public constant symbol = "DSC";
    uint8 public constant decimals = 18;

    // --------------------------------------------------------------
    //  Immutable
    // --------------------------------------------------------------
    IERC20 public immutable collateral;

    // --------------------------------------------------------------
    //  State Variables
    // --------------------------------------------------------------
    address public operator;
    uint256 public collateralizationRatio; // 1e18 precision, 1.5e18 = 150%
    bool public mintingPaused;
    bool public redemptionPaused;
    uint256 public totalStableSupply;
    uint256 public totalCollateralReserve;
    uint256 public accumulatedFees;

    mapping(address => uint256) public stableBalances;
    mapping(address => uint256) public collateralBalances;

    // --------------------------------------------------------------
    //  Modifiers
    // --------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // --------------------------------------------------------------
    //  Constructor
    // --------------------------------------------------------------
    /**
     * @param _collateral The ERC20 token used as collateral.
     * @param _operator   The address authorized to adjust parameters.
     */
    constructor(address _collateral, address _operator) {
        if (_collateral == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        collateral = IERC20(_collateral);
        operator = _operator;
        collateralizationRatio = 1.5e18; // 150%
    }

    // --------------------------------------------------------------
    //  Internal — Safe ERC20 Helpers
    // --------------------------------------------------------------
    /**
     * @dev Performs a transferFrom that tolerates tokens which do not
     *      return a bool (e.g. USDT-style). Reverts on failure.
     */
    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(collateral).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success) revert CollateralTransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert CollateralTransferFailed();
    }

    /**
     * @dev Performs a transfer that tolerates tokens which do not
     *      return a bool (e.g. USDT-style). Reverts on failure.
     */
    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(collateral).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert CollateralTransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert CollateralTransferFailed();
    }

    // --------------------------------------------------------------
    //  Collateral Management
    // --------------------------------------------------------------

    /**
     * @notice Deposit collateral into the system, crediting the caller.
     * @param amount The amount of collateral to deposit.
     */
    function depositCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        // Effects
        collateralBalances[msg.sender] += amount;
        totalCollateralReserve += amount;

        // Interaction
        _safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw unencumbered (free) collateral that is not
     *         required to back the caller's outstanding stable tokens.
     * @param amount The amount of collateral to withdraw.
     */
    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 available = getAvailableCollateral(msg.sender);
        if (amount > available) revert InsufficientFreeCollateral();

        // Effects
        collateralBalances[msg.sender] -= amount;
        totalCollateralReserve -= amount;

        // Interaction
        _safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    // --------------------------------------------------------------
    //  Stable Token — Mint & Redeem
    // --------------------------------------------------------------

    /**
     * @notice Mint stable tokens against the caller's deposited collateral.
     *         The caller must have sufficient unencumbered collateral to
     *         satisfy the collateralization ratio for the minted amount.
     * @param amount The amount of stable tokens to mint (1e18 precision).
     */
    function mint(uint256 amount) external {
        if (mintingPaused) revert MintingPaused();
        if (amount == 0) revert ZeroAmount();

        uint256 requiredCollateral = (amount * collateralizationRatio) / PRECISION;
        uint256 available = getAvailableCollateral(msg.sender);
        if (requiredCollateral > available) revert InsufficientCollateral();

        // Effects
        stableBalances[msg.sender] += amount;
        totalStableSupply += amount;

        emit StableMinted(msg.sender, amount);
    }

    /**
     * @notice Redeem stable tokens for collateral. Burns the caller's
     *         stable tokens and returns collateral at a 1:1 rate minus
     *         a 0.5% fee deducted from the returned amount. The fee
     *         accumulates as protocol revenue in the collateral reserve.
     * @param amount The amount of stable tokens to redeem.
     */
    function redeem(uint256 amount) external {
        if (redemptionPaused) revert RedemptionPaused();
        if (amount == 0) revert ZeroAmount();
        if (stableBalances[msg.sender] < amount) revert InsufficientStableBalance();

        // Fee: 0.5% of the redeemed stable amount, taken from the
        // returned collateral. The over-collateralization remains
        // as the caller's free collateral.
        uint256 fee = (amount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 collateralToReturn = amount - fee;

        // Effects — burn stable tokens and reduce the caller's
        // collateral balance by the face value of the stable amount.
        stableBalances[msg.sender] -= amount;
        totalStableSupply -= amount;
        collateralBalances[msg.sender] -= amount;
        totalCollateralReserve -= collateralToReturn;
        accumulatedFees += fee;

        // Interaction
        _safeTransfer(msg.sender, collateralToReturn);

        emit StableRedeemed(msg.sender, amount, collateralToReturn, fee);
    }

    // --------------------------------------------------------------
    //  Views
    // --------------------------------------------------------------

    /**
     * @notice Returns the amount of unencumbered collateral an account
     *         can withdraw or use to mint additional stable tokens.
     * @param account The account to query.
     * @return The available collateral amount.
     */
    function getAvailableCollateral(address account) public view returns (uint256) {
        uint256 locked = (stableBalances[account] * collateralizationRatio) / PRECISION;
        if (collateralBalances[account] > locked) {
            return collateralBalances[account] - locked;
        }
        return 0;
    }

    /**
     * @notice Returns the stable token balance of an account.
     */
    function balanceOf(address account) external view returns (uint256) {
        return stableBalances[account];
    }

    /**
     * @notice Returns the total supply of the stable token.
     */
    function totalSupply() external view returns (uint256) {
        return totalStableSupply;
    }

    // --------------------------------------------------------------
    //  Operator Functions
    // --------------------------------------------------------------

    /**
     * @notice Update the collateralization ratio. Must be at least 100%.
     * @param newRatio The new ratio in 1e18 precision (e.g., 1.5e18 = 150%).
     */
    function setCollateralizationRatio(uint256 newRatio) external onlyOperator {
        if (newRatio < PRECISION) revert InvalidCollateralizationRatio();
        uint256 oldRatio = collateralizationRatio;
        collateralizationRatio = newRatio;
        emit CollateralizationRatioUpdated(oldRatio, newRatio);
    }

    /**
     * @notice Pause or unpause stable token minting.
     * @param paused True to pause, false to unpause.
     */
    function setMintingPaused(bool paused) external onlyOperator {
        mintingPaused = paused;
        emit MintingPausedChanged(paused);
    }

    /**
     * @notice Pause or unpause stable token redemption.
     * @param paused True to pause, false to unpause.
     */
    function setRedemptionPaused(bool paused) external onlyOperator {
        redemptionPaused = paused;
        emit RedemptionPausedChanged(paused);
    }

    /**
     * @notice Transfer the operator role to a new address.
     * @param newOperator The new operator address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Collect accumulated redemption fees to a recipient.
     * @param recipient The address to receive the fees.
     */
    function collectFees(address recipient) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 fees = accumulatedFees;
        if (fees == 0) revert ZeroAmount();

        accumulatedFees = 0;
        totalCollateralReserve -= fees;

        _safeTransfer(recipient, fees);

        emit FeesCollected(recipient, fees);
    }
}
