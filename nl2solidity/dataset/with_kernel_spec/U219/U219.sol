// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BoostedYieldVault {
    // ============ Custom Errors ============
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error AmountTooLow();
    error FeeExceedsMax();
    error NotOperator();
    error NoRewardsToClaim();
    error InvalidAmount();
    error ReentrantCall();
    error TransferFailed();
    error ExistingDeposits();
    error FutureBlockLookup();
    error InsufficientRewardBalance();
    error CannotRecoverYieldToken();

    // ============ Constants ============
    uint256 public constant MIN_DEPOSIT = 100;
    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant REWARDS_DURATION = 7 days;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint8 public constant decimals = 18;

    // ============ Token Metadata ============
    string public name;
    string public symbol;

    // ============ Core Configuration ============
    IERC20 public yieldToken;
    IERC20 public rewardToken;
    address public operator;
    address public feeRecipient;
    uint256 public withdrawalFeeBps;

    // ============ ERC20 State (Liquid Wrapper Token) ============
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ============ Deposited Yield Token Tracking ============
    mapping(address => uint256) public depositedBalance;
    uint256 public totalDeposited;

    // ============ Reward Tracking ============
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public periodFinish;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // ============ Voting Power / Delegation ============
    mapping(address => address) public delegates;

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }
    mapping(address => Checkpoint[]) public checkpoints;
    mapping(address => uint32) public numCheckpoints;

    // ============ Reentrancy Guard ============
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ============ Events ============
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event YieldTokenUpdated(address indexed oldToken, address indexed newToken);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    // ============ Modifiers ============
    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ============ Constructor ============
    constructor(
        string memory _name,
        string memory _symbol,
        address _yieldToken,
        address _rewardToken,
        address _operator,
        address _feeRecipient,
        uint256 _withdrawalFeeBps
    ) {
        if (_yieldToken == address(0)) revert ZeroAddress();
        if (_rewardToken == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_withdrawalFeeBps > MAX_FEE_BPS) revert FeeExceedsMax();

        name = _name;
        symbol = _symbol;
        yieldToken = IERC20(_yieldToken);
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
        feeRecipient = _feeRecipient;
        withdrawalFeeBps = _withdrawalFeeBps;
        _status = _NOT_ENTERED;
    }

    // ============ ERC20 View Functions ============
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    // ============ ERC20 Mutable Functions ============
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        return true;
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit IERC20.Approval(owner_, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        _moveVotingPower(delegates[from], delegates[to], amount);
        emit IERC20.Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }
        _moveVotingPower(address(0), delegates[to], amount);
        emit IERC20.Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }
        _moveVotingPower(delegates[from], address(0), amount);
        emit IERC20.Transfer(from, address(0), amount);
    }

    // ============ Voting Power / Delegation ============
    function delegate(address delegatee) external {
        address current = delegates[msg.sender];
        uint256 balance = _balances[msg.sender];
        delegates[msg.sender] = delegatee;
        _moveVotingPower(current, delegatee, balance);
        emit DelegateChanged(msg.sender, current, delegatee);
    }

    function getVotes(address account) public view returns (uint256) {
        uint32 n = numCheckpoints[account];
        return n == 0 ? 0 : checkpoints[account][n - 1].votes;
    }

    function getPastVotes(address account, uint256 blockNumber) public view returns (uint256) {
        if (blockNumber >= block.number) revert FutureBlockLookup();
        uint32 n = numCheckpoints[account];
        if (n == 0) return 0;
        if (checkpoints[account][n - 1].fromBlock <= blockNumber) {
            return checkpoints[account][n - 1].votes;
        }
        if (checkpoints[account][0].fromBlock > blockNumber) return 0;
        uint32 low = 0;
        uint32 high = n - 1;
        while (low < high) {
            uint32 mid = (low + high + 1) / 2;
            if (checkpoints[account][mid].fromBlock <= blockNumber) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return checkpoints[account][low].votes;
    }

    function _moveVotingPower(address from, address to, uint256 amount) internal {
        if (amount == 0) return;
        if (from != address(0)) {
            _writeCheckpoint(from, false, amount);
        }
        if (to != address(0)) {
            _writeCheckpoint(to, true, amount);
        }
    }

    function _writeCheckpoint(address delegatee, bool isAdd, uint256 amount) internal {
        uint32 n = numCheckpoints[delegatee];
        uint224 oldVotes = n == 0 ? 0 : checkpoints[delegatee][n - 1].votes;
        uint224 newVotes;
        if (isAdd) {
            newVotes = oldVotes + uint224(amount);
        } else {
            newVotes = oldVotes - uint224(amount);
        }
        uint32 currentBlock = uint32(block.number);
        // Use >= instead of == to avoid strict-equality flag;
        // fromBlock can never exceed currentBlock, so >= is equivalent to ==.
        if (n > 0 && checkpoints[delegatee][n - 1].fromBlock >= currentBlock) {
            checkpoints[delegatee][n - 1].votes = newVotes;
        } else {
            checkpoints[delegatee].push(Checkpoint(currentBlock, newVotes));
            numCheckpoints[delegatee] = n + 1;
        }
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    // ============ Core Vault Functions ============
    function deposit(uint256 amount) external nonReentrant {
        if (amount < MIN_DEPOSIT) revert AmountTooLow();

        _updateReward(msg.sender);

        // Effects: update state before external interaction (CEI)
        depositedBalance[msg.sender] += amount;
        totalDeposited += amount;
        _mint(msg.sender, amount);

        // Interactions: pull yield token from depositor
        _safeTransferFrom(yieldToken, msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _updateReward(msg.sender);

        uint256 fee = (amount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 amountOut = amount - fee;

        // Effects: burn wrapper tokens and update deposited tracking before transfers
        _burn(msg.sender, amount);

        if (depositedBalance[msg.sender] >= amount) {
            depositedBalance[msg.sender] -= amount;
        } else {
            depositedBalance[msg.sender] = 0;
        }
        totalDeposited -= amount;

        // Interactions
        if (fee > 0) {
            _safeTransfer(yieldToken, feeRecipient, fee);
        }
        _safeTransfer(yieldToken, msg.sender, amountOut);

        emit Withdraw(msg.sender, amount, fee);
    }

    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (!(reward > 0)) revert NoRewardsToClaim();
        // Effects: zero out rewards before transfer (CEI)
        rewards[msg.sender] = 0;
        // Interactions
        _safeTransfer(rewardToken, msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    // ============ Reward Calculation ============
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function notifyRewardAmount(uint256 reward) external onlyOperator nonReentrant {
        _updateReward(address(0));
        uint256 totalRewards;
        if (block.timestamp >= periodFinish) {
            totalRewards = reward;
            rewardRate = reward / REWARDS_DURATION;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            totalRewards = leftover + reward;
            rewardRate = totalRewards / REWARDS_DURATION;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + REWARDS_DURATION;

        // Check total rewards against balance directly (avoid divide-before-multiply)
        uint256 balance = rewardToken.balanceOf(address(this));
        if (totalRewards > balance) revert InsufficientRewardBalance();

        emit RewardAdded(reward);
    }

    // ============ Operator Functions ============
    function setWithdrawalFeeBps(uint256 newFee) external onlyOperator {
        if (newFee > MAX_FEE_BPS) revert FeeExceedsMax();
        uint256 oldFee = withdrawalFeeBps;
        withdrawalFeeBps = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function setYieldToken(address newToken) external onlyOperator {
        if (newToken == address(0)) revert ZeroAddress();
        if (totalDeposited > 0) revert ExistingDeposits();
        address oldToken = address(yieldToken);
        yieldToken = IERC20(newToken);
        emit YieldTokenUpdated(oldToken, newToken);
    }

    function setOperator(address newOperator) external onlyOperator {
        if (newOperator == address(0)) revert ZeroAddress();
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOperator {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(oldRecipient, newFeeRecipient);
    }

    function recoverToken(address token, address to, uint256 amount) external onlyOperator {
        if (to == address(0)) revert ZeroAddress();
        if (token == address(yieldToken)) revert CannotRecoverYieldToken();
        _safeTransfer(IERC20(token), to, amount);
        emit Recovered(token, to, amount);
    }

    // ============ Safe Transfer Helpers ============
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }
}
