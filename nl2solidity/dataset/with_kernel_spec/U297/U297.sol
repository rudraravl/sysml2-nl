// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GovernmentDebtYieldToken
 * @notice A yield-bearing token representing fractional ownership of a basket of
 *         tokenized short-term government debt instruments. Users deposit an
 *         approved stablecoin to mint yield-bearing tokens and can redeem them
 *         for the underlying stablecoin. An authorized administrator may update
 *         the underlying asset value per token, adjust the redemption fee, and
 *         pause deposits and redemptions.
 */
contract GovernmentDebtYieldToken {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAdmin();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidAssetValue();
    error FeeTooHigh();
    error EnforcedPause();
    error EmptyString();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed caller, address indexed receiver, uint256 stablecoinAmount, uint256 sharesMinted);
    event Redeem(address indexed caller, address indexed receiver, uint256 sharesBurned, uint256 stablecoinOut, uint256 fee);
    event AssetValueUpdated(uint256 oldAssetValue, uint256 newAssetValue);
    event RedemptionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event Paused(address account);
    event Unpaused(address account);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The stablecoin accepted for deposits and redemptions.
    address public immutable stablecoin;

    /// @notice The current underlying asset value per token, scaled by 1e18.
    uint256 public assetValuePerToken;

    /// @notice Redemption fee in basis points (1 bps = 0.01%). Fixed at 10 bps (0.1%).
    uint256 public redemptionFeeBps;

    /// @notice Maximum allowed redemption fee in basis points (10%).
    uint256 public constant MAX_FEE_BPS = 1000;

    /// @notice Scaling factor for asset value per token.
    uint256 public constant VALUE_PRECISION = 1e18;

    /// @notice Basis points denominator.
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice Authorized administrator.
    address public admin;

    /// @notice Pause status.
    bool public paused;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert EnforcedPause();
        }
        _;
    }

    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param stablecoin_ The ERC20 stablecoin used for deposits and redemptions.
     * @param name_ The name of the yield-bearing token.
     * @param symbol_ The symbol of the yield-bearing token.
     * @param admin_ The initial administrator address.
     */
    constructor(
        address stablecoin_,
        string memory name_,
        string memory symbol_,
        address admin_
    )
        nonZeroAddress(stablecoin_)
        nonZeroAddress(admin_)
    {
        if (bytes(name_).length == 0) revert EmptyString();
        if (bytes(symbol_).length == 0) revert EmptyString();

        stablecoin = stablecoin_;
        admin = admin_;
        name = name_;
        symbol = symbol_;
        assetValuePerToken = VALUE_PRECISION; // 1:1 initially
        redemptionFeeBps = 10; // 0.1% fixed
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, allowance[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert InsufficientAllowance();
        }
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();

        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) {
            revert InsufficientBalance();
        }

        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        uint256 accountBalance = balanceOf[account];
        if (accountBalance < amount) {
            revert InsufficientBalance();
        }

        balanceOf[account] = accountBalance - amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert InsufficientAllowance();
            }
            allowance[owner][spender] = currentAllowance - amount;
        }
    }

    /*//////////////////////////////////////////////////////////////
                     STABLECOIN SAFE TRANSFER HELPERS
    //////////////////////////////////////////////////////////////*/

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            _revert(data);
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            _revert(data);
        }
    }

    function _revert(bytes memory data) internal pure {
        if (data.length > 0) {
            assembly {
                revert(add(data, 32), mload(data))
            }
        }
        revert();
    }

    function _stablecoinBalanceOf(address account) internal view returns (uint256) {
        (bool success, bytes memory data) = stablecoin.staticcall(
            abi.encodeWithSelector(0x70a08231, account)
        );
        if (!success || data.length < 32) {
            return 0;
        }
        return abi.decode(data, (uint256));
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT / REDEMPTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits stablecoin and mints yield-bearing tokens to the receiver.
     * @param stablecoinAmount The amount of stablecoin to deposit.
     * @param receiver The address that will receive the minted tokens.
     * @return sharesMinted The number of yield-bearing tokens minted.
     */
    function deposit(uint256 stablecoinAmount, address receiver)
        external
        whenNotPaused
        nonZeroAddress(receiver)
        returns (uint256 sharesMinted)
    {
        if (stablecoinAmount == 0) {
            revert ZeroAmount();
        }

        sharesMinted = (stablecoinAmount * VALUE_PRECISION) / assetValuePerToken;
        if (sharesMinted == 0) {
            revert ZeroShares();
        }

        // Effects: mint shares before external transfer (checks-effects-interactions)
        _mint(receiver, sharesMinted);

        // Interactions: pull stablecoin from caller
        _safeTransferFrom(stablecoin, msg.sender, address(this), stablecoinAmount);

        emit Deposit(msg.sender, receiver, stablecoinAmount, sharesMinted);
    }

    /**
     * @notice Redeems yield-bearing tokens for the underlying stablecoin.
     * @param shares The number of yield-bearing tokens to redeem.
     * @param receiver The address that will receive the stablecoin payout.
     * @return stablecoinOut The amount of stablecoin sent to the receiver after fees.
     * @return fee The fee deducted from the gross redemption amount.
     */
    function redeem(uint256 shares, address receiver)
        external
        whenNotPaused
        nonZeroAddress(receiver)
        returns (uint256 stablecoinOut, uint256 fee)
    {
        if (shares == 0) {
            revert ZeroAmount();
        }
        if (balanceOf[msg.sender] < shares) {
            revert InsufficientBalance();
        }

        // Compute fee directly from the full-precision product to avoid
        // divide-before-multiply rounding loss.
        uint256 totalAssets = shares * assetValuePerToken;
        fee = (totalAssets * redemptionFeeBps) / (VALUE_PRECISION * BPS_DENOMINATOR);
        uint256 grossAssets = totalAssets / VALUE_PRECISION;
        stablecoinOut = grossAssets - fee;

        if (stablecoinOut == 0) {
            revert ZeroAmount();
        }
        if (_stablecoinBalanceOf(address(this)) < grossAssets) {
            revert InsufficientBalance();
        }

        // Effects: burn shares before external transfer
        _burn(msg.sender, shares);

        // Interactions: send stablecoin to receiver and fee to admin
        _safeTransfer(stablecoin, receiver, stablecoinOut);
        if (fee > 0) {
            _safeTransfer(stablecoin, admin, fee);
        }

        emit Redeem(msg.sender, receiver, shares, stablecoinOut, fee);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the underlying asset value per token.
     * @param newAssetValue The new asset value per token, scaled by 1e18.
     */
    function setAssetValuePerToken(uint256 newAssetValue) external onlyAdmin {
        if (newAssetValue == 0) {
            revert InvalidAssetValue();
        }
        uint256 oldAssetValue = assetValuePerToken;
        assetValuePerToken = newAssetValue;
        emit AssetValueUpdated(oldAssetValue, newAssetValue);
    }

    /**
     * @notice Updates the redemption fee in basis points.
     * @param newFeeBps The new fee in basis points (max 1000 = 10%).
     */
    function setRedemptionFee(uint256 newFeeBps) external onlyAdmin {
        if (newFeeBps > MAX_FEE_BPS) {
            revert FeeTooHigh();
        }
        uint256 oldFeeBps = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Pauses all deposit and redemption operations.
     */
    function pause() external onlyAdmin {
        if (paused) {
            revert EnforcedPause();
        }
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpauses deposit and redemption operations.
     */
    function unpause() external onlyAdmin {
        if (!paused) {
            revert EnforcedPause();
        }
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Transfers the administrator role to a new address.
     * @param newAdmin The address of the new administrator.
     */
    function transferAdmin(address newAdmin) external onlyAdmin nonZeroAddress(newAdmin) {
        address previousAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(previousAdmin, newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of stablecoin a given number of shares is worth,
     *         before fees.
     * @param shares The number of yield-bearing tokens.
     * @return The gross stablecoin value.
     */
    function convertToStablecoin(uint256 shares) external view returns (uint256) {
        return (shares * assetValuePerToken) / VALUE_PRECISION;
    }

    /**
     * @notice Returns the number of shares that would be minted for a given
     *         stablecoin deposit amount.
     * @param stablecoinAmount The amount of stablecoin to deposit.
     * @return The number of shares that would be minted.
     */
    function convertToShares(uint256 stablecoinAmount) external view returns (uint256) {
        return (stablecoinAmount * VALUE_PRECISION) / assetValuePerToken;
    }

    /**
     * @notice Returns the net stablecoin payout for redeeming a given number of
     *         shares, after the redemption fee.
     * @param shares The number of yield-bearing tokens to redeem.
     * @return payout The net stablecoin amount after fees.
     * @return fee The fee amount.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 payout, uint256 fee) {
        // Compute fee directly from the full-precision product to avoid
        // divide-before-multiply rounding loss.
        uint256 totalAssets = shares * assetValuePerToken;
        fee = (totalAssets * redemptionFeeBps) / (VALUE_PRECISION * BPS_DENOMINATOR);
        uint256 grossAssets = totalAssets / VALUE_PRECISION;
        payout = grossAssets - fee;
    }

    /**
     * @notice Returns the number of shares that would be minted for a given
     *         stablecoin deposit amount (alias for convertToShares).
     * @param stablecoinAmount The amount of stablecoin to deposit.
     * @return The number of shares that would be minted.
     */
    function previewDeposit(uint256 stablecoinAmount) external view returns (uint256) {
        return (stablecoinAmount * VALUE_PRECISION) / assetValuePerToken;
    }
}
