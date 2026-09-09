// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
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

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: zero address");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/// @title TokenLaunchpad
/// @notice Facilitates fair-launch token events. Depositors supply an existing
///         "launch token" and receive a pro-rata share of the raised capital.
///         Committers supply a "raise token" and receive a pro-rata share of a
///         new token at a ratio set by the operator. A 2% fee on all raised
///         capital is sent to the treasury on successful finalization.
contract TokenLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ------------------------------------------------------------------ */
    /*  Enums                                                             */
    /* ------------------------------------------------------------------ */

    enum Phase {
        Deposit,      // depositors supply launch tokens
        Commitment,   // committers supply raise-token capital
        Distribution, // successful launch — claims enabled
        Cancelled     // failed/cancelled launch — refunds enabled
    }

    /* ------------------------------------------------------------------ */
    /*  Structs                                                           */
    /* ------------------------------------------------------------------ */

    struct Launch {
        address launchToken;     // ERC-20 deposited by depositors
        address newToken;         // ERC-20 distributed to committers on success
        address raiseToken;       // ERC-20 committed by committers (capital)
        uint256 targetRaise;      // target amount of raiseToken to raise
        uint256 ratio;            // new tokens minted per launch token deposited
        uint256 totalDeposited;   // total launch tokens deposited
        uint256 totalCommitted;   // total raise tokens committed
        uint256 totalNewTokens;   // totalDeposited * ratio (set at finalize)
        uint256 startTime;        // timestamp of initiation
        Phase phase;              // current phase
        bool success;             // whether the launch succeeded
        bool sweptTokens;         // whether operator has swept launch tokens
    }

    struct Participant {
        uint256 deposited;           // launch tokens deposited
        uint256 committed;           // raise tokens committed
        uint256 allocatedNewTokens;  // snapshot of new-token allocation
        uint256 allocatedCapital;    // snapshot of capital allocation
        bool claimedNewTokens;       // whether new tokens were claimed
        bool claimedCapital;         // whether raised capital was claimed
        bool withdrawnCommitted;     // whether committed funds were refunded
        bool withdrawnDeposited;     // whether deposited tokens were refunded
    }

    /* ------------------------------------------------------------------ */
    /*  Constants                                                         */
    /* ------------------------------------------------------------------ */

    uint256 public constant SUCCESS_THRESHOLD = 50;       // 50% of target
    uint256 public constant PERCENT_DENOMINATOR = 100;
    uint256 public constant TREASURY_FEE = 2;              // 2% of raised capital
    uint256 public constant FEE_DENOMINATOR = 100;

    /* ------------------------------------------------------------------ */
    /*  Storage                                                           */
    /* ------------------------------------------------------------------ */

    address public operator;
    address public treasury;
    uint256 public launchCount;

    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => Participant)) public participants;

    /* ------------------------------------------------------------------ */
    /*  Events                                                            */
    /* ------------------------------------------------------------------ */

    event LaunchInitiated(
        uint256 indexed launchId,
        address indexed launchToken,
        address indexed newToken,
        address raiseToken,
        uint256 targetRaise,
        uint256 ratio
    );
    event TokensDeposited(uint256 indexed launchId, address indexed depositor, uint256 amount);
    event FundsCommitted(uint256 indexed launchId, address indexed committer, uint256 amount);
    event PhaseAdvanced(uint256 indexed launchId, Phase newPhase);
    event LaunchFinalized(uint256 indexed launchId, bool success, uint256 totalRaised, uint256 treasuryFee);
    event LaunchCancelled(uint256 indexed launchId);
    event NewTokensClaimed(uint256 indexed launchId, address indexed claimer, uint256 amount);
    event CapitalClaimed(uint256 indexed launchId, address indexed depositor, uint256 amount);
    event CommittedFundsWithdrawn(uint256 indexed launchId, address indexed committer, uint256 amount);
    event DepositedTokensWithdrawn(uint256 indexed launchId, address indexed depositor, uint256 amount);
    event OperatorSwept(uint256 indexed launchId, address indexed token, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /* ------------------------------------------------------------------ */
    /*  Errors                                                            */
    /* ------------------------------------------------------------------ */

    error NotOperator();
    error InvalidLaunchId();
    error NotInPhase(Phase expected, Phase actual);
    error ZeroAmount();
    error ZeroAddress();
    error LaunchNotSuccessful();
    error LaunchNotCancelled();
    error NothingToClaim();
    error AlreadyClaimed();
    error InsufficientNewTokens();
    error CannotCancelFromCurrentPhase();

    /* ------------------------------------------------------------------ */
    /*  Modifiers                                                         */
    /* ------------------------------------------------------------------ */

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier validLaunchId(uint256 launchId) {
        if (launchId >= launchCount) revert InvalidLaunchId();
        _;
    }

    /* ------------------------------------------------------------------ */
    /*  Constructor                                                       */
    /* ------------------------------------------------------------------ */

    constructor(address _treasury) Ownable(msg.sender) {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        operator = msg.sender;
    }

    /* ------------------------------------------------------------------ */
    /*  Admin — set operator / treasury                                   */
    /* ------------------------------------------------------------------ */

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    /* ------------------------------------------------------------------ */
    /*  Operator — launch lifecycle                                       */
    /* ------------------------------------------------------------------ */

    /// @notice Initiates a new launch. The contract must later be funded
    ///         with enough `newToken` to cover `totalDeposited * ratio`
    ///         before finalization can succeed.
    function initiateLaunch(
        address _launchToken,
        address _newToken,
        address _raiseToken,
        uint256 _targetRaise,
        uint256 _ratio
    ) external onlyOperator returns (uint256 launchId) {
        if (
            _launchToken == address(0) || _newToken == address(0) || _raiseToken == address(0)
        ) revert ZeroAddress();
        if (_targetRaise == 0 || _ratio == 0) revert ZeroAmount();

        launchId = launchCount++;
        Launch storage l = launches[launchId];
        l.launchToken = _launchToken;
        l.newToken = _newToken;
        l.raiseToken = _raiseToken;
        l.targetRaise = _targetRaise;
        l.ratio = _ratio;
        l.phase = Phase.Deposit;
        l.startTime = block.timestamp;

        emit LaunchInitiated(launchId, _launchToken, _newToken, _raiseToken, _targetRaise, _ratio);
    }

    /// @notice Advances the launch from the Deposit phase to the Commitment phase.
    function advancePhase(uint256 launchId) external validLaunchId(launchId) onlyOperator {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Deposit) revert NotInPhase(Phase.Deposit, l.phase);
        l.phase = Phase.Commitment;
        emit PhaseAdvanced(launchId, l.phase);
    }

    /// @notice Finalizes the launch. If `totalCommitted >= 50%` of `targetRaise`
    ///         and at least one launch token was deposited, the launch succeeds;
    ///         the 2% treasury fee is transferred and the phase moves to
    ///         Distribution. Otherwise the launch is marked Cancelled.
    function finalizeLaunch(uint256 launchId)
        external
        validLaunchId(launchId)
        onlyOperator
        nonReentrant
    {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Commitment) revert NotInPhase(Phase.Commitment, l.phase);

        bool success = l.totalCommitted >= (l.targetRaise * SUCCESS_THRESHOLD) / PERCENT_DENOMINATOR
            && l.totalDeposited > 0;

        if (success) {
            // Checks
            l.totalNewTokens = l.totalDeposited * l.ratio;
            if (IERC20(l.newToken).balanceOf(address(this)) < l.totalNewTokens)
                revert InsufficientNewTokens();

            // Effects
            l.success = true;
            l.phase = Phase.Distribution;

            // Interactions — transfer 2% fee to treasury
            uint256 fee = (l.totalCommitted * TREASURY_FEE) / FEE_DENOMINATOR;
            if (fee > 0) {
                IERC20(l.raiseToken).safeTransfer(treasury, fee);
            }

            emit LaunchFinalized(launchId, true, l.totalCommitted, fee);
        } else {
            l.success = false;
            l.phase = Phase.Cancelled;
            emit LaunchFinalized(launchId, false, l.totalCommitted, 0);
        }
    }

    /// @notice Cancels an in-progress launch. Not callable after distribution.
    function cancelLaunch(uint256 launchId) external validLaunchId(launchId) onlyOperator {
        Launch storage l = launches[launchId];
        if (l.phase == Phase.Distribution || l.phase == Phase.Cancelled)
            revert CannotCancelFromCurrentPhase();
        l.phase = Phase.Cancelled;
        l.success = false;
        emit LaunchCancelled(launchId);
    }

    /// @notice Allows the operator to retrieve the deposited launch tokens
    ///         after a successful finalization.
    function sweepLaunchTokens(uint256 launchId)
        external
        validLaunchId(launchId)
        onlyOperator
        nonReentrant
    {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Distribution) revert LaunchNotSuccessful();
        if (l.sweptTokens) revert AlreadyClaimed();

        l.sweptTokens = true;
        uint256 amount = l.totalDeposited;
        IERC20(l.launchToken).safeTransfer(operator, amount);
        emit OperatorSwept(launchId, l.launchToken, amount);
    }

    /* ------------------------------------------------------------------ */
    /*  Participant — deposit phase                                       */
    /* ------------------------------------------------------------------ */

    /// @notice Deposits `amount` of the launch token into the pool.
    function depositLaunchTokens(uint256 launchId, uint256 amount)
        external
        validLaunchId(launchId)
        nonReentrant
    {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Deposit) revert NotInPhase(Phase.Deposit, l.phase);
        if (amount == 0) revert ZeroAmount();

        l.totalDeposited += amount;
        participants[launchId][msg.sender].deposited += amount;

        IERC20(l.launchToken).safeTransferFrom(msg.sender, address(this), amount);

        emit TokensDeposited(launchId, msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /*  Participant — commitment phase                                   */
    /* ------------------------------------------------------------------ */

    /// @notice Commits `amount` of the raise token to the launch.
    function commitFunds(uint256 launchId, uint256 amount)
        external
        validLaunchId(launchId)
        nonReentrant
    {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Commitment) revert NotInPhase(Phase.Commitment, l.phase);
        if (amount == 0) revert ZeroAmount();

        l.totalCommitted += amount;
        participants[launchId][msg.sender].committed += amount;

        IERC20(l.raiseToken).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsCommitted(launchId, msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /*  Participant — distribution (success)                              */
    /* ------------------------------------------------------------------ */

    /// @notice Claims the caller's pro-rata share of new tokens based on
    ///         their committed raise tokens.
    function claimNewTokens(uint256 launchId) external validLaunchId(launchId) nonReentrant {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Distribution) revert LaunchNotSuccessful();

        Participant storage p = participants[launchId][msg.sender];
        if (p.committed == 0) revert NothingToClaim();
        if (p.claimedNewTokens) revert AlreadyClaimed();

        uint256 allocation = (p.committed * l.totalNewTokens) / l.totalCommitted;
        p.allocatedNewTokens = allocation;
        p.claimedNewTokens = true;

        IERC20(l.newToken).safeTransfer(msg.sender, allocation);

        emit NewTokensClaimed(launchId, msg.sender, allocation);
    }

    /// @notice Claims the caller's pro-rata share of the raised capital
    ///         (minus the 2% treasury fee) based on their deposited launch tokens.
    function claimCapital(uint256 launchId) external validLaunchId(launchId) nonReentrant {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Distribution) revert LaunchNotSuccessful();

        Participant storage p = participants[launchId][msg.sender];
        if (p.deposited == 0) revert NothingToClaim();
        if (p.claimedCapital) revert AlreadyClaimed();

        uint256 fee = (l.totalCommitted * TREASURY_FEE) / FEE_DENOMINATOR;
        uint256 distributable = l.totalCommitted - fee;
        uint256 allocation = (p.deposited * distributable) / l.totalDeposited;
        p.allocatedCapital = allocation;
        p.claimedCapital = true;

        IERC20(l.raiseToken).safeTransfer(msg.sender, allocation);

        emit CapitalClaimed(launchId, msg.sender, allocation);
    }

    /* ------------------------------------------------------------------ */
    /*  Participant — cancellation (failure)                              */
    /* ------------------------------------------------------------------ */

    /// @notice Withdraws the caller's committed raise tokens when the
    ///         launch has been cancelled or failed.
    function withdrawCommittedFunds(uint256 launchId) external validLaunchId(launchId) nonReentrant {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Cancelled) revert LaunchNotCancelled();

        Participant storage p = participants[launchId][msg.sender];
        if (p.committed == 0) revert NothingToClaim();
        if (p.withdrawnCommitted) revert AlreadyClaimed();

        uint256 amount = p.committed;
        p.withdrawnCommitted = true;

        IERC20(l.raiseToken).safeTransfer(msg.sender, amount);

        emit CommittedFundsWithdrawn(launchId, msg.sender, amount);
    }

    /// @notice Withdraws the caller's deposited launch tokens when the
    ///         launch has been cancelled or failed.
    function withdrawDepositedTokens(uint256 launchId) external validLaunchId(launchId) nonReentrant {
        Launch storage l = launches[launchId];
        if (l.phase != Phase.Cancelled) revert LaunchNotCancelled();

        Participant storage p = participants[launchId][msg.sender];
        if (p.deposited == 0) revert NothingToClaim();
        if (p.withdrawnDeposited) revert AlreadyClaimed();

        uint256 amount = p.deposited;
        p.withdrawnDeposited = true;

        IERC20(l.launchToken).safeTransfer(msg.sender, amount);

        emit DepositedTokensWithdrawn(launchId, msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /*  View functions                                                    */
    /* ------------------------------------------------------------------ */

    function getLaunch(uint256 launchId)
        external
        view
        validLaunchId(launchId)
        returns (
            address launchToken,
            address newToken,
            address raiseToken,
            uint256 targetRaise,
            uint256 ratio,
            uint256 totalDeposited,
            uint256 totalCommitted,
            uint256 totalNewTokens,
            Phase phase,
            bool success
        )
    {
        Launch storage l = launches[launchId];
        return (
            l.launchToken,
            l.newToken,
            l.raiseToken,
            l.targetRaise,
            l.ratio,
            l.totalDeposited,
            l.totalCommitted,
            l.totalNewTokens,
            l.phase,
            l.success
        );
    }

    function getParticipant(uint256 launchId, address account)
        external
        view
        returns (
            uint256 deposited,
            uint256 committed,
            uint256 allocatedNewTokens,
            uint256 allocatedCapital,
            bool claimedNewTokens,
            bool claimedCapital,
            bool withdrawnCommitted,
            bool withdrawnDeposited
        )
    {
        Participant storage p = participants[launchId][account];
        return (
            p.deposited,
            p.committed,
            p.allocatedNewTokens,
            p.allocatedCapital,
            p.claimedNewTokens,
            p.claimedCapital,
            p.withdrawnCommitted,
            p.withdrawnDeposited
        );
    }
}
