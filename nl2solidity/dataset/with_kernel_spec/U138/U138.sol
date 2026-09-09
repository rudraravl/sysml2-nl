// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

error SafeERC20FailedOperation(address token);

/**
 * @title RealWorldAssetVault
 * @notice A vault for tokenized real-world assets that holds whitelisted ERC-20 tokens
 *         representing fractional ownership of physical goods. Users deposit whitelisted
 *         tokens to receive vault shares, redeem shares for underlying assets (subject to
 *         a redemption fee and minimum share threshold), and transfer shares to others.
 */
contract RealWorldAssetVault {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__NotOperator();
    error Vault__AssetNotWhitelisted(address asset);
    error Vault__AssetAlreadyWhitelisted(address asset);
    error Vault__InsufficientShares(uint256 available, uint256 requested);
    error Vault__RedemptionFeeTooHigh(uint256 fee);
    error Vault__MinimumSharesNotMet(uint256 shares, uint256 minimum);
    error Vault__Paused();
    error Vault__NotPaused();
    error Vault__ZeroAddress();
    error Vault__ZeroAmount();
    error Vault__InsufficientVaultBalance(uint256 available, uint256 required);
    error Vault__AllowanceExceeded(uint256 available, uint256 requested);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Maximum redemption fee in basis points (5%)
    uint256 public constant MAX_REDEMPTION_FEE_BPS = 500;
    /// @notice Minimum shares required to initiate a redemption
    uint256 public constant MIN_SHARES_FOR_REDEMPTION = 100;
    /// @notice Basis points denominator
    uint256 public constant BPS_DENOMINATOR = 10000;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The operator who can manage whitelist, fees, and pause state
    address public operator;

    /// @notice Redemption fee in basis points (e.g., 500 = 5%)
    uint256 public redemptionFeeBps;

    /// @notice Whether deposits and redemptions are paused
    bool public paused;

    /// @notice Mapping of whitelisted assets
    mapping(address => bool) public whitelistedAssets;

    /// @notice List of all whitelisted asset addresses
    address[] public whitelistedAssetList;

    /// @notice User share balances: user => asset => shares
    mapping(address => mapping(address => uint256)) public userShares;

    /// @notice Total shares issued per asset
    mapping(address => uint256) public totalShares;

    /// @notice Share allowances: owner => spender => asset => amount
    mapping(address => mapping(address => mapping(address => uint256))) public shareAllowance;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposited(
        address indexed caller,
        address indexed owner,
        address indexed asset,
        uint256 amount,
        uint256 shares
    );
    event Redeemed(
        address indexed caller,
        address indexed receiver,
        address owner,
        address indexed asset,
        uint256 sharesBurned,
        uint256 assetsReturned,
        uint256 feeCharged
    );
    event SharesTransferred(address indexed from, address indexed to, address indexed asset, uint256 shares);
    event SharesApproved(address indexed owner, address indexed spender, address indexed asset, uint256 shares);
    event RedemptionFeeUpdated(address indexed operator, uint256 oldFeeBps, uint256 newFeeBps);
    event AssetWhitelisted(address indexed operator, address indexed asset);
    event AssetRemovedFromWhitelist(address indexed operator, address indexed asset);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert Vault__NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Vault__Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert Vault__NotPaused();
        _;
    }

    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) revert Vault__ZeroAddress();
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert Vault__ZeroAmount();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _operator, uint256 _redemptionFeeBps) nonZeroAddress(_operator) {
        if (_redemptionFeeBps > MAX_REDEMPTION_FEE_BPS)
            revert Vault__RedemptionFeeTooHigh(_redemptionFeeBps);
        operator = _operator;
        redemptionFeeBps = _redemptionFeeBps;
        emit RedemptionFeeUpdated(address(0), 0, _redemptionFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Whitelist an ERC-20 asset for deposits
     * @param asset The address of the ERC-20 token to whitelist
     */
    function whitelistAsset(address asset)
        external
        onlyOperator
        nonZeroAddress(asset)
    {
        if (whitelistedAssets[asset]) revert Vault__AssetAlreadyWhitelisted(asset);
        whitelistedAssets[asset] = true;
        whitelistedAssetList.push(asset);
        emit AssetWhitelisted(msg.sender, asset);
    }

    /**
     * @notice Remove an asset from the whitelist
     * @param asset The address of the ERC-20 token to remove
     */
    function removeWhitelistedAsset(address asset)
        external
        onlyOperator
        nonZeroAddress(asset)
    {
        if (!whitelistedAssets[asset]) revert Vault__AssetNotWhitelisted(asset);
        whitelistedAssets[asset] = false;
        uint256 len = whitelistedAssetList.length;
        for (uint256 i = 0; i < len; i++) {
            if (whitelistedAssetList[i] == asset) {
                whitelistedAssetList[i] = whitelistedAssetList[len - 1];
                whitelistedAssetList.pop();
                break;
            }
        }
        emit AssetRemovedFromWhitelist(msg.sender, asset);
    }

    /**
     * @notice Update the redemption fee (in basis points)
     * @param newFeeBps New fee in basis points (max 500 = 5%)
     */
    function updateRedemptionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_REDEMPTION_FEE_BPS)
            revert Vault__RedemptionFeeTooHigh(newFeeBps);
        uint256 oldFee = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(msg.sender, oldFee, newFeeBps);
    }

    /**
     * @notice Pause all deposits and redemptions
     */
    function pause() external onlyOperator whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause all deposits and redemptions
     */
    function unpause() external onlyOperator whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Transfer operator role to a new address
     * @param newOperator The address of the new operator
     */
    function transferOperator(address newOperator)
        external
        onlyOperator
        nonZeroAddress(newOperator)
    {
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                          USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit a whitelisted asset and receive vault shares 1:1
     * @param asset The address of the whitelisted ERC-20 token
     * @param amount The amount of tokens to deposit
     * @param receiver The address that will receive the vault shares
     * @return shares The number of vault shares minted
     */
    function deposit(address asset, uint256 amount, address receiver)
        external
        whenNotPaused
        nonZeroAddress(asset)
        nonZeroAddress(receiver)
        nonZeroAmount(amount)
        returns (uint256 shares)
    {
        if (!whitelistedAssets[asset]) revert Vault__AssetNotWhitelisted(asset);

        // Effects: mint shares 1:1 before external transfer (CEI)
        shares = amount;
        userShares[receiver][asset] += shares;
        totalShares[asset] += shares;

        emit Deposited(msg.sender, receiver, asset, amount, shares);

        // Interaction: pull tokens from caller (from is always msg.sender)
        bool success = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!success) revert SafeERC20FailedOperation(asset);
    }

    /**
     * @notice Redeem vault shares for the underlying asset, subject to fee and minimum shares
     * @param asset The address of the whitelisted ERC-20 token
     * @param shares The number of shares to redeem
     * @param receiver The address that will receive the underlying assets
     * @return assetsReturned The net amount of underlying assets returned after fee
     */
    function redeem(address asset, uint256 shares, address receiver)
        external
        whenNotPaused
        nonZeroAddress(asset)
        nonZeroAddress(receiver)
        nonZeroAmount(shares)
        returns (uint256 assetsReturned)
    {
        if (!whitelistedAssets[asset]) revert Vault__AssetNotWhitelisted(asset);
        if (shares < MIN_SHARES_FOR_REDEMPTION)
            revert Vault__MinimumSharesNotMet(shares, MIN_SHARES_FOR_REDEMPTION);
        if (userShares[msg.sender][asset] < shares)
            revert Vault__InsufficientShares(userShares[msg.sender][asset], shares);

        // Calculate fee and net amount (1:1 shares to assets)
        uint256 fee = (shares * redemptionFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = shares - fee;

        uint256 vaultBalance = IERC20(asset).balanceOf(address(this));
        if (vaultBalance < netAmount)
            revert Vault__InsufficientVaultBalance(vaultBalance, netAmount);

        // Effects: burn shares before external transfer (CEI)
        userShares[msg.sender][asset] -= shares;
        totalShares[asset] -= shares;

        emit Redeemed(msg.sender, receiver, msg.sender, asset, shares, netAmount, fee);

        // Interactions: transfer net amount to receiver and fee to operator
        if (netAmount > 0) {
            bool ok = IERC20(asset).transfer(receiver, netAmount);
            if (!ok) revert SafeERC20FailedOperation(asset);
        }
        if (fee > 0) {
            bool okFee = IERC20(asset).transfer(operator, fee);
            if (!okFee) revert SafeERC20FailedOperation(asset);
        }

        assetsReturned = netAmount;
    }

    /**
     * @notice Transfer vault shares of a specific asset to another address
     * @param to The recipient address
     * @param asset The address of the whitelisted ERC-20 token
     * @param shares The number of shares to transfer
     */
    function transferShares(address to, address asset, uint256 shares)
        external
        nonZeroAddress(to)
        nonZeroAddress(asset)
        nonZeroAmount(shares)
    {
        if (userShares[msg.sender][asset] < shares)
            revert Vault__InsufficientShares(userShares[msg.sender][asset], shares);

        userShares[msg.sender][asset] -= shares;
        userShares[to][asset] += shares;

        emit SharesTransferred(msg.sender, to, asset, shares);
    }

    /**
     * @notice Approve another address to transfer vault shares on behalf of the caller
     * @param spender The address approved to transfer shares
     * @param asset The address of the whitelisted ERC-20 token
     * @param shares The number of shares to approve
     */
    function approveShares(address spender, address asset, uint256 shares)
        external
        nonZeroAddress(spender)
        nonZeroAddress(asset)
        returns (bool)
    {
        shareAllowance[msg.sender][spender][asset] = shares;
        emit SharesApproved(msg.sender, spender, asset, shares);
        return true;
    }

    /**
     * @notice Transfer vault shares on behalf of an approved owner
     * @param from The owner of the shares
     * @param to The recipient address
     * @param asset The address of the whitelisted ERC-20 token
     * @param shares The number of shares to transfer
     */
    function transferSharesFrom(address from, address to, address asset, uint256 shares)
        external
        nonZeroAddress(from)
        nonZeroAddress(to)
        nonZeroAddress(asset)
        nonZeroAmount(shares)
        returns (bool)
    {
        if (userShares[from][asset] < shares)
            revert Vault__InsufficientShares(userShares[from][asset], shares);

        uint256 allowed = shareAllowance[from][msg.sender][asset];
        if (allowed < shares)
            revert Vault__AllowanceExceeded(allowed, shares);

        shareAllowance[from][msg.sender][asset] = allowed - shares;
        userShares[from][asset] -= shares;
        userShares[to][asset] += shares;

        emit SharesTransferred(from, to, asset, shares);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the share balance of a user for a specific asset
     * @param user The user address
     * @param asset The asset address
     * @return The number of shares
     */
    function getUserShares(address user, address asset) external view returns (uint256) {
        return userShares[user][asset];
    }

    /**
     * @notice Get the total shares issued for an asset
     * @param asset The asset address
     * @return The total shares
     */
    function getTotalShares(address asset) external view returns (uint256) {
        return totalShares[asset];
    }

    /**
     * @notice Get the number of whitelisted assets
     * @return The count of whitelisted assets
     */
    function getWhitelistedAssetCount() external view returns (uint256) {
        return whitelistedAssetList.length;
    }

    /**
     * @notice Get all whitelisted asset addresses
     * @return Array of whitelisted asset addresses
     */
    function getWhitelistedAssets() external view returns (address[] memory) {
        return whitelistedAssetList;
    }

    /**
     * @notice Get the share allowance of a spender for a specific owner and asset
     * @param owner The owner address
     * @param spender The spender address
     * @param asset The asset address
     * @return The remaining allowance
     */
    function getShareAllowance(address owner, address spender, address asset)
        external
        view
        returns (uint256)
    {
        return shareAllowance[owner][spender][asset];
    }

    /**
     * @notice Preview the net assets returned for redeeming a given number of shares
     * @param asset The asset address
     * @param shares The number of shares to redeem
     * @return netAssets The net assets after fee deduction
     */
    function previewRedeem(address asset, uint256 shares) external view returns (uint256 netAssets) {
        uint256 fee = (shares * redemptionFeeBps) / BPS_DENOMINATOR;
        netAssets = shares - fee;
    }

    /**
     * @notice Preview the fee charged for redeeming a given number of shares
     * @param shares The number of shares to redeem
     * @return fee The fee amount in underlying asset units
     */
    function previewRedeemFee(uint256 shares) external view returns (uint256 fee) {
        fee = (shares * redemptionFeeBps) / BPS_DENOMINATOR;
    }
}
