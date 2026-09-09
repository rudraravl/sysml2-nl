// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
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
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
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

contract Web3Launchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidPrice();
    error InvalidDeadline();
    error FundingGoalTooLow();
    error ProjectNotFound();
    error ProjectNotApproved();
    error ProjectAlreadyApproved();
    error ProjectAlreadyLaunched();
    error ProjectAlreadyFailed();
    error ProjectNotActive();
    error DeadlinePassed();
    error DeadlineNotPassed();
    error GoalNotReached();
    error GoalReached();
    error ExceedsRemainingAllocation();
    error NoContribution();
    error AlreadyClaimed();
    error AlreadyRefunded();
    error FundsAlreadyWithdrawn();
    error TokensAlreadyReclaimed();
    error FeeTooHigh();
    error NotProjectCreator();
    error NotOperator();

    uint256 public constant MIN_FUNDING_GOAL = 100;
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10000;

    struct Project {
        address creator;
        address projectToken;
        address contributionToken;
        uint256 fundingGoal;
        uint256 raised;
        uint256 tokenAmount;
        uint256 tokensRemaining;
        uint256 pricePerToken;
        uint256 deadline;
        bool approved;
        bool launched;
        bool failed;
        bool fundsWithdrawn;
        bool tokensReclaimed;
    }

    address public feeRecipient;
    uint256 public platformFeeBps = 500;

    uint256 public projectCount;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(uint256 => mapping(address => bool)) public hasRefunded;
    mapping(address => bool) public operators;

    event ProjectProposed(
        uint256 indexed projectId,
        address indexed creator,
        address projectToken,
        address contributionToken,
        uint256 fundingGoal,
        uint256 tokenAmount,
        uint256 pricePerToken,
        uint256 deadline
    );
    event ProjectApproved(uint256 indexed projectId);
    event Contributed(uint256 indexed projectId, address indexed participant, uint256 amount, uint256 tokensOwed);
    event ProjectLaunched(uint256 indexed projectId, uint256 raised);
    event ProjectFailed(uint256 indexed projectId, uint256 raised, uint256 fundingGoal);
    event TokensClaimed(uint256 indexed projectId, address indexed participant, uint256 tokenAmount);
    event ContributionRefunded(uint256 indexed projectId, address indexed participant, uint256 amount);
    event FundsWithdrawn(uint256 indexed projectId, address indexed creator, uint256 amount, uint256 fee);
    event TokensReclaimed(uint256 indexed projectId, address indexed creator, uint256 tokenAmount);
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event OperatorSet(address indexed operator, bool approved);

    modifier onlyOperatorOrOwner() {
        if (msg.sender != owner() && !operators[msg.sender]) revert NotOperator();
        _;
    }

    modifier onlyProjectCreator(uint256 projectId) {
        if (projects[projectId].creator != msg.sender) revert NotProjectCreator();
        _;
    }

    modifier projectExists(uint256 projectId) {
        if (projects[projectId].creator == address(0)) revert ProjectNotFound();
        _;
    }

    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    function proposeProject(
        address projectToken,
        address contributionToken,
        uint256 tokenAmount,
        uint256 pricePerToken,
        uint256 deadline
    ) external nonReentrant returns (uint256 projectId) {
        if (projectToken == address(0) || contributionToken == address(0)) revert ZeroAddress();
        if (tokenAmount == 0) revert ZeroAmount();
        if (pricePerToken == 0) revert InvalidPrice();
        if (deadline <= block.timestamp) revert InvalidDeadline();

        uint256 fundingGoal = tokenAmount * pricePerToken;
        if (fundingGoal < MIN_FUNDING_GOAL) revert FundingGoalTooLow();

        projectId = ++projectCount;
        Project storage p = projects[projectId];
        p.creator = msg.sender;
        p.projectToken = projectToken;
        p.contributionToken = contributionToken;
        p.fundingGoal = fundingGoal;
        p.tokenAmount = tokenAmount;
        p.tokensRemaining = tokenAmount;
        p.pricePerToken = pricePerToken;
        p.deadline = deadline;

        IERC20(projectToken).safeTransferFrom(msg.sender, address(this), tokenAmount);

        emit ProjectProposed(
            projectId,
            msg.sender,
            projectToken,
            contributionToken,
            fundingGoal,
            tokenAmount,
            pricePerToken,
            deadline
        );
    }

    function approveProject(uint256 projectId) external onlyOperatorOrOwner projectExists(projectId) {
        Project storage p = projects[projectId];
        if (p.approved) revert ProjectAlreadyApproved();
        if (block.timestamp >= p.deadline) revert DeadlinePassed();

        p.approved = true;
        emit ProjectApproved(projectId);
    }

    function contribute(uint256 projectId, uint256 amount)
        external
        nonReentrant
        projectExists(projectId)
    {
        Project storage p = projects[projectId];
        if (!p.approved) revert ProjectNotApproved();
        if (p.launched) revert ProjectAlreadyLaunched();
        if (p.failed) revert ProjectAlreadyFailed();
        if (block.timestamp >= p.deadline) revert DeadlinePassed();
        if (amount == 0) revert ZeroAmount();

        uint256 maxContribution = p.tokensRemaining * p.pricePerToken;
        if (amount > maxContribution) revert ExceedsRemainingAllocation();

        uint256 tokensOwed = amount / p.pricePerToken;
        if (tokensOwed == 0) revert ZeroAmount();

        p.tokensRemaining -= tokensOwed;
        p.raised += amount;
        contributions[projectId][msg.sender] += amount;

        IERC20(p.contributionToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Contributed(projectId, msg.sender, amount, tokensOwed);
    }

    function launchProject(uint256 projectId) external nonReentrant onlyProjectCreator(projectId) {
        Project storage p = projects[projectId];
        if (!p.approved) revert ProjectNotApproved();
        if (p.launched) revert ProjectAlreadyLaunched();
        if (p.failed) revert ProjectAlreadyFailed();
        if (p.raised < p.fundingGoal) revert GoalNotReached();
        if (block.timestamp >= p.deadline) revert DeadlinePassed();

        p.launched = true;
        emit ProjectLaunched(projectId, p.raised);
    }

    function failProject(uint256 projectId) external projectExists(projectId) {
        Project storage p = projects[projectId];
        if (!p.approved) revert ProjectNotApproved();
        if (p.launched) revert ProjectAlreadyLaunched();
        if (p.failed) revert ProjectAlreadyFailed();
        if (block.timestamp < p.deadline) revert DeadlineNotPassed();
        if (p.raised >= p.fundingGoal) revert GoalReached();

        p.failed = true;
        emit ProjectFailed(projectId, p.raised, p.fundingGoal);
    }

    function claimTokens(uint256 projectId) external nonReentrant projectExists(projectId) {
        Project storage p = projects[projectId];
        if (!p.launched) revert ProjectNotActive();
        if (hasClaimed[projectId][msg.sender]) revert AlreadyClaimed();

        uint256 contribution = contributions[projectId][msg.sender];
        if (contribution == 0) revert NoContribution();

        hasClaimed[projectId][msg.sender] = true;
        uint256 tokensOwed = contribution / p.pricePerToken;

        IERC20(p.projectToken).safeTransfer(msg.sender, tokensOwed);

        emit TokensClaimed(projectId, msg.sender, tokensOwed);
    }

    function refund(uint256 projectId) external nonReentrant projectExists(projectId) {
        Project storage p = projects[projectId];
        if (!p.failed) revert ProjectNotActive();
        if (hasRefunded[projectId][msg.sender]) revert AlreadyRefunded();

        uint256 contribution = contributions[projectId][msg.sender];
        if (contribution == 0) revert NoContribution();

        hasRefunded[projectId][msg.sender] = true;
        contributions[projectId][msg.sender] = 0;

        IERC20(p.contributionToken).safeTransfer(msg.sender, contribution);

        emit ContributionRefunded(projectId, msg.sender, contribution);
    }

    function withdrawFunds(uint256 projectId)
        external
        nonReentrant
        onlyProjectCreator(projectId)
    {
        Project storage p = projects[projectId];
        if (!p.launched) revert ProjectNotActive();
        if (p.fundsWithdrawn) revert FundsAlreadyWithdrawn();

        p.fundsWithdrawn = true;
        uint256 total = p.raised;
        uint256 fee = (total * platformFeeBps) / BASIS_POINTS_DENOMINATOR;
        uint256 net = total - fee;

        if (fee > 0) {
            IERC20(p.contributionToken).safeTransfer(feeRecipient, fee);
        }
        IERC20(p.contributionToken).safeTransfer(p.creator, net);

        emit FundsWithdrawn(projectId, p.creator, net, fee);
    }

    function reclaimTokens(uint256 projectId)
        external
        nonReentrant
        onlyProjectCreator(projectId)
    {
        Project storage p = projects[projectId];
        if (!p.failed) revert ProjectNotActive();
        if (p.tokensReclaimed) revert TokensAlreadyReclaimed();

        p.tokensReclaimed = true;
        uint256 amount = p.tokensRemaining;

        IERC20(p.projectToken).safeTransfer(p.creator, amount);

        emit TokensReclaimed(projectId, p.creator, amount);
    }

    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        uint256 old = platformFeeBps;
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(old, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setOperator(address operator, bool approved) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = approved;
        emit OperatorSet(operator, approved);
    }

    function getProjectCreator(uint256 projectId) external view returns (address) {
        return projects[projectId].creator;
    }

    function getProjectToken(uint256 projectId) external view returns (address) {
        return projects[projectId].projectToken;
    }

    function getContributionToken(uint256 projectId) external view returns (address) {
        return projects[projectId].contributionToken;
    }

    function getFundingGoal(uint256 projectId) external view returns (uint256) {
        return projects[projectId].fundingGoal;
    }

    function getRaised(uint256 projectId) external view returns (uint256) {
        return projects[projectId].raised;
    }

    function getTokenAmount(uint256 projectId) external view returns (uint256) {
        return projects[projectId].tokenAmount;
    }

    function getTokensRemaining(uint256 projectId) external view returns (uint256) {
        return projects[projectId].tokensRemaining;
    }

    function getPricePerToken(uint256 projectId) external view returns (uint256) {
        return projects[projectId].pricePerToken;
    }

    function getDeadline(uint256 projectId) external view returns (uint256) {
        return projects[projectId].deadline;
    }

    function isApproved(uint256 projectId) external view returns (bool) {
        return projects[projectId].approved;
    }

    function isLaunched(uint256 projectId) external view returns (bool) {
        return projects[projectId].launched;
    }

    function isFailed(uint256 projectId) external view returns (bool) {
        return projects[projectId].failed;
    }

    function getContribution(uint256 projectId, address participant) external view returns (uint256) {
        return contributions[projectId][participant];
    }

    function remainingAllocation(uint256 projectId) external view returns (uint256) {
        Project storage p = projects[projectId];
        return p.tokensRemaining * p.pricePerToken;
    }
}
