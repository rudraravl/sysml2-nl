// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool ok = token.transfer(to, amount);
        if (!ok) revert SafeERC20FailedTransfer();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool ok = token.transferFrom(from, to, amount);
        if (!ok) revert SafeERC20FailedTransferFrom();
    }

    error SafeERC20FailedTransfer();
    error SafeERC20FailedTransferFrom();
}

contract TokenLaunchpad {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error ReentrantCall();
    error LaunchDoesNotExist();
    error LaunchNotFinalized();
    error LaunchAlreadyFinalized();
    error LaunchWindowNotOpen();
    error LaunchWindowNotEnded();
    error DepositBelowMinimum();
    error NothingToWithdraw();
    error NothingToClaim();
    error AlreadyFullyClaimed();
    error ZeroAmount();
    error NoCollateralRaised();
    error OperatorAlreadyWithdrawn();
    error InvalidTimeWindow();

    // -------------------------------------------------------------
    // Events
    // -------------------------------------------------------------
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeeRecipientUpdated(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event LaunchStarted(uint256 indexed launchId, address indexed newToken, uint256 collateralRequirement, uint256 startTime, uint256 endTime);
    event CollateralRequirementUpdated(uint256 indexed launchId, uint256 collateralRequirement);
    event DistributionFinalized(uint256 indexed launchId, address indexed newToken, uint256 totalCollateralPooled, uint256 totalTokensDistributed);
    event CollateralDeposited(uint256 indexed launchId, address indexed user, uint256 amount);
    event CollateralWithdrawn(uint256 indexed launchId, address indexed user, uint256 amount);
    event TokensClaimed(uint256 indexed launchId, address indexed user, uint256 grossAmount, uint256 feeAmount, uint256 netAmount);
    event RaisedCollateralWithdrawn(uint256 indexed launchId, address indexed operator, uint256 amount);

    // -------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // -------------------------------------------------------------
    // State
    // -------------------------------------------------------------
    IERC20 public immutable collateralToken;
    address public owner;
    address public operator;
    address public feeRecipient;

    struct Launch {
        address newToken;
        uint256 collateralRequirement;
        uint256 startTime;
        uint256 endTime;
        bool finalized;
        bool operatorWithdrawn;
        uint256 totalCollateralPooled;
        uint256 totalTokensDistributed;
    }

    mapping(uint256 => Launch) private _launches;
    mapping(uint256 => mapping(address => uint256)) private _deposits;
    mapping(uint256 => mapping(address => uint256)) private _claimedTokens;
    mapping(uint256 => mapping(address => uint256)) private _unallocatedWithdrawn;
    uint256 public nextLaunchId;

    uint256 private _reentrancyStatus;

    // -------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == 2) revert ReentrantCall();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    // -------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------
    constructor(address _collateralToken, address _operator, address _feeRecipient) {
        if (_collateralToken == address(0) || _operator == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        collateralToken = IERC20(_collateralToken);
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        _reentrancyStatus = 1;
        emit OwnershipTransferred(address(0), msg.sender);
        emit OperatorUpdated(address(0), _operator);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    // -------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, _operator);
        operator = _operator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    // -------------------------------------------------------------
    // Operator: Launch management
    // -------------------------------------------------------------
    function startLaunch(
        address newToken,
        uint256 collateralRequirement,
        uint256 startTime,
        uint256 endTime
    ) external onlyOperator returns (uint256 launchId) {
        if (newToken == address(0)) revert ZeroAddress();
        if (collateralRequirement == 0) revert ZeroAmount();
        if (startTime < block.timestamp) revert InvalidTimeWindow();
        if (endTime <= startTime) revert InvalidTimeWindow();

        launchId = nextLaunchId++;
        Launch storage l = _launches[launchId];
        l.newToken = newToken;
        l.collateralRequirement = collateralRequirement;
        l.startTime = startTime;
        l.endTime = endTime;

        emit LaunchStarted(launchId, newToken, collateralRequirement, startTime, endTime);
    }

    function setCollateralRequirement(uint256 launchId, uint256 collateralRequirement) external onlyOperator {
        Launch storage l = _launches[launchId];
        if (l.newToken == address(0)) revert LaunchDoesNotExist();
        if (l.finalized) revert LaunchAlreadyFinalized();
        if (collateralRequirement == 0) revert ZeroAmount();
        l.collateralRequirement = collateralRequirement;
        emit CollateralRequirementUpdated(launchId, collateralRequirement);
    }

    function finalizeLaunch(uint256 launchId, uint256 totalTokensToDistribute) external onlyOperator nonReentrant {
        Launch storage l = _launches[launchId];
        if (l.newToken == address(0)) revert LaunchDoesNotExist();
        if (l.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp <= l.endTime) revert LaunchWindowNotEnded();
        if (l.totalCollateralPooled == 0) revert NoCollateralRaised();
        if (totalTokensToDistribute == 0) revert ZeroAmount();

        l.finalized = true;
        l.totalTokensDistributed = totalTokensToDistribute;

        IERC20(l.newToken).safeTransferFrom(msg.sender, address(this), totalTokensToDistribute);

        emit DistributionFinalized(launchId, l.newToken, l.totalCollateralPooled, totalTokensToDistribute);
    }

    function withdrawRaisedCollateral(uint256 launchId) external onlyOperator nonReentrant {
        Launch storage l = _launches[launchId];
        if (!l.finalized) revert LaunchNotFinalized();
        if (l.operatorWithdrawn) revert OperatorAlreadyWithdrawn();

        uint256 totalPooled = l.totalCollateralPooled;
        uint256 requirement = l.collateralRequirement;
        uint256 usedTotal = totalPooled > requirement ? requirement : totalPooled;
        if (usedTotal == 0) revert NothingToWithdraw();

        l.operatorWithdrawn = true;
        collateralToken.safeTransfer(operator, usedTotal);
        emit RaisedCollateralWithdrawn(launchId, operator, usedTotal);
    }

    // -------------------------------------------------------------
    // User: Deposit collateral
    // -------------------------------------------------------------
    function depositCollateral(uint256 launchId, uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert DepositBelowMinimum();
        Launch storage l = _launches[launchId];
        if (l.newToken == address(0)) revert LaunchDoesNotExist();
        if (l.finalized) revert LaunchAlreadyFinalized();
        if (block.timestamp < l.startTime || block.timestamp > l.endTime) revert LaunchWindowNotOpen();

        _deposits[launchId][msg.sender] += amount;
        l.totalCollateralPooled += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(launchId, msg.sender, amount);
    }

    // -------------------------------------------------------------
    // User: Withdraw collateral
    // -------------------------------------------------------------
    function withdrawCollateral(uint256 launchId) external nonReentrant {
        Launch storage l = _launches[launchId];
        if (l.newToken == address(0)) revert LaunchDoesNotExist();

        uint256 userDeposit = _deposits[launchId][msg.sender];
        if (userDeposit == 0) revert NothingToWithdraw();

        if (!l.finalized) {
            _deposits[launchId][msg.sender] = 0;
            l.totalCollateralPooled -= userDeposit;
            collateralToken.safeTransfer(msg.sender, userDeposit);
            emit CollateralWithdrawn(launchId, msg.sender, userDeposit);
        } else {
            uint256 totalPooled = l.totalCollateralPooled;
            if (totalPooled == 0) revert NothingToWithdraw();
            uint256 requirement = l.collateralRequirement;
            uint256 usedTotal = totalPooled > requirement ? requirement : totalPooled;
            uint256 excessTotal = totalPooled - usedTotal;
            uint256 userUnallocated = (userDeposit * excessTotal) / totalPooled;
            uint256 alreadyWithdrawn = _unallocatedWithdrawn[launchId][msg.sender];
            if (userUnallocated <= alreadyWithdrawn) revert NothingToWithdraw();

            uint256 withdrawable = userUnallocated - alreadyWithdrawn;
            _unallocatedWithdrawn[launchId][msg.sender] = userUnallocated;
            collateralToken.safeTransfer(msg.sender, withdrawable);
            emit CollateralWithdrawn(launchId, msg.sender, withdrawable);
        }
    }

    // -------------------------------------------------------------
    // User: Claim allocated new tokens (2% fee deducted)
    // -------------------------------------------------------------
    function claimTokens(uint256 launchId) external nonReentrant {
        Launch storage l = _launches[launchId];
        if (!l.finalized) revert LaunchNotFinalized();

        uint256 userDeposit = _deposits[launchId][msg.sender];
        if (userDeposit == 0) revert NothingToClaim();

        uint256 totalPooled = l.totalCollateralPooled;
        uint256 totalTokens = l.totalTokensDistributed;
        if (totalPooled == 0 || totalTokens == 0) revert NothingToClaim();

        uint256 grossAllocation = (userDeposit * totalTokens) / totalPooled;
        if (grossAllocation == 0) revert NothingToClaim();

        uint256 alreadyClaimed = _claimedTokens[launchId][msg.sender];
        if (grossAllocation <= alreadyClaimed) revert AlreadyFullyClaimed();

        uint256 pending = grossAllocation - alreadyClaimed;
        uint256 fee = (pending * FEE_BPS) / BPS_DENOMINATOR;
        uint256 net = pending - fee;

        _claimedTokens[launchId][msg.sender] = grossAllocation;

        if (fee > 0) {
            IERC20(l.newToken).safeTransfer(feeRecipient, fee);
        }
        if (net > 0) {
            IERC20(l.newToken).safeTransfer(msg.sender, net);
        }

        emit TokensClaimed(launchId, msg.sender, grossAllocation, fee, net);
    }

    // -------------------------------------------------------------
    // Views
    // -------------------------------------------------------------
    function pendingTokens(uint256 launchId, address user) external view returns (uint256 gross, uint256 fee, uint256 net) {
        Launch storage l = _launches[launchId];
        if (l.totalCollateralPooled == 0 || l.totalTokensDistributed == 0) return (0, 0, 0);
        uint256 userDeposit = _deposits[launchId][user];
        if (userDeposit == 0) return (0, 0, 0);
        gross = (userDeposit * l.totalTokensDistributed) / l.totalCollateralPooled;
        uint256 alreadyClaimed = _claimedTokens[launchId][user];
        uint256 pendingGross = gross > alreadyClaimed ? gross - alreadyClaimed : 0;
        fee = (pendingGross * FEE_BPS) / BPS_DENOMINATOR;
        net = pendingGross - fee;
    }

    function getLaunch(uint256 launchId) external view returns (
        address newToken,
        uint256 collateralRequirement,
        uint256 startTime,
        uint256 endTime,
        bool finalized,
        bool operatorWithdrawn,
        uint256 totalCollateralPooled,
        uint256 totalTokensDistributed
    ) {
        Launch storage l = _launches[launchId];
        return (
            l.newToken,
            l.collateralRequirement,
            l.startTime,
            l.endTime,
            l.finalized,
            l.operatorWithdrawn,
            l.totalCollateralPooled,
            l.totalTokensDistributed
        );
    }

    function getUserData(uint256 launchId, address user) external view returns (
        uint256 collateralDeposited,
        uint256 claimedTokens,
        uint256 unallocatedWithdrawn
    ) {
        return (
            _deposits[launchId][user],
            _claimedTokens[launchId][user],
            _unallocatedWithdrawn[launchId][user]
        );
    }

    function getUnallocatedWithdrawable(uint256 launchId, address user) external view returns (uint256) {
        Launch storage l = _launches[launchId];
        if (!l.finalized) return 0;
        uint256 totalPooled = l.totalCollateralPooled;
        if (totalPooled == 0) return 0;
        uint256 requirement = l.collateralRequirement;
        uint256 usedTotal = totalPooled > requirement ? requirement : totalPooled;
        uint256 excessTotal = totalPooled - usedTotal;
        uint256 userUnallocated = (_deposits[launchId][user] * excessTotal) / totalPooled;
        uint256 alreadyWithdrawn = _unallocatedWithdrawn[launchId][user];
        return userUnallocated > alreadyWithdrawn ? userUnallocated - alreadyWithdrawn : 0;
    }
}
