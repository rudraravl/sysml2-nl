// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract PrivateMixer is ReentrancyGuard {
    error NotOwner();
    error ContractPaused();
    error InsufficientDeposit();
    error CommitmentAlreadyUsed();
    error NullifierAlreadySpent();
    error InvalidProof();
    error InsufficientBalance();
    error WithdrawalFailed();
    error FeeTransferFailed();
    error InvalidFee();
    error InvalidAddress();
    error ZeroAmount();

    address public owner;
    bool public paused;
    uint256 public feeBps; // basis points, 10 = 0.1%
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant MAX_FEE_BPS = 10000;

    mapping(bytes32 => bool) public nullifierSpent;
    mapping(bytes32 => bool) public commitments;
    bytes32[] public depositCommitments;

    event Deposit(address indexed sender, bytes32 indexed commitment, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed recipient, bytes32 indexed nullifier, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PausedStateChanged(bool isPaused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor() {
        owner = msg.sender;
        feeBps = 10; // 0.1%
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeUpdated(0, feeBps);
    }

    function deposit(bytes32 _commitment) external payable nonReentrant whenNotPaused {
        if (msg.value < MIN_DEPOSIT) revert InsufficientDeposit();
        if (commitments[_commitment]) revert CommitmentAlreadyUsed();

        commitments[_commitment] = true;
        depositCommitments.push(_commitment);

        emit Deposit(msg.sender, _commitment, msg.value, block.timestamp);
    }

    function withdraw(
        bytes32 _nullifier,
        bytes32 _root,
        uint256 _amount,
        bytes calldata _proof
    ) external nonReentrant whenNotPaused {
        if (_amount == 0) revert ZeroAmount();
        if (nullifierSpent[_nullifier]) revert NullifierAlreadySpent();
        if (!verifyProof(_nullifier, _root, _amount, _proof)) revert InvalidProof();

        nullifierSpent[_nullifier] = true;

        uint256 fee = (_amount * feeBps) / MAX_FEE_BPS;
        uint256 amountToTransfer = _amount - fee;

        if (address(this).balance < _amount) revert InsufficientBalance();

        if (fee > 0) {
            (bool feeSuccess, ) = owner.call{value: fee}("");
            if (!feeSuccess) revert FeeTransferFailed();
        }

        (bool success, ) = msg.sender.call{value: amountToTransfer}("");
        if (!success) revert WithdrawalFailed();

        emit Withdrawal(msg.sender, _nullifier, amountToTransfer, fee);
    }

    function verifyProof(
        bytes32 _nullifier,
        bytes32 _root,
        uint256 _amount,
        bytes calldata _proof
    ) internal pure returns (bool) {
        // Placeholder verification: accepts any non-empty proof.
        // In production this would verify a zero-knowledge proof against
        // the public inputs (nullifier, root, amount).
        if (_proof.length == 0) return false;
        if (_nullifier == bytes32(0)) return false;
        if (_root == bytes32(0)) return false;
        if (_amount == 0) return false;
        return true;
    }

    function setFee(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 oldFeeBps = feeBps;
        feeBps = _newFeeBps;
        emit FeeUpdated(oldFeeBps, _newFeeBps);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert InvalidAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function getDepositCount() external view returns (uint256) {
        return depositCommitments.length;
    }

    function getDepositCommitment(uint256 _index) external view returns (bytes32) {
        return depositCommitments[_index];
    }

    function isCommitmentUsed(bytes32 _commitment) external view returns (bool) {
        return commitments[_commitment];
    }

    function isNullifierSpent(bytes32 _nullifier) external view returns (bool) {
        return nullifierSpent[_nullifier];
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
