// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IMintableToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: new owner is the zero address");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address previous = owner;
        owner = address(0);
        emit OwnershipTransferred(previous, address(0));
    }
}

contract TokenLaunchpad is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_SUCCESS_THRESHOLD = 100 ether;
    uint256 public constant MAX_MAX_COMMITMENT = 500 ether;
    uint256 public constant MIN_DURATION = 1 hours;

    enum Status { Active, Success, Failed }

    struct Launch {
        address token;
        address fundingToken;
        uint256 allocationRatio;
        uint256 maxCommitment;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        uint256 totalTokensMinted;
        Status status;
    }

    uint256 public launchCount;
    mapping(uint256 => Launch) public launches;
    mapping(uint256 => mapping(address => uint256)) public commitments;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(uint256 => mapping(address => bool)) public hasWithdrawn;
    mapping(uint256 => bool) public raisedFundsWithdrawn;

    uint256 private _locked = 1;

    event LaunchInitiated(
        uint256 indexed launchId,
        address indexed token,
        address fundingToken,
        uint256 allocationRatio,
        uint256 maxCommitment,
        uint256 startTime,
        uint256 endTime
    );
    event FundsCommitted(uint256 indexed launchId, address indexed participant, uint256 amount);
    event TokensClaimed(uint256 indexed launchId, address indexed participant, uint256 amount);
    event FundsWithdrawn(uint256 indexed launchId, address indexed participant, uint256 amount);
    event LaunchFinalized(uint256 indexed launchId, bool success, uint256 totalRaised);
    event AllocationRatioUpdated(uint256 indexed launchId, uint256 newRatio);
    event MaxCommitmentUpdated(uint256 indexed launchId, uint256 newMax);
    event RaisedFundsWithdrawn(uint256 indexed launchId, address indexed recipient, uint256 amount);

    error ZeroAddress();
    error LaunchNotFound(uint256 launchId);
    error LaunchNotActive(uint256 launchId);
    error LaunchAlreadyFinalized(uint256 launchId);
    error LaunchNotSuccess(uint256 launchId);
    error LaunchNotFailed(uint256 launchId);
    error LaunchNotEnded(uint256 launchId);
    error CommitmentExceedsMax(uint256 amount, uint256 max);
    error MaxCommitmentExceedsCap(uint256 max);
    error ZeroAmount();
    error AlreadyClaimed(address participant);
    error AlreadyWithdrawn(address participant);
    error NoCommitment(address participant);
    error DurationTooShort();
    error TransferFailed();
    error NothingToWithdraw();
    error ReentrantCall();

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor() Ownable(msg.sender) {}

    function initiateLaunch(
        address token,
        address fundingToken,
        uint256 allocationRatio,
        uint256 maxCommitment,
        uint256 duration
    ) external onlyOwner returns (uint256 launchId) {
        if (token == address(0) || fundingToken == address(0)) revert ZeroAddress();
        if (allocationRatio == 0) revert ZeroAmount();
        if (maxCommitment == 0) revert ZeroAmount();
        if (maxCommitment > MAX_MAX_COMMITMENT) revert MaxCommitmentExceedsCap(maxCommitment);
        if (duration < MIN_DURATION) revert DurationTooShort();

        launchId = launchCount++;
        uint256 startTime = block.timestamp;
        launches[launchId] = Launch({
            token: token,
            fundingToken: fundingToken,
            allocationRatio: allocationRatio,
            maxCommitment: maxCommitment,
            startTime: startTime,
            endTime: startTime + duration,
            totalRaised: 0,
            totalTokensMinted: 0,
            status: Status.Active
        });

        emit LaunchInitiated(launchId, token, fundingToken, allocationRatio, maxCommitment, startTime, startTime + duration);
    }

    function setAllocationRatio(uint256 launchId, uint256 newRatio) external onlyOwner {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound(launchId);
        if (launch.status != Status.Active) revert LaunchNotActive(launchId);
        if (newRatio == 0) revert ZeroAmount();

        launch.allocationRatio = newRatio;
        emit AllocationRatioUpdated(launchId, newRatio);
    }

    function setMaxCommitment(uint256 launchId, uint256 newMax) external onlyOwner {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound(launchId);
        if (launch.status != Status.Active) revert LaunchNotActive(launchId);
        if (newMax == 0) revert ZeroAmount();
        if (newMax > MAX_MAX_COMMITMENT) revert MaxCommitmentExceedsCap(newMax);

        launch.maxCommitment = newMax;
        emit MaxCommitmentUpdated(launchId, newMax);
    }

    function commitFunds(uint256 launchId, uint256 amount) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound(launchId);
        if (launch.status != Status.Active) revert LaunchNotActive(launchId);
        if (block.timestamp >= launch.endTime) revert LaunchNotEnded(launchId);
        if (amount == 0) revert ZeroAmount();

        uint256 currentCommitment = commitments[launchId][msg.sender];
        if (currentCommitment + amount > launch.maxCommitment) {
            revert CommitmentExceedsMax(currentCommitment + amount, launch.maxCommitment);
        }

        // Effects: update state before interactions
        commitments[launchId][msg.sender] = currentCommitment + amount;
        launch.totalRaised += amount;

        // Interactions
        IERC20(launch.fundingToken).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsCommitted(launchId, msg.sender, amount);
    }

    function finalizeLaunch(uint256 launchId) external onlyOwner nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound(launchId);
        if (launch.status != Status.Active) revert LaunchAlreadyFinalized(launchId);
        if (block.timestamp < launch.endTime) revert LaunchNotEnded(launchId);

        bool success = launch.totalRaised >= MIN_SUCCESS_THRESHOLD;

        if (success) {
            launch.status = Status.Success;
            uint256 totalTokens = launch.totalRaised * launch.allocationRatio;
            launch.totalTokensMinted = totalTokens;

            // Interactions: mint tokens after state is updated
            IMintableToken(launch.token).mint(address(this), totalTokens);
        } else {
            launch.status = Status.Failed;
        }

        emit LaunchFinalized(launchId, success, launch.totalRaised);
    }

    function claimTokens(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound(launchId);
        if (launch.status != Status.Success) revert LaunchNotSuccess(launchId);
        if (hasClaimed[launchId][msg.sender]) revert AlreadyClaimed(msg.sender);

        uint256 commitment = commitments[launchId][msg.sender];
        if (commitment == 0) revert NoCommitment(msg.sender);

        uint256 tokenAmount = commitment * launch.allocationRatio;
        if (tokenAmount == 0) revert ZeroAmount();

        // Effects
        hasClaimed[launchId][msg.sender] = true;

        // Interactions
        IERC20(launch.token).safeTransfer(msg.sender, tokenAmount);

        emit TokensClaimed(launchId, msg.sender, tokenAmount);
    }

    function withdrawFunds(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound(launchId);
        if (launch.status != Status.Failed) revert LaunchNotFailed(launchId);
        if (hasWithdrawn[launchId][msg.sender]) revert AlreadyWithdrawn(msg.sender);

        uint256 commitment = commitments[launchId][msg.sender];
        if (commitment == 0) revert NoCommitment(msg.sender);

        // Effects
        hasWithdrawn[launchId][msg.sender] = true;
        commitments[launchId][msg.sender] = 0;

        // Interactions
        IERC20(launch.fundingToken).safeTransfer(msg.sender, commitment);

        emit FundsWithdrawn(launchId, msg.sender, commitment);
    }

    function withdrawRaisedFunds(uint256 launchId, address recipient) external onlyOwner nonReentrant {
        Launch storage launch = launches[launchId];
        if (launch.token == address(0)) revert LaunchNotFound(launchId);
        if (launch.status != Status.Success) revert LaunchNotSuccess(launchId);
        if (recipient == address(0)) revert ZeroAddress();
        if (raisedFundsWithdrawn[launchId]) revert AlreadyWithdrawn(address(0));

        uint256 amountToWithdraw = launch.totalRaised;
        IERC20 fundingToken = IERC20(launch.fundingToken);
        uint256 balance = fundingToken.balanceOf(address(this));
        if (balance < amountToWithdraw) revert NothingToWithdraw();

        // Effects
        raisedFundsWithdrawn[launchId] = true;

        // Interactions
        fundingToken.safeTransfer(recipient, amountToWithdraw);

        emit RaisedFundsWithdrawn(launchId, recipient, amountToWithdraw);
    }

    function getLaunch(uint256 launchId) external view returns (Launch memory) {
        if (launches[launchId].token == address(0)) revert LaunchNotFound(launchId);
        return launches[launchId];
    }

    function getCommitment(uint256 launchId, address participant) external view returns (uint256) {
        return commitments[launchId][participant];
    }

    function getLaunchCount() external view returns (uint256) {
        return launchCount;
    }
}
