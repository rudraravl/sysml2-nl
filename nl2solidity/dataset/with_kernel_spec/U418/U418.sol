// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract TokenLaunchpad {
    // ============ Custom Errors ============
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error LaunchNotFound();
    error LaunchNotActive();
    error LaunchEnded();
    error LaunchNotEnded();
    error LaunchNotFinalized();
    error LaunchNotCancelled();
    error LaunchAlreadyFinalized();
    error LaunchAlreadyCancelled();
    error InvalidTokenAddresses();
    error InvalidContributionPeriod();
    error InvalidTargetRaise();
    error InsufficientOffering();
    error NoContribution();
    error AlreadyClaimed();
    error NothingToWithdraw();
    error TransferFailed();
    error ProjectTokensNotDeposited();

    // ============ Constants ============
    uint24 public constant MIN_PERIOD = 24 hours;
    uint24 public constant MAX_PERIOD = 7 days;
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ============ Enums ============
    enum LaunchStatus {
        Pending,
        Active,
        Finalized,
        Cancelled
    }

    // ============ Structs ============
    struct Launch {
        address projectToken;
        address baseToken;
        uint256 totalOffering;
        uint256 targetRaise;
        uint64 startTime;
        uint64 endTime;
        uint256 totalRaised;
        uint256 totalClaimed;
        LaunchStatus status;
    }

    // ============ State Variables ============
    address public owner;
    address public operator;
    address public treasury;

    uint256 public launchCounter;
    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => uint256)) public allocations;
    mapping(uint256 => mapping(address => bool)) public claimed;

    // ============ Events ============
    event LaunchCreated(
        uint256 indexed launchId,
        address indexed projectToken,
        address indexed baseToken,
        uint256 totalOffering,
        uint256 targetRaise,
        uint64 startTime,
        uint64 endTime
    );
    event Contributed(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event TokensClaimed(uint256 indexed launchId, address indexed claimer, uint256 amount);
    event BaseTokensWithdrawn(uint256 indexed launchId, address indexed withdrawer, uint256 amount);
    event LaunchFinalized(uint256 indexed launchId, uint256 totalRaised, uint256 feeCollected);
    event LaunchCancelled(uint256 indexed launchId);
    event ContributionPeriodUpdated(uint256 indexed launchId, uint64 newStartTime, uint64 newEndTime);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TreasuryChanged(address indexed previousTreasury, address indexed newTreasury);

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier launchExists(uint256 launchId) {
        if (launches[launchId].projectToken == address(0)) revert LaunchNotFound();
        _;
    }

    // ============ Constructor ============
    constructor(address _treasury) {
        if (_treasury == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = msg.sender;
        treasury = _treasury;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorChanged(address(0), msg.sender);
        emit TreasuryChanged(address(0), _treasury);
    }

    // ============ Admin Functions ============
    function setOwner(address _owner) external onlyOwner {
        if (_owner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _owner);
        owner = _owner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorChanged(operator, _operator);
        operator = _operator;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        emit TreasuryChanged(treasury, _treasury);
        treasury = _treasury;
    }

    // ============ Launch Management ============
    function createLaunch(
        address _projectToken,
        address _baseToken,
        uint256 _totalOffering,
        uint256 _targetRaise,
        uint64 _startTime,
        uint64 _endTime
    ) external onlyOwner returns (uint256 launchId) {
        if (_projectToken == address(0) || _baseToken == address(0)) revert InvalidTokenAddresses();
        if (_projectToken == _baseToken) revert InvalidTokenAddresses();
        if (_totalOffering == 0) revert ZeroAmount();
        if (_targetRaise == 0) revert InvalidTargetRaise();
        if (_endTime <= _startTime) revert InvalidContributionPeriod();
        if (_endTime - _startTime < MIN_PERIOD || _endTime - _startTime > MAX_PERIOD) {
            revert InvalidContributionPeriod();
        }

        // Custody project tokens from the owner
        uint256 balBefore = IERC20(_projectToken).balanceOf(address(this));
        bool ok = IERC20(_projectToken).transferFrom(msg.sender, address(this), _totalOffering);
        if (!ok) revert TransferFailed();
        if (IERC20(_projectToken).balanceOf(address(this)) - balBefore != _totalOffering) {
            revert ProjectTokensNotDeposited();
        }

        launchId = ++launchCounter;
        launches[launchId] = Launch({
            projectToken: _projectToken,
            baseToken: _baseToken,
            totalOffering: _totalOffering,
            targetRaise: _targetRaise,
            startTime: _startTime,
            endTime: _endTime,
            totalRaised: 0,
            totalClaimed: 0,
            status: LaunchStatus.Pending
        });

        emit LaunchCreated(launchId, _projectToken, _baseToken, _totalOffering, _targetRaise, _startTime, _endTime);
    }

    function updateContributionPeriod(
        uint256 launchId,
        uint64 _startTime,
        uint64 _endTime
    ) external onlyOperator launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.status == LaunchStatus.Finalized || launch.status == LaunchStatus.Cancelled) {
            revert LaunchEnded();
        }
        if (_endTime <= _startTime) revert InvalidContributionPeriod();
        if (_endTime - _startTime < MIN_PERIOD || _endTime - _startTime > MAX_PERIOD) {
            revert InvalidContributionPeriod();
        }

        launch.startTime = _startTime;
        launch.endTime = _endTime;

        emit ContributionPeriodUpdated(launchId, _startTime, _endTime);
    }

    function finalizeLaunch(uint256 launchId) external onlyOwner launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.status == LaunchStatus.Finalized) revert LaunchAlreadyFinalized();
        if (launch.status == LaunchStatus.Cancelled) revert LaunchAlreadyCancelled();
        if (block.timestamp < launch.endTime) revert LaunchNotEnded();
        if (launch.totalRaised < launch.targetRaise) revert InsufficientOffering();

        launch.status = LaunchStatus.Finalized;

        // Compute proportional allocations for all contributors based on total raised
        // allocation = (contribution * totalOffering) / totalRaised
        // This is tracked per-contributor at claim time to avoid iteration.

        // Transfer fee to treasury and net amount to owner
        uint256 fee = (launch.totalRaised * FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = launch.totalRaised - fee;

        if (fee > 0) {
            bool okFee = IERC20(launch.baseToken).transfer(treasury, fee);
            if (!okFee) revert TransferFailed();
        }
        if (netAmount > 0) {
            bool okNet = IERC20(launch.baseToken).transfer(owner, netAmount);
            if (!okNet) revert TransferFailed();
        }

        emit LaunchFinalized(launchId, launch.totalRaised, fee);
    }

    function cancelLaunch(uint256 launchId) external onlyOwner launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.status == LaunchStatus.Finalized) revert LaunchAlreadyFinalized();
        if (launch.status == LaunchStatus.Cancelled) revert LaunchAlreadyCancelled();

        launch.status = LaunchStatus.Cancelled;

        emit LaunchCancelled(launchId);
    }

    // ============ Participant Functions ============
    function contribute(uint256 launchId, uint256 amount) external launchExists(launchId) {
        if (amount == 0) revert ZeroAmount();
        Launch storage launch = launches[launchId];

        if (block.timestamp < launch.startTime) revert LaunchNotActive();
        if (block.timestamp >= launch.endTime) revert LaunchEnded();
        if (launch.status != LaunchStatus.Pending && launch.status != LaunchStatus.Active) {
            revert LaunchEnded();
        }

        if (launch.status == LaunchStatus.Pending) {
            launch.status = LaunchStatus.Active;
        }

        // Transfer base tokens from contributor with balance check
        IERC20 baseToken = IERC20(launch.baseToken);
        uint256 balBefore = baseToken.balanceOf(address(this));
        bool ok = baseToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        uint256 received = baseToken.balanceOf(address(this)) - balBefore;
        if (received == 0) revert ZeroAmount();

        contributions[launchId][msg.sender] += received;
        launch.totalRaised += received;

        emit Contributed(launchId, msg.sender, received);
    }

    function claimTokens(uint256 launchId) external launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.status != LaunchStatus.Finalized) revert LaunchNotFinalized();
        if (claimed[launchId][msg.sender]) revert AlreadyClaimed();

        uint256 contributed = contributions[launchId][msg.sender];
        if (contributed == 0) revert NoContribution();

        // Proportional allocation: (contribution * totalOffering) / totalRaised
        uint256 allocation = (contributed * launch.totalOffering) / launch.totalRaised;
        if (allocation == 0) revert NoContribution();

        claimed[launchId][msg.sender] = true;
        allocations[launchId][msg.sender] = allocation;
        launch.totalClaimed += allocation;

        IERC20 projectToken = IERC20(launch.projectToken);
        bool ok = projectToken.transfer(msg.sender, allocation);
        if (!ok) revert TransferFailed();

        emit TokensClaimed(launchId, msg.sender, allocation);
    }

    function withdrawBaseTokens(uint256 launchId) external launchExists(launchId) {
        Launch storage launch = launches[launchId];
        if (launch.status != LaunchStatus.Cancelled) revert LaunchNotCancelled();

        uint256 contributed = contributions[launchId][msg.sender];
        if (contributed == 0) revert NothingToWithdraw();

        contributions[launchId][msg.sender] = 0;

        IERC20 baseToken = IERC20(launch.baseToken);
        bool ok = baseToken.transfer(msg.sender, contributed);
        if (!ok) revert TransferFailed();

        emit BaseTokensWithdrawn(launchId, msg.sender, contributed);
    }

    // ============ View Functions ============
    function getLaunch(uint256 launchId) external view launchExists(launchId) returns (Launch memory) {
        return launches[launchId];
    }

    function getContribution(uint256 launchId, address account) external view returns (uint256) {
        return contributions[launchId][account];
    }

    function getAllocation(uint256 launchId, address account) external view returns (uint256) {
        return allocations[launchId][account];
    }

    function hasClaimed(uint256 launchId, address account) external view returns (bool) {
        return claimed[launchId][account];
    }

    function previewAllocation(uint256 launchId, uint256 baseAmount) external view returns (uint256) {
        Launch storage launch = launches[launchId];
        if (launch.totalRaised == 0) {
            if (launch.targetRaise == 0) return 0;
            return (baseAmount * launch.totalOffering) / launch.targetRaise;
        }
        return (baseAmount * launch.totalOffering) / launch.totalRaised;
    }
}
