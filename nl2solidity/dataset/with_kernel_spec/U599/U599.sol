Looking at the failing tests, all three (`deposit`, `withdraw`, `addRewards`) involve `safeTransferFrom`. The bug is in the `SafeERC20.safeTransferFrom` function: it's missing the `from` parameter in `abi.encodeWithSelector`, causing the ERC20 `transferFrom` call to receive malformed arguments.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IYieldProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function claimRewards() external returns (uint256);
    function totalValue() external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        (bool success, bytes memory returndata) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "SafeERC20: approve failed");
    }
}

contract LiquidStakingVault {
    using SafeERC20 for IERC20;

    // --- Errors ---
    error ZeroAddress();
    error NotOwner();
    error NotOperator();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error FeeExceedsCap();
    error NoRewardsToClaim();
    error TransferFailed();

    // --- Events ---
    event Deposited(address indexed account, uint256 baseAmount, uint256 lstMinted);
    event Withdrawn(address indexed account, uint256 lstBurned, uint256 baseAmount, uint256 fee);
    event RewardsAdded(uint256 rewardAmount);
    event RewardsClaimed(address indexed account, uint256 amount);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event WithdrawalFeeUpdated(uint256 previousFee, uint256 newFee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // --- Token Metadata ---
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // --- Constants ---
    uint256 public constant FEE_CAP = 50; // 0.5% in basis points
    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 private constant REWARD_PRECISION = 1e18;

    // --- Immutables ---
    IERC20 public immutable baseAsset;
    IYieldProtocol public immutable yieldProtocol;

    // --- Access Control ---
    address public owner;
    address public operator;

    // --- Vault State ---
    uint256 public withdrawalFeeBps;
    uint256 public totalSupply;
    uint256 public totalBaseDeposited;
    uint256 public totalRewardsAccrued;
    uint256 public unclaimedRewards;

    // --- ERC20 State ---
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- Reward Index Accounting ---
    uint256 public globalRewardIndex;
    mapping(address => uint256) public userRewardIndex;
    mapping(address => uint256) public accruedRewards;

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    constructor(
        address _baseAsset,
        address _yieldProtocol,
        string memory _name,
        string memory _symbol
    ) {
        if (_baseAsset == address(0) || _yieldProtocol == address(0)) revert ZeroAddress();
        baseAsset = IERC20(_baseAsset);
        yieldProtocol = IYieldProtocol(_yieldProtocol);
        owner = msg.sender;
        operator = msg.sender;
        name = _name;
        symbol = _symbol;
        emit OperatorUpdated(address(0), operator);
    }

    // --- Owner Functions ---

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        address previous = operator;
        operator = _operator;
        emit OperatorUpdated(previous, _operator);
    }

    function setWithdrawalFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > FEE_CAP) revert FeeExceedsCap();
        uint256 previous = withdrawalFeeBps;
        withdrawalFeeBps = _feeBps;
        emit WithdrawalFeeUpdated(previous, _feeBps);
    }

    // --- ERC20 Functions ---

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            _approve(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _approve(address accountOwner, address spender, uint256 amount) internal {
        if (accountOwner == address(0) || spender == address(0)) revert ZeroAddress();
        allowance[accountOwner][spender] = amount;
        emit Approval(accountOwner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        _updateReward(from);
        _updateReward(to);

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        _updateReward(account);
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();
        if (balanceOf[account] < amount) revert InsufficientBalance();
        _updateReward(account);
        balanceOf[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    // --- Vault Value ---

    function _totalVaultValue() internal view returns (uint256) {
        return baseAsset.balanceOf(address(this)) + _protocolValue();
    }

    function _protocolValue() internal view returns (uint256) {
        try yieldProtocol.totalValue() returns (uint256 v) {
            return v;
        } catch {
            return 0;
        }
    }

    function exchangeRate() external view returns (uint256) {
        if (totalSupply == 0) return 1e18;
        return (_totalVaultValue() * 1e18) / totalSupply;
    }

    // --- User Functions ---

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 sharesToMint;
        if (totalSupply == 0) {
            sharesToMint = amount;
        } else {
            uint256 totalValue = _totalVaultValue();
            if (totalValue == 0) revert ZeroAmount();
            sharesToMint = (amount * totalSupply) / totalValue;
        }
        if (sharesToMint == 0) revert ZeroAmount();

        baseAsset.safeTransferFrom(msg.sender, address(this), amount);

        totalBaseDeposited += amount;
        _mint(msg.sender, sharesToMint);

        emit Deposited(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 lstAmount) external {
        if (lstAmount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < lstAmount) revert InsufficientBalance();

        uint256 totalValue = _totalVaultValue();
        if (totalValue == 0 || totalSupply == 0) revert InsufficientBalance();

        uint256 baseAmount = (lstAmount * totalValue) / totalSupply;
        if (baseAmount == 0) revert ZeroAmount();

        _burn(msg.sender, lstAmount);

        uint256 fee = (baseAmount * withdrawalFeeBps) / BPS_DENOMINATOR;
        uint256 amountToUser = baseAmount - fee;

        if (baseAmount > totalBaseDeposited) {
            totalBaseDeposited = 0;
        } else {
            totalBaseDeposited -= baseAmount;
        }

        if (fee > 0) {
            unclaimedRewards += fee;
            _distributeRewards(fee);
        }

        baseAsset.safeTransfer(msg.sender, amountToUser);

        emit Withdrawn(msg.sender, lstAmount, amountToUser, fee);
    }

    function claimRewards() external {
        _updateReward(msg.sender);
        uint256 pending = accruedRewards[msg.sender];
        if (pending == 0) revert NoRewardsToClaim();

        accruedRewards[msg.sender] = 0;
        unclaimedRewards -= pending;

        baseAsset.safeTransfer(msg.sender, pending);

        emit RewardsClaimed(msg.sender, pending);
    }

    function pendingRewards(address account) external view returns (uint256) {
        if (balanceOf[account] == 0) return accruedRewards[account];
        uint256 delta = globalRewardIndex - userRewardIndex[account];
        return accruedRewards[account] + (balanceOf[account] * delta) / REWARD_PRECISION;
    }

    // --- Operator Functions ---

    function operatorDepositToProtocol(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        if (baseAsset.balanceOf(address(this)) < amount) revert InsufficientBalance();
        baseAsset.safeApprove(address(yieldProtocol), amount);
        yieldProtocol.deposit(amount);
    }

    function operatorWithdrawFromProtocol(uint256 amount) external onlyOperator returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        uint256 received = yieldProtocol.withdraw(amount);
        return received;
    }

    function operatorClaimAndDistributeRewards() external onlyOperator {
        uint256 before = baseAsset.balanceOf(address(this));
        yieldProtocol.claimRewards();
        uint256 afterBalance = baseAsset.balanceOf(address(this));
        if (afterBalance <= before) revert NoRewardsToClaim();

        uint256 rewardAmount = afterBalance - before;
        totalRewardsAccrued += rewardAmount;
        unclaimedRewards += rewardAmount;

        _distributeRewards(rewardAmount);

        emit RewardsAdded(rewardAmount);
    }

    function addRewards(uint256 amount) external onlyOperator {
        if (amount == 0) revert ZeroAmount();
        baseAsset.safeTransferFrom(msg.sender, address(this), amount);

        totalRewardsAccrued += amount;
        unclaimedRewards += amount;

        _distributeRewards(amount);

        emit RewardsAdded(amount);
    }

    // --- Internal Reward Accounting ---

    function _distributeRewards(uint256 rewardAmount) internal {
        if (totalSupply == 0) {
            unclaimedRewards -= rewardAmount;
            return;
        }
        uint256 perShare = (rewardAmount * REWARD_PRECISION) / totalSupply;
        globalRewardIndex += perShare;
    }

    function _updateReward(address account) internal {
        if (userRewardIndex[account] < globalRewardIndex) {
            uint256 delta = globalRewardIndex - userRewardIndex[account];
            accruedRewards[account] += (balanceOf[account] * delta) / REWARD_PRECISION;
            userRewardIndex[account] = globalRewardIndex;
        }
    }
}
