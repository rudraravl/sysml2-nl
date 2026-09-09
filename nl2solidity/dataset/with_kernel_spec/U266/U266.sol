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
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool success = token.transfer(to, value);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bool success = token.transferFrom(from, to, value);
        if (!success) revert SafeERC20FailedOperation(address(token));
    }
    error SafeERC20FailedOperation(address token);
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

/// @title TokenLaunchpad
/// @notice Custodies deposited base tokens and project tokens for token launch campaigns.
contract TokenLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum CampaignStatus {
        Active,
        Finalized,
        Cancelled
    }

    struct Campaign {
        address projectToken;
        address baseToken;
        uint256 targetRaise;
        uint256 currentRaised;
        uint256 totalProjectTokens;
        CampaignStatus status;
        bool projectTokensDeposited;
    }

    /// @dev Minimum base-token contribution per participant (assumes 18 decimals).
    uint256 public constant MIN_CONTRIBUTION = 0.01 ether;
    /// @dev Maximum base-token contribution per participant (assumes 18 decimals).
    uint256 public constant MAX_CONTRIBUTION = 100 ether;

    uint256 public campaignCount;

    mapping(uint256 => Campaign) private s_campaigns;
    mapping(uint256 => mapping(address => uint256)) private s_contributions;
    mapping(uint256 => mapping(address => bool)) private s_hasClaimed;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed projectToken,
        address indexed baseToken,
        uint256 targetRaise,
        uint256 totalProjectTokens
    );
    event DepositMade(uint256 indexed campaignId, address indexed participant, uint256 amount);
    event ProjectTokensClaimed(uint256 indexed campaignId, address indexed participant, uint256 amount);
    event BaseTokensWithdrawn(uint256 indexed campaignId, address indexed participant, uint256 amount);
    event CampaignFinalized(uint256 indexed campaignId, uint256 totalRaised);
    event CampaignCancelled(uint256 indexed campaignId);
    event ProjectTokensDeposited(uint256 indexed campaignId, uint256 amount);

    error CampaignNotFound();
    error CampaignNotActive();
    error CampaignNotFinalized();
    error CampaignNotCancelled();
    error ContributionTooLow();
    error ContributionExceedsMax();
    error InsufficientProjectTokens();
    error ProjectTokensNotDeposited();
    error AlreadyClaimed();
    error TargetNotReached();
    error ZeroAddress();
    error InvalidTargetRaise();
    error InvalidTotalProjectTokens();
    error NoContribution();

    constructor() Ownable(msg.sender) {}

    /// @notice Creates a new launch campaign.
    /// @param projectToken The ERC20 token that participants will claim on success.
    /// @param baseToken The ERC20 token used to fundraise.
    /// @param targetRaise The minimum base-token amount required for a successful launch.
    /// @param totalProjectTokens The total project tokens to be distributed on success.
    function createCampaign(
        address projectToken,
        address baseToken,
        uint256 targetRaise,
        uint256 totalProjectTokens
    ) external onlyOwner returns (uint256 campaignId) {
        if (projectToken == address(0) || baseToken == address(0)) revert ZeroAddress();
        if (targetRaise == 0) revert InvalidTargetRaise();
        if (totalProjectTokens == 0) revert InvalidTotalProjectTokens();

        campaignId = ++campaignCount;
        Campaign storage c = s_campaigns[campaignId];
        c.projectToken = projectToken;
        c.baseToken = baseToken;
        c.targetRaise = targetRaise;
        c.totalProjectTokens = totalProjectTokens;
        c.status = CampaignStatus.Active;
        c.projectTokensDeposited = false;

        emit CampaignCreated(
            campaignId,
            projectToken,
            baseToken,
            targetRaise,
            totalProjectTokens
        );
    }

    /// @notice Deposits base tokens into an active campaign.
    /// @param campaignId The id of the campaign to fund.
    /// @param amount The amount of base tokens to deposit.
    function deposit(uint256 campaignId, uint256 amount) external nonReentrant {
        Campaign storage c = s_campaigns[campaignId];
        if (c.baseToken == address(0)) revert CampaignNotFound();
        if (c.status != CampaignStatus.Active) revert CampaignNotActive();
        if (amount < MIN_CONTRIBUTION) revert ContributionTooLow();
        if (s_contributions[campaignId][msg.sender] + amount > MAX_CONTRIBUTION) revert ContributionExceedsMax();

        c.currentRaised += amount;
        s_contributions[campaignId][msg.sender] += amount;

        IERC20(c.baseToken).safeTransferFrom(msg.sender, address(this), amount);

        emit DepositMade(campaignId, msg.sender, amount);
    }

    /// @notice Finalizes a successful campaign and pulls project tokens from the owner.
    /// @dev Requires the target raise to be reached.
    function finalizeCampaign(uint256 campaignId) external onlyOwner nonReentrant {
        Campaign storage c = s_campaigns[campaignId];
        if (c.baseToken == address(0)) revert CampaignNotFound();
        if (c.status != CampaignStatus.Active) revert CampaignNotActive();
        if (c.currentRaised < c.targetRaise) revert TargetNotReached();

        uint256 totalTokens = c.totalProjectTokens;
        IERC20(c.projectToken).safeTransferFrom(msg.sender, address(this), totalTokens);

        c.projectTokensDeposited = true;
        c.status = CampaignStatus.Finalized;

        emit ProjectTokensDeposited(campaignId, totalTokens);
        emit CampaignFinalized(campaignId, c.currentRaised);
    }

    /// @notice Cancels a failed campaign and unlocks base token withdrawals.
    function cancelCampaign(uint256 campaignId) external onlyOwner {
        Campaign storage c = s_campaigns[campaignId];
        if (c.baseToken == address(0)) revert CampaignNotFound();
        if (c.status != CampaignStatus.Active) revert CampaignNotActive();

        c.status = CampaignStatus.Cancelled;
        emit CampaignCancelled(campaignId);
    }

    /// @notice Claims allocated project tokens from a finalized campaign.
    function claimProjectTokens(uint256 campaignId) external nonReentrant {
        Campaign storage c = s_campaigns[campaignId];
        if (c.baseToken == address(0)) revert CampaignNotFound();
        if (c.status != CampaignStatus.Finalized) revert CampaignNotFinalized();
        if (!c.projectTokensDeposited) revert ProjectTokensNotDeposited();
        if (s_hasClaimed[campaignId][msg.sender]) revert AlreadyClaimed();

        uint256 contribution = s_contributions[campaignId][msg.sender];
        if (contribution == 0) revert NoContribution();

        s_hasClaimed[campaignId][msg.sender] = true;

        uint256 allocated = (contribution * c.totalProjectTokens) / c.currentRaised;
        if (allocated == 0) revert InsufficientProjectTokens();

        IERC20(c.projectToken).safeTransfer(msg.sender, allocated);

        emit ProjectTokensClaimed(campaignId, msg.sender, allocated);
    }

    /// @notice Withdraws base token contributions from a cancelled campaign.
    function withdrawBaseTokens(uint256 campaignId) external nonReentrant {
        Campaign storage c = s_campaigns[campaignId];
        if (c.baseToken == address(0)) revert CampaignNotFound();
        if (c.status != CampaignStatus.Cancelled) revert CampaignNotCancelled();

        uint256 contribution = s_contributions[campaignId][msg.sender];
        if (contribution == 0) revert NoContribution();

        s_contributions[campaignId][msg.sender] = 0;

        IERC20(c.baseToken).safeTransfer(msg.sender, contribution);

        emit BaseTokensWithdrawn(campaignId, msg.sender, contribution);
    }

    /// @notice Returns the campaign details.
    function getCampaign(uint256 campaignId) external view returns (
        address projectToken,
        address baseToken,
        uint256 targetRaise,
        uint256 currentRaised,
        uint256 totalProjectTokens,
        CampaignStatus status,
        bool projectTokensDeposited
    ) {
        Campaign storage c = s_campaigns[campaignId];
        return (
            c.projectToken,
            c.baseToken,
            c.targetRaise,
            c.currentRaised,
            c.totalProjectTokens,
            c.status,
            c.projectTokensDeposited
        );
    }

    /// @notice Returns a participant's contribution in a campaign.
    function getContribution(uint256 campaignId, address account) external view returns (uint256) {
        return s_contributions[campaignId][account];
    }

    /// @notice Returns whether a participant has already claimed project tokens.
    function hasClaimed(uint256 campaignId, address account) external view returns (bool) {
        return s_hasClaimed[campaignId][account];
    }
}
