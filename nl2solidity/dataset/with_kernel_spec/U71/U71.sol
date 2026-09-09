// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

library MerkleProof {
    function verify(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        return computedHash == root;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
}

/**
 * @title TokenBridge
 * @notice Cross-chain token bridge that escrows native ERC-20 tokens on this network
 *         and redeems them against Merkle proofs of burns of the corresponding wrapped
 *         tokens on origin networks.
 *
 * Lifecycle:
 *   - `transfer`: escrows native tokens on this chain and emits `TokensDeposited`.
 *                 An off-chain relayer listening to the event instructs the destination
 *                 network's bridge to release/mint the wrapped counterpart to the recipient.
 *   - `redeem`:   verifies a Merkle proof (against `transferRoots[originNetwork]`) that the
 *                 wrapped tokens were burned on the origin network, then releases the
 *                 corresponding native tokens from escrow to the recipient on this chain.
 *
 * Fees:
 *   - A fee in basis points (`transferFeeBps`, at most 50 bps = 0.5%) is charged on each
 *     `transfer`. The fee accrues to the operator and is claimable via `collectFees`.
 *
 * Limits:
 *   - Minimum transfer/redeem amount is 1 unit of the token.
 */
contract TokenBridge is Ownable, ReentrancyGuard {
    /* ------------------------------- Constants ------------------------------ */

    /// @dev Maximum transfer fee in basis points. 0.5% = 50 bps.
    uint256 public constant MAX_FEE_BPS = 50;

    /// @dev Basis points denominator (100% = 10_000 bps).
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /// @dev Minimum transfer amount for any token, denominated in the token's
    ///      smallest unit (1 wei of the ERC-20 balance).
    uint256 public constant MIN_TRANSFER_AMOUNT = 1;

    /* -------------------------------- Storage ------------------------------- */

    /// @dev Identifier of the network this bridge is deployed on.
    uint256 public immutable thisNetworkId;

    /// @dev Transfer fee in basis points, capped at `MAX_FEE_BPS`.
    uint256 public transferFeeBps;

    /// @dev network => token => registered? Tokens that the bridge supports per network.
    mapping(uint256 => mapping(address => bool)) public registeredTokens;

    /// @dev network => wrapped token (on that network) => native token (on this chain).
    ///      Used to identify which native to release when a wrapped token is redeemed.
    mapping(uint256 => mapping(address => address)) public wrappedToNative;

    /// @dev network => native token (on this chain) => wrapped token (on that network).
    ///      Used to identify the destination wrapped token when transferring out.
    mapping(uint256 => mapping(address => address)) public nativeToWrapped;

    /// @dev origin network => Merkle root of confirmed transfers (wrapped burns on
    ///      that network).
    mapping(uint256 => bytes32) public transferRoots;

    /// @dev transfer key hash => processed. Prevents double redemption.
    mapping(bytes32 => bool) public processedTransfers;

    /// @dev token => amount currently escrowed (owed to future redeemers).
    mapping(address => uint256) public escrowBalances;

    /// @dev token => fees accrued and claimable by the operator.
    mapping(address => uint256) public accruedFees;

    /// @dev Sequential counter for transfer IDs originating on this chain.
    uint256 public nextTransferId;

    /* --------------------------------- Events -------------------------------- */

    event TokensDeposited(
        uint256 indexed transferId,
        address indexed token,
        address indexed sender,
        uint256 destNetwork,
        address recipient,
        uint256 amount,
        uint256 fee
    );

    event TokensRedeemed(
        uint256 indexed transferId,
        address indexed token,
        address recipient,
        uint256 amount
    );

    event TokenPairRegistered(
        uint256 indexed networkId,
        address indexed nativeToken,
        address indexed wrappedToken
    );

    event TransferFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    event TransferRootUpdated(uint256 indexed originNetwork, bytes32 oldRoot, bytes32 newRoot);

    event FeesCollected(address indexed token, address indexed recipient, uint256 amount);

    /* --------------------------------- Errors -------------------------------- */

    error ZeroAddress();
    error SameNetworkTransfer(uint256 networkId);
    error TokenNotRegistered(uint256 networkId, address token);
    error WrappedTokenNotConfigured(uint256 destNetwork, address nativeToken);
    error NativeTokenNotConfigured(uint256 originNetwork, address wrappedToken);
    error TransferFeeTooHigh(uint256 provided, uint256 maximum);
    error AmountBelowMinimum(uint256 amount, uint256 minimum);
    error TransferAlreadyProcessed(bytes32 transferKey);
    error TransferRootNotSet(uint256 originNetwork);
    error InvalidMerkleRoot();
    error InvalidTransferProof(bytes32 transferKey);
    error InsufficientEscrow(address token, uint256 available, uint256 required);
    error NoFeesToCollect(address token);
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    /* ------------------------------- Constructor ----------------------------- */

    constructor(uint256 thisNetworkId_, uint256 transferFeeBps_) Ownable(msg.sender) {
        if (transferFeeBps_ > MAX_FEE_BPS) {
            revert TransferFeeTooHigh(transferFeeBps_, MAX_FEE_BPS);
        }
        thisNetworkId = thisNetworkId_;
        transferFeeBps = transferFeeBps_;
        emit TransferFeeUpdated(0, transferFeeBps_);
    }

    /* ----------------------------- User Functions ----------------------------- */

    /**
     * @notice Deposit native tokens to bridge them to a destination network.
     * @param token       The native ERC-20 token address on this chain. Must be registered.
     * @param amount      The amount to deposit. Must be >= `MIN_TRANSFER_AMOUNT`.
     * @param destNetwork The destination network identifier.
     * @param recipient   The recipient address on the destination network (cannot be zero).
     * @return transferId The unique identifier assigned to this transfer.
     */
    function transfer(
        address token,
        uint256 amount,
        uint256 destNetwork,
        address recipient
    ) external nonReentrant returns (uint256 transferId) {
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount < MIN_TRANSFER_AMOUNT) revert AmountBelowMinimum(amount, MIN_TRANSFER_AMOUNT);
        if (destNetwork == thisNetworkId) revert SameNetworkTransfer(destNetwork);
        if (!registeredTokens[thisNetworkId][token]) {
            revert TokenNotRegistered(thisNetworkId, token);
        }

        address wrappedToken = nativeToWrapped[destNetwork][token];
        if (wrappedToken == address(0)) {
            revert WrappedTokenNotConfigured(destNetwork, token);
        }
        if (!registeredTokens[destNetwork][wrappedToken]) {
            revert TokenNotRegistered(destNetwork, wrappedToken);
        }

        uint256 fee = (amount * transferFeeBps) / BPS_DENOMINATOR;
        uint256 escrowAmount = amount - fee;

        // Effects
        transferId = nextTransferId++;
        escrowBalances[token] += escrowAmount;
        if (fee > 0) {
            accruedFees[token] += fee;
        }

        // Interactions: pull the full amount into escrow (escrow + fees)
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit TokensDeposited(transferId, token, msg.sender, destNetwork, recipient, amount, fee);
    }

    /**
     * @notice Redeem native tokens by presenting a Merkle proof that the corresponding
     *         wrapped tokens were burned on the origin network.
     * @param transferId    The unique transfer identifier assigned on the origin network.
     * @param originNetwork The network where the wrapped tokens were burned.
     * @param originToken   The wrapped token address on the origin network.
     * @param recipient     The recipient address on this chain.
     * @param amount        The amount of native tokens to release.
     * @param proof         Merkle proof verifying the transfer against `transferRoots[originNetwork]`.
     */
    function redeem(
        uint256 transferId,
        uint256 originNetwork,
        address originToken,
        address recipient,
        uint256 amount,
        bytes32[] calldata proof
    ) external nonReentrant {
        if (originToken == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount < MIN_TRANSFER_AMOUNT) revert AmountBelowMinimum(amount, MIN_TRANSFER_AMOUNT);
        if (originNetwork == thisNetworkId) revert SameNetworkTransfer(originNetwork);

        address nativeToken = wrappedToNative[originNetwork][originToken];
        if (nativeToken == address(0)) {
            revert NativeTokenNotConfigured(originNetwork, originToken);
        }

        bytes32 transferKey = _transferKey(transferId, originNetwork, originToken, recipient, amount);
        if (processedTransfers[transferKey]) {
            revert TransferAlreadyProcessed(transferKey);
        }

        bytes32 root = transferRoots[originNetwork];
        if (root == bytes32(0)) {
            revert TransferRootNotSet(originNetwork);
        }

        bytes32 leaf = _transferLeaf(transferId, originNetwork, originToken, recipient, amount);
        if (!MerkleProof.verify(proof, root, leaf)) {
            revert InvalidTransferProof(transferKey);
        }

        // Effects
        processedTransfers[transferKey] = true;
        uint256 available = escrowBalances[nativeToken];
        if (available < amount) {
            revert InsufficientEscrow(nativeToken, available, amount);
        }
        unchecked {
            escrowBalances[nativeToken] = available - amount;
        }

        // Interactions
        _safeTransfer(nativeToken, recipient, amount);

        emit TokensRedeemed(transferId, nativeToken, recipient, amount);
    }

    /* --------------------------- Operator Functions -------------------------- */

    /**
     * @notice Register a token pair: a native token on this chain and its wrapped
     *         counterpart on another network.
     * @param networkId    The destination network where the wrapped token lives.
     * @param nativeToken  The native token on this chain.
     * @param wrappedToken The wrapped token on `networkId`.
     */
    function registerToken(
        uint256 networkId,
        address nativeToken,
        address wrappedToken
    ) external onlyOwner {
        if (networkId == thisNetworkId) revert SameNetworkTransfer(networkId);
        if (nativeToken == address(0) || wrappedToken == address(0)) revert ZeroAddress();

        registeredTokens[thisNetworkId][nativeToken] = true;
        registeredTokens[networkId][wrappedToken] = true;

        nativeToWrapped[networkId][nativeToken] = wrappedToken;
        wrappedToNative[networkId][wrappedToken] = nativeToken;

        emit TokenPairRegistered(networkId, nativeToken, wrappedToken);
    }

    /**
     * @notice Update the transfer fee in basis points. Capped at `MAX_FEE_BPS` (0.5%).
     * @param newFeeBps The new fee in basis points.
     */
    function setTransferFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) {
            revert TransferFeeTooHigh(newFeeBps, MAX_FEE_BPS);
        }
        uint256 old = transferFeeBps;
        transferFeeBps = newFeeBps;
        emit TransferFeeUpdated(old, newFeeBps);
    }

    /**
     * @notice Update the Merkle root of confirmed transfers for an origin network.
     * @param originNetwork The origin network whose root is being updated.
     * @param newRoot        The new Merkle root (cannot be zero).
     */
    function setTransferRoot(uint256 originNetwork, bytes32 newRoot) external onlyOwner {
        if (originNetwork == thisNetworkId) revert SameNetworkTransfer(originNetwork);
        if (newRoot == bytes32(0)) revert InvalidMerkleRoot();
        bytes32 old = transferRoots[originNetwork];
        transferRoots[originNetwork] = newRoot;
        emit TransferRootUpdated(originNetwork, old, newRoot);
    }

    /**
     * @notice Collect accrued fees for a given token.
     * @param token     The token whose fees should be collected.
     * @param recipient The recipient of the collected fees.
     */
    function collectFees(address token, address recipient) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees[token];
        if (amount == 0) revert NoFeesToCollect(token);

        accruedFees[token] = 0;
        _safeTransfer(token, recipient, amount);
        emit FeesCollected(token, recipient, amount);
    }

    /* --------------------------------- Views --------------------------------- */

    /**
     * @notice Returns the wrapped token address on `networkId` corresponding to the
     *         native `token` on this chain.
     */
    function getWrappedToken(uint256 networkId, address token) external view returns (address) {
        return nativeToWrapped[networkId][token];
    }

    /**
     * @notice Returns the native token on this chain corresponding to a wrapped token
     *         on `networkId`.
     */
    function getNativeToken(uint256 networkId, address wrappedToken) external view returns (address) {
        return wrappedToNative[networkId][wrappedToken];
    }

    /**
     * @notice Compute the Merkle leaf for a given redemption.
     */
    function transferLeaf(
        uint256 transferId,
        uint256 originNetwork,
        address originToken,
        address recipient,
        uint256 amount
    ) external pure returns (bytes32) {
        return _transferLeaf(transferId, originNetwork, originToken, recipient, amount);
    }

    /**
     * @notice Compute the transfer key used for double-redemption protection.
     */
    function transferKey(
        uint256 transferId,
        uint256 originNetwork,
        address originToken,
        address recipient,
        uint256 amount
    ) external pure returns (bytes32) {
        return _transferKey(transferId, originNetwork, originToken, recipient, amount);
    }

    /* ------------------------------- Internal -------------------------------- */

    function _transferLeaf(
        uint256 transferId,
        uint256 originNetwork,
        address originToken,
        address recipient,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(transferId, originNetwork, originToken, recipient, amount)
        );
    }

    function _transferKey(
        uint256 transferId,
        uint256 originNetwork,
        address originToken,
        address recipient,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(transferId, originNetwork, originToken, recipient, amount)
        );
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFromFailed();
        }
    }
}
