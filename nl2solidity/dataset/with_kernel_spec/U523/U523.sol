// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[4] memory input
    ) external view returns (bool);
}

/**
 * @title PrivateTransfer
 * @notice Facilitates private transfers of a designated base ERC-20 token using
 *         a Merkle tree of deposit commitments and zero-knowledge proofs for
 *         withdrawals. Deposit and withdrawal fees are configurable by the owner.
 */
contract PrivateTransfer {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    IERC20 public immutable baseToken;
    IVerifier public verifier;
    address public owner;

    uint256 public depositFeeBps;
    uint256 public withdrawalFeeBps;

    uint32 public immutable levels;
    uint32 public nextIndex;
    bytes32 public currentRoot;

    mapping(uint256 => bytes32) public filledSubtrees;
    bytes32[] public zeros;
    mapping(bytes32 => bool) public knownRoots;

    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullifierSpent;

    event Deposit(bytes32 indexed commitment, uint256 amount, uint32 leafIndex);
    event Withdrawal(bytes32 indexed nullifier, address indexed recipient, uint256 amount);
    event DepositFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event VerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RootUpdated(bytes32 newRoot);

    error Unauthorized();
    error ZeroAddress();
    error InvalidAmount();
    error CommitmentAlreadyUsed();
    error NullifierAlreadySpent();
    error InvalidRoot();
    error InvalidProof();
    error TreeFull();
    error FeeTooHigh();
    error TransferFailed();
    error ReentrantCall();
    error InvalidLevels();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(
        address _baseToken,
        address _verifier,
        uint32 _levels,
        address _owner
    ) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_verifier == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        if (_levels == 0 || _levels > 32) revert InvalidLevels();

        baseToken = IERC20(_baseToken);
        verifier = IVerifier(_verifier);
        owner = _owner;

        depositFeeBps = 10;
        withdrawalFeeBps = 20;

        levels = _levels;
        zeros = new bytes32[](_levels);

        bytes32 currentZero = bytes32(0);
        for (uint32 i = 0; i < _levels; i++) {
            zeros[i] = currentZero;
            currentZero = hashLeftRight(currentZero, currentZero);
        }
        currentRoot = currentZero;
        knownRoots[currentRoot] = true;

        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), _owner);
        emit VerifierUpdated(address(0), _verifier);
        emit RootUpdated(currentRoot);
    }

    function hashLeftRight(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encode(left, right));
    }

    function _insert(bytes32 leaf) internal returns (uint32 index) {
        uint32 _nextIndex = nextIndex;
        if (_nextIndex >= uint32(2) ** levels) revert TreeFull();

        index = _nextIndex;
        bytes32 current = leaf;
        uint32 currentIndex = _nextIndex;

        for (uint32 i = 0; i < levels; i++) {
            if (currentIndex & 1 == 0) {
                filledSubtrees[i] = current;
                current = hashLeftRight(current, zeros[i]);
            } else {
                current = hashLeftRight(filledSubtrees[i], current);
            }
            currentIndex >>= 1;
        }

        nextIndex = _nextIndex + 1;
        currentRoot = current;
        knownRoots[current] = true;
        emit RootUpdated(current);
    }

    function deposit(bytes32 commitment, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (commitments[commitment]) revert CommitmentAlreadyUsed();

        uint256 fee = (amount * depositFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;
        if (netAmount == 0) revert InvalidAmount();

        // Effects: update state before external interactions
        commitments[commitment] = true;
        uint32 leafIndex = _insert(commitment);

        // Interactions: pull tokens from depositor
        bool ok = baseToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposit(commitment, netAmount, leafIndex);
    }

    function withdraw(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[4] memory input
    ) external nonReentrant {
        bytes32 root = bytes32(input[0]);
        bytes32 nullifier = bytes32(input[1]);
        address recipient = address(uint160(input[2]));
        uint256 amount = input[3];

        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert ZeroAddress();
        if (nullifierSpent[nullifier]) revert NullifierAlreadySpent();
        if (!knownRoots[root]) revert InvalidRoot();

        if (!verifier.verifyProof(a, b, c, input)) revert InvalidProof();

        // Effects: mark nullifier spent before transfer
        nullifierSpent[nullifier] = true;

        uint256 fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;
        if (netAmount == 0) revert InvalidAmount();

        // Interactions: send tokens to recipient
        bool ok = baseToken.transfer(recipient, netAmount);
        if (!ok) revert TransferFailed();

        emit Withdrawal(nullifier, recipient, netAmount);
    }

    function setDepositFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = depositFeeBps;
        depositFeeBps = newFeeBps;
        emit DepositFeeUpdated(old, newFeeBps);
    }

    function setWithdrawalFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(old, newFeeBps);
    }

    function setVerifier(address newVerifier) external onlyOwner {
        if (newVerifier == address(0)) revert ZeroAddress();
        address old = address(verifier);
        verifier = IVerifier(newVerifier);
        emit VerifierUpdated(old, newVerifier);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function isKnownRoot(bytes32 root) external view returns (bool) {
        return knownRoots[root];
    }

    function zeroAt(uint32 level) external view returns (bytes32) {
        return zeros[level];
    }

    function filledSubtreeAt(uint32 level) external view returns (bytes32) {
        return filledSubtrees[level];
    }
}
