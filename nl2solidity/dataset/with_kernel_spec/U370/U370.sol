// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: TRANSFER_FROM_FAILED"
        );
    }
}

contract CrowdfundingCampaign {
    using SafeERC20 for IERC20;

    enum State { NotStarted, Active, Succeeded, Failed }

    // ────────── Access control ──────────
    address public owner;
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ────────── Reentrancy guard ──────────
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ────────── Tokens & limits ──────────
    IERC20 public immutable depositToken;
    IERC20 public immutable rewardToken;
    uint8 private immutable depositTokenDecimals;
    uint256 public immutable MIN_GOAL_RAW;
    uint256 public constant MAX_DURATION = 30 days;

    // ────────── Campaign state ──────────
    uint256 public fundingGoal;
    uint256 public startTime;
    uint256 public endTime;
    State public currentState;

    uint256 public totalDeposits;
    uint256 public totalRewardTokens;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public rewardClaimed;
    mapping(address => bool) public depositWithdrawn;

    bool private raisedFundsWithdrawn;

    // ────────── Events ──────────
    event Deposited(address indexed participant, uint256 amount);
    event CampaignStatusChanged(State previousState, State newState);
    event FundingGoalSet(uint256 goal);
    event CampaignStarted(uint256 startTime, uint256 endTime);
    event CampaignFinalized(State finalState);
    event RewardTokensDeposited(address indexed depositor, uint256 amount);
    event RewardClaimed(address indexed participant, uint256 amount);
    event DepositWithdrawn(address indexed participant, uint256 amount);
    event RaisedFundsWithdrawn(address indexed beneficiary, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ────────── Errors ──────────
    error NotOwner();
    error ReentrantCall();
    error ZeroAddress();
    error InvalidState(State current);
    error InvalidFundingGoal(uint256 goal, uint256 minimum);
    error InvalidDuration(uint256 duration, uint256 maxDuration);
    error GoalNotSet();
    error NotEnded();
    error DepositZero();
    error NoDeposit();
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error InsufficientRewardTokens();
    error FundsAlreadyWithdrawn();

    // ────────── Constructor ──────────
    constructor(address _depositToken, address _rewardToken) {
        if (_depositToken == address(0)) revert ZeroAddress();
        if (_rewardToken == address(0)) revert ZeroAddress();

        depositToken = IERC20(_depositToken);
        rewardToken = IERC20(_rewardToken);
        depositTokenDecimals = _getDecimals(_depositToken);
        MIN_GOAL_RAW = 100_000 * (10 ** depositTokenDecimals);

        currentState = State.NotStarted;
        owner = msg.sender;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ────────── Ownership ──────────
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address old = owner;
        owner = address(0);
        emit OwnershipTransferred(old, address(0));
    }

    // ────────── Owner: campaign configuration ──────────
    function setFundingGoal(uint256 goal) external onlyOwner {
        if (currentState != State.NotStarted) revert InvalidState(currentState);
        if (goal < MIN_GOAL_RAW) revert InvalidFundingGoal(goal, MIN_GOAL_RAW);
        fundingGoal = goal;
        emit FundingGoalSet(goal);
    }

    function startCampaign(uint256 duration) external onlyOwner {
        if (currentState != State.NotStarted) revert InvalidState(currentState);
        if (fundingGoal == 0) revert GoalNotSet();
        if (duration == 0 || duration > MAX_DURATION) revert InvalidDuration(duration, MAX_DURATION);

        startTime = block.timestamp;
        endTime = startTime + duration;
        currentState = State.Active;

        emit CampaignStatusChanged(State.NotStarted, State.Active);
        emit CampaignStarted(startTime, endTime);
    }

    function finalizeCampaign() external onlyOwner {
        if (currentState != State.Active) revert InvalidState(currentState);
        if (block.timestamp < endTime) revert NotEnded();

        State previous = currentState;
        if (totalDeposits >= fundingGoal) {
            currentState = State.Succeeded;
        } else {
            currentState = State.Failed;
        }

        emit CampaignStatusChanged(previous, currentState);
        emit CampaignFinalized(currentState);
    }

    function depositRewardTokens(uint256 amount) external onlyOwner {
        if (amount == 0) revert DepositZero();
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        totalRewardTokens += amount;
        emit RewardTokensDeposited(msg.sender, amount);
    }

    function withdrawRaisedFunds(address beneficiary) external onlyOwner {
        if (currentState != State.Succeeded) revert InvalidState(currentState);
        if (beneficiary == address(0)) revert ZeroAddress();
        if (raisedFundsWithdrawn) revert FundsAlreadyWithdrawn();

        raisedFundsWithdrawn = true;
        uint256 amount = totalDeposits;
        depositToken.safeTransfer(beneficiary, amount);
        emit RaisedFundsWithdrawn(beneficiary, amount);
    }

    // ────────── Participant functions ──────────
    function deposit(uint256 amount) external nonReentrant {
        if (currentState != State.Active) revert InvalidState(currentState);
        if (amount == 0) revert DepositZero();

        depositToken.safeTransferFrom(msg.sender, address(this), amount);
        deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposited(msg.sender, amount);
    }

    function claimReward() external nonReentrant {
        if (currentState != State.Succeeded) revert InvalidState(currentState);
        uint256 userDeposit = deposits[msg.sender];
        if (userDeposit == 0) revert NoDeposit();
        if (rewardClaimed[msg.sender]) revert AlreadyClaimed();
        if (totalDeposits == 0) revert InsufficientRewardTokens();

        rewardClaimed[msg.sender] = true;
        uint256 reward = (userDeposit * totalRewardTokens) / totalDeposits;
        if (reward == 0) revert InsufficientRewardTokens();

        rewardToken.safeTransfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function withdrawDeposit() external nonReentrant {
        if (currentState != State.Failed) revert InvalidState(currentState);
        uint256 userDeposit = deposits[msg.sender];
        if (userDeposit == 0) revert NoDeposit();
        if (depositWithdrawn[msg.sender]) revert AlreadyWithdrawn();

        depositWithdrawn[msg.sender] = true;
        deposits[msg.sender] = 0;
        totalDeposits -= userDeposit;

        depositToken.safeTransfer(msg.sender, userDeposit);
        emit DepositWithdrawn(msg.sender, userDeposit);
    }

    // ────────── Views ──────────
    function getDepositTokenDecimals() external view returns (uint8) {
        return depositTokenDecimals;
    }

    function participantDeposit(address account) external view returns (uint256) {
        return deposits[account];
    }

    // ────────── Internal helpers ──────────
    function _getDecimals(address token) private view returns (uint8) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        require(success && data.length == 32, "Crowdfunding: decimals read failed");
        return abi.decode(data, (uint8));
    }
}
