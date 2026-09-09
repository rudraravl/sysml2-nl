// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title TokenLaunchManager
 * @dev Manages token launches: participants deposit funds during the deposit phase,
 *      the operator records allocations during the allocation phase, participants
 *      claim their allocated launch tokens during the claim phase, and may withdraw
 *      their deposited funds if the launch is canceled. Each launch proceeds through
 *      deposit -> allocation -> claim in strict order. The maximum individual deposit
 *      per participant per launch is capped at 1000 units (assumed 18 decimals).
 */
contract TokenLaunchManager {
    enum LaunchPhase {
        Idle,
        Deposit,
        Allocation,
        Claim,
        Canceled
    }

    struct Launch {
        IERC20 launchToken;
        IERC20 depositToken;
        uint256 totalSupply;
        uint256 maxIndividualDeposit;
        uint256 totalDeposited;
        uint256 totalAllocated;
        uint256 totalClaimed;
        LaunchPhase phase;
        bool exists;
        bool unclaimedRecovered;
    }

    struct Participant {
        uint256 depositedAmount;
        uint256 allocatedTokens;
        bool claimed;
    }

    uint256 public constant MAX_INDIVIDUAL_DEPOSIT = 1000 ether;

    address public operator;
    uint256 public nextLaunchId;

    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => Participant)) public participants;

    bool private _locked;

    event LaunchInitiated(
        uint256 indexed launchId,
        address indexed launchToken,
        address indexed depositToken,
        uint256 totalSupply,
        uint256 maxIndividualDeposit
    );
    event Deposited(uint256 indexed launchId, address indexed participant, uint256 amount);
    event TokensClaimed(uint256 indexed launchId, address indexed participant, uint256 amount);
    event AllocationsSet(uint256 indexed launchId, address indexed participant, uint256 amount);
    event FundsWithdrawn(uint256 indexed launchId, address indexed participant, uint256 amount);
    event PhaseTransitioned(uint256 indexed launchId, LaunchPhase oldPhase, LaunchPhase newPhase);
    event LaunchCanceled(uint256 indexed launchId);
    event UnallocatedTokensRecovered(uint256 indexed launchId, address indexed recipient, uint256 amount);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);

    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error LaunchNotFound();
    error InvalidPhase(LaunchPhase expected, LaunchPhase actual);
    error InvalidPhaseTransition();
    error DepositExceedsCap(uint256 attempted, uint256 cap);
    error CapExceedsHardLimit(uint256 attempted, uint256 limit);
    error NothingToClaim();
    error AlreadyClaimed();
    error NothingToWithdraw();
    error AlreadyRecovered();
    error NotDepositor();
    error ArraysLengthMismatch();
    error AllocationExceedsSupply();
    error TokenTransferFailed();
    error ReentrancyDetected();

    modifier nonReentrant() {
        if (_locked) revert ReentrancyDetected();
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier launchExists(uint256 launchId) {
        if (!launches[launchId].exists) revert LaunchNotFound();
        _;
    }

    modifier atPhase(uint256 launchId, LaunchPhase expected) {
        if (launches[launchId].phase != expected) {
            revert InvalidPhase(expected, launches[launchId].phase);
        }
        _;
    }

    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        nextLaunchId = 1;
        emit OperatorChanged(address(0), _operator);
    }

    function initiateLaunch(
        address _launchToken,
        address _depositToken,
        uint256 _totalSupply,
        uint256 _maxIndividualDeposit
    ) external onlyOperator nonReentrant returns (uint256 launchId) {
        if (_launchToken == address(0) || _depositToken == address(0)) revert ZeroAddress();
        if (_totalSupply == 0) revert ZeroAmount();
        if (_maxIndividualDeposit == 0) revert ZeroAmount();
        if (_maxIndividualDeposit > MAX_INDIVIDUAL_DEPOSIT) {
            revert CapExceedsHardLimit(_maxIndividualDeposit, MAX_INDIVIDUAL_DEPOSIT);
        }

        IERC20 launchToken = IERC20(_launchToken);
        bool ok = launchToken.transferFrom(msg.sender, address(this), _totalSupply);
        if (!ok) revert TokenTransferFailed();

        launchId = nextLaunchId++;
        launches[launchId] = Launch({
            launchToken: launchToken,
            depositToken: IERC20(_depositToken),
            totalSupply: _totalSupply,
            maxIndividualDeposit: _maxIndividualDeposit,
            totalDeposited: 0,
            totalAllocated: 0,
            totalClaimed: 0,
            phase: LaunchPhase.Deposit,
            exists: true,
            unclaimedRecovered: false
        });

        emit LaunchInitiated(launchId, _launchToken, _depositToken, _totalSupply, _maxIndividualDeposit);
    }

    function closeDepositPhase(uint256 launchId)
        external
        onlyOperator
        launchExists(launchId)
        atPhase(launchId, LaunchPhase.Deposit)
        nonReentrant
    {
        Launch storage l = launches[launchId];
        l.phase = LaunchPhase.Allocation;
        emit PhaseTransitioned(launchId, LaunchPhase.Deposit, LaunchPhase.Allocation);
    }

    function setAllocations(
        uint256 launchId,
        address[] calldata _participants,
        uint256[] calldata _amounts
    ) external onlyOperator launchExists(launchId) atPhase(launchId, LaunchPhase.Allocation) nonReentrant {
        if (_participants.length != _amounts.length) revert ArraysLengthMismatch();
        if (_participants.length == 0) revert ZeroAmount();

        Launch storage l = launches[launchId];
        uint256 runningTotal = l.totalAllocated;

        for (uint256 i = 0; i < _participants.length; i++) {
            address participant = _participants[i];
            uint256 amount = _amounts[i];

            if (participant == address(0)) revert ZeroAddress();
            if (participants[launchId][participant].depositedAmount == 0) revert NotDepositor();

            uint256 oldAllocation = participants[launchId][participant].allocatedTokens;
            participants[launchId][participant].allocatedTokens = amount;
            runningTotal = runningTotal + amount - oldAllocation;

            emit AllocationsSet(launchId, participant, amount);
        }

        if (runningTotal > l.totalSupply) revert AllocationExceedsSupply();
        l.totalAllocated = runningTotal;
    }

    function finalizeAllocations(uint256 launchId)
        external
        onlyOperator
        launchExists(launchId)
        atPhase(launchId, LaunchPhase.Allocation)
        nonReentrant
    {
        Launch storage l = launches[launchId];
        l.phase = LaunchPhase.Claim;
        emit PhaseTransitioned(launchId, LaunchPhase.Allocation, LaunchPhase.Claim);
    }

    function cancelLaunch(uint256 launchId)
        external
        onlyOperator
        launchExists(launchId)
        nonReentrant
    {
        Launch storage l = launches[launchId];
        if (l.phase != LaunchPhase.Deposit && l.phase != LaunchPhase.Allocation) {
            revert InvalidPhaseTransition();
        }
        LaunchPhase oldPhase = l.phase;
        l.phase = LaunchPhase.Canceled;
        emit PhaseTransitioned(launchId, oldPhase, LaunchPhase.Canceled);
        emit LaunchCanceled(launchId);
    }

    function recoverUnallocatedLaunchTokens(uint256 launchId, address recipient)
        external
        onlyOperator
        launchExists(launchId)
        nonReentrant
    {
        if (recipient == address(0)) revert ZeroAddress();
        Launch storage l = launches[launchId];
        if (l.unclaimedRecovered) revert AlreadyRecovered();

        uint256 amount;
        if (l.phase == LaunchPhase.Claim) {
            amount = l.totalSupply - l.totalAllocated;
        } else if (l.phase == LaunchPhase.Canceled) {
            amount = l.totalSupply - l.totalClaimed;
        } else {
            revert InvalidPhaseTransition();
        }

        if (amount == 0) revert NothingToWithdraw();

        l.unclaimedRecovered = true;
        bool ok = l.launchToken.transfer(recipient, amount);
        if (!ok) revert TokenTransferFailed();

        emit UnallocatedTokensRecovered(launchId, recipient, amount);
    }

    function transferOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = newOperator;
        emit OperatorChanged(previous, newOperator);
    }

    function deposit(uint256 launchId, uint256 amount)
        external
        launchExists(launchId)
        atPhase(launchId, LaunchPhase.Deposit)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        Launch storage l = launches[launchId];
        Participant storage part = participants[launchId][msg.sender];

        uint256 newTotal = part.depositedAmount + amount;
        if (newTotal > l.maxIndividualDeposit) {
            revert DepositExceedsCap(newTotal, l.maxIndividualDeposit);
        }

        part.depositedAmount = newTotal;
        l.totalDeposited += amount;

        bool ok = l.depositToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TokenTransferFailed();

        emit Deposited(launchId, msg.sender, amount);
    }

    function claimTokens(uint256 launchId)
        external
        launchExists(launchId)
        atPhase(launchId, LaunchPhase.Claim)
        nonReentrant
    {
        Participant storage part = participants[launchId][msg.sender];
        uint256 allocation = part.allocatedTokens;
        if (allocation == 0) revert NothingToClaim();
        if (part.claimed) revert AlreadyClaimed();

        part.claimed = true;
        Launch storage l = launches[launchId];
        l.totalClaimed += allocation;

        bool ok = l.launchToken.transfer(msg.sender, allocation);
        if (!ok) revert TokenTransferFailed();

        emit TokensClaimed(launchId, msg.sender, allocation);
    }

    function withdrawDepositedFunds(uint256 launchId)
        external
        launchExists(launchId)
        atPhase(launchId, LaunchPhase.Canceled)
        nonReentrant
    {
        Participant storage part = participants[launchId][msg.sender];
        uint256 amount = part.depositedAmount;
        if (amount == 0) revert NothingToWithdraw();

        part.depositedAmount = 0;
        Launch storage l = launches[launchId];
        l.totalDeposited -= amount;

        bool ok = l.depositToken.transfer(msg.sender, amount);
        if (!ok) revert TokenTransferFailed();

        emit FundsWithdrawn(launchId, msg.sender, amount);
    }

    function getLaunchConfig(uint256 launchId)
        external
        view
        launchExists(launchId)
        returns (
            address launchToken,
            address depositToken,
            uint256 totalSupply,
            uint256 maxIndividualDeposit
        )
    {
        Launch storage l = launches[launchId];
        return (
            address(l.launchToken),
            address(l.depositToken),
            l.totalSupply,
            l.maxIndividualDeposit
        );
    }

    function getLaunchTotals(uint256 launchId)
        external
        view
        launchExists(launchId)
        returns (
            uint256 totalDeposited,
            uint256 totalAllocated,
            uint256 totalClaimed,
            LaunchPhase phase
        )
    {
        Launch storage l = launches[launchId];
        return (
            l.totalDeposited,
            l.totalAllocated,
            l.totalClaimed,
            l.phase
        );
    }

    function getParticipant(uint256 launchId, address account)
        external
        view
        launchExists(launchId)
        returns (uint256 depositedAmount, uint256 allocatedTokens, bool claimed)
    {
        Participant storage p = participants[launchId][account];
        return (p.depositedAmount, p.allocatedTokens, p.claimed);
    }

    function currentPhase(uint256 launchId)
        external
        view
        launchExists(launchId)
        returns (LaunchPhase)
    {
        return launches[launchId].phase;
    }
}
