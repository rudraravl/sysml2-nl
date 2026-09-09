// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title L1L2Bridge
 * @notice Facilitates transfer of Ether and ERC-20 tokens between Layer 1 and
 *         Layer 2. Deposited assets are held in escrow on Layer 1. Withdrawals
 *         are proven against the latest Layer 2 state root and can be finalized
 *         only after a 7-day challenge period. A fixed fee of 0.001 Ether is
 *         deducted from each Ether withdrawal.
 */
contract L1L2Bridge {
    // ───────────────────────── Custom errors ─────────────────────────
    error OnlyOperator();
    error ZeroAddress();
    error ZeroAmount();
    error ContractPaused();
    error ContractNotPaused();
    error InvalidMerkleProof();
    error WithdrawalAlreadyProven();
    error WithdrawalNotProven();
    error WithdrawalAlreadyFinalized();
    error FinalizationTooEarly();
    error FeeExceedsAmount();
    error InsufficientEscrow();
    error EtherTransferFailed();
    error TokenTransferFailed();
    error InvalidParameters();

    // ───────────────────────────── Events ────────────────────────────
    event DepositInitiated(
        address indexed depositor,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );
    event WithdrawalProven(
        bytes32 indexed l2TxHash,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 provenAt
    );
    event WithdrawalFinalized(
        bytes32 indexed l2TxHash,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    event StateRootUpdated(bytes32 oldRoot, bytes32 newRoot, address indexed by);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeeCollectorUpdated(address indexed oldFeeCollector, address indexed newFeeCollector);
    event FeeWithdrawn(address indexed to, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // ─────────────────────────── Constants ────────────────────────────
    uint256 public constant WITHDRAWAL_FEE = 0.001 ether;
    uint256 public constant FINALIZATION_DELAY = 7 days;
    uint256 public constant MERKLE_DEPTH = 32;

    // ───────────────────────── State variables ───────────────────────
    address public operator;
    address public feeCollector;
    bytes32 public l2StateRoot;
    bool public paused;
    uint256 public accumulatedFees;

    struct Withdrawal {
        address recipient;
        address token; // address(0) for Ether
        uint256 amount;
        uint256 provenAt;
        bool finalized;
    }

    // L1 tx hash => L2 tx hash (for withdrawals)
    mapping(bytes32 => bytes32) public l1TxHashToL2TxHash;
    // L2 tx hash => withdrawal details
    mapping(bytes32 => Withdrawal) public withdrawals;
    // token => escrowed balance for withdrawals
    mapping(address => uint256) public escrowedBalances;

    // ─────────────────────────── Modifiers ───────────────────────────
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ─────────────────────────── Constructor ─────────────────────────
    constructor(address _operator, address _feeCollector, bytes32 _initialStateRoot) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeCollector == address(0)) revert ZeroAddress();
        operator = _operator;
        feeCollector = _feeCollector;
        l2StateRoot = _initialStateRoot;
        emit StateRootUpdated(bytes32(0), _initialStateRoot, msg.sender);
    }

    // ─────────────────────── Operator functions ──────────────────────
    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _newOperator);
        operator = _newOperator;
    }

    function setFeeCollector(address _newFeeCollector) external onlyOperator {
        if (_newFeeCollector == address(0)) revert ZeroAddress();
        emit FeeCollectorUpdated(feeCollector, _newFeeCollector);
        feeCollector = _newFeeCollector;
    }

    function updateL2StateRoot(bytes32 _newRoot) external onlyOperator {
        emit StateRootUpdated(l2StateRoot, _newRoot, msg.sender);
        l2StateRoot = _newRoot;
    }

    function setPaused(bool _paused) external onlyOperator {
        if (_paused) {
            if (paused) revert ContractPaused();
            paused = true;
            emit Paused(msg.sender);
        } else {
            if (!paused) revert ContractNotPaused();
            paused = false;
            emit Unpaused(msg.sender);
        }
    }

    function withdrawFees(address payable _to) external onlyOperator {
        if (_to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert ZeroAmount();
        accumulatedFees = 0;
        (bool ok, ) = _to.call{value: amount}("");
        if (!ok) revert EtherTransferFailed();
        emit FeeWithdrawn(_to, amount);
    }

    // ──────────────────────── Deposit functions ──────────────────────
    function depositEther(address _recipient) external payable whenNotPaused {
        if (_recipient == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert ZeroAmount();
        escrowedBalances[address(0)] += msg.value;
        emit DepositInitiated(msg.sender, _recipient, address(0), msg.value);
    }

    function depositERC20(address _token, uint256 _amount, address _recipient) external whenNotPaused {
        if (_token == address(0)) revert ZeroAddress();
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        bool ok = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!ok) revert TokenTransferFailed();
        escrowedBalances[_token] += _amount;
        emit DepositInitiated(msg.sender, _recipient, _token, _amount);
    }

    // ──────────────────── Prove withdrawal on L1 ─────────────────────
    /**
     * @notice Prove that an L2 withdrawal transaction is included in the L2
     *         state root. The proof is verified against the current root and,
     *         on success, a 7-day finalization delay begins.
     */
    function proveL2Transaction(
        bytes32 _l1TxHash,
        bytes32 _l2TxHash,
        address _recipient,
        address _token,
        uint256 _amount,
        bytes32[] calldata _proof
    ) external whenNotPaused {
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        if (withdrawals[_l2TxHash].provenAt != 0) revert WithdrawalAlreadyProven();
        if (withdrawals[_l2TxHash].finalized) revert WithdrawalAlreadyFinalized();
        if (_proof.length > MERKLE_DEPTH) revert InvalidParameters();

        bytes32 leaf = keccak256(abi.encode(_l2TxHash, _recipient, _token, _amount));
        if (!verifyMerkleProof(leaf, _proof, l2StateRoot)) revert InvalidMerkleProof();

        l1TxHashToL2TxHash[_l1TxHash] = _l2TxHash;
        withdrawals[_l2TxHash] = Withdrawal({
            recipient: _recipient,
            token: _token,
            amount: _amount,
            provenAt: block.timestamp,
            finalized: false
        });

        emit WithdrawalProven(_l2TxHash, _recipient, _token, _amount, block.timestamp);
    }

    // ───────────────────── Finalize withdrawal ───────────────────────
    /**
     * @notice Finalize a withdrawal after the 7-day challenge period. A fixed
     *         fee of 0.001 Ether is deducted from each Ether withdrawal.
     */
    function finalizeWithdrawal(bytes32 _l2TxHash) external whenNotPaused {
        Withdrawal storage w = withdrawals[_l2TxHash];
        if (w.provenAt == 0) revert WithdrawalNotProven();
        if (w.finalized) revert WithdrawalAlreadyFinalized();
        if (block.timestamp < w.provenAt + FINALIZATION_DELAY) revert FinalizationTooEarly();
        if (escrowedBalances[w.token] < w.amount) revert InsufficientEscrow();

        uint256 fee;
        uint256 payout;

        if (w.token == address(0)) {
            // Ether withdrawal with fee
            if (w.amount <= WITHDRAWAL_FEE) revert FeeExceedsAmount();
            fee = WITHDRAWAL_FEE;
            payout = w.amount - fee;
        } else {
            // ERC-20 withdrawal, no fee
            fee = 0;
            payout = w.amount;
        }

        // Effects
        w.finalized = true;
        escrowedBalances[w.token] -= w.amount;
        accumulatedFees += fee;

        // Interactions
        if (w.token == address(0)) {
            (bool ok, ) = payable(w.recipient).call{value: payout}("");
            if (!ok) revert EtherTransferFailed();
        } else {
            bool ok = IERC20(w.token).transfer(w.recipient, payout);
            if (!ok) revert TokenTransferFailed();
        }

        emit WithdrawalFinalized(_l2TxHash, w.recipient, w.token, payout, fee);
    }

    // ──────────────────────────── Views ───────────────────────────────
    function getWithdrawal(bytes32 _l2TxHash) external view returns (Withdrawal memory) {
        return withdrawals[_l2TxHash];
    }

    function isFinalizable(bytes32 _l2TxHash) external view returns (bool) {
        Withdrawal storage w = withdrawals[_l2TxHash];
        return w.provenAt != 0
            && !w.finalized
            && block.timestamp >= w.provenAt + FINALIZATION_DELAY;
    }

    function getL2TxHash(bytes32 _l1TxHash) external view returns (bytes32) {
        return l1TxHashToL2TxHash[_l1TxHash];
    }

    function getEscrowedBalance(address _token) external view returns (uint256) {
        return escrowedBalances[_token];
    }

    // ─────────────────────── Internal helpers ────────────────────────
    function verifyMerkleProof(
        bytes32 _leaf,
        bytes32[] calldata _proof,
        bytes32 _root
    ) internal pure returns (bool) {
        bytes32 computed = _leaf;
        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 sibling = _proof[i];
            if (computed < sibling) {
                computed = keccak256(abi.encode(computed, sibling));
            } else {
                computed = keccak256(abi.encode(sibling, computed));
            }
        }
        return computed == _root;
    }

    // ─────────────────────────── Receive ─────────────────────────────
    receive() external payable {
        revert("Use depositEther");
    }
}
