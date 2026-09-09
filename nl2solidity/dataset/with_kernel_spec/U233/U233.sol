// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IHasher {
    function hash(uint256 left, uint256 right) external pure returns (uint256);
}

interface IVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata input
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

contract PrivateTokenTransfer is ReentrancyGuard {
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE_BPS = 10;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant WITHDRAWAL_DELAY = 10 minutes;
    uint256 public constant MAX_BATCH_SIZE = 256;
    uint256 public constant MAX_TREE_LEVELS = 32;

    IERC20 public immutable token;
    IHasher public immutable hasher;
    IVerifier public verifier;

    address public owner;
    uint256 public feeBps;
    bool public depositsPaused;

    uint256 public immutable levels;
    uint256 public nextIndex;
    bytes32 public currentRoot;

    mapping(uint256 => bytes32) private zeros;
    mapping(uint256 => bytes32) private filledSubtrees;
    mapping(bytes32 => bool) public knownRoots;

    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullifierSpent;
    mapping(address => uint256) public lastWithdrawalTime;

    event Deposit(
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    event Withdrawal(
        address indexed recipient,
        bytes32 indexed nullifier,
        bytes32 indexed root,
        uint256 amount,
        uint256 timestamp
    );

    event NullifierBatchSubmitted(
        address indexed submitter,
        uint256 count,
        uint256 timestamp
    );

    event DepositFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event VerifierUpdated(address oldVerifier, address newVerifier);
    event DepositsPausedChanged(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidLevels();
    error TreeFull();
    error InvalidCommitment();
    error InvalidNullifier();
    error CommitmentAlreadyUsed();
    error NullifierAlreadySpent();
    error UnknownRoot();
    error WithdrawalTooSoon(uint256 availableAt);
    error InvalidProof();
    error TokenTransferFailed();
    error DepositsPausedError();
    error FeeTooHigh();
    error EmptyBatch();
    error BatchTooLarge();
    error InsufficientContractBalance();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        address _token,
        address _hasher,
        address _verifier,
        uint256 _levels
    ) {
        if (_token == address(0) || _hasher == address(0) || _verifier == address(0)) {
            revert ZeroAddress();
        }
        if (_levels == 0 || _levels > MAX_TREE_LEVELS) revert InvalidLevels();

        token = IERC20(_token);
        hasher = IHasher(_hasher);
        verifier = IVerifier(_verifier);
        owner = msg.sender;
        levels = _levels;
        feeBps = DEFAULT_FEE_BPS;

        bytes32 zero = bytes32(0);
        zeros[0] = zero;
        for (uint256 i = 0; i < _levels; i++) {
            filledSubtrees[i] = zero;
            zero = bytes32(hasher.hash(uint256(zero), uint256(zero)));
            zeros[i + 1] = zero;
        }
        currentRoot = zeros[_levels];
        knownRoots[currentRoot] = true;
    }

    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        if (nextIndex >= (uint256(1) << levels)) revert TreeFull();

        index = uint32(nextIndex);
        uint256 currentIndex = uint256(index);
        bytes32 currentLevelHash = _leaf;

        for (uint256 i = 0; i < levels; i++) {
            if ((currentIndex & 1) == 0) {
                filledSubtrees[i] = currentLevelHash;
                currentLevelHash = bytes32(
                    hasher.hash(uint256(currentLevelHash), uint256(zeros[i]))
                );
            } else {
                currentLevelHash = bytes32(
                    hasher.hash(uint256(filledSubtrees[i]), uint256(currentLevelHash))
                );
            }
            currentIndex >>= 1;
        }

        currentRoot = currentLevelHash;
        knownRoots[currentRoot] = true;
        nextIndex += 1;
    }

    function deposit(bytes32 _commitment, uint256 _amount) external nonReentrant {
        if (depositsPaused) revert DepositsPausedError();
        if (_commitment == bytes32(0)) revert InvalidCommitment();
        if (_amount == 0) revert ZeroAmount();
        if (commitments[_commitment]) revert CommitmentAlreadyUsed();

        uint256 fee = (_amount * feeBps) / FEE_DENOMINATOR;

        commitments[_commitment] = true;
        uint32 leafIndex = _insert(_commitment);

        if (!token.transferFrom(msg.sender, address(this), _amount)) {
            revert TokenTransferFailed();
        }
        if (fee > 0) {
            if (!token.transfer(owner, fee)) revert TokenTransferFailed();
        }

        emit Deposit(_commitment, leafIndex, _amount, fee, block.timestamp);
    }

    function withdraw(
        bytes32 _nullifier,
        bytes32 _root,
        address _recipient,
        uint256 _amount,
        uint256[2] calldata _proofA,
        uint256[2][2] calldata _proofB,
        uint256[2] calldata _proofC
    ) external nonReentrant {
        if (_nullifier == bytes32(0)) revert InvalidNullifier();
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        if (nullifierSpent[_nullifier]) revert NullifierAlreadySpent();
        if (!knownRoots[_root]) revert UnknownRoot();

        uint256 availableAt = lastWithdrawalTime[_recipient] + WITHDRAWAL_DELAY;
        if (block.timestamp < availableAt) revert WithdrawalTooSoon(availableAt);

        uint256[5] memory input = [
            uint256(_nullifier),
            uint256(_root),
            uint256(uint160(_recipient)),
            _amount,
            uint256(uint160(address(token)))
        ];

        if (!verifier.verifyProof(_proofA, _proofB, _proofC, input)) revert InvalidProof();

        nullifierSpent[_nullifier] = true;
        lastWithdrawalTime[_recipient] = block.timestamp;

        if (token.balanceOf(address(this)) < _amount) revert InsufficientContractBalance();

        if (!token.transfer(_recipient, _amount)) revert TokenTransferFailed();

        emit Withdrawal(_recipient, _nullifier, _root, _amount, block.timestamp);
    }

    function submitNullifierBatch(bytes32[] calldata _nullifiers) external {
        if (_nullifiers.length == 0) revert EmptyBatch();
        if (_nullifiers.length > MAX_BATCH_SIZE) revert BatchTooLarge();

        uint256 newlySpent = 0;
        for (uint256 i = 0; i < _nullifiers.length; i++) {
            bytes32 n = _nullifiers[i];
            if (n == bytes32(0)) revert InvalidNullifier();
            if (!nullifierSpent[n]) {
                nullifierSpent[n] = true;
                newlySpent += 1;
            }
        }

        emit NullifierBatchSubmitted(msg.sender, newlySpent, block.timestamp);
    }

    function setDepositFee(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit DepositFeeUpdated(feeBps, _newFeeBps);
        feeBps = _newFeeBps;
    }

    function setVerifier(address _newVerifier) external onlyOwner {
        if (_newVerifier == address(0)) revert ZeroAddress();
        emit VerifierUpdated(address(verifier), _newVerifier);
        verifier = IVerifier(_newVerifier);
    }

    function setDepositsPaused(bool _paused) external onlyOwner {
        depositsPaused = _paused;
        emit DepositsPausedChanged(_paused);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function isKnownRoot(bytes32 _root) external view returns (bool) {
        return knownRoots[_root];
    }

    function isSpent(bytes32 _nullifier) external view returns (bool) {
        return nullifierSpent[_nullifier];
    }

    function isCommitmentKnown(bytes32 _commitment) external view returns (bool) {
        return commitments[_commitment];
    }

    function getNextIndex() external view returns (uint256) {
        return nextIndex;
    }
}
