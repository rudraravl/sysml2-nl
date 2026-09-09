// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StablecoinProtocol
 * @notice A decentralized stablecoin protocol that custodies a reserve cryptocurrency
 *         and issues a fiat-pegged stable token and a volatility-absorbing reserve token.
 *         The stable token is over-collateralized at a minimum 400% ratio by the reserve
 *         cryptocurrency, and a 0.5% fee is applied to all stable token redemptions.
 */
contract StablecoinProtocol {
    // ============ Constants ============
    uint8 public constant DECIMALS = 18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;

    string public constant STABLE_NAME = "Decentralized Stable USD";
    string public constant STABLE_SYMBOL = "dUSD";
    string public constant RESERVE_TOKEN_NAME = "Protocol Reserve Token";
    string public constant RESERVE_TOKEN_SYMBOL = "pRES";

    // ============ State — Supplies & Pool ============
    uint256 public stableSupply;
    uint256 public reserveTokenSupply;
    uint256 public reserveBalance; // total reserve crypto (ETH) custodied

    // ============ State — Oracle ============
    uint256 public oraclePriceFeed; // fiat per reserve unit, 18 decimals
    uint256 public lastOracleUpdate;

    // ============ State — Parameters ============
    uint256 public collateralRatioBps; // 40000 = 400%
    uint256 public redemptionFeeBps;   // 50 = 0.5%

    // ============ State — Access Control ============
    address public operator;
    address public admin;

    // ============ Mappings — Token Balances & Allowances ============
    mapping(address => uint256) public stableBalances;
    mapping(address => uint256) public reserveTokenBalances;
    mapping(address => mapping(address => uint256)) public stableAllowances;
    mapping(address => mapping(address => uint256)) public reserveTokenAllowances;

    // ============ Reentrancy Guard ============
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus;

    // ============ Events ============
    event StableMinted(address indexed user, uint256 reserveDeposited, uint256 stableMinted);
    event StableRedeemed(address indexed user, uint256 stableBurned, uint256 reserveReturned, uint256 feeCollected);
    event ReserveTokenMinted(address indexed user, uint256 reserveDeposited, uint256 reserveTokensMinted);
    event ReserveTokenRedeemed(address indexed user, uint256 reserveTokensBurned, uint256 reserveReturned);
    event OracleUpdated(uint256 newPrice, uint256 timestamp);
    event ParametersUpdated(uint256 newCollateralRatioBps, uint256 newRedemptionFeeBps);
    event OperatorChanged(address oldOperator, address newOperator);
    event AdminChanged(address oldAdmin, address newAdmin);
    event StableTransfer(address indexed from, address indexed to, uint256 value);
    event StableApproval(address indexed owner, address indexed spender, uint256 value);
    event ReserveTokenTransfer(address indexed from, address indexed to, uint256 value);
    event ReserveTokenApproval(address indexed owner, address indexed spender, uint256 value);

    // ============ Errors ============
    error NotAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidPrice();
    error InvalidParameter();
    error InsufficientBalance();
    error InsufficientAllowance();
    error CollateralizationViolated();
    error InsufficientReservePool();
    error NoExcessValue();
    error TransferFailed();
    error ReentrancyCall();

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAuthorized();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrancyCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ============ Constructor ============
    /**
     * @param _initialPrice The initial oracle price of the reserve asset in fiat (18 decimals)
     * @param _operator     The address privileged to update the oracle price and parameters
     */
    constructor(uint256 _initialPrice, address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialPrice == 0) revert InvalidPrice();

        oraclePriceFeed = _initialPrice;
        lastOracleUpdate = block.timestamp;
        collateralRatioBps = 40000; // 400%
        redemptionFeeBps = 50;       // 0.5%
        operator = _operator;
        admin = msg.sender;
        _reentrancyStatus = _NOT_ENTERED;

        emit OracleUpdated(_initialPrice, block.timestamp);
    }

    // ============================================================
    //                    STABLE TOKEN — MINT
    // ============================================================

    /**
     * @notice Mints stable tokens by depositing reserve cryptocurrency.
     * @dev    The amount of stable tokens minted is bounded by the collateralization
     *         ratio: stableMinted = depositValue * BASIS_POINTS / collateralRatioBps.
     *         The system must remain at or above the minimum ratio after minting.
     * @return stableMinted The amount of stable tokens minted to the caller.
     */
    function mintStable() external payable nonReentrant returns (uint256 stableMinted) {
        uint256 reserveAmount = msg.value;
        if (reserveAmount == 0) revert ZeroAmount();

        // stableMinted = reserveAmount * oraclePriceFeed * BASIS_POINTS / (PRICE_PRECISION * collateralRatioBps)
        stableMinted = (reserveAmount * oraclePriceFeed * BASIS_POINTS) / (PRICE_PRECISION * collateralRatioBps);
        if (stableMinted == 0) revert ZeroAmount();

        uint256 newReserveBalance = reserveBalance + reserveAmount;
        uint256 newStableSupply = stableSupply + stableMinted;

        // Collateralization check performed with full-precision products to avoid
        // divide-before-multiply precision loss:
        if (newReserveBalance * oraclePriceFeed * BASIS_POINTS < newStableSupply * collateralRatioBps * PRICE_PRECISION) {
            revert CollateralizationViolated();
        }

        // Effects
        reserveBalance = newReserveBalance;
        stableSupply = newStableSupply;
        stableBalances[msg.sender] += stableMinted;

        emit StableMinted(msg.sender, reserveAmount, stableMinted);
        emit StableTransfer(address(0), msg.sender, stableMinted);
    }

    // ============================================================
    //                   STABLE TOKEN — REDEEM
    // ============================================================

    /**
     * @notice Redeems stable tokens for reserve cryptocurrency. A 0.5% fee is deducted
     *         from the returned reserve and retained in the pool, benefiting reserve
     *         token holders.
     * @param stableAmount The amount of stable tokens to redeem.
     * @return reserveReturned The amount of reserve crypto returned to the caller.
     */
    function redeemStable(uint256 stableAmount) external nonReentrant returns (uint256 reserveReturned) {
        if (stableAmount == 0) revert ZeroAmount();
        if (stableBalances[msg.sender] < stableAmount) revert InsufficientBalance();

        // Gross reserve equivalent of the stable tokens being redeemed.
        uint256 reserveToReturn = (stableAmount * PRICE_PRECISION) / oraclePriceFeed;

        // Fee is computed directly from the original stable amount (and oracle price)
        // rather than from the already-divided `reserveToReturn`, avoiding a
        // divide-before-multiply precision loss:
        uint256 fee = (stableAmount * PRICE_PRECISION * redemptionFeeBps) / (oraclePriceFeed * BASIS_POINTS);
        reserveReturned = reserveToReturn - fee;

        if (reserveBalance < reserveReturned) revert InsufficientReservePool();

        // Effects
        stableBalances[msg.sender] -= stableAmount;
        stableSupply -= stableAmount;
        reserveBalance -= reserveReturned;

        // Interactions
        (bool success, ) = msg.sender.call{value: reserveReturned}("");
        if (!success) revert TransferFailed();

        emit StableRedeemed(msg.sender, stableAmount, reserveReturned, fee);
        emit StableTransfer(msg.sender, address(0), stableAmount);
    }

    // ============================================================
    //               RESERVE TOKEN — MINT
    // ============================================================

    /**
     * @notice Mints reserve tokens by depositing reserve cryptocurrency. Reserve tokens
     *         represent a proportional share of the excess collateral (reserve pool value
     *         minus stable token liability) and absorb volatility.
     * @return minted The amount of reserve tokens minted to the caller.
     */
    function mintReserveToken() external payable nonReentrant returns (uint256 minted) {
        uint256 reserveAmount = msg.value;
        if (reserveAmount == 0) revert ZeroAmount();

        if (reserveTokenSupply == 0) {
            // First mint: 1:1 with the fiat value of the deposit.
            minted = (reserveAmount * oraclePriceFeed) / PRICE_PRECISION;
        } else {
            uint256 poolValue = (reserveBalance * oraclePriceFeed) / PRICE_PRECISION;
            if (poolValue <= stableSupply) revert NoExcessValue();
            uint256 excessValue = poolValue - stableSupply;

            // Combined single expression to avoid dividing `depositValue` (itself a
            // division result) and then multiplying by `reserveTokenSupply`:
            minted = (reserveAmount * oraclePriceFeed * reserveTokenSupply) / (PRICE_PRECISION * excessValue);
        }

        if (minted == 0) revert ZeroAmount();

        // Effects
        reserveBalance += reserveAmount;
        reserveTokenSupply += minted;
        reserveTokenBalances[msg.sender] += minted;

        emit ReserveTokenMinted(msg.sender, reserveAmount, minted);
        emit ReserveTokenTransfer(address(0), msg.sender, minted);
    }

    // ============================================================
    //               RESERVE TOKEN — REDEEM
    // ============================================================

    /**
     * @notice Redeems reserve tokens for reserve cryptocurrency. The returned amount
     *         is proportional to the caller's share of the excess collateral.
     * @param rtAmount The amount of reserve tokens to redeem.
     * @return reserveReturned The amount of reserve crypto returned to the caller.
     */
    function redeemReserveToken(uint256 rtAmount) external nonReentrant returns (uint256 reserveReturned) {
        if (rtAmount == 0) revert ZeroAmount();
        if (reserveTokenBalances[msg.sender] < rtAmount) revert InsufficientBalance();

        uint256 poolValue = (reserveBalance * oraclePriceFeed) / PRICE_PRECISION;
        if (poolValue <= stableSupply) revert NoExcessValue();
        uint256 excessValue = poolValue - stableSupply;

        // reserveReturned = rtAmount * excessValue * PRICE_PRECISION / (reserveTokenSupply * oraclePriceFeed)
        reserveReturned = (rtAmount * excessValue * PRICE_PRECISION) / (reserveTokenSupply * oraclePriceFeed);

        if (reserveReturned == 0) revert ZeroAmount();
        if (reserveBalance < reserveReturned) revert InsufficientReservePool();

        // Effects
        reserveTokenBalances[msg.sender] -= rtAmount;
        reserveTokenSupply -= rtAmount;
        reserveBalance -= reserveReturned;

        // Interactions
        (bool success, ) = msg.sender.call{value: reserveReturned}("");
        if (!success) revert TransferFailed();

        emit ReserveTokenRedeemed(msg.sender, rtAmount, reserveReturned);
        emit ReserveTokenTransfer(msg.sender, address(0), rtAmount);
    }

    // ============================================================
    //               ERC20 — STABLE TOKEN TRANSFERS
    // ============================================================

    function stableTransfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (stableBalances[msg.sender] < amount) revert InsufficientBalance();
        stableBalances[msg.sender] -= amount;
        stableBalances[to] += amount;
        emit StableTransfer(msg.sender, to, amount);
        return true;
    }

    function stableApprove(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        stableAllowances[msg.sender][spender] = amount;
        emit StableApproval(msg.sender, spender, amount);
        return true;
    }

    function stableTransferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (stableBalances[from] < amount) revert InsufficientBalance();
        if (stableAllowances[from][msg.sender] < amount) revert InsufficientAllowance();

        stableAllowances[from][msg.sender] -= amount;
        stableBalances[from] -= amount;
        stableBalances[to] += amount;
        emit StableTransfer(from, to, amount);
        return true;
    }

    // ============================================================
    //             ERC20 — RESERVE TOKEN TRANSFERS
    // ============================================================

    function reserveTokenTransfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (reserveTokenBalances[msg.sender] < amount) revert InsufficientBalance();
        reserveTokenBalances[msg.sender] -= amount;
        reserveTokenBalances[to] += amount;
        emit ReserveTokenTransfer(msg.sender, to, amount);
        return true;
    }

    function reserveTokenApprove(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        reserveTokenAllowances[msg.sender][spender] = amount;
        emit ReserveTokenApproval(msg.sender, spender, amount);
        return true;
    }

    function reserveTokenTransferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (reserveTokenBalances[from] < amount) revert InsufficientBalance();
        if (reserveTokenAllowances[from][msg.sender] < amount) revert InsufficientAllowance();

        reserveTokenAllowances[from][msg.sender] -= amount;
        reserveTokenBalances[from] -= amount;
        reserveTokenBalances[to] += amount;
        emit ReserveTokenTransfer(from, to, amount);
        return true;
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Returns the current collateralization ratio of the stable token supply
     *         in basis points. Returns type(uint256).max if no stable tokens are issued.
     */
    function reserveRatio() external view returns (uint256) {
        if (stableSupply == 0) return type(uint256).max;
        return (reserveBalance * oraclePriceFeed * BASIS_POINTS) / (PRICE_PRECISION * stableSupply);
    }

    /**
     * @notice Returns the fiat price of a single reserve token (18 decimals).
     *         Equals excess collateral value divided by reserve token supply.
     */
    function reserveTokenPrice() public view returns (uint256) {
        if (reserveTokenSupply == 0) return 0;
        // excessValue = (reserveBalance * oraclePriceFeed) / PRICE_PRECISION - stableSupply
        // price = excessValue * PRICE_PRECISION / reserveTokenSupply
        // Combined to avoid rounding loss from an intermediate division:
        uint256 excessNumerator = reserveBalance * oraclePriceFeed;
        uint256 stableLiabilityNumerator = stableSupply * PRICE_PRECISION;
        if (excessNumerator <= stableLiabilityNumerator) return 0;
        return (excessNumerator - stableLiabilityNumerator) / reserveTokenSupply;
    }

    /**
     * @notice Returns the total fiat value of the reserve pool.
     */
    function reservePoolValue() external view returns (uint256) {
        return (reserveBalance * oraclePriceFeed) / PRICE_PRECISION;
    }

    /**
     * @notice Returns the excess collateral value (reserve pool value minus stable liability).
     */
    function excessCollateralValue() external view returns (uint256) {
        uint256 poolValue = (reserveBalance * oraclePriceFeed) / PRICE_PRECISION;
        if (poolValue <= stableSupply) return 0;
        return poolValue - stableSupply;
    }

    function stableBalanceOf(address account) external view returns (uint256) {
        return stableBalances[account];
    }

    function reserveTokenBalanceOf(address account) external view returns (uint256) {
        return reserveTokenBalances[account];
    }

    function stableAllowanceOf(address owner, address spender) external view returns (uint256) {
        return stableAllowances[owner][spender];
    }

    function reserveTokenAllowanceOf(address owner, address spender) external view returns (uint256) {
        return reserveTokenAllowances[owner][spender];
    }

    /**
     * @notice Returns the total supply of both the stable token and reserve token.
     */
    function getTotalSupplies() external view returns (uint256 stable, uint256 reserve) {
        return (stableSupply, reserveTokenSupply);
    }

    /**
     * @notice Returns the current oracle price of the reserve cryptocurrency.
     */
    function getOraclePrice() external view returns (uint256) {
        return oraclePriceFeed;
    }

    // ============================================================
    //               OPERATOR / ADMIN FUNCTIONS
    // ============================================================

    /**
     * @notice Adjusts the oracle price feed for the reserve cryptocurrency.
     * @dev    Only the designated operator may call this. The new price must not
     *         cause the collateralization ratio to fall below the minimum.
     * @param newPrice The new price in fiat per reserve unit (18 decimals).
     */
    function adjustOraclePriceFeed(uint256 newPrice) external onlyOperator {
        if (newPrice == 0) revert InvalidPrice();
        if (stableSupply > 0) {
            // newReserveValue = reserveBalance * newPrice / PRICE_PRECISION
            // Require: newReserveValue * BASIS_POINTS >= stableSupply * collateralRatioBps
            // Performed with full-precision products to avoid divide-before-multiply:
            if (reserveBalance * newPrice * BASIS_POINTS < stableSupply * collateralRatioBps * PRICE_PRECISION) {
                revert CollateralizationViolated();
            }
        }
        oraclePriceFeed = newPrice;
        lastOracleUpdate = block.timestamp;
        emit OracleUpdated(newPrice, block.timestamp);
    }

    /**
     * @notice Updates system parameters: collateralization ratio and redemption fee.
     * @dev    The collateral ratio must be at least 100% (BASIS_POINTS) and the fee
     *         must not exceed 100% (BASIS_POINTS). The new ratio must not violate
     *         the current collateralization state.
     * @param _collateralRatioBps New collateralization ratio in basis points.
     * @param _redemptionFeeBps   New redemption fee in basis points.
     */
    function updateParameters(uint256 _collateralRatioBps, uint256 _redemptionFeeBps) external onlyOperator {
        if (_collateralRatioBps < BASIS_POINTS) revert InvalidParameter();
        if (_redemptionFeeBps > BASIS_POINTS) revert InvalidParameter();
        if (stableSupply > 0) {
            // reserveValue = reserveBalance * oraclePriceFeed / PRICE_PRECISION
            // Require: reserveValue * BASIS_POINTS >= stableSupply * _collateralRatioBps
            // Performed with full-precision products to avoid divide-before-multiply:
            if (reserveBalance * oraclePriceFeed * BASIS_POINTS < stableSupply * _collateralRatioBps * PRICE_PRECISION) {
                revert CollateralizationViolated();
            }
        }
        collateralRatioBps = _collateralRatioBps;
        redemptionFeeBps = _redemptionFeeBps;
        emit ParametersUpdated(_collateralRatioBps, _redemptionFeeBps);
    }

    /**
     * @notice Transfers the operator role to a new address.
     * @param newOperator The address of the new operator.
     */
    function setOperator(address newOperator) external onlyAdmin {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    /**
     * @notice Transfers the admin role to a new address.
     * @param newAdmin The address of the new admin.
     */
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }
}
