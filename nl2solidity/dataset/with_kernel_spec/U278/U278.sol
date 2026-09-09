// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenLaunchpad {
    enum Phase { Pending, Funding, Distribution, Failed, Cancelled }

    error NotAuthorized();
    error InvalidPhase();
    error InvalidParameter();
    error DepositZero();
    error MaxDepositExceeded();
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error NothingToClaim();
    error NothingToWithdraw();
    error FundingWindowClosed();
    error FundingNotEnded();
    error ProjectTokensNotFunded();
    error DistributionNotInitiated();
    error TransferFailed();
    error ReentrancyDetected();

    event PhaseAdvanced(Phase indexed previousPhase, Phase indexed newPhase, uint256 timestamp);
    event LaunchParametersSet(uint256 minTarget, uint256 projectTokenAmount, uint256 fundingDuration, uint256 timestamp);
    event Deposited(address indexed participant, uint256 amount, uint256 totalDeposited);
    event DistributionInitiated(uint256 totalDeposited, uint256 projectTokenAmount, uint256 timestamp);
    event TokensClaimed(address indexed participant, uint256 amountClaimed, uint256 feeAmount);
    event FundsWithdrawn(address indexed participant, uint256 amount);
    event ProjectTokensRecovered(address indexed recoveredBy, address indexed to, uint256 amount);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    uint256 public constant MAX_DEPOSIT = 1000e18;
    uint256 public constant FEE_BPS = 200;
    uint256 public constant BPS_DENOM = 10000;

    IERC20 public immutable depositToken;
    IERC20 public immutable projectToken;

    address public operator;
    address public treasury;

    uint256 public minTarget;
    uint256 public projectTokenAmount;
    uint256 public fundingDuration;
    uint256 public fundingStartTime;
    uint256 public fundingEndTime;

    Phase public currentPhase;
    bool public distributionInitiated;
    uint256 public totalDeposited;
    uint256 public totalAllocated;
    uint256 public totalClaimed;
    uint256 public totalFeesCollected;
    uint256 public totalWithdrawn;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public allocations;
    mapping(address => bool) public hasClaimed;
    mapping(address => bool) public hasWithdrawn;
    address[] public participants;
    mapping(address => bool) public isParticipant;

    uint256 private _locked = 1;

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotAuthorized();
        _;
    }

    modifier onlyPhase(Phase p) {
        if (currentPhase != p) revert InvalidPhase();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrancyDetected();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address _depositToken,
        address _projectToken,
        address _operator,
        address _treasury
    ) {
        if (_depositToken == address(0) || _projectToken == address(0)) revert InvalidParameter();
        if (_operator == address(0) || _treasury == address(0)) revert InvalidParameter();
        depositToken = IERC20(_depositToken);
        projectToken = IERC20(_projectToken);
        operator = _operator;
        treasury = _treasury;
        currentPhase = Phase.Pending;
    }

    function setLaunchParameters(
        uint256 _minTarget,
        uint256 _projectTokenAmount,
        uint256 _fundingDuration
    ) external onlyOperator onlyPhase(Phase.Pending) {
        if (_minTarget == 0 || _projectTokenAmount == 0 || _fundingDuration == 0) revert InvalidParameter();
        minTarget = _minTarget;
        projectTokenAmount = _projectTokenAmount;
        fundingDuration = _fundingDuration;
        emit LaunchParametersSet(_minTarget, _projectTokenAmount, _fundingDuration, block.timestamp);
    }

    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert InvalidParameter();
        address prev = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(prev, _treasury);
    }

    function advancePhase() external onlyOperator nonReentrant {
        Phase prev = currentPhase;

        if (prev == Phase.Pending) {
            if (minTarget == 0 || projectTokenAmount == 0 || fundingDuration == 0) revert InvalidParameter();
            if (projectToken.balanceOf(address(this)) < projectTokenAmount) revert ProjectTokensNotFunded();
            currentPhase = Phase.Funding;
            fundingStartTime = block.timestamp;
            fundingEndTime = block.timestamp + fundingDuration;
        } else if (prev == Phase.Funding) {
            if (block.timestamp < fundingEndTime) revert FundingNotEnded();
            currentPhase = totalDeposited >= minTarget ? Phase.Distribution : Phase.Failed;
        } else {
            revert InvalidPhase();
        }

        emit PhaseAdvanced(prev, currentPhase, block.timestamp);
    }

    function cancelLaunch() external onlyOperator nonReentrant {
        Phase prev = currentPhase;
        if (prev != Phase.Pending && prev != Phase.Funding) revert InvalidPhase();
        currentPhase = Phase.Cancelled;
        emit PhaseAdvanced(prev, currentPhase, block.timestamp);
    }

    function initiateDistribution() external onlyOperator onlyPhase(Phase.Distribution) nonReentrant {
        if (distributionInitiated) revert InvalidPhase();
        if (totalDeposited == 0) revert InvalidParameter();
        distributionInitiated = true;
        totalAllocated = projectTokenAmount;
        emit DistributionInitiated(totalDeposited, projectTokenAmount, block.timestamp);
    }

    function deposit(uint256 amount) external onlyPhase(Phase.Funding) nonReentrant {
        if (block.timestamp > fundingEndTime) revert FundingWindowClosed();
        if (amount == 0) revert DepositZero();
        if (deposits[msg.sender] + amount > MAX_DEPOSIT) revert MaxDepositExceeded();

        deposits[msg.sender] += amount;
        totalDeposited += amount;

        if (!isParticipant[msg.sender]) {
            isParticipant[msg.sender] = true;
            participants.push(msg.sender);
        }

        bool ok = depositToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Deposited(msg.sender, amount, totalDeposited);
    }

    function participantAllocation(address user) public view returns (uint256) {
        if (totalDeposited == 0) return 0;
        return (deposits[user] * projectTokenAmount) / totalDeposited;
    }

    function participantCount() external view returns (uint256) {
        return participants.length;
    }

    function getParticipant(address user)
        external
        view
        returns (
            uint256 deposited,
            uint256 allocation,
            bool claimed,
            bool withdrawn
        )
    {
        deposited = deposits[user];
        allocation = participantAllocation(user);
        claimed = hasClaimed[user];
        withdrawn = hasWithdrawn[user];
    }

    function launchSummary()
        external
        view
        returns (
            Phase phase,
            uint256 minTarget_,
            uint256 projectTokenAmount_,
            uint256 fundingStart,
            uint256 fundingEnd,
            uint256 deposited,
            uint256 allocated,
            uint256 claimed,
            uint256 fees,
            uint256 withdrawn,
            bool distributionLive
        )
    {
        phase = currentPhase;
        minTarget_ = minTarget;
        projectTokenAmount_ = projectTokenAmount;
        fundingStart = fundingStartTime;
        fundingEnd = fundingEndTime;
        deposited = totalDeposited;
        allocated = totalAllocated;
        claimed = totalClaimed;
        fees = totalFeesCollected;
        withdrawn = totalWithdrawn;
        distributionLive = distributionInitiated;
    }

    function claim() external onlyPhase(Phase.Distribution) nonReentrant {
        if (!distributionInitiated) revert DistributionNotInitiated();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        uint256 allocation = participantAllocation(msg.sender);
        if (allocation == 0) revert NothingToClaim();

        hasClaimed[msg.sender] = true;
        allocations[msg.sender] = allocation;

        uint256 fee = (allocation * FEE_BPS) / BPS_DENOM;
        uint256 toUser = allocation - fee;

        totalClaimed += toUser;
        totalFeesCollected += fee;

        bool ok1 = projectToken.transfer(msg.sender, toUser);
        if (!ok1) revert TransferFailed();

        if (fee > 0) {
            bool ok2 = projectToken.transfer(treasury, fee);
            if (!ok2) revert TransferFailed();
        }

        emit TokensClaimed(msg.sender, toUser, fee);
    }

    function withdrawFailedFunds() external nonReentrant {
        if (currentPhase != Phase.Failed && currentPhase != Phase.Cancelled) revert InvalidPhase();
        if (hasWithdrawn[msg.sender]) revert AlreadyWithdrawn();

        uint256 amount = deposits[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        hasWithdrawn[msg.sender] = true;
        deposits[msg.sender] = 0;
        totalWithdrawn += amount;

        bool ok = depositToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit FundsWithdrawn(msg.sender, amount);
    }

    function recoverProjectTokens() external onlyOperator nonReentrant {
        if (currentPhase == Phase.Funding || currentPhase == Phase.Distribution) revert InvalidPhase();

        uint256 bal = projectToken.balanceOf(address(this));
        if (bal < 1) revert NothingToWithdraw();

        bool ok = projectToken.transfer(treasury, bal);
        if (!ok) revert TransferFailed();

        emit ProjectTokensRecovered(msg.sender, treasury, bal);
    }
}
