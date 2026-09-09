// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TruthBounty {
    // --- Enums ---
    enum Status { Open, ResolvedTrue, ResolvedFalse }

    // --- Structs ---
    struct Claim {
        address creator;
        string description;
        uint256 endTime;
        Status status;
        uint256 totalFor;
        uint256 totalAgainst;
        uint256 feePercentage;
    }

    struct UserStake {
        uint256 amountFor;
        uint256 amountAgainst;
        bool claimed;
    }

    // --- State Variables ---
    address public operator;
    uint256 public feePercentage;

    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MIN_STAKING_PERIOD = 7 days;
    uint256 public constant MAX_FEE = 1000; // 10% cap

    uint256 public nextClaimId;
    mapping(uint256 => Claim) public claims;
    mapping(uint256 => mapping(address => UserStake)) public userStakes;

    bool private _locked;

    // --- Events ---
    event ClaimCreated(uint256 indexed claimId, address indexed creator, string description, uint256 endTime);
    event Staked(uint256 indexed claimId, address indexed staker, bool side, uint256 amount);
    event StakeWithdrawn(uint256 indexed claimId, address indexed staker, uint256 amountFor, uint256 amountAgainst);
    event ClaimResolved(uint256 indexed claimId, bool winningSide, uint256 totalRewards, uint256 feeAmount);
    event RewardsClaimed(uint256 indexed claimId, address indexed claimer, uint256 amount);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    // --- Errors ---
    error NotOperator();
    error ZeroAddress();
    error ClaimNotFound();
    error StakingPeriodTooShort();
    error StakingPeriodEnded();
    error StakingPeriodActive();
    error AlreadyResolved();
    error NotResolved();
    error AlreadyClaimed();
    error NothingToWithdraw();
    error WrongSide();
    error NothingToClaim();
    error ZeroAmount();
    error EmptyDescription();
    error TransferFailed();
    error FeeTooHigh();
    error ReentrancyDetected();

    // --- Modifiers ---
    modifier nonReentrant() {
        if (_locked) revert ReentrancyDetected();
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    // --- Constructor ---
    constructor(address _operator) {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        feePercentage = 200; // 2% default
        emit OperatorUpdated(address(0), _operator);
        emit FeePercentageUpdated(0, feePercentage);
    }

    // --- External / Public Functions ---

    /**
     * @notice Creates a new claim with a staking period of at least 7 days.
     * @param _description Human-readable description of the claim.
     * @param _stakingPeriod Duration in seconds during which staking is allowed.
     * @return claimId The ID of the newly created claim.
     */
    function createClaim(string calldata _description, uint256 _stakingPeriod)
        external
        nonReentrant
        returns (uint256 claimId)
    {
        if (bytes(_description).length == 0) revert EmptyDescription();
        if (_stakingPeriod < MIN_STAKING_PERIOD) revert StakingPeriodTooShort();

        claimId = nextClaimId++;
        uint256 endTime = block.timestamp + _stakingPeriod;

        claims[claimId] = Claim({
            creator: msg.sender,
            description: _description,
            endTime: endTime,
            status: Status.Open,
            totalFor: 0,
            totalAgainst: 0,
            feePercentage: feePercentage
        });

        emit ClaimCreated(claimId, msg.sender, _description, endTime);
    }

    /**
     * @notice Stakes ETH on the truth or falsity of a claim.
     * @param _claimId The claim to stake on.
     * @param _side True to stake in favor, false to stake against.
     */
    function stake(uint256 _claimId, bool _side) external payable nonReentrant {
        if (_claimId >= nextClaimId) revert ClaimNotFound();
        if (msg.value == 0) revert ZeroAmount();

        Claim storage claim = claims[_claimId];
        if (claim.status != Status.Open) revert AlreadyResolved();
        if (block.timestamp >= claim.endTime) revert StakingPeriodEnded();

        UserStake storage userStake = userStakes[_claimId][msg.sender];
        if (_side) {
            userStake.amountFor += msg.value;
            claim.totalFor += msg.value;
        } else {
            userStake.amountAgainst += msg.value;
            claim.totalAgainst += msg.value;
        }

        emit Staked(_claimId, msg.sender, _side, msg.value);
    }

    /**
     * @notice Withdraws the caller's entire stake from an unresolved claim.
     * @param _claimId The claim to withdraw from.
     */
    function withdrawStake(uint256 _claimId) external nonReentrant {
        if (_claimId >= nextClaimId) revert ClaimNotFound();

        Claim storage claim = claims[_claimId];
        if (claim.status != Status.Open) revert AlreadyResolved();

        UserStake storage userStake = userStakes[_claimId][msg.sender];
        uint256 amountFor = userStake.amountFor;
        uint256 amountAgainst = userStake.amountAgainst;
        uint256 total = amountFor + amountAgainst;
        if (total == 0) revert NothingToWithdraw();

        // Effects
        userStake.amountFor = 0;
        userStake.amountAgainst = 0;
        claim.totalFor -= amountFor;
        claim.totalAgainst -= amountAgainst;

        // Interactions
        (bool success, ) = msg.sender.call{value: total}("");
        if (!success) revert TransferFailed();

        emit StakeWithdrawn(_claimId, msg.sender, amountFor, amountAgainst);
    }

    /**
     * @notice Resolves a claim as true or false. Only callable by the operator.
     *         Sends the operator's fee from the losing pool immediately.
     * @param _claimId The claim to resolve.
     * @param _resolvedAsTrue Whether the claim is resolved as true.
     */
    function resolveClaim(uint256 _claimId, bool _resolvedAsTrue) external onlyOperator nonReentrant {
        if (_claimId >= nextClaimId) revert ClaimNotFound();

        Claim storage claim = claims[_claimId];
        if (claim.status != Status.Open) revert AlreadyResolved();
        if (block.timestamp < claim.endTime) revert StakingPeriodActive();

        claim.status = _resolvedAsTrue ? Status.ResolvedTrue : Status.ResolvedFalse;

        uint256 winningPool = _resolvedAsTrue ? claim.totalFor : claim.totalAgainst;
        uint256 losingPool = _resolvedAsTrue ? claim.totalAgainst : claim.totalFor;

        uint256 feeAmount = 0;
        if (winningPool > 0 && losingPool > 0) {
            feeAmount = (losingPool * claim.feePercentage) / FEE_DENOMINATOR;
            if (feeAmount > 0) {
                (bool success, ) = operator.call{value: feeAmount}("");
                if (!success) revert TransferFailed();
            }
        }

        uint256 totalRewards = losingPool - feeAmount;

        emit ClaimResolved(_claimId, _resolvedAsTrue, totalRewards, feeAmount);
    }

    /**
     * @notice Claims the caller's stake and proportional reward share after resolution.
     * @param _claimId The resolved claim to claim rewards from.
     */
    function claimRewards(uint256 _claimId) external nonReentrant {
        if (_claimId >= nextClaimId) revert ClaimNotFound();

        Claim storage claim = claims[_claimId];
        if (claim.status == Status.Open) revert NotResolved();

        UserStake storage userStake = userStakes[_claimId][msg.sender];
        if (userStake.claimed) revert AlreadyClaimed();

        bool resolvedTrue = claim.status == Status.ResolvedTrue;
        uint256 userWinning = resolvedTrue ? userStake.amountFor : userStake.amountAgainst;
        if (userWinning == 0) revert WrongSide();

        uint256 totalWinning = resolvedTrue ? claim.totalFor : claim.totalAgainst;
        uint256 losingPool = resolvedTrue ? claim.totalAgainst : claim.totalFor;

        if (totalWinning == 0) revert NothingToClaim();

        // Calculate fee and net rewards (fee already sent to operator at resolution)
        uint256 feeAmount = (losingPool * claim.feePercentage) / FEE_DENOMINATOR;
        uint256 netRewards = losingPool - feeAmount;
        uint256 rewardShare = (userWinning * netRewards) / totalWinning;
        uint256 payout = userWinning + rewardShare;

        // Effects
        userStake.claimed = true;

        // Interactions
        (bool success, ) = msg.sender.call{value: payout}("");
        if (!success) revert TransferFailed();

        emit RewardsClaimed(_claimId, msg.sender, payout);
    }

    // --- Operator Administration ---

    /**
     * @notice Updates the global fee percentage for future claims.
     * @param _newFeePercentage New fee in basis points (max 10%).
     */
    function setFeePercentage(uint256 _newFeePercentage) external onlyOperator {
        if (_newFeePercentage > MAX_FEE) revert FeeTooHigh();
        uint256 oldFee = feePercentage;
        feePercentage = _newFeePercentage;
        emit FeePercentageUpdated(oldFee, _newFeePercentage);
    }

    /**
     * @notice Transfers the operator role to a new address.
     * @param _newOperator The address of the new operator.
     */
    function setOperator(address _newOperator) external onlyOperator {
        if (_newOperator == address(0)) revert ZeroAddress();
        address oldOperator = operator;
        operator = _newOperator;
        emit OperatorUpdated(oldOperator, _newOperator);
    }

    // --- View Functions ---

    /**
     * @notice Returns full claim details.
     */
    function getClaim(uint256 _claimId) external view returns (Claim memory) {
        if (_claimId >= nextClaimId) revert ClaimNotFound();
        return claims[_claimId];
    }

    /**
     * @notice Returns a user's stake on a specific claim.
     */
    function getUserStake(uint256 _claimId, address _user) external view returns (UserStake memory) {
        if (_claimId >= nextClaimId) revert ClaimNotFound();
        return userStakes[_claimId][_user];
    }

    /**
     * @notice Returns the number of claims created so far.
     */
    function getClaimCount() external view returns (uint256) {
        return nextClaimId;
    }
}
