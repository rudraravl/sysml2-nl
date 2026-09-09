// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IExternalRecord {
    /// @notice Verifies that `account` owns `amount` of the underlying asset in the external system.
    /// @dev The external system is responsible for validating and consuming the proof to prevent replay.
    function verifyOwnershipProof(
        address account,
        uint256 amount,
        bytes calldata proof
    ) external returns (bool valid);

    /// @notice Notifies the external system that `netAmount` of the underlying asset should be released to `receiver`.
    function notifyRedemption(
        address account,
        address receiver,
        uint256 amount
    ) external;
}

/**
 * @title TokenizedUSTreasury
 * @notice Tokenized representation of short-term U.S. government debt.
 *         The contract holds no custodied assets; all underlying ownership is
 *         recorded and settled by an external system of record.
 */
contract TokenizedUSTreasury {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error Paused();
    error NotAuthorized();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidProof();
    error ProofAlreadyUsed();
    error FeeExceedsCap();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ReentrantCall();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Mint(
        address indexed minter,
        address indexed to,
        uint256 amount,
        bytes32 indexed proofHash
    );
    event Redeem(
        address indexed from,
        address indexed receiver,
        uint256 grossAmount,
        uint256 feeAmount
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event PausedStatusChanged(bool isPaused);
    event OperatorUpdated(
        address indexed oldOperator,
        address indexed newOperator
    );

    // -----------------------------------------------------------------------
    // Metadata & Constants
    // -----------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 6;
    /// @dev Maximum redemption fee in basis points (0.5%).
    uint256 public constant FEE_CAP_BPS = 50;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public operator;
    address public feeRecipient;
    uint256 public redemptionFeeBps;
    bool public paused;

    IExternalRecord public immutable externalRecord;
    mapping(bytes32 => bool) public usedProofs;

    // -----------------------------------------------------------------------
    // Reentrancy guard
    // -----------------------------------------------------------------------
    uint256 private _status = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = 1;
    }

    // -----------------------------------------------------------------------
    // Access control
    // -----------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    /**
     * @param _externalRecord Address of the external system-of-record contract.
     * @param _operator       Address authorised to pause and adjust fees.
     * @param _feeRecipient   Address that receives redemption fees (defaults to operator if zero).
     * @param _initialFeeBps  Initial redemption fee in basis points (max 50).
     */
    constructor(
        address _externalRecord,
        address _operator,
        address _feeRecipient,
        uint256 _initialFeeBps
    ) {
        if (_externalRecord == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_initialFeeBps > FEE_CAP_BPS) revert FeeExceedsCap();

        externalRecord = IExternalRecord(_externalRecord);
        operator = _operator;
        feeRecipient = _feeRecipient == address(0) ? _operator : _feeRecipient;
        redemptionFeeBps = _initialFeeBps;
        name = "Tokenized US Treasury";
        symbol = "tUST";

        emit FeeUpdated(0, _initialFeeBps);
        emit FeeRecipientUpdated(address(0), feeRecipient);
        emit OperatorUpdated(address(0), _operator);
    }

    // -----------------------------------------------------------------------
    // Minting
    // -----------------------------------------------------------------------
    /**
     * @notice Mint tokens to `to` by proving ownership of `amount` underlying
     *         assets in the external system.
     * @dev Follows checks-effects-interactions: all state is updated before
     *      the external verification call. A revert from the external call or
     *      an invalid proof rolls back all state changes.
     * @param to     Recipient of minted tokens.
     * @param amount Number of tokens to mint (same denomination as underlying).
     * @param proof  Opaque proof consumed by the external record for validation.
     */
    function mint(
        address to,
        uint256 amount,
        bytes calldata proof
    ) external whenNotPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        bytes32 proofHash = keccak256(
            abi.encode(msg.sender, to, amount, proof)
        );
        if (usedProofs[proofHash]) revert ProofAlreadyUsed();

        // Effects — commit all state changes before any external interaction.
        // If verification fails below, the revert restores this state.
        usedProofs[proofHash] = true;
        balanceOf[to] += amount;
        totalSupply += amount;

        // Interaction — verify ownership with the external system of record.
        bool valid = externalRecord.verifyOwnershipProof(
            msg.sender,
            amount,
            proof
        );
        if (!valid) revert InvalidProof();

        emit Mint(msg.sender, to, amount, proofHash);
        emit Transfer(address(0), to, amount);
    }

    // -----------------------------------------------------------------------
    // ERC-20 transfer / approval
    // -----------------------------------------------------------------------
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();

        balanceOf[msg.sender] = senderBalance - amount;
        balanceOf[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        if (sender == address(0) || recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 senderBalance = balanceOf[sender];
        if (senderBalance < amount) revert InsufficientBalance();

        uint256 allowed = allowance[sender][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        // Effects
        if (allowed != type(uint256).max) {
            allowance[sender][msg.sender] = allowed - amount;
        }
        balanceOf[sender] = senderBalance - amount;
        balanceOf[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Redemption
    // -----------------------------------------------------------------------
    /**
     * @notice Redeem `amount` tokens for the underlying asset. A configurable
     *         fee (capped at 0.5%) is deducted and routed to `feeRecipient`;
     *         only the net amount is burned and released by the external record.
     * @param amount   Gross number of tokens to redeem.
     * @param receiver Address that should receive the underlying asset.
     */
    function redeem(
        uint256 amount,
        address receiver
    ) external whenNotPaused nonReentrant {
        if (receiver == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < amount) revert InsufficientBalance();

        uint256 fee = (amount * redemptionFeeBps) / BPS_DENOMINATOR;
        uint256 net = amount - fee;

        // Effects — all state changes before external interaction.
        balanceOf[msg.sender] = senderBalance - amount;
        totalSupply -= net;

        if (fee > 0) {
            balanceOf[feeRecipient] += fee;
            emit Transfer(msg.sender, feeRecipient, fee);
        }

        emit Transfer(msg.sender, address(0), net);
        emit Redeem(msg.sender, receiver, amount, fee);

        // Interaction — notify external system to release underlying.
        externalRecord.notifyRedemption(msg.sender, receiver, net);
    }

    // -----------------------------------------------------------------------
    // Operator administration
    // -----------------------------------------------------------------------
    /**
     * @notice Pause or unpause minting and redemption.
     */
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedStatusChanged(_paused);
    }

    /**
     * @notice Update the redemption fee. Capped at 0.5% (50 bps).
     */
    function setRedemptionFee(uint256 _feeBps) external onlyOperator {
        if (_feeBps > FEE_CAP_BPS) revert FeeExceedsCap();
        uint256 old = redemptionFeeBps;
        redemptionFeeBps = _feeBps;
        emit FeeUpdated(old, _feeBps);
    }

    /**
     * @notice Update the address that receives redemption fees.
     */
    function setFeeRecipient(address _feeRecipient) external onlyOperator {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(old, _feeRecipient);
    }

    /**
     * @notice Transfer operator privileges to a new address.
     */
    function setOperator(address _operator) external onlyOperator {
        if (_operator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = _operator;
        emit OperatorUpdated(old, _operator);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------
    /**
     * @dev Convenience view for off-chain fee calculation.
     */
    function previewRedeemFee(
        uint256 amount
    ) external view returns (uint256 fee, uint256 net) {
        fee = (amount * redemptionFeeBps) / BPS_DENOMINATOR;
        net = amount - fee;
    }
}
