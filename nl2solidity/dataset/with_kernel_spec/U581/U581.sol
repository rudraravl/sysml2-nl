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
        uint256[5] memory input
    ) external view returns (bool);
}

contract PrivacyMixer {
    error NotOwner();
    error NotAuthorizedRelayer();
    error ZeroAddress();
    error MixerDoesNotExist();
    error MixerInactive();
    error InvalidDenomination();
    error InvalidFee();
    error CommitmentAlreadySubmitted();
    error NullifierAlreadySpent();
    error InvalidProof();
    error TransferFailed();
    error RecipientZero();
    error InvalidParameters();
    error ReentrantCall();

    struct MixerInstance {
        address token;
        uint256 denomination;
        bool active;
    }

    struct ProofData {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    uint256 public constant FEE_BASIS_POINTS_MAX = 10000;
    uint256 public feeBasisPoints = 10; // 0.1%

    address public owner;
    IVerifier public immutable verifier;

    mapping(uint256 => MixerInstance) public mixers;
    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullifiers;
    mapping(address => uint256) public totalDeposits;
    mapping(address => bool) public isRelayer;
    mapping(uint256 => uint256) public mixerDepositCount;
    uint256 public mixerCount;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    event Deposit(
        uint256 indexed mixerId,
        address indexed token,
        bytes32 indexed commitment,
        uint256 denomination,
        uint256 timestamp
    );
    event Withdrawal(
        uint256 indexed mixerId,
        address indexed token,
        address indexed recipient,
        bytes32 nullifier,
        address relayer,
        uint256 amount,
        uint256 fee
    );
    event FeeUpdated(uint256 oldFeeBasisPoints, uint256 newFeeBasisPoints);
    event MixerAdded(uint256 indexed mixerId, address indexed token, uint256 denomination);
    event MixerDeactivated(uint256 indexed mixerId);
    event RelayerStatusChanged(address indexed relayer, bool status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRelayer() {
        if (!isRelayer[msg.sender]) revert NotAuthorizedRelayer();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(IVerifier _verifier) {
        if (address(_verifier) == address(0)) revert ZeroAddress();
        owner = msg.sender;
        verifier = _verifier;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function addMixer(address token, uint256 denomination) external onlyOwner returns (uint256) {
        if (token == address(0)) revert ZeroAddress();
        if (denomination == 0) revert InvalidDenomination();
        uint256 id = mixerCount++;
        mixers[id] = MixerInstance({token: token, denomination: denomination, active: true});
        emit MixerAdded(id, token, denomination);
        return id;
    }

    function deactivateMixer(uint256 mixerId) external onlyOwner {
        MixerInstance storage m = mixers[mixerId];
        if (m.token == address(0)) revert MixerDoesNotExist();
        if (!m.active) revert MixerInactive();
        m.active = false;
        emit MixerDeactivated(mixerId);
    }

    function setFee(uint256 newFeeBasisPoints) external onlyOwner {
        if (newFeeBasisPoints > FEE_BASIS_POINTS_MAX) revert InvalidFee();
        emit FeeUpdated(feeBasisPoints, newFeeBasisPoints);
        feeBasisPoints = newFeeBasisPoints;
    }

    function setRelayer(address relayer, bool status) external onlyOwner {
        if (relayer == address(0)) revert ZeroAddress();
        isRelayer[relayer] = status;
        emit RelayerStatusChanged(relayer, status);
    }

    function deposit(uint256 mixerId, bytes32 commitment) external nonReentrant {
        MixerInstance memory m = mixers[mixerId];
        if (m.token == address(0)) revert MixerDoesNotExist();
        if (!m.active) revert MixerInactive();
        if (commitment == bytes32(0)) revert InvalidParameters();
        if (commitments[commitment]) revert CommitmentAlreadySubmitted();

        commitments[commitment] = true;
        totalDeposits[m.token] += m.denomination;
        mixerDepositCount[mixerId] += 1;

        bool ok = IERC20(m.token).transferFrom(msg.sender, address(this), m.denomination);
        if (!ok) revert TransferFailed();

        emit Deposit(mixerId, m.token, commitment, m.denomination, block.timestamp);
    }

    function withdraw(
        uint256 mixerId,
        bytes32 nullifier,
        bytes32 root,
        uint256[2] memory proofA,
        uint256[2][2] memory proofB,
        uint256[2] memory proofC,
        address recipient
    ) external nonReentrant {
        ProofData memory proof = ProofData({a: proofA, b: proofB, c: proofC});
        _withdraw(mixerId, nullifier, root, proof, recipient, msg.sender);
    }

    function relayWithdraw(
        uint256 mixerId,
        bytes32 nullifier,
        bytes32 root,
        uint256[2] memory proofA,
        uint256[2][2] memory proofB,
        uint256[2] memory proofC,
        address recipient
    ) external nonReentrant onlyRelayer {
        ProofData memory proof = ProofData({a: proofA, b: proofB, c: proofC});
        _withdraw(mixerId, nullifier, root, proof, recipient, msg.sender);
    }

    function _withdraw(
        uint256 mixerId,
        bytes32 nullifier,
        bytes32 root,
        ProofData memory proof,
        address recipient,
        address relayer
    ) internal {
        MixerInstance memory m = mixers[mixerId];
        if (m.token == address(0)) revert MixerDoesNotExist();
        if (!m.active) revert MixerInactive();
        if (nullifier == bytes32(0)) revert InvalidParameters();
        if (nullifiers[nullifier]) revert NullifierAlreadySpent();
        if (recipient == address(0)) revert RecipientZero();

        _verifyAndTransfer(mixerId, m, nullifier, root, proof, recipient, relayer);
    }

    function _verifyAndTransfer(
        uint256 mixerId,
        MixerInstance memory m,
        bytes32 nullifier,
        bytes32 root,
        ProofData memory proof,
        address recipient,
        address relayer
    ) internal {
        uint256[5] memory inputs;
        inputs[0] = uint256(nullifier);
        inputs[1] = uint256(root);
        inputs[2] = mixerId;
        inputs[3] = m.denomination;
        inputs[4] = uint256(uint160(recipient));

        bool valid = verifier.verifyProof(proof.a, proof.b, proof.c, inputs);
        if (!valid) revert InvalidProof();

        nullifiers[nullifier] = true;
        totalDeposits[m.token] -= m.denomination;

        uint256 fee = (m.denomination * feeBasisPoints) / FEE_BASIS_POINTS_MAX;
        uint256 payout = m.denomination - fee;

        _payout(m.token, recipient, payout);
        if (fee > 0) {
            _payout(m.token, owner, fee);
        }

        emit Withdrawal(mixerId, m.token, recipient, nullifier, relayer, payout, fee);
    }

    function _payout(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function getMixer(uint256 mixerId) external view returns (address token, uint256 denomination, bool active) {
        MixerInstance memory m = mixers[mixerId];
        return (m.token, m.denomination, m.active);
    }

    function isCommitmentSpent(bytes32 commitment) external view returns (bool) {
        return commitments[commitment];
    }

    function isNullifierSpent(bytes32 nullifier) external view returns (bool) {
        return nullifiers[nullifier];
    }
}
