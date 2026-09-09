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
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: TRANSFER_FROM_FAILED"
        );
    }
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

    function _transferOwnership(address newOwner) internal virtual {
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

contract TokenLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidRate();
    error SaleNotActive();
    error SaleAlreadyActive();
    error SaleNotEnded();
    error SaleNotFailed();
    error SaleNotConcluded();
    error BelowMinimumDeposit();
    error ExceedsProjectTokenCap();
    error NoDeposit();
    error NothingToClaim();
    error AlreadyClaimed();
    error AlreadyDeposited();
    error NoRemainingTokens();
    error CannotChangeDuringActiveSale();
    error InsufficientProjectTokensInContract();

    enum SalePhase {
        Inactive,
        Active,
        Ended,
        Failed
    }

    uint256 public constant MIN_DEPOSIT = 100 ether;
    uint256 public constant DEFAULT_ALLOCATION_RATE = 100;
    uint256 public constant RATE_DENOMINATOR = 100;

    IERC20 public immutable baseToken;
    IERC20 public immutable projectToken;

    uint256 public allocationRate;
    uint256 public totalProjectTokensForSale;
    uint256 public totalProjectTokensAllocated;
    uint256 public totalBaseDeposited;
    uint256 public minimumRaiseTarget;

    SalePhase public currentPhase;
    bool public saleSuccessful;

    uint256 public saleStartTime;
    uint256 public saleEndTime;

    struct Participant {
        uint256 depositedAmount;
        uint256 allocatedProjectTokens;
        bool claimed;
    }

    mapping(address => Participant) public participants;
    address[] public participantList;

    event TokensDeposited(address indexed participant, uint256 baseAmount, uint256 projectAmount);
    event ProjectTokensClaimed(address indexed participant, uint256 projectAmount);
    event DepositWithdrawn(address indexed participant, uint256 baseAmount);
    event SalePhaseChanged(SalePhase indexed previousPhase, SalePhase indexed newPhase, uint256 timestamp);
    event AllocationRateUpdated(uint256 oldRate, uint256 newRate);
    event MinimumRaiseUpdated(uint256 newMinimum);
    event TotalProjectTokensForSaleUpdated(uint256 newCap);
    event ProjectTokensFunded(address indexed from, uint256 amount);
    event RemainingProjectTokensWithdrawn(address indexed owner, uint256 amount);

    constructor(
        address _baseToken,
        address _projectToken,
        uint256 _totalProjectTokensForSale,
        uint256 _minimumRaiseTarget
    ) Ownable(msg.sender) ReentrancyGuard() {
        if (_baseToken == address(0) || _projectToken == address(0)) revert InvalidAddress();
        if (_totalProjectTokensForSale == 0) revert InvalidAmount();

        baseToken = IERC20(_baseToken);
        projectToken = IERC20(_projectToken);
        allocationRate = DEFAULT_ALLOCATION_RATE;
        totalProjectTokensForSale = _totalProjectTokensForSale;
        minimumRaiseTarget = _minimumRaiseTarget;
        currentPhase = SalePhase.Inactive;

        emit AllocationRateUpdated(0, allocationRate);
        emit MinimumRaiseUpdated(_minimumRaiseTarget);
        emit TotalProjectTokensForSaleUpdated(_totalProjectTokensForSale);
    }

    function setAllocationRate(uint256 _newRate) external onlyOwner {
        if (currentPhase != SalePhase.Inactive) revert CannotChangeDuringActiveSale();
        if (_newRate == 0) revert InvalidRate();
        uint256 oldRate = allocationRate;
        allocationRate = _newRate;
        emit AllocationRateUpdated(oldRate, _newRate);
    }

    function setMinimumRaiseTarget(uint256 _newMinimum) external onlyOwner {
        if (currentPhase != SalePhase.Inactive) revert CannotChangeDuringActiveSale();
        minimumRaiseTarget = _newMinimum;
        emit MinimumRaiseUpdated(_newMinimum);
    }

    function setTotalProjectTokensForSale(uint256 _amount) external onlyOwner {
        if (currentPhase != SalePhase.Inactive) revert CannotChangeDuringActiveSale();
        if (_amount == 0) revert InvalidAmount();
        totalProjectTokensForSale = _amount;
        emit TotalProjectTokensForSaleUpdated(_amount);
    }

    function fundProjectTokens(uint256 _amount) external onlyOwner {
        if (_amount == 0) revert InvalidAmount();
        projectToken.safeTransferFrom(msg.sender, address(this), _amount);
        totalProjectTokensForSale += _amount;
        emit ProjectTokensFunded(msg.sender, _amount);
    }

    function startSale() external onlyOwner {
        if (currentPhase != SalePhase.Inactive) revert SaleAlreadyActive();
        if (projectToken.balanceOf(address(this)) < totalProjectTokensForSale) {
            revert InsufficientProjectTokensInContract();
        }
        saleStartTime = block.timestamp;
        currentPhase = SalePhase.Active;
        emit SalePhaseChanged(SalePhase.Inactive, SalePhase.Active, block.timestamp);
    }

    function endSale() external onlyOwner {
        if (currentPhase != SalePhase.Active) revert SaleNotActive();
        saleEndTime = block.timestamp;
        saleSuccessful = totalBaseDeposited >= minimumRaiseTarget;
        SalePhase newPhase = saleSuccessful ? SalePhase.Ended : SalePhase.Failed;
        currentPhase = newPhase;
        emit SalePhaseChanged(SalePhase.Active, newPhase, block.timestamp);
    }

    function withdrawRemainingProjectTokens() external onlyOwner nonReentrant {
        if (currentPhase != SalePhase.Ended && currentPhase != SalePhase.Failed) {
            revert SaleNotConcluded();
        }
        uint256 unallocated = totalProjectTokensForSale - totalProjectTokensAllocated;
        if (unallocated == 0) revert NoRemainingTokens();

        totalProjectTokensForSale = totalProjectTokensAllocated;
        projectToken.safeTransfer(owner(), unallocated);
        emit RemainingProjectTokensWithdrawn(owner(), unallocated);
    }

    function deposit(uint256 _amount) external nonReentrant {
        if (currentPhase != SalePhase.Active) revert SaleNotActive();
        if (_amount < MIN_DEPOSIT) revert BelowMinimumDeposit();
        if (participants[msg.sender].depositedAmount > 0) revert AlreadyDeposited();

        uint256 projectAmount = (_amount * RATE_DENOMINATOR) / allocationRate;
        if (totalProjectTokensAllocated + projectAmount > totalProjectTokensForSale) {
            revert ExceedsProjectTokenCap();
        }

        participants[msg.sender] = Participant({
            depositedAmount: _amount,
            allocatedProjectTokens: projectAmount,
            claimed: false
        });
        participantList.push(msg.sender);
        totalBaseDeposited += _amount;
        totalProjectTokensAllocated += projectAmount;

        baseToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit TokensDeposited(msg.sender, _amount, projectAmount);
    }

    function claimProjectTokens() external nonReentrant {
        if (currentPhase != SalePhase.Ended) revert SaleNotEnded();
        Participant storage p = participants[msg.sender];
        if (p.depositedAmount == 0) revert NoDeposit();
        if (p.claimed) revert AlreadyClaimed();
        if (p.allocatedProjectTokens == 0) revert NothingToClaim();

        p.claimed = true;
        uint256 amount = p.allocatedProjectTokens;

        projectToken.safeTransfer(msg.sender, amount);

        emit ProjectTokensClaimed(msg.sender, amount);
    }

    function withdrawDepositedTokens() external nonReentrant {
        if (currentPhase != SalePhase.Failed) revert SaleNotFailed();
        Participant storage p = participants[msg.sender];
        uint256 amount = p.depositedAmount;
        if (amount == 0) revert NoDeposit();

        p.depositedAmount = 0;
        p.allocatedProjectTokens = 0;

        baseToken.safeTransfer(msg.sender, amount);

        emit DepositWithdrawn(msg.sender, amount);
    }

    function getParticipantCount() external view returns (uint256) {
        return participantList.length;
    }

    function getParticipant(address _account)
        external
        view
        returns (uint256 depositedAmount, uint256 allocatedProjectTokens, bool claimed)
    {
        Participant storage p = participants[_account];
        return (p.depositedAmount, p.allocatedProjectTokens, p.claimed);
    }

    function pendingProjectTokens(address _account) external view returns (uint256) {
        Participant storage p = participants[_account];
        if (p.claimed) return 0;
        return p.allocatedProjectTokens;
    }

    function saleSucceeded() external view returns (bool) {
        return totalBaseDeposited >= minimumRaiseTarget;
    }
}
