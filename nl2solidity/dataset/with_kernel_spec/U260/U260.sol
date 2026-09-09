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
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        if (address(token).code.length == 0) {
            revert("SafeERC20: address is not a contract");
        }

        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: low-level call failed");
            }
        }

        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) {
                revert("SafeERC20: ERC20 operation did not succeed");
            }
        }
    }
}

contract FairLaunchEscrow {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error InvalidFeePercent();
    error InsufficientCreatorDeposit();
    error CampaignNotFound();
    error CampaignNotPending();
    error CampaignNotOpen();
    error CampaignNotClosed();
    error CampaignStillActive();
    error NothingToClaim();
    error NotCampaignCreator();
    error DepositAlreadyWithdrawn();
    error FundsAlreadyWithdrawn();
    error ZeroContribution();
    error ExceedsHardCap();
    error UnauthorizedOperator();
    error Unauthorized();
    error InvalidCapConfig();
    error TargetNotReached();
    error EnforcedPause();
    error ExpectedPause();
    error ReentrantCall();

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        address indexed token,
        address baseCurrency,
        uint256 softCap,
        uint256 hardCap,
        uint256 tokenAllocation,
        uint256 startTime,
        uint256 endTime,
        uint256 creatorDeposit
    );
    event CampaignApproved(uint256 indexed campaignId, address indexed operator);
    event CampaignRejected(uint256 indexed campaignId, address indexed operator);
    event Contributed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignClosed(uint256 indexed campaignId, bool success, uint256 totalRaised, uint256 feeCollected);
    event TokensClaimed(uint256 indexed campaignId, address indexed contributor, uint256 tokenAmount, uint256 refundAmount);
    event CreatorDepositWithdrawn(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event CreatorFundsWithdrawn(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event FeePercentUpdated(uint256 oldPercent, uint256 newPercent);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event OperatorSet(address indexed operator, bool status);
    event PausedState(bool isPaused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct Campaign {
        address creator;
        address token;
        address baseCurrency;
        uint256 softCap;
        uint256 hardCap;
        uint256 tokenAllocation;
        uint256 startTime;
        uint256 endTime;
        uint256 creatorDeposit;
        bool depositWithdrawn;
        bool fundsWithdrawn;
        CampaignState state;
        uint256 totalRaised;
        uint256 feeCollected;
        uint256 tokenPerBase;
    }

    struct Contributor {
        uint256 amount;
        bool claimed;
    }

    enum CampaignState {
        Pending,
        Rejected,
        Open,
        Closed
    }

    uint256 public constant MIN_CREATOR_DEPOSIT = 100 ether;
    uint256 public constant HUNDRED_PERCENT = 100 ether;
    uint256 public constant FEE_DEFAULT = 2 ether;

    address public owner;
    bool public paused;
    uint256 public feePercent;
    uint256 public campaignCount;
    address public feeRecipient;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contributor)) public contributions;
    mapping(address => bool) public operators;

    bool private _locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert UnauthorizedOperator();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    modifier campaignExists(uint256 campaignId) {
        if (campaigns[campaignId].creator == address(0)) revert CampaignNotFound();
        _;
    }

    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        feePercent = FEE_DEFAULT;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeePercentUpdated(0, feePercent);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    function setFeePercent(uint256 _percent) external onlyOwner {
        if (_percent > HUNDRED_PERCENT) revert InvalidFeePercent();
        uint256 old = feePercent;
        feePercent = _percent;
        emit FeePercentUpdated(old, _percent);
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        if (_recipient == address(0)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = _recipient;
        emit FeeRecipientUpdated(old, _recipient);
    }

    function setOperator(address _operator, bool _status) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operators[_operator] = _status;
        emit OperatorSet(_operator, _status);
    }

    function pause() external onlyOwner {
        paused = true;
        emit PausedState(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit PausedState(false);
    }

    function createCampaign(
        address token,
        address baseCurrency,
        uint256 softCap,
        uint256 hardCap,
        uint256 tokenAllocation,
        uint256 startTime,
        uint256 endTime,
        uint256 creatorDeposit
    ) external whenNotPaused nonReentrant returns (uint256 campaignId) {
        if (token == address(0) || baseCurrency == address(0)) revert ZeroAddress();
        if (creatorDeposit < MIN_CREATOR_DEPOSIT) revert InsufficientCreatorDeposit();
        if (hardCap == 0 || softCap > hardCap) revert InvalidCapConfig();
        if (endTime <= startTime || endTime <= block.timestamp) revert InvalidCapConfig();
        if (tokenAllocation == 0) revert InvalidCapConfig();

        campaignId = campaignCount++;

        Campaign storage c = campaigns[campaignId];
        c.creator = msg.sender;
        c.token = token;
        c.baseCurrency = baseCurrency;
        c.softCap = softCap;
        c.hardCap = hardCap;
        c.tokenAllocation = tokenAllocation;
        c.startTime = startTime;
        c.endTime = endTime;
        c.creatorDeposit = creatorDeposit;
        c.state = CampaignState.Pending;

        IERC20(baseCurrency).safeTransferFrom(msg.sender, address(this), creatorDeposit);

        emit CampaignCreated(
            campaignId,
            msg.sender,
            token,
            baseCurrency,
            softCap,
            hardCap,
            tokenAllocation,
            startTime,
            endTime,
            creatorDeposit
        );
    }

    function approveCampaign(uint256 campaignId)
        external
        onlyOperator
        campaignExists(campaignId)
        nonReentrant
    {
        Campaign storage c = campaigns[campaignId];
        if (c.state != CampaignState.Pending) revert CampaignNotPending();

        IERC20(c.token).safeTransferFrom(c.creator, address(this), c.tokenAllocation);
        c.state = CampaignState.Open;

        emit CampaignApproved(campaignId, msg.sender);
    }

    function rejectCampaign(uint256 campaignId)
        external
        onlyOperator
        campaignExists(campaignId)
        nonReentrant
    {
        Campaign storage c = campaigns[campaignId];
        if (c.state != CampaignState.Pending) revert CampaignNotPending();

        c.state = CampaignState.Rejected;
        c.depositWithdrawn = true;

        IERC20(c.baseCurrency).safeTransfer(c.creator, c.creatorDeposit);

        emit CampaignRejected(campaignId, msg.sender);
    }

    function contribute(uint256 campaignId, uint256 amount)
        external
        whenNotPaused
        campaignExists(campaignId)
        nonReentrant
    {
        Campaign storage c = campaigns[campaignId];
        if (c.state != CampaignState.Open) revert CampaignNotOpen();
        if (block.timestamp < c.startTime || block.timestamp >= c.endTime) revert CampaignNotOpen();
        if (amount == 0) revert ZeroContribution();
        if (c.totalRaised + amount > c.hardCap) revert ExceedsHardCap();

        IERC20(c.baseCurrency).safeTransferFrom(msg.sender, address(this), amount);
        contributions[campaignId][msg.sender].amount += amount;
        c.totalRaised += amount;

        emit Contributed(campaignId, msg.sender, amount);

        if (c.totalRaised == c.hardCap) {
            _closeCampaign(campaignId);
        }
    }

    function closeCampaign(uint256 campaignId)
        external
        campaignExists(campaignId)
        nonReentrant
    {
        Campaign storage c = campaigns[campaignId];
        if (c.state != CampaignState.Open) revert CampaignNotOpen();
        if (block.timestamp < c.endTime && c.totalRaised < c.hardCap) revert CampaignStillActive();
        _closeCampaign(campaignId);
    }

    function _closeCampaign(uint256 campaignId) internal {
        Campaign storage c = campaigns[campaignId];
        bool success = c.totalRaised >= c.softCap;

        if (success) {
            if (c.totalRaised == 0) {
                IERC20(c.token).safeTransfer(c.creator, c.tokenAllocation);
                c.tokenPerBase = 0;
                c.feeCollected = 0;
            } else {
                uint256 fee = (c.totalRaised * feePercent) / HUNDRED_PERCENT;
                c.feeCollected = fee;
                c.tokenPerBase = (c.tokenAllocation * 1e18) / c.totalRaised;
                if (fee > 0) {
                    IERC20(c.baseCurrency).safeTransfer(feeRecipient, fee);
                }
            }
        } else {
            c.tokenPerBase = 0;
            c.feeCollected = 0;
            IERC20(c.token).safeTransfer(c.creator, c.tokenAllocation);
        }

        c.state = CampaignState.Closed;
        emit CampaignClosed(campaignId, success, c.totalRaised, c.feeCollected);
    }

    function claim(uint256 campaignId)
        external
        campaignExists(campaignId)
        nonReentrant
    {
        Campaign storage c = campaigns[campaignId];
        if (c.state != CampaignState.Closed) revert CampaignNotClosed();

        Contributor storage con = contributions[campaignId][msg.sender];
        if (con.claimed || con.amount == 0) revert NothingToClaim();

        con.claimed = true;

        uint256 tokenAmount;
        uint256 refundAmount;

        bool success = c.totalRaised >= c.softCap;
        if (success) {
            tokenAmount = (con.amount * c.tokenPerBase) / 1e18;
            refundAmount = 0;
        } else {
            tokenAmount = 0;
            refundAmount = con.amount;
        }

        if (tokenAmount > 0) {
            IERC20(c.token).safeTransfer(msg.sender, tokenAmount);
        }
        if (refundAmount > 0) {
            IERC20(c.baseCurrency).safeTransfer(msg.sender, refundAmount);
        }

        emit TokensClaimed(campaignId, msg.sender, tokenAmount, refundAmount);
    }

    function withdrawCreatorDeposit(uint256 campaignId)
        external
        campaignExists(campaignId)
        nonReentrant
    {
        Campaign storage c = campaigns[campaignId];
        if (msg.sender != c.creator) revert NotCampaignCreator();
        if (c.depositWithdrawn) revert DepositAlreadyWithdrawn();
        if (c.state != CampaignState.Closed) revert CampaignNotClosed();

        c.depositWithdrawn = true;

        if (c.creatorDeposit > 0) {
            IERC20(c.baseCurrency).safeTransfer(c.creator, c.creatorDeposit);
        }

        emit CreatorDepositWithdrawn(campaignId, msg.sender, c.creatorDeposit);
    }

    function withdrawRaisedFunds(uint256 campaignId)
        external
        campaignExists(campaignId)
        nonReentrant
    {
        Campaign storage c = campaigns[campaignId];
        if (msg.sender != c.creator) revert NotCampaignCreator();
        if (c.state != CampaignState.Closed) revert CampaignNotClosed();
        if (c.fundsWithdrawn) revert FundsAlreadyWithdrawn();

        bool success = c.totalRaised >= c.softCap;
        if (!success) revert TargetNotReached();

        c.fundsWithdrawn = true;

        uint256 amount = c.totalRaised - c.feeCollected;
        if (amount > 0) {
            IERC20(c.baseCurrency).safeTransfer(c.creator, amount);
        }

        emit CreatorFundsWithdrawn(campaignId, msg.sender, amount);
    }

    function getCampaign(uint256 campaignId) external view returns (Campaign memory) {
        return campaigns[campaignId];
    }

    function getContribution(uint256 campaignId, address account)
        external
        view
        returns (uint256 amount, bool claimed)
    {
        Contributor storage c = contributions[campaignId][account];
        return (c.amount, c.claimed);
    }

    function isOperator(address account) external view returns (bool) {
        return operators[account];
    }

    function pendingTokenClaim(uint256 campaignId, address account)
        external
        view
        returns (uint256 tokenAmount, uint256 refundAmount)
    {
        Campaign storage c = campaigns[campaignId];
        if (c.state != CampaignState.Closed) return (0, 0);

        Contributor storage con = contributions[campaignId][account];
        if (con.claimed || con.amount == 0) return (0, 0);

        bool success = c.totalRaised >= c.softCap;
        if (success) {
            tokenAmount = (con.amount * c.tokenPerBase) / 1e18;
            refundAmount = 0;
        } else {
            tokenAmount = 0;
            refundAmount = con.amount;
        }
    }
}
