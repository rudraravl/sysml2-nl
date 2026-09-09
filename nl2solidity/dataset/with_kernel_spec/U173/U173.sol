// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IStrategy {
    function executeStrategy(uint256 vaultId) external returns (int256 pnlDelta);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract StrategyVaultManager {
    using SafeERC20 for IERC20;

    event VaultCreated(
        uint256 indexed vaultId,
        address indexed creator,
        address indexed baseToken,
        address profitToken,
        address strategy,
        uint256 initialDeposit
    );
    event Deposited(
        uint256 indexed vaultId,
        address indexed depositor,
        uint256 amount,
        uint256 sharesMinted
    );
    event Withdrawn(
        uint256 indexed vaultId,
        address indexed withdrawer,
        uint256 sharesBurned,
        uint256 amountReturned,
        uint256 fee
    );
    event StrategyExecuted(
        uint256 indexed vaultId,
        address indexed strategy,
        int256 pnlDelta,
        uint256 newAllocatedCapital
    );
    event StrategyApproved(
        address indexed strategy,
        uint256 maxAllocation,
        uint256 minAllocation,
        uint256 performanceFeeBps
    );
    event StrategyParamsUpdated(
        address indexed strategy,
        uint256 maxAllocation,
        uint256 minAllocation,
        uint256 performanceFeeBps
    );
    event StrategyRevoked(address indexed strategy);
    event SystemPaused(address indexed operator);
    event SystemUnpaused(address indexed operator);
    event TreasuryUpdated(address indexed operator, address oldTreasury, address newTreasury);
    event OperatorUpdated(address indexed oldOperator, address newOperator);

    error NotOperator();
    error NotVaultCreator();
    error EnforcedPause();
    error StrategyNotApproved();
    error InsufficientDeposit();
    error InsufficientShares();
    error ZeroShares();
    error ZeroAmount();
    error VaultNotFound();
    error InvalidParameters();
    error AllocationExceeded();
    error ReentrantCall();

    uint256 public constant MIN_INITIAL_DEPOSIT = 100e18;
    uint256 public constant WITHDRAW_FEE_BPS = 50;
    uint256 public constant BPS_DIVISOR = 10000;

    address public operator;
    address public treasury;
    bool public paused;
    uint256 public vaultCount;

    struct StrategyParams {
        bool approved;
        uint256 maxAllocation;
        uint256 minAllocation;
        uint256 performanceFeeBps;
        uint256 totalAllocated;
    }

    struct VaultData {
        address baseToken;
        address profitToken;
        address strategy;
        address creator;
        uint256 allocatedCapital;
        int256 profitAndLoss;
        uint256 totalShares;
        uint256 lastStrategyExecution;
    }

    mapping(address => StrategyParams) public strategyRegistry;
    mapping(uint256 => VaultData) public vaults;
    mapping(uint256 => mapping(address => uint256)) public userShares;

    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier vaultExists(uint256 vaultId) {
        if (vaults[vaultId].baseToken == address(0)) revert VaultNotFound();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _treasury) {
        if (_treasury == address(0)) revert InvalidParameters();
        operator = msg.sender;
        treasury = _treasury;
    }

    function approveStrategy(
        address strategy,
        uint256 maxAllocation,
        uint256 minAllocation,
        uint256 performanceFeeBps
    ) external onlyOperator {
        if (strategy == address(0)) revert InvalidParameters();
        if (minAllocation > maxAllocation) revert InvalidParameters();
        if (performanceFeeBps > BPS_DIVISOR) revert InvalidParameters();

        strategyRegistry[strategy] = StrategyParams({
            approved: true,
            maxAllocation: maxAllocation,
            minAllocation: minAllocation,
            performanceFeeBps: performanceFeeBps,
            totalAllocated: 0
        });

        emit StrategyApproved(strategy, maxAllocation, minAllocation, performanceFeeBps);
    }

    function updateStrategyParams(
        address strategy,
        uint256 maxAllocation,
        uint256 minAllocation,
        uint256 performanceFeeBps
    ) external onlyOperator {
        if (!strategyRegistry[strategy].approved) revert StrategyNotApproved();
        if (minAllocation > maxAllocation) revert InvalidParameters();
        if (performanceFeeBps > BPS_DIVISOR) revert InvalidParameters();

        StrategyParams storage sp = strategyRegistry[strategy];
        sp.maxAllocation = maxAllocation;
        sp.minAllocation = minAllocation;
        sp.performanceFeeBps = performanceFeeBps;

        emit StrategyParamsUpdated(strategy, maxAllocation, minAllocation, performanceFeeBps);
    }

    function revokeStrategy(address strategy) external onlyOperator {
        if (!strategyRegistry[strategy].approved) revert StrategyNotApproved();
        strategyRegistry[strategy].approved = false;
        emit StrategyRevoked(strategy);
    }

    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        if (_paused) {
            emit SystemPaused(msg.sender);
        } else {
            emit SystemUnpaused(msg.sender);
        }
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert InvalidParameters();
        emit TreasuryUpdated(msg.sender, treasury, _treasury);
        treasury = _treasury;
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert InvalidParameters();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function createVault(
        address baseToken,
        address profitToken,
        address strategy,
        uint256 initialDeposit
    ) external whenNotPaused nonReentrant returns (uint256 vaultId) {
        if (baseToken == address(0)) revert InvalidParameters();
        if (strategy == address(0)) revert InvalidParameters();
        if (!strategyRegistry[strategy].approved) revert StrategyNotApproved();
        if (initialDeposit < MIN_INITIAL_DEPOSIT) revert InsufficientDeposit();

        StrategyParams storage sp = strategyRegistry[strategy];
        if (sp.totalAllocated + initialDeposit > sp.maxAllocation) revert AllocationExceeded();

        vaultId = vaultCount++;
        VaultData storage v = vaults[vaultId];
        v.baseToken = baseToken;
        v.profitToken = profitToken;
        v.strategy = strategy;
        v.creator = msg.sender;
        v.allocatedCapital = initialDeposit;
        v.profitAndLoss = 0;
        v.totalShares = initialDeposit;
        v.lastStrategyExecution = block.timestamp;

        userShares[vaultId][msg.sender] = initialDeposit;
        sp.totalAllocated += initialDeposit;

        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), initialDeposit);

        emit VaultCreated(vaultId, msg.sender, baseToken, profitToken, strategy, initialDeposit);
        emit Deposited(vaultId, msg.sender, initialDeposit, initialDeposit);
    }

    function deposit(uint256 vaultId, uint256 amount)
        external
        whenNotPaused
        nonReentrant
        vaultExists(vaultId)
    {
        if (amount == 0) revert ZeroAmount();

        VaultData storage v = vaults[vaultId];
        StrategyParams storage sp = strategyRegistry[v.strategy];
        if (!sp.approved) revert StrategyNotApproved();
        if (sp.totalAllocated + amount > sp.maxAllocation) revert AllocationExceeded();

        uint256 shares;
        if (v.totalShares == 0 || v.allocatedCapital == 0) {
            shares = amount;
        } else {
            shares = (amount * v.totalShares) / v.allocatedCapital;
        }

        v.allocatedCapital += amount;
        v.totalShares += shares;
        userShares[vaultId][msg.sender] += shares;
        sp.totalAllocated += amount;

        IERC20(v.baseToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(vaultId, msg.sender, amount, shares);
    }

    function withdraw(uint256 vaultId, uint256 shares)
        external
        whenNotPaused
        nonReentrant
        vaultExists(vaultId)
    {
        if (shares == 0) revert ZeroShares();

        VaultData storage v = vaults[vaultId];
        if (v.totalShares == 0) revert InvalidParameters();
        if (userShares[vaultId][msg.sender] < shares) revert InsufficientShares();

        // Compute fee first using full-precision multiplication to avoid divide-before-multiply
        // fee = shares * allocatedCapital * WITHDRAW_FEE_BPS / (totalShares * BPS_DIVISOR)
        uint256 fee = (shares * v.allocatedCapital * WITHDRAW_FEE_BPS) / (v.totalShares * BPS_DIVISOR);
        uint256 totalAmount = (shares * v.allocatedCapital) / v.totalShares;
        // fee is guaranteed <= totalAmount because WITHDRAW_FEE_BPS < BPS_DIVISOR
        uint256 amountToUser = totalAmount - fee;

        userShares[vaultId][msg.sender] -= shares;
        v.totalShares -= shares;
        v.allocatedCapital -= totalAmount;
        strategyRegistry[v.strategy].totalAllocated -= totalAmount;

        if (fee > 0) {
            IERC20(v.baseToken).safeTransfer(treasury, fee);
        }
        if (amountToUser > 0) {
            IERC20(v.baseToken).safeTransfer(msg.sender, amountToUser);
        }

        emit Withdrawn(vaultId, msg.sender, shares, amountToUser, fee);
    }

    function executeStrategy(uint256 vaultId)
        external
        whenNotPaused
        nonReentrant
        vaultExists(vaultId)
    {
        VaultData storage v = vaults[vaultId];
        StrategyParams storage sp = strategyRegistry[v.strategy];
        if (!sp.approved) revert StrategyNotApproved();
        if (v.creator != msg.sender && msg.sender != operator) revert NotVaultCreator();

        // Effects: record timestamp before external call (checks-effects-interactions)
        v.lastStrategyExecution = block.timestamp;

        // Interaction: external call to strategy
        int256 pnlDelta = IStrategy(v.strategy).executeStrategy(vaultId);

        // Effects: apply PnL delta after external call (guarded by nonReentrant)
        v.profitAndLoss += pnlDelta;
        if (pnlDelta >= 0) {
            uint256 gain = uint256(pnlDelta);
            v.allocatedCapital += gain;
            sp.totalAllocated += gain;
        } else {
            uint256 loss = uint256(-pnlDelta);
            if (loss >= v.allocatedCapital) {
                v.allocatedCapital = 0;
            } else {
                v.allocatedCapital -= loss;
            }
            if (loss >= sp.totalAllocated) {
                sp.totalAllocated = 0;
            } else {
                sp.totalAllocated -= loss;
            }
        }

        emit StrategyExecuted(vaultId, v.strategy, pnlDelta, v.allocatedCapital);
    }

    function getVault(uint256 vaultId)
        external
        view
        vaultExists(vaultId)
        returns (
            address baseToken,
            address profitToken,
            address strategy,
            address creator,
            uint256 allocatedCapital,
            int256 profitAndLoss,
            uint256 totalShares,
            uint256 lastStrategyExecution
        )
    {
        VaultData storage v = vaults[vaultId];
        return (
            v.baseToken,
            v.profitToken,
            v.strategy,
            v.creator,
            v.allocatedCapital,
            v.profitAndLoss,
            v.totalShares,
            v.lastStrategyExecution
        );
    }

    function getStrategyParams(address strategy)
        external
        view
        returns (
            bool approved,
            uint256 maxAllocation,
            uint256 minAllocation,
            uint256 performanceFeeBps,
            uint256 totalAllocated
        )
    {
        StrategyParams storage s = strategyRegistry[strategy];
        return (
            s.approved,
            s.maxAllocation,
            s.minAllocation,
            s.performanceFeeBps,
            s.totalAllocated
        );
    }

    function getUserShares(uint256 vaultId, address user) external view returns (uint256) {
        return userShares[vaultId][user];
    }

    function getSharePrice(uint256 vaultId) external view vaultExists(vaultId) returns (uint256) {
        VaultData storage v = vaults[vaultId];
        if (v.totalShares == 0) return 0;
        return (v.allocatedCapital * 1e18) / v.totalShares;
    }

    function isPaused() external view returns (bool) {
        return paused;
    }

    function getVaultCount() external view returns (uint256) {
        return vaultCount;
    }
}
