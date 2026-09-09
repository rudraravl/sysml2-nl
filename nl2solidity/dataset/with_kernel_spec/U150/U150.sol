// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FiatCryptoPaymentProcessor {
    IERC20 public immutable stablecoin;

    address public owner;
    address public operator;

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_DEPOSIT = 10_000 * 10 ** 18;
    uint256 public processingFeeBps;

    mapping(address => uint256) public userBalances;
    mapping(string => bool) public supportedFiatCurrencies;

    enum PayoutStatus {
        Pending,
        Approved,
        Rejected
    }

    struct PayoutRequest {
        address requester;
        uint256 fiatAmount;
        string fiatCurrency;
        string bankAccount;
        uint256 stablecoinAmount;
        uint256 feeAmount;
        PayoutStatus status;
        uint256 createdAt;
    }

    mapping(uint256 => PayoutRequest) public payoutRequests;
    uint256 public payoutRequestCount;

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event PayoutRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint256 fiatAmount,
        string fiatCurrency,
        string bankAccount,
        uint256 stablecoinAmount,
        uint256 feeAmount
    );
    event PayoutApproved(uint256 indexed requestId, address indexed operator, uint256 stablecoinAmount);
    event PayoutRejected(uint256 indexed requestId, address indexed operator);
    event ProcessingFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FiatCurrencyAdded(string currency);
    event FiatCurrencyRemoved(string currency);
    event OperatorUpdated(address oldOperator, address newOperator);
    event OwnershipTransferred(address oldOwner, address newOwner);

    error OnlyOwner();
    error OnlyOperator();
    error ZeroAddress();
    error DepositExceedsMax(uint256 amount, uint256 max);
    error TransferFailed();
    error InsufficientBalance(uint256 available, uint256 required);
    error CurrencyNotSupported(string currency);
    error InvalidAmount();
    error InvalidBankAccount();
    error EmptyString();
    error PayoutNotPending(uint256 requestId, PayoutStatus status);
    error PayoutNotFound(uint256 requestId);
    error InvalidFeeBps(uint256 bps);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        processingFeeBps = 50; // 0.5%

        supportedFiatCurrencies["USD"] = true;
        supportedFiatCurrencies["EUR"] = true;
        supportedFiatCurrencies["GBP"] = true;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit ProcessingFeeUpdated(0, 50);
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (amount > MAX_DEPOSIT) revert DepositExceedsMax(amount, MAX_DEPOSIT);

        uint256 balanceBefore = stablecoin.balanceOf(address(this));
        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
        uint256 received = stablecoin.balanceOf(address(this)) - balanceBefore;

        userBalances[msg.sender] += received;

        emit Deposited(msg.sender, received, userBalances[msg.sender]);
    }

    function requestPayout(
        uint256 fiatAmount,
        string calldata fiatCurrency,
        string calldata bankAccount
    ) external returns (uint256 requestId) {
        if (fiatAmount == 0) revert InvalidAmount();
        if (!supportedFiatCurrencies[fiatCurrency]) revert CurrencyNotSupported(fiatCurrency);
        if (bytes(bankAccount).length == 0) revert InvalidBankAccount();

        uint256 feeAmount = (fiatAmount * processingFeeBps) / FEE_DENOMINATOR;
        uint256 stablecoinAmount = fiatAmount + feeAmount;

        if (userBalances[msg.sender] < stablecoinAmount) {
            revert InsufficientBalance(userBalances[msg.sender], stablecoinAmount);
        }

        userBalances[msg.sender] -= stablecoinAmount;

        requestId = payoutRequestCount++;
        payoutRequests[requestId] = PayoutRequest({
            requester: msg.sender,
            fiatAmount: fiatAmount,
            fiatCurrency: fiatCurrency,
            bankAccount: bankAccount,
            stablecoinAmount: stablecoinAmount,
            feeAmount: feeAmount,
            status: PayoutStatus.Pending,
            createdAt: block.timestamp
        });

        emit PayoutRequested(
            requestId,
            msg.sender,
            fiatAmount,
            fiatCurrency,
            bankAccount,
            stablecoinAmount,
            feeAmount
        );
    }

    function approvePayout(uint256 requestId) external onlyOperator {
        PayoutRequest storage req = payoutRequests[requestId];
        if (req.requester == address(0)) revert PayoutNotFound(requestId);
        if (req.status != PayoutStatus.Pending) revert PayoutNotPending(requestId, req.status);

        req.status = PayoutStatus.Approved;

        bool success = stablecoin.transfer(operator, req.stablecoinAmount);
        if (!success) revert TransferFailed();

        emit PayoutApproved(requestId, msg.sender, req.stablecoinAmount);
    }

    function rejectPayout(uint256 requestId) external onlyOperator {
        PayoutRequest storage req = payoutRequests[requestId];
        if (req.requester == address(0)) revert PayoutNotFound(requestId);
        if (req.status != PayoutStatus.Pending) revert PayoutNotPending(requestId, req.status);

        req.status = PayoutStatus.Rejected;

        userBalances[req.requester] += req.stablecoinAmount;

        emit PayoutRejected(requestId, msg.sender);
    }

    function updateProcessingFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > FEE_DENOMINATOR) revert InvalidFeeBps(newFeeBps);
        uint256 oldFeeBps = processingFeeBps;
        processingFeeBps = newFeeBps;
        emit ProcessingFeeUpdated(oldFeeBps, newFeeBps);
    }

    function addFiatCurrency(string calldata currency) external onlyOperator {
        if (bytes(currency).length == 0) revert EmptyString();
        supportedFiatCurrencies[currency] = true;
        emit FiatCurrencyAdded(currency);
    }

    function removeFiatCurrency(string calldata currency) external onlyOperator {
        if (bytes(currency).length == 0) revert EmptyString();
        supportedFiatCurrencies[currency] = false;
        emit FiatCurrencyRemoved(currency);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function getBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }

    function getPayoutRequest(uint256 requestId)
        external
        view
        returns (
            address requester,
            uint256 fiatAmount,
            string memory fiatCurrency,
            string memory bankAccount,
            uint256 stablecoinAmount,
            uint256 feeAmount,
            PayoutStatus status,
            uint256 createdAt
        )
    {
        PayoutRequest storage req = payoutRequests[requestId];
        return (
            req.requester,
            req.fiatAmount,
            req.fiatCurrency,
            req.bankAccount,
            req.stablecoinAmount,
            req.feeAmount,
            req.status,
            req.createdAt
        );
    }

    function isFiatSupported(string calldata currency) external view returns (bool) {
        return supportedFiatCurrencies[currency];
    }
}
