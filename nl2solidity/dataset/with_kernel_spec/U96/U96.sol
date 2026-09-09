// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DerivativesStrategyVault
/// @notice A tokenized vault that accepts a base ERC-20 asset and issues vault
/// shares representing a pro-rata claim on the vault's assets. An owner role can
/// tune the strategy parameters, pause deposits, and set the management fee,
/// while a designated operator role can rebalance the vault's holdings according
/// to the active strategy. The management fee accrues continuously at 0.5% per
/// year of the vault's total value and is captured by minting fee shares to the
/// owner. Virtual shares and assets mitigate inflation/donation attacks.
contract DerivativesStrategyVault {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error ZeroAddress();
    error DepositsPaused();
    error InsufficientDeposit();
    error ZeroShares();
    error ZeroAssets();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidStrategy();
    error InvalidFee();
    error TransferFailed();
    error Reentrancy();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event StrategyUpdated(
        address indexed strategyAddress,
        uint256 targetAllocation,
        uint256 maxLeverage,
        bool active
    );
    event DepositsPauseStateChanged(bool paused);
    event ManagementFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event RebalanceInitiated(address indexed operator, uint256 amount, bool depositToStrategy);
    event FeeAccrued(uint256 feeShares, uint256 totalValueBefore, uint256 elapsed);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MAX_BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10% hard cap
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MIN_DEPOSIT = 100; // 100 base-token units
    uint256 internal constant VIRTUAL_SHARES = 1_000;
    uint256 internal constant VIRTUAL_ASSETS = 1_000;

    bytes4 private constant TRANSFER_FROM_SELECTOR = 0x23b872dd;
    bytes4 private constant TRANSFER_SELECTOR = 0xa9059cbb;
    bytes4 private constant BALANCE_OF_SELECTOR = 0x70a08231;
    bytes4 private constant DECIMALS_SELECTOR = 0x313ce567;

    /*//////////////////////////////////////////////////////////////
                       VAULT SHARE TOKEN STORAGE
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                       VAULT CONFIGURATION STATE
    //////////////////////////////////////////////////////////////*/
    address public immutable baseToken;
    uint8 public immutable baseDecimals;

    address public owner;
    address public operator;
    bool public depositsPaused;

    /// @notice Annual management fee in basis points (default 50 = 0.5%).
    uint256 public managementFeeBps;
    /// @notice Timestamp of the last management-fee accrual.
    uint256 public lastFeeAccrual;

    /// @notice Lifetime base-token deposits credited per user (informational).
    mapping(address => uint256) public userDeposits;

    struct StrategyConfig {
        address strategyAddress; // recipient/manager of rebalanced funds
        uint256 targetAllocation; // target share of total assets deployed (bps)
        uint256 maxLeverage; // maximum leverage permitted, scaled by 1e2
        bool active;
    }

    StrategyConfig public strategy;

    /*//////////////////////////////////////////////////////////////
                              REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/
    bool private _locked;

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _baseToken,
        string memory _name,
        string memory _symbol,
        address _operator
    ) {
        if (_baseToken == address(0) || _operator == address(0)) revert ZeroAddress();
        baseToken = _baseToken;
        baseDecimals = _safeDecimals(_baseToken);
        decimals = baseDecimals;
        name = _name;
        symbol = _symbol;

        owner = msg.sender;
        operator = _operator;
        managementFeeBps = 50; // 0.5% per year
        lastFeeAccrual = block.timestamp;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit ManagementFeeUpdated(0, 50);
    }

    /*//////////////////////////////////////////////////////////////
                       ERC-20 SHARE LOGIC
    //////////////////////////////////////////////////////////////*/
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBal - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 fromBal = balanceOf[from];
        if (fromBal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBal - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal {
        uint256 allowed = allowance[owner_][spender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[owner_][spender] = allowed - amount;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                       ASSET / SHARE ACCOUNTING
    //////////////////////////////////////////////////////////////*/
    function asset() external view returns (address) {
        return baseToken;
    }

    /// @notice Total base assets under vault control, including any assets held
    /// by the active strategy address.
    function totalAssets() public view returns (uint256) {
        uint256 bal = _balanceOf(baseToken, address(this));
        address strat = strategy.strategyAddress;
        if (strat != address(0) && strat != address(this)) {
            bal += _balanceOf(baseToken, strat);
        }
        return bal;
    }

    function _convertToShares(uint256 assets, bool roundUp) internal view returns (uint256) {
        uint256 supply = totalSupply + VIRTUAL_SHARES;
        uint256 ta = totalAssets() + VIRTUAL_ASSETS;
        uint256 numerator = assets * supply;
        uint256 shares = numerator / ta;
        if (roundUp && numerator % ta != 0) {
            shares += 1;
        }
        return shares;
    }

    function _convertToAssets(uint256 shares, bool roundUp) internal view returns (uint256) {
        uint256 supply = totalSupply + VIRTUAL_SHARES;
        uint256 ta = totalAssets() + VIRTUAL_ASSETS;
        uint256 numerator = shares * ta;
        uint256 assets = numerator / supply;
        if (roundUp && numerator % supply != 0) {
            assets += 1;
        }
        return assets;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, false);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, false);
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, false);
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, true);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, true);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, false);
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner_) external view returns (uint256) {
        return _convertToAssets(balanceOf[owner_], false);
    }

    function maxRedeem(address owner_) external view returns (uint256) {
        return balanceOf[owner_];
    }

    /*//////////////////////////////////////////////////////////////
                       DEPOSIT / WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (depositsPaused) revert DepositsPaused();
        if (assets < MIN_DEPOSIT) revert InsufficientDeposit();
        if (receiver == address(0)) revert ZeroAddress();

        _accrueFee();
        shares = _convertToShares(assets, false);
        if (shares < 1) revert ZeroShares();

        userDeposits[receiver] += assets;
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);

        _safeTransferFrom(baseToken, msg.sender, address(this), assets);
    }

    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        if (depositsPaused) revert DepositsPaused();
        if (shares < 1) revert ZeroShares();
        if (receiver == address(0)) revert ZeroAddress();

        _accrueFee();
        assets = _convertToAssets(shares, true);
        if (assets < MIN_DEPOSIT) revert InsufficientDeposit();

        userDeposits[receiver] += assets;
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);

        _safeTransferFrom(baseToken, msg.sender, address(this), assets);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner_
    ) external nonReentrant returns (uint256 shares) {
        if (receiver == address(0)) revert ZeroAddress();
        if (assets < 1) revert ZeroAssets();

        _accrueFee();
        shares = _convertToShares(assets, true);
        if (shares < 1) revert ZeroShares();

        if (msg.sender != owner_) {
            _spendAllowance(owner_, msg.sender, shares);
        }
        if (balanceOf[owner_] < shares) revert InsufficientBalance();

        _burn(owner_, shares);
        _decreaseUserDeposit(owner_, assets);
        emit Withdraw(msg.sender, receiver, owner_, assets, shares);

        _safeTransfer(baseToken, receiver, assets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner_
    ) external nonReentrant returns (uint256 assets) {
        if (receiver == address(0)) revert ZeroAddress();
        if (shares < 1) revert ZeroShares();

        _accrueFee();
        assets = _convertToAssets(shares, false);
        if (assets < 1) revert ZeroAssets();

        if (msg.sender != owner_) {
            _spendAllowance(owner_, msg.sender, shares);
        }
        if (balanceOf[owner_] < shares) revert InsufficientBalance();

        _burn(owner_, shares);
        _decreaseUserDeposit(owner_, assets);
        emit Withdraw(msg.sender, receiver, owner_, assets, shares);

        _safeTransfer(baseToken, receiver, assets);
    }

    function _decreaseUserDeposit(address user, uint256 assets) internal {
        uint256 deposited = userDeposits[user];
        if (deposited > assets) {
            unchecked {
                userDeposits[user] = deposited - assets;
            }
        } else {
            userDeposits[user] = 0;
        }
    }

    /*//////////////////////////////////////////////////////////////
                       MANAGEMENT FEE LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Accrues pending management fees to the owner as vault shares.
    /// Anyone may call this; it is also invoked before every deposit/withdraw.
    function accrueFees() external nonReentrant {
        _accrueFee();
    }

    function _accrueFee() internal {
        uint256 last = lastFeeAccrual;
        if (block.timestamp <= last) return;

        uint256 elapsed = block.timestamp - last;
        lastFeeAccrual = block.timestamp;

        uint256 feeBps = managementFeeBps;
        address feeReceiver = owner;
        if (feeBps == 0 || feeReceiver == address(0)) return;

        uint256 totalValue = totalAssets();
        if (totalValue < 1) return;

        uint256 feeAssets = (totalValue * feeBps * elapsed) / (MAX_BPS * SECONDS_PER_YEAR);
        if (feeAssets < 1) return;

        uint256 feeShares = _convertToShares(feeAssets, false);
        if (feeShares < 1) return;

        _mint(feeReceiver, feeShares);
        emit FeeAccrued(feeShares, totalValue, elapsed);
    }

    /*//////////////////////////////////////////////////////////////
                       STRATEGY / ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/
    function setStrategy(
        address strategyAddress,
        uint256 targetAllocation,
        uint256 maxLeverage,
        bool active
    ) external onlyOwner {
        if (targetAllocation > MAX_BPS) revert InvalidStrategy();
        if (active && strategyAddress == address(0)) revert InvalidStrategy();
        strategy = StrategyConfig({
            strategyAddress: strategyAddress,
            targetAllocation: targetAllocation,
            maxLeverage: maxLeverage,
            active: active
        });
        emit StrategyUpdated(strategyAddress, targetAllocation, maxLeverage, active);
    }

    function setDepositsPaused(bool paused) external onlyOwner {
        depositsPaused = paused;
        emit DepositsPauseStateChanged(paused);
    }

    function setManagementFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        _accrueFee();
        uint256 old = managementFeeBps;
        managementFeeBps = newFeeBps;
        emit ManagementFeeUpdated(old, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR REBALANCE LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Rebalances vault assets either by deploying base tokens to the
    /// active strategy address or by pulling them back into the vault. When
    /// deploying, the amount moved is capped by the strategy target allocation.
    function rebalance(uint256 amount, bool depositToStrategy) external onlyOperator nonReentrant {
        StrategyConfig memory strat = strategy;
        if (!strat.active) revert InvalidStrategy();
        address stratAddr = strat.strategyAddress;
        if (stratAddr == address(0) || stratAddr == address(this)) revert InvalidStrategy();
        if (amount < 1) revert InvalidStrategy();

        _accrueFee();

        if (depositToStrategy) {
            uint256 vaultBal = _balanceOf(baseToken, address(this));
            uint256 stratHeld = _balanceOf(baseToken, stratAddr);
            uint256 total = vaultBal + stratHeld;
            uint256 target = (total * strat.targetAllocation) / MAX_BPS;

            uint256 toMove = _min(amount, vaultBal);
            if (stratHeld < target) {
                uint256 room = target - stratHeld;
                if (toMove > room) toMove = room;
            } else {
                toMove = 0;
            }
            if (toMove < 1) revert InvalidStrategy();

            _safeTransfer(baseToken, stratAddr, toMove);
            emit RebalanceInitiated(msg.sender, toMove, true);
        } else {
            uint256 stratHeld = _balanceOf(baseToken, stratAddr);
            uint256 toMove = _min(amount, stratHeld);
            if (toMove < 1) revert InvalidStrategy();

            _safeTransferFrom(baseToken, stratAddr, address(this), toMove);
            emit RebalanceInitiated(msg.sender, toMove, false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                       LOW-LEVEL TOKEN HELPERS
    //////////////////////////////////////////////////////////////*/
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _balanceOf(address token, address account) internal view returns (uint256) {
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(BALANCE_OF_SELECTOR, account)
        );
        if (ok && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }

    function _safeDecimals(address token) internal view returns (uint8) {
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(DECIMALS_SELECTOR)
        );
        if (ok && data.length >= 32) {
            uint8 d = abi.decode(data, (uint8));
            return d;
        }
        return 18;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(TRANSFER_SELECTOR, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(TRANSFER_FROM_SELECTOR, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
