// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidStakingPool {
    // ============ Constants ============

    uint256 public constant MAX_VALIDATORS = 25;
    uint256 public constant WITHDRAWAL_FEE_BPS = 50; // 0.5% fixed
    uint256 public constant MAX_FEE_BPS = 5000; // 50%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRECISION = 1e18;

    // ============ Token Metadata ============

    string public constant name = "Liquid Staked ETH";
    string public constant symbol = "LSETH";
    uint8 public constant decimals = 18;

    // ============ Access Control ============

    address public owner;
    address public operator;
    address public feeRecipient;

    // ============ Fee Configuration ============

    uint256 public feePercentage; // in basis points, applied to reward distribution

    // ============ Staking State ============

    uint256 public totalStaked;
    uint256 public totalLSTSupply;

    // ============ Validator Registry ============

    mapping(address => bool) public isValidator;
    address[] public validatorList;
    uint256 public validatorCount;

    // ============ ERC20 State ============

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ============ Rewards State ============

    uint256 public accRewardPerShare;
    mapping(address => uint256) public userRewardDebt;
    mapping(address => uint256) public userPendingRewards;

    // ============ Reentrancy Guard ============

    uint256 private _locked = 1;

    // ============ Events ============

    event Deposited(address indexed user, uint256 amount, uint256 minted);
    event Withdrawn(address indexed user, uint256 amountBurned, uint256 nativeReturned, uint256 fee);
    event LSTMinted(address indexed to, uint256 amount);
    event LSTBurned(address indexed from, uint256 amount);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event RewardsDistributed(address indexed caller, uint256 amount, uint256 feeAmount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event OperatorUpdated(address oldOperator, address newOperator);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ============ Errors ============

    error NotOwner();
    error NotOperator();
    error ZeroAddress();
    error MaxValidatorsReached();
    error ValidatorAlreadyApproved();
    error ValidatorNotApproved();
    error FeeTooHigh();
    error InsufficientBalance();
    error InsufficientAllowance();
    error NoValidatorsApproved();
    error NothingToClaim();
    error ZeroAmount();
    error NoActiveStake();
    error TransferFailed();
    error Reentrancy();

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============ Constructor ============

    constructor(address _operator, address _feeRecipient, uint256 _feePercentage) {
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feePercentage > MAX_FEE_BPS) revert FeeTooHigh();
        owner = msg.sender;
        operator = _operator;
        feeRecipient = _feeRecipient;
        feePercentage = _feePercentage;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============ ERC20 View Functions ============

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address account, address spender) public view returns (uint256) {
        return _allowances[account][spender];
    }

    function totalSupply() public view returns (uint256) {
        return totalLSTSupply;
    }

    // ============ ERC20 Mutative Functions ============

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (_balances[from] < amount) revert InsufficientBalance();
        if (from == to) {
            return;
        }
        _updateReward(from);
        _updateReward(to);
        _balances[from] -= amount;
        _balances[to] += amount;
        userRewardDebt[from] = _balances[from] * accRewardPerShare / PRECISION;
        userRewardDebt[to] = _balances[to] * accRewardPerShare / PRECISION;
        emit Transfer(from, to, amount);
    }

    // ============ Internal Rewards Helpers ============

    function _updateReward(address user) internal {
        uint256 balance = _balances[user];
        if (balance > 0) {
            uint256 pending = balance * accRewardPerShare / PRECISION - userRewardDebt[user];
            if (pending > 0) {
                userPendingRewards[user] += pending;
            }
        }
        userRewardDebt[user] = balance * accRewardPerShare / PRECISION;
    }

    // ============ Public View: Rewards ============

    function pendingReward(address user) external view returns (uint256) {
        uint256 currentPending = _balances[user] * accRewardPerShare / PRECISION - userRewardDebt[user];
        return userPendingRewards[user] + currentPending;
    }

    // ============ Staking: Deposit ============

    function deposit() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (validatorCount == 0) revert NoValidatorsApproved();

        _updateReward(msg.sender);

        uint256 toMint;
        if (totalLSTSupply == 0 || totalStaked == 0) {
            toMint = msg.value;
        } else {
            toMint = msg.value * totalLSTSupply / totalStaked;
        }

        totalStaked += msg.value;
        _balances[msg.sender] += toMint;
        totalLSTSupply += toMint;
        userRewardDebt[msg.sender] = _balances[msg.sender] * accRewardPerShare / PRECISION;

        emit Transfer(address(0), msg.sender, toMint);
        emit LSTMinted(msg.sender, toMint);
        emit Deposited(msg.sender, msg.value, toMint);
    }

    // ============ Staking: Withdraw ============

    function withdraw(uint256 lstAmount) external nonReentrant {
        if (lstAmount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < lstAmount) revert InsufficientBalance();
        if (totalLSTSupply == 0) revert NoActiveStake();

        _updateReward(msg.sender);

        // Compute fee with full precision to avoid divide-before-multiply.
        // fee = (lstAmount * totalStaked * WITHDRAWAL_FEE_BPS) / (totalLSTSupply * BPS_DENOMINATOR)
        uint256 fee = (lstAmount * totalStaked * WITHDRAWAL_FEE_BPS) /
            (totalLSTSupply * BPS_DENOMINATOR);
        uint256 nativeValue = (lstAmount * totalStaked) / totalLSTSupply;
        uint256 toReturn = nativeValue - fee;

        _balances[msg.sender] -= lstAmount;
        totalLSTSupply -= lstAmount;
        totalStaked -= toReturn;
        userRewardDebt[msg.sender] = _balances[msg.sender] * accRewardPerShare / PRECISION;

        emit Transfer(msg.sender, address(0), lstAmount);
        emit LSTBurned(msg.sender, lstAmount);
        emit Withdrawn(msg.sender, lstAmount, toReturn, fee);

        (bool success, ) = msg.sender.call{value: toReturn}("");
        if (!success) revert TransferFailed();
    }

    // ============ Rewards: Distribute ============

    function distributeRewards() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (totalLSTSupply == 0) revert NoActiveStake();

        uint256 fee = msg.value * feePercentage / BPS_DENOMINATOR;
        uint256 rewardAmount = msg.value - fee;

        accRewardPerShare += rewardAmount * PRECISION / totalLSTSupply;

        emit RewardsDistributed(msg.sender, rewardAmount, fee);

        if (fee > 0) {
            (bool success, ) = feeRecipient.call{value: fee}("");
            if (!success) revert TransferFailed();
        }
    }

    // ============ Rewards: Claim ============

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 pending = userPendingRewards[msg.sender];
        if (pending == 0) revert NothingToClaim();
        userPendingRewards[msg.sender] = 0;
        emit RewardsClaimed(msg.sender, pending);
        (bool success, ) = msg.sender.call{value: pending}("");
        if (!success) revert TransferFailed();
    }

    // ============ Operator: Validator Management ============

    function addValidator(address validator) external onlyOperator {
        if (validator == address(0)) revert ZeroAddress();
        if (isValidator[validator]) revert ValidatorAlreadyApproved();
        if (validatorCount >= MAX_VALIDATORS) revert MaxValidatorsReached();
        isValidator[validator] = true;
        validatorList.push(validator);
        validatorCount++;
        emit ValidatorAdded(validator);
    }

    function removeValidator(address validator) external onlyOperator {
        if (!isValidator[validator]) revert ValidatorNotApproved();
        isValidator[validator] = false;
        uint256 len = validatorList.length;
        for (uint256 i = 0; i < len; i++) {
            if (validatorList[i] == validator) {
                validatorList[i] = validatorList[len - 1];
                validatorList.pop();
                break;
            }
        }
        validatorCount--;
        emit ValidatorRemoved(validator);
    }

    // ============ Operator: Fee Update ============

    function updateFeePercentage(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeePercentageUpdated(feePercentage, newFee);
        feePercentage = newFee;
    }

    // ============ Owner: Configuration ============

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ============ View Functions ============

    function getValidators() external view returns (address[] memory) {
        return validatorList;
    }

    function getExchangeRate() external view returns (uint256) {
        if (totalLSTSupply == 0) return PRECISION;
        return totalStaked * PRECISION / totalLSTSupply;
    }

    function totalRewardsPending() external view returns (uint256) {
        return address(this).balance - totalStaked;
    }
}
