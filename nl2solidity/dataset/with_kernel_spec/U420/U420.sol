// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PortfolioManager {
    error ErrZeroAddress();
    error ErrSameAddress();
    error ErrPaused();
    error ErrNotOperator();
    error ErrAssetNotSupported();
    error ErrAssetAlreadySupported();
    error ErrMaxAssetsReached();
    error ErrAssetInUse();
    error ErrInsufficientBalance();
    error ErrInvalidAmount();
    error ErrLimitExceeded();
    error ErrSameToken();
    error ErrRouterNotAllowed();
    error ErrSwapFailed();
    error ErrInsufficientSwapOutput();
    error ErrTransferFailed();
    error ErrNoFeesToCollect();
    error ErrReentrant();

    uint256 public constant MAX_ASSETS = 50;
    uint256 public constant ANNUAL_MANAGEMENT_FEE_BPS = 10; // 0.1%
    uint256 public constant MONTHLY_INTERVAL = 30 days;
    uint256 public constant MAX_TRADING_FEE_BPS = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000 * 12 * MONTHLY_INTERVAL;

    address public operator;
    bool public paused;
    uint256 public tradingFeeBps;

    address[] public supportedAssets;
    mapping(address => bool) public isSupportedAsset;
    mapping(address => uint256) public depositCap;
    mapping(address => uint256) public totalDeposited;
    mapping(address => mapping(address => uint256)) public portfolioBalances;
    mapping(address => uint256) public lastFeeDeduction;
    mapping(address => uint256) public accruedFees;
    mapping(address => bool) public allowedRouters;

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Rebalance(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event PortfolioTransferred(address indexed from, address indexed to);
    event AssetAdded(address indexed token);
    event AssetRemoved(address indexed token);
    event TradingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event DepositCapSet(address indexed token, uint256 cap);
    event RouterStatusUpdated(address indexed router, bool allowed);
    event Paused(address indexed caller);
    event Unpaused(address indexed caller);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event ManagementFeeDeducted(address indexed user, uint256 totalFee);
    event FeesCollected(address indexed token, address indexed collector, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrNotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ErrPaused();
        _;
    }

    modifier onlySupportedAsset(address token) {
        if (!isSupportedAsset[token]) revert ErrAssetNotSupported();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ErrReentrant();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    constructor(address _operator, uint256 _tradingFeeBps) {
        if (_operator == address(0)) revert ErrZeroAddress();
        if (_tradingFeeBps > MAX_TRADING_FEE_BPS) revert ErrLimitExceeded();
        operator = _operator;
        tradingFeeBps = _tradingFeeBps;
        _reentrancyStatus = _NOT_ENTERED;
    }

    function deposit(address token, uint256 amount)
        external
        whenNotPaused
        onlySupportedAsset(token)
        nonReentrant
    {
        if (amount == 0) revert ErrInvalidAmount();
        _accrueManagementFee(msg.sender);
        if (depositCap[token] > 0 && totalDeposited[token] + amount > depositCap[token]) {
            revert ErrLimitExceeded();
        }
        // Effects before interactions
        portfolioBalances[msg.sender][token] += amount;
        totalDeposited[token] += amount;
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount)
        external
        whenNotPaused
        onlySupportedAsset(token)
        nonReentrant
    {
        if (amount == 0) revert ErrInvalidAmount();
        _accrueManagementFee(msg.sender);
        if (portfolioBalances[msg.sender][token] < amount) revert ErrInsufficientBalance();
        // Effects before interactions
        portfolioBalances[msg.sender][token] -= amount;
        totalDeposited[token] -= amount;
        _safeTransfer(token, msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    function rebalance(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address router,
        bytes calldata swapData
    ) external whenNotPaused onlySupportedAsset(tokenIn) onlySupportedAsset(tokenOut) nonReentrant {
        if (amountIn == 0) revert ErrInvalidAmount();
        if (tokenIn == tokenOut) revert ErrSameToken();
        if (!allowedRouters[router]) revert ErrRouterNotAllowed();

        _accrueManagementFee(msg.sender);
        if (portfolioBalances[msg.sender][tokenIn] < amountIn) revert ErrInsufficientBalance();

        uint256 fee = (amountIn * tradingFeeBps) / 10000;
        uint256 swapAmount = amountIn - fee;

        // Effects: deduct tokenIn before external call
        portfolioBalances[msg.sender][tokenIn] -= amountIn;
        totalDeposited[tokenIn] -= amountIn;
        if (fee > 0) accruedFees[tokenIn] += fee;

        // Interactions: execute swap
        uint256 amountOut = _executeSwap(tokenIn, tokenOut, router, swapAmount, swapData);
        if (amountOut < minAmountOut) revert ErrInsufficientSwapOutput();

        // Effects: credit tokenOut after swap (protected by nonReentrant)
        portfolioBalances[msg.sender][tokenOut] += amountOut;
        totalDeposited[tokenOut] += amountOut;

        emit Rebalance(msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    function _executeSwap(
        address tokenIn,
        address tokenOut,
        address router,
        uint256 swapAmount,
        bytes calldata swapData
    ) internal returns (uint256 amountOut) {
        _safeApprove(tokenIn, router, 0);
        if (swapAmount > 0) {
            _safeApprove(tokenIn, router, swapAmount);
        }

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        (bool success, ) = router.call(swapData);
        if (!success) revert ErrSwapFailed();
        uint256 balanceAfter = IERC20(tokenOut).balanceOf(address(this));

        // Compare immediately after reading balanceAfter, before any other external call
        if (balanceAfter < balanceBefore) revert ErrInsufficientSwapOutput();
        amountOut = balanceAfter - balanceBefore;

        // Reset approval after balance comparison
        _safeApprove(tokenIn, router, 0);
    }

    function transferPortfolio(address to) external whenNotPaused nonReentrant {
        if (to == address(0)) revert ErrZeroAddress();
        if (to == msg.sender) revert ErrSameAddress();

        _accrueManagementFee(msg.sender);
        _accrueManagementFee(to);

        _transferAllAssets(msg.sender, to);

        lastFeeDeduction[msg.sender] = 0;
        lastFeeDeduction[to] = block.timestamp;

        emit PortfolioTransferred(msg.sender, to);
    }

    function _transferAllAssets(address from, address to) internal {
        address[] storage assets = supportedAssets;
        uint256 len = assets.length;
        for (uint256 i = 0; i < len; ) {
            address token = assets[i];
            uint256 balance = portfolioBalances[from][token];
            if (balance > 0) {
                portfolioBalances[from][token] = 0;
                portfolioBalances[to][token] += balance;
            }
            unchecked {
                ++i;
            }
        }
    }

    function applyManagementFee(address user) external whenNotPaused {
        _accrueManagementFee(user);
    }

    function addAsset(address token) external onlyOperator {
        if (token == address(0)) revert ErrZeroAddress();
        if (isSupportedAsset[token]) revert ErrAssetAlreadySupported();
        if (supportedAssets.length >= MAX_ASSETS) revert ErrMaxAssetsReached();
        isSupportedAsset[token] = true;
        supportedAssets.push(token);
        emit AssetAdded(token);
    }

    function removeAsset(address token) external onlyOperator {
        if (!isSupportedAsset[token]) revert ErrAssetNotSupported();
        if (totalDeposited[token] > 0) revert ErrAssetInUse();
        isSupportedAsset[token] = false;
        _removeFromAssetArray(token);
        emit AssetRemoved(token);
    }

    function _removeFromAssetArray(address token) internal {
        address[] storage assets = supportedAssets;
        uint256 len = assets.length;
        for (uint256 i = 0; i < len; i++) {
            if (assets[i] == token) {
                assets[i] = assets[len - 1];
                assets.pop();
                break;
            }
        }
    }

    function setTradingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_TRADING_FEE_BPS) revert ErrLimitExceeded();
        uint256 old = tradingFeeBps;
        tradingFeeBps = newFeeBps;
        emit TradingFeeUpdated(old, newFeeBps);
    }

    function setDepositCap(address token, uint256 cap) external onlyOperator {
        if (token == address(0)) revert ErrZeroAddress();
        depositCap[token] = cap;
        emit DepositCapSet(token, cap);
    }

    function setRouter(address router, bool allowed) external onlyOperator {
        if (router == address(0)) revert ErrZeroAddress();
        allowedRouters[router] = allowed;
        emit RouterStatusUpdated(router, allowed);
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ErrZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function collectFees(address token) external onlyOperator nonReentrant {
        if (token == address(0)) revert ErrZeroAddress();
        uint256 amount = accruedFees[token];
        if (amount == 0) revert ErrNoFeesToCollect();
        accruedFees[token] = 0;
        _safeTransfer(token, operator, amount);
        emit FeesCollected(token, operator, amount);
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function getSupportedAssetCount() external view returns (uint256) {
        return supportedAssets.length;
    }

    function getPortfolioValue(address user) external view returns (uint256) {
        return _getPortfolioValue(user);
    }

    function _getPortfolioValue(address user) internal view returns (uint256 totalValue) {
        address[] storage assets = supportedAssets;
        uint256 len = assets.length;
        for (uint256 i = 0; i < len; ) {
            totalValue += portfolioBalances[user][assets[i]];
            unchecked {
                ++i;
            }
        }
    }

    function _accrueManagementFee(address user) internal {
        uint256 last = lastFeeDeduction[user];
        if (last < 1) {
            lastFeeDeduction[user] = block.timestamp;
            return;
        }
        if (block.timestamp <= last) return;

        uint256 elapsed = block.timestamp - last;
        if (elapsed < MONTHLY_INTERVAL) return;

        uint256 totalValue = _getPortfolioValue(user);
        // Use modulo to compute newLast without divide-before-multiply
        uint256 newLast = block.timestamp - (elapsed % MONTHLY_INTERVAL);

        if (totalValue < 1) {
            lastFeeDeduction[user] = newLast;
            return;
        }

        // All multiplications before division to avoid divide-before-multiply
        uint256 fee = (totalValue * ANNUAL_MANAGEMENT_FEE_BPS * elapsed) / FEE_DENOMINATOR;

        if (fee < 1) {
            lastFeeDeduction[user] = newLast;
            return;
        }
        if (fee > totalValue) fee = totalValue;

        uint256 totalDeducted = _deductFeeProportional(user, fee, totalValue);

        lastFeeDeduction[user] = newLast;
        if (totalDeducted > 0) emit ManagementFeeDeducted(user, totalDeducted);
    }

    function _deductFeeProportional(
        address user,
        uint256 fee,
        uint256 totalValue
    ) internal returns (uint256 totalDeducted) {
        address[] storage assets = supportedAssets;
        uint256 len = assets.length;
        for (uint256 i = 0; i < len; i++) {
            address token = assets[i];
            uint256 balance = portfolioBalances[user][token];
            if (balance > 0) {
                uint256 assetFee = (balance * fee) / totalValue;
                if (assetFee > balance) assetFee = balance;
                if (assetFee > 0) {
                    portfolioBalances[user][token] -= assetFee;
                    totalDeposited[token] -= assetFee;
                    accruedFees[token] += assetFee;
                    totalDeducted += assetFee;
                }
            }
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert ErrTransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert ErrTransferFailed();
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert ErrTransferFailed();
    }
}
