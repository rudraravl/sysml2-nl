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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract PredictionMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error EmptyOutcomes();
    error InvalidOutcome();
    error InvalidResolutionTime();
    error InsufficientInitialDeposit();
    error InsufficientDeposit();
    error InsufficientStake();
    error MarketDoesNotExist();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error ResolutionTimeNotPassed();
    error NotOperator();
    error AlreadyClaimed();
    error NothingToClaim();
    error NoFeesAccrued();

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        bytes32[] outcomeIds,
        uint256 resolutionTime
    );
    event Deposited(
        uint256 indexed marketId,
        address indexed depositor,
        bytes32 outcomeId,
        uint256 amount
    );
    event Withdrawn(
        uint256 indexed marketId,
        address indexed withdrawer,
        bytes32 outcomeId,
        uint256 amount
    );
    event MarketResolved(
        uint256 indexed marketId,
        bytes32 winningOutcomeId,
        uint256 totalPool,
        uint256 winningPool
    );
    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed claimer,
        uint256 grossPayout,
        uint256 fee,
        uint256 netPayout
    );
    event FeesSwept(address indexed receiver, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    uint256 public constant MIN_INITIAL_DEPOSIT = 100 ether;
    uint256 public constant FEE_BPS = 200; // 2% = 200 basis points

    IERC20 public immutable baseCurrency;
    address public operator;
    uint256 public nextMarketId;
    uint256 public accruedFees;

    struct Market {
        string question;
        bytes32[] outcomes;
        uint256 resolutionTime;
        uint256 totalPool;
        uint256 winningPool;
        bytes32 winningOutcome;
        bool resolved;
        mapping(bytes32 => bool) isOutcome;
        mapping(bytes32 => uint256) outcomeLiquidity;
        mapping(address => mapping(bytes32 => uint256)) userStake;
        mapping(address => bool) claimed;
    }

    mapping(uint256 => Market) private markets;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address baseCurrency_, address operator_) {
        if (baseCurrency_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        baseCurrency = IERC20(baseCurrency_);
        operator = operator_;
        nextMarketId = 1;
    }

    function createMarket(
        string calldata question,
        bytes32[] calldata outcomes,
        uint256 resolutionTime,
        bytes32 initialOutcome,
        uint256 initialDeposit
    ) external nonReentrant returns (uint256 marketId) {
        if (outcomes.length < 2) revert EmptyOutcomes();
        if (initialDeposit < MIN_INITIAL_DEPOSIT) revert InsufficientInitialDeposit();
        if (resolutionTime <= block.timestamp) revert InvalidResolutionTime();

        marketId = nextMarketId++;
        Market storage m = markets[marketId];
        m.question = question;
        m.outcomes = outcomes;
        m.resolutionTime = resolutionTime;
        for (uint256 i; i < outcomes.length; ++i) {
            m.isOutcome[outcomes[i]] = true;
        }
        if (!m.isOutcome[initialOutcome]) revert InvalidOutcome();

        m.userStake[msg.sender][initialOutcome] += initialDeposit;
        m.outcomeLiquidity[initialOutcome] += initialDeposit;
        m.totalPool += initialDeposit;

        baseCurrency.safeTransferFrom(initialDeposit);

        emit MarketCreated(marketId, msg.sender, question, outcomes, resolutionTime);
        emit Deposited(marketId, msg.sender, initialOutcome, initialDeposit);
    }

    function deposit(uint256 marketId, bytes32 outcome, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        if (m.outcomes.length == 0) revert MarketDoesNotExist();
        if (m.resolved) revert MarketAlreadyResolved();
        if (!m.isOutcome[outcome]) revert InvalidOutcome();
        if (amount == 0) revert InsufficientDeposit();

        m.userStake[msg.sender][outcome] += amount;
        m.outcomeLiquidity[outcome] += amount;
        m.totalPool += amount;

        baseCurrency.safeTransferFrom(amount);

        emit Deposited(marketId, msg.sender, outcome, amount);
    }

    function withdraw(uint256 marketId, bytes32 outcome) external nonReentrant {
        Market storage m = markets[marketId];
        if (m.outcomes.length == 0) revert MarketDoesNotExist();
        if (m.resolved) revert MarketAlreadyResolved();
        if (!m.isOutcome[outcome]) revert InvalidOutcome();

        uint256 stake = m.userStake[msg.sender][outcome];
        if (stake == 0) revert InsufficientStake();

        m.userStake[msg.sender][outcome] = 0;
        m.outcomeLiquidity[outcome] -= stake;
        m.totalPool -= stake;

        baseCurrency.safeTransfer(msg.sender, stake);

        emit Withdrawn(marketId, msg.sender, outcome, stake);
    }

    function resolve(uint256 marketId, bytes32 winningOutcome) external onlyOperator {
        Market storage m = markets[marketId];
        if (m.outcomes.length == 0) revert MarketDoesNotExist();
        if (m.resolved) revert MarketAlreadyResolved();
        if (block.timestamp < m.resolutionTime) revert ResolutionTimeNotPassed();
        if (!m.isOutcome[winningOutcome]) revert InvalidOutcome();

        m.winningOutcome = winningOutcome;
        m.winningPool = m.outcomeLiquidity[winningOutcome];
        m.resolved = true;

        emit MarketResolved(marketId, winningOutcome, m.totalPool, m.winningPool);
    }

    function claim(uint256 marketId) external nonReentrant {
        Market storage m = markets[marketId];
        if (m.outcomes.length == 0) revert MarketDoesNotExist();
        if (!m.resolved) revert MarketNotResolved();
        if (m.claimed[msg.sender]) revert AlreadyClaimed();

        uint256 stake = m.userStake[msg.sender][m.winningOutcome];
        if (stake == 0) revert NothingToClaim();

        m.claimed[msg.sender] = true;

        uint256 gross;
        uint256 fee;
        if (m.winningPool == 0) {
            gross = stake;
            fee = (stake * FEE_BPS) / 10000;
        } else {
            // Perform all multiplications before divisions to avoid
            // divide-before-multiply precision loss
            uint256 numerator = stake * m.totalPool;
            gross = numerator / m.winningPool;
            fee = (numerator * FEE_BPS) / (m.winningPool * 10000);
        }
        uint256 net = gross - fee;
        accruedFees += fee;

        baseCurrency.safeTransfer(msg.sender, net);

        emit WinningsClaimed(marketId, msg.sender, gross, fee, net);
    }

    function sweepFees(address recipient) external onlyOperator nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees;
        if (amount == 0) revert NoFeesAccrued();
        accruedFees = 0;
        baseCurrency.safeTransfer(recipient, amount);
        emit FeesSwept(recipient, amount);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function getMarket(uint256 marketId)
        external
        view
        returns (
            string memory question,
            bytes32[] memory outcomes,
            uint256 resolutionTime,
            uint256 totalPool,
            uint256 winningPool,
            bytes32 winningOutcome,
            bool resolved
        )
    {
        Market storage m = markets[marketId];
        return (
            m.question,
            m.outcomes,
            m.resolutionTime,
            m.totalPool,
            m.winningPool,
            m.winningOutcome,
            m.resolved
        );
    }

    function getOutcomeLiquidity(uint256 marketId, bytes32 outcome) external view returns (uint256) {
        return markets[marketId].outcomeLiquidity[outcome];
    }

    function getUserStake(uint256 marketId, address user, bytes32 outcome) external view returns (uint256) {
        return markets[marketId].userStake[user][outcome];
    }

    function hasClaimed(uint256 marketId, address user) external view returns (bool) {
        return markets[marketId].claimed[user];
    }

    function isOutcome(uint256 marketId, bytes32 outcome) external view returns (bool) {
        return markets[marketId].isOutcome[outcome];
    }
}
