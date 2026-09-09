pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/// @title PaymentChannelEscrow
/// @notice Escrows fungible tokens for instant off-chain transfers between two channel
///         participants. A channel is opened with an on-chain deposit, balance updates are
///         applied via co-signed off-chain state transitions, and the channel is closed
///         on-chain to settle final balances.
contract PaymentChannelEscrow {
    /// @notice Minimum number of blocks a channel must remain open before it may be closed.
    uint256 public constant MIN_OPEN_BLOCKS = 100;

    /// @notice Default base fee (in token units) charged to the channel opener.
    uint256 public constant DEFAULT_BASE_FEE = 50;

    /// @notice The fungible token escrowed by this contract.
    IERC20 public immutable token;

    /// @notice Address permitted to adjust the base fee.
    address public owner;

    /// @notice Fee charged when opening a new channel.
    uint256 public baseFee;

    /// @dev Next channel id to be assigned by `openChannel`.
    uint256 private _nextChannelId = 1;

    struct Channel {
        address participant1;
        address participant2;
        uint256 balance1;
        uint256 balance2;
        uint256 totalDeposit;
        uint256 openBlock;
        uint256 nonce;
        bool open;
        bool closed;
    }

    mapping(uint256 => Channel) internal _channels;

    event ChannelOpened(
        uint256 indexed channelId,
        address indexed participant1,
        address indexed participant2,
        uint256 balance1,
        uint256 balance2,
        uint256 openBlock
    );
    event ChannelUpdated(
        uint256 indexed channelId,
        uint256 balance1,
        uint256 balance2,
        uint256 nonce
    );
    event ChannelClosed(
        uint256 indexed channelId,
        address indexed participant1,
        address indexed participant2,
        uint256 balance1,
        uint256 balance2
    );
    event BaseFeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error SelfParticipant();
    error ChannelNotFound();
    error ChannelNotOpen();
    error ChannelAlreadyClosed();
    error InsufficientDeposit();
    error ChannelTooYoung(uint256 openBlock, uint256 currentBlock, uint256 minCloseBlock);
    error InvalidSignature();
    error BalanceMismatch();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address token_, address owner_) {
        if (token_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        owner = owner_;
        baseFee = DEFAULT_BASE_FEE;
        emit OwnershipTransferred(address(0), owner_);
        emit BaseFeeUpdated(0, DEFAULT_BASE_FEE);
    }

    /// @notice Transfers contract ownership to a new account.
    /// @param newOwner Address of the new owner. Must not be the zero address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Updates the base fee charged when opening new channels.
    /// @param newFee New base fee value.
    function setBaseFee(uint256 newFee) external onlyOwner {
        uint256 old = baseFee;
        baseFee = newFee;
        emit BaseFeeUpdated(old, newFee);
    }

    /// @notice Opens a new channel funded by `msg.sender` (participant1) for off-chain
    ///         transfers with `participant2`. A flat `baseFee` is deducted from `deposit1`
    ///         and forwarded to the contract owner; the remainder becomes participant1's
    ///         starting on-chain balance. `participant2` starts with a zero balance and
    ///         receives funds only through co-signed state updates.
    /// @param participant2 The counterparty of the channel.
    /// @param deposit1     Total amount of tokens participant1 deposits (must be >= baseFee).
    /// @return channelId   Identifier of the newly created channel.
    function openChannel(address participant2, uint256 deposit1) external returns (uint256 channelId) {
        if (participant2 == address(0)) revert ZeroAddress();
        if (participant2 == msg.sender) revert SelfParticipant();
        if (deposit1 < baseFee) revert InsufficientDeposit();

        uint256 fee = baseFee;
        uint256 netBalance1 = deposit1 - fee;

        _safeTransferFrom(msg.sender, address(this), deposit1);
        _safeTransfer(owner, fee);

        channelId = _nextChannelId++;
        Channel storage c = _channels[channelId];
        c.participant1 = msg.sender;
        c.participant2 = participant2;
        c.balance1 = netBalance1;
        c.balance2 = 0;
        c.totalDeposit = netBalance1;
        c.openBlock = block.number;
        c.nonce = 0;
        c.open = true;
        c.closed = false;

        emit ChannelOpened(channelId, msg.sender, participant2, netBalance1, 0, block.number);
    }

    /// @notice Updates a channel's balances to a state that both participants have signed
    ///         off-chain. The sum of the two balances must equal the channel's total deposit.
    /// @param channelId    Identifier of the channel to update.
    /// @param newBalance1  Proposed balance of participant1.
    /// @param newBalance2  Proposed balance of participant2.
    /// @param sig1         EIP-191 signature over the state hash by participant1.
    /// @param sig2         EIP-191 signature over the state hash by participant2.
    function updateChannel(
        uint256 channelId,
        uint256 newBalance1,
        uint256 newBalance2,
        bytes calldata sig1,
        bytes calldata sig2
    ) external {
        Channel storage c = _channels[channelId];
        if (!c.open) revert ChannelNotOpen();
        if (c.closed) revert ChannelAlreadyClosed();
        if (newBalance1 + newBalance2 != c.totalDeposit) revert BalanceMismatch();

        uint256 nextNonce = c.nonce + 1;
        bytes32 stateHash = keccak256(
            abi.encodePacked(block.chainid, address(this), channelId, newBalance1, newBalance2, nextNonce)
        );

        address signer1 = _recoverSigner(stateHash, sig1);
        address signer2 = _recoverSigner(stateHash, sig2);
        if (signer1 != c.participant1 || signer2 != c.participant2) revert InvalidSignature();

        c.balance1 = newBalance1;
        c.balance2 = newBalance2;
        c.nonce = nextNonce;

        emit ChannelUpdated(channelId, newBalance1, newBalance2, nextNonce);
    }

    /// @notice Closes a channel and disburses the latest agreed balances on-chain.
    ///         Callable by anyone, but only after `MIN_OPEN_BLOCKS` have elapsed since opening.
    /// @param channelId Identifier of the channel to close.
    function closeChannel(uint256 channelId) external {
        Channel storage c = _channels[channelId];
        if (!c.open) revert ChannelNotFound();
        if (c.closed) revert ChannelAlreadyClosed();
        if (block.number < c.openBlock + MIN_OPEN_BLOCKS) {
            revert ChannelTooYoung(c.openBlock, block.number, c.openBlock + MIN_OPEN_BLOCKS);
        }

        address p1 = c.participant1;
        address p2 = c.participant2;
        uint256 b1 = c.balance1;
        uint256 b2 = c.balance2;

        // Checks-effects-interactions: mark closed before external token transfers.
        c.closed = true;
        c.open = false;

        if (b1 > 0) _safeTransfer(p1, b1);
        if (b2 > 0) _safeTransfer(p2, b2);

        emit ChannelClosed(channelId, p1, p2, b1, b2);
    }

    /// @notice Returns the full state of a channel.
    /// @param channelId Identifier of the channel.
    function getChannel(uint256 channelId)
        external
        view
        returns (
            address participant1,
            address participant2,
            uint256 balance1,
            uint256 balance2,
            uint256 totalDeposit,
            uint256 openBlock,
            uint256 nonce,
            bool open,
            bool closed
        )
    {
        Channel storage c = _channels[channelId];
        return (
            c.participant1,
            c.participant2,
            c.balance1,
            c.balance2,
            c.totalDeposit,
            c.openBlock,
            c.nonce,
            c.open,
            c.closed
        );
    }

    /// @notice Returns the latest balance recorded for `participant` within `channelId`.
    function balanceOf(uint256 channelId, address participant) external view returns (uint256) {
        Channel storage c = _channels[channelId];
        if (participant == c.participant1) return c.balance1;
        if (participant == c.participant2) return c.balance2;
        return 0;
    }

    /// @notice Returns the next channel id that will be assigned by `openChannel`.
    function nextChannelId() external view returns (uint256) {
        return _nextChannelId;
    }

    /// @dev Recovers the signer of an EIP-191 personal signature over `stateHash`.
    function _recoverSigner(bytes32 stateHash, bytes calldata sig) internal pure returns (address signer) {
        if (sig.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        // Guard against signature malleability.
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) revert InvalidSignature();
        if (v != 27 && v != 28) revert InvalidSignature();

        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", stateHash));
        signer = ecrecover(ethSigned, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
    }

    /// @dev Safe transfer wrapper that bubbles a failure as a custom error.
    function _safeTransfer(address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    /// @dev Safe transferFrom wrapper that bubbles a failure as a custom error.
    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert TransferFailed();
    }
}
