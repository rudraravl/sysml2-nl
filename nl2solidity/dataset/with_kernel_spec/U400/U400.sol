// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedTransferFrom();

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool success = token.transfer(to, value);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }

    function safeTransferFrom(IERC20 token, address to, uint256 value) internal {
        bool success = token.transferFrom(msg.sender, to, value);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }
}

abstract contract Ownable {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableUnauthorizedAccount(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableUnauthorizedAccount(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
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

contract CoveragePool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ErrZeroAddress();
    error ErrAmountZero();
    error ErrInsufficientBalance();
    error ErrInsufficientCoverage();
    error ErrClaimExceedsLimit();
    error ErrNotAuthorized();
    error ErrInvalidClaimStatus();
    error ErrClaimNotFound();
    error ErrFeeTooHigh();
    error ErrCoverageLimitZero();
    error ErrLimitInsufficient();

    event Deposit(address indexed user, uint256 amount, uint256 totalPool);
    event Withdraw(address indexed user, uint256 amount, uint256 totalPool);
    event ClaimFiled(uint256 indexed claimId, address indexed claimant, uint256 amount, bytes32 evidenceHash);
    event ClaimApproved(uint256 indexed claimId, address indexed resolver, uint256 payout, uint256 fee);
    event ClaimRejected(uint256 indexed claimId, address indexed resolver);
    event ClaimPaid(uint256 indexed claimId, address indexed claimant, uint256 payout);
    event CoverageLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event ClaimFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event Rescue(address indexed token, address indexed to, uint256 amount);

    uint256 public constant MAX_COVERAGE_PER_INCIDENT = 1000 * 10 ** 18;
    uint16 public constant MAX_FEE_BPS = 1_000;
    uint16 public constant DEFAULT_CLAIM_FEE_BPS = 50;
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable coverageToken;
    address public operator;

    uint256 public coverageLimit;
    uint16 public claimFeeBps;
    uint256 public totalCoveragePool;
    uint256 public reservedCoverage;
    uint256 public totalClaimsFiled;
    uint256 public totalClaimsPaid;
    uint256 public totalPayouts;

    enum ClaimStatus {
        Pending,
        Approved,
        Rejected,
        Paid
    }

    struct Claim {
        address claimant;
        uint256 amount;
        uint256 payoutAmount;
        uint256 fee;
        ClaimStatus status;
        uint64 filedAt;
        uint64 resolvedAt;
    }

    mapping(address => uint256) public deposits;
    mapping(uint256 => Claim) public claims;

    modifier onlyOperatorOrOwner() {
        if (msg.sender != operator && msg.sender != owner()) {
            revert ErrNotAuthorized();
        }
        _;
    }

    constructor(address token_, address operator_, uint256 coverageLimit_) Ownable(msg.sender) {
        if (token_ == address(0)) revert ErrZeroAddress();
        if (operator_ == address(0)) revert ErrZeroAddress();
        if (coverageLimit_ == 0) revert ErrCoverageLimitZero();

        coverageToken = IERC20(token_);
        operator = operator_;
        coverageLimit = coverageLimit_;
        claimFeeBps = DEFAULT_CLAIM_FEE_BPS;

        emit OperatorUpdated(address(0), operator_);
        emit CoverageLimitUpdated(0, coverageLimit_);
        emit ClaimFeeUpdated(0, claimFeeBps);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrAmountZero();

        coverageToken.safeTransferFrom(address(this), amount);

        deposits[msg.sender] += amount;
        totalCoveragePool += amount;

        emit Deposit(msg.sender, amount, totalCoveragePool);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ErrAmountZero();

        uint256 bal = deposits[msg.sender];
        if (amount > bal) revert ErrInsufficientBalance();
        if (amount > totalCoveragePool) revert ErrInsufficientBalance();
        if (totalCoveragePool - amount < reservedCoverage) revert ErrInsufficientCoverage();

        deposits[msg.sender] -= amount;
        totalCoveragePool -= amount;

        coverageToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, totalCoveragePool);
    }

    function fileClaim(uint256 amount, bytes32 evidenceHash) external nonReentrant returns (uint256 claimId) {
        if (amount == 0) revert ErrAmountZero();
        if (amount > MAX_COVERAGE_PER_INCIDENT) revert ErrClaimExceedsLimit();
        if (amount > coverageLimit) revert ErrInsufficientCoverage();
        if (totalCoveragePool < reservedCoverage) revert ErrInsufficientCoverage();
        if (totalCoveragePool - reservedCoverage < amount) revert ErrInsufficientCoverage();

        claimId = ++totalClaimsFiled;

        claims[claimId] = Claim({
            claimant: msg.sender,
            amount: amount,
            payoutAmount: 0,
            fee: 0,
            status: ClaimStatus.Pending,
            filedAt: uint64(block.timestamp),
            resolvedAt: 0
        });

        emit ClaimFiled(claimId, msg.sender, amount, evidenceHash);
    }

    function approveClaim(uint256 claimId) external onlyOperatorOrOwner nonReentrant {
        Claim storage c = claims[claimId];
        if (c.claimant == address(0) && c.filedAt == 0) revert ErrClaimNotFound();
        if (c.status != ClaimStatus.Pending) revert ErrInvalidClaimStatus();

        if (c.amount > MAX_COVERAGE_PER_INCIDENT) revert ErrClaimExceedsLimit();
        if (c.amount > coverageLimit) revert ErrInsufficientCoverage();
        if (totalCoveragePool < reservedCoverage) revert ErrInsufficientCoverage();
        if (totalCoveragePool - reservedCoverage < c.amount) revert ErrInsufficientCoverage();

        uint256 fee = (c.amount * uint256(claimFeeBps)) / BPS_DENOMINATOR;
        uint256 payout = c.amount - fee;

        c.fee = fee;
        c.payoutAmount = payout;
        c.status = ClaimStatus.Approved;
        c.resolvedAt = uint64(block.timestamp);

        reservedCoverage += c.amount;

        emit ClaimApproved(claimId, msg.sender, payout, fee);
    }

    function rejectClaim(uint256 claimId) external onlyOperatorOrOwner {
        Claim storage c = claims[claimId];
        if (c.claimant == address(0) && c.filedAt == 0) revert ErrClaimNotFound();
        if (c.status != ClaimStatus.Pending) revert ErrInvalidClaimStatus();

        c.status = ClaimStatus.Rejected;
        c.resolvedAt = uint64(block.timestamp);

        emit ClaimRejected(claimId, msg.sender);
    }

    function payClaim(uint256 claimId) external nonReentrant {
        Claim storage c = claims[claimId];
        if (c.claimant == address(0) && c.filedAt == 0) revert ErrClaimNotFound();
        if (c.status != ClaimStatus.Approved) revert ErrInvalidClaimStatus();

        if (msg.sender != c.claimant && msg.sender != owner() && msg.sender != operator) {
            revert ErrNotAuthorized();
        }

        c.status = ClaimStatus.Paid;

        reservedCoverage -= c.amount;
        totalCoveragePool -= c.amount;
        totalPayouts += c.payoutAmount;
        totalClaimsPaid += 1;

        coverageToken.safeTransfer(c.claimant, c.payoutAmount);
        if (c.fee > 0) {
            coverageToken.safeTransfer(owner(), c.fee);
        }

        emit ClaimPaid(claimId, c.claimant, c.payoutAmount);
    }

    function setCoverageLimit(uint256 newLimit) external onlyOwner {
        if (newLimit == 0) revert ErrCoverageLimitZero();
        if (newLimit < reservedCoverage) revert ErrLimitInsufficient();

        emit CoverageLimitUpdated(coverageLimit, newLimit);
        coverageLimit = newLimit;
    }

    function setClaimFeeBps(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert ErrFeeTooHigh();
        emit ClaimFeeUpdated(claimFeeBps, newFeeBps);
        claimFeeBps = newFeeBps;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ErrZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function rescue(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ErrZeroAddress();
        if (to == address(0)) revert ErrZeroAddress();
        if (amount == 0) revert ErrAmountZero();

        if (token == address(coverageToken)) {
            uint256 contractBal = coverageToken.balanceOf(address(this));
            if (contractBal < totalCoveragePool) revert ErrInsufficientBalance();
            if (amount > contractBal - totalCoveragePool) revert ErrInsufficientBalance();
        }

        IERC20(token).safeTransfer(to, amount);
        emit Rescue(token, to, amount);
    }

    function getClaim(uint256 claimId) external view returns (Claim memory) {
        Claim storage c = claims[claimId];
        if (c.claimant == address(0) && c.filedAt == 0) revert ErrClaimNotFound();
        return c;
    }

    function availableCoverage() external view returns (uint256) {
        if (totalCoveragePool < reservedCoverage) return 0;
        return totalCoveragePool - reservedCoverage;
    }

    function usableCoverage() external view returns (uint256) {
        uint256 remaining = (totalCoveragePool < reservedCoverage) ? 0 : totalCoveragePool - reservedCoverage;
        uint256 bounded = (remaining < coverageLimit) ? remaining : coverageLimit;
        return (bounded < MAX_COVERAGE_PER_INCIDENT) ? bounded : MAX_COVERAGE_PER_INCIDENT;
    }
}
