// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract DecentralizedInsurance {
    // ============ Errors ============
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error ProtocolNotRegistered();
    error ProtocolAlreadyRegistered();
    error ZeroAmount();
    error InsufficientAvailableCollateral();
    error InvalidDuration();
    error CoverageExceedsCapacity();
    error PolicyNotActive();
    error PolicyExpired();
    error ClaimAlreadyFiled();
    error InvalidClaimStatus();
    error NotPolicyBuyer();
    error ClaimAmountExceedsCoverage();
    error TransferFailed();
    error ReentrantCall();

    // ============ Events ============
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event ProtocolAdded(address indexed protocol, uint256 maxCoveragePerPolicy, uint256 premiumRatePerDay);
    event ProtocolParametersUpdated(address indexed protocol, uint256 maxCoveragePerPolicy, uint256 premiumRatePerDay);
    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed buyer,
        address indexed protocol,
        uint256 coverageAmount,
        uint256 startTime,
        uint256 endTime,
        uint256 premium,
        uint256 fee
    );
    event ClaimFiled(uint256 indexed policyId, address indexed claimant, uint256 claimAmount, uint256 filedAt);
    event ClaimApproved(uint256 indexed policyId, address indexed claimant, uint256 payoutAmount);
    event ClaimRejected(uint256 indexed policyId, address indexed claimant);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    // ============ Constants ============
    uint256 public constant MAX_COVERAGE_DURATION = 365 days;
    uint256 public constant FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ============ Structs ============
    struct ProtocolConfig {
        bool registered;
        uint256 maxCoveragePerPolicy;
        uint256 premiumRatePerDay; // premium per unit coverage per day, in basis points
        uint256 totalActiveCoverage;
    }

    struct Policy {
        uint256 policyId;
        address buyer;
        address protocol;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 premiumPaid;
        bool active;
    }

    enum ClaimStatus {
        None,
        Filed,
        Approved,
        Rejected
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        uint256 filedAt;
        ClaimStatus status;
    }

    // ============ State ============
    address public owner;
    address public operator;
    address public treasury;

    IERC20 public immutable stablecoin;

    uint256 public totalCollateralDeposited;
    uint256 public totalCoverageOutstanding;
    uint256 public nextPolicyId;

    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userAvailableCollateral;
    mapping(address => ProtocolConfig) public protocolConfigs;
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;

    // ============ Reentrancy Guard ============
    uint256 private _locked = 1;

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Access Control ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyRegisteredProtocol(address protocol) {
        if (!protocolConfigs[protocol].registered) revert ProtocolNotRegistered();
        _;
    }

    // ============ Constructor ============
    constructor(address _stablecoin, address _treasury, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        stablecoin = IERC20(_stablecoin);
        treasury = _treasury;
        operator = _operator;
        owner = msg.sender;
    }

    // ============ Admin Functions ============
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

    function addProtocol(
        address protocol,
        uint256 maxCoveragePerPolicy,
        uint256 premiumRatePerDay
    ) external onlyOperator {
        if (protocol == address(0)) revert ZeroAddress();
        if (protocolConfigs[protocol].registered) revert ProtocolAlreadyRegistered();
        if (maxCoveragePerPolicy == 0) revert ZeroAmount();

        protocolConfigs[protocol] = ProtocolConfig({
            registered: true,
            maxCoveragePerPolicy: maxCoveragePerPolicy,
            premiumRatePerDay: premiumRatePerDay,
            totalActiveCoverage: 0
        });

        emit ProtocolAdded(protocol, maxCoveragePerPolicy, premiumRatePerDay);
    }

    function updateProtocolParameters(
        address protocol,
        uint256 maxCoveragePerPolicy,
        uint256 premiumRatePerDay
    ) external onlyOperator onlyRegisteredProtocol(protocol) {
        if (maxCoveragePerPolicy == 0) revert ZeroAmount();

        ProtocolConfig storage config = protocolConfigs[protocol];
        config.maxCoveragePerPolicy = maxCoveragePerPolicy;
        config.premiumRatePerDay = premiumRatePerDay;

        emit ProtocolParametersUpdated(protocol, maxCoveragePerPolicy, premiumRatePerDay);
    }

    function approveClaim(uint256 policyId) external onlyOperator nonReentrant {
        Claim storage claim = claims[policyId];
        if (claim.status != ClaimStatus.Filed) revert InvalidClaimStatus();

        Policy storage policy = policies[policyId];
        if (!policy.active) revert PolicyNotActive();

        // Effects
        claim.status = ClaimStatus.Approved;
        policy.active = false;

        uint256 payout = claim.claimAmount;

        ProtocolConfig storage config = protocolConfigs[policy.protocol];
        if (config.totalActiveCoverage >= policy.coverageAmount) {
            config.totalActiveCoverage -= policy.coverageAmount;
        } else {
            config.totalActiveCoverage = 0;
        }

        if (totalCoverageOutstanding >= policy.coverageAmount) {
            totalCoverageOutstanding -= policy.coverageAmount;
        } else {
            totalCoverageOutstanding = 0;
        }

        if (totalCollateralDeposited >= payout) {
            totalCollateralDeposited -= payout;
        } else {
            totalCollateralDeposited = 0;
        }

        // Interaction
        bool success = stablecoin.transfer(policy.buyer, payout);
        if (!success) revert TransferFailed();

        emit ClaimApproved(policyId, policy.buyer, payout);
    }

    function rejectClaim(uint256 policyId) external onlyOperator {
        Claim storage claim = claims[policyId];
        if (claim.status != ClaimStatus.Filed) revert InvalidClaimStatus();

        Policy storage policy = policies[policyId];
        if (!policy.active) revert PolicyNotActive();

        claim.status = ClaimStatus.Rejected;
        policy.active = false;

        // Release the coverage lock back to the pool
        ProtocolConfig storage config = protocolConfigs[policy.protocol];
        if (config.totalActiveCoverage >= policy.coverageAmount) {
            config.totalActiveCoverage -= policy.coverageAmount;
        } else {
            config.totalActiveCoverage = 0;
        }

        if (totalCoverageOutstanding >= policy.coverageAmount) {
            totalCoverageOutstanding -= policy.coverageAmount;
        } else {
            totalCoverageOutstanding = 0;
        }

        emit ClaimRejected(policyId, policy.buyer);
    }

    // ============ User Functions ============
    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        bool success = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        userCollateral[msg.sender] += amount;
        userAvailableCollateral[msg.sender] += amount;
        totalCollateralDeposited += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userAvailableCollateral[msg.sender] < amount) revert InsufficientAvailableCollateral();

        userAvailableCollateral[msg.sender] -= amount;
        userCollateral[msg.sender] -= amount;
        totalCollateralDeposited -= amount;

        bool success = stablecoin.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function purchaseCoverage(
        address protocol,
        uint256 coverageAmount,
        uint256 duration
    ) external onlyRegisteredProtocol(protocol) nonReentrant returns (uint256 policyId) {
        if (coverageAmount == 0) revert ZeroAmount();
        if (duration == 0 || duration > MAX_COVERAGE_DURATION) revert InvalidDuration();

        ProtocolConfig storage config = protocolConfigs[protocol];
        if (coverageAmount > config.maxCoveragePerPolicy) revert CoverageExceedsCapacity();

        // Compute premium and fee from the full numerator to avoid
        // divide-before-multiply precision loss.
        // rawPremium = coverageAmount * premiumRatePerDay * duration
        // totalCost  = rawPremium * (BPS_DENOMINATOR + FEE_BPS) / BPS_DENOMINATOR^2
        // premium    = rawPremium / BPS_DENOMINATOR
        // fee        = totalCost - premium
        uint256 rawPremium = coverageAmount * config.premiumRatePerDay * duration;
        uint256 totalCost = (rawPremium * (BPS_DENOMINATOR + FEE_BPS)) /
            (BPS_DENOMINATOR * BPS_DENOMINATOR);
        uint256 premium = rawPremium / BPS_DENOMINATOR;
        uint256 fee = totalCost - premium;

        if (userAvailableCollateral[msg.sender] < totalCost) revert InsufficientAvailableCollateral();

        // Verify the global pool has enough free capacity to back this coverage
        uint256 availableCoverage = totalCollateralDeposited > totalCoverageOutstanding
            ? totalCollateralDeposited - totalCoverageOutstanding
            : 0;
        if (coverageAmount > availableCoverage) revert CoverageExceedsCapacity();

        // Effects: deduct premium + fee from user's available collateral and pool
        userAvailableCollateral[msg.sender] -= totalCost;
        totalCollateralDeposited -= totalCost;

        // Lock coverage amount in the pool
        config.totalActiveCoverage += coverageAmount;
        totalCoverageOutstanding += coverageAmount;

        // Interaction: send fee to treasury
        if (fee > 0) {
            bool feeSuccess = stablecoin.transfer(treasury, fee);
            if (!feeSuccess) revert TransferFailed();
        }

        // Create policy
        policyId = nextPolicyId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        policies[policyId] = Policy({
            policyId: policyId,
            buyer: msg.sender,
            protocol: protocol,
            coverageAmount: coverageAmount,
            startTime: startTime,
            endTime: endTime,
            premiumPaid: premium,
            active: true
        });

        emit PolicyPurchased(policyId, msg.sender, protocol, coverageAmount, startTime, endTime, premium, fee);
    }

    function fileClaim(uint256 policyId, uint256 claimAmount) external nonReentrant {
        Policy storage policy = policies[policyId];
        if (!policy.active) revert PolicyNotActive();
        if (policy.buyer != msg.sender) revert NotPolicyBuyer();
        if (claims[policyId].status != ClaimStatus.None) revert ClaimAlreadyFiled();
        if (claimAmount == 0) revert ZeroAmount();
        if (claimAmount > policy.coverageAmount) revert ClaimAmountExceedsCoverage();

        claims[policyId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            claimAmount: claimAmount,
            filedAt: block.timestamp,
            status: ClaimStatus.Filed
        });

        emit ClaimFiled(policyId, msg.sender, claimAmount, block.timestamp);
    }

    // ============ View Functions ============
    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function getClaim(uint256 policyId) external view returns (Claim memory) {
        return claims[policyId];
    }

    function getProtocolConfig(address protocol) external view returns (ProtocolConfig memory) {
        return protocolConfigs[protocol];
    }

    function isPolicyActive(uint256 policyId) external view returns (bool) {
        Policy storage policy = policies[policyId];
        return policy.active && block.timestamp <= policy.endTime;
    }

    function totalAvailableCoverage() external view returns (uint256) {
        if (totalCollateralDeposited > totalCoverageOutstanding) {
            return totalCollateralDeposited - totalCoverageOutstanding;
        }
        return 0;
    }

    function previewPremium(
        address protocol,
        uint256 coverageAmount,
        uint256 duration
    ) external view onlyRegisteredProtocol(protocol) returns (uint256 premium, uint256 fee, uint256 totalCost) {
        ProtocolConfig storage config = protocolConfigs[protocol];
        uint256 rawPremium = coverageAmount * config.premiumRatePerDay * duration;
        totalCost = (rawPremium * (BPS_DENOMINATOR + FEE_BPS)) /
            (BPS_DENOMINATOR * BPS_DENOMINATOR);
        premium = rawPremium / BPS_DENOMINATOR;
        fee = totalCost - premium;
    }
}
