// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IYieldStrategy {
    function deposit(uint256 amount) external returns (uint256);
    function withdraw(uint256 amount) external returns (uint256);
    function harvest() external returns (uint256);
}

contract YieldGateway {
    // ═══════════════════════════════════════════════════════════════
    //  ERC20 Share Token State
    // ═══════════════════════════════════════════════════════════════
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowances;

    // ═══════════════════════════════════════════════════════════════
    //  Access Control & Reentrancy
    // ═══════════════════════════════════════════════════════════════
    address public owner;
    address public operator;
    address public feeRecipient;
    uint256 private _reentrancyStatus;

    // ═══════════════════════════════════════════════════════════════
    //  Vault State
    // ═══════════════════════════════════════════════════════════════
    IERC20 public immutable asset;
    uint256 internal _totalAssets;
    address[] internal _strategyList;
    mapping(address => bool) internal _isWhitelistedStrategy;
    mapping(address => uint256) internal _strategyAllocation;

    // ═══════════════════════════════════════════════════════════════
    //  Constants
    // ═══════════════════════════════════════════════════════════════
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ═══════════════════════════════════════════════════════════════
    //  Errors
    // ═══════════════════════════════════════════════════════════════
    error BelowMinimumDeposit(uint256 amount, uint256 minimum);
    error ZeroAmount();
    error ZeroShares();
    error ZeroAssets();
    error ZeroAddress();
    error InsufficientShares(address owner, uint256 requested, uint256 available);
    error InsufficientLiquidity(uint256 requested, uint256 available);
    error InsufficientAllowance(uint256 needed, uint256 available);
    error NotOperator();
    error NotOwner();
    error ReentrancyDetected();
    error StrategyNotWhitelisted(address strategy);
    error StrategyAlreadyWhitelisted(address strategy);
    error StrategyHasActiveAllocation(address strategy);
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    // ═══════════════════════════════════════════════════════════════
    //  Events
    // ═══════════════════════════════════════════════════════════════
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 fee);
    event Redeem(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 fee);
    event Rebalance(address indexed strategy, uint256 amount, bool isAllocation);
    event Harvest(address indexed strategy, uint256 yieldAmount);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ═══════════════════════════════════════════════════════════════
    //  Modifiers
    // ═══════════════════════════════════════════════════════════════
    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrancyDetected();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    //  Constructor
    // ═══════════════════════════════════════════════════════════════
    constructor(
        IERC20 _asset,
        address _operator,
        address _feeRecipient,
        string memory _name,
        string memory _symbol
    ) validAddress(_operator) validAddress(_feeRecipient) {
        if (address(_asset) == address(0)) revert ZeroAddress();
        asset = _asset;
        operator = _operator;
        feeRecipient = _feeRecipient;
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        _reentrancyStatus = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════
    //  ERC20 Share Token Functions
    // ═══════════════════════════════════════════════════════════════
    function allowance(address ownerAddr, address spender) external view returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

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

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientShares(from, amount, fromBalance);
        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address ownerAddr, address spender, uint256 amount) internal {
        if (ownerAddr == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    function _spendAllowance(address ownerAddr, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[ownerAddr][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance(amount, currentAllowance);
            _allowances[ownerAddr][spender] = currentAllowance - amount;
        }
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientShares(from, amount, fromBalance);
        balanceOf[from] = fromBalance - amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //  Vault View Functions
    // ═══════════════════════════════════════════════════════════════
    function totalAssets() public view returns (uint256) {
        return _totalAssets;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply < 1 || _totalAssets < 1) return shares;
        return (shares * _totalAssets + supply - 1) / supply;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply < 1 || _totalAssets < 1) return assets;
        return (assets * supply + _totalAssets - 1) / _totalAssets;
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares);
    }

    // ═══════════════════════════════════════════════════════════════
    //  Vault Operations
    // ═══════════════════════════════════════════════════════════════
    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (assets < 1) revert ZeroAmount();
        if (assets < MIN_DEPOSIT) revert BelowMinimumDeposit(assets, MIN_DEPOSIT);
        if (receiver == address(0)) revert ZeroAddress();

        shares = previewDeposit(assets);
        if (shares < 1) revert ZeroShares();

        // Effects before interactions
        _totalAssets += assets;
        _mint(receiver, shares);

        // Interaction
        _safeTransferFrom(asset, msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        if (shares < 1) revert ZeroShares();
        if (receiver == address(0)) revert ZeroAddress();

        assets = previewMint(shares);
        if (assets < 1) revert ZeroAssets();
        if (assets < MIN_DEPOSIT) revert BelowMinimumDeposit(assets, MIN_DEPOSIT);

        // Effects before interactions
        _totalAssets += assets;
        _mint(receiver, shares);

        // Interaction
        _safeTransferFrom(asset, msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address ownerAddr)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (assets < 1) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        if (ownerAddr == address(0)) revert ZeroAddress();

        shares = previewWithdraw(assets);
        if (shares < 1) revert ZeroShares();
        if (balanceOf[ownerAddr] < shares) revert InsufficientShares(ownerAddr, shares, balanceOf[ownerAddr]);

        _spendAllowance(ownerAddr, msg.sender, shares);

        uint256 fee = (assets * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAssets = assets - fee;

        // Effects before interactions
        _burn(ownerAddr, shares);
        _totalAssets -= assets;

        // Interactions
        _ensureLiquidity(assets);
        _safeTransfer(asset, receiver, netAssets);
        if (fee > 0) {
            _safeTransfer(asset, feeRecipient, fee);
        }

        emit Withdraw(msg.sender, receiver, ownerAddr, assets, shares, fee);
    }

    function redeem(uint256 shares, address receiver, address ownerAddr)
        external
        nonReentrant
        returns (uint256 assets)
    {
        if (shares < 1) revert ZeroShares();
        if (receiver == address(0)) revert ZeroAddress();
        if (ownerAddr == address(0)) revert ZeroAddress();
        if (balanceOf[ownerAddr] < shares) revert InsufficientShares(ownerAddr, shares, balanceOf[ownerAddr]);

        _spendAllowance(ownerAddr, msg.sender, shares);

        assets = previewRedeem(shares);
        if (assets < 1) revert ZeroAssets();

        uint256 fee = (assets * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAssets = assets - fee;

        // Effects before interactions
        _burn(ownerAddr, shares);
        _totalAssets -= assets;

        // Interactions
        _ensureLiquidity(assets);
        _safeTransfer(asset, receiver, netAssets);
        if (fee > 0) {
            _safeTransfer(asset, feeRecipient, fee);
        }

        emit Redeem(msg.sender, receiver, ownerAddr, assets, shares, fee);
    }

    // ═══════════════════════════════════════════════════════════════
    //  Strategy Management
    // ═══════════════════════════════════════════════════════════════
    function rebalance(address strategy, uint256 amount) external onlyOperator nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (!_isWhitelistedStrategy[strategy]) revert StrategyNotWhitelisted(strategy);

        uint256 balance = asset.balanceOf(address(this));
        if (balance < amount) revert InsufficientLiquidity(amount, balance);

        // Effects before interactions
        _strategyAllocation[strategy] += amount;

        // Interactions
        _safeTransfer(asset, strategy, amount);
        IYieldStrategy(strategy).deposit(amount);

        emit Rebalance(strategy, amount, true);
    }

    function recall(address strategy, uint256 amount) external onlyOperator nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (!_isWhitelistedStrategy[strategy]) revert StrategyNotWhitelisted(strategy);
        if (_strategyAllocation[strategy] < amount)
            revert InsufficientLiquidity(amount, _strategyAllocation[strategy]);

        // Effects before interactions
        _strategyAllocation[strategy] -= amount;

        // Interaction
        IYieldStrategy(strategy).withdraw(amount);

        emit Rebalance(strategy, amount, false);
    }

    function harvest(address strategy) external onlyOperator nonReentrant {
        if (!_isWhitelistedStrategy[strategy]) revert StrategyNotWhitelisted(strategy);

        uint256 balanceBefore = asset.balanceOf(address(this));
        IYieldStrategy(strategy).harvest();
        uint256 balanceAfter = asset.balanceOf(address(this));

        uint256 yieldAmount = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
        if (yieldAmount > 0) {
            _totalAssets += yieldAmount;
        }

        emit Harvest(strategy, yieldAmount);
    }

    function addStrategy(address strategy) external onlyOperator validAddress(strategy) {
        if (_isWhitelistedStrategy[strategy]) revert StrategyAlreadyWhitelisted(strategy);
        _isWhitelistedStrategy[strategy] = true;
        _strategyList.push(strategy);
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external onlyOperator {
        if (!_isWhitelistedStrategy[strategy]) revert StrategyNotWhitelisted(strategy);
        if (_strategyAllocation[strategy] > 0) revert StrategyHasActiveAllocation(strategy);

        _isWhitelistedStrategy[strategy] = false;
        uint256 len = _strategyList.length;
        for (uint256 i = 0; i < len; i++) {
            if (_strategyList[i] == strategy) {
                _strategyList[i] = _strategyList[len - 1];
                _strategyList.pop();
                break;
            }
        }
        emit StrategyRemoved(strategy);
    }

    // ═══════════════════════════════════════════════════════════════
    //  Admin Functions
    // ═══════════════════════════════════════════════════════════════
    function setOperator(address newOperator) external onlyOwner validAddress(newOperator) {
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner validAddress(newRecipient) {
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner validAddress(newOwner) {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ═══════════════════════════════════════════════════════════════
    //  View Functions
    // ═══════════════════════════════════════════════════════════════
    function isWhitelistedStrategy(address strategy) external view returns (bool) {
        return _isWhitelistedStrategy[strategy];
    }

    function strategyAllocation(address strategy) external view returns (uint256) {
        return _strategyAllocation[strategy];
    }

    function strategyCount() external view returns (uint256) {
        return _strategyList.length;
    }

    function availableLiquidity() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function totalStrategyAllocations() external view returns (uint256) {
        uint256 total = 0;
        uint256 len = _strategyList.length;
        for (uint256 i = 0; i < len; i++) {
            total += _strategyAllocation[_strategyList[i]];
        }
        return total;
    }

    // ═══════════════════════════════════════════════════════════════
    //  Internal Helpers
    // ═══════════════════════════════════════════════════════════════
    function _convertToShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply < 1 || _totalAssets < 1) return assets;
        return (assets * supply) / _totalAssets;
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply < 1) return 0;
        return (shares * _totalAssets) / supply;
    }

    function _ensureLiquidity(uint256 amount) internal {
        uint256 balance = asset.balanceOf(address(this));
        if (balance >= amount) return;

        uint256 deficit = amount - balance;
        uint256 len = _strategyList.length;
        for (uint256 i = 0; i < len && deficit > 0; i++) {
            address strategy = _strategyList[i];
            uint256 allocation = _strategyAllocation[strategy];
            if (allocation < 1) continue;
            uint256 toRecall = allocation < deficit ? allocation : deficit;
            // Effects before interactions
            _strategyAllocation[strategy] -= toRecall;
            deficit -= toRecall;
            // Interaction
            IYieldStrategy(strategy).withdraw(toRecall);
        }

        uint256 finalBalance = asset.balanceOf(address(this));
        if (finalBalance < amount) revert InsufficientLiquidity(amount, finalBalance);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert SafeTransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert SafeTransferFromFailed();
    }
}
