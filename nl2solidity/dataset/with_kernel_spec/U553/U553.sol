// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract PredictionMarket {
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error EmptyOutcomes();
    error DuplicateOutcome(bytes32 outcome);
    error InvalidOutcome();
    error InvalidWinningOutcome();
    error MarketNotFound();
    error MarketNotSettled();
    error MarketAlreadySettled();
    error BetTooSmall(uint256 amount, uint256 minimum);
    error InsufficientBalance(uint256 available, uint256 required);
    error NothingToClaim();
    error AlreadyClaimed();
    error NoWinningBets();
    error FeeTooHigh(uint256 feeBps);
    error TransferFailed();
    error ReentrantCall();

    event MarketCreated(uint256 indexed marketId, address indexed creator, bytes32[] outcomes, uint256 createdAt);
    event BetPlaced(uint256 indexed marketId, address indexed bettor, bytes32 outcome, uint256 amount, uint256 fee);
    event MarketSettled(uint256 indexed marketId, bytes32 winningOutcome, uint256 totalPool, uint256 winningTotal);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesCollected(address indexed operator, uint256 amount);
    event MinBetUpdated(uint256 oldMinBet, uint256 newMinBet);

    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 100;

    IERC20 public immutable collateralToken;

    address public operator;
    uint256 public feeBps;
    uint256 public minBet;
    uint256 public marketCount;
    uint256 private _status;

    struct Market {
        address creator;
        bool settled;
        bytes32 winningOutcome;
        uint256 totalPool;
        uint256 feePool;
        uint256 winningTotal;
        uint256 createdAt;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => bytes32[]) internal _outcomes;
    mapping(uint256 => mapping(bytes32 => bool)) public isValidOutcome;
    mapping(uint256 => mapping(bytes32 => uint256)) public outcomeTotals;
    mapping(uint256 => mapping(address => mapping(bytes32 => uint256))) public userBets;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(address => uint256) public balances;

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address _collateralToken, address _operator) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        feeBps = DEFAULT_FEE_BPS;
        minBet = 100 * 10 ** 18;
        _status = 1;
        emit FeeUpdated(0, DEFAULT_FEE_BPS);
        emit OperatorUpdated(address(0), _operator);
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(collateralToken).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(collateralToken).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 available = balances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);
        balances[msg.sender] = available - amount;
        _safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function createMarket(bytes32[] calldata outcomes) external returns (uint256) {
        if (outcomes.length < 2) revert EmptyOutcomes();
        uint256 id = ++marketCount;
        Market storage m = markets[id];
        m.creator = msg.sender;
        m.createdAt = block.timestamp;
        for (uint256 i = 0; i < outcomes.length; i++) {
            bytes32 o = outcomes[i];
            if (o == bytes32(0)) revert InvalidOutcome();
            if (isValidOutcome[id][o]) revert DuplicateOutcome(o);
            isValidOutcome[id][o] = true;
            _outcomes[id].push(o);
        }
        emit MarketCreated(id, msg.sender, outcomes, block.timestamp);
        return id;
    }

    function placeBet(uint256 marketId, bytes32 outcome, uint256 amount) external nonReentrant {
        if (amount < minBet) revert BetTooSmall(amount, minBet);
        Market storage m = markets[marketId];
        if (m.createdAt == 0) revert MarketNotFound();
        if (m.settled) revert MarketAlreadySettled();
        if (!isValidOutcome[marketId][outcome]) revert InvalidOutcome();

        uint256 available = balances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        uint256 fee = (amount * feeBps) / BPS_DENOM;
        uint256 betNet = amount - fee;

        balances[msg.sender] = available - amount;
        outcomeTotals[marketId][outcome] += betNet;
        userBets[marketId][msg.sender][outcome] += betNet;
        m.totalPool += betNet;
        m.feePool += fee;

        emit BetPlaced(marketId, msg.sender, outcome, amount, fee);
    }

    function settleMarket(uint256 marketId, bytes32 winningOutcome) external onlyOperator nonReentrant {
        Market storage m = markets[marketId];
        if (m.createdAt == 0) revert MarketNotFound();
        if (m.settled) revert MarketAlreadySettled();
        if (!isValidOutcome[marketId][winningOutcome]) revert InvalidWinningOutcome();

        uint256 winningTotal = outcomeTotals[marketId][winningOutcome];
        if (winningTotal == 0) revert NoWinningBets();

        m.settled = true;
        m.winningOutcome = winningOutcome;
        m.winningTotal = winningTotal;

        uint256 fees = m.feePool;
        if (fees > 0) {
            m.feePool = 0;
            balances[operator] += fees;
            emit FeesCollected(operator, fees);
        }

        emit MarketSettled(marketId, winningOutcome, m.totalPool, winningTotal);
    }

    function claimWinnings(uint256 marketId) external nonReentrant {
        Market storage m = markets[marketId];
        if (m.createdAt == 0) revert MarketNotFound();
        if (!m.settled) revert MarketNotSettled();
        if (hasClaimed[marketId][msg.sender]) revert AlreadyClaimed();

        uint256 myBet = userBets[marketId][msg.sender][m.winningOutcome];
        if (myBet == 0) revert NothingToClaim();

        hasClaimed[marketId][msg.sender] = true;
        uint256 payout = (myBet * m.totalPool) / m.winningTotal;
        balances[msg.sender] += payout;

        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps);
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function setMinBet(uint256 newMinBet) external onlyOperator {
        if (newMinBet == 0) revert ZeroAmount();
        uint256 old = minBet;
        minBet = newMinBet;
        emit MinBetUpdated(old, newMinBet);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function getOutcomes(uint256 marketId) external view returns (bytes32[] memory) {
        return _outcomes[marketId];
    }
}
