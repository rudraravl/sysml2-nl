// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title OperationStaking
 * @notice Users stake tokens against the continued correct operation of a designated
 *         external smart contract. Staked tokens are held in escrow. Users may attest
 *         to a failure of the designated contract. A designated operator may declare a
 *         failure event, which pays out rewards to successful attestors (minus a 1% fee)
 *         and slashes stakers. The owner configures the designated contract, reward rate,
 *         slash percentage, and operator.
 */
contract OperationStaking {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error InsufficientStake();
    error AlreadyAttested();
    error NoAttestation();
    error FailureAlreadyDeclared();
    error NotFailureDeclared();
    error InsufficientRewardPool();
    error NothingToWithdraw();
    error AmountExceedsStake();
    error InvalidRewardRate();
    error InvalidSlashBps();
    error CannotRecoverStakingToken();
    error ReentrantCall();
    error ZeroAmount();

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    uint256 public constant MIN_STAKE = 100;
    uint256 public constant FEE_BPS = 100; // 1%
    uint256 public constant BPS_DENOM = 10000;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    address public owner;
    address public operator;
    IERC20 public immutable stakingToken;

    address public designatedContract;
    uint256 public rewardRate; // gross reward paid to each successful attester
    uint256 public slashBps; // slash applied to stakers on failure (in bps)
    uint256 public rewardPool; // tokens reserved for attester payouts
    uint256 public totalStaked;

    struct UserInfo {
        uint256 stakedAmount;
        address stakedAgainst;
        bool isRegistered;
    }

    mapping(address => UserInfo) public userInfo;
    address[] public stakers;

    mapping(address => bool) public hasAttested;
    address[] public attestors;
    uint256 public attestorCount;

    bool public failureDeclared;

    // Reentrancy guard state
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event Staked(address indexed user, address indexed against, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Attested(address indexed user, address indexed against);
    event FailureDeclared(
        address indexed against,
        uint256 slashAmount,
        uint256 payoutAmount,
        uint256 feeAmount
    );
    event DesignatedContractUpdated(address indexed previous, address indexed current);
    event RewardRateUpdated(uint256 previous, uint256 current);
    event SlashBpsUpdated(uint256 previous, uint256 current);
    event RewardPoolFunded(address indexed funder, uint256 amount);
    event OperatorUpdated(address indexed previous, address indexed current);
    event OwnershipTransferred(address indexed previous, address indexed newOwner);
    event RoundReset();
    event TokensRecovered(address indexed token, address indexed to, uint256 amount);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier whenActive() {
        if (failureDeclared) revert FailureAlreadyDeclared();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(
        address _stakingToken,
        address _designatedContract,
        address _operator,
        uint256 _rewardRate,
        uint256 _slashBps
    ) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_designatedContract == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_rewardRate == 0) revert InvalidRewardRate();
        if (_slashBps == 0 || _slashBps > BPS_DENOM) revert InvalidSlashBps();

        stakingToken = IERC20(_stakingToken);
        designatedContract = _designatedContract;
        operator = _operator;
        rewardRate = _rewardRate;
        slashBps = _slashBps;
        owner = msg.sender;
        _status = _NOT_ENTERED;

        emit OwnershipTransferred(address(0), msg.sender);
        emit DesignatedContractUpdated(address(0), _designatedContract);
        emit OperatorUpdated(address(0), _operator);
        emit RewardRateUpdated(0, _rewardRate);
        emit SlashBpsUpdated(0, _slashBps);
    }

    // -----------------------------------------------------------------------
    // User functions
    // -----------------------------------------------------------------------

    /**
     * @notice Stake tokens against the designated external contract.
     * @param amount The number of staking tokens to deposit. Must be >= MIN_STAKE.
     */
    function stake(uint256 amount) external nonReentrant whenActive {
        if (amount < MIN_STAKE) revert InsufficientStake();

        UserInfo storage info = userInfo[msg.sender];
        if (!info.isRegistered) {
            info.isRegistered = true;
            stakers.push(msg.sender);
        }
        info.stakedAmount += amount;
        info.stakedAgainst = designatedContract;
        totalStaked += amount;

        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Stake transfer failed"
        );

        emit Staked(msg.sender, designatedContract, amount);
    }

    /**
     * @notice Withdraw staked tokens. After a failure event, only the unslashed
     *         remainder is available.
     * @param amount The number of staking tokens to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage info = userInfo[msg.sender];
        if (info.stakedAmount == 0) revert NothingToWithdraw();
        if (amount > info.stakedAmount) revert AmountExceedsStake();

        info.stakedAmount -= amount;
        totalStaked -= amount;
        if (info.stakedAmount == 0) {
            info.stakedAgainst = address(0);
        }

        require(stakingToken.transfer(msg.sender, amount), "Withdraw transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Attest to a failure of the designated external contract. Only one
     *         attestation per user per round is permitted.
     */
    function attest() external whenActive {
        if (hasAttested[msg.sender]) revert AlreadyAttested();

        hasAttested[msg.sender] = true;
        attestors.push(msg.sender);
        attestorCount++;

        emit Attested(msg.sender, designatedContract);
    }

    // -----------------------------------------------------------------------
    // Operator functions
    // -----------------------------------------------------------------------

    /**
     * @notice Declare a failure event for the designated contract. Successful
     *         attestors receive `rewardRate` each (minus a 1% fee sent to the owner),
     *         and every staker is slashed by `slashBps`. Slashed tokens are added to
     *         the reward pool to fund future rounds.
     */
    function declareFailure() external onlyOperator nonReentrant {
        if (failureDeclared) revert FailureAlreadyDeclared();
        if (attestorCount == 0) revert NoAttestation();

        // Compute totals with multiplication BEFORE division to avoid precision loss.
        // The gross amount per attester is `rewardRate`; the fee is 1% of the gross.
        // totalGross = rewardRate * attestorCount  (multiply first)
        // totalFee   = (totalGross * FEE_BPS) / BPS_DENOM  (multiply then divide)
        uint256 totalGross = rewardRate * attestorCount;
        uint256 totalFee = (totalGross * FEE_BPS) / BPS_DENOM;
        uint256 totalNet = totalGross - totalFee;

        if (rewardPool < totalGross) revert InsufficientRewardPool();

        // --- Effects: update all state BEFORE any external calls (CEI) ---
        failureDeclared = true;

        // Slash stakers (state-only, no external calls).
        uint256 totalSlashed = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            UserInfo storage info = userInfo[stakers[i]];
            uint256 bal = info.stakedAmount;
            if (bal == 0) continue;
            uint256 slash = (bal * slashBps) / BPS_DENOM;
            info.stakedAmount = bal - slash;
            totalSlashed += slash;
        }
        totalStaked -= totalSlashed;
        rewardPool = rewardPool - totalGross + totalSlashed;

        // Clear attestation flags so users may attest again after resetRound.
        for (uint256 i = 0; i < attestorCount; i++) {
            hasAttested[attestors[i]] = false;
        }

        // --- Interactions: transfer tokens out ---
        uint256 netPerAttestor = totalNet / attestorCount;
        uint256 netRemainder = totalNet % attestorCount;
        for (uint256 i = 0; i < attestorCount; i++) {
            address att = attestors[i];
            uint256 amount = netPerAttestor;
            if (i == attestorCount - 1) {
                amount += netRemainder;
            }
            require(
                stakingToken.transfer(att, amount),
                "Attestor payout failed"
            );
        }

        if (totalFee > 0) {
            require(stakingToken.transfer(owner, totalFee), "Fee transfer failed");
        }

        emit FailureDeclared(designatedContract, totalSlashed, totalNet, totalFee);
    }

    /**
     * @notice Reset the round after a failure event so that staking and attestation
     *         may resume. Existing staker registrations are preserved.
     */
    function resetRound() external onlyOperator nonReentrant {
        if (!failureDeclared) revert NotFailureDeclared();

        delete attestors;
        attestorCount = 0;
        failureDeclared = false;

        emit RoundReset();
    }

    // -----------------------------------------------------------------------
    // Owner functions
    // -----------------------------------------------------------------------

    /**
     * @notice Set the designated external contract that stakers stake against.
     */
    function setDesignatedContract(address _designatedContract) external onlyOwner {
        if (_designatedContract == address(0)) revert ZeroAddress();
        address previous = designatedContract;
        designatedContract = _designatedContract;
        emit DesignatedContractUpdated(previous, _designatedContract);
    }

    /**
     * @notice Set the reward rate paid to each successful attester on failure.
     */
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        if (_rewardRate == 0) revert InvalidRewardRate();
        uint256 previous = rewardRate;
        rewardRate = _rewardRate;
        emit RewardRateUpdated(previous, _rewardRate);
    }

    /**
     * @notice Set the slash percentage (in basis points) applied to stakers on failure.
     */
    function setSlashBps(uint256 _slashBps) external onlyOwner {
        if (_slashBps == 0 || _slashBps > BPS_DENOM) revert InvalidSlashBps();
        uint256 previous = slashBps;
        slashBps = _slashBps;
        emit SlashBpsUpdated(previous, _slashBps);
    }

    /**
     * @notice Set the operator authorized to declare failure events.
     */
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = _operator;
        emit OperatorUpdated(previous, _operator);
    }

    /**
     * @notice Fund the global reward pool used to pay successful attestors.
     */
    function fundRewardPool(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        rewardPool += amount;
        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Funding transfer failed"
        );
        emit RewardPoolFunded(msg.sender, amount);
    }

    /**
     * @notice Transfer ownership to a new address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    /**
     * @notice Recover accidentally sent ERC20 tokens. The staking token may only be
     *         recovered in excess of the total staked amount plus the reward pool.
     */
    function recoverTokens(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (token == address(stakingToken)) {
            uint256 locked = totalStaked + rewardPool;
            uint256 contractBalance = stakingToken.balanceOf(address(this));
            uint256 recoverable = contractBalance > locked
                ? contractBalance - locked
                : 0;
            if (amount > recoverable) revert CannotRecoverStakingToken();
        }

        require(IERC20(token).transfer(to, amount), "Recovery transfer failed");
        emit TokensRecovered(token, to, amount);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    function stakerCount() external view returns (uint256) {
        return stakers.length;
    }

    function getStakerAt(uint256 index) external view returns (address) {
        return stakers[index];
    }

    function getAttestorAt(uint256 index) external view returns (address) {
        return attestors[index];
    }
}
