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

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

library SafeERC20 {
    error SafeERC20FailedOperation();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation();
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeERC20FailedOperation();
        }
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
    uint32 public constant LEVELS = 20;
    uint32 public constant ROOT_HISTORY_SIZE = 100;

    bytes32[] public filledSubtrees;
    bytes32[] public zeros;
    bytes32[ROOT_HISTORY_SIZE] public roots;
    uint32 public currentRootIndex;
    uint32 public nextIndex;

    constructor() {
        zeros = new bytes32[](LEVELS + 1);
        zeros[0] = bytes32(0);
        for (uint32 i = 1; i <= LEVELS; i++) {
            zeros[i] = hashLeftRight(zeros[i - 1], zeros[i - 1]);
        }
        filledSubtrees = new bytes32[](LEVELS);
        for (uint32 i = 0; i < LEVELS; i++) {
            filledSubtrees[i] = zeros[i];
        }
        roots[0] = zeros[LEVELS];
        currentRootIndex = 0;
        nextIndex = 0;
    }

    function hashLeftRight(bytes32 left, bytes32 right) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }

    function isKnownRoot(bytes32 root) public view returns (bool) {
        if (root == bytes32(0)) return false;
        uint32 i = currentRootIndex;
        do {
            if (roots[i] == root) return true;
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != currentRootIndex);
        return false;
    }

    function getCurrentRoot() public view returns (bytes32) {
        return roots[currentRootIndex];
    }

    function _insert(bytes32 leaf) internal returns (uint32 index) {
        require(nextIndex < uint32(2) ** LEVELS, "Merkle tree is full");
        uint32 currentIndex = nextIndex;
        bytes32 currentLevelHash = leaf;
        bytes32 left;
        bytes32 right;
        for (uint32 i = 0; i < LEVELS; i++) {
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
        currentRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        roots[currentRootIndex] = currentLevelHash;
        index = nextIndex;
        nextIndex += 1;
    }
}

contract PrivateAssetMixer is MerkleTreeWithHistory, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IVerifier public immutable verifier;
    address public owner;
    address public treasury;

    uint256 public constant FEE_BASIS_POINTS = 10; // 0.1%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_TOKEN_LIMIT = 1000;

    mapping(bytes32 => bool) public nullifierHashes;
    mapping(bytes32 => bool) public commitments;

    struct TokenConfig {
        bool supported;
        uint256 maxDeposit;
    }

    mapping(address => TokenConfig) public tokens;

    event Deposit(
        bytes32 indexed commitment,
        uint32 indexed leafIndex,
        uint256 timestamp,
        address indexed token,
        uint256 amount
    );
    event Withdrawal(
        address indexed recipient,
        bytes32 indexed nullifier,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    event TokenAdded(address indexed token, uint256 maxDeposit);
    event TokenRemoved(address indexed token);
    event TokenLimitUpdated(address indexed token, uint256 maxDeposit);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    error NotOwner();
    error TokenNotSupported();
    error AmountExceedsLimit();
    error AmountIsZero();
    error CommitmentAlreadySubmitted();
    error NullifierAlreadySpent();
    error InvalidRoot();
    error InvalidProof();
    error ZeroAddress();
    error LimitExceedsMax();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _verifier, address _treasury) {
        if (_verifier == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        verifier = IVerifier(_verifier);
        owner = msg.sender;
        treasury = _treasury;
        emit OwnershipTransferred(address(0), msg.sender);
        emit TreasuryUpdated(address(0), _treasury);
    }

    function addToken(address token, uint256 maxDeposit) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (maxDeposit == 0 || maxDeposit > MAX_TOKEN_LIMIT) revert LimitExceedsMax();
        tokens[token].supported = true;
        tokens[token].maxDeposit = maxDeposit;
        emit TokenAdded(token, maxDeposit);
    }

    function removeToken(address token) external onlyOwner {
        tokens[token].supported = false;
        tokens[token].maxDeposit = 0;
        emit TokenRemoved(token);
    }

    function setTokenLimit(address token, uint256 maxDeposit) external onlyOwner {
        if (!tokens[token].supported) revert TokenNotSupported();
        if (maxDeposit == 0 || maxDeposit > MAX_TOKEN_LIMIT) revert LimitExceedsMax();
        tokens[token].maxDeposit = maxDeposit;
        emit TokenLimitUpdated(token, maxDeposit);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(old, _treasury);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function deposit(bytes32 commitment, address token, uint256 amount) external nonReentrant {
        TokenConfig storage cfg = tokens[token];
        if (!cfg.supported) revert TokenNotSupported();
        if (amount == 0) revert AmountIsZero();
        if (amount > cfg.maxDeposit) revert AmountExceedsLimit();
        if (commitments[commitment]) revert CommitmentAlreadySubmitted();

        commitments[commitment] = true;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint32 leafIndex = _insert(commitment);
        emit Deposit(commitment, leafIndex, block.timestamp, token, amount);
    }

    function withdraw(
        bytes32 nullifierHash,
        bytes32 root,
        address token,
        uint256 amount,
        address recipient,
        uint256[2] memory proofA,
        uint256[2][2] memory proofB,
        uint256[2] memory proofC
    ) external nonReentrant {
        if (nullifierHashes[nullifierHash]) revert NullifierAlreadySpent();
        if (!isKnownRoot(root)) revert InvalidRoot();
        if (!tokens[token].supported) revert TokenNotSupported();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountIsZero();

        uint256[] memory input = new uint256[](5);
        input[0] = uint256(nullifierHash);
        input[1] = uint256(root);
        input[2] = uint256(uint160(token));
        input[3] = amount;
        input[4] = uint256(uint160(recipient));

        if (!verifier.verifyProof(proofA, proofB, proofC, input)) revert InvalidProof();

        nullifierHashes[nullifierHash] = true;

        uint256 fee = (amount * FEE_BASIS_POINTS) / FEE_DENOMINATOR;
        uint256 payout = amount - fee;

        IERC20(token).safeTransfer(recipient, payout);

        if (fee > 0) {
            IERC20(token).safeTransfer(treasury, fee);
        }

        emit Withdrawal(recipient, nullifierHash, token, amount, fee);
    }

    function isSpent(bytes32 nullifierHash) external view returns (bool) {
        return nullifierHashes[nullifierHash];
    }

    function isCommitmentKnown(bytes32 commitment) external view returns (bool) {
        return commitments[commitment];
    }

    function isTokenSupported(address token) external view returns (bool) {
        return tokens[token].supported;
    }

    function getTokenLimit(address token) external view returns (uint256) {
        return tokens[token].maxDeposit;
    }
}
