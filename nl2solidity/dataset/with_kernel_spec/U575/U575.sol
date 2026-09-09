// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata input
    ) external view returns (bool);
}

contract PrivateGateway {
    // ---------- Errors ----------
    error NotOperator();
    error ZeroAddress();
    error InvalidDepositAmount();
    error ExceedsMaxDeposit();
    error InvalidProof();
    error NullifierAlreadySpent();
    error RecipientAlreadyRegistered();
    error InvalidRoot();
    error RootNotPending();
    error RootDelayNotElapsed();
    error WithdrawalFailed();
    error ReentrantCall();
    error DuplicateCommitment();
    error RecipientNotRegistered();

    // ---------- Events ----------
    event EthDeposited(address indexed depositor, uint256 amount, bytes32 indexed commitment, uint32 leafIndex);
    event TokenDeposited(address indexed depositor, uint256 amount, bytes32 indexed commitment, uint32 leafIndex);
    event Withdrawn(
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 fee,
        bytes32 indexed nullifier,
        bytes32 newRoot
    );
    event RootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);
    event RootQueued(bytes32 indexed pendingRoot, uint256 queuedAt);
    event RecipientRegistered(address indexed user, address indexed recipient);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // ---------- Constants ----------
    uint256 public constant FEE_BPS = 10; // 0.1%
    uint256 public constant FEE_BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_ETH_DEPOSIT = 100 ether;
    uint256 public constant ROOT_DELAY = 1 hours;
    uint32 public constant TREE_LEVELS = 20;

    // ---------- Immutables ----------
    IERC20 public immutable designatedToken;
    uint256 public immutable MAX_TOKEN_DEPOSIT;
    IVerifier public immutable verifier;

    // ---------- State ----------
    address public operator;
    address public feeRecipient;

    bytes32 public currentRoot;
    bytes32 public pendingRoot;
    uint256 public pendingRootTimestamp;

    mapping(address => uint256) public ethDeposited;
    mapping(address => uint256) public tokenDeposited;
    mapping(bytes32 => bool) public nullifierSpent;
    mapping(bytes32 => bool) public commitments;
    mapping(address => address) public registeredRecipient;
    mapping(address => bool) public hasRecipient;
    mapping(address => bool) public registeredRecipients;

    bytes32[] public rootHistory;
    mapping(bytes32 => bool) public knownRoots;

    uint32 public nextLeafIndex;

    // Incremental Merkle tree state
    bytes32[TREE_LEVELS] public zeros;
    bytes32[TREE_LEVELS] public filledSubtrees;

    uint256 private locked = 1;

    // ---------- Modifiers ----------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (locked != 1) revert ReentrantCall();
        locked = 2;
        _;
        locked = 1;
    }

    // ---------- Constructor ----------
    constructor(
        address _operator,
        address _feeRecipient,
        IERC20 _designatedToken,
        IVerifier _verifier
    ) {
        if (
            _operator == address(0) ||
            _feeRecipient == address(0) ||
            address(_designatedToken) == address(0) ||
            address(_verifier) == address(0)
        ) {
            revert ZeroAddress();
        }
        operator = _operator;
        feeRecipient = _feeRecipient;
        designatedToken = _designatedToken;
        verifier = _verifier;

        uint8 decimals = _designatedToken.decimals();
        MAX_TOKEN_DEPOSIT = 10_000 * (10 ** uint256(decimals));

        // Initialize zero hashes for the Merkle tree
        zeros[0] = keccak256(abi.encodePacked(uint256(0)));
        for (uint256 i = 1; i < TREE_LEVELS; i++) {
            zeros[i] = keccak256(abi.encodePacked(zeros[i - 1], zeros[i - 1]));
        }
        currentRoot = zeros[TREE_LEVELS - 1];
        knownRoots[currentRoot] = true;
        rootHistory.push(currentRoot);
    }

    // ---------- Deposit Ether ----------
    function depositEth(bytes32 commitment) external payable nonReentrant {
        if (msg.value == 0) revert InvalidDepositAmount();
        if (msg.value > MAX_ETH_DEPOSIT) revert ExceedsMaxDeposit();
        if (commitments[commitment]) revert DuplicateCommitment();

        commitments[commitment] = true;
        ethDeposited[msg.sender] += msg.value;

        uint32 leafIndex = _insertLeaf(commitment);

        emit EthDeposited(msg.sender, msg.value, commitment, leafIndex);
    }

    // ---------- Deposit ERC-20 ----------
    function depositToken(uint256 amount, bytes32 commitment) external nonReentrant {
        if (amount == 0) revert InvalidDepositAmount();
        if (amount > MAX_TOKEN_DEPOSIT) revert ExceedsMaxDeposit();
        if (commitments[commitment]) revert DuplicateCommitment();

        // Checks-effects-interactions: update state before external transfer
        commitments[commitment] = true;
        tokenDeposited[msg.sender] += amount;

        uint32 leafIndex = _insertLeaf(commitment);

        bool ok = designatedToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert WithdrawalFailed();

        emit TokenDeposited(msg.sender, amount, commitment, leafIndex);
    }

    // ---------- Register Recipient ----------
    function registerRecipient(address recipient) external {
        if (recipient == address(0)) revert ZeroAddress();
        if (hasRecipient[msg.sender] && registeredRecipient[msg.sender] == recipient) revert RecipientAlreadyRegistered();

        registeredRecipient[msg.sender] = recipient;
        hasRecipient[msg.sender] = true;
        registeredRecipients[recipient] = true;

        emit RecipientRegistered(msg.sender, recipient);
    }

    // ---------- Operator: Queue new Merkle root ----------
    function queueRootUpdate(bytes32 newRoot) external onlyOperator {
        if (newRoot == bytes32(0)) revert InvalidRoot();
        if (knownRoots[newRoot]) revert InvalidRoot();

        pendingRoot = newRoot;
        pendingRootTimestamp = block.timestamp;

        emit RootQueued(newRoot, block.timestamp);
    }

    // ---------- Operator: Activate queued root after delay ----------
    function activateRoot() external onlyOperator {
        if (pendingRoot == bytes32(0)) revert RootNotPending();
        if (block.timestamp < pendingRootTimestamp + ROOT_DELAY) revert RootDelayNotElapsed();

        bytes32 oldRoot = currentRoot;
        currentRoot = pendingRoot;
        knownRoots[pendingRoot] = true;
        rootHistory.push(pendingRoot);

        delete pendingRoot;
        delete pendingRootTimestamp;

        emit RootUpdated(oldRoot, currentRoot);
    }

    // ---------- Operator: Process withdrawal after ZK verification ----------
    function processWithdrawal(
        address recipient,
        address token,
        uint256 amount,
        bytes32 nullifier,
        bytes32 root,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata input
    ) external onlyOperator nonReentrant {
        if (nullifierSpent[nullifier]) revert NullifierAlreadySpent();
        if (!knownRoots[root]) revert InvalidRoot();
        if (recipient == address(0)) revert ZeroAddress();
        if (!registeredRecipients[recipient]) revert RecipientNotRegistered();

        // Validate public inputs match the provided parameters.
        // input layout: [nullifier, root, amount, recipient, tokenFlag]
        if (bytes32(input[0]) != nullifier) revert InvalidProof();
        if (bytes32(input[1]) != root) revert InvalidProof();
        if (input[2] != amount) revert InvalidProof();
        if (input[3] != uint256(uint160(recipient))) revert InvalidProof();

        bool isToken = token != address(0);
        if (input[4] != (isToken ? 1 : 0)) revert InvalidProof();

        if (isToken && token != address(designatedToken)) revert InvalidProof();

        bool valid = verifier.verifyProof(a, b, c, input);
        if (!valid) revert InvalidProof();

        // Mark nullifier as spent (checks-effects-interactions)
        nullifierSpent[nullifier] = true;

        uint256 fee = (amount * FEE_BPS) / FEE_BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        if (isToken) {
            _safeTokenTransfer(recipient, payout);
            _safeTokenTransfer(feeRecipient, fee);
        } else {
            _safeEthTransfer(recipient, payout);
            _safeEthTransfer(feeRecipient, fee);
        }

        emit Withdrawn(recipient, token, amount, fee, nullifier, currentRoot);
    }

    // ---------- Admin ----------
    function setFeeRecipient(address newRecipient) external onlyOperator {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    // ---------- Views ----------
    function isRootKnown(bytes32 root) external view returns (bool) {
        return knownRoots[root];
    }

    function rootHistoryLength() external view returns (uint256) {
        return rootHistory.length;
    }

    function getRootHistory(uint256 index) external view returns (bytes32) {
        return rootHistory[index];
    }

    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTokenBalance() external view returns (uint256) {
        return designatedToken.balanceOf(address(this));
    }

    // ---------- Internal: Incremental Merkle Tree ----------
    function _insertLeaf(bytes32 leaf) internal returns (uint32 leafIndex) {
        leafIndex = nextLeafIndex;
        uint256 currentIndex = uint256(leafIndex);
        bytes32 currentLevelHash = leaf;

        for (uint256 i = 0; i < TREE_LEVELS; i++) {
            if (currentIndex % 2 == 0) {
                filledSubtrees[i] = currentLevelHash;
                currentLevelHash = keccak256(abi.encodePacked(currentLevelHash, zeros[i]));
            } else {
                currentLevelHash = keccak256(abi.encodePacked(filledSubtrees[i], currentLevelHash));
            }
            currentIndex /= 2;
        }

        nextLeafIndex++;
        bytes32 oldRoot = currentRoot;
        currentRoot = currentLevelHash;
        knownRoots[currentRoot] = true;
        rootHistory.push(currentRoot);

        emit RootUpdated(oldRoot, currentRoot);
    }

    // ---------- Internal: Safe Transfers ----------
    function _safeEthTransfer(address to, uint256 amount) internal {
        (bool ok, ) = payable(to).call{value: amount}("");
        if (!ok) revert WithdrawalFailed();
    }

    function _safeTokenTransfer(address to, uint256 amount) internal {
        bool ok = designatedToken.transfer(to, amount);
        if (!ok) revert WithdrawalFailed();
    }

    // ---------- Receive ----------
    receive() external payable {
        revert InvalidDepositAmount();
    }
}
