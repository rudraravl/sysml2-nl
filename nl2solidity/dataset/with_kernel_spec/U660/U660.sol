// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    error SafeERC20TransferFailed();
    error SafeERC20TransferFromFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert SafeERC20TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transferFrom(msg.sender, to, amount);
        if (!success) revert SafeERC20TransferFromFailed();
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract MutualCoverPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_COLLATERAL_RATIO = 1200; // 120% in basis points
    uint256 public constant FEE_RATE = 500;              // 5% in basis points
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS_DENOMINATOR = 10000;

    error ZeroAddress();
    error TokenNotApproved();
    error InvalidPrice();
    error InvalidAmount();
    error InvalidDuration();
    error InsufficientCollateral();
    error PolicyNotActive();
    error NotPolicyHolder();
    error ClaimAlreadyFiled();
    error ClaimAlreadyResolved();
    error NotOperator();
    error PolicyNotExpired();
    error PolicyHasPendingClaim();
    error ExceedsMaxCover();
    error PolicyNotFound();
    error ClaimNotFound();

    address public operator;
    address public treasury;

    uint256 public maxCoverPerPolicy = 1_000_000 * PRECISION; // 1,000,000 USD
    uint256 public minCoverDuration = 1 days;
    uint256 public maxCoverDuration = 90 days;

    struct Policy {
        address holder;
        bytes32 protocol;
        address collateralToken;
        uint256 coverAmount;      // in USD (1e18 decimals)
        uint256 collateralLocked; // in token units
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool hasPendingClaim;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 amount;   // in USD (1e18 decimals)
        uint256 filedAt;
        bool approved;
        bool resolved;
    }

    mapping(address => bool) public approvedTokens;
    mapping(address => uint256) public tokenPrice; // USD per whole token, 1e18 scale

    mapping(address => mapping(address => uint256)) public userCollateral; // user => token => available
    mapping(address => mapping(address => uint256)) public userLocked;     // user => token => locked
    mapping(address => uint256) public totalCollateral;                    // token => total held

    mapping(uint256 => Policy) public policies;
    uint256 public policyCount;

    mapping(uint256 => Claim) public claims;
    uint256 public claimCount;

    event OperatorChanged(address indexed operator);
    event TreasuryChanged(address indexed treasury);
    event TokenApproved(address indexed token, uint256 price);
    event TokenPriceUpdated(address indexed token, uint256 price);
    event CoverParamsUpdated(uint256 maxCoverPerPolicy, uint256 minCoverDuration, uint256 maxCoverDuration);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event CoverPurchased(
        uint256 indexed policyId,
        address indexed holder,
        bytes32 indexed protocol,
        address collateralToken,
        uint256 coverAmount,
        uint256 collateralLocked,
        uint256 fee,
        uint256 endTime
    );
    event ClaimFiled(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimResolved(uint256 indexed claimId, uint256 indexed policyId, bool approved, uint256 payout);
    event PolicyReleased(uint256 indexed policyId, address indexed holder, uint256 collateralReturned);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address treasury_) Ownable(msg.sender) {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        operator = msg.sender;
        emit TreasuryChanged(treasury_);
        emit OperatorChanged(operator);
    }

    function setOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        operator = op;
        emit OperatorChanged(op);
    }

    function setTreasury(address tr) external onlyOwner {
        if (tr == address(0)) revert ZeroAddress();
        treasury = tr;
        emit TreasuryChanged(tr);
    }

    function approveToken(address token, uint256 price) external onlyOperator {
        if (token == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        approvedTokens[token] = true;
        tokenPrice[token] = price;
        emit TokenApproved(token, price);
    }

    function setTokenPrice(address token, uint256 price) external onlyOperator {
        if (!approvedTokens[token]) revert TokenNotApproved();
        if (price == 0) revert InvalidPrice();
        tokenPrice[token] = price;
        emit TokenPriceUpdated(token, price);
    }

    function setCoverParams(uint256 maxCover, uint256 minDur, uint256 maxDur) external onlyOperator {
        if (minDur == 0 || maxDur < minDur) revert InvalidDuration();
        maxCoverPerPolicy = maxCover;
        minCoverDuration = minDur;
        maxCoverDuration = maxDur;
        emit CoverParamsUpdated(maxCover, minDur, maxDur);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!approvedTokens[token]) revert TokenNotApproved();
        if (amount == 0) revert InvalidAmount();
        IERC20(token).safeTransferFrom(address(this), amount);
        userCollateral[msg.sender][token] += amount;
        totalCollateral[token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function purchaseCover(
        bytes32 protocol,
        address token,
        uint256 coverAmount,
        uint256 duration
    ) external nonReentrant returns (uint256 policyId) {
        if (!approvedTokens[token]) revert TokenNotApproved();
        if (coverAmount == 0) revert InvalidAmount();
        if (coverAmount > maxCoverPerPolicy) revert ExceedsMaxCover();
        if (duration < minCoverDuration || duration > maxCoverDuration) revert InvalidDuration();

        uint256 price = tokenPrice[token];
        if (price == 0) revert InvalidPrice();

        // Collateral required: 120% of cover amount, converted to token units.
        // Multiply before divide to avoid precision loss.
        uint256 lockedAmount = (coverAmount * MIN_COLLATERAL_RATIO * PRECISION) / (BPS_DENOMINATOR * price);

        // Fee: 5% of cover amount, converted to token units, sent to treasury.
        // Multiply before divide to avoid precision loss.
        uint256 feeAmount = (coverAmount * FEE_RATE * PRECISION) / (BPS_DENOMINATOR * price);

        uint256 available = userCollateral[msg.sender][token];
        if (available < lockedAmount + feeAmount) revert InsufficientCollateral();

        // Effects before interactions.
        userCollateral[msg.sender][token] = available - lockedAmount - feeAmount;
        userLocked[msg.sender][token] += lockedAmount;
        totalCollateral[token] -= feeAmount;

        // Interactions.
        IERC20(token).safeTransfer(treasury, feeAmount);

        policyId = policyCount++;
        policies[policyId] = Policy({
            holder: msg.sender,
            protocol: protocol,
            collateralToken: token,
            coverAmount: coverAmount,
            collateralLocked: lockedAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            active: true,
            hasPendingClaim: false
        });

        emit CoverPurchased(
            policyId,
            msg.sender,
            protocol,
            token,
            coverAmount,
            lockedAmount,
            feeAmount,
            block.timestamp + duration
        );
    }

    function fileClaim(uint256 policyId, uint256 amount) external nonReentrant returns (uint256 claimId) {
        if (policyId >= policyCount) revert PolicyNotFound();
        Policy storage p = policies[policyId];
        if (!p.active) revert PolicyNotActive();
        if (p.holder != msg.sender) revert NotPolicyHolder();
        if (p.hasPendingClaim) revert ClaimAlreadyFiled();
        if (amount == 0 || amount > p.coverAmount) revert InvalidAmount();

        p.hasPendingClaim = true;

        claimId = claimCount++;
        claims[claimId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            amount: amount,
            filedAt: block.timestamp,
            approved: false,
            resolved: false
        });

        emit ClaimFiled(claimId, policyId, msg.sender, amount);
    }

    function resolveClaim(uint256 claimId, bool approve) external onlyOperator nonReentrant {
        if (claimId >= claimCount) revert ClaimNotFound();
        Claim storage c = claims[claimId];
        if (c.resolved) revert ClaimAlreadyResolved();

        Policy storage p = policies[c.policyId];
        if (!p.active) revert PolicyNotActive();

        address token = p.collateralToken;
        address holder = p.holder;
        uint256 locked = p.collateralLocked;

        // Effects.
        c.resolved = true;
        c.approved = approve;
        p.active = false;
        p.hasPendingClaim = false;
        userLocked[holder][token] -= locked;

        uint256 payout = 0;

        if (approve) {
            uint256 price = tokenPrice[token];
            if (price == 0) revert InvalidPrice();

            // Payout in token units, capped at locked collateral.
            uint256 payoutToken = (c.amount * PRECISION) / price;
            if (payoutToken > locked) {
                payoutToken = locked;
            }
            payout = payoutToken;

            // Remaining locked collateral returns to the policy holder.
            uint256 remainder = locked - payoutToken;
            if (remainder > 0) {
                userCollateral[holder][token] += remainder;
            }

            // Payout leaves the pool.
            totalCollateral[token] -= payoutToken;

            // Interaction.
            IERC20(token).safeTransfer(c.claimant, payoutToken);
        } else {
            // Denied: return all locked collateral to the holder.
            userCollateral[holder][token] += locked;
        }

        emit ClaimResolved(claimId, c.policyId, approve, payout);
    }

    function releaseExpiredPolicy(uint256 policyId) external nonReentrant {
        if (policyId >= policyCount) revert PolicyNotFound();
        Policy storage p = policies[policyId];
        if (!p.active) revert PolicyNotActive();
        if (p.hasPendingClaim) revert PolicyHasPendingClaim();
        if (block.timestamp < p.endTime) revert PolicyNotExpired();

        address token = p.collateralToken;
        address holder = p.holder;
        uint256 locked = p.collateralLocked;

        p.active = false;
        userLocked[holder][token] -= locked;
        userCollateral[holder][token] += locked;

        emit PolicyReleased(policyId, holder, locked);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (!approvedTokens[token]) revert TokenNotApproved();
        if (amount == 0) revert InvalidAmount();

        uint256 available = userCollateral[msg.sender][token];
        if (available < amount) revert InsufficientCollateral();

        userCollateral[msg.sender][token] = available - amount;
        totalCollateral[token] -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, token, amount);
    }

    function availableCollateral(address user, address token) external view returns (uint256) {
        return userCollateral[user][token];
    }

    function lockedCollateral(address user, address token) external view returns (uint256) {
        return userLocked[user][token];
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function getClaim(uint256 claimId) external view returns (Claim memory) {
        return claims[claimId];
    }
}
