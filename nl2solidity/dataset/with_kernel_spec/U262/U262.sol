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
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, currentAllowance + value));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < requestedDecrease) {
            revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, currentAllowance - requestedDecrease));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) internal {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(returndata, 32), returndata_size)
                }
            } else {
                revert SafeERC20FailedOperation(address(token));
            }
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), SafeERC20FailedOperation(address(token)));
        }
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

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() public virtual onlyOwner {
        address oldOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
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

interface IYieldProtocol {
    function deposit(uint256 wbtcAmount) external returns (uint256 receiptAmount);
    function withdraw(uint256 receiptAmount) external returns (uint256 wbtcAmount);
    function claimRewards() external returns (uint256 rewardAmount);
}

contract WBTCYieldVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant REWARD_PRECISION = 1e18;
    uint256 public constant MAX_FEE_BPS = 1_000; // 10%
    uint256 public constant MAX_TIMELOCK = 7 days;

    IERC20 public immutable wbtcToken;
    IERC20 public immutable yieldReceiptToken;
    IERC20 public immutable rewardToken;

    IYieldProtocol public yieldProtocol;
    address public feeRecipient;

    uint256 public totalDepositedWBTC;
    uint256 public totalShares;
    uint256 public depositFeeBps;
    uint256 public timelockDuration;
    uint256 public accRewardPerShare;

    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public lastDepositTime;
    mapping(address => uint256) public userRewardDebt;

    event Deposit(address indexed user, uint256 amountDeposited, uint256 sharesMinted, uint256 feeCollected);
    event Withdraw(address indexed user, uint256 amountWithdrawn, uint256 sharesBurned, uint256 rewardCollected);
    event ClaimRewards(address indexed user, uint256 rewardAmount);
    event YieldProtocolUpdated(address indexed oldProtocol, address indexed newProtocol);
    event OperationalParamsUpdated(uint256 newDepositFeeBps, uint256 newTimelockDuration);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientShares();
    error TimelockActive(uint256 unlockTime);
    error FeeExceedsMax();
    error TimelockExceedsMax();
    error NoSharesMinted();
    error NoAmountWithdrawn();
    error InsufficientRewardBalance();

    constructor(
        address _wbtcToken,
        address _yieldProtocol,
        address _yieldReceiptToken,
        address _rewardToken,
        address _feeRecipient
    ) Ownable(msg.sender) {
        if (_wbtcToken == address(0)) revert ZeroAddress();
        if (_yieldProtocol == address(0)) revert ZeroAddress();
        if (_yieldReceiptToken == address(0)) revert ZeroAddress();
        if (_rewardToken == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();

        wbtcToken = IERC20(_wbtcToken);
        yieldProtocol = IYieldProtocol(_yieldProtocol);
        yieldReceiptToken = IERC20(_yieldReceiptToken);
        rewardToken = IERC20(_rewardToken);
        feeRecipient = _feeRecipient;
        depositFeeBps = 50; // 0.5%
        timelockDuration = 24 hours;
    }

    function _updateReward() internal {
        if (totalShares > 0) {
            uint256 balanceBefore = rewardToken.balanceOf(address(this));
            try yieldProtocol.claimRewards() returns (uint256) {} catch {
                return;
            }
            uint256 rewardsReceived = rewardToken.balanceOf(address(this)) - balanceBefore;
            if (rewardsReceived > 0) {
                accRewardPerShare += (rewardsReceived * REWARD_PRECISION) / totalShares;
            }
        }
    }

    function _pendingRewards(address user) internal view returns (uint256) {
        return (userShares[user] * accRewardPerShare) / REWARD_PRECISION - userRewardDebt[user];
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _updateReward();

        wbtcToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 fee = (amount * depositFeeBps) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        if (fee > 0) {
            wbtcToken.safeTransfer(feeRecipient, fee);
        }

        wbtcToken.safeIncreaseAllowance(address(yieldProtocol), netAmount);
        uint256 sharesMinted = yieldProtocol.deposit(netAmount);
        if (sharesMinted == 0) revert NoSharesMinted();

        userDeposits[msg.sender] += netAmount;
        userShares[msg.sender] += sharesMinted;
        totalDepositedWBTC += netAmount;
        totalShares += sharesMinted;
        lastDepositTime[msg.sender] = block.timestamp;
        userRewardDebt[msg.sender] += (sharesMinted * accRewardPerShare) / REWARD_PRECISION;

        emit Deposit(msg.sender, amount, sharesMinted, fee);
    }

    function withdraw(uint256 shares) external nonReentrant {
        if (shares == 0) revert ZeroAmount();
        if (userShares[msg.sender] < shares) revert InsufficientShares();
        if (block.timestamp < lastDepositTime[msg.sender] + timelockDuration) {
            revert TimelockActive(lastDepositTime[msg.sender] + timelockDuration);
        }

        _updateReward();

        uint256 pending = _pendingRewards(msg.sender);

        uint256 depositReduction = (userDeposits[msg.sender] * shares) / userShares[msg.sender];

        userShares[msg.sender] -= shares;
        userDeposits[msg.sender] -= depositReduction;
        totalShares -= shares;
        totalDepositedWBTC -= depositReduction;
        userRewardDebt[msg.sender] = (userShares[msg.sender] * accRewardPerShare) / REWARD_PRECISION;

        uint256 amountWithdrawn = yieldProtocol.withdraw(shares);
        if (amountWithdrawn == 0) revert NoAmountWithdrawn();

        wbtcToken.safeTransfer(msg.sender, amountWithdrawn);

        if (pending > 0) {
            if (rewardToken.balanceOf(address(this)) < pending) revert InsufficientRewardBalance();
            rewardToken.safeTransfer(msg.sender, pending);
            emit ClaimRewards(msg.sender, pending);
        }

        emit Withdraw(msg.sender, amountWithdrawn, shares, pending);
    }

    function claimRewards() external nonReentrant {
        _updateReward();
        uint256 pending = _pendingRewards(msg.sender);
        if (pending > 0) {
            if (rewardToken.balanceOf(address(this)) < pending) revert InsufficientRewardBalance();
            userRewardDebt[msg.sender] = (userShares[msg.sender] * accRewardPerShare) / REWARD_PRECISION;
            rewardToken.safeTransfer(msg.sender, pending);
            emit ClaimRewards(msg.sender, pending);
        }
    }

    function setYieldProtocol(address newProtocol) external onlyOwner {
        if (newProtocol == address(0)) revert ZeroAddress();
        address oldProtocol = address(yieldProtocol);
        yieldProtocol = IYieldProtocol(newProtocol);
        emit YieldProtocolUpdated(oldProtocol, newProtocol);
    }

    function setOperationalParams(uint256 _depositFeeBps, uint256 _timelockDuration) external onlyOwner {
        if (_depositFeeBps > MAX_FEE_BPS) revert FeeExceedsMax();
        if (_timelockDuration > MAX_TIMELOCK) revert TimelockExceedsMax();
        depositFeeBps = _depositFeeBps;
        timelockDuration = _timelockDuration;
        emit OperationalParamsUpdated(_depositFeeBps, _timelockDuration);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function pendingRewards(address user) external view returns (uint256) {
        return _pendingRewards(user);
    }

    function getUserInfo(address user)
        external
        view
        returns (uint256 deposited, uint256 shares, uint256 pending, uint256 unlockTime)
    {
        deposited = userDeposits[user];
        shares = userShares[user];
        pending = _pendingRewards(user);
        unlockTime = lastDepositTime[user] + timelockDuration;
    }

    function totalReceiptTokens() external view returns (uint256) {
        return yieldReceiptToken.balanceOf(address(this));
    }
}
