// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
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
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract ParlayPredictions is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error InvalidStake();
    error InvalidOutcomeCount();
    error InvalidMultiplier();
    error ParlayNotOpen();
    error ParlayClosed();
    error AlreadyJoined();
    error NotParticipant();
    error NotSettled();
    error AlreadySettled();
    error AlreadyClaimed();
    error DuplicateOutcome();
    error NotOperator();
    error InvalidParlayId();
    error InvalidOutcomeIndex();
    error NothingToClaim();
    error InvalidStatus();

    event ParlayCreated(uint256 indexed parlayId, address indexed creator, uint256 stake, uint8 outcomeCount);
    event ParlayJoined(uint256 indexed parlayId, address indexed user, uint256 stake);
    event OutcomeSettled(uint256 indexed parlayId, uint256 indexed outcomeId, bool indexed won);
    event ParlayStatusUpdated(uint256 indexed parlayId, uint8 status);
    event Claimed(uint256 indexed parlayId, address indexed user, uint256 payout, uint256 fee);
    event OperatorUpdated(address indexed operator, bool allowed);
    event FeeRecipientUpdated(address indexed feeRecipient);
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    uint256 public constant PROTOCOL_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint8 public constant MIN_PREDICTIONS = 2;
    uint8 public constant MAX_PREDICTIONS = 10;

    enum ParlayStatus {
        Open,
        Settling,
        Settled,
        Cancelled
    }

    enum OutcomeStatus {
        Pending,
        Won,
        Lost
    }

    struct Outcome {
        bytes32 outcomeKey;
        OutcomeStatus status;
    }

    struct Parlay {
        address creator;
        uint256 stake;
        uint256 payoutMultiplierBps;
        uint8 outcomeCount;
        ParlayStatus status;
        bool fullySettled;
        Outcome[] outcomes;
        address[] participants;
        mapping(address => bool) hasJoined;
        mapping(address => bool) hasClaimed;
        uint256 totalPool;
    }

    IERC20 public immutable stablecoin;

    mapping(address => bool) public operators;
    address public feeRecipient;

    mapping(uint256 => Parlay) public parlays;
    uint256 public parlayCount;

    uint256 public accumulatedFees;

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    modifier validParlayId(uint256 parlayId) {
        if (parlayId >= parlayCount) revert InvalidParlayId();
        _;
    }

    constructor(address _stablecoin, address _feeRecipient, address _operator) Ownable(msg.sender) {
        if (_stablecoin == address(0) || _feeRecipient == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        stablecoin = IERC20(_stablecoin);
        feeRecipient = _feeRecipient;
        operators[_operator] = true;

        emit OperatorUpdated(_operator, true);
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function setOperator(address operator, bool allowed) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = allowed;
        emit OperatorUpdated(operator, allowed);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NothingToClaim();
        accumulatedFees = 0;
        stablecoin.safeTransfer(feeRecipient, amount);
        emit FeesWithdrawn(feeRecipient, amount);
    }

    function createParlay(
        bytes32[] calldata outcomeKeys,
        uint256 stake,
        uint256 payoutMultiplierBps
    ) external nonReentrant returns (uint256 parlayId) {
        if (stake == 0) revert InvalidStake();
        if (outcomeKeys.length < MIN_PREDICTIONS || outcomeKeys.length > MAX_PREDICTIONS) {
            revert InvalidOutcomeCount();
        }
        if (payoutMultiplierBps == 0) revert InvalidMultiplier();

        for (uint256 i = 0; i < outcomeKeys.length; ++i) {
            for (uint256 j = i + 1; j < outcomeKeys.length; ++j) {
                if (outcomeKeys[i] == outcomeKeys[j]) revert DuplicateOutcome();
            }
        }

        parlayId = parlayCount++;
        Parlay storage p = parlays[parlayId];

        p.creator = msg.sender;
        p.stake = stake;
        p.payoutMultiplierBps = payoutMultiplierBps;
        p.outcomeCount = uint8(outcomeKeys.length);
        p.status = ParlayStatus.Open;

        for (uint256 i = 0; i < outcomeKeys.length; ++i) {
            p.outcomes.push(Outcome({outcomeKey: outcomeKeys[i], status: OutcomeStatus.Pending}));
        }

        p.participants.push(msg.sender);
        p.hasJoined[msg.sender] = true;
        p.totalPool = stake;

        stablecoin.safeTransferFrom(msg.sender, address(this), stake);

        emit ParlayCreated(parlayId, msg.sender, stake, uint8(outcomeKeys.length));
        emit ParlayJoined(parlayId, msg.sender, stake);
    }

    function joinParlay(uint256 parlayId) external nonReentrant validParlayId(parlayId) {
        Parlay storage p = parlays[parlayId];
        if (p.status != ParlayStatus.Open) revert ParlayNotOpen();
        if (p.hasJoined[msg.sender]) revert AlreadyJoined();

        p.hasJoined[msg.sender] = true;
        p.participants.push(msg.sender);
        p.totalPool += p.stake;

        stablecoin.safeTransferFrom(msg.sender, address(this), p.stake);

        emit ParlayJoined(parlayId, msg.sender, p.stake);
    }

    function claim(uint256 parlayId) external nonReentrant validParlayId(parlayId) {
        Parlay storage p = parlays[parlayId];
        if (p.status != ParlayStatus.Settled) revert NotSettled();
        if (!p.hasJoined[msg.sender]) revert NotParticipant();
        if (p.hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (!p.fullySettled) revert NothingToClaim();

        p.hasClaimed[msg.sender] = true;

        // Compute fee from the raw product before any division to avoid
        // divide-before-multiply precision loss.
        uint256 rawPayout = p.stake * p.payoutMultiplierBps;
        uint256 fee = (rawPayout * PROTOCOL_FEE_BPS) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
        uint256 grossPayout = rawPayout / BPS_DENOMINATOR;
        uint256 netPayout = grossPayout - fee;

        accumulatedFees += fee;
        stablecoin.safeTransfer(msg.sender, netPayout);

        emit Claimed(parlayId, msg.sender, netPayout, fee);
    }

    function settleOutcome(uint256 parlayId, uint256 outcomeId, bool won)
        external
        onlyOperator
        validParlayId(parlayId)
    {
        Parlay storage p = parlays[parlayId];
        if (p.status == ParlayStatus.Settled || p.status == ParlayStatus.Cancelled) revert ParlayClosed();
        if (outcomeId >= p.outcomeCount) revert InvalidOutcomeIndex();

        Outcome storage o = p.outcomes[outcomeId];
        if (o.status != OutcomeStatus.Pending) revert AlreadySettled();

        o.status = won ? OutcomeStatus.Won : OutcomeStatus.Lost;

        emit OutcomeSettled(parlayId, outcomeId, won);

        if (!won) {
            p.fullySettled = false;
            p.status = ParlayStatus.Settled;
            emit ParlayStatusUpdated(parlayId, uint8(ParlayStatus.Settled));
            return;
        }

        bool allWon = true;
        for (uint256 i = 0; i < p.outcomeCount; ++i) {
            if (p.outcomes[i].status != OutcomeStatus.Won) {
                allWon = false;
                break;
            }
        }

        if (allWon) {
            p.fullySettled = true;
            p.status = ParlayStatus.Settled;
            emit ParlayStatusUpdated(parlayId, uint8(ParlayStatus.Settled));
        } else if (p.status == ParlayStatus.Open) {
            p.status = ParlayStatus.Settling;
            emit ParlayStatusUpdated(parlayId, uint8(ParlayStatus.Settling));
        }
    }

    function cancelParlay(uint256 parlayId) external onlyOperator validParlayId(parlayId) {
        Parlay storage p = parlays[parlayId];
        if (p.status == ParlayStatus.Settled || p.status == ParlayStatus.Cancelled) revert ParlayClosed();
        p.status = ParlayStatus.Cancelled;
        emit ParlayStatusUpdated(parlayId, uint8(ParlayStatus.Cancelled));
    }

    function refundCancelled(uint256 parlayId) external nonReentrant validParlayId(parlayId) {
        Parlay storage p = parlays[parlayId];
        if (p.status != ParlayStatus.Cancelled) revert InvalidStatus();
        if (!p.hasJoined[msg.sender]) revert NotParticipant();
        if (p.hasClaimed[msg.sender]) revert AlreadyClaimed();

        p.hasClaimed[msg.sender] = true;
        stablecoin.safeTransfer(msg.sender, p.stake);

        emit Claimed(parlayId, msg.sender, p.stake, 0);
    }

    function getParlay(uint256 parlayId)
        external
        view
        validParlayId(parlayId)
        returns (
            address creator,
            uint256 stake,
            uint256 payoutMultiplierBps,
            uint8 outcomeCount,
            uint8 status,
            bool fullySettled,
            uint256 totalPool,
            uint256 participantCount
        )
    {
        Parlay storage p = parlays[parlayId];
        return (
            p.creator,
            p.stake,
            p.payoutMultiplierBps,
            p.outcomeCount,
            uint8(p.status),
            p.fullySettled,
            p.totalPool,
            uint256(p.participants.length)
        );
    }

    function getOutcome(uint256 parlayId, uint256 outcomeId)
        external
        view
        validParlayId(parlayId)
        returns (bytes32 outcomeKey, uint8 status)
    {
        Parlay storage p = parlays[parlayId];
        if (outcomeId >= p.outcomeCount) revert InvalidOutcomeIndex();
        Outcome storage o = p.outcomes[outcomeId];
        return (o.outcomeKey, uint8(o.status));
    }

    function getParticipant(uint256 parlayId, uint256 index)
        external
        view
        validParlayId(parlayId)
        returns (address)
    {
        return parlays[parlayId].participants[index];
    }

    function hasJoined(uint256 parlayId, address user) external view validParlayId(parlayId) returns (bool) {
        return parlays[parlayId].hasJoined[user];
    }

    function hasClaimed(uint256 parlayId, address user) external view validParlayId(parlayId) returns (bool) {
        return parlays[parlayId].hasClaimed[user];
    }
}
