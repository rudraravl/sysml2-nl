// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHasher {
    function MiMCSponge(uint256 xL, uint256 xR) external pure returns (uint256);
}

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

contract MerkleTreeWithHistory {
    uint8 public levels;
    uint256 public constant ROOT_HISTORY_SIZE = 30;

    bytes32[] public zeros;
    mapping(uint8 => bytes32) public filledSubtrees;
    mapping(uint256 => bytes32) public roots;

    uint256 public currentRootIndex;
    uint32 public nextIndex;

    IHasher public immutable hasher;

    uint256 internal constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    event RootAdded(bytes32 indexed root, uint256 index);

    constructor(uint8 _levels, IHasher _hasher) {
        require(_levels > 0 && _levels <= 32, "Unsupported tree depth");
        levels = _levels;
        hasher = _hasher;

        zeros = new bytes32[](_levels + 1);
        zeros[0] = bytes32(0);
        for (uint8 i = 1; i <= _levels; i++) {
            zeros[i] = _hashLeftRight(zeros[i - 1], zeros[i - 1]);
        }

        for (uint8 i = 0; i < _levels; i++) {
            filledSubtrees[i] = zeros[i];
        }

        bytes32 initialRoot = zeros[_levels];
        roots[currentRootIndex] = initialRoot;
        emit RootAdded(initialRoot, currentRootIndex);
    }

    function _hashLeftRight(bytes32 _left, bytes32 _right) internal returns (bytes32) {
        require(uint256(_left) < FIELD_SIZE && uint256(_right) < FIELD_SIZE, "Out of field");
        return bytes32(hasher.MiMCSponge(uint256(_left), uint256(_right)));
    }

    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        uint32 next = nextIndex;
        require(next < uint32(2) ** levels, "Tree is full");

        bytes32 current = _leaf;
        for (uint8 level = 0; level < levels; level++) {
            if (next % 2 == 0) {
                filledSubtrees[level] = current;
                current = _hashLeftRight(current, zeros[level]);
            } else {
                current = _hashLeftRight(filledSubtrees[level], current);
            }
            next = next / 2;
        }

        currentRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        roots[currentRootIndex] = current;
        nextIndex += 1;
        emit RootAdded(current, currentRootIndex);
        return nextIndex - 1;
    }

    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == bytes32(0)) return false;
        uint256 i = currentRootIndex;
        for (uint256 j = 0; j < ROOT_HISTORY_SIZE; j++) {
            if (roots[i] == _root) return true;
            if (i == 0) {
                i = ROOT_HISTORY_SIZE - 1;
            } else {
                i -= 1;
            }
        }
        return false;
    }

    function currentRoot() public view returns (bytes32) {
        return roots[currentRootIndex];
    }
}

contract ShieldedVault is MerkleTreeWithHistory, ReentrancyGuard {
    error NotOperator();
    error TokenNotSupported();
    error DepositExceedsMax();
    error InvalidDepositAmount();
    error UnknownRoot();
    error NullifierAlreadySpent();
    error InvalidProof();
    error InsufficientPrivateBalance();
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error FeeTooHigh();

    event Deposit(
        address indexed token,
        address indexed from,
        bytes32 indexed commitment,
        uint256 amount,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Withdrawal(
        address indexed token,
        address indexed to,
        bytes32 indexed nullifierHash,
        uint256 amount,
        uint256 fee
    );
    event TokenSupported(address indexed token, bool supported);
    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    uint256 public constant MAX_DEPOSIT = 1000;
    uint256 public constant DEFAULT_FEE_BPS = 10; // 0.1%
    uint256 public constant MAX_FEE_BPS = 1000; // 10%

    address public operator;
    address public feeRecipient;
    uint256 public withdrawalFeeBps;

    mapping(bytes32 => bool) public nullifierSpent;
    mapping(bytes32 => bool) public commitmentExists;
    mapping(address => mapping(address => uint256)) public privateBalances;
    mapping(address => bool) public supportedTokens;

    IVerifier public immutable verifier;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!supportedTokens[token]) revert TokenNotSupported();
        _;
    }

    struct WithdrawProof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    constructor(
        uint8 _levels,
        IHasher _hasher,
        IVerifier _verifier
    ) MerkleTreeWithHistory(_levels, _hasher) {
        if (address(_verifier) == address(0)) revert ZeroAddress();
        verifier = _verifier;
        operator = msg.sender;
        feeRecipient = msg.sender;
        withdrawalFeeBps = DEFAULT_FEE_BPS;
    }

    function setSupportedToken(address token, bool supported) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        supportedTokens[token] = supported;
        emit TokenSupported(token, supported);
    }

    function setWithdrawalFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = withdrawalFeeBps;
        withdrawalFeeBps = _feeBps;
        emit WithdrawalFeeUpdated(old, _feeBps);
    }

    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function updateMerkleRoot(bytes32 _root) external onlyOperator {
        require(_root != bytes32(0), "Zero root");
        currentRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        roots[currentRootIndex] = _root;
        emit RootAdded(_root, currentRootIndex);
    }

    function deposit(
        address token,
        uint256 amount,
        bytes32 commitment
    ) external onlySupportedToken(token) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_DEPOSIT) revert DepositExceedsMax();
        if (commitment == bytes32(0)) revert InvalidDepositAmount();
        if (commitmentExists[commitment]) revert InvalidDepositAmount();

        commitmentExists[commitment] = true;
        privateBalances[msg.sender][token] += amount;
        uint32 leafIndex = _insert(commitment);

        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();

        emit Deposit(token, msg.sender, commitment, amount, leafIndex, block.timestamp);
    }

    function withdraw(
        address token,
        uint256 amount,
        bytes32 nullifierHash,
        bytes32 root,
        address recipient,
        WithdrawProof calldata proof
    ) external onlySupportedToken(token) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        if (!isKnownRoot(root)) revert UnknownRoot();
        if (nullifierSpent[nullifierHash]) revert NullifierAlreadySpent();
        if (privateBalances[msg.sender][token] < amount) revert InsufficientPrivateBalance();

        uint256[] memory input = new uint256[](5);
        input[0] = uint256(root);
        input[1] = uint256(nullifierHash);
        input[2] = amount;
        input[3] = uint256(uint160(token));
        input[4] = uint256(uint160(recipient));

        if (!verifier.verifyProof(proof.a, proof.b, proof.c, input)) revert InvalidProof();

        nullifierSpent[nullifierHash] = true;
        privateBalances[msg.sender][token] -= amount;

        uint256 fee = (amount * withdrawalFeeBps) / 10000;
        uint256 amountOut = amount - fee;

        _safeTransfer(token, recipient, amountOut);
        if (fee > 0) {
            _safeTransfer(token, feeRecipient, fee);
        }

        emit Withdrawal(token, recipient, nullifierHash, amount, fee);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, value)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function getMerkleRoot() external view returns (bytes32) {
        return currentRoot();
    }

    function isSpent(bytes32 nullifierHash) external view returns (bool) {
        return nullifierSpent[nullifierHash];
    }
}
