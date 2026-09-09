// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
    error FailedInnerCall();

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.call(data);
        return verifyCallResult(success, returndata);
    }

    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(returndata, 0x20), returndata_size)
                }
            } else {
                revert FailedInnerCall();
            }
        }
    }
}

library SafeERC20 {
    using Address for address;

    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)) && data.length >= 32)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)) && data.length >= 32)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        _approve(token, spender, currentAllowance + value);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < requestedDecrease) {
            revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        _approve(token, spender, currentAllowance - requestedDecrease);
    }

    function _approve(IERC20 token, address spender, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)) && data.length >= 32)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract TradingStrategyManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error SameTokenPair();
    error InsufficientBalance();
    error MaxStrategiesReached();
    error StrategyNotFound();
    error StrategyNotActive();
    error StrategyAlreadyPaused();
    error StrategyAlreadyActive();
    error TradingPaused();
    error FeeTooHigh();
    error InvalidTradeParameters();
    error SlippageExceeded();

    // ============ Events ============
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event StrategyCreated(
        address indexed user,
        uint256 indexed strategyId,
        address tokenIn,
        address tokenOut,
        uint256 tradeAmount,
        uint256 minReturn,
        uint256 maxSlippageBps
    );
    event StrategyModified(
        address indexed user,
        uint256 indexed strategyId,
        uint256 tradeAmount,
        uint256 minReturn,
        uint256 maxSlippageBps
    );
    event StrategyPaused(address indexed user, uint256 indexed strategyId);
    event StrategyResumed(address indexed user, uint256 indexed strategyId);
    event StrategyCancelled(address indexed user, uint256 indexed strategyId);
    event TradeExecuted(
        address indexed user,
        uint256 indexed strategyId,
        address tokenIn,
        address tokenOut,
        uint256 executedAmount,
        uint256 receivedAmount,
        uint256 feeAmount
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address oldOperator, address newOperator);
    event GlobalTradingPaused();
    event GlobalTradingResumed();

    // ============ Constants ============
    uint256 public constant MAX_ACTIVE_STRATEGIES = 5;
    uint256 public constant MAX_FEE_BPS = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5%

    // ============ Struct ============
    struct Strategy {
        address tokenIn;
        address tokenOut;
        uint256 tradeAmount;
        uint256 minReturn;
        uint256 maxSlippageBps;
        bool isActive;
        bool isPaused;
        uint256 createdAt;
        uint256 lastExecuted;
        uint256 totalTrades;
    }

    // ============ State ============
    address public operator;
    uint256 public globalFeeBps;
    bool public globalTradingPaused;

    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => mapping(address => uint256)) public userLockedBalances;
    mapping(address => Strategy[]) public userStrategies;
    mapping(address => uint256) public userActiveStrategyCount;

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotGloballyPaused() {
        if (globalTradingPaused) revert TradingPaused();
        _;
    }

    modifier validToken(address token) {
        if (token == address(0)) revert ZeroAddress();
        _;
    }

    // ============ Constructor ============
    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        globalFeeBps = DEFAULT_FEE_BPS;
    }

    // ============ Admin ============
    function setOperator(address _operator) external onlyOwner validToken(_operator) {
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    function setGlobalFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = globalFeeBps;
        globalFeeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    function pauseGlobalTrading() external onlyOperator {
        if (globalTradingPaused) revert TradingPaused();
        globalTradingPaused = true;
        emit GlobalTradingPaused();
    }

    function resumeGlobalTrading() external onlyOperator {
        if (!globalTradingPaused) revert TradingPaused();
        globalTradingPaused = false;
        emit GlobalTradingResumed();
    }

    // ============ Balance ============
    function deposit(address token, uint256 amount) external nonReentrant whenNotGloballyPaused validToken(token) {
        if (amount == 0) revert ZeroAmount();
        userBalances[msg.sender][token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant validToken(token) {
        if (amount == 0) revert ZeroAmount();
        uint256 locked = userLockedBalances[msg.sender][token];
        uint256 balance = userBalances[msg.sender][token];
        if (amount > balance - locked) revert InsufficientBalance();
        userBalances[msg.sender][token] = balance - amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    // ============ Strategy Management ============
    function createStrategy(
        address tokenIn,
        address tokenOut,
        uint256 tradeAmount,
        uint256 minReturn,
        uint256 maxSlippageBps
    ) external nonReentrant whenNotGloballyPaused validToken(tokenIn) validToken(tokenOut) returns (uint256 strategyId) {
        if (tokenIn == tokenOut) revert SameTokenPair();
        if (tradeAmount == 0) revert ZeroAmount();
        if (maxSlippageBps > 10000) revert InvalidTradeParameters();
        if (userActiveStrategyCount[msg.sender] >= MAX_ACTIVE_STRATEGIES) revert MaxStrategiesReached();

        uint256 available = userBalances[msg.sender][tokenIn] - userLockedBalances[msg.sender][tokenIn];
        if (tradeAmount > available) revert InsufficientBalance();

        userLockedBalances[msg.sender][tokenIn] += tradeAmount;

        strategyId = userStrategies[msg.sender].length;
        userStrategies[msg.sender].push(
            Strategy({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                tradeAmount: tradeAmount,
                minReturn: minReturn,
                maxSlippageBps: maxSlippageBps,
                isActive: true,
                isPaused: false,
                createdAt: block.timestamp,
                lastExecuted: 0,
                totalTrades: 0
            })
        );
        userActiveStrategyCount[msg.sender]++;

        emit StrategyCreated(msg.sender, strategyId, tokenIn, tokenOut, tradeAmount, minReturn, maxSlippageBps);
    }

    function modifyStrategy(
        uint256 strategyId,
        uint256 newTradeAmount,
        uint256 newMinReturn,
        uint256 newMaxSlippageBps
    ) external nonReentrant whenNotGloballyPaused {
        Strategy[] storage strategies = userStrategies[msg.sender];
        if (strategyId >= strategies.length) revert StrategyNotFound();
        Strategy storage strategy = strategies[strategyId];
        if (!strategy.isActive) revert StrategyNotActive();
        if (newTradeAmount == 0) revert ZeroAmount();
        if (newMaxSlippageBps > 10000) revert InvalidTradeParameters();

        address tokenIn = strategy.tokenIn;
        if (newTradeAmount > strategy.tradeAmount) {
            uint256 diff = newTradeAmount - strategy.tradeAmount;
            uint256 available = userBalances[msg.sender][tokenIn] - userLockedBalances[msg.sender][tokenIn];
            if (diff > available) revert InsufficientBalance();
            userLockedBalances[msg.sender][tokenIn] += diff;
        } else if (newTradeAmount < strategy.tradeAmount) {
            uint256 diff = strategy.tradeAmount - newTradeAmount;
            userLockedBalances[msg.sender][tokenIn] -= diff;
        }

        strategy.tradeAmount = newTradeAmount;
        strategy.minReturn = newMinReturn;
        strategy.maxSlippageBps = newMaxSlippageBps;

        emit StrategyModified(msg.sender, strategyId, newTradeAmount, newMinReturn, newMaxSlippageBps);
    }

    function pauseStrategy(uint256 strategyId) external {
        Strategy[] storage strategies = userStrategies[msg.sender];
        if (strategyId >= strategies.length) revert StrategyNotFound();
        Strategy storage strategy = strategies[strategyId];
        if (!strategy.isActive) revert StrategyAlreadyPaused();

        strategy.isActive = false;
        strategy.isPaused = true;
        userActiveStrategyCount[msg.sender]--;
        userLockedBalances[msg.sender][strategy.tokenIn] -= strategy.tradeAmount;

        emit StrategyPaused(msg.sender, strategyId);
    }

    function resumeStrategy(uint256 strategyId) external whenNotGloballyPaused {
        Strategy[] storage strategies = userStrategies[msg.sender];
        if (strategyId >= strategies.length) revert StrategyNotFound();
        Strategy storage strategy = strategies[strategyId];
        if (strategy.isActive) revert StrategyAlreadyActive();
        if (userActiveStrategyCount[msg.sender] >= MAX_ACTIVE_STRATEGIES) revert MaxStrategiesReached();

        uint256 available = userBalances[msg.sender][strategy.tokenIn] - userLockedBalances[msg.sender][strategy.tokenIn];
        if (strategy.tradeAmount > available) revert InsufficientBalance();

        userLockedBalances[msg.sender][strategy.tokenIn] += strategy.tradeAmount;
        strategy.isActive = true;
        strategy.isPaused = false;
        userActiveStrategyCount[msg.sender]++;

        emit StrategyResumed(msg.sender, strategyId);
    }

    function cancelStrategy(uint256 strategyId) external nonReentrant {
        Strategy[] storage strategies = userStrategies[msg.sender];
        if (strategyId >= strategies.length) revert StrategyNotFound();
        Strategy storage strategy = strategies[strategyId];

        if (strategy.isActive) {
            userLockedBalances[msg.sender][strategy.tokenIn] -= strategy.tradeAmount;
            userActiveStrategyCount[msg.sender]--;
        }

        uint256 lastIndex = strategies.length - 1;
        if (strategyId != lastIndex) {
            strategies[strategyId] = strategies[lastIndex];
        }
        strategies.pop();

        emit StrategyCancelled(msg.sender, strategyId);
    }

    // ============ Trade Execution ============
    function executeTrade(
        address user,
        uint256 strategyId,
        uint256 receivedAmount
    ) external onlyOperator nonReentrant whenNotGloballyPaused returns (uint256 feeAmount, uint256 netReceived) {
        Strategy[] storage strategies = userStrategies[user];
        if (strategyId >= strategies.length) revert StrategyNotFound();
        Strategy storage strategy = strategies[strategyId];
        if (!strategy.isActive) revert StrategyNotActive();
        if (receivedAmount < strategy.minReturn) revert SlippageExceeded();

        uint256 tradeAmount = strategy.tradeAmount;
        address tokenIn = strategy.tokenIn;
        address tokenOut = strategy.tokenOut;

        userBalances[user][tokenIn] -= tradeAmount;
        userLockedBalances[user][tokenIn] -= tradeAmount;

        feeAmount = (receivedAmount * globalFeeBps) / 10000;
        netReceived = receivedAmount - feeAmount;

        userBalances[user][tokenOut] += netReceived;
        if (feeAmount > 0) {
            userBalances[operator][tokenOut] += feeAmount;
        }

        strategy.lastExecuted = block.timestamp;
        strategy.totalTrades++;
        strategy.isActive = false;
        strategy.tradeAmount = 0;
        userActiveStrategyCount[user]--;

        emit TradeExecuted(user, strategyId, tokenIn, tokenOut, tradeAmount, receivedAmount, feeAmount);
    }

    // ============ Views ============
    function getStrategy(address user, uint256 strategyId) external view returns (Strategy memory) {
        if (strategyId >= userStrategies[user].length) revert StrategyNotFound();
        return userStrategies[user][strategyId];
    }

    function getStrategyCount(address user) external view returns (uint256) {
        return userStrategies[user].length;
    }

    function getActiveStrategyCount(address user) external view returns (uint256) {
        return userActiveStrategyCount[user];
    }

    function getAvailableBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token] - userLockedBalances[user][token];
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }
}
