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

/// @title PrivateTransfer
/// @notice Custodies fungible tokens and issues private "notes" that obscure the
///         link between deposits and withdrawals. Deposits mint notes; withdrawals
///         must spend at least two existing notes.
contract PrivateTransfer {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientNotes();
    error NoteAlreadySpent();
    error NoteNotOwned();
    error NoteNotFound();
    error FeeTooHigh();
    error SafeTransferFailed();
    error SafeTransferFromFailed();
    error DuplicateCommitment();
    error Reentrancy();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(
        address indexed depositor,
        bytes32 indexed commitment,
        uint256 noteAmount,
        uint256 fee
    );
    event Withdrawal(
        address indexed withdrawer,
        bytes32[] spentCommitments,
        uint256 totalAmount
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OperatorUpdated(address oldOperator, address newOperator);

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    struct Note {
        bytes32 commitment;
        uint256 amount;
    }

    /// @notice Token custodied by this contract.
    IERC20 public immutable token;

    /// @notice Address permitted to update the deposit fee and operator.
    address public operator;

    /// @notice Deposit fee in basis points (5 = 0.05%).
    uint256 public depositFeeBps;

    /// @dev Maximum permitted fee: 10%.
    uint256 public constant MAX_FEE_BPS = 1000;

    /// @notice Sum of the amounts of all unspent notes.
    uint256 public totalNoteSupply;

    /// @notice Per-user set of unspent notes.
    mapping(address => Note[]) public notes;

    /// @notice Whether a note commitment has been spent.
    mapping(bytes32 => bool) public spent;

    /// @notice Owner of a given note commitment.
    mapping(bytes32 => address) public noteOwner;

    /// @notice Amount recorded for a given note commitment.
    mapping(bytes32 => uint256) public noteAmount;

    /// @dev Reentrancy guard.
    bool private locked;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _token, address _operator) {
        if (_token == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        token = IERC20(_token);
        operator = _operator;
        depositFeeBps = 5; // 0.05%
    }

    /*//////////////////////////////////////////////////////////////
                              DEPOSIT
    //////////////////////////////////////////////////////////////*/
    /// @notice Deposits `amount` of the custodied token, deducting a fee and
    ///         crediting the caller with a single private note of `amount - fee`.
    /// @param amount Total tokens to deposit (inclusive of fee).
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * depositFeeBps) / 10000;
        uint256 netAmount = amount - fee;

        // Pull the full amount (principal + fee) from the depositor.
        _safeTransferFrom(msg.sender, address(this), amount);

        // Mint a private note for the depositor.
        bytes32 commitment = _computeCommitment(
            msg.sender,
            netAmount,
            block.timestamp,
            notes[msg.sender].length
        );

        if (noteOwner[commitment] != address(0)) revert DuplicateCommitment();

        notes[msg.sender].push(Note(commitment, netAmount));
        noteOwner[commitment] = msg.sender;
        noteAmount[commitment] = netAmount;
        totalNoteSupply += netAmount;

        emit Deposit(msg.sender, commitment, netAmount, fee);
    }

    /*//////////////////////////////////////////////////////////////
                             WITHDRAW
    //////////////////////////////////////////////////////////////*/
    /// @notice Withdraws tokens by spending at least two existing private notes
    ///         owned by the caller. The sum of the spent notes is transferred out.
    /// @param commitmentsToSpend Note commitments to consume.
    function withdraw(bytes32[] calldata commitmentsToSpend) external nonReentrant {
        if (commitmentsToSpend.length < 2) revert InsufficientNotes();

        uint256 total = 0;
        for (uint256 i = 0; i < commitmentsToSpend.length; i++) {
            bytes32 c = commitmentsToSpend[i];

            if (spent[c]) revert NoteAlreadySpent();
            if (noteOwner[c] != msg.sender) revert NoteNotOwned();

            uint256 amt = noteAmount[c];
            if (amt == 0) revert NoteNotFound();

            // Effects: mark spent and remove from the user's note set.
            spent[c] = true;
            _removeNote(msg.sender, c);

            total += amt;
        }

        totalNoteSupply -= total;

        // Interaction: send tokens to the caller.
        _safeTransfer(msg.sender, total);

        emit Withdrawal(msg.sender, commitmentsToSpend, total);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Updates the deposit fee (in basis points).
    /// @param newFeeBps New fee in basis points; must not exceed MAX_FEE_BPS.
    function setDepositFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = depositFeeBps;
        depositFeeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    /// @notice Transfers operator role to a new address.
    /// @param newOperator Address of the new operator.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorUpdated(old, newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the number of unspent notes owned by `user`.
    function noteCount(address user) external view returns (uint256) {
        return notes[user].length;
    }

    /// @notice Returns a specific note owned by `user`.
    function getNote(address user, uint256 index) external view returns (bytes32 commitment, uint256 amount) {
        Note storage n = notes[user][index];
        return (n.commitment, n.amount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _computeCommitment(
        address owner,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, amount, timestamp, nonce));
    }

    /// @dev Removes a note commitment from the user's note array via swap-and-pop.
    function _removeNote(address user, bytes32 commitment) internal {
        Note[] storage userNotes = notes[user];
        uint256 len = userNotes.length;
        for (uint256 i = 0; i < len; i++) {
            if (userNotes[i].commitment == commitment) {
                if (i != len - 1) {
                    userNotes[i] = userNotes[len - 1];
                }
                userNotes.pop();
                return;
            }
        }
        revert NoteNotFound();
    }

    /// @dev Safe transfer that reverts on failure.
    function _safeTransfer(address recipient, uint256 amount) internal {
        bool success = token.transfer(recipient, amount);
        if (!success) revert SafeTransferFailed();
    }

    /// @dev Safe transferFrom that reverts on failure.
    function _safeTransferFrom(address sender, address recipient, uint256 amount) internal {
        bool success = token.transferFrom(sender, recipient, amount);
        if (!success) revert SafeTransferFromFailed();
    }
}
