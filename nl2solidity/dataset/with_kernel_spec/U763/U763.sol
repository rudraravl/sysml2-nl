// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @title StakedEtherLiquidityMarketplace
 * @notice A decentralized marketplace that accepts Ether deposits, tracks notional
 *         allocation across approved liquid staking derivative (LSD) tokens, and
 *         distributes LSD-token rewards to depositors. Users may swap accumulated
 *         reward credits between approved LSDs, incurring a platform fee.
 */
contract StakedEtherLiquidityMarketplace {
    /* ------------------------------------------------------------------ */
    /* Constants                                                          */
    /* ------------------------------------------------------------------ */

    uint256 public constant MIN_DEPOSIT = 1 ether;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10 %

    /* ------------------------------------------------------------------ */
    /* Access control                                                     */
    /* ------------------------------------------------------------------ */

    address public owner;
    address public operator;
    uint256 public platformFeeBps; // 50 = 0.5 %

    /* ------------------------------------------------------------------ */
    /* Deposit state                                                      */
    /* ------------------------------------------------------------------ */

    uint256 public totalDepositedEther;
    mapping(address => uint256) public userDepositedEther;

    /* ------------------------------------------------------------------ */
    /* LSD registry & allocation                                          */
    /* ------------------------------------------------------------------ */

    address[] public approvedLSDs;
    mapping(address => bool) public isApprovedLSD;
    mapping(address => uint256) public lsdAllocationWeight;
    uint256 public totalAllocationWeight;
    mapping(address => uint256) public etherAllocatedToLSD;

    /* ------------------------------------------------------------------ */
    /* Reward accounting (per-LSD reward-per-share)                       */
    /* ------------------------------------------------------------------ */

    mapping(address => uint256) public accRewardPerShare; // lsd => index
    mapping(address => mapping(address => uint256)) public userRewardDebt; // user => lsd => debt
    mapping(address => mapping(address => uint256)) public userRewardCredit; // user => lsd => credit
    mapping(address => uint256) public totalRewardCredit; // lsd => sum of all user credits
    mapping(address => uint256) public platformFees; // lsd => accumulated fees

    /* ------------------------------------------------------------------ */
    /* Reentrancy                                                         */
    /* ------------------------------------------------------------------ */

    uint256 private _status = 1; // 1 = idle, 2 = locked

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsHarvested(address indexed user, address indexed lsd, uint256 amount);
    event RewardsClaimed(address indexed user, address indexed lsd, uint256 amount);
    event RewardsSwapped(
        address indexed user,
        address indexed fromLSD,
        address indexed toLSD,
        uint256 amountIn,
        uint256 amountOut
    );
    event RewardsReported(address indexed lsd, uint256 amount);
    event LSDAdded(address indexed lsd, uint256 weight);
    event AllocationWeightUpdated(address indexed lsd, uint256 oldWeight, uint256 newWeight);
    event EtherAllocationUpdated(address indexed lsd, uint256 oldAllocation, uint256 newAllocation);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event FeesWithdrawn(address indexed lsd, uint256 amount);
    event TokenRecovered(address indexed token, uint256 amount);

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */

    error OnlyOwner();
    error OnlyOperator();
    error ZeroAddress();
    error DepositTooSmall();
    error InsufficientBalance();
    error LSDNotApproved();
    error LSDAlreadyApproved();
    error SameLSD();
    error InsufficientCredit();
    error InsufficientLiquidity();
    error ZeroAmount();
    error NoDeposits();
    error ArrayLengthMismatch();
    error TransferFailed();
    error ReentrancyDetected();
    error FeeTooHigh();

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrancyDetected();
        _status = 2;
        _;
        _status = 1;
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */

    constructor(address _operator, uint256 _platformFeeBps) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_platformFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        owner = msg.sender;
        operator = _operator;
        platformFeeBps = _platformFeeBps;

        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit PlatformFeeUpdated(0, _platformFeeBps);
    }

    /* ------------------------------------------------------------------ */
    /* User: deposit                                                      */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Deposit Ether into the marketplace. A minimum of 1 Ether is
     *         required per deposit. Deposited Ether is notionally allocated
     *         across approved LSDs according to their allocation weights.
     */
    function deposit() external payable nonReentrant {
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall();

        _harvestUserRewards(msg.sender);

        userDepositedEther[msg.sender] += msg.value;
        totalDepositedEther += msg.value;

        _updateUserDebt(msg.sender);
        _allocateDeposit(msg.value);

        emit Deposited(msg.sender, msg.value);
    }

    /* ------------------------------------------------------------------ */
    /* User: withdraw                                                     */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Withdraw previously deposited Ether. Pending rewards across all
     *         LSDs are harvested into credit before the balance is reduced.
     *         Reward credits remain claimable separately.
     * @param amount The amount of Ether (in wei) to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (userDepositedEther[msg.sender] < amount) revert InsufficientBalance();
        if (address(this).balance < amount) revert InsufficientLiquidity();

        _harvestUserRewards(msg.sender);

        uint256 oldTotal = totalDepositedEther;
        userDepositedEther[msg.sender] -= amount;
        totalDepositedEther -= amount;

        _updateUserDebt(msg.sender);
        _deallocateWithdraw(amount, oldTotal);

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /* ------------------------------------------------------------------ */
    /* User: claim rewards                                                */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Claim all accumulated reward credit for a single LSD token.
     *         The actual LSD tokens are transferred to the caller.
     * @param lsd The LSD token to claim rewards for.
     */
    function claimRewards(address lsd) external nonReentrant {
        if (!isApprovedLSD[lsd]) revert LSDNotApproved();

        _harvestUserRewards(msg.sender);

        uint256 credit = userRewardCredit[msg.sender][lsd];
        if (credit == 0) revert InsufficientCredit();

        userRewardCredit[msg.sender][lsd] = 0;
        totalRewardCredit[lsd] -= credit;

        if (!IERC20(lsd).transfer(msg.sender, credit)) revert TransferFailed();

        emit RewardsClaimed(msg.sender, lsd, credit);
    }

    /* ------------------------------------------------------------------ */
    /* User: swap rewards                                                 */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Swap accumulated reward credit from one LSD to another at a 1:1
     *         rate, minus the platform fee. The contract must hold sufficient
     *         `toLSD` tokens to back the resulting credit.
     * @param fromLSD The LSD token whose credit is spent.
     * @param toLSD   The LSD token whose credit is received.
     * @param amount  The amount of `fromLSD` credit to swap.
     */
    function swapRewards(address fromLSD, address toLSD, uint256 amount) external nonReentrant {
        if (!isApprovedLSD[fromLSD] || !isApprovedLSD[toLSD]) revert LSDNotApproved();
        if (fromLSD == toLSD) revert SameLSD();
        if (amount == 0) revert ZeroAmount();

        _harvestUserRewards(msg.sender);

        if (userRewardCredit[msg.sender][fromLSD] < amount) revert InsufficientCredit();

        uint256 fee = (amount * platformFeeBps) / FEE_DENOMINATOR;
        uint256 received = amount - fee;

        // Deduct from sender's fromLSD credit
        userRewardCredit[msg.sender][fromLSD] -= amount;
        totalRewardCredit[fromLSD] -= amount;

        // Add to sender's toLSD credit
        userRewardCredit[msg.sender][toLSD] += received;
        totalRewardCredit[toLSD] += received;

        // Fee accrues to the platform in fromLSD tokens
        platformFees[fromLSD] += fee;

        // Ensure the contract holds enough toLSD tokens to honour all credits
        if (IERC20(toLSD).balanceOf(address(this)) < totalRewardCredit[toLSD]) {
            revert InsufficientLiquidity();
        }

        emit RewardsSwapped(msg.sender, fromLSD, toLSD, amount, received);
    }

    /* ------------------------------------------------------------------ */
    /* Operator: reward reporting                                         */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Report rewards for an LSD. The LSD tokens must already reside
     *         in this contract (e.g. transferred by a reward distributor)
     *         before calling this function. Rewards are distributed
     *         proportionally to all depositors via the reward-per-share index.
     * @param lsd    The LSD token being rewarded.
     * @param amount The amount of LSD tokens distributed.
     */
    function reportRewards(address lsd, uint256 amount) external onlyOperator {
        if (!isApprovedLSD[lsd]) revert LSDNotApproved();
        if (amount == 0) revert ZeroAmount();
        if (totalDepositedEther == 0) revert NoDeposits();

        // The contract must hold enough tokens to back existing credits plus
        // the newly reported rewards.
        if (IERC20(lsd).balanceOf(address(this)) < totalRewardCredit[lsd] + amount) {
            revert InsufficientLiquidity();
        }

        accRewardPerShare[lsd] += (amount * ACC_PRECISION) / totalDepositedEther;

        emit RewardsReported(lsd, amount);
    }

    /* ------------------------------------------------------------------ */
    /* Operator: LSD registry & allocation                               */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Add a new LSD token to the approved registry with an initial
     *         allocation weight.
     */
    function addLSD(address lsd, uint256 weight) external onlyOperator {
        if (lsd == address(0)) revert ZeroAddress();
        if (isApprovedLSD[lsd]) revert LSDAlreadyApproved();

        isApprovedLSD[lsd] = true;
        approvedLSDs.push(lsd);
        lsdAllocationWeight[lsd] = weight;
        totalAllocationWeight += weight;

        emit LSDAdded(lsd, weight);
        emit AllocationWeightUpdated(lsd, 0, weight);
    }

    /**
     * @notice Update the allocation weight of a single approved LSD.
     */
    function updateAllocation(address lsd, uint256 newWeight) external onlyOperator {
        if (!isApprovedLSD[lsd]) revert LSDNotApproved();

        uint256 oldWeight = lsdAllocationWeight[lsd];
        lsdAllocationWeight[lsd] = newWeight;
        totalAllocationWeight = totalAllocationWeight - oldWeight + newWeight;

        emit AllocationWeightUpdated(lsd, oldWeight, newWeight);
    }

    /**
     * @notice Batch-update allocation weights for multiple approved LSDs.
     */
    function updateAllocations(
        address[] calldata lsds,
        uint256[] calldata weights
    ) external onlyOperator {
        if (lsds.length != weights.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < lsds.length; i++) {
            address lsd = lsds[i];
            if (!isApprovedLSD[lsd]) revert LSDNotApproved();

            uint256 oldWeight = lsdAllocationWeight[lsd];
            lsdAllocationWeight[lsd] = weights[i];
            totalAllocationWeight = totalAllocationWeight - oldWeight + weights[i];

            emit AllocationWeightUpdated(lsd, oldWeight, weights[i]);
        }
    }

    /**
     * @notice Set the platform fee (in basis points) charged on reward swaps.
     */
    function setPlatformFee(uint256 newFeeBps) external onlyOperator {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        uint256 oldFee = platformFeeBps;
        platformFeeBps = newFeeBps;

        emit PlatformFeeUpdated(oldFee, newFeeBps);
    }

    /* ------------------------------------------------------------------ */
    /* Owner: fee withdrawal & token recovery                             */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Withdraw accumulated platform fees for a given LSD.
     */
    function withdrawFees(address lsd) external onlyOwner {
        if (!isApprovedLSD[lsd]) revert LSDNotApproved();

        uint256 amount = platformFees[lsd];
        if (amount == 0) revert ZeroAmount();

        platformFees[lsd] = 0;

        if (!IERC20(lsd).transfer(msg.sender, amount)) revert TransferFailed();

        emit FeesWithdrawn(lsd, amount);
    }

    /**
     * @notice Recover excess ERC20 tokens that are not owed to users as
     *         reward credits or platform fees. This is intended for tokens
     *         accidentally sent to the contract or freed up by reward swaps.
     */
    function recoverToken(address token, uint256 amount) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 reserved = totalRewardCredit[token] + platformFees[token];

        if (amount == 0) revert ZeroAmount();
        if (balance < reserved + amount) revert InsufficientBalance();

        if (!IERC20(token).transfer(msg.sender, amount)) revert TransferFailed();

        emit TokenRecovered(token, amount);
    }

    /* ------------------------------------------------------------------ */
    /* Owner: admin                                                       */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Set a new operator.
     */
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();

        address old = operator;
        operator = newOperator;

        emit OperatorUpdated(old, newOperator);
    }

    /**
     * @notice Transfer contract ownership.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        address old = owner;
        owner = newOwner;

        emit OwnershipTransferred(old, newOwner);
    }

    /* ------------------------------------------------------------------ */
    /* Internal: allocation                                               */
    /* ------------------------------------------------------------------ */

    function _allocateDeposit(uint256 amount) internal {
        if (totalAllocationWeight == 0) return;

        for (uint256 i = 0; i < approvedLSDs.length; i++) {
            address lsd = approvedLSDs[i];
            uint256 weight = lsdAllocationWeight[lsd];
            if (weight == 0) continue;

            uint256 alloc = (amount * weight) / totalAllocationWeight;
            if (alloc == 0) continue;

            uint256 oldAlloc = etherAllocatedToLSD[lsd];
            etherAllocatedToLSD[lsd] = oldAlloc + alloc;

            emit EtherAllocationUpdated(lsd, oldAlloc, oldAlloc + alloc);
        }
    }

    function _deallocateWithdraw(uint256 amount, uint256 oldTotal) internal {
        for (uint256 i = 0; i < approvedLSDs.length; i++) {
            address lsd = approvedLSDs[i];
            uint256 currentAlloc = etherAllocatedToLSD[lsd];
            if (currentAlloc == 0) continue;

            uint256 dealloc = (amount * currentAlloc) / oldTotal;
            if (dealloc == 0) continue;

            uint256 newAlloc = currentAlloc - dealloc;
            etherAllocatedToLSD[lsd] = newAlloc;

            emit EtherAllocationUpdated(lsd, currentAlloc, newAlloc);
        }
    }

    /* ------------------------------------------------------------------ */
    /* Internal: reward accounting                                         */
    /* ------------------------------------------------------------------ */

    /**
     * @dev Harvest all pending rewards for a user across every approved LSD
     *      into their claimable credit, then synchronise their reward debt.
     *      Must be called *before* the user's deposited balance changes.
     */
    function _harvestUserRewards(address user) internal {
        for (uint256 i = 0; i < approvedLSDs.length; i++) {
            address lsd = approvedLSDs[i];
            uint256 pending = _pendingRewards(user, lsd);

            if (pending > 0) {
                userRewardCredit[user][lsd] += pending;
                totalRewardCredit[lsd] += pending;
                emit RewardsHarvested(user, lsd, pending);
            }

            userRewardDebt[user][lsd] =
                (userDepositedEther[user] * accRewardPerShare[lsd]) /
                ACC_PRECISION;
        }
    }

    /**
     * @dev Re-sync the user's reward debt after their deposited balance has
     *      changed. Pending rewards are not harvested here.
     */
    function _updateUserDebt(address user) internal {
        for (uint256 i = 0; i < approvedLSDs.length; i++) {
            address lsd = approvedLSDs[i];
            userRewardDebt[user][lsd] =
                (userDepositedEther[user] * accRewardPerShare[lsd]) /
                ACC_PRECISION;
        }
    }

    function _pendingRewards(address user, address lsd) internal view returns (uint256) {
        return
            (userDepositedEther[user] * accRewardPerShare[lsd]) /
            ACC_PRECISION -
            userRewardDebt[user][lsd];
    }

    /* ------------------------------------------------------------------ */
    /* View functions                                                     */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Returns the list of all approved LSD tokens.
     */
    function getApprovedLSDs() external view returns (address[] memory) {
        return approvedLSDs;
    }

    /**
     * @notice Returns the number of approved LSD tokens.
     */
    function getLSDCount() external view returns (uint256) {
        return approvedLSDs.length;
    }

    /**
     * @notice Returns the pending (un-harvested) rewards for a user and LSD.
     */
    function pendingRewards(address user, address lsd) external view returns (uint256) {
        return _pendingRewards(user, lsd);
    }

    /**
     * @notice Returns the claimable reward credit for a user and LSD.
     */
    function getUserRewardCredit(address user, address lsd) external view returns (uint256) {
        return userRewardCredit[user][lsd];
    }

    /**
     * @notice Returns the total pending plus credited rewards for a user
     *         across a specific LSD.
     */
    function totalUserRewards(address user, address lsd) external view returns (uint256) {
        return _pendingRewards(user, lsd) + userRewardCredit[user][lsd];
    }

    /* ------------------------------------------------------------------ */
    /* Receive                                                            */
    /* ------------------------------------------------------------------ */

    receive() external payable {}
}
