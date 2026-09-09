// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function harvest() external returns (uint256);
}

contract YieldAggregator {
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotSupported();
    error TokenAlreadySupported();
    error MaxTokensReached();
    error InsufficientBalance();
    error StrategyNotSet();
    error NoYieldToClaim();
    error TransferFailed();
    error ReentrantCall();
    error InsufficientStrategyLiquidity();

    uint256 public constant MAX_SUPPORTED_TOKENS = 10;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public operator;
    address public feeRecipient;

    uint256 private _locked = 1;

    address[] internal _supportedTokens;
    mapping(address => bool) public isSupported;
    mapping(address => address) public tokenStrategy;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => uint256) public totalDeposited;
    mapping(address => uint256) public accumulatedYield;
    mapping(address => mapping(address => uint256)) public yieldClaimed;

    event TokenAdded(address indexed token, address indexed strategy);
    event StrategyUpdated(address indexed token, address indexed oldStrategy, address indexed newStrategy);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event YieldClaimed(address indexed user, address indexed token, uint256 amount);
    event YieldHarvested(address indexed token, uint256 amount);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldFeeRecipient, address indexed newFeeRecipient);

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _operator, address _feeRecipient) {
        if (_operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        operator = _operator;
        feeRecipient = _feeRecipient;
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    function supportedTokensCount() external view returns (uint256) {
        return _supportedTokens.length;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return _supportedTokens;
    }

    function pendingYield(address token, address user) external view returns (uint256) {
        if (!isSupported[token]) return 0;
        uint256 totalDep = totalDeposited[token];
        if (totalDep < 1) return 0;
        uint256 userDep = userBalances[token][user];
        if (userDep < 1) return 0;
        uint256 userShare = (userDep * accumulatedYield[token]) / totalDep;
        uint256 claimed = yieldClaimed[token][user];
        if (userShare <= claimed) return 0;
        return userShare - claimed;
    }

    function addSupportedToken(address token, address strategy) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (isSupported[token]) revert TokenAlreadySupported();
        if (_supportedTokens.length >= MAX_SUPPORTED_TOKENS) revert MaxTokensReached();
        isSupported[token] = true;
        _supportedTokens.push(token);
        tokenStrategy[token] = strategy;
        emit TokenAdded(token, strategy);
    }

    function updateStrategy(address token, address newStrategy) external onlyOperator {
        if (!isSupported[token]) revert TokenNotSupported();
        address oldStrategy = tokenStrategy[token];
        tokenStrategy[token] = newStrategy;
        emit StrategyUpdated(token, oldStrategy, newStrategy);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (!isSupported[token]) revert TokenNotSupported();

        // Effects: update state before external interactions
        userBalances[token][msg.sender] += amount;
        totalDeposited[token] += amount;

        // Interactions: pull tokens from depositor
        _safeTransferFrom(token, msg.sender, address(this), amount);

        address strat = tokenStrategy[token];
        if (strat != address(0)) {
            _safeTransfer(token, strat, amount);
            IStrategy(strat).deposit(amount);
        }

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (amount < 1) revert ZeroAmount();
        if (!isSupported[token]) revert TokenNotSupported();
        if (userBalances[token][msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Effects: update state before external interactions
        userBalances[token][msg.sender] -= amount;
        totalDeposited[token] -= amount;

        // Interactions: withdraw from strategy if set and use return value
        address strat = tokenStrategy[token];
        if (strat != address(0)) {
            uint256 returned = IStrategy(strat).withdraw(amount);
            if (returned < amount) {
                // Top up from contract balance if possible
                uint256 contractBal = IERC20(token).balanceOf(address(this));
                if (contractBal + returned < amount) revert InsufficientStrategyLiquidity();
            }
        }

        _safeTransfer(token, msg.sender, netAmount);
        if (fee > 0) {
            _safeTransfer(token, feeRecipient, fee);
        }

        emit Withdrawal(msg.sender, token, netAmount, fee);
    }

    function harvestYield(address token) external nonReentrant {
        if (!isSupported[token]) revert TokenNotSupported();
        address strat = tokenStrategy[token];
        if (strat == address(0)) revert StrategyNotSet();
        uint256 harvested = IStrategy(strat).harvest();
        if (harvested < 1) revert NoYieldToClaim();
        accumulatedYield[token] += harvested;
        emit YieldHarvested(token, harvested);
    }

    function claimYield(address token) external nonReentrant {
        if (!isSupported[token]) revert TokenNotSupported();
        uint256 totalDep = totalDeposited[token];
        uint256 userDep = userBalances[token][msg.sender];
        if (totalDep < 1 || userDep < 1) revert NoYieldToClaim();

        uint256 totalY = accumulatedYield[token];
        if (totalY < 1) revert NoYieldToClaim();

        uint256 userShare = (userDep * totalY) / totalDep;
        uint256 alreadyClaimed = yieldClaimed[token][msg.sender];
        if (userShare <= alreadyClaimed) revert NoYieldToClaim();

        uint256 claimable = userShare - alreadyClaimed;

        // Effects: record claimed amount before transfer
        yieldClaimed[token][msg.sender] = userShare;

        // Interactions
        _safeTransfer(token, msg.sender, claimable);

        emit YieldClaimed(msg.sender, token, claimable);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }
}
