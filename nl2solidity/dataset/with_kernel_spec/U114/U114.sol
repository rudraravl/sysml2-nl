// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

library SafeToken {
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeToken: transfer failed"
        );
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeToken: transferFrom failed"
        );
    }
}

contract TokenLaunchpad {
    using SafeToken for address;

    enum LaunchStatus { Pending, Launched, Cancelled }

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroAllocation();
    error LaunchNotPending();
    error LaunchNotActive();
    error LaunchNotCancelled();
    error ClaimPeriodNotStarted();
    error AlreadyClaimed();
    error AlreadyDeposited();
    error DepositExceedsMax();
    error NoDeposit();
    error NothingToClaim();
    error ProjectTokenNotSet();

    event Deposited(address indexed participant, uint256 amount);
    event ProjectTokensClaimed(address indexed participant, uint256 amount);
    event LaunchStatusChanged(LaunchStatus indexed status);
    event ProjectTokenSet(address indexed projectToken, uint256 totalAllocation);
    event DepositWithdrawn(address indexed participant, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public owner;
    address public immutable depositToken;
    address public projectToken;
    uint256 public totalProjectAllocation;
    uint256 public totalDeposited;
    uint256 public launchTime;
    uint256 public claimStartsAt;

    LaunchStatus public launchStatus;

    uint256 public constant MAX_INDIVIDUAL_DEPOSIT = 1000 ether;
    uint256 public constant CLAIM_DELAY = 24 hours;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public hasClaimed;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyPending() {
        if (launchStatus != LaunchStatus.Pending) revert LaunchNotPending();
        _;
    }

    constructor(address _depositToken) {
        if (_depositToken == address(0)) revert ZeroAddress();
        depositToken = _depositToken;
        owner = msg.sender;
        launchStatus = LaunchStatus.Pending;
        emit OwnershipTransferred(address(0), msg.sender);
        emit LaunchStatusChanged(LaunchStatus.Pending);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function setProjectToken(address _projectToken, uint256 _totalAllocation) external onlyOwner onlyPending {
        if (_projectToken == address(0)) revert ZeroAddress();
        if (_totalAllocation == 0) revert ZeroAllocation();
        projectToken = _projectToken;
        totalProjectAllocation = _totalAllocation;
        emit ProjectTokenSet(_projectToken, _totalAllocation);
    }

    function initiateLaunch() external onlyOwner onlyPending {
        if (projectToken == address(0)) revert ProjectTokenNotSet();
        if (totalProjectAllocation == 0) revert ZeroAllocation();
        if (totalDeposited == 0) revert NoDeposit();
        launchStatus = LaunchStatus.Launched;
        launchTime = block.timestamp;
        claimStartsAt = block.timestamp + CLAIM_DELAY;
        emit LaunchStatusChanged(LaunchStatus.Launched);
    }

    function cancelLaunch() external onlyOwner onlyPending {
        launchStatus = LaunchStatus.Cancelled;
        emit LaunchStatusChanged(LaunchStatus.Cancelled);
    }

    function deposit(uint256 amount) external onlyPending {
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_INDIVIDUAL_DEPOSIT) revert DepositExceedsMax();
        if (deposits[msg.sender] > 0) revert AlreadyDeposited();

        deposits[msg.sender] = amount;
        totalDeposited += amount;

        SafeToken.safeTransferFrom(depositToken, msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    function claimProjectTokens() external {
        if (launchStatus != LaunchStatus.Launched) revert LaunchNotActive();
        if (block.timestamp < claimStartsAt) revert ClaimPeriodNotStarted();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        uint256 userDeposit = deposits[msg.sender];
        if (userDeposit == 0) revert NoDeposit();
        if (totalDeposited == 0) revert NothingToClaim();

        uint256 allocation = (userDeposit * totalProjectAllocation) / totalDeposited;
        if (allocation == 0) revert NothingToClaim();

        hasClaimed[msg.sender] = true;

        SafeToken.safeTransfer(projectToken, msg.sender, allocation);

        emit ProjectTokensClaimed(msg.sender, allocation);
    }

    function withdrawDeposit() external {
        if (launchStatus != LaunchStatus.Cancelled) revert LaunchNotCancelled();

        uint256 amount = deposits[msg.sender];
        if (amount == 0) revert NoDeposit();

        deposits[msg.sender] = 0;
        totalDeposited -= amount;

        SafeToken.safeTransfer(depositToken, msg.sender, amount);

        emit DepositWithdrawn(msg.sender, amount);
    }

    function claimableAllocation(address participant) external view returns (uint256) {
        if (launchStatus != LaunchStatus.Launched) return 0;
        if (block.timestamp < claimStartsAt) return 0;
        if (hasClaimed[participant]) return 0;
        if (totalDeposited == 0) return 0;
        return (deposits[participant] * totalProjectAllocation) / totalDeposited;
    }

    function claimStarted() external view returns (bool) {
        return launchStatus == LaunchStatus.Launched && block.timestamp >= claimStartsAt;
    }

    function projectTokenBalance() external view returns (uint256) {
        if (projectToken == address(0)) return 0;
        return IERC20(projectToken).balanceOf(address(this));
    }

    function depositTokenBalance() external view returns (uint256) {
        return IERC20(depositToken).balanceOf(address(this));
    }
}
