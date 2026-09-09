// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Unauthorized();

    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert Unauthorized();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Unauthorized();
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract DecentralizedInvestmentFund is Ownable, ReentrancyGuard {
    error ZeroAddress();
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error InsufficientShares(address investor, uint256 requested, uint256 available);
    error InsufficientLiquidity(uint256 required, uint256 available);
    error NotOperator();
    error StrategyNotFound(uint256 strategyId);
    error StrategyNotPending(uint256 strategyId);
    error StrategyNotApproved(uint256 strategyId);
    error StrategyNotExecuted(uint256 strategyId);
    error InvalidFeeBps(uint256 feeBps);
    error InvalidMinDeposit(uint256 minDeposit);
    error NothingToWithdraw();
    error InvalidAmount();
    error AmountExceedsInvested(uint256 requested, uint256 invested);
    error TransferFailed();

    event Deposited(address indexed investor, uint256 amount, uint256 sharesMinted, uint256 fee);
    event Withdrawn(address indexed investor, uint256 sharesBurned, uint256 amount);
    event StrategyProposed(
        uint256 indexed strategyId,
        address indexed proposer,
        address strategyContract,
        uint256 amount,
        string description
    );
    event StrategyApproved(uint256 indexed strategyId, address indexed operator);
    event StrategyRejected(uint256 indexed strategyId, address indexed operator);
    event StrategyExecuted(uint256 indexed strategyId, address indexed strategyContract, uint256 amount);
    event StrategyDivested(uint256 indexed strategyId, address indexed strategyContract, uint256 amount);
    event ManagementFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MinDepositUpdated(uint256 oldMinDeposit, uint256 newMinDeposit);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesCollected(address indexed to, uint256 amount);

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5%
    uint256 public constant DEFAULT_MIN_DEPOSIT = 100;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10%

    enum StrategyStatus {
        Pending,
        Approved,
        Rejected,
        Executed
    }

    struct Strategy {
        address proposer;
        address strategyContract;
        uint256 amount;
        string description;
        StrategyStatus status;
        uint64 proposedAt;
        uint64 executedAt;
    }

    address public operator;

    uint256 public managementFeeBps;
    uint256 public minDeposit;

    uint256 public totalShares;
    uint256 public totalInvested;
    uint256 public accumulatedFees;
    uint256 public totalAssetsUnderManagement;

    mapping(address => uint256) public shares;
    mapping(address => uint256) public totalDepositedPerInvestor;
    mapping(address => uint256) public totalWithdrawnPerInvestor;

    mapping(uint256 => Strategy) public strategies;
    uint256 public strategyCount;

    mapping(address => uint256) public strategyInvested;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyExistingStrategy(uint256 strategyId) {
        if (strategies[strategyId].proposer == address(0)) revert StrategyNotFound(strategyId);
        _;
    }

    constructor(address operator_) Ownable(msg.sender) {
        if (operator_ == address(0)) revert ZeroAddress();

        operator = operator_;
        managementFeeBps = DEFAULT_FEE_BPS;
        minDeposit = DEFAULT_MIN_DEPOSIT;

        emit OperatorUpdated(address(0), operator_);
        emit ManagementFeeUpdated(0, managementFeeBps);
        emit MinDepositUpdated(0, minDeposit);
    }

    receive() external payable {}

    function deposit(uint256 amount) external payable nonReentrant {
        if (msg.value != amount) revert InvalidAmount();
        if (amount < minDeposit) revert DepositBelowMinimum(amount, minDeposit);

        uint256 fee = (amount * managementFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        accumulatedFees += fee;

        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = netAmount;
        } else {
            sharesToMint = (netAmount * totalShares) / totalAssetsUnderManagement;
        }

        totalShares += sharesToMint;
        shares[msg.sender] += sharesToMint;
        totalDepositedPerInvestor[msg.sender] += amount;
        totalAssetsUnderManagement += netAmount;

        emit Deposited(msg.sender, amount, sharesToMint, fee);
    }

    function withdraw(uint256 shareAmount) external nonReentrant {
        if (shareAmount == 0) revert InvalidAmount();

        uint256 investorShares = shares[msg.sender];
        if (investorShares < shareAmount) {
            revert InsufficientShares(msg.sender, shareAmount, investorShares);
        }

        uint256 assetsToReturn = (shareAmount * totalAssetsUnderManagement) / totalShares;
        uint256 availableLiquidity = address(this).balance - accumulatedFees;
        if (availableLiquidity < assetsToReturn) {
            revert InsufficientLiquidity(assetsToReturn, availableLiquidity);
        }

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalAssetsUnderManagement -= assetsToReturn;
        totalWithdrawnPerInvestor[msg.sender] += assetsToReturn;

        (bool success, ) = msg.sender.call{value: assetsToReturn}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, shareAmount, assetsToReturn);
    }

    function proposeStrategy(
        address strategyContract,
        uint256 amount,
        string calldata description
    ) external returns (uint256 strategyId) {
        if (strategyContract == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        strategyId = strategyCount++;
        strategies[strategyId] = Strategy({
            proposer: msg.sender,
            strategyContract: strategyContract,
            amount: amount,
            description: description,
            status: StrategyStatus.Pending,
            proposedAt: uint64(block.timestamp),
            executedAt: 0
        });

        emit StrategyProposed(strategyId, msg.sender, strategyContract, amount, description);
    }

    function approveStrategy(uint256 strategyId)
        external
        onlyOperator
        onlyExistingStrategy(strategyId)
    {
        Strategy storage strat = strategies[strategyId];
        if (strat.status != StrategyStatus.Pending) revert StrategyNotPending(strategyId);

        strat.status = StrategyStatus.Approved;
        emit StrategyApproved(strategyId, msg.sender);
    }

    function rejectStrategy(uint256 strategyId)
        external
        onlyOperator
        onlyExistingStrategy(strategyId)
    {
        Strategy storage strat = strategies[strategyId];
        if (strat.status != StrategyStatus.Pending) revert StrategyNotPending(strategyId);

        strat.status = StrategyStatus.Rejected;
        emit StrategyRejected(strategyId, msg.sender);
    }

    function executeStrategy(uint256 strategyId)
        external
        onlyOperator
        nonReentrant
        onlyExistingStrategy(strategyId)
    {
        Strategy storage strat = strategies[strategyId];
        if (strat.status != StrategyStatus.Approved) revert StrategyNotApproved(strategyId);

        uint256 amount = strat.amount;
        address strategyContract = strat.strategyContract;

        uint256 availableLiquidity = address(this).balance - accumulatedFees;
        if (availableLiquidity < amount) revert InsufficientLiquidity(amount, availableLiquidity);

        strat.status = StrategyStatus.Executed;
        strat.executedAt = uint64(block.timestamp);
        strategyInvested[strategyContract] += amount;
        totalInvested += amount;

        (bool success, ) = strategyContract.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit StrategyExecuted(strategyId, strategyContract, amount);
    }

    function divestStrategy(uint256 strategyId, uint256 amount)
        external
        onlyOperator
        nonReentrant
        onlyExistingStrategy(strategyId)
    {
        Strategy storage strat = strategies[strategyId];
        if (strat.status != StrategyStatus.Executed) revert StrategyNotExecuted(strategyId);

        address strategyContract = strat.strategyContract;
        uint256 invested = strategyInvested[strategyContract];
        if (amount > invested) revert AmountExceedsInvested(amount, invested);

        strategyInvested[strategyContract] = invested - amount;
        totalInvested -= amount;

        uint256 balanceBefore = address(this).balance;
        (bool success, ) = strategyContract.call(
            abi.encodeWithSignature("divest(uint256)", amount)
        );
        if (!success) revert TransferFailed();
        if (address(this).balance < balanceBefore + amount) revert TransferFailed();

        emit StrategyDivested(strategyId, strategyContract, amount);
    }

    function setManagementFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFeeBps(newFeeBps);
        uint256 old = managementFeeBps;
        managementFeeBps = newFeeBps;
        emit ManagementFeeUpdated(old, newFeeBps);
    }

    function setMinDeposit(uint256 newMinDeposit) external onlyOperator {
        if (newMinDeposit == 0) revert InvalidMinDeposit(newMinDeposit);
        uint256 old = minDeposit;
        minDeposit = newMinDeposit;
        emit MinDepositUpdated(old, newMinDeposit);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function collectFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToWithdraw();

        accumulatedFees = 0;
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesCollected(to, amount);
    }

    function totalAssets() public view returns (uint256) {
        return totalAssetsUnderManagement;
    }

    function balanceOf(address investor) public view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares[investor] * totalAssetsUnderManagement) / totalShares;
    }

    function investorShareBps(address investor) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares[investor] * BPS_DENOMINATOR) / totalShares;
    }

    function liquidBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getStrategy(uint256 strategyId)
        external
        view
        onlyExistingStrategy(strategyId)
        returns (
            address proposer,
            address strategyContract,
            uint256 amount,
            string memory description,
            StrategyStatus status,
            uint64 proposedAt,
            uint64 executedAt
        )
    {
        Strategy storage strat = strategies[strategyId];
        return (
            strat.proposer,
            strat.strategyContract,
            strat.amount,
            strat.description,
            strat.status,
            strat.proposedAt,
            strat.executedAt
        );
    }
}
