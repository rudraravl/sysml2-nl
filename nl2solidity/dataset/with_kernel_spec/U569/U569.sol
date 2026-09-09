// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address tokenOwner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20TransferFailed();

    function safeTransfer(IERC20 token_, address to, uint256 amount) internal {
        bool ok = token_.transfer(to, amount);
        if (!ok) revert SafeERC20TransferFailed();
    }
}

error NotOwner();
error NotOperator();
error NotOwnerOrOperator();
error TransfersPaused();
error TransfersNotPaused();
error ZeroAddress();
error FeeTooHigh(uint256 provided, uint256 maximum);
error InsufficientBalance(uint256 requested, uint256 available);
error AmountZero();
error InvalidProof();
error NullifierAlreadyUsed(bytes32 nullifier);
error TransferFromFailed();

contract PrivateTransferEscrow {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_FEE_BPS = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;

    event Deposit(address indexed user, uint256 grossAmount, uint256 fee, uint256 netAmount);
    event Withdrawal(address indexed user, uint256 amount);
    event PrivateTransferInitiated(
        address indexed from,
        bytes32 indexed nullifier,
        bytes32 proofHash,
        uint256 amount,
        uint256 blockNumber
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    IERC20 public immutable token;
    address public owner;

    uint256 public depositFeeBps;
    address public operator;
    bool public transfersPaused;

    mapping(address => uint256) public balances;
    uint256 public totalDeposits;

    mapping(bytes32 => bool) public nullifierUsed;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner && msg.sender != operator) revert NotOwnerOrOperator();
        _;
    }

    modifier whenNotPaused() {
        if (transfersPaused) revert TransfersPaused();
        _;
    }

    constructor(address tokenAddress, uint256 initialFeeBps, address initialOperator) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (initialOperator == address(0)) revert ZeroAddress();
        if (initialFeeBps > MAX_FEE_BPS) revert FeeTooHigh(initialFeeBps, MAX_FEE_BPS);

        token = IERC20(tokenAddress);
        owner = msg.sender;
        depositFeeBps = initialFeeBps;
        operator = initialOperator;

        emit FeeUpdated(0, initialFeeBps);
        emit OperatorUpdated(address(0), initialOperator);
    }

    function setDepositFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        uint256 old = depositFeeBps;
        depositFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    function pauseTransfers() external onlyOwnerOrOperator {
        if (transfersPaused) revert TransfersPaused();
        transfersPaused = true;
        emit Paused(msg.sender);
    }

    function unpauseTransfers() external onlyOwnerOrOperator {
        if (!transfersPaused) revert TransfersNotPaused();
        transfersPaused = false;
        emit Unpaused(msg.sender);
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (amount == 0) revert AmountZero();

        uint256 fee = (amount * depositFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Effects: update internal accounting before external interaction
        balances[msg.sender] += netAmount;
        totalDeposits += netAmount;

        // Interactions: transferFrom only from msg.sender — never an arbitrary from
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFromFailed();

        emit Deposit(msg.sender, amount, fee, netAmount);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        if (amount == 0) revert AmountZero();
        if (balances[msg.sender] < amount) revert InsufficientBalance(amount, balances[msg.sender]);

        // Effects: debit before external interaction
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        // Interactions
        token.safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    function initiatePrivateTransfer(
        uint256 amount,
        bytes32 nullifier,
        bytes32 proofHash,
        bytes calldata proof
    ) external whenNotPaused {
        if (amount == 0) revert AmountZero();
        if (balances[msg.sender] < amount) revert InsufficientBalance(amount, balances[msg.sender]);
        if (nullifier == bytes32(0)) revert InvalidProof();
        if (proofHash == bytes32(0)) revert InvalidProof();
        if (proof.length == 0) revert InvalidProof();
        if (nullifierUsed[nullifier]) revert NullifierAlreadyUsed(nullifier);

        if (!_verifyProof(proof, proofHash, nullifier, amount)) revert InvalidProof();

        // Effects
        nullifierUsed[nullifier] = true;
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        emit PrivateTransferInitiated(msg.sender, nullifier, proofHash, amount, block.number);
    }

    function _verifyProof(
        bytes calldata proof,
        bytes32 proofHash,
        bytes32 nullifier,
        uint256 amount
    ) internal pure returns (bool) {
        bytes32 computed = keccak256(abi.encodePacked(proof, nullifier, amount));
        return computed == proofHash;
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
}
