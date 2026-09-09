// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly { revert(add(data, 32), mload(data)) }
            }
            revert("SafeERC20: transfer failed");
        }
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transfer returned false");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, amount)
        );
        if (!success) {
            if (data.length > 0) {
                assembly { revert(add(data, 32), mload(data)) }
            }
            revert("SafeERC20: transferFrom failed");
        }
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeERC20: transferFrom returned false");
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

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract WrappedBitcoinRestaker is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_STAKING_RATE_BPS = 1000;
    uint256 public constant MAX_PROTOCOL_FEE_BPS = 1000;
    uint256 public constant DEFAULT_PROTOCOL_FEE_BPS = 50;
    uint256 private constant BPS_DENOM = 10000;
    uint256 private constant YEAR = 365 days;
    uint256 private constant REWARD_PRECISION = 1e18;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientDeposit(address account, uint256 requested, uint256 available);
    error OperatorNotApproved(address operator);
    error OperatorAlreadyApproved(address operator);
    error OperatorNotInList(address operator);
    error StakingRateExceedsMax(uint256 rate, uint256 max);
    error ProtocolFeeExceedsMax(uint256 fee, uint256 max);
    error NothingToClaim(address account);
    error InvalidFeeRecipient();
    error CannotRescueStakingToken();

    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, address recipient, uint256 amount);
    event Restaked(address indexed account, address indexed operator, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 grossRewards, uint256 protocolFee, uint256 netRewards);
    event StakingRateUpdated(uint256 oldRate, uint256 newRate);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OperatorApproved(address indexed operator);
    event OperatorRevoked(address indexed operator);

    IERC20 public immutable wbtc;

    uint256 public stakingRateBps;
    uint256 public protocolFeeBps;
    address public feeRecipient;

    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    uint256 public lastRewardTimestamp;

    struct Account {
        uint256 depositBalance;
        uint256 stakedBalance;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }
    mapping(address => Account) public accounts;

    mapping(address => bool) public approvedOperators;
    address[] public operatorList;

    modifier onlyApprovedOperator(address operator) {
        if (!approvedOperators[operator]) revert OperatorNotApproved(operator);
        _;
    }

    constructor(
        address wbtc_,
        address feeRecipient_,
        uint256 initialStakingRateBps
    ) Ownable(msg.sender) {
        if (wbtc_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        if (initialStakingRateBps > MAX_STAKING_RATE_BPS)
            revert StakingRateExceedsMax(initialStakingRateBps, MAX_STAKING_RATE_BPS);

        wbtc = IERC20(wbtc_);
        feeRecipient = feeRecipient_;
        stakingRateBps = initialStakingRateBps;
        protocolFeeBps = DEFAULT_PROTOCOL_FEE_BPS;
        lastRewardTimestamp = block.timestamp;

        emit FeeRecipientUpdated(address(0), feeRecipient_);
        emit StakingRateUpdated(0, initialStakingRateBps);
        emit ProtocolFeeUpdated(0, DEFAULT_PROTOCOL_FEE_BPS);
    }

    function updateGlobalRewards() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }
        if (totalStaked == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastRewardTimestamp;
        uint256 rewardPerShareDelta = (stakingRateBps * REWARD_PRECISION * elapsed) /
            (BPS_DENOM * YEAR);
        accRewardPerShare += rewardPerShareDelta;
        lastRewardTimestamp = block.timestamp;
    }

    function _updateAccountRewards(address account) internal {
        Account storage a = accounts[account];
        uint256 newPending = (a.stakedBalance * accRewardPerShare) / REWARD_PRECISION;
        if (newPending >= a.rewardDebt) {
            uint256 delta = newPending - a.rewardDebt;
            a.pendingRewards += delta;
        }
        a.rewardDebt = newPending;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        updateGlobalRewards();
        _updateAccountRewards(msg.sender);

        Account storage a = accounts[msg.sender];
        a.depositBalance += amount;

        wbtc.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    function restake(address operator, uint256 amount) external onlyApprovedOperator(operator) {
        if (amount == 0) revert ZeroAmount();
        updateGlobalRewards();
        _updateAccountRewards(msg.sender);

        Account storage a = accounts[msg.sender];
        if (a.depositBalance < amount)
            revert InsufficientDeposit(msg.sender, amount, a.depositBalance);

        a.depositBalance -= amount;
        a.stakedBalance += amount;
        totalStaked += amount;

        a.rewardDebt = (a.stakedBalance * accRewardPerShare) / REWARD_PRECISION;

        emit Restaked(msg.sender, operator, amount);
    }

    function claimRewards() external {
        updateGlobalRewards();
        _updateAccountRewards(msg.sender);

        Account storage a = accounts[msg.sender];
        uint256 gross = a.pendingRewards;
        if (gross == 0) revert NothingToClaim(msg.sender);

        a.pendingRewards = 0;

        uint256 fee = (gross * protocolFeeBps) / BPS_DENOM;
        uint256 net = gross - fee;

        if (fee > 0) {
            wbtc.safeTransfer(feeRecipient, fee);
        }
        wbtc.safeTransfer(msg.sender, net);

        emit RewardsClaimed(msg.sender, gross, fee, net);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        updateGlobalRewards();
        _updateAccountRewards(msg.sender);

        Account storage a = accounts[msg.sender];
        if (a.depositBalance < amount)
            revert InsufficientDeposit(msg.sender, amount, a.depositBalance);

        a.depositBalance -= amount;
        wbtc.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, msg.sender, amount);
    }

    function pendingRewards(address account) external view returns (uint256) {
        Account storage a = accounts[account];
        uint256 acc = accRewardPerShare;
        if (totalStaked > 0 && block.timestamp > lastRewardTimestamp) {
            uint256 elapsed = block.timestamp - lastRewardTimestamp;
            uint256 delta = (stakingRateBps * REWARD_PRECISION * elapsed) / (BPS_DENOM * YEAR);
            acc += delta;
        }
        uint256 newPending = (a.stakedBalance * acc) / REWARD_PRECISION;
        if (newPending >= a.rewardDebt) {
            return a.pendingRewards + (newPending - a.rewardDebt);
        }
        return a.pendingRewards;
    }

    function operatorCount() external view returns (uint256) {
        return operatorList.length;
    }

    function approveOperator(address operator) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        if (approvedOperators[operator]) revert OperatorAlreadyApproved(operator);
        approvedOperators[operator] = true;
        operatorList.push(operator);
        emit OperatorApproved(operator);
    }

    function revokeOperator(address operator) external onlyOwner {
        if (!approvedOperators[operator]) revert OperatorNotInList(operator);
        approvedOperators[operator] = false;
        uint256 len = operatorList.length;
        for (uint256 i = 0; i < len; i++) {
            if (operatorList[i] == operator) {
                operatorList[i] = operatorList[len - 1];
                operatorList.pop();
                break;
            }
        }
        emit OperatorRevoked(operator);
    }

    function setStakingRate(uint256 newRateBps) external onlyOwner {
        if (newRateBps > MAX_STAKING_RATE_BPS)
            revert StakingRateExceedsMax(newRateBps, MAX_STAKING_RATE_BPS);
        updateGlobalRewards();
        uint256 old = stakingRateBps;
        stakingRateBps = newRateBps;
        emit StakingRateUpdated(old, newRateBps);
    }

    function setProtocolFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_PROTOCOL_FEE_BPS)
            revert ProtocolFeeExceedsMax(newFeeBps, MAX_PROTOCOL_FEE_BPS);
        uint256 old = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(old, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidFeeRecipient();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function rescueToken(address token, uint256 amount) external onlyOwner {
        if (token == address(wbtc)) revert CannotRescueStakingToken();
        IERC20(token).safeTransfer(owner(), amount);
    }
}
