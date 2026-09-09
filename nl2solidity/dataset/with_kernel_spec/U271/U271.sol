// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20
 * @dev Minimal ERC20 interface for the CoveragePool.
 */
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

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure when the token
 *      contract returns false. The safeTransferFrom helper always uses
 *      msg.sender as the source to prevent arbitrary token pulls.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    /**
     * @dev Transfers tokens from msg.sender to `to`. The `from` is hardcoded
     *      to msg.sender to avoid arbitrary-send-erc20 vulnerabilities.
     */
    function safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transferFrom(msg.sender, to, amount);
        if (!ok) revert SafeERC20FailedOperation(address(token));
    }

    error SafeERC20FailedOperation(address token);
}

/**
 * @title ReentrancyGuard
 * @dev Contract module that helps prevent reentrant calls.
 */
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    error ReentrancyGuardReentrantCall();
}

/**
 * @title Ownable
 * @dev Contract module providing basic access control where only the owner
 *      can call certain functions.
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        address currentOwner = owner();
        if (msg.sender != currentOwner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        address previousOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address previousOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }

    function _checkOwner() internal view {
        if (msg.sender != owner()) revert OwnableUnauthorizedAccount(msg.sender);
    }
}

/**
 * @title CoveragePool
 * @notice A decentralized coverage pool that accepts multiple ERC20 collateral
 *         tokens, issues coverage policies against defined risks, and manages
 *         claim filing, resolution, and fee accrual.
 */
contract CoveragePool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────
    uint256 public constant MIN_DURATION = 7 days;
    uint256 public constant MAX_DURATION = 365 days;
    uint256 public constant POLICY_FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOM = 10000;
    uint256 public constant PRECISION = 1e18;

    // ─────────────────────────────────────────────
    // Enums
    // ─────────────────────────────────────────────
    enum ClaimStatus { None, Pending, Approved, Rejected }

    // ─────────────────────────────────────────────
    // Structs
    // ─────────────────────────────────────────────
    struct Policy {
        address holder;
        address collateralToken;
        address coveredAsset;
        uint256 coverageAmount;
        uint256 premiumAmount;
        uint256 feeAmount;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool claimFiled;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 amount;
        uint256 filedAt;
        ClaimStatus status;
    }

    // ─────────────────────────────────────────────
    // State Variables
    // ─────────────────────────────────────────────
    /// @dev user => token => deposited collateral
    mapping(address => mapping(address => uint256)) public collateral;
    /// @dev token => sum of all user collateral balances
    mapping(address => uint256) public totalCollateral;
    /// @dev token => supported flag
    mapping(address => bool) public supportedTokens;
    /// @dev coveredAsset => premium rate per second per unit of coverage (1e18 precision)
    mapping(address => uint256) public premiumRate;
    /// @dev token => accrued protocol fees, claimable by admin
    mapping(address => uint256) public feesAccrued;
    /// @dev token => tokens reserved for pending claim payouts
    mapping(address => uint256) public pendingPayouts;

    uint256 public claimProcessingDelay;
    bool public policyPurchasePaused;

    uint256 public nextPolicyId;
    uint256 public nextClaimId;

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) internal _userPolicies;
    mapping(address => uint256[]) internal _userClaims;
    uint256[] internal _pendingClaimIds;

    // ─────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed holder,
        address indexed coveredAsset,
        address collateralToken,
        uint256 coverageAmount,
        uint256 premiumAmount,
        uint256 feeAmount,
        uint256 startTime,
        uint256 endTime
    );
    event ClaimFiled(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimResolved(uint256 indexed claimId, ClaimStatus status, uint256 payoutAmount);
    event PremiumRateUpdated(address indexed coveredAsset, uint256 oldRate, uint256 newRate);
    event ClaimProcessingDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event PolicyPurchasePauseChanged(bool paused);
    event TokenSupportUpdated(address indexed token, bool supported);
    event FeesWithdrawn(address indexed token, address indexed recipient, uint256 amount);

    // ─────────────────────────────────────────────
    // Custom Errors
    // ─────────────────────────────────────────────
    error TokenNotSupported();
    error DurationOutOfRange();
    error InsufficientCollateral();
    error PolicyNotActive();
    error PolicyExpired();
    error PolicyAlreadyClaimed();
    error ClaimNotPending();
    error NotPolicyHolder();
    error PolicyPurchasePausedError();
    error ZeroAmount();
    error ClaimResolutionTooEarly();
    error InvalidPayoutAmount();
    error InsufficientPoolBalance();

    // ─────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────
    constructor(uint256 _claimProcessingDelay) Ownable(msg.sender) ReentrancyGuard() {
        claimProcessingDelay = _claimProcessingDelay;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    // ─────────────────────────────────────────────
    // Modifiers
    // ─────────────────────────────────────────────
    modifier whenPurchaseNotPaused() {
        if (policyPurchasePaused) revert PolicyPurchasePausedError();
        _;
    }

    // ─────────────────────────────────────────────
    // Admin Functions
    // ─────────────────────────────────────────────
    function setTokenSupport(address token, bool supported) external onlyOwner {
        supportedTokens[token] = supported;
        emit TokenSupportUpdated(token, supported);
    }

    function setPremiumRate(address coveredAsset, uint256 rate) external onlyOwner {
        emit PremiumRateUpdated(coveredAsset, premiumRate[coveredAsset], rate);
        premiumRate[coveredAsset] = rate;
    }

    function setClaimProcessingDelay(uint256 delay) external onlyOwner {
        emit ClaimProcessingDelayUpdated(claimProcessingDelay, delay);
        claimProcessingDelay = delay;
    }

    function setPolicyPurchasePaused(bool paused) external onlyOwner {
        policyPurchasePaused = paused;
        emit PolicyPurchasePauseChanged(paused);
    }

    function withdrawFees(address token) external onlyOwner nonReentrant {
        uint256 amount = feesAccrued[token];
        if (amount == 0) revert ZeroAmount();
        feesAccrued[token] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit FeesWithdrawn(token, msg.sender, amount);
    }

    // ─────────────────────────────────────────────
    // Collateral Functions
    // ─────────────────────────────────────────────
    function depositCollateral(address token, uint256 amount) external nonReentrant {
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert ZeroAmount();
        collateral[msg.sender][token] += amount;
        totalCollateral[token] += amount;
        IERC20(token).safeTransferFrom(address(this), amount);
        emit CollateralDeposited(msg.sender, token, amount);
    }

    function withdrawCollateral(address token, uint256 amount) external nonReentrant {
        if (!supportedTokens[token]) revert TokenNotSupported();
        if (amount == 0) revert ZeroAmount();
        uint256 avail = availableForWithdrawal(msg.sender, token);
        if (amount > avail) revert InsufficientCollateral();
        collateral[msg.sender][token] -= amount;
        totalCollateral[token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /// @notice Returns the maximum collateral a user can withdraw for a token,
    ///         accounting for protocol fees and pending claim payouts.
    function availableForWithdrawal(address user, address token) public view returns (uint256) {
        uint256 userBalance = collateral[user][token];
        if (userBalance == 0) return 0;
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        uint256 reserved = feesAccrued[token] + pendingPayouts[token];
        uint256 poolAvailable = contractBalance > reserved ? contractBalance - reserved : 0;
        return userBalance < poolAvailable ? userBalance : poolAvailable;
    }

    // ─────────────────────────────────────────────
    // Policy Functions
    // ─────────────────────────────────────────────
    function purchasePolicy(
        address collateralToken,
        address coveredAsset,
        uint256 coverageAmount,
        uint256 duration
    ) external whenPurchaseNotPaused nonReentrant returns (uint256 policyId) {
        if (!supportedTokens[collateralToken]) revert TokenNotSupported();
        if (duration < MIN_DURATION || duration > MAX_DURATION) revert DurationOutOfRange();
        if (coverageAmount == 0) revert ZeroAmount();

        uint256 rate = premiumRate[coveredAsset];

        // Compute the raw premium numerator before any division to avoid
        // divide-before-multiply precision loss.
        uint256 basePremiumNumerator = coverageAmount * rate * duration;

        uint256 premium = basePremiumNumerator / PRECISION;
        if (premium == 0) revert ZeroAmount();

        // Compute fee from the undivided numerator to preserve full precision.
        uint256 fee = (basePremiumNumerator * POLICY_FEE_BPS) / (PRECISION * BPS_DENOM);

        uint256 totalCharge = premium + fee;

        if (collateral[msg.sender][collateralToken] < totalCharge) revert InsufficientCollateral();

        collateral[msg.sender][collateralToken] -= totalCharge;
        totalCollateral[collateralToken] -= totalCharge;
        feesAccrued[collateralToken] += fee;

        policyId = nextPolicyId++;
        policies[policyId] = Policy({
            holder: msg.sender,
            collateralToken: collateralToken,
            coveredAsset: coveredAsset,
            coverageAmount: coverageAmount,
            premiumAmount: premium,
            feeAmount: fee,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            active: true,
            claimFiled: false
        });
        _userPolicies[msg.sender].push(policyId);

        emit PolicyPurchased(
            policyId,
            msg.sender,
            coveredAsset,
            collateralToken,
            coverageAmount,
            premium,
            fee,
            block.timestamp,
            block.timestamp + duration
        );
    }

    // ─────────────────────────────────────────────
    // Claim Functions
    // ─────────────────────────────────────────────
    function fileClaim(uint256 policyId, uint256 amount) external nonReentrant returns (uint256 claimId) {
        Policy storage p = policies[policyId];
        if (p.holder == address(0)) revert PolicyNotActive();
        if (p.holder != msg.sender) revert NotPolicyHolder();
        if (!p.active) revert PolicyNotActive();
        if (p.claimFiled) revert PolicyAlreadyClaimed();
        if (block.timestamp > p.endTime) revert PolicyExpired();
        if (amount == 0 || amount > p.coverageAmount) revert InvalidPayoutAmount();

        uint256 contractBalance = IERC20(p.collateralToken).balanceOf(address(this));
        uint256 reserved = feesAccrued[p.collateralToken] + pendingPayouts[p.collateralToken];
        if (contractBalance < reserved + amount) revert InsufficientPoolBalance();

        p.claimFiled = true;
        p.active = false;
        pendingPayouts[p.collateralToken] += amount;

        claimId = nextClaimId++;
        claims[claimId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            amount: amount,
            filedAt: block.timestamp,
            status: ClaimStatus.Pending
        });
        _userClaims[msg.sender].push(claimId);
        _pendingClaimIds.push(claimId);

        emit ClaimFiled(claimId, policyId, msg.sender, amount);
    }

    function approveClaim(uint256 claimId) external onlyOwner nonReentrant {
        Claim storage c = claims[claimId];
        if (c.status != ClaimStatus.Pending) revert ClaimNotPending();
        if (block.timestamp < c.filedAt + claimProcessingDelay) revert ClaimResolutionTooEarly();

        Policy storage p = policies[c.policyId];
        c.status = ClaimStatus.Approved;
        pendingPayouts[p.collateralToken] -= c.amount;

        IERC20(p.collateralToken).safeTransfer(c.claimant, c.amount);

        _removePendingClaim(claimId);

        emit ClaimResolved(claimId, ClaimStatus.Approved, c.amount);
    }

    function rejectClaim(uint256 claimId) external onlyOwner nonReentrant {
        Claim storage c = claims[claimId];
        if (c.status != ClaimStatus.Pending) revert ClaimNotPending();

        Policy storage p = policies[c.policyId];
        c.status = ClaimStatus.Rejected;
        pendingPayouts[p.collateralToken] -= c.amount;

        _removePendingClaim(claimId);

        emit ClaimResolved(claimId, ClaimStatus.Rejected, 0);
    }

    // ─────────────────────────────────────────────
    // View Functions
    // ─────────────────────────────────────────────
    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return _userPolicies[user];
    }

    function getUserClaims(address user) external view returns (uint256[] memory) {
        return _userClaims[user];
    }

    function getPendingClaimIds() external view returns (uint256[] memory) {
        return _pendingClaimIds;
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function getClaim(uint256 claimId) external view returns (Claim memory) {
        return claims[claimId];
    }

    // ─────────────────────────────────────────────
    // Internal Helpers
    // ─────────────────────────────────────────────
    function _removePendingClaim(uint256 claimId) internal {
        uint256 len = _pendingClaimIds.length;
        for (uint256 i = 0; i < len; i++) {
            if (_pendingClaimIds[i] == claimId) {
                _pendingClaimIds[i] = _pendingClaimIds[len - 1];
                _pendingClaimIds.pop();
                break;
            }
        }
    }
}
