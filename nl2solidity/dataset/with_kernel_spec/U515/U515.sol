// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title FractionalizedDebtPool
 * @notice Tokenizes a pool of fractionalized real-world debt instruments. Custodies
 *         stablecoin collateral and issues asset tokens proportional to deposits.
 */
contract FractionalizedDebtPool {
    //--------------------------------------------------------------------------------
    // Constants
    //--------------------------------------------------------------------------------
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_REDEMPTION_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_FEE_BPS = 500; // 5% hard cap
    uint256 public constant SUPPLY_HARD_CAP = 10_000_000 * 10 ** 18; // 10M units

    //--------------------------------------------------------------------------------
    // Immutables
    //--------------------------------------------------------------------------------
    IERC20 public immutable stablecoin;

    //--------------------------------------------------------------------------------
    // ERC20 Metadata
    //--------------------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    //--------------------------------------------------------------------------------
    // ERC20 State
    //--------------------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    //--------------------------------------------------------------------------------
    // Pool State
    //--------------------------------------------------------------------------------
    address public owner;
    address public operator;
    uint256 public redemptionFeeBps;
    uint256 public maxTotalSupply;
    address public feeRecipient;

    /// @notice Total stablecoin collateral currently custodied by the pool.
    uint256 public totalCollateral;

    /// @notice Per-user record of stablecoin deposited (historical gross deposits).
    mapping(address => uint256) public depositedStablecoin;

    //--------------------------------------------------------------------------------
    // Events
    //--------------------------------------------------------------------------------
    event Deposit(address indexed depositor, uint256 stablecoinAmount, uint256 assetTokensMinted);
    event Redemption(address indexed redeemer, uint256 assetTokensBurned, uint256 stablecoinReturned, uint256 feeTaken);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RedemptionFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MaxTotalSupplyUpdated(uint256 oldCap, uint256 newCap);
    event OperatorUpdated(address oldOperator, address newOperator);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    //--------------------------------------------------------------------------------
    // Errors
    //--------------------------------------------------------------------------------
    error ZeroAddress();
    error AmountZero();
    error ExceedsMaxTotalSupply(uint256 requested, uint256 available);
    error InsufficientBalance();
    error InsufficientAllowance();
    error FeeExceedsCap(uint256 feeBps, uint256 maxBps);
    error SupplyCapExceedsHardCap(uint256 cap, uint256 hardCap);
    error MaxTotalSupplyBelowCurrent(uint256 newCap, uint256 currentSupply);
    error OnlyOwner();
    error OnlyOperator();
    error StablecoinTransferFailed();
    error StablecoinTransferFromFailed();
    error NoSupplyAvailable();

    //--------------------------------------------------------------------------------
    // Modifiers
    //--------------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    //--------------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------------
    constructor(
        address _stablecoin,
        address _owner,
        address _operator,
        address _feeRecipient,
        string memory _name,
        string memory _symbol
    ) {
        if (_stablecoin == address(0) || _owner == address(0) || _operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        owner = _owner;
        operator = _operator;
        feeRecipient = _feeRecipient == address(0) ? _owner : _feeRecipient;
        redemptionFeeBps = DEFAULT_REDEMPTION_FEE_BPS;
        maxTotalSupply = SUPPLY_HARD_CAP;
        name = _name;
        symbol = _symbol;

        emit OwnershipTransferred(address(0), _owner);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), feeRecipient);
        emit RedemptionFeeUpdated(0, redemptionFeeBps);
        emit MaxTotalSupplyUpdated(0, maxTotalSupply);
    }

    //--------------------------------------------------------------------------------
    // ERC20 Core
    //--------------------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        if (currentAllowance != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = currentAllowance - amount;
            }
        }

        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, allowance[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        if (tokenOwner == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (totalSupply + amount > maxTotalSupply) {
            revert ExceedsMaxTotalSupply(amount, maxTotalSupply - totalSupply);
        }

        unchecked {
            totalSupply += amount;
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    //--------------------------------------------------------------------------------
    // Pool Operations
    //--------------------------------------------------------------------------------

    /**
     * @notice Deposit stablecoins to receive asset tokens at the current exchange rate.
     * @param stablecoinAmount The amount of stablecoins to deposit.
     * @return assetTokensMinted The number of asset tokens minted.
     */
    function deposit(uint256 stablecoinAmount) external returns (uint256 assetTokensMinted) {
        if (stablecoinAmount == 0) revert AmountZero();

        // Pull stablecoins from depositor (checks-effects-interactions)
        uint256 balanceBefore = stablecoin.balanceOf(address(this));
        bool ok = stablecoin.transferFrom(msg.sender, address(this), stablecoinAmount);
        if (!ok) revert StablecoinTransferFromFailed();
        uint256 received = stablecoin.balanceOf(address(this)) - balanceBefore;

        // Calculate asset tokens to mint based on current pool ratio.
        // Guard against uninitialized pool using a single inequality check.
        if (totalSupply <= 0) {
            assetTokensMinted = received;
        } else {
            assetTokensMinted = (received * totalSupply) / totalCollateral;
        }

        // Update collateral and user deposit record before minting.
        totalCollateral += received;
        depositedStablecoin[msg.sender] += received;

        _mint(msg.sender, assetTokensMinted);

        emit Deposit(msg.sender, received, assetTokensMinted);
    }

    /**
     * @notice Redeem asset tokens for stablecoins. A redemption fee is deducted
     *         from the stablecoin amount and sent to the fee recipient.
     * @param assetTokenAmount The number of asset tokens to redeem.
     * @return stablecoinReturned The stablecoins sent to the redeemer (net of fee).
     */
    function redeem(uint256 assetTokenAmount) external returns (uint256 stablecoinReturned) {
        if (assetTokenAmount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < assetTokenAmount) revert InsufficientBalance();
        if (totalSupply <= 0) revert NoSupplyAvailable();

        // Compute the gross stablecoin value and fee from the full product
        // before any division to avoid divide-before-multiply precision loss.
        uint256 grossValue = assetTokenAmount * totalCollateral;
        uint256 fee = (grossValue * redemptionFeeBps) / (totalSupply * FEE_DENOMINATOR);
        uint256 stablecoinEquivalent = grossValue / totalSupply;
        stablecoinReturned = stablecoinEquivalent - fee;

        // Burn asset tokens first (checks-effects-interactions).
        _burn(msg.sender, assetTokenAmount);

        // Reduce collateral tracked by the pool.
        totalCollateral -= stablecoinEquivalent;

        // Transfer stablecoins to redeemer.
        bool ok = stablecoin.transfer(msg.sender, stablecoinReturned);
        if (!ok) revert StablecoinTransferFailed();

        // Transfer fee to fee recipient.
        if (fee > 0) {
            bool feeOk = stablecoin.transfer(feeRecipient, fee);
            if (!feeOk) revert StablecoinTransferFailed();
        }

        emit Redemption(msg.sender, assetTokenAmount, stablecoinReturned, fee);
    }

    //--------------------------------------------------------------------------------
    // Operator Functions
    //--------------------------------------------------------------------------------

    /**
     * @notice Update the stablecoin redemption fee (in basis points).
     * @param newFeeBps The new fee in basis points (max 500 = 5%).
     */
    function setRedemptionFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeExceedsCap(newFeeBps, MAX_FEE_BPS);
        uint256 oldFee = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(oldFee, newFeeBps);
    }

    /**
     * @notice Update the maximum total supply of asset tokens. Cannot exceed the hard cap.
     * @param newCap The new maximum total supply.
     */
    function setMaxTotalSupply(uint256 newCap) external onlyOperator {
        if (newCap > SUPPLY_HARD_CAP) revert SupplyCapExceedsHardCap(newCap, SUPPLY_HARD_CAP);
        if (newCap < totalSupply) revert MaxTotalSupplyBelowCurrent(newCap, totalSupply);
        uint256 oldCap = maxTotalSupply;
        maxTotalSupply = newCap;
        emit MaxTotalSupplyUpdated(oldCap, newCap);
    }

    /**
     * @notice Update the fee recipient address.
     */
    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    //--------------------------------------------------------------------------------
    // Owner Functions
    //--------------------------------------------------------------------------------

    /**
     * @notice Transfer contract ownership to a new address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    /**
     * @notice Update the operator address.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    //--------------------------------------------------------------------------------
    // View Functions
    //--------------------------------------------------------------------------------

    /**
     * @notice Returns the stablecoin collateral currently custodied by the pool.
     */
    function totalCollateralBalance() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    /**
     * @notice Computes the fee and net stablecoin payout for a given redemption amount.
     */
    function previewRedeem(uint256 assetTokenAmount) external view returns (uint256 netPayout, uint256 fee) {
        if (totalSupply <= 0) {
            return (0, 0);
        }
        // Compute fee from the full product before division to avoid
        // divide-before-multiply precision loss.
        uint256 grossValue = assetTokenAmount * totalCollateral;
        fee = (grossValue * redemptionFeeBps) / (totalSupply * FEE_DENOMINATOR);
        uint256 stablecoinEquivalent = grossValue / totalSupply;
        netPayout = stablecoinEquivalent - fee;
    }

    /**
     * @notice Computes the asset tokens that would be minted for a given deposit.
     */
    function previewDeposit(uint256 stablecoinAmount) external view returns (uint256 assetTokensMinted) {
        if (totalSupply <= 0) {
            return stablecoinAmount;
        }
        return (stablecoinAmount * totalSupply) / totalCollateral;
    }
}
