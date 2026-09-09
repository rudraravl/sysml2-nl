// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) {
            revert("SafeERC20: transfer failed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) {
            revert("SafeERC20: transferFrom failed");
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
        if (_status == _ENTERED) {
            revert("ReentrancyGuard: reentrant call");
        }
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/// @title TokenLaunch
/// @notice Manages token launches: participants deposit tokens during a funding
/// phase and receive project tokens during a distribution phase based on their
/// proportional share of deposits. A 2% fee on deposits is forwarded to a treasury.
/// After the launch concludes, unspent deposits may be withdrawn back by their owners.
contract TokenLaunch is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Lifecycle stages of a launch.
    enum Phase {
        Inactive,
        Funding,
        Distribution,
        Concluded
    }

    /// @dev All parameters describing a single launch.
    struct LaunchInfo {
        IERC20 depositToken;
        IERC20 projectToken;
        uint256 totalProjectTokens;
        uint256 fundingStartTime;
        uint256 fundingEndTime;
        uint256 totalDeposited;
        uint256 totalAllocated;
        uint256 totalClaimed;
        bool projectTokenSet;
        Phase phase;
    }

    uint256 public constant FEE_PERCENT = 2;
    uint256 public constant HUNDRED_PERCENT = 100;
    uint256 public constant MIN_FUNDING_DURATION = 1 days;
    uint256 public constant MAX_FUNDING_DURATION = 7 days;

    address public operator;
    address public treasury;
    uint256 public fundingDuration;

    uint256 public currentLaunchId;
    mapping(uint256 => LaunchInfo) public launches;
    mapping(uint256 => address[]) internal _participants;
    mapping(uint256 => mapping(address => bool)) public isParticipant;
    mapping(uint256 => mapping(address => uint256)) public deposits;
    mapping(uint256 => mapping(address => uint256)) public allocations;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    event LaunchStarted(uint256 indexed launchId, address indexed depositToken, uint256 startTime, uint256 endTime);
    event FundingPhaseEnded(uint256 indexed launchId, uint256 endTime);
    event DistributionPhaseStarted(uint256 indexed launchId, uint256 totalAllocated);
    event LaunchConcluded(uint256 indexed launchId);
    event Deposited(uint256 indexed launchId, address indexed participant, uint256 amount, uint256 fee);
    event Claimed(uint256 indexed launchId, address indexed participant, uint256 amount);
    event Withdrawn(uint256 indexed launchId, address indexed participant, uint256 amount);
    event ProjectTokenSet(uint256 indexed launchId, address projectToken, uint256 totalSupply);
    event FundingDurationSet(uint256 duration);
    event TreasurySet(address treasury);
    event OperatorSet(address operator);
    event UnclaimedRecovered(uint256 indexed launchId, uint256 recoveredProjectTokens);

    error NotOperator();
    error InvalidPhase();
    error InvalidDuration();
    error ZeroAddress();
    error AlreadySet();
    error NothingToClaim();
    error NothingToWithdraw();
    error AlreadyClaimed();
    error FundingNotEnded();
    error ProjectTokenNotSet();
    error AmountZero();
    error LaunchNotFound();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(address _operator, address _treasury, uint256 _fundingDuration) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_fundingDuration < MIN_FUNDING_DURATION || _fundingDuration > MAX_FUNDING_DURATION) {
            revert InvalidDuration();
        }
        operator = _operator;
        treasury = _treasury;
        fundingDuration = _fundingDuration;
        emit OperatorSet(_operator);
        emit TreasurySet(_treasury);
        emit FundingDurationSet(_fundingDuration);
    }

    /// @notice Updates the treasury address that receives the 2% deposit fee.
    function setTreasury(address _treasury) external onlyOperator {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    /// @notice Sets the duration of subsequent funding phases. Must be within [1 day, 7 days].
    function setFundingDuration(uint256 _fundingDuration) external onlyOperator {
        if (_fundingDuration < MIN_FUNDING_DURATION || _fundingDuration > MAX_FUNDING_DURATION) {
            revert InvalidDuration();
        }
        fundingDuration = _fundingDuration;
        emit FundingDurationSet(_fundingDuration);
    }

    /// @notice Initiates a new launch in the Funding phase for the given deposit token.
    function initiateLaunch(IERC20 depositToken) external onlyOperator returns (uint256 launchId) {
        if (address(depositToken) == address(0)) revert ZeroAddress();
        launchId = ++currentLaunchId;
        LaunchInfo storage launch = launches[launchId];
        launch.depositToken = depositToken;
        launch.fundingStartTime = block.timestamp;
        launch.fundingEndTime = block.timestamp + fundingDuration;
        launch.phase = Phase.Funding;
        emit LaunchStarted(launchId, address(depositToken), launch.fundingStartTime, launch.fundingEndTime);
    }

    /// @notice Sets the project token and total supply for a launch. Must be set before distribution.
    function setProjectToken(uint256 launchId, IERC20 projectToken, uint256 totalSupply) external onlyOperator {
        if (launchId == 0 || launchId > currentLaunchId) revert LaunchNotFound();
        LaunchInfo storage launch = launches[launchId];
        if (launch.phase != Phase.Funding) revert InvalidPhase();
        if (launch.projectTokenSet) revert AlreadySet();
        if (address(projectToken) == address(0)) revert ZeroAddress();
        if (totalSupply == 0) revert AmountZero();
        launch.projectToken = projectToken;
        launch.totalProjectTokens = totalSupply;
        launch.projectTokenSet = true;
        emit ProjectTokenSet(launchId, address(projectToken), totalSupply);
    }

    /// @notice Advances the launch phase: Funding -> Distribution, or Distribution -> Concluded.
    function advancePhase(uint256 launchId) external onlyOperator nonReentrant {
        if (launchId == 0 || launchId > currentLaunchId) revert LaunchNotFound();
        LaunchInfo storage launch = launches[launchId];
        if (launch.phase == Phase.Funding) {
            if (block.timestamp < launch.fundingEndTime) revert FundingNotEnded();
            if (!launch.projectTokenSet) revert ProjectTokenNotSet();

            // Pull project tokens from the operator into the contract for distribution.
            IERC20(launch.projectToken).safeTransferFrom(msg.sender, address(this), launch.totalProjectTokens);

            // Calculate and store each participant's allocation proportionally.
            address[] storage parts = _participants[launchId];
            uint256 totalAlloc = 0;
            if (launch.totalDeposited > 0) {
                uint256 partsLen = parts.length;
                for (uint256 i = 0; i < partsLen; ) {
                    address p = parts[i];
                    uint256 alloc = (deposits[launchId][p] * launch.totalProjectTokens) / launch.totalDeposited;
                    allocations[launchId][p] = alloc;
                    totalAlloc += alloc;
                    unchecked {
                        ++i;
                    }
                }
                launch.totalAllocated = totalAlloc;
            }

            launch.phase = Phase.Distribution;
            emit FundingPhaseEnded(launchId, launch.fundingEndTime);
            emit DistributionPhaseStarted(launchId, totalAlloc);
        } else if (launch.phase == Phase.Distribution) {
            launch.phase = Phase.Concluded;
            emit LaunchConcluded(launchId);
        } else {
            revert InvalidPhase();
        }
    }

    /// @notice Deposits tokens during the funding phase. A 2% fee is forwarded to the treasury.
    function deposit(uint256 launchId, uint256 amount) external nonReentrant {
        if (launchId == 0 || launchId > currentLaunchId) revert LaunchNotFound();
        LaunchInfo storage launch = launches[launchId];
        if (launch.phase != Phase.Funding) revert InvalidPhase();
        if (amount == 0) revert AmountZero();

        uint256 fee = (amount * FEE_PERCENT) / HUNDRED_PERCENT;
        uint256 netAmount = amount - fee;

        IERC20(launch.depositToken).safeTransferFrom(msg.sender, address(this), amount);
        if (fee > 0) {
            IERC20(launch.depositToken).safeTransfer(treasury, fee);
        }

        if (!isParticipant[launchId][msg.sender]) {
            isParticipant[launchId][msg.sender] = true;
            _participants[launchId].push(msg.sender);
        }

        deposits[launchId][msg.sender] += netAmount;
        launch.totalDeposited += netAmount;

        emit Deposited(launchId, msg.sender, netAmount, fee);
    }

    /// @notice Claims the caller's allocated project tokens during the distribution phase.
    function claim(uint256 launchId) external nonReentrant {
        if (launchId == 0 || launchId > currentLaunchId) revert LaunchNotFound();
        LaunchInfo storage launch = launches[launchId];
        if (launch.phase != Phase.Distribution) revert InvalidPhase();
        if (hasClaimed[launchId][msg.sender]) revert AlreadyClaimed();
        uint256 allocation = allocations[launchId][msg.sender];
        if (allocation == 0) revert NothingToClaim();

        hasClaimed[launchId][msg.sender] = true;
        launch.totalClaimed += allocation;
        IERC20(launch.projectToken).safeTransfer(msg.sender, allocation);

        emit Claimed(launchId, msg.sender, allocation);
    }

    /// @notice Withdraws the caller's unspent deposited tokens after the launch concludes.
    /// A participant who has claimed project tokens is considered "spent" and cannot withdraw.
    function withdraw(uint256 launchId) external nonReentrant {
        if (launchId == 0 || launchId > currentLaunchId) revert LaunchNotFound();
        LaunchInfo storage launch = launches[launchId];
        if (launch.phase != Phase.Concluded) revert InvalidPhase();
        if (hasClaimed[launchId][msg.sender]) revert AlreadyClaimed();
        uint256 deposited = deposits[launchId][msg.sender];
        if (deposited == 0) revert NothingToWithdraw();

        deposits[launchId][msg.sender] = 0;
        IERC20(launch.depositToken).safeTransfer(msg.sender, deposited);

        emit Withdrawn(launchId, msg.sender, deposited);
    }

    /// @notice Allows the operator to recover any project tokens that were never claimed after conclusion.
    function recoverUnclaimedProjectTokens(uint256 launchId) external onlyOperator nonReentrant {
        if (launchId == 0 || launchId > currentLaunchId) revert LaunchNotFound();
        LaunchInfo storage launch = launches[launchId];
        if (launch.phase != Phase.Concluded) revert InvalidPhase();
        uint256 unclaimedProject = launch.totalProjectTokens - launch.totalClaimed;
        if (unclaimedProject == 0) revert NothingToWithdraw();

        launch.totalClaimed = launch.totalProjectTokens;
        IERC20(launch.projectToken).safeTransfer(operator, unclaimedProject);
        emit UnclaimedRecovered(launchId, unclaimedProject);
    }

    /// @notice Returns the deposit amount for a participant in a given launch.
    function getDeposit(uint256 launchId, address participant) external view returns (uint256) {
        return deposits[launchId][participant];
    }

    /// @notice Returns the project token allocation for a participant in a given launch.
    function getAllocation(uint256 launchId, address participant) external view returns (uint256) {
        return allocations[launchId][participant];
    }

    /// @notice Returns the number of unique participants in a given launch.
    function getParticipantsCount(uint256 launchId) external view returns (uint256) {
        return _participants[launchId].length;
    }

    /// @notice Returns the participant address at a given index for a given launch.
    function getParticipant(uint256 launchId, uint256 index) external view returns (address) {
        return _participants[launchId][index];
    }

    /// @notice Returns the full LaunchInfo for a given launch.
    function getLaunchInfo(uint256 launchId)
        external
        view
        returns (
            address depositToken,
            address projectToken,
            uint256 totalProjectTokens,
            uint256 fundingStartTime,
            uint256 fundingEndTime,
            uint256 totalDeposited,
            uint256 totalAllocated,
            uint256 totalClaimed,
            bool projectTokenSet,
            Phase phase
        )
    {
        LaunchInfo storage l = launches[launchId];
        return (
            address(l.depositToken),
            address(l.projectToken),
            l.totalProjectTokens,
            l.fundingStartTime,
            l.fundingEndTime,
            l.totalDeposited,
            l.totalAllocated,
            l.totalClaimed,
            l.projectTokenSet,
            l.phase
        );
    }
}
