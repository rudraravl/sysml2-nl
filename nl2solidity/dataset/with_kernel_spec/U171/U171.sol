// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenBridgeEscrow {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposited(address indexed user, uint256 amount);
    event WithdrawalInitiated(
        address indexed user,
        uint256 indexed requestId,
        uint256 amount,
        uint256 indexed destinationChainId
    );
    event WithdrawalApproved(
        address indexed user,
        uint256 indexed requestId,
        uint256 amount,
        uint256 indexed destinationChainId
    );
    event WithdrawalClaimed(
        address indexed user,
        uint256 indexed requestId,
        uint256 amount,
        uint256 fee,
        uint256 indexed destinationChainId
    );
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event BridgeFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error ZeroAmount();
    error NotOwner();
    error NotOperator();
    error InsufficientDepositedBalance();
    error RequestNotFound();
    error RequestExpired();
    error AlreadyApproved();
    error NotApproved();
    error AlreadyClaimed();
    error NotRequester();
    error InvalidFeeBps();
    error TransferFailed();
    error AlreadyOperator();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant APPROVAL_WINDOW = 24 hours;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10000;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public owner;
    IERC20 public immutable token;

    uint256 public bridgeFeeBps = 10;
    uint256 public accumulatedFees;

    mapping(address => bool) public isOperator;
    mapping(address => uint256) public depositedBalance;

    struct WithdrawalRequest {
        address user;
        uint256 amount;
        uint256 destinationChainId;
        uint256 initiatedAt;
        bool approved;
        bool claimed;
    }

    uint256 public nextRequestId;
    mapping(uint256 => WithdrawalRequest) public requests;
    mapping(address => uint256[]) public userRequestIds;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _token, address[] memory _operators) {
        if (_token == address(0)) revert ZeroAddress();
        token = IERC20(_token);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        for (uint256 i = 0; i < _operators.length; i++) {
            address op = _operators[i];
            if (op == address(0)) revert ZeroAddress();
            if (isOperator[op]) revert AlreadyOperator();
            isOperator[op] = true;
            emit OperatorAdded(op);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE TRANSFER
    //////////////////////////////////////////////////////////////*/
    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory returnData) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (returnData.length > 0 && !abi.decode(returnData, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory returnData) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (returnData.length > 0 && !abi.decode(returnData, (bool)))) {
            revert TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                              DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        _safeTransferFrom(msg.sender, address(this), amount);

        depositedBalance[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function initiateWithdrawal(uint256 amount, uint256 destinationChainId)
        external
        returns (uint256 requestId)
    {
        if (amount == 0) revert ZeroAmount();
        if (depositedBalance[msg.sender] < amount) revert InsufficientDepositedBalance();

        depositedBalance[msg.sender] -= amount;

        requestId = nextRequestId++;
        requests[requestId] = WithdrawalRequest({
            user: msg.sender,
            amount: amount,
            destinationChainId: destinationChainId,
            initiatedAt: block.timestamp,
            approved: false,
            claimed: false
        });
        userRequestIds[msg.sender].push(requestId);

        emit WithdrawalInitiated(msg.sender, requestId, amount, destinationChainId);
    }

    function approveWithdrawal(uint256 requestId) external onlyOperator {
        WithdrawalRequest storage req = requests[requestId];
        if (req.user == address(0)) revert RequestNotFound();
        if (req.approved) revert AlreadyApproved();
        if (req.claimed) revert AlreadyClaimed();
        if (block.timestamp > req.initiatedAt + APPROVAL_WINDOW) revert RequestExpired();

        req.approved = true;

        emit WithdrawalApproved(req.user, requestId, req.amount, req.destinationChainId);
    }

    function claim(uint256 requestId) external {
        WithdrawalRequest storage req = requests[requestId];
        if (req.user == address(0)) revert RequestNotFound();
        if (msg.sender != req.user) revert NotRequester();
        if (!req.approved) revert NotApproved();
        if (req.claimed) revert AlreadyClaimed();

        req.claimed = true;

        uint256 fee = (req.amount * bridgeFeeBps) / BPS_DENOMINATOR;
        uint256 payout = req.amount - fee;
        accumulatedFees += fee;

        _safeTransfer(msg.sender, payout);

        emit WithdrawalClaimed(msg.sender, requestId, payout, fee, req.destinationChainId);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function addOperator(address operator) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        if (isOperator[operator]) revert AlreadyOperator();
        isOperator[operator] = true;
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        if (!isOperator[operator]) revert NotOperator();
        isOperator[operator] = false;
        emit OperatorRemoved(operator);
    }

    /*//////////////////////////////////////////////////////////////
                             FEE CONFIG
    //////////////////////////////////////////////////////////////*/
    function setBridgeFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        uint256 old = bridgeFeeBps;
        bridgeFeeBps = newFeeBps;
        emit BridgeFeeUpdated(old, newFeeBps);
    }

    function withdrawFees(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        _safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          OWNERSHIP
    //////////////////////////////////////////////////////////////*/
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    function getRequest(uint256 requestId) external view returns (WithdrawalRequest memory) {
        return requests[requestId];
    }

    function getUserRequests(address user) external view returns (uint256[] memory) {
        return userRequestIds[user];
    }

    function getUserRequestCount(address user) external view returns (uint256) {
        return userRequestIds[user].length;
    }

    function isRequestExpired(uint256 requestId) external view returns (bool) {
        WithdrawalRequest storage req = requests[requestId];
        if (req.user == address(0)) return true;
        return block.timestamp > req.initiatedAt + APPROVAL_WINDOW;
    }
}
