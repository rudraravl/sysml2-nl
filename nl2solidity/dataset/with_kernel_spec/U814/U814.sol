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

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
        return returndata;
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (_owner != _msgSender()) revert OwnableUnauthorizedAccount(_msgSender());
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(newOwner);
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }
}

contract TokenLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Phase { Idle, Open, Finalized }

    error NotInOpenPhase();
    error NotFinalized();
    error AlreadyParticipated();
    error InsufficientDeposit();
    error LaunchNotEnded();
    error LaunchSuccessful();
    error LaunchFailed();
    error NothingToClaim();
    error NothingToWithdraw();
    error ZeroAddress();
    error InvalidParameters();

    uint256 public constant MIN_RAISE = 100_000 * 10 ** 18;
    uint256 public constant MIN_PARTICIPATION_DURATION = 24 hours;

    IERC20 public immutable depositToken;
    IERC20 public immutable projectToken;

    Phase public phase;
    uint256 public launchStartTime;
    uint256 public launchEndTime;
    uint256 public totalRaised;
    uint256 public totalProjectTokens;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public hasParticipated;
    mapping(address => uint256) public claimedProjectTokens;
    mapping(address => bool) public hasClaimed;

    bool public launchSuccessful;

    event LaunchStarted(uint256 startTime, uint256 endTime);
    event LaunchFinalized(bool successful, uint256 totalRaised);
    event Deposited(address indexed participant, uint256 amount);
    event ProjectTokensClaimed(address indexed participant, uint256 amount);
    event DepositedTokensWithdrawn(address indexed participant, uint256 amount);
    event ProjectTokensWithdrawnByOwner(uint256 amount);
    event DepositedTokensWithdrawnByOwner(uint256 amount);

    constructor(address _depositToken, address _projectToken) {
        if (_depositToken == address(0) || _projectToken == address(0)) revert ZeroAddress();
        depositToken = IERC20(_depositToken);
        projectToken = IERC20(_projectToken);
    }

    modifier onlyOpenPhase() {
        if (phase != Phase.Open) revert NotInOpenPhase();
        _;
    }

    modifier onlyFinalized() {
        if (phase != Phase.Finalized) revert NotFinalized();
        _;
    }

    function startLaunch(uint256 participationDuration, uint256 _totalProjectTokens) external onlyOwner {
        if (phase != Phase.Idle) revert InvalidParameters();
        if (participationDuration < MIN_PARTICIPATION_DURATION) revert InvalidParameters();
        if (_totalProjectTokens == 0) revert InvalidParameters();

        totalProjectTokens = _totalProjectTokens;
        launchStartTime = block.timestamp;
        launchEndTime = block.timestamp + participationDuration;
        phase = Phase.Open;

        projectToken.safeTransferFrom(msg.sender, address(this), _totalProjectTokens);

        emit LaunchStarted(launchStartTime, launchEndTime);
    }

    function deposit(uint256 amount) external nonReentrant onlyOpenPhase {
        if (block.timestamp >= launchEndTime) revert NotInOpenPhase();
        if (amount == 0) revert InsufficientDeposit();
        if (hasParticipated[msg.sender]) revert AlreadyParticipated();

        // Effects before interactions
        hasParticipated[msg.sender] = true;
        deposits[msg.sender] = amount;
        totalRaised += amount;

        depositToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    function finalizeLaunch() external onlyOwner onlyOpenPhase {
        if (block.timestamp < launchEndTime) revert LaunchNotEnded();

        launchSuccessful = totalRaised >= MIN_RAISE;
        phase = Phase.Finalized;

        emit LaunchFinalized(launchSuccessful, totalRaised);
    }

    function claimProjectTokens() external nonReentrant onlyFinalized {
        if (!launchSuccessful) revert LaunchFailed();
        if (!hasParticipated[msg.sender]) revert NothingToClaim();
        if (hasClaimed[msg.sender]) revert NothingToClaim();

        uint256 allocation = (deposits[msg.sender] * totalProjectTokens) / totalRaised;
        if (allocation == 0) revert NothingToClaim();

        hasClaimed[msg.sender] = true;
        claimedProjectTokens[msg.sender] = allocation;

        projectToken.safeTransfer(msg.sender, allocation);

        emit ProjectTokensClaimed(msg.sender, allocation);
    }

    function withdrawFailedDeposit() external nonReentrant onlyFinalized {
        if (launchSuccessful) revert LaunchSuccessful();
        if (!hasParticipated[msg.sender]) revert NothingToWithdraw();

        uint256 amount = deposits[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        deposits[msg.sender] = 0;
        hasParticipated[msg.sender] = false;

        depositToken.safeTransfer(msg.sender, amount);

        emit DepositedTokensWithdrawn(msg.sender, amount);
    }

    function withdrawUnclaimedProjectTokens() external onlyOwner onlyFinalized {
        if (!launchSuccessful) revert LaunchFailed();

        uint256 balance = projectToken.balanceOf(address(this));
        uint256 claimedTotal = _totalClaimed();
        uint256 unclaimed = totalProjectTokens > claimedTotal ? totalProjectTokens - claimedTotal : 0;
        uint256 toWithdraw = unclaimed < balance ? unclaimed : balance;
        if (toWithdraw <= 0) revert NothingToWithdraw();

        projectToken.safeTransfer(msg.sender, toWithdraw);

        emit ProjectTokensWithdrawnByOwner(toWithdraw);
    }

    function withdrawRaisedDepositTokens() external onlyOwner onlyFinalized {
        if (!launchSuccessful) revert LaunchFailed();

        uint256 balance = depositToken.balanceOf(address(this));
        if (balance <= 0) revert NothingToWithdraw();

        depositToken.safeTransfer(msg.sender, balance);

        emit DepositedTokensWithdrawnByOwner(balance);
    }

    function _totalClaimed() internal view returns (uint256) {
        return totalProjectTokens > projectToken.balanceOf(address(this))
            ? totalProjectTokens - projectToken.balanceOf(address(this))
            : 0;
    }

    function previewAllocation(address participant) external view returns (uint256) {
        if (totalRaised == 0) return 0;
        return (deposits[participant] * totalProjectTokens) / totalRaised;
    }
}
