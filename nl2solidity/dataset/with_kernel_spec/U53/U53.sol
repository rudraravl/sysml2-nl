// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
 * @title CryptoDebitCardGateway
 * @notice A payment gateway that holds user-deposited stablecoins to back
 *         crypto debit card spending. Users deposit stablecoins, withdraw
 *         their available balance, and request card top-ups. A designated
 *         operator approves top-up requests and manages the fee configuration.
 */
contract CryptoDebitCardGateway {
    // -----------------------------------------------------------------------
    //                             Custom Errors
    // -----------------------------------------------------------------------
    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error CardNotActivated(address user);
    error InsufficientBalance(uint256 available, uint256 required);
    error InvalidRequestId(uint256 requestId);
    error InvalidFeeBps(uint256 feeBps);
    error TransferFailed();
    error ReentrantCall();

    // -----------------------------------------------------------------------
    //                              Enums
    // -----------------------------------------------------------------------
    enum TopUpStatus {
        NonExistent,
        Pending,
        Approved,
        Rejected
    }

    // -----------------------------------------------------------------------
    //                             Structs
    // -----------------------------------------------------------------------
    struct TopUpRequest {
        address user;
        uint256 amount;
        TopUpStatus status;
    }

    // -----------------------------------------------------------------------
    //                              Events
    // -----------------------------------------------------------------------
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event TopUpRequested(address indexed user, uint256 requestId, uint256 amount);
    event TopUpApproved(
        address indexed user,
        uint256 indexed requestId,
        uint256 grossAmount,
        uint256 fee,
        uint256 netAmount
    );
    event TopUpRejected(address indexed user, uint256 indexed requestId, uint256 amount);
    event CardTopUp(address indexed user, uint256 netAmount, uint256 fee);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address oldOperator, address newOperator);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event CardActivated(address indexed user);

    // -----------------------------------------------------------------------
    //                            Constants
    // -----------------------------------------------------------------------
    uint256 public constant MAX_FEE_BPS = 10000; // 100% cap
    uint256 public constant MIN_DEPOSIT = 100 * 10**18; // minimum deposit for card activation
    uint256 public constant DEFAULT_FEE_BPS = 50; // 0.5% — applied to all top-ups

    // -----------------------------------------------------------------------
    //                            Immutables
    // -----------------------------------------------------------------------
    IERC20 public immutable stablecoin;

    // -----------------------------------------------------------------------
    //                            State Variables
    // -----------------------------------------------------------------------
    address public operator;

    uint256 public cardTopUpFeeBps; // current fee in basis points
    uint256 public totalOutstandingBalance; // total outstanding across all cards
    uint256 public feePool; // accumulated fees claimable by operator

    mapping(address => uint256) public userBalances; // available (unallocated) balance
    mapping(address => uint256) public cardBalances; // balance allocated to card
    mapping(address => bool) public cardActivated;

    mapping(uint256 => TopUpRequest) public topUpRequests;
    uint256 public nextTopUpId;

    // Reentrancy guard
    uint256 private _locked;

    // -----------------------------------------------------------------------
    //                             Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 0) revert ReentrantCall();
        _locked = 1;
        _;
        _locked = 0;
    }

    // -----------------------------------------------------------------------
    //                             Constructor
    // -----------------------------------------------------------------------
    /**
     * @param _stablecoin The ERC-20 stablecoin used for deposits.
     * @param _operator    The privileged operator address.
     */
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        cardTopUpFeeBps = DEFAULT_FEE_BPS;

        emit OperatorUpdated(address(0), _operator);
        emit FeeUpdated(0, DEFAULT_FEE_BPS);
    }

    // -----------------------------------------------------------------------
    //                       User-Facing Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit stablecoins into the gateway. A deposit of at least
     *         `MIN_DEPOSIT` activates the card for the caller.
     * @param amount The amount of stablecoins to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _safeTransferFrom(msg.sender, address(this), amount);
        userBalances[msg.sender] += amount;

        if (!cardActivated[msg.sender] && amount >= MIN_DEPOSIT) {
            cardActivated[msg.sender] = true;
            emit CardActivated(msg.sender);
        }

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw available (unallocated) stablecoins from the gateway.
     * @param amount The amount to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 available = userBalances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        userBalances[msg.sender] = available - amount;
        _safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Initiate a card top-up request. Funds are locked from the user's
     *         available balance until the operator approves or rejects the request.
     * @param amount The gross amount to top up (before fee deduction).
     * @return requestId The unique identifier for this top-up request.
     */
    function requestTopUp(uint256 amount) external nonReentrant returns (uint256 requestId) {
        if (!cardActivated[msg.sender]) revert CardNotActivated(msg.sender);
        if (amount == 0) revert ZeroAmount();

        uint256 available = userBalances[msg.sender];
        if (available < amount) revert InsufficientBalance(available, amount);

        // Lock the funds immediately to prevent double-spending between
        // request and approval.
        userBalances[msg.sender] = available - amount;

        requestId = nextTopUpId++;
        topUpRequests[requestId] = TopUpRequest({
            user: msg.sender,
            amount: amount,
            status: TopUpStatus.Pending
        });

        emit TopUpRequested(msg.sender, requestId, amount);
    }

    /**
     * @notice Cancel a pending top-up request and return locked funds.
     * @param requestId The ID of the top-up request to cancel.
     */
    function cancelTopUp(uint256 requestId) external nonReentrant {
        TopUpRequest storage req = topUpRequests[requestId];
        if (req.user != msg.sender) revert Unauthorized();
        if (req.status != TopUpStatus.Pending) revert InvalidRequestId(requestId);

        req.status = TopUpStatus.Rejected;
        userBalances[msg.sender] += req.amount;

        emit TopUpRejected(msg.sender, requestId, req.amount);
    }

    // -----------------------------------------------------------------------
    //                      Operator-Facing Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Approve a pending card top-up request. Deducts the configured fee
     *         and credits the net amount to the user's card balance.
     * @param requestId The ID of the top-up request to approve.
     */
    function approveTopUp(uint256 requestId) external onlyOperator nonReentrant {
        TopUpRequest storage req = topUpRequests[requestId];
        if (req.status != TopUpStatus.Pending) revert InvalidRequestId(requestId);

        uint256 gross = req.amount;
        uint256 fee = (gross * cardTopUpFeeBps) / MAX_FEE_BPS;
        uint256 net = gross - fee;

        cardBalances[req.user] += net;
        totalOutstandingBalance += net;
        feePool += fee;

        req.status = TopUpStatus.Approved;

        emit TopUpApproved(req.user, requestId, gross, fee, net);
        emit CardTopUp(req.user, net, fee);
    }

    /**
     * @notice Reject a pending card top-up request and return locked funds.
     * @param requestId The ID of the top-up request to reject.
     */
    function rejectTopUp(uint256 requestId) external onlyOperator nonReentrant {
        TopUpRequest storage req = topUpRequests[requestId];
        if (req.status != TopUpStatus.Pending) revert InvalidRequestId(requestId);

        req.status = TopUpStatus.Rejected;
        userBalances[req.user] += req.amount;

        emit TopUpRejected(req.user, requestId, req.amount);
    }

    /**
     * @notice Update the fee applied to card top-up transactions.
     * @param newFeeBps The new fee in basis points (e.g., 50 = 0.5%).
     */
    function updateFeeBps(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFeeBps(newFeeBps);

        uint256 old = cardTopUpFeeBps;
        cardTopUpFeeBps = newFeeBps;

        emit FeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Transfer the operator role to a new address.
     * @param newOperator The new operator address.
     */
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();

        address old = operator;
        operator = newOperator;

        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Withdraw accumulated fees from top-up transactions.
     * @param amount The amount of fees to withdraw.
     */
    function withdrawFees(uint256 amount) external onlyOperator nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (feePool < amount) revert InsufficientBalance(feePool, amount);

        feePool -= amount;
        _safeTransfer(msg.sender, amount);

        emit FeesWithdrawn(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    //                          View Functions
    // -----------------------------------------------------------------------

    function getAvailableBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }

    function getCardBalance(address user) external view returns (uint256) {
        return cardBalances[user];
    }

    function getTopUpRequest(uint256 requestId) external view returns (TopUpRequest memory) {
        return topUpRequests[requestId];
    }

    function isCardActivated(address user) external view returns (bool) {
        return cardActivated[user];
    }

    function totalDeposited() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    // -----------------------------------------------------------------------
    //                       Internal Transfer Helpers
    // -----------------------------------------------------------------------

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(stablecoin).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
