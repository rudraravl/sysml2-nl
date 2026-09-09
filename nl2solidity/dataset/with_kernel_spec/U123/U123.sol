// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

error NotOwner();
error NotOperator();
error ZeroAddress();
error ZeroAmount();
error TokenNotSupported();
error TokenAlreadySupported();
error FeeExceedsLimit();
error InsufficientBalance();
error RequestNotFound();
error RequestNotPending();
error RequestExpired();
error TransferFailed();
error NotRequestOwner();

/// @title CryptoDebitCard
/// @notice Manages user balances for a crypto-linked debit card service.
///         Users deposit supported ERC-20 tokens, withdraw with a fee (max 0.5%),
///         and initiate card payment requests that an operator approves or rejects within 24 hours.
contract CryptoDebitCard {
    uint256 public constant MAX_FEE_BPS = 50; // 0.5%
    uint256 public constant APPROVAL_WINDOW = 24 hours;
    uint256 private constant BPS_DENOMINATOR = 10000;

    address public owner;
    address public operator;

    struct TokenConfig {
        bool supported;
        uint256 feeBps;
    }

    enum RequestStatus {
        Pending,
        Approved,
        Rejected
    }

    struct PaymentRequest {
        address user;
        address token;
        uint256 amount;
        uint256 submittedAt;
        RequestStatus status;
        bool exists;
    }

    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => TokenConfig) public tokenConfigs;
    address[] public supportedTokens;

    mapping(uint256 => PaymentRequest) public paymentRequests;
    uint256 public nextRequestId;

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event CardPaymentRequested(uint256 indexed requestId, address indexed user, address indexed token, uint256 amount);
    event CardPaymentApproved(uint256 indexed requestId);
    event CardPaymentRejected(uint256 indexed requestId);
    event TokenAdded(address indexed token, uint256 feeBps);
    event TokenRemoved(address indexed token);
    event FeeUpdated(address indexed token, uint256 feeBps);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = _operator;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), _operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, newOperator);
        operator = newOperator;
    }

    function addSupportedToken(address token, uint256 feeBps) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (tokenConfigs[token].supported) revert TokenAlreadySupported();
        if (feeBps > MAX_FEE_BPS) revert FeeExceedsLimit();

        tokenConfigs[token] = TokenConfig({supported: true, feeBps: feeBps});
        supportedTokens.push(token);
        emit TokenAdded(token, feeBps);
    }

    function removeSupportedToken(address token) external onlyOperator {
        if (!tokenConfigs[token].supported) revert TokenNotSupported();

        tokenConfigs[token].supported = false;
        tokenConfigs[token].feeBps = 0;

        uint256 len = supportedTokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[len - 1];
                supportedTokens.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    function setWithdrawalFee(address token, uint256 feeBps) external onlyOperator {
        if (!tokenConfigs[token].supported) revert TokenNotSupported();
        if (feeBps > MAX_FEE_BPS) revert FeeExceedsLimit();

        tokenConfigs[token].feeBps = feeBps;
        emit FeeUpdated(token, feeBps);
    }

    function deposit(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (!tokenConfigs[token].supported) revert TokenNotSupported();

        _safeTransferFrom(token, msg.sender, address(this), amount);
        balances[msg.sender][token] += amount;
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (!tokenConfigs[token].supported) revert TokenNotSupported();
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();

        uint256 fee = (amount * tokenConfigs[token].feeBps) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        balances[msg.sender][token] -= amount;

        if (fee > 0) {
            _safeTransfer(token, operator, fee);
        }
        _safeTransfer(token, msg.sender, payout);

        emit Withdrawn(msg.sender, token, amount, fee);
    }

    function initiateCardPayment(address token, uint256 amount) external returns (uint256 requestId) {
        if (amount == 0) revert ZeroAmount();
        if (!tokenConfigs[token].supported) revert TokenNotSupported();
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();

        balances[msg.sender][token] -= amount;

        requestId = nextRequestId++;
        paymentRequests[requestId] = PaymentRequest({
            user: msg.sender,
            token: token,
            amount: amount,
            submittedAt: block.timestamp,
            status: RequestStatus.Pending,
            exists: true
        });

        emit CardPaymentRequested(requestId, msg.sender, token, amount);
    }

    function approveCardPayment(uint256 requestId) external onlyOperator {
        PaymentRequest storage req = paymentRequests[requestId];
        if (!req.exists) revert RequestNotFound();
        if (req.status != RequestStatus.Pending) revert RequestNotPending();
        if (block.timestamp > req.submittedAt + APPROVAL_WINDOW) revert RequestExpired();

        req.status = RequestStatus.Approved;

        _safeTransfer(req.token, operator, req.amount);

        emit CardPaymentApproved(requestId);
    }

    function rejectCardPayment(uint256 requestId) external onlyOperator {
        PaymentRequest storage req = paymentRequests[requestId];
        if (!req.exists) revert RequestNotFound();
        if (req.status != RequestStatus.Pending) revert RequestNotPending();

        req.status = RequestStatus.Rejected;
        balances[req.user][req.token] += req.amount;

        emit CardPaymentRejected(requestId);
    }

    function cancelCardPayment(uint256 requestId) external {
        PaymentRequest storage req = paymentRequests[requestId];
        if (!req.exists) revert RequestNotFound();
        if (req.user != msg.sender) revert NotRequestOwner();
        if (req.status != RequestStatus.Pending) revert RequestNotPending();

        req.status = RequestStatus.Rejected;
        balances[req.user][req.token] += req.amount;

        emit CardPaymentRejected(requestId);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function getBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }

    function isTokenSupported(address token) external view returns (bool) {
        return tokenConfigs[token].supported;
    }

    function getTokenFee(address token) external view returns (uint256) {
        return tokenConfigs[token].feeBps;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getPaymentRequest(uint256 requestId)
        external
        view
        returns (
            address user,
            address token,
            uint256 amount,
            uint256 submittedAt,
            RequestStatus status,
            bool exists
        )
    {
        PaymentRequest storage req = paymentRequests[requestId];
        return (req.user, req.token, req.amount, req.submittedAt, req.status, req.exists);
    }

    function supportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }
}
