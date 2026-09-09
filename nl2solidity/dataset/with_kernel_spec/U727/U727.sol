// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory input
    ) external view returns (bool);
}

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

contract ConfidentialMixer is ReentrancyGuard {
    // --- Errors ---
    error Unauthorized();
    error InvalidDepositAmount();
    error InvalidFee();
    error FeeTooHigh();
    error InvalidRoot();
    error CommitmentAlreadyUsed();
    error NullifierAlreadySpent();
    error InvalidProof();
    error TransferFailed();
    error ZeroAddress();

    // --- Events ---
    event Deposit(
        bytes32 indexed commitment,
        uint256 amount,
        bytes32 depositRoot
    );
    event Withdrawal(
        address indexed recipient,
        bytes32 indexed nullifier,
        uint256 amount,
        bytes32 nullifierRoot
    );
    event DepositFeeUpdated(uint256 newFeeBps);
    event DepositRootUpdated(bytes32 newRoot);
    event NullifierRootUpdated(bytes32 newRoot);
    event OperatorUpdated(address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // --- Constants ---
    uint256 public constant DENOMINATION = 1 ether;
    uint256 public constant MAX_FEE_BPS = 500; // 5% in basis points

    // --- State Variables ---
    IVerifier public immutable verifier;
    address public owner;
    address public operator;

    bytes32 public depositRoot;
    bytes32 public nullifierRoot;

    uint256 public depositFeeBps; // in basis points (e.g., 100 = 1%)
    uint256 public accumulatedFees;

    mapping(bytes32 => bool) public usedCommitments;
    mapping(bytes32 => bool) public spentNullifiers;

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    // --- Constructor ---
    constructor(
        address _verifier,
        bytes32 _initialDepositRoot,
        bytes32 _initialNullifierRoot,
        uint256 _initialFeeBps
    ) {
        if (_verifier == address(0)) revert ZeroAddress();
        if (_initialFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        verifier = IVerifier(_verifier);
        owner = msg.sender;
        operator = msg.sender;
        depositRoot = _initialDepositRoot;
        nullifierRoot = _initialNullifierRoot;
        depositFeeBps = _initialFeeBps;

        emit DepositFeeUpdated(_initialFeeBps);
        emit DepositRootUpdated(_initialDepositRoot);
        emit NullifierRootUpdated(_initialNullifierRoot);
    }

    // --- Owner Functions ---

    /**
     * @notice Updates the deposit fee in basis points. Cannot exceed 5% (500 bps).
     * @param _newFeeBps New fee in basis points.
     */
    function updateDepositFee(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        depositFeeBps = _newFeeBps;
        emit DepositFeeUpdated(_newFeeBps);
    }

    /**
     * @notice Sets a new operator address.
     * @param _newOperator Address of the new operator.
     */
    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert ZeroAddress();
        operator = _newOperator;
        emit OperatorUpdated(_newOperator);
    }

    /**
     * @notice Allows the owner to withdraw accumulated fees.
     * @param _to Address to receive the fees.
     */
    function withdrawFees(address payable _to) external onlyOwner nonReentrant {
        if (_to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert InvalidFee();

        accumulatedFees = 0;
        (bool success, ) = _to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(_to, amount);
    }

    /**
     * @notice Allows the owner to transfer ownership.
     * @param _newOwner Address of the new owner.
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        owner = _newOwner;
    }

    // --- Operator Functions ---

    /**
     * @notice Updates the Merkle root of the deposit commitment tree.
     * @param _newDepositRoot New root of the deposit commitment tree.
     */
    function updateDepositRoot(bytes32 _newDepositRoot) external onlyOperator {
        depositRoot = _newDepositRoot;
        emit DepositRootUpdated(_newDepositRoot);
    }

    /**
     * @notice Updates the Merkle root of the nullifier tree.
     * @param _newNullifierRoot New root of the nullifier tree.
     */
    function updateNullifierRoot(bytes32 _newNullifierRoot) external onlyOperator {
        nullifierRoot = _newNullifierRoot;
        emit NullifierRootUpdated(_newNullifierRoot);
    }

    /**
     * @notice Updates both Merkle roots atomically.
     * @param _newDepositRoot New root of the deposit commitment tree.
     * @param _newNullifierRoot New root of the nullifier tree.
     */
    function updateRoots(
        bytes32 _newDepositRoot,
        bytes32 _newNullifierRoot
    ) external onlyOperator {
        depositRoot = _newDepositRoot;
        nullifierRoot = _newNullifierRoot;
        emit DepositRootUpdated(_newDepositRoot);
        emit NullifierRootUpdated(_newNullifierRoot);
    }

    // --- Public Functions ---

    /**
     * @notice Deposits exactly 1 unit of native currency with a zero-knowledge
     *         proof of a valid commitment.
     * @param _commitment The deposit commitment (hash of secret + nullifier).
     * @param _a Proof parameter a.
     * @param _b Proof parameter b.
     * @param _c Proof parameter c.
     * @param _inputs Public inputs: [commitment, depositRoot].
     */
    function deposit(
        bytes32 _commitment,
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[] memory _inputs
    ) external payable nonReentrant {
        if (msg.value != DENOMINATION) revert InvalidDepositAmount();
        if (usedCommitments[_commitment]) revert CommitmentAlreadyUsed();

        // Validate public inputs reference the current deposit root.
        if (_inputs.length < 2) revert InvalidProof();
        bytes32 proofCommitment = bytes32(_inputs[0]);
        bytes32 proofRoot = bytes32(_inputs[1]);

        if (proofCommitment != _commitment) revert InvalidProof();
        if (proofRoot != depositRoot) revert InvalidRoot();

        // Verify the zero-knowledge proof.
        if (!verifier.verifyProof(_a, _b, _c, _inputs)) revert InvalidProof();

        // Effects: mark commitment as used.
        usedCommitments[_commitment] = true;

        emit Deposit(_commitment, DENOMINATION, depositRoot);
    }

    /**
     * @notice Withdraws native currency to a specified recipient using a
     *         zero-knowledge proof of a valid nullifier and commitment.
     * @param _recipient Address to receive the withdrawn funds (minus fee).
     * @param _nullifier The nullifier preventing double-spending.
     * @param _a Proof parameter a.
     * @param _b Proof parameter b.
     * @param _c Proof parameter c.
     * @param _inputs Public inputs: [nullifier, commitment, depositRoot, nullifierRoot, feeBps].
     */
    function withdraw(
        address payable _recipient,
        bytes32 _nullifier,
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[] memory _inputs
    ) external nonReentrant {
        if (_recipient == address(0)) revert ZeroAddress();
        if (spentNullifiers[_nullifier]) revert NullifierAlreadySpent();

        // Validate public inputs reference current roots and fee.
        if (_inputs.length < 5) revert InvalidProof();
        bytes32 proofNullifier = bytes32(_inputs[0]);
        bytes32 proofDepositRoot = bytes32(_inputs[2]);
        bytes32 proofNullifierRoot = bytes32(_inputs[3]);
        uint256 proofFeeBps = _inputs[4];

        if (proofNullifier != _nullifier) revert InvalidProof();
        if (proofDepositRoot != depositRoot) revert InvalidRoot();
        if (proofNullifierRoot != nullifierRoot) revert InvalidRoot();
        if (proofFeeBps != depositFeeBps) revert InvalidFee();

        // Verify the zero-knowledge proof.
        if (!verifier.verifyProof(_a, _b, _c, _inputs)) revert InvalidProof();

        // Effects: mark nullifier as spent and accumulate fees.
        spentNullifiers[_nullifier] = true;

        uint256 feeAmount = (DENOMINATION * depositFeeBps) / 10000;
        uint256 withdrawAmount = DENOMINATION - feeAmount;

        accumulatedFees += feeAmount;

        // Interactions: transfer funds to recipient.
        (bool success, ) = _recipient.call{value: withdrawAmount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(_recipient, _nullifier, withdrawAmount, nullifierRoot);
    }

    // --- View Functions ---

    /**
     * @notice Returns the current accumulated fees held by the contract.
     */
    function getAccumulatedFees() external view returns (uint256) {
        return accumulatedFees;
    }

    /**
     * @notice Returns the total native currency balance of the contract.
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // --- Fallback ---
    receive() external payable {
        revert("Use deposit function");
    }
}
