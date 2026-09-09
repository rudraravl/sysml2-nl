// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 current, uint256 requested);

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        if (!_callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (!_callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        if (!_callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < requestedDecrease) {
            revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        if (!_callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, currentAllowance - requestedDecrease))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (success && returndata.length > 0) {
            return abi.decode(returndata, (bool));
        }
        return success;
    }
}

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

/// @title AssetIndexVault
/// @notice Manages multiple index baskets of diverse digital assets.
/// Users can deposit assets to receive shares, redeem shares for a proportional
/// basket, and an operator can create indices, adjust compositions, and update fees.
/// A 0.5% default annual management fee is accrued continuously, and a 0.1%
/// default redemption fee is charged on withdrawals.
contract AssetIndexVault {
    using SafeERC20 for IERC20;

    // ──────────────────────── Custom Errors ────────────────────────
    error NotOperator();
    error InvalidIndex();
    error AssetNotAllowed();
    error TooManyAssets();
    error NoAssets();
    error DuplicateAsset();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error FeeRateTooHigh();
    error InvalidAddress();
    error TransferFailed();
    error ReentrantCall();

    // ─────────────────────────── Events ────────────────────────────
    event IndexCreated(
        uint256 indexed indexId,
        string name,
        address[] assets,
        uint256 managementFeeRate,
        uint256 redemptionFeeRate
    );
    event Deposited(
        uint256 indexed indexId,
        address indexed user,
        address asset,
        uint256 amount,
        uint256 shares
    );
    event Redeemed(
        uint256 indexed indexId,
        address indexed user,
        uint256 shares,
        address[] assets,
        uint256[] assetAmounts
    );
    event IndexRebalanced(uint256 indexed indexId, address[] newAssets);
    event FeeUpdated(
        uint256 indexed indexId,
        uint256 newManagementFeeRate,
        uint256 newRedemptionFeeRate
    );
    event ManagementFeeAccrued(uint256 indexed indexId, address indexed recipient, uint256 sharesMinted);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed newFeeRecipient);

    // ──────────────────────── Data Structures ───────────────────────
    struct Index {
        string name;
        address[] assets;
        mapping(address => bool) isAsset;
        uint256 totalShares;
        mapping(address => uint256) userShares;
        uint256 managementFeeRate; // annual fee in basis points (e.g., 50 = 0.5%)
        uint256 redemptionFeeRate; // fee in basis points (e.g., 10 = 0.1%)
        uint256 lastFeeTimestamp;
    }

    // ──────────────────────── State Variables ──────────────────────
    IPriceOracle public immutable oracle;
    address public operator;
    address public feeRecipient;
    uint256 public nextIndexId;
    mapping(uint256 => Index) private indices;

    uint256 private constant MAX_ASSETS = 10;
    uint256 private constant MAX_FEE_RATE = 10000; // 100%
    uint256 private constant PRECISION = 1e18;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus = _NOT_ENTERED;

    // ────────────────────────── Modifiers ──────────────────────────
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier validIndex(uint256 indexId) {
        if (indexId >= nextIndexId) revert InvalidIndex();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ───────────────────────── Constructor ─────────────────────────
    constructor(address _oracle, address _feeRecipient) {
        if (_oracle == address(0) || _feeRecipient == address(0)) revert InvalidAddress();
        oracle = IPriceOracle(_oracle);
        operator = msg.sender;
        feeRecipient = _feeRecipient;
    }

    // ──────────────────── Operator Functions ───────────────────────
    /// @notice Creates a new index basket.
    /// @param name Human-readable name for the index.
    /// @param assets Array of ERC20 token addresses (max 10, no duplicates).
    /// @param managementFeeRate Annual management fee in basis points.
    /// @param redemptionFeeRate Redemption fee in basis points.
    /// @return indexId The ID of the newly created index.
    function createIndex(
        string calldata name,
        address[] calldata assets,
        uint256 managementFeeRate,
        uint256 redemptionFeeRate
    ) external onlyOperator returns (uint256 indexId) {
        if (assets.length == 0) revert NoAssets();
        if (assets.length > MAX_ASSETS) revert TooManyAssets();
        if (managementFeeRate > MAX_FEE_RATE || redemptionFeeRate > MAX_FEE_RATE)
            revert FeeRateTooHigh();

        indexId = nextIndexId++;
        Index storage index = indices[indexId];
        index.name = name;
        index.managementFeeRate = managementFeeRate;
        index.redemptionFeeRate = redemptionFeeRate;
        index.lastFeeTimestamp = block.timestamp;

        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            if (asset == address(0)) revert InvalidAddress();
            if (index.isAsset[asset]) revert DuplicateAsset();
            index.isAsset[asset] = true;
            index.assets.push(asset);
        }

        emit IndexCreated(indexId, name, assets, managementFeeRate, redemptionFeeRate);
    }

    /// @notice Updates the asset composition of an existing index.
    /// @param indexId The index to update.
    /// @param newAssets New array of asset addresses (max 10, no duplicates).
    function updateIndexComposition(
        uint256 indexId,
        address[] calldata newAssets
    ) external onlyOperator validIndex(indexId) {
        if (newAssets.length == 0) revert NoAssets();
        if (newAssets.length > MAX_ASSETS) revert TooManyAssets();
        Index storage index = indices[indexId];

        // Clear old flags
        for (uint256 i = 0; i < index.assets.length; i++) {
            index.isAsset[index.assets[i]] = false;
        }
        delete index.assets;

        // Set new assets
        for (uint256 i = 0; i < newAssets.length; i++) {
            address asset = newAssets[i];
            if (asset == address(0)) revert InvalidAddress();
            if (index.isAsset[asset]) revert DuplicateAsset();
            index.isAsset[asset] = true;
            index.assets.push(asset);
        }

        index.lastFeeTimestamp = block.timestamp;

        emit IndexRebalanced(indexId, newAssets);
    }

    /// @notice Updates the fee rates for an index. Accrues pending management fees first.
    /// @param indexId The index to update.
    /// @param newManagementFeeRate New annual management fee in basis points.
    /// @param newRedemptionFeeRate New redemption fee in basis points.
    function updateFees(
        uint256 indexId,
        uint256 newManagementFeeRate,
        uint256 newRedemptionFeeRate
    ) external onlyOperator validIndex(indexId) {
        if (newManagementFeeRate > MAX_FEE_RATE || newRedemptionFeeRate > MAX_FEE_RATE)
            revert FeeRateTooHigh();
        Index storage index = indices[indexId];
        _accrueManagementFee(indexId);
        index.managementFeeRate = newManagementFeeRate;
        index.redemptionFeeRate = newRedemptionFeeRate;
        emit FeeUpdated(indexId, newManagementFeeRate, newRedemptionFeeRate);
    }

    /// @notice Transfers operator role to a new address.
    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert InvalidAddress();
        emit OperatorTransferred(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Sets a new fee recipient address.
    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert InvalidAddress();
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    // ─────────────────────── User Functions ────────────────────────
    /// @notice Deposits an asset into an index and receives shares.
    /// @param indexId The index to deposit into.
    /// @param asset The ERC20 token to deposit (must be part of the index).
    /// @param amount The amount of tokens to deposit.
    /// @return shares The number of shares minted.
    function deposit(
        uint256 indexId,
        address asset,
        uint256 amount
    ) external nonReentrant validIndex(indexId) returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();
        Index storage index = indices[indexId];
        if (!index.isAsset[asset]) revert AssetNotAllowed();

        _accrueManagementFee(indexId);

        uint256 assetPrice = oracle.getPrice(asset);
        if (assetPrice == 0) revert ZeroAmount();

        if (index.totalShares == 0) {
            // First deposit: shares = depositValue = (amount * assetPrice) / PRECISION
            shares = (amount * assetPrice) / PRECISION;
        } else {
            uint256 totalValue = _getTotalValue(indexId);
            if (totalValue == 0) revert ZeroAmount();
            // Combined multiplication before division to avoid precision loss:
            // shares = (amount * assetPrice * totalShares) / (PRECISION * totalValue)
            shares = (amount * assetPrice * index.totalShares) / (PRECISION * totalValue);
        }
        if (shares == 0) revert ZeroShares();

        // Effects: credit shares before external transfer (checks-effects-interactions)
        index.userShares[msg.sender] += shares;
        index.totalShares += shares;

        // Interactions
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(indexId, msg.sender, asset, amount, shares);
    }

    /// @notice Redeems shares for a proportional basket of the underlying assets.
    /// @param indexId The index to redeem from.
    /// @param shares The number of shares to burn.
    /// @return assetsOut Array of asset addresses returned.
    /// @return assetAmounts Array of asset amounts received, in the same order as the index composition.
    function redeem(
        uint256 indexId,
        uint256 shares
    ) external nonReentrant validIndex(indexId) returns (address[] memory assetsOut, uint256[] memory assetAmounts) {
        if (shares == 0) revert ZeroAmount();
        Index storage index = indices[indexId];
        if (index.userShares[msg.sender] < shares) revert InsufficientShares();

        _accrueManagementFee(indexId);

        uint256 totalShares = index.totalShares;
        if (totalShares == 0) revert ZeroAmount();
        uint256 redemptionFeeRate = index.redemptionFeeRate;

        address[] memory assets = index.assets;
        uint256 len = assets.length;
        assetAmounts = new uint256[](len);

        // Effects: burn shares first (checks-effects-interactions)
        index.userShares[msg.sender] -= shares;
        index.totalShares = totalShares - shares;

        // Interactions: transfer assets to user and fee to recipient
        // Combined multiplication before division to avoid precision loss:
        // userAmount = (balance * shares * (MAX_FEE_RATE - redemptionFeeRate)) / (totalShares * MAX_FEE_RATE)
        // feeAmount  = (balance * shares * redemptionFeeRate) / (totalShares * MAX_FEE_RATE)
        uint256 denom = totalShares * MAX_FEE_RATE;
        uint256 userNum = shares * (MAX_FEE_RATE - redemptionFeeRate);
        uint256 feeNum = shares * redemptionFeeRate;

        for (uint256 i = 0; i < len; i++) {
            address asset = assets[i];
            uint256 balance = IERC20(asset).balanceOf(address(this));
            uint256 userAmount = (balance * userNum) / denom;
            uint256 feeAmount = (balance * feeNum) / denom;
            assetAmounts[i] = userAmount;

            if (userAmount > 0) {
                IERC20(asset).safeTransfer(msg.sender, userAmount);
            }
            if (feeAmount > 0) {
                IERC20(asset).safeTransfer(feeRecipient, feeAmount);
            }
        }

        emit Redeemed(indexId, msg.sender, shares, assets, assetAmounts);
        assetsOut = assets;
    }

    // ────────────────────── Public View Functions ──────────────────
    /// @notice Returns the total USD value of an index (sum of asset balances * price).
    function getTotalValue(uint256 indexId) public view validIndex(indexId) returns (uint256) {
        return _getTotalValue(indexId);
    }

    /// @notice Returns the number of shares a user holds in an index.
    function getUserShares(
        uint256 indexId,
        address user
    ) external view validIndex(indexId) returns (uint256) {
        return indices[indexId].userShares[user];
    }

    /// @notice Returns the array of asset addresses that compose an index.
    function getIndexAssets(
        uint256 indexId
    ) external view validIndex(indexId) returns (address[] memory) {
        return indices[indexId].assets;
    }

    /// @notice Returns the total supply of shares for an index.
    function getTotalShares(uint256 indexId) external view validIndex(indexId) returns (uint256) {
        return indices[indexId].totalShares;
    }

    /// @notice Returns index metadata and fee configuration.
    function getIndexInfo(
        uint256 indexId
    )
        external
        view
        validIndex(indexId)
        returns (
            string memory name,
            uint256 totalShares,
            uint256 managementFeeRate,
            uint256 redemptionFeeRate,
            uint256 lastFeeTimestamp
        )
    {
        Index storage index = indices[indexId];
        return (
            index.name,
            index.totalShares,
            index.managementFeeRate,
            index.redemptionFeeRate,
            index.lastFeeTimestamp
        );
    }

    /// @notice Returns the share price of an index in USD (18 decimals).
    function getSharePrice(uint256 indexId) external view validIndex(indexId) returns (uint256) {
        Index storage index = indices[indexId];
        if (index.totalShares == 0) return 0;
        return (_getTotalValue(indexId) * PRECISION) / index.totalShares;
    }

    /// @notice Returns whether a given asset is part of an index.
    function isAssetInIndex(
        uint256 indexId,
        address asset
    ) external view validIndex(indexId) returns (bool) {
        return indices[indexId].isAsset[asset];
    }

    // ───────────────────── Internal Functions ──────────────────────
    /// @dev Accrues management fees by minting shares to the fee recipient.
    /// Uses a combined formula to avoid divide-before-multiply precision loss:
    ///   sharesToMint = (rate * timeElapsed * totalShares) / (SECONDS_PER_YEAR * MAX_FEE_RATE - rate * timeElapsed)
    function _accrueManagementFee(uint256 indexId) internal {
        Index storage index = indices[indexId];
        // Use <= instead of strict == to guard against timestamp manipulation edge cases
        if (block.timestamp <= index.lastFeeTimestamp) return;
        uint256 timeElapsed = block.timestamp - index.lastFeeTimestamp;

        uint256 totalValue = _getTotalValue(indexId);
        if (totalValue == 0) {
            index.lastFeeTimestamp = block.timestamp;
            return;
        }

        uint256 managementFeeRate = index.managementFeeRate;
        if (managementFeeRate == 0) {
            index.lastFeeTimestamp = block.timestamp;
            return;
        }

        uint256 totalShares = index.totalShares;
        if (totalShares == 0) {
            index.lastFeeTimestamp = block.timestamp;
            return;
        }

        // feeNumerator = managementFeeRate * timeElapsed
        uint256 feeNumerator = managementFeeRate * timeElapsed;
        uint256 yearDenom = SECONDS_PER_YEAR * MAX_FEE_RATE;

        // Guard against pathological case where annualized fee exceeds 100%
        if (feeNumerator >= yearDenom) {
            index.lastFeeTimestamp = block.timestamp;
            return;
        }

        // Combined formula: sharesToMint = (feeNumerator * totalShares) / (yearDenom - feeNumerator)
        // This avoids computing an intermediate feeValue (rounded) and then multiplying,
        // which would cause divide-before-multiply precision loss.
        uint256 denom = yearDenom - feeNumerator;
        uint256 sharesToMint = (feeNumerator * totalShares) / denom;

        if (sharesToMint > 0) {
            index.userShares[feeRecipient] += sharesToMint;
            index.totalShares = totalShares + sharesToMint;
            emit ManagementFeeAccrued(indexId, feeRecipient, sharesToMint);
        }

        index.lastFeeTimestamp = block.timestamp;
    }

    /// @dev Computes the total USD value of an index by summing (balance * price) for each asset.
    function _getTotalValue(uint256 indexId) internal view returns (uint256 totalValue) {
        Index storage index = indices[indexId];
        address[] memory assets = index.assets;
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            uint256 balance = IERC20(asset).balanceOf(address(this));
            if (balance > 0) {
                uint256 price = oracle.getPrice(asset);
                if (price > 0) {
                    totalValue += (balance * price) / PRECISION;
                }
            }
        }
    }
}
