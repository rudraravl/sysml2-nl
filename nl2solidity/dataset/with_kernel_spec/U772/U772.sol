// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract WrappedExternalAssetBridge {
    // --- ERC20 Metadata ---
    string public name;
    string public symbol;
    uint8 public decimals;

    // --- ERC20 State ---
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- External Asset ---
    IERC20 public immutable underlyingToken;

    // --- Access Control ---
    address public operator;
    address public pendingOperator;

    // --- Pausable ---
    bool public paused;

    // --- Daily Mint Cap ---
    uint256 public dailyMintCap;
    uint256 public currentDay;
    uint256 public mintedToday;

    // --- Withdrawal Fee ---
    uint256 public constant WITHDRAWAL_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public accumulatedFees;

    // --- Withdrawal Requests ---
    enum RequestStatus {
        Pending,
        Approved,
        Executed,
        Cancelled
    }

    struct WithdrawalRequest {
        address requester;
        uint256 grossAmount;
        uint256 fee;
        uint256 netAmount;
        RequestStatus status;
        uint256 createdAt;
    }

    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    uint256 public withdrawalRequestCount;

    // --- Events ---
    event Deposit(address indexed sender, address indexed recipient, uint256 amount);
    event Withdrawal(address indexed sender, address indexed recipient, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event WithdrawalRequested(uint256 indexed requestId, address indexed requester, uint256 grossAmount);
    event WithdrawalApproved(uint256 indexed requestId);
    event WithdrawalExecuted(uint256 indexed requestId, address indexed requester, uint256 netAmount, uint256 fee);
    event WithdrawalCancelled(uint256 indexed requestId);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event OperatorChangeProposed(address indexed currentOperator, address indexed proposedOperator);
    event PausedStateChanged(bool paused);
    event DailyMintCapUpdated(uint256 newCap);
    event FeesCollected(address indexed collector, uint256 amount);

    // --- Errors ---
    error NotOperator();
    error ContractPaused();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DailyMintCapExceeded(uint256 attempted, uint256 remaining);
    error RequestNotFound();
    error NotPending();
    error NotApproved();
    error AlreadyExecuted();
    error NotPendingOperator();
    error UnderlyingTransferFailed();
    error InvalidDecimals();

    // --- Modifiers ---
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // --- Constructor ---
    constructor(
        address _underlyingToken,
        string memory _name,
        string memory _symbol,
        uint256 _decimals
    ) {
        if (_underlyingToken == address(0)) revert ZeroAddress();
        if (_decimals > type(uint8).max) revert InvalidDecimals();
        underlyingToken = IERC20(_underlyingToken);
        name = _name;
        symbol = _symbol;
        decimals = uint8(_decimals);
        dailyMintCap = 100_000 * 10 ** _decimals;
        operator = msg.sender;
        currentDay = block.timestamp / 1 days;
        emit OperatorChanged(address(0), msg.sender);
    }

    // --- Internal Helpers ---
    function _currentDay() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function _refreshDailyMintWindow() internal {
        uint256 day = _currentDay();
        if (day != currentDay) {
            currentDay = day;
            mintedToday = 0;
        }
    }

    function _mint(address to, uint256 amount) internal {
        _refreshDailyMintWindow();
        uint256 remaining = dailyMintCap > mintedToday ? dailyMintCap - mintedToday : 0;
        if (amount > remaining) revert DailyMintCapExceeded(amount, remaining);
        totalSupply += amount;
        balanceOf[to] += amount;
        mintedToday += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    // --- ERC20 Functions ---
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
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

    // --- Deposit Functions ---
    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        bool ok = underlyingToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert UnderlyingTransferFailed();
        _mint(msg.sender, amount);
        emit Deposit(msg.sender, msg.sender, amount);
    }

    function depositTo(uint256 amount, address recipient) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        bool ok = underlyingToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert UnderlyingTransferFailed();
        _mint(recipient, amount);
        emit Deposit(msg.sender, recipient, amount);
    }

    // --- Withdrawal Functions ---
    function requestWithdrawal(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;
        uint256 requestId = withdrawalRequestCount;
        withdrawalRequests[requestId] = WithdrawalRequest({
            requester: msg.sender,
            grossAmount: amount,
            fee: fee,
            netAmount: netAmount,
            status: RequestStatus.Pending,
            createdAt: block.timestamp
        });
        withdrawalRequestCount++;
        emit WithdrawalRequested(requestId, msg.sender, amount);
    }

    function approveWithdrawal(uint256 requestId) external onlyOperator {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requester == address(0)) revert RequestNotFound();
        if (req.status != RequestStatus.Pending) revert NotPending();
        req.status = RequestStatus.Approved;
        emit WithdrawalApproved(requestId);
    }

    function executeWithdrawal(uint256 requestId) external onlyOperator {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requester == address(0)) revert RequestNotFound();
        if (req.status != RequestStatus.Approved) revert NotApproved();
        req.status = RequestStatus.Executed;
        accumulatedFees += req.fee;
        bool ok = underlyingToken.transfer(req.requester, req.netAmount);
        if (!ok) revert UnderlyingTransferFailed();
        emit Withdrawal(req.requester, req.requester, req.netAmount);
        emit WithdrawalExecuted(requestId, req.requester, req.netAmount, req.fee);
    }

    function cancelWithdrawal(uint256 requestId) external onlyOperator {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        if (req.requester == address(0)) revert RequestNotFound();
        if (req.status == RequestStatus.Executed || req.status == RequestStatus.Cancelled) revert AlreadyExecuted();
        req.status = RequestStatus.Cancelled;
        totalSupply += req.grossAmount;
        balanceOf[req.requester] += req.grossAmount;
        emit Transfer(address(0), req.requester, req.grossAmount);
        emit WithdrawalCancelled(requestId);
    }

    // --- Operator Administration ---
    function pause() external onlyOperator {
        paused = true;
        emit PausedStateChanged(true);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit PausedStateChanged(false);
    }

    function setDailyMintCap(uint256 newCap) external onlyOperator {
        dailyMintCap = newCap;
        emit DailyMintCapUpdated(newCap);
    }

    function proposeOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        pendingOperator = newOperator;
        emit OperatorChangeProposed(operator, newOperator);
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert NotPendingOperator();
        address previous = operator;
        operator = pendingOperator;
        pendingOperator = address(0);
        emit OperatorChanged(previous, operator);
    }

    function collectFees(address recipient) external onlyOperator {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        bool ok = underlyingToken.transfer(recipient, amount);
        if (!ok) revert UnderlyingTransferFailed();
        emit FeesCollected(recipient, amount);
    }

    // --- View Functions ---
    function getWithdrawalRequest(uint256 requestId)
        external
        view
        returns (
            address requester,
            uint256 grossAmount,
            uint256 fee,
            uint256 netAmount,
            RequestStatus status,
            uint256 createdAt
        )
    {
        WithdrawalRequest storage req = withdrawalRequests[requestId];
        return (req.requester, req.grossAmount, req.fee, req.netAmount, req.status, req.createdAt);
    }

    function remainingDailyMint() external view returns (uint256) {
        uint256 day = _currentDay();
        if (day != currentDay) return dailyMintCap;
        return dailyMintCap > mintedToday ? dailyMintCap - mintedToday : 0;
    }

    function underlyingBalance() external view returns (uint256) {
        return underlyingToken.balanceOf(address(this));
    }
}
