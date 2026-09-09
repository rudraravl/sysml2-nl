// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token_, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token_, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    modifier whenPaused() {
        if (!_paused) revert ExpectedPause();
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
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

contract TokenBridge is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public relayer;

    uint256 public constant MAX_DEPOSIT = 100_000 * 10**18;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public withdrawalFeeBps = 5; // 0.05%

    uint256 private _nonce;

    enum MessageStatus {
        NonExistent,
        Pending,
        Finalized,
        Claimed
    }

    struct PendingWithdrawal {
        address recipient;
        uint256 amount;
    }

    mapping(address => uint256) public l2Balances;
    mapping(bytes32 => MessageStatus) public messageStatus;
    mapping(bytes32 => PendingWithdrawal) public pendingWithdrawals;

    uint256 public accumulatedFees;

    event Deposited(address indexed user, uint256 amount);
    event WithdrawInitiated(address indexed user, uint256 amount, bytes32 indexed messageId);
    event WithdrawFinalized(bytes32 indexed messageId);
    event WithdrawClaimed(address indexed user, uint256 amount, uint256 fee);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event RelayerUpdated(address newRelayer);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error ZeroAmount();
    error ZeroAddress();
    error ExceedsMaxDeposit();
    error InsufficientL2Balance();
    error MessageNotPending();
    error MessageNotFinalized();
    error InvalidProof();
    error NotRelayer();
    error Unauthorized();
    error InvalidFeeBps();

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert NotRelayer();
        _;
    }

    constructor(address _token, address _relayer) Ownable(msg.sender) {
        if (_token == address(0) || _relayer == address(0)) revert ZeroAddress();
        token = IERC20(_token);
        relayer = _relayer;
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount >= MAX_DEPOSIT) revert ExceedsMaxDeposit();

        token.safeTransferFrom(msg.sender, address(this), amount);
        l2Balances[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    function initiateWithdrawal(uint256 amount) external nonReentrant returns (bytes32 messageId) {
        if (amount == 0) revert ZeroAmount();
        if (l2Balances[msg.sender] < amount) revert InsufficientL2Balance();

        l2Balances[msg.sender] -= amount;
        messageId = keccak256(abi.encodePacked(msg.sender, amount, _nonce, block.chainid));
        _nonce++;

        pendingWithdrawals[messageId] = PendingWithdrawal({
            recipient: msg.sender,
            amount: amount
        });
        messageStatus[messageId] = MessageStatus.Pending;

        emit WithdrawInitiated(msg.sender, amount, messageId);
    }

    function finalizeWithdrawal(bytes32 messageId, bytes calldata proof) external onlyRelayer nonReentrant {
        if (messageStatus[messageId] != MessageStatus.Pending) revert MessageNotPending();
        if (proof.length == 0) revert InvalidProof();

        messageStatus[messageId] = MessageStatus.Finalized;

        emit WithdrawFinalized(messageId);
    }

    function claim(bytes32 messageId) external nonReentrant {
        if (messageStatus[messageId] != MessageStatus.Finalized) revert MessageNotFinalized();

        PendingWithdrawal memory withdrawal = pendingWithdrawals[messageId];
        if (msg.sender != withdrawal.recipient) revert Unauthorized();

        messageStatus[messageId] = MessageStatus.Claimed;
        delete pendingWithdrawals[messageId];

        uint256 fee = (withdrawal.amount * withdrawalFeeBps) / FEE_DENOMINATOR;
        uint256 amountToSend = withdrawal.amount - fee;

        if (fee > 0) {
            accumulatedFees += fee;
        }

        token.safeTransfer(msg.sender, amountToSend);

        emit WithdrawClaimed(msg.sender, amountToSend, fee);
    }

    function setWithdrawalFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > 10000) revert InvalidFeeBps();
        emit WithdrawalFeeUpdated(withdrawalFeeBps, _feeBps);
        withdrawalFeeBps = _feeBps;
    }

    function pauseDeposits() external onlyOwner {
        _pause();
    }

    function unpauseDeposits() external onlyOwner {
        _unpause();
    }

    function setRelayer(address _relayer) external onlyOwner {
        if (_relayer == address(0)) revert ZeroAddress();
        relayer = _relayer;
        emit RelayerUpdated(_relayer);
    }

    function withdrawFees(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (accumulatedFees == 0) revert ZeroAmount();

        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        token.safeTransfer(to, amount);

        emit FeesWithdrawn(to, amount);
    }
}
