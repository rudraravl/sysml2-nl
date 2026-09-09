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

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Unauthorized();
    error ZeroAddress();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert Unauthorized();
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title InsuranceFund
 * @notice Decentralized insurance fund where underwriters deposit stablecoins
 *         to back coverage policies. Users purchase coverage for specified
 *         assets, submit claims against active policies, and a designated
 *         operator approves or rejects claims. A 1% fee on every policy
 *         purchase is routed to the protocol treasury.
 */
contract InsuranceFund is Ownable {
    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint256 public constant MAX_COVERAGE_DAYS = 365;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant FEE_BPS = 100;
    uint256 public constant MAX_PREMIUM_RATE = 5000;

    // ---------------------------------------------------------------------
    // Immutables & State
    // ---------------------------------------------------------------------

    IERC20 public immutable stablecoin;
    address public treasury;
    address public operator;

    uint256 public premiumRate = 500;

    uint256 public totalReserve;
    uint256 public totalUnderwriting;
    mapping(address => uint256) public underwriterBalance;

    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;

    enum PolicyStatus {None, Active, Claimed, Cancelled}
    enum ClaimStatus {None, Pending, Approved, Rejected}

    struct Policy {
        address buyer;
        address asset;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 feePaid;
        uint256 startTime;
        uint256 endTime;
        PolicyStatus status;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 amount;
        ClaimStatus status;
        string proof;
        uint256 submittedAt;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposited(address indexed underwriter, uint256 amount);
    event Withdrawn(address indexed underwriter, uint256 amount);
    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed buyer,
        address indexed asset,
        uint256 coverageAmount,
        uint256 premium,
        uint256 fee
    );
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address claimant, uint256 amount);
    event ClaimApproved(uint256 indexed claimId, uint256 payout);
    event ClaimRejected(uint256 indexed claimId);
    event TreasuryUpdated(address newTreasury);
    event OperatorUpdated(address newOperator);
    event PremiumRateUpdated(uint256 newPremiumRate);

    // ---------------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------------

    error ZeroAddressErr();
    error InvalidAmount();
    error InvalidDuration();
    error InsufficientReserve();
    error InsufficientUnderwriterBalance();
    error PolicyNotActive();
    error PolicyExpired();
    error ExceedsCoverage();
    error NotPolicyBuyer();
    error InvalidClaimStatus();
    error UnauthorizedOperator();
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != operator) revert UnauthorizedOperator();
        _;
    }

    // ---------------------------------------------------------------------
    // Internal Helpers
    // ---------------------------------------------------------------------

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
            revert TransferFailed();
        }
        if (data.length > 0 && !abi.decode(data, (bool))) revert TransferFailed();
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor(address _stablecoin, address _treasury, address _operator) Ownable(msg.sender) {
        if (_stablecoin == address(0) || _treasury == address(0) || _operator == address(0)) revert ZeroAddressErr();
        stablecoin = IERC20(_stablecoin);
        treasury = _treasury;
        operator = _operator;
    }

    // ---------------------------------------------------------------------
    // Underwriter Functions
    // ---------------------------------------------------------------------

    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        _safeTransferFrom(address(stablecoin), msg.sender, address(this), amount);
        underwriterBalance[msg.sender] += amount;
        totalUnderwriting += amount;
        totalReserve += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (underwriterBalance[msg.sender] < amount) revert InsufficientUnderwriterBalance();
        if (totalReserve < amount) revert InsufficientReserve();

        underwriterBalance[msg.sender] -= amount;
        totalUnderwriting -= amount;
        totalReserve -= amount;

        _safeTransfer(address(stablecoin), msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // ---------------------------------------------------------------------
    // Policy Purchase
    // ---------------------------------------------------------------------

    function purchaseCoverage(
        address asset,
        uint256 coverageAmount,
        uint256 durationDays
    ) external returns (uint256 policyId) {
        if (asset == address(0)) revert ZeroAddressErr();
        if (coverageAmount == 0) revert InvalidAmount();
        if (durationDays == 0 || durationDays > MAX_COVERAGE_DAYS) revert InvalidDuration();

        // Compute fee directly from coverageAmount to avoid divide-before-multiply.
        // fee = coverageAmount * premiumRate * FEE_BPS / (BPS_DENOMINATOR * BPS_DENOMINATOR)
        uint256 fee = (coverageAmount * premiumRate * FEE_BPS) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
        uint256 premium = (coverageAmount * premiumRate) / BPS_DENOMINATOR;
        if (premium == 0) revert InvalidAmount();
        // toReserve is the portion of the premium remaining after the fee.
        uint256 toReserve = premium - fee;

        _safeTransferFrom(address(stablecoin), msg.sender, address(this), premium);
        if (fee > 0) {
            _safeTransfer(address(stablecoin), treasury, fee);
        }
        totalReserve += toReserve;

        policyId = nextPolicyId++;
        policies[policyId] = Policy({
            buyer: msg.sender,
            asset: asset,
            coverageAmount: coverageAmount,
            premiumPaid: premium,
            feePaid: fee,
            startTime: block.timestamp,
            endTime: block.timestamp + (durationDays * 1 days),
            status: PolicyStatus.Active
        });

        emit PolicyPurchased(policyId, msg.sender, asset, coverageAmount, premium, fee);
    }

    // ---------------------------------------------------------------------
    // Claim Submission & Processing
    // ---------------------------------------------------------------------

    function submitClaim(
        uint256 policyId,
        uint256 amount,
        string calldata proof
    ) external returns (uint256 claimId) {
        Policy storage policy = policies[policyId];
        if (policy.buyer == address(0)) revert InvalidClaimStatus();
        if (policy.status != PolicyStatus.Active) revert PolicyNotActive();
        if (block.timestamp > policy.endTime) revert PolicyExpired();
        if (msg.sender != policy.buyer) revert NotPolicyBuyer();
        if (amount == 0 || amount > policy.coverageAmount) revert ExceedsCoverage();

        claimId = nextClaimId++;
        claims[claimId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            amount: amount,
            status: ClaimStatus.Pending,
            proof: proof,
            submittedAt: block.timestamp
        });

        emit ClaimSubmitted(claimId, policyId, msg.sender, amount);
    }

    function approveClaim(uint256 claimId) external onlyOperator {
        Claim storage claim = claims[claimId];
        if (claim.status != ClaimStatus.Pending) revert InvalidClaimStatus();

        Policy storage policy = policies[claim.policyId];
        if (policy.status != PolicyStatus.Active) revert PolicyNotActive();
        if (block.timestamp > policy.endTime) revert PolicyExpired();
        if (totalReserve < claim.amount) revert InsufficientReserve();

        // Effects before interactions
        claim.status = ClaimStatus.Approved;
        policy.status = PolicyStatus.Claimed;
        totalReserve -= claim.amount;

        // Interaction
        _safeTransfer(address(stablecoin), claim.claimant, claim.amount);

        emit ClaimApproved(claimId, claim.amount);
    }

    function rejectClaim(uint256 claimId) external onlyOperator {
        Claim storage claim = claims[claimId];
        if (claim.status != ClaimStatus.Pending) revert InvalidClaimStatus();
        claim.status = ClaimStatus.Rejected;
        emit ClaimRejected(claimId);
    }

    // ---------------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------------

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddressErr();
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddressErr();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setPremiumRate(uint256 _premiumRate) external onlyOwner {
        if (_premiumRate == 0 || _premiumRate > MAX_PREMIUM_RATE) revert InvalidAmount();
        premiumRate = _premiumRate;
        emit PremiumRateUpdated(_premiumRate);
    }

    // ---------------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------------

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function getClaim(uint256 claimId) external view returns (Claim memory) {
        return claims[claimId];
    }

    function isPolicyActive(uint256 policyId) external view returns (bool) {
        Policy storage policy = policies[policyId];
        return policy.status == PolicyStatus.Active && block.timestamp <= policy.endTime;
    }

    function availablePayoutCapacity() external view returns (uint256) {
        return totalReserve;
    }
}
