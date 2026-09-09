// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(value == 0 || token.allowance(address(this), spender) == 0, "SafeERC20: approve from non-zero to non-zero allowance");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

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
        if (owner() != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
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

    uint256 public constant MIN_DEPOSIT = 100 * 1e18;
    uint256 public constant CLAIM_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable stablecoin;
    address public operator;
    uint256 public premiumRateBps;
    uint256 public totalDeposits;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public supportedTargets;

    struct Policy {
        address holder;
        address target;
        uint256 coverageAmount;
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
        uint256 amount;
        ClaimStatus status;
        uint256 filedAt;
    }

    mapping(uint256 => Policy) public policies;
    uint256 public nextPolicyId;
    mapping(uint256 => Claim) public claims;
    uint256 public nextClaimId;

    event DepositMade(address indexed user, uint256 amount);
    event WithdrawalMade(address indexed user, uint256 amount);
    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed holder,
        address indexed target,
        uint256 coverageAmount,
        uint256 premiumPaid
    );
    event ClaimFiled(
        uint256 indexed claimId,
        uint256 indexed policyId,
        address indexed claimant,
        uint256 amount
    );
    event ClaimApproved(uint256 indexed claimId, uint256 payoutAmount, uint256 feeAmount);
    event ClaimRejected(uint256 indexed claimId);
    event PremiumRateUpdated(uint256 oldRate, uint256 newRate);
    event TargetAdded(address indexed target);
    event TargetRemoved(address indexed target);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error Unauthorized();
    error InvalidAmount();
    error InvalidPremiumRate();
    error InsufficientDeposit();
    error TargetNotSupported();
    error TargetAlreadySupported();
    error PolicyNotActive();
    error NotPolicyHolder();
    error ClaimExceedsCoverage();
    error InvalidClaimStatus();
    error PoolBalanceInsufficient();
    error NoAccumulatedFees();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    constructor(
        address _stablecoin,
        address _operator,
        uint256 _premiumRateBps
    ) Ownable(msg.sender) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_premiumRateBps == 0 || _premiumRateBps > BPS_DENOMINATOR) revert InvalidPremiumRate();

        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        premiumRateBps = _premiumRateBps;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setPremiumRate(uint256 _premiumRateBps) external onlyOwner {
        if (_premiumRateBps == 0 || _premiumRateBps > BPS_DENOMINATOR) revert InvalidPremiumRate();
        emit PremiumRateUpdated(premiumRateBps, _premiumRateBps);
        premiumRateBps = _premiumRateBps;
    }

    function addTarget(address _target) external onlyOwner {
        if (_target == address(0)) revert ZeroAddress();
        if (supportedTargets[_target]) revert TargetAlreadySupported();
        supportedTargets[_target] = true;
        emit TargetAdded(_target);
    }

    function removeTarget(address _target) external onlyOwner {
        if (!supportedTargets[_target]) revert TargetNotSupported();
        supportedTargets[_target] = false;
        emit TargetRemoved(_target);
    }

    function withdrawAccumulatedFees() external onlyOwner nonReentrant {
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (contractBalance <= totalDeposits) revert NoAccumulatedFees();
        uint256 withdrawable = contractBalance - totalDeposits;
        stablecoin.safeTransfer(msg.sender, withdrawable);
        emit FeesWithdrawn(msg.sender, withdrawable);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        deposits[msg.sender] += amount;
        totalDeposits += amount;
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        emit DepositMade(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (amount > deposits[msg.sender]) revert InsufficientDeposit();
        if (amount > stablecoin.balanceOf(address(this))) revert PoolBalanceInsufficient();
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        stablecoin.safeTransfer(msg.sender, amount);
        emit WithdrawalMade(msg.sender, amount);
    }

    function purchasePolicy(address target, uint256 coverageAmount) external nonReentrant {
        if (coverageAmount == 0) revert InvalidAmount();
        if (!supportedTargets[target]) revert TargetNotSupported();
        if (deposits[msg.sender] < MIN_DEPOSIT) revert InsufficientDeposit();

        uint256 premium = (coverageAmount * premiumRateBps) / BPS_DENOMINATOR;
        if (premium > deposits[msg.sender]) revert InsufficientDeposit();

        deposits[msg.sender] -= premium;
        totalDeposits -= premium;

        uint256 policyId = nextPolicyId++;
        policies[policyId] = Policy({
            holder: msg.sender,
            target: target,
            coverageAmount: coverageAmount,
            premiumPaid: premium,
            active: true
        });

        emit PolicyPurchased(policyId, msg.sender, target, coverageAmount, premium);
    }

    function fileClaim(uint256 policyId, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        Policy storage policy = policies[policyId];
        if (!policy.active) revert PolicyNotActive();
        if (policy.holder != msg.sender) revert NotPolicyHolder();
        if (amount > policy.coverageAmount) revert ClaimExceedsCoverage();

        uint256 claimId = nextClaimId++;
        claims[claimId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            amount: amount,
            status: ClaimStatus.Filed,
            filedAt: block.timestamp
        });

        emit ClaimFiled(claimId, policyId, msg.sender, amount);
    }

    function approveClaim(uint256 claimId) external onlyOperator nonReentrant {
        Claim storage claim = claims[claimId];
        if (claim.status != ClaimStatus.Filed) revert InvalidClaimStatus();

        Policy storage policy = policies[claim.policyId];
        if (!policy.active) revert PolicyNotActive();
        if (claim.amount > policy.coverageAmount) revert ClaimExceedsCoverage();

        uint256 fee = (claim.amount * CLAIM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = claim.amount - fee;

        if (payout > stablecoin.balanceOf(address(this))) revert PoolBalanceInsufficient();

        claim.status = ClaimStatus.Approved;
        policy.coverageAmount -= claim.amount;
        if (policy.coverageAmount == 0) {
            policy.active = false;
        }

        stablecoin.safeTransfer(claim.claimant, payout);

        emit ClaimApproved(claimId, payout, fee);
    }

    function rejectClaim(uint256 claimId) external onlyOperator {
        Claim storage claim = claims[claimId];
        if (claim.status != ClaimStatus.Filed) revert InvalidClaimStatus();
        claim.status = ClaimStatus.Rejected;
        emit ClaimRejected(claimId);
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function getClaim(uint256 claimId) external view returns (Claim memory) {
        return claims[claimId];
    }

    function isPolicyActive(uint256 policyId) external view returns (bool) {
        return policies[policyId].active;
    }

    function calculatePremium(uint256 coverageAmount) external view returns (uint256) {
        return (coverageAmount * premiumRateBps) / BPS_DENOMINATOR;
    }

    function calculatePayout(uint256 claimAmount) external pure returns (uint256 payout, uint256 fee) {
        fee = (claimAmount * CLAIM_FEE_BPS) / BPS_DENOMINATOR;
        payout = claimAmount - fee;
    }

    function accumulatedFees() external view returns (uint256) {
        uint256 contractBalance = stablecoin.balanceOf(address(this));
        if (contractBalance <= totalDeposits) return 0;
        return contractBalance - totalDeposits;
    }
}
