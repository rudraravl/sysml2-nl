// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract AlgorithmicStablecoin {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error ZeroAddress();
    error AmountZero();
    error InsufficientBalance();
    error InsufficientAllowance();
    error PriceChangeExceedsLimit(uint256 requestedChange, uint256 maxChange);
    error PriceUpdateTooSoon(uint256 timeRemaining);
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(
        address indexed minter,
        address indexed recipient,
        uint256 baseAssetDeposited,
        uint256 feeCollected,
        uint256 stablecoinMinted
    );
    event Burn(
        address indexed burner,
        address indexed recipient,
        uint256 stablecoinBurned,
        uint256 baseAssetReturned
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event TargetPriceUpdated(uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The peg ratio: 1 stablecoin = 0.1 base asset units (in 1e18 precision)
    uint256 public constant PEG_RATIO = 1e17;

    /// @notice Mint fee in basis points (0.5% = 50 bps)
    uint256 public constant MINT_FEE_BPS = 50;

    /// @notice Maximum price change per 24-hour period (0.001 in 1e18 precision)
    uint256 public constant MAX_PRICE_CHANGE_PER_DAY = 1e15;

    /// @notice 24-hour period in seconds
    uint256 public constant ONE_DAY = 1 days;

    /// @notice Basis points denominator
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice Precision factor
    uint256 public constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable baseAsset;

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice Current target price of the base asset in 1e18 precision
    uint256 public targetPrice;

    /// @notice Authorized operator who can adjust the target price
    address public operator;

    /// @notice Timestamp of the last target price update
    uint256 public lastPriceUpdate;

    /// @notice Accumulated fees from minting operations
    uint256 public accumulatedFees;

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert NotOperator();
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

    constructor(
        address _baseAsset,
        address _operator,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialTargetPrice
    ) nonZeroAddress(_baseAsset) nonZeroAddress(_operator) {
        if (_initialTargetPrice == 0) {
            revert AmountZero();
        }

        baseAsset = IERC20(_baseAsset);
        operator = _operator;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        targetPrice = _initialTargetPrice;
        lastPriceUpdate = block.timestamp;

        emit OperatorChanged(address(0), _operator);
        emit TargetPriceUpdated(0, _initialTargetPrice, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                         MINT & BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints stablecoins by depositing base asset. A 0.5% fee is deducted
     *         from the deposited base asset before computing the mint amount.
     * @param recipient The address to receive the minted stablecoins
     * @param baseAssetAmount The amount of base asset to deposit
     * @return minted The amount of stablecoins minted
     */
    function mint(address recipient, uint256 baseAssetAmount)
        external
        nonZeroAddress(recipient)
        returns (uint256 minted)
    {
        if (baseAssetAmount == 0) {
            revert AmountZero();
        }

        uint256 fee = (baseAssetAmount * MINT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 effectiveDeposit = baseAssetAmount - fee;

        // Avoid divide-before-multiply: compute minted directly without
        // intermediate division of (PEG_RATIO * targetPrice) / PRECISION.
        // minted = effectiveDeposit * PRECISION^2 / (PEG_RATIO * targetPrice)
        uint256 denominator = PEG_RATIO * targetPrice;
        if (denominator == 0) {
            revert AmountZero();
        }

        minted = (effectiveDeposit * PRECISION * PRECISION) / denominator;
        if (minted == 0) {
            revert AmountZero();
        }

        // Effects: update state before external interaction
        accumulatedFees += fee;
        totalSupply += minted;
        balanceOf[recipient] += minted;

        // Interaction: pull base asset from caller (from is always msg.sender)
        _safeTransferFrom(address(baseAsset), msg.sender, address(this), baseAssetAmount);

        emit Mint(msg.sender, recipient, baseAssetAmount, fee, minted);
        emit Transfer(address(0), recipient, minted);
    }

    /**
     * @notice Burns stablecoins to redeem the corresponding base asset.
     * @param amount The amount of stablecoins to burn
     * @param recipient The address to receive the redeemed base asset
     * @return returned The amount of base asset returned
     */
    function burn(uint256 amount, address recipient)
        external
        nonZeroAddress(recipient)
        returns (uint256 returned)
    {
        if (amount == 0) {
            revert AmountZero();
        }
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        // Avoid divide-before-multiply: compute returned directly without
        // intermediate division of (PEG_RATIO * targetPrice) / PRECISION.
        // returned = amount * PEG_RATIO * targetPrice / PRECISION^2
        returned = (amount * PEG_RATIO * targetPrice) / PRECISION / PRECISION;

        // Effects: update state before external interaction
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        // Interaction: send base asset to recipient
        _safeTransfer(address(baseAsset), recipient, returned);

        emit Burn(msg.sender, recipient, amount, returned);
        emit Transfer(msg.sender, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC20 TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address recipient, uint256 amount)
        external
        nonZeroAddress(recipient)
        returns (bool)
    {
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        external
        nonZeroAddress(spender)
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        external
        nonZeroAddress(sender)
        nonZeroAddress(recipient)
        returns (bool)
    {
        if (balanceOf[sender] < amount) {
            revert InsufficientBalance();
        }

        uint256 allowed = allowance[sender][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) {
                revert InsufficientAllowance();
            }
            allowance[sender][msg.sender] = allowed - amount;
        }

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR: PRICE ADJUSTMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the target price of the base asset. The price can only
     *         change by at most 0.001 units per 24-hour period.
     * @param newPrice The new target price in 1e18 precision
     */
    function updateTargetPrice(uint256 newPrice) external onlyOperator {
        if (newPrice == 0) {
            revert AmountZero();
        }

        uint256 timeSinceLastUpdate = block.timestamp - lastPriceUpdate;
        if (timeSinceLastUpdate < ONE_DAY) {
            revert PriceUpdateTooSoon(ONE_DAY - timeSinceLastUpdate);
        }

        uint256 priceChange = newPrice > targetPrice
            ? newPrice - targetPrice
            : targetPrice - newPrice;

        if (priceChange > MAX_PRICE_CHANGE_PER_DAY) {
            revert PriceChangeExceedsLimit(priceChange, MAX_PRICE_CHANGE_PER_DAY);
        }

        uint256 oldPrice = targetPrice;
        targetPrice = newPrice;
        lastPriceUpdate = block.timestamp;

        emit TargetPriceUpdated(oldPrice, newPrice, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR: ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the current operator to set a new operator.
     * @param newOperator The address of the new operator
     */
    function setOperator(address newOperator)
        external
        onlyOperator
        nonZeroAddress(newOperator)
    {
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    /**
     * @notice Withdraws accumulated mint fees to a specified recipient.
     * @param recipient The address to receive the fees
     * @param amount The amount of base asset to withdraw
     */
    function withdrawFees(address recipient, uint256 amount)
        external
        onlyOperator
        nonZeroAddress(recipient)
    {
        if (amount == 0) {
            revert AmountZero();
        }
        if (amount > accumulatedFees) {
            revert InsufficientBalance();
        }

        accumulatedFees -= amount;
        _safeTransfer(address(baseAsset), recipient, amount);

        emit FeesWithdrawn(recipient, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of base asset equivalent for a given stablecoin amount.
     * @param stablecoinAmount The amount of stablecoins
     * @return The equivalent base asset amount
     */
    function getBaseAssetValue(uint256 stablecoinAmount) external view returns (uint256) {
        // Avoid divide-before-multiply: multiply before dividing.
        return (stablecoinAmount * PEG_RATIO * targetPrice) / PRECISION / PRECISION;
    }

    /**
     * @notice Returns the amount of stablecoins that would be minted for a given
     *         base asset deposit, accounting for the 0.5% fee.
     * @param baseAssetAmount The amount of base asset to deposit
     * @return The amount of stablecoins that would be minted
     */
    function getMintAmount(uint256 baseAssetAmount) external view returns (uint256) {
        if (baseAssetAmount == 0) return 0;

        uint256 fee = (baseAssetAmount * MINT_FEE_BPS) / BPS_DENOMINATOR;
        uint256 effectiveDeposit = baseAssetAmount - fee;

        uint256 denominator = PEG_RATIO * targetPrice;
        if (denominator == 0) return 0;

        return (effectiveDeposit * PRECISION * PRECISION) / denominator;
    }

    /**
     * @notice Returns the remaining time before the target price can be updated again.
     * @return The remaining time in seconds (0 if update is allowed now)
     */
    function timeUntilNextPriceUpdate() external view returns (uint256) {
        uint256 timeSinceLastUpdate = block.timestamp - lastPriceUpdate;
        if (timeSinceLastUpdate >= ONE_DAY) {
            return 0;
        }
        return ONE_DAY - timeSinceLastUpdate;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Low-level safe transfer that checks the success flag and return data.
     *      Avoids the arbitrary-from pattern by using call directly.
     */
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    /**
     * @dev Low-level safe transferFrom that checks the success flag and return data.
     *      Only called with msg.sender as `from`, preventing arbitrary-send-erc20.
     */
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
