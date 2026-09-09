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

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(0x20, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
        return returndata;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract DecentralizedInsurancePool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_COVERAGE_PERIOD = 365 days;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant MIN_PREMIUM_RATE_BPS = 10; // 0.1%
    uint256 public constant MAX_PREMIUM_RATE_BPS = 5_000; // 50%

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable collateralToken;
    IERC20 public immutable coverageToken;

    address public operator;

    uint256 public totalCollateral;
    uint256 public totalOutstandingCoverage;
    uint256 public premiumRateBps;

    uint256 public accumulatedRewardPerShare;
    uint256 public totalRewards;

    struct UserInfo {
        uint256 collateralBalance;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    mapping(address => UserInfo) public userInfo;

    struct Policy {
        address holder;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool claimSubmitted;
        bool claimApproved;
        bool claimRejected;
    }

    mapping(uint256 => Policy) public policies;
    uint256 public policyCount;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    event PolicyPurchased(
        uint256 indexed policyId,
        address indexed holder,
        uint256 coverageAmount,
        uint256 premiumPaid,
        uint256 endTime
    );
    event ClaimSubmitted(uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimResolved(uint256 indexed policyId, bool approved, uint256 payout);
    event Withdraw(address indexed user, uint256 collateralAmount, uint256 rewardAmount, uint256 feeAmount);
    event PremiumRateUpdated(uint256 oldRate, uint256 newRate);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event RewardsAdded(uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error NotOperator();
    error NotPolicyHolder();
    error CoveragePeriodExceeded();
    error PolicyNotActive();
    error PolicyExpired();
    error PolicyNotExpired();
    error ClaimAlreadySubmitted();
    error ClaimAlreadyResolved();
    error ClaimNotSubmitted();
    error InvalidPremiumRate();
    error InsufficientCollateral();
    error PolicyNotFound();
    error InsufficientPoolBalance();
    error NoPendingRewards();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _collateralToken,
        address _coverageToken,
        address _operator,
        uint256 _initialPremiumRateBps
    ) {
        if (_collateralToken == address(0) || _coverageToken == address(0) || _operator == address(0)) {
            revert ZeroAddress();
        }
        if (_initialPremiumRateBps < MIN_PREMIUM_RATE_BPS || _initialPremiumRateBps > MAX_PREMIUM_RATE_BPS) {
            revert InvalidPremiumRate();
        }
        collateralToken = IERC20(_collateralToken);
        coverageToken = IERC20(_coverageToken);
        operator = _operator;
        premiumRateBps = _initialPremiumRateBps;
        emit OperatorUpdated(address(0), _operator);
        emit PremiumRateUpdated(0, _initialPremiumRateBps);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setPremiumRate(uint256 _newRateBps) external onlyOperator {
        if (_newRateBps < MIN_PREMIUM_RATE_BPS || _newRateBps > MAX_PREMIUM_RATE_BPS) {
            revert InvalidPremiumRate();
        }
        emit PremiumRateUpdated(premiumRateBps, _newRateBps);
        premiumRateBps = _newRateBps;
    }

    /*//////////////////////////////////////////////////////////////
                          USER: DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updateUserRewards(msg.sender);

        // Effects
        UserInfo storage user = userInfo[msg.sender];
        user.collateralBalance += amount;
        totalCollateral += amount;
        user.rewardDebt = (user.collateralBalance * accumulatedRewardPerShare) / REWARD_PRECISION;

        // Interactions
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, user.collateralBalance);
    }

    /*//////////////////////////////////////////////////////////////
                       USER: PURCHASE COVERAGE
    //////////////////////////////////////////////////////////////*/

    function purchaseCoverage(uint256 coverageAmount, uint256 duration)
        external
        nonReentrant
        returns (uint256 policyId)
    {
        if (coverageAmount == 0) revert ZeroAmount();
        if (duration == 0 || duration > MAX_COVERAGE_PERIOD) revert CoveragePeriodExceeded();

        _updateUserRewards(msg.sender);

        uint256 premium = (coverageAmount * premiumRateBps * duration) / (MAX_COVERAGE_PERIOD * BPS_DENOMINATOR);
        if (premium == 0) revert ZeroAmount();

        UserInfo storage user = userInfo[msg.sender];
        if (user.collateralBalance < premium) revert InsufficientCollateral();

        // Effects
        user.collateralBalance -= premium;
        totalCollateral -= premium;
        user.rewardDebt = (user.collateralBalance * accumulatedRewardPerShare) / REWARD_PRECISION;

        _addRewards(premium);

        policyId = policyCount++;
        uint256 endTime = block.timestamp + duration;
        policies[policyId] = Policy({
            holder: msg.sender,
            coverageAmount: coverageAmount,
            premiumPaid: premium,
            startTime: block.timestamp,
            endTime: endTime,
            active: true,
            claimSubmitted: false,
            claimApproved: false,
            claimRejected: false
        });

        totalOutstandingCoverage += coverageAmount;

        // Interactions
        coverageToken.safeTransfer(msg.sender, coverageAmount);

        emit PolicyPurchased(policyId, msg.sender, coverageAmount, premium, endTime);
    }

    /*//////////////////////////////////////////////////////////////
                       USER: FILE CLAIM
    //////////////////////////////////////////////////////////////*/

    function fileClaim(uint256 policyId) external nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (policy.holder != msg.sender) revert NotPolicyHolder();
        if (!policy.active) revert PolicyNotActive();
        if (block.timestamp > policy.endTime) revert PolicyExpired();
        if (policy.claimSubmitted) revert ClaimAlreadySubmitted();

        // Effects
        policy.claimSubmitted = true;

        // Interactions — escrow coverage tokens from the claimant (msg.sender)
        // Using msg.sender as `from` instead of an arbitrary address fixes the
        // arbitrary-send-erc20 vulnerability previously present in resolveClaim.
        coverageToken.safeTransferFrom(msg.sender, address(this), policy.coverageAmount);

        emit ClaimSubmitted(policyId, msg.sender, policy.coverageAmount);
    }

    /*//////////////////////////////////////////////////////////////
                     OPERATOR: RESOLVE CLAIM
    //////////////////////////////////////////////////////////////*/

    function resolveClaim(uint256 policyId, bool approve) external onlyOperator nonReentrant {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (!policy.claimSubmitted) revert ClaimNotSubmitted();
        if (policy.claimApproved || policy.claimRejected) revert ClaimAlreadyResolved();

        uint256 payout = 0;

        if (approve) {
            // Effects
            policy.claimApproved = true;
            policy.active = false;
            payout = policy.coverageAmount;

            uint256 poolBalance = collateralToken.balanceOf(address(this));
            if (poolBalance < payout) revert InsufficientPoolBalance();
            if (totalCollateral < payout) revert InsufficientPoolBalance();

            totalOutstandingCoverage -= policy.coverageAmount;
            totalCollateral -= payout;

            // Interactions — pay out collateral to the holder.
            // Coverage tokens were already escrowed in fileClaim by the
            // claimant themselves, so no transferFrom with arbitrary `from`.
            collateralToken.safeTransfer(policy.holder, payout);
        } else {
            // Effects
            policy.claimRejected = true;
            policy.active = false;
            totalOutstandingCoverage -= policy.coverageAmount;

            // Interactions — return escrowed coverage tokens to the holder
            coverageToken.safeTransfer(policy.holder, policy.coverageAmount);
        }

        emit ClaimResolved(policyId, approve, payout);
    }

    /*//////////////////////////////////////////////////////////////
                       USER: EXPIRE POLICY
    //////////////////////////////////////////////////////////////*/

    function expirePolicy(uint256 policyId) external {
        Policy storage policy = policies[policyId];
        if (policy.holder == address(0)) revert PolicyNotFound();
        if (!policy.active) revert PolicyNotActive();
        if (block.timestamp <= policy.endTime) revert PolicyNotExpired();

        policy.active = false;
        totalOutstandingCoverage -= policy.coverageAmount;
    }

    /*//////////////////////////////////////////////////////////////
                       USER: WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function withdraw(uint256 collateralAmount) external nonReentrant {
        if (collateralAmount == 0) revert ZeroAmount();

        _updateUserRewards(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        if (user.collateralBalance < collateralAmount) revert InsufficientCollateral();

        uint256 rewardAmount = user.pendingRewards;
        uint256 fee = (collateralAmount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 collateralToUser = collateralAmount - fee;

        // Effects
        user.collateralBalance -= collateralAmount;
        totalCollateral -= collateralAmount;
        user.pendingRewards = 0;
        user.rewardDebt = (user.collateralBalance * accumulatedRewardPerShare) / REWARD_PRECISION;

        _addRewards(fee);

        // Interactions
        if (collateralToUser + rewardAmount > 0) {
            collateralToken.safeTransfer(msg.sender, collateralToUser + rewardAmount);
        }

        emit Withdraw(msg.sender, collateralToUser, rewardAmount, fee);
    }

    /*//////////////////////////////////////////////////////////////
                       USER: CLAIM REWARDS
    //////////////////////////////////////////////////////////////*/

    function claimRewards() external nonReentrant {
        _updateUserRewards(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        uint256 rewardAmount = user.pendingRewards;
        if (rewardAmount == 0) revert NoPendingRewards();

        // Effects
        user.pendingRewards = 0;

        // Interactions
        collateralToken.safeTransfer(msg.sender, rewardAmount);

        emit Withdraw(msg.sender, 0, rewardAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function pendingRewards(address userAddr) external view returns (uint256) {
        UserInfo storage user = userInfo[userAddr];
        uint256 accPerShare = accumulatedRewardPerShare;
        uint256 accumulated = (user.collateralBalance * accPerShare) / REWARD_PRECISION;
        if (accumulated > user.rewardDebt) {
            return user.pendingRewards + (accumulated - user.rewardDebt);
        }
        return user.pendingRewards;
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    function isPolicyActive(uint256 policyId) external view returns (bool) {
        Policy storage policy = policies[policyId];
        return policy.active && block.timestamp <= policy.endTime;
    }

    function getUserInfo(address userAddr) external view returns (uint256, uint256, uint256) {
        UserInfo storage user = userInfo[userAddr];
        return (user.collateralBalance, user.rewardDebt, user.pendingRewards);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _addRewards(uint256 amount) internal {
        if (amount == 0) return;
        totalRewards += amount;
        if (totalCollateral > 0) {
            accumulatedRewardPerShare += (amount * REWARD_PRECISION) / totalCollateral;
        }
        emit RewardsAdded(amount);
    }

    function _updateUserRewards(address userAddr) internal {
        UserInfo storage user = userInfo[userAddr];
        uint256 accumulated = (user.collateralBalance * accumulatedRewardPerShare) / REWARD_PRECISION;
        if (accumulated > user.rewardDebt) {
            user.pendingRewards += accumulated - user.rewardDebt;
        }
        user.rewardDebt = accumulated;
    }
}
