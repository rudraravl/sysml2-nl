// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedInsurancePool {
    // ---------- Errors ----------
    error ZeroAddress();
    error ZeroAmount();
    error DepositTooSmall();
    error InsufficientBalance();
    error PolicyNotFound();
    error PolicyNotActive();
    error PolicyExpired();
    error CoverageExceedsLimit();
    error DurationInvalid();
    error NotPolicyHolder();
    error ClaimAlreadySubmitted();
    error ClaimAlreadyProcessed();
    error NotOperator();
    error NotOwner();
    error InvalidConfiguration();
    error TransferFailed();
    error PayoutThresholdExceeded();
    error InsufficientPoolLiquidity();

    // ---------- Events ----------
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event PolicyIssued(uint256 indexed policyId, address indexed holder, uint256 coverageAmount, uint40 startTime, uint40 endTime, uint256 premium);
    event ClaimSubmitted(uint256 indexed policyId, address indexed claimant, uint256 claimAmount, uint40 timestamp);
    event ClaimApproved(uint256 indexed policyId, address indexed claimant, uint256 claimAmount, uint256 payout, uint256 fee);
    event ClaimRejected(uint256 indexed policyId, address indexed claimant, uint40 timestamp);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event ConfigurationUpdated(uint256 minDeposit, uint256 feeBps, uint256 payoutThreshold, uint256 maxCoveragePerPolicy);

    // ---------- Structs ----------
    struct Policy {
        address holder;
        uint256 coverageAmount;
        uint256 premium;
        uint40 startTime;
        uint40 endTime;
        bool active;
        ClaimStatus claimStatus;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        uint40 submittedAt;
        bool processed;
        bool approved;
    }

    enum ClaimStatus { None, Submitted, Approved, Rejected }

    // ---------- Constants ----------
    uint256 public constant MIN_DEPOSIT = 100 * 1e18;
    uint256 public constant FEE_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 365 days;

    // ---------- State ----------
    address public owner;
    address public operator;
    IERC20 public immutable stablecoin;

    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    uint256 public nextPolicyId;
    uint256 public activePolicyCount;

    uint256 public minDeposit;
    uint256 public feeBps;
    uint256 public payoutThreshold;
    uint256 public maxCoveragePerPolicy;
    uint256 public totalPayouts;

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // ---------- Constructor ----------
    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0) || _operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        owner = msg.sender;
        operator = _operator;
        minDeposit = MIN_DEPOSIT;
        feeBps = FEE_BPS;
        payoutThreshold = 1_000_000 * 1e18;
        maxCoveragePerPolicy = 100_000 * 1e18;
        nextPolicyId = 1;
        emit OperatorUpdated(address(0), _operator);
        emit ConfigurationUpdated(minDeposit, feeBps, payoutThreshold, maxCoveragePerPolicy);
    }

    // ---------- Admin ----------
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    function updateConfiguration(
        uint256 _minDeposit,
        uint256 _feeBps,
        uint256 _payoutThreshold,
        uint256 _maxCoveragePerPolicy
    ) external onlyOwner {
        if (_feeBps > BPS_DENOMINATOR) revert InvalidConfiguration();
        if (_minDeposit < MIN_DEPOSIT) revert InvalidConfiguration();
        if (_payoutThreshold == 0 || _maxCoveragePerPolicy == 0) revert InvalidConfiguration();
        minDeposit = _minDeposit;
        feeBps = _feeBps;
        payoutThreshold = _payoutThreshold;
        maxCoveragePerPolicy = _maxCoveragePerPolicy;
        emit ConfigurationUpdated(minDeposit, feeBps, payoutThreshold, maxCoveragePerPolicy);
    }

    // ---------- User: Deposit ----------
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (!stablecoin.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposited(msg.sender, amount);
    }

    // ---------- User: Withdraw ----------
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = deposits[msg.sender];
        if (bal < amount) revert InsufficientBalance();

        deposits[msg.sender] = bal - amount;
        totalDeposits -= amount;

        if (!stablecoin.transfer(msg.sender, amount)) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function availableBalance(address user) external view returns (uint256) {
        return deposits[user];
    }

    // ---------- User: Request Coverage ----------
    function requestCoverage(uint256 coverageAmount, uint40 duration) external returns (uint256 policyId) {
        if (coverageAmount == 0) revert ZeroAmount();
        if (coverageAmount > maxCoveragePerPolicy) revert CoverageExceedsLimit();
        if (duration < MIN_DURATION || duration > MAX_DURATION) revert DurationInvalid();
        if (deposits[msg.sender] < minDeposit) revert DepositTooSmall();

        uint256 premium = (coverageAmount * 100) / BPS_DENOMINATOR;

        policyId = nextPolicyId++;
        uint40 startTime = uint40(block.timestamp);
        uint40 endTime = startTime + duration;

        policies[policyId] = Policy({
            holder: msg.sender,
            coverageAmount: coverageAmount,
            premium: premium,
            startTime: startTime,
            endTime: endTime,
            active: true,
            claimStatus: ClaimStatus.None
        });

        activePolicyCount++;

        emit PolicyIssued(policyId, msg.sender, coverageAmount, startTime, endTime, premium);
    }

    // ---------- User: Submit Claim ----------
    function submitClaim(uint256 policyId, uint256 claimAmount) external {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (msg.sender != policy.holder) revert NotPolicyHolder();
        if (!policy.active) revert PolicyNotActive();
        if (policy.claimStatus != ClaimStatus.None) revert ClaimAlreadySubmitted();
        if (block.timestamp > policy.endTime) revert PolicyExpired();
        if (claimAmount == 0 || claimAmount > policy.coverageAmount) revert CoverageExceedsLimit();
        if (totalPayouts + claimAmount > payoutThreshold) revert PayoutThresholdExceeded();

        policy.claimStatus = ClaimStatus.Submitted;

        claims[policyId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            claimAmount: claimAmount,
            submittedAt: uint40(block.timestamp),
            processed: false,
            approved: false
        });

        emit ClaimSubmitted(policyId, msg.sender, claimAmount, uint40(block.timestamp));
    }

    // ---------- Operator: Approve ----------
    function approveClaim(uint256 policyId) external onlyOperator {
        Policy storage policy = policies[policyId];
        Claim storage claim = claims[policyId];

        if (policy.holder == address(0)) revert PolicyNotFound();
        if (policy.claimStatus != ClaimStatus.Submitted) revert ClaimAlreadyProcessed();
        if (claim.processed) revert ClaimAlreadyProcessed();

        claim.processed = true;
        claim.approved = true;
        policy.claimStatus = ClaimStatus.Approved;
        policy.active = false;
        activePolicyCount--;

        uint256 claimAmount = claim.claimAmount;
        uint256 fee = (claimAmount * feeBps) / BPS_DENOMINATOR;
        uint256 payout = claimAmount - fee;

        totalPayouts += claimAmount;

        if (stablecoin.balanceOf(address(this)) < payout) revert InsufficientPoolLiquidity();

        if (!stablecoin.transfer(claim.claimant, payout)) revert TransferFailed();

        emit ClaimApproved(policyId, claim.claimant, claimAmount, payout, fee);
    }

    // ---------- Operator: Reject ----------
    function rejectClaim(uint256 policyId) external onlyOperator {
        Policy storage policy = policies[policyId];
        Claim storage claim = claims[policyId];

        if (policy.holder == address(0)) revert PolicyNotFound();
        if (policy.claimStatus != ClaimStatus.Submitted) revert ClaimAlreadyProcessed();
        if (claim.processed) revert ClaimAlreadyProcessed();

        claim.processed = true;
        claim.approved = false;
        policy.claimStatus = ClaimStatus.Rejected;

        emit ClaimRejected(policyId, claim.claimant, uint40(block.timestamp));
    }

    // ---------- Views ----------
    function getPolicy(uint256 policyId) external view returns (
        address holder,
        uint256 coverageAmount,
        uint256 premium,
        uint40 startTime,
        uint40 endTime,
        bool active,
        ClaimStatus claimStatus
    ) {
        Policy storage p = policies[policyId];
        return (p.holder, p.coverageAmount, p.premium, p.startTime, p.endTime, p.active, p.claimStatus);
    }

    function getClaim(uint256 policyId) external view returns (
        address claimant,
        uint256 claimAmount,
        uint40 submittedAt,
        bool processed,
        bool approved
    ) {
        Claim storage c = claims[policyId];
        return (c.claimant, c.claimAmount, c.submittedAt, c.processed, c.approved);
    }

    function isPolicyActive(uint256 policyId) external view returns (bool) {
        Policy storage p = policies[policyId];
        return p.active && block.timestamp <= p.endTime;
    }

    function poolReserves() external view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }
}
