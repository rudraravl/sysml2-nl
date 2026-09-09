// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(0x20, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract CrossChainEscrow {
    using SafeERC20 for IERC20;

    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error DepositTooSmall(uint256 amount, uint256 minimum);
    error WithdrawalDelayTooLong(uint256 delay, uint256 maximum);
    error TokenNotSupported();
    error TokenAlreadySupported();
    error InvalidL2Token();
    error WithdrawalDoesNotExist();
    error WithdrawalAlreadyClaimed();
    error WithdrawalNotReady(uint256 currentTime, uint256 unlockTime);
    error InvalidClaimant(address caller, address recipient);

    uint256 public constant MAX_WITHDRAWAL_DELAY = 7 days;
    uint256 public constant MIN_DEPOSIT = 100;

    event Deposit(
        address indexed sender,
        bytes32 indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 depositId
    );
    event WithdrawalProcessed(
        uint256 indexed withdrawalId,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 unlockTime
    );
    event WithdrawalClaimed(
        uint256 indexed withdrawalId,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );
    event TokenSupported(address indexed token, address indexed l2Token);
    event L2TokenUpdated(
        address indexed token,
        address indexed oldL2Token,
        address indexed newL2Token
    );
    event WithdrawalDelaySet(address indexed token, uint256 oldDelay, uint256 newDelay);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    struct PendingDeposit {
        address sender;
        bytes32 recipient;
        address token;
        uint256 amount;
        uint256 timestamp;
    }

    struct PendingWithdrawal {
        address recipient;
        address token;
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }

    address public operator;
    mapping(address => address) public l2Tokens;
    mapping(address => uint256) public withdrawalDelays;
    mapping(uint256 => PendingDeposit) public pendingDeposits;
    mapping(uint256 => PendingWithdrawal) public pendingWithdrawals;
    uint256 public nextDepositId;
    uint256 public nextWithdrawalId;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        nextDepositId = 1;
        nextWithdrawalId = 1;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function addSupportedToken(address token, address l2Token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (l2Token == address(0)) revert InvalidL2Token();
        if (l2Tokens[token] != address(0)) revert TokenAlreadySupported();
        l2Tokens[token] = l2Token;
        emit TokenSupported(token, l2Token);
    }

    function updateL2Token(address token, address newL2Token) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (l2Tokens[token] == address(0)) revert TokenNotSupported();
        if (newL2Token == address(0)) revert InvalidL2Token();
        address old = l2Tokens[token];
        l2Tokens[token] = newL2Token;
        emit L2TokenUpdated(token, old, newL2Token);
    }

    function setWithdrawalDelay(address token, uint256 delay) external onlyOperator {
        if (l2Tokens[token] == address(0)) revert TokenNotSupported();
        if (delay > MAX_WITHDRAWAL_DELAY) {
            revert WithdrawalDelayTooLong(delay, MAX_WITHDRAWAL_DELAY);
        }
        uint256 old = withdrawalDelays[token];
        withdrawalDelays[token] = delay;
        emit WithdrawalDelaySet(token, old, delay);
    }

    function deposit(address token, bytes32 recipient, uint256 amount) external {
        if (l2Tokens[token] == address(0)) revert TokenNotSupported();
        if (recipient == bytes32(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_DEPOSIT) revert DepositTooSmall(amount, MIN_DEPOSIT);

        uint256 depositId = nextDepositId++;
        pendingDeposits[depositId] = PendingDeposit({
            sender: msg.sender,
            recipient: recipient,
            token: token,
            amount: amount,
            timestamp: block.timestamp
        });

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, recipient, token, amount, depositId);
    }

    function processWithdrawal(address recipient, address token, uint256 amount) external onlyOperator {
        if (l2Tokens[token] == address(0)) revert TokenNotSupported();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 withdrawalId = nextWithdrawalId++;
        uint256 delay = withdrawalDelays[token];
        uint256 unlockTime = block.timestamp + delay;

        pendingWithdrawals[withdrawalId] = PendingWithdrawal({
            recipient: recipient,
            token: token,
            amount: amount,
            unlockTime: unlockTime,
            claimed: false
        });

        emit WithdrawalProcessed(withdrawalId, recipient, token, amount, unlockTime);
    }

    function claimWithdrawal(uint256 withdrawalId) external {
        PendingWithdrawal storage w = pendingWithdrawals[withdrawalId];
        if (w.recipient == address(0)) revert WithdrawalDoesNotExist();
        if (w.claimed) revert WithdrawalAlreadyClaimed();
        if (msg.sender != w.recipient) revert InvalidClaimant(msg.sender, w.recipient);
        if (block.timestamp < w.unlockTime) {
            revert WithdrawalNotReady(block.timestamp, w.unlockTime);
        }

        w.claimed = true;
        address token = w.token;
        uint256 amount = w.amount;
        address recipient = w.recipient;

        IERC20(token).safeTransfer(recipient, amount);

        emit WithdrawalClaimed(withdrawalId, recipient, token, amount);
    }

    function getL2Token(address token) external view returns (address) {
        return l2Tokens[token];
    }

    function getWithdrawalDelay(address token) external view returns (uint256) {
        return withdrawalDelays[token];
    }

    function isSupported(address token) external view returns (bool) {
        return l2Tokens[token] != address(0);
    }

    function getPendingDeposit(uint256 depositId) external view returns (PendingDeposit memory) {
        return pendingDeposits[depositId];
    }

    function getPendingWithdrawal(uint256 withdrawalId) external view returns (PendingWithdrawal memory) {
        return pendingWithdrawals[withdrawalId];
    }

    function escrowBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
