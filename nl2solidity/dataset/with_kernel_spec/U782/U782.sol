// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPriceOracle {
    /// @notice Returns the USD price of one full token in 18-decimal precision.
    function getPrice(address token) external view returns (uint256);
}

contract RWAStablecoin {
    // ---------------------------------------------------------------------
    // Metadata
    // ---------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ---------------------------------------------------------------------
    // ERC-20 state
    // ---------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------
    // Collateral state
    // ---------------------------------------------------------------------
    struct CollateralType {
        bool approved;
        uint256 totalDeposited;
    }

    mapping(address => CollateralType) public collateralTypes;
    mapping(address => bool) public collateralInList;
    address[] public collateralList;

    /// @dev user => collateral token => amount deposited
    mapping(address => mapping(address => uint256)) public userCollateral;

    // ---------------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------------
    IPriceOracle public priceOracle;
    address public operator;
    address public feeRecipient;

    /// @dev 0 means unlimited
    uint256 public maxMintLimit;

    uint256 public currentCollateralizationRatio;

    uint256 public constant MIN_COLLATERALIZATION_RATIO = 105 * 1e16; // 105% in 1e18
    uint256 public constant REDEMPTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // Reentrancy guard
    // ---------------------------------------------------------------------
    uint256 private _locked = 1;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MintStablecoin(
        address indexed user,
        address indexed collateralToken,
        uint256 collateralAmount,
        uint256 stablecoinAmount
    );
    event RedeemStablecoin(
        address indexed user,
        address indexed collateralToken,
        uint256 stablecoinAmount,
        uint256 collateralReturned,
        uint256 fee
    );
    event CollateralizationRatioChanged(uint256 oldRatio, uint256 newRatio);
    event CollateralTypeApprovalChanged(address indexed collateralToken, bool approved);
    event MaxMintLimitChanged(uint256 oldLimit, uint256 newLimit);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event PriceOracleChanged(address indexed oldOracle, address indexed newOracle);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error Unauthorized();
    error ZeroAddress();
    error InvalidAmount();
    error CollateralNotApproved();
    error CollateralAlreadyInState();
    error OraclePriceZero();
    error MintLimitExceeded();
    error InsufficientCollateral();
    error InsufficientStablecoinBalance();
    error AllowanceExceeded();
    error TokenTransferFailed();
    error InvalidCollateralization();
    error Reentrancy();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor(
        string memory name_,
        string memory symbol_,
        address priceOracle_,
        address feeRecipient_,
        uint256 maxMintLimit_
    ) {
        if (priceOracle_ == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();
        name = name_;
        symbol = symbol_;
        priceOracle = IPriceOracle(priceOracle_);
        feeRecipient = feeRecipient_;
        operator = msg.sender;
        maxMintLimit = maxMintLimit_;
        emit OperatorChanged(address(0), msg.sender);
        emit FeeRecipientChanged(address(0), feeRecipient_);
        emit PriceOracleChanged(address(0), priceOracle_);
        emit MaxMintLimitChanged(0, maxMintLimit_);
    }

    // ---------------------------------------------------------------------
    // Operator administration
    // ---------------------------------------------------------------------
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(oldRecipient, newRecipient);
    }

    function setPriceOracle(address newOracle) external onlyOperator {
        if (newOracle == address(0)) revert ZeroAddress();
        address oldOracle = address(priceOracle);
        priceOracle = IPriceOracle(newOracle);
        emit PriceOracleChanged(oldOracle, newOracle);
    }

    function approveCollateralType(address token, bool approved) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        CollateralType storage ct = collateralTypes[token];
        if (ct.approved == approved) revert CollateralAlreadyInState();

        ct.approved = approved;
        if (approved && !collateralInList[token]) {
            collateralInList[token] = true;
            collateralList.push(token);
        }

        emit CollateralTypeApprovalChanged(token, approved);
    }

    function setMaxMintLimit(uint256 newLimit) external onlyOperator {
        uint256 oldLimit = maxMintLimit;
        maxMintLimit = newLimit;
        emit MaxMintLimitChanged(oldLimit, newLimit);
    }

    // ---------------------------------------------------------------------
    // ERC-20 functions
    // ---------------------------------------------------------------------
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert AllowanceExceeded();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
            emit Approval(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        _approve(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowance[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert AllowanceExceeded();
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    // ---------------------------------------------------------------------
    // Minting — deposit approved collateral and receive stablecoins
    // ---------------------------------------------------------------------
    function depositCollateral(
        address collateralToken,
        uint256 collateralAmount
    ) external nonReentrant returns (uint256 stablecoinAmount) {
        if (collateralAmount == 0) revert InvalidAmount();

        CollateralType storage ct = collateralTypes[collateralToken];
        if (!ct.approved) revert CollateralNotApproved();

        uint256 price = _getPrice(collateralToken);

        // Pull collateral from caller. For standard ERC20 tokens the received
        // amount equals the requested amount; we rely on the boolean return.
        if (!IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount)) {
            revert TokenTransferFailed();
        }

        uint256 received = collateralAmount;

        // Compute mintable stablecoins at minimum collateralization ratio (105%).
        // Combined formula avoids divide-before-multiply:
        // stablecoinAmount = (received * price / PRECISION) * PRECISION / MIN_COLLATERALIZATION_RATIO
        //                 = received * price / MIN_COLLATERALIZATION_RATIO
        stablecoinAmount = (received * price) / MIN_COLLATERALIZATION_RATIO;

        if (stablecoinAmount < 1) revert InvalidAmount();

        if (maxMintLimit != 0 && totalSupply + stablecoinAmount > maxMintLimit) {
            revert MintLimitExceeded();
        }

        // Effects: record collateral and mint stablecoin
        userCollateral[msg.sender][collateralToken] += received;
        ct.totalDeposited += received;

        _mint(msg.sender, stablecoinAmount);
        _updateCollateralization();

        emit MintStablecoin(msg.sender, collateralToken, received, stablecoinAmount);
    }

    // ---------------------------------------------------------------------
    // Redemption — burn stablecoins and receive underlying collateral
    // ---------------------------------------------------------------------
    function redeemStablecoin(
        uint256 stablecoinAmount,
        address collateralToken
    ) external nonReentrant returns (uint256 collateralReturned) {
        if (stablecoinAmount == 0) revert InvalidAmount();
        if (!collateralTypes[collateralToken].approved) revert CollateralNotApproved();
        if (balanceOf[msg.sender] < stablecoinAmount) revert InsufficientStablecoinBalance();

        uint256 price = _getPrice(collateralToken);

        // Fee: 0.1% of redeemed stablecoins
        uint256 fee = (stablecoinAmount * REDEMPTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netStablecoin = stablecoinAmount - fee;

        // Collateral to return based on net stablecoin value
        collateralReturned = (netStablecoin * PRECISION) / price;
        if (collateralReturned < 1) revert InvalidAmount();

        uint256 userDeposited = userCollateral[msg.sender][collateralToken];
        if (userDeposited < collateralReturned) revert InsufficientCollateral();

        // The USD value of the collateral being removed equals the net stablecoin
        // value redeemed (collateralReturned * price / PRECISION == netStablecoin),
        // so we use netStablecoin directly to avoid divide-before-multiply.
        uint256 removedCollateralValueUsd = netStablecoin;
        uint256 currentTotalCollateralValue = _getTotalCollateralValue();
        uint256 newTotalCollateralValue = currentTotalCollateralValue - removedCollateralValueUsd;
        // Net supply change: burn stablecoinAmount, mint fee to feeRecipient.
        uint256 newTotalSupply = totalSupply - netStablecoin;

        if (
            newTotalSupply > 0 &&
            (newTotalCollateralValue * PRECISION) / newTotalSupply < MIN_COLLATERALIZATION_RATIO
        ) {
            revert InvalidCollateralization();
        }

        // Effects: burn full amount from caller, mint fee portion to fee recipient
        _burn(msg.sender, stablecoinAmount);
        if (fee > 0) {
            _mint(feeRecipient, fee);
        }

        // Update collateral records
        userCollateral[msg.sender][collateralToken] -= collateralReturned;
        collateralTypes[collateralToken].totalDeposited -= collateralReturned;

        // Interaction: return collateral to caller
        if (!IERC20(collateralToken).transfer(msg.sender, collateralReturned)) {
            revert TokenTransferFailed();
        }

        _updateCollateralization();

        emit RedeemStablecoin(msg.sender, collateralToken, stablecoinAmount, collateralReturned, fee);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------
    function getTotalCollateralValue() external view returns (uint256) {
        return _getTotalCollateralValue();
    }

    function collateralValueOf(address token, uint256 amount) external view returns (uint256) {
        uint256 price = priceOracle.getPrice(token);
        if (price == 0) revert OraclePriceZero();
        return (amount * price) / PRECISION;
    }

    function maxMintableFor(address token, uint256 collateralAmount) external view returns (uint256) {
        if (!collateralTypes[token].approved) return 0;
        uint256 price = priceOracle.getPrice(token);
        if (price == 0) return 0;
        // Combined formula avoids divide-before-multiply:
        // (collateralAmount * price / PRECISION) * PRECISION / MIN_COLLATERALIZATION_RATIO
        // = collateralAmount * price / MIN_COLLATERALIZATION_RATIO
        return (collateralAmount * price) / MIN_COLLATERALIZATION_RATIO;
    }

    function collateralListLength() external view returns (uint256) {
        return collateralList.length;
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------
    function _getTotalCollateralValue() internal view returns (uint256 totalValue) {
        uint256 len = collateralList.length;
        for (uint256 i = 0; i < len; i++) {
            address token = collateralList[i];
            if (!collateralTypes[token].approved) continue;

            uint256 deposited = collateralTypes[token].totalDeposited;
            uint256 price = priceOracle.getPrice(token);
            if (price > 0 && deposited > 0) {
                totalValue += (deposited * price) / PRECISION;
            }
        }
    }

    function _getPrice(address token) internal view returns (uint256) {
        uint256 price = priceOracle.getPrice(token);
        if (price == 0) revert OraclePriceZero();
        return price;
    }

    function _updateCollateralization() internal {
        uint256 oldRatio = currentCollateralizationRatio;
        uint256 newRatio;
        if (totalSupply > 0) {
            newRatio = (_getTotalCollateralValue() * PRECISION) / totalSupply;
        } else {
            newRatio = 0;
        }
        currentCollateralizationRatio = newRatio;
        emit CollateralizationRatioChanged(oldRatio, newRatio);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        if (balanceOf[account] < amount) revert InsufficientStablecoinBalance();
        unchecked {
            balanceOf[account] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (balanceOf[from] < amount) revert InsufficientStablecoinBalance();

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
