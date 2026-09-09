// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IHasher {
    function poseidon(bytes32[] calldata inputs) external pure returns (bytes32);
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
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant ZERO_VALUE =
        2166383900441693294538235590879059922526880266223290358250979569353185826424;

    IHasher public immutable hasher;
    uint32 public immutable levels;

    bytes32[] public filledSubtrees;
    bytes32[] public zeros;
    uint32 public currentRootIndex;
    uint32 public nextLeafIndex;

    uint32 public constant ROOT_HISTORY_SIZE = 100;
    bytes32[] public roots;

    event RootAdded(bytes32 root, uint32 leafIndex);

    constructor(uint32 _levels, IHasher _hasher) {
        require(_levels > 0 && _levels <= 32, "invalid levels");
        require(address(_hasher) != address(0), "invalid hasher");

        hasher = _hasher;
        levels = _levels;

        zeros = new bytes32[](_levels + 1);
        filledSubtrees = new bytes32[](_levels);

        bytes32 currentZero = bytes32(ZERO_VALUE);
        zeros[0] = currentZero;
        for (uint32 i = 1; i <= _levels; i++) {
            currentZero = hashLeftRight(currentZero, currentZero);
            zeros[i] = currentZero;
        }

        roots = new bytes32[](ROOT_HISTORY_SIZE);
        roots[0] = zeros[_levels];
    }

    function hashLeftRight(bytes32 _left, bytes32 _right) public view returns (bytes32) {
        bytes32[] memory inputs = new bytes32[](2);
        inputs[0] = _left;
        inputs[1] = _right;
        return hasher.poseidon(inputs);
    }

    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        require(uint256(nextLeafIndex) < uint256(2) ** levels, "Merkle tree is full");

        uint32 currentIndex = nextLeafIndex;
        bytes32 currentLevelHash = _leaf;
        bytes32 left;
        bytes32 right;
        uint32 i = levels;

        while (i > 0) {
            i -= 1;
            if (currentIndex % 2 == 0) {
                left = currentLevelHash;
                right = zeros[i];
                filledSubtrees[i] = currentLevelHash;
            } else {
                left = filledSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = hashLeftRight(left, right);
            currentIndex /= 2;
        }

        uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;
        roots[newRootIndex] = currentLevelHash;
        index = nextLeafIndex;
        nextLeafIndex += 1;

        emit RootAdded(currentLevelHash, index);
    }

    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == bytes32(0)) return false;
        for (uint32 i = 0; i < ROOT_HISTORY_SIZE; i++) {
            if (roots[i] == _root) return true;
        }
        return false;
    }

    function currentRoot() public view returns (bytes32) {
        return roots[currentRootIndex];
    }
}

contract TokenMixer is MerkleTreeWithHistory, ReentrancyGuard {
    error OnlyOwner();
    error ZeroAddress();
    error UnsupportedDenomination();
    error CommitmentAlreadyUsed();
    error NullifierAlreadySpent();
    error UnknownRoot();
    error InvalidProof();
    error InsufficientBalance();
    error InvalidFee();
    error InvalidAmount();
    error InvalidRelayerFee();

    IERC20 public immutable token;
    IVerifier public immutable verifier;

    address public owner;
    address public feeRecipient;

    uint256 public feeBps; // basis points; 50 == 0.5%

    mapping(bytes32 => bool) public nullifierHashes;
    mapping(bytes32 => bool) public commitments;
    mapping(uint256 => bool) public supportedDenominations;

    uint256[] public denominationList;

    uint256 public totalDeposited;

    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 amount, uint256 timestamp);
    event Withdrawal(
        bytes32 indexed nullifierHash,
        address indexed recipient,
        address indexed relayer,
        uint256 amount,
        uint256 fee,
        uint256 relayerFee,
        uint256 timestamp
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event DenominationAdded(uint256 amount);
    event DenominationRemoved(uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(
        address _token,
        IHasher _hasher,
        IVerifier _verifier,
        uint32 _levels,
        uint256[] memory _denominations,
        address _feeRecipient,
        uint256 _feeBps
    ) MerkleTreeWithHistory(_levels, _hasher) {
        if (_token == address(0)) revert ZeroAddress();
        if (address(_verifier) == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > 10000) revert InvalidFee();
        if (_denominations.length == 0) revert InvalidAmount();

        token = IERC20(_token);
        verifier = _verifier;
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;

        for (uint256 i = 0; i < _denominations.length; i++) {
            uint256 d = _denominations[i];
            if (d == 0) revert InvalidAmount();
            if (!supportedDenominations[d]) {
                supportedDenominations[d] = true;
                denominationList.push(d);
                emit DenominationAdded(d);
            }
        }

        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
        emit FeeUpdated(0, _feeBps);
    }

    function deposit(uint256 _amount, bytes32 _commitment) external nonReentrant {
        if (!supportedDenominations[_amount]) revert UnsupportedDenomination();
        if (commitments[_commitment]) revert CommitmentAlreadyUsed();

        // Effects
        commitments[_commitment] = true;
        totalDeposited += _amount;
        uint32 leafIndex = _insert(_commitment);

        // Interactions
        if (!token.transferFrom(msg.sender, address(this), _amount)) revert InvalidAmount();

        emit Deposit(_commitment, leafIndex, _amount, block.timestamp);
    }

    function withdraw(
        uint256[2] memory _proofA,
        uint256[2][2] memory _proofB,
        uint256[2] memory _proofC,
        bytes32 _root,
        bytes32 _nullifierHash,
        uint256 _amount,
        address _recipient,
        address _relayer,
        uint256 _relayerFee
    ) external nonReentrant {
        if (!isKnownRoot(_root)) revert UnknownRoot();
        if (nullifierHashes[_nullifierHash]) revert NullifierAlreadySpent();
        if (!supportedDenominations[_amount]) revert UnsupportedDenomination();
        if (_recipient == address(0)) revert ZeroAddress();
        if (_relayerFee > _amount) revert InvalidRelayerFee();

        uint256[] memory input = new uint256[](4);
        input[0] = uint256(_root);
        input[1] = uint256(_nullifierHash);
        input[2] = _amount;
        input[3] = uint256(uint160(_recipient));

        if (!verifier.verifyProof(_proofA, _proofB, _proofC, input)) revert InvalidProof();

        // Effects
        nullifierHashes[_nullifierHash] = true;
        totalDeposited -= _amount;

        uint256 fee = (_amount * feeBps) / 10000;
        uint256 payout = _amount - fee - _relayerFee;

        if (token.balanceOf(address(this)) < _amount) revert InsufficientBalance();

        // Interactions
        if (payout > 0) {
            if (!token.transfer(_recipient, payout)) revert InvalidAmount();
        }
        if (_relayerFee > 0) {
            if (!token.transfer(_relayer, _relayerFee)) revert InvalidAmount();
        }
        if (fee > 0) {
            if (!token.transfer(feeRecipient, fee)) revert InvalidAmount();
        }

        emit Withdrawal(
            _nullifierHash,
            _recipient,
            _relayer,
            _amount,
            fee,
            _relayerFee,
            block.timestamp
        );
    }

    function isSpent(bytes32 _nullifierHash) external view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    function isKnownRootExternal(bytes32 _root) external view returns (bool) {
        return isKnownRoot(_root);
    }

    function getDenominations() external view returns (uint256[] memory) {
        return denominationList;
    }

    function getRoot() external view returns (bytes32) {
        return currentRoot();
    }

    function getNextLeafIndex() external view returns (uint32) {
        return nextLeafIndex;
    }

    function setFee(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > 10000) revert InvalidFee();
        uint256 old = feeBps;
        feeBps = _newFeeBps;
        emit FeeUpdated(old, _newFeeBps);
    }

    function addDenomination(uint256 _amount) external onlyOwner {
        if (_amount == 0) revert InvalidAmount();
        if (supportedDenominations[_amount]) revert UnsupportedDenomination();
        supportedDenominations[_amount] = true;
        denominationList.push(_amount);
        emit DenominationAdded(_amount);
    }

    function removeDenomination(uint256 _amount) external onlyOwner {
        if (!supportedDenominations[_amount]) revert UnsupportedDenomination();
        supportedDenominations[_amount] = false;

        uint256 len = denominationList.length;
        for (uint256 i = 0; i < len; i++) {
            if (denominationList[i] == _amount) {
                denominationList[i] = denominationList[len - 1];
                denominationList.pop();
                break;
            }
        }

        emit DenominationRemoved(_amount);
    }

    function setFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(old, _newRecipient);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = _newOwner;
        emit OwnershipTransferred(old, _newOwner);
    }

    function withdrawFees() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        if (contractBalance <= totalDeposited) revert InvalidAmount();
        uint256 fees = contractBalance - totalDeposited;
        if (!token.transfer(owner, fees)) revert InvalidAmount();
    }
}
