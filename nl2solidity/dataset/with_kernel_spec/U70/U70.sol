// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CoverageMarket {
    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public operator;
    bool public paused;

    uint256 public constant MAX_COVERAGE_DURATION = 365 days;
    uint256 public constant CLAIM_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public maxCoverageDuration;
    uint256 public claimAssessmentPeriod;
    uint256 public policyCounter;

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    enum PolicyStatus {
        Requested,
        Active,
        ClaimFiled,
        Approved,
        Rejected,
        Expired,
        Cancelled
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Policy {
        address holder;
        address underwriter;
        uint256 coverageAmount;
        uint256 premium;
        uint256 duration;
        uint256 startTime;
        uint256 endTime;
        uint256 claimFiledTime;
        PolicyStatus status;
    }

    /*//////////////////////////////////////////////////////////////
                              MAPPINGS
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public collateralDeposits;
    mapping(uint256 => Policy) public policies;
    mapping(address => uint256[]) public holderPolicies;
    mapping(address => uint256[]) public underwrittenPolicies;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event PolicyRequested(
        uint256 indexed policyId,
        address indexed holder,
        uint256 coverageAmount,
        uint256 premium,
        uint256 duration
    );
    event PolicyUnderwritten(uint256 indexed policyId, address indexed underwriter, address indexed holder);
    event ClaimFiled(uint256 indexed policyId, address indexed holder);
    event ClaimApproved(uint256 indexed policyId, address indexed holder, uint256 payout, uint256 fee);
    event ClaimRejected(uint256 indexed policyId, address indexed holder);
    event PolicyExpired(uint256 indexed policyId);
    event RequestCancelled(uint256 indexed policyId);
    event MaxCoverageDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event ClaimAssessmentPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();
    error ContractPaused();
    error ZeroAmount();
    error ZeroAddress();
    error DurationExceedsMax();
    error InsufficientCollateral();
    error PolicyNotFound();
    error PolicyNotActive();
    error PolicyNotRequested();
    error NotPolicyHolder();
    error NoClaimFiled();
    error ClaimPeriodExpired();
    error AssessmentPeriodNotElapsed();
    error PolicyNotExpired();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 _claimAssessmentPeriod) {
        if (_claimAssessmentPeriod == 0) revert ZeroAmount();
        operator = msg.sender;
        maxCoverageDuration = MAX_COVERAGE_DURATION;
        claimAssessmentPeriod = _claimAssessmentPeriod;
        emit OperatorUpdated(address(0), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositCollateral() external payable whenNotPaused {
        if (msg.value == 0) revert ZeroAmount();
        collateralDeposits[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    function withdrawCollateral(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (collateralDeposits[msg.sender] < amount) revert InsufficientCollateral();
        collateralDeposits[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        POLICY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function requestCoverage(
        uint256 coverageAmount,
        uint256 premium,
        uint256 duration
    ) external whenNotPaused {
        if (coverageAmount == 0) revert ZeroAmount();
        if (premium == 0) revert ZeroAmount();
        if (duration == 0 || duration > maxCoverageDuration) revert DurationExceedsMax();
        if (collateralDeposits[msg.sender] < premium) revert InsufficientCollateral();

        collateralDeposits[msg.sender] -= premium;

        uint256 policyId = ++policyCounter;
        Policy storage p = policies[policyId];
        p.holder = msg.sender;
        p.coverageAmount = coverageAmount;
        p.premium = premium;
        p.duration = duration;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + duration;
        p.status = PolicyStatus.Requested;

        holderPolicies[msg.sender].push(policyId);

        emit PolicyRequested(policyId, msg.sender, coverageAmount, premium, duration);
    }

    function underwrite(uint256 policyId) external whenNotPaused {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotFound();
        if (p.status != PolicyStatus.Requested) revert PolicyNotRequested();
        if (collateralDeposits[msg.sender] < p.coverageAmount) revert InsufficientCollateral();

        collateralDeposits[msg.sender] -= p.coverageAmount;
        collateralDeposits[msg.sender] += p.premium;

        p.underwriter = msg.sender;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + p.duration;
        p.status = PolicyStatus.Active;

        underwrittenPolicies[msg.sender].push(policyId);

        emit PolicyUnderwritten(policyId, msg.sender, p.holder);
    }

    function fileClaim(uint256 policyId) external whenNotPaused {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotFound();
        if (p.holder != msg.sender) revert NotPolicyHolder();
        if (p.status != PolicyStatus.Active) revert PolicyNotActive();
        if (block.timestamp > p.endTime) revert PolicyNotActive();

        p.status = PolicyStatus.ClaimFiled;
        p.claimFiledTime = block.timestamp;

        emit ClaimFiled(policyId, msg.sender);
    }

    function approveClaim(uint256 policyId) external onlyOperator {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotFound();
        if (p.status != PolicyStatus.ClaimFiled) revert NoClaimFiled();
        if (block.timestamp > p.claimFiledTime + claimAssessmentPeriod) revert ClaimPeriodExpired();

        p.status = PolicyStatus.Approved;

        uint256 fee = (p.coverageAmount * CLAIM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = p.coverageAmount - fee;

        collateralDeposits[p.holder] += payout;
        collateralDeposits[operator] += fee;

        emit ClaimApproved(policyId, p.holder, payout, fee);
    }

    function rejectClaim(uint256 policyId) external onlyOperator {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotFound();
        if (p.status != PolicyStatus.ClaimFiled) revert NoClaimFiled();
        if (block.timestamp > p.claimFiledTime + claimAssessmentPeriod) revert ClaimPeriodExpired();

        p.status = PolicyStatus.Rejected;
        collateralDeposits[p.underwriter] += p.coverageAmount;

        emit ClaimRejected(policyId, p.holder);
    }

    function resolveExpiredClaim(uint256 policyId) external {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotFound();
        if (p.status != PolicyStatus.ClaimFiled) revert NoClaimFiled();
        if (block.timestamp <= p.claimFiledTime + claimAssessmentPeriod) revert AssessmentPeriodNotElapsed();

        p.status = PolicyStatus.Rejected;
        collateralDeposits[p.underwriter] += p.coverageAmount;

        emit ClaimRejected(policyId, p.holder);
    }

    function expirePolicy(uint256 policyId) external {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotFound();
        if (p.status != PolicyStatus.Active) revert PolicyNotActive();
        if (block.timestamp <= p.endTime) revert PolicyNotExpired();

        p.status = PolicyStatus.Expired;
        collateralDeposits[p.underwriter] += p.coverageAmount;

        emit PolicyExpired(policyId);
    }

    function cancelRequest(uint256 policyId) external whenNotPaused {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotFound();
        if (p.holder != msg.sender) revert NotPolicyHolder();
        if (p.status != PolicyStatus.Requested) revert PolicyNotRequested();

        p.status = PolicyStatus.Cancelled;
        collateralDeposits[p.holder] += p.premium;

        emit RequestCancelled(policyId);
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setMaxCoverageDuration(uint256 newDuration) external onlyOperator {
        if (newDuration == 0 || newDuration > MAX_COVERAGE_DURATION) revert DurationExceedsMax();
        emit MaxCoverageDurationUpdated(maxCoverageDuration, newDuration);
        maxCoverageDuration = newDuration;
    }

    function setClaimAssessmentPeriod(uint256 newPeriod) external onlyOperator {
        if (newPeriod == 0) revert ZeroAmount();
        emit ClaimAssessmentPeriodUpdated(claimAssessmentPeriod, newPeriod);
        claimAssessmentPeriod = newPeriod;
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function pause() external onlyOperator {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOperator {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHolderPolicies(address user) external view returns (uint256[] memory) {
        return holderPolicies[user];
    }

    function getUnderwrittenPolicies(address underwriter) external view returns (uint256[] memory) {
        return underwrittenPolicies[underwriter];
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function getPolicyCount() external view returns (uint256) {
        return policyCounter;
    }
}
