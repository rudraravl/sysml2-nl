// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[5] memory input
    ) external view returns (bool);
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddressOwner();

    constructor(address _owner) {
        if (_owner == address(0)) revert ZeroAddressOwner();
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddressOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
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
    uint32 public levels;
    uint32 public constant ROOT_HISTORY_SIZE = 30;

    bytes32[] public zeros;
    bytes32[] public filledSubtrees;
    bytes32[] public roots;

    uint32 public currentRootIndex;
    uint32 public nextLeafIndex;

    mapping(bytes32 => bool) public rootHistory;

    error TreeFull();
    error UnknownRoot();
    error InvalidLevels();

    constructor(uint32 _levels) {
        if (_levels == 0) revert InvalidLevels();
        levels = _levels;

        zeros = new bytes32[](_levels);
        filledSubtrees = new bytes32[](_levels);
        roots = new bytes32[](ROOT_HISTORY_SIZE);

        bytes32 zero = bytes32(0);
        for (uint32 i = 0; i < _levels; i++) {
            zeros[i] = zero;
            filledSubtrees[i] = zero;
            zero = _hashLeftRight(zero, zero);
        }

        roots[0] = zero;
        rootHistory[zero] = true;
    }

    function _hashLeftRight(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encode(left, right));
    }

    function _insert(bytes32 leaf) internal returns (uint32 index) {
        uint32 leafIndex = nextLeafIndex;
        if (leafIndex == 0 && roots[0] != zeros[levels - 1]) {
            revert TreeFull();
        }

        uint32 currentIndex = leafIndex;
        bytes32 current = leaf;

        for (uint32 i = 0; i < levels; i++) {
            if (currentIndex % 2 == 0) {
                filledSubtrees[i] = current;
                current = _hashLeftRight(current, zeros[i]);
            } else {
                current = _hashLeftRight(filledSubtrees[i], current);
            }
            currentIndex >>= 1;
        }

        uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;
        roots[newRootIndex] = current;
        rootHistory[current] = true;

        nextLeafIndex = uint32((uint256(leafIndex) + 1) % (uint256(1) << levels));
        return leafIndex;
    }

    function isKnownRoot(bytes32 root) public view returns (bool) {
        if (root == bytes32(0)) {
            return false;
        }
        return rootHistory[root];
    }
}

contract AnonymousTransfer is MerkleTreeWithHistory, Ownable, ReentrancyGuard {
    IERC20 public immutable token;
    IVerifier public immutable verifier;

    uint256 public minDepositAmount;
    uint256 public maxDepositAmount;
    uint256 public feeBps; // basis points, e.g. 100 = 1%

    mapping(bytes32 => bool) public nullifierHashes;
    mapping(bytes32 => bool) public commitments;

    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed recipient, address indexed relayer, bytes32 nullifier, uint256 amount, uint256 fee);
    event ConfigUpdated(uint256 minDeposit, uint256 maxDeposit, uint256 feeBps);

    error InvalidDepositAmount();
    error CommitmentAlreadySubmitted();
    error NullifierAlreadySpent();
    error InvalidProof();
    error InvalidConfig();
    error TransferFromFailed();
    error TransferFailed();
    error ZeroAddressToken();
    error ZeroAddressRecipient();
    error FeeExceedsAmount();

    constructor(
        address _token,
        IVerifier _verifier,
        uint32 _merkleLevels,
        address _owner
    ) MerkleTreeWithHistory(_merkleLevels) Ownable(_owner) {
        if (_token == address(0)) revert ZeroAddressToken();
        token = IERC20(_token);
        verifier = _verifier;
        minDepositAmount = 0.01 ether; // 0.01 tokens assuming 18 decimals
        maxDepositAmount = 1000 ether; // 1000 tokens assuming 18 decimals
        feeBps = 100; // 1%
    }

    function deposit(uint256 commitment, uint256 amount) external nonReentrant {
        if (amount < minDepositAmount || amount > maxDepositAmount) revert InvalidDepositAmount();
        bytes32 commitmentBytes = bytes32(commitment);
        if (commitments[commitmentBytes]) revert CommitmentAlreadySubmitted();

        // Effects: record state before the external interaction (CEI).
        commitments[commitmentBytes] = true;
        uint32 leafIndex = _insert(commitmentBytes);

        // Interactions: custody the deposited tokens.
        _safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(commitmentBytes, leafIndex, amount, block.timestamp);
    }

    function withdraw(
        uint256 nullifier,
        uint256 root,
        uint256 amount,
        address recipient,
        address relayer,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c
    ) public nonReentrant {
        if (recipient == address(0)) revert ZeroAddressRecipient();
        bytes32 nullifierBytes = bytes32(nullifier);
        if (nullifierHashes[nullifierBytes]) revert NullifierAlreadySpent();
        if (!isKnownRoot(bytes32(root))) revert UnknownRoot();

        uint256 fee = (amount * feeBps) / 10000;
        if (fee > amount) revert FeeExceedsAmount();
        address feeRecipient = relayer == address(0) ? owner : relayer;

        // Public inputs: [nullifier, root, amount, fee, feeRecipient]
        uint256[5] memory input = [
            nullifier,
            root,
            amount,
            fee,
            uint256(uint160(feeRecipient))
        ];

        if (!verifier.verifyProof(a, b, c, input)) revert InvalidProof();

        // Effects: mark the nullifier as spent before any external transfer.
        nullifierHashes[nullifierBytes] = true;

        uint256 payout = amount - fee;

        // Interactions.
        if (payout > 0) {
            _safeTransfer(recipient, payout);
        }
        if (fee > 0) {
            _safeTransfer(feeRecipient, fee);
        }

        emit Withdrawal(recipient, feeRecipient, nullifierBytes, amount, fee);
    }

    function relayWithdraw(
        uint256 nullifier,
        uint256 root,
        uint256 amount,
        address recipient,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c
    ) external nonReentrant {
        withdraw(nullifier, root, amount, recipient, msg.sender, a, b, c);
    }

    function updateConfig(
        uint256 _minDeposit,
        uint256 _maxDeposit,
        uint256 _feeBps
    ) external onlyOwner {
        if (_minDeposit > _maxDeposit) revert InvalidConfig();
        if (_feeBps > 10000) revert InvalidConfig();

        minDepositAmount = _minDeposit;
        maxDepositAmount = _maxDeposit;
        feeBps = _feeBps;

        emit ConfigUpdated(_minDeposit, _maxDeposit, _feeBps);
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFromFailed();
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }
}
