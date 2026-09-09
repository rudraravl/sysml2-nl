// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

contract BasketStablecoin {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error EnforcedPause();
    error EnforcedUnpause();
    error CollateralNotApproved(address token);
    error CollateralAlreadyApproved(address token);
    error CollateralNotInList(address token);
    error CollateralInUse(address token, uint256 remaining);
    error InsufficientCollateralization(uint256 ratio, uint256 required);
    error InsufficientBalance(address account, uint256 amount);
    error InsufficientAllowance(address owner, address spender, uint256 amount);
    error InsufficientCollateralDeposit(address account, address token, uint256 requested, uint256 available);
    error ZeroAddress();
    error InvalidAmount();
    error SlippageExceeded(uint256 actual, uint256 minimum);
    error InvalidFee(uint256 fee);
    error ReentrancyGuard();

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant MIN_COLLATERAL_RATIO = 10500; // 105% in basis points
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% cap
    uint8 public constant decimals = 18;

    // -------------------------------------------------------------------------
    // Stablecoin State
    // -------------------------------------------------------------------------

    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -------------------------------------------------------------------------
    // Collateral State
    // -------------------------------------------------------------------------

    struct CollateralInfo {
        bool approved;
        uint8 decimals;
    }

    mapping(address => CollateralInfo) public collateralInfo;
    address[] internal _collateralList;

    /// @dev Per-account, per-token collateral deposits (the global reserve pool)
    mapping(address => mapping(address => uint256)) public accountCollateral;
    /// @dev Total collateral held in the contract per token
    mapping(address => uint256) public totalCollateral;

    // -------------------------------------------------------------------------
    // Configuration
    // -------------------------------------------------------------------------

    uint256 public redemptionFeeBps; // 10 = 0.1%
    bool public paused;
    address public owner;
    address public operator;
    IPriceOracle public priceOracle;

    // -------------------------------------------------------------------------
    // Reentrancy
    // -------------------------------------------------------------------------

    uint256 private _locked = 1;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Mint(address indexed user, address indexed collateralToken, uint256 collateralAmount, uint256 stablecoinAmount);
    event Redeem(address indexed user, address indexed collateralToken, uint256 stablecoinAmount, uint256 feeAmount, uint256 collateralAmount);
    event CollateralAdded(address indexed token);
    event CollateralRemoved(address indexed token);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);
    event Paused();
    event Unpaused();
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event PriceOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        string memory _name,
        string memory _symbol,
        address _priceOracle,
        address _operator
    ) {
        if (_priceOracle == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        name = _name;
        symbol = _symbol;
        priceOracle = IPriceOracle(_priceOracle);
        operator = _operator;
        owner = msg.sender;
        redemptionFeeBps = 10; // 0.1%

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
        emit PriceOracleUpdated(address(0), _priceOracle);
        emit RedemptionFeeUpdated(0, 10);
    }

    // -------------------------------------------------------------------------
    // Internal — Collateral Valuation
    // -------------------------------------------------------------------------

    /// @dev Returns the total stablecoin-denominated value of all collateral
    ///      deposited by `account`, using oracle prices.
    function _getAccountCollateralValue(address account) internal view returns (uint256 totalValue) {
        uint256 len = _collateralList.length;
        for (uint256 i = 0; i < len; ) {
            address token = _collateralList[i];
            uint256 deposited = accountCollateral[account][token];
            if (deposited > 0) {
                uint256 price = priceOracle.getPrice(token);
                uint8 dec = collateralInfo[token].decimals;
                totalValue += (deposited * price) / (10 ** uint256(dec));
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Converts a collateral amount into stablecoin-denominated value.
    function _collateralToValue(address token, uint256 amount) internal view returns (uint256 value) {
        uint256 price = priceOracle.getPrice(token);
        uint8 dec = collateralInfo[token].decimals;
        value = (amount * price) / (10 ** uint256(dec));
    }

    /// @dev Converts a stablecoin-denominated value into a collateral amount.
    function _valueToCollateral(address token, uint256 value) internal view returns (uint256 amount) {
        uint256 price = priceOracle.getPrice(token);
        uint8 dec = collateralInfo[token].decimals;
        amount = (value * (10 ** uint256(dec))) / price;
    }

    // -------------------------------------------------------------------------
    // Internal — ERC20 Primitives
    // -------------------------------------------------------------------------

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance(from, amount);
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    // -------------------------------------------------------------------------
    // Minting
    // -------------------------------------------------------------------------

    /// @notice Deposit approved collateral and mint stablecoins.
    /// @param collateralToken  The collateral token to deposit.
    /// @param collateralAmount Amount of collateral to deposit (in token units).
    /// @param stablecoinAmount Amount of stablecoins to mint (in 1e18 units).
    /// @dev The account's collateralization ratio must remain >= 105% after minting.
    function mint(
        address collateralToken,
        uint256 collateralAmount,
        uint256 stablecoinAmount
    ) external whenNotPaused nonReentrant {
        if (collateralAmount == 0 || stablecoinAmount == 0) revert InvalidAmount();
        if (!collateralInfo[collateralToken].approved) revert CollateralNotApproved(collateralToken);

        // Pull collateral from the caller into the reserve pool
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        // Record the deposit
        accountCollateral[msg.sender][collateralToken] += collateralAmount;
        totalCollateral[collateralToken] += collateralAmount;

        // Enforce minimum collateralization ratio of 105%
        uint256 collateralValue = _getAccountCollateralValue(msg.sender);
        uint256 newBalance = balanceOf[msg.sender] + stablecoinAmount;
        uint256 requiredValue = (newBalance * MIN_COLLATERAL_RATIO) / BPS_DENOMINATOR;

        if (collateralValue < requiredValue) {
            revert InsufficientCollateralization(
                (collateralValue * BPS_DENOMINATOR) / newBalance,
                MIN_COLLATERAL_RATIO
            );
        }

        _mint(msg.sender, stablecoinAmount);

        emit Mint(msg.sender, collateralToken, collateralAmount, stablecoinAmount);
    }

    // -------------------------------------------------------------------------
    // Redemption
    // -------------------------------------------------------------------------

    /// @notice Burn stablecoins and receive collateral from the reserve pool.
    /// @param collateralToken     The collateral token to receive.
    /// @param stablecoinAmount    Amount of stablecoins to redeem (in 1e18 units).
    /// @param minCollateralAmount Minimum collateral to receive (slippage protection).
    /// @dev A 0.1% redemption fee is deducted; the corresponding collateral remains
    ///      in the reserve pool as protocol surplus.
    function redeem(
        address collateralToken,
        uint256 stablecoinAmount,
        uint256 minCollateralAmount
    ) external whenNotPaused nonReentrant {
        if (stablecoinAmount == 0) revert InvalidAmount();
        if (!collateralInfo[collateralToken].approved) revert CollateralNotApproved(collateralToken);
        if (balanceOf[msg.sender] < stablecoinAmount) revert InsufficientBalance(msg.sender, stablecoinAmount);

        // Compute fee and redeemable value
        uint256 fee = (stablecoinAmount * redemptionFeeBps) / BPS_DENOMINATOR;
        uint256 redeemableValue = stablecoinAmount - fee;

        // Determine collateral to return
        uint256 collateralToReturn = _valueToCollateral(collateralToken, redeemableValue);

        if (collateralToReturn < minCollateralAmount) {
            revert SlippageExceeded(collateralToReturn, minCollateralAmount);
        }

        uint256 available = accountCollateral[msg.sender][collateralToken];
        if (available < collateralToReturn) {
            revert InsufficientCollateralDeposit(msg.sender, collateralToken, collateralToReturn, available);
        }

        // Effects: burn stablecoins and reduce collateral deposits
        _burn(msg.sender, stablecoinAmount);

        accountCollateral[msg.sender][collateralToken] -= collateralToReturn;
        totalCollateral[collateralToken] -= collateralToReturn;

        // Post-redemption collateralization check (skip if fully redeemed)
        uint256 newBalance = balanceOf[msg.sender];
        if (newBalance > 0) {
            uint256 collateralValue = _getAccountCollateralValue(msg.sender);
            uint256 requiredValue = (newBalance * MIN_COLLATERAL_RATIO) / BPS_DENOMINATOR;
            if (collateralValue < requiredValue) {
                revert InsufficientCollateralization(
                    (collateralValue * BPS_DENOMINATOR) / newBalance,
                    MIN_COLLATERAL_RATIO
                );
            }
        }

        // Interaction: return collateral to the caller
        IERC20(collateralToken).safeTransfer(msg.sender, collateralToReturn);

        emit Redeem(msg.sender, collateralToken, stablecoinAmount, fee, collateralToReturn);
    }

    // -------------------------------------------------------------------------
    // ERC20 — Transfer / Approve
    // -------------------------------------------------------------------------

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance(msg.sender, amount);

        unchecked {
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance(from, amount);

        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance(from, msg.sender, amount);

        if (currentAllowance != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = currentAllowance - amount;
            }
        }

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // -------------------------------------------------------------------------
    // Operator — Pause / Unpause
    // -------------------------------------------------------------------------

    function pause() external onlyOperator {
        if (paused) revert EnforcedPause();
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOperator {
        if (!paused) revert EnforcedUnpause();
        paused = false;
        emit Unpaused();
    }

    // -------------------------------------------------------------------------
    // Owner — Collateral Management
    // -------------------------------------------------------------------------

    function addCollateral(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (collateralInfo[token].approved) revert CollateralAlreadyApproved(token);

        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        collateralInfo[token] = CollateralInfo({approved: true, decimals: tokenDecimals});
        _collateralList.push(token);

        emit CollateralAdded(token);
    }

    function removeCollateral(address token) external onlyOwner {
        if (!collateralInfo[token].approved) revert CollateralNotInList(token);
        if (totalCollateral[token] > 0) revert CollateralInUse(token, totalCollateral[token]);

        collateralInfo[token].approved = false;

        uint256 len = _collateralList.length;
        for (uint256 i = 0; i < len; ) {
            if (_collateralList[i] == token) {
                _collateralList[i] = _collateralList[len - 1];
                _collateralList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit CollateralRemoved(token);
    }

    // -------------------------------------------------------------------------
    // Owner — Configuration
    // -------------------------------------------------------------------------

    function setRedemptionFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee(newFeeBps);
        uint256 oldFee = redemptionFeeBps;
        redemptionFeeBps = newFeeBps;
        emit RedemptionFeeUpdated(oldFee, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function setPriceOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert ZeroAddress();
        address old = address(priceOracle);
        priceOracle = IPriceOracle(newOracle);
        emit PriceOracleUpdated(old, newOracle);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------

    function getApprovedCollaterals() external view returns (address[] memory) {
        return _collateralList;
    }

    function collateralListLength() external view returns (uint256) {
        return _collateralList.length;
    }

    function isApprovedCollateral(address token) external view returns (bool) {
        return collateralInfo[token].approved;
    }

    function getAccountCollateralValue(address account) external view returns (uint256) {
        return _getAccountCollateralValue(account);
    }

    function getCollateralizationRatio(address account) external view returns (uint256) {
        uint256 bal = balanceOf[account];
        if (bal == 0) return type(uint256).max;
        uint256 collateralValue = _getAccountCollateralValue(account);
        return (collateralValue * BPS_DENOMINATOR) / bal;
    }

    function getAccountCollateral(address account, address token) external view returns (uint256) {
        return accountCollateral[account][token];
    }

    function getTotalReserveValue() external view returns (uint256 totalValue) {
        uint256 len = _collateralList.length;
        for (uint256 i = 0; i < len; ) {
            address token = _collateralList[i];
            uint256 amount = totalCollateral[token];
            if (amount > 0) {
                uint256 price = priceOracle.getPrice(token);
                uint8 dec = collateralInfo[token].decimals;
                totalValue += (amount * price) / (10 ** uint256(dec));
            }
            unchecked {
                ++i;
            }
        }
    }
}
