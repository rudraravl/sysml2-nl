// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract PrivateCreditPool is IERC20, IERC20Metadata {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant MANAGEMENT_FEE_BPS = 50;
    uint256 public constant BPS = 10_000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    uint256 private constant VIRTUAL_SHARES = 10_000;
    uint256 private constant VIRTUAL_ASSETS = 10_000;

    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }
    mapping(address => Snapshots) private _accountSnapshots;
    uint256 private _currentSnapshotId;

    mapping(bytes32 => mapping(address => bool)) private _roles;

    uint256 private _lock = 1;

    IERC20 public immutable stablecoin;
    uint8 private immutable _stablecoinDecimals;
    address public treasury;

    uint256 public immutable MIN_DEPOSIT;

    uint256 public totalAssetsUnderManagement;
    uint256 public totalInvested;
    uint256 public accumulatedManagementFee;
    uint40 public lastFeeTimestamp;

    mapping(address => uint256) public depositedStablecoin;

    struct Investment {
        address assetToken;
        uint256 stablecoinInvested;
        uint256 maturity;
        uint256 expectedReturn;
        bool active;
        bool distributed;
        uint256 distributedAmount;
        uint256 totalReceiptsAtDistribution;
        uint256 snapshotId;
    }
    mapping(uint256 => Investment) public investments;
    uint256 public nextInvestmentId;

    mapping(uint256 => mapping(address => uint256)) public claimedReceipts;
    mapping(uint256 => uint256) public totalClaimedAssets;

    struct StrategyConfig {
        string name;
        uint256 targetAllocationBps;
        bool active;
    }
    mapping(uint256 => StrategyConfig) public strategies;
    uint256 public nextStrategyId;

    event Deposit(address indexed investor, uint256 stablecoinAmount, uint256 receiptAmount, uint256 timestamp);
    event Withdrawal(address indexed investor, uint256 receiptAmount, uint256 stablecoinAmount, uint256 timestamp);
    event Redemption(
        address indexed investor,
        uint256 indexed investmentId,
        uint256 receiptAmount,
        uint256 assetAmount,
        address indexed assetToken
    );
    event InvestmentAdded(
        uint256 indexed investmentId,
        address indexed assetToken,
        uint256 maturity,
        uint256 expectedReturn
    );
    event AssetPurchased(
        uint256 indexed investmentId,
        address indexed destination,
        uint256 stablecoinAmount,
        uint256 timestamp
    );
    event DistributionCompleted(
        uint256 indexed investmentId,
        address indexed assetToken,
        uint256 returnAmount,
        int256 profit,
        uint256 timestamp
    );
    event StrategyConfigured(uint256 indexed strategyId, string name, uint256 targetAllocationBps);
    event ManagementFeeAccrued(uint256 feeAmount, uint256 timestamp);
    event ManagementFeeClaimed(address indexed treasury, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    error ZeroAddress();
    error ZeroAmount();
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientBalance(uint256 have, uint256 want);
    error InsufficientLiquidity(uint256 required, uint256 available);
    error InvestmentNotActive(uint256 investmentId);
    error InvestmentAlreadyDistributed(uint256 investmentId);
    error InvestmentNotDistributed(uint256 investmentId);
    error InvestmentNotMatured(uint256 investmentId, uint256 maturity, uint256 currentTime);
    error InvalidMaturity();
    error NothingToClaim();
    error AllocationTooHigh(uint256 requested, uint256 maximum);
    error ExceedsDistributedAmount();
    error InsufficientSnapshotBalance();
    error UnauthorizedRole(bytes32 role);
    error SafeTransferFailed();
    error ReentrantCall();

    modifier onlyRole(bytes32 role) {
        if (!_roles[role][msg.sender]) revert UnauthorizedRole(role);
        _;
    }

    modifier nonReentrant() {
        if (_lock != 1) revert ReentrantCall();
        _lock = 2;
        _;
        _lock = 1;
    }

    modifier accruesFee() {
        _accrueManagementFee();
        _;
    }

    constructor(
        address _stablecoin,
        address _treasury,
        string memory receiptName,
        string memory receiptSymbol
    ) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        _stablecoinDecimals = _tryGetDecimals(_stablecoin);
        treasury = _treasury;
        _name = receiptName;
        _symbol = receiptSymbol;
        _decimals = _stablecoinDecimals;
        MIN_DEPOSIT = 1000 * (10 ** uint256(_stablecoinDecimals));
        lastFeeTimestamp = uint40(block.timestamp);

        _roles[DEFAULT_ADMIN_ROLE][msg.sender] = true;
        _roles[OPERATOR_ROLE][msg.sender] = true;
        emit RoleGranted(DEFAULT_ADMIN_ROLE, msg.sender);
        emit RoleGranted(OPERATOR_ROLE, msg.sender);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientBalance(allowed, amount);
            unchecked {
                _allowances[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 current = _allowances[msg.sender][spender];
        if (current < subtractedValue) revert InsufficientBalance(current, subtractedValue);
        unchecked {
            _approve(msg.sender, spender, current - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(fromBalance, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        _updateAccountSnapshot(from);
        _updateAccountSnapshot(to);
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }
        _updateAccountSnapshot(to);
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(fromBalance, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }
        _updateAccountSnapshot(from);
        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _snapshot() internal returns (uint256) {
        unchecked {
            _currentSnapshotId += 1;
        }
        return _currentSnapshotId;
    }

    function _updateAccountSnapshot(address account) internal {
        Snapshots storage snaps = _accountSnapshots[account];
        uint256 currentId = _currentSnapshotId;
        if (snaps.ids.length == 0 || snaps.ids[snaps.ids.length - 1] < currentId) {
            snaps.ids.push(currentId);
            snaps.values.push(_balances[account]);
        } else {
            snaps.values[snaps.values.length - 1] = _balances[account];
        }
    }

    function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256) {
        Snapshots storage snaps = _accountSnapshots[account];
        uint256 len = snaps.ids.length;
        if (len == 0) return 0;
        uint256 low = 0;
        uint256 high = len;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (snaps.ids[mid] <= snapshotId) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        if (low == 0) return 0;
        return snaps.values[low - 1];
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _roles[role][account] = true;
        emit RoleGranted(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _roles[role][account] = false;
        emit RoleRevoked(role, account);
    }

    function deposit(uint256 stablecoinAmount)
        external
        nonReentrant
        accruesFee
        returns (uint256 receiptAmount)
    {
        if (stablecoinAmount < MIN_DEPOSIT) revert DepositBelowMinimum(stablecoinAmount, MIN_DEPOSIT);

        receiptAmount = _convertToShares(stablecoinAmount);
        if (receiptAmount < 1) revert ZeroAmount();

        _mint(msg.sender, receiptAmount);
        totalAssetsUnderManagement += stablecoinAmount;
        depositedStablecoin[msg.sender] += stablecoinAmount;

        _safeTransferFrom(stablecoin, msg.sender, address(this), stablecoinAmount);

        emit Deposit(msg.sender, stablecoinAmount, receiptAmount, block.timestamp);
    }

    function withdraw(uint256 receiptAmount)
        external
        nonReentrant
        accruesFee
        returns (uint256 stablecoinAmount)
    {
        if (receiptAmount < 1) revert ZeroAmount();
        if (_balances[msg.sender] < receiptAmount) revert InsufficientBalance(_balances[msg.sender], receiptAmount);

        stablecoinAmount = _convertToAssets(receiptAmount);

        uint256 available = _availableStablecoin();
        if (stablecoinAmount > available) revert InsufficientLiquidity(stablecoinAmount, available);
        if (stablecoinAmount < 1) revert NothingToClaim();

        _burn(msg.sender, receiptAmount);
        totalAssetsUnderManagement -= stablecoinAmount;

        if (depositedStablecoin[msg.sender] >= stablecoinAmount) {
            depositedStablecoin[msg.sender] -= stablecoinAmount;
        } else {
            depositedStablecoin[msg.sender] = 0;
        }

        _safeTransfer(stablecoin, msg.sender, stablecoinAmount);

        emit Withdrawal(msg.sender, receiptAmount, stablecoinAmount, block.timestamp);
    }

    function redeem(uint256 investmentId, uint256 receiptAmount)
        external
        nonReentrant
        accruesFee
        returns (uint256 assetAmount)
    {
        if (receiptAmount < 1) revert ZeroAmount();
        if (_balances[msg.sender] < receiptAmount) revert InsufficientBalance(_balances[msg.sender], receiptAmount);

        Investment storage inv = investments[investmentId];
        if (!inv.distributed) revert InvestmentNotDistributed(investmentId);
        if (inv.totalReceiptsAtDistribution < 1) revert NothingToClaim();

        uint256 snapshotBalance = balanceOfAt(msg.sender, inv.snapshotId);
        if (claimedReceipts[investmentId][msg.sender] + receiptAmount > snapshotBalance) {
            revert InsufficientSnapshotBalance();
        }

        assetAmount = (receiptAmount * inv.distributedAmount) / inv.totalReceiptsAtDistribution;
        if (assetAmount < 1) revert NothingToClaim();
        if (totalClaimedAssets[investmentId] + assetAmount > inv.distributedAmount) {
            revert ExceedsDistributedAmount();
        }

        claimedReceipts[investmentId][msg.sender] += receiptAmount;
        totalClaimedAssets[investmentId] += assetAmount;

        _burn(msg.sender, receiptAmount);
        if (totalAssetsUnderManagement >= assetAmount) {
            totalAssetsUnderManagement -= assetAmount;
        } else {
            totalAssetsUnderManagement = 0;
        }

        _safeTransfer(IERC20(inv.assetToken), msg.sender, assetAmount);

        emit Redemption(msg.sender, investmentId, receiptAmount, assetAmount, inv.assetToken);
    }

    function addInvestment(
        address assetToken,
        uint256 maturity,
        uint256 expectedReturn
    ) external onlyRole(OPERATOR_ROLE) accruesFee nonReentrant returns (uint256 investmentId) {
        if (assetToken == address(0)) revert ZeroAddress();
        if (maturity <= block.timestamp) revert InvalidMaturity();

        investmentId = nextInvestmentId++;
        investments[investmentId] = Investment({
            assetToken: assetToken,
            stablecoinInvested: 0,
            maturity: maturity,
            expectedReturn: expectedReturn,
            active: true,
            distributed: false,
            distributedAmount: 0,
            totalReceiptsAtDistribution: 0,
            snapshotId: 0
        });

        emit InvestmentAdded(investmentId, assetToken, maturity, expectedReturn);
    }

    function purchaseAsset(
        uint256 investmentId,
        address destination,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) accruesFee nonReentrant {
        if (destination == address(0)) revert ZeroAddress();
        if (amount < 1) revert ZeroAmount();

        Investment storage inv = investments[investmentId];
        if (!inv.active || inv.distributed) revert InvestmentNotActive(investmentId);

        uint256 available = _availableStablecoin();
        if (amount > available) revert InsufficientLiquidity(amount, available);

        inv.stablecoinInvested += amount;
        totalInvested += amount;
        totalAssetsUnderManagement -= amount;

        _safeTransfer(stablecoin, destination, amount);

        emit AssetPurchased(investmentId, destination, amount, block.timestamp);
    }

    function distributeReturns(uint256 investmentId, uint256 returnAmount)
        external
        onlyRole(OPERATOR_ROLE)
        accruesFee
        nonReentrant
    {
        if (returnAmount < 1) revert ZeroAmount();

        Investment storage inv = investments[investmentId];
        if (!inv.active) revert InvestmentNotActive(investmentId);
        if (inv.distributed) revert InvestmentAlreadyDistributed(investmentId);
        if (block.timestamp < inv.maturity) {
            revert InvestmentNotMatured(investmentId, inv.maturity, block.timestamp);
        }

        uint256 principal = inv.stablecoinInvested;

        inv.distributed = true;
        inv.active = false;
        inv.distributedAmount = returnAmount;
        inv.snapshotId = _snapshot();
        inv.totalReceiptsAtDistribution = _totalSupply;

        totalInvested -= principal;

        int256 profit = int256(returnAmount) - int256(principal);
        if (profit >= 0) {
            totalAssetsUnderManagement += uint256(profit);
        } else {
            uint256 loss = uint256(-profit);
            if (totalAssetsUnderManagement < loss) {
                totalAssetsUnderManagement = 0;
            } else {
                totalAssetsUnderManagement -= loss;
            }
        }

        _safeTransferFrom(IERC20(inv.assetToken), msg.sender, address(this), returnAmount);

        emit DistributionCompleted(investmentId, inv.assetToken, returnAmount, profit, block.timestamp);
    }

    function configureStrategy(string calldata strategyName, uint256 targetAllocationBps)
        external
        onlyRole(OPERATOR_ROLE)
        accruesFee
        nonReentrant
        returns (uint256 strategyId)
    {
        if (targetAllocationBps > BPS) revert AllocationTooHigh(targetAllocationBps, BPS);

        strategyId = nextStrategyId++;
        strategies[strategyId] = StrategyConfig({
            name: strategyName,
            targetAllocationBps: targetAllocationBps,
            active: true
        });

        emit StrategyConfigured(strategyId, strategyName, targetAllocationBps);
    }

    function claimManagementFee() external onlyRole(OPERATOR_ROLE) nonReentrant {
        _accrueManagementFee();

        uint256 fee = accumulatedManagementFee;
        if (fee < 1) revert NothingToClaim();

        uint256 available = _availableStablecoin();
        uint256 toTransfer = fee > available ? available : fee;
        if (toTransfer < 1) revert NothingToClaim();

        accumulatedManagementFee -= toTransfer;
        if (totalAssetsUnderManagement >= toTransfer) {
            totalAssetsUnderManagement -= toTransfer;
        } else {
            totalAssetsUnderManagement = 0;
        }

        _safeTransfer(stablecoin, treasury, toTransfer);

        emit ManagementFeeClaimed(treasury, toTransfer);
    }

    function accrueManagementFee() external {
        _accrueManagementFee();
    }

    function _accrueManagementFee() internal {
        uint256 timeDelta = block.timestamp - lastFeeTimestamp;
        if (timeDelta < 1) return;

        uint256 aum = totalAssetsUnderManagement;
        if (aum > 0) {
            uint256 fee = (aum * MANAGEMENT_FEE_BPS * timeDelta) / (BPS * SECONDS_PER_YEAR);
            if (fee > 0) {
                accumulatedManagementFee += fee;
                emit ManagementFeeAccrued(fee, block.timestamp);
            }
        }
        lastFeeTimestamp = uint40(block.timestamp);
    }

    function getAUM() external view returns (uint256) {
        return totalAssetsUnderManagement;
    }

    function getNetAUM() external view returns (uint256) {
        return _netAUM();
    }

    function availableStablecoin() external view returns (uint256) {
        return _availableStablecoin();
    }

    function getInvestment(uint256 investmentId) external view returns (Investment memory) {
        return investments[investmentId];
    }

    function getStrategy(uint256 strategyId) external view returns (StrategyConfig memory) {
        return strategies[strategyId];
    }

    function sharePrice() external view returns (uint256) {
        return _sharePrice();
    }

    function convertToShares(uint256 stablecoinAmount) external view returns (uint256) {
        return _convertToShares(stablecoinAmount);
    }

    function convertToAssets(uint256 receiptAmount) external view returns (uint256) {
        return _convertToAssets(receiptAmount);
    }

    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function _netAUM() internal view returns (uint256) {
        return totalAssetsUnderManagement > accumulatedManagementFee
            ? totalAssetsUnderManagement - accumulatedManagementFee
            : 0;
    }

    function _availableStablecoin() internal view returns (uint256) {
        uint256 balance = stablecoin.balanceOf(address(this));
        return balance > accumulatedManagementFee ? balance - accumulatedManagementFee : 0;
    }

    function _sharePrice() internal view returns (uint256) {
        uint256 supply = _totalSupply;
        if (supply < 1) {
            return 10 ** uint256(_decimals);
        }
        return (_netAUM() * (10 ** uint256(_decimals))) / supply;
    }

    function _convertToShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = _totalSupply;
        return (assets * (supply + VIRTUAL_SHARES)) / (_netAUM() + VIRTUAL_ASSETS);
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        uint256 supply = _totalSupply;
        return (shares * (_netAUM() + VIRTUAL_ASSETS)) / (supply + VIRTUAL_SHARES);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length >= 32 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length >= 32 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _tryGetDecimals(address token) private view returns (uint8) {
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(IERC20Metadata.decimals.selector)
        );
        if (ok && data.length >= 32) {
            uint256 dec = abi.decode(data, (uint256));
            if (dec <= type(uint8).max) {
                return uint8(dec);
            }
        }
        return 18;
    }
}
