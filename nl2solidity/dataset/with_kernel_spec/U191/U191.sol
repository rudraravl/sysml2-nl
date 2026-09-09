// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DecentralizedInsurance {
    error ZeroAddress();
    error NotOperator();
    error ZeroAmount();
    error InvalidPremiumRate();
    error InvalidDuration();
    error ProductNotSupported();
    error ProductAlreadySupported();
    error ExceedsMaxCoverage();
    error InsufficientStake();
    error InsufficientPoolLiquidity();
    error PolicyNotFound();
    error NotPolicyHolder();
    error PolicyNotActive();
    error PolicyExpired();
    error PolicyNotExpired();
    error ClaimNotPending();
    error TransferFailed();

    event CollateralStaked(address indexed staker, uint256 amount);
    event CollateralWithdrawn(address indexed withdrawer, uint256 amount);
    event ProductAdded(uint256 indexed productId, uint256 premiumRateBps);
    event PremiumRateUpdated(uint256 indexed productId, uint256 oldRate, uint256 newRate);
    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed holder,
        uint256 indexed productId,
        uint256 coverageAmount,
        uint256 premiumPaid,
        uint64 expiration
    );
    event ClaimFiled(uint256 indexed policyId, address indexed holder);
    event ClaimApproved(uint256 indexed policyId, address indexed holder, uint256 payout, uint256 fee);
    event ClaimRejected(uint256 indexed policyId, address indexed holder);
    event PolicyReleased(uint256 indexed policyId);
    event OperatorChanged(address indexed oldOperator, address indexed newOperator);

    uint256 public constant MAX_COVERAGE = 10_000;
    uint256 public constant CLAIM_FEE_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint64 public constant MIN_DURATION = 1 days;
    uint64 public constant MAX_DURATION = 365 days * 10;

    IERC20 public immutable stablecoin;
    address public operator;
    uint256 public totalCollateral;
    uint256 public totalLiabilities;
    uint256 public nextPolicyId;

    enum PolicyStatus {
        Active,
        ClaimFiled,
        Approved,
        Rejected,
        Expired
    }

    struct Product {
        bool supported;
        uint256 premiumRateBps;
    }

    struct Policy {
        address holder;
        uint256 productId;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint64 expiration;
        PolicyStatus status;
    }

    mapping(uint256 => Product) public products;
    uint256[] internal supportedProductIds;
    mapping(uint256 => Policy) internal policies;
    mapping(address => uint256) public stakedBalance;

    uint256 private _locked;
    modifier nonReentrant() {
        require(_locked == 0, "Reentrant");
        _locked = 1;
        _;
        _locked = 0;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _stablecoin, address _operator) {
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        stablecoin = IERC20(_stablecoin);
        operator = _operator;
        nextPolicyId = 1;
        emit OperatorChanged(address(0), _operator);
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        stakedBalance[msg.sender] += amount;
        totalCollateral += amount;
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        emit CollateralStaked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > stakedBalance[msg.sender]) revert InsufficientStake();
        if (amount > totalCollateral - totalLiabilities) revert InsufficientPoolLiquidity();
        stakedBalance[msg.sender] -= amount;
        totalCollateral -= amount;
        bool ok = stablecoin.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function addProduct(uint256 productId, uint256 premiumRateBps) external onlyOperator {
        if (products[productId].supported) revert ProductAlreadySupported();
        if (premiumRateBps == 0 || premiumRateBps > BPS_DENOMINATOR) revert InvalidPremiumRate();
        products[productId] = Product({supported: true, premiumRateBps: premiumRateBps});
        supportedProductIds.push(productId);
        emit ProductAdded(productId, premiumRateBps);
    }

    function updatePremiumRate(uint256 productId, uint256 newPremiumRateBps) external onlyOperator {
        if (!products[productId].supported) revert ProductNotSupported();
        if (newPremiumRateBps == 0 || newPremiumRateBps > BPS_DENOMINATOR) revert InvalidPremiumRate();
        uint256 old = products[productId].premiumRateBps;
        products[productId].premiumRateBps = newPremiumRateBps;
        emit PremiumRateUpdated(productId, old, newPremiumRateBps);
    }

    function purchasePolicy(uint256 productId, uint256 coverageAmount, uint64 duration) external nonReentrant {
        Product memory product = products[productId];
        if (!product.supported) revert ProductNotSupported();
        if (coverageAmount == 0) revert ZeroAmount();
        if (coverageAmount > MAX_COVERAGE) revert ExceedsMaxCoverage();
        if (duration < MIN_DURATION || duration > MAX_DURATION) revert InvalidDuration();
        if (totalCollateral - totalLiabilities < coverageAmount) revert InsufficientPoolLiquidity();

        uint256 premium = (coverageAmount * product.premiumRateBps) / BPS_DENOMINATOR;
        if (premium == 0) revert ZeroAmount();

        uint64 expiration = uint64(block.timestamp) + duration;
        uint256 policyId = nextPolicyId++;
        policies[policyId] = Policy({
            holder: msg.sender,
            productId: productId,
            coverageAmount: coverageAmount,
            premiumPaid: premium,
            expiration: expiration,
            status: PolicyStatus.Active
        });

        totalLiabilities += coverageAmount;
        totalCollateral += premium;
        bool ok = stablecoin.transferFrom(msg.sender, address(this), premium);
        if (!ok) revert TransferFailed();

        emit PolicyPurchased(policyId, msg.sender, productId, coverageAmount, premium, expiration);
    }

    function fileClaim(uint256 policyId) external nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (policy.holder != msg.sender) revert NotPolicyHolder();
        if (policy.status != PolicyStatus.Active) revert PolicyNotActive();
        if (block.timestamp > policy.expiration) revert PolicyExpired();

        policy.status = PolicyStatus.ClaimFiled;
        emit ClaimFiled(policyId, msg.sender);
    }

    function approveClaim(uint256 policyId) external onlyOperator nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (policy.status != PolicyStatus.ClaimFiled) revert ClaimNotPending();

        uint256 coverage = policy.coverageAmount;
        uint256 fee = (coverage * CLAIM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = coverage - fee;

        policy.status = PolicyStatus.Approved;
        totalLiabilities -= coverage;
        totalCollateral -= payout;

        bool ok = stablecoin.transfer(policy.holder, payout);
        if (!ok) revert TransferFailed();

        emit ClaimApproved(policyId, policy.holder, payout, fee);
    }

    function rejectClaim(uint256 policyId) external onlyOperator nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (policy.status != PolicyStatus.ClaimFiled) revert ClaimNotPending();

        policy.status = PolicyStatus.Rejected;
        totalLiabilities -= policy.coverageAmount;
        emit ClaimRejected(policyId, policy.holder);
    }

    function releaseExpiredPolicy(uint256 policyId) external nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (policy.status != PolicyStatus.Active) revert PolicyNotActive();
        if (block.timestamp <= policy.expiration) revert PolicyNotExpired();

        policy.status = PolicyStatus.Expired;
        totalLiabilities -= policy.coverageAmount;
        emit PolicyReleased(policyId);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        address old = operator;
        operator = newOperator;
        emit OperatorChanged(old, newOperator);
    }

    function getSupportedProductIds() external view returns (uint256[] memory) {
        return supportedProductIds;
    }

    function supportedProductCount() external view returns (uint256) {
        return supportedProductIds.length;
    }

    function getProduct(uint256 productId) external view returns (bool supported, uint256 premiumRateBps) {
        Product memory p = products[productId];
        return (p.supported, p.premiumRateBps);
    }

    function getPolicy(uint256 policyId)
        external
        view
        returns (
            address holder,
            uint256 productId,
            uint256 coverageAmount,
            uint256 premiumPaid,
            uint64 expiration,
            PolicyStatus status
        )
    {
        Policy memory p = policies[policyId];
        return (p.holder, p.productId, p.coverageAmount, p.premiumPaid, p.expiration, p.status);
    }

    function availableToWithdraw(address staker) external view returns (uint256) {
        uint256 bal = stakedBalance[staker];
        uint256 free = totalCollateral - totalLiabilities;
        if (bal <= free) return bal;
        return free;
    }

    function poolAvailableLiquidity() external view returns (uint256) {
        return totalCollateral - totalLiabilities;
    }
}
