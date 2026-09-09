// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

contract ReentrancyGuard {
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
}

contract StrategyVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error NotOperator();
    error DepositsArePaused();
    error TokenNotAllowed();
    error InsufficientBalance();
    error MaxAgentStrategiesReached();
    error AgentNotActive();
    error AgentNotApproved();
    error AgentAlreadyActive();
    error ZeroAmount();
    error AddressZero();

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event AgentStrategyApproved(address indexed user, address indexed agent);
    event AgentStrategyRevoked(address indexed user, address indexed agent);
    event TokenAllowed(address indexed token, bool allowed);
    event AgentConfigured(address indexed agent, bool approved, bytes32 config);
    event DepositsPaused(bool paused);
    event OperatorUpdated(address indexed newOperator);

    address public operator;
    bool public depositsPaused;

    uint256 public constant MAX_AGENT_STRATEGIES_PER_USER = 10;
    uint256 public constant FEE_BPS = 10;
    uint256 private constant BPS_DENOMINATOR = 10000;

    mapping(address => bool) public allowedTokens;
    mapping(address => mapping(address => uint256)) public userBalances;

    mapping(address => bool) public approvedAgents;
    mapping(address => bytes32) public agentStrategyConfig;
    mapping(address => mapping(address => bool)) public userActiveAgents;
    mapping(address => uint256) public userActiveAgentCount;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsArePaused();
        _;
    }

    modifier onlyAllowedToken(address token) {
        if (!allowedTokens[token]) revert TokenNotAllowed();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert AddressZero();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert AddressZero();
        operator = _newOperator;
        emit OperatorUpdated(_newOperator);
    }

    function setAllowedToken(address token, bool allowed) external onlyOperator {
        if (token == address(0)) revert AddressZero();
        allowedTokens[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    function setDepositsPaused(bool _paused) external onlyOperator {
        depositsPaused = _paused;
        emit DepositsPaused(_paused);
    }

    function configureAgentStrategy(address agent, bool approved, bytes32 config) external onlyOperator {
        if (agent == address(0)) revert AddressZero();
        approvedAgents[agent] = approved;
        agentStrategyConfig[agent] = config;
        emit AgentConfigured(agent, approved, config);
    }

    function deposit(address token, uint256 amount) external nonReentrant whenDepositsNotPaused onlyAllowedToken(token) {
        if (amount == 0) revert ZeroAmount();

        userBalances[msg.sender][token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant onlyAllowedToken(token) {
        if (amount == 0) revert ZeroAmount();

        uint256 balance = userBalances[msg.sender][token];
        if (balance < amount) revert InsufficientBalance();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 amountAfterFee = amount - fee;

        userBalances[msg.sender][token] = balance - amount;

        IERC20(token).safeTransfer(msg.sender, amountAfterFee);
        if (fee > 0) {
            IERC20(token).safeTransfer(operator, fee);
        }

        emit Withdraw(msg.sender, token, amount, fee);
    }

    function approveAgentStrategy(address agent) external {
        if (agent == address(0)) revert AddressZero();
        if (!approvedAgents[agent]) revert AgentNotApproved();
        if (userActiveAgents[msg.sender][agent]) revert AgentAlreadyActive();
        if (userActiveAgentCount[msg.sender] >= MAX_AGENT_STRATEGIES_PER_USER) revert MaxAgentStrategiesReached();

        userActiveAgents[msg.sender][agent] = true;
        userActiveAgentCount[msg.sender]++;

        emit AgentStrategyApproved(msg.sender, agent);
    }

    function revokeAgentStrategy(address agent) external {
        if (!userActiveAgents[msg.sender][agent]) revert AgentNotActive();

        userActiveAgents[msg.sender][agent] = false;
        userActiveAgentCount[msg.sender]--;

        emit AgentStrategyRevoked(msg.sender, agent);
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }

    function isAgentActiveForUser(address user, address agent) external view returns (bool) {
        return userActiveAgents[user][agent];
    }

    function isTokenAllowed(address token) external view returns (bool) {
        return allowedTokens[token];
    }

    function isAgentApproved(address agent) external view returns (bool) {
        return approvedAgents[agent];
    }

    function getActiveAgentCount(address user) external view returns (uint256) {
        return userActiveAgentCount[user];
    }
}
