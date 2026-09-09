// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(value == 0 || token.allowance(address(this), spender) == 0, "SafeERC20: bad approve call");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: operation did not succeed");
        }
    }
}

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert NotOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract TokenLaunchPlatform is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error NotEventCreator();
    error InvalidCaps();
    error InvalidTimes();
    error InvalidPrice();
    error InvalidAllocation();
    error EventNotActive();
    error EventNotEnded();
    error HardCapExceeded();
    error AllocationExceeded();
    error ZeroAmount();
    error NothingToClaim();
    error NothingToWithdraw();
    error AlreadyClaimed();
    error FeeTooHigh();
    error NoFeesToWithdraw();

    struct LaunchEvent {
        address saleToken;
        address fundToken;
        uint256 softCap;
        uint256 hardCap;
        uint256 allocationPerUser;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        address creator;
        uint256 totalRaised;
        uint256 saleTokenDeposited;
        bool cancelled;
        bool finalized;
    }

    uint256 public feePercent;
    uint256 public constant MAX_FEE = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MIN_SOFT_CAP_TOKENS = 100;
    uint256 public constant MAX_HARD_CAP_TOKENS = 10000;
    uint256 public nextEventId;

    mapping(uint256 => LaunchEvent) public launchEvents;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(address => uint256) public accumulatedFees;

    event LaunchCreated(
        uint256 indexed eventId,
        address indexed creator,
        address saleToken,
        address fundToken,
        uint256 softCap,
        uint256 hardCap,
        uint256 allocationPerUser,
        uint256 startTime,
        uint256 endTime,
        uint256 price
    );
    event Contributed(uint256 indexed eventId, address indexed contributor, uint256 amount);
    event TokensClaimed(uint256 indexed eventId, address indexed contributor, uint256 saleAmount);
    event ContributionWithdrawn(uint256 indexed eventId, address indexed contributor, uint256 amount);
    event EventCancelled(uint256 indexed eventId);
    event EventFinalized(uint256 indexed eventId, bool success);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);
    event LeftoverWithdrawn(uint256 indexed eventId, address indexed creator, uint256 amount);

    constructor() {
        feePercent = 200;
    }

    function createLaunch(
        address saleToken,
        address fundToken,
        uint256 softCap,
        uint256 hardCap,
        uint256 allocationPerUser,
        uint256 startTime,
        uint256 endTime,
        uint256 price
    ) external nonReentrant returns (uint256 eventId) {
        if (saleToken == address(0) || fundToken == address(0)) revert InvalidCaps();
        if (softCap > hardCap) revert InvalidCaps();
        if (price == 0) revert InvalidPrice();
        if (allocationPerUser == 0 || allocationPerUser > hardCap) revert InvalidAllocation();
        if (startTime >= endTime || startTime < block.timestamp) revert InvalidTimes();

        uint256 unit = 10 ** uint256(IERC20(fundToken).decimals());
        if (softCap < MIN_SOFT_CAP_TOKENS * unit) revert InvalidCaps();
        if (hardCap > MAX_HARD_CAP_TOKENS * unit) revert InvalidCaps();

        eventId = nextEventId++;
        LaunchEvent storage e = launchEvents[eventId];
        e.saleToken = saleToken;
        e.fundToken = fundToken;
        e.softCap = softCap;
        e.hardCap = hardCap;
        e.allocationPerUser = allocationPerUser;
        e.startTime = startTime;
        e.endTime = endTime;
        e.price = price;
        e.creator = msg.sender;

        uint256 saleAmount = hardCap * price;
        e.saleTokenDeposited = saleAmount;

        IERC20(saleToken).safeTransferFrom(msg.sender, address(this), saleAmount);

        emit LaunchCreated(
            eventId,
            msg.sender,
            saleToken,
            fundToken,
            softCap,
            hardCap,
            allocationPerUser,
            startTime,
            endTime,
            price
        );
    }

    function contribute(uint256 eventId, uint256 amount) external nonReentrant {
        LaunchEvent storage e = launchEvents[eventId];
        if (e.creator == address(0)) revert EventNotActive();
        if (e.cancelled || e.finalized) revert EventNotActive();
        if (block.timestamp < e.startTime || block.timestamp > e.endTime) revert EventNotActive();
        if (amount == 0) revert ZeroAmount();
        if (e.totalRaised + amount > e.hardCap) revert HardCapExceeded();
        if (contributions[eventId][msg.sender] + amount > e.allocationPerUser) revert AllocationExceeded();

        contributions[eventId][msg.sender] += amount;
        e.totalRaised += amount;

        IERC20(e.fundToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Contributed(eventId, msg.sender, amount);
    }

    function finalizeEvent(uint256 eventId) external nonReentrant {
        LaunchEvent storage e = launchEvents[eventId];
        if (e.creator == address(0)) revert EventNotActive();
        if (e.finalized) revert EventNotActive();
        if (!e.cancelled && block.timestamp < e.endTime) revert EventNotEnded();

        e.finalized = true;
        bool success = !e.cancelled && e.totalRaised >= e.softCap;

        if (success) {
            uint256 fee = (e.totalRaised * feePercent) / FEE_DENOMINATOR;
            accumulatedFees[e.fundToken] += fee;
            uint256 creatorShare = e.totalRaised - fee;
            if (creatorShare > 0) {
                IERC20(e.fundToken).safeTransfer(e.creator, creatorShare);
            }
        }

        emit EventFinalized(eventId, success);
    }

    function claimTokens(uint256 eventId) external nonReentrant {
        LaunchEvent storage e = launchEvents[eventId];
        if (!e.finalized) revert EventNotEnded();
        if (e.cancelled || e.totalRaised < e.softCap) revert NothingToClaim();
        if (hasClaimed[eventId][msg.sender]) revert AlreadyClaimed();

        uint256 contribution = contributions[eventId][msg.sender];
        if (contribution == 0) revert NothingToClaim();

        hasClaimed[eventId][msg.sender] = true;
        uint256 saleAmount = contribution * e.price;

        IERC20(e.saleToken).safeTransfer(msg.sender, saleAmount);

        emit TokensClaimed(eventId, msg.sender, saleAmount);
    }

    function withdrawContribution(uint256 eventId) external nonReentrant {
        LaunchEvent storage e = launchEvents[eventId];
        if (e.creator == address(0)) revert EventNotActive();

        bool canWithdraw = e.cancelled || (e.finalized && e.totalRaised < e.softCap);
        if (!canWithdraw) revert NothingToWithdraw();

        uint256 contribution = contributions[eventId][msg.sender];
        if (contribution == 0) revert NothingToWithdraw();

        contributions[eventId][msg.sender] = 0;

        IERC20(e.fundToken).safeTransfer(msg.sender, contribution);

        emit ContributionWithdrawn(eventId, msg.sender, contribution);
    }

    function cancelEvent(uint256 eventId) external onlyOwner {
        LaunchEvent storage e = launchEvents[eventId];
        if (e.creator == address(0)) revert EventNotActive();
        if (e.cancelled || e.finalized) revert EventNotActive();
        e.cancelled = true;
        emit EventCancelled(eventId);
    }

    function creatorWithdrawLeftover(uint256 eventId) external nonReentrant {
        LaunchEvent storage e = launchEvents[eventId];
        if (msg.sender != e.creator) revert NotEventCreator();
        if (!e.finalized && !e.cancelled) revert EventNotEnded();

        uint256 remaining;
        if (!e.cancelled && e.totalRaised >= e.softCap) {
            uint256 sold = e.totalRaised * e.price;
            remaining = e.saleTokenDeposited > sold ? e.saleTokenDeposited - sold : 0;
        } else {
            remaining = e.saleTokenDeposited;
        }

        if (remaining == 0) revert NothingToWithdraw();

        e.saleTokenDeposited = 0;

        IERC20(e.saleToken).safeTransfer(e.creator, remaining);

        emit LeftoverWithdrawn(eventId, e.creator, remaining);
    }

    function setFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert FeeTooHigh();
        uint256 oldFee = feePercent;
        feePercent = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function withdrawFees(address token) external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees[token];
        if (amount == 0) revert NoFeesToWithdraw();
        accumulatedFees[token] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit FeesWithdrawn(token, msg.sender, amount);
    }

    function getContribution(uint256 eventId, address user) external view returns (uint256) {
        return contributions[eventId][user];
    }

    function getEventStatus(uint256 eventId) external view returns (uint8) {
        LaunchEvent storage e = launchEvents[eventId];
        if (e.cancelled) return 3;
        if (!e.finalized) {
            if (block.timestamp < e.endTime) return 0;
            return e.totalRaised >= e.softCap ? 1 : 2;
        }
        return e.totalRaised >= e.softCap ? 1 : 2;
    }

    function previewClaim(uint256 eventId, address user) external view returns (uint256) {
        return contributions[eventId][user] * launchEvents[eventId].price;
    }
}
