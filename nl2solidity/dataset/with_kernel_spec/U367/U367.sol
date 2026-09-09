// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).code.length > 0, "SafeERC20: call to non-contract");
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        address oldOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata input
    ) external view returns (bool);
}

contract AnonymousTokenTransfer is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant INITIAL_WITHDRAWAL_FEE_PERCENT = 100; // 1%
    uint256 public constant MAX_WITHDRAWAL_FEE_PERCENT = 1_000; // 10%

    IERC20 public immutable token;
    IVerifier public immutable verifier;
    uint256 public immutable maxDepositAmount;

    address public feeRecipient;
    uint256 public withdrawalFeePercent;

    bool public depositsPaused;
    bool public withdrawalsPaused;

    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullifiers;

    event Deposit(address indexed sender, uint256 amount, bytes32 indexed commitment);
    event Withdrawal(address indexed recipient, uint256 amount, bytes32 indexed nullifierHash, uint256 fee);
    event WithdrawalFeePercentUpdated(uint256 oldFeePercent, uint256 newFeePercent);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event DepositsPausedStateChanged(bool paused);
    event WithdrawalsPausedStateChanged(bool paused);

    error ZeroAddress();
    error ZeroAmount();
    error ExceedsMaxDepositAmount(uint256 amount, uint256 max);
    error CommitmentAlreadyUsed(bytes32 commitment);
    error NullifierAlreadySpent(bytes32 nullifierHash);
    error InvalidProof();
    error WithdrawalFeeTooHigh(uint256 feePercent, uint256 maxFeePercent);
    error DepositsArePaused();
    error WithdrawalsArePaused();

    modifier whenDepositsNotPaused() {
        if (depositsPaused) revert DepositsArePaused();
        _;
    }

    modifier whenWithdrawalsNotPaused() {
        if (withdrawalsPaused) revert WithdrawalsArePaused();
        _;
    }

    constructor(
        address _token,
        address _verifier,
        address _feeRecipient,
        uint256 _maxDepositAmount
    ) Ownable(msg.sender) {
        if (_token == address(0) || _verifier == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }
        if (_maxDepositAmount == 0) revert ZeroAmount();
        token = IERC20(_token);
        verifier = IVerifier(_verifier);
        feeRecipient = _feeRecipient;
        maxDepositAmount = _maxDepositAmount;
        withdrawalFeePercent = INITIAL_WITHDRAWAL_FEE_PERCENT;
    }

    function deposit(uint256 amount, bytes32 commitment) external whenDepositsNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > maxDepositAmount) revert ExceedsMaxDepositAmount(amount, maxDepositAmount);
        if (commitments[commitment]) revert CommitmentAlreadyUsed(commitment);

        commitments[commitment] = true;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, commitment);
    }

    function withdraw(
        uint256 amount,
        bytes32 nullifierHash,
        address recipient,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c
    ) external whenWithdrawalsNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > maxDepositAmount) revert ExceedsMaxDepositAmount(amount, maxDepositAmount);
        if (recipient == address(0)) revert ZeroAddress();
        if (nullifierHash == bytes32(0) || nullifiers[nullifierHash]) {
            revert NullifierAlreadySpent(nullifierHash);
        }

        uint256[3] memory input;
        input[0] = uint256(nullifierHash);
        input[1] = amount;
        input[2] = uint256(uint160(recipient));

        if (!verifier.verifyProof(a, b, c, input)) revert InvalidProof();

        nullifiers[nullifierHash] = true;

        uint256 fee = (amount * withdrawalFeePercent) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        token.safeTransfer(recipient, netAmount);
        if (fee > 0) {
            token.safeTransfer(feeRecipient, fee);
        }

        emit Withdrawal(recipient, amount, nullifierHash, fee);
    }

    function setWithdrawalFeePercent(uint256 newFeePercent) external onlyOwner {
        if (newFeePercent > MAX_WITHDRAWAL_FEE_PERCENT) {
            revert WithdrawalFeeTooHigh(newFeePercent, MAX_WITHDRAWAL_FEE_PERCENT);
        }
        uint256 old = withdrawalFeePercent;
        withdrawalFeePercent = newFeePercent;
        emit WithdrawalFeePercentUpdated(old, newFeePercent);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(old, newFeeRecipient);
    }

    function setDepositsPaused(bool paused) external onlyOwner {
        depositsPaused = paused;
        emit DepositsPausedStateChanged(paused);
    }

    function setWithdrawalsPaused(bool paused) external onlyOwner {
        withdrawalsPaused = paused;
        emit WithdrawalsPausedStateChanged(paused);
    }
}
