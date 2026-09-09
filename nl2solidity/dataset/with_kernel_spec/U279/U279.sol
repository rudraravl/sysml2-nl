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

interface IMintableToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(returndata, 0x20), returndata_size)
                }
            } else {
                revert("SafeERC20: call failed");
            }
        }
        if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: operation failed");
        }
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
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
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract FairLaunch is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    uint256 public constant MIN_SUPPLY = 1_000_000;
    uint256 public constant MAX_SUPPLY = 10_000_000_000;
    uint256 public constant FEE_BPS = 200;
    uint256 public constant BPS_DENOM = 10_000;

    // ============ Enums ============
    enum Phase {
        Pending,
        Active,
        Finalized,
        Cancelled
    }

    // ============ Immutable Storage ============
    IERC20 public immutable baseToken;
    IMintableToken public immutable projectToken;

    // ============ Mutable Storage ============
    address public treasury;
    Phase public currentPhase;
    uint256 public projectTokenSupply;
    uint256 public launchStartTime;
    uint256 public launchEndTime;
    uint256 public launchDuration;
    uint256 public minDepositAmount;
    uint256 public maxDepositAmount;
    uint256 public totalBaseCollected;
    uint256 public totalProjectAllocated;

    struct Participant {
        uint256 baseContributed;
        uint256 projectTokenAllocation;
        bool projectTokensClaimed;
        bool baseTokensWithdrawn;
    }

    mapping(address => Participant) public participants;
    address[] public participantList;

    // ============ Events ============
    event LaunchStarted(uint256 startTime, uint256 endTime, uint256 projectTokenSupply);
    event Deposited(address indexed participant, uint256 baseAmount, uint256 feeAmount);
    event ProjectTokensClaimed(address indexed participant, uint256 amount);
    event BaseTokensWithdrawn(address indexed participant, uint256 amount);
    event SupplyUpdated(uint256 newSupply);
    event PhaseParametersAdjusted(uint256 startTime, uint256 endTime, uint256 minDeposit, uint256 maxDeposit);
    event LaunchFinalized(uint256 totalBaseCollected, uint256 totalProjectAllocated);
    event LaunchCancelled();
    event TreasuryUpdated(address newTreasury);
    event BaseTokensSwept(address indexed treasury, uint256 amount);

    // ============ Custom Errors ============
    error InvalidPhase();
    error ZeroAddress();
    error ZeroAmount();
    error SupplyOutOfRange(uint256 supply);
    error DepositOutOfRange();
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error LaunchNotEnded();
    error NoContribution();
    error InvalidTimeRange();
    error NotInLaunchWindow();
    error NoParticipants();

    // ============ Constructor ============
    constructor(
        address _baseToken,
        address _projectToken,
        address _treasury,
        uint256 _projectTokenSupply,
        uint256 _launchDuration,
        uint256 _minDeposit,
        uint256 _maxDeposit
    ) Ownable(msg.sender) {
        if (_baseToken == address(0)) revert ZeroAddress();
        if (_projectToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_projectTokenSupply < MIN_SUPPLY || _projectTokenSupply > MAX_SUPPLY)
            revert SupplyOutOfRange(_projectTokenSupply);
        if (_launchDuration == 0) revert ZeroAmount();
        if (_maxDeposit > 0 && _minDeposit > _maxDeposit) revert DepositOutOfRange();

        baseToken = IERC20(_baseToken);
        projectToken = IMintableToken(_projectToken);
        treasury = _treasury;
        projectTokenSupply = _projectTokenSupply;
        launchDuration = _launchDuration;
        launchStartTime = block.timestamp;
        launchEndTime = block.timestamp + _launchDuration;
        minDepositAmount = _minDeposit;
        maxDepositAmount = _maxDeposit;
        currentPhase = Phase.Pending;

        emit SupplyUpdated(_projectTokenSupply);
    }

    // ============ Owner Functions ============

    function startLaunch() external onlyOwner {
        if (currentPhase != Phase.Pending) revert InvalidPhase();
        launchStartTime = block.timestamp;
        launchEndTime = block.timestamp + launchDuration;
        currentPhase = Phase.Active;
        emit LaunchStarted(launchStartTime, launchEndTime, projectTokenSupply);
    }

    function setProjectTokenSupply(uint256 _supply) external onlyOwner {
        if (currentPhase == Phase.Finalized || currentPhase == Phase.Cancelled) revert InvalidPhase();
        if (_supply < MIN_SUPPLY || _supply > MAX_SUPPLY) revert SupplyOutOfRange(_supply);
        projectTokenSupply = _supply;
        emit SupplyUpdated(_supply);
    }

    function adjustLaunchPhase(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minDeposit,
        uint256 _maxDeposit
    ) external onlyOwner {
        if (currentPhase == Phase.Finalized || currentPhase == Phase.Cancelled) revert InvalidPhase();
        if (_endTime <= _startTime) revert InvalidTimeRange();
        if (_maxDeposit > 0 && _minDeposit > _maxDeposit) revert DepositOutOfRange();

        launchStartTime = _startTime;
        launchEndTime = _endTime;
        launchDuration = _endTime - _startTime;
        minDepositAmount = _minDeposit;
        maxDepositAmount = _maxDeposit;

        emit PhaseParametersAdjusted(_startTime, _endTime, _minDeposit, _maxDeposit);
    }

    function finalizeLaunch() external onlyOwner {
        if (currentPhase != Phase.Active) revert InvalidPhase();
        if (block.timestamp <= launchEndTime) revert LaunchNotEnded();
        if (participantList.length == 0) revert NoParticipants();
        if (totalBaseCollected == 0) revert NoContribution();

        currentPhase = Phase.Finalized;
        totalProjectAllocated = projectTokenSupply;

        for (uint256 i = 0; i < participantList.length; i++) {
            address participant = participantList[i];
            uint256 allocation =
                (participants[participant].baseContributed * projectTokenSupply) / totalBaseCollected;
            participants[participant].projectTokenAllocation = allocation;
        }

        projectToken.mint(address(this), projectTokenSupply);

        emit LaunchFinalized(totalBaseCollected, totalProjectAllocated);
    }

    function cancelLaunch() external onlyOwner {
        if (currentPhase == Phase.Finalized || currentPhase == Phase.Cancelled) revert InvalidPhase();
        currentPhase = Phase.Cancelled;
        emit LaunchCancelled();
    }

    function sweepBaseTokens() external onlyOwner {
        if (currentPhase != Phase.Finalized) revert InvalidPhase();
        uint256 balance = baseToken.balanceOf(address(this));
        if (balance > 0) {
            baseToken.safeTransfer(treasury, balance);
            emit BaseTokensSwept(treasury, balance);
        }
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    // ============ Participant Functions ============

    function deposit(uint256 amount) external nonReentrant {
        if (currentPhase != Phase.Active) revert InvalidPhase();
        if (block.timestamp < launchStartTime || block.timestamp > launchEndTime) revert NotInLaunchWindow();
        if (amount == 0) revert ZeroAmount();
        if (minDepositAmount > 0 && amount < minDepositAmount) revert DepositOutOfRange();
        if (maxDepositAmount > 0 && amount > maxDepositAmount) revert DepositOutOfRange();

        uint256 fee = (amount * FEE_BPS) / BPS_DENOM;
        uint256 netAmount = amount - fee;

        if (participants[msg.sender].baseContributed == 0) {
            participantList.push(msg.sender);
        }
        participants[msg.sender].baseContributed += netAmount;
        totalBaseCollected += netAmount;

        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        if (fee > 0) {
            baseToken.safeTransfer(treasury, fee);
        }

        emit Deposited(msg.sender, netAmount, fee);
    }

    function claimProjectTokens() external nonReentrant {
        if (currentPhase != Phase.Finalized) revert InvalidPhase();
        Participant storage p = participants[msg.sender];
        if (p.projectTokensClaimed) revert AlreadyClaimed();
        if (p.projectTokenAllocation == 0) revert NoContribution();

        p.projectTokensClaimed = true;
        uint256 amount = p.projectTokenAllocation;

        IERC20(address(projectToken)).safeTransfer(msg.sender, amount);

        emit ProjectTokensClaimed(msg.sender, amount);
    }

    function withdrawBaseTokens() external nonReentrant {
        if (currentPhase != Phase.Cancelled) revert InvalidPhase();
        Participant storage p = participants[msg.sender];
        if (p.baseTokensWithdrawn) revert AlreadyWithdrawn();
        if (p.baseContributed == 0) revert NoContribution();

        p.baseTokensWithdrawn = true;
        uint256 amount = p.baseContributed;

        baseToken.safeTransfer(msg.sender, amount);

        emit BaseTokensWithdrawn(msg.sender, amount);
    }

    // ============ View Functions ============

    function getParticipantCount() external view returns (uint256) {
        return participantList.length;
    }

    function getParticipantInfo(address user)
        external
        view
        returns (
            uint256 baseContributed,
            uint256 projectTokenAllocation,
            bool projectTokensClaimed,
            bool baseTokensWithdrawn
        )
    {
        Participant storage p = participants[user];
        return (
            p.baseContributed,
            p.projectTokenAllocation,
            p.projectTokensClaimed,
            p.baseTokensWithdrawn
        );
    }

    function isLaunchActive() external view returns (bool) {
        return currentPhase == Phase.Active
            && block.timestamp >= launchStartTime
            && block.timestamp <= launchEndTime;
    }

    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= launchEndTime) return 0;
        return launchEndTime - block.timestamp;
    }
}
