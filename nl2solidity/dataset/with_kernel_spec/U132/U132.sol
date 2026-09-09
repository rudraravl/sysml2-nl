// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WrappedAssetBridge {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public operator;
    address public pendingOperator;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public escrowedBalance;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(bytes32 => bool) public externalDepositProcessed;
    mapping(bytes32 => bool) public withdrawalRequestProcessed;

    uint256 public constant MAX_MINT = 1000 ether;
    uint256 public constant WITHDRAWAL_FEE = 0.01 ether;

    event Minted(address indexed to, uint256 amount, uint256 fee, bytes32 indexed externalDepositId);
    event Burned(address indexed from, uint256 amount, bytes32 indexed withdrawalRequestId);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, bytes32 indexed externalDepositId);
    event WithdrawalRequested(address indexed user, uint256 amount, bytes32 indexed externalDepositId);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error NotOperator();
    error NotPendingOperator();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountExceedsMax();
    error AlreadyProcessed();
    error ZeroAmount();
    error ZeroAddress();
    error FeeExceedsAmount();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        name = "Wrapped External Asset";
        symbol = "wEXT";
        emit OperatorChanged(address(0), _operator);
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        escrowedBalance[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    function requestWithdrawal(uint256 amount, bytes32 externalDepositId) external {
        if (amount == 0) revert ZeroAmount();
        if (amount <= WITHDRAWAL_FEE) revert FeeExceedsAmount();

        emit WithdrawalRequested(msg.sender, amount, externalDepositId);
    }

    function mint(address to, uint256 amount, bytes32 externalDepositId) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_MINT) revert AmountExceedsMax();
        if (amount <= WITHDRAWAL_FEE) revert FeeExceedsAmount();
        if (externalDepositProcessed[externalDepositId]) revert AlreadyProcessed();

        externalDepositProcessed[externalDepositId] = true;

        uint256 fee = WITHDRAWAL_FEE;
        uint256 net = amount - fee;

        totalSupply += amount;
        balanceOf[to] += net;
        balanceOf[operator] += fee;

        emit Minted(to, amount, fee, externalDepositId);
        emit Withdrawn(to, net, externalDepositId);
    }

    function burn(address from, uint256 amount, bytes32 withdrawalRequestId) external onlyOperator {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (withdrawalRequestProcessed[withdrawalRequestId]) revert AlreadyProcessed();
        if (escrowedBalance[from] < amount) revert InsufficientBalance();

        withdrawalRequestProcessed[withdrawalRequestId] = true;
        escrowedBalance[from] -= amount;
        totalSupply -= amount;

        emit Burned(from, amount, withdrawalRequestId);
    }

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
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                if (allowed < amount) revert InsufficientAllowance();
                allowance[from][msg.sender] = allowed - amount;
            }
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function proposeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        pendingOperator = newOperator;
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NotPendingOperator();

        address previous = operator;
        operator = pendingOperator;
        pendingOperator = address(0);

        emit OperatorChanged(previous, operator);
    }
}
