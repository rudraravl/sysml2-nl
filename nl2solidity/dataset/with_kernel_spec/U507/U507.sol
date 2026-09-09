// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address token, uint256 requested, uint256 current);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert SafeERC20FailedOperation(address(token));
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
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
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract Launchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ErrZeroAddress();
    error ErrUnauthorized();
    error ErrRoundNotFound(uint256 roundId);
    error ErrRoundNotPending(uint256 roundId);
    error ErrRoundNotActive(uint256 roundId);
    error ErrRoundNotFunded(uint256 roundId);
    error ErrRoundNotFailed(uint256 roundId);
    error ErrRoundNotDistributed(uint256 roundId);
    error ErrRoundAlreadyDistributed(uint256 roundId);
    error ErrMaxParticipantsReached();
    error ErrDepositZero();
    error ErrDepositBelowMin(uint256 minDeposit);
    error ErrDepositAboveMax(uint256 maxDeposit);
    error ErrHardCapExceeded();
    error ErrNothingToClaim();
    error ErrNothingToWithdraw();
    error ErrVestingNotConfigured();
    error ErrInvalidVestingSchedule();
    error ErrInvalidTimeRange();
    error ErrInvalidCap();
    error ErrInsufficientProjectTokens();
    error ErrRoundNotEnded(uint256 roundId);

    enum RoundState {
        Pending,
        Active,
        Funded,
        Failed,
        Distributed
    }

    struct VestingSchedule {
        uint256 start;
        uint256 cliff;
        uint256 duration;
    }

    struct RoundView {
        address projectToken;
        address paymentToken;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 hardCap;
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        uint256 totalAllocated;
        uint256 totalClaimed;
        uint256 participantCount;
        RoundState state;
        uint256 vestingStart;
        uint256 vestingCliff;
        uint256 vestingDuration;
    }

    struct Round {
        IERC20 projectToken;
        IERC20 paymentToken;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 hardCap;
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        uint256 totalAllocated;
        uint256 totalClaimed;
        uint256 participantCount;
        RoundState state;
        VestingSchedule vesting;
        mapping(address => uint256) deposited;
        mapping(address => uint256) claimed;
        mapping(address => bool) isParticipant;
    }

    address public operator;
    uint256 public constant MAX_PARTICIPANTS = 500;
    uint256 public constant FEE_BPS = 200;

    mapping(uint256 => Round) private rounds;
    uint256 public roundCount;

    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event RoundCreated(
        uint256 indexed roundId,
        address indexed projectToken,
        address indexed paymentToken,
        uint256 tokenPrice,
        uint256 softCap,
        uint256 hardCap,
        uint256 startTime,
        uint256 endTime
    );
    event VestingConfigured(uint256 indexed roundId, uint256 start, uint256 cliff, uint256 duration);
    event RoundStateChanged(uint256 indexed roundId, RoundState newState);
    event RoundFunded(uint256 indexed roundId, uint256 totalRaised);
    event RoundFailed(uint256 indexed roundId, uint256 totalRaised);
    event Deposited(uint256 indexed roundId, address indexed participant, uint256 amount);
    event DepositWithdrawn(uint256 indexed roundId, address indexed participant, uint256 amount);
    event TokensDistributed(uint256 indexed roundId, uint256 totalAllocated, uint256 fee);
    event TokensClaimed(uint256 indexed roundId, address indexed participant, uint256 amount);
    event FeeCollected(uint256 indexed roundId, address indexed owner, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) revert ErrUnauthorized();
        _;
    }

    modifier roundExists(uint256 roundId) {
        if (roundId == 0 || roundId > roundCount) revert ErrRoundNotFound(roundId);
        _;
    }

    constructor(address _operator) Ownable(msg.sender) {
        if (_operator == address(0)) revert ErrZeroAddress();
        operator = _operator;
        emit OperatorChanged(address(0), _operator);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ErrZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function createRound(
        IERC20 projectToken,
        IERC20 paymentToken,
        uint256 tokenPrice,
        uint256 softCap,
        uint256 hardCap,
        uint256 minDeposit,
        uint256 maxDeposit,
        uint256 startTime,
        uint256 endTime
    ) external onlyOperator returns (uint256 roundId) {
        if (address(projectToken) == address(0) || address(paymentToken) == address(0)) revert ErrZeroAddress();
        if (tokenPrice == 0) revert ErrInvalidCap();
        if (softCap == 0 || hardCap == 0 || softCap > hardCap) revert ErrInvalidCap();
        if (minDeposit == 0 || maxDeposit == 0 || minDeposit > maxDeposit) revert ErrInvalidCap();
        if (startTime >= endTime) revert ErrInvalidTimeRange();

        roundId = ++roundCount;
        Round storage r = rounds[roundId];
        r.projectToken = projectToken;
        r.paymentToken = paymentToken;
        r.tokenPrice = tokenPrice;
        r.softCap = softCap;
        r.hardCap = hardCap;
        r.minDeposit = minDeposit;
        r.maxDeposit = maxDeposit;
        r.startTime = startTime;
        r.endTime = endTime;
        r.state = RoundState.Pending;

        emit RoundCreated(
            roundId,
            address(projectToken),
            address(paymentToken),
            tokenPrice,
            softCap,
            hardCap,
            startTime,
            endTime
        );
    }

    function configureVesting(
        uint256 roundId,
        uint256 vestingStart,
        uint256 cliff,
        uint256 duration
    ) external onlyOperator roundExists(roundId) {
        Round storage r = rounds[roundId];
        if (r.state == RoundState.Distributed) revert ErrRoundAlreadyDistributed(roundId);
        if (duration == 0 || cliff > duration) revert ErrInvalidVestingSchedule();

        r.vesting = VestingSchedule({start: vestingStart, cliff: cliff, duration: duration});

        emit VestingConfigured(roundId, vestingStart, cliff, duration);
    }

    function activateRound(uint256 roundId) external onlyOperator roundExists(roundId) {
        Round storage r = rounds[roundId];
        if (r.state != RoundState.Pending) revert ErrRoundNotPending(roundId);
        if (block.timestamp < r.startTime) revert ErrRoundNotActive(roundId);
        r.state = RoundState.Active;
        emit RoundStateChanged(roundId, RoundState.Active);
    }

    function deposit(uint256 roundId, uint256 amount) external nonReentrant roundExists(roundId) {
        Round storage r = rounds[roundId];

        if (r.state == RoundState.Pending) {
            if (block.timestamp < r.startTime) revert ErrRoundNotActive(roundId);
            r.state = RoundState.Active;
            emit RoundStateChanged(roundId, RoundState.Active);
        }

        if (r.state != RoundState.Active) revert ErrRoundNotActive(roundId);
        if (block.timestamp > r.endTime) revert ErrRoundNotActive(roundId);
        if (amount == 0) revert ErrDepositZero();

        uint256 newTotal = r.totalRaised + amount;
        if (newTotal > r.hardCap) revert ErrHardCapExceeded();

        if (!r.isParticipant[msg.sender]) {
            if (r.participantCount >= MAX_PARTICIPANTS) revert ErrMaxParticipantsReached();
            r.isParticipant[msg.sender] = true;
            r.participantCount += 1;
        }

        uint256 newDeposit = r.deposited[msg.sender] + amount;
        if (newDeposit < r.minDeposit) revert ErrDepositBelowMin(r.minDeposit);
        if (newDeposit > r.maxDeposit) revert ErrDepositAboveMax(r.maxDeposit);

        // Effects before interactions
        r.deposited[msg.sender] = newDeposit;
        r.totalRaised = newTotal;

        if (newTotal >= r.hardCap) {
            r.state = RoundState.Funded;
            emit RoundFunded(roundId, newTotal);
            emit RoundStateChanged(roundId, RoundState.Funded);
        }

        r.paymentToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(roundId, msg.sender, amount);
    }

    function finalizeRound(uint256 roundId) external roundExists(roundId) {
        Round storage r = rounds[roundId];
        if (r.state != RoundState.Active) revert ErrRoundNotActive(roundId);
        if (block.timestamp <= r.endTime) revert ErrRoundNotEnded(roundId);

        if (r.totalRaised >= r.softCap) {
            r.state = RoundState.Funded;
            emit RoundFunded(roundId, r.totalRaised);
            emit RoundStateChanged(roundId, RoundState.Funded);
        } else {
            r.state = RoundState.Failed;
            emit RoundFailed(roundId, r.totalRaised);
            emit RoundStateChanged(roundId, RoundState.Failed);
        }
    }

    function withdrawDeposit(uint256 roundId) external nonReentrant roundExists(roundId) {
        Round storage r = rounds[roundId];
        if (r.state != RoundState.Failed) revert ErrRoundNotFailed(roundId);

        uint256 amount = r.deposited[msg.sender];
        if (amount == 0) revert ErrNothingToWithdraw();

        // Effects before interactions
        r.deposited[msg.sender] = 0;
        r.totalRaised -= amount;

        r.paymentToken.safeTransfer(msg.sender, amount);

        emit DepositWithdrawn(roundId, msg.sender, amount);
    }

    function distributeTokens(uint256 roundId) external onlyOperator nonReentrant roundExists(roundId) {
        Round storage r = rounds[roundId];
        if (r.state != RoundState.Funded) revert ErrRoundNotFunded(roundId);
        if (r.vesting.duration == 0) revert ErrVestingNotConfigured();

        // Compute total project tokens and fee without divide-before-multiply
        uint256 totalProjectTokens = (r.totalRaised * 1e18) / r.tokenPrice;
        uint256 fee = (r.totalRaised * 1e18 * FEE_BPS) / (r.tokenPrice * 10000);
        uint256 netTokens = totalProjectTokens - fee;

        uint256 contractBalance = r.projectToken.balanceOf(address(this));
        if (contractBalance < totalProjectTokens) revert ErrInsufficientProjectTokens();

        // Effects before interactions
        r.totalAllocated = netTokens;
        r.state = RoundState.Distributed;

        if (fee > 0) {
            r.projectToken.safeTransfer(owner(), fee);
            emit FeeCollected(roundId, owner(), fee);
        }

        emit TokensDistributed(roundId, netTokens, fee);
        emit RoundStateChanged(roundId, RoundState.Distributed);
    }

    function claimTokens(uint256 roundId) external nonReentrant roundExists(roundId) {
        Round storage r = rounds[roundId];
        if (r.state != RoundState.Distributed) revert ErrRoundNotDistributed(roundId);

        uint256 deposited = r.deposited[msg.sender];
        if (deposited == 0) revert ErrNothingToClaim();

        uint256 allocated = (deposited * r.totalAllocated) / r.totalRaised;
        uint256 vested = _vestedAmount(r, allocated);
        if (vested <= r.claimed[msg.sender]) revert ErrNothingToClaim();
        uint256 claimable = vested - r.claimed[msg.sender];

        // Effects before interactions
        r.claimed[msg.sender] += claimable;
        r.totalClaimed += claimable;

        r.projectToken.safeTransfer(msg.sender, claimable);

        emit TokensClaimed(roundId, msg.sender, claimable);
    }

    function recoverToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    function _vestedAmount(Round storage r, uint256 allocation) internal view returns (uint256) {
        VestingSchedule memory v = r.vesting;
        if (block.timestamp < v.start) return 0;
        if (block.timestamp < v.start + v.cliff) return 0;
        if (block.timestamp >= v.start + v.duration) return allocation;

        uint256 elapsed = block.timestamp - v.start - v.cliff;
        uint256 vestingPeriod = v.duration - v.cliff;
        return (allocation * elapsed) / vestingPeriod;
    }

    function getRound(uint256 roundId) external view roundExists(roundId) returns (RoundView memory) {
        Round storage r = rounds[roundId];
        return RoundView({
            projectToken: address(r.projectToken),
            paymentToken: address(r.paymentToken),
            tokenPrice: r.tokenPrice,
            softCap: r.softCap,
            hardCap: r.hardCap,
            minDeposit: r.minDeposit,
            maxDeposit: r.maxDeposit,
            startTime: r.startTime,
            endTime: r.endTime,
            totalRaised: r.totalRaised,
            totalAllocated: r.totalAllocated,
            totalClaimed: r.totalClaimed,
            participantCount: r.participantCount,
            state: r.state,
            vestingStart: r.vesting.start,
            vestingCliff: r.vesting.cliff,
            vestingDuration: r.vesting.duration
        });
    }

    function getParticipant(uint256 roundId, address participant)
        external
        view
        roundExists(roundId)
        returns (uint256 depositedAmount, uint256 allocatedTokens, uint256 claimedTokens, bool isParticipant)
    {
        Round storage r = rounds[roundId];
        depositedAmount = r.deposited[participant];
        claimedTokens = r.claimed[participant];
        isParticipant = r.isParticipant[participant];

        if (r.state == RoundState.Distributed && depositedAmount > 0 && r.totalRaised > 0) {
            allocatedTokens = (depositedAmount * r.totalAllocated) / r.totalRaised;
        }
    }

    function claimableTokens(uint256 roundId, address participant) external view roundExists(roundId) returns (uint256) {
        Round storage r = rounds[roundId];
        if (r.state != RoundState.Distributed) return 0;

        uint256 deposited = r.deposited[participant];
        if (deposited == 0) return 0;

        uint256 allocated = (deposited * r.totalAllocated) / r.totalRaised;
        uint256 vested = _vestedAmount(r, allocated);
        if (vested <= r.claimed[participant]) return 0;
        return vested - r.claimed[participant];
    }

    function getRoundState(uint256 roundId) external view roundExists(roundId) returns (RoundState) {
        return rounds[roundId].state;
    }
}
