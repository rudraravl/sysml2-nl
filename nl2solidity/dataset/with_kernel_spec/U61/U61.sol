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

interface IStrategy {
    function invest(address token, uint256 amount) external;
    function divest(address token, uint256 amount) external returns (uint256 returned);
    function balanceOf(address token) external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract ERC20 is IERC20, IERC20Metadata {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view virtual override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _allowances[from][msg.sender] = currentAllowance - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: insufficient balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual {
        require(owner_ != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _mint(address to, uint256 amount) internal virtual {
        require(to != address(0), "ERC20: mint to zero address");
        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: burn from zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: burn exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}

contract AssetVault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ ERRORS ============
    error ZeroAddress();
    error Unauthorized();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error InsufficientShares();
    error InsufficientLiquidity();
    error StrategyLimitReached();
    error StrategyAlreadyActive();
    error InvalidFee();
    error InvalidAmount();
    error NoAssetsConfigured();
    error InvalidIndex();
    error UnsupportedSweep();

    // ============ CONSTANTS ============
    uint256 public constant MAX_STRATEGIES = 10;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public constant DEFAULT_WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant MAX_FEE_BPS = 1000;              // 10%

    // ============ STATE ============
    address public operator;
    uint256 public withdrawalFeeBps;
    address public feeRecipient;

    address[] public supportedAssets;
    mapping(address => bool) public isSupportedAsset;
    mapping(address => uint8) public assetDecimals;

    IStrategy[] public activeStrategies;
    mapping(address => bool) public isActiveStrategy;

    mapping(address => mapping(address => uint256)) public userDeposits;

    // ============ EVENTS ============
    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address[] assets, uint256[] amounts, uint256 shares, uint256 totalFee);
    event Redeem(address indexed user, address indexed asset, uint256 amountOut, uint256 shares, uint256 fee);
    event StrategyUpgraded(address indexed oldStrategy, address indexed newStrategy);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event Rebalance(address indexed strategy, address indexed token, uint256 amount, bool isInvest);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event AssetAdded(address indexed asset);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ============ MODIFIERS ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // ============ CONSTRUCTOR ============
    constructor(address[] memory _assets, address _feeRecipient)
        ERC20("Asset Vault Receipt", "AVR", 18)
        Ownable(msg.sender)
    {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_assets.length == 0) revert NoAssetsConfigured();
        feeRecipient = _feeRecipient;
        operator = msg.sender;
        withdrawalFeeBps = DEFAULT_WITHDRAWAL_FEE_BPS;
        for (uint256 i = 0; i < _assets.length; i++) {
            _addAsset(_assets[i]);
        }
    }

    // ============ INTERNAL: ASSET MANAGEMENT ============
    function _addAsset(address asset) internal {
        if (asset == address(0)) revert ZeroAddress();
        if (isSupportedAsset[asset]) revert AssetAlreadySupported();
        isSupportedAsset[asset] = true;
        assetDecimals[asset] = IERC20Metadata(asset).decimals();
        supportedAssets.push(asset);
        emit AssetAdded(asset);
    }

    function _normalizeTo18(address asset, uint256 amount) internal view returns (uint256) {
        uint8 d = assetDecimals[asset];
        if (d <= 18) {
            return amount * (10 ** (18 - d));
        }
        return amount / (10 ** (d - 18));
    }

    // ============ INTERNAL: STRATEGY DIVESTING ============
    // Does not read strategy balance before the external call to avoid stale data.
    // Requests the full remaining amount; the strategy returns what it can.
    function _divestFromStrategies(address asset, uint256 needed) internal {
        if (needed <= 0) return;
        uint256 remaining = needed;
        for (uint256 i = 0; i < activeStrategies.length && remaining > 0; i++) {
            uint256 toDivest = remaining;
            uint256 returned = activeStrategies[i].divest(asset, toDivest);
            if (returned >= remaining) {
                remaining = 0;
            } else {
                remaining -= returned;
            }
        }
        if (remaining > 0) revert InsufficientLiquidity();
    }

    function _forceApprove(address token, address spender, uint256 amount) internal {
        IERC20(token).safeApprove(spender, 0);
        IERC20(token).safeApprove(spender, amount);
    }

    // ============ PUBLIC VIEWS ============
    function totalAssetBalance(address asset) public view returns (uint256) {
        uint256 bal = IERC20(asset).balanceOf(address(this));
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            bal += activeStrategies[i].balanceOf(asset);
        }
        return bal;
    }

    function vaultValue() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            sum += _normalizeTo18(asset, totalAssetBalance(asset));
        }
        return sum;
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function getActiveStrategies() external view returns (address[] memory) {
        address[] memory result = new address[](activeStrategies.length);
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            result[i] = address(activeStrategies[i]);
        }
        return result;
    }

    function activeStrategyCount() external view returns (uint256) {
        return activeStrategies.length;
    }

    function supportedAssetCount() external view returns (uint256) {
        return supportedAssets.length;
    }

    function previewDeposit(address asset, uint256 amount) external view returns (uint256) {
        if (!isSupportedAsset[asset]) revert AssetNotSupported();
        uint256 normalizedAmount = _normalizeTo18(asset, amount);
        uint256 ts = totalSupply();
        uint256 currentValue = vaultValue();
        if (ts < 1 || currentValue < 1) return normalizedAmount;
        return (normalizedAmount * ts) / currentValue;
    }

    // ============ USER: DEPOSIT ============
    function deposit(address asset, uint256 amount) external nonReentrant returns (uint256 shares) {
        if (!isSupportedAsset[asset]) revert AssetNotSupported();
        if (amount <= 0) revert InvalidAmount();

        uint256 currentValue = vaultValue();
        uint256 normalizedAmount = _normalizeTo18(asset, amount);
        uint256 ts = totalSupply();

        if (ts < 1 || currentValue < 1) {
            shares = normalizedAmount;
        } else {
            shares = (normalizedAmount * ts) / currentValue;
        }
        if (shares < 1) revert InvalidAmount();

        // Effects
        userDeposits[msg.sender][asset] += amount;
        _mint(msg.sender, shares);

        // Interactions
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, asset, amount, shares);
    }

    // ============ USER: WITHDRAW (proportional basket) ============
    function withdraw(uint256 shares)
        external
        nonReentrant
        returns (address[] memory assets, uint256[] memory amounts, uint256 totalFee)
    {
        if (shares <= 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < shares) revert InsufficientShares();

        uint256 ts = totalSupply();
        uint256 assetCount = supportedAssets.length;
        assets = new address[](assetCount);
        amounts = new uint256[](assetCount);
        uint256[] memory grossAmounts = new uint256[](assetCount);
        uint256[] memory fees = new uint256[](assetCount);
        totalFee = 0;

        // Compute gross amounts and fees independently to avoid divide-before-multiply
        for (uint256 i = 0; i < assetCount; i++) {
            address asset = supportedAssets[i];
            uint256 totalBal = totalAssetBalance(asset);
            grossAmounts[i] = (totalBal * shares) / ts;
            // Fee computed from raw numerator to avoid multiplying a divided result
            fees[i] = (totalBal * shares * withdrawalFeeBps) / (ts * FEE_PRECISION);
            assets[i] = asset;
        }

        // Effects: update user deposits and burn shares
        for (uint256 i = 0; i < assetCount; i++) {
            address asset = supportedAssets[i];
            if (grossAmounts[i] <= 0) continue;
            uint256 userDep = userDeposits[msg.sender][asset];
            if (userDep >= grossAmounts[i]) {
                userDeposits[msg.sender][asset] = userDep - grossAmounts[i];
            } else {
                userDeposits[msg.sender][asset] = 0;
            }
        }
        _burn(msg.sender, shares);

        // Interactions: divest and transfer
        for (uint256 i = 0; i < assetCount; i++) {
            address asset = supportedAssets[i];
            uint256 grossAmount = grossAmounts[i];
            if (grossAmount <= 0) continue;

            uint256 vaultBal = IERC20(asset).balanceOf(address(this));
            if (vaultBal < grossAmount) {
                _divestFromStrategies(asset, grossAmount - vaultBal);
            }

            uint256 userAmount = grossAmount - fees[i];
            amounts[i] = userAmount;
            if (userAmount > 0) IERC20(asset).safeTransfer(msg.sender, userAmount);
            if (fees[i] > 0) IERC20(asset).safeTransfer(feeRecipient, fees[i]);
            totalFee += fees[i];
        }

        emit Withdraw(msg.sender, assets, amounts, shares, totalFee);
    }

    // ============ USER: REDEEM (single asset) ============
    function redeem(uint256 shares, address asset)
        external
        nonReentrant
        returns (uint256 amountOut, uint256 fee)
    {
        if (!isSupportedAsset[asset]) revert AssetNotSupported();
        if (shares <= 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < shares) revert InsufficientShares();

        uint256 ts = totalSupply();
        uint256 totalBal = totalAssetBalance(asset);
        amountOut = (totalBal * shares) / ts;
        if (amountOut <= 0) revert InvalidAmount();

        // Fee computed from raw numerator to avoid multiplying a divided result
        fee = (totalBal * shares * withdrawalFeeBps) / (ts * FEE_PRECISION);
        uint256 userAmount = amountOut - fee;

        // Effects
        uint256 userDep = userDeposits[msg.sender][asset];
        if (userDep >= amountOut) {
            userDeposits[msg.sender][asset] = userDep - amountOut;
        } else {
            userDeposits[msg.sender][asset] = 0;
        }
        _burn(msg.sender, shares);

        // Interactions
        uint256 vaultBal = IERC20(asset).balanceOf(address(this));
        if (vaultBal < amountOut) {
            _divestFromStrategies(asset, amountOut - vaultBal);
        }
        if (userAmount > 0) IERC20(asset).safeTransfer(msg.sender, userAmount);
        if (fee > 0) IERC20(asset).safeTransfer(feeRecipient, fee);

        emit Redeem(msg.sender, asset, amountOut, shares, fee);
    }

    // ============ OWNER: ASSET CONFIG ============
    function addAsset(address asset) external onlyOwner {
        _addAsset(asset);
    }

    // ============ OPERATOR: STRATEGY MANAGEMENT ============
    function addStrategy(IStrategy strategy) external onlyOperator nonReentrant {
        if (address(strategy) == address(0)) revert ZeroAddress();
        if (activeStrategies.length >= MAX_STRATEGIES) revert StrategyLimitReached();
        if (isActiveStrategy[address(strategy)]) revert StrategyAlreadyActive();

        activeStrategies.push(strategy);
        isActiveStrategy[address(strategy)] = true;

        emit StrategyUpgraded(address(0), address(strategy));
        emit StrategyAdded(address(strategy));
    }

    function removeStrategy(uint256 index) external onlyOperator nonReentrant {
        if (index >= activeStrategies.length) revert InvalidIndex();
        IStrategy oldStrategy = activeStrategies[index];

        // Effects first: update state before any external calls
        uint256 lastIdx = activeStrategies.length - 1;
        isActiveStrategy[address(oldStrategy)] = false;
        if (index != lastIdx) {
            activeStrategies[index] = activeStrategies[lastIdx];
        }
        activeStrategies.pop();

        emit StrategyRemoved(address(oldStrategy));
        emit StrategyUpgraded(address(oldStrategy), address(0));

        // Interactions: divest all assets from the old strategy
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            uint256 bal = oldStrategy.balanceOf(asset);
            if (bal > 0) {
                oldStrategy.divest(asset, bal);
            }
        }
    }

    function upgradeStrategy(uint256 index, IStrategy newStrategy) external onlyOperator nonReentrant {
        if (index >= activeStrategies.length) revert InvalidIndex();
        if (address(newStrategy) == address(0)) revert ZeroAddress();
        if (isActiveStrategy[address(newStrategy)]) revert StrategyAlreadyActive();

        IStrategy oldStrategy = activeStrategies[index];

        // Effects first: swap strategy in array and update mapping before external calls
        activeStrategies[index] = newStrategy;
        isActiveStrategy[address(oldStrategy)] = false;
        isActiveStrategy[address(newStrategy)] = true;

        emit StrategyUpgraded(address(oldStrategy), address(newStrategy));

        // Interactions: divest all assets from the old strategy
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            uint256 bal = oldStrategy.balanceOf(asset);
            if (bal > 0) {
                oldStrategy.divest(asset, bal);
            }
        }
    }

    // ============ OPERATOR: REBALANCE ============
    function rebalance(address asset, uint256 amount, uint256 strategyIndex, bool isInvest)
        external
        onlyOperator
        nonReentrant
    {
        if (!isSupportedAsset[asset]) revert AssetNotSupported();
        if (strategyIndex >= activeStrategies.length) revert InvalidIndex();
        if (amount <= 0) revert InvalidAmount();

        IStrategy strategy = activeStrategies[strategyIndex];

        if (isInvest) {
            uint256 vaultBal = IERC20(asset).balanceOf(address(this));
            if (vaultBal < amount) revert InsufficientLiquidity();
            _forceApprove(asset, address(strategy), amount);
            strategy.invest(asset, amount);
        } else {
            uint256 stratBal = strategy.balanceOf(asset);
            if (stratBal < amount) revert InsufficientLiquidity();
            strategy.divest(asset, amount);
        }

        emit Rebalance(address(strategy), asset, amount, isInvest);
    }

    function rebalanceBetweenStrategies(address asset, uint256 amount, uint256 fromIdx, uint256 toIdx)
        external
        onlyOperator
        nonReentrant
    {
        if (!isSupportedAsset[asset]) revert AssetNotSupported();
        if (fromIdx >= activeStrategies.length || toIdx >= activeStrategies.length) revert InvalidIndex();
        if (fromIdx == toIdx) revert InvalidIndex();
        if (amount <= 0) revert InvalidAmount();

        IStrategy fromStrategy = activeStrategies[fromIdx];
        IStrategy toStrategy = activeStrategies[toIdx];

        uint256 stratBal = fromStrategy.balanceOf(asset);
        if (stratBal < amount) revert InsufficientLiquidity();

        uint256 returned = fromStrategy.divest(asset, amount);
        if (returned <= 0) revert InvalidAmount();

        _forceApprove(asset, address(toStrategy), returned);
        toStrategy.invest(asset, returned);

        emit Rebalance(address(fromStrategy), asset, amount, false);
        emit Rebalance(address(toStrategy), asset, returned, true);
    }

    // ============ OPERATOR: FEES ============
    function setWithdrawalFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 oldFee = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit FeeUpdated(oldFee, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    // ============ OWNER: SAFETY ============
    function sweep(address token, address to, uint256 amount) external onlyOwner {
        if (isSupportedAsset[token]) revert UnsupportedSweep();
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
    }
}
