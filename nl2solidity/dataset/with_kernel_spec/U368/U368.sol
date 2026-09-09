// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        require(success, "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        require(success, "SafeERC20: transferFrom failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

/// @title DecentralizedCoverage
/// @notice A decentralized coverage pool that accepts collateral deposits and sells
///         vulnerability coverage policies for smart contracts. Operators report
///         vulnerabilities, and approved claims pay out 90% of the covered amount.
contract DecentralizedCoverage is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------
    //                            Errors
    // ------------------------------------------------------------------
    error NotOperator();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidDuration();
    error ExceedsMaxCoverage();
    error Paused();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error PolicyNotFound();
    error PolicyNotActive();
    error NotPolicyOwner();
    error PolicyAlreadyClaimed();
    error NoVulnerabilityReported();
    error ClaimWindowClosed();
    error PolicyNotExpired();
    error PolicyAlreadyExpired();
    error ClaimNotFound();
    error ClaimAlreadyResolved();
    error ZeroPremium();
    error InvalidPremiumRate();

    // ------------------------------------------------------------------
    //                            Constants
    // ------------------------------------------------------------------
    /// @dev Approved claims pay out 90% of the covered amount.
    uint256 public constant PAYOUT_RATIO = 90;
    uint256 public constant PAYOUT_DENOMINATOR = 100;
    /// @dev Claims must be filed within 90 days of a reported vulnerability.
    uint256 public constant CLAIM_WINDOW = 90 days;
    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 365 days;
    uint256 public constant BASIS_POINTS = 10_000;

    // ------------------------------------------------------------------
    //                            Storage
    // ------------------------------------------------------------------
    IERC20 public immutable collateralToken;
    address public operator;
    bool public paused;

    /// @dev Total amount of collateral tokens currently held by the contract.
    uint256 public totalCollateral;
    /// @dev Sum of the potential payouts (90% of coverage) for active policies.
    uint256 public totalActivePayoutLiability;

    /// @dev Premium rate expressed in basis points of coverage per day (1 = 0.01%).
    uint256 public premiumRatePerDay;
    /// @dev Maximum coverage amount that can be purchased in a single policy.
    uint256 public maxCoverageAmount;

    struct Policy {
        address owner;
        address smartContract;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool claimed;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        address smartContract;
        uint256 coverageAmount;
        uint256 filedAt;
        uint256 vulnerabilityReportedAt;
        bool approved;
        bool rejected;
        bool resolved;
    }

    mapping(address => uint256) public collateralBalance;
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256) public lastVulnerabilityReport;

    uint256 public policyCount;
    uint256 public claimCount;

    // ------------------------------------------------------------------
    //                            Events
    // ------------------------------------------------------------------
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed owner,
        address indexed smartContract,
        uint256 coverageAmount,
        uint256 premium,
        uint256 startTime,
        uint256 endTime
    );
    event PremiumPaid(uint256 indexed policyId, address indexed payer, uint256 premium);
    event VulnerabilityReported(address indexed smartContract, uint256 timestamp);
    event ClaimFiled(
        uint256 indexed claimId,
        uint256 indexed policyId,
        address indexed claimant,
        address smartContract,
        uint256 coverageAmount
    );
    event ClaimResolved(
        uint256 indexed claimId,
        uint256 indexed policyId,
        bool approved,
        uint256 payout
    );
    event PremiumRateUpdated(uint256 oldRate, uint256 newRate);
    event MaxCoverageUpdated(uint256 oldMax, uint256 newMax);
    event PausedChanged(bool paused);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    // ------------------------------------------------------------------
    //                            Modifiers
    // ------------------------------------------------------------------
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    // ------------------------------------------------------------------
    //                            Constructor
    // ------------------------------------------------------------------
    constructor(
        address _collateralToken,
        address _operator,
        uint256 _premiumRatePerDay,
        uint256 _maxCoverageAmount
    ) {
        if (_collateralToken == address(0) || _operator == address(0)) revert ZeroAddress();
        if (_premiumRatePerDay == 0) revert ZeroAmount();
        if (_maxCoverageAmount == 0) revert ZeroAmount();

        collateralToken = IERC20(_collateralToken);
        operator = _operator;
        premiumRatePerDay = _premiumRatePerDay;
        maxCoverageAmount = _maxCoverageAmount;
    }

    // ------------------------------------------------------------------
    //                       Collateral Management
    // ------------------------------------------------------------------

    /// @notice Deposits collateral tokens into the pool, crediting the caller.
    /// @param amount The amount of collateral tokens to deposit.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        collateralBalance[msg.sender] += amount;
        totalCollateral += amount;

        emit CollateralDeposited(msg.sender, amount);

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Withdraws available collateral, subject to pool solvency constraints.
    /// @param amount The amount of collateral tokens to withdraw.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 balance = collateralBalance[msg.sender];
        if (balance < amount) revert InsufficientCollateral();

        // Ensure the pool remains solvent after the withdrawal: the remaining
        // collateral must cover all active payout liabilities.
        if (totalCollateral - amount < totalActivePayoutLiability) {
            revert InsufficientLiquidity();
        }

        // Effects
        collateralBalance[msg.sender] = balance - amount;
        totalCollateral -= amount;

        emit CollateralWithdrawn(msg.sender, amount);

        // Interactions
        collateralToken.safeTransfer(msg.sender, amount);
    }

    // ------------------------------------------------------------------
    //                       Coverage Purchases
    // ------------------------------------------------------------------

    /// @notice Purchases coverage for a specified smart contract.
    /// @param smartContract The address of the contract being covered.
    /// @param coverageAmount The amount of coverage to purchase.
    /// @param duration The duration of the policy.
    /// @return policyId The id of the newly created policy.
    function purchaseCoverage(
        address smartContract,
        uint256 coverageAmount,
        uint256 duration
    ) external whenNotPaused nonReentrant returns (uint256 policyId) {
        if (smartContract == address(0)) revert ZeroAddress();
        if (coverageAmount == 0) revert ZeroAmount();
        if (duration < MIN_DURATION || duration > MAX_DURATION) revert InvalidDuration();
        if (coverageAmount > maxCoverageAmount) revert ExceedsMaxCoverage();

        uint256 premium = computePremium(coverageAmount, duration);
        if (premium == 0) revert ZeroPremium();

        uint256 balance = collateralBalance[msg.sender];
        if (balance < premium) revert InsufficientCollateral();

        // Effects
        policyId = policyCount++;
        policies[policyId] = Policy({
            owner: msg.sender,
            smartContract: smartContract,
            coverageAmount: coverageAmount,
            premium: premium,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            active: true,
            claimed: false
        });

        collateralBalance[msg.sender] = balance - premium;
        totalActivePayoutLiability += (coverageAmount * PAYOUT_RATIO) / PAYOUT_DENOMINATOR;

        emit PremiumPaid(policyId, msg.sender, premium);
        emit PolicyPurchased(
            policyId,
            msg.sender,
            smartContract,
            coverageAmount,
            premium,
            block.timestamp,
            block.timestamp + duration
        );
    }

    /// @notice Computes the premium for a given coverage amount and duration.
    /// @dev Premium = coverageAmount * premiumRatePerDay * durationDays / 10_000.
    function computePremium(uint256 coverageAmount, uint256 duration) public view returns (uint256) {
        uint256 durationDays = duration / 1 days;
        return (coverageAmount * premiumRatePerDay * durationDays) / BASIS_POINTS;
    }

    // ------------------------------------------------------------------
    //                          Claims
    // ------------------------------------------------------------------

    /// @notice Files a claim against an active policy for a reported vulnerability.
    /// @dev Claims must be filed within 90 days of the vulnerability report and
    ///      while the policy is still active.
    function fileClaim(uint256 policyId) external nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.owner == address(0)) revert PolicyNotFound();
        if (policy.owner != msg.sender) revert NotPolicyOwner();
        if (!policy.active) revert PolicyNotActive();
        if (policy.claimed) revert PolicyAlreadyClaimed();
        if (block.timestamp > policy.endTime) revert PolicyNotActive();

        uint256 vulnTime = lastVulnerabilityReport[policy.smartContract];
        if (vulnTime == 0) revert NoVulnerabilityReported();
        if (block.timestamp > vulnTime + CLAIM_WINDOW) revert ClaimWindowClosed();

        // Effects: mark policy as claimed and inactive. Liability is retained
        // until the claim is resolved.
        policy.claimed = true;
        policy.active = false;

        uint256 claimId = claimCount++;
        claims[claimId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            smartContract: policy.smartContract,
            coverageAmount: policy.coverageAmount,
            filedAt: block.timestamp,
            vulnerabilityReportedAt: vulnTime,
            approved: false,
            rejected: false,
            resolved: false
        });

        emit ClaimFiled(claimId, policyId, msg.sender, policy.smartContract, policy.coverageAmount);
    }

    /// @notice Approves a filed claim and pays out 90% of the covered amount.
    function approveClaim(uint256 claimId) external onlyOperator nonReentrant {
        Claim storage claim = claims[claimId];
        if (claim.claimant == address(0)) revert ClaimNotFound();
        if (claim.resolved) revert ClaimAlreadyResolved();

        uint256 payout = (claim.coverageAmount * PAYOUT_RATIO) / PAYOUT_DENOMINATOR;
        if (totalCollateral < payout) revert InsufficientLiquidity();

        // Effects
        claim.approved = true;
        claim.resolved = true;
        totalActivePayoutLiability -= payout;
        totalCollateral -= payout;

        emit ClaimResolved(claimId, claim.policyId, true, payout);

        // Interactions
        collateralToken.safeTransfer(claim.claimant, payout);
    }

    /// @notice Rejects a filed claim; no payout is made and the liability is released.
    function rejectClaim(uint256 claimId) external onlyOperator nonReentrant {
        Claim storage claim = claims[claimId];
        if (claim.claimant == address(0)) revert ClaimNotFound();
        if (claim.resolved) revert ClaimAlreadyResolved();

        // Effects
        claim.rejected = true;
        claim.resolved = true;

        // The policy was closed when the claim was filed; release its liability.
        totalActivePayoutLiability -= (claim.coverageAmount * PAYOUT_RATIO) / PAYOUT_DENOMINATOR;

        emit ClaimResolved(claimId, claim.policyId, false, 0);
    }

    // ------------------------------------------------------------------
    //                       Policy Expiration
    // ------------------------------------------------------------------

    /// @notice Marks an expired, unclaimed policy as inactive and releases its liability.
    /// @dev Anyone may call this once a policy has passed its end time.
    function expirePolicy(uint256 policyId) external nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.owner == address(0)) revert PolicyNotFound();
        if (block.timestamp <= policy.endTime) revert PolicyNotExpired();
        if (!policy.active) revert PolicyAlreadyExpired();

        policy.active = false;
        totalActivePayoutLiability -= (policy.coverageAmount * PAYOUT_RATIO) / PAYOUT_DENOMINATOR;
    }

    // ------------------------------------------------------------------
    //                       Operator Configuration
    // ------------------------------------------------------------------

    /// @notice Reports a vulnerability for a smart contract, opening the claim window.
    function reportVulnerability(address smartContract) external onlyOperator {
        if (smartContract == address(0)) revert ZeroAddress();
        lastVulnerabilityReport[smartContract] = block.timestamp;
        emit VulnerabilityReported(smartContract, block.timestamp);
    }

    /// @notice Updates the premium rate (in basis points of coverage per day).
    function setPremiumRate(uint256 newRate) external onlyOperator {
        if (newRate == 0 || newRate > BASIS_POINTS) revert InvalidPremiumRate();
        uint256 oldRate = premiumRatePerDay;
        premiumRatePerDay = newRate;
        emit PremiumRateUpdated(oldRate, newRate);
    }

    /// @notice Updates the maximum coverage amount purchasable in a single policy.
    function setMaxCoverageAmount(uint256 newMax) external onlyOperator {
        if (newMax == 0) revert ZeroAmount();
        uint256 oldMax = maxCoverageAmount;
        maxCoverageAmount = newMax;
        emit MaxCoverageUpdated(oldMax, newMax);
    }

    /// @notice Pauses or unpauses new policy purchases. Does not affect deposits,
    ///         withdrawals, or claim handling.
    function setPaused(bool _paused) external onlyOperator {
        paused = _paused;
        emit PausedChanged(_paused);
    }

    /// @notice Transfers the operator role to a new address.
    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorChanged(oldOperator, newOperator);
    }

    // ------------------------------------------------------------------
    //                          View Helpers
    // ------------------------------------------------------------------

    /// @notice Returns the withdrawable collateral for a user. Note that actual
    ///         withdrawals are also constrained by pool solvency.
    function availableCollateral(address user) external view returns (uint256) {
        return collateralBalance[user];
    }

    /// @notice Returns whether a policy is currently active and unexpired.
    function isPolicyActive(uint256 policyId) external view returns (bool) {
        Policy storage policy = policies[policyId];
        return policy.active && block.timestamp <= policy.endTime;
    }

    /// @notice Returns the remaining time to file a claim for a smart contract.
    function claimWindowRemaining(address smartContract) external view returns (uint256) {
        uint256 vulnTime = lastVulnerabilityReport[smartContract];
        if (vulnTime == 0) return 0;
        uint256 deadline = vulnTime + CLAIM_WINDOW;
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
}
